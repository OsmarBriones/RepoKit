# Changelog

## [Unreleased]

- Added **Multiplayer Authority & Network Architecture Standards** in `REPO_MODS_METHODOLOGY.md` §6.2.2 and `RepoKit/skills/refine-mod-concept/SKILL.md`:
  - Formalized the 3-tier networking scope classification: Category 1 (True Host-Only), Category 2 (Client-Synced), and Category 3 (Asymmetric Hybrid / Graceful Degradation).
  - Instituted the mandatory **4-Question Network Feasibility Gate** (evaluating input hooks, native RPC serialization, state machine dimensionality, and unequip/drop lifecycle side-effects) to prevent desynchronization when designing Host-Only mods.
- Added **Multiplayer Scope Disclosure Standards in `README.md` & `manifest.json`** in `REPO_MODS_METHODOLOGY.md` §7.2.1 and `refine-mod-concept` skill:
  - Established standardized description phrasing per scope category for `manifest.json` (< 250 chars).
  - Defined the mandatory GitHub alert callout template for Category 3 (Asymmetric Hybrid) mods in `README.md` comparing Vanilla client gameplay vs. Enhanced client audiovisuals without technical engine jargon.
  - Agents must present a complete pre-release summary (including the full player-facing `README.md` content) and strictly require manual user typed confirmation (`aprobado`) before tagging/pushing releases, preventing accidental releases by forbidding clickable UI option modals (`ask_question`).
  - Added `-Confirmed` switch to `publish-mod.ps1` with interactive `Read-Host` confirmation prompt when executed manually.
- Added canonical item shop prices and economics reference in `RepoKit/references/item-prices.md`:
  - Documents all 59+ game items with their English/Spanish names, internal keys, categories, base `[valueMin, valueMax]` ranges, and resulting shop price ranges (`$K`).
  - Formalizes shop pricing formulas from `ItemAttributes` and `ShopManager`, including dynamic scaling rules for player upgrades (+50% per purchase), health packs (+5% per level), and power crystals (+20% per level).
- Added `refine-mod-concept` skill (`RepoKit/skills/refine-mod-concept/SKILL.md`):
  - Cyclical Q&A clarification loop to refine raw mod ideas into unambiguous specifications (gameplay, networking, config, audio/visual feel, edge cases, naming).
- Added `create-mod` skill (`RepoKit/skills/create-mod/SKILL.md`) and automation script `create-mod.ps1`:
  - Scaffolds mod from `repo_mod_template` with `dotnet new repo-mod`.
  - Automatically initializes Git (`master`), links `RepoAPI` and `RepoKit` git submodules, and creates public GitHub repository with `THUNDERSTORE_TOKEN` secret.
- Added `develop-mod` skill (`RepoKit/skills/develop-mod/SKILL.md`):
  - Autonomous end-to-end mod development cycle using Spec-Kit (`plan.md`, `tasks.md`, C# code implementation, Harmony hooking, iterative compilation, and documentation updates).
  - Designed for autonomous technical execution, escalating only design/gameplay ambiguities or irreconcilable blockers to the human developer.
- Established **Cross-Platform & Multi-Machine Portability Policy** in `REPO_MODS_METHODOLOGY.md` §12 and `REPO_MODS_WORKSPACE.md`:
  - Enforced dynamic PowerShell engine resolution (`pwsh` preferred, fallback to `powershell`) across all scripts and skills.
  - Mandated path neutrality (no hardcoded personal absolute paths, cross-platform slashes and `Join-Path`).
  - Required graceful degradation for optional tools and environment tokens.
- Fixed UTF-8 BOM emission in `publish-mod.ps1` and `package-mod.ps1` by enforcing `[System.Text.UTF8Encoding]::new($false)` to prevent Thunderstore HTTP 400 rejection on `CHANGELOG.md` and `manifest.json`.
- Architected GitHub Actions release bridge in `publish.yml` and `publish-mod.ps1`: locally packages verified mod zip with game assemblies, creates GitHub Release, and delegates cloud Thunderstore publishing to GitHub Actions via release asset download.
- Improved working tree hygiene in `publish-mod.ps1` by generating `thunderstore.toml` strictly inside `dist/` only during `-LocalPublish`, wrapped in a guaranteed `try ... finally` cleanup block, and adding `thunderstore.toml` to `.gitignore` templates to prevent untracked artifacts.
- Implemented automatic Thunderstore category inference and synchronization (`categories.txt`):
  - Automatically deduces community category slugs (`mods`, `monsters`, `serverside`, `clientside`, `ai-generated`, `quality-of-life`, etc.) based on mod code, architecture, and asset analysis.
  - Passes categories to `GreenTF/upload-thunderstore-package` in `publish.yml` and injects them into `thunderstore.toml` for `-LocalPublish`, eliminating manual category editing on Thunderstore.
- Added `clean-mod` skill (`RepoKit/skills/clean-mod/SKILL.md`) and automation script `clean-mod.ps1`:
  - Removes compiled mod deployment copies (`.dll`, `.pdb`, folders, and optional `.cfg` configs) from Steam and/or r2modman game directories.
  - Supports configurable targeting via `-Target All` (default), `-Target Steam`, or `-Target R2` (with `-Profile <Name>|All`).
- Added root workspace skill entry points under `.agents/skills/create-mod/`, `.agents/skills/refine-mod-concept/`, `.agents/skills/develop-mod/`, and `.agents/skills/clean-mod/`.

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
