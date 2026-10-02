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
    [ValidateSet("patch", "minor", "major", "")]
    [string]$Bump = "",
    [switch]$SkipPush,
    [switch]$LocalPublish,
    [switch]$Confirmed
)

$ErrorActionPreference = "Stop"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

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
        $ps = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
        & $ps -ExecutionPolicy Bypass -File $proceduralScript -ModName $modName -OutputPath $iconPath
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

# Parse current version into SemVer components (Major.Minor.Patch)
$currentMajor = 1
$currentMinor = 0
$currentPatch = 0
if ($targetVersion -match '^(\d+)\.(\d+)\.(\d+)') {
    $currentMajor = [int]$Matches[1]
    $currentMinor = [int]$Matches[2]
    $currentPatch = [int]$Matches[3]
}

$nextMajor = $currentMajor + 1
$nextMinor = $currentMinor + 1
$nextPatch = $currentPatch + 1

if (-not [string]::IsNullOrWhiteSpace($Version)) {
    $targetVersion = $Version
} elseif (-not [string]::IsNullOrWhiteSpace($Bump)) {
    switch ($Bump.ToLower()) {
        "major" {
            $targetVersion = "{0}.0.0" -f $nextMajor
        }
        "minor" {
            $targetVersion = "{0}.{1}.0" -f $currentMajor, $nextMinor
        }
        "patch" {
            $targetVersion = "{0}.{1}.{2}" -f $currentMajor, $currentMinor, $nextPatch
        }
    }
} else {
    # If no Version or Bump provided, check if current version tag already exists in Git
    $existingTag = & git -C $resolvedPath tag -l "v$targetVersion" 2>$null
    if (-not [string]::IsNullOrWhiteSpace($existingTag)) {
        # Current version was already tagged/released, auto-bump patch by default
        $targetVersion = "{0}.{1}.{2}" -f $currentMajor, $currentMinor, $nextPatch
        Write-Host "    Current version v$($manifest.version_number) already released; auto-bumping patch to $targetVersion" -ForegroundColor Yellow
    }
}

$manifest.version_number = $targetVersion

# Save manifest.json back
$manifestJson = $manifest | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($manifestPath, $manifestJson, $utf8NoBom)

# Sync .csproj version
$csprojContent = Get-Content $csproj.FullName -Raw
if ($csprojContent -match '<Version>(.*?)</Version>') {
    if ($Matches[1] -ne $targetVersion) {
        $csprojContent = $csprojContent -replace '<Version>.*?</Version>', "<Version>$targetVersion</Version>"
        [System.IO.File]::WriteAllText($csproj.FullName, $csprojContent, $utf8NoBom)
        Write-Host "    Updated $($csproj.Name) Version to $targetVersion" -ForegroundColor Gray
    }
}

# Sync *Plugin.cs PluginVersion
$pluginFiles = Get-ChildItem -Path $resolvedPath -Filter "*Plugin.cs" -Recurse -File
if ($pluginFiles.Count -gt 0) {
    $pluginFile = $pluginFiles[0]
    $pluginContent = Get-Content $pluginFile.FullName -Raw
    if ($pluginContent -match 'PluginVersion\s*=\s*".*?"') {
        $pluginContent = $pluginContent -replace 'PluginVersion\s*=\s*".*?"', "PluginVersion = `"$targetVersion`""
        [System.IO.File]::WriteAllText($pluginFile.FullName, $pluginContent, $utf8NoBom)
        Write-Host "    Updated $($pluginFile.Name) PluginVersion to $targetVersion" -ForegroundColor Gray
    }
}

Write-Host "    Target Release Version: $targetVersion" -ForegroundColor Cyan

# 4. Promote or curate CHANGELOG.md entry for target release version
$changelogPath = Join-Path $resolvedPath "CHANGELOG.md"
if (Test-Path $changelogPath) {
    $todayStr = Get-Date -Format "yyyy-MM-dd"
    $changelogContent = Get-Content $changelogPath -Raw

    $escapedVersion = [regex]::Escape($targetVersion)
    $hasVersionEntry = ($changelogContent -match "##\s+\[?$escapedVersion\]?")

    if ($changelogContent -match '##\s+\[?Unreleased\]?') {
        Write-Host "==> Promoting CHANGELOG.md [Unreleased] section to [$targetVersion] - $todayStr..." -ForegroundColor Cyan
        $changelogContent = $changelogContent -replace '##\s+\[?Unreleased\]?', "## [$targetVersion] - $todayStr"
        [System.IO.File]::WriteAllText($changelogPath, $changelogContent, $utf8NoBom)
        Write-Host "    CHANGELOG.md updated successfully." -ForegroundColor Green
    } elseif (-not $hasVersionEntry) {
        Write-Host "==> Adding curated player-facing entry for [$targetVersion] in CHANGELOG.md..." -ForegroundColor Cyan
        
        # Get recent git commits since last tag to curate player-facing bullets
        $lastTag = & git -C $resolvedPath describe --tags --abbrev=0 2>$null
        $commitLog = if ($lastTag) {
            & git -C $resolvedPath log "$lastTag..HEAD" --pretty=format:"%s" 2>$null
        } else {
            & git -C $resolvedPath log -n 5 --pretty=format:"%s" 2>$null
        }

        $bullets = @()
        if ($commitLog) {
            foreach ($line in ($commitLog -split "`r?`n")) {
                $trimmed = $line.Trim()
                # Strict filter: ignore internal/CI/CD/build/refactor/submodule/sensitive commits
                if ($trimmed -match '^(ci|build|chore|test|refactor|submodule|repo_kit|repokit|secrets?|token|workflows?|bump|merge):' -or
                    $trimmed -match 'github action|submodule|token|secret|workflow|\.github|Directory\.Build|csproj' -or
                    [string]::IsNullOrWhiteSpace($trimmed)) {
                    continue
                }
                # Clean up commit prefixes like "feat:", "fix:", "docs:"
                $cleanMsg = $trimmed -replace '^(feat|fix|docs|perf|style)(\(.*?\))?:\s*', ''
                if ($cleanMsg.Length -gt 1) {
                    $cleanMsg = $cleanMsg.Substring(0,1).ToUpper() + $cleanMsg.Substring(1)
                }
                $bullets += "- $cleanMsg"
            }
        }

        if ($bullets.Count -eq 0) {
            $bullets += "- Maintenance update and gameplay improvements."
        }

        $newEntry = "`n## [$targetVersion] - $todayStr`n" + ($bullets -join "`n") + "`n"

        if ($changelogContent -match '(?m)^#\s+Changelog\s*$') {
            $changelogContent = $changelogContent -replace '(?m)(^#\s+Changelog\s*$)', "`$1`n$newEntry"
        } else {
            $changelogContent = "# Changelog`n$newEntry`n" + $changelogContent
        }

        [System.IO.File]::WriteAllText($changelogPath, $changelogContent, $utf8NoBom)
        Write-Host "    CHANGELOG.md updated with curated player-facing notes." -ForegroundColor Green
    }

    # 4.1. Audit & Validate CHANGELOG.md historical version coverage
    Write-Host "==> Auditing CHANGELOG.md historical version coverage..." -ForegroundColor Cyan
    $legacyChangelogCandidates = @(
        (Join-Path $resolvedPath "zip\CHANGELOG.md"),
        (Join-Path $resolvedPath "docs\CHANGELOG.md")
    )
    foreach ($legChangelog in $legacyChangelogCandidates) {
        if (Test-Path $legChangelog) {
            $legContent = Get-Content $legChangelog -Raw
            $legVersionMatches = [regex]::Matches($legContent, '##\s+\[?(\d+\.\d+\.\d+)\]?')
            foreach ($lvm in $legVersionMatches) {
                $legVer = $lvm.Groups[1].Value
                if ($changelogContent -notmatch "##\s+\[?$([regex]::Escape($legVer))\]?") {
                    Write-Warning "Historical version $legVer found in $legChangelog is missing from root CHANGELOG.md! Merging..."
                    $pattern = "(?s)##\s+\[?" + [regex]::Escape($legVer) + "\]?.*?(?=(?:##\s+\[?\d+\.\d+\.\d+\]?|\Z))"
                    $match = [regex]::Match($legContent, $pattern)
                    if ($match.Success) {
                        $changelogContent = $changelogContent.TrimEnd() + "`n`n" + $match.Value.Trim() + "`n"
                        [System.IO.File]::WriteAllText($changelogPath, $changelogContent, $utf8NoBom)
                        Write-Host "    Merged historical version $legVer into root CHANGELOG.md." -ForegroundColor Green
                    }
                }
            }
        }
    }

    # Verify existing git tags are in CHANGELOG.md
    $allTags = & git -C $resolvedPath tag -l "v*" 2>$null
    if ($allTags) {
        foreach ($t in ($allTags -split "`r?`n")) {
            $tagVer = $t.Trim().TrimStart('v')
            if ($tagVer -match '^\d+\.\d+\.\d+' -and $tagVer -ne $targetVersion) {
                if ($changelogContent -notmatch "##\s+\[?$([regex]::Escape($tagVer))\]?") {
                    Write-Warning "Git tag $t exists, but version $tagVer is missing from CHANGELOG.md."
                }
            }
        }
    }
}

# 4.2. Audit & Validate README.md completeness and accuracy
$readmePath = Join-Path $resolvedPath "README.md"
if (-not (Test-Path $readmePath)) {
    throw "Missing required file: README.md"
}
Write-Host "==> Auditing README.md completeness and accuracy..." -ForegroundColor Cyan
$readmeContent = Get-Content $readmePath -Raw

# Check essential sections
$requiredSections = @("Features", "Configuration", "Installation", "Credits")
foreach ($sec in $requiredSections) {
    if ($readmeContent -notmatch "(?i)##\s+.*$sec") {
        Write-Warning "README.md is missing recommended section: '## $sec'"
    }
}

# Detect legacy READMEs and check credits/content preservation
$legacyReadmeCandidates = @(
    (Join-Path $resolvedPath "zip\README.md"),
    (Join-Path $resolvedPath "docs\README.md")
)
foreach ($legReadme in $legacyReadmeCandidates) {
    if (Test-Path $legReadme) {
        $legContent = Get-Content $legReadme -Raw
        if ($legContent -match '(?i)credit|thanks|contributor') {
            $legCreditsMatches = [regex]::Matches($legContent, '(?i)(?:thanks to|credit to|by)\s+\*\*?([A-Za-z0-9_ -]+)\*\*?')
            foreach ($cm in $legCreditsMatches) {
                $contributor = $cm.Groups[1].Value.Trim()
                if ($contributor -and $contributor -ne "Osmar Briones" -and $readmeContent -notmatch [regex]::Escape($contributor)) {
                    Write-Warning "Legacy README ($legReadme) credits '$contributor', but they appear missing from current README.md Credits section!"
                }
            }
        }
    }
}

# Check if C# Config options are documented in README
$csFiles = Get-ChildItem -Path $resolvedPath -Filter "*.cs" -Recurse | Where-Object { $_.FullName -notmatch '[\\/](obj|bin|dist|external)[\\/]' }
$configKeys = [System.Collections.Generic.HashSet[string]]::new()
foreach ($cs in $csFiles) {
    $code = Get-Content $cs.FullName -Raw
    $bindMatches = [regex]::Matches($code, 'Bind(?:<[^>]+>)?\s*\(\s*"[^"]+"\s*,\s*"([^"]+)"')
    foreach ($bm in $bindMatches) {
        $configKeys.Add($bm.Groups[1].Value) | Out-Null
    }
}
$missingKeys = @()
foreach ($key in $configKeys) {
    if ($readmeContent -notmatch [regex]::Escape($key)) {
        $missingKeys += $key
    }
}
if ($missingKeys.Count -gt 0) {
    Write-Warning "The following configuration keys from code were not found in README.md: $($missingKeys -join ', ')"
    Write-Warning "Please ensure all player-facing settings are documented in README.md."
} else {
    Write-Host "    Configuration options coverage verified in README.md." -ForegroundColor Green
}

# Check for unresolved template placeholders
$placeholders = @("YOUR_REPO_URL", "AUTHOR_ID", "Example mod description", "TODO")
foreach ($ph in $placeholders) {
    if ($readmeContent -match [regex]::Escape($ph)) {
        throw "README.md contains unresolved placeholder: '$ph'"
    }
}

# 5. Ensure GitHub Actions Workflow exists (.github/workflows/publish.yml)
$githubDir = Join-Path $resolvedPath ".github\workflows"
if (-not (Test-Path $githubDir)) {
    New-Item -ItemType Directory -Path $githubDir -Force | Out-Null
}

$workflowPath = Join-Path $githubDir "publish.yml"
$templatePath = Join-Path $resolvedPath "external/RepoKit/skills/publish-mod/templates/publish.yml"
if (-not (Test-Path $templatePath)) {
    $templatePath = Join-Path $resolvedPath "../RepoKit/skills/publish-mod/templates/publish.yml"
}

if (Test-Path $templatePath) {
    $needsUpdate = $false
    if (-not (Test-Path $workflowPath)) {
        $needsUpdate = $true
    } else {
        $currentWorkflow = Get-Content $workflowPath -Raw
        if ($currentWorkflow -notmatch "categories:") {
            $needsUpdate = $true
        }
    }
    if ($needsUpdate) {
        Copy-Item -Path $templatePath -Destination $workflowPath -Force
        Write-Host "    Synced .github/workflows/publish.yml with latest template (including categories support)." -ForegroundColor Green
    }
}

# 5.1 Thunderstore Category Inference and Sync (categories.txt)
$validCategories = @(
    "quality-of-life", "ai-generated", "cosmetics", "serverside", "clientside",
    "levels", "monsters", "drones", "weapons", "upgrades", "items", "valuables",
    "audio", "misc", "libraries", "tools", "modpacks", "mods"
)
$categoriesFile = Join-Path $resolvedPath "categories.txt"
$categories = [System.Collections.Generic.List[string]]::new()

if (Test-Path $categoriesFile) {
    Get-Content $categoriesFile | ForEach-Object {
        $c = $_.Trim().ToLowerInvariant()
        if (-not [string]::IsNullOrWhiteSpace($c) -and $validCategories -contains $c -and -not $categories.Contains($c)) {
            $categories.Add($c)
        }
    }
}

if ($categories.Count -eq 0) {
    Write-Host "==> Inferring Thunderstore categories for $modName..." -ForegroundColor Cyan
    $categories.Add("mods")

    $allCsFiles = Get-ChildItem -Path $resolvedPath -Filter "*.cs" -Recurse | Where-Object { $_.FullName -notmatch '[\\/](obj|bin|dist)[\\/]' }
    $codeText = ($allCsFiles | Get-Content -Raw) -join "`n"
    $archPath = Join-Path $resolvedPath "ARCHITECTURE.md"
    $archText = if (Test-Path $archPath) { Get-Content $archPath -Raw } else { "" }
    $readmeText = if (Test-Path $readmePath) { Get-Content $readmePath -Raw } else { "" }
    $context = "$codeText`n$archText`n$readmeText`n$($manifest.description)"

    if ($context -match '(?i)(monster|enemy|trudge|gnome|headman|centipede|EnemyDirector|EnemyParent|HealthDamage)') {
        if (-not $categories.Contains("monsters")) { $categories.Add("monsters") }
    }
    if ($context -match '(?i)(server-side|serverside|host-only|host only|only the host|SemiFunc\.IsMasterClientOrSingleplayer)') {
        if (-not $categories.Contains("serverside")) { $categories.Add("serverside") }
    } elseif ($context -match '(?i)(client-side|clientside|client only|client-only|purely visual|hud only)') {
        if (-not $categories.Contains("clientside")) { $categories.Add("clientside") }
    }
    if ($context -match '(?i)(ai[- ]generated|dall-e|midjourney|chatgpt|claude|gemini|antigravity)') {
        if (-not $categories.Contains("ai-generated")) { $categories.Add("ai-generated") }
    }
    if ($context -match '(?i)(\bweapon\b|\bweapons\b|\bgun\b|\bguns\b)') {
        if (-not $categories.Contains("weapons")) { $categories.Add("weapons") }
    }
    if ($context -match '(?i)(\bitem\b|\bitems\b)') {
        if (-not $categories.Contains("items")) { $categories.Add("items") }
    }
    if ($context -match '(?i)(\bupgrade\b|\bupgrades\b)') {
        if (-not $categories.Contains("upgrades")) { $categories.Add("upgrades") }
    }
    if ($context -match '(?i)(\baudio\b|\bsound\b|\bmusic\b|\bvoice\b)') {
        if (-not $categories.Contains("audio")) { $categories.Add("audio") }
    }
    if ($context -match '(?i)(quality[- ]of[- ]life|\bqol\b)') {
        if (-not $categories.Contains("quality-of-life")) { $categories.Add("quality-of-life") }
    }

    $catContent = ($categories -join "`n") + "`n"
    [System.IO.File]::WriteAllText($categoriesFile, $catContent, $utf8NoBom)
    Write-Host "    Inferred categories saved to categories.txt: $($categories -join ', ')" -ForegroundColor Green
} else {
    Write-Host "==> Using verified categories from categories.txt: $($categories -join ', ')" -ForegroundColor Green
}

# 6. Run Packaging Script
Write-Host "==> Building and packaging mod..." -ForegroundColor Cyan
$packageScript = Join-Path $resolvedPath "external/RepoKit/skills/package-mod/scripts/package-mod.ps1"
if (-not (Test-Path $packageScript)) {
    $packageScript = Join-Path $resolvedPath "../RepoKit/skills/package-mod/scripts/package-mod.ps1"
}

if (Test-Path $packageScript) {
    $ps = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
    & $ps -ExecutionPolicy Bypass -File $packageScript -ModPath $resolvedPath -Configuration Release
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

# 6.1 Pre-Release Approval Gate
$tagName = "v$targetVersion"
Write-Host ""
Write-Host "================ PRE-RELEASE SUMMARY ================" -ForegroundColor Cyan
Write-Host " Mod Name    : $modName" -ForegroundColor White
Write-Host " Version     : $targetVersion (Tag: $tagName)" -ForegroundColor White
Write-Host " Description : $($manifest.description)" -ForegroundColor White
Write-Host " Website URL : $($manifest.website_url)" -ForegroundColor White
Write-Host " Categories  : $($categories -join ', ')" -ForegroundColor White
Write-Host " Package Zip : $distZip" -ForegroundColor White
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host ""

if (-not $Confirmed) {
    if ([Environment]::UserInteractive) {
        $userInput = Read-Host "Type 'aprobado' to proceed with release (or anything else to abort)"
        if ($userInput -ne "aprobado") {
            Write-Warning "Publish cancelled by user (input was '$userInput', expected 'aprobado')."
            return
        }
        Write-Host "Confirmation received ('aprobado'). Proceeding with release..." -ForegroundColor Green
    } else {
        throw "Release confirmation required. Pass -Confirmed to authorize publication or run interactively and type 'aprobado'."
    }
}

# 7. Git Commit, Tag, and Push
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

# 8. Push Commits, Tags, and Create GitHub Release
if (-not $SkipPush) {
    Write-Host "==> Pushing commits and tag $tagName to GitHub..." -ForegroundColor Cyan
    & git -C $resolvedPath push origin master --tags
    Write-Host "==> SUCCESS: Tag $tagName pushed to GitHub!" -ForegroundColor Green

    # Create or update GitHub Release with attached package asset to trigger GitHub Actions
    $ghCmd = Get-Command "gh" -ErrorAction SilentlyContinue
    if ($ghCmd) {
        Write-Host "==> Ensuring GitHub Release $tagName exists with package asset..." -ForegroundColor Cyan
        $relExists = $false
        try {
            $prevEap = $ErrorActionPreference
            $ErrorActionPreference = "SilentlyContinue"
            $null = & gh release view $tagName --repo "OsmarBriones/$modName" 2>$null
            if ($LASTEXITCODE -eq 0) {
                $relExists = $true
            }
        } catch {
            $relExists = $false
        } finally {
            $ErrorActionPreference = $prevEap
        }

        if ($relExists) {
            Write-Host "    GitHub Release $tagName already exists. Updating package asset..." -ForegroundColor Yellow
            & gh release upload $tagName $distZip --clobber --repo "OsmarBriones/$modName"
        } else {
            & gh release create $tagName $distZip --title "$modName $tagName" --notes-file $changelogPath --repo "OsmarBriones/$modName"
        }
        Write-Host "==> SUCCESS: GitHub Release $tagName verified with package asset attached!" -ForegroundColor Green
        Write-Host "==> GitHub Actions is now publishing $modName $tagName to Thunderstore:" -ForegroundColor Green
        Write-Host "    https://github.com/OsmarBriones/$modName/actions" -ForegroundColor Cyan
    } else {
        Write-Warning "gh CLI not found. To trigger automated Thunderstore publishing via GitHub Actions, install gh CLI or create release manually."
    }
} else {
    Write-Host "    [-SkipPush specified] Release prepared and tagged locally." -ForegroundColor Yellow
}

# 9. Optional Local Publish via tcli (only when explicitly requested via -LocalPublish)
if ($LocalPublish) {
    if (-not [string]::IsNullOrWhiteSpace($localToken)) {
        Write-Host "==> [-LocalPublish specified] Publishing package directly to Thunderstore via tcli..." -ForegroundColor Cyan
        $tcliCmd = Get-Command "tcli" -ErrorAction SilentlyContinue
        if ($tcliCmd) {
            $distDir = Join-Path $resolvedPath "dist"
            if (-not (Test-Path $distDir)) {
                New-Item -ItemType Directory -Path $distDir -Force | Out-Null
            }
            $tomlPath = Join-Path $distDir "thunderstore.toml"
            $categoriesArrayJson = "[" + (($categories | ForEach-Object { "`"$_`"" }) -join ", ") + "]"
            try {
                $tomlContent = @"
[config]
schemaVersion = "0.0.1"

[package]
namespace = "OsmarBriones"
name = "$modName"
versionNumber = "$targetVersion"
description = "$($manifest.description)"
websiteUrl = "$($manifest.website_url)"
containsNsfwContent = false

[package.dependencies]
BepInEx-BepInExPack = "5.4.2304"

[publish]
repository = "https://thunderstore.io"
communities = [ "repo" ]

[publish.categories]
repo = $categoriesArrayJson
"@
                [System.IO.File]::WriteAllText($tomlPath, $tomlContent, $utf8NoBom)

                $publishOutput = & tcli publish --file $distZip --token $localToken --config-path $tomlPath 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "==> SUCCESS: Mod $modName v$targetVersion successfully published to Thunderstore!" -ForegroundColor Green
                } elseif ($publishOutput -match "Package of the same namespace, name and version already exists") {
                    Write-Host "==> UP-TO-DATE: Mod $modName v$targetVersion is ALREADY published on Thunderstore. No changes needed." -ForegroundColor Yellow
                } else {
                    Write-Host $publishOutput
                    throw "tcli publish failed with exit code $LASTEXITCODE"
                }
            } finally {
                if (Test-Path $tomlPath) {
                    Remove-Item $tomlPath -Force -ErrorAction SilentlyContinue
                }
            }
        } else {
            Write-Warning "tcli command not found locally. Install via 'dotnet tool install -g tcli'."
        }
    } else {
        Write-Warning "Cannot perform local publish: THUNDERSTORE_TOKEN not found."
    }
}
