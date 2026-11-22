-- The mage's scrolls, for the Classes tab's Comprehension section
-- (UI/MageScrolls.lua). Written by hand (not generated): the "Scroll of ..."
-- items only a mage can use, read from the WoW: Forever item lists on
-- Wowhead that Mike saved on 2026-10-19. The "Scroll: ..." items anyone can
-- use are left out. Most are new in Forever, so Classic-DB doesn't have
-- them, and the saved pages name no drop sources. The game names each item
-- and gives its icon and tooltip, so only the facts ship. One line per scroll:
--   { item ID, required level (nil: none) },  -- its name
local _, ns = ...

ns.Data:RegisterMageScrolls({
    { 215257 },      -- Scroll of Comprehension
    { 213548 },      -- Scroll of Liminal Passage
    { 213564 },      -- Scroll of Minor Evocation
    { 275067, 5 },   -- Scroll of Imbue Chillknife
    { 274947, 5 },   -- Scroll of Imbue Lesser Flame
    { 217495, 16 },  -- Scroll of Cryoblast
    { 277487, 16 },  -- Scroll of Imbue Baleflame
    { 277485, 16 },  -- Scroll of Imbue Frost
    { 277488, 16 },  -- Scroll of Imbue Iceknife
    { 277489, 16 },  -- Scroll of Imbue Spark
    { 277486, 16 },  -- Scroll of Imbue Striking
    { 277494, 25 },  -- Scroll of Imbue Accuracy
    { 277496, 25 },  -- Scroll of Imbue Balefrost
    { 277497, 25 },  -- Scroll of Imbue Flame
    { 277498, 25 },  -- Scroll of Imbue Manablade
    { 277495, 25 },  -- Scroll of Imbue Quickening
    { 277492, 25 },  -- Scroll of Khadgar's Unlocking
    { 277499, 46 },  -- Scroll of Greater Cryoblast
    { 277500, 46 },  -- Scroll of Imbue Greater Flame
    { 277501, 46 },  -- Scroll of Imbue Greater Frost
    { 277502, 46 },  -- Scroll of Imbue Precision
    { 277503, 46 },  -- Scroll of Imbue Spellbreak
})
