<#
.SYNOPSIS
    Re-decompiles R.E.P.O.'s Assembly-CSharp.dll with ilspycmd, diffs it against the
    previous decompilation and reports which mods patch types that changed.

.DESCRIPTION
    1. Resolves the game directory (-GameDir, $env:REPO_GAME_DIR, then the default Steam path).
    2. Decompiles Assembly-CSharp.dll into '<OutDir>.new' (project layout, like the existing output).
    3. Compares '<OutDir>.new' against the current '<OutDir>' by file hash.
    4. Scans sibling mod repositories for Harmony patch targets and reports the ones whose
       source file changed or disappeared.
    5. Unless -DiffOnly is used, keeps the old output as '<OutDir>.prev' and promotes the new one.

.PARAMETER GameDir
    R.E.P.O. installation directory. Defaults to $env:REPO_GAME_DIR, then the default Steam path.

.PARAMETER OutDir
    Decompiled output directory. Defaults to $env:REPO_DECOMPILED, then '<workspace>/repo_decompiled_code'.

.PARAMETER ModsRoot
    Folder containing the mod repositories to scan. Defaults to the parent of OutDir.

.PARAMETER DiffOnly
    Decompile and report, but leave OutDir untouched (the '.new' folder is kept for inspection).

.PARAMETER ReportPath
    Optional path for a Markdown copy of the report.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File RepoKit/skills/decompile-game/scripts/decompile-game.ps1
#>

[CmdletBinding()]
param(
    [string]$GameDir,
    [string]$OutDir,
    [string]$ModsRoot,
    [switch]$DiffOnly,
    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'

# --- Resolve paths -----------------------------------------------------------------------
if (-not $GameDir) { $GameDir = $env:REPO_GAME_DIR }
if (-not $GameDir) { $GameDir = 'C:\Program Files (x86)\Steam\steamapps\common\REPO' }

if (-not $OutDir) { $OutDir = $env:REPO_DECOMPILED }
if (-not $OutDir) {
    $workspace = Resolve-Path (Join-Path $PSScriptRoot '../../../..')
    $OutDir = Join-Path $workspace 'repo_decompiled_code'
}
$OutDir = [System.IO.Path]::GetFullPath($OutDir).TrimEnd('\', '/')
if (-not $ModsRoot) { $ModsRoot = Split-Path $OutDir -Parent }

$dll = Join-Path $GameDir 'REPO_Data/Managed/Assembly-CSharp.dll'
if (-not (Test-Path $dll)) {
    Write-Warning "Assembly-CSharp.dll not found at '$dll'. Set REPO_GAME_DIR or pass -GameDir."
    exit 1
}
if (-not (Get-Command ilspycmd -ErrorAction SilentlyContinue)) {
    Write-Warning "ilspycmd not found. Install it with: dotnet tool install -g ilspycmd"
    exit 1
}

$newDir = "$OutDir.new"
$prevDir = "$OutDir.prev"

# --- Decompile ---------------------------------------------------------------------------
Write-Host "Game DLL : $dll ($((Get-Item $dll).LastWriteTime))"
Write-Host "Output   : $OutDir"
if (Test-Path $newDir) { Remove-Item $newDir -Recurse -Force }
New-Item -ItemType Directory -Path $newDir | Out-Null

Write-Host 'Decompiling (this takes a minute)...'
& ilspycmd -p -o $newDir $dll | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Warning "ilspycmd failed (exit $LASTEXITCODE)."; exit 1 }

# --- Diff --------------------------------------------------------------------------------
function Get-HashMap([string]$root) {
    $map = @{}
    if (-not (Test-Path $root)) { return $map }
    $rootLen = $root.Length + 1
    Get-ChildItem $root -Recurse -File -Filter *.cs | ForEach-Object {
        $rel = $_.FullName.Substring($rootLen).Replace('\', '/')
        # Normalize line endings so CRLF/LF differences do not show up as changes.
        $text = [System.IO.File]::ReadAllText($_.FullName) -replace "`r`n", "`n"
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
        $sha = [System.Security.Cryptography.SHA1]::Create()
        $map[$rel] = [BitConverter]::ToString($sha.ComputeHash($bytes))
    }
    return $map
}

$old = Get-HashMap $OutDir
$new = Get-HashMap $newDir

$added = @($new.Keys | Where-Object { -not $old.ContainsKey($_) } | Sort-Object)
$removed = @($old.Keys | Where-Object { -not $new.ContainsKey($_) } | Sort-Object)
$changed = @($new.Keys | Where-Object { $old.ContainsKey($_) -and $old[$_] -ne $new[$_] } | Sort-Object)

# --- Scan mods for Harmony targets ---------------------------------------------------------
$patchRegex = [regex]'HarmonyPatch\(\s*typeof\(\s*(?<type>\w+)\s*\)(?:\s*,\s*(?:nameof\(\s*\w+\.(?<m1>\w+)\s*\)|"(?<m2>\w+)"))?'
$mods = Get-ChildItem $ModsRoot -Directory | Where-Object {
    $_.FullName -ne $OutDir -and $_.Name -notlike 'repo_*' -and $_.Name -notin 'RepoKit', 'sandbox', 'useful_classes'
}

$targets = @{}   # type -> list of "Mod: Method"
foreach ($mod in $mods) {
    $files = Get-ChildItem $mod.FullName -Recurse -File -Filter *.cs -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](external|bin|obj)[\\/]' }
    foreach ($f in $files) {
        foreach ($m in $patchRegex.Matches([System.IO.File]::ReadAllText($f.FullName))) {
            $type = $m.Groups['type'].Value
            $method = if ($m.Groups['m1'].Success) { $m.Groups['m1'].Value } elseif ($m.Groups['m2'].Success) { $m.Groups['m2'].Value } else { '(see HarmonyTargetMethod)' }
            if (-not $targets.ContainsKey($type)) { $targets[$type] = New-Object System.Collections.Generic.List[string] }
            $targets[$type].Add("$($mod.Name): $method")
        }
    }
}

$affected = foreach ($type in ($targets.Keys | Sort-Object)) {
    $file = "$type.cs"
    $status = if ($removed -contains $file) { 'REMOVED' } elseif ($changed -contains $file) { 'CHANGED' } elseif ($added -contains $file) { 'ADDED' } else { $null }
    if ($status) { [pscustomobject]@{ Type = $type; Status = $status; PatchedBy = (($targets[$type] | Sort-Object -Unique) -join '; ') } }
}

# --- Report ------------------------------------------------------------------------------
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Decompilation diff - $(Get-Date -Format 'yyyy-MM-dd HH:mm')")
$lines.Add('')
$lines.Add("- Added: $($added.Count)  Removed: $($removed.Count)  Changed: $($changed.Count)  Unchanged: $($new.Count - $added.Count - $changed.Count)")
$lines.Add('')
$lines.Add('## Types patched by mods that changed')
if ($affected) { foreach ($a in $affected) { $lines.Add("- **$($a.Type)** [$($a.Status)] - $($a.PatchedBy)") } }
else { $lines.Add('- None of the patched types changed.') }
$lines.Add('')
$lines.Add("## Added ($($added.Count))")
$added | ForEach-Object { $lines.Add("- $_") }
$lines.Add('')
$lines.Add("## Removed ($($removed.Count))")
$removed | ForEach-Object { $lines.Add("- $_") }
$lines.Add('')
$lines.Add("## Changed ($($changed.Count))")
$changed | ForEach-Object { $lines.Add("- $_") }

$lines | ForEach-Object { Write-Host $_ }
if ($ReportPath) { $lines | Set-Content -Path $ReportPath -Encoding UTF8; Write-Host "`nReport saved to $ReportPath" }

# --- Promote -----------------------------------------------------------------------------
if ($DiffOnly) {
    Write-Host "`n-DiffOnly: '$OutDir' left untouched. New output kept at '$newDir'."
    exit 0
}

if (Test-Path $prevDir) { Remove-Item $prevDir -Recurse -Force }
if (Test-Path $OutDir) { Rename-Item $OutDir (Split-Path $prevDir -Leaf) }
Rename-Item $newDir (Split-Path $OutDir -Leaf)
Write-Host "`nDone. Previous version kept at '$prevDir'."
