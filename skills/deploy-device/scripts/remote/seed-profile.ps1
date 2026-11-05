# Runs ON the device (uploaded by the controller). Creates the BepInEx files of an r2modman profile from an archive
# prepared on the controller, only when the profile has no BepInEx yet. Never overwrites an existing mods.yml.
param(
    [string]$ProfileName = 'Debug',
    [string]$ArchiveName = 'profile-seed.zip'
)

$ErrorActionPreference = 'Stop'

$staging = Join-Path $env:USERPROFILE 'repo-deploy'
$profileDir = Join-Path $env:APPDATA ("r2modmanPlus-local\REPO\profiles\{0}" -f $ProfileName)
$core = Join-Path $profileDir 'BepInEx\core\BepInEx.dll'

if (Test-Path $core) {
    Write-Output (ConvertTo-Json -Compress -InputObject ([pscustomobject]@{ ok = $true; changed = $false; profileDir = $profileDir; message = 'BepInEx is already in the profile.' }))
    return
}

$archive = Join-Path $staging $ArchiveName
if (-not (Test-Path $archive)) { throw "Archive not found: $archive" }

$temp = Join-Path $env:TEMP ('repo-seed-' + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $temp -Force | Out-Null
    Expand-Archive -Path $archive -DestinationPath $temp -Force
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null

    foreach ($item in Get-ChildItem -Path $temp -Force) {
        $destination = Join-Path $profileDir $item.Name
        if ($item.Name -eq 'mods.yml' -and (Test-Path $destination)) { continue }
        Copy-Item -Path $item.FullName -Destination $destination -Recurse -Force
    }
    foreach ($folder in 'BepInEx\plugins', 'BepInEx\config', 'BepInEx\patchers') {
        New-Item -ItemType Directory -Path (Join-Path $profileDir $folder) -Force | Out-Null
    }
}
finally {
    if (Test-Path $temp) { Remove-Item -Path $temp -Recurse -Force -ErrorAction SilentlyContinue }
}

$ok = Test-Path $core
Write-Output (ConvertTo-Json -Compress -InputObject ([pscustomobject]@{ ok = $ok; changed = $ok; profileDir = $profileDir; message = $(if ($ok) { 'Profile created from the controller template.' } else { 'BepInEx was not found after extracting the archive.' }) }))
