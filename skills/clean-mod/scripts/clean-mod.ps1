<#
.SYNOPSIS
    Removes compiled mod deployments from Steam and r2modman game directories.

.DESCRIPTION
    PostBuild MSBuild targets automatically deploy compiled mod assemblies to:
      1. Steam: <REPO_GAME_DIR>\BepInEx\plugins\<ModName>.dll
      2. r2modman: %APPDATA%\r2modmanPlus-local\REPO\profiles\<Profile>\BepInEx\plugins\<ModName>.dll

    This script cleans up those copies so developers can test clean vanilla states,
    switch between development versions, or completely remove a mod from game installations.

.PARAMETER ModPath
    Path to the mod project directory (e.g. '.', 'StealLifeFromMonsters').
    Defaults to current directory. Used to resolve ModName if -ModName is omitted.

.PARAMETER ModName
    Explicit name of the mod to clean (e.g. 'StealLifeFromMonsters').
    If omitted, auto-detected from .csproj or manifest.json in ModPath.

.PARAMETER Target
    Where to remove the mod from:
      - 'All' (default): Cleans both Steam and r2modman.
      - 'Steam': Cleans only the Steam BepInEx installation.
      - 'R2' or 'R2Modman': Cleans only the r2modman profile installation.

.PARAMETER Profile
    Target r2modman profile name (default 'Debug').
    Use '*' or 'All' to clean across all r2modman profiles.

.PARAMETER IncludeConfig
    Switch to also delete generated configuration files (*<ModName>*.cfg)
    from BepInEx/config directories.

.PARAMETER WhatIf
    Previews which files and directories would be removed without deleting them.

.EXAMPLE
    # Clean both Steam and r2modman Debug copies for the mod in current folder
    powershell -ExecutionPolicy Bypass -File RepoKit/skills/clean-mod/scripts/clean-mod.ps1

.EXAMPLE
    # Clean only from Steam for a specific mod
    powershell -ExecutionPolicy Bypass -File RepoKit/skills/clean-mod/scripts/clean-mod.ps1 -ModName StealLifeFromMonsters -Target Steam

.EXAMPLE
    # Clean only from r2modman and remove config files as well
    powershell -ExecutionPolicy Bypass -File RepoKit/skills/clean-mod/scripts/clean-mod.ps1 -ModName StealLifeFromMonsters -Target R2 -IncludeConfig
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$ModPath = ".",

    [Parameter(Position = 1)]
    [string]$ModName,

    [Parameter()]
    [ValidateSet("All", "Steam", "R2", "R2Modman")]
    [string]$Target = "All",

    [Parameter()]
    [string]$Profile = "Debug",

    [Parameter()]
    [switch]$IncludeConfig,

    [Parameter()]
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

# 1. Resolve ModName
$resolvedPath = Resolve-Path $ModPath -ErrorAction SilentlyContinue
if (-not $resolvedPath) {
    $resolvedPath = $ModPath
}

if ([string]::IsNullOrWhiteSpace($ModName)) {
    # Try finding .csproj in ModPath
    $csprojFiles = Get-ChildItem -Path $resolvedPath -Filter "*.csproj" -ErrorAction SilentlyContinue
    if ($csprojFiles -and $csprojFiles.Count -gt 0) {
        $csprojContent = [xml](Get-Content $csprojFiles[0].FullName)
        $assemblyNameNode = $csprojContent.SelectSingleNode("//AssemblyName")
        if ($assemblyNameNode -and -not [string]::IsNullOrWhiteSpace($assemblyNameNode.InnerText)) {
            $ModName = $assemblyNameNode.InnerText.Trim()
        } else {
            $ModName = [System.IO.Path]::GetFileNameWithoutExtension($csprojFiles[0].FullName)
        }
    }

    # Fallback to manifest.json name
    if ([string]::IsNullOrWhiteSpace($ModName)) {
        $manifestPath = Join-Path $resolvedPath "manifest.json"
        if (Test-Path $manifestPath) {
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
            if ($manifest.name) {
                $ModName = $manifest.name
            }
        }
    }

    # Fallback to folder name
    if ([string]::IsNullOrWhiteSpace($ModName)) {
        $ModName = Split-Path $resolvedPath -Leaf
    }
}

if ([string]::IsNullOrWhiteSpace($ModName)) {
    throw "Could not determine ModName. Please specify -ModName <ModName>."
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  R.E.P.O. Clean Mod Deployment" -ForegroundColor Cyan
Write-Host "  Mod Name : $ModName" -ForegroundColor Yellow
Write-Host "  Target   : $Target" -ForegroundColor Yellow
Write-Host "  Profile  : $Profile" -ForegroundColor Yellow
if ($IncludeConfig) {
    Write-Host "  Config   : Included (*$ModName*.cfg)" -ForegroundColor Yellow
}
if ($WhatIf) {
    Write-Host "  Mode     : WhatIf (dry run)" -ForegroundColor Magenta
}
Write-Host "==========================================================" -ForegroundColor Cyan

$deletedCount = 0

# Helper to remove item safely
function Remove-ModItem {
    param(
        [string]$Path,
        [string]$Description
    )
    if (Test-Path $Path) {
        if ($WhatIf) {
            Write-Host "    [WHAT-IF] Would remove $Description : $Path" -ForegroundColor Magenta
        } else {
            try {
                Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
                Write-Host "    [REMOVED] $Description : $Path" -ForegroundColor Green
                $script:deletedCount++
            } catch {
                Write-Warning "Failed to remove $($Path): $_"
            }
        }
    }
}

# 2. Clean Steam Deployment
$cleanSteam = ($Target -eq "All" -or $Target -eq "Steam")
if ($cleanSteam) {
    Write-Host "`n--> Checking Steam installation..." -ForegroundColor Cyan
    $steamDirs = @()
    if ($env:REPO_GAME_DIR) {
        $steamDirs += $env:REPO_GAME_DIR
    }
    $steamDirs += "C:\Program Files (x86)\Steam\steamapps\common\REPO"
    $steamDirs += "C:\Program Files\Steam\steamapps\common\REPO"

    $foundSteam = $false
    foreach ($sDir in ($steamDirs | Select-Object -Unique)) {
        if (Test-Path $sDir) {
            $foundSteam = $true
            $pluginsDir = Join-Path $sDir "BepInEx\plugins"
            if (Test-Path $pluginsDir) {
                # Target DLL & PDB
                Remove-ModItem -Path (Join-Path $pluginsDir "$ModName.dll") -Description "Steam Plugin DLL"
                Remove-ModItem -Path (Join-Path $pluginsDir "$ModName.pdb") -Description "Steam Plugin PDB"
                # Target subfolder if any
                $modFolder = Join-Path $pluginsDir $ModName
                if (Test-Path $modFolder) {
                    Remove-ModItem -Path $modFolder -Description "Steam Plugin Folder"
                }
            } else {
                Write-Host "    Steam BepInEx\plugins directory not found at: $sDir" -ForegroundColor Gray
            }

            # Config files
            if ($IncludeConfig) {
                $configDir = Join-Path $sDir "BepInEx\config"
                if (Test-Path $configDir) {
                    Get-ChildItem -Path $configDir -Filter "*$ModName*.cfg" -ErrorAction SilentlyContinue | ForEach-Object {
                        Remove-ModItem -Path $_.FullName -Description "Steam Config File"
                    }
                }
            }
        }
    }

    if (-not $foundSteam) {
        Write-Host "    No Steam REPO installation detected." -ForegroundColor Gray
    }
}

# 3. Clean r2modman Deployment
$cleanR2 = ($Target -eq "All" -or $Target -eq "R2" -or $Target -eq "R2Modman")
if ($cleanR2) {
    Write-Host "`n--> Checking r2modman installation..." -ForegroundColor Cyan
    $appData = if ($env:APPDATA) { $env:APPDATA } else { [Environment]::GetFolderPath("ApplicationData") }
    $r2ProfilesRoot = Join-Path $appData "r2modmanPlus-local\REPO\profiles"

    if (Test-Path $r2ProfilesRoot) {
        $targetProfiles = @()
        if ($Profile -eq "*" -or $Profile -eq "All") {
            $targetProfiles = Get-ChildItem -Path $r2ProfilesRoot -Directory | Select-Object -ExpandProperty Name
        } else {
            $targetProfiles = @($Profile)
        }

        foreach ($pName in $targetProfiles) {
            $profilePath = Join-Path $r2ProfilesRoot $pName
            if (Test-Path $profilePath) {
                Write-Host "    Profile [$pName]:" -ForegroundColor DarkCyan
                $pluginsDir = Join-Path $profilePath "BepInEx\plugins"
                if (Test-Path $pluginsDir) {
                    Remove-ModItem -Path (Join-Path $pluginsDir "$ModName.dll") -Description "r2modman [$pName] Plugin DLL"
                    Remove-ModItem -Path (Join-Path $pluginsDir "$ModName.pdb") -Description "r2modman [$pName] Plugin PDB"
                    $modFolder = Join-Path $pluginsDir $ModName
                    if (Test-Path $modFolder) {
                        Remove-ModItem -Path $modFolder -Description "r2modman [$pName] Plugin Folder"
                    }
                }

                if ($IncludeConfig) {
                    $configDir = Join-Path $profilePath "BepInEx\config"
                    if (Test-Path $configDir) {
                        Get-ChildItem -Path $configDir -Filter "*$ModName*.cfg" -ErrorAction SilentlyContinue | ForEach-Object {
                            Remove-ModItem -Path $_.FullName -Description "r2modman [$pName] Config File"
                        }
                    }
                }
            } else {
                Write-Host "    Profile [$pName] does not exist." -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "    No r2modman REPO profiles directory detected at: $r2ProfilesRoot" -ForegroundColor Gray
    }
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
if ($WhatIf) {
    Write-Host "  WhatIf summary complete." -ForegroundColor Magenta
} elseif ($deletedCount -gt 0) {
    Write-Host "  SUCCESS: Removed $deletedCount deployed item(s) for $ModName." -ForegroundColor Green
} else {
    Write-Host "  INFO: No deployed copies of $ModName found in target location(s)." -ForegroundColor Yellow
}
Write-Host "==========================================================" -ForegroundColor Cyan
