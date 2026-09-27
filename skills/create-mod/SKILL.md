---
name: create-mod
description: Scaffolds and initializes a new R.E.P.O. BepInEx mod repository from a concept. Refines the idea via refine-mod-concept, scaffolds from repo_mod_template, initializes Git, creates a public GitHub repo with secrets, configures submodules (RepoAPI and RepoKit), sets up spec-kit, and verifies the build.
---

# Create Mod Skill

Use this skill when the user wants to create, scaffold, or start a new R.E.P.O. mod (e.g., `/create-mod "Un mod para robar vida de los monstruos"` or `/create-mod`).

## Workflow

Creating a new mod consists of two connected phases:

```
[User Concept]
      │
      ▼
┌────────────────────────┐
│  refine-mod-concept    │  <── Cyclical Q&A until no gaps remain
└────────────────────────┘
      │
      ▼ (ModName, Description, Mechanics, Config, Spec Markdown)
┌────────────────────────┐
│  create-mod.ps1        │  <── Scaffolds from repo_mod_template, Git init,
└────────────────────────┘      submodules, GitHub repo, THUNDERSTORE_TOKEN,
      │                         Spec-Kit feature initialization, dotnet build
      ▼
┌────────────────────────┐
│  Spec-Kit Workflow     │  <── Ready for /speckit-plan or /speckit-tasks
└────────────────────────┘
```

---

## Phase 1: Concept Refinement

1. Check if the user already has a completely defined concept.
2. If not, invoke or execute the **`refine-mod-concept`** skill to run an iterative clarification loop:
   - Ask clarifying questions (gameplay triggers, multipliers, networking scope, config options, audio/visual feel).
   - Resolve mod name in **PascalCase** (e.g. `LifeSteal`, `MonsterLeech`).
   - Draft player-facing description (< 250 characters, following the `"Only Host, clients don't need it."` standard if host-only).
   - Formulate structured user stories and acceptance criteria for Spec-Kit.

---

## Phase 2: Scaffolding and Setup

Once the concept is refined, execute the creation script from the workspace root:

```powershell
$ps = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
& $ps -ExecutionPolicy Bypass -File RepoKit/skills/create-mod/scripts/create-mod.ps1 `
    -ModName "<ModName>" `
    -Description "<Description>" `
    -FeatureDescription "<FeatureDescription>" `
    -FeatureShortName "<feature-short-name>" `
    -SpecMarkdownContent @"
<MarkdownContentFromRefinement>
"@
```

### What the script executes automatically:

1. **Naming & Directory Verification:** Validates PascalCase name and ensures no duplicate folder exists in `REPO_Mods/`.
2. **Template Verification:** Installs or updates the `dotnet new repo-mod` template from `repo_mod_template/`.
3. **Scaffolding:** Runs `dotnet new repo-mod -n <ModName> -o <ModName>` and removes any leftover `.template.config`.
4. **Manifest Synchronization:** Updates `manifest.json` (`name`, `version_number: 1.0.0`, `website_url: https://github.com/OsmarBriones/<ModName>`, `description`).
5. **README Synchronization:** Updates `# <ModName>` title and player-facing description.
6. **Git Initialization:** Runs `git init -b master` and sets CRLF conventions.
7. **Submodules:** Adds `external/RepoAPI` and `external/RepoKit` git submodules.
8. **Initial Commit:** Commits scaffolded structure (`feat: initial mod structure from repo-mod template`).
9. **GitHub Remote & Secrets:**
   - Creates public repository: `gh repo create OsmarBriones/<ModName> --public --source=. --remote=origin --push`.
   - Automatically provisions `THUNDERSTORE_TOKEN` secret via `gh secret set` if `$env:THUNDERSTORE_TOKEN` is present.
10. **Spec-Kit Setup:**
    - Runs `.specify/scripts/powershell/create-new-feature.ps1` to create `specs/001-<feature-short-name>/spec.md` and `.specify/feature.json`.
    - Injects the refined specification details (User Stories, Requirements, Success Criteria).
11. **Build Verification:** Executes `dotnet build` to confirm clean compilation with 0 errors.
12. **Push Initial Spec:** Commits and pushes the initial Spec-Kit feature to GitHub.

---

## Phase 3: Transition to Spec-Kit

After running the creation script, inform the user that the mod is initialized and guide them into Spec-Kit:
- **Location:** `REPO_Mods/<ModName>/`
- **GitHub:** `https://github.com/OsmarBriones/<ModName>`
- **Active Spec:** `specs/001-<feature-short-name>/spec.md`
- **Next Command:** Suggest running `/speckit-plan` or `$speckit-tasks` inside the mod folder to begin technical planning and implementation.
