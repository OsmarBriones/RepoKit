<#
.SYNOPSIS
    Installs the Thunderstore mods of a profile on THIS machine into the device's r2modman profile, skipping deprecated ones
    and keeping disabled mods disabled.

.DESCRIPTION
    Meant for the general helper mods you debug with (REPOLib, config menus, admin menus...). For every mod in the source
    profile's mods.yml it copies the mod's folders (plugins, patchers, monomod), r2modman's package cache (icon) and the
    mods.yml entry. Mods already on the device are replaced by the source version. Your own dev builds (plain DLLs deployed
    with deploy-device.ps1) are not part of this; they are not in mods.yml.

    Deprecated mods are detected with the Thunderstore API and skipped. A mod that another selected mod lists as a
    dependency but that was skipped is reported, so you can decide.

.PARAMETER Name            Registered device name.
.PARAMETER SourceProfile   Profile on this machine to copy from (default Debug).
.PARAMETER ExcludeMod      Extra mods to skip, as Author-Name (for example Zichen-LateJoinNow).
.PARAMETER IncludeDeprecated  Copy deprecated mods too.
.PARAMETER Force           Continue even if r2modman or the game is running on the device.
.PARAMETER WhatIf          Only show what would be copied.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Name,
    [string]$SourceProfile = 'Debug',
    [string[]]$ExcludeMod = @(),
    [switch]$IncludeDeprecated,
    [switch]$Force,
    [switch]$WhatIf
)

. (Join-Path $PSScriptRoot 'DeviceCommon.ps1')

function Split-Blocks([string]$text) {
    return @([regex]::Split($text, '(?m)^(?=- manifestVersion)') | Where-Object { $_.Trim().Length -gt 0 })
}

$device = Get-DeviceByName $Name
$connection = Test-DeviceConnection $device
if (-not $connection.Ok) { throw "Cannot reach '$Name': $($connection.Message)" }

$sourceDir = Join-Path $env:APPDATA ("r2modmanPlus-local\REPO\profiles\{0}" -f $SourceProfile)
$modsFile = Join-Path $sourceDir 'mods.yml'
if (-not (Test-Path $modsFile)) { throw "No mods.yml in the source profile: $modsFile" }

# 1. Read the source mods
$mods = @()
foreach ($block in Split-Blocks ([IO.File]::ReadAllText($modsFile))) {
    $nameMatch = [regex]::Match($block, '(?m)^  name:\s*(.+?)\s*$')
    if (-not $nameMatch.Success) { continue }
    $versionMatch = [regex]::Match($block, '(?ms)versionNumber:\s*\r?\n\s+major:\s*(\d+)\s*\r?\n\s+minor:\s*(\d+)\s*\r?\n\s+patch:\s*(\d+)')
    $depsMatch = [regex]::Match($block, '(?m)^  dependencies:\s*\r?\n((?:    - .*\r?\n?)*)')
    $deps = @()
    if ($depsMatch.Success) { $deps = @([regex]::Matches($depsMatch.Groups[1].Value, '    - (.+)') | ForEach-Object { $_.Groups[1].Value.Trim() }) }
    $mods += [pscustomobject]@{
        Name       = $nameMatch.Groups[1].Value
        Version    = if ($versionMatch.Success) { '{0}.{1}.{2}' -f $versionMatch.Groups[1].Value, $versionMatch.Groups[2].Value, $versionMatch.Groups[3].Value } else { '' }
        Enabled    = ($block -notmatch '(?m)^  enabled:\s*false')
        Block      = $block
        DependsOn  = @($deps | ForEach-Object { ($_ -replace '-\d+\.\d+\.\d+$', '') })
        Deprecated = $false
        Skip       = ''
    }
}

# 2. Decide what to skip
foreach ($mod in $mods) {
    if ($mod.Name -eq 'BepInEx-BepInExPack') { $mod.Skip = 'already in every profile'; continue }
    if ($ExcludeMod -contains $mod.Name) { $mod.Skip = 'excluded by you'; continue }
    if (-not $IncludeDeprecated) {
        $parts = $mod.Name -split '-', 2
        try {
            $info = Invoke-RestMethod -Uri ("https://thunderstore.io/api/experimental/package/{0}/{1}/" -f $parts[0], $parts[1]) -Headers @{ 'User-Agent' = 'repo-mods-deploy' } -TimeoutSec 20
            if ($info.is_deprecated) { $mod.Deprecated = $true; $mod.Skip = 'deprecated on Thunderstore' }
        }
        catch {
            Write-Host ("Could not check deprecation of {0} (continuing without that check): {1}" -f $mod.Name, $_.Exception.Message) -ForegroundColor Yellow
        }
    }
}
$selected = @($mods | Where-Object { -not $_.Skip })
$skipped = @($mods | Where-Object { $_.Skip })

Write-Host "Source profile '$SourceProfile' -> device '$Name' (profile '$($device.ProfileName)')" -ForegroundColor Cyan
foreach ($mod in $selected) { Write-Host ("  copy   {0} {1}{2}" -f $mod.Name, $mod.Version, $(if (-not $mod.Enabled) { '  (stays disabled)' } else { '' })) -ForegroundColor Green }
foreach ($mod in $skipped) { Write-Host ("  skip   {0} {1}: {2}" -f $mod.Name, $mod.Version, $mod.Skip) -ForegroundColor DarkGray }

$skippedNames = @($skipped | ForEach-Object { $_.Name })
foreach ($mod in $selected) {
    $missing = @($mod.DependsOn | Where-Object { $skippedNames -contains $_ -and $_ -ne 'BepInEx-BepInExPack' })
    if ($missing.Count -gt 0) {
        Write-Host ("  note   {0} lists {1} as a dependency; it was skipped, so r2modman may warn about a missing dependency." -f $mod.Name, ($missing -join ', ')) -ForegroundColor Yellow
    }
}
if ($WhatIf) { return }
if ($selected.Count -eq 0) { Write-Host 'Nothing to copy.'; return }

# 3. Build the archive
$work = Join-Path ([IO.Path]::GetTempPath()) ('repo-mods-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work -Force | Out-Null
try {
    foreach ($mod in $selected) {
        foreach ($kind in 'plugins', 'patchers', 'monomod') {
            $folder = Join-Path (Join-Path $sourceDir "BepInEx\$kind") $mod.Name
            if (Test-Path $folder) {
                $target = Join-Path (Join-Path $work "BepInEx\$kind") $mod.Name
                New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
                Copy-Item -Path $folder -Destination $target -Recurse -Force
            }
        }
        $cacheFolder = Join-Path $env:APPDATA ("r2modmanPlus-local\REPO\cache\{0}\{1}" -f $mod.Name, $mod.Version)
        if (Test-Path $cacheFolder) {
            $cacheTarget = Join-Path (Join-Path $work ("cache\{0}" -f $mod.Name)) $mod.Version
            New-Item -ItemType Directory -Path (Split-Path -Parent $cacheTarget) -Force | Out-Null
            Copy-Item -Path $cacheFolder -Destination $cacheTarget -Recurse -Force
        }
    }
    $blocks = @($selected | ForEach-Object { $_.Block.TrimEnd("`r", "`n") })
    [IO.File]::WriteAllText((Join-Path $work 'mods-selected.yml'), (($blocks -join "`n") + "`n"), (New-Object Text.UTF8Encoding($false)))

    $zip = Join-Path ([IO.Path]::GetTempPath()) 'mods-sync.zip'
    if (Test-Path $zip) { Remove-Item $zip -Force }
    Compress-Archive -Path (Join-Path $work '*') -DestinationPath $zip -Force
    Write-Host ("Uploading {0:N1} MB..." -f ((Get-Item $zip).Length / 1MB))
    Send-DeviceFile $device $zip
}
finally {
    Remove-Item -Path $work -Recurse -Force -ErrorAction SilentlyContinue
}

# 4. Install on the device
$result = Invoke-DeviceScript $device 'apply-mods.ps1' @{ ProfileName = $device.ProfileName; ArchiveName = 'mods-sync.zip'; Force = [bool]$Force }
if (-not $result.ok) {
    if ($result.error -eq 'apps-running') {
        throw ("r2modman or the game is running on '{0}' (r2modman: {1}, game: {2}). Close them first, because r2modman rewrites its mod list when it closes, or use -Force." -f $Name, $result.r2modmanRunning, $result.gameRunning)
    }
    throw "The device could not apply the mods: $($result.error)"
}

# 5. Verify what the device has now
$status = Invoke-DeviceScript $device 'device-status.ps1' @{ ProfileName = $device.ProfileName }
Write-Host ''
Write-Host "Mods in the device's profile now:" -ForegroundColor Cyan
foreach ($item in @($status.installedMods)) {
    $expected = $mods | Where-Object { $_.Name -eq $item.name } | Select-Object -First 1
    $state = if ($item.enabled) { 'enabled' } else { 'disabled' }
    $note = ''
    if ($expected -and $expected.Enabled -ne $item.enabled) { $note = '  <-- state differs from the source' }
    Write-Host ("  {0,-40} {1} {2,-9} files: {3}{4}" -f $item.name, $item.version, $state, $item.files, $note)
}
Write-Host ''
Write-Host 'Done. Open r2modman on the device to see them (restart it if it was open).' -ForegroundColor Green
