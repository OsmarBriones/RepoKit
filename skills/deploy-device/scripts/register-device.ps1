<#
.SYNOPSIS
    Registers (or updates) a test device in the per-user registry.

.DESCRIPTION
    The registry lives outside every repository (default <user profile>\.repo-mods\devices.json). Nothing secret is stored:
    the connection uses your existing SSH key, and the device only needs your PUBLIC key.

    Easiest way, one command on the device and one paste here:
      1. register-device.ps1 -PrintBootstrap          -> prints ONE command to run on the device, as administrator
      2. that command ends with a line "REPO-DEVICE-CODE:..." -> register-device.ps1 -Code "REPO-DEVICE-CODE:..." -Name laptop -Prepare

.PARAMETER Name            Short name you will use later (for example "laptop"). With -Code it defaults to the device's computer name.
.PARAMETER Code            The line printed by setup-device.ps1 on the device. Fills in host, user and addresses by itself.
.PARAMETER HostName        Device network name or IP on the local network (not needed with -Code).
.PARAMETER User            Windows account on the device that owns the game and r2modman (not needed with -Code).
.PARAMETER Port            SSH port (default 22).
.PARAMETER ProfileName     r2modman profile to deploy into (default Debug).
.PARAMETER Transport       ssh (default) or local (a simulated device in a folder, for testing the scripts).
.PARAMETER LocalRoot       Folder for the simulated device (transport local only).
.PARAMETER PrintBootstrap  Print the single command to run on a new device and exit.
.PARAMETER Prepare         After registering, run prepare-device.ps1 -InstallR2Modman -SeedProfile.
.PARAMETER SkipTest        Do not try to connect after registering.
#>
[CmdletBinding()]
param(
    [string]$Name = '',
    [string]$Code = '',
    [string]$HostName = '',
    [string]$User = '',
    [int]$Port = 22,
    [string]$ProfileName = 'Debug',
    [ValidateSet('ssh', 'local')][string]$Transport = 'ssh',
    [string]$LocalRoot = '',
    [switch]$PrintBootstrap,
    [switch]$Prepare,
    [switch]$SkipTest
)

. (Join-Path $PSScriptRoot 'DeviceCommon.ps1')

$setupUrl = 'https://raw.githubusercontent.com/OsmarBriones/RepoKit/master/skills/deploy-device/scripts/setup-device.ps1'

function Get-ControllerPublicKey {
    $path = Join-Path (Join-Path (Get-UserHome) '.ssh') 'id_ed25519.pub'
    if (-not (Test-Path $path)) {
        throw "No SSH key found at $path. Create one first with:  ssh-keygen -t ed25519"
    }
    return (Get-Content -Raw $path).Trim()
}

if ($PrintBootstrap) {
    $publicKey = Get-ControllerPublicKey
    Write-Host 'Run this ONCE on the new device, in an administrator PowerShell (it installs the SSH server for key logins, r2modman if missing, and prints a code):' -ForegroundColor Cyan
    Write-Host ''
    Write-Host ("powershell -NoProfile -ExecutionPolicy Bypass -Command `"iwr '{0}' -OutFile `$env:TEMP\setup-device.ps1; & `$env:TEMP\setup-device.ps1 -PublicKey '{1}' -InstallR2Modman`"" -f $setupUrl, $publicKey)
    Write-Host ''
    Write-Host 'To read the script before running it, download it first and open it:' -ForegroundColor DarkGray
    Write-Host ("  iwr '{0}' -OutFile `"`$env:TEMP\setup-device.ps1`"" -f $setupUrl) -ForegroundColor DarkGray
    Write-Host 'Then copy the line starting with REPO-DEVICE-CODE: and register it here with  -Code "<that line>".'
    return
}

if ($Code) {
    $payload = $Code.Trim()
    if ($payload -like 'REPO-DEVICE-CODE:*') { $payload = $payload.Substring('REPO-DEVICE-CODE:'.Length) }
    try {
        $info = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json
    }
    catch {
        throw 'The code is not valid. Paste the whole line that starts with REPO-DEVICE-CODE:'
    }
    if (-not $Name) { $Name = ([string]$info.name).ToLowerInvariant() }
    if (-not $User) { $User = [string]$info.user }
    if ($info.port) { $Port = [int]$info.port }
    # Prefer an IP address (works without name resolution); keep the computer name as a fallback.
    $addresses = @($info.addresses | ForEach-Object { [string]$_ })
    $candidates = @($addresses) + @([string]$info.name)
    $HostName = $candidates[0]
    $alternates = @($candidates | Select-Object -Skip 1)
}
else {
    $alternates = @()
}

if ([string]::IsNullOrWhiteSpace($Name)) { throw 'Give the device a -Name (or use -Code).' }
if ($Transport -eq 'ssh' -and ([string]::IsNullOrWhiteSpace($HostName) -or [string]::IsNullOrWhiteSpace($User))) {
    throw 'An ssh device needs -HostName and -User (or -Code).'
}
if ($Transport -eq 'local' -and [string]::IsNullOrWhiteSpace($LocalRoot)) {
    throw 'A local (simulated) device needs -LocalRoot.'
}

$device = [pscustomobject]@{
    Name        = $Name
    Transport   = $Transport
    HostName    = $HostName
    Alternates  = @($alternates)
    User        = $User
    Port        = $Port
    ProfileName = $ProfileName
    LocalRoot   = $LocalRoot
}

$others = @(Get-AllDevices | Where-Object { $_.Name -ne $Name })
Save-AllDevices (@($others) + @($device))
Write-Host "Registered device '$Name' in $(Get-DeviceStorePath)" -ForegroundColor Green

if ($Transport -eq 'ssh' -and -not $Code) {
    Write-Host ''
    Write-Host 'The device must run the one-time setup first. Print the command with:  register-device.ps1 -PrintBootstrap' -ForegroundColor Yellow
}

if ($Transport -eq 'ssh' -and -not $SkipTest) {
    Write-Host "Testing the connection to $(Get-DeviceTarget $device) ..."
    $test = Test-DeviceConnection $device
    if ($test.Ok) { Write-Host "Connected: $($test.Message)" -ForegroundColor Green }
    else {
        Write-Host "Not reachable yet: $($test.Message)" -ForegroundColor Yellow
        if ($Prepare) { throw 'Cannot continue with -Prepare until the device is reachable.' }
    }
}

if ($Prepare) {
    & (Join-Path $PSScriptRoot 'prepare-device.ps1') -Name $Name -InstallR2Modman -SeedProfile
}
