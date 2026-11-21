# Azeroth Foundry v1.0.32 — Secondary Profession Guide Corrections

## Cooking (1–300)

- Starts with **Roasted Boar Meat (1–50)**, learned with Cooking. **Brilliant Smallfish** is a **vendor pattern**, not trainer taught; learned fish recipes can still appear as alternatives after scanning.
- 50–100 **Longjaw Mud Snapper**, 100–150 **Bristle Whisker Catfish**: clarify purchased recipe sources and Journeyman/Expert rank requirements.
- 150–175 **Curiously Tasty Omelet** replaces the green Bristle Whisker Catfish stretch; specify Alliance/Horde pattern vendors and reagents.
- 175–225 **Mithril Headed Trout**, with an Artisan Cooking / Clamlette Surprise checkpoint.
- 225–285 **Spotted Yellowtail**, 285–300 **Nightfin Soup**, both using a standard Cooking Fire. Removed the Mightfish Steak default because current Forever references list an **Iron Oven** requirement, while crafting the Iron Oven itself requires Cooking 300.
- Updated reference craft budgets; yellow crafts may require extras. Pattern purchases, profession training, and Clamlette quest turn-ins are still **not included** in the material-cost total.

## First Aid (1–300)

- Reconciled cloth/bandage craft estimates with current Forever guides.
- Clarifies **Expert First Aid - Under Wraps** at skill 125, the fact **Silk Bandage is trainer-taught**, and manual acquisition for Heavy Silk / Mageweave Bandages.
- Explicitly splits the **225 Triage requirement** from the 210–225 Mageweave band to avoid implying crafting beyond the skill cap without Artisan.
- Clarifies faction doctors and 240/260/290 recipe unlocks. Notes the unavoidable 75–80 green Heavy Linen Bandage fallback.

## Fishing

- Fishing is a third secondary profession but is leveled by catching fish rather than producing recipes. Foundry currently does not offer a catch-based Training Guide. A dedicated fishing-location and rank-unlock guide would require a separate non-crafting model.

## Release notes

- **Official v1.0.32 release**, promoted from the tested v1.0.31.1 guide fixes. The in-game Changelog, addon manifest, and internal version now match the public release.
- No changes to UI behavior, crafting, collection systems, saved data, theme assets, Atlas, or the other six profession guides. No SavedVariables reset is required.
- Reference data cross-checked against Wowhead Forever, Method, wow-professions Forever, Icy Veins, and extracted Forever recipe thresholds. **Individual recipe availability and workstation rules should still be checked in the live client**; guide estimates are not guarantees.

---

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
