# Azeroth Foundry — v1.0.0 (Forever)

*Your Adventurer's Journal*

Azeroth Foundry is a locally saved, account-wide adventurer's journal for **World of Warcraft: Forever**.

## Installation

1. Close World of Warcraft: Forever.
2. Extract the `AzerothFoundry` folder into the Forever client's `Interface/AddOns/` directory. The manifest must be at `Interface/AddOns/AzerothFoundry/AzerothFoundry.toc` (not inside another folder).
3. Start Forever and enable the addon from the AddOns menu. Type `/af` to open it; `/af guide` opens the optional Adventurer's Guide.
4. When updating from an older test version, replace the *entire* `Interface/AddOns/AzerothFoundry` folder so deleted legacy texture files do not linger. **Do not delete your `WTF` folder** or SavedVariables.

This release targets the Forever 1.60.1 interface (`16001`). If the client updates its interface version, the manifest may need to change; interface-number compatibility alone does not certify gameplay APIs.

## Main features

- Characters, account progress and a customizable Overview dashboard.
- Professions, recipe browsing, materials inventory, crafting projects and a player-controlled Crafting Queue.
- Atlas, exploration, active quests and Quest Journal / Recap.
- Discovery-first Collections for mounts, companions, toys and appearances (subject to data exposed by the client).
- Goals, Notes, and optional Self-Found Expeditions with milestones and history.
- Multiple interface themes, Overview customization and an optional Adventurer's Guide.

## Self-Found and saved records

Self-Found is **optional** and hidden by default on a fresh install. Enable it under Settings > Modules if you want personal rules, milestones and Expedition history. It is a journal and challenge tracker, not an anti-cheat or independent verification system.

Data is stored locally in WoW SavedVariables. Inventory snapshots and quest observations may be incomplete or stale when a character is offline. Back up `WTF/Account/.../SavedVariables/AzerothFoundry.lua` before major upgrades.

## Optional reference integrations

ProfessionDB, ItemDB and QuestDB are optional dependencies. Foundry should load without them, but offline catalog and source information may be less complete. These libraries are *not* distributed in this ZIP.

## Useful slash commands

- `/af` — open or close the journal
- `/af guide` — Adventurer's Guide
- `/af theme` — theme settings
- `/af recipes`, `/af queue`, `/af materials` — Workshop
- `/af goals`, `/af notes`, `/af atlas` — journal sections
- `/af deps`, `/af craftstatus` — dependency and crafting diagnostics

## Release notes — v1.0.0

Initial Forever-targeted public package, based on v0.7.5.3, whose theme fixes and recovered-artwork cleanup were verified in Retail. Earlier versions of the Atlas and other features were also tested in the Forever beta. The full v1.0.0 build still needs live Forever testing, particularly crafting, quest updates, Collections data, persistence and any API changes at launch.

This build removes the recovered client BLP texture sheets used by older prototype themes. It retains the custom TGA media and theme-aware Quest Journal and Quest Recap windows from the Retail-tested build.

## Credits and asset notices

OpenMap code/data adaptation: see `OPENMAP_ATTRIBUTION.txt` for attribution and the MIT license notice. Its current source is at https://github.com/openmap-world/openmap . Blizzard names, models, and client-loaded interface artwork belong to Blizzard Entertainment. This package does not bundle recovered Blizzard client BLP sheets.

The initial CurseForge license setting for Azeroth Foundry's original material is All Rights Reserved; third-party material remains under its own terms. The authorship and licensing of included custom TGA artwork should be confirmed before broad redistribution. This file is not a substitute for checking third-party asset rights.
