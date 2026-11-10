-- Azeroth Foundry: Blacksmithing 1-300 curated Forever training route.
-- Route reviewed Nov 9 2026 against Forever client thresholds; verify availability in-game.
-- Source names in row[5] indicate how to acquire recipes, not reagent sources.
-- Cross-referenced against:
-- https://www.wowhead.com/forever/profession-leveling-guides/blacksmithing
-- https://www.icy-veins.com/wow-forever/blacksmithing-leveling-guide
-- Route correction references (do not replace live client verification):
-- https://www.stillsixty.com/recipe/3323
-- https://www.icy-veins.com/wow-forever/blacksmithing-leveling-guide
local _, AF = ...

AF:RegisterTrainingGuide('blacksmithing', {
    {1, 25, 'Rough Sharpening Stone', 30},
    {25, 50, 'Rough Grinding Stone', 30, 'trainer', 'Keep grinding stones for later recipes.'},
    {50, 62, 'Coarse Grinding Stone', 19, 'trainer', 'Turns green around 62-63; keep these for later bronze crafts and make extra as materials, not skill-ups.'},
    {62, 75, 'Runed Copper Gauntlets', 13, 'trainer', 'Guaranteed orange through 74; uses Copper Bars and Rough Grinding Stones.'},
    {75, 95, 'Runed Copper Belt', 23},
    {95, 100, 'Patterned Bronze Bracers', 5},
    {100, 112, 'Heavy Grinding Stone', 20, 'trainer', 'Keep the crafted stones for Golden Scale Bracers.'},
    {112, 125, 'Patterned Bronze Bracers', 13},
    {125, 140, 'Bronze Shortsword', 24},
    {140, 170, 'Bronze Warhammer', 39},
    {170, 175, 'Green Iron Bracers', 9},
    {175, 180, 'Solid Grinding Stone', 8},
    {180, 195, 'Golden Scale Bracers', 20},
    {195, 210, 'Heavy Mithril Gauntlet', 21},
    {210, 215, 'Heavy Mithril Axe', 6},
    {215, 225, 'Heavy Mithril Breastplate', 10},
    {225, 235, 'Dense Weightstone', 15},
    {235, 240, 'Mithril Coif', 12},
    {240, 246, 'Heavy Mithril Boots', 17},
    {246, 250, 'Big Black Mace', 12, 'trainer', 'Requires pearls and grinding stones; check other learned recipes for cheaper crafts.'},
    {250, 257, 'Arcanite Skeleton Key', 10, 'trainer', 'Uses Arcanite Bars: consider your learned alternatives if the AH is expensive.'},
    {257, 270, 'Ebon Shiv', 20, 'vendor', 'Plans sold by Magnus Frostwake; confirm the vendor source in Forever.'},
    {270, 275, 'Bold Dirk', 5, 'vendor', 'Plans sold by Pexmit; may require Azerothium Bars.'},
    {275, 279, 'Ornate Thorium Handaxe', 4, 'vendor', 'Plans sold by Magnus Frostwake.'},
    {279, 300, 'Bold Dirk', 24, 'vendor', 'High reagent cost; compare your discovered recipes and recorded AH quotes.'},
})
