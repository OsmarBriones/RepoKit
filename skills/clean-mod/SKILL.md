---
name: clean-mod
description: Removes compiled mod deployments (DLL, PDB, subfolders, and optional configs) from Steam and/or r2modman game directories to restore clean vanilla environments or test version transitions.
---

# Clean Mod Deployment Skill

Use this skill when the user wants to remove, clean, or undeploy compiled mod files from Steam, r2modman, or both (e.g., `/clean-mod`, `borrar mod de steam`, `limpiar copia de r2`).

---

## Background

When building R.E.P.O. mods (`dotnet build`), the MSBuild `PostBuild` target automatically copies the compiled assembly (`<ModName>.dll`) to:
1. **Steam**: `<REPO_GAME_DIR>\BepInEx\plugins\<ModName>.dll`
2. **r2modman**: `%APPDATA%\r2modmanPlus-local\REPO\profiles\<Profile>\BepInEx\plugins\<ModName>.dll`

This skill cleanly removes those deployed files without modifying the source code, repository files, or git status.

---

## Usage

### Option 1: From the Workspace Root

```powershell
$ps = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
& $ps -ExecutionPolicy Bypass -File RepoKit/skills/clean-mod/scripts/clean-mod.ps1 `
    -ModName "<ModName>" `
    [-Target All|Steam|R2] `
    [-Profile Debug|<ProfileName>|All] `
    [-IncludeConfig] `
    [-WhatIf]
```

### Option 2: From Within a Mod Directory

When running from the root of a mod repository (e.g. `StealLifeFromMonsters`), `-ModName` is automatically resolved from the `.csproj` or `manifest.json`:

```powershell
$ps = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
& $ps -ExecutionPolicy Bypass -File external/RepoKit/skills/clean-mod/scripts/clean-mod.ps1 `
    [-Target All|Steam|R2]
```

---

## Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `-ModName` | `string` | *(auto-detected)* | Name of the mod assembly to clean (e.g., `StealLifeFromMonsters`). |
| `-ModPath` | `string` | `.` | Directory containing the mod project to auto-detect its name. |
| `-Target` | `ValidateSet` | `All` | Deployment destination to clean: `All`, `Steam`, or `R2` (`R2Modman`). |
| `-Profile` | `string` | `Debug` | Target r2modman profile name. Use `*` or `All` to clean across all profiles. |
| `-IncludeConfig` | `switch` | `false` | Also removes generated config files (`BepInEx/config/*<ModName>*.cfg`). |
| `-WhatIf` | `switch` | `false` | Performs a dry-run previewing what files would be removed. |

---

## Examples

### 1. Clean from Both Steam and r2modman (Default)
```powershell
powershell -ExecutionPolicy Bypass -File RepoKit/skills/clean-mod/scripts/clean-mod.ps1 -ModName StealLifeFromMonsters
```

### 2. Clean Only Steam
```powershell
powershell -ExecutionPolicy Bypass -File RepoKit/skills/clean-mod/scripts/clean-mod.ps1 -ModName StealLifeFromMonsters -Target Steam
```

### 3. Clean Only r2modman
```powershell
powershell -ExecutionPolicy Bypass -File RepoKit/skills/clean-mod/scripts/clean-mod.ps1 -ModName StealLifeFromMonsters -Target R2
```

### 4. Clean All r2modman Profiles + Config Files
```powershell
powershell -ExecutionPolicy Bypass -File RepoKit/skills/clean-mod/scripts/clean-mod.ps1 -ModName StealLifeFromMonsters -Target R2 -Profile All -IncludeConfig
```
