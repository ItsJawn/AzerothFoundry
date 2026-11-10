-- Azeroth Foundry: FirstAid 1-300 curated Forever training route.
-- Reference bands; live client recipe colors and acquisition sources may differ.
-- Source names in row[5] indicate how to acquire recipes, not reagent sources.
-- Cross-referenced against:
-- https://www.wowhead.com/forever/profession-leveling-guides/first-aid
-- https://www.icy-veins.com/wow-forever/professions-overview
local _, AF = ...

AF:RegisterTrainingGuide('first aid', {
    {1, 40, 'Linen Bandage', 41},
    {40, 80, 'Heavy Linen Bandage', 55, 'trainer', 'Turns green at 75, but Wool Bandage is not trainable until 80; 75-80 is a documented green fallback rather than a promised orange/yellow stretch.'},
    {80, 115, 'Wool Bandage', 48},
    {115, 150, 'Heavy Wool Bandage', 48},
    {150, 180, 'Silk Bandage', 41, 'book', 'Expert First Aid rank requires Under Wraps book; sold by Deneb Walker or Balai Lok\'Wein.'},
    {180, 210, 'Heavy Silk Bandage', 41, 'book', 'Manual: Heavy Silk Bandage sold by First Aid vendors.'},
    {210, 240, 'Mageweave Bandage', 41, 'book', 'Manual: Mageweave Bandage sold by First Aid vendors.'},
    {240, 260, 'Heavy Mageweave Bandage', 24, 'special-trainer', 'Requires Artisan First Aid and the Triage quest with a faction doctor.'},
    {260, 290, 'Runecloth Bandage', 40, 'special-trainer', 'Train at your faction\'s Artisan First Aid doctor.'},
    {290, 300, 'Heavy Runecloth Bandage', 11, 'special-trainer', 'Train at your faction\'s Artisan First Aid doctor.'},
})
