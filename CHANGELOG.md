# Changelog

## 1.4.0 — 2026-09-25

- Defined the workspace testing strategy in `REPO_MODS_METHODOLOGY.md` §8
  (Tier 1: decoupled unit tests via `dotnet test`, Tier 2: Harmony reflection
  contract verification, Tier 3: in-game test harness / fast debug triggers).
- Updated `REPO_MODS_WORKSPACE.md` testing decision and migration status.

## 1.3.0 — 2026-09-25

- Renamed the repository from `repo-mods-guidance` to `RepoKit`, consistent
  with `RepoAPI`. Consuming mods must re-register the submodule at
  `external/RepoKit` (GitHub redirects the old clone URL, but the local path
  and `.gitmodules` entry must be updated by hand).

## 1.2.0 — 2026-09-25

- Documented the exact once-per-task synchronization commands.

## 1.1.0 — 2026-09-25

- Added the mandatory once-per-task shared-guidance synchronization gate.

## 1.0.0 — 2026-09-25

- Established the dedicated repository for REPO Mods shared guidance.
- Added the workspace context, development methodology, version marker, and
  cross-project documentation maintenance rules.
- Defined the once-per-task guidance synchronization gate for consuming mods.
