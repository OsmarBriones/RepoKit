---
name: develop-mod
description: Autonomously executes the complete end-to-end mod development cycle using Spec-Kit. Handles technical planning (plan.md), task decomposition (tasks.md), C# code implementation, Harmony hooking, compilation, verification, and documentation. Only interrupts the user for critical design/gameplay decisions or irreconcilable technical blockers.
---

# Develop Mod Skill

Use this skill when you are inside a R.E.P.O. mod directory (e.g. `StealLifeFromMonsters`, `DucksEveryWhere`) and want to execute the complete development cycle using **Spec-Kit** (e.g. `/develop-mod`).

---

## Core Operational Philosophy: Autonomous Technical Ownership

The agent carries **100% of the technical workload**. The human developer is a stakeholder and creative director:
- **The AI does NOT ask the user** about:
  - C# syntax, internal class designs, method signatures, or namespace layouts.
  - Which decompiled game methods to hook when reverse-engineering yields clear targets.
  - Standard compiler fixes, dependency inclusions in `.csproj`, or formatting.
  - Routine BepInEx configuration bindings and logging statements.
- **The AI ONLY consults the user** (`ask_question` tool or structured prompt) when:
  1. **Gameplay / Design Ambiguity:** A design choice has multiple viable directions that significantly alter game feel, difficulty, or multiplayer balance (e.g. *"Should holding the monster slow player movement by 30% or allow normal sprint?"*).
  2. **Scope Expansion:** A technical edge case requires introducing an entirely new mechanic outside `spec.md`.
  3. **Irreconcilable Technical Blocker:** A game engine limitation or missing Unity reference cannot be resolved autonomously without human guidance.

---

## 5-Stage Autonomous Development Workflow

```
[spec.md Ready]
      │
      ▼
┌────────────────────────┐
│ Stage 1: Pre-flight    │  <── Read spec.md, verify .specify/feature.json
└────────────────────────┘
      │
      ▼
┌────────────────────────┐
│ Stage 2: Tech Planning │  <── Run setup-plan.ps1, research reference code,
└────────────────────────┘      define Harmony hooks & plan.md
      │
      ▼
┌────────────────────────┐
│ Stage 3: Task Breakdown│  <── Run setup-tasks.ps1, generate phased tasks.md
└────────────────────────┘
      │
      ▼
┌────────────────────────┐
│ Stage 4: Implementation│  <── Write C# domain logic, config, patches,
└────────────────────────┘      compile iteratively (dotnet build)
      │
      ▼
┌────────────────────────┐
│ Stage 5: Quality Gate  │  <── Update ARCHITECTURE.md, README.md,
└────────────────────────┘      verify Release/Debug builds, git commit
```

---

### Stage 1: Pre-flight & Spec Verification

1. Verify the current working directory is a mod root (contains `.csproj`, `Directory.Build.props`, and `.specify/`).
2. Read `.specify/feature.json` to identify the active feature directory (e.g. `specs/001-monster-life-drain/`).
   - If missing, inspect `specs/` for the latest numeric feature folder.
3. Read `spec.md` and `.specify/memory/constitution.md`.
4. Ensure all requirements, acceptance criteria, and user stories (P1..Pn) are understood before writing code.

---

### Stage 2: Technical Planning (`plan.md`)

1. Initialize `plan.md` using the project's Spec-Kit script with dynamic PowerShell engine resolution:
   ```powershell
   $ps = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }; & $ps -ExecutionPolicy Bypass -File .specify/scripts/powershell/setup-plan.ps1
   ```
2. **Reverse-Engineering & Reference Research:**
   - Search the decompiled game source in `reference/` (or `repo_decompiled_code/`) for the relevant classes:
     - Player state & input: `PlayerAvatar`, `PlayerController`, `SemiFunc`.
     - Entity health & interactions: `Enemy`, `PhysGrabObject`, `Health`.
     - Multiplayer RPCs: `PhotonUnityNetworking`, `PunRPC` targets.
3. **RepoAPI Evaluation:**
   - Check if reusable modules exist in `external/RepoAPI/` (e.g. `Items/`, `Game/`).
   - If needed, include only the necessary source files in `<ModName>.csproj` via `<Compile Include="external\RepoAPI\..." />`.
4. **Draft `plan.md`:**
   - Architecture & Data Flow.
   - Exact Harmony Hook signatures (`[HarmonyPatch(typeof(...), nameof(...))]`).
   - BepInEx Configuration structure.
   - Error handling & safety boundaries (e.g., dead players, destroyed entities, null checks).

---

### Stage 3: Task Breakdown (`tasks.md`)

1. Initialize `tasks.md` using Spec-Kit:
   ```powershell
   $ps = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }; & $ps -ExecutionPolicy Bypass -File .specify/scripts/powershell/setup-tasks.ps1
   ```
   > [!NOTE]
   > The output `AVAILABLE_DOCS: [FAIL]` in Spec-Kit indicates that optional research/contract docs were not created; this is normal and expected for single-feature mods and does NOT indicate a failure.

2. Structure tasks into clean, sequential phases:
   - **Phase 1: Setup & Configuration**: ConfigurationController entries, default values.
   - **Phase 2: Core Domain Logic**: Controller/manager classes handling state and math.
   - **Phase 3: Harmony Patches**: Hooking trigger methods, wiring events, and removing template dummy patches (`ReloadOnLevelStart.cs`).
   - **Phase 4: Feedback & Game Feel**: Audio clips, particle/screen effects, logging.
   - **Phase 5: Verification & Documentation**: Build checks, ARCHITECTURE.md, README.md.

---

### Stage 4: Autonomous Code Implementation

Systematically execute each task from `tasks.md`:

1. **Coding Standards:**
   - Modern C# (`net48`, `LangVersion: latest`, `Nullable: enable`).
   - No hungarian or Hungarian-like prefixes (use `logger`, `config`, not `_logger`, `s_config`).
   - Scope classes to `internal` by default.
   - Separate concerns cleanly:
     - `Configuration/ConfigurationController.cs`: config bindings only.
     - `Patches/<TargetName>Patch.cs`: thin wiring only; delegate logic to controllers.
     - `<Domain>/`: domain-specific logic.
2. **Iterative Build Verification:**
   - After creating or editing C# files, run:
     ```powershell
     dotnet build
     ```
   - If compiler errors or warnings occur, resolve them autonomously (check namespaces, publicizer access, null safety).
3. **Task Tracking:**
   - Mark completed items `[x]` in `tasks.md` as progress is made.

---

### Stage 5: Quality Gate & Synchronization

1. **Dual Configuration Build:**
   ```powershell
   dotnet build -c Debug
   dotnet build -c Release
   ```
   Both must succeed with **0 errors and 0 warnings**.
2. **Documentation Maintenance:**
   - Update `ARCHITECTURE.md`: Document newly created classes, runtime lifecycle hooks, and data flow.
   - Update `README.md`: Ensure `## Features` and `## Configuration` accurately reflect implemented settings without exposing internal Unity engine symbols.
3. **Git Commit:**
   Stage all completed implementation files and commit:
   ```powershell
   git add .
   git commit -m "feat: implement <feature-short-name> via spec-kit"
   ```
4. **Handoff Report:**
   Report to the user:
   - List of implemented user stories and acceptance criteria met.
   - Build status.
   - Local plugin deployment location (in r2modman / Steam plugins directory).
   - Prompt them to test in-game or run `/publish` when ready to release.
