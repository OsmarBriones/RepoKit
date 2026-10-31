---
name: decompile-game
description: Re-decompiles R.E.P.O.'s Assembly-CSharp.dll with ilspycmd after a game update, diffs it against the previous decompilation and reports which mods patch types that changed.
---

# Decompile Game Skill

Use this skill after a R.E.P.O. update, or when the user asks to refresh the decompiled
source or find out which mods a game update may break (e.g. `/decompile-game`,
`actualizar la descompilación`, `qué mods afecta el update`).

---

## Background

`repo_decompiled_code/` (exposed to mods as `REPO_DECOMPILED`) holds the ILSpy-exported
source of `Assembly-CSharp.dll`. It goes stale whenever Steam updates the game. This skill
regenerates it and tells you what changed, so Harmony patches can be re-verified.

## Usage

```powershell
$ps = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
& $ps -ExecutionPolicy Bypass -File RepoKit/skills/decompile-game/scripts/decompile-game.ps1 `
    [-GameDir <path>] [-OutDir <path>] [-ModsRoot <path>] [-DiffOnly] [-ReportPath <file.md>]
```

| Parameter | Default | Description |
| :--- | :--- | :--- |
| `-GameDir` | `$env:REPO_GAME_DIR`, then default Steam path | Game installation directory. |
| `-OutDir` | `$env:REPO_DECOMPILED`, then `<workspace>/repo_decompiled_code` | Decompiled output directory. |
| `-ModsRoot` | Parent of `-OutDir` | Folder with the mod repositories to scan for `[HarmonyPatch]` targets. |
| `-DiffOnly` | `false` | Report only; keep the new output in `<OutDir>.new` and leave `-OutDir` untouched. |
| `-ReportPath` | none | Also write the report as Markdown. |

## What it does

1. Decompiles with `ilspycmd -p` into `<OutDir>.new`.
2. Diffs against the current output by normalized file hash (added / removed / changed).
3. Scans mods (excluding `external/`, `bin/`, `obj/`) for `[HarmonyPatch(typeof(X), ...)]` and lists
   the patched types whose `X.cs` changed or disappeared, with the mod and method that patches it.
4. Moves the old output to `<OutDir>.prev` and promotes the new one (skipped with `-DiffOnly`).

## After running

- Read the diff of each affected type: `diff <OutDir>.prev/X.cs <OutDir>/X.cs`.
- Types patched through `HarmonyTargetMethod` or reflection are reported with method
  `(see HarmonyTargetMethod)`; mods using `AccessTools`/`GetField` strings need a manual check.
- Mods that use `itemDictionary` or enemy lists may also need updates for newly added items or enemies.
- Rebuild every affected mod and smoke-test it per `REPO_MODS_METHODOLOGY.md` §8.

The script requires `ilspycmd` (`dotnet tool install -g ilspycmd`). It degrades with a warning
when the game or the tool is missing. `.prev` and `.new` folders are throwaway; do not commit them.
