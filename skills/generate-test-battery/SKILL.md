---
name: generate-test-battery
description: Generates a comprehensive, actionable QA test battery (Tier 1-3 testing protocol) for a R.E.P.O. mod by analyzing its specs, ARCHITECTURE.md, configuration, and Harmony hooks. Produces an interactive checklist with happy paths, boundary tests, edge cases, multiplayer checks, and log verification patterns.
---

# Generate Test Battery Skill

Use this skill when preparing to test, verify, or release a R.E.P.O. mod (e.g. `/generate-test-battery`, *"genera la batería de pruebas para este mod"*, *"crea el plan de pruebas"*).

It automatically analyzes existing documentation and source code to synthesize an end-to-end QA testing protocol without maintaining redundant test documents.

---

## Operational Workflow

When this skill is invoked inside a mod repository (or targeting a mod folder):

```
┌───────────────────────────────────────────────────────────────┐
│                     1. Document & Code Audit                  │
│  - specs/<feature>/spec.md      (Scenarios, acceptance rules) │
│  - ARCHITECTURE.md              (Hooks, data flow, authority) │
│  - README.md / Config files     (Options, defaults, ranges)   │
│  - Patches/*.cs                 (Hooked game methods)         │
└───────────────────────────────┬───────────────────────────────┘
                                │
                                ▼
┌───────────────────────────────────────────────────────────────┐
│                     2. Synthesis & Coverage                   │
│  - Map User Stories to physical in-game player actions        │
│  - Identify configuration boundaries (default, min, max, off) │
│  - Detect lifecycle triggers (Round Start, Scene Switch, etc) │
│  - Extract expected log strings (BepInEx/LogOutput.log)       │
└───────────────────────────────┬───────────────────────────────┘
                                │
                                ▼
┌───────────────────────────────────────────────────────────────┐
│               3. Actionable QA Protocol Output                │
│  - Tier 1: Automated Unit Tests (dotnet test)                 │
│  - Tier 2: Assembly & Harmony Contract Verification           │
│  - Tier 3: Interactive In-Game Smoke Test Battery (- [ ])     │
└───────────────────────────────────────────────────────────────┘
```

---

## Test Battery Structure

The generated battery must adhere to the 3-Tier Testing Strategy defined in `REPO_MODS_METHODOLOGY.md` §8:

### Tier 1: Automated Unit Tests
- Identifies any companion test projects (e.g. `RepoAPI.Test/` or `<ModName>.Test/`).
- Specifies the exact `dotnet test` commands and expected pass counts.

### Tier 2: Contract & Build Verification
- Verifies clean compilation in both `Debug` and `Release` modes:
  ```bash
  dotnet build -c Debug
  dotnet build -c Release
  ```
- Confirms zero errors and zero warnings.
- Checks that the post-build deployment copied the `.dll` to Steam and r2modman Debug folders.

### Tier 3: In-Game Smoke Test Protocol (Interactive Checklist)
Organized into distinct phases with actionable markdown checkboxes (`- [ ]`), explicit setup conditions, player actions, and observable results:

#### Phase A: Baseline / Vanilla Parity (Mod Disabled)
- Test mod with its master switch disabled (`Enabled = false` or feature toggle off).
- Verify vanilla game mechanics function without errors or unwanted side effects.

#### Phase B: Happy Path (Core Gameplay Loop)
- Step-by-step verification of the primary user stories.
- Clear setup (e.g. required items, monster spawns, truck status).
- Concrete physical player inputs (keys, grabs, actions).
- Concrete expected outputs (visuals, sounds, UI stats, game state changes).

#### Phase C: Configuration & Boundary Matrix
- **Default State**: Confirm fresh install behaves as documented.
- **Minimum Value**: Test lowest allowed bound (e.g. `0`, `0.0`).
- **Maximum Value**: Test highest allowed bound (e.g. `100`, `1000`).
- **Dynamic Reload**: Verify if settings update on round start or level load without restarting the entire game.

#### Phase D: Edge Cases, Cancellations & Negative Tests
- **Player Death / Tumble**: What happens if the player dies, gets knocked down, or tumbles during the interaction?
- **Entity Destruction**: What happens if the target monster/item is destroyed, falls into a death pit, or despawns?
- **Interrupted States**: Early release, moving out of range, level transition while interacting.
- **Run Over / Wipe**: Verifies game over properly clears per-run state and resets persistent trackers.

#### Phase E: Multiplayer & Network Authority (Host vs Client)
- Verify singleplayer functionality.
- For host-only mods:
  - Confirm logic executes exclusively on the host (`SemiFunc.IsMasterClientOrSingleplayer()`).
  - Confirm connected clients observe synchronized effects via Photon RPCs or vanilla replication.
  - Confirm clients without the mod experience no desyncs, crashes, or phantom objects.

#### Phase F: Log & Telemetry Auditing
- Lists exact log messages to grep in `%APPDATA%\r2modmanPlus-local\REPO\profiles\<Profile>\BepInEx\LogOutput.log` (or `<REPO_GAME_DIR>\BepInEx\LogOutput.log`).
- Verifies that initialization, execution, and cleanup lines are emitted without unexpected exceptions.

---

## Output Options

When executing this skill:
1. **Chat Artifact (Default):** Render the full test battery as a clean, interactive markdown artifact. The user can reference or check off items as they play.
2. **On-Demand Spec Integration:** If requested or if working within a Spec-Kit branch, the agent may optionally write the checklist into `specs/<feature>/qa-battery.md`.
