---
name: package-mod
description: Prepares, validates, and packages a R.E.P.O. mod into a Thunderstore-compliant release zip archive. Verifies manifest.json, README.md, icon.png (256x256), and compiled .dll.
---

# Package Mod (Thunderstore Release)

This skill guides agents through validating and packaging a R.E.P.O. BepInEx mod into a distribution zip ready for upload to [Thunderstore](https://thunderstore.io/).

---

## Thunderstore Package Requirements

A valid Thunderstore mod package is a flat `.zip` file containing the following files **at its root** (no nesting inside an extra folder):

File | Requirement | Description
:--- | :--- | :---
`manifest.json` | Mandatory | Package metadata (name, version, description <= 250 chars, dependencies).
`icon.png` | Mandatory | Exactly **256x256** pixels, square PNG format, < 256 KB.
`README.md` | Mandatory | Markdown description of the mod, features, install instructions, and config.
`<ModName>.dll` | Mandatory | Compiled BepInEx assembly targeting `.NET Framework 4.8`.
`CHANGELOG.md` | Recommended | Version history notes (mandatory per `RepoKit` methodology).

---

## Pre-Release Validation Checklist

Before building and packaging, ensure the following fields are synchronized:

1. **Version alignment:** Verify that the version matches in:
   - `<Version>` tag in `[ModName].csproj`
   - `"version_number"` in `manifest.json` (SemVer `X.Y.Z`)
   - `PluginVersion` constant in `[ModName]Plugin.cs`
   - Top entry in `CHANGELOG.md`
2. **Manifest rules:**
   - `"name"`: Only alphanumeric characters and underscores (`[a-zA-Z0-9_]`). No hyphens or spaces!
   - `"description"`: Maximum 250 characters.
   - `"dependencies"`: Array of Thunderstore package strings (e.g. `["BepInEx-BepInExPack-5.4.2100"]`).
3. **Icon requirements:**
   - Must be exactly 256x256 pixels. If missing or different size, use the `generate-thumbnail` skill.

---

## Workflow

### Option 1: Automated Script Execution (Recommended)

Run the bundled packaging script from PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File external/RepoKit/skills/package-mod/scripts/package-mod.ps1 `
  -ModPath . `
  -Configuration Release
```

**Parameters:**
- `-ModPath`: Root directory of the mod (defaults to `.`).
- `-Configuration`: `Release` (default) or `Debug`.
- `-SkipBuild`: Optional switch if the mod was already built.
- `-OutputDir`: Custom destination folder (defaults to `<ModPath>/dist`).

The script automatically:
1. Builds the project via `dotnet build -c Release`.
2. Validates `manifest.json` schema and description length.
3. Checks `icon.png` dimensions using `System.Drawing`.
4. Stages files into a temporary clean folder.
5. Emits `dist/<ModName>-<Version>.zip`.

### Option 2: MSBuild Target (`dotnet build`)

Every mod built from `repo_mod_template` includes a `PackThunderstore` MSBuild target:

```bash
dotnet build -c Release
```

This target builds the `.dll` and outputs the package archive directly to `dist/<ModName>.zip`.

---

## Output Verification

After packaging, verify the archive structure:

```powershell
tar -tf dist/*.zip
# Or in PowerShell:
[System.IO.Compression.ZipFile]::OpenRead((Resolve-Path dist/*.zip)).Entries | Select-Object FullName, Length
```

Ensure no files are placed in subfolders within the archive.
