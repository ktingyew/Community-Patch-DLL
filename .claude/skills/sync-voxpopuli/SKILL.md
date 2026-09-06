---
name: sync-voxpopuli
description: Deploy this Vox Populi + EUI checkout into the live Civ V installation (mods, DLC, DLL, text, cache) so changes can be tested in-game. Use when the user asks to sync, deploy, install, or push the mod/build to test it in Civ V, or invokes /sync-voxpopuli by name.
---

## Ownership

This skill owns `Sync-VoxPopuli.ps1` (in this same folder). The user does not run it by hand — this fork exists purely so Claude can manage their personal modding workflow, not to develop/contribute upstream. When they ask to sync/deploy/test their build, run the script yourself via the Bash or PowerShell tool.

## What it does

Deploys the "Vox Populi (with EUI)" component set from this checkout into the live game install:

- `(1) Community Patch`, `(2) Vox Populi`, `(3a) VP - EUI Compatibility Files` → the user's `MODS\` folder (LUA subfolders removed, since EUI provides its own UI)
- `VPUI\`, `UI_bc1\` → Steam `Assets\DLC\`
- `VPUI Text\VPUI_tips_en_us.xml` → user `Text\`
- The two Expansion2 DLC files → `Assets\DLC\Expansion2\`
- Overlays a self-built `CvGameCore_Expansion2.dll` (newest of `BuildOutput\` or `clang-output\`) over the committed one
- Clears the game cache

It's fail-fast: every source path is validated before anything is touched, so a checkout whose file layout doesn't match this script's expectations (e.g. an older/newer VP version) aborts cleanly instead of partially deploying.

## Running it

```powershell
pwsh -File .claude/skills/sync-voxpopuli/Sync-VoxPopuli.ps1              # full deploy
pwsh -File .claude/skills/sync-voxpopuli/Sync-VoxPopuli.ps1 -DryRun       # preview only, no changes
pwsh -File .claude/skills/sync-voxpopuli/Sync-VoxPopuli.ps1 -NoBuiltDll   # deploy the committed DLL, skip self-built overlay
pwsh -File .claude/skills/sync-voxpopuli/Sync-VoxPopuli.ps1 -DllConfig Release
```

Steam/MODS install paths default to the author's own machine, hardcoded in the script — override with `-SteamDir` / `-ModsDir` if that ever changes.

## When invoked

- Default to running the full deploy (no flags) unless the user asks for a dry run or names a specific config.
- If they want to test a change that touches C++ (`CvGameCoreDLL_Expansion2/**`, etc.), build first (`python build_vp_clang.py --config <release|debug>`) before syncing, so the overlay picks up the fresh DLL.
- After running, report what actually got deployed — especially which DLL (committed vs. self-built, Release vs. Debug) — and remind the user to restart Civ V if it's running.
- If the script aborts on missing sources, that means this checkout's file layout doesn't match what the script expects (e.g. VP folder names changed upstream). Don't silently patch around it — tell the user what's missing and ask before touching the script's source-path mappings.
