<#
.SYNOPSIS
    Automates the creation, scaffolding, Git initialization, GitHub publishing,
    and Spec-Kit preparation for a new R.E.P.O. BepInEx mod.

.DESCRIPTION
    1. Validates the PascalCase mod name and ensures directory does not already exist.
    2. Installs or verifies the dotnet new repo-mod template.
    3. Scaffolds the mod project.
    4. Synchronizes manifest.json, README.md, and project metadata.
    5. Initializes Git repository on the 'master' branch.
    6. Adds external/RepoAPI and external/RepoKit git submodules.
    7. Creates the initial Git commit.
    8. Publishes the public GitHub repository (https://github.com/OsmarBriones/<ModName>).
    9. Provisions the THUNDERSTORE_TOKEN repository secret via gh CLI if available.
    10. Prepares Spec-Kit with an initial feature branch under specs/001-<short-name>/.
    11. Verifies compilation with dotnet build.
    12. Commits and pushes the initial Spec-Kit feature.

.PARAMETER ModName
    PascalCase name for the mod (e.g. LifeSteal, DucksEveryWhere).

.PARAMETER Description
    Short, engaging description for manifest.json (< 250 chars).

.PARAMETER FeatureDescription
    Detailed feature description for Spec-Kit's initial specification.

.PARAMETER FeatureShortName
    Short 2-4 word kebab-case identifier for Spec-Kit feature (e.g. lifesteal-core).

.PARAMETER SpecMarkdownContent
    Optional full markdown specification content to write directly into spec.md.

.PARAMETER WorkspaceRoot
    Path to REPO_Mods root. Defaults to parent directory of RepoKit.

.PARAMETER SkipGitHub
    Skip GitHub repository creation and secret provisioning.

.PARAMETER SkipSpecKit
    Skip initializing Spec-Kit feature under specs/.

.PARAMETER SkipBuild
    Skip running dotnet build verification.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ModName,

    [Parameter(Position = 1)]
    [string]$Description = "",

    [string]$FeatureDescription = "",
    [string]$FeatureShortName = "",
    [string]$SpecMarkdownContent = "",
    [string]$WorkspaceRoot = "",
    [switch]$SkipGitHub,
    [switch]$SkipSpecKit,
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

# 1. Resolve Workspace Root
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $WorkspaceRoot) {
    # script is in RepoKit/skills/create-mod/scripts/ -> parent 4 levels up is REPO_Mods
    $WorkspaceRoot = (Resolve-Path (Join-Path $scriptDir "..\..\..\..")).Path
}
if (-not (Test-Path $WorkspaceRoot)) {
    New-Item -ItemType Directory -Path $WorkspaceRoot -Force | Out-Null
}
$resolvedWorkspace = (Resolve-Path $WorkspaceRoot).Path

Write-Host "==> Workspace root: $resolvedWorkspace" -ForegroundColor Cyan

# 2. Validate Mod Name (PascalCase, no special characters)
if ($ModName -notmatch '^[A-Z][a-zA-Z0-9]+$') {
    throw "ModName '$ModName' must be in PascalCase without spaces or special characters (e.g. LifeSteal, DucksEveryWhere)."
}

$targetPath = Join-Path $resolvedWorkspace $ModName
if (Test-Path $targetPath) {
    throw "Target directory already exists at: $targetPath"
}

Write-Host "==> Creating new mod: $ModName" -ForegroundColor Cyan
Write-Host "    Target Path: $targetPath" -ForegroundColor Gray

# 3. Ensure dotnet new template is available
$templateDir = Join-Path $resolvedWorkspace "repo_mod_template"
if (Test-Path $templateDir) {
    Write-Host "==> Verifying dotnet new repo-mod template..." -ForegroundColor Cyan
    & dotnet new install "$templateDir" --force | Out-Null
}

# 4. Scaffold from template
Write-Host "==> Scaffolding project from repo-mod template..." -ForegroundColor Cyan
$scaffoldOutput = & dotnet new repo-mod -n $ModName -o $targetPath 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host $scaffoldOutput
    throw "Failed to scaffold template with exit code $LASTEXITCODE"
}

# Clean up .template.config inside target folder if present
$nestedTemplateConfig = Join-Path $targetPath ".template.config"
if (Test-Path $nestedTemplateConfig) {
    Remove-Item -Path $nestedTemplateConfig -Recurse -Force
}

# 5. Synchronize manifest.json
Write-Host "==> Configuring manifest.json..." -ForegroundColor Cyan
$manifestPath = Join-Path $targetPath "manifest.json"
if (Test-Path $manifestPath) {
    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
    $manifest.name = $ModName
    $manifest.version_number = "1.0.0"
    $manifest.website_url = "https://github.com/OsmarBriones/$ModName"

    if (-not [string]::IsNullOrWhiteSpace($Description)) {
        $manifest.description = $Description
    } elseif ([string]::IsNullOrWhiteSpace($manifest.description) -or $manifest.description -match "Example mod") {
        $manifest.description = "$ModName mod for R.E.P.O. Fully configurable. Only Host, clients don't need it."
    }

    $jsonStr = $manifest | ConvertTo-Json -Depth 10
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($manifestPath, $jsonStr, $utf8NoBom)
}

# 6. Synchronize README.md with ModName and Description
$readmePath = Join-Path $targetPath "README.md"
if (Test-Path $readmePath) {
    $readmeContent = Get-Content $readmePath -Raw
    $readmeContent = $readmeContent -replace 'RepoModTemplate', $ModName
    $effectiveDesc = if (-not [string]::IsNullOrWhiteSpace($Description)) { $Description } else { "$ModName mod for R.E.P.O." }
    $readmeContent = $readmeContent -replace 'A starting template for building BepInEx 5.x Harmony mods for R.E.P.O.', $effectiveDesc
    [System.IO.File]::WriteAllText($readmePath, $readmeContent, (New-Object System.Text.UTF8Encoding($false)))
}

# 7. Initialize Git Repository
Write-Host "==> Initializing Git repository on master branch..." -ForegroundColor Cyan
& git -C $targetPath init -b master | Out-Null
& git -C $targetPath config core.autocrlf true | Out-Null
& git -C $targetPath config core.safecrlf false | Out-Null

# 8. Add Submodules (RepoAPI and RepoKit)
Write-Host "==> Adding git submodules (RepoAPI and RepoKit)..." -ForegroundColor Cyan
$repoApiUrl = "https://github.com/OsmarBriones/RepoAPI.git"
$repoKitUrl = "https://github.com/OsmarBriones/RepoKit.git"

& git -C $targetPath -c core.safecrlf=false submodule add $repoApiUrl external/RepoAPI 2>$null | Out-Null
& git -C $targetPath -c core.safecrlf=false submodule add $repoKitUrl external/RepoKit 2>$null | Out-Null

# 9. Initial Commit
Write-Host "==> Creating initial git commit..." -ForegroundColor Cyan
& git -C $targetPath add .
& git -C $targetPath commit -m "feat: initial mod structure from repo-mod template" -q | Out-Null

# 10. Public GitHub Repository Creation & Secret Provisioning
if (-not $SkipGitHub) {
    $ghCmd = Get-Command "gh" -ErrorAction SilentlyContinue
    if ($ghCmd) {
        Write-Host "==> Creating public GitHub repository OsmarBriones/$ModName..." -ForegroundColor Cyan
        try {
            # Create remote repo without direct --push to prevent OAuth workflow scope collisions
            & gh repo create "OsmarBriones/$ModName" --public 2>$null | Out-Null
            & git -C $targetPath remote add origin "https://github.com/OsmarBriones/$ModName.git" 2>$null | Out-Null
            & git -C $targetPath push -u origin master -q 2>$null | Out-Null
            Write-Host "    Repository created and pushed at: https://github.com/OsmarBriones/$ModName" -ForegroundColor Green
        } catch {
            Write-Warning "Could not create or push to GitHub repo: $_"
        }

        # Provision THUNDERSTORE_TOKEN secret if set
        $token = if ($env:THUNDERSTORE_TOKEN) { $env:THUNDERSTORE_TOKEN } else { $env:TCLI_AUTH_TOKEN }
        if (-not [string]::IsNullOrWhiteSpace($token)) {
            Write-Host "==> Provisioning THUNDERSTORE_TOKEN secret in GitHub repository..." -ForegroundColor Cyan
            try {
                & gh secret set THUNDERSTORE_TOKEN --body "$token" --repo "OsmarBriones/$ModName"
                Write-Host "    Secret THUNDERSTORE_TOKEN provisioned successfully." -ForegroundColor Green
            } catch {
                Write-Warning "Could not set THUNDERSTORE_TOKEN secret: $_"
            }
        } else {
            Write-Warning "No THUNDERSTORE_TOKEN or TCLI_AUTH_TOKEN environment variable found. Secret provisioning skipped."
        }
    } else {
        Write-Warning "GitHub CLI (gh) not found in PATH. Remote repository creation skipped."
    }
}

# 11. Spec-Kit Preparation
if (-not $SkipSpecKit) {
    $specScript = Join-Path $targetPath ".specify\scripts\powershell\create-new-feature.ps1"
    if (Test-Path $specScript) {
        Write-Host "==> Initializing Spec-Kit feature specification..." -ForegroundColor Cyan
        $effectiveFeatureDesc = if (-not [string]::IsNullOrWhiteSpace($FeatureDescription)) {
            $FeatureDescription
        } else {
            "Implement core gameplay mechanics for $ModName"
        }

        $effectiveShortName = if (-not [string]::IsNullOrWhiteSpace($FeatureShortName)) {
            $FeatureShortName
        } else {
            "$($ModName.ToLower())-core"
        }

        & powershell -ExecutionPolicy Bypass -File $specScript "$effectiveFeatureDesc" -ShortName "$effectiveShortName"

        # Ensure spec.md is populated with actual content (not raw placeholders)
        if ([string]::IsNullOrWhiteSpace($SpecMarkdownContent)) {
            $SpecMarkdownContent = @"
# Feature Specification: $ModName Core Mechanics

**Feature Branch**: `001-$effectiveShortName`

**Created**: $(Get-Date -Format 'yyyy-MM-dd')

**Status**: Draft

**Input**: User description: "$effectiveFeatureDesc"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Core Gameplay Mechanic (Priority: P1)

As a player, I want $effectiveFeatureDesc, so that the gameplay experience is enhanced.

**Why this priority**: Essential functionality for $ModName.

**Independent Test**: Verify the feature works during level gameplay.

**Acceptance Scenarios**:

1. **Given** default configuration, **When** the player triggers the mechanic, **Then** the expected effect occurs smoothly.

---

### User Story 2 - Configuration Tuning (Priority: P2)

As a player or server host, I want to configure the mod settings via BepInEx config, so that I can customize balance.

**Why this priority**: Supports player preference and difficulty adjustment.

**Independent Test**: Change settings in config and verify they take effect in-game.

**Acceptance Scenarios**:

1. **Given** custom configuration values, **When** the game loads, **Then** the mod applies the configured values.

## Functional Requirements

- **FR-001**: The mod MUST be configurable via BepInEx configuration.
- **FR-002**: Core gameplay mechanics MUST execute cleanly and log errors gracefully.

## Success Criteria

1. Feature executes in-game without null references or performance drops.
2. Settings persist and reload correctly from config file.
"@
        }

        $specsDir = Join-Path $targetPath "specs"
        $matchingSpecDir = Get-ChildItem -Path $specsDir -Directory | Where-Object { $_.Name -like "*-$effectiveShortName" } | Select-Object -First 1
        if ($matchingSpecDir) {
            $targetSpecFile = Join-Path $matchingSpecDir.FullName "spec.md"
            [System.IO.File]::WriteAllText($targetSpecFile, $SpecMarkdownContent, (New-Object System.Text.UTF8Encoding($false)))
            Write-Host "    Populated spec.md with specification." -ForegroundColor Green
        }
    }
}

# 12. Build Verification
if (-not $SkipBuild) {
    Write-Host "==> Verifying build with dotnet build..." -ForegroundColor Cyan
    $csprojPath = Join-Path $targetPath "$ModName.csproj"
    $buildOutput = & dotnet build $csprojPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host $buildOutput
        Write-Warning "Build completed with exit code $LASTEXITCODE. Check references or dependencies."
    } else {
        Write-Host "    Build succeeded with 0 errors!" -ForegroundColor Green
    }
}

# 13. Commit Spec-Kit files & Push
Write-Host "==> Finalizing git state..." -ForegroundColor Cyan
& git -C $targetPath add .
$statusOutput = & git -C $targetPath status --porcelain
if (-not [string]::IsNullOrWhiteSpace($statusOutput)) {
    & git -C $targetPath commit -m "docs(spec): initialize spec-kit feature for $ModName" -q | Out-Null
    if (-not $SkipGitHub) {
        try {
            & git -C $targetPath push origin master -q 2>$null | Out-Null
            Write-Host "    Pushed Spec-Kit initialization to GitHub." -ForegroundColor Green
        } catch {
            Write-Warning "Could not push to remote: $_"
        }
    }
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host " Mod '$ModName' successfully created and configured!" -ForegroundColor Green
Write-Host " Path:        $targetPath" -ForegroundColor Cyan
Write-Host " GitHub:      https://github.com/OsmarBriones/$ModName" -ForegroundColor Cyan
Write-Host " Ready for:   Spec-Kit (speckit-plan / speckit-tasks / speckit-implement)" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Green
