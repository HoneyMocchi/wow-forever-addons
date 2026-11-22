-- Travel portals new in WoW: Forever, which the game's world map marks
-- (UI/WorldMapMarkers.lua). Written by hand (not generated). Each portal's
-- object ID, zone and spot are facts read from QuestieDB's WoW: Forever
-- object data (github.com/Questie/QuestieDB,
-- corrections/Forever/generated/foreverBaseObject.lua); nothing of its
-- files is copied. QuestieDB keys a spawn by its zone's AreaTable ID; here
-- it is the game's map ID that zone has (ZONE_MAPS in
-- scraper/needroll_scraper/questie_quests.py: Zephra's Isle 16593 is map
-- 2521). A portal QuestieDB has at a few spots side by side stands at
-- their middle.
--
-- Left out until QuestieDB has a spot for them: Portal To Auberdine
-- (object 716522, in Stormwind City) and Portal to Valanaar (716304, in
-- Mulgore).
--
--   object       the portal's game object ID
--   spot         { uiMapID, x, y }: where it stands, x and y in percent
--   destination  the uiMapID of the city it takes the player to, or of the
--                zone holding the town (Southshore: Hillsbrad Foothills),
--                as the game has no map of the town's own. The tooltip
--                names it as the game's map does, in the client's language
local _, ns = ...

local MAP = {
    ZEPHRAS_ISLE = 2521, DUROTAR = 1411, WETLANDS = 1437, DARKSHORE = 1439,
    DUSTWALLOW_MARSH = 1445, TIRISFAL_GLADES = 1420, ALTERAC_MOUNTAINS = 1416,
    HILLSBRAD_FOOTHILLS = 1424, STRANGLETHORN_VALE = 1434,
    STORMWIND_CITY = 1453, ORGRIMMAR = 1454, THUNDER_BLUFF = 1456, UNDERCITY = 1458,
}

ns.Data:RegisterPortals({
    { object = 716301, spot = { MAP.ZEPHRAS_ISLE, 65.7, 83.3 }, destination = MAP.ALTERAC_MOUNTAINS },  -- to Dalaran
    { object = 716302, spot = { MAP.ZEPHRAS_ISLE, 58.0, 80.5 }, destination = MAP.THUNDER_BLUFF },
    { object = 716523, spot = { MAP.DARKSHORE, 31.0, 41.1 }, destination = MAP.STORMWIND_CITY },
    { object = 716524, spot = { MAP.WETLANDS, 5.3, 57.0 }, destination = MAP.HILLSBRAD_FOOTHILLS },  -- to Southshore
    { object = 716525, spot = { MAP.WETLANDS, 5.6, 63.2 }, destination = MAP.DUSTWALLOW_MARSH },  -- to Theramore
    { object = 716526, spot = { MAP.DUSTWALLOW_MARSH, 71.5, 55.5 }, destination = MAP.WETLANDS },  -- to Menethil
    { object = 716527, spot = { MAP.DUROTAR, 51.0, 13.5 }, destination = MAP.UNDERCITY },
    { object = 716528, spot = { MAP.TIRISFAL_GLADES, 60.9, 58.9 }, destination = MAP.ORGRIMMAR },
    { object = 716529, spot = { MAP.DUROTAR, 50.6, 13.5 }, destination = MAP.STRANGLETHORN_VALE },  -- to Grom'gol
})
