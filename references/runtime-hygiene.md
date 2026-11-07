# Runtime hygiene check

A mod runs inside a game that loads and destroys whole levels, many times per session, next to dozens of other mods. A mod that
leaves things alive after its time, or computes things nobody needs, is not necessarily wrong today, but it makes crashes, slowdowns
and leaks possible and hard to trace. This check is a short review done for **every mod** before it is finished (a gate next to the
known pitfalls gate): go through the list, fix what applies and record the result in `plan.md`, section "Runtime Hygiene Check".

It exists because a crash inside Unity's memory scan when leaving a level could not be shown to be caused by a charm, but the
charms did keep references to the level's objects until the next level started, and did a lot of work every frame. Nothing proved the
mod guilty; nothing proved it innocent; the review removes the doubt.

## The checklist

### 1. Lifetime of references
- Nothing static or long-lived (static fields, singletons, plugin fields, caches) holds game objects (valuables, enemies, players,
  UI elements) longer than the level. Hold ids, not objects, when an id is enough.
- Clear per-level state **when the level ends** (not only when the next one starts): lists, sets, dictionaries, per-player
  accumulators, last-seen caches. In a charm: override `Charm.OnLevelEnded`.
- Working buffers (lists reused between scans) are emptied after use, so they do not keep references between scans.
- Every cache or set that can grow has a cap or is cleared at a natural boundary.
- Event subscriptions are removed (`OnDisable`/`OnDestroy`) and anything the mod changed in the game (speeds, UI sizes, flags) is
  restored when the effect stops (see P-007).

### 2. Work frequency
- Nothing is computed every frame that can be event-driven or throttled. Scans of the level (valuables, enemies, players) run at
  0.2 to 1 second intervals, not every frame; read-only checks may run at a lower rate than the effect they feed.
- Work that depends on a condition does nothing, and allocates nothing, while the condition is false (check `IsActive` first).
- Do not recompute what has not changed: store the last inputs of a calculation and skip it when they are the same.

### 3. Allocations in hot paths
- `Update`, `FixedUpdate` and prefixes/postfixes of frequently called game methods allocate nothing: no LINQ, no new lists or
  arrays, no string formatting or concatenation unless the value changed; reuse buffers.
- No `FindObjectsOfType`, `FindObjectOfType`, `GameObject.Find` or `GetComponentsInChildren` in per-frame code. Find once and cache,
  and drop the cache with the level.
- A debug log line with an interpolated string is built before the call, even when debug mode is off. In per-frame or hot-patch code
  guard it: `if (charm.DebugMode) { charm.LogDebug($"..."); }`.

### 4. UI
- Change a text, color, size or position only when the value changed: each change makes a TMP text rebuild its mesh and marks the
  canvas dirty. Assign `text` only when the string differs.
- Layout calculations are cached by their inputs.

### 5. Patches
- A patch on a hot method (`Update`, `Hurt`, `Break...`) exits early and cheaply when the mod is inactive and does O(1) work.
- Patches never keep state that outlives the call, except through the places covered by item 1.

## How to record it

In `plan.md` ("Runtime Hygiene Check"), one line per item: `ok`, `fixed` (what was changed) or `not applicable` (why). Re-check before
finishing; a change that adds a cache, a scan or a UI element reopens the relevant item.

## Automatic help (charm mods)

- CharmCore calls `Charm.OnLevelEnded` when a level ends and clears its own tracking; the cooldown view touches the UI only when
  something changed.
- `CharmRulesTests` (copied into every charm from the `create-charm` template) fails when a charm mod keeps a static field that holds
  a game object, or calls a `Find...` method. A deliberate exception needs a `// hygiene-ok: <reason>` comment on the same or the
  previous line.
- The tests cannot judge frequency or allocations: items 2 to 4 are a human (or agent) review.
