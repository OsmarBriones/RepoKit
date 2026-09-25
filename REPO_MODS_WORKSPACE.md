# REPO Mods — Shared Workspace Context

This is the canonical source of workspace context for every AI agent working
under `REPO_Mods/`, including Claude Code, Codex, Gemini CLI, and Google
Antigravity. Project-level `CLAUDE.md`, `AGENTS.md`, and `GEMINI.md` files
deliberately point here instead of copying shared rules.

Keep this document accurate when a workspace-wide architectural decision,
project inventory, build convention, or coordination rule changes. Do not
fork its content into tool-specific instruction files.

## What this workspace is

A collection of **independent** BepInEx 5.x mods for the Unity game **R.E.P.O.**, plus one shared library and some non-project material, all living as sibling folders on this machine. This is **not a monorepo** — each mod is its own standalone git repository that must build on its own after a normal `git clone`. `REPO_Mods/` itself is a plain folder, not a git repo.

Full rationale and the complete convention (folder layout, naming, docs standard, migration plan) live in [REPO_MODS_METHODOLOGY.md](REPO_MODS_METHODOLOGY.md) — read it before restructuring anything here. This file is the short version plus the lessons already learned.

## Layout

```
REPO_Mods/
├── EnemyDrops/                 independent git repo — migrated to the current convention (pilot)
├── ExtractionPointReward/      independent git repo — not yet migrated
├── StartWithRandomWeapon/      independent git repo — not yet migrated
├── TumbleAttackStun/           independent git repo — not yet migrated
├── RepoAPI/                    independent git repo — shared library (see below)
├── repo_mod_template/          independent git repo — dotnet new template (repo-mod)
├── reference/                  not a git repo — decompiled source / extracted assets (read-only)
├── sandbox/                    not a git repo — throwaway/experimental code
├── repo-mods-guidance/          independent git repo — canonical shared guidance
│   ├── REPO_MODS_WORKSPACE.md
│   ├── REPO_MODS_METHODOLOGY.md
│   ├── VERSION.md
│   └── CHANGELOG.md
└── AGENTS.md / GEMINI.md / CLAUDE.md
                                workspace compatibility entry points
```

## Core decisions already made

- **One git repo per mod**, flat (no `<ModName>/<ModName>/` nesting — that came from `repo_mod_template`'s old `preferNameDirectory: true`, now fixed).
- **Every mod targets `net48`**, via a per-repo `Directory.Build.props` that resolves game/BepInEx paths from a `REPO_GAME_DIR` env var (falls back to the default Steam path). Don't hardcode multi-level relative `HintPath`s — that was the old, fragile pattern.
- **Shared code lives in `RepoAPI`** (its own repo, `https://github.com/OsmarBriones/RepoAPI`), consumed by other mods as a **git submodule** at `external/RepoAPI`, compiled in with `<Compile Include>` for **only the module folders actually needed** — not `<ProjectReference>`. There is no `RepoAPI.dll` in a consuming mod's output, no merge step, no ILRepack. See `RepoAPI/README.md` for the module dependency graph (`Items/` needs `Game/`, etc.).
  - An earlier version of this plan used `ProjectReference` + a `ILRepack` publish-time merge. It was abandoned after real friction: the `ILRepack.Lib.MSBuild.Task` NuGet package auto-registers its own merge-everything-in-bin target that collided with a custom one, assembly resolution needed explicit search paths, and Debug builds needed two DLLs deployed together. `Compile Include` sidesteps all of it. Don't reintroduce ILRepack without a real reason.
  - **Gotcha**: once a submodule sits inside a mod's project folder (e.g. `external/RepoAPI/`), the SDK's implicit glob will try to compile everything under it, including that submodule's own test project. Always pair `<Compile Include>` of the needed files with `<Compile Remove="external\**" />` (+ same for `EmbeddedResource`/`None`) first.
  - RepoAPI itself has **no `[BepInPlugin]` entry point** — it's a pure library, never installed standalone.
- **Not everything with a matching filename across mods is actually a duplicate.** Before deleting a mod's own `ConfigurationController.cs`/`ItemKeys.cs`/etc. in favor of RepoAPI, read both — EnemyDrops' versions turned out to be mod-specific (weighted drop tables, `MaxDropsPerLevel`) despite sharing a name with RepoAPI's differently-designed (enum-based) equivalents. Only `ItemProvider`/`ItemKeysProvider`/`ItemName` were genuinely swappable.
- **Testing**: the real, currently-used workflow is **r2modman**, profile `Debug` — wired into each mod's `PostBuild` target (`AppData\Roaming\r2modmanPlus-local\REPO\profiles\Debug\BepInEx\plugins`), alongside a direct copy to the Steam `BepInEx\plugins` folder. A `Thunderstore Mod Manager` install also exists on this machine with a `Multimancos` profile (used for group/multiplayer testing with other real mods installed) but nothing in any `.csproj` deploys there automatically — if a build needs to reach it, it's a manual copy unless explicitly wired in.
- **Don't commit build artifacts.** `bin/`, `obj/`, and any packaged `.dll`/`.zip` (`zip/`, `ts_build/`, `Thunderstore/` folders) should be gitignored, not tracked. Several mods still have old tracked copies of these — clean up is part of migrating that mod, not done workspace-wide yet.

## Migration status

Only `EnemyDrops` and `RepoAPI` have been brought onto this convention so far. `ExtractionPointReward`, `StartWithRandomWeapon`, `TumbleAttackStun`, and `repo_mod_template` still need the same treatment (flatten nesting, `Directory.Build.props`, dedupe against RepoAPI where it's a real duplicate, docs). Follow §10 of `REPO_MODS_METHODOLOGY.md` for the phased plan, and `EnemyDrops/CLAUDE.md` + `EnemyDrops/ARCHITECTURE.md` as the reference example of the target shape (both build and docs).

## Reference material

Decompiled game source and extracted assets belong under `reference/` (not yet moved there as of this writing — still at `repo_decompiled_code/` and `repo_assets_extracted/` in the workspace root). Individual mods' `CLAUDE.md` files reference these via `REPO_DECOMPILED` / `REPO_ASSETS` environment variables rather than a fixed path.

## Multi-agent coordination

This workspace is intentionally shared by several agents and tools. Agents
may work in parallel only when their file ownership does not overlap. The
agent coordinating a task is responsible for dividing work by repository or
non-overlapping files, integrating the results, and validating the combined
change.

Before editing:

1. Read this file. Read the target mod's `ARCHITECTURE.md`, project-specific
   agent guidance, and the relevant section of `REPO_MODS_METHODOLOGY.md` when the work
   touches layout, builds, packaging, RepoAPI, or shared conventions.
2. Identify the owning git repository. Run its status and preserve unrelated
   uncommitted work; do not reset, discard, or rewrite it.
3. Define the change's impact scope: one mod, RepoAPI plus its consumers, the
   template plus future mods, or a workspace-wide convention.

## Shared-guidance synchronization gate

Every independent repository consumes this guidance through the
`external/repo-mods-guidance` git submodule. Before the first edit of each
task, synchronize and read it once:

1. Initialize the submodule if needed with `git submodule update --init --
   external/repo-mods-guidance`.
2. Fetch its remote, compare its checked-out revision with `origin/master`,
   and update the submodule if a newer revision exists.
3. When updated, read `VERSION.md`, this document, and
   `REPO_MODS_METHODOLOGY.md`; stage the changed submodule pointer with the
   task's parent-repository changes.

Do not repeat the check during the same task unless the task changes this
guidance repository. The pinned submodule revision makes the task reproducible
while the once-per-task gate ensures no task starts on known stale guidance.

While editing:

- Treat a change to shared code, build conventions, templates, documentation,
  configuration formats, item keys, or deployment paths as potentially
  cross-project. Search the sibling projects and RepoAPI for consumers before
  declaring it complete.
- A generic improvement found in a mod belongs in `RepoAPI` only when it is
  genuinely reusable; preserve mod-specific behavior even if a file has a
  similar name elsewhere.
- RepoAPI changes must be made and committed in its own repository. Update
  every affected consumer's submodule pointer and source includes when that
  consumer is in scope; explicitly report any consumer intentionally deferred.
- For concurrent work, do not make opportunistic edits in a file assigned to
  another agent. Report proposed follow-up changes to the coordinating agent
  instead.

Before completion:

1. Check each touched repository independently, including submodule state.
2. Build or otherwise validate every affected mod in proportion to the change.
3. Update documentation in the same change whenever it has become inaccurate:
   this file for workspace-wide facts, `REPO_MODS_METHODOLOGY.md` for conventions,
   `ARCHITECTURE.md` for runtime/design changes, and a mod's `README.md`,
   `CHANGELOG.md`, or local agent guidance when its behavior, use, build, or
   release information changed. Do not claim completion while known affected
   documentation is stale; explicitly state any deliberately deferred update.
4. Summarize the cross-project impact: what was changed, which consumers and
   documents were checked or updated, and what (if anything) remains
   deliberately out of scope.

## Instruction-file maintenance

- `REPO_MODS_WORKSPACE.md` is the single source of truth for workspace context.
- `CLAUDE.md`, `AGENTS.md`, and `GEMINI.md` are compatibility entry points.
  Keep them short and make them point here; do not duplicate the rules.
- A mod may have a local instruction file only for facts unique to that mod.
  It supplements this file and must not contradict it.
- Every agent must consider documentation maintenance part of the definition of
  done. Update this file and the other affected documents as part of the same
  task, not as an optional follow-up.
