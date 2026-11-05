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

## One-time setup of a new device

1. **Register it** (on the controller):
   ```powershell
   powershell -ExecutionPolicy Bypass -File RepoKit/skills/deploy-device/scripts/register-device.ps1 -Name laptop -HostName <name-or-ip> -User <windows-user>
   ```
   It saves the device and prints two commands for the device (download `setup-device.ps1`, run it with your public key). If no SSH key exists, create one first with `ssh-keygen -t ed25519`.
2. **On the device, as administrator:** run those two commands. The script installs the OpenSSH server, turns passwords off, authorizes the key, opens port 22 for the local subnet on Private networks, makes PowerShell the SSH shell and prints the host name, IP and user to use.
3. **Prepare it** (controller):
   ```powershell
   powershell -ExecutionPolicy Bypass -File RepoKit/skills/deploy-device/scripts/prepare-device.ps1 -Name laptop -InstallR2Modman
   ```
   It checks the game (Steam), r2modman and the profile, installs r2modman if missing, and lists what is left.
4. **On the device, once:** open r2modman, choose R.E.P.O., create the profile named in the registry (`Debug` by default). r2modman installs BepInEx into it by itself. Install R.E.P.O. from Steam first if needed. These two items cannot be automated from here.
5. `prepare-device.ps1 -Name laptop` again should say the device is ready.

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
| `Cannot reach` | The one-time setup was not done, the machines are on different networks, or the device's network is not marked Private. |
| `Permission denied (publickey)` | The controller's public key is not authorized on the device; run `setup-device.ps1` again with the right key. |
| `profile-missing` | Create the r2modman profile on the device (step 4). |
| `HASH DIFFERS` | The copy was corrupted or the file was replaced; deploy again. |
| `The game is running` | Close the game on the device, or use `-Force` and restart it. |

## What is verified and what is not

The scripts were run end to end against a **simulated device** (a folder on the controller, `-Transport local`): registry, status, deploy with hash verification, config backup and log fetch. **Not yet run against a real second machine:** the SSH/scp transport, `setup-device.ps1`, the r2modman installation and r2modman picking up a profile it has just created. Treat the first real device as the test of those parts and record any problem in `references/known-pitfalls.md` if it passes the filter there.

## Testing the scripts without a second machine

```powershell
$env:REPO_MODS_DEVICE_STORE = "$env:TEMP\devices-test.json"
register-device.ps1 -Name fake -Transport local -LocalRoot <folder>   # create <folder>\AppData\r2modmanPlus-local\REPO\profiles\Debug\BepInEx\{core,plugins} first
prepare-device.ps1 -Name fake
deploy-device.ps1 -Name fake -ModPath <mod> -NoBuild -Force
```
