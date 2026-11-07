<#
.SYNOPSIS
    Audits BepInEx configuration entries: every numeric setting must declare the values it accepts.

.DESCRIPTION
    Finds every ConfigFile.Bind(...) call in a mod's C# sources and checks its type:
      - numeric (int, float, double, ...) without AcceptableValueRange or AcceptableValueList -> ERROR
      - a default value that is not a literal and whose type cannot be told                    -> REVIEW (informational)
    A numeric setting that really can be any number may opt out with a comment on the same line or the line above:
        // config-range-ok: <reason>
    Exit code 1 when an ERROR is found. Used by publish-mod before a release and recommended in every plan
    ("Configuration Types Check"), see REPO_MODS_WORKSPACE.md.

.PARAMETER Path
    A mod folder, or the workspace root to audit every repository under it (folders that contain a .csproj).
    Defaults to the workspace root (the parent of RepoKit).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File RepoKit/scripts/check-config-types.ps1
    powershell -ExecutionPolicy Bypass -File RepoKit/scripts/check-config-types.ps1 -Path REPO-Pockets
#>

[CmdletBinding()]
param(
    [string]$Path = ""
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Path) { $Path = (Resolve-Path (Join-Path $scriptDir "..\..")).Path }
$Path = (Resolve-Path $Path).Path

$numericTypes = @('int', 'long', 'short', 'byte', 'sbyte', 'uint', 'ulong', 'ushort', 'float', 'double', 'decimal',
    'Int16', 'Int32', 'Int64', 'UInt16', 'UInt32', 'UInt64', 'Single', 'Double', 'Decimal', 'Byte')

# A repository is a folder that contains a .csproj directly.
$repos = @()
if (Get-ChildItem -Path $Path -Filter *.csproj -File -ErrorAction SilentlyContinue) {
    $repos = @(Get-Item $Path)
} else {
    $repos = Get-ChildItem -Path $Path -Directory | Where-Object {
        Get-ChildItem -Path $_.FullName -Filter *.csproj -File -ErrorAction SilentlyContinue
    }
}

function Get-TopLevelArguments([string]$text) {
    $arguments = New-Object System.Collections.Generic.List[string]
    $depth = 0; $inString = $false; $verbatim = $false; $start = 0
    for ($i = 0; $i -lt $text.Length; $i++) {
        $c = $text[$i]
        if ($inString) {
            if ($c -eq '"') {
                if ($verbatim -and $i + 1 -lt $text.Length -and $text[$i + 1] -eq '"') { $i++ } else { $inString = $false }
            } elseif ($c -eq '\' -and -not $verbatim) { $i++ }
            continue
        }
        switch ($c) {
            '"' { $inString = $true; $verbatim = ($i -gt 0 -and $text[$i - 1] -eq '@') }
            '(' { $depth++ }
            '[' { $depth++ }
            '{' { $depth++ }
            ')' { $depth-- }
            ']' { $depth-- }
            '}' { $depth-- }
            ',' { if ($depth -eq 0) { $arguments.Add($text.Substring($start, $i - $start).Trim()); $start = $i + 1 } }
        }
    }
    $arguments.Add($text.Substring($start).Trim())
    return $arguments
}

function Get-CallBody([string]$text, [int]$openIndex) {
    $depth = 0; $inString = $false; $verbatim = $false
    for ($i = $openIndex; $i -lt $text.Length; $i++) {
        $c = $text[$i]
        if ($inString) {
            if ($c -eq '"') {
                if ($verbatim -and $i + 1 -lt $text.Length -and $text[$i + 1] -eq '"') { $i++ } else { $inString = $false }
            } elseif ($c -eq '\' -and -not $verbatim) { $i++ }
            continue
        }
        if ($c -eq '"') { $inString = $true; $verbatim = ($i -gt 0 -and $text[$i - 1] -eq '@'); continue }
        if ($c -eq '(') { $depth++ }
        elseif ($c -eq ')') { $depth--; if ($depth -eq 0) { return $text.Substring($openIndex + 1, $i - $openIndex - 1) } }
    }
    return $null
}

$errors = 0; $reviews = 0; $checked = 0
foreach ($repo in $repos) {
    $files = Get-ChildItem -Path $repo.FullName -Filter *.cs -Recurse -File | Where-Object {
        $relative = $_.FullName.Substring($repo.FullName.Length).TrimStart('\', '/')
        $first = ($relative -split '[\\/]')[0]
        -not (@('obj', 'bin', 'external', '.git') -contains $first) -and -not ($first -like '*.Tests')
    }
    foreach ($file in $files) {
        $text = [System.IO.File]::ReadAllText($file.FullName)
        $lines = $text -split "`r?`n"
        foreach ($m in [regex]::Matches($text, '\.Bind\s*(<\s*(?<t>[\w\.]+)\s*>)?\s*\(')) {
            $openIndex = $m.Index + $m.Length - 1
            $body = Get-CallBody $text $openIndex
            if ($null -eq $body) { continue }
            $arguments = Get-TopLevelArguments $body
            if ($arguments.Count -lt 3) { continue }   # not ConfigFile.Bind(section, key, default, ...)
            $checked++
            $lineNumber = ($text.Substring(0, $m.Index) -split "`n").Count
            $key = $arguments[1]
            $default = $arguments[2]
            $type = $m.Groups['t'].Value
            if (-not $type) {
                if ($default -match '^-?\d+$') { $type = 'int' }
                elseif ($default -match '^-?(\d+\.\d*|\.\d+)f?$|^-?\d+f$') { $type = 'float' }
                elseif ($default -match '^(true|false)$') { $type = 'bool' }
                elseif ($default -match '^@?"') { $type = 'string' }
                elseif ($default -match '^(?<id>[A-Za-z_]\w*)\s*(\[.*\])?$') {
                    # A variable or parameter: look for its declaration in the same file.
                    $id = [regex]::Escape($Matches['id'])
                    $declaration = [regex]::Match($text, '\b(?<ty>int|long|short|byte|uint|float|double|decimal|bool|string)\s*(\[\])?\s+' + $id + '\b')
                    if ($declaration.Success) { $type = $declaration.Groups['ty'].Value }
                }
            }
            # A range is declared either inline or through a ConfigDescription built with a second argument (a variable
            # holding the AcceptableValueRange).
            $hasRange = $body -match 'AcceptableValueRange|AcceptableValueList'
            if (-not $hasRange -and $arguments.Count -ge 4 -and $arguments[3] -match '^new\s+ConfigDescription\s*\(') {
                $descriptionBody = Get-CallBody $arguments[3] ($arguments[3].IndexOf('('))
                if ($descriptionBody -and (Get-TopLevelArguments $descriptionBody).Count -ge 2) { $hasRange = $true }
            }
            $optOut = ($lineNumber -ge 1 -and $lines[$lineNumber - 1] -match 'config-range-ok:') -or ($lineNumber -ge 2 -and $lines[$lineNumber - 2] -match 'config-range-ok:')
            $relativeFile = $file.FullName.Substring($Path.Length).TrimStart('\', '/')
            # A range that starts below zero for a setting that is naturally never negative (time, percent, chance, count, ...).
            if ($hasRange -and $body -match 'AcceptableValueRange\s*<[^>]+>\s*\(\s*-\s*[\d.]' -and
                "$key $body" -match '(?i)second|seconds|cooldown|delay|duration|timer|percent|chance|probability|weight|count|amount|max|radius|distance|range|multiplier|interval') {
                Write-Host "review ${relativeFile}:$lineNumber  $key  range starts below zero; confirm negative values make sense" -ForegroundColor Yellow
                $reviews++
            }
            if ($type -and ($numericTypes -contains $type)) {
                if (-not $hasRange -and -not $optOut) {
                    Write-Host "ERROR  ${relativeFile}:$lineNumber  numeric setting $key ($type) has no AcceptableValueRange" -ForegroundColor Red
                    $errors++
                }
            } elseif (-not $type -and -not $hasRange -and -not $optOut) {
                Write-Host "review ${relativeFile}:$lineNumber  $key  type not evident from '$default'; confirm it is not numeric" -ForegroundColor Yellow
                $reviews++
            }
        }
    }
}

Write-Host ""
Write-Host "Config types check: $checked entries, $errors error(s), $reviews to review." -ForegroundColor $(if ($errors) { 'Red' } else { 'Green' })
if ($errors -gt 0) { exit 1 }
