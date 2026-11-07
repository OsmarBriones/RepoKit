# Runs ON the device (uploaded by the controller). Installs a set of Thunderstore mods into an r2modman profile from an
# archive prepared on the controller: their folders under BepInEx, their package cache, and their entries in mods.yml.
# Disabled mods stay disabled (their files keep the .old suffix r2modman gave them and the entry keeps enabled: false).
param(
    [string]$ProfileName = 'Debug',
    [string]$ArchiveName = 'mods-sync.zip',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$staging = Join-Path $env:USERPROFILE 'repo-deploy'
$profileDir = Join-Path $env:APPDATA ("r2modmanPlus-local\REPO\profiles\{0}" -f $ProfileName)
$cacheRoot = Join-Path $env:APPDATA 'r2modmanPlus-local\REPO\cache'

function Write-Result($object) { Write-Output (ConvertTo-Json -Compress -Depth 5 -InputObject $object) }
function Split-Blocks([string]$text) {
    return @([regex]::Split($text, '(?m)^(?=- manifestVersion)') | Where-Object { $_.Trim().Length -gt 0 })
}
function Get-BlockName([string]$block) {
    $m = [regex]::Match($block, '(?m)^  name:\s*(.+?)\s*$')
    if ($m.Success) { return $m.Groups[1].Value }
    return $null
}

if (-not (Test-Path $profileDir)) {
    Write-Result ([pscustomobject]@{ ok = $false; error = 'profile-missing'; profileDir = $profileDir })
    return
}

# r2modman rewrites mods.yml when it closes, and a running game may lock files: refuse unless forced.
$r2Running = [bool](Get-Process -Name 'r2modman' -ErrorAction SilentlyContinue)
$gameRunning = [bool](Get-Process -Name 'REPO' -ErrorAction SilentlyContinue)
if (($r2Running -or $gameRunning) -and -not $Force) {
    Write-Result ([pscustomobject]@{ ok = $false; error = 'apps-running'; r2modmanRunning = $r2Running; gameRunning = $gameRunning })
    return
}

$archive = Join-Path $staging $ArchiveName
if (-not (Test-Path $archive)) { throw "Archive not found: $archive" }

$temp = Join-Path $env:TEMP ('repo-mods-' + [guid]::NewGuid().ToString('N'))
$installed = @()
try {
    New-Item -ItemType Directory -Path $temp -Force | Out-Null
    Expand-Archive -Path $archive -DestinationPath $temp -Force

    # 1. Mod folders (plugins, patchers, monomod): replaced as a whole so the enabled/disabled state matches the source.
    $bepinex = Join-Path $temp 'BepInEx'
    if (Test-Path $bepinex) {
        foreach ($kind in Get-ChildItem -Path $bepinex -Directory) {
            $kindTarget = Join-Path (Join-Path $profileDir 'BepInEx') $kind.Name
            if (-not (Test-Path $kindTarget)) { New-Item -ItemType Directory -Path $kindTarget -Force | Out-Null }
            foreach ($modFolder in Get-ChildItem -Path $kind.FullName -Directory) {
                $destination = Join-Path $kindTarget $modFolder.Name
                if (Test-Path $destination) { Remove-Item -Path $destination -Recurse -Force }
                Copy-Item -Path $modFolder.FullName -Destination $destination -Recurse -Force
                $installed += ('{0}/{1}' -f $kind.Name, $modFolder.Name)
            }
        }
    }

    # 2. Package cache (icons and files), never overwritten.
    $cacheStage = Join-Path $temp 'cache'
    if (Test-Path $cacheStage) {
        if (-not (Test-Path $cacheRoot)) { New-Item -ItemType Directory -Path $cacheRoot -Force | Out-Null }
        foreach ($package in Get-ChildItem -Path $cacheStage -Directory) {
            foreach ($version in Get-ChildItem -Path $package.FullName -Directory) {
                $destination = Join-Path (Join-Path $cacheRoot $package.Name) $version.Name
                if (-not (Test-Path $destination)) {
                    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
                    Copy-Item -Path $version.FullName -Destination $destination -Recurse -Force
                }
            }
        }
    }

    # 3. mods.yml: keep what the device has, replace or add the incoming entries.
    $modsFile = Join-Path $profileDir 'mods.yml'
    $incomingFile = Join-Path $temp 'mods-selected.yml'
    $added = @()
    if (Test-Path $incomingFile) {
        $incoming = Split-Blocks ([IO.File]::ReadAllText($incomingFile))
        $existing = @()
        if (Test-Path $modsFile) {
            Copy-Item -Path $modsFile -Destination ($modsFile + '.bak-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) -Force
            $existing = Split-Blocks ([IO.File]::ReadAllText($modsFile))
        }
        $incomingNames = @($incoming | ForEach-Object { Get-BlockName $_ })
        $merged = @()
        foreach ($block in $existing) {
            if ($incomingNames -notcontains (Get-BlockName $block)) { $merged += $block }
        }
        foreach ($block in $incoming) { $merged += $block; $added += (Get-BlockName $block) }
        $text = (($merged | ForEach-Object { $_.TrimEnd("`r", "`n") }) -join "`n") + "`n"
        [IO.File]::WriteAllText($modsFile, $text, (New-Object Text.UTF8Encoding($false)))
    }
}
finally {
    if (Test-Path $temp) { Remove-Item -Path $temp -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Result ([pscustomobject]@{ ok = $true; error = $null; folders = $installed; mods = $added; r2modmanRunning = $r2Running; gameRunning = $gameRunning })
