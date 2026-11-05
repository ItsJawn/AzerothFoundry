# Azeroth Foundry — v1.0.12 (Forever test build)

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

## Release notes — v1.0.12 (strict toy discovery validation)

- **Fixed false Toys discoveries:** Ordinary vendor weapons, tools, reagents and other items are no longer treated as toys just because the generic Toy Box info or toy tooltip accepts an item ID.
- Requires affirmative evidence: a native Toy Box index entry, a `GetToyLink` whose item link matches the item ID, confirmed `PlayerHasToy` ownership, or the confirmed Forever item ID for Shen'dorei Windwell.
- Previously saved unverified toy observations are **not deleted**. They are hidden from My Discoveries and Reveal All until the game can validate them, at which point the original vendor history reappears automatically.
- `/af toystatus` reports counts of verified and hidden/unverified saved observations.
- The previous mount vendor identification improvements remain unchanged. No map, crafting, UI theme, or artwork code was modified for this fix.

## Earlier updates

All previous fixes through v1.0.11 are included. See the CurseForge/GitHub changelog for earlier details. This remains a **TEST build** pending in-game verification.
