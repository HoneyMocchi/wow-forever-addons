-- NeedRoll: addon bootstrap. Owns the event frame, SavedVariables,
-- slash commands and the addon compartment (minimap menu) entry, and the
-- small helpers every file shares (ns:Print, ns.Plain, ns.ParseGUID, ns.PlayerLevel,
-- ns.HeardNumber, ns.Base36, ns.CutToBytes, ns.CleanName, ns.NpcIDOf, ns.CountKeys, ns.CharacterKey,
-- ns.PlayerServerID, ns.PlayerFaction), and ns.SectionMemory, where open and shut sections are
-- remembered.
local addonName, ns = ...
local L = ns.L

ns.name = addonName
ns.version = C_AddOns.GetAddOnMetadata(addonName, "Version")

-- Item drop chances stay in the data but are hidden until WoW: Forever has
-- enough kills behind them (Mike, 2026-10-13). True brings them back in the
-- loot grid, its tooltips, recipe sources and the Wishlist.
ns.SHOW_DROP_RATES = false

-- NeedRoll's Discord invite (no expiry), offered in Settings and the
-- first-login translation notice (UI/Welcome.lua).
ns.DISCORD_URL = "https://discord.gg/UhkFth8vsr"

local defaults = {
    -- width / height: set once the window is resized by hand (nil: default size).
    -- locked: true while the padlock by the X stops the window being dragged (UI/MainFrame.lua).
    window = { scale = 1, point = nil, width = nil, height = nil, locked = false },
    lastTab = "DUNGEON",
    -- Window style: "native" (the game's own frames), or one of NeedRoll's
    -- flat looks chosen on the Settings page: "modern", "dark" or "elvui"
    -- (shown as dark while ElvUI isn't loaded, keeping this). Saved for every
    -- player, so anyone who started on Modern keeps it.
    skin = "native",
    textSize = "normal", -- "normal" or "large" (the window drawn 4/3 as big, see UI:WindowScale)
    -- welcomed: true once the first-run pointer at the Settings button has
    -- been shown (no default, so nil means "not yet").
    -- An older Overview page's open quests and faction sections; nothing reads them.
    overview = { quests = {}, sections = {} },
    -- Shopping lists, shared by every character on the account (see Core/Shopping.lua).
    -- Older saves hold one list's entries here; Core/Shopping.lua moves them into `lists`.
    shopping = { lists = {} },
    -- Shopping List: take what is already in the bags off the "To buy" counts.
    shoppingBags = false,
    -- ...and what this character's alts hold (bags and bank).
    shoppingAlts = false,
    -- Wishlists, shared by every character on the account (see Core/Wishlist.lua).
    wishlist = { lists = {}, current = L["Starred items"], view = "overview" },
    -- Saved talent plans, shared by every character on the account: class ID -> its plans
    -- (see Core/Talents.lua).
    talentPlans = {},
    -- Minimap button, read and written by LibDBIcon-1.0 (UI/MinimapButton.lua):
    -- its spot on the minimap's edge (degrees, counterclockwise from the right)
    -- and whether /nr minimap or Settings has hidden it.
    minimap = { minimapPos = 225, hide = false },
    -- The game's world map inside a dungeon or raid: "needroll" lays
    -- NeedRoll's map of the player's floor over it (UI/WorldMapOverlay.lua),
    -- "game" leaves it alone.
    dungeonMap = "needroll",
    -- What the quest giver and book markers on the game's world map show,
    -- picked with the map's NeedRoll button (UI/WorldMapMarkers.lua):
    -- "incomplete" what is still to do, "all" the done ones too (faded), "off".
    mapMarkers = "incomplete",
    -- Tabs turned off in Settings: module key -> false (see Modules below).
    modules = {},
    -- Loot recorder: recipes and Uncommon or better drops (see Core/LootLog.lua).
    lootLog = {},
    -- Unlisted items found by /nr loot scan.
    lootScan = {},
    -- Library Books (Core/LibraryBooks.lua): by side, the hand-in quest of
    -- each book the data has none for, learned when a character of that
    -- side handed one in (book item ID -> quest ID). The game says per
    -- character whether that quest is done, so one character's hand-in
    -- tells every other's.
    libraryBookQuests = { Alliance = {}, Horde = {} },
    --[==[@debug@
    -- Every trainer a dev build opened, checked against NeedRoll's data (see Core/TrainerCheck.lua).
    trainerChecks = {},
    -- Recipes the data says a vendor sells that a dev build didn't see in its window (see Core/Vendors.lua).
    vendorMissing = {},
    -- Each character's dungeon and raid runs: bosses, drops and everyone's rolls (see Core/Runs.lua).
    runs = {},
    -- The run tracker on the game's screen (see UI/RunTracker.lua): its line under the minimap and
    -- its kill cards, each switched in Settings, and whether its first-run card has shown. Where
    -- the line was dragged is runLinePoint, unset (under the minimap) until it is. Whether the dock
    -- on the Objectives pane is folded to its header (its minus/plus button) is runDockCollapsed,
    -- whether the player popped it out to the line (its pop-out button) runDockOff, and whether
    -- they put it at the pane's left (its move button) runDockSide ("left"; unset: above it).
    runProgressLine = true,
    runKillCards = true,
    runIntroShown = false,
    --@end-debug@]==]
    -- /nr loot fish: the ID range it sweeps, the next ID to look at, whether
    -- it is running (it carries on after logging in), what it found and
    -- which of those were moved to the fished window's Hidden tab.
    fish = { from = 241000, to = 500000, next = 241000, running = false, found = {}, hidden = {} },
    -- Boss drops seen in dungeons and raids and quests NeedRoll doesn't
    -- know, the player's own and other players' (see Core/Drops.lua), and
    -- the messages still to send.
    drops = {},
    dropOutbox = {},
    newQuests = {},
    questLoot = {},
    -- What class trainers teach at another level or price than NeedRoll's
    -- data says, or that it doesn't list, read in game or heard from other
    -- copies (see Core/Trainers.lua).
    trainerSpells = {},
    -- What profession trainers, hunter pet trainers and the rogue's poison
    -- trainers teach that NeedRoll's data says otherwise or doesn't list,
    -- read in game or heard from other copies (see Core/TrainerShare.lua).
    trainerServices = {},
    -- Recipe items vendors sell that NeedRoll's data doesn't know they do, read
    -- in game or heard from other copies (see Core/Vendors.lua).
    vendorRecipes = {},
    -- And the other items only a few vendors sell, laid out the same.
    vendorItems = {},
    -- dropChannel: the player's answer to drop sharing in this round of
    -- asking (see shownDroptalkConsent): true once they said yes (Share
    -- drops on the notice or in Settings), false once they said no (Don't
    -- share, or Settings' Off); nil, not answered yet, shares nothing (see
    -- Core/Drops.lua ChannelOn). A new round sets a true back to nil.
    -- dropCredit: false once the player chose not to be credited for the
    -- drops they share (nil means credited; see Core/Drops.lua Credit).
    -- shownDroptalkConsent: true once drop sharing was answered, on the
    -- first-login notice or with Settings' Share drops; false again when a
    -- new round of asking starts (see UI/Welcome.lua).
    -- dropNoticeRound: the round of asking that notice last started on this
    -- account (nil before round 2; see UI/Welcome.lua).
    -- shownTranslationNotice: true once the first-login notice asking for
    -- help with translations was closed (non-English clients only; see
    -- UI/Welcome.lua).
    -- tooltipSources: false once Settings turns off the dungeon and raid
    -- sources on item tooltips and the dungeon quest chain lines on quest
    -- tooltips (nil means on; see Core/Tooltip.lua, UI/QuestChainNotes.lua).
    -- collectionTicks: false once Settings hides the transmog ticks after
    -- item names (nil means shown; see UI/LootGrid.lua).
    -- libraryByZone: true once the Library tab's "Group by zone" box
    -- is ticked (nil means grouped by level; see UI/LibraryBooks.lua).
    -- newestVersion: the newest feature release heard from other players
    -- (see Version check below; nil until one is heard).
    -- sectionMemory: where open and shut sections are remembered, picked
    -- in Settings (nil means "character"); sections: what was remembered
    -- (see Remembered sections below).
    -- movedToGUIDKey: player GUID -> true once that character's data saved
    -- under its old "Name-Realm" keys was taken over (see Character keys).
    -- realmOfServer: server ID -> the realm name the game gave a character
    -- there (GetRealmName(), empty since WoW: Forever's build 71037; see
    -- Character keys).
}

-- Fills in what the saved settings lack, at any depth; the player's own stay.
local function ApplyDefaults(saved, defaultValues)
    for key, default in pairs(defaultValues) do
        if type(default) == "table" then
            saved[key] = type(saved[key]) == "table" and saved[key] or {}
            ApplyDefaults(saved[key], default)
        elseif saved[key] == nil then
            saved[key] = default
        end
    end
end

-- Saves from before the minimap button was a LibDBIcon button keep its spot:
-- their `angle` is what LibDBIcon calls `minimapPos` (the same degrees).
local function MoveMinimapAngle(saved)
    local minimap = saved.minimap
    if type(minimap) ~= "table" or minimap.angle == nil then return end
    if minimap.minimapPos == nil then minimap.minimapPos = minimap.angle end
    minimap.angle = nil
end

-- Event dispatch: each file adds handlers with ns:On("EVENT", handler).
local frame = CreateFrame("Frame")
local handlers = {}

function ns:On(event, handler)
    if not handlers[event] then
        handlers[event] = {}
        frame:RegisterEvent(event)
    end
    table.insert(handlers[event], handler)
end

frame:SetScript("OnEvent", function(_, event, ...)
    for _, handler in ipairs(handlers[event]) do handler(...) end
end)

ns:On("ADDON_LOADED", function(loadedAddon)
    if loadedAddon ~= addonName then return end
    NeedRollDB = NeedRollDB or {}
    MoveMinimapAngle(NeedRollDB)
    ApplyDefaults(NeedRollDB, defaults)
    -- The removed spell recorder's saved data (enemy spells can't be read
    -- in game; tools/combatlog collects them from combat logs instead).
    NeedRollDB.spellLog, NeedRollDB.spellOutbox = nil, nil
    ns.db = NeedRollDB
    ns.Modules:Check()
end)

-- Remembered sections -------------------------------------------------------
-- Whether each collapsible section, fold and "N more trainers" list is
-- open or shut. Settings' "Remember sections" (NeedRollDB.sectionMemory)
-- picks where they are kept:
--   "character" (the default, also when unset): this character's own,
--       NeedRollDB.sections.characters[ns.CharacterKey()];
--   "account": one set every character shares, NeedRollDB.sections.account;
--   "off": a set that lasts until the game reloads, saving nothing.
-- A set holds one table per area, each mapping a stable key (an ID or a
-- fixed word, never translated text, which changes with the client's
-- language) to that section's state:
--   "loot": the loot pane's sections (Quest Items, Weapons ...), by key;
--       a Factions page's per profession, by "PROFESSION_" and the recipe subclass;
--   "bosses": the loot pane's boss folds (the Ring of Law), by NPC ID;
--   "lootClasses": the loot pane's PvP class folds, by "CLASS:<token>"
--       ("CLASS:ALL" for All classes);
--   "trainers": "N more trainers" lists opened whole, by recipe spell ID
--       (a recipe's page) or "CLASS" (the Classes tab's Overview);
--   "list": per dungeon, raid or profession ID, its middle column groups
--       (Encounters, Quests, wings, colour sets, questlines);
--   "instances": the raid list's Classic Raids group ("CLASSIC_RAIDS");
--   "classes": the Classes tab's sections and quest folds;
--   "attunement": a raid's Attunement heading, by raid ID, and an item
--       chain's heading (a dungeon's key), by "<instance ID>:<item ID>";
--   "spells", "hunterPets", "warlockPets": a spell's or pet ability's
--       ranks, by its first rank's spell ID;
--   "professions": per profession ID (and "CAMPING", the Camping list),
--       its Overview's sections and its rank, zone and specialization rows;
--   "library": the Library page's level bracket and zone folds.
-- The game writes SavedVariables only on /reload, logout or exit.
-- Switching the setting takes the new set's states as they are, empty the
-- first time (each section then starts as it always does); the other sets
-- are kept, so switching back finds them again.
local SectionMemory = { MODES = { "character", "account", "off" } }
ns.SectionMemory = SectionMemory

local sessionSections = {} -- the "off" set
local modeChangeHandlers = {}

-- parent[key], made an empty table first when it isn't one (nothing saved
-- yet, or saved data edited by hand).
local function TableIn(parent, key)
    if type(parent[key]) ~= "table" then parent[key] = {} end
    return parent[key]
end

-- "character", "account" or "off"; anything else saved reads as the default.
function SectionMemory.Mode()
    local mode = ns.db and ns.db.sectionMemory
    if mode == "account" or mode == "off" then return mode end
    return "character"
end

function SectionMemory.IsRemembering()
    return SectionMemory.Mode() ~= "off"
end

-- The set the setting picks. Before SavedVariables load (nothing is drawn
-- then) the session's.
local function CurrentSectionSet()
    local mode = SectionMemory.Mode()
    if mode == "off" or not ns.db then return sessionSections end
    local saved = TableIn(ns.db, "sections")
    if mode == "account" then return TableIn(saved, "account") end
    return TableIn(TableIn(saved, "characters"), ns.CharacterKey())
end

-- Area `area`'s table of states in the set in use; with `part`, that
-- part's own table inside it (one dungeon's groups in "list"). Whoever
-- keeps the table takes it again in an OnModeChange handler.
function SectionMemory.Area(area, part)
    local states = TableIn(CurrentSectionSet(), area)
    if part == nil then return states end
    return TableIn(states, part)
end

-- Whether section `key` of `states` (an area's table) is open: as the
-- player left it, else `isOpenAtFirst` (nil: shut) when they never opened
-- or shut it.
function SectionMemory.IsOpen(states, key, isOpenAtFirst)
    local state = states[key]
    if type(state) == "boolean" then return state end
    return isOpenAtFirst == true
end

-- Opens section `key` of `states` when shut and shuts it when open. Kept as
-- true or false, so a section that starts open stays shut once shut.
function SectionMemory.Toggle(states, key, isOpenAtFirst)
    states[key] = not SectionMemory.IsOpen(states, key, isOpenAtFirst)
end

-- Runs `handler` after the setting changes, so a pane keeping an area's
-- table takes the new set's.
function SectionMemory.OnModeChange(handler)
    table.insert(modeChangeHandlers, handler)
end

function SectionMemory.SetMode(mode)
    if not tContains(SectionMemory.MODES, mode) or mode == SectionMemory.Mode() then return end
    ns.db.sectionMemory = mode
    for _, handler in ipairs(modeChangeHandlers) do handler() end
end

-- Drops the empty tables under `states`: every dungeon the list showed gets
-- one, though only those with a group opened or shut need saving.
local function DropEmptyTables(states)
    for key, value in pairs(states) do
        if type(value) == "table" then
            DropEmptyTables(value)
            if next(value) == nil then states[key] = nil end
        end
    end
end

ns:On("PLAYER_LOGOUT", function()
    if ns.db and type(ns.db.sections) == "table" then DropEmptyTables(ns.db.sections) end
end)

-- Modules -----------------------------------------------------------------
-- Each tab is a module the player can turn off in Settings. A module that
-- is off has no tab, its panes are never built, and search, the Back trail
-- and the dungeon map leave it out. `requires` names a module it can't work
-- without: with that one off it is off too, and its own choice is kept for
-- when that one comes back. `sub` marks a part of another tab rather than a
-- tab of its own (Settings lists it under that tab, with `atlas` as its
-- icon if given; `own` lists it as a row of its own instead, as Quests,
-- part of both Dungeons and Raids); `detail` adds to its tooltip there.
-- `off`: off until turned on (a choice rather than a tab). Saved account-wide
-- (NeedRollDB.modules).
local Modules = {
    list = {
        { key = "DUNGEON", label = L["Dungeons"], about = L["Loot, quests, maps and boss abilities"] },
        { key = "RAID", label = L["Raids"], about = L["Raid loot, quests and attunements"] },
        { key = "QUESTS", label = L["Quests"], about = L["Dungeon quests and raid attunements"],
            detail = L["Turned off, Dungeons and Raids show only loot, bosses and maps: no Quests list, quest pages or raid Attunement."],
            atlas = "Exclamation-up-c60", sub = true, own = true },
        { key = "QUEST_MAP_FILTER", label = L["Show only accepted quests"],
            about = L["When enabled: the dungeon map only shows quests you're on or can pick up inside the instance"],
            detail = L["On, the dungeon map shows quest markers, kill and loot icons, drop areas and zone-wide quests only for quests in your quest log, and the \"!\" of quests you can pick up inside. Off, it shows every quest's. A target clicked on a quest page shows its markers either way."],
            atlas = "Crosshair_lootall_96", requires = "QUESTS", sub = true, off = true },
        { key = "QUEST_GIVER_MARKERS", label = L["Quest givers on the world map"],
            about = L["Marks where to pick up dungeon and raid quests you can take"],
            detail = L["A quest \"!\" where you can pick one up now; a questline \"!\" where the steps one needs first start. Click to open it in NeedRoll."],
            atlas = "QuestNormal", requires = "QUESTS", sub = true },
        { key = "QUEST_LOG_BUTTON", label = L["Open in NeedRoll in the quest log"],
            about = L["The quest chain note and Open in NeedRoll button in a quest's details"],
            detail = L["A chain quest names its dungeon beside the Back button, with a button to open it in NeedRoll."],
            atlas = "questlog-questtypeicon-dungeon", requires = "QUESTS", sub = true },
        { key = "PVP", label = L["PvP"], about = L["Honor and battleground rewards"] },
        { key = "FACTION", label = L["Factions"], about = L["Reputation rewards"] },
        { key = "COLLECTION", label = L["Collections"], about = L["Tier sets, mounts, pets and more"] },
        { key = "LIBRARY_BOOKS", label = L["Library"],
            about = L["Where every library book is, and which ones you've handed in"],
            detail = L["Each book's spot as a map pin, whether you hold it or handed it in, and the reward quests at 10, 20, 25 and 38 books."] },
        { key = "LIBRARY_BOOK_MARKERS", label = L["Books on the world map"],
            about = L["Marks the library books you haven't found yet"],
            detail = L["Only books you haven't handed in and don't hold in your bags or bank. Click one to open the Library."],
            atlas = "Campaign-QuestLog-LoreBook", requires = "LIBRARY_BOOKS", sub = true },
        -- Part of no tab and needing none, so a row of its own (`own`), not indented under a tab.
        { key = "PORTAL_MARKERS", label = L["Portals on the world map"],
            about = L["Marks the portals to other cities and zones"],
            detail = L["Both sides' portals, on the zone map each stands in. Click one to pin it on your map."],
            atlas = "PortalPurple", sub = true, own = true },
        { key = "PROFESSION", label = L["Professions"], about = L["Recipes, materials and where to learn them"] },
        { key = "PROFESSION_ICONS", label = L["Professions Icons"], about = L["Item icons beside recipes in the Professions list"],
            detail = L["Shows what each recipe makes, in a ring left of its name. Hover one for the item's tooltip."],
            requires = "PROFESSION", sub = true },
        { key = "SHOPPING", label = L["Shopping List"], about = L["Materials to buy for your crafts"], requires = "PROFESSION" },
        { key = "WISHLIST", label = L["Wishlist"], about = L["Gear you want, starred on loot lists"] },
        { key = "CLASSES", label = L["Classes"], about = L["Every class's talent trees, with a planner"] },
    },
    byKey = {},
}
for _, info in ipairs(Modules.list) do Modules.byKey[info.key] = info end
ns.Modules = Modules

-- Whether the player left `key` on, whatever it needs.
function Modules:Chosen(key)
    local saved = ns.db and ns.db.modules[key]
    if saved == nil then return not (self.byKey[key] and self.byKey[key].off) end
    return saved ~= false
end

-- Whether `key` is in use: chosen and everything it needs is too. Keys that
-- aren't modules always are.
function Modules:IsOn(key)
    local info = self.byKey[key]
    if not info then return true end
    return self:Chosen(key) and (not info.requires or self:IsOn(info.requires))
end

-- How many tabs are in use; with `without`, as if it (and what needs it) were off too.
function Modules:Count(without)
    local count = 0
    for _, info in ipairs(self.list) do
        local wouldGoOff = without and (info.key == without or self:Needs(info.key, without))
        if not info.sub and self:IsOn(info.key) and not wouldGoOff then count = count + 1 end
    end
    return count
end

-- Whether `key` needs `other`, directly or through another module.
function Modules:Needs(key, other)
    local info = self.byKey[key]
    while info and info.requires do
        if info.requires == other then return true end
        info = self.byKey[info.requires]
    end
    return false
end

-- One tab always stays: `key` can be turned off while another would be left.
function Modules:CanTurnOff(key)
    return self.byKey[key].sub or self:Count(key) > 0
end

-- `key` if it is a tab in use, else the first tab that is.
function Modules:Usable(key)
    local asked = self.byKey[key]
    if asked and not asked.sub and self:IsOn(key) then return key end
    for _, info in ipairs(self.list) do
        if not info.sub and self:IsOn(info.key) then return info.key end
    end
    return "DUNGEON"
end

function Modules:Set(key, on)
    if not self.byKey[key] or on == self:Chosen(key) then return end
    if not on and not self:CanTurnOff(key) then return end
    -- Saved only when it differs from the module's default.
    local isOnByDefault = not self.byKey[key].off
    if on == isOnByDefault then
        ns.db.modules[key] = nil
    else
        ns.db.modules[key] = on
    end
    if ns.Search and ns.Search.Reset then ns.Search:Reset() end
    if ns.UI and ns.UI.ApplyModules then ns.UI:ApplyModules() end
    if ns.WorldMapOverlay then ns.WorldMapOverlay:Recheck() end
    if ns.WorldMapMarkers then ns.WorldMapMarkers.Invalidate() end
    if ns.QuestChainNotes then ns.QuestChainNotes.Refresh() end
end

-- Saved settings that leave nothing on (or name a module that went away)
-- turn Dungeons back on.
function Modules:Check()
    for key in pairs(ns.db.modules) do
        if not self.byKey[key] then ns.db.modules[key] = nil end
    end
    if self:Count() == 0 then ns.db.modules.DUNGEON = nil end
end

-- The addon's name in blue, at the start of every chat line it prints.
local CHAT_NAME = "|cff7fb2ffNeedRoll|r"

function ns:Print(...)
    print(CHAT_NAME, ...)
end

-- Secret values: WoW: Forever (Blizzard's Midnight API) can hand addons a value they may not
-- read: tooltip creature names, quest titles, some unit names and GUIDs, inspect tooltip sizes.
-- Comparing one, doing math on it, joining it into text or using it as a table key throws,
-- so check with issecretvalue() first. ns.Plain(value): the value, or nil when it is secret.
function ns.Plain(value)
    if issecretvalue(value) then return nil end
    return value
end

-- Your character's level. Ketho's lists don't say whether Forever can hand it back secret, so
-- it is read through ns.Plain like any other unit value; 1 stands in if it can't be read, as
-- the pages only compare it with levels and show it.
function ns.PlayerLevel()
    return ns.Plain(UnitLevel("player")) or 1
end

-- Text someone else wrote (pasted, or heard from another player's copy), made to show as
-- typed: a doubled "|" can't start a color, line break, texture or hyperlink.
function ns.Literal(text)
    return (text:gsub("|", "||"))
end

-- The forms a game format string with a Korean particle pick ("|1이라는;라는;": the game keeps
-- the first after a consonant, the second after a vowel) can take, one for each choice.
local function ParticleForms(format)
    local first, second = format:match("|1([^;]*);([^;]*);")
    if not first then return { format } end
    local forms = {}
    for _, choice in ipairs({ first, second }) do
        local picked = format:gsub("|1[^;]*;[^;]*;", (choice:gsub("%%", "%%%%")), 1)
        for _, form in ipairs(ParticleForms(picked)) do table.insert(forms, form) end
    end
    return forms
end

-- Lua patterns that read a line the game wrote from one of its format strings (ERR_*, ITEM_*,
-- in the client's language), each capturing the %s and %d values in order. The game's grammar
-- picks are read too: a plural ("|4item:items;", Russian) matches any word, and a Korean
-- particle gets a pattern for each choice. A line can match more than one; try them in order.
function ns.GameTextPatterns(format)
    local patterns = {}
    local plain = format:gsub("%%%d%$([sd])", "%%%1"):gsub("|4[^;]*;", "\001")
    for _, form in ipairs(ParticleForms(plain)) do
        local pattern = form:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
        pattern = pattern:gsub("%%%%d", "(%%d+)"):gsub("%%%%s", "(.+)"):gsub("\001", ".-")
        table.insert(patterns, "^" .. pattern .. "$")
    end
    return patterns
end

--[==[@debug@
-- ns.ReadGameText's patterns and argument order for each format it has read. Only the run
-- tracker (Core/Runs.lua, local checkouts only) reads the game's lines this way yet, so a release
-- leaves both out.
local gameTextReaders = {}

-- The values a line the game wrote from `format` carries, keyed by their argument number in the
-- format, or nil when the line isn't one of its. A translation can put the values in another
-- order than English ("%4$s ... %2$d ... %3$s"), so values[2] is the second argument wherever
-- that client's text puts it. Every value is the text the line has there.
function ns.ReadGameText(text, format)
    local reader = gameTextReaders[format]
    if not reader then
        local order, nextArgument = {}, 0
        for position in format:gmatch("%%(%d*)%$?[sd]") do
            nextArgument = nextArgument + 1
            table.insert(order, tonumber(position) or nextArgument)
        end
        reader = { patterns = ns.GameTextPatterns(format), order = order }
        gameTextReaders[format] = reader
    end
    for _, pattern in ipairs(reader.patterns) do
        if text:find(pattern) then
            local captures, values = { text:match(pattern) }, {}
            for i, argument in ipairs(reader.order) do values[argument] = captures[i] end
            return values
        end
    end
end
--@end-debug@]==]

-- The game's IDs, counts and builds fit a 32-bit signed integer.
local HEARD_NUMBER_MAX = 2147483647

-- A number in text someone else wrote (a message heard from another player's copy, a pasted
-- talent plan): plain digits only, at most `max` (HEARD_NUMBER_MAX when left out), else nil
-- (treated as missing). Bare tonumber would also take "nan", "inf", "0x1f", "-3", "1.5" and
-- "1e9", which NeedRoll never writes. `base` 36 reads the lowercase base-36 digits (0-9, a-z)
-- a talent plan's share string packs its talent IDs in.
function ns.HeardNumber(field, max, base)
    local digits = base == 36 and "^[%da-z]+$" or "^%d+$"
    if type(field) ~= "string" or not field:match(digits) then return nil end
    local number = tonumber(field, base or 10)
    if number > (max or HEARD_NUMBER_MAX) then return nil end
    return number
end

local BASE36_DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"

-- A whole number in lowercase base 36, which keeps share strings short (a wishlist's items, a
-- talent plan's talents); ns.HeardNumber(code, nil, 36) or tonumber(code, 36) reads it back.
function ns.Base36(number)
    local text = ""
    repeat
        local digit = number % 36
        text = BASE36_DIGITS:sub(digit + 1, digit + 1) .. text
        number = math.floor(number / 36)
    until number == 0
    return text
end

-- UTF-8 writes a letter outside English as a lead byte and then continuation bytes (128-191):
-- a Cyrillic letter is 2 bytes, a Hangul one 3.
local function IsContinuationByte(byte)
    return byte >= 128 and byte <= 191
end

-- `text` cut to at most `maxBytes` bytes, never inside a UTF-8 character: a cut that would
-- split one drops that whole character.
function ns.CutToBytes(text, maxBytes)
    if #text <= maxBytes then return text end
    local cut = maxBytes
    while cut > 0 and IsContinuationByte(text:byte(cut + 1)) do cut = cut - 1 end
    return text:sub(1, cut)
end

-- A name the player typed for something saved (a wishlist, a talent plan), as it is kept:
-- trimmed, on one line, no colons (share strings use them) or "|" (it starts the game's text
-- codes), at most `maxBytes` bytes long. Nil when nothing is left.
function ns.CleanName(name, maxBytes)
    name = strtrim((tostring(name or ""):gsub("[:|\n\r]", " "):gsub("%s+", " ")))
    if name == "" then return nil end
    return ns.CutToBytes(name, maxBytes)
end

-- A unit or object GUID's parts: "Creature-0-<server>-<instance>-<zoneUID>-<ID>-<spawnUID>"
-- gives "Creature", the ID as a number, and the spawn key "<zoneUID>-<spawnUID>", which names
-- one spawn in one instance run (one corpse); the spawn key is nil unless the spawn part is
-- plain hex, as the game writes it. Nil for anything else (players, items, no GUID).
function ns.ParseGUID(guid)
    if type(guid) ~= "string" then return nil end
    local unitType, zone, id, spawn = guid:match("^(%a+)%-%d+%-%d+%-%d+%-(%d+)%-(%d+)%-(.*)$")
    if not unitType then return nil end
    local spawnKey = spawn:match("^%x+$") and (zone .. "-" .. spawn) or nil
    return unitType, tonumber(id), spawnKey
end

-- The creature ID of `unit` ("npc" is the trainer or vendor whose window is
-- open), or 0 when it isn't a creature or its GUID can't be read (secret).
function ns.NpcIDOf(unit)
    local unitType, npcID = ns.ParseGUID(ns.Plain(UnitGUID(unit)))
    return unitType == "Creature" and npcID or 0
end

-- How many keys table `map` has (# counts only a list's 1 to n).
function ns.CountKeys(map)
    local count = 0
    for _ in pairs(map) do count = count + 1 end
    return count
end

-- The colours the game's own money text gives the "g", "s" and "c" after
-- each amount. Forever's interface names no constant for them (Ketho's
-- forever lists have only the coin letters and icons), so they're written
-- out here.
local GOLD_COIN_COLOR = "|cffffd700"
local SILVER_COIN_COLOR = "|cffc7c7cf"
local COPPER_COIN_COLOR = "|cffeda55f"

-- One coin's part, "5g": `amountFormat` filled with `amount`, its letters
-- (what isn't a digit) in `coinColor`, the digits left in the surrounding
-- text's colour.
local function CoinText(amountFormat, amount, coinColor)
    local text = amountFormat:format(amount)
    return (text:gsub("%D+", function(letters) return coinColor .. letters .. "|r" end))
end

-- A sum of money: "5g 3s 20c" ("" for none, or "0c" with `showZero` where
-- a blank would read as missing), each coin's letter in the game's colour
-- for it. Forever has no global GetCoinTextureString (only
-- C_CurrencyInfo's), so this text is what players see; the coin icons show
-- only where the old global exists.
function ns.Money(copper, showZero)
    if GetCoinTextureString then return GetCoinTextureString(copper) end
    local gold, silver, copperLeft = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if gold > 0 then table.insert(parts, CoinText(L["%dg"], gold, GOLD_COIN_COLOR)) end
    if silver > 0 then table.insert(parts, CoinText(L["%ds"], silver, SILVER_COIN_COLOR)) end
    if copperLeft > 0 or (showZero and copper == 0) then
        table.insert(parts, CoinText(L["%dc"], copperLeft, COPPER_COIN_COLOR))
    end
    return table.concat(parts, " ")
end

-- Character keys ----------------------------------------------------------------
-- Each character's own saved data (PER_CHARACTER_TABLES below) is kept under its GUID,
-- "Player-<server ID>-<character ID>", which names one character on one server for good. Up to
-- v2.0.0 it was "Name-Realm", with the first name UnitName gives; since WoW: Forever's build 71037
-- GetRealmName() is empty, so that key became "Name-" and two characters of one first name on
-- different servers shared it.

-- The last player GUID read: the player can't change within a session, so it stays the key
-- while the GUID can't be read (a secret value).
local lastPlayerGUID

-- The old "Name-Realm" key, with "?" for an empty realm: the key until the GUID has been read.
local function FallbackKey()
    local name, realm = ns.Plain(UnitName("player")), ns.Plain(GetRealmName())
    return (name or "?") .. "-" .. ((realm and realm ~= "") and realm or "?")
end

-- The key this character's own saved data is kept under: its GUID. Until the GUID has been read
-- (the game may not give it before PLAYER_LOGIN) FallbackKey(); ns.MoveSavedDataToGUIDKey takes
-- what was saved under that over at login.
function ns.CharacterKey()
    local guid = ns.Plain(UnitGUID("player"))
    if guid then lastPlayerGUID = guid end
    return lastPlayerGUID or FallbackKey()
end

-- The ID of the server this character is on, from its GUID; nil until the GUID has been read.
-- Characters on one server can mail each other.
function ns.PlayerServerID()
    return tonumber(ns.CharacterKey():match("^Player%-(%d+)%-%x+$"))
end

-- NeedRollDB's table at `path`, or nil when there is none (nothing is made).
local function SavedTable(path)
    local saved = ns.db
    for _, key in ipairs(path) do
        saved = type(saved) == "table" and saved[key] or nil
    end
    return type(saved) == "table" and saved or nil
end

local function IsEmpty(value)
    return value == nil or (type(value) == "table" and next(value) == nil)
end

-- How an old key's entry is merged into the GUID key's (`current`). MoveTableEntries goes from the
-- newest old key to the oldest, so what the GUID key already has wins, then the newest.

-- A live snapshot NeedRoll writes again at once (record, bags, bank): the newest one whole.
local function TakeNewest(current, older)
    if IsEmpty(current) and not IsEmpty(older) then return older end
    return current
end

-- Settings a player builds up (open and shut sections, the loot filter, the Known box): every key
-- older has and current lacks, tables within tables too. NeedRoll writes empty shells on first
-- use (a loot filter of { types = {} }, an area's {}), so the states set before build 71037 and
-- not touched since stay. Some settings save "off" as no key at all (the loot filter's class and
-- types, the ticked Known box), so one cleared since comes back from the older key, once, at the
-- move.
local function FillIn(current, older)
    if current == nil then return older end
    if type(current) ~= "table" or type(older) ~= "table" then return current end
    for key, value in pairs(older) do current[key] = FillIn(current[key], value) end
    return current
end

-- Two lists of saved events joined, by each entry's `timeField`; an entry of `older` with the
-- same time and `idField` as one in `current` is the same event and is left out.
local function JoinLists(current, older, timeField, idField)
    if type(current) ~= "table" then return older end
    if type(older) ~= "table" then return current end
    local function EventKey(entry) return tostring(entry[timeField]) .. ":" .. tostring(entry[idField]) end
    local isListed = {}
    for _, entry in ipairs(current) do isListed[EventKey(entry)] = true end
    for _, entry in ipairs(older) do
        if not isListed[EventKey(entry)] then table.insert(current, entry) end
    end
    table.sort(current, function(a, b) return (a[timeField] or 0) < (b[timeField] or 0) end)
    return current
end

-- Core/Runs.lua's runs: one list, oldest first (Runs keeps the newest RUNS_KEPT at the next run).
local function JoinRuns(current, older)
    return JoinLists(current, older, "startedAt", "mapID")
end

-- Core/Drops.lua's chain clues: the hand-in histories joined, the NPC snapshots and counts filled in.
-- FillIn would merge the two history lists index by index (filling one hand-in's fields from an
-- unrelated one and adding older's past the end), so the history is out of current while it runs.
local function JoinChainClues(current, older)
    if type(current) ~= "table" or type(older) ~= "table" then return TakeNewest(current, older) end
    local history = JoinLists(current.history, older.history, "at", "quest")
    current.history = nil
    FillIn(current, older)
    current.history = history
    return current
end

-- The saved tables that keep one entry per character under ns.CharacterKey(): each one's path
-- in NeedRollDB, and how an old key's entry is merged into the GUID key's.
local PER_CHARACTER_TABLES = {
    { path = { "characters" }, Merge = TakeNewest },             -- Core/Shopping.lua: who, money
    { path = { "bags" }, Merge = TakeNewest },
    { path = { "bank" }, Merge = TakeNewest },
    { path = { "sections", "characters" }, Merge = FillIn },     -- remembered sections ("lootClasses" too)
    { path = { "lootFilter" }, Merge = FillIn },                 -- UI/LootGrid.lua
    { path = { "hideKnownPoisons" }, Merge = FillIn },           -- UI/Poisons.lua
    { path = { "questOffers" }, Merge = JoinChainClues },        -- Core/Drops.lua
    { path = { "runs" }, Merge = JoinRuns },                     -- Core/Runs.lua (local checkouts only)
}

-- Whether `key` is a character key from before GUID keys for the first name `name`.
local function IsOldKeyOf(key, name)
    local prefix = name .. "-"
    return type(key) == "string" and key:sub(1, #prefix) == prefix and not key:find("^Player%-%d+%-%x+$")
end

-- Whether an old key's saved record (NeedRollDB.characters) is another character of the same
-- first name: one of another class or side. Without a record nothing says so.
local function IsOtherCharacter(record, class, faction)
    if type(record) ~= "table" then return false end
    return (record.class ~= nil and record.class ~= class) or (record.faction ~= nil and record.faction ~= faction)
end

-- The realm part of an old key of the first name `name`: "" for "Name-", "?" for a FallbackKey
-- written while GetRealmName() was empty, else the realm name the key was saved under.
local function RealmOfOldKey(key, name)
    return key:sub(#name + 2)
end

local function IsRealmName(realm)
    return realm ~= "" and realm ~= "?"
end

-- Of `keys` ("Name-<realm>", saved before build 71037), the one of this character on server
-- `serverID`, or nil. NeedRollDB.realmOfServer[serverID] holds the realm name the game gave for
-- that server (GetRealmName(), noted by MoveSavedDataToGUIDKey); with it, the key of that realm
-- is this character's, at any login. Without it, only at the first move (`isFirstMove`): a key
-- left alone once the realms the game gave for other servers are set aside. That is a guess (a
-- character made since build 71037 can take the key of one of the same first name, class and
-- side on another server), so a key taken this way never teaches its realm to realmOfServer.
-- With two left, which one is this character's can't be told: both wait until the game gives
-- the realm name of this character's server.
local function RealmNamedKeyOfMine(keys, name, serverID, isFirstMove)
    local realmOfServer = TableIn(ns.db, "realmOfServer")
    local myRealm = realmOfServer[serverID]
    if myRealm then
        for _, key in ipairs(keys) do
            if RealmOfOldKey(key, name) == myRealm then return key end
        end
        return nil
    end
    if not isFirstMove then return nil end
    local isOtherServersRealm, possible = {}, {}
    for _, realm in pairs(realmOfServer) do isOtherServersRealm[realm] = true end
    for _, key in ipairs(keys) do
        if not isOtherServersRealm[RealmOfOldKey(key, name)] then table.insert(possible, key) end
    end
    if #possible == 1 then return possible[1] end
end

-- This character's entries under old keys, newest first. What this session saved before the
-- GUID could be read (FallbackKey) is always taken. At the first move (`isFirstMove`) also
-- "Name-" (saved since build 71037). Then the "Name-<realm>" key saved before it that is this
-- character's (RealmNamedKeyOfMine), at any login while one is left.
local function OldKeysOfMine(name, class, faction, serverID, isFirstMove)
    local records = SavedTable({ "characters" }) or {}
    local isCandidate = {}
    for _, saved in ipairs(PER_CHARACTER_TABLES) do
        for key in pairs(SavedTable(saved.path) or {}) do
            if IsOldKeyOf(key, name) and not IsOtherCharacter(records[key], class, faction) then
                isCandidate[key] = true
            end
        end
    end
    local mine = {}
    local function Take(key)
        if not (key and isCandidate[key]) then return end
        table.insert(mine, key)
        isCandidate[key] = nil
    end
    Take(FallbackKey())
    if isFirstMove then Take(name .. "-") end
    local realmNamed = {}
    for key in pairs(isCandidate) do
        if IsRealmName(RealmOfOldKey(key, name)) then table.insert(realmNamed, key) end
    end
    Take(RealmNamedKeyOfMine(realmNamed, name, serverID, isFirstMove))
    return mine
end

-- Notes for every character of the account the realm name the game gives for server `serverID`
-- (NeedRollDB.realmOfServer). Only the game's: since build 71037 GetRealmName() is empty, and a
-- realm named by an old key is a guess (RealmNamedKeyOfMine).
local function NoteRealmOfServer(serverID)
    local realm = ns.Plain(GetRealmName())
    if realm and IsRealmName(realm) then TableIn(ns.db, "realmOfServer")[serverID] = realm end
end

-- Merges one saved table's entries under `oldKeys` (newest first) into `newKey`'s, its own way
-- (`saved`, one of PER_CHARACTER_TABLES), and drops the old keys, so nothing (gold on the
-- Shopping List) counts twice.
local function MoveTableEntries(saved, oldKeys, newKey)
    local entries = SavedTable(saved.path)
    if not entries then return end
    for _, oldKey in ipairs(oldKeys) do
        entries[newKey] = saved.Merge(entries[newKey], entries[oldKey])
        entries[oldKey] = nil
    end
end

-- Takes this character's data saved under old keys over to its GUID key: at its first login with
-- GUID keys (NeedRollDB.movedToGUIDKey[guid] remembers it) all of it; at every login what this
-- session saved before the GUID could be read, and its "Name-<realm>" key once the realm name of
-- its server is known (RealmNamedKeyOfMine). Runs as SavedVariables load and again at
-- PLAYER_LOGIN, the first time the game has the character's GUID, name, class and side. A
-- character's old keys stay until it logs in, and a realm-named key whose server can't be told
-- stays (its gold still counted) until the game gives a character there its realm name.
function ns.MoveSavedDataToGUIDKey()
    if not ns.db then return end
    local guid, name = ns.Plain(UnitGUID("player")), ns.Plain(UnitName("player"))
    local class, faction = select(2, UnitClass("player")), UnitFactionGroup("player")
    local serverID = guid and tonumber(guid:match("^Player%-(%d+)%-"))
    if not (serverID and name and class and faction) then return end
    NoteRealmOfServer(serverID)
    local moved = TableIn(ns.db, "movedToGUIDKey")
    local oldKeys = OldKeysOfMine(name, class, faction, serverID, not moved[guid])
    moved[guid] = true
    if not oldKeys[1] then return end
    for _, saved in ipairs(PER_CHARACTER_TABLES) do MoveTableEntries(saved, oldKeys, guid) end
end

ns:On("ADDON_LOADED", function(loadedAddon)
    if loadedAddon == addonName then ns.MoveSavedDataToGUIDKey() end
end)
ns:On("PLAYER_LOGIN", ns.MoveSavedDataToGUIDKey)

-- The player's side as quests and lists name it: "Horde", else "Alliance".
-- What NeedRoll shows asks this; what it saves or shares about the
-- character (Core/Drops.lua, Core/Shopping.lua) asks the game.
function ns.PlayerFaction()
    --[==[@debug@
    -- Local checkouts: /nr devedit's "View as" boxes (UI/MapEdit.lua).
    if ns.viewAsFaction then return ns.viewAsFaction end
    --@end-debug@]==]
    return UnitFactionGroup("player") == "Horde" and "Horde" or "Alliance"
end

-- Whether this character has done quest `questID` (the game keeps that per
-- character); false for no quest.
function ns.IsQuestDone(questID)
    return questID ~= nil and C_QuestLog.IsQuestFlaggedCompleted(questID) == true
end

-- Whether the other side can attack the player out in the world: where the
-- game has War Mode, War Mode on; else a realm with PvP rules. When the game
-- doesn't say, true: the Professions Overview then keeps its safe zones
-- apart, the careful answer.
function ns.IsPvPRealm()
    if C_PvP and C_PvP.IsWarModeFeatureEnabled and C_PvP.IsWarModeFeatureEnabled() then
        return C_PvP.IsWarModeDesired() == true
    end
    local pvpRules = Enum and Enum.GameRule and Enum.GameRule.PvPRuleset
    if not (pvpRules and C_GameRules and C_GameRules.IsGameRuleActive) then return true end
    return C_GameRules.IsGameRuleActive(pvpRules) ~= false
end

--[==[@debug@
-- Dev builds: tools/combatlog needs combat logs with Advanced Combat
-- Logging's extra fields (the caster's zone and level), so at login this
-- turns both on and returns how it went, for the end of the login line.
local function CombatLoggingStatus()
    local isLogging = LoggingCombat() or (pcall(LoggingCombat, true) and LoggingCombat())
    local text
    if C_CVar.GetCVarBool("advancedCombatLogging") then
        text = "Advanced Combat Logging is enabled."
    elseif pcall(C_CVar.SetCVar, "advancedCombatLogging", "1") and C_CVar.GetCVarBool("advancedCombatLogging") then
        text = "Advanced Combat Logging was off, so NeedRoll enabled it."
    else
        text = "Advanced Combat Logging is off: System > Network > Advanced Combat Logging."
    end
    if not isLogging then text = text .. " Couldn't start /combatlog: type it yourself." end
    return text
end
--@end-debug@]==]

-- Addon messages ----------------------------------------------------------
-- Every hidden addon message NeedRoll sends (the version check below, drop
-- sharing in Core/Drops.lua, its copies to Battle.net friends among them)
-- goes out on one prefix, and the game lets a prefix send 10 messages,
-- refilled one a second, before it answers
-- "throttled". So they all go through AddonMessages:Send and share its
-- count: THROTTLE_STOP throttled answers stop all of them until a /reload.
-- The game also blocks addon messages at times (boss fights and the like);
-- each sender waits that out with AddonMessages:WaitsOnLockdown, which only
-- holds for LOCKDOWN_MAX seconds, since a check stuck on "blocked" would
-- otherwise keep NeedRoll from ever sending.
local AddonMessages = {
    PREFIX = "NeedRoll",
    RETRY = 120,           -- seconds before a message that couldn't go is tried again
    LOCKDOWN_MAX = 120,    -- seconds of lockdown after which a send is tried anyway
    THROTTLE_PAUSE = 600,  -- seconds of quiet after the game says "throttled"
    THROTTLE_STOP = 3,     -- throttled answers after which nothing more is sent this session
    -- The game's checks for a lockdown, as C_ChatInfo names them.
    LOCKDOWN_CHECKS = { "AreOutgoingAddonChatMessagesRestricted", "InChatMessagingLockdown" },
    throttledCount = 0,
    isStoppedThisSession = false,
    lockedDownSince = nil, -- GetTime() when a lockdown check first said yes
}
ns.AddonMessages = AddonMessages

-- Whether the game blocks addon messages right now. Only a plain true
-- counts, and a check that errors doesn't: a copy whose outbox waited on
-- one never sent anything at all.
function AddonMessages:IsLockedDown()
    for _, name in ipairs(self.LOCKDOWN_CHECKS) do
        local ok, restricted = pcall(C_ChatInfo[name])
        if ok and restricted == true then return true end
    end
    return false
end

-- Whether a message should wait for a lockdown to end: true while one has
-- lasted less than LOCKDOWN_MAX seconds, after which the message is tried
-- anyway (the game then says if it's still blocked).
function AddonMessages:WaitsOnLockdown()
    if not self:IsLockedDown() then
        self.lockedDownSince = nil
        return false
    end
    self.lockedDownSince = self.lockedDownSince or GetTime()
    return GetTime() - self.lockedDownSince < self.LOCKDOWN_MAX
end

-- The name of a SendAddonMessage answer ("Success", "InvalidChannel", ...),
-- or nil for a number Enum.SendAddonMessageResult doesn't have.
function AddonMessages.ResultName(result)
    for name, value in pairs(Enum.SendAddonMessageResult) do
        if value == result then return name end
    end
end

-- How the game turned a message down: "throttled" (too many sent), "later"
-- (a lockdown or restriction: worth trying again in RETRY seconds), or nil
-- otherwise: sent, or turned down for a reason waiting won't fix (no guild,
-- player offline, too long), which the senders drop like a sent one.
function AddonMessages.Refusal(result)
    if type(result) ~= "number" or result == 0 then return nil end
    local name = AddonMessages.ResultName(result)
    if not name then return nil end
    if name:find("Throttle") then return "throttled" end
    if name:find("Lockdown") or name:find("Restrict") then return "later" end
end

-- Sends one addon message on NeedRoll's prefix (channelOrTarget: a channel
-- number for "CHANNEL", a player for "WHISPER", a Battle.net friend's game
-- account ID for "BNET", which C_BattleNet.SendGameData sends). Returns the
-- game's answer and its Refusal; nil and "stopped" without sending once
-- throttled answers have stopped sending this session. Lockdowns are the
-- caller's to check.
function AddonMessages:Send(text, chatType, channelOrTarget)
    if self.isStoppedThisSession then return nil, "stopped" end
    local result
    if chatType == "BNET" then
        result = C_BattleNet.SendGameData(channelOrTarget, self.PREFIX, text)
    else
        result = C_ChatInfo.SendAddonMessage(self.PREFIX, text, chatType, channelOrTarget)
    end
    local refusal = self.Refusal(result)
    if refusal == "throttled" then
        self.throttledCount = self.throttledCount + 1
        if self.throttledCount >= self.THROTTLE_STOP then self.isStoppedThisSession = true end
    end
    return result, refusal
end

-- Version check -----------------------------------------------------------
-- Addons can't go online, so NeedRoll learns about new releases from other
-- players' copies: each copy tells the guild and group which version it runs
-- (a hidden addon message), and whispers it back to anyone running an older
-- one. Only feature releases count (a newer major or minor number); the
-- daily data patches (vX.Y.Z+1) never nag. Local checkouts carry the
-- packager's placeholder instead of a version, so they neither send nor warn.
local PREFIX = AddonMessages.PREFIX
local VERSION_GAP = 60 -- seconds between version messages to one chat or player

-- "v0.6.2" or "0.6.2" -> 0, 6, 2; anything else -> nil.
local function ParseVersion(text)
    local major, minor, patch = tostring(text or ""):match("^v?(%d+)%.(%d+)%.(%d+)$")
    if major then return tonumber(major), tonumber(minor), tonumber(patch) end
end

-- -1, 0 or 1 as version `a`'s feature release (patch left out) is older, the same or newer than `b`'s.
local function CompareFeature(a, b)
    local aMajor, aMinor = ParseVersion(a)
    local bMajor, bMinor = ParseVersion(b)
    if aMajor ~= bMajor then return aMajor < bMajor and -1 or 1 end
    if aMinor ~= bMinor then return aMinor < bMinor and -1 or 1 end
    return 0
end

-- answered: players whispered back; sent: GetTime() of the last message per
-- chat type or target; retrying: chat types and targets with a retry on its way.
local Version = { warned = false, answered = {}, sent = {}, retrying = {} }
ns.Version = Version

-- This copy's version as "0.6.0", or nil for a local checkout.
function Version:Mine()
    if ParseVersion(ns.version) then return (ns.version:gsub("^v", "")) end
end

-- The newer feature release other players run, or nil when up to date.
function Version:Newer()
    local mine, newest = self:Mine(), ns.db and ns.db.newestVersion
    if mine and ParseVersion(newest) and CompareFeature(newest, mine) > 0 then return newest end
end

-- Tries Send again in `seconds`. A chat type or target has at most one
-- retry waiting, and Send leaves it alone until then, so group changes
-- during a lockdown don't pile up timers.
function Version:RetryLater(chatType, target, seconds)
    local key = target or chatType
    self.retrying[key] = true
    C_Timer.After(seconds, function()
        Version.retrying[key] = nil
        Version:Send(chatType, target)
    end)
end

-- Sends this copy's version on a chat type (to `target` for a whisper), at
-- most once every VERSION_GAP seconds each. During a lockdown, or when the game says
-- it's blocked, it's tried again RETRY seconds later; when the game says
-- "throttled", THROTTLE_PAUSE seconds later. Other refusals (not in a guild,
-- player offline, sending stopped for the session) drop it like a sent one.
function Version:Send(chatType, target)
    local mine = self:Mine()
    local key = target or chatType
    if not mine or self.retrying[key] then return end
    local now = GetTime()
    if self.sent[key] and now - self.sent[key] < VERSION_GAP then return end
    if AddonMessages:WaitsOnLockdown() then return self:RetryLater(chatType, target, AddonMessages.RETRY) end
    local _, refusal = AddonMessages:Send("V:" .. mine, chatType, target)
    if refusal == "throttled" then return self:RetryLater(chatType, target, AddonMessages.THROTTLE_PAUSE) end
    if refusal == "later" then return self:RetryLater(chatType, target, AddonMessages.RETRY) end
    self.sent[key] = now
end

function Version:Broadcast()
    if IsInGuild() then self:Send("GUILD") end
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        self:Send("INSTANCE_CHAT")
    elseif IsInRaid() then
        self:Send("RAID")
    elseif IsInGroup() then
        self:Send("PARTY")
    end
end

-- Once a session: the chat line, and the window's footer note.
function Version:Announce()
    local newer = self:Newer()
    if newer and not self.warned then
        self.warned = true
        ns:Print(L["v%s is available (you are running v%s). Update through CurseForge."]
            :format(newer, self:Mine()))
    end
    if ns.UI and ns.UI.UpdateVersionNote then ns.UI:UpdateVersionNote() end
end

-- Another copy's "V:<version>" message: a newer feature release is kept
-- and announced; an older copy is whispered this one's version, once.
function Version:Heard(text, sender)
    local theirs = tostring(text or ""):match("^V:(.+)$")
    local mine = self:Mine()
    if not (mine and ParseVersion(theirs)) then return end
    local order = CompareFeature(theirs, mine)
    if order > 0 then
        local newest = ns.db.newestVersion
        if not ParseVersion(newest) or CompareFeature(theirs, newest) > 0 then
            ns.db.newestVersion = theirs
        end
        self:Announce()
    elseif order < 0 and not self.answered[sender] then
        -- They may have logged in before us and missed our broadcast.
        self.answered[sender] = true
        self:Send("WHISPER", sender)
    end
end

-- The login line: "NeedRoll v0.6.0 by Flowmotion". A local checkout has no
-- version number, so it says "dev"; dev builds add how combat logging is set.
ns:On("PLAYER_LOGIN", function()
    local mine = Version:Mine()
    local line = (CHAT_NAME .. " " .. L["%s by Flowmotion"]):format(mine and ("v" .. mine) or "dev")
    --[==[@debug@
    line = line .. " - " .. CombatLoggingStatus()
    --@end-debug@]==]
    print(line)
end)

-- A language picked in Settings can only apply if the game loads NeedRollDB
-- before NeedRoll's files (the .toc's LoadSavedVariablesFirst, see
-- Locales/Locales.lua). If it loaded them first, the text came up in the
-- client's language: say so at login, so the setting doesn't just look broken.
ns:On("PLAYER_LOGIN", function()
    local picked = ns.KnownLanguage(ns.db.language)
    if not picked or picked == ns.loadedLanguage then return end
    ns:Print(L["NeedRoll couldn't switch to the language picked in Settings on this client."])
end)

ns:On("PLAYER_LOGIN", function()
    if not Version:Mine() then return end
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    -- An update since last time clears the saved notice.
    if ParseVersion(ns.db.newestVersion) and CompareFeature(ns.db.newestVersion, Version:Mine()) <= 0 then
        ns.db.newestVersion = nil
    end
    C_Timer.After(10, function()
        Version:Announce()
        Version.inGroup = IsInGroup()
        Version:Broadcast()
    end)
end)

-- Copies tell only their guild and group (and whisper older copies), so a
-- version heard on a custom channel, the realm channel included, is never
-- one of theirs: anyone can send there.
ns:On("CHAT_MSG_ADDON", function(prefix, text, chatType, sender)
    if prefix ~= PREFIX or not sender or chatType == "CHANNEL" then return end
    if Ambiguate(sender, "none") == UnitName("player") then return end
    Version:Heard(text, sender)
end)

-- Joining a group tells its members (the roster event fires often, so only
-- on the change from solo to grouped).
ns:On("GROUP_ROSTER_UPDATE", function()
    local inGroup = IsInGroup()
    if inGroup and Version.inGroup == false then Version:Broadcast() end
    if Version.inGroup ~= nil then Version.inGroup = inGroup end
end)

-- Shows or hides the window (UI/MainFrame.lua), or says so if the UI files failed to load.
function ns:Toggle()
    if ns.UI and ns.UI.Toggle then
        ns.UI:Toggle()
    else
        ns:Print(L["UI not built yet."])
    end
end

-- Slash commands ----------------------------------------------------------
-- /nr (or /needroll) toggles the window, as does a word it doesn't know. A known word runs
-- its `commands` entry with `arg` the next word and `rest` the rest of the line, lower case.
SLASH_NEEDROLL1 = "/nr"
SLASH_NEEDROLL2 = "/needroll"
local commands = {}

-- The style after `skin` among those that can be shown now, the first
-- again after the last (or for a style that can't be shown).
local function NextSkin(skin)
    local skins = ns.Theme:AvailableSkins()
    for i, name in ipairs(skins) do
        if name == skin then return skins[i % #skins + 1] end
    end
    return skins[1]
end

-- /nr style [native|modern|dark|elvui]: the window's look; no name moves on
-- to the next style. ElvUI's only while ElvUI is loaded.
function commands.style(arg)
    local Theme = ns.Theme
    local target = arg ~= "" and arg or NextSkin(ns.db.skin)
    if not Theme:IsSkinAvailable(target) then
        ns:Print(L["Styles: %s."]:format(table.concat(Theme:AvailableSkins(), ", ")))
        return
    end
    ns.UI:SetSkin(target)
    ns:Print(L["Window style: %s."]:format(Theme.skinNames[target]))
end
commands.skin = commands.style

-- /nr text [normal|large] (or size, font): the text size; no name switches.
function commands.text(arg)
    local target = arg ~= "" and arg or (ns.db.textSize == "large" and "normal" or "large")
    local names = ns.Theme.textSizeNames
    if not names[target] then
        ns:Print(L["Text sizes: normal, large."])
        return
    end
    ns.UI:SetTextSize(target)
    ns:Print(L["Text size: %s."]:format(names[target]))
end
commands.size = commands.text
commands.font = commands.text

-- Saves the language pick (nil: Game language) and says when it shows:
-- after a reload, or already, when the text is in that language now.
local function SaveLanguagePick(code)
    ns.db.language = code
    if not ns.LanguageNeedsReload(code) then
        ns:Print(L["NeedRoll's text is already in %s."]:format(ns.LanguageName(ns.loadedLanguage)))
    elseif code then
        ns:Print(L["NeedRoll's text switches to %s after a /reload."]:format(ns.LanguageName(code)))
    else
        ns:Print(L["NeedRoll's text follows the game's language after a /reload."])
    end
end

-- /nr language [game|enus|dede|...]: the language of NeedRoll's own text,
-- as Settings' Language picks it; it switches after a reload. No name, or
-- one NeedRoll hasn't, lists them.
function commands.language(arg)
    if arg == "game" then return SaveLanguagePick(nil) end
    local codes = {}
    for _, language in ipairs(ns.LANGUAGES) do
        if language.code:lower() == arg then return SaveLanguagePick(language.code) end
        table.insert(codes, language.code)
    end
    ns:Print(L["Languages: %s, or game."]:format(table.concat(codes, ", ")))
end

-- /nr hotfixes: the Game hotfixes page (UI/Hotfixes.lua), also linked at the bottom of Settings.
function commands.hotfixes()
    ns.UI:Show()
    ns.UI:OpenHotfixes()
end

-- The minimap button (UI/MinimapButton.lua), the first-run pointer at the Settings button
-- (UI/Welcome.lua), the game's icons and crests (UI/IconDebug.lua; insigniadebug is its old
-- name) and unit frames (UI/FrameDebug.lua), and the window's default size and position.
function commands.minimap() ns.MinimapButton:Toggle() end
function commands.welcome()
    ns.UI:Show()
    ns.Welcome:Show()
end
function commands.icondebug() ns.IconDebug:Toggle() end
commands.insigniadebug = commands.icondebug
function commands.framedebug() ns.FrameDebug:Toggle() end
function commands.reset()
    ns.UI:ResetWindow()
    ns:Print(L["Window size and position reset."])
end

--[==[@debug@
-- Local checkouts only: the packager leaves this block out of releases, where these words
-- toggle the window like plain /nr. So does a dev tool whose file is missing.
-- devCommandHelp[word] = { usage = its arguments, purpose = what it does }: /nr devcommands
-- lists them. Each sits beside its command so the list can't fall behind, and a smoke scenario
-- checks every command in this block has one. In English, like the dev commands' own output.
local devCommandHelp = {}

-- /nr devedit [reset]: dev edit mode (map spots and which quests start
-- inside), or drops its edits; /nr devexport copies them out (UI/MapEdit.lua).
devCommandHelp.devedit = { usage = "[reset]",
    purpose = "dev edit mode: map spots and which quests start inside; reset drops its edits" }
function commands.devedit(arg)
    if arg == "reset" then ns.MapEdit:Reset() else ns.MapEdit:Toggle() end
end
devCommandHelp.devexport = { usage = "", purpose = "copies dev edit mode's edits out" }
function commands.devexport() ns.MapEdit:Export() end

-- /nr loot [all|clear|scan|leads|fish ...|fished]: recorded drops NeedRoll doesn't list
-- yet, and the item ID scans and sweep (Core/LootLog.lua, UI/Fished.lua).
devCommandHelp.loot = { usage = "[all|clear|scan|leads|fish ...|fished]",
    purpose = "recorded drops NeedRoll doesn't list yet, the item ID scans and the sweep's catches" }
function commands.loot(arg, rest)
    if arg == "clear" then
        ns.LootLog:Clear()
    elseif arg == "scan" then
        ns.LootLog:ScanIDs()
    elseif arg == "leads" then
        ns.LootLog:PrintLeads()
    elseif arg == "fish" then
        ns.LootLog:Fish(rest)
    elseif arg == "fished" then
        ns.FishedWindow:Toggle()
    else
        ns.LootLog:Print(arg == "all")
    end
end

-- /nr runs [new|list|dock|line reset|demo [off|kill|firsttime|raid]]: this dungeon or raid run's
-- bosses, drops and rolls, and why NeedRoll took it for a new run or the same one; new starts a
-- new run by hand; list shows the last few runs (Core/Runs.lua); dock says which Objectives pane
-- the run tracker docked on, or why not; line reset puts its line back under the minimap
-- (UI/RunTracker.lua); demo shows made-up runs on the run pages and the run tracker, kill shows
-- its kill card, firsttime its first-run card and raid puts the player in Molten Core
-- (UI/RunDemo.lua).
devCommandHelp.runs = { usage = "[new|list|dock|line reset|demo [off|kill|firsttime|raid]]",
    purpose = "this run's bosses, drops and rolls; new run by hand; past runs; where the progress docked; "
        .. "the line back under the minimap; made-up runs, cards and line" }
function commands.runs(arg, rest)
    if arg == "demo" and ns.RunDemo then
        ns.RunDemo.Command(rest)
    elseif arg == "dock" and ns.RunTracker then
        ns.RunTracker.Refresh()
        ns:Print(ns.RunTracker.DockStatusText())
    elseif arg == "line" and rest == "reset" and ns.RunTracker then
        ns.RunTracker.ResetLine()
    elseif arg == "new" then
        ns.Runs:StartNew()
    elseif arg == "list" then
        ns.Runs:PrintList()
    else
        ns.Runs:PrintCurrent()
    end
end

-- /nr droptalk [list|key <name>|outbox|pull [on|off|name <name>]|clear]:
-- the boss drop and new quest messages sent and heard, and what was saved; pull turns a PROBERS
-- character's whispered asks on or off, or saves the character's whole name for them
-- (Core/Drops.lua, Core/DropPull.lua, UI/DropTalk.lua).
devCommandHelp.droptalk = { usage = "[list|key <name>|outbox|pull [on|off|name <name>]|clear]",
    purpose = "drop and quest messages sent and heard, what was saved, and whispered asks for finds" }
function commands.droptalk(arg, rest, restAsTyped)
    if arg == "pull" and ns.DropPull then
        ns.DropPull.Command(rest, restAsTyped)
    elseif arg == "clear" then
        ns.Drops:Clear()
    elseif arg == "key" then
        ns.Drops:PrintKey(rest)
    elseif arg == "outbox" then
        ns.Drops:OutboxStatus()
    elseif arg == "list" or not ns.DropTalkWindow then
        ns.Drops:Print()
    else
        ns.DropTalkWindow:Toggle()
    end
end
-- /nr users [history]: how many players share drops (the realm channel's
-- member count), how many copies in the guild answer a roll call, and past
-- roll calls (Core/Drops.lua, Roll call).
devCommandHelp.users = { usage = "[history]",
    purpose = "how many players share drops, a guild roll call, and past roll calls" }
function commands.users(arg)
    if arg == "history" then ns.Drops:PrintRollCalls() else ns.Drops:RollCall() end
end
devCommandHelp.questlog = { usage = "[clear]", purpose = "new quests heard from other players" }
function commands.questlog(arg)
    if arg == "clear" then ns.Drops:QuestLogClear() else ns.Drops:QuestLogPrint() end
end
-- /nr trainercheck [clear]: what the trainers opened teach that differs from
-- NeedRoll's data (Core/TrainerCheck.lua).
devCommandHelp.trainercheck = { usage = "[clear]",
    purpose = "what the trainers opened teach that differs from NeedRoll's data" }
function commands.trainercheck(arg)
    if not ns.TrainerCheck then return ns:Toggle() end
    if arg == "clear" then ns.TrainerCheck:Clear() else ns.TrainerCheck:Print() end
end

-- The UI sound tester, the text size editor (fontdebug [reset]) and mock
-- quest chain lines.
devCommandHelp.sounds = { usage = "", purpose = "the UI sound tester" }
function commands.sounds()
    if not ns.SoundTest then return ns:Toggle() end
    ns.SoundTest:Toggle()
end
devCommandHelp.fontdebug = { usage = "[reset]", purpose = "the text size editor" }
function commands.fontdebug(arg)
    if not ns.FontDebug then return ns:Toggle() end
    ns.FontDebug:Toggle(arg)
end
devCommandHelp.linedump = { usage = "", purpose = "mock quest chain line looks" }
function commands.linedump()
    if not ns.LineDump then return ns:Toggle() end
    ns.LineDump:Toggle()
end
-- /nr levelup [level]: the window of skills to train that an even level up
-- shows, for `level` or your own (UI/LevelUp.lua), even with nothing to train.
devCommandHelp.levelup = { usage = "[level]",
    purpose = "the window of skills to train an even level up shows, for that level or yours" }
function commands.levelup(arg)
    if not ns.LevelUp then return ns:Toggle() end
    ns.LevelUp:Preview(tonumber(arg))
end

-- /nr devcommands: every command in this block with its arguments and what it does, sorted.
-- Chat reads "|" as the start of a code, so each is written doubled.
devCommandHelp.devcommands = { usage = "", purpose = "lists these dev commands" }
function commands.devcommands()
    local words = {}
    for word in pairs(devCommandHelp) do table.insert(words, word) end
    table.sort(words)
    ns:Print("Dev commands (local checkouts only):")
    for _, word in ipairs(words) do
        local help = devCommandHelp[word]
        local usage = help.usage ~= "" and (" " .. help.usage:gsub("|", "||")) or ""
        print(("  /nr %s%s: %s"):format(word, usage, help.purpose))
    end
end
--@end-debug@]==]

local COMMAND_PARTS = "^(%S*)%s*(%S*)%s*(.-)%s*$" -- the command, its first word and the rest

SlashCmdList.NEEDROLL = function(msg)
    local typed = strtrim(msg or "")
    local cmd, arg, rest = typed:lower():match(COMMAND_PARTS)
    local run = commands[cmd]
    if not run then return ns:Toggle() end
    -- The rest as typed too, for a word whose capitals count (a character's name).
    run(arg, rest, (select(3, typed:match(COMMAND_PARTS))))
end

-- The key binding (Bindings.xml): its section and name in the game's Key
-- Bindings, under AddOns. Pressing it runs NeedRoll_OnCompartmentClick.
BINDING_HEADER_NEEDROLL = "NeedRoll"
BINDING_NAME_NEEDROLL_TOGGLE = L["Toggle NeedRoll"]

-- Addon compartment callbacks (named in the .toc).
function NeedRoll_OnCompartmentClick()
    ns:Toggle()
end

function NeedRoll_OnCompartmentEnter(_, owner)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:SetText("NeedRoll")
    GameTooltip:AddLine(L["Click to browse loot."], unpack(ns.Theme.tip.text))
    GameTooltip:Show()
end

function NeedRoll_OnCompartmentLeave()
    GameTooltip:Hide()
end
