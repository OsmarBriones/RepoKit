<#
.SYNOPSIS
    Runs ONCE ON THE DEVICE, as administrator. Lets the controller machine connect with an SSH key so mods can be deployed.

.DESCRIPTION
    What it does:
      - installs and starts the Windows OpenSSH server;
      - turns password logins OFF (key logins only);
      - authorizes the given PUBLIC key;
      - opens port 22 only for the Private network profile and only from the local subnet;
      - makes PowerShell the default SSH shell;
      - creates the staging folder used by the deploy scripts.
    -Remove undoes it: stops and disables the server, deletes the firewall rule and removes the authorized key.
    Read the script before running it.

.PARAMETER PublicKey  The controller's public key line (from register-device.ps1).
.PARAMETER Remove     Undo the setup.
#>
[CmdletBinding()]
param(
    [string]$PublicKey = '',
    [switch]$Remove
)

$ErrorActionPreference = 'Stop'

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script from an elevated (administrator) PowerShell.'
}

$ruleName = 'REPO-Mods-SSH'
$sshdConfig = Join-Path $env:ProgramData 'ssh\sshd_config'
$adminKeys = Join-Path $env:ProgramData 'ssh\administrators_authorized_keys'
$userKeys = Join-Path $env:USERPROFILE '.ssh\authorized_keys'

function Get-KeyBody([string]$line) {
    $parts = $line.Trim() -split '\s+'
    if ($parts.Count -ge 2) { return $parts[1] }
    return $line.Trim()
}

if ($Remove) {
    if (Get-Service sshd -ErrorAction SilentlyContinue) {
        Stop-Service sshd -ErrorAction SilentlyContinue
        Set-Service sshd -StartupType Disabled
    }
    Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
    foreach ($file in $adminKeys, $userKeys) {
        if (Test-Path $file) {
            $kept = Get-Content $file | Where-Object { $_ -notmatch 'repo-mods-controller' }
            Set-Content -Path $file -Value $kept -Encoding ascii
        }
    }
    Write-Host 'Removed: SSH server stopped and disabled, firewall rule deleted, controller key removed.' -ForegroundColor Green
    return
}

if ([string]::IsNullOrWhiteSpace($PublicKey) -or $PublicKey -notmatch '^(ssh-ed25519|ssh-rsa|ecdsa-sha2-\S+)\s+\S+') {
    throw 'Pass the controller public key with -PublicKey (a line starting with ssh-ed25519 ...).'
}

# 1. OpenSSH server
$capability = Get-WindowsCapability -Online | Where-Object { $_.Name -like 'OpenSSH.Server*' } | Select-Object -First 1
if ($capability -and $capability.State -ne 'Installed') {
    Write-Host 'Installing the OpenSSH server (Windows feature)...'
    Add-WindowsCapability -Online -Name $capability.Name | Out-Null
}
if (-not (Get-Service sshd -ErrorAction SilentlyContinue)) { throw 'The OpenSSH server could not be installed.' }

# 2. Key logins only
if (Test-Path $sshdConfig) {
    $config = Get-Content $sshdConfig
    if ($config -match '^\s*#?\s*PasswordAuthentication') {
        $config = $config -replace '^\s*#?\s*PasswordAuthentication.*$', 'PasswordAuthentication no'
    }
    else {
        $config += 'PasswordAuthentication no'
    }
    Set-Content -Path $sshdConfig -Value $config -Encoding ascii
}

# 3. Authorize the key (administrators use a shared file with strict permissions)
$keyLine = ($PublicKey.Trim() + ' repo-mods-controller')
$existing = @()
if (Test-Path $adminKeys) { $existing = @(Get-Content $adminKeys) }
$body = Get-KeyBody $PublicKey
if (-not ($existing | Where-Object { $_ -like "*$body*" })) { $existing += $keyLine }
Set-Content -Path $adminKeys -Value $existing -Encoding ascii
& icacls.exe $adminKeys /inheritance:r /grant 'Administrators:F' /grant 'SYSTEM:F' | Out-Null
# Also authorize it for the signed-in account's own folder, for accounts that are not in the Administrators group.
$userSsh = Join-Path $env:USERPROFILE '.ssh'
if (-not (Test-Path $userSsh)) { New-Item -ItemType Directory -Path $userSsh -Force | Out-Null }
$userExisting = @()
if (Test-Path $userKeys) { $userExisting = @(Get-Content $userKeys) }
if (-not ($userExisting | Where-Object { $_ -like "*$(Get-KeyBody $PublicKey)*" })) { $userExisting += $keyLine }
Set-Content -Path $userKeys -Value $userExisting -Encoding ascii

# 4. PowerShell as the default SSH shell
New-Item -Path 'HKLM:\SOFTWARE\OpenSSH' -Force | Out-Null
New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell -Value (Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe') -PropertyType String -Force | Out-Null

# 5. Firewall: Private profile and local subnet only
Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue | Disable-NetFirewallRule
Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
New-NetFirewallRule -Name $ruleName -DisplayName 'REPO Mods SSH (local network only)' -Direction Inbound -Protocol TCP -LocalPort 22 `
    -Action Allow -Profile Private -RemoteAddress LocalSubnet | Out-Null

# 6. Start the server and make it start with Windows
Set-Service sshd -StartupType Automatic
Restart-Service sshd

# 7. Staging folder
$staging = Join-Path $env:USERPROFILE 'repo-deploy'
if (-not (Test-Path $staging)) { New-Item -ItemType Directory -Path $staging -Force | Out-Null }

$addresses = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } | ForEach-Object { $_.IPAddress })
Write-Host ''
Write-Host 'Done. Use these values on the controller (register-device.ps1):' -ForegroundColor Green
Write-Host ("  -HostName  {0}  (or one of: {1})" -f $env:COMPUTERNAME, ($addresses -join ', '))
Write-Host ("  -User      {0}" -f $env:USERNAME)
$nonPrivate = Get-NetConnectionProfile -ErrorAction SilentlyContinue | Where-Object { $_.NetworkCategory -ne 'Private' }
if ($nonPrivate) {
    Write-Host ''
    Write-Host 'Note: some network connections are not marked Private, and the firewall rule only applies to Private networks.' -ForegroundColor Yellow
    Write-Host 'If the controller cannot connect, set this network to Private in Windows settings.' -ForegroundColor Yellow
}
