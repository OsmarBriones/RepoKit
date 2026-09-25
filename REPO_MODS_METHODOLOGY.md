# REPO Mods — Development Methodology

This document defines the standard architecture, folder layout, and conventions for every mod in this workspace. It replaces the ad-hoc structure that grew from copy-pasting a template repeatedly and hand-copying shared code between mods.

## 1. Scope and principles

- **Each mod is an independent, standalone project**, with its own git repository. A mod repo must build on its own after a normal `git clone` (with submodule support configured once, see §4).
- `REPO_Mods/` (this folder) is **not** a git repo. It is a plain working directory that groups sibling projects on this machine.
- Shared code lives in one place — `RepoAPI` — which is itself an independent repo. Other mods consume it via a git submodule, compiling in only the modules they need (see §4). No more hand-copied `ItemProvider.cs` / `ConfigurationController.cs` / etc. across mods.

## 2. Workspace layout

```
REPO_Mods/
├── EnemyDrops/                 (independent git repo)
├── ExtractionPointReward/      (independent git repo)
├── TumbleAttackStun/           (independent git repo)
├── StartWithRandomWeapon/      (independent git repo)
├── RepoAPI/                    (independent git repo — shared library)
├── repo_mod_template/          (independent git repo — dotnet new template)
├── RepoKit/                     (independent git repo — canonical shared guidance)
│   ├── REPO_MODS_WORKSPACE.md
│   ├── REPO_MODS_METHODOLOGY.md
│   ├── VERSION.md
│   └── CHANGELOG.md
├── AGENTS.md / GEMINI.md / CLAUDE.md
│                               (workspace compatibility entry points)
├── reference/                  (not a git repo — read-only reference material)
│   ├── decompiled/             (ex repo_decompiled_code)
│   └── assets/                 (ex repo_assets_extracted)
└── sandbox/                    (not a git repo — throwaway/experimental code)
    ├── Test1/
    ├── Test3/
    └── useful_classes/
```

## 3. Standard mod repository layout

Every mod repo follows this shape. Only include the sub-folders a given mod actually needs (don't create an empty `Configuration/` if the mod has no config).

```
<ModName>/                          (repo root — no <ModName>/<ModName>/ nesting)
├── .git/
├── .gitignore
├── Directory.Build.props           local to this repo: env-var based game paths, TFM, LangVersion
├── <ModName>.sln
├── <ModName>.csproj
├── AGENTS.md                     canonical local context for all coding agents
├── GEMINI.md / CLAUDE.md          compatibility entry points; point to AGENTS.md
├── <ModName>Plugin.cs               BepInEx entry point — thin, wiring only
├── manifest.json
├── icon.png
├── README.md                        Thunderstore-facing description
├── CHANGELOG.md
├── ARCHITECTURE.md                  the "why" — runtime data flow, design decisions
├── CLAUDE.md                        the "how" — build commands, env vars, cross-references
├── Configuration/                   config binding, only if the mod has config
├── Patches/                         one file per patched method
├── <DomainFolder>/                  mod-specific logic only (never duplicate RepoAPI code here)
└── external/
    └── RepoAPI/                     git submodule, see §4
```

Root cause of the historic `<ModName>/<ModName>/` doubling: `repo_mod_template/RepoModTemplate/.template.config/template.json` has `"preferNameDirectory": true`. **Fix: set it to `false`** so `dotnet new repo-mod -n X -o X` doesn't nest.

## 4. Shared code: RepoAPI

**Decision:** git submodule + `<Compile Include>` of only the needed module folders. No `ProjectReference`, no separate `RepoAPI.dll`, no merge step (an earlier version of this plan used `ProjectReference` + an `ILRepack` publish-time merge — abandoned: it meant two assemblies during development, a real bug hunt around ILRepack's own auto-merge target and assembly-resolution paths, and Debug builds needing two DLLs deployed together. Compiling the needed source directly into the mod's own assembly avoids all of that, at the cost of RepoAPI's `internal` members not being enforced across the mod boundary — an acceptable trade for a single-developer workspace).

Rationale for the submodule (over a hand-copied `.dll` or NuGet): mods actively co-evolve with RepoAPI (generic logic discovered while building a mod gets promoted into RepoAPI), so the dev loop needs to be "edit → build" with no manual compile-and-copy step, and no publish/versioning overhead.

### One-time setup (per machine)

```bash
git config --global submodule.recurse true
```

This makes `clone`, `pull`, and `checkout` handle submodules automatically, avoiding the classic "empty submodule folder" trap.

### Per mod, one-time setup

```bash
git submodule add <RepoAPI-repo-url> external/RepoAPI
```

In the mod's `.csproj`, exclude the submodule from the implicit glob, then include only the module folders/files this mod needs (see `RepoAPI/README.md` for the module dependency graph):

```xml
<ItemGroup>
  <Compile Remove="external\**" />
  <EmbeddedResource Remove="external\**" />
  <None Remove="external\**" />

  <Compile Include="external\RepoAPI\Items\**\*.cs" />
  <Compile Include="external\RepoAPI\Game\**\*.cs" />
</ItemGroup>
```

A module is "a folder that compiles as a self-contained unit." Some modules depend on others (e.g. `Items/` needs `Game/`) — include the whole dependency chain; the compiler errors clearly on a missing type if you forget one. Prefer whole-folder includes; fall back to specific files (like `EnemyDrops.csproj` does for `Items/`) only when the folder also contains files that would pull in an unwanted extra dependency.

### Day-to-day workflow

1. Work on the mod as usual.
2. When something belongs in RepoAPI instead (generic, reusable), edit it directly under `external/RepoAPI/` — it's a real checkout of the RepoAPI repo. A normal rebuild of the mod picks up the change immediately, same as any other local file.
3. Once happy, commit and push **inside `external/RepoAPI/`** (it's its own repo), then commit the updated submodule pointer in the mod's repo (`git add external/RepoAPI && git commit`).
4. To pull RepoAPI improvements made from another mod: `git submodule update --remote external/RepoAPI` inside the mod repo, then commit the pointer bump.

Since there's no separate `RepoAPI.dll` at any point, there's nothing to merge and nothing to internalize — the shipped `<ModName>.dll` is a single file by construction, and `manifest.json` never lists RepoAPI as a Thunderstore dependency.

## 5. Build configuration per mod

Each repo carries its **own** `Directory.Build.props` (not shared across repos, so the repo stays self-sufficient on any machine):

```xml
<Project>
  <PropertyGroup>
    <TargetFramework>net48</TargetFramework>
    <LangVersion>latest</LangVersion>
    <Nullable>enable</Nullable>
    <RepoRootPath Condition="'$(REPO_GAME_DIR)' != ''">$(REPO_GAME_DIR)</RepoRootPath>
    <RepoRootPath Condition="'$(RepoRootPath)' == ''">C:\Program Files (x86)\Steam\steamapps\common\REPO</RepoRootPath>
    <RepoManaged>$(RepoRootPath)\REPO_Data\Managed</RepoManaged>
    <RepoBepInExCore>$(RepoRootPath)\BepInEx\core</RepoBepInExCore>
  </PropertyGroup>
</Project>
```

This replaces both the unused root `Directory.Repo.props` and the fragile 9-level `..\..\..\` relative `HintPath`s found in `EnemyDrops.csproj`. Every mod targets **`net48`** — `EnemyDrops` is the current outlier on `netstandard2.1` and should be aligned.

`PostBuild` keeps copying to the BepInEx `plugins` folder and the r2modman debug profile(s); `PackThunderstore` keeps building the Thunderstore zip — both write to a `dist/`-style folder that stays out of git (see §6).

## 6. Coding standards and conventions

All mods and shared libraries follow modern, idiomatic C# conventions. The goal is clean, readable code that avoids legacy prefixes and Hungarian notation.

### 6.1 Naming and case rules

- **No Hungarian or scope prefixes:**
  - **No underscore prefix for private/protected members:** Use `logger`, `config`, `itemTable` (never `_logger`, `_config`).
  - **No static prefixes:** Use `dropsThisLevel`, `instance`, `defaultDropChance` (never `s_dropsThisLevel`, `sInstance`, or `m_`).
  - **No type prefixes:** Avoid `strName`, `iCount`, `bEnabled`. Let strong typing do the work.
- **PascalCase:**
  - Types: classes, structs, enums, interfaces, records (`EnemyDeathHandler`, `ItemName`).
  - Methods and local functions (`TrySpawnItem`, `ReloadConfig`).
  - Properties (`public ConfigFile Config { get; }`, `internal static ManualLogSource Logger { get; }`).
  - Constants and `public static readonly` values (`DefaultDropRate`).
  - Namespaces and file names.
- **camelCase:**
  - Private and internal instance fields (`dropRate`, `trackedEnemies`).
  - Private and internal static fields (`dropsThisLevel`, `cachedInstance`).
  - Method parameters and lambda parameters (`enemyHealth`, `itemKey`).
  - Local variables (`spawnPosition`, `randomItem`).
- **Interfaces:** Prefix with `I` (`IItemProvider`, `IConfigProvider`).
- **Enums:** PascalCase for enum name and elements. Use singular names unless the enum represents bit flags (`ItemName`, `ItemCategory`).

### 6.2 Mod and Harmony patterns

- **Patch files:** One file per patched method: `<TargetType>_<TargetMethod>_Patch.cs` (e.g. `EnemyHealth_Awake_Patch.cs`, `EnemyDirector_Start_Patch.cs`).
- **Patch methods:** Standard Harmony method names: `Prefix`, `Postfix`, `Transpiler`, `Finalizer`.
- **Harmony parameters:** Harmony-injected parameters use Harmony's required syntax (`__instance`, `__result`, `__state`, `___field`), but all custom/mod-defined variables and arguments must follow standard `camelCase`.
- **Early guard clauses:** Check authority and level lifecycle at the top of patches:
  ```csharp
  if (!SemiFunc.RunIsLevel()) return;
  if (!SemiFunc.IsMasterClientOrSingleplayer()) return;
  ```
- **Namespaces:**
  - Mod: `<ModName>`, `<ModName>.Patches`, `<ModName>.Configuration`, `<ModName>.<Domain>`.
  - RepoAPI: `RepoAPI.<Area>` (e.g. `RepoAPI.Items`, `RepoAPI.Game`, `RepoAPI.ModConfig`).

### 6.2.1 Level lifecycle and generation hooks

R.E.P.O. levels are generated procedurally over multiple frames via `LevelGenerator`. Mod authors must choose their lifecycle hooks carefully based on which game objects they depend on:

1. **Scene Load / Frame 0 (`EnemyDirector.Start` Postfix):**
   - **Timing:** Executes immediately when Unity loads the level scene assets, *before* procedural dungeon rooms or the truck are instantiated.
   - **Appropriate for:** Resetting in-memory state, per-level drop counters, or refreshing static configurations.
   - **Do NOT use for:** Interacting with dungeon geometry, truck objects, or searching for `TruckSafetySpawnPoint.instance` (it will be `null`).

2. **Procedural Generation Complete (`RoundDirector.StartRoundLogic` or `SemiFunc.OnLevelGenDone` Postfix):**
   - **Timing:** Executes once `LevelGenerator.Instance.Generated == true`, after all rooms, the truck, extraction points, and player spawn points are instantiated.
   - **Appropriate for:** Spawning starting items, placing world objects, anchoring items to `TruckSafetySpawnPoint.instance`, or querying level rooms and player avatars.

### 6.3 Scoping and encapsulation

- **Default to `internal` or `private`:** Only the BepInEx entry point (`[BepInPlugin]`) must be `public`. All other classes, structs, helpers, and patches inside a mod should be `internal` or `private` to avoid polluting the global Unity assembly namespace.
- **Properties over public fields:** Prefer auto-properties with appropriate accessors (`internal static ManualLogSource Logger { get; private set; }`).
- **RepoAPI code:** Reusable types in `RepoAPI` use `public` so they are accessible when compiled into consuming mod projects.

### 6.4 Modern C# idioms (`net48` + `LangVersion latest`)

- **Nullable reference types (`Nullable enable`):** Declare nullability intent explicitly (`string?`, `Enemy?`). Avoid blanket `!` suppression unless safely assigned in lifecycle (`Awake`).
- **Expression-bodied members:** Preferred for single-line methods, read-only properties, and simple getters:
  ```csharp
  internal bool HasBattery => maxBattery > 0;
  ```
- **Pattern matching & modern null checks:** Prefer `is not null`, `is null`, and switch expressions over nested `null` checks and type casts.
- **Implicit typing (`var`):** Use `var` when the type is obvious from the right-hand side (`var tracker = new EnemyTracker()`); use explicit types when the return type is non-obvious.

### 6.5 Logging

- Always log through BepInEx's `ManualLogSource` (`Logger.LogInfo()`, `LogWarning()`, `LogError()`, `LogDebug()`).
- Never use `Console.WriteLine` or raw `UnityEngine.Debug.Log`.

## 7. Documentation standard (mandatory per mod)

- `REPO_MODS_WORKSPACE.md` is the canonical shared context for
  Claude Code, Codex, Gemini CLI, and Antigravity. `CLAUDE.md`, `AGENTS.md`,
  and `GEMINI.md` are deliberately small entry points that refer to it; do not
  duplicate workspace rules across those files.
- `README.md`, `CHANGELOG.md`, `manifest.json`, `icon.png` — Thunderstore-facing.
- `ARCHITECTURE.md` — the *why*: runtime data flow, design decisions. Use `EnemyDrops/ARCHITECTURE.md` as the template; it is already the best example in the workspace.
- Every independent repository has its own `AGENTS.md` as its canonical local
  context. Its `GEMINI.md` and `CLAUDE.md` files are small compatibility entry
  points that point to `AGENTS.md`; do not duplicate the local rules. The local
  context contains only the *how* unique to that project: build commands,
  environment variables, cross-references to `ARCHITECTURE.md`, and its
  project-specific invariants.
- A pre-existing, detailed `CLAUDE.md` may temporarily remain the canonical
  local context while `AGENTS.md` and `GEMINI.md` point to it. EnemyDrops uses
  this compatibility arrangement; migrate it only when its local context is
  otherwise being revised.
- A local context must let a freshly cloned repository be worked on without
  depending on this workspace folder. When the repository is checked out under
  `REPO_Mods/`, it additionally follows the `RepoKit` submodule for shared
  conventions and cross-project coordination.
- `repo_mod_template` includes these agent entry points so newly generated mods
  start with their own local context.
- Documentation is maintained with the implementation: update the workspace
  context, methodology, architecture, README, changelog, and local agent
  guidance whenever the change makes any of them inaccurate. See the
  multi-agent completion checklist in `REPO_MODS_WORKSPACE.md`.

### 7.1 Spec-driven development (Spec Kit)

When using Spec Kit for feature development in mod repositories:
- `.specify/memory/constitution.md` serves as the non-negotiable governing law that binds Spec Kit to `RepoKit` standards (§6 Coding standards, §8 Testing tiers, and host-only authority).
- Feature-specific documentation resides in `specs/<feature-name>/` (`spec.md`, `plan.md`, `tasks.md`).
- Repository-level documentation (`ARCHITECTURE.md`, `README.md`, `CHANGELOG.md`) must be kept synchronized with each implemented feature as part of the phase tasks.

## 8. Testing strategy

Testing mods for a closed-source, real-time Unity game with multiplayer networking (Photon PUN 2) and Steam dependencies requires a pragmatic, multi-tier strategy. Full automated end-to-end (E2E) testing via game binary execution is slow, fragile, and constrained by Steamworks initialization and networking handshakes. Instead, mods follow a 3-tier testing approach:

### Tier 1: Decoupled Unit Tests (Off-game / `dotnet test`)
- Pure business logic, drop probability tables, configuration validation, enum mappings, and mathematical algorithms should be decoupled from Unity `MonoBehaviour` and `PhotonNetwork` whenever possible.
- Tested using MSTest or NUnit in a companion test project (like `RepoAPI.Test/`).
- Runs in milliseconds via `dotnet test` without needing the game installed or launched.

### Tier 2: Harmony Contract & Reflection Verification
- Game updates frequently rename or change parameter types on internal methods in `Assembly-CSharp.dll`, causing Harmony patches to fail silently at runtime.
- Use reflection tests to verify that every `[HarmonyPatch]` target class, method, and signature actually exists in the referenced game assemblies.
- Catches breaking game updates instantly during build/test before launching the game.

### Tier 3: In-Game Smoke Testing & Optional Debug Triggers
- **Default for most mods:** Simple in-game observation. After `PostBuild` deploys the DLL to the r2modman `Debug` profile, launch R.E.P.O. and test the mod during normal gameplay. Most mods do **not** need custom test code or hotkeys.
- **Optional (opt-in only, disabled by default):** If a mod involves mechanics that are difficult or time-consuming to trigger naturally (e.g. rare enemy encounters, high-level extraction states), developers *may* optionally add debug shortcuts:
  - Guarded strictly behind debug checks (e.g., `#if DEBUG` or `DebugMode = false` by default in config) so release builds are never polluted.
  - Can simulate the event (e.g. triggering an artificial enemy death or extraction event) to speed up manual iteration.
  - Emit structured log messages to `BepInEx/LogOutput.log` to confirm execution.
- **Rule:** Do not burden new or simple mods with debug hotkeys or test harness boilerplate. Keep mods lean by default.

### Why full headless E2E is avoided
- Running `REPO.exe -batchmode -nographics` can bypass rendering, but proprietary game initialization (Steamworks `SteamAPI.Init()` and Photon networking handshakes) makes fully headless CI/CD execution unreliable. Tier 1 + 2 provide automated regression safety, while Tier 3 manual verification is sufficient for in-game behavior.

## 9. Git hygiene

- One repo per mod. No repo nested inside another mod's folder.
- No `<ModName>/<ModName>/` doubling (fix the template, see §3).
- `.gitignore` must exclude build outputs: `bin/`, `obj/`, `.vs/`, `dist/`, `*.dll`, `*.zip`. Today several mods have their built `.dll`/`.zip` committed under `zip/`, `ts_build/`, `Thunderstore/` — these are regenerated by the build, not source, and should stop being tracked.

## 10. Reference and sandbox material

- `reference/` — read-only material used to understand game internals: decompiled source (ex `repo_decompiled_code`) and extracted assets (ex `repo_assets_extracted`). Not a git repo, not shipped, documented once via the `REPO_DECOMPILED` / `REPO_ASSETS` environment variables so every mod's `CLAUDE.md` can point at the same explanation instead of repeating it.
- `sandbox/` — experiments and throwaway code (ex `Test1`, `Test3`, `useful_classes`). Kept as-is per your decision to reorganize without deleting anything; clearly marked as non-shipping so it's never mistaken for a real mod.

## 11. Migration plan (phased)

1. **Foundation** — fix `repo_mod_template` (`preferNameDirectory: false`), set up `RepoAPI` as the canonical repo with its own `Directory.Build.props`, verify it builds standalone. Done.
2. **Pilot: EnemyDrops** — already has the best docs, use it to validate the whole pattern end to end: fix the nested folder, add RepoAPI as a submodule, remove the code now sourced from RepoAPI, `Compile Include` the needed modules, verify build + deploy + in-game smoke test. Done — see `EnemyDrops/CLAUDE.md`.
3. **Roll out** the same pattern to `ExtractionPointReward`, `StartWithRandomWeapon`, `TumbleAttackStun`.
4. **Reorganize** `reference/` and `sandbox/`.
5. **Final verification** — build every mod, confirm deploy paths, confirm each Thunderstore zip contains a single merged DLL with no undeclared dependency.
