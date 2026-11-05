# Runs ON the device (uploaded by the controller). Copies staged files into an r2modman profile and verifies them.
# The manifest (JSON, in the staging folder) lists: [{ name, kind ("plugin"|"config"), sha256 }].
param(
    [string]$ProfileName = 'Debug',
    [string]$ManifestName = 'deploy-manifest.json'
)

$ErrorActionPreference = 'Stop'

$staging = Join-Path $env:USERPROFILE 'repo-deploy'
$profileDir = Join-Path $env:APPDATA ("r2modmanPlus-local\REPO\profiles\{0}" -f $ProfileName)
$gameRunning = [bool](Get-Process -Name 'REPO' -ErrorAction SilentlyContinue)

if (-not (Test-Path $profileDir)) {
    Write-Output (ConvertTo-Json -Compress -InputObject ([pscustomobject]@{ ok = $false; error = 'profile-missing'; profileDir = $profileDir; gameRunning = $gameRunning; results = @() }))
    return
}

# Windows PowerShell 5.1 returns a JSON array as one object; piping it unrolls the entries.
$manifest = @(Get-Content -Raw -Path (Join-Path $staging $ManifestName) | ConvertFrom-Json | ForEach-Object { $_ })
$results = @()
$allOk = $true

foreach ($entry in $manifest) {
    $source = Join-Path $staging $entry.name
    $status = 'copied'
    $destinationSha = $null
    try {
        if (-not (Test-Path $source)) { throw 'staged file missing' }
        $sourceSha = (Get-FileHash -Algorithm SHA256 -Path $source).Hash.ToLowerInvariant()
        if ($sourceSha -ne $entry.sha256) { throw 'staged file hash differs from the manifest (corrupt upload)' }

        if ($entry.kind -eq 'config') { $destinationDir = Join-Path $profileDir 'BepInEx\config' }
        else { $destinationDir = Join-Path $profileDir 'BepInEx\plugins' }
        if (-not (Test-Path $destinationDir)) { New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null }

        $destination = Join-Path $destinationDir $entry.name
        if ($entry.kind -eq 'config' -and (Test-Path $destination)) {
            Copy-Item -Path $destination -Destination ($destination + '.bak-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) -Force
        }
        Copy-Item -Path $source -Destination $destination -Force
        $destinationSha = (Get-FileHash -Algorithm SHA256 -Path $destination).Hash.ToLowerInvariant()
        if ($destinationSha -ne $entry.sha256) { throw 'destination hash differs after copy' }
    }
    catch {
        $status = 'failed: ' + $_.Exception.Message
        $allOk = $false
    }
    $results += [pscustomobject]@{ name = $entry.name; kind = $entry.kind; status = $status; sha = $(if ($destinationSha) { $destinationSha.Substring(0, 16) } else { $null }) }
}

Write-Output (ConvertTo-Json -Compress -Depth 5 -InputObject ([pscustomobject]@{ ok = $allOk; error = $null; profileDir = $profileDir; gameRunning = $gameRunning; results = $results }))
