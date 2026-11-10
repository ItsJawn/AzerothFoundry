-- Azeroth Foundry: Engineering 1-300 curated Forever training route.
-- Reference bands; live client recipe colors and acquisition sources may differ.
-- Source names in row[5] indicate how to acquire recipes, not reagent sources.
-- Cross-referenced against:
-- https://www.wowhead.com/forever/profession-leveling-guides/engineering
-- https://mobalytics.gg/wow-forever/guides/engineering-profession-guide
local _, AF = ...

AF:RegisterTrainingGuide('engineering', {
    {1, 30, 'Rough Blasting Powder', 60, 'trainer', 'Save powder for Copper Bombs.'},
    {30, 50, 'Handful of Copper Bolts', 30, 'trainer', 'Save bolts for bombs.'},
    {50, 51, 'Arclight Spanner', 1, 'trainer', 'Keep this Engineering tool.'},
    {51, 75, 'Rough Copper Bomb', 30},
    {75, 90, 'Coarse Blasting Powder', 20},
    {90, 100, 'Coarse Dynamite', 17},
    {100, 105, 'Silver Contact', 5},
    {105, 125, 'Bronze Tube', 25},
    {125, 135, 'Standard Scope', 10},
    {135, 145, 'Heavy Blasting Powder', 20},
    {145, 150, 'Whirring Bronze Gizmo', 15},
    {150, 160, 'Bronze Framework', 15},
    {160, 175, 'Explosive Sheep', 15},
    {175, 185, 'Solid Blasting Powder', 13, 'trainer', 'Save Solid Blasting Powder for later crafts; turn green around 185.'},
    {185, 194, 'Iron Grenade', 12, 'trainer', 'Replaces the inefficient green Solid Blasting Powder grind; uses Iron Bars, Heavy Blasting Powder and Silk Cloth.'},
    {194, 195, 'Gyromatic Micro-Adjustor', 1, 'trainer', 'Keep this tool.'},
    {195, 200, 'Mithril Tube', 6},
    {200, 215, 'Unstable Trigger', 20, 'trainer', 'Save triggers for Hi-Explosive Bombs.'},
    {215, 238, 'Mithril Casing', 33, 'trainer', 'Keep casings for Hi-Explosive Bombs.'},
    {238, 250, 'Hi-Explosive Bomb', 15},
    {250, 260, 'Dense Blasting Powder', 27},
    {260, 285, 'Thorium Widget', 27, 'vendor', 'Schematic sold by Gearcutter Cogspinner (Alliance) or Sovik (Horde).'},
    {285, 300, 'Thorium Tube', 18, 'vendor', 'Schematic sold by Xizzer Fizzbolt in Winterspring; buy on your Engineer.'},
})
