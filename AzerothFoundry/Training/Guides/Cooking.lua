-- Azeroth Foundry: Cooking 1-300 curated Forever training route.
-- Reference bands; live client recipe colors and acquisition sources may differ.
-- Source names in row[5] indicate how to acquire recipes, not reagent sources.
-- Cross-referenced against:
-- https://www.wowhead.com/forever/profession-leveling-guides/cooking
-- https://www.icy-veins.com/wow-forever/professions-overview
local _, AF = ...

AF:RegisterTrainingGuide('cooking', {
    {1, 50, 'Brilliant Smallfish', 50, 'trainer', 'Requires Raw Brilliant Smallfish; compare local fish prices.'},
    {50, 100, 'Longjaw Mud Snapper', 52, 'vendor', 'Recipe sold by fishing or cooking vendors; faction stock varies.'},
    {100, 150, 'Bristle Whisker Catfish', 80, 'vendor', 'Recipe sold by cooking/fishing vendors; obtain Expert Cookbook to raise cap. Verify faction access.'},
    {150, 175, 'Bristle Whisker Catfish', 40, 'vendor', 'May become yellow during this stretch; check actual skill color.'},
    {175, 225, 'Mithril Headed Trout', 52, 'vendor', 'Recipe sold by cooking/fishing vendors.'},
    {225, 275, 'Spotted Yellowtail', 52, 'vendor', 'Learn Artisan Cooking through the Clamlette Surprise quest.'},
    {275, 300, 'Mightfish Steak', 26, 'vendor', 'Recipe sold by Vivianna (Alliance) or Sheendra Tallgrass (Horde).'},
})
