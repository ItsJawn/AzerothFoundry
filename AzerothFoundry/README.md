# Azeroth Foundry — v1.0.27 (Forever test build)

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
- `/af navstatus` — city guard navigation diagnostics
- `/af deps`, `/af craftstatus` — dependency and crafting diagnostics

## Release notes — v1.0.27 (camera-plane Transmog panning)

- Corrected an armor-preview clipping regression introduced by v1.0.26. The mannequin stays inside a fixed model viewport instead of moving the render frame and its clipping boundaries.
- Uses camera-plane panning: the camera and its look-at point translate by the same vector, preserving camera orientation and model-centered rotation while allowing larger right-drag movements. Mouse-wheel zoom is computed from the native camera baseline.
- Preserves v1.0.24's full-body camera, v1.0.25's expanded 200% pan limits, reset, all transmog search/sort improvements, and all existing game systems.
- Falls back to safe zoom without panning if camera coordinates cannot be obtained from the client. This needs a live Forever visual check before public release.

## Previous release notes — v1.0.26 (flat armor panning)

- Fixed a perspective/skew effect while panning the large Transmog armor preview up or down.
- Armor panning now moves the model's UI viewport inside a clipped frame instead of translating the 3D camera projection. Camera pitch, yaw, facing, orbit target, distance, and roll are not touched by this change.
- Retains 200% panning limits and Reset 3D View; model-frame anchors reset between different selected appearances.
- Leaves gallery thumbnails, weapon/mount/toy viewers, sorting, search, and all other Foundry functionality unchanged.

## Previous release notes — v1.0.25 (simplified Transmog preview and expanded panning)

- Removed the Full Body / Item Focus switch in the large Transmog preview. Full Body is now the permanent default for armor, matching the confirmed-working v1.0.24 viewer.
- Expanded right-drag panning from 80% to 200% of the preview width and height per direction. Reset 3D View returns to the baseline framing.
- Preserved model-centered rotation, mouse-wheel zoom, weapon/item previews, gallery cameras and all other systems.

## Previous release notes — v1.0.24 (full-body camera preview)

- Replaced problematic thumbnail camera offsets with Blizzard's full-body dressing-room camera for large Transmog armor previews.
- Kept model-centered rotation and adjustable zoom/pan; retained native item cameras for the small gallery cards and weapon previews.
- Confirmed in Forever that Full Body mode, rotation, zoom and pan work as intended.

## Previous release notes — v1.0.22 (transmog detail pivot correction)

- Corrected a misplaced orbit pivot in the right-hand Transmog 3D preview. The large detail camera now re-anchors its target to the dressed mannequin when the client exposes the required camera and model coordinates, while preserving the original wardrobe camera orientation.
- Removed inherited horizontal thumbnail offsets from the large detail viewer, avoiding a character standing far off to one side.
- Reduced the automatic camera pullback so full-body previews are not unnecessarily tiny. Zoom, rotation, pan and Reset 3D View remain available.
- Added a model-centred rotation fallback when native camera coordinates cannot be read. Gallery card cameras and standalone weapon previews are unchanged.
- Fixed the Technical/API Details panel reporting `Wardrobe camera: nil` for previews whose camera ID was actually resolved; it now also records the detail orbit's status to help diagnose client differences.
- UI tests and syntax validation passed; this remains a TEST build until the pivot is visually checked in Forever.

## Earlier update — v1.0.20 (gallery camera reuse)

- Started reusing each appearance's native gallery camera in the detail viewer instead of forcing a full-body dressing-room camera. The misplaced pivot from that first implementation is addressed in v1.0.24.

## Earlier update — v1.0.19 (transmog browsing and preview framing)

- Transmog search now resolves actual appearance names incrementally, instead of searching only the initial `Appearance #ID` placeholders. Search can also match appearance IDs, item IDs and names of known appearance sources.
- Added **Game Order**, **Name A–Z** and **Name Z–A** sorting. Game Order follows Blizzard's wardrobe `uiOrder` and slot/category ordering, not arbitrary item IDs.
- Added **All Slots** and **All Armor** to the existing wardrobe slot selector. All Armor includes the eleven armor categories; All Slots includes armor and weapon categories. Existing specific-slot filtering is preserved.
- Large wardrobe views use session-only catalog caching and incremental name lookups; source metadata is not stored as player discovery.
- (Superseded by v1.0.20) Earlier full-body-camera experiments for robes were replaced by native appearance cameras; v1.0.24 further corrects their orbit pivot.
- Corrected an invalid assumption about `GetUICameraInfo`: it returns camera positions and look-at coordinates, not a yaw in the fourth return value. Native model facing is now preserved.
- Compatible with the Forever `16001` interface. These UI changes still require visual verification in the game client.

## Earlier update — v1.0.17 (recorded recipe rarity)

- Recorded Recipes now shows a thin color bar beside each recipe icon indicating the **crafted item's quality**, separately from profession skill-up chance.
- A compact **Rarity** dropdown below the existing search field filters Poor, Common, Uncommon, Rare, Epic, Legendary, Artifact, Heirloom, WoW Token, and Unknown quality (plus All).
- Filtering respects the existing recipe/reagent search, character, profession, learned status, and Expedition scope.
- Unknown or asynchronously loading output quality is never guessed as Common. Quality lookup is rate-limited and refreshed when item data loads.
- The recipe database and crafting logic are unchanged.

## Earlier update — v1.0.16 (city waypoint tracking)

- Selecting a saved city destination now enables native user-waypoint supertracking when Forever accepts the map point.
- A small directional arrow appears on the actual minimap for an active city destination, including guard POIs. It follows facing when rotate-minimap is enabled and hides outside the city or near the destination.
- `/af navstatus` now reports whether the native waypoint was set and whether the minimap arrow is visible.
- No new artwork, dependencies, or global CVars. Native in-world markers are still governed by client settings.

## Earlier experimental features — v1.0.15 (city navigation / terrain experiment)

- **City Navigation (experimental):** While physically inside a city recognized by Forever's map APIs, the Atlas' Selected Region section becomes Navigation. It shows the active guard's available dialogue choices when talking to a guard, plus destination coordinates previously marked by a guard while Foundry was running.
- Selecting a guard option uses the actual guard dialogue. When the client creates a guard direction pin, Foundry remembers the POI and can reselect it later. Selecting a saved destination places a pin on Foundry's map and attempts to use Blizzard's user-waypoint API if permitted.
- This is *not* a full offline city directory yet. Visit and interact with a guard to capture destinations; map API cannot query guard menus when you aren't talking to them. Only positively reported map coordinates are persisted.
- **City terrain fallback (experimental):** Where a validated city map projects into already indexed mainland minimap tiles but provides no exploration masks, display those minimap tiles instead of suppressing all terrain. No guesswork and no changes to outdoor exploration masking.
- **Interiors and dungeons:** Continue to use their supported native map art. Individual interior/instance terrain datasets and multi-floor alignment still need verification; no universal interior terrain claim.
- `/af navstatus` reports the detected city, live guard choices, known destinations, and current marker.
- Tested with static validation and mocked city guards; **in-game city navigation, native waypoint behavior and city ground-layer alignment are not yet confirmed**. Keep v1.0.14 as the public release until verified.

## Release notes — v1.0.14 (interface settings)

- **Auto-hide in combat:** New toggle in Settings > General. If the journal is open when combat begins, Foundry temporarily hides it and brings it back when combat ends. Closed windows stay closed. Disabled by default.
- **Interface:** The existing Scale controls now share an Interface section with a window opacity slider (40–100%). Changes apply immediately and persist through reloads; the minimap button and Blizzard profession frames keep their normal opacity.
- No crafting, recipe, collection, Atlas, or saved gameplay record logic changed.

## Earlier update — v1.0.13 (ingredient-aware recipe search)

- **Recorded Recipes now searches ingredients in the existing search field.** Enter an item name (for example `Rugged Leather`) to find observed recipes that use it as a reagent, or continue searching by recipe name or spell/recipe ID.
- Also accepts reagent item IDs when a client hasn't loaded the localized item name yet.
- Searches the saved native schematic reagents, and can consult optional ProfessionDB for missing schematic data. No new dependency is required.
- Searches only recipes already recorded on the selected characters and professions; does not reveal an undiscovered catalog.
- Item data is loaded asynchronously when necessary, and the recipe list refreshes when the client receives it.
- This is a UI/search-only change; crafting logic, collection discoveries, saved records, and other systems remain unchanged.

## Earlier updates — v1.0.12 (strict toy discovery validation)

- **Fixed false Toys discoveries:** Ordinary vendor weapons, tools, reagents and other items are no longer treated as toys just because the generic Toy Box info or toy tooltip accepts an item ID.
- Requires affirmative evidence: a native Toy Box index entry, a `GetToyLink` whose item link matches the item ID, confirmed `PlayerHasToy` ownership, or the confirmed Forever item ID for Shen'dorei Windwell.
- Previously saved unverified toy observations are **not deleted**. They are hidden from My Discoveries and Reveal All until the game can validate them, at which point the original vendor history reappears automatically.
- `/af toystatus` reports counts of verified and hidden/unverified saved observations.
- The previous mount vendor identification improvements remain unchanged. No map, crafting, UI theme, or artwork code was modified for this fix.

## Earlier updates

All previous fixes through v1.0.12 are included. See the CurseForge/GitHub changelog for earlier details. This remains a **TEST build** pending in-game verification of the latest changes.
