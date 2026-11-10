# Azeroth Foundry Training Guide Research — November 9, 2026

Scope: curated *reference* progressions from 1–300 for the eight recipe-based
professions. This update is **not** a claim that every listed skill range,
source or material quantity was tested in the live Forever client.

## Primary source sites

- Wowhead: https://www.wowhead.com/forever/profession-leveling-guides
- Mobalytics: https://mobalytics.gg/wow-forever/professions
- Method: https://www.method.gg/wow-forever/professions
- Icy Veins: https://www.icy-veins.com/wow-forever/professions-overview

## Data cross-checks

- Profession skill cap 300 and client-derived color boundaries:
  https://kovarel.com/wow-forever/professions
  https://www.60.tools/guides/professions
- Enchanting rod training requirements at 130/175/220:
  https://www.wowhead.com/forever/guide/professions/enchanting/overview
- Engineering 185–195: use Iron Grenade instead of green Solid Blasting Powder:
  https://www.icy-veins.com/wow-forever/engineering-leveling-guide
  https://mobalytics.gg/wow-forever/guides/engineering-profession-guide
- Tailoring's transition from wool/silk into Runecloth and post-225 vendors:
  https://www.wowhead.com/forever/profession-leveling-guides/tailoring
  https://www.icy-veins.com/wow-forever/tailoring-leveling-guide
- Leatherworking 1–225 baseline and possible Artisan vendor patterns:
  https://www.method.gg/wow-forever/leatherworking-in-wow-forever-leveling-guide-and-trainers
  https://www.wowhead.com/forever/profession-leveling-guides/leatherworking
- Cooking recipes and First Aid expert books/artisan quest:
  https://www.wowhead.com/forever/profession-leveling-guides/cooking
  https://www.wowhead.com/forever/profession-leveling-guides/first-aid
- Alchemy, Blacksmithing, Engineering, Enchanting post-225 route candidates:
  https://www.wowhead.com/forever/profession-leveling-guides/alchemy
  https://www.wowhead.com/forever/profession-leveling-guides/blacksmithing
  https://www.wowhead.com/forever/profession-leveling-guides/engineering
  https://www.wowhead.com/forever/profession-leveling-guides/enchanting

Some references still use Forever beta data or describe alternate valid routes.
The player’s observed recipe list and LibProfessionDB’s skill thresholds are
higher-priority evidence than the editorial guide when they disagree.

## Vendor reference prices (copper before reputation discounts)

- Coarse Thread (2320) 10 copper each:
  https://www.foreverdb.app/en/forever/items/2320/coarse-thread
- Fine Thread (2321) 100 copper each:
  https://www.foreverdb.app/en/forever/items/2321/fine-thread
- Bleach (2324) 25 copper each:
  https://www.foreverdb.app/en/forever/items/2324/bleach
- Mild Spices (2678) 10 copper per 5:
  https://www.foreverdb.app/en/forever/items/2678/mild-spices
- Rune Thread (14341) 5000 copper each:
  https://www.wowhead.com/forever/item=14341/rune-thread
- Crystal Vial (8925) 2500 copper per 5:
  https://foreverdb.net/item/8925

These are reference values only. Foundry’s observed merchant purchase prices
supersede them and are properly marked as observed; it never uses merchant
sell-to-vendor values as player purchase prices.

## Remaining verification work

Verify recipe IDs and names in the loaded ProfessionDB, inspect special/vendor
patterns by faction, compare every route's orange/yellow thresholds against the
live profession window, and compare total material budgets to actual crafting.
In particular, expensive 225–300 vendor-pattern steps are *candidates* with
clear acquisition warnings, not promises the selected trainer teaches them.

### Nov 9, 2026 accuracy pass (v1.0.30.6)

Focused data checks used the live-client-oriented references embedded in
`Guides/{Leatherworking,Tailoring,Blacksmithing}.lua`. Key evidence:

- Wicked Leather Gauntlets: green from 265; Runic Leather Headband: orange
  265-284; Heavy Scorpid Helm: yellow from 290, green only at 300.
- Woolen Cape: green at 97; Bolt of Mageweave: green around 147-148;
  Formal White Shirt stays yellow through 149; Runecloth Shoulders turns green
  at 290; Mooncloth Robe stays yellow through 300 (requires Spinning Wheel).
- Coarse Grinding Stone green near 63; Runed Copper Gauntlets orange through 74.
- First Aid Heavy Linen Bandage green at 75, Wool Bandage learned at 80:
  the 75-80 stretch is an explicit low-chance exception, not orange/yellow.

As always, verify trainers, vendor stock, ranks, reagents, and live color before
purchase. These are reference guide corrections and not a global optimizer.
