<#
.SYNOPSIS
    Builds one or more mods here and installs them into the device's r2modman profile, then verifies by hash.

.PARAMETER Name           Registered device name.
.PARAMETER ModPath        One or more mod repository folders (each with its .csproj). Defaults to the current folder.
.PARAMETER Configuration  Release (default) or Debug.
.PARAMETER NoBuild        Use the DLL that is already built.
.PARAMETER ConfigFile     Optional .cfg file(s) to place in the profile's BepInEx\config (an existing one is backed up first).
.PARAMETER Force          Deploy even if the game is running on the device (the new code only loads after a restart).

.NOTES
    Never publishes anything and never touches Thunderstore. It only writes into the device's r2modman profile.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Name,
    [string[]]$ModPath = @('.'),
    [ValidateSet('Release', 'Debug')][string]$Configuration = 'Release',
    [switch]$NoBuild,
    [string[]]$ConfigFile = @(),
    [switch]$Force
)

. (Join-Path $PSScriptRoot 'DeviceCommon.ps1')

$device = Get-DeviceByName $Name
$connection = Test-DeviceConnection $device
if (-not $connection.Ok) { throw "Cannot reach '$Name': $($connection.Message)" }

# 1. Find, build and collect the DLLs
$files = @()
foreach ($path in $ModPath) {
    $resolved = (Resolve-Path $path).Path
    $csproj = Get-ChildItem -Path $resolved -Filter '*.csproj' -File | Select-Object -First 1
    if ($null -eq $csproj) { throw "No .csproj found in $resolved" }

    [xml]$project = Get-Content -Raw $csproj.FullName
    $assemblyName = $null
    foreach ($group in @($project.Project.PropertyGroup)) {
        if ($group.PSObject.Properties.Name -contains 'AssemblyName' -and $group.AssemblyName) { $assemblyName = [string]$group.AssemblyName; break }
    }
    if (-not $assemblyName) { $assemblyName = [IO.Path]::GetFileNameWithoutExtension($csproj.Name) }

    if (-not $NoBuild) {
        Write-Host "Building $assemblyName ($Configuration)..." -ForegroundColor Cyan
        $build = Invoke-Native 'dotnet' @('build', $csproj.FullName, '-c', $Configuration)
        if ($build.ExitCode -ne 0) { throw ("Build of {0} failed:`n{1}" -f $assemblyName, (($build.Output | Select-Object -Last 15) -join "`n")) }
    }

    $dll = Join-Path $resolved ("bin\{0}\net48\{1}.dll" -f $Configuration, $assemblyName)
    if (-not (Test-Path $dll)) { throw "Built DLL not found: $dll" }
    $files += [pscustomobject]@{ Path = $dll; Name = "$assemblyName.dll"; Kind = 'plugin' }
}
foreach ($cfg in $ConfigFile) {
    if (-not (Test-Path $cfg)) { throw "Config file not found: $cfg" }
    $files += [pscustomobject]@{ Path = (Resolve-Path $cfg).Path; Name = (Split-Path -Leaf $cfg); Kind = 'config' }
}

# 2. Upload the files and a manifest with their hashes
$manifest = @()
foreach ($file in $files) {
    $sha = Get-FileSha256 $file.Path
    $manifest += [pscustomobject]@{ name = $file.Name; kind = $file.Kind; sha256 = $sha }
    Send-DeviceFile $device $file.Path
}
$manifestPath = Join-Path ([IO.Path]::GetTempPath()) 'deploy-manifest.json'
[IO.File]::WriteAllText($manifestPath, (ConvertTo-Json -InputObject @($manifest)), (New-Object Text.UTF8Encoding($false)))
Send-DeviceFile $device $manifestPath

# 3. Install on the device and verify
$status = Invoke-DeviceScript $device 'device-status.ps1' @{ ProfileName = $device.ProfileName }
if ($status.gameRunning -and -not $Force) {
    throw "The game is running on '$Name'. Close it first (a running game keeps the old code in memory and may block the copy), or use -Force to copy anyway."
}

$result = Invoke-DeviceScript $device 'deploy-files.ps1' @{ ProfileName = $device.ProfileName }
if ($result.error -eq 'profile-missing') {
    throw "The r2modman profile '$($device.ProfileName)' does not exist on '$Name' ($($result.profileDir)). Run prepare-device.ps1 and follow its steps."
}

Write-Host ''
foreach ($item in $result.results) {
    $localSha = ($manifest | Where-Object { $_.name -eq $item.name }).sha256.Substring(0, 16)
    $match = ($item.sha -eq $localSha)
    $line = '{0,-28} {1,-7} {2}  {3}' -f $item.name, $item.kind, $item.status, $(if ($match) { 'hash matches' } else { 'HASH DIFFERS' })
    Write-Host $line -ForegroundColor $(if ($item.status -eq 'copied' -and $match) { 'Green' } else { 'Red' })
}
Write-Host ''
if (-not $result.ok) { throw 'Some files were not deployed correctly (see above).' }
if ($result.gameRunning) { Write-Host 'The game is running on the device: restart it so it loads the new code.' -ForegroundColor Yellow }
else { Write-Host "Deployed to '$Name' (profile '$($device.ProfileName)'). Open the game from r2modman on the device." -ForegroundColor Green }
