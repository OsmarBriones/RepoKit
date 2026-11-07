# Charm __DISPLAY__

__EFFECT__: __SUMMARY__

> **Everyone in the lobby must install this mod, together with Pockets and CharmCore.** The power changes what your own character can do and its state shows on your inventory slot, so friends without the mods would see an empty slot and be unable to use the pocket.

## How to Use

1. Find the **__DISPLAY__** valuable and store it in a free inventory slot with [Pockets](https://thunderstore.io/c/repo/p/OsmarBriones/Pockets/) (grab it, press the slot key).
2. TODO: describe when the power triggers.
3. Take the valuable out of the pocket and the power stops.

## Features

- **__EFFECT__:** TODO: one gameplay sentence.
- **It costs the valuable:** each use wears away a share of its value, and a worn-out valuable breaks.
- **Everything is configurable:** wear, pause between uses and anything specific to this power. The host's choices apply to everyone.

## Requirements
- [BepInEx Pack for R.E.P.O.](https://thunderstore.io/c/repo/p/BepInEx/BepInExPack/)
- [Pockets](https://thunderstore.io/c/repo/p/OsmarBriones/Pockets/)
- [CharmCore](https://thunderstore.io/c/repo/p/OsmarBriones/CharmCore/)

## Installation
1. Install through r2modman / Thunderstore Mod Manager (Pockets and CharmCore come with it), or place `__MOD__.dll` next to `Pockets.dll` and `CharmCore.dll` in `BepInEx/plugins`. **All players need it.**
2. Launch the game once; the configuration file is created inside `BepInEx/config`.

## Configuration
Settings are in `com.osmar.__MOD__.cfg` inside `BepInEx/config`, section `Charm.__NAME__`. The host's choices apply to everyone.

- `Enabled` (default `true`): turn this charm on or off.
- `WearPercent` (default `__WEAR__`): share of the valuable's original value lost on each use.
- `CooldownSeconds` (default `__COOLDOWN_TEXT__`): pause between uses. `0` means none.

Section `Debug`: `DebugMode` (default `false`) places a __DISPLAY__ on the floor in front of you when a level starts (host or singleplayer) and writes extra log lines. For testing. `SpawnNow` (default `false`, needs `DebugMode`): set it to `true` while a level is running to place one right away; it switches itself back off.

## Issues & Bug Reports
The official way to report issues, suggest improvements, or submit feedback is by opening an issue on the official GitHub repository:
👉 [GitHub Issues](https://github.com/OsmarBriones/REPO-__MOD__/issues)

## Credits
Developed by **Osmar Briones**
