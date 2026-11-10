# Azeroth Foundry — v1.0.30

**Workshop Training Guides — Full Release**

This changelog covers changes **since v1.0.28**, including the v1.0.29 development series.

## New: Workshop → Training

- Dedicated Training Guide page with character/profession selection and saved, character-specific target skills.
- Curated skill milestones and a connected **bottom-to-top training tree**. View the full route or focus an individual step.
- **Eight craft-based professions**, each with a reference guide from skill 1–225: Alchemy, Blacksmithing, Enchanting, Engineering, Leatherworking, Tailoring, Cooking, and First Aid.
- Gathering-only professions (Herbalism, Mining, Skinning, and Fishing) are not presented as recipe-crafting guides.
- Guide acquisition notes distinguish trainer recipes from vendor patterns, Expert books, and manuals. Steps requiring unverified unlocks remain flagged.
- The selected character's learned recipes may appear as optional branches; alternatives do not silently replace the curated route.

## Planning and materials

- Milestone crafting estimates with orange/yellow skill-up awareness and live difficulty observations when available.
- Per-goal and per-step material totals with consistent **Need / Own / Get** quantities and item readiness checks.
- Expandable **one-level material subcraft branches**, with cost-to-craft versus acquisition estimates where available.
- Auctionator integration for recorded auction quotes, freshness information, and optional price/profit comparisons. Vendor purchase prices are only used when actually observed.
- Gold, silver and copper displayed with native game coin icons.
- Estimated route costs exclude unknown prices instead of pretending missing quotes are free.

## Training interface

- Theme Studio-aware data surfaces, native game icons, scalable nodes and connected recipe/material branches.
- Smooth mouse-wheel zoom and drag panning; separate Focus zoom keeps the selected milestone open.
- Overview and Focus Current Step navigation, compact markers for discovered alternatives and expanded focused details.
- Resizable material inspector sidebar using Foundry's original drag handle.
- Progress feedback for skill increases, milestone completion, and an optional Darkmoon-style purple/gold fanfare using built-in game sounds and UI effects.

## Integrated crafting

- Craft 1 / Craft All controls within the focused, active, learned recipe milestone.
- Live casting progress based on the same native timing information as Crafting Queue.
- Background native profession preparation and explicit Scan fallback where Forever requires a player click.
- Preserved Crafting Queue safeguards: no automatic protected actions, no false completion credit, no accidental queue modification, and no crafting from offline characters or unknown recipes.

## Reliability and compatibility

- Reworked ProfessionDB detection, skill-threshold interpretation, and trainer-source diagnostics.
- Fixed target skill edits reverting, disappearing alternative choices, stale plans, and exaggerated near-gray material projections.
- Removed the old speculative Personal Route from the Training interface in favor of the curated guide with player-discovered alternatives.
- Existing Azeroth Foundry systems, custom artwork and saved data retained.

**Compatibility:** World of Warcraft: Forever, interface `16001`.

**Guide scope:** The reference routes cover skill **1–225** in this release. Recipes, training requirements, future difficulty colors, and prices can vary with Forever client data. Unverified steps are not automatically considered ready to craft, and the 225–300 guide expansion requires a later verified dataset. Auctionator and ProfessionDB are optional external addons and are not included in this package.
