-- Azeroth Foundry: Tailoring 1-300 curated Forever training route.
-- Route reviewed Nov 9 2026 against Forever client thresholds; verify availability in-game.
-- Source names in row[5] indicate how to acquire recipes, not reagent sources.
-- Cross-referenced against:
-- https://www.wowhead.com/forever/profession-leveling-guides/tailoring
-- https://www.icy-veins.com/wow-forever/tailoring-leveling-guide
-- Route correction references (do not replace live client verification):
-- https://www.method.gg/wow-forever/tailoring-in-wow-forever-1-300-leveling-guide-and-trainers
-- https://www.wowforever.info/professions/tailoring
-- https://theforeverera.com/en/recipes/tailoring/mooncloth-robe/
local _, AF = ...

AF:RegisterTrainingGuide('tailoring', {
    {1, 30, 'Bolt of Linen Cloth', 30},
    {30, 55, 'Linen Belt', 29},
    {55, 75, 'Bolt of Woolen Cloth', 30, 'trainer', 'Stop the training stage before the recipe becomes green.'},
    {75, 97, 'Woolen Cape', 28, 'trainer', 'Turns green at about 97 in current Forever recipe data; switch before green.'},
    {97, 125, 'Double-stitched Woolen Shoulders', 31, 'trainer', 'Orange to 110, yellow through 126; make Bolt of Silk Cloth separately as materials when needed.'},
    {125, 132, 'Azure Silk Hood', 7},
    {132, 139, 'Lesser Wizard\'s Robe', 8},
    {139, 140, 'Formal White Shirt', 1},
    {140, 147, 'Bolt of Mageweave', 7, 'trainer', 'Skill-up range ends before the recipe becomes green; additional bolts are subcraft materials.'},
    {147, 150, 'Formal White Shirt', 5, 'trainer', 'Yellow through skill 149; avoid green Bolt of Mageweave attempts.'},
    {150, 160, 'Earthen Vest', 10},
    {160, 170, 'Crimson Silk Vest', 11},
    {170, 180, 'Crimson Silk Pantaloons', 13},
    {180, 190, 'Orange Mageweave Shirt', 11},
    {190, 205, 'Black Mageweave Gloves', 18},
    {205, 214, 'Bolt of Runecloth', 12, 'trainer', 'Save Runecloth Bolts for the next milestone.'},
    {214, 225, 'Runecloth Belt', 11},
    {225, 235, 'Runecloth Belt', 13, 'trainer', 'Train Artisan Tailoring to raise the cap from 225 to 300.'},
    {235, 250, 'Runecloth Cloak', 18, 'vendor', 'Pattern sold by Darnall; check faction and availability.'},
    {250, 260, 'Runecloth Boots', 12, 'vendor', 'Pattern sold by Darnall; check source in the current client.'},
    {260, 280, 'Runecloth Cuffs', 25, 'vendor', 'Pattern sold by Pexmit; keep Auctionator pricing current.'},
    {280, 290, 'Runecloth Shoulders', 14, 'drop', 'Pattern required (skill 260); yellow until 290, then green. Verify pattern availability before buying materials.'},
    {290, 300, 'Mooncloth Robe', 14, 'vendor', 'Pattern: Mooncloth Robe (skill 275); requires a Spinning Wheel and Mooncloth. Costly fallback: compare learned alternatives and current AH prices.'},
})
