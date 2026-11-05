<#
.SYNOPSIS
    Checks a registered device and gets it ready: game, r2modman (installed if missing) and the r2modman profile.

.PARAMETER Name              Registered device name.
.PARAMETER InstallR2Modman   Install r2modman on the device when it is missing (winget, official package).
.PARAMETER AllowDownload     With -InstallR2Modman, also allow the official GitHub installer when winget is not available.

.NOTES
    Read-only unless -InstallR2Modman is given. The game itself is installed through Steam on the device; that part is yours.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Name,
    [switch]$InstallR2Modman,
    [switch]$AllowDownload
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
    $pending += ("Open r2modman once on the device, choose R.E.P.O., and create a profile named '{0}'. r2modman installs BepInEx into it by itself." -f $status.profileName)
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
