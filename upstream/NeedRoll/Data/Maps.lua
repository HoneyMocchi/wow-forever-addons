-- Dungeon and raid layout maps. The Classic dungeons and raids use
-- Blizzard's own world map art (the Wrath-era drawings), shipped in
-- Media/Maps/Classic: copies of the game's enUS files, since the Russian,
-- Mexican Spanish and Italian clients don't have them (their maps drew as
-- solid green, the game's missing texture). Each level still lists the
-- game's file IDs after the shipped tiles: the game's own map is matched to
-- a level by them (ns.UI.MapFloor). Upper Blackrock Spire's first two
-- floors are drawings the client lacks, shipped in Media/Maps. The dungeons
-- new in Forever use maps by Santiago Reyes (Atlas de Azeroth: Forever),
-- shipped in Media/Maps with his permission and credited under each map;
-- see Media/Maps/CREDITS.txt.
-- Hand-kept. File IDs come from the community file list (wowdev/wow-listfile,
-- interface/worldmap/<map>/<map><level>_<tile>.blp), and the shipped tiles
-- keep those folder and file names. Where Blizzard later redrew a dungeon,
-- these are the drawings of its Classic layout.
local _, ns = ...

local SR = "Interface\\AddOns\\NeedRoll\\Media\\Maps\\"
local CLASSIC = SR .. "Classic\\"
local SR_CREDIT = "Map by Santiago Reyes  " .. ns.DOT .. "  Atlas de Azeroth: Forever"
--[==[@debug@
-- For Data/DevDungeons.lua, the maps not shipped yet.
ns.Data.santiagoMaps = { path = SR, credit = SR_CREDIT }
--@end-debug@]==]

-- instance = { level, level, ..., start = the level shown first (default 1),
--              credit = a line shown under the map }
-- level = { name, tiles, fallback tiles... }: the name is the game's own
-- DUNGEON_FLOOR_<name> string when it has one, else the text itself. Tiles
-- are a 4x3 grid of 256px textures: a number is tile 1's file ID with the
-- rest numbered in file name order (1, 10, 11, 12, 2 ... 9), a table lists
-- tiles 1 to 12, and a string is a texture path that ends in the tile
-- number. A fallback set is tried when the client lacks the first (never
-- for tiles NeedRoll ships); the game's file IDs after the shipped tiles
-- are kept for ns.UI.MapFloor.
-- A level can also list its boss pins, pins = { { encounter ID, x, y,
-- creature display ID (for the portrait) }, ... }, x and y from 0 to 1
-- across the drawn map; the Classic maps get theirs from the list below.
ns.Data:RegisterMaps({
    -- Pins by the rooms named on the map; Plunder's (the pillared hall
    -- before the last boss) is a best guess.
    HALL_OF_THANES = { { "Hall of Thanes", SR .. "HallOfThanes_", pins = {
        { "FALDRIM_ANVILMAR", 0.509, 0.663 },   -- Anvilmar's Rest
        { "MAGMATUS", 0.742, 0.483 },           -- Dark Iron Ingress
        { "PLUNDER", 0.509, 0.508 },
        { "DURGEN_DIRGEHAMMER", 0.512, 0.180 }, -- Reliquary of Kings
    } }, credit = SR_CREDIT },
    RUINS_OF_LORDAERON = { { "Ruins of Lordaeron", SR .. "RuinsOfLordaeron_" }, credit = SR_CREDIT },
    EXCAVATION_SITE_WETLANDS = { { "Excavation Site", SR .. "ExcavationSite_" }, credit = SR_CREDIT },
    CITY_OF_DALARAN = { { "City of Dalaran", SR .. "CityOfDalaran_" }, { "Dalaran Sewers", SR .. "DalaranSewers_" }, credit = SR_CREDIT },
    -- The grove outside first, then the cave off it and the four levels
    -- below, as Santiago numbers them. Bonesnout's pin is in the thicket
    -- named for him; the other bosses wait for a spot placed in game
    -- (/nr devedit).
    BLACKMAW_HOLD = {
        { "Blackmaw Hold", SR .. "BlackmawHold_", pins = {
            { "BONESNOUT_THE_UNBROKEN", 0.760, 0.510 },  -- Bonesnout's Thicket
        } },
        { "Festering Grotto", SR .. "BlackmawHoldGrotto_" },
        { "Depths of the Fallen Grove", SR .. "BlackmawHold1_" },
        { "Depths of the Elders", SR .. "BlackmawHold2_" },
        { "Depths of the Burrow", SR .. "BlackmawHold3_" },
        { "Depths of Forbidden Magic", SR .. "BlackmawHold4_" },
        credit = SR_CREDIT,
    },
    RAGEFIRE = { { "RAGEFIRE1", CLASSIC .. "ragefire\\ragefire1_", 449736 } },
    WAILING_CAVERNS = { { "WAILINGCAVERNS1", CLASSIC .. "wailingcaverns\\wailingcaverns1_", 448454 } },
    DEADMINES = {
        { "THEDEADMINES1", CLASSIC .. "thedeadmines\\thedeadmines1_", 449591 },
        { "THEDEADMINES2", CLASSIC .. "thedeadmines\\thedeadmines2_", 449603 },
    },
    SHADOWFANG = {
        { "SHADOWFANGKEEP1", CLASSIC .. "shadowfangkeep\\shadowfangkeep1_", 448226 },
        { "SHADOWFANGKEEP2", CLASSIC .. "shadowfangkeep\\shadowfangkeep2_", 448238 },
        { "SHADOWFANGKEEP3", CLASSIC .. "shadowfangkeep\\shadowfangkeep3_", 448250 },
        { "SHADOWFANGKEEP4", CLASSIC .. "shadowfangkeep\\shadowfangkeep4_", 448262 },
        { "SHADOWFANGKEEP5", CLASSIC .. "shadowfangkeep\\shadowfangkeep5_", 448274 },
        { "SHADOWFANGKEEP6", CLASSIC .. "shadowfangkeep\\shadowfangkeep6_", 448286 },
        { "SHADOWFANGKEEP7", CLASSIC .. "shadowfangkeep\\shadowfangkeep7_", 448298 },
    },
    BLACKFATHOM = {
        { "BLACKFATHOMDEEPS1", CLASSIC .. "blackfathomdeeps\\blackfathomdeeps1_", 447578 },
        { "BLACKFATHOMDEEPS2", CLASSIC .. "blackfathomdeeps\\blackfathomdeeps2_", 447590 },
        { "BLACKFATHOMDEEPS3", CLASSIC .. "blackfathomdeeps\\blackfathomdeeps3_", 447602 },
    },
    STOCKADE = { { "THESTOCKADE1", CLASSIC .. "thestockade\\thestockade1_", 455959, 450182 } },
    GNOMEREGAN = {
        { "GNOMEREGAN1", CLASSIC .. "gnomeregan\\gnomeregan1_",
            { 449580, 449584, 449585, 449586, 449587, 449588, 449589, 449590, 449627, 449581, 449582, 449583 } },
        { "GNOMEREGAN2", CLASSIC .. "gnomeregan\\gnomeregan2_", 449628 },
        { "GNOMEREGAN3", CLASSIC .. "gnomeregan\\gnomeregan3_", 449640 },
        { "GNOMEREGAN4", CLASSIC .. "gnomeregan\\gnomeregan4_", 449652 },
    },
    RAZORFEN_KRAUL = { { "RAZORFENKRAUL1", CLASSIC .. "razorfenkraul\\razorfenkraul1_", 448106 } },
    SM_GRAVEYARD = {
        { "Graveyard", CLASSIC .. "scarletmonastery\\scarletmonastery1_", 449760,
            { 5333983, 5333984, 5333985, 5333986, 5333987, 5333988,
                5333989, 5333990, 5333991, 5333992, 5333993, 5333994 } },
    },
    SM_LIBRARY = {
        { "Library", CLASSIC .. "scarletmonastery\\scarletmonastery2_", 449772,
            { 5333996, 5333997, 5333998, 5333999, 5334000, 5334001,
                5334002, 5334003, 5334004, 5334005, 5334006, 5334007 } },
    },
    SM_ARMORY = {
        { "Armory", CLASSIC .. "scarletmonastery\\scarletmonastery3_", 449784,
            { 5334009, 5334010, 5334011, 5334012, 5334013, 5334014,
                5334015, 5334016, 5334017, 5334018, 5334019, 5334020 } },
    },
    SM_CATHEDRAL = {
        { "Cathedral", CLASSIC .. "scarletmonastery\\scarletmonastery4_", 449796,
            { 5334037, 5334038, 5334040, 5334041, 5334043, 5334044,
                5334046, 5334047, 5334049, 5334050, 5334052, 5334053 } },
    },
    RAZORFEN_DOWNS = { { "RAZORFENDOWNS1", CLASSIC .. "razorfendowns\\razorfendowns1_", 448094 } },
    ULDAMAN = {
        { "ULDAMAN1", CLASSIC .. "uldaman\\uldaman1_", 448430 },
        { "ULDAMAN2", CLASSIC .. "uldaman\\uldaman2_", 448442 },
    },
    ZULFARRAK = { { "ZULFARRAK", CLASSIC .. "zulfarrak\\zulfarrak", 449820 } },
    MARAUDON = {
        { "MARAUDON1", CLASSIC .. "maraudon\\maraudon1_", 449676 },
        { "MARAUDON2", CLASSIC .. "maraudon\\maraudon2_", 449688 },
    },
    SUNKEN_TEMPLE = {
        { "THETEMPLEOFATALHAKKAR1", CLASSIC .. "thetempleofatalhakkar\\thetempleofatalhakkar1_", 452514 },
    },
    BRD = {
        { "BLACKROCKDEPTHS1", CLASSIC .. "blackrockdepths\\blackrockdepths1_", 447638 },
        { "BLACKROCKDEPTHS2", CLASSIC .. "blackrockdepths\\blackrockdepths2_", 447650 },
    },
    LBRS = {
        { "BLACKROCKSPIRE1", CLASSIC .. "blackrockspire\\blackrockspire1_", 447662 },
        { "BLACKROCKSPIRE2", CLASSIC .. "blackrockspire\\blackrockspire2_", 447674 },
        { "BLACKROCKSPIRE3", CLASSIC .. "blackrockspire\\blackrockspire3_", 447686 },
        { "BLACKROCKSPIRE4", CLASSIC .. "blackrockspire\\blackrockspire4_", 447698 },
        { "BLACKROCKSPIRE5", CLASSIC .. "blackrockspire\\blackrockspire5_", 447710 },
        { "BLACKROCKSPIRE6", CLASSIC .. "blackrockspire\\blackrockspire6_", 447722 },
    },
    -- The game's Blackrock Spire floors 1-6 are Lower Blackrock Spire's.
    -- Upper's first two floors are drawings titled Upper Blackrock Spire
    -- that the client doesn't have (Media/Maps), then Blizzard's Blackrock
    -- Spire floor 7.
    UBRS = {
        { "Dragonspire Hall", SR .. "UpperBlackrockSpire1_" },
        { "Hall of Binding", SR .. "UpperBlackrockSpire2_" },
        { "Blackrock Stadium", CLASSIC .. "blackrockspire\\blackrockspire7_", 447734 },
    },
    DM_NORTH = { { "DIREMAUL1", CLASSIC .. "diremaul\\diremaul1_", 449508 } },
    DM_WEST = {
        { "DIREMAUL2", CLASSIC .. "diremaul\\diremaul2_", 449520 },
        { "DIREMAUL3", CLASSIC .. "diremaul\\diremaul3_", 449532 },
        { "DIREMAUL4", CLASSIC .. "diremaul\\diremaul4_", 449544 },
    },
    DM_EAST = {
        { "DIREMAUL5", CLASSIC .. "diremaul\\diremaul5_", 449556 },
        { "DIREMAUL6", CLASSIC .. "diremaul\\diremaul6_", 449568 },
    },
    SCHOLOMANCE = {
        { "SCHOLOMANCE1", CLASSIC .. "scholomanceold\\scholomanceold1_", 5332424, 448178 },
        { "SCHOLOMANCE2", CLASSIC .. "scholomanceold\\scholomanceold2_", 5332436, 448190 },
        { "SCHOLOMANCE3", CLASSIC .. "scholomanceold\\scholomanceold3_", 5332448, 448202 },
        { "SCHOLOMANCE4", CLASSIC .. "scholomanceold\\scholomanceold4_", 5332460, 448214 },
    },
    STRAT_LIVE = {
        { "STRATHOLME1", CLASSIC .. "stratholme\\stratholme1_", 448322 },
        { "STRATHOLME2", CLASSIC .. "stratholme\\stratholme2_", 448334 },
    },
    STRAT_UNDEAD = {
        { "STRATHOLME1", CLASSIC .. "stratholme\\stratholme1_", 448322 },
        { "STRATHOLME2", CLASSIC .. "stratholme\\stratholme2_", 448334 },
        start = 2,
    },
    MOLTEN_CORE = { { "MOLTENCORE1", CLASSIC .. "moltencore\\moltencore1_", 448058 } },
    ONYXIA = { { "ONYXIASLAIR1", CLASSIC .. "onyxiaslair\\onyxiaslair1_", 448070 } },
    ZULGURUB = { { "ZULGURUB1", CLASSIC .. "zulgurub\\zulgurub", 515607 } },
    BWL = {
        { "BLACKWINGLAIR1", CLASSIC .. "blackwinglair\\blackwinglair1_", 447770 },
        { "BLACKWINGLAIR2", CLASSIC .. "blackwinglair\\blackwinglair2_", 447782 },
        { "BLACKWINGLAIR3", CLASSIC .. "blackwinglair\\blackwinglair3_", 447794 },
        { "BLACKWINGLAIR4", CLASSIC .. "blackwinglair\\blackwinglair4_", 447806 },
    },
    AQ20 = { { "RUINSOFAHNQIRAJ1", CLASSIC .. "ruinsofahnqiraj\\ruinsofahnqiraj", 449748 } },
    AQ40 = {
        { "AHNQIRAJ1", CLASSIC .. "ahnqiraj\\ahnqiraj1_", 450110 },
        { "AHNQIRAJ2", CLASSIC .. "ahnqiraj\\ahnqiraj2_", 450122 },
        { "AHNQIRAJ3", CLASSIC .. "ahnqiraj\\ahnqiraj3_", 450134 },
    },
    NAXXRAMAS = {
        { "NAXXRAMAS1", CLASSIC .. "naxxramas\\naxxramas1_", 252466 },
        { "NAXXRAMAS2", CLASSIC .. "naxxramas\\naxxramas2_", 252478 },
        { "NAXXRAMAS3", CLASSIC .. "naxxramas\\naxxramas3_", 252490 },
        { "NAXXRAMAS4", CLASSIC .. "naxxramas\\naxxramas4_", 252502 },
        { "NAXXRAMAS5", CLASSIC .. "naxxramas\\naxxramas5_", 252514 },
        { "NAXXRAMAS6", CLASSIC .. "naxxramas\\naxxramas6_", 255178 },
    },
})

-- Where each boss stands on the Classic maps above: per instance, per level
-- number, { encounter ID, x, y, creature display ID (for the portrait) or an
-- icon's texture path or atlas }, x
-- and y from 0 to 1 across the drawn map. Worked out offline from CMaNGOS
-- Classic-DB spawn points, lined up with the boss skulls Blizzard drew on
-- the maps; bosses that only appear in an event stand where it happens
-- (Mutanus at Naralex, Ragnaros at the lava in his lair, and so on). Left
-- out where the spot is unknown or off the drawing: Lord Pythas, the Deviate
-- Faerie Dragon, Marduk Blackpool, Vectus,
-- Gandling, Burning Felguard. Many spots have since been dragged into place
-- by Mike in game (/nr devedit), as have the Forever dungeons' pins.
ns.Data:RegisterBossPins({
    RUINS_OF_LORDAERON = {
        [1] = {
            { "WITHERFANG", 0.706, 0.355, 144189 },
            { "RATHMAEL", 0.494, 0.588, 144175 },
            { "VIKTOR_THE_VILE", 0.383, 0.665, 139455 },
            { "THE_BARON", 0.602, 0.703, 144188 },
            { "BJORK", 0.387, 0.239, 144170 },
            { "THE_ABANDONED", 0.408, 0.529, 138667 },
        },
    },
    EXCAVATION_SITE_WETLANDS = {
        [1] = {
            -- Walks back and forth along the road, from the cliff edge east
            -- to the crossroads.
            { "SHADETOOTH", 0.566, 0.470, patrol = { open = true,
                0.521, 0.470, 0.564, 0.463, 0.600, 0.484, 0.634, 0.526, 0.671, 0.553, 0.698, 0.558, 0.733, 0.473, 0.764, 0.500, 0.790, 0.543, 0.835, 0.547, 0.882, 0.551,
            } },
            { "SALTSPINE", 0.398, 0.535, 144209 },
            { "RELIC_GUARDIAN", 0.647, 0.252, 144224 },
        },
    },
    CITY_OF_DALARAN = {
        [1] = {
            { "FEL_ANCIENT", 0.516, 0.552, 129894 },
            { "UNSTABLE_SENTINEL", 0.616, 0.414, 129954 },
            { "ARCANIC_ENIGMA", 0.673, 0.507, 129900 },
            { "ARCANE_ANOMALY", 0.525, 0.842, 129891 },
            { "SHADE_OF_THE_ARCHMAGE", 0.525, 0.207, 130061 },
            { "MANA_DEVOURER", 0.412, 0.745, 129895 },
        },
        [2] = {
            { "ATREXIS_THE_GRAVE_KNIGHT", 0.546, 0.511, 145787 },
            { "LYN_THE_IGNORED", 0.691, 0.167, 130235 },
        },
    },
    RAGEFIRE = {
        [1] = {
            { "OGGLEFLINT", 0.566, 0.384, 11611 },
            { "TARAGAMAN_THE_HUNGERER", 0.410, 0.577, 7970 },
            { "JERGOSH_THE_INVOKER", 0.342, 0.814, 11429 },
            { "BAZZALAN", 0.408, 0.853, 2007 },
        },
    },
    WAILING_CAVERNS = {
        [1] = {
            { "LADY_ANACONDRA", 0.306, 0.430, 4313 },
            { "LORD_COBRAHN", 0.159, 0.566, 4213 },
            { "KRESH", 0.385, 0.350, 5126 },
            { "SKUM", 0.619, 0.738, 4203 },
            { "LORD_SERPENTIS", 0.615, 0.534, 4215 },
            { "VERDAN_THE_EVERLIVING", 0.551, 0.464, 4256 },
            { "MUTANUS_THE_DEVOURER", 0.343, 0.136, 4088 },
            { "LORD_PYTHAS", 0.191, 0.397, 4214 },
            { "DEVIATE_FAERIE_DRAGON", 0.657, 0.584, 1267 },
        },
    },
    DEADMINES = {
        [1] = {
            { "RHAHKZOR", 0.363, 0.612, 14403 },
            { "MINER_JOHNSON", 0.516, 0.501, 556 },
            { "SNEEDS_SHREDDER", 0.506, 0.864, 1269 },
            { "SNEED", 0.546, 0.922, 7125 },
        },
        [2] = {
            { "GILNID", 0.123, 0.756, 7124 },
            { "MR_SMITE", 0.505, 0.173, 2026 },
            { "GREENSKIN", 0.606, 0.348, 7113 },
            { "VANCLEEF", 0.608, 0.467, 2029 },
            { "COOKIE", 0.684, 0.406, 1305 },
        },
    },
    SHADOWFANG = {
        [1] = {
            { "RETHILGORE", 0.667, 0.720, 524 },
            { "COMMANDER_SPRINGVALE", 0.278, 0.599, 3223 },
            { "DEATHSWORN_CAPTAIN", 0.662, 0.466, 3224 },
        },
        [2] = {
            { "BARON_SILVERLAINE", 0.302, 0.765, 3222 },
            { "RAZORCLAW_THE_BUTCHER", 0.484, 0.262, 524 },
        },
        [4] = {
            { "FENRUS_THE_DEVOURER", 0.543, 0.535, 2352 },
        },
        [6] = {
            { "WOLF_MASTER_NANDOS", 0.560, 0.630, 11179 },
            { "ARCHMAGE_ARUGAL", 0.682, 0.332, 2353 },
        },
        [7] = {
            { "ODO_THE_BLINDWATCHER", 0.596, 0.830, 522 },
        },
    },
    BLACKFATHOM = {
        [1] = {
            { "GHAMOO_RA", 0.328, 0.602, 5027 },
            { "LADY_SAREVESS", 0.113, 0.395, 4979 },
            { "GELIHAST", 0.543, 0.567, 1773 },
            { "LORGUS_JETT", 0.614, 0.636, 12822 },
        },
        [2] = {
            { "BARON_AQUANIS", 0.450, 0.771, 110 },
            { "TWILIGHT_LORD_KELRIS", 0.527, 0.817, 4939 },
            { "AKUMAI", 0.857, 0.862, 2837 },
        },
        [3] = {
            { "OLD_SERRAKIS", 0.588, 0.302, 1816 },
        },
    },
    STOCKADE = {
        [1] = {
            { "TARGORR_THE_DREAD", 0.500, 0.211, 517 },
            { "KAM_DEEPFURY", 0.625, 0.292, 825 },
            { "HAMHOCK", 0.782, 0.457, 3250 },
            { "BAZIL_THREDD", 0.860, 0.515, 1621 },
            { "DEXTREN_WARD", 0.217, 0.262, 2149 },
            { "BRUEGAL_IRONKNUCKLE", 0.390, 0.280, 2142 },
        },
    },
    GNOMEREGAN = {
        [1] = {
            { "GRUBBIS", 0.773, 0.665, 6533 },
            { "VISCOUS_FALLOUT", 0.559, 0.563, 5497 },
        },
        [2] = {
            { "CROWD_PUMMELER_9_60", 0.242, 0.678, 6774 },
        },
        [3] = {
            { "ELECTROCUTIONER_6000", 0.431, 0.877, 6915 },
        },
        [4] = {
            { "MEKGINEER_THERMAPLUGG", 0.312, 0.293, 6980 },
            -- Walks back and forth (placed by Mike in dev edit).
            { "DARK_IRON_AMBASSADOR", 0.317, 0.594, 6669, patrol = { open = true, 0.424, 0.672, 0.291, 0.619, 0.301, 0.485 } },
        },
    },
    RAZORFEN_KRAUL = {
        [1] = {
            { "ROOGUG", 0.641, 0.401, 6110 },
            { "AGGEM_THORNCURSE", 0.805, 0.515, 6097 },
            { "DEATH_SPEAKER_JARGBA", 0.873, 0.413, 4644 },
            { "OVERLORD_RAMTUSK", 0.573, 0.307, 4652 },
            { "AGATHELOS_THE_RAGING", 0.079, 0.680, 2450 },
            { "BLIND_HUNTER", 0.095, 0.347, 4735 },
            { "CHARLGA_RAZORFLANK", 0.218, 0.307, 4642 },
            { "EARTHCALLER_HALMGAR", 0.483, 0.452, 6102 },
        },
    },
    SM_GRAVEYARD = {
        [1] = {
            { "INTERROGATOR_VISHAS", 0.721, 0.594, 2044 },
            { "BLOODMAGE_THALNOS", 0.243, 0.560, 11396 },
            { "AZSHIR_THE_SLEEPLESS", 0.262, 0.720, 5534 },
            { "FALLEN_CHAMPION", 0.418, 0.708, 5230 },
            { "IRONSPINE", 0.356, 0.693, 5231 },
        },
    },
    SM_LIBRARY = {
        [1] = {
            { "HOUNDMASTER_LOKSEY", 0.293, 0.841, 2040 },
            { "ARCANIST_DOAN", 0.833, 0.743, 5266 },
        },
    },
    SM_ARMORY = {
        [1] = {
            { "HEROD", 0.785, 0.106, 2041 },
        },
    },
    SM_CATHEDRAL = {
        [1] = {
            { "HIGH_INQUISITOR_FAIRBANKS", 0.554, 0.249, 2605 },
            { "SCARLET_COMMANDER_MOGRAINE", 0.489, 0.275, 2042 },
            { "HIGH_INQUISITOR_WHITEMANE", 0.491, 0.165, 2043 },
        },
    },
    RAZORFEN_DOWNS = {
        [1] = {
            { "TUTENKASH", 0.591, 0.338, 7845 },
            { "MORDRESH_FIRE_EYE", 0.857, 0.466, 8055 },
            { "GLUTTON", 0.345, 0.665, 7864 },
            { "RAGGLESNOUT", 0.527, 0.708, 11382 },
            { "AMNENNAR_THE_COLDBRINGER", 0.443, 0.602, 7971 },
        },
    },
    ULDAMAN = {
        [1] = {
            { "REVELOSH", 0.534, 0.712, 5945 },
            { "IRONAYA", 0.369, 0.737, 6089 },
            { "OBSIDIAN_SENTINEL", 0.288, 0.599, 5285 },
            { "ANCIENT_STONE_KEEPER", 0.474, 0.440, 10798 },
            { "GALGANN_FIREHAMMER", 0.265, 0.323, 6059 },
            { "GRIMLOK", 0.220, 0.257, 11165 },
        },
        [2] = {
            { "ARCHAEDAS", 0.552, 0.504, 5988 },
        },
    },
    ZULFARRAK = {
        [1] = {
            { "ANTUSUL", 0.643, 0.274, 7353 },
            { "THEKA_THE_MARTYR", 0.527, 0.262, 6696 },
            { "WITCH_DOCTOR_ZUMRAH", 0.441, 0.174, 6434 },
            { "NEKRUM_GUTCHEWER", 0.332, 0.218, 6690 },
            { "SHADOWPRIEST_SEZZZIZ", 0.338, 0.138, 6441 },
            { "SERGEANT_BLY", 0.290, 0.170, 6433 },
            { "HYDROMANCER_VELRATHA", 0.282, 0.370, 6685, patrol = {
                0.345, 0.417, 0.316, 0.463, 0.275, 0.414, 0.282, 0.370, 0.310, 0.358,
            } },
            { "GAHZRILLA", 0.313, 0.412, 7271 },
            { "CHIEF_UKORZ_SANDSCALP", 0.422, 0.334, 6439 },
            { "ZERILLIS", 0.517, 0.346, 9293 },
            { "SANDARR_DUNEREAVER", 0.457, 0.511, 9291 },
            { "DUSTWRAITH", 0.348, 0.450, 9292 },
        },
    },
    MARAUDON = {
        [1] = {
            { "NOXXION", 0.358, 0.099, 11172 },
            { "RAZORLASH", 0.163, 0.338, 12389 },
            { "LORD_VYLETONGUE", 0.377, 0.708, 12334 },
            { "MESHLOK_THE_HARVESTER", 0.247, 0.871, 9014 },
        },
        [2] = {
            { "CELEBRAS_THE_CURSED", 0.245, 0.136, 12350 },
            { "LANDSLIDE", 0.411, 0.488, 12293 },
            { "TINKERER_GIZLOCK", 0.489, 0.687, 7125 },
            { "ROTGRIP", 0.411, 0.814, 13589 },
            { "PRINCESS_THERADRAS", 0.258, 0.784, 12292 },
        },
    },
    SUNKEN_TEMPLE = {
        [1] = {
            { "ATALALARION", 0.502, 0.457, 7873 },
            { "DREAMSCYTHE", 0.552, 0.900, 7553 },
            { "WEAVER", 0.472, 0.836, 6375 },
            { "JAMMALAN_THE_PROPHET", 0.759, 0.454, 6708 },
            { "OGOM_THE_WRETCHED", 0.759, 0.454, 6709 },
            { "MORPHAZ", 0.523, 0.831, 7975 },
            { "HAZZAS", 0.501, 0.902, 9584 },
            { "SHADE_OF_ERANIKUS", 0.665, 0.874, 7806 },
            { "AVATAR_OF_HAKKAR", 0.241, 0.454, 8053 },
        },
    },
    BRD = {
        [1] = {
            { "LORD_ROCCOR", 0.508, 0.544, 5781 },
            { "HIGH_INTERROGATOR_GERSTAHN", 0.477, 0.924, 8761 },
            { "BAELGAR", 0.255, 0.527, 12162 },
            { "LORD_INCENDIUS", 0.565, 0.308, 1204 },
            { "FINEOUS_DARKVIRE", 0.636, 0.210, 8704 },
            { "PYROMANCER_LOREGRAIN", 0.560, 0.671, 8762 },
            -- On Detention Block, as Mike found them in game; rough spots.
            { "HOUNDMASTER_GREBMAR", 0.495, 0.866, 9212 },
            -- The arena's six fighters share one pin with crossed swords.
            { "RING_OF_LAW", 0.514, 0.636, "Interface\\Icons\\Ability_DualWield" },
        },
        [2] = {
            { "WARDER_STILGISS", 0.596, 0.661, 9089 },
            { "VEREK", 0.618, 0.631, 9019 },
            { "GENERAL_ANGERFORGE", 0.366, 0.827, 8756 },
            { "GOLEM_LORD_ARGELMACH", 0.364, 0.644, 8759 },
            { "THE_SEVEN", 0.535, 0.244, 8686 },
            { "HURLEY_BLACKBREATH", 0.516, 0.678, 8658 },
            { "RIBBLY_SCREWSPIGOT", 0.497, 0.633, 8667 },
            { "PLUGGER_SPAZZRING", 0.485, 0.684, 8652 },
            { "PHALANX", 0.531, 0.635, 8177 },
            { "AMBASSADOR_FLAMELASH", 0.539, 0.484, 8329 },
            { "MAGMUS", 0.804, 0.117, 12162 },
            { "EMPEROR_DAGRAN_THAURISSAN", 0.918, 0.117, 8807 },
            { "PRINCESS_MOIRA_BRONZEBEARD", 0.940, 0.086, 8705 },
            { "PANZOR_THE_INVINCIBLE", 0.504, 0.320, 8270 },
        },
    },
    LBRS = {
        [1] = {
            { "WAR_MASTER_VOONE", 0.523, 0.546, 9733 },
            { "BANNOK_GRIMAXE", 0.472, 0.656, 9668 },
        },
        [2] = {
            { "SHADOW_HUNTER_VOSHGAJIN", 0.554, 0.693, 9732 },
            { "MOTHER_SMOLDERWEB", 0.618, 0.740, 9929 },
            { "CRYSTAL_FANG", 0.535, 0.750, 9755 },
        },
        [3] = {
            { "HIGHLORD_OMOKK", 0.385, 0.587, 11565 },
            { "SPIRESTONE_BUTCHER", 0.455, 0.600, 11574 },
            { "SPIRESTONE_BATTLE_LORD", 0.376, 0.623, 11576 },
            { "SPIRESTONE_LORD_MAGUS", 0.389, 0.633, 11578 },
        },
        [4] = {
            { "UROK_DOOMHOWL", 0.453, 0.551, 11583 },
        },
        [5] = {
            { "QUARTERMASTER_ZIGRIS", 0.540, 0.844, 9738 },
            { "HALYCON", 0.379, 0.835, 9567 },
            { "GIZRUL_THE_SLAVENER", 0.379, 0.835, 9564 },
            { "GHOK_BASHGUUD", 0.367, 0.620, 11809 },
        },
        [6] = {
            { "OVERLORD_WYRMTHALAK", 0.575, 0.605, 8711 },
        },
    },
    -- By the skulls printed on the maps; Jed and Goraluk stand above the
    -- Hall of Binding, in the Hall of Blackhand.
    UBRS = {
        [2] = {
            { "PYROGUARD_EMBERSEER", 0.303, 0.262, 2172 },
            { "SOLAKAR_FLAMEWREATH", 0.381, 0.381, 9581 },
        },
        [3] = {
            { "JED_RUNEWATCHER", 0.350, 0.258, 9686 },
            { "GORALUK_ANVILCRACK", 0.299, 0.261, 10222 },
            { "GYTH", 0.485, 0.199, 9806 },
            { "WARCHIEF_REND_BLACKHAND", 0.486, 0.253, 9778 },
            { "THE_BEAST", 0.644, 0.313, 10193 },
            { "GENERAL_DRAKKISATH", 0.348, 0.495, 10115 },
        },
    },
    DM_EAST = {
        [1] = {
            { "PUSILLIN", 0.885, 0.380, 7552 },
            { "ZEVRIM_THORNHOOF", 0.438, 0.475, 11335 },
        },
        [2] = {
            { "HYDROSPAWN", 0.576, 0.738, 5489 },
            { "LETHTENDRIS", 0.536, 0.711, 14378 },
            { "ALZZIN_THE_WILDSHAPER", 0.564, 0.284, 14416 },
            { "ISALIEN", 0.599, 0.322, 16000 },
        },
    },
    DM_WEST = {
        [1] = {
            { "TENDRIS_WARPWOOD", 0.332, 0.531, 14383 },
            { "ILLYANNA_RAVENOAK", 0.208, 0.780, 11270, patrol = { open = true,
                0.192, 0.398, 0.208, 0.780, 0.436, 0.820,
            } },
        },
        [2] = {
            { "MAGISTER_KALENDRIS", 0.337, 0.445, 14384 },
        },
        [3] = {
            { "IMMOLTHAR", 0.348, 0.572, 14173 },
            { "PRINCE_TORTHELDRIN", 0.621, 0.231, 11256 },
            { "TSUZEE", 0.344, 0.473, 11250 },
        },
    },
    DM_NORTH = {
        [1] = {
            { "GUARD_MOLDAR", 0.694, 0.754, 11561 },
            { "STOMPER_KREEG", 0.609, 0.681, 11545 },
            { "GUARD_SLIPKIK", 0.263, 0.570, 11561 },
            { "CAPTAIN_KROMCRUSH", 0.318, 0.497, 11564 },
            { "CHORUSH_THE_OBSERVER", 0.296, 0.334, 11537 },
            { "KING_GORDOK", 0.353, 0.326, 11583 },
            { "GORDOK_TRIBUTE", 0.319, 0.264 },
            { "GUARD_FENGUS", 0.496, 0.780, 11561, patrol = { open = true,
                0.426, 0.865, 0.424, 0.688, 0.439, 0.773, 0.496, 0.780, 0.495, 0.874, 0.559, 0.901, 0.449, 0.896,
            } },
        },
    },
    -- Floors and spots as Mike placed them in game (2026-10-10 and 11).
    SCHOLOMANCE = {
        [1] = {
            -- Walks the Reliquary; drops the Blood of the Innocents that
            -- summons Kirtonos.
            { "BLOOD_STEWARD_OF_KIRTONOS", 0.817, 0.519, 10925, patrol = { open = true, 0.702, 0.384, 0.796, 0.468, 0.790, 0.698 } },
        },
        [2] = {
            { "KIRTONOS_THE_HERALD", 0.495, 0.105, 7534 },
        },
        [3] = {
            { "JANDICE_BAROV", 0.541, 0.145, 11073 },
            { "RATTLEGORE", 0.316, 0.646, 12073 },
            { "INSTRUCTOR_MALICIA", 0.730, 0.705, 11069 },
            { "DOCTOR_THEOLEN_KRASTINOV", 0.890, 0.461, 10901 },
            { "LOREKEEPER_POLKELT", 0.724, 0.221, 11492 },
            { "DEATH_KNIGHT_DARKREAVER", 0.275, 0.592, 14591 },
        },
        [4] = {
            { "THE_RAVENIAN", 0.677, 0.484, 10433 },
            { "LORD_ALEXEI_BAROV", 0.792, 0.298, 11072 },
            { "LADY_ILLUCIA_BAROV", 0.673, 0.151, 11835 },
            { "RAS_FROSTWHISPER", 0.404, 0.813, 7919 },
        },
    },
    STRAT_LIVE = {
        [1] = {
            { "THE_UNFORGIVEN", 0.735, 0.201, 10771 },
            { "TIMMY_THE_CRUEL", 0.362, 0.339, 571 },
            { "MALOR_THE_ZEALOUS", 0.297, 0.406, 10458 },
            { "CANNON_MASTER_WILLEY", 0.041, 0.507, 10674 },
            { "ARCHIVIST_GALFORD", 0.271, 0.747, 10544 },
            { "BALNAZZAR", 0.204, 0.817, 10691 },
            { "HEARTHSINGER_FORRESTEN", 0.839, 0.283, 10482 },
            { "SKUL", 0.804, 0.438, 2606 },
        },
    },
    STRAT_UNDEAD = {
        [1] = {
            { "POSTMASTER_MALOWN", 0.552, 0.694, 10669 },
        },
        [2] = {
            -- Walks the loop around The Gauntlet's middle block.
            { "STONESPINE", 0.662, 0.508, 7856, patrol = {
                0.623, 0.258, 0.665, 0.283, 0.684, 0.340, 0.712, 0.413, 0.714, 0.484, 0.635, 0.480, 0.581, 0.426, 0.586, 0.357, 0.592, 0.291, 0.557, 0.192,
            } },
            { "MAGISTRATE_BARTHILAS", 0.568, 0.157, 10433 },
            { "NERUBENKAN", 0.571, 0.460, 9793 },
            { "BARONESS_ANASTARI", 0.745, 0.461, 10698 },
            { "MALEKI_THE_PALLID", 0.676, 0.214, 10546 },
            { "BARON_RIVENDARE", 0.390, 0.202, 10729 },
            { "RAMSTEIN_THE_GORGER", 0.451, 0.195, 12818 },  -- the Slaughter Square skull
        },
    },
    MOLTEN_CORE = {
        [1] = {
            { "LUCIFRON", 0.658, 0.377, 13031 },
            { "MAGMADAR", 0.689, 0.237, 10193 },
            { "GEHENNAS", 0.332, 0.487, 13030 },
            { "GARR", 0.308, 0.698, 12110 },
            { "SHAZZRAH", 0.551, 0.846, 13032 },
            { "BARON_GEDDON", 0.674, 0.628, 12129 },
            { "GOLEMAGG_THE_INCINERATOR", 0.685, 0.584, 11986 },
            { "SULFURON_HARBINGER", 0.826, 0.828, 13030 },
            { "MAJORDOMO_EXECUTUS", 0.838, 0.657, 12029 },
            { "RAGNAROS", 0.558, 0.539, 11121 },
        },
    },
    ONYXIA = {
        [1] = {
            { "ONYXIA", 0.673, 0.307, 8570 },
        },
    },
    ZULGURUB = {
        [1] = {
            { "HIGH_PRIESTESS_JEKLIK", 0.365, 0.716, 15219 },
            { "HIGH_PRIEST_VENOXIS", 0.508, 0.542, 15217 },
            { "HIGH_PRIESTESS_MARLI", 0.451, 0.739, 15220 },
            { "BLOODLORD_MANDOKIR", 0.602, 0.798, 11288 },
            { "GRILEK", 0.597, 0.461, 8390 },
            { "HAZZARAH", 0.596, 0.459, 15267 },
            { "RENATAKI", 0.596, 0.459, 15268 },
            { "WUSHOOLAY", 0.596, 0.459, 15269 },
            { "GAHZRANKA", 0.541, 0.317, 15288 },
            { "HIGH_PRIEST_THEKAL", 0.637, 0.327, 15216 },
            { "HIGH_PRIESTESS_ARLOKK", 0.475, 0.205, 15218 },
            { "JINDO_THE_HEXXER", 0.315, 0.246, 11311 },
            { "HAKKAR", 0.498, 0.395, 15295 },
        },
    },
    BWL = {
        [1] = {
            { "FIREMAW", 0.269, 0.402, 6377 },
            { "EBONROC", 0.330, 0.275, 6377 },
            { "FLAMEGOR", 0.404, 0.354, 6377 },
            { "CHROMAGGUS", 0.416, 0.602, 14367 },
        },
        [3] = {
            { "RAZORGORE_THE_UNTAMED", 0.501, 0.617, 10115 },
            { "VAELASTRASZ_THE_CORRUPT", 0.461, 0.428, 13992 },
        },
        [4] = {
            { "BROODLORD_LASHLAYER", 0.393, 0.720, 14308 },
            { "NEFARIAN", 0.702, 0.725, 11380 },
        },
    },
    AQ20 = {
        [1] = {
            { "KURINNAXX", 0.559, 0.356, 15742 },
            { "GENERAL_RAJAXX", 0.584, 0.493, 15376 },
            { "MOAM", 0.328, 0.364, 15392 },
            { "BURU_THE_GORGER", 0.699, 0.620, 15654 },
            { "AYAMISS_THE_HUNTER", 0.616, 0.900, 15431 },
            { "OSSIRIAN_THE_UNSCARRED", 0.431, 0.692, 15432 },
        },
    },
    AQ40 = {
        [1] = {
            { "BATTLEGUARD_SARTURA", 0.444, 0.334, 15583 },
            { "FANKRISS_THE_UNYIELDING", 0.621, 0.225, 15743 },
            { "VISCIDUS", 0.721, 0.178, 15686 },
            { "PRINCESS_HUHURAN", 0.433, 0.499, 15739 },
            { "TWIN_EMPERORS", 0.605, 0.698, 15778 },
            { "OURO", 0.302, 0.815, 15509 },
            { "BUG_TRIO", 0.284, 0.495, 15656 },
        },
        [2] = {
            { "THE_PROPHET_SKERAM", 0.460, 0.520, 15345 },
        },
        [3] = {
            { "CTHUN", 0.569, 0.626, 15787 },
        },
    },
    NAXXRAMAS = {
        [1] = {
            { "PATCHWERK", 0.539, 0.418, 16174 },
            { "GROBBULUS", 0.616, 0.524, 16035 },
            { "GLUTH", 0.458, 0.440, 16064 },
            { "THADDIUS", 0.264, 0.147, 16137 },
        },
        [2] = {
            { "ANUBREKHAN", 0.305, 0.467, 15931 },
            { "GRAND_WIDOW_FAERLINA", 0.439, 0.359, 15940 },
            { "MAEXXNA", 0.685, 0.153, 15928 },
        },
        [3] = {
            { "INSTRUCTOR_RAZUVIOUS", 0.426, 0.455, 16582 },
            { "GOTHIK_THE_HARVESTER", 0.674, 0.596, 16279 },
            { "FOUR_HORSEMEN", 0.301, 0.766, 16155 },
        },
        [4] = {
            { "NOTH_THE_PLAGUEBRINGER", 0.346, 0.563, 16590 },
            { "HEIGAN_THE_UNCLEAN", 0.497, 0.455, 16309 },
            { "LOATHEB", 0.756, 0.283, 16110 },
        },
        [6] = {
            { "SAPPHIRON", 0.565, 0.672, 16033 },
            { "KELTHUZAD", 0.365, 0.225, 15945 },
        },
    },
})

-- Each map's entrances (drawn with the Dungeon or Raid swirl) and the spots
-- that lead to another level (clicking one switches the map to it): per
-- instance, entrance = { { level, x, y, "raid" for a raid's entrance inside
-- a dungeon }, ... }, lock = { { level, x, y }, ... } (doors that need a key
-- or lockpicking), links = { [level] = { { level it leads to, x, y, icon
-- }, ... } } and marker = { { level, x, y, icon, quest ID }, ... } (where a
-- quest's item, kill, vendor or escort is; icons in Data/Data.lua's
-- markerIcons), x and y from 0 to 1 across the drawn map. Entrances sit on the
-- entrance swirl printed on the map art (found by matching it in Blizzard's
-- tiles and on Santiago Reyes's maps); maps with no printed swirl
-- (Naxxramas) have none. Forever has no map link data for these old
-- dungeons, so links were placed by eye on the art, and most have since
-- been placed by Mike in game (/nr devedit). A link's icon is "up" or
-- "down" (stairs, ramps, drops), "door" or "door-up/-down/-left/-right" (a
-- way through to a part drawn on another level), or by default down to a
-- later level and up to an earlier one. Shift-click a map to print a spot.
local STRAT_LINKS = {
    [1] = { { 2, 0.903, 0.325, "door-right" } },  -- Festival Lane's gate
    [2] = { { 1, 0.585, 0.765, "door-left" } },  -- into Elders' Square
}
ns.Data:RegisterMapSpots({
    HALL_OF_THANES = { entrance = { { 1, 0.509, 0.946 } }, lock = { { 1, 0.516, 0.596 } },
        marker = { { 1, 0.428, 0.644, "quest", 96395 }, { 1, 0.512, 0.180, "quest", 96393, boss = "DURGEN_DIRGEHAMMER" }, { 1, 0.489, 0.121, "quest", 98423 }, { 1, 0.567, 0.603, "attack", 96394, area = { 0.577, 0.594, 0.610, 0.673, 0.591, 0.760, 0.440, 0.772, 0.411, 0.681, 0.427, 0.595 } } } },
    RUINS_OF_LORDAERON = { entrance = { { 1, 0.613, 0.215 } },
        marker = { { 1, 0.494, 0.588, "quest", 92422, boss = "RATHMAEL" }, { 1, 0.537, 0.585, "quest", 92401 }, { 1, 0.706, 0.355, "quest", 95216, boss = "WITHERFANG" }, { 1, 0.376, 0.494, "quest", 95189 }, { 1, 0.560, 0.595, "quest", 95189 }, { 1, 0.376, 0.494, "quest", 95204 }, { 1, 0.560, 0.596, "quest", 95204 }, { 1, 0.435, 0.277, "quest", 95204 }, { 1, 0.436, 0.276, "quest", 95189 }, { 1, 0.343, 0.214, "quest", 95189 }, { 1, 0.342, 0.214, "quest", 95204 }, { 1, 0.673, 0.493, "quest", 95204 }, { 1, 0.672, 0.494, "quest", 95189 }, { 1, 0.602, 0.703, "quest", 95250, boss = "THE_BARON" }, { 1, 0.536, 0.586, "quest", 92415 } } },
    EXCAVATION_SITE_WETLANDS = { entrance = { { 1, 0.078, 0.614 } },
        marker = { { 1, 0.647, 0.252, "quest", 98823, boss = "RELIC_GUARDIAN" }, { 1, 0.875, 0.637, "quest", 95646 }, { 1, 0.902, 0.544, "quest", 95772 }, { 1, 0.922, 0.544, "quest", 95682 }, { 1, 0.689, 0.203, "quest", 95809 }, { 1, 0.647, 0.252, "quest", 98824, boss = "RELIC_GUARDIAN" } } },
    BLACKMAW_HOLD = { entrance = { { 1, 0.181, 0.739 } } },
    -- The entrance is printed on the Sewers map.
    CITY_OF_DALARAN = { entrance = { { 2, 0.184, 0.844 } },
        marker = { { 2, 0.546, 0.511, "quest", 96986, boss = "ATREXIS_THE_GRAVE_KNIGHT" }, { 1, 0.430, 0.392, "quest", 96987 }, { 1, 0.525, 0.207, "quest", 92458, boss = "SHADE_OF_THE_ARCHMAGE" }, { 1, 0.525, 0.207, "quest", 96984, boss = "SHADE_OF_THE_ARCHMAGE" }, { 1, 0.673, 0.507, "quest", 92489, boss = "ARCANIC_ENIGMA" }, { 1, 0.516, 0.552, "quest", 92456, boss = "FEL_ANCIENT" } },
        links = {
        [1] = { { 2, 0.507, 0.684, "door-down" }, { 2, 0.536, 0.359, "door-down" } },
        [2] = { { 1, 0.761, 0.578, "door-up" }, { 1, 0.250, 0.479, "door-up" } },
    } },
    RAGEFIRE = { entrance = { { 1, 0.610, 0.072 } },
        -- The quests on the bosses they're about (boss = its pin).
        marker = { { 1, 0.333, 0.419, "buy", 5725, area = { 0.471, 0.438, 0.551, 0.537, 0.474, 0.709, 0.268, 0.694, 0.308, 0.466, 0.388, 0.407 } }, { 1, 0.566, 0.384, "quest", 5722, boss = "OGGLEFLINT" }, { 1, 0.408, 0.853, "quest", 5728, boss = "BAZZALAN" }, { 1, 0.410, 0.577, "quest", 5761, boss = "TARAGAMAN_THE_HUNGERER" }, { 1, 0.342, 0.814, "quest", 5728, boss = "JERGOSH_THE_INVOKER" }, { 1, 0.333, 0.419, "quest", 5725, on = true } } },
    WAILING_CAVERNS = { entrance = { { 1, 0.460, 0.591 } },
        marker = { { 1, 0.343, 0.136, "quest", 6981, boss = "MUTANUS_THE_DEVOURER" }, { 1, 0.159, 0.566, "quest", 914, boss = "LORD_COBRAHN" }, { 1, 0.615, 0.534, "quest", 914, boss = "LORD_SERPENTIS" }, { 1, 0.306, 0.430, "quest", 914, boss = "LADY_ANACONDRA" }, { 1, 0.191, 0.397, "quest", 914, boss = "LORD_PYTHAS" }, { 1, 0.468, 0.527, "escort", nil }, { 1, 0.468, 0.527, "quest", 6981, on = true } } },
    DEADMINES = { entrance = { { 1, 0.297, 0.132 } },
        marker = { { 1, 0.506, 0.864, "quest", 2040, boss = "SNEEDS_SHREDDER" }, { 2, 0.608, 0.467, "quest", 373, boss = "VANCLEEF" }, { 2, 0.608, 0.467, "quest", 166, boss = "VANCLEEF" }, { 1, 0.443, 0.855, "quest", 95036 }, { 2, 0.125, 0.817, "quest", 92753 } },
        links = {
        [1] = { { 2, 0.653, 0.692, "door-down" } },  -- the Goblin Foundry floor
        [2] = { { 1, 0.127, 0.906, "door-up" } },
    } },
    SHADOWFANG = { entrance = { { 1, 0.703, 0.606 } },
        -- The Courtyard, where Shadowfang Darksouls drop the Large Soran'ruk
        -- Fragment (placed from the boss pins around it; Mike to adjust).
        marker = { { 1, 0.666, 0.470, "loot", 1740, area = { 0.600, 0.400, 0.730, 0.400, 0.740, 0.540, 0.600, 0.540 } },
            { 4, 0.470, 0.477, "quest", 1013 }, { 1, 0.663, 0.646, "quest", 1098 }, { 1, 0.572, 0.579, "quest", 1098 }, { 6, 0.682, 0.332, "quest", 1014, boss = "ARCHMAGE_ARUGAL" }, { 1, 0.337, 0.577, "quest", 95036 } },
        links = {
        [1] = { { 2, 0.137, 0.905, "door-down" }, { 7, 0.360, 0.664, "door-right" }, { 2, 0.384, 0.405, "door-left" } },
        [2] = { { 1, 0.272, 0.888, "door-up" }, { 1, 0.625, 0.117, "door-right" } },
        [3] = { { 7, 0.484, 0.714, "door-left" }, { 4, 0.536, 0.799, "door-right" } },
        [4] = { { 3, 0.433, 0.785, "door-down" }, { 5, 0.519, 0.903, "door-up" } },
        [5] = { { 4, 0.429, 0.780, "door-down" }, { 6, 0.488, 0.811, "door-up" } },
        [6] = { { 5, 0.412, 0.820, "door-left" } },
        [7] = { { 6, 0.230, 0.754, "door-left" }, { 3, 0.408, 0.291, "door-up" } },
    } },
    BLACKFATHOM = { entrance = { { 1, 0.453, 0.109 } },
        -- Moonshrine Sanctum, where Twilight Acolytes drop the Soran'ruk
        -- Fragments (placed around Twilight Lord Kelris's pin; Mike to adjust).
        marker = { { 2, 0.565, 0.770, "loot", 1740, area = { 0.490, 0.755, 0.580, 0.755, 0.590, 0.870, 0.485, 0.870 } },
            { 1, 0.212, 0.741, "quest", 1198 }, { 1, 0.335, 0.401, "quest", 971 }, { 2, 0.527, 0.817, "quest", 1200, boss = "TWILIGHT_LORD_KELRIS" }, { 2, 0.527, 0.817, "quest", 6561, boss = "TWILIGHT_LORD_KELRIS" }, { 1, 0.614, 0.636, "quest", 6565, boss = "LORGUS_JETT" }, { 2, 0.447, 0.685, "quest", 6921 }, { 2, 0.450, 0.771, "quest", 6922, boss = "BARON_AQUANIS" }, { 1, 0.213, 0.739, "quest", 6561 } },
        links = {
        [1] = { { 2, 0.618, 0.746, "door-down" } },
        [2] = { { 1, 0.338, 0.226, "door-up" }, { 3, 0.483, 0.715, "door-right" } },
        [3] = { { 2, 0.388, 0.606, "door-left" } },
    } },
    STOCKADE = { entrance = { { 1, 0.501, 0.813 } },
        marker = { { 1, 0.860, 0.515, "quest", 391, boss = "BAZIL_THREDD" }, { 1, 0.500, 0.211, "quest", 386, boss = "TARGORR_THE_DREAD" }, { 1, 0.625, 0.292, "quest", 378, boss = "KAM_DEEPFURY" }, { 1, 0.217, 0.262, "quest", 377, boss = "DEXTREN_WARD" } } },
    -- The front door, and the train depot's back door.
    GNOMEREGAN = { entrance = { { 1, 0.642, 0.275 }, { 3, 0.867, 0.479 } },
        marker = { { 2, 0.636, 0.622, "quest", 2951 }, { 4, 0.312, 0.293, "quest", 2951, boss = "MEKGINEER_THERMAPLUGG" } },
        links = {
        [1] = { { 2, 0.476, 0.849, "door-down" }, { 2, 0.337, 0.634, "door-down" }, { 2, 0.519, 0.847, "door-down" } },
        [2] = { { 3, 0.308, 0.666, "door-down" }, { 1, 0.730, 0.823, "door-up" }, { 1, 0.596, 0.626, "door-up" }, { 1, 0.857, 0.397, "door-up" }, { 3, 0.434, 0.841, "door-down" } },
        [3] = { { 2, 0.453, 0.425, "door-up" }, { 4, 0.491, 0.711, "door-down" }, { 4, 0.252, 0.409, "door-down" }, { 2, 0.293, 0.220, "door-up" } },
        [4] = { { 3, 0.468, 0.536, "door-up" } },
    } },
    RAZORFEN_KRAUL = { entrance = { { 1, 0.714, 0.837 } },
        marker = { { 1, 0.286, 0.331, "quest", 1221 }, { 1, 0.368, 0.320, "escort", 1144 }, { 1, 0.386, 0.284, "quest", 1144 }, { 1, 0.218, 0.307, "quest", 1101, boss = "CHARLGA_RAZORFLANK" }, { 1, 0.218, 0.307, "quest", 1102, boss = "CHARLGA_RAZORFLANK" }, { 1, 0.110, 0.469, "buy", 1109, area = { 0.122, 0.509, 0.186, 0.526, 0.196, 0.595, 0.131, 0.579, 0.070, 0.580, 0.060, 0.469, 0.069, 0.391, 0.104, 0.366, 0.097, 0.311, 0.116, 0.286, 0.151, 0.357, 0.133, 0.444, 0.108, 0.450 } } } },
    SM_GRAVEYARD = { entrance = { { 1, 0.841, 0.828 } } },
    SM_LIBRARY = { entrance = { { 1, 0.129, 0.247 } },
        marker = { { 1, 0.833, 0.743, "quest", 96800, boss = "ARCANIST_DOAN" }, { 1, 0.843, 0.300, "quest", 1050 }, { 1, 0.842, 0.301, "quest", 1049 }, { 1, 0.454, 0.299, "quest", 1160 }, { 1, 0.293, 0.841, "quest", 1053, boss = "HOUNDMASTER_LOKSEY" }, { 1, 0.293, 0.841, "quest", 1048, boss = "HOUNDMASTER_LOKSEY" }, { 1, 0.839, 0.193, "quest", 1951 } } },
    SM_ARMORY = { entrance = { { 1, 0.609, 0.954 } },
        marker = { { 1, 0.785, 0.106, "quest", 1048, boss = "HEROD" }, { 1, 0.785, 0.106, "quest", 1053, boss = "HEROD" } } },
    SM_CATHEDRAL = { entrance = { { 1, 0.621, 0.921 } },
        marker = { { 1, 0.489, 0.275, "quest", 1048, boss = "SCARLET_COMMANDER_MOGRAINE" }, { 1, 0.491, 0.165, "quest", 1048, boss = "HIGH_INQUISITOR_WHITEMANE" }, { 1, 0.489, 0.275, "quest", 1053, boss = "SCARLET_COMMANDER_MOGRAINE" }, { 1, 0.491, 0.165, "quest", 1053, boss = "HIGH_INQUISITOR_WHITEMANE" } } },
    RAZORFEN_DOWNS = { entrance = { { 1, 0.235, 0.189 } } },
    ULDAMAN = { entrance = { { 1, 0.678, 0.725 }, { 1, 0.287, 0.692 } }, links = {
        [1] = { { 2, 0.470, 0.219, "door-up" } },  -- past the Hall of the Crafters
        [2] = { { 1, 0.645, 0.402, "door-down" } },
    } },
    ZULFARRAK = { entrance = { { 1, 0.564, 0.901 } } },
    -- The orange and purple entrances.
    MARAUDON = { entrance = { { 1, 0.621, 0.280 }, { 1, 0.765, 0.657 } }, links = {
        [1] = { { 2, 0.240, 0.880, "down" }, { 2, 0.151, 0.580, "door-left" } },
        [2] = { { 1, 0.299, 0.045, "door-right" } },
    } },
    SUNKEN_TEMPLE = { entrance = { { 1, 0.497, 0.105 } } },
    BRD = { entrance = { { 1, 0.330, 0.792 }, { 2, 0.673, 0.357, "raid" } }, lock = { { 1, 0.365, 0.733 }, { 1, 0.383, 0.658 } }, links = {
        [1] = { { 2, 0.407, 0.659, "door-up" }, { 2, 0.652, 0.303, "door-up" } },
        [2] = { { 1, 0.644, 0.582, "door-down" }, { 1, 0.422, 0.946, "door-down" } },
    } },
    -- Printed on the Hall of Blackhand level.
    LBRS = { entrance = { { 4, 0.367, 0.421 } } },
    UBRS = { entrance = { { 1, 0.374, 0.323 }, { 3, 0.547, 0.213, "raid" } }, links = {
        [1] = { { 2, 0.304, 0.139, "door-up" } },
        [2] = { { 1, 0.305, 0.146, "door-down" }, { 3, 0.293, 0.413, "door-left" } },
        [3] = { { 2, 0.298, 0.409, "door-right" } },
    } },
    DM_NORTH = { entrance = { { 1, 0.717, 0.925 } } },
    DM_WEST = { entrance = { { 1, 0.934, 0.509 }, { 1, 0.933, 0.720 } }, links = {
        [1] = { { 2, 0.221, 0.188, "door-right" }, { 2, 0.397, 0.337, "door-up" }, { 3, 0.299, 0.431, "door-left" } },
        [2] = { { 1, 0.493, 0.121, "door-left" }, { 1, 0.566, 0.261, "door-down" } },
        [3] = { { 1, 0.764, 0.398, "door-right" } },
    } },
    DM_EAST = { entrance = { { 1, 0.952, 0.507 }, { 1, 0.162, 0.852 }, { 2, 0.279, 0.554 } }, links = {
        [1] = { { 2, 0.227, 0.497, "door-down" }, { 2, 0.512, 0.628, "door-right" } },
        [2] = { { 1, 0.400, 0.707, "door-up" }, { 1, 0.620, 0.825, "door-up" } },
    } },
    SCHOLOMANCE = { entrance = { { 1, 0.389, 0.652 } },
        -- The Great Ossuary, where Plagued Hatchlings drop the Healthy Dragon Scale.
        marker = { { 2, 0.325, 0.697, "loot", 5582, area = { 0.252, 0.623, 0.395, 0.602, 0.396, 0.804, 0.255, 0.817 } } },
        links = {
        [1] = { { 2, 0.667, 0.328, "door-up" } },
        [2] = { { 3, 0.294, 0.857, "door-down" }, { 3, 0.291, 0.325, "door-right" }, { 1, 0.623, 0.296, "door-down" }, { 3, 0.645, 0.537, "door-right" }, { 4, 0.479, 0.846, "door-down" } },
        [3] = { { 2, 0.352, 0.809, "door-up" }, { 2, 0.285, 0.197, "door-left" }, { 2, 0.583, 0.628, "door-left" }, { 4, 0.710, 0.461, "door-right" } },
        [4] = { { 3, 0.624, 0.300, "door-left" }, { 2, 0.484, 0.558, "door-up" } },
    } },
    -- The two front gates on the living side, the back door on the undead side.
    STRAT_LIVE = { entrance = { { 1, 0.687, 0.879 }, { 1, 0.638, 0.879 } }, links = STRAT_LINKS },
    STRAT_UNDEAD = { entrance = { { 2, 0.657, 0.906 } }, links = STRAT_LINKS },
    MOLTEN_CORE = { entrance = { { 1, 0.260, 0.226 } } },
    ONYXIA = { entrance = { { 1, 0.338, 0.205 } } },
    ZULGURUB = { entrance = { { 1, 0.291, 0.487 } } },
    BWL = { entrance = { { 1, 0.525, 0.835 } } },
    AQ20 = { entrance = { { 1, 0.610, 0.112 } } },
    AQ40 = { entrance = { { 2, 0.523, 0.268 } }, links = {
        [1] = { { 3, 0.364, 0.644, "door-down" }, { 2, 0.357, 0.457, "door-up" } },
        [2] = { { 1, 0.492, 0.638, "door-down" } },
        [3] = { { 1, 0.595, 0.397, "door-up" } },
    } },
    NAXXRAMAS = { links = {
        -- The overview: a door into each quarter, the way up to the lair.
        [5] = { { 1, 0.420, 0.270, "door" }, { 2, 0.624, 0.236, "door" },
                { 3, 0.364, 0.664, "door" }, { 4, 0.659, 0.669, "door" },
                { 6, 0.530, 0.430, "up" } },
        [1] = { { 5, 0.630, 0.720, "door" } },
        [2] = { { 5, 0.340, 0.710, "door" } },
        [3] = { { 5, 0.640, 0.240, "door" } },
        [4] = { { 5, 0.340, 0.240, "door" } },
        [6] = { { 5, 0.750, 0.730, "down" } },
    } },
})

-- Each instance's map ID, the eighth thing GetInstanceInfo() returns inside
-- it, so the map can find the instance the player is in whatever language
-- the game is in. Wings that share a map (Scarlet Monastery, Dire Maul,
-- Blackrock Spire, Stratholme) share the ID; the map art tells them apart.
-- The instances new in WoW: Forever have none yet, so they go by their
-- English name, which only works on English clients.
ns.Data:RegisterInstanceMapIDs({
    RAGEFIRE = 389, WAILING_CAVERNS = 43, DEADMINES = 36, SHADOWFANG = 33,
    BLACKFATHOM = 48, STOCKADE = 34, GNOMEREGAN = 90, RAZORFEN_KRAUL = 47,
    SM_GRAVEYARD = 189, SM_LIBRARY = 189, SM_ARMORY = 189, SM_CATHEDRAL = 189,
    RAZORFEN_DOWNS = 129, ULDAMAN = 70, ZULFARRAK = 209, MARAUDON = 349,
    SUNKEN_TEMPLE = 109, BRD = 230, LBRS = 229, UBRS = 229,
    DM_EAST = 429, DM_WEST = 429, DM_NORTH = 429, SCHOLOMANCE = 289,
    STRAT_LIVE = 329, STRAT_UNDEAD = 329,
    MOLTEN_CORE = 409, ONYXIA = 249, ZULGURUB = 309, BWL = 469,
    AQ20 = 509, AQ40 = 531, NAXXRAMAS = 533,
})

-- Zone-wide quests: kill or drop quests that count anywhere in the
-- dungeon, shown on the map's corner badge. Icon names: the map markers'
-- (Data.lua's markerIcons), or loot (a drop). A
-- hand-kept list, added to in dev edit (/nr devexport).
ns.Data:RegisterZoneQuests({
    BLACKFATHOM = { { 1654, "loot" }, { 1199, "loot" }, { 1275, "loot" } },
    DEADMINES = { { 214, "loot" } },
    HALL_OF_THANES = { { 96403, "loot" } },
    RAZORFEN_KRAUL = { { 1142, "loot" } },  -- Mortality Wanes: any humanoid drops Treshala's Pendant
    RUINS_OF_LORDAERON = { { 92421, "loot" }, { 95195, "loot" } },
    STOCKADE = { { 387, "attack" }, { 388, "loot" } },
    -- Magics of the Drowned City. Its map is in dev builds only (Data/DevDungeons.lua);
    -- without one the badge isn't drawn.
    THE_DROWNED_CITY = { { 95788, "loot" } },
    WAILING_CAVERNS = {
        { 1487, "attack" },  -- Deviate Eradication
        { 1486, "loot" },    -- Deviate Hides
        { 1491, "loot" },    -- Smart Drinks
    },
})
