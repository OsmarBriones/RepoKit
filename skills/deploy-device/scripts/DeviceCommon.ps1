# Shared helpers for the deploy-device skill. Dot-source it: . "$PSScriptRoot\DeviceCommon.ps1"
#
# A "device" is another machine that has R.E.P.O. and r2modman. Devices are kept in a per-user registry file
# OUTSIDE every repository (default: <user profile>\.repo-mods\devices.json, override with REPO_MODS_DEVICE_STORE).
# Transports:
#   ssh   - the real thing: key-based OpenSSH to a Windows machine whose default shell is PowerShell.
#   local - a simulated device on this machine (a folder), used to test the scripts without a second machine.

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:StagingFolderName = 'repo-deploy'

function Get-UserHome {
    return [Environment]::GetFolderPath('UserProfile')
}

function Get-DeviceStorePath {
    if ($env:REPO_MODS_DEVICE_STORE) { return $env:REPO_MODS_DEVICE_STORE }
    return (Join-Path (Get-UserHome) '.repo-mods\devices.json')
}

function Get-AllDevices {
    $path = Get-DeviceStorePath
    if (-not (Test-Path $path)) { return @() }
    $store = Get-Content -Raw -Path $path | ConvertFrom-Json
    if ($null -eq $store -or -not ($store.PSObject.Properties.Name -contains 'devices') -or $null -eq $store.devices) { return @() }
    return @($store.devices)
}

function Save-AllDevices {
    param([object[]]$Devices)
    $path = Get-DeviceStorePath
    $dir = Split-Path -Parent $path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $json = ConvertTo-Json -Depth 6 -InputObject ([pscustomobject]@{ devices = @($Devices) })
    [System.IO.File]::WriteAllText($path, $json, (New-Object System.Text.UTF8Encoding($false)))
}

function Get-DeviceByName {
    param([Parameter(Mandatory)][string]$Name)
    $device = Get-AllDevices | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
    if ($null -eq $device) {
        throw "Device '$Name' is not registered. Register it first with register-device.ps1 (registry: $(Get-DeviceStorePath))."
    }
    return $device
}

function Get-PowerShellExe {
    if (Get-Command pwsh -ErrorAction SilentlyContinue) { return 'pwsh' }
    return 'powershell'
}

function Get-SshOptions {
    param($Device)
    return @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=10', '-o', 'StrictHostKeyChecking=accept-new')
}

function Get-DeviceTarget {
    param($Device)
    return ('{0}@{1}' -f $Device.User, $Device.HostName)
}

function Invoke-Native {
    # Runs a native command, returns its output lines and exit code without letting stderr become a PowerShell error.
    param([string]$File, [string[]]$Arguments)
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $lines = & $File @Arguments 2>&1 | ForEach-Object { "$_" }
        $code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previous
    }
    return [pscustomobject]@{ Output = @($lines); ExitCode = $code }
}

function Get-LocalDeviceEnvironment {
    # The environment a simulated (local) device runs under: its own APPDATA and user profile folders.
    param($Device)
    $root = $Device.LocalRoot
    return @{
        APPDATA     = (Join-Path $root 'AppData')
        USERPROFILE = (Join-Path $root 'home')
    }
}

function Invoke-DeviceCommand {
    # Runs a PowerShell command line (single quotes only, no double quotes) on the device and returns the output lines.
    param([Parameter(Mandatory)]$Device, [Parameter(Mandatory)][string]$Command)

    if ($Device.Transport -eq 'local') {
        $overrides = Get-LocalDeviceEnvironment $Device
        $saved = @{}
        foreach ($key in $overrides.Keys) { $saved[$key] = [Environment]::GetEnvironmentVariable($key); [Environment]::SetEnvironmentVariable($key, $overrides[$key]) }
        try {
            $result = Invoke-Native (Get-PowerShellExe) @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', $Command)
        }
        finally {
            foreach ($key in $saved.Keys) { [Environment]::SetEnvironmentVariable($key, $saved[$key]) }
        }
    }
    else {
        $arguments = @(Get-SshOptions $Device) + @('-p', [string]$Device.Port, (Get-DeviceTarget $Device), $Command)
        $result = Invoke-Native 'ssh' $arguments
    }

    if ($result.ExitCode -ne 0) {
        throw ("Command on device '{0}' failed (exit {1}):`n{2}" -f $Device.Name, $result.ExitCode, ($result.Output -join "`n"))
    }
    return $result.Output
}

function Send-DeviceFile {
    # Copies a local file into the device's staging folder (home\repo-deploy).
    param([Parameter(Mandatory)]$Device, [Parameter(Mandatory)][string]$LocalPath)

    if ($Device.Transport -eq 'local') {
        $staging = Join-Path (Join-Path $Device.LocalRoot 'home') $script:StagingFolderName
        if (-not (Test-Path $staging)) { New-Item -ItemType Directory -Path $staging -Force | Out-Null }
        Copy-Item -Path $LocalPath -Destination $staging -Force
        return
    }

    # Make sure the staging folder exists, then copy (scp paths without a drive letter are relative to the remote home).
    Invoke-DeviceCommand $Device ("New-Item -ItemType Directory -Force -Path (Join-Path `$env:USERPROFILE '{0}') | Out-Null" -f $script:StagingFolderName) | Out-Null
    $arguments = @('-q', '-P', [string]$Device.Port) + @(Get-SshOptions $Device) + @($LocalPath, ('{0}:{1}/' -f (Get-DeviceTarget $Device), $script:StagingFolderName))
    $result = Invoke-Native 'scp' $arguments
    if ($result.ExitCode -ne 0) { throw ("scp to '{0}' failed:`n{1}" -f $Device.Name, ($result.Output -join "`n")) }
}

function Receive-DeviceFile {
    # Copies a file from the device (absolute path on the device) to a local path.
    param([Parameter(Mandatory)]$Device, [Parameter(Mandatory)][string]$RemotePath, [Parameter(Mandatory)][string]$LocalPath)

    if ($Device.Transport -eq 'local') {
        Copy-Item -Path $RemotePath -Destination $LocalPath -Force
        return
    }

    $remote = '{0}:{1}' -f (Get-DeviceTarget $Device), ($RemotePath -replace '\\', '/')
    $arguments = @('-q', '-P', [string]$Device.Port) + @(Get-SshOptions $Device) + @($remote, $LocalPath)
    $result = Invoke-Native 'scp' $arguments
    if ($result.ExitCode -ne 0) { throw ("scp from '{0}' failed:`n{1}" -f $Device.Name, ($result.Output -join "`n")) }
}

function Invoke-DeviceScript {
    # Uploads one of the scripts in scripts\remote, runs it on the device with the given parameters, and returns its JSON result.
    param([Parameter(Mandatory)]$Device, [Parameter(Mandatory)][string]$ScriptName, [hashtable]$Parameters = @{})

    $scriptPath = Join-Path (Join-Path $PSScriptRoot 'remote') $ScriptName
    if (-not (Test-Path $scriptPath)) { throw "Remote script not found: $scriptPath" }
    Send-DeviceFile $Device $scriptPath

    $parts = @()
    foreach ($key in $Parameters.Keys) {
        $value = $Parameters[$key]
        if ($value -is [bool] -or $value -is [System.Management.Automation.SwitchParameter]) {
            if ($value) { $parts += "-$key" }
        }
        else {
            $parts += ("-{0} '{1}'" -f $key, ([string]$value -replace "'", "''"))
        }
    }
    $command = "& (Join-Path `$env:USERPROFILE '{0}\{1}') {2}" -f $script:StagingFolderName, $ScriptName, ($parts -join ' ')
    $output = Invoke-DeviceCommand $Device $command

    $text = ($output -join "`n").Trim()
    $start = $text.IndexOf('{')
    if ($start -lt 0) { throw "The device returned no result from ${ScriptName}:`n$text" }
    return ($text.Substring($start) | ConvertFrom-Json)
}

function Test-DeviceConnection {
    param([Parameter(Mandatory)]$Device)
    try {
        $out = Invoke-DeviceCommand $Device "'ok:' + `$env:COMPUTERNAME"
        return [pscustomobject]@{ Ok = $true; Message = ($out -join ' ').Trim() }
    }
    catch {
        return [pscustomobject]@{ Ok = $false; Message = $_.Exception.Message }
    }
}

function Get-FileSha256 {
    param([string]$Path)
    return (Get-FileHash -Algorithm SHA256 -Path $Path).Hash.ToLowerInvariant()
}
