-- Azeroth Foundry: First Aid 1-300 curated Forever training route.
-- Cross-checked against Wowhead Forever (Nov 21, 2026), Method (Nov 15),
-- and wow-professions Forever. Only bandages are the default; new Forever
-- healing potions/poultices remain possible learned alternatives.
-- https://www.wowhead.com/forever/guide/professions/first-aid/overview
-- https://www.method.gg/wow-forever/first-aid-in-wow-forever-1-300-leveling-guide-and-trainers
-- https://www.wow-professions.com/forever/first-aid-leveling-guide
local _, AF = ...

AF:RegisterTrainingGuide('first aid', {
    {1, 40, 'Linen Bandage', 45, 'trainer', 'Basic First Aid trainer recipe; one Linen Cloth per craft.'},
    {40, 80, 'Heavy Linen Bandage', 65, 'trainer', 'Trainer recipe, two Linen Cloth per craft. Turns green at 75, but Wool Bandage is only trainable at 80; this is a necessary green fallback.'},
    {80, 115, 'Wool Bandage', 50, 'trainer', 'Trainer recipe, one Wool Cloth per craft.'},
    {115, 150, 'Heavy Wool Bandage', 50, 'trainer', 'Trainer recipe, two Wool Cloth per craft. At First Aid 125, buy and read Expert First Aid - Under Wraps from Deneb Walker (Alliance, Arathi Highlands) or Balai Lok\'Wein (Horde, Dustwallow Marsh), before reaching the 150 cap. Buy Heavy Silk and Mageweave manuals on the same visit.'},
    {150, 180, 'Silk Bandage', 45, 'trainer', 'Silk Bandage is taught by a normal First Aid trainer at skill 150; it is NOT learned from a manual. Expert First Aid rank comes from the Under Wraps book, which can be used from skill 125.'},
    {180, 210, 'Heavy Silk Bandage', 45, 'book', 'Use Manual: Heavy Silk Bandage, sold by Deneb Walker (Alliance) or Balai Lok\'Wein (Horde), to learn this recipe. Requires two Silk Cloth per craft.'},
    {210, 225, 'Mageweave Bandage', 20, 'book', 'Use Manual: Mageweave Bandage, sold by the same Expert First Aid book vendors. Stop at the 225 cap, then complete the Triage quest before crafting more.'},
    {225, 240, 'Mageweave Bandage', 30, 'book', 'Requires Artisan First Aid from Triage at skill 225 and character level 35: Doctor Gustaf VanHowzen (Alliance, Theramore) or Doctor Gregory Victor (Horde, Hammerfall). Keep crafting the already learned Mageweave Bandage after the quest.'},
    {240, 260, 'Heavy Mageweave Bandage', 30, 'special-trainer', 'Learn at skill 240 from your faction Artisan First Aid doctor after completing Triage. Two Mageweave Cloth per craft.'},
    {260, 290, 'Runecloth Bandage', 50, 'special-trainer', 'Learn at skill 260 from your faction Artisan First Aid doctor after completing Triage. One Runecloth per craft.'},
    {290, 300, 'Heavy Runecloth Bandage', 15, 'special-trainer', 'Learn at skill 290 from your faction Artisan First Aid doctor after completing Triage. Two Runecloth per craft.'},
})
