-- Library Books: the books any class can find around the world and hand in,
-- one quest each, to their side's librarian; 10, 20, 25 and 38 handed in
-- unlock four reward quests. The Library tab shows them (UI/LibraryBooks.lua).
-- Written by hand (not generated), from Mike's saved copy of the Wowhead
-- Forever guide "Collecting Library Books: Locations and Rewards" (never
-- fetched), cleaned up: the guide's summary table lists Nar'thalas Almanac
-- in four zones; three are copy errors, and Darkshore is right. Each book's
-- first spot and the order of the books come from Mike's /way list
-- (2026-11-11); the list shows a fold's books in this order. Which books
-- only one side can hand in comes from Mike's saved pages of the two
-- librarians (the quests each ends, with each quest's side), not the guide's
-- "Alliance Only" and "Horde Only" labels. The 38 books' reward comes from
-- Mike's saved page of its quest. The game names each book and gives its
-- icon and tooltip.
--
-- Gaps wait on IDs Mike is looking up: a book whose hand-in quest isn't
-- known for a side (no `quest`, nor that side in `questBySide`) has it
-- learned in game when a player of that side hands the book in
-- (Core/LibraryBooks.lua; dev builds print it). The scraper's `ingest`
-- adds what Mike's characters learned to the book's `questBySide` here
-- (scraper/needroll_scraper/librarybooks.py), changing only that line.
--
--   librarians  each side's librarian: { npc, name (English, until the
--               game's own), place (where in their city) }; their map spots
--               come with the class quests' NPCs (Data/ClassQuests.lua)
--   rewards     the reward quests, fewest books first: { books (handed in
--               to unlock it), quest, name (English, until the game's own),
--               choices (the item IDs to pick one of), level (the level
--               its rewards need, if any) }
--   zones       the zones books sit in, by uiMapID: { lowest level, highest
--               level (Classic's), continent's uiMapID, isCity (a capital,
--               listed as "City") }
--   books       each book: { item, quest (both sides hand it in with this
--               quest), questBySide = { Alliance = quest, Horde = quest }
--               (a book each side hands in with its own quest, as far as
--               known), name (English, until the game's own), side (only
--               that side can hand it in; nil: both), spots = { { zone, x,
--               y }, ... } (the first is where the list places it; more are
--               other spots it spawns at), place (the subzone), how (how to
--               get it) }
local _, ns = ...
local L = ns.L

local KALIMDOR, EASTERN_KINGDOMS = 1414, 1415

ns.Data:RegisterLibraryBooks({
    librarians = {
        Alliance = { npc = 211033, name = "Garion Wendell", place = L["Mage Tower"] },
        Horde = { npc = 211022, name = "Owen Thadd", place = L["Magic Quarter"] },
    },

    rewards = {
        { books = 10, quest = 78150, name = "Friend of the Library", choices = { 277203, 277204 } },
        { books = 20, quest = 79536, name = "Greater Friend of the Library", choices = { 281634, 281635 } },
        { books = 25, quest = 82208, name = "Greater Friend of the Library", choices = { 277254, 277258, 277260 },
          level = 40 },
        { books = 38, quest = 84394, name = "Greater Friend of the Library", choices = { 281637, 281636, 277202 },
          level = 50 },  -- the quest itself can't be taken before 50, so neither can its rewards
    },

    zones = {
        [1429] = { 1, 10, EASTERN_KINGDOMS },        -- Elwynn Forest
        [1420] = { 1, 10, EASTERN_KINGDOMS },        -- Tirisfal Glades
        [1455] = { 1, 10, EASTERN_KINGDOMS, true },  -- Ironforge
        [1454] = { 1, 10, KALIMDOR, true },          -- Orgrimmar
        [1439] = { 10, 20, KALIMDOR },               -- Darkshore
        [1413] = { 10, 25, KALIMDOR },               -- The Barrens
        [1432] = { 10, 20, EASTERN_KINGDOMS },       -- Loch Modan
        [1421] = { 10, 20, EASTERN_KINGDOMS },       -- Silverpine Forest
        [1436] = { 10, 20, EASTERN_KINGDOMS },       -- Westfall
        [1442] = { 15, 27, KALIMDOR },               -- Stonetalon Mountains
        [1431] = { 18, 30, EASTERN_KINGDOMS },       -- Duskwood
        [1437] = { 20, 30, EASTERN_KINGDOMS },       -- Wetlands
        [1441] = { 25, 35, KALIMDOR },               -- Thousand Needles
        [1416] = { 30, 40, EASTERN_KINGDOMS },       -- Alterac Mountains
        [1417] = { 30, 40, EASTERN_KINGDOMS },       -- Arathi Highlands
        [1443] = { 30, 40, KALIMDOR },               -- Desolace
        [1434] = { 30, 45, EASTERN_KINGDOMS },       -- Stranglethorn Vale
        [1418] = { 35, 45, EASTERN_KINGDOMS },       -- Badlands
        [1445] = { 35, 45, KALIMDOR },               -- Dustwallow Marsh
        [1435] = { 35, 45, EASTERN_KINGDOMS },       -- Swamp of Sorrows
        [1444] = { 40, 50, KALIMDOR },               -- Feralas
        [1425] = { 40, 50, EASTERN_KINGDOMS },       -- The Hinterlands
        [1446] = { 40, 50, KALIMDOR },               -- Tanaris
        [1427] = { 43, 50, EASTERN_KINGDOMS },       -- Searing Gorge
        [1447] = { 45, 55, KALIMDOR },               -- Azshara
        [1419] = { 45, 55, EASTERN_KINGDOMS },       -- Blasted Lands
        [1448] = { 48, 55, KALIMDOR },               -- Felwood
        [1428] = { 50, 58, EASTERN_KINGDOMS },       -- Burning Steppes
        [1422] = { 51, 58, EASTERN_KINGDOMS },       -- Western Plaguelands
        [1423] = { 53, 60, EASTERN_KINGDOMS },       -- Eastern Plaguelands
        [1452] = { 55, 60, KALIMDOR },               -- Winterspring
    },

    books = {
        { item = 220348, quest = 81952, name = "Everyday Etiquette",
          spots = { { 1447, 20.7, 62.0 } } },
        { item = 209843, quest = 78124, name = "Nar'thalas Almanac, Vol. 74",
          spots = { { 1439, 59.6, 22.2 } },
          place = L["Ruins of Mathystra"], how = L["Down the stairs, on the third landing"] },
        { item = 215817, quest = 79950, name = "Demons and You",
          spots = { { 1443, 55.1, 26.2 } },
          place = L["Thunder Axe Fortress"], how = L["On a bench inside the big building"] },
        { item = 215822, quest = 79952, name = "RwlRwlRwlRwl!",
          spots = { { 1445, 57.2, 20.8 } },
          place = L["Witch Hill"], how = L["On the ground at the east edge of the murloc camp"] },
        -- The eight books with a questBySide are one series, and its quests
        -- are the Alliance's: Owen Thadd's saved page doesn't list them, so
        -- the Horde's may differ (Mike, 2026-11-07).
        { item = 228134, questBySide = { Alliance = 84397 }, name = "Northern Kalimdor - A Comprehensive Guide",
          spots = { { 1448, 65.2, 3.3 } },
          place = L["Timbermaw Hold"], how = L["By the bridge above the vendor"] },
        -- Its hand-in quest isn't known yet.
        { item = 220347, name = "The Liminal and the Arcane",
          spots = { { 1444, 50.6, 15.7 } } },
        { item = 207972, quest = 79094, name = "The Lessons of Ta'zo", side = "Horde",
          spots = { { 1454, 38.7, 78.4 } },
          place = L["Valley of Spirits"], how = L["Trace the tablet before the Darkbriar Lodge sign"] },
        { item = 209851, quest = 78149, name = "Fury of the Land",
          spots = { { 1442, 74.4, 85.7 } },
          place = L["Grimtotem Camp"], how = L["On a barrel inside one of the tents"] },
        { item = 220346, quest = 81949, name = "Legends of the Tidesages",
          spots = { { 1446, 72.7, 47.8 } } },
        { item = 209847, quest = 78145, name = "Arcanic Systems Manual",
          spots = { { 1413, 56.3, 8.8 } },
          place = L["The Sludge Fen"], how = L["On a chair at the top of the oil rig"] },
        { item = 208800, quest = 79097, name = "Baxtan: On Destructive Magics",
          spots = { { 1413, 62.7, 36.3 } },
          place = L["Ratchet"], how = L["Next to Gazlowe in the engineering building"] },
        { item = 209846, quest = 78143, name = "Secrets of the Dreamers",
          spots = { { 1413, 52.83, 54.70 } },  -- Mike's in-game read (2026-11-18)
          place = L["Wailing Caverns"], how = L["Just outside the instance"] },
        { item = 215683, quest = 79947, name = "Geomancy: The Stone-Cold Truth",
          spots = { { 1441, 34.4, 40.1 } },
          place = L["Darkcloud Pinnacle"], how = L["Inside the largest hut; path up at 31, 37"] },
        { item = 228136, questBySide = { Alliance = 84399 }, name = "Ka-Boom!",
          spots = { { 1452, 60.7, 37.7 } },
          place = L["Everlook"], how = L["Alchemy shop, on the shelf behind Evie Whirlbrew"] },
        { item = 215815, quest = 79948, name = "Defensive Magics 101",
          spots = { { 1416, 48.4, 57.6 } },
          place = L["Gallows' Corner"], how = L["Inside the first tower of the ogre fortress"] },
        { item = 215816, quest = 79949, name = "A Web of Lies: Debunking Myths and Legends",
          spots = { { 1417, 73.6, 65.2 } },
          place = L["Witherbark Village"], how = L["Outside a tent, toward the hut"] },
        { item = 215820, quest = 79951, name = "Mummies: A Guide to the Unsavory Undead",
          spots = { { 1418, 56.7, 39.9 } },
          place = L["The Crypt"], how = L["South foothills of the butte; path starts at 56, 45"] },
        { item = 220353, quest = 81956, name = "Conjurer's Codex",
          spots = { { 1419, 55.4, 32.2 } } },
        { item = 220349, quest = 81953, name = "Stonewrought Design",
          spots = { { 1428, 29.0, 28.9 } },
          place = L["Center Vault"], how = L["One floor down, on the big platform"] },
        { item = 228133, questBySide = { Alliance = 84396 }, name = "Magma or Lava?",
          spots = { { 1428, 29.6, 28.2 } },
          place = L["Blackrock Depths"], how = L["Past Lothos Riftwaker, outside the instance"] },
        { item = 209849, quest = 78147, name = "Crimes Against Anatomy",
          spots = { { 1431, 16.6, 28.5 } },
          place = L["Raven Hill Crypt"], how = L["In the catacombs, entered from the west crypt"] },
        { item = 228135, questBySide = { Alliance = 84398 }, name = "A Study of the Light",
          spots = { { 1423, 71.8, 48.2 } } },
        { item = 228140, questBySide = { Alliance = 84401 }, name = "Scourge: Undead Menace or Misunderstood?",
          spots = { { 1423, 31.3, 21.0 } },
          place = L["Stratholme gates"], how = L["On the table by the gibbets, before the bridge"] },
        { item = 228138, questBySide = { Alliance = 84400 }, name = "The Knight and the Lady",
          spots = { { 1423, 47.3, 42.3 } } },
        { item = 203755, quest = 79092, name = "Archmage Theocritus' Research Journal",
          spots = { { 1429, 65.4, 70.1 } },
          place = L["Tower of Azora"], how = L["On a table halfway up the tower"] },
        { item = 220350, quest = 81954, name = "Venomous Journeys",
          spots = { { 1425, 36.0, 72.8 } } },
        { item = 203754, quest = 79091, name = "Archmage Antonidas: The Unabridged Autobiography", side = "Alliance",
          spots = { { 1455, 75.7, 10.5 } },
          place = L["Hall of Explorers"], how = L["On a table in the centre of the hall"] },
        { item = 208860, quest = 79093, name = "Rumi of Gnomeregan: The Collected Works",
          spots = { { 1436, 52.7, 53.8 } } },
        { item = 209850, quest = 78148, name = "Runes of the Sorcerer-Kings",
          spots = { { 1432, 77.4, 14.0 } },
          place = L["Mo'grosh Stronghold"], how = L["In the ogre cave"] },
        { item = 220352, quest = 81955, name = "A Mind of Metal",
          spots = { { 1427, 37.8, 49.3 } } },
        { item = 210177, quest = 79096, name = "Ataeric: On Arcane Curiosities", side = "Horde",
          spots = { { 1421, 43.4, 41.2 } },
          place = L["The Sepulcher"], how = L["On the table by Sebastian Meloche"] },
        { item = 209844, quest = 78127, name = "The Dalaran Digest, Vol. 23",
          spots = { { 1421, 63.5, 63.1 } },
          place = L["Amber Mill"], how = L["Bookshelf in the northeast corner of the main hall"] },
        { item = 213165, quest = 79535, name = "Basilisks: Should Petrification be Feared?",
          spots = { { 1434, 41.4, 50.9 } },
          place = L["Crystalvein Mine"], how = L["Wooden platform right of the cave entrance"] },
        { item = 215824, quest = 79953, name = "A Luddite's Guide to Caring for Your Demonic Pet",
          spots = { { 1435, 61.4, 22.4 } },
          place = L["Fallow Sanctuary"], how = L["In a cage: Rusted Cage Key from Lost Ones"] },
        { item = 220345, quest = 81947, name = "Sanguine Sorcery",
          spots = { { 1435, 70.0, 51.0 } } },
        { item = 208185, quest = 79095, name = "The Apothecary's Metaphysical Primer",
          spots = { { 1420, 59.4, 52.3 } },
          place = L["Brill"], how = L["Alchemy shop, on the shelf by Apothecary Johaan"] },
        { item = 228141, questBySide = { Alliance = 84402 }, name = "Necromancy 101",
          spots = { { 1422, 69.4, 72.8 } },
          place = L["Caer Darrow"], how = L["Top of Scholomance, outside the instance"] },
        { item = 228132, questBySide = { Alliance = 84395 }, name = "Undead Potatoes",
          spots = { { 1422, 38.3, 54.6 } },
          place = L["Felstone Field"], how = L["Top of the farmhouse stairs"] },
        -- Also on Zephras Isle (map 2521), eight spots.
        { item = 209845, quest = 78142, name = "Bewitchments and Glamours",
          spots = { { 1436, 45.4, 70.5 },
                    { 2521, 35.6, 24.1 }, { 2521, 37.1, 32.9 }, { 2521, 44.3, 26.7 }, { 2521, 51.8, 67.4 },
                    { 2521, 55.7, 59.7 }, { 2521, 61.8, 51.5 }, { 2521, 65.0, 36.3 }, { 2521, 65.5, 69.9 } },
          place = L["Moonbrook"], how = L["Bookshelf in the first house on the left"] },
        -- Mike's /way list puts it in Elwynn Forest (1429), but Whelgar's
        -- Excavation Site is in the Wetlands: kept there until he confirms.
        { item = 209848, quest = 78146, name = "Goaz Scrolls",
          spots = { { 1437, 33.6, 47.9 } },
          place = L["Whelgar's Excavation Site"], how = L["In an urn on the lowest level"] },
    },
})
