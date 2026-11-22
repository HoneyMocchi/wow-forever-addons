-- Recipe vendors new in WoW: Forever come in pairs: one in The Barrens for
-- the Horde and one in Redridge Mountains for the Alliance, selling the same
-- recipes. The scraped data (Data/RecipeSources.lua) only knows the Horde
-- one, so each pair is written here by hand: every recipe the Horde vendor
-- sells shows them on a Horde character and the Alliance vendor on an
-- Alliance character. One line per pair:
--   [Horde vendor's NPC ID] = { Alliance vendor's name (in L[...]), uiMapID, x, y },  -- Horde vendor, profession
-- (x and y are the game's map coordinates; 1433 is Redridge Mountains.)
-- Vendors who serve one side and have no partner are written with just
-- that side:
--   [NPC ID] = "Alliance" or "Horde",  -- vendor, where
-- Vendors not listed here (and not tagged by the scraped data) show to both.
local _, ns = ...
local L = ns.L

ns.Data:RegisterVendorPairs({
    [248202] = { L["Mivin Shadowweave"], 1433, 10.0, 72.8 },   -- Jim'bek, Tailoring
    [248199] = { L["Alynsia"], 1433, 11.2, 71.6 },             -- Beneris, Enchanting
    [248197] = { L["Stondry Darkhammer"], 1433, 10.4, 74.6 },  -- Gor'mak, Blacksmithing
    [248201] = { L["Daniel Stitchsong"], 1433, 10.0, 72.6 },   -- Pawani, Leatherworking
    [248200] = { L["Fritz Fizzle"], 1433, 10.4, 74.6 },        -- Fizzlefuse, Engineering
    [248196] = { L["Nina Surefire"], 1433, 10.8, 72.6 },       -- Apothecary Durelle, Alchemy
    [248198] = "Horde",     -- Aza'bek, The Barrens: Cooking
    [264078] = "Horde",     -- Sutara Plainstalker, Mulgore: Earthen Ring
    [264797] = "Alliance",  -- Aisarra Nightmeadow, Mount Hyjal
})
