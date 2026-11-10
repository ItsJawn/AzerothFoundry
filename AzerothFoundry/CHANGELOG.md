# Azeroth Foundry — v1.0.31

**Forever 1.60.1 / Interface 16001**  
**Profession Training Guides, Smart Alternatives & Stability**

This public-facing changelog summarizes improvements made **since v1.0.30**, including the v1.0.30.1–v1.0.30.7 test series.

## Training Guides: 1–300
- Eight crafting-based profession guides now cover skill levels **1–300**: Leatherworking, Alchemy, Blacksmithing, Enchanting, Engineering, Tailoring, Cooking, and First Aid.
- Profession routes live in **independent Lua guide files**, using a shared Training engine and material-cost helpers.
- Revised selected skill-up transitions in **Tailoring, Leatherworking, and Blacksmithing** based on Forever-specific recipe references.
- Special **trainer, vendor, book, manual, and faction/source requirements** are labeled where data is available. Unknown requirements stay visibly unverified.
- **Gathering professions** are not falsely presented as recipe-crafting guides.

## Training Tree & Route Review
- Consecutive use of the **same recipe** is consolidated into one readable overview block, with the original skill bands preserved for crafting and materials.
- Focus mode retains **Skill-Band Breakdown** to inspect individual milestones without merging craft submissions.
- Added **Route Review** for unusually long recipe stretches and interrupted recipe reuse. Warnings are advisory; they do not alter the route.
- Balanced compact, detailed and Focus views; improved zoom ease-in/out, panning, and returning to Overview.
- Kept milestone progress, live casting status, and optional Darkmoon-style completion fanfare.

## Material Prices & Discovered Alternatives
- Material estimates can now compare **Auctionator prices** with known **vendor purchase prices**, including labeled baseline estimates for a small set of common vendor supplies.
- Merchant-observed purchase prices override reference prices. Limited-stock items are not treated as unlimited vendor supply.
- Added **green Recommended Alternative** highlighting when a **learned** recipe is cheaper in *estimated total reagent cost* and has **equal or better expected skill-up odds** at every skill point in that band.
- Other discovered alternatives remain available without misleading recommendations; manual selection is always required.
- Unknown, incomplete, or stale prices are not guarantees of savings or sale profit.

## Reliability & Quality-of-Life
- Fixed the Training profession selector Lua error and reduced switching lag.
- Improved native profession scan preparation while respecting client-protected actions.
- Reduced unnecessary Training graph rebuilds during animated zoom.
- Maintained existing Craft 1 / Craft All safeguards, in-game cast timing, and confirmation-based crafting progress.
- Corrected the internal addon version string to match the installed manifest.

## New in v1.0.31
- Added a **Changelog** button beside **? Guide** in the Foundry header, opening a scrollable, theme-aware window showing the release notes for the installed version.
- Added the `/af changelog` shortcut (`/af changes` also works).
- Completed a package, load-order, Training, theme, and preservation audit. See the accompanying audit report for the scope and remaining live-client checks.

**Upgrading:** Replace the `AzerothFoundry` addon folder and retain your SavedVariables. No SavedVariables reset or migration is required for this version.

**Important:** Guide skill-up odds and prices remain estimates where Forever-native verification is unavailable. Route coverage to 300 is not proof every recipe can be learned or crafted on every faction or character. This update does not bypass client-protected crafting restrictions.
