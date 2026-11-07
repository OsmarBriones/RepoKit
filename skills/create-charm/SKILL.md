---
name: create-charm
description: Scaffolds a new Charm mod (one valuable, one power) on top of Pockets and CharmCore from a template that already follows the charm rules, including DebugMode, and checks those rules with tests. Use it for every new Charm<Valuable> mod instead of create-mod.
---

# Create Charm Skill

Use this skill for every new `Charm<Valuable>` mod of the PocketCharms family (spec: `sandbox/PocketCharms_spec.md`). It wraps `create-mod` (repository, GitHub, topics, secret, submodules, Spec-Kit) and then replaces the generic scaffold with the charm template, so the mod starts compliant.

## Charm rules (enforced)

Every charm mod:

1. **Derives from `CharmCore.Api.Charm` and registers with `CharmsApi.Register`.** That binds `Enabled`, `WearPercent`, `CooldownSeconds` and the **`Debug.DebugMode`** setting for free. CharmCore does the rest of debug mode: with it on, the charm's valuable is placed on the floor in front of the player at the start of each level (any level; prefabs are in Resources).
2. **Writes debug detail only through `Charm.LogDebug(...)`**, never through the plugin logger. The plugin class may log startup lines. This keeps normal play quiet and puts the detail behind `DebugMode`.
3. **Depends on Pockets and CharmCore** in `manifest.json`, and is Category 2 (everyone installs).
4. **Documents `DebugMode` in `README.md`** and starts its **QA battery with a debug-mode quick start**.
5. **Uses `AddSetting` for any extra number** so the host's value applies to everyone.
6. **Has a game-contract test** listing every game member its effect reads, writes or patches.

Rules 1 to 4 are checked by `<Mod>.Tests/CharmRulesTests.cs`, and the configuration types rule (numeric settings need a value range) by `ConfigRulesTests.cs` (both copied from the template). The test runs with `dotnet test`, which is already part of the pre-release checks, so a charm that breaks a rule fails before it can ship. Do not delete or weaken those tests; fix the charm.

## Usage

Build Pockets and CharmCore in Release first (their DLLs are referenced), then from the workspace root:

```powershell
$ps = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
& $ps -ExecutionPolicy Bypass -File RepoKit/skills/create-charm/scripts/create-charm.ps1 `
    -Name CoffeeCup -DisplayName "Coffee Cup" -PrefabName "Valuable Arctic Coffee Cup" `
    -EffectName "Second Wind" -EffectSummary "when your energy runs out, part of it comes right back." `
    -WearPercent 20 -CooldownSeconds 3
```

Use `-NoCooldown` for a power without a pause. Do not put double quotes inside the texts.

## What it does

1. Runs `create-mod` for `Charm<Name>` (GitHub repo `REPO-Charm<Name>`).
2. Writes the template: plugin, charm class, effect stub (`<EffectClass>.cs`, with TODOs), project files referencing Pockets and CharmCore, tests, README, ARCHITECTURE, CHANGELOG and the QA battery.
3. Adds the Pockets and CharmCore dependencies to `manifest.json`.
4. Builds, runs the tests, commits and pushes when both pass.

## After the scaffold

1. Implement the effect in `<EffectClass>.cs` following the comments (check `Charm.IsActive`, call `Charm.TryUse()` at the trigger, use `Charm.LogDebug`).
2. Fill every `TODO` in `README.md`, `ARCHITECTURE.md`, the QA battery and `GameContractTests.cs`.
3. Test in game with `DebugMode = true`.
4. Follow the normal workspace gates (known pitfalls, RepoAPI reuse decision, documentation) and `publish-mod` for the release.
