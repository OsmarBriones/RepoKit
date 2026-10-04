---
name: refine-mod-concept
description: Refines a raw R.E.P.O. mod concept through cyclical, iterative questions until its gameplay mechanics, networking scope (host vs client), configuration, audiovisual feel, and edge cases are completely defined with no gaps.
---

# Refine Mod Concept Skill

Use this skill when the user provides a raw or vague mod idea (e.g., `/refine-mod-concept "Un mod para robar vida de los monstruos"`) or as the first step of `/create-mod`.

The goal is to turn an informal idea into an exhaustive, unambiguous specification ready for scaffolding and Spec-Kit.

---

## Adaptive 2-Stage Clarification Loop

Rather than overwhelming the user or asking questions that might be invalidated by earlier choices, structure the questioning into **2 focused, sequential micro-rounds**:

### Round 1: Core Premise & Trigger Action (The "HOW")
Focus strictly on the core player interaction and trigger condition:
- What exact action does the player perform? (e.g., weapon attack, holding a monster/grab interaction, proximity, on-death trigger?)
- Proposed 2-3 **PascalCase** mod names matching that specific interaction.
*Wait for the user's response before designing specific values or configurations.*

### Round 2: Tuning, Networking & Game Feel (The "DETAILS")
Once the core trigger is locked down:
- **Math / Cadence:** Exact calculation (e.g. 10% per tick vs fixed HP) and caps (overheal allowed or strictly capped at 100 HP).
- **Networking:** Confirm Host-Only status (`"Only Host, clients don't need it."`).
- **Config & Audio/Visuals:** Tunable settings in `com.osmar.<ModName>.cfg` and native/custom sound/visual effects.

---

## The 6 Dimension Checklist (Gaps to Cover)

In each cycle, check if all of the following six dimensions have clear, concrete definitions:

### 1. Core Gameplay Mechanics & Triggers
- **Trigger**: What event triggers the effect? (e.g. melee attack, gun shot, enemy kill, item throw, proximity?)
- **Calculation**: How is the magnitude calculated? (Flat amount, percentage of damage dealt, tiered by enemy type?)
- **Limits / Caps**: Is there a cap? Can it overheal beyond maximum player health, or strictly clamped to max HP?

### 2. Multiplayer & Synchronization Model
- **Categorization**: Classify into one of the 3 standard scopes:
  - **Category 1 (True Host-Only)**: Logic executed 100% on the MasterClient via vanilla game RPCs or object spawns. Vanilla clients connect without DLL. Manifest: `"Only Host, clients don't need it."`.
  - **Category 2 (Client-Synced)**: All players required. Mandatory if introducing custom keybinds/inputs, custom 3D models/bundles, custom UI/HUD canvas overlays, or local camera/audio mechanics.
  - **Category 3 (Asymmetric Hybrid)**: Mechanics run Host-Only for all players; modded clients receive enhanced audiovisual synchronization (custom shaders, colored beams, LEDs, localized UI labels).
- **The 4-Question Network Feasibility Gate (MANDATORY IF PROPOSING HOST-ONLY)**:
  1. *Does the trigger hook a client-held input (`heldByLocalPlayer` / `SemiFunc.InputDown`)?*
     If yes, the interaction must match native binary input states (e.g. alternating ON/OFF) or require the DLL on clients.
  2. *Does R.E.P.O. have native RPCs for the visual/game effect?*
     Damage, health, and positions are synchronized; shaders, line renderer colors, and UI overlays are strictly local.
  3. *Is the vanilla target state machine binary (ON/OFF) or custom extensible?*
     Forcing a 3rd state on a binary toggle causes packet bouncing.
  4. *What happens on unequip, drop, or depletion?*
     Prevent auto-turn-off interference (`autoTurnOffWhenEquipped`, `DropItem`).
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
