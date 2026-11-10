-- Azeroth Foundry: Leatherworking 1-300 curated Forever training route.
-- Route reviewed Nov 9 2026 against Forever client thresholds; verify availability in-game.
-- Source names in row[5] indicate how to acquire recipes, not reagent sources.
-- Cross-referenced against:
-- https://www.wowhead.com/forever/profession-leveling-guides/leatherworking
-- https://mobalytics.gg/wow-forever/guides/leatherworking-profession-guide
-- Route correction references (do not replace live client verification):
-- https://wowforever.ninja/professions/leatherworking/19049-wicked-leather-gauntlets/
-- https://wowforever.ninja/professions/leatherworking/19082-runic-leather-headband/
-- https://wowforever.ninja/professions/leatherworking/19088-heavy-scorpid-helm/
local _, AF = ...

AF:RegisterTrainingGuide('leatherworking', {
    {1, 30, 'Light Armor Kit', 30},
    {30, 55, 'Cured Light Hide', 28, 'trainer', 'Retain cured hides for later recipes; buy salt from a trade supplier.'},
    {55, 75, 'Embossed Leather Gloves', 21},
    {75, 80, 'Medium Leather', 8},
    {80, 90, 'Cured Medium Hide', 10, 'trainer', 'Save cured medium hides for Dark Leather Belt.'},
    {90, 100, 'Fine Leather Belt', 16, 'trainer', 'Keep 10 belts to use in Dark Leather Belt.'},
    {100, 115, 'Light Leather Pants', 22},
    {115, 125, 'Dark Leather Belt', 10},
    {125, 130, 'Heavy Leather', 7},
    {130, 140, 'Cured Heavy Hide', 20, 'trainer', 'Keep cured hides for later leatherworking.'},
    {140, 155, 'Hillman\'s Leather Gloves', 20},
    {155, 165, 'Barbaric Shoulders', 10},
    {165, 175, 'Guardian Gloves', 10},
    {175, 195, 'Thick Armor Kit', 23, 'trainer', 'Verify live difficulty after 185; the trainer may offer a better orange/yellow recipe.'},
    {195, 210, 'Nightscape Headband', 20},
    {210, 225, 'Nightscape Pants', 15},
    {225, 230, 'Cured Rugged Hide', 6, 'trainer', 'Requires Refined Deeprock Salt; prepare it using a Salt Shaker.'},
    {230, 240, 'Nightscape Boots', 18, 'trainer', 'Confirm the correct Artisan leatherworking trainer teaches this recipe.'},
    {240, 265, 'Wicked Leather Gauntlets', 31, 'vendor', 'Pattern from Leonard Porter or Werg Thickblade; orange until 255, yellow to 264, green at 265.'},
    {265, 270, 'Runic Leather Headband', 5, 'vendor', 'Pattern from Jase Farlane; orange at 265-284. Avoid green Wicked Leather Gauntlets.'},
    {270, 300, 'Heavy Scorpid Helm', 35, 'vendor', 'Pattern from Zannok Hidepiercer (Silithus); orange to 289, yellow 290-299. Reagents include Cured Rugged Hide and Heavy Scorpid Scale.'},
})
