# Known Pitfalls

Problems that have already cost time in R.E.P.O. mods. Compare every new mod or feature against this list **while planning** and again **before declaring it done**, and note which entries were relevant. An entry that does not apply is fine; one that applies and was ignored is not.

## What belongs here (and what does not)

The list only works if it stays short and every entry is worth reading. Add an entry only when **both** parts are true:

1. **It is worth remembering**, at least one of:
   - **Hard to notice:** it fails silently or late (no error, no log, wrong data in a save, an effect on a different feature) and was found only by investigation or by luck.
   - **Critical:** data loss, a corrupted or ever-growing save, a crash, a desync between players, or something that could affect a release.
   - **Recurring:** it happened in more than one mod, or in the same mod more than once.
   - **Costly to rediscover:** the cause was non-obvious and took real investigation (more than a build-and-fix cycle).
2. **It can be acted on:** it generalizes beyond a single bug in a single file, and there is a concrete safeguard or check to write down.

Do **not** add:
- Errors the compiler or the tests already report (typos, a missing reference, a nullable warning).
- A one-off logic bug in a mod's own code, or a layout and cosmetic issue.
- Anything already enforced by a test, a build step or a rule elsewhere (point to it instead).
- A guess that was not verified. Mark uncertain causes as such, or leave the entry out.

Before adding, search the list: if the new case is the same root cause as an existing entry, **extend that entry** (a new "Seen in" mod, a sharper check) instead of creating one. When a game update fixes a problem for good, mark the entry `Status: obsolete (fixed in <version>)` rather than silently deleting it.

## How entries get captured during development

1. **Trigger:** whenever a bug, a surprise or a failed assumption costs more than one build-and-fix cycle, or is found by luck, or could silently affect players, write it down as a **candidate** in the feature's `research.md`, section "Pitfall candidates": one line saying what happened and the verdict of the filter above (add / extend P-0XX / skip, with the reason). Do this at the moment it happens, not at the end.
2. **Promotion:** at the quality gate, every candidate whose verdict is "add" or "extend" is written into this file, in the same change set as the mod, with the template below. Candidates marked "skip" stay in `research.md` as history.
3. **Review:** the gate also re-reads the list against the finished work (see below), so an entry created now protects the next feature.

## How to use this list

1. **Plan:** read the whole list. In `plan.md` (section "Known Pitfalls Check") and in the completion summary, write one line per entry: `relevant` with the safeguard you chose, or `not relevant` with the reason.
2. **Before finishing:** re-read the entries marked relevant and verify the safeguard exists in the code and, when possible, in a test or in-game check.
3. **After any new problem:** apply the filter above; if it passes, add or extend an entry with the template at the bottom, in the same change that fixes it. Keep entries short and concrete.

Entry fields: **Symptom** (what the player or developer saw), **Cause** (what we know, and how sure we are), **Avoid it** (the safeguard), **Check** (how to verify it), **Seen in** (where it happened).

---

## P-001: Mod-spawned items make the game's item lists grow without control

- **Symptom:** items that a mod generates in levels (drops, rewards, starting items) kept adding up in the game's persistent item lists, so the list of items expanded without limit across levels and saves.
- **Cause:** spawned items are registered in the game's own save structures (`StatsManager.item`, `StatsManager.itemStatBattery`, `itemsPurchased`), and anything that is never collected or consumed stays registered unless the mod removes it. Instance names are assigned asynchronously (`PunManager.SetItemNameLOGIC`), so cleanup cannot rely on the name at spawn time.
- **Avoid it:**
  - Put a hard cap on what the mod spawns per level and what it preserves between levels (EnemyDrops: `MaxDropsPerLevel`, `MaxPreservedItems`), configurable and with a safe default.
  - Track every instance the mod creates and, before the game saves (prefix on `SemiFunc.OnSceneSwitch`), remove the ones that were not preserved from the item lists.
  - Reuse `RepoAPI.Items.ItemPreservation` instead of writing new persistence code.
  - Decrement the counters when an item is consumed or destroyed (`StatsManager.ItemRemove`) and reset them on a new run (`StatsManager.RunStartStats`).
- **Check:** play several consecutive levels with the mod producing many items and confirm the item lists and the save file do not keep growing; confirm abandoned items disappear from the lists at the level change.
- **Seen in:** EnemyDrops, ExtractionPointReward (see their `ARCHITECTURE.md` for the working implementation).

## P-002: Shop items inherit the battery of mod-spawned items

- **Symptom:** items bought in the shop arrived with a low battery that belonged to a different item the mod had spawned earlier (fixed in EnemyDrops 1.1.0).
- **Cause:** the battery state lives in `StatsManager.itemStatBattery`, keyed by instance names such as `"Item Gun Shotgun/1"`. When the entries for mod-spawned instances are left behind (or are created before the real name exists), a later item that gets the same name picks up that stale battery. Likely the same root as P-001: stale data in the item lists.
- **Avoid it:** the same cleanup as P-001, specifically removing the `itemStatBattery` entry together with the `item` entry for every non-preserved instance; link each spawned GameObject to its battery key only after the instance name has been assigned; never write to those dictionaries from a path that also serves shop purchases.
- **Check:** after a level where the mod spawned battery items that were abandoned, open the shop and confirm purchased items start with full battery.
- **Seen in:** EnemyDrops.

## P-003: In singleplayer every PhotonView id is 0

- **Symptom:** two different valuables reported the same id in singleplayer, so a registry keyed by view id would have mixed them up.
- **Cause:** objects have no allocated view id outside a Photon room; in a lobby they get real ids (for example 92). Observed in Pockets (Museum Tooth, Museum Fish and Wizard Bird Skull all had 0).
- **Avoid it:** use the view id as a key only in multiplayer and `GameObject.GetInstanceID()` in singleplayer, behind one small helper (`PocketedValuable.Key`).
- **Check:** unit tests accept 0 and negative keys; test with two objects in singleplayer.
- **Seen in:** Pockets.

## P-004: A running game locks the deployed DLL

- **Symptom:** `dotnet build` succeeds but the post-build copy fails with exit code 4 (warning MSB3073) and the old DLL stays in the Steam and r2modman folders, so testing silently uses stale code.
- **Cause:** the game keeps `Pockets.dll` open while it runs.
- **Avoid it:** close the game before building, and after building compare the deployed DLL with `bin/<Configuration>/net48` (`cmp`). Remember Debug and Release both deploy: the last build wins.
- **Check:** the deployed DLL matches the intended build before asking someone to test.
- **Seen in:** Pockets.

## P-005: Valuables and hidden objects interact with extraction rooms

- **Symptom (risk found by reading the game code):** a valuable hidden by a mod but still sitting inside an extraction room can be added to the extraction haul list and be counted or destroyed.
- **Cause:** `ValuableObject.Update` adds an object to `RoundDirector.dollarHaulList` when its room check reports an extraction room.
- **Avoid it:** remove it from the haul list when hiding, guard `AddToDollarHaulList`, and refuse to hide objects that are `committedToExtraction`. Disabling the colliders also empties the room list, which vanilla uses to remove it.
- **Check:** hide a valuable inside the zone and confirm `inHaulList` is false, then restore it and confirm it is counted again (done for Pockets with the spike tools, see its `research.md`).
- **Seen in:** Pockets.

## P-006: Hard-coded lists of game content go stale with every game update

- **Symptom:** a design or a table assumed the game's content (29 Tiny valuables) and the Sunstone update had already added six more, so six valuables had no assigned effect and no icon. Nothing failed: the new content was simply ignored.
- **Cause:** lists of items, valuables, enemies or levels copied from an earlier version of the game's assets are never refreshed automatically.
- **Avoid it:** after each game update, re-extract and diff the content lists (`decompile-game` skill and `repo_assets_extracted_*`), derive tables from the game's own data at runtime when possible, and give anything unassigned a safe default (do nothing) instead of an error.
- **Check:** compare the mod's tables against the current extracted assets; for icons, re-run the icon baker and look for valuables without a packaged icon in the log (`Icon for <name>: rendered/generic`).
- **Seen in:** Pockets and the PocketTalismans concept.

---

## Template for a new entry

```markdown
## P-0XX: Short title

- **Symptom:** what was seen.
- **Cause:** what is known, and how sure we are.
- **Avoid it:** the safeguard.
- **Check:** how to verify it.
- **Seen in:** the mod or mods.
```
