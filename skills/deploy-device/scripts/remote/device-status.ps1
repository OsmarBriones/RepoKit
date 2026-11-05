# Runs ON the device (uploaded by the controller). Read-only: reports the game, r2modman and profile state as JSON.
param([string]$ProfileName = 'Debug')

$ErrorActionPreference = 'Stop'

function Find-GamePath {
    $roots = New-Object System.Collections.Generic.List[string]
    $steam = $null
    foreach ($key in 'HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam') {
        try {
            $props = Get-ItemProperty -Path $key -ErrorAction Stop
            if ($props.PSObject.Properties.Name -contains 'SteamPath') { $steam = $props.SteamPath }
            elseif ($props.PSObject.Properties.Name -contains 'InstallPath') { $steam = $props.InstallPath }
        }
        catch { }
        if ($steam) { break }
    }
    if ($steam) {
        $roots.Add(($steam -replace '/', '\'))
        $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
        if (Test-Path $vdf) {
            foreach ($line in Get-Content $vdf) {
                if ($line -match '"path"\s+"([^"]+)"') { $roots.Add(($Matches[1] -replace '\\\\', '\')) }
            }
        }
    }
    foreach ($root in ($roots | Select-Object -Unique)) {
        $candidate = Join-Path $root 'steamapps\common\REPO'
        if (Test-Path (Join-Path $candidate 'REPO.exe')) { return $candidate }
    }
    return $null
}

function Find-R2Modman {
    $paths = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\r2modman\r2modman.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\r2modman-desktop\r2modman.exe'),
        (Join-Path $env:ProgramFiles 'r2modman\r2modman.exe')
    )
    foreach ($path in $paths) { if ($path -and (Test-Path $path)) { return $path } }
    foreach ($hive in 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall') {
        if (-not (Test-Path $hive)) { continue }
        foreach ($entry in Get-ChildItem $hive -ErrorAction SilentlyContinue) {
            $props = Get-ItemProperty $entry.PSPath -ErrorAction SilentlyContinue
            if ($props -and ($props.PSObject.Properties.Name -contains 'DisplayName') -and $props.DisplayName -like 'r2modman*') {
                if ($props.PSObject.Properties.Name -contains 'DisplayIcon' -and $props.DisplayIcon) { return ($props.DisplayIcon -replace '"', '') }
                return $props.DisplayName
            }
        }
    }
    return $null
}

$gamePath = Find-GamePath
$r2modmanPath = Find-R2Modman
$profileRoot = Join-Path $env:APPDATA 'r2modmanPlus-local\REPO\profiles'
$profileDir = Join-Path $profileRoot $ProfileName
$pluginsDir = Join-Path $profileDir 'BepInEx\plugins'

$plugins = @()
if (Test-Path $pluginsDir) {
    foreach ($file in Get-ChildItem -Path $pluginsDir -Filter '*.dll' -File -ErrorAction SilentlyContinue) {
        $plugins += [pscustomobject]@{
            name  = $file.Name
            bytes = $file.Length
            sha   = (Get-FileHash -Algorithm SHA256 -Path $file.FullName).Hash.ToLowerInvariant().Substring(0, 16)
            time  = $file.LastWriteTime.ToString('yyyy-MM-dd HH:mm')
        }
    }
}

$result = [pscustomobject]@{
    computer       = $env:COMPUTERNAME
    user           = $env:USERNAME
    os             = [Environment]::OSVersion.VersionString
    psVersion      = $PSVersionTable.PSVersion.ToString()
    gamePath       = $gamePath
    gameInstalled  = [bool]$gamePath
    gameRunning    = [bool](Get-Process -Name 'REPO' -ErrorAction SilentlyContinue)
    r2modmanPath   = $r2modmanPath
    r2modmanReady  = [bool]$r2modmanPath
    wingetPresent  = [bool](Get-Command winget -ErrorAction SilentlyContinue)
    profileName    = $ProfileName
    profileDir     = $profileDir
    profileExists  = (Test-Path $profileDir)
    bepInExPresent = (Test-Path (Join-Path $profileDir 'BepInEx\core\BepInEx.dll'))
    pluginsDir     = $pluginsDir
    plugins        = $plugins
    logPath        = (Join-Path $profileDir 'BepInEx\LogOutput.log')
}
Write-Output (ConvertTo-Json -InputObject $result -Depth 5 -Compress)
