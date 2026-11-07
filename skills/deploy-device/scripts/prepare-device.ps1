<#
.SYNOPSIS
    Checks a registered device and gets it ready: game, r2modman (installed if missing) and the r2modman profile.

.PARAMETER Name              Registered device name.
.PARAMETER InstallR2Modman   Install r2modman on the device when it is missing (winget, official package).
.PARAMETER AllowDownload     With -InstallR2Modman, also allow the official GitHub installer when winget is not available.
.PARAMETER SeedProfile       When the device's r2modman profile has no BepInEx yet, create it from this machine's own profile
                             (BepInEx core files only; none of your mods). Saves opening r2modman on the device to create it.
                             r2modman may still need to be opened once on the device to pick up the profile.
.PARAMETER SeedFrom          Name of the profile on THIS machine to copy the BepInEx files from (default Debug).

.NOTES
    Read-only unless -InstallR2Modman is given. The game itself is installed through Steam on the device; that part is yours.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Name,
    [switch]$InstallR2Modman,
    [switch]$AllowDownload,
    [switch]$SeedProfile,
    [string]$SeedFrom = 'Debug'
)

. (Join-Path $PSScriptRoot 'DeviceCommon.ps1')

$device = Get-DeviceByName $Name
$connection = Test-DeviceConnection $device
if (-not $connection.Ok) {
    throw "Cannot reach '$Name': $($connection.Message)`nCheck that the one-time setup was done on the device (see register-device.ps1 output) and that both machines are on the same network."
}

$status = Invoke-DeviceScript $device 'device-status.ps1' @{ ProfileName = $device.ProfileName }

if (-not $status.r2modmanReady -and $InstallR2Modman) {
    Write-Host 'r2modman is missing; installing it on the device...' -ForegroundColor Cyan
    $install = Invoke-DeviceScript $device 'install-r2modman.ps1' @{ AllowDownload = [bool]$AllowDownload }
    Write-Host ("  method: {0}; installed: {1}; {2}" -f $install.method, $install.installed, $install.message)
    $status = Invoke-DeviceScript $device 'device-status.ps1' @{ ProfileName = $device.ProfileName }
}

if ($SeedProfile -and $status.r2modmanReady -and -not $status.bepInExPresent) {
    $sourceProfile = Join-Path $env:APPDATA ("r2modmanPlus-local\REPO\profiles\{0}" -f $SeedFrom)
    if (-not (Test-Path (Join-Path $sourceProfile 'BepInEx\core\BepInEx.dll'))) {
        Write-Host "Cannot seed: this machine has no BepInEx in its r2modman profile '$SeedFrom'." -ForegroundColor Yellow
    }
    else {
        Write-Host "Creating the '$($device.ProfileName)' profile on the device from this machine's '$SeedFrom' profile (BepInEx core only)..." -ForegroundColor Cyan
        $work = Join-Path ([IO.Path]::GetTempPath()) ('repo-seed-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $work -Force | Out-Null
        try {
            foreach ($seedItem in '.doorstop_version', 'doorstop_config.ini', 'winhttp.dll') {
                $file = Join-Path $sourceProfile $seedItem
                if (Test-Path $file) { Copy-Item -Path $file -Destination $work -Force }
            }
            New-Item -ItemType Directory -Path (Join-Path $work 'BepInEx') -Force | Out-Null
            Copy-Item -Path (Join-Path $sourceProfile 'BepInEx\core') -Destination (Join-Path $work 'BepInEx\core') -Recurse -Force
            $patchers = Join-Path $sourceProfile 'BepInEx\patchers'
            if (Test-Path $patchers) { Copy-Item -Path $patchers -Destination (Join-Path $work 'BepInEx\patchers') -Recurse -Force }

            # mods.yml with only the first entry (BepInExPack), so r2modman knows what the profile contains.
            $modsFile = Join-Path $sourceProfile 'mods.yml'
            if (Test-Path $modsFile) {
                $kept = New-Object System.Collections.Generic.List[string]
                $entries = 0
                foreach ($line in Get-Content $modsFile) {
                    if ($line -match '^- manifestVersion') { $entries++ }
                    if ($entries -gt 1) { break }
                    if ($entries -ge 1) { $kept.Add($line) }
                }
                if ($kept.Count -gt 0) { [IO.File]::WriteAllLines((Join-Path $work 'mods.yml'), $kept, (New-Object Text.UTF8Encoding($false))) }
            }

            $archive = Join-Path ([IO.Path]::GetTempPath()) 'profile-seed.zip'
            if (Test-Path $archive) { Remove-Item $archive -Force }
            Compress-Archive -Path (Join-Path $work '*') -DestinationPath $archive -Force
            Send-DeviceFile $device $archive
            $seed = Invoke-DeviceScript $device 'seed-profile.ps1' @{ ProfileName = $device.ProfileName; ArchiveName = 'profile-seed.zip' }
            Write-Host ("  {0}" -f $seed.message)
        }
        finally {
            Remove-Item -Path $work -Recurse -Force -ErrorAction SilentlyContinue
        }
        $status = Invoke-DeviceScript $device 'device-status.ps1' @{ ProfileName = $device.ProfileName }
    }
}

if ($SeedProfile -and $status.r2modmanReady -and -not $status.bepInExCached) {
    $cacheSource = Join-Path $env:APPDATA 'r2modmanPlus-local\REPO\cache\BepInEx-BepInExPack'
    if (Test-Path $cacheSource) {
        Write-Host "Adding r2modman's BepInExPack package cache to the device (icon and files)..." -ForegroundColor Cyan
        $cacheWork = Join-Path ([IO.Path]::GetTempPath()) ('repo-cache-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $cacheWork -Force | Out-Null
        try {
            Copy-Item -Path $cacheSource -Destination (Join-Path $cacheWork 'BepInEx-BepInExPack') -Recurse -Force
            $cacheZip = Join-Path ([IO.Path]::GetTempPath()) 'cache-seed.zip'
            if (Test-Path $cacheZip) { Remove-Item $cacheZip -Force }
            Compress-Archive -Path (Join-Path $cacheWork '*') -DestinationPath $cacheZip -Force
            Send-DeviceFile $device $cacheZip
            $cacheResult = Invoke-DeviceScript $device 'seed-profile.ps1' @{ ProfileName = $device.ProfileName; ArchiveName = 'profile-seed.zip'; CacheArchiveName = 'cache-seed.zip' }
            Write-Host ("  {0}" -f $cacheResult.message)
        }
        finally {
            Remove-Item -Path $cacheWork -Recurse -Force -ErrorAction SilentlyContinue
        }
        $status = Invoke-DeviceScript $device 'device-status.ps1' @{ ProfileName = $device.ProfileName }
    }
}

function Show-Check([string]$label, [bool]$ok, [string]$detail) {
    $mark = if ($ok) { '[ok]  ' } else { '[todo]' }
    $color = if ($ok) { 'Green' } else { 'Yellow' }
    Write-Host ("{0} {1}{2}" -f $mark, $label, $(if ($detail) { ': ' + $detail } else { '' })) -ForegroundColor $color
}

Write-Host ("Device '{0}': {1} ({2}), PowerShell {3}" -f $Name, $status.computer, $status.os, $status.psVersion)
Show-Check 'R.E.P.O. installed (Steam)' $status.gameInstalled $status.gamePath
Show-Check 'r2modman installed' $status.r2modmanReady $status.r2modmanPath
Show-Check ("r2modman profile '{0}'" -f $status.profileName) $status.profileExists $status.profileDir
Show-Check 'BepInEx inside the profile' $status.bepInExPresent ''
Show-Check 'Game closed' (-not $status.gameRunning) $(if ($status.gameRunning) { 'the game is running; restart it after each deploy' } else { '' })

$pending = @()
if (-not $status.gameInstalled) { $pending += 'Install R.E.P.O. from Steam on the device.' }
if (-not $status.r2modmanReady) { $pending += 'Install r2modman (run this script again with -InstallR2Modman).' }
if ($status.r2modmanReady -and -not $status.profileExists) {
    $pending += ("Open r2modman once on the device, choose R.E.P.O., and create a profile named '{0}' (or run this script with -SeedProfile to create it from this machine). r2modman installs BepInEx into it by itself." -f $status.profileName)
}
if ($status.profileExists -and -not $status.bepInExPresent) {
    $pending += ("Open r2modman, select the '{0}' profile and let it finish installing BepInExPack." -f $status.profileName)
}

Write-Host ''
if ($pending.Count -eq 0) {
    Write-Host 'The device is ready. Deploy with deploy-device.ps1.' -ForegroundColor Green
    if ($status.plugins.Count -gt 0) {
        Write-Host 'Plugins currently in the profile:'
        $status.plugins | ForEach-Object { Write-Host ("  {0}  {1}  {2}" -f $_.name, $_.sha, $_.time) }
    }
}
else {
    Write-Host 'Still to do on the device (one time per device):' -ForegroundColor Yellow
    $pending | ForEach-Object { Write-Host "  - $_" }
}
