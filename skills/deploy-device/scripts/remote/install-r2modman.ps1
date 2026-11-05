# Runs ON the device (uploaded by the controller). Installs r2modman if it is missing, silently, and reports JSON.
# Order: winget (official package ebkr.r2modman), then, only with -AllowDownload, the official GitHub release installer.
param([switch]$AllowDownload)

$ErrorActionPreference = 'Stop'

function Test-R2Modman {
    $paths = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\r2modman\r2modman.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\r2modman-desktop\r2modman.exe'),
        (Join-Path $env:ProgramFiles 'r2modman\r2modman.exe')
    )
    foreach ($path in $paths) { if ($path -and (Test-Path $path)) { return $path } }
    return $null
}

$existing = Test-R2Modman
if ($existing) {
    Write-Output (ConvertTo-Json -Compress -InputObject ([pscustomobject]@{ installed = $true; changed = $false; method = 'already-installed'; path = $existing }))
    return
}

$method = $null
$message = ''

if (Get-Command winget -ErrorAction SilentlyContinue) {
    $method = 'winget'
    $out = & winget install --id ebkr.r2modman --exact --silent --accept-package-agreements --accept-source-agreements 2>&1 | ForEach-Object { "$_" }
    $message = ($out | Select-Object -Last 3) -join ' | '
}
elseif ($AllowDownload) {
    $method = 'github-release'
    $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/ebkr/r2modmanPlus/releases/latest' -Headers @{ 'User-Agent' = 'repo-mods-deploy' }
    $asset = $release.assets | Where-Object { $_.name -like 'r2modman-Setup-*.exe' } | Select-Object -First 1
    if (-not $asset) { throw 'No r2modman setup installer found in the latest GitHub release.' }
    $target = Join-Path $env:TEMP $asset.name
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $target -UseBasicParsing
    Start-Process -FilePath $target -ArgumentList '/S' -Wait
    $message = ('Installed {0} ({1} bytes) from {2}' -f $asset.name, (Get-Item $target).Length, $asset.browser_download_url)
}
else {
    Write-Output (ConvertTo-Json -Compress -InputObject ([pscustomobject]@{ installed = $false; changed = $false; method = 'none'; path = $null; message = 'winget is not available; run again with -AllowDownload to use the official GitHub installer.' }))
    return
}

$after = Test-R2Modman
Write-Output (ConvertTo-Json -Compress -InputObject ([pscustomobject]@{ installed = [bool]$after; changed = [bool]$after; method = $method; path = $after; message = $message }))
