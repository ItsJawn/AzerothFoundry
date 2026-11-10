-- Azeroth Foundry: Alchemy 1-300 curated Forever training route.
-- Reference bands; live client recipe colors and acquisition sources may differ.
-- Source names in row[5] indicate how to acquire recipes, not reagent sources.
-- Cross-referenced against:
-- https://www.wowhead.com/forever/profession-leveling-guides/alchemy
-- https://www.method.gg/wow-forever/alchemy-in-wow-forever-leveling-guide-and-trainers
local _, AF = ...

AF:RegisterTrainingGuide('alchemy', {
    {1, 10, 'Minor Arcane Elixir', 9},
    {10, 55, 'Elixir of Minor Defense', 45},
    {55, 65, 'Minor Mana Potion', 10},
    {65, 90, 'Elixir of Minor Fortitude', 27},
    {90, 120, 'Elixir of Wisdom', 30},
    {120, 130, 'Lesser Mana Potion', 11},
    {130, 150, 'Fire Oil', 23, 'trainer', 'Check local fish prices against the trainer potion alternative.'},
    {150, 165, 'Elixir of Fire Power', 15},
    {165, 195, 'Mana Potion', 36},
    {195, 205, 'Elixir of Agility', 11},
    {205, 225, 'Greater Mana Potion', 23},
    {225, 240, 'Greater Mana Potion', 20, 'trainer', 'Remember Artisan Alchemy increases the skill cap to 300.'},
    {240, 260, 'Draught of Detect Undead', 23},
    {260, 270, 'Superior Mana Potion', 11, 'vendor', 'Recipe sold by Ulthir (Alliance) or Algernon (Horde).'},
    {270, 300, 'Major Discolored Healing Potion', 32, 'special-trainer', 'Special trainers after a faction questline: Odd Child (Alliance) or Apothecary Renferrel (Horde).'},
})
