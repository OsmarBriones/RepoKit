<#
.SYNOPSIS
    Registers (or updates) a test device in the per-user registry and prints what must be run once on that device.

.DESCRIPTION
    The registry lives outside every repository (default <user profile>\.repo-mods\devices.json). Nothing secret is stored:
    the connection uses your existing SSH key, and the device only needs your PUBLIC key.

.PARAMETER Name        Short name you will use later (for example "laptop").
.PARAMETER HostName    Device network name or IP on the local network.
.PARAMETER User        Windows account on the device that owns the game and r2modman.
.PARAMETER Port        SSH port (default 22).
.PARAMETER ProfileName r2modman profile to deploy into (default Debug).
.PARAMETER Transport   ssh (default) or local (a simulated device in a folder, for testing the scripts).
.PARAMETER LocalRoot   Folder for the simulated device (transport local only).
.PARAMETER SkipTest    Do not try to connect after registering.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Name,
    [string]$HostName = '',
    [string]$User = '',
    [int]$Port = 22,
    [string]$ProfileName = 'Debug',
    [ValidateSet('ssh', 'local')][string]$Transport = 'ssh',
    [string]$LocalRoot = '',
    [switch]$SkipTest
)

. (Join-Path $PSScriptRoot 'DeviceCommon.ps1')

if ($Transport -eq 'ssh' -and ([string]::IsNullOrWhiteSpace($HostName) -or [string]::IsNullOrWhiteSpace($User))) {
    throw 'An ssh device needs -HostName and -User.'
}
if ($Transport -eq 'local' -and [string]::IsNullOrWhiteSpace($LocalRoot)) {
    throw 'A local (simulated) device needs -LocalRoot.'
}

$device = [pscustomobject]@{
    Name        = $Name
    Transport   = $Transport
    HostName    = $HostName
    User        = $User
    Port        = $Port
    ProfileName = $ProfileName
    LocalRoot   = $LocalRoot
}

$others = @(Get-AllDevices | Where-Object { $_.Name -ne $Name })
Save-AllDevices (@($others) + @($device))
Write-Host "Registered device '$Name' in $(Get-DeviceStorePath)" -ForegroundColor Green

if ($Transport -eq 'ssh') {
    $publicKeyPath = Join-Path (Join-Path (Get-UserHome) '.ssh') 'id_ed25519.pub'
    if (-not (Test-Path $publicKeyPath)) {
        Write-Host "No SSH key found at $publicKeyPath. Create one first with:  ssh-keygen -t ed25519" -ForegroundColor Yellow
    }
    else {
        $publicKey = (Get-Content -Raw $publicKeyPath).Trim()
        $setupUrl = 'https://raw.githubusercontent.com/OsmarBriones/RepoKit/master/skills/deploy-device/scripts/setup-device.ps1'
        Write-Host ''
        Write-Host 'ONE-TIME STEP ON THE DEVICE (as administrator, in PowerShell):' -ForegroundColor Cyan
        Write-Host '  1. Download and read the script (it enables the OpenSSH server for key logins on the local network only):'
        Write-Host "       iwr '$setupUrl' -OutFile `"`$env:TEMP\setup-device.ps1`""
        Write-Host '  2. Run it with your public key:'
        Write-Host "       powershell -ExecutionPolicy Bypass -File `"`$env:TEMP\setup-device.ps1`" -PublicKey '$publicKey'"
        Write-Host '  To undo it later: the same script with -Remove.'
    }

    if (-not $SkipTest) {
        Write-Host ''
        Write-Host "Testing the connection to $(Get-DeviceTarget $device) ..."
        $test = Test-DeviceConnection $device
        if ($test.Ok) { Write-Host "Connected: $($test.Message)" -ForegroundColor Green }
        else { Write-Host "Not reachable yet (expected until the step above is done): $($test.Message)" -ForegroundColor Yellow }
    }
}
