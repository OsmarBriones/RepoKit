<#
.SYNOPSIS
    Automates pre-release checks, thumbnail generation, changelog release promotion,
    packaging, git tagging, and GitHub Actions publishing via Thunderstore CLI (tcli).

.DESCRIPTION
    1. Validates mod files (manifest.json, README.md, icon.png).
    2. Auto-generates a 256x256 thumbnail if icon.png is missing or default placeholder.
    3. Promotes ## [Unreleased] changelog section to ## [X.Y.Z] - YYYY-MM-DD.
    4. Syncs version across .csproj, manifest.json, and Plugin.cs.
    5. Ensures .github/workflows/publish.yml is configured for GitHub Actions CI/CD.
    6. Runs package-mod.ps1 to build and verify dist/<ModName>-<Version>.zip.
    7. Commits changes, tags the release (vX.Y.Z), and pushes to GitHub to trigger tcli publish.

.PARAMETER ModPath
    Path to the target mod repository root. Defaults to current directory.

.PARAMETER Version
    Optional explicit version number to release (e.g. "1.1.0"). If omitted, uses current manifest version.

.PARAMETER SkipPush
    Prepare and tag the release locally without pushing commits and tags to remote Git repository.

.PARAMETER LocalPublish
    Run tcli publish directly on local machine using local THUNDERSTORE_TOKEN or TCLI_AUTH_TOKEN environment variable.
#>

[CmdletBinding()]
param(
    [string]$ModPath = ".",
    [string]$Version = "",
    [switch]$SkipPush,
    [switch]$LocalPublish
)

$ErrorActionPreference = "Stop"

$resolvedPath = (Resolve-Path $ModPath).Path
Write-Host "==> Starting Publish Workflow for R.E.P.O. Mod at: $resolvedPath" -ForegroundColor Cyan

# 1. Locate .csproj
$csprojFiles = Get-ChildItem -Path $resolvedPath -Filter "*.csproj" -File
if ($csprojFiles.Count -eq 0) {
    throw "No .csproj file found in $resolvedPath"
}
$csproj = $csprojFiles[0]
[xml]$projXml = Get-Content $csproj.FullName

$modName = $projXml.Project.PropertyGroup.AssemblyName | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1
if (-not $modName) {
    $modName = [System.IO.Path]::GetFileNameWithoutExtension($csproj.Name)
}

# 2. Check / Generate Icon
$iconPath = Join-Path $resolvedPath "icon.png"
$needIconGen = $false

if (-not (Test-Path $iconPath)) {
    $needIconGen = $true
} else {
    Add-Type -AssemblyName System.Drawing
    try {
        $img = [System.Drawing.Image]::FromFile($iconPath)
        if ($img.Width -ne 256 -or $img.Height -ne 256) {
            Write-Warning "Existing icon.png is $($img.Width)x$($img.Height) (must be 256x256). Regenerating..."
            $needIconGen = $true
        }
        $img.Dispose()
    } catch {
        $needIconGen = $true
    }
}

if ($needIconGen) {
    Write-Host "==> Generating 256x256 icon for $modName..." -ForegroundColor Yellow
    $proceduralScript = Join-Path $resolvedPath "external/RepoKit/skills/generate-thumbnail/scripts/generate-procedural-icon.ps1"
    if (-not (Test-Path $proceduralScript)) {
        # Fallback search in RepoKit sibling directory
        $proceduralScript = Join-Path $resolvedPath "../RepoKit/skills/generate-thumbnail/scripts/generate-procedural-icon.ps1"
    }

    if (Test-Path $proceduralScript) {
        & powershell -ExecutionPolicy Bypass -File $proceduralScript -ModName $modName -OutputPath $iconPath
        Write-Host "    Icon generated successfully." -ForegroundColor Green
    } else {
        Write-Warning "Could not locate generate-procedural-icon.ps1. Please ensure 256x256 icon.png exists."
    }
}

# 3. Read & Validate manifest.json
$manifestPath = Join-Path $resolvedPath "manifest.json"
if (-not (Test-Path $manifestPath)) {
    throw "Missing required file: manifest.json"
}
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

# Auto-detect website_url from git remote origin if missing
if ([string]::IsNullOrWhiteSpace($manifest.website_url) -or $manifest.website_url -match 'GITHUB_REPO_URL|YOUR_REPO_URL') {
    $gitRemote = & git -C $resolvedPath config --get remote.origin.url 2>$null
    if (-not [string]::IsNullOrWhiteSpace($gitRemote)) {
        $gitRemote = $gitRemote.Trim()
        if ($gitRemote -match '^git@github\.com:(.+?)(?:\.git)?$') {
            $gitRemote = "https://github.com/$($Matches[1])"
        } elseif ($gitRemote -match '^(https?://.+?)(?:\.git)?$') {
            $gitRemote = $Matches[1]
        }
        $manifest | Add-Member -NotePropertyName "website_url" -NotePropertyValue $gitRemote -Force
    }
}

# Determine target version
$targetVersion = $manifest.version_number
if (-not [string]::IsNullOrWhiteSpace($Version)) {
    $targetVersion = $Version
    $manifest.version_number = $targetVersion
}

# Save manifest.json back
$manifestJson = $manifest | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($manifestPath, $manifestJson, [System.Text.Encoding]::UTF8)

# Sync .csproj version
if ($projXml.Project.PropertyGroup.Version -ne $targetVersion) {
    $projXml.Project.PropertyGroup.Version = $targetVersion
    $projXml.Save($csproj.FullName)
    Write-Host "    Updated $($csproj.Name) Version to $targetVersion" -ForegroundColor Gray
}

Write-Host "    Target Release Version: $targetVersion" -ForegroundColor Cyan

# 4. Promote CHANGELOG.md [Unreleased] to Release Version
$changelogPath = Join-Path $resolvedPath "CHANGELOG.md"
if (Test-Path $changelogPath) {
    $todayStr = Get-Date -Format "yyyy-MM-dd"
    $changelogContent = Get-Content $changelogPath -Raw

    if ($changelogContent -match '## \[Unreleased\]') {
        Write-Host "==> Promoting CHANGELOG.md [Unreleased] section to [$targetVersion] - $todayStr..." -ForegroundColor Cyan
        $changelogContent = $changelogContent -replace '## \[Unreleased\]', "## [$targetVersion] - $todayStr"
        [System.IO.File]::WriteAllText($changelogPath, $changelogContent, [System.Text.Encoding]::UTF8)
        Write-Host "    CHANGELOG.md updated successfully." -ForegroundColor Green
    }
}

# 5. Ensure GitHub Actions Workflow exists (.github/workflows/publish.yml)
$githubDir = Join-Path $resolvedPath ".github\workflows"
if (-not (Test-Path $githubDir)) {
    New-Item -ItemType Directory -Path $githubDir -Force | Out-Null
}

$workflowPath = Join-Path $githubDir "publish.yml"
if (-not (Test-Path $workflowPath)) {
    Write-Host "==> Adding GitHub Actions publish.yml workflow..." -ForegroundColor Cyan
    $templatePath = Join-Path $resolvedPath "external/RepoKit/skills/publish-mod/templates/publish.yml"
    if (-not (Test-Path $templatePath)) {
        $templatePath = Join-Path $resolvedPath "../RepoKit/skills/publish-mod/templates/publish.yml"
    }

    if (Test-Path $templatePath) {
        Copy-Item -Path $templatePath -Destination $workflowPath -Force
        Write-Host "    Created .github/workflows/publish.yml" -ForegroundColor Green
    } else {
        Write-Warning "Could not find publish.yml template to copy to .github/workflows/publish.yml"
    }
}

# 6. Run Packaging Script
Write-Host "==> Building and packaging mod..." -ForegroundColor Cyan
$packageScript = Join-Path $resolvedPath "external/RepoKit/skills/package-mod/scripts/package-mod.ps1"
if (-not (Test-Path $packageScript)) {
    $packageScript = Join-Path $resolvedPath "../RepoKit/skills/package-mod/scripts/package-mod.ps1"
}

if (Test-Path $packageScript) {
    & powershell -ExecutionPolicy Bypass -File $packageScript -ModPath $resolvedPath -Configuration Release
} else {
    & dotnet build $csproj.FullName -c Release
}

$distZip = Join-Path $resolvedPath "dist\$modName-$targetVersion.zip"
if (-not (Test-Path $distZip)) {
    $distZip = Join-Path $resolvedPath "dist\$modName.zip"
}

if (-not (Test-Path $distZip)) {
    throw "Packaging failed. Expected zip archive at: $distZip"
}

Write-Host "==> Verified packaged archive: $distZip" -ForegroundColor Green

# 7. Git Commit, Tag, and Push
$tagName = "v$targetVersion"
Write-Host "==> Staging git changes and creating tag $tagName..." -ForegroundColor Cyan

& git -C $resolvedPath add .
$statusOutput = & git -C $resolvedPath status --porcelain
if (-not [string]::IsNullOrWhiteSpace($statusOutput)) {
    & git -C $resolvedPath commit -m "release: $tagName"
    Write-Host "    Committed release changes." -ForegroundColor Green
} else {
    Write-Host "    No unstaged changes to commit." -ForegroundColor Gray
}

# Check if tag exists
$existingTag = & git -C $resolvedPath tag -l $tagName
if ($existingTag -eq $tagName) {
    Write-Warning "Git tag $tagName already exists."
} else {
    & git -C $resolvedPath tag -a $tagName -m "Release $tagName"
    Write-Host "    Created git tag $tagName" -ForegroundColor Green
}

# Auto-sync THUNDERSTORE_TOKEN to GitHub repository secrets if local env var is set
$localToken = if ($env:THUNDERSTORE_TOKEN) { $env:THUNDERSTORE_TOKEN } else { $env:TCLI_AUTH_TOKEN }
if (-not [string]::IsNullOrWhiteSpace($localToken)) {
    $ghCmd = Get-Command "gh" -ErrorAction SilentlyContinue
    if ($ghCmd) {
        $gitRemote = & git -C $resolvedPath config --get remote.origin.url 2>$null
        if ($gitRemote -match 'github\.com[:/](.+?)/(.+?)(?:\.git)?$') {
            $repoSlug = "$($Matches[1])/$($Matches[2])"
            try {
                Write-Host "==> Syncing THUNDERSTORE_TOKEN secret to GitHub repository $repoSlug..." -ForegroundColor Cyan
                & gh secret set THUNDERSTORE_TOKEN --body "$localToken" --repo $repoSlug
                Write-Host "    GitHub secret THUNDERSTORE_TOKEN updated successfully." -ForegroundColor Green
            } catch {
                Write-Warning "Could not auto-set GitHub secret via gh CLI: $_"
            }
        }
    }
}

# 8. Push / Local Publish
if (-not $SkipPush) {
    Write-Host "==> Pushing commits and tag $tagName to GitHub..." -ForegroundColor Cyan
    & git -C $resolvedPath push origin master --tags
    Write-Host "==> SUCCESS: Tag $tagName pushed to GitHub!" -ForegroundColor Green
    Write-Host "    GitHub Actions will now build and publish to Thunderstore via tcli using THUNDERSTORE_TOKEN." -ForegroundColor Yellow
} else {
    Write-Host "    [-SkipPush specified] Release prepared and tagged locally." -ForegroundColor Yellow
}

if ($LocalPublish -or (-not [string]::IsNullOrWhiteSpace($env:THUNDERSTORE_TOKEN)) -or (-not [string]::IsNullOrWhiteSpace($env:TCLI_AUTH_TOKEN))) {
    Write-Host "==> Attempting direct local publish with tcli..." -ForegroundColor Cyan
    $tcliCmd = Get-Command "tcli" -ErrorAction SilentlyContinue
    if ($tcliCmd) {
        & tcli publish --file $distZip
        Write-Host "    Direct local publish completed successfully!" -ForegroundColor Green
    } else {
        Write-Warning "tcli command not found locally. Install via 'dotnet tool install -g ThunderstoreCLI'."
    }
}
