<#
.SYNOPSIS
    Packages a R.E.P.O. mod into a Thunderstore-compliant release zip archive.

.DESCRIPTION
    Validates manifest.json, icon.png (256x256), README.md, CHANGELOG.md, and compiled .dll,
    then packages them into a clean zip archive under the dist/ directory.

.PARAMETER ModPath
    Path to the mod repository root. Defaults to current directory.

.PARAMETER Configuration
    Build configuration to package (Release or Debug). Defaults to Release.

.PARAMETER SkipBuild
    Skip running dotnet build before packaging.

.PARAMETER OutputDir
    Directory where the zip archive will be written. Defaults to <ModPath>/dist.
#>

[CmdletBinding()]
param(
    [string]$ModPath = ".",
    [ValidateSet("Release", "Debug")]
    [string]$Configuration = "Release",
    [switch]$SkipBuild,
    [string]$OutputDir = ""
)

$ErrorActionPreference = "Stop"

$resolvedPath = (Resolve-Path $ModPath).Path
Write-Host "==> Packaging R.E.P.O. mod at: $resolvedPath" -ForegroundColor Cyan

# 1. Locate .csproj
$csprojFiles = Get-ChildItem -Path $resolvedPath -Filter "*.csproj" -File
if ($csprojFiles.Count -eq 0) {
    throw "No .csproj file found in $resolvedPath"
}
$csproj = $csprojFiles[0]
[xml]$projXml = Get-Content $csproj.FullName

$assemblyName = $projXml.Project.PropertyGroup.AssemblyName | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1
if (-not $assemblyName) {
    $assemblyName = [System.IO.Path]::GetFileNameWithoutExtension($csproj.Name)
}

$projVersion = $projXml.Project.PropertyGroup.Version | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1
if (-not $projVersion) {
    $projVersion = "1.0.0"
}

Write-Host "    Project: $assemblyName (Version: $projVersion)" -ForegroundColor Gray

# 2. Build if requested
if (-not $SkipBuild) {
    Write-Host "==> Building mod in $Configuration mode..." -ForegroundColor Cyan
    $buildOutput = & dotnet build $csproj.FullName -c $Configuration 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host $buildOutput
        throw "Build failed with exit code $LASTEXITCODE"
    }
    Write-Host "    Build succeeded." -ForegroundColor Green
}

# 3. Locate compiled DLL
$dllCandidate = Join-Path $resolvedPath "bin\$Configuration\net48\$assemblyName.dll"
if (-not (Test-Path $dllCandidate)) {
    # Fallback to Debug if Release was requested but not found
    $debugCandidate = Join-Path $resolvedPath "bin\Debug\net48\$assemblyName.dll"
    if (Test-Path $debugCandidate) {
        Write-Warning "DLL not found in $Configuration; falling back to Debug: $debugCandidate"
        $dllCandidate = $debugCandidate
    } else {
        throw "Could not locate compiled assembly: $dllCandidate"
    }
}
Write-Host "    Assembly located: $dllCandidate" -ForegroundColor Gray

# 4. Validate manifest.json
$manifestPath = Join-Path $resolvedPath "manifest.json"
if (-not (Test-Path $manifestPath)) {
    throw "Missing required file: manifest.json"
}

$manifestContent = Get-Content $manifestPath -Raw | ConvertFrom-Json
if (-not $manifestContent.name -or $manifestContent.name -notmatch '^[a-zA-Z0-9_]+$') {
    throw "manifest.json 'name' field must contain only alphanumeric characters and underscores: '$($manifestContent.name)'"
}

if (-not $manifestContent.version_number -or $manifestContent.version_number -notmatch '^\d+\.\d+\.\d+$') {
    throw "manifest.json 'version_number' must be valid SemVer (e.g. 1.0.0): '$($manifestContent.version_number)'"
}

if ($manifestContent.description.Length -gt 250) {
    throw "manifest.json 'description' exceeds 250 characters (current: $($manifestContent.description.Length))"
}

if ($null -eq $manifestContent.dependencies) {
    throw "manifest.json missing required 'dependencies' array."
}

Write-Host "    manifest.json validated successfully." -ForegroundColor Green

# 5. Validate icon.png
$iconPath = Join-Path $resolvedPath "icon.png"
if (-not (Test-Path $iconPath)) {
    throw "Missing required file: icon.png"
}

$iconItem = Get-Item $iconPath
if ($iconItem.Length -gt 256KB) {
    Write-Warning "icon.png exceeds recommended size limit of 256 KB (size: $($iconItem.Length / 1KB) KB)"
}

Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Image]::FromFile($iconPath)
$width = $img.Width
$height = $img.Height
$img.Dispose()

if ($width -ne 256 -or $height -ne 256) {
    throw "icon.png MUST be exactly 256x256 pixels. Found: ${width}x${height}."
}
Write-Host "    icon.png dimensions verified (256x256)." -ForegroundColor Green

# 6. Validate README.md and CHANGELOG.md
$readmePath = Join-Path $resolvedPath "README.md"
if (-not (Test-Path $readmePath)) {
    throw "Missing required file: README.md"
}

$changelogPath = Join-Path $resolvedPath "CHANGELOG.md"
if (-not (Test-Path $changelogPath)) {
    throw "Missing recommended file: CHANGELOG.md"
}

# 7. Package files into zip
if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $resolvedPath "dist"
}

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$zipFileName = "$($manifestContent.name)-$($manifestContent.version_number).zip"
$zipFilePath = Join-Path $OutputDir $zipFileName

$stagingDir = Join-Path $OutputDir "staging_$([System.Guid]::NewGuid().ToString('N').Substring(0, 8))"
New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

try {
    Copy-Item -Path $dllCandidate -Destination $stagingDir -Force
    Copy-Item -Path $manifestPath -Destination $stagingDir -Force
    Copy-Item -Path $iconPath -Destination $stagingDir -Force
    Copy-Item -Path $readmePath -Destination $stagingDir -Force
    Copy-Item -Path $changelogPath -Destination $stagingDir -Force

    if (Test-Path $zipFilePath) {
        Remove-Item -Path $zipFilePath -Force
    }

    # Compress staging contents directly to root of zip archive
    Compress-Archive -Path "$stagingDir\*" -DestinationPath $zipFilePath -Force
    Write-Host "==> Archive successfully created:" -ForegroundColor Green
    Write-Host "    $zipFilePath" -ForegroundColor Cyan
    Write-Host "    Files packaged:" -ForegroundColor Gray
    Get-ChildItem -Path $stagingDir | ForEach-Object { Write-Host "      - $($_.Name) ($($_.Length) bytes)" -ForegroundColor Gray }
}
finally {
    if (Test-Path $stagingDir) {
        Remove-Item -Path $stagingDir -Recurse -Force
    }
}
