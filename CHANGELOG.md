# Changelog

## 1.7.0 — 2026-09-25

- Formalized distinction between human developer Author name (`Osmar Briones`) and technical reverse-DNS identifier (`com.osmar`) in `REPO_MODS_METHODOLOGY.md` §7.1 and `REPO_MODS_WORKSPACE.md`:
  - Developer name (`Osmar Briones`): used in `README.md` credits, `<Authors>` tag in `.csproj`, and packaging metadata.
  - Technical reverse-DNS ID (`com.osmar`): reserved exclusively for BepInEx `PluginGuid`, config file names (`BepInEx/config/com.osmar.<ModName>.cfg`), and code namespaces.
- Established documentation audience separation in `REPO_MODS_METHODOLOGY.md` §7.2:
  - `README.md` is Thunderstore player-facing: the `## Features` section must focus purely on player experience and gameplay mechanics in accessible language.
  - Internal Unity engine terminology, hook/patch targets (`EnemyDirector.Start`, `TruckSafetySpawnPoint`, etc.), and code architecture are strictly forbidden in `README.md` and belong in `ARCHITECTURE.md`.
- Updated `skills/package-mod` checklist and `package-mod.ps1` script to validate `<Authors>` metadata and warn on `com.osmar` or unreplaced template placeholders in `README.md`.

## 1.6.0 — 2026-09-25

- Added shared agent skills in `skills/`:
  - `package-mod`: Thunderstore package automation and pre-release validation (`manifest.json`, `icon.png`, `README.md`, `CHANGELOG.md`, `.dll`).
  - `generate-thumbnail`: 256x256 mod icon generation via multimodal prompt (`generate_image`) or procedural hazard badge script.
- Documented level lifecycle hooks in `REPO_MODS_METHODOLOGY.md` §6.2.1 (`EnemyDirector.Start` vs `RoundDirector.StartRoundLogic`).
- Documented Spec Kit development and constitution binding in `REPO_MODS_METHODOLOGY.md` §7.1.

## 1.5.0 — 2026-09-25

- Defined the workspace modern coding standards in `REPO_MODS_METHODOLOGY.md` §6
  (no `_` or `s_` prefixes, clean PascalCase/camelCase, `internal` scoping by
  default, modern C# idioms, and BepInEx logging rules).
- Updated `REPO_MODS_WORKSPACE.md` coordination rules to enforce §6 coding standards.

## 1.4.0 — 2026-09-25

- Defined the workspace testing strategy in `REPO_MODS_METHODOLOGY.md` §8
  (Tier 1: decoupled unit tests via `dotnet test`, Tier 2: Harmony reflection
  contract verification, Tier 3: in-game test harness / fast debug triggers).
- Updated `REPO_MODS_WORKSPACE.md` testing decision and migration status.

## 1.3.0 — 2026-09-25

- Renamed the repository from `repo-mods-guidance` to `RepoKit`, consistent
  with `RepoAPI`. Consuming mods must re-register the submodule at
  `external/RepoKit` (GitHub redirects the old clone URL, but the local path
  and `.gitmodules` entry must be updated by hand).

## 1.2.0 — 2026-09-25

- Documented the exact once-per-task synchronization commands.

## 1.1.0 — 2026-09-25

- Added the mandatory once-per-task shared-guidance synchronization gate.

## 1.0.0 — 2026-09-25

- Established the dedicated repository for REPO Mods shared guidance.
- Added the workspace context, development methodology, version marker, and
  cross-project documentation maintenance rules.
- Defined the once-per-task guidance synchronization gate for consuming mods.
