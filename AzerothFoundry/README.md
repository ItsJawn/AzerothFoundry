# Azeroth Foundry — v1.0.31 (Training Guides & Stability)

*Your Adventurer's Journal*

Azeroth Foundry is a locally saved, account-wide adventurer's journal for **World of Warcraft: Forever**.

## Installation

1. Close World of Warcraft: Forever.
2. Extract the `AzerothFoundry` folder into the Forever client's `Interface/AddOns/` directory. The manifest must be at `Interface/AddOns/AzerothFoundry/AzerothFoundry.toc` (not inside another folder).
3. Start Forever and enable the addon from the AddOns menu. Type `/af` to open it; `/af guide` opens the optional Adventurer's Guide, and `/af changelog` opens the latest release notes.
4. When updating from an older test version, replace the *entire* `Interface/AddOns/AzerothFoundry` folder so deleted legacy texture files do not linger. **Do not delete your `WTF` folder** or SavedVariables.

This release targets the Forever 1.60.1 interface (`16001`). If the client updates its interface version, the manifest may need to change; interface-number compatibility alone does not certify gameplay APIs.

## v1.0.31 — Training Guide & Stability Release

- Updated and modularized all eight curated profession guides to cover skill **1–300**.
- Corrected selected Forever-specific route transitions; added guide review warnings and consolidated adjacent duplicate recipe nodes.
- Improved Auctionator/vendor material comparisons and green recommendations for cheaper alternatives with no worse estimated skill-up odds.
- Fixed Training profession switching errors and improved three-stage zoom performance.
- Added a new **Changelog** button next to **? Guide** in the journal header, plus the `/af changelog` shortcut.
- Kept the rest of Azeroth Foundry and saved character data intact. See `CHANGELOG.md` for full release notes and `CHANGELOG-v1.0.30.md` for historical notes.

## v1.0.30.7 — Recommended Alternative Recipes (Test Build)

- **Green, theme-aware recommendation cards** highlight learned alternatives only when
  the saved material quotes show a lower estimated total cost **and** the alternative
  covers every skill point in the milestone with equal or better estimated skill-up odds.
- Recommendations are sorted first and shown in Overview as a better-value branch.
  Focusing a step shows the estimated savings, with WoW's native checkmark icon.
- Alternatives with cheaper materials but worse/unknown skill-up odds remain visible,
  without the green recommendation. Missing reagent prices never produce a green pick.
- Selection is **always manual**. Choosing a recommended alternative highlights
  the selected recipe, and Restore Trainer Baseline remains available.
- Price comparisons use recorded Auctionator quotes, actual merchant buy prices,
  or labeled vendor-reference estimates. Quotes may be stale; the highlight is
  not a guaranteed profit or exact gold-saving promise.
- All eight curated routes, guide files, native crafting, scan and milestone UI
  remain unchanged. No SavedVariables migration is needed.

## v1.0.30.6 — Training Route Accuracy Pass (Test Build)

- Corrected Forever skill-color transitions in **Tailoring**, including Woolen Cape,
  Bolt of Mageweave, and the 280-300 finish. The late finish now uses Runecloth
  Shoulders and Mooncloth Robe instead of near-gray Venomspew patterns. The latter
  requires a Spinning Wheel and expensive Mooncloth; it is provisional until
  recipe/pattern availability is verified in the live client.
- **Leatherworking** now stops Wicked Leather Gauntlets before green at 265,
  inserts an orange Runic Leather Headband bridge to 270, and retains the
  supported Heavy Scorpid Helm finish through 300.
- **Blacksmithing** stops Coarse Grinding Stone before green and switches to
  guaranteed-orange Runed Copper Gauntlets for the remainder of that range.
- Clarified that **First Aid 75-80** still uses a documented green fallback,
  because Wool Bandage begins at 80 in the references reviewed.
- All eight profession guides still cover 1-300; unchanged guides remain
  provisional pending individual recipe-source and rank verification.
- No UI, crafting, scanning, theme, animation, or SavedVariables changes.

## v1.0.30.5 — Training Route Consolidation & Guide Sanity Warnings (Test Build)

- **Cleaner Training overview:** consecutive milestone steps using the same recipe and acquisition state now appear as one visual node. For example, 270–300 Heavy Scorpid Helm can be a single card instead of three repeated ten-skill cards. The total estimated craft count is the sum of the original bands.
- **Inspect / Focus:** merged nodes include a combined range and expected craft count, with an optional **Skill-Band Breakdown**. Select an individual band to use its original native Craft 1/Craft All controls and material requirements; no crafting quantities are silently combined or submitted.
- **Guide QA:** a Route Review control flags long single-recipe stretches (20+ skill points) and recipes repeated after an intervening choice. It shows the underlying skill ranges for data review; these warnings do not alter the route automatically.
- Kept the eight curated 1–300 profession datasets, Auctionator/vendor estimates, background scanning, three-state zoom, Theme Studio colors, milestone celebrations, queue safeguards, and SavedVariables schema unchanged.

**Notes:** Visual consolidation does not prove a recipe's skill thresholds or acquisition source. The existing guide-data verification warnings remain in force.

## v1.0.30.2 — Three-Stage Training Zoom (UI Test Build)

- Restored **automatic entry into Focus** when scrolling above 120% in the Training Guide.
- Balanced semantic navigation into three bands: **compact overview** (50–85%), **detailed overview** (85–120%), and **focused milestone** (upper zoom band).
- Mouse wheel moves in **5% increments**, with smoothstep ease-in/ease-out interpolation instead of abrupt target snaps.
- Added a short, theme-aware eased fade for compact/detail and detail/Focus handoffs; frame-heavy graph layouts rebuild only behind the fade or after zoom settles.
- Mouse wheel continues to zoom **within** Focus; it does not unexpectedly eject the player to Overview. The Overview control exits Focus and returns to a readable detailed view.
- Retained v1.0.30.1 profession-selection stability, protected scanning, milestone crafting, native cast progress, guide content, and all existing artwork.

## v1.0.30.1 — Training Stability Hotfix
- Fixed an undefined `EnsureTrainingScan` function call when selecting a different profession in Workshop → Training. Previously the click could throw a Lua error before refreshing the selected guide.
- Profession changes now run the native scan from the original player click, handle API errors without aborting UI selection, and defer the heavier graph rebuild by one frame. Repeatedly selecting the already-active profession is a no-op; use Scan to refresh its data.
- Reduced frame churn when wheel-zooming the training tree by animating the existing graph, only rebuilding the crisp scene at the destination zoom level.
- Debounced graph redraws during window resizing and cleaned up theme handlers belonging to retired graph scenes.
- Preserved v1.0.30's eight curated profession guides and existing crafting, milestone, and Theme Studio behavior.

## v1.0.30 — Training Guide Release

- Training Guides now cover **Alchemy, Blacksmithing, Enchanting, Engineering, Leatherworking, Tailoring, Cooking, and First Aid** from skill **1–300**. The new guides build on the tested Leatherworking UI and use the same native profession scanning, inventory/material calculations, Auctionator estimates, Focus/Overview navigation, optional learned-recipe alternatives, crafting buttons, cast progress, and milestone celebrations.
- Training is for craft-levelable professions. Gathering professions are managed from the regular Professions page; no recipe-based Mining, Herbalism, Skinning or Fishing paths are invented.
- Vendor formulas, skill books and manuals are labeled on their affected guide steps. The reference data is not a guarantee that a specific trainer offers each recipe. Unlearned or unverified steps are never automatically treated as ready to craft.
- Guide rows are estimates that need additional live testing; skill 225–300 is provisionally covered with explicitly labeled special/vendor/book steps. For detailed release notes see `CHANGELOG.md` and for research provenance see `TRAINING_GUIDE_REFERENCES.txt`.

## Training features introduced since v1.0.28

- Training's focused recipe now retains its cast-progress UI references across no-op refreshes, uses Crafting Queue's actual `GetWorkshopCraftCastProgress()` timing, and displays a pending-craft status when timing is not exposed.
- Re-entering the previously active Training page via a clickable Foundry opener attempts the native background profession scan. Training navigation, Focus Current Step, profession selection, and the manual Scan button are also real click paths. Protected OpenTradeSkill cannot be guaranteed from an automatic page-show, slash command, or timer; if the client blocks it, click Scan.
- Wheel zoom adjusts by 5% per notch with eased interpolation. Focus uses its own zoom and never exits to Overview from wheel zoom.
- A real recorded skill increase across a training milestone closes the focused step and then returns to Overview with a Darkmoon-style visual celebration. Optional Blizzard-installed sound cues respect the Fanfare setting; no audio or artwork is bundled.
- The existing crafting, queue safety, and curated Leatherworking guide logic are unchanged.

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

ProfessionDB, ItemDB, QuestDB and Auctionator are optional dependencies. Foundry should load without them, but offline catalog and source information may be less complete. These dependencies are *not* distributed in this ZIP. The Training Planner requires LibProfessionDB for a multi-skill route; Auctionator supplies optional recorded material prices.

## Useful slash commands

- `/af` — open or close the journal
- `/af guide` — Adventurer's Guide
- `/af theme` — theme settings
- `/af recipes`, `/af training`, `/af queue`, `/af materials` — Workshop
- `/af goals`, `/af notes`, `/af atlas` — journal sections
- `/af navstatus` — city guard navigation diagnostics
- `/af deps`, `/af craftstatus` — dependency and crafting diagnostics

## Test changes — v1.0.29.4

- **Unlearned trainer-exclusive recipes:** With Forever LibProfessionDB active, Training considers recipes from its offline catalogue even if the chosen character has not learned them. It only adds an unlearned recipe if its recorded source kinds show **trainer only** (no vendor, drop, quest, or container), its required learn-skill is known, its reagents and difficulty range are usable, and it is not hidden, auto-taught, or specialization-locked. Recipe data alone never proves actual trainer availability.
- **Trainer recipes only toggle:** Optional persisted setting filters *all* training candidates to explicitly trainer-exclusive sources. OFF allows other recipes already learned by the character, but still never assumes an unlearned vendor/drop/quest recipe can be obtained at a trainer.
- **Trainer breakpoints:** When the chosen route switches to an unlearned trainer recipe, a themed `VISIT <profession> TRAINER` notice shows the recipe and required profession skill. Hover provides recorded trainer NPC names when exposed. Borrowed Vanilla source/required-skill records are explicitly labeled **unconfirmed in Forever**.
- **Training safety:** The route can display hypothetical steps through a trainer visit, but the **Queue Estimated Crafts** action remains unavailable until every recipe in the plan is actually learned and the route is recalculated; no automatic trainer or crafting action. Trainer learning fees are NOT yet included in gold optimization.
- **Auction freshness:** Shows the last full AH scan timestamp where the installed Auctionator build exposes `AUCTIONATOR_LAST_SCAN_TIME`; otherwise reports that the precise scan date is unavailable and, if supported, derives a separately labeled approximate date from Auctionator's *per-item* quote ages. Never claims this observation date is the exact full scan date. Missing price-age APIs are handled gracefully.
- **Existing features preserved:** Background profession scanning, goal drafts, priority for guaranteed orange skill-ups, material inventory netting, alternative branches, zoom, pan, theme engine, and original assets.
- **Limitations:** The cheapest route is still a per-skill heuristic rather than a globally proven minimum. LibProfessionDB's Forever trainer-source information is often borrowed from Vanilla, and may not reflect the trainer's actual offerings. Confirm patterns in-game. AH prices are recorded quotes, not current availability. Live Forever testing needed.

## Test changes — v1.0.29.3

- Preserves unsaved target skill input; adds Orange Skill-ups ON/OFF, a reset control for alternatives, and a minimum practical expected skill-up probability to avoid recommending near-gray grinding as an efficient route.

## Test changes — v1.0.29.2

- **Probability curve:** Replaces the original blanket 65% yellow / 30% green assumption with the Classic community estimate `(gray threshold - current skill) / (gray threshold - yellow threshold)`, constrained to valid recipe skill ranges. Only orange is guaranteed. This is still a modeled skill-up expectation, **not** an observed/guaranteed Forever result. The difficulty thresholds come from a matching, verified LibProfessionDB recipe; unverified/placeholder thresholds are excluded.
- **Fewer biased routes:** The recipe comparison now uses expected market cost per skill point. Saved inventory is credited to the final shopping list rather than causing the optimizer to choose an inferior recipe just because its ingredients are already owned. If a competing learned recipe has missing Auctionator quotes, the calculator falls back to fewer expected crafts for that step and reports that cheapest is unverified. Offline prices are not live market guarantees.
- **Real grouped stages:** Adjacent skill steps using the same recipe are presented as one manufacturing stage, even though their skill-up probability changes as skill rises. Stages report the start-to-end modeled chance and aggregate craft count. Stops at the recorded skill cap and warns about low-chance skill ranges where newer trained recipes may be needed.
- **Graph presentation:** Graph uses the Theme Studio `dataSurface` / `dataText` palette family. Recipe icons, item/reagent icons, visible inputs, accent borders and grid guides improve legibility; retains clickable alternative-recipe branches and material requirements.
- **Stale-target safety:** When you edit the target (e.g. 150 to 127), the existing graph is marked outdated and queue export is disabled until the route is recalculated. This fixes the screenshot case where the left input said 127 but the displayed route still said 150.
- **Pan/zoom:** Drag empty graph space to pan; mouse wheel or `+/-` buttons zoom 50–165%; the percentage button resets to 100%; Shift + wheel pans horizontally. Zoom is centered around the viewport center. Retains existing queue export and profession background scan behavior.
- **User test needed:** Check layout/theme contrast, pan/zoom and real LibProfessionDB difficulty inputs in Forever. Revisit a trainer and rescan newly learned recipes before buying materials. Large predicted craft counts remain possible when only green/near-gray recipes are learned.

## Test fixes — v1.0.29.1

- **Forever library detection:** Recognizes interface `16001` without requiring a particular `WOW_PROJECT_ID`. This avoids incorrectly rejecting a ready LibProfessionDB library on a genuine Forever client. Never accepts a different game version's data in its place.
- **Actionable database status:** Training now distinguishes a missing/not-loaded addon, an unregistered library, unloaded data, and the wrong game version. `/af deps` provides the same reason.
- **Training profession selection:** Clicking a profession owned by the current character prepares Blizzard's native profession frame in the same quiet compact session used by the Professions/Recipes pages. The normal delayed recipe scan follows; it never crafts anything. Offline characters remain browse-only, and game combat restrictions still apply.
- Saves, crafting outcomes and the Training Planner's calculation logic are unchanged in this fix. Blizzard-client validation is still required.

## Test notes — v1.0.29 (Workshop Training Planner)

- Added **Workshop > Training**, directly below Professions, with goal editing moved here. Existing per-character Training Goal records and linked Goals projects are preserved; Professions now links into this planner.
- The first graph prototype lays out a horizontal skill route, reagent branches, a selectable alternative recipe where available, and trainer rank-cap breakpoints.
- The original v1.0.29 prototype used only verified learned recipes. Starting v1.0.29.4, it additionally considers trainer-exclusive reference recipes with explicit learn requirements, marking Forever-unverified sources and withholding queue export until they are learned.
- Optional **Auctionator** quotes are taken from its recorded item-price API. After scanning the Auction House, calculate again. Unpriced ingredients are always marked unknown, never free. “Cheapest” is a local expected-cost heuristic, not a provably globally optimal route; without prices, it falls back to a fewer-crafts estimate.
- Yellow and green estimated skill chances are provisional (65% / 30%). All expected quantities and inventory balances are **planning estimates**, not guaranteed skill-ups or currently accessible stock.
- Materials produced by earlier route steps are credited against ingredients required by later steps. This is a one-pass projection, not automatic sourcing of missing intermediate crafts.
- **Save Goal** persists the old Training Goal. **Queue Estimated Crafts** asks for confirmation and appends batches in skill order (up to 99 crafts per entry). Queueing does not automatically craft, buy reagents, learn patterns or continue past a skill cap.
- Initial prototype limits: unknown trainer offerings, recipe-source verification, material-buy-versus-subcraft graph choices, responsive re-planning from live skill gains, and vendor-price comparisons need later validation/implementation. Review every generated route before crafting.

## Release notes — v1.0.28 (quiet profession scanning and live crafting cast progress)

- Clicking a current-character profession in Workshop > Professions or Workshop > Recipes prepares Blizzard's native profession interface invisibly and refreshes recorded learned/unlearned recipes as its data loads.
- Profession data-source changes are observed before recording refreshed recipes. The clicked profession is checked against the active native session, so a previous profession's data is not saved under the new one.
- Offline-character entries remain browse-only. Simply selecting an alt's saved recipe data never opens or edits that alt's profession.
- Crafting Queue now shows a native cast-timing bar above Craft 1 / Craft All. It follows genuine profession casts, including individual repeats, and does not claim success or invent a timer before the game reports a cast.
- The existing protected, player-clicked crafting path, form cancellation, and result-based queue crediting remain unchanged.

## Previous release notes — v1.0.27 (camera-plane Transmog panning)

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

## Workshop / Training (v1.0.29.10 prototype)

The curated Leatherworking trainer guide is the only Training view. Its upward-directed milestone graph shows the current step at the bottom and target toward the top. Scroll-wheel zoom switches from compact route cards with an exclamation mark for discovered alternatives to detailed cards. Drag empty canvas to pan. **Focus Current Step** isolates one stage and displays its ingredients, expected crafting count, trainer status, and learned alternatives. The arrows step between milestones; Overview returns to the full graph.

The target skill is edited within the graph header using **Set Goal**, and the character/profession selector is at the top of the right-hand sidebar. The sidebar contains separate shopping lists and price estimates for the **total goal** and the **selected step**. Auctionator prices are only recorded quotes and may be missing or stale.

Skill-up progress animates when Foundry records a profession skill change. Reaching a curated milestone produces a brief visual highlight and optional sound (**Fanfare: ON/OFF**); the first page open never plays a sound. Milestones do not count crafting XP: orange guarantees one skill point, yellow gives a chance, and green/gray are excluded from this curated guide. Queue export still requires learned, verified recipes and never crafts without a player action.

All eight recipe-based professions now have curated 1–300 guide coverage. Gathering professions remain excluded from this crafting planner. The guide is reference data and should be verified in Forever before shopping.


### v1.0.30.3 — Modular profession-guide datasets

Profession Training now loads shared calculations from `Training/TrainingGuide.lua`,
shared material and crafting helpers from `Training/TrainingMaterials.lua`, and
each profession's unchanged curated milestone references from
`Training/Guides/<Profession>.lua`. The existing `UI/TrainingPlanner.lua`
remains the shared UI. No SavedVariables migration is required.

The eight files are **reference route data**, not proof that all Forever
recipes or trainer unlocks have been verified. The guide's existing
uncertainty markers and crafting safeguards remain in place.

`AF:RegisterTrainingGuide(professionName, rows)` expects ordered contiguous
`{skillFrom, skillTo, recipeName, estimatedCrafts, acquisition?, note?}`
rows. Additional guides can be registered in their own file after loading
`Training/TrainingGuide.lua` and before building the Training UI.

### v1.0.30.4 — Extended 1–300 guides and vendor-aware prices

All eight individual profession guides now extend to the skill cap of 300.
Several inefficient or misclassified steps were updated after cross-checking
Wowhead, Mobalytics, Method and Icy Veins (see `Training/GuideSources.md`).
Enchanting rod milestones were moved to their recorded Forever learning skills;
Engineering replaces the green Solid Blasting Powder stretch with Iron Grenades;
Tailoring updates its wool, silk, Mageweave and Runecloth transitions.

Material cost comparisons (including learned-recipe alternatives) now use
saved Auctionator prices and actual vendor purchase quotes, choosing the
cheaper source. Common trade supplies have labeled **vendor reference prices**
where a live vendor quote has not yet been observed. Costs and recipe acquisition
sources remain provisional when the current game data cannot confirm them.

The existing focus/zoom UI, native crafting, profession scanning, and fanfare
systems were not changed in this release.
