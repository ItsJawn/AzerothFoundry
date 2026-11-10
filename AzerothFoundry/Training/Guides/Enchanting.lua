-- Azeroth Foundry: Enchanting 1-300 curated Forever training route.
-- Reference bands; live client recipe colors and acquisition sources may differ.
-- Source names in row[5] indicate how to acquire recipes, not reagent sources.
-- Cross-referenced against:
-- https://www.wowhead.com/forever/profession-leveling-guides/enchanting
-- https://mobalytics.gg/wow-forever/guides/enchanting-profession-guide
local _, AF = ...

AF:RegisterTrainingGuide('enchanting', {
    {1, 2, 'Runed Copper Rod', 1, 'trainer', 'Save this rod for later enchantments.'},
    {2, 20, 'Enchant Bracer - Inferior Stamina', 18, 'trainer', 'Disenchanting green items can be an early alternative.'},
    {20, 70, 'Enchant Chest - Inferior Stamina', 50, 'trainer', 'May be less efficient than wands; compare discovered alternatives.'},
    {70, 100, 'Enchant Bracer - Minor Stamina', 30},
    {100, 109, 'Enchant Cloak - Minor Protection', 9},
    {109, 110, 'Runed Silver Rod', 1, 'trainer', 'Keep the rod.'},
    {110, 130, 'Enchant Cloak - Minor Protection', 32},
    {130, 150, 'Enchant Boots - Minor Stamina', 20},
    {150, 151, 'Runed Golden Rod', 1, 'trainer', 'Keep the rod.'},
    {151, 165, 'Minor Mana Oil', 16, 'vendor', 'Requires an enchanting-supply vendor formula.'},
    {165, 200, 'Enchant Boots - Lesser Agility', 47},
    {200, 201, 'Runed Truesilver Rod', 1, 'trainer', 'Keep this rod for later enchantments.'},
    {201, 220, 'Lesser Wizard Oil', 25, 'vendor', 'Requires an enchanting-supply vendor formula.'},
    {220, 225, 'Enchant Cloak - Greater Defense', 5},
    {225, 230, 'Enchant Gloves - Agility', 5, 'trainer', 'Artisan Enchanting is trained by Annora in Uldaman.'},
    {230, 235, 'Enchant Boots - Stamina', 5},
    {235, 250, 'Enchant Chest - Superior Stamina', 18},
    {250, 265, 'Lesser Mana Oil', 16, 'vendor', 'Formula sold by Lokhtos Darkbargainer; check access restrictions.'},
    {265, 294, 'Enchant Shield - Greater Stamina', 32, 'vendor', 'Formula sold by enchanting vendors; check faction availability.'},
    {294, 295, 'Runed Arcanite Rod', 1, 'vendor', 'Formula from Lorelae Wintersong; preserve the rod.'},
    {295, 300, 'Enchant Cloak - Superior Defense', 5, 'vendor', 'Formula from Lorelae Wintersong; check the actual Forever source.'},
})
