---
name: deploy-device
description: Deploys a mod build to another Windows machine (a test device on the local network) over key-based SSH, prepares that machine (r2modman, profile), verifies every file by hash and fetches its BepInEx log, so the human only has to open the game there. Includes a one-time setup per device and a way to register several devices.
---

# Deploy Device Skill

Use it when a mod must be tested on another machine (for example a multiplayer test with a second player's PC), in phrases like *"despliega esto en el otro equipo"*, *"prepara el portátil para probar"*, *"lee el log del otro equipo"*, or when `generate-test-battery` reaches the multiplayer phase.

It never publishes anything and never touches Thunderstore. It only writes into the device's r2modman profile.

---

## Model

```
 controller (this machine)                             device (the other machine)
 ┌────────────────────────────┐   SSH (key only, LAN)  ┌────────────────────────────┐
 │ register-device.ps1        │ ─────────────────────▶ │ OpenSSH server (setup once)│
 │ prepare-device.ps1         │                        │ r2modman + profile "Debug" │
 │ deploy-device.ps1  (build) │ ── scp DLLs + hashes ─▶ │ BepInEx\plugins\*.dll      │
 │ get-device-log.ps1         │ ◀── LogOutput.log ───── │ BepInEx\LogOutput.log      │
 └────────────────────────────┘                        └────────────────────────────┘
```

- Devices live in a per-user registry **outside every repository**: `<user profile>\.repo-mods\devices.json` (override with `REPO_MODS_DEVICE_STORE`). Nothing secret is stored; the connection uses the controller's existing SSH key and the device only holds its public key.
- Changing devices is just registering another name; every command takes `-Name`.
- Scripts run on Windows PowerShell 5.1 and PowerShell 7 and resolve paths dynamically (no machine-specific paths).

## Security rules for the agent

- The agent **never asks for, types or stores a password**. Key logins only; password logins are turned off on the device.
- The one-time device setup (`setup-device.ps1`) is run **by the human, as administrator, on the device**, after reading it. The agent does not run it remotely.
- The setup opens SSH only for the **Private** network profile and only from the **local subnet**. `-Remove` undoes everything.
- Installing r2modman on a device is an explicit step (`prepare-device.ps1 -InstallR2Modman`). The default source is winget (`ebkr.r2modman`); the GitHub installer is used only with `-AllowDownload`.
- Say what a command will change on the device before running anything that is not read-only.

## One-time setup of a new device (three steps, one of them on the device)

1. **Controller:** print the single command for the new device.
   ```powershell
   powershell -ExecutionPolicy Bypass -File RepoKit/skills/deploy-device/scripts/register-device.ps1 -PrintBootstrap
   ```
   (If there is no SSH key yet, create one first with `ssh-keygen -t ed25519`.)
2. **Device, as administrator, in PowerShell:** paste that one command. It downloads `setup-device.ps1` and runs it (the command is for PowerShell, not cmd): installs the OpenSSH server for key logins only, turns passwords off, authorizes your key, opens port 22 for the local subnet on Private networks only, makes PowerShell the SSH shell, installs r2modman if missing (winget) and finally prints a line starting with `REPO-DEVICE-CODE:`. To read the script before running it, download it first (the controller prints that variant too).
3. **Controller:** register from that line and prepare everything in one go.
   ```powershell
   powershell -ExecutionPolicy Bypass -File RepoKit/skills/deploy-device/scripts/register-device.ps1 -Code "REPO-DEVICE-CODE:..." -Name laptop -Prepare
   ```
   The code carries the computer name, user and IP addresses, so nothing is typed by hand; the device keeps the addresses as fallbacks if its IP changes. `-Prepare` checks the game, installs r2modman if it is still missing and **creates the r2modman profile on the device from this machine's own BepInEx files** (`prepare-device.ps1 -SeedProfile`; BepInEx core only, none of your mods).

What cannot be automated from here: installing **R.E.P.O. through Steam** on the device, and, in case r2modman does not list the seeded profile, opening r2modman once on the device to choose R.E.P.O. (or to create the profile there by hand; r2modman then installs BepInEx itself). `prepare-device.ps1` tells you which of these is still pending.

Manual variant (no code): `register-device.ps1 -Name laptop -HostName <name-or-ip> -User <windows-user>`.

## Every deploy

```powershell
powershell -ExecutionPolicy Bypass -File RepoKit/skills/deploy-device/scripts/deploy-device.ps1 -Name laptop -ModPath REPO-Pockets
```

- Builds each `-ModPath` (Release by default, `-Configuration Debug`, or `-NoBuild`), uploads the DLLs with a hash manifest, copies them into the profile's `BepInEx\plugins`, and **verifies the hash on the device**. Several mods: `-ModPath REPO-Pockets,REPO-TalismanCore`.
- `-ConfigFile <file.cfg>` places a config in `BepInEx\config` (an existing one is backed up first), for example to enable a test option.
- If the game is running on the device it stops, because a running game may block the copy and always keeps the old code in memory (known pitfall P-004). `-Force` copies anyway and tells you to restart the game.
- When it says *Deployed*, the human only has to open the game from r2modman on the device.

## After the test

```powershell
powershell -ExecutionPolicy Bypass -File RepoKit/skills/deploy-device/scripts/get-device-log.ps1 -Name laptop -Pattern 'Pockets|Exception|Error'
```

It copies the device's `LogOutput.log` here, prints the matching lines and the saved path, so the agent can read it exactly like a local log.

## Troubleshooting

| Symptom | Likely cause |
|---------|--------------|
| `running scripts is disabled` | Old versions of these scripts; update RepoKit. They now bypass the execution policy for their own process. |
| `Cannot reach` | The one-time setup was not done, the machines are on different networks, or the device's network is not marked Private. |
| `Permission denied (publickey)` | The controller's public key is not authorized on the device; run `setup-device.ps1` again with the right key. |
| `profile-missing` | Run `prepare-device.ps1 -Name <device> -SeedProfile`, or create the profile by hand in r2modman on the device. |
| `HASH DIFFERS` | The copy was corrupted or the file was replaced; deploy again. |
| `The game is running` | Close the game on the device, or use `-Force` and restart it. |

## What is verified and what is not

- **Verified on a real second machine (2026-11-06):** the registration code, the key-based SSH connection, `setup-device.ps1`, `prepare-device.ps1` (game and r2modman detection, profile creation with `-SeedProfile`), and `deploy-device.ps1` with hash verification (the deployed DLL hash matched the build). The first real run also exposed that Windows blocks unsigned scripts by default; remote scripts are now run through a child PowerShell with the execution policy bypassed for that process only.
- **Verified only on the simulated device (`-Transport local`):** the config backup and the log fetch.
- **r2modman and a seeded profile (verified 2026-11-06 by screenshot):** r2modman lists the `Debug` profile and its BepInExPack entry. A seeded profile has no package cache on the device, so the entry showed a placeholder image; `-SeedProfile` now also copies the BepInExPack cache. Mods deployed by this skill are plain DLLs that BepInEx loads from the plugins folder: **r2modman does not list them** (it only lists what it installed itself), which is expected.
- **First modded launch (verified 2026-11-06):** the device's log, fetched with `get-device-log.ps1`, shows BepInEx starting from the seeded profile, `1 plugin to load`, `Loading [Pockets 1.0.0]` and `Pockets 1.0.0 loaded!` with no errors, so a seeded profile works end to end.
- **Not yet verified:** the winget install path when r2modman is missing; the `-Remove` undo.

## Testing the scripts without a second machine

```powershell
$env:REPO_MODS_DEVICE_STORE = "$env:TEMP\devices-test.json"
register-device.ps1 -Name fake -Transport local -LocalRoot <folder>   # create <folder>\AppData\r2modmanPlus-local\REPO\profiles\Debug\BepInEx\{core,plugins} first
prepare-device.ps1 -Name fake
deploy-device.ps1 -Name fake -ModPath <mod> -NoBuild -Force
```
