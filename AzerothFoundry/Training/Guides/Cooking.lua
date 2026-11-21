-- Azeroth Foundry: Cooking 1-300 curated Forever training route.
-- Route checked against Wowhead Forever (updated Nov 21, 2026),
-- Method (Nov 16, 2026), and wow-professions Forever (Nov 2026).
-- Recipe source describes how to LEARN the recipe; material prices are separate.
-- All suggested finish recipes use a standard Cooking Fire, NOT the
-- skill-300 Iron Oven. Cooking yields and yellow skill gains vary.
-- https://www.wowhead.com/forever/guide/professions/cooking/overview-leveling
-- https://www.method.gg/wow-forever/wow-forever-cooking-profession-leveling-guide-items-and-trainers
-- https://www.wow-professions.com/forever/cooking-leveling-guide
local _, AF = ...

AF:RegisterTrainingGuide('cooking', {
    {1, 50, 'Roasted Boar Meat', 52, 'trainer', 'Learned with basic Cooking; needs Chunk of Boar Meat and a Cooking Fire. Fishing option: Recipe: Brilliant Smallfish must be purchased from a vendor; it is NOT taught by a trainer. Learned fish recipes can appear as alternatives.'},
    {50, 100, 'Longjaw Mud Snapper', 55, 'vendor', 'Buy Recipe: Longjaw Mud Snapper from a fishing or cooking vendor. Train Journeyman Cooking at skill 50 before hitting the 75 cap. Needs Raw Longjaw Mud Snapper and a Cooking Fire.'},
    {100, 150, 'Bristle Whisker Catfish', 55, 'vendor', 'Buy Recipe: Bristle Whisker Catfish from a cooking/fishing vendor. Obtain Expert Cookbook at Cooking 125 from Shandrina (Alliance, Ashenvale) or Wulan (Horde, Desolace), then read it before the 150 cap.'},
    {150, 175, 'Curiously Tasty Omelet', 27, 'vendor', 'Buy Recipe: Curiously Tasty Omelet from Kendor Kabonka (Alliance, Stormwind) or Keena (Horde, Arathi Highlands); a quest reward may also exist. Uses Raptor Egg and vendor Hot Spices at a Cooking Fire. Stays orange to 170; avoids green Bristle Whisker Catfish at 160.'},
    {175, 225, 'Mithril Headed Trout', 55, 'vendor', 'Buy Recipe: Mithril Head Trout from a cooking/fishing vendor, such as Tansy Puddlefizz (Alliance, Ironforge) or Shankys (Horde, Orgrimmar). Needs Raw Mithril Head Trout and a Cooking Fire. Complete Clamlette Surprise at Cooking 225 to raise cap to 300 (requires character level 35).'},
    {225, 265, 'Spotted Yellowtail', 40, 'vendor', 'Complete Clamlette Surprise (Dirge Quikcleave, Gadgetzan; 12 Giant Egg, 10 Zesty Clam Meat, 20 Alterac Swiss) to unlock Artisan. Buy Recipe: Spotted Yellowtail from Gikkix, Steamwheedle Port, Tanaris. Uses a normal Cooking Fire; yellow at 265 and green at 285.'},
    {265, 285, 'Spotted Yellowtail', 32, 'vendor', 'Complete Clamlette Surprise (Dirge Quikcleave, Gadgetzan; 12 Giant Egg, 10 Zesty Clam Meat, 20 Alterac Swiss) to unlock Artisan. Buy Recipe: Spotted Yellowtail from Gikkix, Steamwheedle Port, Tanaris. Uses a normal Cooking Fire; yellow at 265 and green at 285.'},
    {285, 300, 'Nightfin Soup', 18, 'vendor', 'Buy Recipe: Nightfin Soup from Gikkix in Steamwheedle Port, Tanaris. Uses Raw Nightfin Snapper plus vendor Refreshing Spring Water at a Cooking Fire. Orange until 290, then yellow through 300. Do not use Mightfish Steak as the default: Forever lists an Iron Oven requirement (oven is a skill-300 craft).'},
})
