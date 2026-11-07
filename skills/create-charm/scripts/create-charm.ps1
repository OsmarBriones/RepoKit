<#
.SYNOPSIS
    Creates a new Charm mod (one valuable, one power) on top of Pockets and CharmCore.

.DESCRIPTION
    1. Checks that REPO-Pockets and REPO-CharmCore are built (their Release DLLs are referenced).
    2. Runs create-mod.ps1 for Charm<Name> (GitHub repo REPO-Charm<Name>, topics, secret, submodules, Spec-Kit).
    3. Replaces the generic scaffold with the charm template (RepoKit/skills/create-charm/template): plugin,
       charm class, effect stub, project files with the Pockets and CharmCore references, tests (game contract
       and charm rules), README, ARCHITECTURE, CHANGELOG and the QA battery that starts with DebugMode.
    4. Adds the Pockets and CharmCore dependencies to manifest.json.
    5. Builds, runs the tests, commits and pushes when both pass.

.PARAMETER Name
    PascalCase name of the valuable (for example CoffeeCup). The mod is called Charm<Name>.

.PARAMETER DisplayName
    Player-facing name of the valuable (for example "Coffee Cup").

.PARAMETER PrefabName
    Exact prefab name of the valuable (for example "Valuable Arctic Coffee Cup").

.PARAMETER EffectName
    Name of the power (for example "Second Wind").

.PARAMETER EffectSummary
    One player-facing sentence describing the power.

.PARAMETER WearPercent
    Default wear per use, in percent of the valuable's original value.

.PARAMETER CooldownSeconds
    Default pause between uses; use -NoCooldown for a power without one.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$DisplayName,
    [Parameter(Mandatory = $true)][string]$PrefabName,
    [Parameter(Mandatory = $true)][string]$EffectName,
    [Parameter(Mandatory = $true)][string]$EffectSummary,
    [double]$WearPercent = 20,
    [double]$CooldownSeconds = 3,
    [switch]$NoCooldown,
    [switch]$SkipGitHub,
    [string]$WorkspaceRoot = ""
)

$ErrorActionPreference = "Stop"
$inv = [System.Globalization.CultureInfo]::InvariantCulture
$utf8 = New-Object System.Text.UTF8Encoding($false)

if ($Name -notmatch '^[A-Z][a-zA-Z0-9]+$') { throw "Name '$Name' must be PascalCase without spaces (for example CoffeeCup)." }
if ($EffectSummary.Contains('"') -or $DisplayName.Contains('"') -or $EffectName.Contains('"')) { throw "Do not use double quotes in the texts; they break argument passing." }

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $WorkspaceRoot) { $WorkspaceRoot = (Resolve-Path (Join-Path $scriptDir "..\..\..\..")).Path }
$templateDir = Join-Path $scriptDir "..\template"
$modName = "Charm$Name"
$repoName = "REPO-$modName"
$modPath = Join-Path $WorkspaceRoot $repoName
$effectClass = ($EffectName -replace '[^A-Za-z0-9]', '')
$shortName = (($EffectName.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-'))

# 1. Prerequisites: the dependency DLLs the charm references
$pocketsDll = Join-Path $WorkspaceRoot "REPO-Pockets\bin\Release\net48\Pockets.dll"
$coreDll = Join-Path $WorkspaceRoot "REPO-CharmCore\bin\Release\net48\CharmCore.dll"
foreach ($dll in @($pocketsDll, $coreDll)) {
    if (-not (Test-Path $dll)) { throw "Missing $dll. Build it first: dotnet build -c Release in that repository." }
}

# 2. Repository, GitHub, submodules, Spec-Kit
$description = "$EffectName`: $EffectSummary Needs Pockets and CharmCore. Everyone in the lobby needs it."
if ($description.Length -gt 249) { $description = $description.Substring(0, 249) }
$spec = @"
## User Scenarios

### User Story 1 - $EffectName (Priority: P1)
A player stores the $DisplayName in a pocket and gets this power while it stays there: $EffectSummary
**Acceptance**: with the valuable pocketed the power works; with it out of the pocket it does not; each use wears the valuable and shows the cooldown on the slot.

## Requirements
- FR-001: Registers a charm with CharmCore for the prefab $PrefabName.
- FR-002: Settings through CharmCore: Enabled, WearPercent, CooldownSeconds, DebugMode; host-authoritative except DebugMode.
- FR-003: All players install it (Category 2); depends on Pockets and CharmCore.
"@
$ps = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
$createMod = Join-Path $WorkspaceRoot "RepoKit\skills\create-mod\scripts\create-mod.ps1"
& $ps -ExecutionPolicy Bypass -File $createMod -ModName $modName -Description $description `
    -FeatureDescription "$DisplayName charm: $EffectName" -FeatureShortName $shortName -SpecMarkdownContent $spec `
    @(if ($SkipGitHub) { "-SkipGitHub" })
if (-not (Test-Path $modPath)) { throw "create-mod did not create $modPath" }

# create-mod can finish without a Spec-Kit folder when the feature script fails; make sure one exists.
$specsDir = Join-Path $modPath "specs"
if (-not (Test-Path $specsDir) -or -not (Get-ChildItem $specsDir -Directory -ErrorAction SilentlyContinue)) {
    Push-Location $modPath
    try { & $ps -ExecutionPolicy Bypass -File ".specify\scripts\powershell\create-new-feature.ps1" -Json -ShortName $shortName "$DisplayName charm: $EffectName" | Out-Null } finally { Pop-Location }
}
$featureDir = (Get-ChildItem $specsDir -Directory | Select-Object -First 1).FullName
[System.IO.File]::WriteAllText((Join-Path $featureDir "spec.md"), $spec, $utf8)

# 3. Overlay the template
foreach ($leftover in @("Patches", "ConfigurationController.cs", "$modName`Plugin.cs")) {
    $p = Join-Path $modPath $leftover
    if (Test-Path $p) { Remove-Item $p -Recurse -Force }
}

$cooldownCode = if ($NoCooldown) { "null" } else { ($CooldownSeconds.ToString($inv) + "f") }
$cooldownText = if ($NoCooldown) { "none" } else { $CooldownSeconds.ToString($inv) }
$tokens = [ordered]@{
    "__EFFECT_CLASS__"  = $effectClass
    "__EFFECT__"        = $EffectName
    "__SUMMARY__"       = $EffectSummary
    "__DISPLAY__"       = $DisplayName
    "__PREFAB__"        = $PrefabName
    "__COOLDOWN_TEXT__" = $cooldownText
    "__COOLDOWN__"      = $cooldownCode
    "__WEAR__"          = $WearPercent.ToString($inv)
    "__NAME__"          = $Name
    "__MOD__"           = $modName
}

function Expand-Template([string]$text) {
    foreach ($key in $tokens.Keys) { $text = $text.Replace($key, [string]$tokens[$key]) }
    return $text
}

$map = @(
    @("__MOD__.csproj.tpl", "$modName.csproj"),
    @("__MOD__Plugin.cs", "$modName`Plugin.cs"),
    @("__NAME__Charm.cs", "$Name`Charm.cs"),
    @("__EFFECT_CLASS__.cs", "$effectClass.cs"),
    @("README.md", "README.md"),
    @("ARCHITECTURE.md", "ARCHITECTURE.md"),
    @("CHANGELOG.md", "CHANGELOG.md"),
    @("qa-battery.md", "specs\$(Split-Path $featureDir -Leaf)\qa-battery.md"),
    @("__MOD__.Tests\__MOD__.Tests.csproj.tpl", "$modName.Tests\$modName.Tests.csproj"),
    @("__MOD__.Tests\GameContractTests.cs", "$modName.Tests\GameContractTests.cs"),
    @("__MOD__.Tests\CharmRulesTests.cs", "$modName.Tests\CharmRulesTests.cs")
)
foreach ($entry in $map) {
    $source = Join-Path $templateDir $entry[0]
    $target = Join-Path $modPath $entry[1]
    $dir = Split-Path -Parent $target
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $text = Expand-Template ([System.IO.File]::ReadAllText($source))
    if ($NoCooldown -and $entry[1] -eq "README.md") {
        $text = (($text -split "`r?`n") | Where-Object { $_ -notmatch 'CooldownSeconds` \(default' }) -join "`n"
    }
    [System.IO.File]::WriteAllText($target, $text, $utf8)
}

# 4. Manifest dependencies
$manifestPath = Join-Path $modPath "manifest.json"
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
$pocketsVersion = (Get-Content (Join-Path $WorkspaceRoot "REPO-Pockets\manifest.json") -Raw | ConvertFrom-Json).version_number
$coreVersion = (Get-Content (Join-Path $WorkspaceRoot "REPO-CharmCore\manifest.json") -Raw | ConvertFrom-Json).version_number
$dependencies = @($manifest.dependencies | ForEach-Object { $_ })
$dependencies += "OsmarBriones-Pockets-$pocketsVersion"
$dependencies += "OsmarBriones-CharmCore-$coreVersion"
$manifest.dependencies = $dependencies | Select-Object -Unique
[System.IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 5), $utf8)

# 5. Build, test, commit, push
Push-Location $modPath
try {
    dotnet build -c Release 2>&1 | Select-Object -Last 4 | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Build failed; fix it before committing." }
    Push-Location "$modName.Tests"
    try {
        dotnet test 2>&1 | Select-Object -Last 3 | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Tests failed; fix them before committing." }
    } finally { Pop-Location }
    git add -A
    git commit -q -m "feat: charm scaffold from the create-charm template`n`nCo-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
    if (-not $SkipGitHub) { git push -q }
} finally { Pop-Location }

Write-Host ""
Write-Host "Charm '$modName' created: $modPath" -ForegroundColor Green
Write-Host "GitHub: https://github.com/OsmarBriones/$repoName"
Write-Host "Next: implement $effectClass.cs, fill the TODOs in README.md, ARCHITECTURE.md, the QA battery and GameContractTests.cs."
