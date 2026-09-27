---
name: refine-mod-concept
description: Refines a raw R.E.P.O. mod concept through cyclical, iterative questions until its gameplay mechanics, networking scope (host vs client), configuration, audiovisual feel, and edge cases are completely defined with no gaps.
---

# Refine Mod Concept Skill

Use this skill when the user provides a raw or vague mod idea (e.g., `/refine-mod-concept "Un mod para robar vida de los monstruos"`) or as the first step of `/create-mod`.

The goal is to turn an informal idea into an exhaustive, unambiguous specification ready for scaffolding and Spec-Kit.

---

## Cyclical Refinement Loop

Refinement operates as a **cyclical interview loop**. In each iteration, you evaluate what is known versus what is missing, asking targeted questions until **no gaps remain**.

```
    ┌──────────────────────────────────────────────┐
    │ 1. Parse current concept & analyze gaps      │
    └──────────────────────┬───────────────────────┘
                           │
                           ▼
    ┌──────────────────────────────────────────────┐
    │ 2. Ask 2-4 focused questions with options    │ <─── Cycle continues until
    └──────────────────────┬───────────────────────┘      user is satisfied and
                           │                              no ambiguities exist
                           ▼
    ┌──────────────────────────────────────────────┐
    │ 3. Integrate user answers & check edge cases │
    └──────────────────────┬───────────────────────┘
                           │
               [Are there remaining gaps?]
                 ├── YES ──> Loop back to Step 2
                 └── NO
                           │
                           ▼
    ┌──────────────────────────────────────────────┐
    │ 4. Emit finalized Mod Concept Specification  │
    └──────────────────────────────────────────────┘
```

---

## The 6 Dimension Checklist (Gaps to Cover)

In each cycle, check if all of the following six dimensions have clear, concrete definitions:

### 1. Core Gameplay Mechanics & Triggers
- **Trigger**: What event triggers the effect? (e.g. melee attack, gun shot, enemy kill, item throw, proximity?)
- **Calculation**: How is the magnitude calculated? (Flat amount, percentage of damage dealt, tiered by enemy type?)
- **Limits / Caps**: Is there a cap? Can it overheal beyond maximum player health, or strictly clamped to max HP?

### 2. Multiplayer & Synchronization Model
- **Host vs. Client**: Does this run strictly on the Host (where the host executes logic and syncs health/state via game RPCs), or does every player need the mod installed?
- **Manifest convention**: If host-only, enforce the workspace standard phrase: `"Only Host, clients don't need it."`.

### 3. Configurable Settings (`BepInEx/config/com.osmar.<ModName>.cfg`)
- What parameters should players be able to tune?
- Examples: `Enabled` (bool), `LifestealPercent` (float), `HealFlatAmount` (int), `AllowOverheal` (bool), `EnableAudioFeedback` (bool).
- Provide sensible defaults for each.

### 4. Audiovisual Feedback & Game Feel
- **Visuals**: Particle effect, vignette/screen flash, health bar pulse, or floating text?
- **Audio**: Sound effect when triggered, volume, pitch variation?
- **Feedback fallback**: If no custom assets, what vanilla game audio/particles can be reused (via `SemiFunc`)?

### 5. Edge Cases & Safety Constraints
- What if the player is downed or dead?
- What if the enemy has 0 health remaining or is invulnerable?
- Does it trigger on friendly fire / PvP damage?
- Does it trigger on environmental damage or self-inflicted damage?

### 6. Mod Identity & Naming
- Propose 2-3 **PascalCase** candidate names (e.g. `LifeSteal`, `VampiricStrikes`, `BloodLeech`).
- Formulate a player-friendly description (< 250 characters) for `manifest.json`.

---

## Question Asking Guidelines

- **Interactive Modal**: When executing inside Antigravity, use the `ask_question` tool to render structured interactive multiple-choice questions with clear options and a recommended default marked `(Recommended)`.
- **Text CLI Fallback**: When running in text-only environments, format questions with markdown tables or clear lettered choices (A, B, C, Custom).
- Group related questions together (2 to 4 questions per turn). Never overwhelm the user with a 15-question wall of text.
- If the user types "listo", "así está bien", or approves the proposal, stop the loop and generate the final output.

---

## Output: Mod Concept Specification

Once all dimensions are resolved, output the specification in this exact structure:

```markdown
# Mod Concept Specification: <ModName>

## Metadata
- **Mod Name:** <ModName> (PascalCase)
- **Plugin GUID:** com.osmar.<ModName>
- **Manifest Description:** <Description under 250 chars>
- **Multiplayer Mode:** Only Host, clients don't need it / All players required

## Gameplay Rules
- **Trigger:** ...
- **Formula / Effect:** ...
- **Limits & Caps:** ...

## Configuration Options (`com.osmar.<ModName>.cfg`)
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| Enabled | bool | true | Enable or disable the mod |
| ... | ... | ... | ... |

## Feedback & Game Feel
- **Visual:** ...
- **Audio:** ...

## Edge Cases
- Downed/Dead player: ...
- Friendly fire: ...
- Invulnerable enemies: ...

## Spec-Kit Initial Feature (Ready for spec.md)
- **Feature Name:** <feature-short-name>
- **User Story 1 (P1):** As a player, I want... so that...
  - **Acceptance Scenario 1:** Given... When... Then...
- **User Story 2 (P2):** As a player, I want to configure... so that...
  - **Acceptance Scenario 1:** Given... When... Then...
- **Success Criteria:** Measurable, technology-agnostic outcomes.
```

When called from `/create-mod`, pass this final specification directly into Phase 2 of `create-mod`.
