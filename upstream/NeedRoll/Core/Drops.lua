-- Drop sharing: copies of NeedRoll tell each other what dungeon and raid
-- bosses drop, so loot lists can be checked and filled in from what players
-- really see (Wowhead can't always be read, and new Forever bosses are
-- missing there). In the open world only Epic items are sent and kept (see
-- Open world below).
--
-- When the player opens a boss's loot inside a dungeon or raid, every item
-- in the window is saved and sent (a hidden addon message) to the group, or
-- to the guild outside one, and then to the guild, for guildmates who
-- weren't in the group (see Outbox below). Nothing is ever sent on
-- NeedRoll's hidden realm channel, as WoW: Forever's live servers carry no
-- addon messages on custom channels: it is joined only for its member list
-- (see Realm channel below). The finder's Battle.net friends playing WoW:
-- Forever get a copy too (see Battle.net friends below). A copy hearing one
-- saves it and passes it on only in its answer when one of Mike's
-- characters asks (see Catch-up probes), an answer that ends with the names
-- of the players it heard share finds (see Referrals); new finds of the
-- player's own also go to the character that asked last, for a few days
-- (see Push after a pull). Messages leave at most one a minute (whispers to
-- Mike's characters one every 30 seconds, see Whispers) and at most
-- DAILY_MAX a day, to stay well clear of the game's throttling, from an
-- outbox kept in NeedRollDB.dropOutbox, so nothing is lost to a boss
-- fight's addon message lockdown or a /reload.
-- That holds for released builds; a dev build's pull whispers on its own
-- clock (see Catch-up probes).
-- None of it runs until the player says yes, on the first-login notice in
-- UI/Welcome.lua or with Settings' "Share drops" (see ChannelOn). Turned
-- off there, or not answered yet: no channel, and none of this file's
-- messages sent to anyone; what others send is still kept.
-- The version check (Core/Init.lua) isn't part of it and still runs.
-- Drops.isSharingEnabled (see Switch below) turns it off the same way for
-- everyone, whatever they chose.
-- A copy that hears a newer message format than its own stops sending
-- until it is updated (see Outdated below).
--
-- Only new finds are sent (see Known drops below): an item NeedRoll's data
-- already has for that boss is saved but not sent, so the messages carry
-- what's new instead of every kill.
--
-- A boss is an NPC that was a boss unit (boss1 to boss5) during an encounter
-- this session, or one NeedRoll's boss data names. In a dungeon or raid
-- NeedRoll has no data for yet, where the game may start no encounter, it is
-- also a creature of which only one has been seen this run and that is
-- elite, rare or a world boss (see New instances below).
--
-- Each kill is keyed by the corpse's GUID, so several players reporting the
-- same corpse count once and kills can later be counted for drop rates.
-- Saved in NeedRollDB.drops:
--     [instanceID] = { name = "The Deadmines", type = "party" or "raid",
--         bosses = { [npcID] = { name = "Rhahk'Zor", encounter = 1234,
--             kills = { [kill] = { at = <time()>, difficulty = 1, build = 60001,
--                 by = "Name-Realm" (nil when the player looted it, ANON when
--                     the finder didn't ask to be credited),
--                 items = { [itemID] = count },
--                 guessed = { [itemID] = true } (items only guessed, see Guessed drops),
--                 partial = true (heard without the drops the finder's NeedRoll knew,
--                     see Known drops),
--                 viaWhisper = true (taken by whisper, by a dev build's pull: kept
--                     out of probe answers, see Catch-up probes) } } } } }
--
-- Message (prefix "NeedRoll"), one boss kill each (see EncodeKill; wrapped here):
--     D2:<type>:<instanceID>:<difficultyID>:<encounterID>:<npcID>:<kill>:<build>:<itemID>.<count>[g],...
--         \t<npc name>\t<instance name>\t[c]\t[p]\t<sender version>
-- D2 is the format's version. type is d (dungeon) or r (raid); encounterID
-- is 0 when not known; a g after an item's count marks a guessed drop (see
-- Guessed drops below). Copies before v0.13.0 send one item per message,
-- which is still read:
--     D1:<type>:<instanceID>:<difficultyID>:<encounterID>:<npcID>:<kill>:<itemID>:<count>:<build>[:g]
--         \t<npc name>\t<instance name>
--
-- New quests travel the same way (see New quests below): a quest accepted
-- anywhere that Data/KnownQuests.lua doesn't list is saved and sent as a Q1
-- message, so quests new in WoW: Forever can be added to NeedRoll's data.
-- And so do class trainers' spells (see Trainer ranks below): what a class
-- trainer teaches at another level or price than NeedRoll's data says, or
-- that the data doesn't list, read by Core/Trainers.lua and sent as A1
-- messages, ten a day at most, behind every drop and quest message; and the same
-- for profession trainers' recipes and ranks, hunter pet trainers'
-- abilities and the rogue's poisons (see Trainer services below), read by
-- Core/TrainerShare.lua and sent as P1 messages in the same lane. What vendors
-- sell goes the same way (see Vendor messages below): a recipe, or another
-- item only a few vendors sell, that a merchant window offers and NeedRoll
-- doesn't know that vendor sells, read by Core/Vendors.lua and sent as V1
-- (recipes) and S1 (rare stock) messages, a few a day, in a lane of their
-- own beside the trainers' (see Lanes).
local _, ns = ...

local Drops = { available = false }
ns.Drops = Drops

-- Switch -----------------------------------------------------------------------
-- Whether drop sharing runs at all, for everyone. It was off from v1.1.0
-- (November 2026) while WoW: Forever's live servers delivered no addon
-- messages on custom chat channels (NeedRollDropSharing, then NRDT, both
-- worked in the beta), and is on again since 2026-11-08 (Mike). The live
-- servers still refuse addon messages on every custom channel, so drops
-- travel through the group, the guild and Battle.net friends, and the realm
-- channel is joined only for its member list, with nothing sent there (see
-- Realm channel). It stays a switch so sharing can be turned off again in
-- one place. While it is false:
--   * nothing is queued or sent (drops, quests, trainer ranks, vendor
--     stock, probe and roll call answers), and what an earlier session
--     left in the outbox waits there,
--   * the realm channel isn't joined, and is left at login if the player is
--     still in it (see LeaveUnusedChannels),
--   * the first-login consent notice isn't shown (UI/Welcome.lua), and
--     Settings hides Share drops and Credit my finds (UI/Settings.lua),
--   * the dev command that sends (/nr users) says sharing is off instead.
-- The player's own finds are still saved, messages heard in the guild or
-- group from copies that still send are still kept, the version check
-- (Core/Init.lua) still runs, and the player's choices (NeedRollDB.dropChannel
-- and dropCredit) are kept as they set them. Setting it back to true brings
-- it all back; bump DROP_NOTICE_ROUND in UI/Welcome.lua with it, so every
-- account is asked again before anything is sent.
Drops.isSharingEnabled = true

-- Every message goes through ns.AddonMessages (Core/Init.lua), which counts
-- the game's throttled answers for all of NeedRoll's messages together.
local AddonMessages = ns.AddonMessages
local PREFIX = AddonMessages.PREFIX
local DROP_VERSION = "D1"  -- one item per message, still read
local KILL_VERSION = "D2"  -- a whole kill per message, sent since v0.13.0
local QUEST_VERSION = "Q1"
local TRAINER_VERSION = "A1" -- ability (trainer) ranks with the reader's standing and race, since v1.8.0; T1 still read
local VENDOR_RECIPES_VERSION = "V1"
local VENDOR_ITEMS_VERSION = "S1" -- rare vendor stock: a letter of its own, which copies before it ignore
local MESSAGE_MAX = 250    -- bytes; the game allows 255
local SEND_GAP = 60        -- seconds between messages, but Whispers.GAP between two whispers
local OUTBOX_MAX = 500     -- oldest messages are dropped past this; holds a whole whispered answer
local TYPES = { party = "d", raid = "r", world = "w" } -- "world" is never an instance type
local TYPE_NAMES = { d = "party", r = "raid", w = "world" }

-- The sender's NeedRoll version, sent as the last tab field of D2 and Q1
-- messages since v0.14.2 and of every T1, A1, P1, V1 and S1 message ("v0.14.2";
-- "vdev" from a local checkout), so /nr droptalk shows which version a
-- message came from. Older copies stop reading before it.
local versionTag
local function VersionTag()
    if not versionTag then
        local release = (ns.version or ""):match("^v?(%d+%.%d+%.%d+[%w%.%-]*)")
        versionTag = "v" .. (release and release:sub(1, 20) or "dev")
    end
    return versionTag
end

-- The message kinds that end with the sender's version.
local CARRIES_VERSION = { ["D2:"] = true, ["Q1:"] = true, ["T1:"] = true, ["A1:"] = true, ["P1:"] = true,
    ["V1:"] = true, ["S1:"] = true }

-- The version a message's sender ran ("v0.14.2"), or nil when the message
-- carries none (a copy before v0.14.2).
function Drops:SenderVersion(text)
    local kind = type(text) == "string" and text:sub(1, 3)
    if not CARRIES_VERSION[kind] then return nil end
    return text:match("\t(v%d+%.%d+%.%d+[%w%.%-]*)$") or text:match("\t(vdev)$")
end

-- Unit GUIDs and names can be secret in some instance situations (see ns.Plain).
local Plain = ns.Plain

-- The NPC ID and kill key ("<zoneUID>-<spawnUID>", one corpse) of a creature GUID, else nil.
local function CreatureAndKill(guid)
    local unitType, npcID, kill = ns.ParseGUID(guid)
    if not kill or (unitType ~= "Creature" and unitType ~= "Vehicle") then return nil end
    return npcID, kill
end

-- The current dungeon or raid as type letter, instance ID, difficulty ID
-- and name, or nil outside one.
local function CurrentInstance()
    local name, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
    local letter = TYPES[Plain(instanceType)]
    instanceID = Plain(instanceID)
    if not letter or not instanceID or instanceID <= 1 then return nil end
    return letter, instanceID, Plain(difficultyID) or 0, Plain(name)
end

-- Boss NPCs in NeedRoll's data: NPC ID -> name (Bosses.lua: { name, display, level, rank, NPC ID }).
local knownBosses
local function KnownBosses()
    if knownBosses then return knownBosses end
    knownBosses = {}
    for _, encounters in pairs(ns.Data.bosses) do
        for _, list in pairs(encounters) do
            for _, boss in ipairs(list) do
                if boss[5] then knownBosses[boss[5]] = boss[1] end
            end
        end
    end
    for _, category in ipairs({ "DUNGEON", "RAID" }) do
        for _, instance in ipairs(ns.Data:List(category)) do
            for _, encounter in ipairs(instance.encounters) do
                if encounter.npc then knownBosses[encounter.npc] = knownBosses[encounter.npc] or encounter.name end
            end
        end
    end
    return knownBosses
end

local function KnownBoss(npcID)
    return KnownBosses()[npcID]
end

-- Boss units seen in this session's encounters: GUID -> encounter ID, and
-- GUID -> the unit's name.
local bossGUIDs, bossNames = {}, {}
local currentEncounter -- the ID of the encounter in progress (0 when not known), if any
local fightGUIDs = {} -- boss units of the latest encounter

local function NoteBossUnits()
    if not currentEncounter then return end
    for i = 1, 5 do
        local guid = Plain(UnitGUID("boss" .. i))
        if guid then
            bossGUIDs[guid] = currentEncounter
            fightGUIDs[guid] = true
            bossNames[guid] = Plain(UnitName("boss" .. i)) or bossNames[guid]
        end
    end
end

-- The name of the corpse with this GUID: a boss unit seen in the fight, or
-- the target or mouseover (a corpse being looted usually is one of them).
local function NameOf(guid)
    if bossNames[guid] then return bossNames[guid] end
    for _, unit in ipairs({ "target", "mouseover" }) do
        local ok, name = pcall(function()
            if Plain(UnitGUID(unit)) == guid then return Plain(UnitName(unit)) end
        end)
        if ok and name then return name end
    end
end

ns:On("ENCOUNTER_START", function(encounterID)
    currentEncounter = Plain(encounterID) or 0
    fightGUIDs = {}
    NoteBossUnits()
end)
ns:On("INSTANCE_ENCOUNTER_ENGAGE_UNIT", NoteBossUnits)
ns:On("ENCOUNTER_END", function()
    NoteBossUnits()
    currentEncounter = nil
end)

-- New instances ------------------------------------------------------------------
-- WoW: Forever adds dungeons and raids NeedRoll has no loot data for yet
-- (The Barrow Deeps), and the game may start no encounter in them, so no
-- boss unit and no boss NeedRoll knows would mark a kill there. One NeedRoll
-- lists with a boss it has no NPC ID for (a dungeon added from its quests
-- before anyone saw its bosses) counts as unlisted here too, until every
-- boss has one. Inside such an unlisted instance a creature also passes for a
-- boss (a boss candidate) when only one spawn of it has been seen this run
-- and it is elite, rare elite, rare or a world boss, or its kind couldn't be
-- read: bosses stand alone, while trash comes in packs and repeats down the
-- halls. Creatures are told apart by NPC ID, never by name (names come in
-- the player's language and can be secret), and counted as the player meets
-- them: nameplates, target, mouseover, boss units and the corpses in the
-- loot window. A lone elite that isn't a boss can still be taken for one,
-- and its drops are then saved and shared under it.
local BOSS_CLASSIFICATIONS = { elite = true, rareelite = true, rare = true, worldboss = true }
local SEEN_NPCS_MAX = 500 -- kinds of creature counted per run; one met past this is never a boss candidate

-- Whether NeedRoll knows the NPC ID of each of the instance's bosses (its
-- Overview page and Trash Drops aren't a boss). An instance with no bosses
-- listed yet (its Overview alone) knows none of them.
local function KnowsEveryBoss(instance)
    if ns.Data:BossCount(instance) == 0 then return false end
    for _, encounter in ipairs(instance.encounters) do
        if not encounter.npc and ns.Data:IsBoss(encounter) then return false end
    end
    return true
end

-- Whether the player's dungeon or raid is one of NeedRoll's: by the game's
-- map ID, else (the instances new in Forever) by name, when NeedRoll knows
-- each of its bosses by NPC ID.
local function IsListedInstance(where)
    for _, mapID in pairs(ns.Data.instanceMapIDs) do
        if mapID == where.mapID then return true end
    end
    for _, category in ipairs({ "DUNGEON", "RAID" }) do
        for _, instance in ipairs(ns.Data:List(category)) do
            if ns.Data:IsPlayerInside(instance, where) then return KnowsEveryBoss(instance) end
        end
    end
    return false
end

-- The answer for the instance last asked about, by its map ID: nameplates
-- ask often, and the answer can't change while the player stays inside.
local unlistedCheck = {} -- { mapID = <GetInstanceInfo's eighth return>, isUnlisted = true or false }

-- Whether the player is in a dungeon or raid NeedRoll has no data for.
local function InUnlistedInstance()
    local _, instanceID = CurrentInstance()  -- the same map ID PlayerWhereabouts reads
    if not instanceID then return false end
    if unlistedCheck.mapID ~= instanceID then
        unlistedCheck = { mapID = instanceID, isUnlisted = not IsListedInstance(ns.Data:PlayerWhereabouts()) }
    end
    return unlistedCheck.isUnlisted
end

-- The creatures seen in this run of an unlisted instance. A run is told by
-- the zoneUID part of its creatures' GUIDs, the same for all of them and new
-- for each run, so a creature from another zoneUID starts the count again.
-- Per NPC ID: the first spawn key seen, repeats = true once a second spawn
-- of it turns up, and its classification (UnitClassification) once read.
local seenRun = { zone = nil, npcs = {}, count = 0 }

local function NoteCreature(guid, classification)
    local npcID, spawnKey = CreatureAndKill(guid)
    if not npcID then return end
    local zone = spawnKey:match("^(%d+)%-")
    if zone ~= seenRun.zone then seenRun = { zone = zone, npcs = {}, count = 0 } end
    local seen = seenRun.npcs[npcID]
    if not seen then
        if seenRun.count >= SEEN_NPCS_MAX then return end
        seen = { spawn = spawnKey }
        seenRun.npcs[npcID] = seen
        seenRun.count = seenRun.count + 1
    elseif seen.spawn ~= spawnKey then
        seen.repeats = true
    end
    seen.classification = classification or seen.classification
end

-- Counts the creature behind a unit ("target", "boss1", a nameplate's unit).
local function NoteUnit(unit)
    if not InUnlistedInstance() then return end
    NoteCreature(Plain(UnitGUID(unit)), Plain(UnitClassification(unit)))
end

ns:On("NAME_PLATE_UNIT_ADDED", NoteUnit)
ns:On("PLAYER_TARGET_CHANGED", function() NoteUnit("target") end)
ns:On("UPDATE_MOUSEOVER_UNIT", function() NoteUnit("mouseover") end)
ns:On("INSTANCE_ENCOUNTER_ENGAGE_UNIT", function()
    for i = 1, 5 do NoteUnit("boss" .. i) end
end)

-- Whether the NPC passes for a boss in an unlisted instance (see above).
local function IsBossCandidate(npcID)
    if not InUnlistedInstance() then return false end
    local seen = seenRun.npcs[npcID]
    if not seen or seen.repeats then return false end
    return seen.classification == nil or BOSS_CLASSIFICATIONS[seen.classification] == true
end

-- Kills kept per boss: the oldest go past this, so other players' drops
-- heard in the guild or group can't grow the saved file without end. Local
-- checkouts keep everything (Drops.keepAll, see the debug block), so the
-- drops can be folded into NeedRoll's data.
local KILLS_MAX = 50

-- Removes the oldest entry (by `at`) when `entries` holds more than `max`;
-- callers save one entry, or one loot window, at a time.
local function DropOldest(entries, max)
    local count, oldestKey, oldestAt = 0, nil, math.huge
    for key, entry in pairs(entries) do
        count = count + 1
        if (entry.at or 0) < oldestAt then oldestKey, oldestAt = key, entry.at or 0 end
    end
    if count > max and oldestKey then entries[oldestKey] = nil end
end

-- Bosses kept across all instances: instance and NPC IDs in a heard kill
-- can be any number, so without this one sender could add boss entries
-- without end. Well above the dungeon and raid bosses Data/Bosses.lua
-- lists, with room for open world finds. Like KILLS_MAX, local checkouts
-- keep everything.
local BOSSES_MAX = 1000

-- The time of the boss's newest saved kill (0 when it has none).
local function NewestKillAt(boss)
    local newest = 0
    for _, kill in pairs(boss.kills) do newest = math.max(newest, kill.at or 0) end
    return newest
end

-- Whether every saved kill of the boss was heard from another player (the
-- player's own finds have no `by`).
local function HeardOnly(boss)
    for _, kill in pairs(boss.kills) do
        if not kill.by then return false end
    end
    return true
end

-- Called before a new boss is saved. While BOSSES_MAX or more are saved,
-- removes bosses heard from others, the one whose newest kill is oldest
-- first, and an instance once it has no boss left; a file saved above the
-- cap is trimmed back the same way. The player's own finds are never
-- removed: a flood of made-up bosses can only push out other heard ones.
-- Returns whether there is room for one more.
local function MakeRoomForBoss()
    local count = 0
    for _, instance in pairs(ns.db.drops) do count = count + ns.CountKeys(instance.bosses) end
    if count < BOSSES_MAX then return true end
    local heardBosses = {}
    for instanceID, instance in pairs(ns.db.drops) do
        for npcID, boss in pairs(instance.bosses) do
            if HeardOnly(boss) then
                heardBosses[#heardBosses + 1] = { instance = instanceID, npc = npcID, newest = NewestKillAt(boss) }
            end
        end
    end
    table.sort(heardBosses, function(a, b) return a.newest < b.newest end)
    local removed = math.min(count - BOSSES_MAX + 1, #heardBosses)
    for i = 1, removed do
        local stale = heardBosses[i]
        local instance = ns.db.drops[stale.instance]
        instance.bosses[stale.npc] = nil
        if not next(instance.bosses) then ns.db.drops[stale.instance] = nil end
    end
    return count - removed < BOSSES_MAX
end

-- Saves one item of one kill; true when it wasn't known yet.
local function Save(drop)
    local instance = ns.db.drops[drop.instance]
    if not (instance and instance.bosses[drop.npc]) and not Drops.keepAll then
        -- Full of the player's own finds: a heard boss isn't kept.
        if not MakeRoomForBoss() and drop.by then return false end
        instance = ns.db.drops[drop.instance] -- gone when its only boss was the one removed
    end
    if not instance then
        instance = { bosses = {} }
        ns.db.drops[drop.instance] = instance
    end
    instance.name = instance.name or drop.instanceName
    instance.type = TYPE_NAMES[drop.type]
    local boss = instance.bosses[drop.npc]
    if not boss then
        boss = { kills = {} }
        instance.bosses[drop.npc] = boss
    end
    boss.name = boss.name or drop.npcName
    if drop.encounter and drop.encounter > 0 then boss.encounter = drop.encounter end
    local kill = boss.kills[drop.kill]
    if not kill then
        kill = { at = time(), difficulty = drop.difficulty, build = drop.build, by = drop.by, items = {},
            partial = drop.partial, viaWhisper = drop.viaWhisper }
        boss.kills[drop.kill] = kill
        if not Drops.keepAll then DropOldest(boss.kills, KILLS_MAX) end
    elseif not drop.partial then
        -- The player's own loot, or a copy that sent the whole kill.
        kill.partial = nil
    end
    local savedCount = kill.items[drop.item]
    local wasGuess = kill.guessed and kill.guessed[drop.item]
    -- A sure report of an item only guessed so far is news; a guess about
    -- an item already seen isn't.
    if savedCount and savedCount >= drop.count and not (wasGuess and not drop.guessed) then return false end
    kill.items[drop.item] = math.max(savedCount or 0, drop.count)
    if drop.guessed and not savedCount then
        kill.guessed = kill.guessed or {}
        kill.guessed[drop.item] = true
    elseif wasGuess and not drop.guessed then
        kill.guessed[drop.item] = nil
        if not next(kill.guessed) then kill.guessed = nil end
    end
    if Drops.NoteItem then Drops.NoteItem(drop.item) end
    return true
end

-- Credit -------------------------------------------------------------------
-- A finder who ticks "Credit my finds" (the first-login notice, Settings)
-- sends a trailing "c" field with each kill. Copies hearing a kill without
-- it, or a quest, keep the sender as ANON instead of their name, so finds
-- are stored anonymously unless credit was asked for (Mike, 2026-10-15).
-- Credited names go in the credits file the scraper's ingest writes.
local ANON = "?"
Drops.ANON = ANON

function Drops:CreditOn()
    return ns.db ~= nil and ns.db.dropCredit ~= false
end

-- Message text -------------------------------------------------------------

-- Packs `fields` into as few messages as fit MESSAGE_MAX, each `head`, then
-- fields joined by commas, then `tail`: { { text = ..., first = <the index
-- of its first field>, last = <of its last> }, ... }.
local function PackFields(head, fields, tail)
    local messages, first = {}, 1
    local function Pack(last)
        messages[#messages + 1] = { text = head .. table.concat(fields, ",", first, last) .. tail, first = first,
            last = last }
    end
    local size = #head + #tail
    for index, field in ipairs(fields) do
        if index > first and size + 1 + #field > MESSAGE_MAX then
            Pack(index - 1)
            first, size = index, #head + #tail
        end
        size = size + #field + (index > first and 1 or 0)
    end
    if #fields >= first then Pack(#fields) end
    return messages
end

-- A whole kill in one message:
--     D2:type:instance:difficulty:encounter:npc:kill:build:items\tnpcName\tinstanceName\t[c]\t[p]\tversion
-- items is "itemID.count" per item, comma separated, with a trailing "g"
-- for a guessed one ("1156.1,5191.2g"). A kill with more items than fit in
-- MESSAGE_MAX bytes goes out as several messages. A "c" field asks for the
-- finder to be credited (see Credit); a "p" field after it (empty when no
-- credit is asked) says the kill was sent without the drops NeedRoll
-- already knew (see Known drops). The sender's version comes last (see
-- VersionTag). Copies before v0.14.0 read neither "p" nor anything after
-- it. kill.isRelayed marks a kill heard from another player, passed on in
-- a probe's answer: it never asks for credit (see Catch-up probes). Returns
-- the texts.
local function EncodeKill(kill, items, partial)
    -- Names must not carry the tab that separates them.
    local npcName = (kill.npcName or ""):gsub("\t", " ")
    local instanceName = (kill.instanceName or ""):gsub("\t", " ")
    local head = table.concat({ KILL_VERSION, kill.type, kill.instance, kill.difficulty, kill.encounter or 0, kill.npc,
        kill.kill, kill.build or 0 }, ":") .. ":"
    local credit = (Drops:CreditOn() and not kill.isRelayed) and "c" or ""
    local tail = "\t" .. npcName .. "\t" .. instanceName .. "\t" .. credit .. "\t" .. (partial and "p" or "")
        .. "\t" .. VersionTag()
    local fields = {}
    for _, item in ipairs(items) do
        fields[#fields + 1] = item.item .. "." .. item.count .. (item.guessed and "g" or "")
    end
    local texts = {}
    for _, message in ipairs(PackFields(head, fields, tail)) do texts[#texts + 1] = message.text end
    return texts
end

-- A heard message's colon-separated fields (empty ones skipped), then four tab
-- fields ("" when missing). Other players wrote it, so readers check each field.
local function SplitMessage(text)
    local head, tab1, tab2, tab3, tab4 = text:match("^([^\t]*)\t?([^\t]*)\t?([^\t]*)\t?([^\t]*)\t?([^\t]*)")
    local fields = {}
    for field in head:gmatch("[^:]+") do fields[#fields + 1] = field end
    return fields, tab1, tab2, tab3, tab4
end

-- A heard message's number field: plain digits only (see ns.HeardNumber in Core/Init.lua).
local HeardNumber = ns.HeardNumber

local function NilIfEmpty(text)
    return text ~= "" and text or nil
end

-- A kill key is "<zone>-<spawn>" (CreatureAndKill) or a guess's "0-<hex>".
local function IsKillKey(kill)
    return kill:match("^%d+%-%x+$") ~= nil
end

-- A D2 message's drops, one per item, and its heard key; nil if any part is bad.
local function DecodeKill(text)
    local fields, npcName, instanceName, credit, partial = SplitMessage(text)
    if fields[1] ~= KILL_VERSION or not TYPE_NAMES[fields[2]] or #fields < 9 then return nil end
    local kill = {
        type = fields[2], instance = HeardNumber(fields[3]), difficulty = HeardNumber(fields[4]),
        encounter = HeardNumber(fields[5]), npc = HeardNumber(fields[6]), kill = fields[7],
        build = HeardNumber(fields[8]),
        npcName = NilIfEmpty(npcName), instanceName = NilIfEmpty(instanceName),
        credit = credit == "c" or nil, partial = partial == "p" or nil,
    }
    if not (kill.instance and kill.instance > 1 and kill.npc and IsKillKey(kill.kill)) then return nil end
    local drops = {}
    for field in fields[9]:gmatch("[^,]+") do
        local itemID, count, guessMark = field:match("^(%d+)%.(%d+)(g?)$")
        itemID, count = HeardNumber(itemID), HeardNumber(count)
        if not (itemID and count and count > 0) then return nil end
        local drop = { item = itemID, count = count, guessed = guessMark == "g" or nil }
        for key, value in pairs(kill) do drop[key] = value end
        drops[#drops + 1] = drop
    end
    return #drops > 0 and drops or nil, fields[7] .. ":" .. fields[9]
end

local function Decode(text)
    local fields, npcName, instanceName = SplitMessage(text)
    if fields[1] ~= DROP_VERSION or not TYPE_NAMES[fields[2]] or #fields < 10 then return nil end
    local drop = {
        type = fields[2], instance = HeardNumber(fields[3]), difficulty = HeardNumber(fields[4]),
        encounter = HeardNumber(fields[5]), npc = HeardNumber(fields[6]), kill = fields[7],
        item = HeardNumber(fields[8]), count = HeardNumber(fields[9]), build = HeardNumber(fields[10]),
        npcName = NilIfEmpty(npcName), instanceName = NilIfEmpty(instanceName), guessed = fields[11] == "g" or nil,
    }
    if not (drop.instance and drop.instance > 1 and drop.npc and drop.item and drop.count and drop.count > 0
        and IsKillKey(drop.kill)) then
        return nil
    end
    return drop
end

-- Realm channel ---------------------------------------------------------------
-- A hidden custom chat channel, NRDropTalk (Mike's name), that every copy
-- with drop sharing on joins (see ChannelOn), only for its member list:
-- nothing is ever sent on it. WoW: Forever's live servers refuse addon
-- messages on every custom channel (November 2026), so finds go to the
-- group, the guild and Battle.net friends instead (see Outbox). The member
-- list names the players who share drops: a dev build's pull
-- (Core/DropPull.lua) reads it to ask them for their finds by whisper (see
-- Catch-up probes), and /nr users counts them. Custom channels are per
-- realm, and likely per faction. The channel is kept out of every chat
-- window and its chat lines are filtered out.
-- Until v1.0.2 it was NeedRollDropSharing, which the live servers turned
-- off soon after launch: they drop every join to it without a word, even
-- one typed by hand, and the game lists it as disabled. NRDT ("NeedRoll
-- drop talk") came next: the servers let players join it but refused every
-- addon message on it, and since 2026-11-12 they answer every join with
-- NOT_ALLOWED_IN_CHANNEL and give no member list for it. A fresh custom
-- channel still gave its member list (Mike's test, 2026-11-09), so on
-- 2026-11-12 Mike chose NRDropTalk, knowingly going back on his rule of
-- 2026-11-06 never to move on to another name, which could look like
-- getting around a block: no copy sends anything on the new one. Older
-- copies still join NRDT and send there, refused as before.
local CHANNEL = "NRDropTalk"
-- NRDT, the realm channel of the copies before NRDropTalk. Releases leave
-- it. A dev build whose pull runs (Drops.ReadsOlderChannel, set by
-- Core/DropPull.lua) sits in it too, only for its member list, so the pull
-- can ask those older copies for their finds as well (Mike, 2026-11-16).
-- It is joined, hidden, numbered and left the same way as the realm channel.
local OLDER_CHANNEL = "NRDT"
-- Names copies used before, left on login: the dev test's, the one the
-- servers turned off, and NRDT (unless this copy reads its member list),
-- so they don't keep one of the player's ten channel slots.
local OLD_CHANNELS = { "nrdt7kq2x", "NeedRollDropSharing", OLDER_CHANNEL }
-- The channels this copy sits in for their member lists (see
-- MemberListChannels); kept as tables, as chat filters ask for them on
-- every channel's chat line.
local REALM_CHANNEL_ONLY, REALM_AND_OLDER_CHANNELS = { CHANNEL }, { CHANNEL, OLDER_CHANNEL }

-- Whether drop sharing is on: switched on for everyone (see Switch), and
-- the player said yes in this round of asking (UI/Welcome.lua), with the
-- first-login notice's Share drops or by turning Settings' "Share drops"
-- on. Both save NeedRollDB.dropChannel = true; nil means not answered yet
-- and false turned off. Off or not answered, none of drop sharing's
-- messages are sent and the realm channel isn't joined.
function Drops:ChannelOn()
    return Drops.isSharingEnabled and ns.db ~= nil and ns.db.dropChannel == true
end

-- The channels this copy sits in while drop sharing is on: the realm
-- channel, and NRDT too while a dev build's pull reads its member list.
local function MemberListChannels()
    if Drops.ReadsOlderChannel and Drops.ReadsOlderChannel() then return REALM_AND_OLDER_CHANNELS end
    return REALM_CHANNEL_ONLY
end

-- A channel's chat number, or nil when not in it.
local function JoinedNumber(channel)
    local number = GetChannelName(channel)
    if number and number > 0 then return number end
end

-- The realm channel's number, or nil when not in it.
function Drops:ChannelID()
    return JoinedNumber(CHANNEL)
end

-- The channel of MemberListChannels that a channel name ("NRDropTalk", or
-- "5. NRDropTalk" as chat events number it) names, or nil.
local function OurChannel(name)
    name = Plain(name)
    if type(name) ~= "string" then return nil end
    local baseName = name:lower():gsub("^%d+%.%s*", "")
    for _, channel in ipairs(MemberListChannels()) do
        if baseName == channel:lower() then return channel end
    end
end

-- Takes the channels out of every chat window; the player stays in them.
local function HideChannels()
    for _, channel in ipairs(MemberListChannels()) do
        for i = 1, (NUM_CHAT_WINDOWS or 10) do
            local chatFrame = _G["ChatFrame" .. i]
            if chatFrame and chatFrame.RemoveChannel then
                pcall(chatFrame.RemoveChannel, chatFrame, channel)
            else
                pcall(RemoveChatWindowChannel, i, channel)
            end
        end
    end
end

-- Chat number ------------------------------------------------------------------
-- Every channel the player is in has a chat number (/1 General, /2 Trade,
-- ...), which players type to talk in it. The game rejoins the last
-- session's custom channels as the player logs in, and on WoW: Forever's live
-- realms the realm channel came back as /1, ahead of General, however late
-- NeedRoll's own join. So whenever NeedRoll finds itself in the channel
-- (after its own join, every 10 minutes, after loading screens and when the
-- game's channel list changes) and another joined channel has a higher
-- number, it moves the realm channel behind them all, the way dragging a
-- channel down in the game's Chat Channels settings does: it swaps places
-- with each joined channel numbered after it in turn, so the others keep
-- their order, each taking the next number down that a channel had:
-- "1. NRDropTalk, 2. General, 3. Trade, 6. Guildies" becomes "1. General,
-- 2. Trade, 3. Guildies, 6. NRDropTalk". Numbers no channel has stay free,
-- so a channel past one can drop by more than one number. The API docs give
-- the swap no combat restrictions. The game's settings also swap the two
-- numbers' entries in ChatTypeInfo (their chat colours); NeedRoll leaves
-- that table alone, as an addon writing to it taints the chat frames, so a
-- player who gave channels colours of their own may see a moved channel in
-- another's colour.
-- A dev build sitting in NRDT too moves each of the two behind every channel
-- that isn't NeedRoll's, so they end up last, side by side, and never trade
-- places with each other.
-- Another addon moving its own channel last would keep trading places with
-- this one, so the channel moves at most ChatNumber.MOVES_MAX times a session.
-- Its numbers and state share one table: this file's main chunk is close to
-- Lua 5.1's limit of 200 locals.
local ChatNumber = {
    MOVES_MAX = 5,
    CHECK_WAIT = 2, -- seconds from a change to the game's channel list to the check
    moves = 0,      -- this session
    isCheckWaiting = false,
}

-- The numbers of the joined channels, other than NeedRoll's own, numbered
-- after `channelNumber`, lowest first. GetChannelList gives three values a
-- channel: its number, name and whether it's disabled.
function ChatNumber.NumbersAfter(channelNumber)
    local list = { GetChannelList() }
    local numbers = {}
    for i = 1, #list, 3 do
        if list[i] > channelNumber and not OurChannel(list[i + 1]) then numbers[#numbers + 1] = list[i] end
    end
    table.sort(numbers)
    return numbers
end

-- Moves `channel` behind every joined channel that isn't NeedRoll's (see
-- Chat number); does nothing when it already is.
function ChatNumber.MoveLast(channel)
    local fromNumber = JoinedNumber(channel)
    if not fromNumber or ChatNumber.moves >= ChatNumber.MOVES_MAX then return end
    local laterNumbers = ChatNumber.NumbersAfter(fromNumber)
    if #laterNumbers == 0 then return end
    ChatNumber.moves = ChatNumber.moves + 1
    local movedNumber = fromNumber
    for _, laterNumber in ipairs(laterNumbers) do
        if not pcall(C_ChatInfo.SwapChatChannelsByChannelIndex, movedNumber, laterNumber) then break end
        movedNumber = laterNumber
    end
    if not Drops.Log then return end
    local stopped = movedNumber ~= laterNumbers[#laterNumbers] and " (a swap failed)" or ""
    Drops.Log("out", "CHANNEL", nil, channel, ("moved from /%d to /%d%s"):format(fromNumber, movedNumber, stopped))
end

-- Moves each channel this copy sits in behind the other joined channels,
-- while drop sharing is on.
function ChatNumber.MoveChannelsLast()
    if not Drops:ChannelOn() then return end
    for _, channel in ipairs(MemberListChannels()) do ChatNumber.MoveLast(channel) end
end

-- Joining ------------------------------------------------------------------------
-- A channel that asks for a password (another player owns it and set one)
-- is left, so the game doesn't keep asking, and not joined again this
-- session: { [channel] = true }.
local passwordAskedChannels = {}

-- Leaves the channel names copies used before, but NRDT while this copy
-- reads its member list (see MemberListChannels), and, while drop sharing
-- is off (switched off for everyone, turned off or not answered yet), the
-- channels it sits in too, which gives back the chat numbers they took. The
-- game rejoins last session's channels at login, which would leave the
-- player in them, often as /1.
local function LeaveUnusedChannels()
    local isSharing = Drops:ChannelOn()
    for _, old in ipairs(OLD_CHANNELS) do
        local isInUse = isSharing and OurChannel(old)
        if not isInUse and JoinedNumber(old) then pcall(LeaveChannelByName, old) end
    end
    if not isSharing and Drops:ChannelID() then pcall(LeaveChannelByName, CHANNEL) end
end

-- Joins each channel of MemberListChannels this copy isn't in, while drop
-- sharing is on, unless it asked for a password this session; five seconds
-- later logs how each join went and moves the channels last (see Chat
-- number). Whether it tried a join.
local function JoinChannels()
    LeaveUnusedChannels()
    if not Drops:ChannelOn() then return false end
    local joinResults = {}
    for _, channel in ipairs(MemberListChannels()) do
        if not (JoinedNumber(channel) or passwordAskedChannels[channel]) then
            joinResults[channel] = pcall(JoinTemporaryChannel, channel)
        end
    end
    if not next(joinResults) then return false end
    C_Timer.After(1, HideChannels)
    C_Timer.After(5, function()
        for channel, ok in pairs(joinResults) do
            if Drops.Log then
                local outcome = JoinedNumber(channel) and "joined" or (ok and "join failed" or "join error")
                Drops.Log("out", "CHANNEL", nil, channel, outcome)
            end
        end
        ChatNumber.MoveChannelsLast()
    end)
    return true
end

-- Joins again whenever the player isn't in a channel: the first try can
-- fail (the game's channels still connecting, a loading screen, all ten
-- channel slots taken), and nothing else would try again until the next
-- login. Checked every 10 minutes and after every loading screen (login and
-- /reload included), once the first try has been made, along with whether
-- the channels have the last chat numbers (see Chat number).
local keepJoined = false

local function KeepJoined()
    if not (keepJoined and Drops:ChannelOn()) then return end
    if not JoinChannels() then ChatNumber.MoveChannelsLast() end
end

ns:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(5, KeepJoined) end)

-- The game's channel list changed (a channel joined, left or moved, the
-- realm channel's own move included): the chat numbers are checked once,
-- ChatNumber.CHECK_WAIT seconds after the first change, as the game often
-- makes a few in a row.
ns:On("CHANNEL_UI_UPDATE", function()
    if not keepJoined or ChatNumber.isCheckWaiting then return end
    ChatNumber.isCheckWaiting = true
    C_Timer.After(ChatNumber.CHECK_WAIT, function()
        ChatNumber.isCheckWaiting = false
        ChatNumber.MoveChannelsLast()
    end)
end)

-- The player's answer, from Settings' Share drops or the first-login
-- notice (see Welcome:AnswerDropSharing in UI/Welcome.lua): joins the
-- channels, or leaves them and drops what was still waiting to be sent. A
-- player the game already put back in a channel at login is moved behind
-- the other channels at once (see Chat number), as JoinChannels leaves a
-- channel already joined alone.
function Drops:SetChannel(on)
    ns.db.dropChannel = on
    if on then
        JoinChannels()
        ChatNumber.MoveChannelsLast()
    else
        wipe(ns.db.dropOutbox)
        -- The players heard sharing, kept only to name them to Mike's
        -- characters (see Referrals).
        ns.db.dropSharers = nil
        LeaveUnusedChannels()
    end
end

-- Notices and chat lines about the channels never reach the chat windows. A
-- chat filter gets the chat frame and the event, then the event's
-- arguments: channelName is the 4th of those, channelBaseName the 9th.
-- They stay hidden with sharing off too, so leaving the channel (Settings,
-- or the switch above) prints no "Left Channel" line.
local function IsHiddenChatLine(_, _, _, _, _, channelName, _, _, _, _, baseName)
    return (OurChannel(baseName) or OurChannel(channelName)) ~= nil
end
for _, event in ipairs({ "CHAT_MSG_CHANNEL", "CHAT_MSG_CHANNEL_NOTICE", "CHAT_MSG_CHANNEL_NOTICE_USER",
    "CHAT_MSG_CHANNEL_JOIN", "CHAT_MSG_CHANNEL_LEAVE" }) do
    ChatFrameUtil.AddMessageEventFilter(event, IsHiddenChatLine)
end

-- A notice about a channel this copy sits in (joined,
-- NOT_ALLOWED_IN_CHANNEL, ...) can put it back in a chat window, so it's
-- hidden again. The dev drop talk log keeps the notice's kind, never the
-- names it may carry.
ns:On("CHAT_MSG_CHANNEL_NOTICE", function(noticeType, _, _, channelName, _, _, _, _, baseName)
    local channel = OurChannel(baseName) or OurChannel(channelName)
    if not (channel and Drops:ChannelOn()) then return end
    if Drops.Log then Drops.Log("in", "CHANNEL", nil, channel, "notice " .. tostring(Plain(noticeType))) end
    C_Timer.After(0.5, HideChannels)
end)

ns:On("CHANNEL_PASSWORD_REQUEST", function(channelName)
    local channel = OurChannel(channelName)
    if not channel then return end
    passwordAskedChannels[channel] = true
    pcall(LeaveChannelByName, channel)
end)

-- Outbox ---------------------------------------------------------------------
-- Entries are { text, to = "GROUP_OR_GUILD", "CHANNEL", "GUILD", "WHISPER"
-- or "BNET", target = <player> for WHISPER, friendSlot and friendTurn for
-- BNET (see Battle.net friends), id = <key>, relay, lane = "trainer" or
-- "vendor" for an A1, P1, V1 or S1 message (see Lanes) }.
-- GROUP_OR_GUILD goes to the group the player is in as it leaves, else to
-- the guild (see GroupOrGuild). A find is queued for it and for the guild,
-- so it reaches both, or the guild once outside a group.
-- CHANNEL is only in outboxes saved by releases before NRDropTalk (see
-- Realm channel); such an entry is sent as GROUP_OR_GUILD. Those outboxes
-- can hold GROUP ones too, which go to whichever group chat fits, or are
-- dropped outside a group.
-- A message heard on (or sent to) the group or guild this session isn't
-- sent there again: heard[GROUP or GUILD][id]. Whispers and Battle.net
-- friends have no heard list.
local heard = { GUILD = {}, GROUP = {} }
-- The heard list each CHAT_MSG_ADDON chat type fills; whispers are read
-- apart (see Whispers.Read).
local HEARD_LIST = { GUILD = "GUILD", PARTY = "GROUP", RAID = "GROUP", INSTANCE_CHAT = "GROUP" }

-- Whispers: NeedRoll whispers only a PROBERS character: the answer to a probe
-- that character whispered (see Catch-up probes), and for Push.DAYS days
-- after it the player's own new finds (see Push after a pull). The outbox is
-- saved with the player's settings and the target is one of Mike's
-- characters, whose name shouldn't sit in players' saved files longer than a
-- push needs it, so whisper entries never outlive the session: they are
-- taken out of the outbox as the game saves it (PLAYER_LOGOUT, which a
-- /reload fires too), and answers and pushes still waiting then are dropped
-- (the next probe's answer carries those finds). sentAt holds, for this
-- session only, GetTime() of the last whisper to each player (by lower-case
-- name), so the game's line saying one isn't online can be told apart (see
-- Offline target).
-- A whisper goes GAP seconds after a whisper sent just before it, so a
-- prober gets a long answer twice as fast; every other message still waits
-- SEND_GAP after the one before (Mike, 2026-11-11).
local Whispers = {
    BOUNCE_WAIT = 60, -- seconds after a whisper in which the game's "not online" line is about it
    GAP = 30,         -- seconds between two whispers in a row
    wasLastSent = false, -- the outbox's last message sent was a whisper
    sentAt = {},
    notFoundPatterns = nil, -- ERR_CHAT_PLAYER_NOT_FOUND_S as Lua patterns, made on first use
}

-- Notes a whisper NeedRoll sends `target` now.
function Whispers.Note(target)
    Whispers.sentAt[target:lower()] = GetTime()
end

-- Whether NeedRoll whispered `name` within BOUNCE_WAIT seconds.
function Whispers.IsRecent(name)
    local sentAt = Whispers.sentAt[name:lower()]
    return sentAt ~= nil and GetTime() - sentAt < Whispers.BOUNCE_WAIT
end

-- Takes the whisper entries out of the outbox: those to `name`, or all of
-- them when no name is given.
function Whispers.Unqueue(name)
    local outbox = ns.db.dropOutbox
    for i = #outbox, 1, -1 do
        local entry = outbox[i]
        if entry.to == "WHISPER" and (not name or entry.target:lower() == name:lower()) then
            table.remove(outbox, i)
        end
    end
end

-- Push after a pull ------------------------------------------------------------
-- A copy that answers a PROBERS character's whispered probe (see Catch-up
-- probes) remembers that character for Push.DAYS days. Meanwhile each new
-- find of the player's own (a D2 kill, a Q1 quest, an A1 or P1 trainer
-- message, a V1 or S1 vendor message) is also whispered to them: one more
-- outbox entry, like the probe's answers, so it leaves at the outbox's pace
-- and counts towards DAILY_MAX. A lane message's push isn't in its lane
-- (see Lanes): it waits in front of the lanes' messages and doesn't count
-- towards the lane's daily messages.
-- Finds heard from other players aren't pushed: the next probe's answer
-- carries them. A probe answered for another PROBERS character moves the
-- push to them. The first whisper to the character that bounces (see Offline
-- target) ends the push and drops the whispers still queued to them, until
-- a probe starts it again. So no copy ever whispers anyone but a PROBERS
-- character that asked within Push.DAYS days, until a whisper to them
-- bounces (Mike, 2026-11-12). With Share drops off nothing is queued (see
-- Queue). Saved in NeedRollDB.dropPush = { to = <the character's name as
-- their probe came>, since = <time() of the probe> }; it is forgotten as the
-- game saves once the push has ended, so the name stays in the player's
-- saved file little longer than the push lasts.
local Push = {
    DAYS = 3,
}

-- The PROBERS character the player's new finds are whispered to now, or nil
-- when none asked within Push.DAYS days, a whisper to them bounced since, or
-- the saved name isn't in PROBERS (any more).
function Push.Target()
    local push = ns.db.dropPush
    if type(push) ~= "table" or type(push.to) ~= "string" or type(push.since) ~= "number" then return nil end
    -- A probe time ahead of the clock (the clock was set back since) ends
    -- the push, so a wrong clock can't stretch it past Push.DAYS days.
    local age = time() - push.since
    if age < 0 or age >= Push.DAYS * 24 * 3600 then return nil end
    if not Drops.IsProber(push.to) then return nil end
    return push.to
end

-- Starts the push to `prober`, whose probe this copy just answered.
function Push.Start(prober)
    ns.db.dropPush = { to = prober, since = time() }
end

-- A whisper to `name` bounced: when the push goes to them, it ends.
function Push.EndIfTo(name)
    local target = Push.Target()
    if target and target:lower() == name:lower() then ns.db.dropPush = nil end
end

ns:On("PLAYER_LOGOUT", function()
    if not ns.db then return end
    Whispers.Unqueue()
    if not Push.Target() then ns.db.dropPush = nil end
end)

-- Offline target: a whisper to a player who has logged off (or who plays
-- on realms of another ruleset, PvE or PvP, which whispers don't reach)
-- makes the game print "No player named '<name>' is currently playing." to
-- the sender. When that line names a player NeedRoll whispered within
-- BOUNCE_WAIT seconds, it is hidden, every whisper still queued to them is
-- dropped and a push to them ends (see Push after a pull). The line about
-- anyone else, after the player's own whispers, shows as usual. It is
-- matched with the game's text in the player's language
-- (ERR_CHAT_PLAYER_NOT_FOUND_S), never with English.

-- The name in a system line saying a player isn't online, when it is one
-- NeedRoll whispered within BOUNCE_WAIT seconds; else nil.
function Whispers.BouncedName(message)
    message = Plain(message)
    if type(message) ~= "string" or type(ERR_CHAT_PLAYER_NOT_FOUND_S) ~= "string" then return nil end
    Whispers.notFoundPatterns = Whispers.notFoundPatterns or ns.GameTextPatterns(ERR_CHAT_PLAYER_NOT_FOUND_S)
    -- Korean has two patterns, and a name can fit both: the recent whisper says which.
    for _, pattern in ipairs(Whispers.notFoundPatterns) do
        local name = message:match(pattern)
        if name and Whispers.IsRecent(name) then return name end
    end
end

ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_SYSTEM", function(_, _, message)
    return Whispers.BouncedName(message) ~= nil
end)

-- A dev build's pull (Core/DropPull.lua) learns from Drops.OnWhisperBounce
-- which of its whispers bounced.
ns:On("CHAT_MSG_SYSTEM", function(message)
    local name = Whispers.BouncedName(message)
    if not name then return end
    if ns.db then
        Whispers.Unqueue(name)
        Push.EndIfTo(name)
    end
    if Drops.OnWhisperBounce then Drops.OnWhisperBounce(name) end
end)

local function GroupChat()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
end

-- Where a GROUP_OR_GUILD entry goes now: the group when in one, else the
-- guild, else nowhere.
local function GroupOrGuild()
    if GroupChat() then return "GROUP" end
    if IsInGuild() then return "GUILD" end
end

-- Lockdowns, the game's answers and throttling are handled by
-- ns.AddonMessages (Core/Init.lua), shared with the version check. An
-- answer that says "later" puts the entry back at the front of the outbox
-- for RETRY seconds.
local RETRY = AddonMessages.RETRY
local THROTTLE_PAUSE = AddonMessages.THROTTLE_PAUSE
local DAILY_MAX = 1500      -- messages a day; the rest wait for the next day (Mike, 2026-11-11)

local isSending = false -- a Pump is waiting on its timer
local lastSentAt        -- GetTime() of the outbox's last message sent

-- Seconds the outbox still waits before it may send `entry`: Whispers.GAP
-- after the last message sent when both are whispers, else SEND_GAP. Zero
-- or less when it may go now.
local function WaitBeforeSending(entry)
    if not lastSentAt then return 0 end
    local gap = (Whispers.wasLastSent and entry.to == "WHISPER") and Whispers.GAP or SEND_GAP
    return gap - (GetTime() - lastSentAt)
end

-- Lanes: trainer ranks and services (A1, P1) and vendor stock (V1 recipes and S1 rare items)
-- can come many at once, after a single trainer or vendor visit, so they
-- queue behind every drop and quest message, each in its own lane (both
-- vendor kinds share one, recipes queued first): at most `daily` of a
-- lane's messages wait at a time (Battle.net friends' copies not counted)
-- and at most `daily` leave a day (those copies counted), so a long list
-- can't crowd out drops. A lane's messages go `to` the chat named, and to
-- Battle.net friends too when `toFriends` says so. The day's count of each
-- lane is NeedRollDB.dropSent[lane]. Outboxes saved before lanes mark a T1
-- entry trainer = true instead of lane = "trainer". The vendor lane's ten
-- leave room for a visit's recipes and its rare stock (a message of each)
-- at a few vendors a day, still one minute apart like everything else; the
-- trainer lane's ten let the A1 and P1 messages of a few trainer visits
-- leave the same day, to the guild and to friends outside it.
local LANES = {
    trainer = { daily = 10, to = "GROUP_OR_GUILD", toFriends = true },
    vendor = { daily = 10, to = "GROUP_OR_GUILD", toFriends = true },
}

-- The lane an outbox entry queues in, or nil for one in none.
local function LaneOf(entry)
    return entry.lane or (entry.trainer and "trainer") or nil
end

-- Whether another of lane `lane`'s messages may leave today (see Lanes).
function Drops.RoomToday(lane)
    local sent = ns.db.dropSent
    if type(sent) ~= "table" or sent.day ~= date("%Y-%m-%d") then return true end
    return (sent[lane] or 0) < LANES[lane].daily
end

-- The outbox position of the next message that may leave: the first one,
-- or past it the first whose lane has room today (lanes queue behind every
-- other message, so only lane messages are skipped). Nil when none may.
local function NextSendable(outbox)
    for index, entry in ipairs(outbox) do
        local lane = LaneOf(entry)
        if not lane or Drops.RoomToday(lane) then return index end
    end
end

-- Outdated: message kinds are a letter and a format number (D1, Q1, R1, T1, A1, P1, V1, S1, N1).
-- Hearing one of our letters with a higher number means a newer release
-- talks in a format this copy doesn't write, so it stops sending (its
-- messages would be in the old format) and stays quiet, across sessions,
-- until the addon's version changes. It takes NEWER_SENDERS different
-- players, so one player sending made-up messages can't silence everyone.
-- The outbox is kept for the update. NeedRollDB.dropNewer = { version =
-- this copy's version, senders = { [name] = true } }. A letter this copy
-- doesn't list is ignored, so copies before v1.8.0, which don't list N,
-- read nothing into an N1 (see Referrals).
local FORMATS = { D = 2, Q = 1, R = 1, T = 1, A = 1, P = 1, V = 1, S = 1, N = 1 }
local NEWER_SENDERS = 3

local function Outdated()
    local newer = ns.db.dropNewer
    if type(newer) ~= "table" or newer.version ~= ns.version then return false end
    return ns.CountKeys(newer.senders) >= NEWER_SENDERS
end

function Drops:NoteFormat(text, channel, sender)
    local letter, number = text:match("^(%u)(%d+):")
    number = tonumber(number)
    if not (letter and FORMATS[letter] and number and number > FORMATS[letter]) then return end
    local newer = ns.db.dropNewer
    if type(newer) ~= "table" or newer.version ~= ns.version then
        newer = { version = ns.version, senders = {} }
        ns.db.dropNewer = newer
    end
    local wasOutdated = Outdated()
    newer.senders[sender] = true
    if not wasOutdated and Drops.Log then
        Drops.Log("in", channel, sender, text, Outdated() and "newer format" or "newer format seen")
    end
end

-- Counts a message against today's DAILY_MAX; false when today is full.
local function CountTowardsDailyMax()
    local today = date("%Y-%m-%d")
    local sent = ns.db.dropSent
    if type(sent) ~= "table" or sent.day ~= today then
        sent = { day = today, n = 0 }
        ns.db.dropSent = sent
    end
    if sent.n >= DAILY_MAX then return false end
    sent.n = sent.n + 1
    return true
end

-- Battle.net friends ------------------------------------------------------------
-- The live servers carry no addon messages on custom channels, so finds
-- would reach only the guild and group. A Battle.net friend's game takes
-- addon messages too (C_BattleNet.SendGameData, heard as BN_CHAT_MSG_ADDON),
-- across realms, rulesets and factions, so the player's own finds (D2
-- kills, Q1 quests, A1 trainer ranks, P1 trainer services, V1 vendor
-- recipes and S1 rare stock; never a probe's or roll call's answer) also go
-- to their friends playing WoW: Forever in the same region (Mike,
-- 2026-11-09). Kept as slow as everything else: a find gets one
-- "BNET" outbox entry per friend, at most FRIENDS_MAX, and each leaves in
-- its own turn, a minute after the message before, counting towards
-- DAILY_MAX, so friends don't make the outbox send any faster.
-- An entry names no friend, as the outbox is saved: it holds a slot
-- (friendSlot, 1 to FRIENDS_MAX) and where its find's turn began among the
-- friends (friendTurn), and is matched to a friend playing when it is sent.
-- With more friends online, each find starts with the friends after the
-- last one's. A find heard from a friend is kept as one heard in the guild
-- is, and like it is not passed on, so nothing goes from one friend to
-- another.
local BattleNet = {
    FRIENDS_MAX = 5, -- friends a find goes to
    turn = 0,        -- friend slots handed out this session, so the next find starts with the next friends
}

-- Whether a friend's game account plays WoW: Forever in the player's region.
function BattleNet.IsForeverHere(info)
    return Plain(info.isOnline) == true
        and BNET_CLIENT_WOW ~= nil and Plain(info.clientProgram) == BNET_CLIENT_WOW
        and WOW_PROJECT_ID ~= nil and Plain(info.wowProjectID) == WOW_PROJECT_ID
        and Plain(info.isInCurrentRegion) == true
end

-- The game account ID of the friend's WoW: Forever login here, or nil.
function BattleNet.ForeverAccount(friendIndex)
    for accountIndex = 1, Plain(C_BattleNet.GetFriendNumGameAccounts(friendIndex)) or 0 do
        local info = C_BattleNet.GetFriendGameAccountInfo(friendIndex, accountIndex)
        local gameAccountID = info and Plain(info.gameAccountID)
        if gameAccountID and BattleNet.IsForeverHere(info) then return gameAccountID end
    end
end

-- The game account IDs of the friends playing WoW: Forever here now.
function BattleNet.OnlineFriends()
    local accounts = {}
    if not BNFeaturesEnabledAndConnected() then return accounts end
    for friendIndex = 1, Plain(BNGetNumFriends()) or 0 do
        local gameAccountID = BattleNet.ForeverAccount(friendIndex)
        if gameAccountID then accounts[#accounts + 1] = gameAccountID end
    end
    return accounts
end

-- The game account a "BNET" entry goes to now, or nil when fewer friends
-- play now than its slot. A find's entries leave a minute or more apart,
-- each matched to the friends playing at that moment, so a friend logging
-- in or out between them shifts the slots: one friend can get the find
-- twice and another not at all.
function BattleNet.Recipient(entry)
    local friends = BattleNet.OnlineFriends()
    if entry.friendSlot > #friends then return nil end
    return friends[(entry.friendTurn + entry.friendSlot - 1) % #friends + 1]
end

-- The chat type an outbox entry goes to now, its whisper target or
-- friend's game account, and the heard list it counts in ("GUILD" or
-- "GROUP"; none for a whisper or a friend); nil when not in a guild or
-- group, already heard there, or with no friend for a "BNET" entry.
local function Destination(entry)
    local to = entry.to
    if to == "BNET" then
        local gameAccountID = BattleNet.Recipient(entry)
        return gameAccountID and "BNET", gameAccountID
    end
    if to == "GROUP_OR_GUILD" or to == "CHANNEL" then to = GroupOrGuild() end
    if not to or (entry.id and heard[to] and heard[to][entry.id]) then return nil end
    if to == "WHISPER" then return entry.target and "WHISPER", entry.target end
    if to == "GUILD" then return IsInGuild() and "GUILD" or nil, nil, to end
    return GroupChat(), nil, to
end

-- Sends the outbox's first message; the seconds to wait before the next,
-- or nil when the outbox is empty or sending has stopped.
local function SendNext()
    local outbox = ns.db.dropOutbox
    if #outbox == 0 or AddonMessages.isStoppedThisSession or Outdated() then return nil end
    -- Sharing switched off for everyone (see Switch): the outbox waits, as
    -- it was, for sharing to come back.
    if not Drops.isSharingEnabled then return nil end
    if AddonMessages:WaitsOnLockdown() then return RETRY end
    -- The player hasn't answered yet (see ChannelOn): the outbox waits for
    -- the answer.
    if ns.db.dropChannel == nil then return RETRY end
    -- Sharing turned off in Settings or on the notice: nothing more leaves.
    if not Drops:ChannelOn() then
        wipe(outbox)
        return RETRY
    end
    -- Lane messages whose lane has sent today's are all that can be left
    -- (see Lanes): they wait in the outbox for another day.
    local index = NextSendable(outbox)
    if not index then return nil end
    local entry = outbox[index]
    -- Checked here, not only by the timer, as the entry after a whisper can
    -- change while it waits (a bounced whisper drops the rest of them).
    local waitLeft = WaitBeforeSending(entry)
    if waitLeft > 0 then return waitLeft end
    table.remove(outbox, index)
    local chatType, target, heardList = Destination(entry)
    if not chatType then return 0 end
    if not CountTowardsDailyMax() then
        table.insert(outbox, index, entry)
        return THROTTLE_PAUSE
    end
    local lane = LaneOf(entry)
    if lane then ns.db.dropSent[lane] = (ns.db.dropSent[lane] or 0) + 1 end
    if chatType == "WHISPER" then Whispers.Note(target) end
    local result, refusal = AddonMessages:Send(entry.text, chatType, target)
    if refusal == "throttled" then
        table.insert(outbox, index, entry)
        if Drops.Log then Drops.Log("out", chatType, nil, entry.text, "throttled", result) end
        if AddonMessages.isStoppedThisSession then return nil end
        return THROTTLE_PAUSE
    end
    if refusal == "later" then
        table.insert(outbox, index, entry)
        return RETRY
    end
    lastSentAt, Whispers.wasLastSent = GetTime(), chatType == "WHISPER"
    if entry.id and heardList then heard[heardList][entry.id] = true end
    if Drops.Log then
        local status = type(entry.relay) == "string" and entry.relay or (entry.relay and "relay" or "own")
        Drops.Log("out", chatType, nil, entry.logText or entry.text, status, result)
    end
    return outbox[1] and WaitBeforeSending(outbox[1]) or SEND_GAP
end

-- Runs SendNext until the outbox is empty. An error never stops it for
-- good: the next message is tried RETRY seconds later.
local function Pump()
    local ok, wait = pcall(SendNext)
    if ok and not wait then
        isSending = false
        return
    end
    C_Timer.After(ok and wait or RETRY, Pump)
end

-- `lane` names the lane of an A1, P1, V1 or S1 message (see Lanes), which goes
-- behind every other message; any other goes in front of those. `target`
-- is the player a WHISPER entry goes to (see Whispers). Returns the queued
-- entry, or nil when sharing is off.
local function Queue(text, to, id, relay, lane, target)
    if not Drops:ChannelOn() then return end
    local outbox = ns.db.dropOutbox
    local place = #outbox + 1
    while not lane and place > 1 and LaneOf(outbox[place - 1]) do place = place - 1 end
    local entry = { text = text, to = to, target = target, id = id, relay = relay, lane = lane }
    table.insert(outbox, place, entry)
    while #outbox > OUTBOX_MAX do table.remove(outbox, 1) end
    if not isSending and not AddonMessages.isStoppedThisSession and not Outdated() then
        isSending = true
        -- A message waiting after a quiet spell goes soon; otherwise the
        -- gap since the last one sent still holds.
        C_Timer.After(math.max(WaitBeforeSending(outbox[1]), 1.5), Pump)
    end
    return entry
end

-- Queues one of the player's own finds (a D2, Q1, A1, P1, V1 or S1 message) for as many
-- Battle.net friends as play now, at most FRIENDS_MAX: an entry each, in
-- the message's lane (see Lanes) when it has one.
function BattleNet.Queue(text, id, lane)
    local count = math.min(#BattleNet.OnlineFriends(), BattleNet.FRIENDS_MAX)
    for slot = 1, count do
        local entry = Queue(text, "BNET", id, nil, lane)
        if not entry then return end
        entry.friendSlot, entry.friendTurn = slot, BattleNet.turn
    end
    BattleNet.turn = BattleNet.turn + count
end

-- Queues one of the player's own finds (D2, Q1, A1, P1, V1 or S1) for the
-- PROBERS character a push goes to, if any (see Push after a pull). A lane
-- message's push isn't in its lane: the group's copy already counts
-- towards the lane's daily messages (see Lanes).
function Push.Queue(text, id)
    local target = Push.Target()
    if target then Queue(text, "WHISPER", id, "push", nil, target) end
end

-- Queues one of the player's own finds (a D2 or Q1 message) for the group
-- or guild, the guild, Battle.net friends and a push.
local function QueueOwnFind(text, id)
    Queue(text, "GROUP_OR_GUILD", id)
    Queue(text, "GUILD", id)
    BattleNet.Queue(text, id)
    Push.Queue(text, id)
end

-- Own loot -------------------------------------------------------------------

local clientBuild = tonumber((select(2, GetBuildInfo()))) -- the game build, saved with each find

-- New items of a kill wait BATCH_WAIT seconds for the rest of its loot, so
-- the whole kill goes out as one message.
local BATCH_WAIT = 3
local waitingKills = {} -- [kill] = { kill = <first drop>, items = { drop, ... } }

-- Known drops --------------------------------------------------------------
-- An item NeedRoll's data already has for the boss (ns.Data:KnownDrop: its
-- loot lists, or Data/KnownDrops.lua's world drops and other known drops,
-- built from Classic-DB, QuestieDB and the drops players shared before) is
-- saved but not sent: drop sharing carries new finds, not every kill (Mike,
-- 2026-10-16). A kill with nothing new sends nothing. One sent without some
-- of its items is marked partial (see EncodeKill), so the scraper counts
-- its items as seen but leaves it out of drop rates, which need everything
-- a kill dropped. The player's own SavedVariables keep the whole kill.

local function SavedKill(drop)
    local instance = ns.db.drops[drop.instance]
    local boss = instance and instance.bosses[drop.npc]
    return boss and boss.kills[drop.kill]
end

-- The items NeedRoll doesn't know the boss drops, and whether the kill
-- (saved, as Save keeps it) has any it does know, left out.
local function NewOnly(npc, items, saved)
    local new = {}
    for _, item in ipairs(items) do
        if not ns.Data:KnownDrop(npc, item.item) then new[#new + 1] = item end
    end
    local partial = #new < #items
    for itemID in pairs(saved and saved.items or {}) do
        partial = partial or ns.Data:KnownDrop(npc, itemID)
    end
    return new, partial
end

local function SendKill(kill, items)
    local new, partial = NewOnly(kill.npc, items, SavedKill(kill))
    if #new == 0 then return end
    local itemsKey = kill.kill
    for _, item in ipairs(new) do itemsKey = itemsKey .. ":" .. item.item end
    for _, text in ipairs(EncodeKill(kill, new, partial)) do QueueOwnFind(text, itemsKey .. ":" .. text) end
end

-- Saves one item of a boss kill and, when it was new, sends it on with the
-- rest of the kill's new items.
local function Record(drop)
    if not drop.type then
        local letter, instanceID, difficultyID, instanceName = CurrentInstance()
        if not letter then return end
        drop.type, drop.instance, drop.difficulty, drop.instanceName = letter, instanceID, difficultyID, instanceName
    end
    drop.build = clientBuild
    if not Save(drop) then return end
    local batch = waitingKills[drop.kill]
    if batch then
        table.insert(batch.items, drop)
        return
    end
    waitingKills[drop.kill] = { kill = drop, items = { drop } }
    C_Timer.After(BATCH_WAIT, function()
        local done = waitingKills[drop.kill]
        waitingKills[drop.kill] = nil
        if done then SendKill(done.kill, done.items) end
    end)
end

-- Guessed drops ----------------------------------------------------------------
-- A Bind on Pickup item that turns up without a corpse to tie it to (a
-- group loot roll, or a loot window whose source the game keeps secret)
-- within GUESS_WINDOW seconds of a boss dying is taken for that boss's drop
-- and marked as guessed. Trash killed next to the boss can be mistaken for
-- it, so the scraper keeps guesses apart from sure drops. The boss is the
-- one whose encounter just ended in a kill, or a dead boss the player has
-- targeted or under the mouse; in an unlisted instance, where no encounter
-- may end, also the boss candidate whose corpse the player last looted (see
-- New instances). Its kill key is its corpse's when the game showed the
-- boss unit or the corpse, else "0-<server time in 5-minute steps, hex>",
-- so players guessing about the same kill usually agree.
local GUESS_WINDOW = 120 -- seconds
local lastBoss -- { npc, kill, encounter, name, at = GetTime() }

local function GuessKill()
    return "0-" .. ("%x"):format(math.floor(GetServerTime() / 300))
end

local bossByName
local function BossNamed(name)
    if not name then return nil end
    if not bossByName then
        bossByName = {}
        for npcID, bossName in pairs(KnownBosses()) do bossByName[bossName] = npcID end
    end
    return bossByName[name]
end

-- A dead boss the player has targeted or under the mouse: one NeedRoll
-- knows, or a boss candidate in an unlisted instance.
local function DeadBoss()
    for _, unit in ipairs({ "target", "mouseover" }) do
        local ok, npcID, kill, name = pcall(function()
            if not UnitIsDead(unit) then return end
            local deadNpcID, deadKill = CreatureAndKill(Plain(UnitGUID(unit)))
            if deadNpcID and (KnownBoss(deadNpcID) or IsBossCandidate(deadNpcID)) then
                return deadNpcID, deadKill, Plain(UnitName(unit))
            end
        end)
        if ok and npcID then return { npc = npcID, kill = kill, name = name, at = GetTime() } end
    end
end

ns:On("ENCOUNTER_END", function(encounterID, encounterName, _, _, success)
    if Plain(success) ~= 1 then return end
    encounterID = Plain(encounterID)
    -- One of the fight's boss units, a boss NeedRoll knows first; else the
    -- boss the encounter is named after.
    local found
    for guid in pairs(fightGUIDs) do
        local npcID, kill = CreatureAndKill(guid)
        if npcID and (not found or (KnownBoss(npcID) and not KnownBoss(found.npc))) then
            found = { npc = npcID, kill = kill, encounter = encounterID, name = bossNames[guid] }
        end
    end
    local name = Plain(encounterName)
    if not found and BossNamed(name) then
        found = { npc = BossNamed(name), kill = GuessKill(), encounter = encounterID, name = name }
    end
    if found then
        found.at = GetTime()
        lastBoss = found
    end
end)

-- isBindOnPickup: the loot roll said so; else the item's binding decides.
local function Guess(itemID, count, isBindOnPickup)
    if not CurrentInstance() then return end
    if not (lastBoss and GetTime() - lastBoss.at < GUESS_WINDOW) then lastBoss = DeadBoss() end
    local boss = lastBoss
    if not boss then return end
    ns.Items:Load(itemID, function()
        local bind = select(14, C_Item.GetItemInfo(itemID))
        if not (isBindOnPickup or Plain(bind) == Enum.ItemBind.OnAcquire) then return end
        Record({ npc = boss.npc, kill = boss.kill, item = itemID, count = count or 1, encounter = boss.encounter,
            npcName = boss.name or KnownBoss(boss.npc), guessed = true })
    end)
end

ns:On("START_LOOT_ROLL", function(rollID)
    local itemID = ns.Items:IDFromLink(Plain(GetLootRollItemLink(rollID)))
    if not itemID then return end
    local _, _, count, _, bop = GetLootRollItemInfo(rollID)
    Guess(itemID, Plain(count) or 1, Plain(bop) and true or nil)
end)

-- Open world: an Epic item looted from any creature outside dungeons and
-- raids is saved and sent like a boss drop, under the zone's map (type w,
-- instance = the zone's uiMapID, the creature as the "boss"). Nothing else
-- from the open world is kept.

-- Companion pets ("Teaches you how to summon this companion", like the Cat
-- Carriers) are Miscellaneous items: the Companion Pets subclass, or (as in
-- the 1.12 data) Junk with a Use spell that doesn't stack.
local function IsCompanionPet(itemID, class, subclass, stack)
    if class ~= Enum.ItemClass.Miscellaneous then return false end
    if subclass == Enum.ItemMiscellaneousSubclass.CompanionPet then return true end
    local _, spell = C_Item.GetItemSpell(itemID)
    return Plain(spell) ~= nil and (stack == nil or stack == 1)
end

-- Item rule (as for NeedRoll's loot lists): Uncommon and better always;
-- Common and Poor only when a quest item, quest starter, Bind on Pickup,
-- a recipe or a companion pet. quality and isQuestItem come from the loot
-- window when known; else the quality comes from ns.Items:Quality, since
-- Forever often gives no quality for a Common item (a reagent like Murloc
-- Eye then slipped through as unknown). Returns nil for an item the game
-- hasn't loaded yet: the loot window keeps those rather than lose them,
-- heard ones wait for the item to load (see SaveWhenLoaded).
local function Wanted(itemID, quality, isQuestItem)
    if isQuestItem then return true end
    if quality == nil then
        if not C_Item.IsItemDataCachedByID(itemID) then return nil end
        quality = ns.Items:Quality(itemID)
    end
    if quality >= Enum.ItemQuality.Uncommon then return true end
    local _, _, _, _, _, _, _, stack, _, _, _, class, subclass, bind = C_Item.GetItemInfo(itemID)
    class, subclass, bind, stack = Plain(class), Plain(subclass), Plain(bind), Plain(stack)
    if class == nil then
        local _, _, _, _, _, instantClass, instantSubclass = C_Item.GetItemInfoInstant(itemID)
        class, subclass = Plain(instantClass), Plain(instantSubclass)
    end
    return class == Enum.ItemClass.Questitem or class == Enum.ItemClass.Recipe or bind == Enum.ItemBind.OnAcquire
        or IsCompanionPet(itemID, class, subclass, stack)
end

local function SlotItemID(slot)
    return GetLootSlotType(slot) == Enum.LootSlotType.Item and ns.Items:IDFromLink(Plain(GetLootSlotLink(slot))) or nil
end

-- In an unlisted instance, every corpse in the loot window counts as seen
-- before any is taken for a boss: area loot can pool several of one kind of
-- trash, and the second one must stop the first passing for a boss.
local function NoteLootSources()
    if not InUnlistedInstance() then return end
    for slot = 1, GetNumLootItems() do
        local sources = { GetLootSourceInfo(slot) }
        for i = 1, #sources, 2 do NoteCreature(Plain(sources[i])) end
    end
end

local function AddToCorpse(found, guid, npcID, kill, itemID, count, encounterID)
    local key = guid .. ":" .. itemID
    if not found[key] then
        found[key] = { npc = npcID, kill = kill, item = itemID, count = 0, encounter = encounterID, guid = guid }
    end
    found[key].count = found[key].count + count
end

local function ScanWorld()
    local _, instanceType = GetInstanceInfo()
    if Plain(instanceType) ~= "none" then return end
    local mapID = Plain(C_Map.GetBestMapForUnit("player"))
    if not mapID or mapID <= 1 then return end
    local zone = Plain(GetRealZoneText())
    local found = {}
    for slot = 1, GetNumLootItems() do
        local itemID = SlotItemID(slot)
        if itemID and Plain(select(5, GetLootSlotInfo(slot))) == Enum.ItemQuality.Epic then
            local sources = { GetLootSourceInfo(slot) }
            for i = 1, #sources, 2 do
                local guid = Plain(sources[i])
                local npcID, kill = CreatureAndKill(guid)
                if npcID then AddToCorpse(found, guid, npcID, kill, itemID, tonumber(Plain(sources[i + 1])) or 1) end
            end
        end
    end
    for _, drop in pairs(found) do
        drop.type, drop.instance, drop.difficulty, drop.instanceName = "w", mapID, 0, zone
        drop.npcName = NameOf(drop.guid)
        Record(drop)
    end
end

local function Scan()
    if not ns.db then return end
    if not CurrentInstance() then return ScanWorld() end
    NoteLootSources()
    -- Item counts per corpse; one slot can pool loot from several corpses
    -- (area loot): GetLootSourceInfo gives guid1, count1, guid2, count2, ...
    local found, unsure = {}, {}
    for slot = 1, GetNumLootItems() do
        local itemID = SlotItemID(slot)
        local _, _, slotCount, _, quality, _, isQuestItem, questID = GetLootSlotInfo(slot)
        local isQuest = Plain(isQuestItem) or (tonumber(Plain(questID)) or 0) > 0
        if itemID and Wanted(itemID, tonumber(Plain(quality)), isQuest) ~= false then
            local sources, readable = { GetLootSourceInfo(slot) }, false
            for i = 1, #sources, 2 do
                local guid = Plain(sources[i])
                readable = readable or guid ~= nil
                local npcID, kill = CreatureAndKill(guid)
                if npcID and (bossGUIDs[guid] or KnownBoss(npcID) or IsBossCandidate(npcID)) then
                    local count = tonumber(Plain(sources[i + 1])) or 1
                    AddToCorpse(found, guid, npcID, kill, itemID, count, bossGUIDs[guid])
                end
            end
            -- The game wouldn't say whose corpse it is: maybe the boss just killed.
            if not readable then unsure[itemID] = (unsure[itemID] or 0) + (Plain(slotCount) or 1) end
        end
    end
    for _, drop in pairs(found) do
        drop.npcName = NameOf(drop.guid) or KnownBoss(drop.npc)
        -- No encounter may end in an unlisted instance, so the looted boss
        -- candidate is the boss that Bind on Pickup rolls are guessed onto.
        if IsBossCandidate(drop.npc) then
            lastBoss = { npc = drop.npc, kill = drop.kill, name = drop.npcName, at = GetTime() }
        end
        Record(drop)
    end
    for itemID, count in pairs(unsure) do Guess(itemID, count) end
end

-- LOOT_READY comes first and also fires with auto loot on; LOOT_OPENED is
-- a fallback. Save keeps the second pass from sending again.
ns:On("LOOT_READY", Scan)
ns:On("LOOT_OPENED", Scan)

-- New quests -----------------------------------------------------------------
-- A quest the player accepts that Data/KnownQuests.lua doesn't list (every
-- 1.12 quest plus the Forever ones NeedRoll already has) is saved and sent
-- like a drop, open world included. So is a known quest that differs from
-- its print in Data/KnownQuests.lua (see Changed): a 1.12 quest's level or
-- rewards, or the XP of any quest NeedRoll lists. A data update carrying
-- the report fixes the print, and then no copy sends it again. Saved in
-- NeedRollDB.newQuests:
--     [questID] = { at = <time()>, title, level, build, by = ANON (heard; nil
--         when the player took it), giver, giverID, giverName, dropper, map, x,
--         y, instance, zone, rewards, xp (nil when not seen at full XP), tag (nil when none),
--         sides = { a = true }, classes = { [classID] = true },
--         senders = { [<sender key, Drops.SenderKey>] = { build, level, rewards, viaWhisper } }
--             (heard only: what each player heard reported, see Drops.NoteSender;
--             level nil when not known, rewards nil when they didn't see the quest window,
--             viaWhisper true when a dev build's pull took it by whisper) }
-- Message, one quest each:
--     Q1:<questID>:<level>:<side>:<classID>:<giver>:<giverID>:<mapID>:<x>:<y>:<instanceID>:<build>:<rewards>:<dropper>
--         :<xp>:<tag>\t<title>\t<giver name>\t<zone>\t<sender version>
-- side is a (Alliance), h (Horde) or n; classID is the taker's class. giver
-- is n (an NPC), o (an object), i (an item) or - (not seen: an
-- auto-accepted quest). giverID is the NPC, object or item ID (0 when not
-- known). dropper is the NPC whose corpse the starting item was looted from
-- (0 when not known or not an item). mapID, x and y are where the taker
-- stood, x and y in tenths of a percent (0 when not known, as inside
-- dungeons and raids); instanceID is 0 outside dungeons and raids. rewards
-- are the item IDs the quest window offered: the ones always given, then
-- after a slash the ones to choose from ("1234,5678/91011,1213"; - when
-- none). xp is the XP the quest window offered (see OfferedFullXP), sent
-- only when the taker was within full-XP range of the quest, else 0; copies
-- before it stop reading at dropper. tag is the quest's tag as the game
-- numbers it (see QuestTagID; 0 for none), so the scraper can tell a new
-- dungeon quest from one out in the world; copies before v1.8.0 stop
-- reading at xp. It is a field added to Q1, not a Q2: copies read Q1's
-- fields up to the ones they know and ignore the rest, while hearing a Q2
-- would mark them Outdated (see Drops:NoteFormat) and silence them. Names
-- are cut so a message stays within MESSAGE_MAX bytes.
-- A quest is sent again when a new side or class takes it, when a better
-- giver turns up for one heard without, or when it brings the XP, rewards
-- or tag the saved one lacks. Fields after tag can be added the same way.
local QUESTS_MAX = 500 -- oldest saved quests go past this (not on local checkouts)
local QUEST_FIELDS = { "title", "level", "build", "giver", "giverID", "giverName", "dropper", "map", "x", "y",
    "instance", "zone", "rewards", "xp", "tag" }

-- How much a report says about who gives the quest: nothing, an item, which
-- item, which item and who dropped it or the NPC or object.
local function GiverRank(report)
    if report.giver == "n" or report.giver == "o" then return 3 end
    if report.giver ~= "i" then return 0 end
    if (report.giverID or 0) == 0 then return 1 end
    return (report.dropper or 0) > 0 and 3 or 2
end

-- Saves one report of a quest; true when it told something new.
local function SaveQuest(report)
    local savedQuests = ns.db.newQuests
    local saved, isNew = savedQuests[report.quest], false
    if not saved then
        saved = { at = time(), by = report.by, viaWhisper = report.viaWhisper, sides = {}, classes = {} }
        savedQuests[report.quest] = saved
        isNew = true
        if not Drops.keepAll then DropOldest(savedQuests, QUESTS_MAX) end
    end
    if isNew or GiverRank(report) > GiverRank(saved) then
        local savedRewards, savedXP, savedTag = saved.rewards, saved.xp, saved.tag
        for _, key in ipairs(QUEST_FIELDS) do saved[key] = report[key] end
        if report.rewards == "-" and savedRewards then saved.rewards = savedRewards end
        -- XP and a tag seen once are kept, as the scraper keeps them (knownquests.py merge_reported).
        saved.xp = savedXP or report.xp
        saved.tag = savedTag or report.tag
        isNew = true
    elseif (saved.rewards == nil or saved.rewards == "-") and report.rewards ~= "-" then
        saved.rewards = report.rewards
        isNew = true
    end
    if report.xp and not saved.xp then
        saved.xp = report.xp
        isNew = true
    end
    if report.tag and not saved.tag then
        saved.tag = report.tag
        isNew = true
    end
    if report.side ~= "n" and not saved.sides[report.side] then
        saved.sides[report.side] = true
        isNew = true
    end
    if report.class > 0 and not saved.classes[report.class] then
        saved.classes[report.class] = true
        isNew = true
    end
    return isNew
end

-- A name cut to at most `size` bytes (never inside a UTF-8 character),
-- without the tab that separates names.
local function Short(text, size)
    local oneField = (text or ""):gsub("\t", " ")
    return ns.CutToBytes(oneField, size)
end

local function EncodeQuest(report)
    local fields = table.concat({ QUEST_VERSION, report.quest, report.level, report.side, report.class,
        report.giver, report.giverID, report.map, report.x, report.y, report.instance, report.build or 0,
        report.rewards or "-", report.dropper or 0, report.xp or 0, report.tag or 0 }, ":")
    -- The names share what is left; the title gets any room the others don't use.
    local version = VersionTag()
    local room = MESSAGE_MAX - #fields - 4 - #version
    local giverName = Short(report.giverName, math.floor(room / 3))
    local zone = Short(report.zone, math.floor(room / 3))
    local title = Short(report.title, room - #giverName - #zone)
    return fields .. "\t" .. title .. "\t" .. giverName .. "\t" .. zone .. "\t" .. version
end

-- A heard quest's rewards ("1,2/3,4"), or "-" (none seen) when the field is
-- missing or any item ID isn't a HeardNumber.
local function HeardRewards(rewards)
    if not (rewards and rewards:match("^[%d,/]+$")) then return "-" end
    for itemID in rewards:gmatch("%d+") do
        if not HeardNumber(itemID) then return "-" end
    end
    return rewards
end

-- A heard quest's XP or tag, or nil: the field is missing (a copy from
-- before it was sent), 0 (the taker wasn't within full-XP range, the quest
-- has no tag) or not a HeardNumber.
local function HeardAboveZero(field)
    local number = HeardNumber(field)
    if number and number > 0 then return number end
end

-- Where a quest was taken, x and y in tenths of a percent (see Where).
local COORDINATE_MAX = 1000

-- A heard Q1 as a quest report, or nil when it can't be read. A build newer
-- than this client's is made up, and reads as unknown, as in the trainer
-- and vendor messages.
local function DecodeQuest(text)
    local fields, title, giverName, zone = SplitMessage(text)
    if fields[1] ~= QUEST_VERSION or #fields < 12 then return nil end
    local report = {
        quest = HeardNumber(fields[2]), level = HeardNumber(fields[3]) or 0, side = fields[4],
        class = HeardNumber(fields[5]) or 0, giver = fields[6], giverID = HeardNumber(fields[7]) or 0,
        map = HeardNumber(fields[8]) or 0, x = HeardNumber(fields[9], COORDINATE_MAX) or 0,
        y = HeardNumber(fields[10], COORDINATE_MAX) or 0,
        instance = HeardNumber(fields[11]) or 0, build = HeardNumber(fields[12], clientBuild),
        rewards = HeardRewards(fields[13]), dropper = HeardNumber(fields[14]) or 0,
        xp = HeardAboveZero(fields[15]), tag = HeardAboveZero(fields[16]),
        title = NilIfEmpty(title), giverName = NilIfEmpty(giverName), zone = NilIfEmpty(zone),
    }
    -- Each class becomes a key of the saved quest's classes, so only the game's class IDs count.
    if report.class > GetNumClasses() then report.class = 0 end
    if not (report.quest and report.quest > 0 and (report.side == "a" or report.side == "h" or report.side == "n")
        and (report.giver == "n" or report.giver == "o" or report.giver == "i" or report.giver == "-")) then
        return nil
    end
    return report
end

-- A hash of a quest's reward items ("1,2/3,4" as the quest window offered
-- them, "-" for none), as Data/KnownQuests.lua's prints have it
-- (scraper/needroll_scraper/knownquests.py reward_hash): each item adds the
-- top 12 bits of (item * 2654435761 + salt) mod 2^32, a different salt for
-- items to choose from, so the order doesn't matter.
local CHOICE_SALT = 2246822519
local function RewardHash(rewards)
    local always, choice = (rewards or "-"):match("^([^/]*)/?(.*)$")
    local hash = 0
    for _, part in ipairs({ { always, 0 }, { choice, CHOICE_SALT } }) do
        local itemIDs, salt = part[1], part[2]
        for itemID in itemIDs:gmatch("%d+") do
            local mixed = (tonumber(itemID) * 2654435761 + salt) % 4294967296
            hash = (hash + math.floor(mixed / 1048576)) % 4096
        end
    end
    return hash
end

-- Whether a report of a quest differs from its print (ns.Data:QuestPrint):
-- other XP, when the report has some (only a taker within full-XP range
-- sends it, see OfferedFullXP); another level; or other rewards when the
-- quest window was seen (allRewardsSeen: false when the window hadn't
-- loaded every reward item, so they aren't compared). Only what the print
-- has is compared. False for a quest with no print.
local function Changed(report, allRewardsSeen)
    local questPrint = ns.Data:QuestPrint(report.quest)
    if not questPrint then return false end
    if questPrint.xp and report.xp and report.xp ~= questPrint.xp then return true end
    if questPrint.level and (report.level or 0) > 0 and report.level ~= questPrint.level then return true end
    if not questPrint.rewardHash or report.giver == "-" or allRewardsSeen == false then return false end
    return RewardHash(report.rewards) ~= questPrint.rewardHash
end

-- Whether NeedRoll's data now has a saved quest as reported (a new quest
-- listed since, or a changed quest whose print now matches).
local function Listed(questID, saved)
    return ns.Data:KnownQuest(questID) and not Changed({ quest = questID, level = saved.level,
        giver = saved.giver or "-", rewards = saved.rewards, xp = saved.xp })
end

-- One report's key: a quest is sent once per side and class.
local function QuestKey(report)
    return "q" .. report.quest .. report.side .. report.class
end

-- Quest items looted from NPCs, so a quest started from an item can name
-- who dropped it: NeedRollDB.questLoot[itemID] = { npc = <NPC ID>, at =
-- <time()> }, only items the loot window marks as quest items, newest 100.
-- The loot window also says which quest an item starts, when it does
-- (startedBy[questID] = itemID, this session).
local QUEST_LOOT_MAX = 100
local startedBy = {}

local function NoteQuestLoot()
    if not ns.db then return end
    local kept = ns.db.questLoot
    for slot = 1, GetNumLootItems() do
        local _, _, _, _, _, _, isQuestItem, questID = GetLootSlotInfo(slot)
        isQuestItem, questID = Plain(isQuestItem), tonumber(Plain(questID))
        local itemID = (isQuestItem or (questID and questID > 0)) and ns.Items:IDFromLink(Plain(GetLootSlotLink(slot)))
        if itemID then
            local npcID = CreatureAndKill(Plain((GetLootSourceInfo(slot))))
            if npcID then kept[itemID] = { npc = npcID, at = time() } end
            if questID and questID > 0 then startedBy[questID] = itemID end
        end
    end
    DropOldest(kept, QUEST_LOOT_MAX)
end
ns:On("LOOT_READY", NoteQuestLoot)

-- The item last used from the bags: a quest an item starts opens right after.
local lastUsedItem, lastUsedAt = nil, 0
local function NoteUse(bag, slot)
    lastUsedItem, lastUsedAt = Plain(C_Container.GetContainerItemID(bag, slot)), GetTime()
end
hooksecurefunc(C_Container, "UseContainerItem", NoteUse)

-- The item IDs the quest window offers ("reward" or "choice"), at most 8,
-- and whether every one was there (an item not loaded yet has no link).
local function RewardIDs(kind, count)
    local ids = {}
    count = math.min(Plain(count) or 0, 8)
    for i = 1, count do
        local itemID = ns.Items:IDFromLink(Plain(GetQuestItemLink(kind, i)))
        if itemID then ids[#ids + 1] = itemID end
    end
    return table.concat(ids, ","), #ids == count
end

-- QuestGiver's answer at QUEST_DETAIL, plus rewards, allRewardsSeen, the
-- XP the window offered and the player's level then, by quest ID: the quest
-- NPC is gone by the time it is accepted.
local givers = {}

local function OpenQuestID()
    local questID = Plain(GetQuestID())
    if questID and questID > 0 then return questID end
end

-- QUEST_ACCEPTED's quest ID: its last argument (older clients send the
-- quest log index first).
local function AcceptedQuestID(...)
    local argCount = select("#", ...)
    local questID = argCount > 0 and tonumber(Plain((select(argCount, ...))))
    if questID and questID > 0 then return questID end
end

-- The NPC ("n") or object ("o") a GUID names: kind and ID; else nil.
local function GUIDSource(guid)
    local unitType, id, spawnKey = ns.ParseGUID(guid)
    if not spawnKey then return nil end -- only a whole GUID, as the game writes it
    local kind = (unitType == "Creature" or unitType == "Vehicle") and "n" or unitType == "GameObject" and "o" or nil
    if not kind then return nil end
    return kind, id
end

-- The quest window's NPC ("n") or object ("o"): kind, ID and name; else nil.
local function QuestWindowSource()
    local kind, id = GUIDSource(Plain(UnitGUID("questnpc")) or Plain(UnitGUID("npc")))
    if not kind then return nil end
    return kind, id, Plain(UnitName("questnpc")) or Plain(UnitName("npc"))
end

-- { kind, id, name, dropper }: kind n (NPC), o (object) or i (item, looted from dropper).
local function QuestGiver(questID)
    local kind, id, name = QuestWindowSource()
    if kind then return { kind = kind, id = id, name = name } end
    -- Started from an item: the one the loot window tied to this quest,
    -- else the one just used from the bags.
    local itemID = startedBy[questID] or (lastUsedItem and GetTime() - lastUsedAt < 3 and lastUsedItem) or 0
    local looted = itemID > 0 and ns.db and ns.db.questLoot[itemID]
    return { kind = "i", id = itemID,
        name = itemID > 0 and Plain(C_Item.GetItemNameByID(itemID)) or nil,
        dropper = looted and looted.npc or 0 }
end

ns:On("QUEST_DETAIL", function()
    local questID = OpenQuestID()
    if not questID then return end
    if ns.Data:KnownQuest(questID) and not ns.Data:QuestPrint(questID) then return end
    local giver = QuestGiver(questID)
    local always, allThere = RewardIDs("reward", GetNumQuestRewards())
    local choose, allChoices = RewardIDs("choice", GetNumQuestChoices())
    giver.rewards = (always == "" and choose == "") and "-" or (choose == "" and always or (always .. "/" .. choose))
    giver.allRewardsSeen = allThere and allChoices
    giver.windowXP, giver.playerLevel = Plain(GetRewardXP()), Plain(UnitLevel("player"))
    givers[questID] = giver
end)

local function QuestLogInfo(questID)
    local index = C_QuestLog.GetLogIndexForQuestID(questID)
    return index and C_QuestLog.GetInfo(index)
end

-- The XP a quest window offered when it is the quest's full XP: the player
-- (at `playerLevel` then) within full-XP range of the quest (`questLevel`,
-- known) and the window offering some. Else nil: above that range the game
-- offers less than the quest pays, and at the level cap nothing.
local function OfferedFullXP(windowXP, questLevel, playerLevel)
    if type(windowXP) ~= "number" or windowXP <= 0 then return nil end
    if not ns.Data:PaysFullXP(questLevel, playerLevel) then return nil end
    return windowXP
end

-- The quest's level and title from the quest log.
local function QuestInfo(questID)
    local level, title
    local info = QuestLogInfo(questID)
    if info then level, title = Plain(info.level), Plain(info.title) end
    title = title or Plain(C_QuestLog.GetTitleForQuestID(questID))
    return tonumber(level) or 0, title
end

-- A quest's tag info as the game gives it (C_QuestLog.GetQuestTagInfo), or
-- nil when it gives none. Guarded with pcall: a read that fails leaves the
-- tag unknown instead of stopping the quest's report. This and QuestTagID
-- hang off Drops rather than being locals: this file's main chunk is close
-- to Lua 5.1's limit of 200 locals.
function Drops.QuestTagInfo(questID)
    local ok, tagInfo = pcall(C_QuestLog.GetQuestTagInfo, questID)
    if ok and type(tagInfo) == "table" then return tagInfo end
end

-- A quest's tag as the game numbers it (Enum.QuestTag: 81 Dungeon, 62 Raid,
-- 1 Group, which WoW: Forever's quest log calls Elite), or nil for none. The
-- number is the same on every client; the tag's name is in the player's
-- language, so it is never sent. An elite quest the game gives no tag
-- number counts as Group.
function Drops.QuestTagID(questID)
    local tagInfo = Drops.QuestTagInfo(questID)
    if not tagInfo then return nil end
    local tagID = tonumber(Plain(tagInfo.tagID))
    if tagID and tagID > 0 then return tagID end
    if Plain(tagInfo.isElite) then return Enum.QuestTag.Group end
end

-- Where the player stands: map ID, x and y (tenths of a percent), instance
-- ID (0 outside dungeons and raids) and zone name.
local function Where()
    local map = Plain(C_Map.GetBestMapForUnit("player")) or 0
    local x, y = 0, 0
    if map > 0 then
        local ok, px, py = pcall(function()
            local pos = C_Map.GetPlayerMapPosition(map, "player")
            if pos then return pos:GetXY() end
        end)
        px, py = ok and Plain(px), ok and Plain(py)
        if px and py then x, y = math.floor(px * 1000 + 0.5), math.floor(py * 1000 + 0.5) end
    end
    local letter, instanceID = CurrentInstance()
    return map, x, y, letter and instanceID or 0, Plain(GetRealZoneText()) or ""
end

local SIDES = { Alliance = "a", Horde = "h" }

-- The player's side as messages write it: a (Alliance), h (Horde) or n (not known).
function Drops.SideLetter()
    return SIDES[Plain(UnitFactionGroup("player"))] or "n"
end

-- Core/Vendors.lua marks where a vendor stands as a quest's taker is marked.
Drops.Where = Where

ns:On("QUEST_ACCEPTED", function(...)
    local questID = AcceptedQuestID(...)
    if not ns.db or not questID then return end
    -- A known quest is sent only when its print differs, once: not when
    -- this copy already sent or heard it.
    local known = ns.Data:KnownQuest(questID)
    if known and (not ns.Data:QuestPrint(questID) or ns.db.newQuests[questID]) then return end
    local giver = givers[questID] or { kind = "-", id = 0, dropper = 0, rewards = "-" }
    givers[questID] = nil
    local level, title = QuestInfo(questID)
    local map, x, y, instance, zone = Where()
    local report = {
        quest = questID, level = level, title = title, build = clientBuild,
        side = Drops.SideLetter(), class = Plain(select(3, UnitClass("player"))) or 0,
        giver = giver.kind, giverID = giver.id, giverName = giver.name, dropper = giver.dropper or 0,
        rewards = giver.rewards, xp = OfferedFullXP(giver.windowXP, level, giver.playerLevel),
        map = map, x = x, y = y, instance = instance, zone = zone, tag = Drops.QuestTagID(questID),
    }
    if known and not Changed(report, giver.allRewardsSeen) then return end
    if SaveQuest(report) then
        QueueOwnFind(EncodeQuest(report), QuestKey(report))
    end
end)

-- Trainer ranks ------------------------------------------------------------------
-- Core/Trainers.lua reads the player's class trainer and keeps what differs
-- from NeedRoll's class spells (Data/ClassSpells.lua); the ranks no copy has
-- sent yet go to the group, or the guild outside one, and to Battle.net
-- friends (see Battle.net friends), several a message:
--     A1:<class token>:<build>:<npc>:<standing>:<race>:<spellID>.<level>.<cost>[.<rank>],...\t<name>,...
--         \t<sender version>
-- class token is the class's file name ("PALADIN"), build the game build the
-- trainer was read on, npc the trainer's NPC ID (0 when not known), standing
-- the reader's standing with the trainer's faction (UnitReaction: 1 hated to
-- 8 exalted, 0 when not known), race the reader's race (the game's race ID,
-- 3 for a Dwarf, 0 when not known: some spells are one race's, see Races in
-- Core/Trainers.lua), level the level the rank needs and cost its
-- price in copper as the reader pays it, after their reputation discount
-- (see Reputation discounts in Core/Trainers.lua). Copies before v1.8.0 send
-- T1, the same without standing and race, which is still read. A spell the
-- sender's NeedRoll doesn't list (for the sender's race) adds its rank
-- number (0 for a spell without ranks) and its name, in the first tab field
-- in the order of those spells (empty when the sender's game isn't in
-- English, as the scraper files spells by their English names). Names are
-- cut short and carry no comma. Trainer messages queue behind every drop
-- and quest message, in the trainer lane (see Lanes), so a trainer's long
-- list can't crowd out drops. A copy hearing one saves its ranks without
-- the sender's name, only its key (Drops.SenderKey), marked heard, and
-- sends them again only in a probe's answer (see Catch-up probes), without
-- the key. Heard ranks wait for NeedRoll's next data update: anyone can
-- send a trainer message, so only the player's own trainer reads show in
-- game, and the scraper applies a heard rank only once two players agree.
-- Ranks with a standing and race have a letter of their own, A ("ability
-- ranks"), rather than a T2: a higher T number would make copies before
-- v1.8.0 stop sending everything (see Outdated) once three players' copies
-- sent one, while a letter they don't know they ignore, and those copies'
-- drops and quests are still wanted.
local TRAINER_LIMITS = {
    level = 100,        -- the highest level a heard rank may need
    skill = 1000,       -- the highest skill a heard service may need (Forever's professions stop at 300)
    cost = 10000000,    -- the highest price in copper a heard rank may have (1000 gold, far over any trainer's)
    name = 30,          -- bytes of a spell's name sent
    standing = 8,       -- the highest standing a heard message may give (exalted)
    race = 100,         -- the highest race ID a heard message may give (the game's playable races are far below)
}
-- Drops fields rather than locals: this file's main chunk is near the 200
-- locals Lua 5.1 allows. The kind of a trainer services message (see
-- Trainer services below).
Drops.TRAINER_SERVICES_VERSION = "P1"
-- The trainer message kinds read, each with the number of ":" fields it has.
Drops.TRAINER_FIELDS = { T1 = 5, [TRAINER_VERSION] = 7, [Drops.TRAINER_SERVICES_VERSION] = 6 }
-- The numbers of each trainer message kind's rank fields, in order.
Drops.TRAINER_RANK_NUMBERS = { T1 = { "spell", "level", "cost" },
    [Drops.TRAINER_SERVICES_VERSION] = { "spell", "skill", "level", "cost" } }
Drops.TRAINER_RANK_NUMBERS[TRAINER_VERSION] = Drops.TRAINER_RANK_NUMBERS.T1

-- One rank's field, its `numbers` joined by "." ("spellID.level.cost" in
-- an A1), and for a spell the sender's NeedRoll doesn't list ".rank" and
-- its name as the message carries it: cut short, without commas.
function Drops.EncodeTrainerRank(rank, numbers)
    local values = {}
    for index, key in ipairs(numbers) do values[index] = rank[key] or 0 end
    local field = table.concat(values, ".")
    if rank.isListed then return field end
    return field .. "." .. (rank.rank or 0), (Short(rank.name, TRAINER_LIMITS.name):gsub(",", " "))
end

-- Trainer messages starting `head` for `ranks`, each rank's field laid out
-- by `numbers`, as many ranks to a message as fit MESSAGE_MAX: { { text =
-- ..., ranks = { the ranks it carries } }, ... }.
function Drops.PackTrainerRanks(head, numbers, ranks)
    local version = VersionTag()
    local messages, fields, names, carried = {}, {}, {}, {}
    local function TextOf(fieldList, nameList)
        return head .. table.concat(fieldList, ",") .. "\t" .. table.concat(nameList, ",") .. "\t" .. version
    end
    for _, rank in ipairs(ranks) do
        local field, name = Drops.EncodeTrainerRank(rank, numbers)
        local size = #TextOf(fields, names) + #field + 1 + (name and #name + 1 or 0)
        if #fields > 0 and size > MESSAGE_MAX then
            messages[#messages + 1] = { text = TextOf(fields, names), ranks = carried }
            fields, names, carried = {}, {}, {}
        end
        fields[#fields + 1] = field
        names[#names + 1] = name
        carried[#carried + 1] = rank
    end
    if #fields > 0 then messages[#messages + 1] = { text = TextOf(fields, names), ranks = carried } end
    return messages
end

-- A1 messages for the ranks of one class read at one trainer on one build
-- at one standing by one race (see Drops.PackTrainerRanks). `group` is {
-- build, npc, standing, race (each 0 when not known, as
-- Trainers.GroupReports gives them; nil is sent as 0 too), ranks }, each
-- rank { spell, level, cost, rank, name, isListed }.
function Drops.EncodeTrainerRanks(classToken, group)
    local head = table.concat({ TRAINER_VERSION, classToken, group.build, group.npc, group.standing or 0,
        group.race or 0 }, ":") .. ":"
    return Drops.PackTrainerRanks(head, Drops.TRAINER_RANK_NUMBERS[TRAINER_VERSION], group.ranks)
end

-- A heard trainer rank field, its `numbers` read into a table by name ({
-- spell, level, cost } in an A1), with a rank number past them for a spell
-- the sender doesn't list, else isListed set; nil when it's bad.
function Drops.DecodeTrainerRank(field, numbers)
    local parts = {}
    for part in (field .. "."):gmatch("([^.]*)%.") do parts[#parts + 1] = part end
    local isListed = #parts == #numbers
    if not (isListed or #parts == #numbers + 1) then return nil end
    local decoded = { isListed = isListed or nil }
    for index, key in ipairs(numbers) do
        decoded[key] = HeardNumber(parts[index], TRAINER_LIMITS[key])
        if not decoded[key] then return nil end
    end
    if decoded.spell == 0 then return nil end
    if not isListed then decoded.rank = HeardNumber(parts[#parts]) end
    if decoded.rank == 0 then decoded.rank = nil end
    return decoded
end

-- The ranks of a heard trainer message: its last ":" field, each rank laid
-- out by `numbers`, and its first tab field, the names of the spells the
-- sender doesn't list, in their order. Nil when any rank is bad or there
-- are none.
function Drops.DecodeTrainerRankList(rankField, nameField, numbers)
    local names, ranks = {}, {}
    for name in (nameField .. ","):gmatch("([^,]*),") do names[#names + 1] = name end
    for field in rankField:gmatch("[^,]+") do
        local rank = Drops.DecodeTrainerRank(field, numbers)
        if not rank then return nil end
        if not rank.isListed then
            local name = table.remove(names, 1)
            -- Another player wrote it: no control characters or "|" (it starts the game's text codes).
            if name and name ~= "" and #name <= TRAINER_LIMITS.name and not name:find("[%c|]") then rank.name = name end
        end
        ranks[#ranks + 1] = rank
    end
    return #ranks > 0 and ranks or nil
end

-- A heard T1 or A1 message as { class = token, build, npc, standing, race,
-- ranks = { { spell, level, cost, rank, name, isListed }, ... } }, standing
-- and race nil when not known (always for a T1), rank and name only for a
-- spell the sender's NeedRoll doesn't list; nil when any part is bad.
-- Every copy on a realm plays the same game build, so a build newer than
-- this client's is made up (or a patch this client hasn't got yet) and the
-- message is refused.
function Drops.DecodeTrainerRanks(text)
    local fields, nameField = SplitMessage(text)
    local kind = fields[1]
    if kind == Drops.TRAINER_SERVICES_VERSION or Drops.TRAINER_FIELDS[kind] ~= #fields then return nil end
    -- A T1 carries no standing or race; an A1 gives 0 for either when the sender's game didn't say.
    local standing, race = 0, 0
    if kind == TRAINER_VERSION then
        standing, race = HeardNumber(fields[5], TRAINER_LIMITS.standing), HeardNumber(fields[6], TRAINER_LIMITS.race)
    end
    local decoded = { class = fields[2], build = HeardNumber(fields[3], clientBuild), npc = HeardNumber(fields[4]),
        standing = standing ~= 0 and standing or nil, race = race ~= 0 and race or nil }
    local isKnownClass = decoded.class:match("^%u+$") and ns.Data:ShippedClassSpells(decoded.class)
    if not (isKnownClass and decoded.build and decoded.npc and standing and race) then return nil end
    decoded.ranks = Drops.DecodeTrainerRankList(fields[#fields], nameField, Drops.TRAINER_RANK_NUMBERS[kind])
    return decoded.ranks and decoded or nil
end

-- Queues a message in lane `lane` ("trainer" or "vendor", see Lanes),
-- behind every other message, keyed by its text before the names. False,
-- and nothing queued, while sharing is off or this copy is outdated, or
-- when the lane's daily count of messages already wait: what it carries
-- then stays unsent for a later try. A message queued here is the
-- player's own find, so it also goes to a push (see Push after a pull).
function Drops.QueueLaneMessage(lane, text)
    if not Drops:ChannelOn() or Outdated() then return false end
    local waiting = 0
    for _, entry in ipairs(ns.db.dropOutbox) do
        if LaneOf(entry) == lane and entry.to ~= "BNET" then waiting = waiting + 1 end
    end
    if waiting >= LANES[lane].daily then return false end
    local id = text:match("^[^\t]*")
    Queue(text, LANES[lane].to, id, nil, lane)
    if LANES[lane].toFriends then BattleNet.Queue(text, id, lane) end
    Push.Queue(text, id)
    return true
end

-- Saves a heard T1 or A1 message's ranks (Core/Trainers.lua) with its
-- sender's key (Drops.SenderKey); its heard key and what came of it, or nil
-- when it can't be read. `isWhispered` marks ranks a dev build's pull took by
-- whisper, kept out of probe answers (see Catch-up probes).
function Drops.TakeTrainerRanks(text, sender, isWhispered)
    local decoded = Drops.DecodeTrainerRanks(text)
    if not decoded then return nil end
    decoded.viaWhisper, decoded.senderKey = isWhispered, Drops.SenderKey(sender)
    return text:match("^[^\t]*"), ns.Trainers.SaveHeard(decoded)
end

-- Trainer services -----------------------------------------------------------------
-- Core/TrainerShare.lua reads every other trainer the player opens and
-- keeps what differs from NeedRoll's data, or that it doesn't list: a
-- profession trainer's recipes and Apprentice to Artisan ranks, a hunter
-- pet trainer's abilities and, at the player's own class trainer, what
-- isn't a class spell (the rogue's poisons). The services no copy has sent
-- yet go out like trainer ranks, in the trainer lane, several a message:
--     P1:<list>:<build>:<npc>:<standing>:<spellID>.<skill>.<level>.<cost>[.<rank>],...\t<name>,...
--         \t<sender version>
-- list is the NeedRoll list the services are on ("MINING", "PET",
-- "POISONS"), worked out from their spell IDs, never from the skill name
-- the game gives (that is in the player's language). build, npc and
-- standing are as in an A1. skill and level are 0 when the game didn't
-- give them (the reader has reached them, or the service needs no skill),
-- cost is the price as the reader pays it. A service the sender's NeedRoll
-- doesn't list adds its rank number (a pet ability's, 0 for none) and its
-- name, as in an A1. P is a letter copies before it don't know, so they
-- ignore it (see Outdated). Dev builds before 2026-11-12 sent realm channel
-- pings as "P1:<time>:<random>"; no release ever did. A copy hearing one
-- saves what differs from its own data, marked heard, without the sender's
-- name but with its key (as for an A1), and sends it again only in a
-- probe's answer (see Catch-up probes); nothing of it is shown in game.

-- P1 messages for the services of one list read at one trainer on one
-- build at one standing (see Drops.PackTrainerRanks). `group` is { list,
-- build, npc, standing (0 when not known, as Trainers.GroupReports gives
-- it; nil is sent as 0 too), ranks }, each rank { spell, skill, level,
-- cost, rank, name, isListed }.
function Drops.EncodeTrainerServices(group)
    local head = table.concat({ Drops.TRAINER_SERVICES_VERSION, group.list, group.build, group.npc,
        group.standing or 0 }, ":") .. ":"
    return Drops.PackTrainerRanks(head, Drops.TRAINER_RANK_NUMBERS[Drops.TRAINER_SERVICES_VERSION], group.ranks)
end

-- A heard P1 message as { list, build, npc, standing (nil when not known),
-- ranks = { { spell, skill, level, cost, rank, name, isListed }, ... } };
-- nil when any part is bad, the list isn't one of NeedRoll's or the build
-- is newer than this client's (see Drops.DecodeTrainerRanks).
function Drops.DecodeTrainerServices(text)
    local fields, nameField = SplitMessage(text)
    local kind = fields[1]
    if kind ~= Drops.TRAINER_SERVICES_VERSION or Drops.TRAINER_FIELDS[kind] ~= #fields then return nil end
    local standing = HeardNumber(fields[5], TRAINER_LIMITS.standing)
    local decoded = { list = fields[2], build = HeardNumber(fields[3], clientBuild), npc = HeardNumber(fields[4]),
        standing = standing ~= 0 and standing or nil }
    if not (ns.TrainerShare.IsKnownList(decoded.list) and decoded.build and decoded.npc and standing) then
        return nil
    end
    decoded.ranks = Drops.DecodeTrainerRankList(fields[6], nameField, Drops.TRAINER_RANK_NUMBERS[kind])
    return decoded.ranks and decoded or nil
end

-- Saves a heard P1 message's services (Core/TrainerShare.lua) with its
-- sender's key; its heard key and what came of it, or nil when it can't be
-- read. `sender` and `isWhispered` as for Drops.TakeTrainerRanks.
function Drops.TakeTrainerServices(text, sender, isWhispered)
    local decoded = Drops.DecodeTrainerServices(text)
    if not decoded then return nil end
    decoded.viaWhisper, decoded.senderKey = isWhispered, Drops.SenderKey(sender)
    return text:match("^[^\t]*"), ns.TrainerShare.SaveHeard(decoded)
end

-- Vendor messages -----------------------------------------------------------------
-- Core/Vendors.lua reads every merchant window the player opens and keeps
-- the recipes, and the other items only a few vendors sell (rare stock),
-- that NeedRoll doesn't know that vendor sells; the ones no copy has sent
-- yet go out, several a message, recipes as V1 and rare stock as S1:
--     V1:<npcID>:<side>:<mapID>:<x>:<y>:<instanceID>:<build>:<itemID>.<price>[.l],...\t<vendor name>
--         \t<sender version>
--     S1:... laid out the same
-- npcID is the vendor's; side is a (Alliance), h (Horde) or n (read on both
-- sides, or not known). mapID, x, y and instanceID say where the vendor
-- stands, as for a quest's taker (see Where: x and y in tenths of a
-- percent, 0 inside dungeons and raids, instanceID 0 outside them). build
-- is the game build the window was read on, price an item's price in
-- copper, and .l marks an item in limited supply. The vendor's name comes
-- only from English clients (the scraper files vendors by their English
-- names), cut short; it is empty otherwise. Vendor messages travel in the
-- vendor lane (see Lanes), to the group or guild and to Battle.net friends.
-- Rare stock has a letter of its own rather than a V2: copies before it
-- read every V1 item as a recipe, and a higher V number would make them
-- stop sending (see Outdated), while a letter they don't know they ignore.
-- A copy hearing one checks that each item is of the message's kind on its
-- own client (Core/Vendors.lua), saves them without the sender's name,
-- marked heard, and doesn't send them again. Anyone can send a vendor
-- message, so the scraper only lists heard vendors for Mike to check
-- (scraper `ingest`).
local VENDOR_LIMITS = {
    price = 100000000, -- the highest price in copper a heard item may have (10000 gold, far over any vendor's)
    name = 40,         -- bytes of a vendor's name sent
}
local VENDOR_VERSIONS = { [VENDOR_RECIPES_VERSION] = true, [VENDOR_ITEMS_VERSION] = true }

-- One item's field, "itemID.price", with ".l" for one in limited supply.
local function EncodeVendorItem(item)
    return item.item .. "." .. item.price .. (item.limited and ".l" or "")
end

-- Vendor messages of kind `version` ("V1" or "S1") for one vendor's items,
-- as many to a message as fit MESSAGE_MAX: { { text = ..., items = { the
-- items it carries } }, ... }. `vendor` is { npc, side, map, x, y,
-- instance, build, name }, each item { item, price, limited }.
function Drops.EncodeVendorMessages(version, vendor, items)
    local head = table.concat({ version, vendor.npc, vendor.side, vendor.map, vendor.x, vendor.y,
        vendor.instance, vendor.build or 0 }, ":") .. ":"
    local tail = "\t" .. Short(vendor.name, VENDOR_LIMITS.name) .. "\t" .. VersionTag()
    local fields = {}
    for _, item in ipairs(items) do fields[#fields + 1] = EncodeVendorItem(item) end
    local messages = PackFields(head, fields, tail)
    for _, message in ipairs(messages) do
        message.items = {}
        for index = message.first, message.last do message.items[#message.items + 1] = items[index] end
    end
    return messages
end

-- A heard item field as { item, price, limited }; nil when it's bad.
local function DecodeVendorItem(field)
    local itemID, price, mark = field:match("^(%d+)%.(%d+)(%.?l?)$")
    local decoded = { item = HeardNumber(itemID), price = HeardNumber(price, VENDOR_LIMITS.price),
        limited = mark == ".l" or nil }
    if not (decoded.item and decoded.item > 0 and decoded.price and (mark == "" or mark == ".l")) then return nil end
    return decoded
end

-- A heard V1 or S1 message as { version, npc, side, map, x, y, instance,
-- build, name, items = { { item, price, limited }, ... } }; nil when any
-- part is bad. As with trainer ranks, a build newer than this client's is
-- made up and refused. The name another player wrote is kept only without control
-- characters or "|" (it starts the game's text codes). Whether each item is
-- of the message's kind is left to Core/Vendors.lua, which asks the game.
function Drops.DecodeVendorMessage(text)
    local fields, name = SplitMessage(text)
    if not VENDOR_VERSIONS[fields[1]] or #fields ~= 9 then return nil end
    local decoded = { version = fields[1], npc = HeardNumber(fields[2]), side = fields[3],
        map = HeardNumber(fields[4]), x = HeardNumber(fields[5], COORDINATE_MAX),
        y = HeardNumber(fields[6], COORDINATE_MAX), instance = HeardNumber(fields[7]),
        build = HeardNumber(fields[8], clientBuild), items = {} }
    local isKnownSide = decoded.side == "a" or decoded.side == "h" or decoded.side == "n"
    if not (decoded.npc and decoded.npc > 0 and isKnownSide and decoded.map and decoded.x and decoded.y
        and decoded.instance and decoded.build) then
        return nil
    end
    if name and name ~= "" and #name <= VENDOR_LIMITS.name and not name:find("[%c|]") then decoded.name = name end
    for field in fields[9]:gmatch("[^,]+") do
        local item = DecodeVendorItem(field)
        if not item then return nil end
        decoded.items[#decoded.items + 1] = item
    end
    return #decoded.items > 0 and decoded or nil
end

-- Saves a heard V1 or S1 message's items (Core/Vendors.lua); its heard key
-- and what came of it, or nil when it can't be read.
function Drops.TakeVendorMessage(text)
    local decoded = Drops.DecodeVendorMessage(text)
    if not decoded then return nil end
    return text:match("^[^\t]*"), ns.Vendors.SaveHeard(decoded)
end

-- Other players' drops ------------------------------------------------------

-- Whether a message's sender is this character ("Name" or "Name-Realm").
-- WoW: Forever hands addons only a character's first name ("Ann") while
-- messages arrive from the whole name ("Ann Smith"), so the whole name is
-- learned when one of this copy's own roll calls (Drops.sentByMe) comes
-- back from the guild.
Drops.sentByMe = {}

function Drops:IsMe(sender)
    if sender == self.selfName then return true end
    local name, realm = UnitFullName("player")
    name = Plain(name) or Plain(UnitName("player"))
    if not name then return false end
    if sender == name or Ambiguate(sender, "none") == name or Ambiguate(sender, "short") == name then return true end
    realm = Plain(realm) or GetNormalizedRealmName()
    return realm ~= nil and sender == name .. "-" .. realm
end

-- Catch-up probes -----------------------------------------------------------
-- Mike's characters ask other copies for the finds they saved, one player
-- at a time, by whisper (a dev build's pull, Core/DropPull.lua, picks them
-- from the realm channel's member list, or, when the game gives none, from
-- players who shared finds before):
--     R1:<since>:<random>
-- where since is a time() value. The pull whispers its probes itself, on
-- its own 10-second clock: outside the outbox, its minute between messages
-- and its DAILY_MAX (Mike, 2026-11-09). Only probes from the characters in
-- PROBERS are answered: the game itself sets who sent an addon message, so
-- nobody can send one in another character's name, whatever they read in
-- this file. PROBERS holds keys (Drops:ProberKey) rather than names, so the
-- characters aren't spelled out here. While sharing is on, the answer is
-- the finds saved since then: first the player's own (bosses they looted,
-- quests they reported, vendors and trainers they read, trainer reports
-- already sent to the guild included, as the prober may not have them),
-- then the kills, quests and trainer reports heard from their guild, group
-- and Battle.net friends, each newest first (Mike, 2026-11-12). Many of
-- those finders never meet Mike's characters, so their finds reach him this
-- way. Finds a dev build took by whisper (viaWhisper, see Whispers.Read)
-- aren't in it: they came from Mike's own pull already. As when they were
-- found, only drops, trainer reports and vendor stock that differ from
-- NeedRoll's data go, so a heard kill can go partial when the finder sent
-- it whole. A heard kill carries neither its finder's name nor the credit
-- flag: the prober's copy credits whoever sent the message (see Credit),
-- which would be this player, not the finder; trainer messages never carry
-- a name or sender key, so the prober's copy keys the trainer reports a
-- copy relays to the relaying player (one player relaying two finders
-- counts once). At most Probe.ANSWER_MAX messages (one per kill), sent as
-- ordinary D2, Q1, A1, P1, V1 and S1 messages by whisper to that character,
-- whose copy saves a find it already has only once: kills by their corpse,
-- quests by quest ID. They leave through the outbox (see Whispers),
-- Whispers.GAP seconds apart (Mike, 2026-11-11), after a random wait. A
-- copy answers at most once every Probe.ANSWER_GAP seconds, and never with
-- finds older than Probe.SINCE_MAX seconds. A probe is the only whisper a
-- copy reads. An answered probe also starts a push to the prober (see Push
-- after a pull); other than that no copy whispers unprompted, so nothing
-- reaches Mike's characters unless they asked (Mike, 2026-11-09). Probes
-- heard in the guild or group (older dev builds sent them on the realm
-- channel) aren't answered.
local Probe = {
    VERSION = "R1",
    ANSWER_MAX = 400,           -- messages
    ANSWER_GAP = 15 * 60,       -- seconds
    ANSWER_WAIT = { 5, 60 },    -- seconds, the shortest and longest
    SINCE_MAX = 14 * 24 * 3600, -- seconds
    answeredAt = 0,             -- time() of the last probe this copy answered
    -- Referrals (see below):
    REFERRAL_VERSION = "N1",
    REFERRALS_MAX = 20,         -- names in the one N1 message after an answer
    SHARERS_MAX = 50,           -- players heard sharing kept, the longest silent dropped
    SHARERS_DAYS = 7,           -- days a player heard sharing is kept
}
local PROBERS = { -- Mike's characters, on the beta and planned for launch
    ["41dfb5a8e3d17196"] = true,
    ["d1637117fd532837"] = true,
    ["19db19866e0a2982"] = true,
    ["45b06bc8e40146ee"] = true,
    ["788b8f2125e2a815"] = true,
    ["c93f5ae78bd3f6b7"] = true,
    ["554408375e5ca0e7"] = true,
    ["5a44dd778743a29f"] = true,
    ["56aa84acb85c1a92"] = true,
}

-- 32-bit FNV-1a of a string, in plain arithmetic (no bit library needed).
local function Hash(text, hash)
    for i = 1, #text do
        -- XOR the hash's low byte with the character, one bit at a time.
        local byte, lowByte, xored, bitValue = text:byte(i), hash % 256, 0, 1
        for _ = 1, 8 do
            if lowByte % 2 ~= byte % 2 then xored = xored + bitValue end
            lowByte, byte, bitValue = math.floor(lowByte / 2), math.floor(byte / 2), bitValue * 2
        end
        hash = hash - hash % 256 + xored
        -- hash * 16777619 (2^24 + 403), kept to 32 bits and exact in a double.
        hash = ((hash % 256) * 16777216 + hash * 403) % 4294967296
    end
    return hash
end

-- A character's key: its name in lower case without spaces or hyphens
-- (WoW: Forever names have two parts, "Ann Smith", and the realm, when a
-- sender carries one, follows the last hyphen), hashed forwards and
-- backwards, as 16 hex digits. The realm is left out so a key can be listed
-- before the character exists (a name planned for launch); a namesake on
-- another realm can probe there too, which only makes copies on that realm
-- whisper it finds they may already have sent.
function Drops:ProberKey(name)
    name = name:lower():gsub("[%s%-]", "")
    return ("%08x%08x"):format(Hash(name, 2166136261), Hash(name:reverse(), 2166136261))
end

-- A sender's name without the realm that follows its last hyphen ("Ann
-- Smith-Realm" gives "Ann Smith"); a name with no hyphen as it is.
function Drops.WithoutRealm(name)
    return name:match("^(.*)%-[^%-]*$") or name
end

-- A heard trainer report's or quest's sender as 8 hex digits, saved with the
-- report (Drops.NoteSender) so the scraper can tell two players saying the
-- same from one player saying it twice. It is the first half of the
-- player's prober key: a short hash of the name, which anyone with a list
-- of names to try (a guild roster) could match back to one, and the same on
-- every copy and client language, as the game hands every copy the same
-- name. The realm is left out as for prober keys: a sender carries it or
-- not depending on the way the message came (Battle.net friends' never
-- do), and a namesake on another realm counting as the same player only
-- makes agreeing harder. Nil when the sender isn't known (ANON). Never
-- sent to anyone.
function Drops.SenderKey(sender)
    if type(sender) ~= "string" or sender == "" or sender == ANON then return nil end
    return Drops:ProberKey(Drops.WithoutRealm(sender)):sub(1, 8)
end

-- One player's heard report may be made up, two players saying the same
-- rarely is. So a heard trainer rank or service (Core/Trainers.lua,
-- Core/TrainerShare.lua) and a heard quest (New quests above) keep, for
-- each player heard reporting them, what that player said, under the
-- player's key (Drops.SenderKey, never the name). The saved report itself
-- stays as its own rules keep it, while each player's numbers are kept
-- whether they agree or not, so the scraper can see whether every player
-- on the game's current build says the same. Keys are saved data only: no
-- message carries them. A report a dev build's pull took by whisper is
-- marked viaWhisper: a probe's answer carries what that copy heard as well
-- as its own finds, with no mark telling them apart, so its sender may only
-- be passing on another player's report, and the scraper doesn't count it
-- towards players agreeing. A Drops field, not a local: this file's main
-- chunk is near the 200 locals Lua 5.1 allows.
Drops.SENDERS_MAX = 8 -- players kept per heard report; two agreeing is enough

-- Keeps what the player with key `senderKey` reported (`report`, with its
-- game build, viaWhisper set when taken by whisper) on saved heard report
-- `kept`, over what they reported before, unless that was heard from them
-- directly on the same build and this came by whisper: what they sent
-- themselves counts for more than what they may be passing on.
-- Reports on an older build than another player's are dropped (only the
-- current build counts), and past SENDERS_MAX players new ones aren't kept.
-- Nothing for a sender not known (ANON). Callers pass heard reports only:
-- the player's own read wins over anything heard.
function Drops.NoteSender(kept, senderKey, report)
    if not (kept and senderKey) then return end
    local senders = kept.senders or {}
    kept.senders = senders
    for _, earlier in pairs(senders) do
        if (earlier.build or 0) > report.build then return end
    end
    local count = 0
    for key, earlier in pairs(senders) do
        if (earlier.build or 0) < report.build then senders[key] = nil else count = count + 1 end
    end
    local earlier = senders[senderKey]
    if not earlier and count >= Drops.SENDERS_MAX then return end
    if earlier and report.viaWhisper and not earlier.viaWhisper then return end
    senders[senderKey] = report
end

-- Whether a sender ("Name", "Name-Realm") may probe.
local function IsProber(sender)
    return PROBERS[Drops:ProberKey(sender)] or PROBERS[Drops:ProberKey(Drops.WithoutRealm(sender))] or false
end
-- For Push.Target, defined above PROBERS, and the pull (Core/DropPull.lua).
Drops.IsProber = IsProber

-- Whether a saved kill, quest or trainer report goes in the answer to a
-- probe for finds since `since`.
function Probe.IsAnswerable(find, since)
    return (find.at or 0) >= since and not find.viaWhisper
end
-- For Core/Trainers.lua and Core/TrainerShare.lua, whose saved reports answer probes too.
Drops.IsProbeAnswerable = Probe.IsAnswerable

-- A saved kill, the player's own or heard, as D2 messages: only drops
-- NeedRoll doesn't know, so maybe none. A heard kill keeps its guessed
-- drops and partial mark; its finder's name and credit flag stay out (see
-- above).
local function KillMessages(instanceID, instance, npcID, boss, killKey, kill)
    local items = {}
    for itemID, count in pairs(kill.items) do
        items[#items + 1] = { item = itemID, count = count, guessed = kill.guessed and kill.guessed[itemID] }
    end
    table.sort(items, function(a, b) return a.item < b.item end)
    local new, partial = NewOnly(npcID, items, kill)
    if #new == 0 then return {} end
    return EncodeKill({ type = TYPES[instance.type], instance = instanceID, difficulty = kill.difficulty or 0,
        encounter = boss.encounter, npc = npcID, kill = killKey, build = kill.build, npcName = boss.name,
        instanceName = instance.name, isRelayed = kill.by ~= nil }, new, partial or kill.partial)
end

local function AddKillAnswers(answers, since)
    for instanceID, instance in pairs(ns.db.drops) do
        for npcID, boss in pairs(TYPES[instance.type] and instance.bosses or {}) do
            for killKey, kill in pairs(boss.kills) do
                if Probe.IsAnswerable(kill, since) then
                    for _, text in ipairs(KillMessages(instanceID, instance, npcID, boss, killKey, kill)) do
                        answers[#answers + 1] = { at = kill.at, isHeard = kill.by ~= nil, id = text, text = text }
                    end
                end
            end
        end
    end
end

-- One message per side and class that took the quest, as when it was found.
local function AddQuestAnswers(answers, since)
    for questID, saved in pairs(ns.db.newQuests) do
        if Probe.IsAnswerable(saved, since) and not Listed(questID, saved) then
            local sides = next(saved.sides or {}) and saved.sides or { n = true }
            local classes = next(saved.classes or {}) and saved.classes or { [0] = true }
            for side in pairs(sides) do
                for class in pairs(classes) do
                    local report = { quest = questID, side = side, class = class, level = 0, giver = "-",
                        giverID = 0, map = 0, x = 0, y = 0, instance = 0 }
                    for _, key in ipairs(QUEST_FIELDS) do
                        if saved[key] ~= nil then report[key] = saved[key] end
                    end
                    answers[#answers + 1] = { at = saved.at, isHeard = saved.by ~= nil, id = QuestKey(report),
                        text = EncodeQuest(report) }
                end
            end
        end
    end
end

-- The vendors the player read since then, as V1 and S1 messages of the
-- items NeedRoll still doesn't know they sell (Core/Vendors.lua), and the
-- trainer reports the player read or heard since then, as A1 and P1
-- messages of what still differs from NeedRoll's data (Core/Trainers.lua,
-- Core/TrainerShare.lua).
local function AddVendorAndTrainerAnswers(answers, since)
    for _, reader in ipairs({ ns.Vendors, ns.Trainers, ns.TrainerShare }) do
        for _, answer in ipairs(reader.Answers(since)) do answers[#answers + 1] = answer end
    end
end

-- The time a heard probe asks for finds since, or nil when it doesn't say.
local function ProbeSince(text)
    return HeardNumber(text:match("^R1:(%d+)"))
end

-- The player's own finds before heard ones, each newest first.
function Probe.IsAnsweredBefore(answer, other)
    local isHeard, isOtherHeard = answer.isHeard == true, other.isHeard == true
    if isHeard ~= isOtherHeard then return isOtherHeard end
    return answer.at > other.at
end

-- Referrals --------------------------------------------------------------------
-- Mike's pull (Core/DropPull.lua) can only ask players it knows run
-- NeedRoll, and the game gives it few of their names, so copies tell it
-- whom they heard share finds (Mike, 2026-11-12). While Share drops is on, a
-- copy keeps the name of each player it heard send a find (D2, Q1, T1, A1,
-- P1, V1 or S1) in its guild or group, as the game gave it ("Ann
-- Smith-Realm"), for Probe.SHARERS_DAYS days, the newest Probe.SHARERS_MAX
-- of them. Never Battle.net friends (the game may not name their character
-- and they can play on any realm), never a whisper's sender, never a
-- PROBERS character or the player. After it answers a PROBERS character's
-- probe it whispers that character one more message, the answer's last:
--     N1:<name>\t<name>...
-- the newest Probe.REFERRALS_MAX names that fit the game's limit, so the
-- pull can ask them too. It goes through the outbox like the answer (its
-- pace, the whisper gap, DAILY_MAX), and no one else is ever sent the
-- names. Copies before v1.8.0 don't know the letter N, so an N1 never makes
-- them think they are outdated (see Outdated). Saved in
-- NeedRollDB.dropSharers = { [name] = { at = <time() last heard> } }; with
-- Share drops off nothing is kept and the list is forgotten (SetChannel, and
-- as the game saves).

-- Notes that `sender` sent a find in the guild or group.
function Probe.NoteSharer(sender)
    if not Drops:ChannelOn() or IsProber(sender) then return end
    local sharers = type(ns.db.dropSharers) == "table" and ns.db.dropSharers or {}
    ns.db.dropSharers = sharers
    sharers[sender] = { at = time() }
    Probe.ForgetOldSharers(sharers)
end

-- Forgets the players last heard sharing more than SHARERS_DAYS days ago,
-- and the longest silent past SHARERS_MAX (players are noted one at a
-- time, so one at most).
function Probe.ForgetOldSharers(sharers)
    local oldest = time() - Probe.SHARERS_DAYS * 24 * 3600
    for name, sharer in pairs(sharers) do
        if type(sharer) ~= "table" or type(sharer.at) ~= "number" or sharer.at < oldest then sharers[name] = nil end
    end
    DropOldest(sharers, Probe.SHARERS_MAX)
end

-- The N1 message naming the players heard sharing, newest first, and how
-- many it names; nil when there is nobody to name.
function Probe.ReferralText()
    local sharers = ns.db.dropSharers
    if type(sharers) ~= "table" then return nil end
    Probe.ForgetOldSharers(sharers)
    local names = {}
    for name in pairs(sharers) do names[#names + 1] = name end
    table.sort(names, function(a, b) return sharers[a].at > sharers[b].at end)
    local text, count = Probe.REFERRAL_VERSION .. ":", 0
    for _, name in ipairs(names) do
        if count == Probe.REFERRALS_MAX then break end
        local longer = count == 0 and text .. name or text .. "\t" .. name
        if #longer > MESSAGE_MAX then break end
        text, count = longer, count + 1
    end
    if count == 0 then return nil end
    return text, count
end

-- Queues the N1 message for `prober`. The message log of a dev build keeps
-- how many players it named, not their names (see Drops.Log).
function Probe.QueueReferral(text, count, prober)
    local entry = Queue(text, "WHISPER", nil, "referral", nil, prober)
    if entry then entry.logText = ("%s:%d"):format(Probe.REFERRAL_VERSION, count) end
end

-- As the game saves, the players silent for SHARERS_DAYS days go, and all of
-- them when Share drops is off, so no stale names stay in the saved file.
ns:On("PLAYER_LOGOUT", function()
    if not ns.db then return end
    if not Drops:ChannelOn() then
        ns.db.dropSharers = nil
    elseif type(ns.db.dropSharers) == "table" then
        Probe.ForgetOldSharers(ns.db.dropSharers)
    end
end)

-- Queues the answer to a whispered probe, by whisper back to `sender`, the
-- prober, with the referral last (see Referrals), and starts a push to
-- them; true when it was answered.
local function Answer(text, sender)
    local since, now = ProbeSince(text), time()
    if not (since and IsProber(sender) and Drops:ChannelOn()) or now - Probe.answeredAt < Probe.ANSWER_GAP then
        return false
    end
    Probe.answeredAt = now
    Push.Start(sender)
    since = math.max(since, now - Probe.SINCE_MAX)
    local answers = {}
    AddKillAnswers(answers, since)
    AddQuestAnswers(answers, since)
    AddVendorAndTrainerAnswers(answers, since)
    table.sort(answers, Probe.IsAnsweredBefore)
    local room = math.min(Probe.ANSWER_MAX, OUTBOX_MAX - #ns.db.dropOutbox)
    local referral, referralCount = Probe.ReferralText()
    C_Timer.After(math.random(Probe.ANSWER_WAIT[1], Probe.ANSWER_WAIT[2]), function()
        for i = 1, math.min(room, #answers) do
            Queue(answers[i].text, "WHISPER", answers[i].id, "answer", nil, sender)
        end
        if referral then Probe.QueueReferral(referral, referralCount, sender) end
    end)
    return true
end

-- Roll call ------------------------------------------------------------------
-- So Mike can see roughly how many players run NeedRoll right now, a PROBERS
-- character's dev build can ask its guild who's there (see Drops:RollCall;
-- the realm channel's member count says how many share drops):
--     U1:<random>
-- Every copy in the guild that hears it answers there with its version:
--     U1:<random>:<version>
-- The text carries no name, but the game shows every listener the sender's
-- character, as for any message in the guild.
-- The answer goes through the outbox after a random wait, so it queues
-- behind any drops waiting there and leaves at most one message a minute.
-- A copy answers at most once every RollCall.GAP seconds, so nobody can use
-- roll calls to make every copy send messages. With "Share drops" off
-- nothing is sent, so a copy doesn't answer.
local RollCall = {
    VERSION = "U1",
    GAP = 30 * 60,  -- seconds
    answeredAt = 0, -- time() of the last roll call this copy answered
}

-- Queues the answer to a roll call heard in the guild, for the guild; true
-- when it was answered.
local function AnswerRollCall(text, sender)
    local callID, now = text:match("^U1:(%d+)$"), time()
    if not (callID and #callID <= 10 and IsProber(sender) and Drops:ChannelOn())
        or now - RollCall.answeredAt < RollCall.GAP then
        return false
    end
    RollCall.answeredAt = now
    local answer = ("%s:%s:%s"):format(RollCall.VERSION, callID, VersionTag())
    C_Timer.After(math.random(Probe.ANSWER_WAIT[1], Probe.ANSWER_WAIT[2]), function()
        Queue(answer, "GUILD", nil, "answer")
    end)
    return true
end

local function SaveWhenLoaded(drop)
    ns.Items:Load(drop.item, function() if Wanted(drop.item) then Save(drop) end end)
end

-- Reading heard messages: each returns the message's key in the heard
-- list and what came of it: "new", "known" (already saved), "waiting"
-- (judged once the item loads), "skipped" (not an item NeedRoll keeps) or
-- "listed" (a quest, trainer ranks or vendor stock NeedRoll's data has);
-- nil when it can't be read. `isWhispered` marks a find a dev build took
-- by whisper (see Whispers.Read).
local function TakeKill(text, sender, isWhispered)
    local drops, key = DecodeKill(text)
    if not drops then return nil end
    local isNew, isWanted, isWaiting = false, false, false
    for _, drop in ipairs(drops) do
        drop.by = drop.credit and sender or ANON
        drop.viaWhisper = isWhispered
        local want = Wanted(drop.item)
        if want then
            isWanted = true
            isNew = Save(drop) or isNew
        elseif want == nil then
            isWaiting = true
            SaveWhenLoaded(drop)
        end
    end
    if not isWanted then return key, isWaiting and "waiting" or "skipped" end
    return key, isNew and "new" or "known"
end

local function TakeOldDrop(text)
    local drop = Decode(text)
    if not drop then return nil end
    drop.by = ANON
    local key = drop.kill .. ":" .. drop.item
    local want = Wanted(drop.item)
    if want == nil then
        SaveWhenLoaded(drop)
        return key, "waiting"
    end
    if not want then return key, "skipped" end
    return key, Save(drop) and "new" or "known"
end

local function TakeQuestReport(text, sender, isWhispered)
    local report = DecodeQuest(text)
    if not report then return nil end
    if ns.Data:KnownQuest(report.quest) and not Changed(report) then return QuestKey(report), "listed" end
    report.by, report.viaWhisper = ANON, isWhispered
    local isNew = SaveQuest(report)
    local saved = ns.db.newQuests[report.quest]
    -- Only a quest saved as heard keeps its senders (the player's own read
    -- wins), and only with a build: DecodeQuest reads one newer than this
    -- client's as unknown, as it is made up and would push every other
    -- sender out (see Drops.NoteSender). Rewards count only when the
    -- sender saw the quest window.
    if saved and saved.by and report.build then
        Drops.NoteSender(saved, Drops.SenderKey(sender), { build = report.build,
            level = report.level > 0 and report.level or nil,
            rewards = report.giver ~= "-" and report.rewards or nil, viaWhisper = isWhispered })
    end
    return QuestKey(report), isNew and "new" or "known"
end

local TAKE = { [KILL_VERSION] = TakeKill, [DROP_VERSION] = TakeOldDrop, [QUEST_VERSION] = TakeQuestReport,
    [TRAINER_VERSION] = Drops.TakeTrainerRanks, T1 = Drops.TakeTrainerRanks,
    [Drops.TRAINER_SERVICES_VERSION] = Drops.TakeTrainerServices,
    [VENDOR_RECIPES_VERSION] = Drops.TakeVendorMessage, [VENDOR_ITEMS_VERSION] = Drops.TakeVendorMessage }
-- The finds a pull's whispered answers and pushes, and Battle.net friends, carry
-- (T1 only from copies before v1.8.0).
local FIND_KINDS = { [KILL_VERSION] = true, [QUEST_VERSION] = true, [TRAINER_VERSION] = true, T1 = true,
    [Drops.TRAINER_SERVICES_VERSION] = true, [VENDOR_RECIPES_VERSION] = true, [VENDOR_ITEMS_VERSION] = true }

-- A NeedRoll message heard by whisper. A copy reads one thing that way: a
-- PROBERS character's probe, answered by whisper (see Catch-up probes). A
-- dev build's pull (Core/DropPull.lua) also takes the D2, Q1, T1, A1, P1,
-- V1 and S1 answers and pushes (see Push after a pull) of the players it asked
-- (Drops.TakesWhisperFrom), through the same format check and readers as
-- any heard message, and marks kills, quests and trainer reports viaWhisper,
-- and their N1 referrals (Drops.OnReferral, see Referrals). Every other
-- whisper is ignored.
function Whispers.Read(text, sender)
    local kind = text:match("^(%u%d):")
    if kind == Probe.VERSION then
        local answered = Answer(text, sender)
        if Drops.Log and IsProber(sender) then
            Drops.Log("in", "WHISPER", sender, text, answered and "probe" or "probe-ignored")
        end
        return
    end
    if not (Drops.TakesWhisperFrom and Drops.TakesWhisperFrom(sender)) then return end
    Drops:NoteFormat(text, "WHISPER", sender)
    if kind == Probe.REFERRAL_VERSION and Drops.OnReferral then return Drops.OnReferral(text, sender) end
    if not FIND_KINDS[kind] then return end
    local id, status = TAKE[kind](text, sender, true)
    if Drops.Log then Drops.Log("in", "WHISPER", sender, text, id and status or "bad") end
end

-- The character a friend's game account plays, as a find's sender, or ANON
-- when the game doesn't say.
function BattleNet.CharacterName(gameAccountID)
    local info = C_BattleNet.GetGameAccountInfoByID(gameAccountID)
    return info and NilIfEmpty(Plain(info.characterName)) or ANON
end

-- A NeedRoll message from a Battle.net friend's game (see Battle.net
-- friends). Only finds, D2 kills, Q1 quests, A1 (and older T1) and P1
-- trainer reports and V1 and S1 vendor stock, are
-- read, through the same format check and readers as any heard message,
-- and kept as heard in the guild; nothing is answered or passed on. With Share drops off they are
-- still kept, as the guild's are. A friend's game can send far longer
-- texts than the 255 bytes of other addon messages, so one longer than any
-- copy sends (MESSAGE_MAX) is ignored.
function BattleNet.Read(prefix, text, _, senderID)
    text, senderID = Plain(text), Plain(senderID)
    if prefix ~= PREFIX or not ns.db or type(text) ~= "string" or not senderID then return end
    if #text > MESSAGE_MAX then return end
    -- All Battle.net friends count as one sender of a newer format: a game
    -- account ID can change each time a friend logs in, and the character
    -- name can be unreadable (ANON), so friends alone can't silence a copy.
    Drops:NoteFormat(text, "BNET", "Battle.net")
    local kind = text:match("^(%u%d):")
    if not FIND_KINDS[kind] then return end
    local sender = BattleNet.CharacterName(senderID)
    local id, status = TAKE[kind](text, sender)
    if Drops.Log then Drops.Log("in", "BNET", sender, text, id and status or "bad") end
end

ns:On("BN_CHAT_MSG_ADDON", BattleNet.Read)

-- Addon messages heard in the guild or group, and whispers (see
-- Whispers.Read). Custom channels are never read: the live servers carry no
-- addon messages there, and no copy sends on the realm channel.
ns:On("CHAT_MSG_ADDON", function(prefix, text, channel, sender)
    text, sender = Plain(text), Plain(sender)
    if prefix ~= PREFIX or not ns.db or type(text) ~= "string" or not sender or channel == "CHANNEL" then return end
    if channel == "WHISPER" then return Whispers.Read(text, sender) end
    if Drops.sentByMe[text] then Drops.selfName = sender end
    local own = Drops:IsMe(sender)
    if Drops.Heard and Drops.Heard(text, channel, sender, own) then return end
    if not own then Drops:NoteFormat(text, channel, sender) end
    local kind = text:match("^(%u%d):")
    if kind == Probe.VERSION then
        -- Probes are answered only by whisper (see Catch-up probes).
        if Drops.Log and not own then Drops.Log("in", channel, sender, text, "probe-ignored") end
        return
    end
    if kind == RollCall.VERSION then
        if channel == "GUILD" and not own then AnswerRollCall(text, sender) end
        return
    end
    if own or not TAKE[kind] then return end
    -- A dev build's pull (Core/DropPull.lua) keeps who sends finds, to ask them by whisper.
    if Drops.OnFindsHeard then Drops.OnFindsHeard(kind, channel, sender) end
    local heardList = HEARD_LIST[channel]
    local id, status
    if heardList then id, status = TAKE[kind](text, sender) end
    if not id then
        if Drops.Log then Drops.Log("in", channel, sender, text, "bad") end
        return
    end
    heard[heardList][id] = true
    if FIND_KINDS[kind] then Probe.NoteSharer(sender) end
    if Drops.Log then Drops.Log("in", channel, sender, text, status) end
end)

ns:On("PLAYER_LOGIN", function()
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    -- Releases before NRDropTalk saved when the realm channel last refused
    -- their messages, to send nothing there for a day; nothing is sent there
    -- any more, so old saves forget it.
    ns.db.channelRefusedAt = nil
    -- After the game's own channels (General, Trade, ...) have been joined,
    -- so the realm channel doesn't take one of their numbers, and when the
    -- game has rejoined it ahead of them anyway, it moves behind them (see
    -- Chat number). While sharing is off (see ChannelOn) this only leaves it.
    C_Timer.After(15, function()
        JoinChannels()
        keepJoined = true
        ChatNumber.MoveChannelsLast()
        C_Timer.NewTicker(600, KeepJoined)
    end)
    -- Carry on with what was left unsent last session.
    if type(ns.db.dropNewer) == "table" and ns.db.dropNewer.version ~= ns.version then ns.db.dropNewer = nil end
    if #ns.db.dropOutbox > 0 and not isSending and not Outdated() then
        isSending = true
        C_Timer.After(20, Pump)
    end
end)

--[==[@debug@
-- /nr droptalk opens the drop talk window (UI/DropTalk.lua): every drop
-- message sent and heard, and every saved drop. /nr droptalk list prints the
-- saved drops by place, boss and item (with how many of the boss's kills it
-- came from and who reported it); /nr droptalk clear empties the saved
-- drops, the outbox and the message log. Local checkouts only: a released
-- build keeps no message log and treats /nr droptalk as plain /nr.
Drops.available = true
Drops.keepAll = true
-- The PROBERS list, so the smoke tests can add a made-up character to it.
Drops.probers = PROBERS
-- For the pull (Core/DropPull.lua): whether this copy stopped sending for a
-- newer format (see Outdated), noting a whisper it sends, so the game's
-- "not online" line about it is hidden for WHISPER_BOUNCE_WAIT seconds (see
-- Offline target), how long copies push to a prober (see Push after a
-- pull), the kind of a referral (see Referrals), and the channels whose
-- member lists it reads, which it joins or leaves at once when its
-- character starts or stops pulling (see Joining).
Drops.IsOutdated = Outdated
Drops.NoteWhisper = Whispers.Note
Drops.WHISPER_BOUNCE_WAIT = Whispers.BOUNCE_WAIT
Drops.PUSH_DAYS = Push.DAYS
Drops.REFERRAL_VERSION = Probe.REFERRAL_VERSION
Drops.MemberListChannels = MemberListChannels
Drops.KeepChannels = KeepJoined

-- The names an N1 referral carries (see Referrals), for the pull; nil when
-- the message isn't one. A name with a control character or an escape
-- sequence ("|"), or longer than any character's name with its realm, is
-- left out: the pull whispers these names and keeps them.
function Drops.DecodeReferral(text)
    local REFERRED_NAME_MAX = 64 -- bytes
    local list = text:match("^" .. Probe.REFERRAL_VERSION .. ":(.+)$")
    if not list then return nil end
    local names, seen = {}, {}
    for name in (list .. "\t"):gmatch("([^\t]*)\t") do
        local isPlain = name ~= "" and #name <= REFERRED_NAME_MAX and not name:find("[%c|]")
        if isPlain and not seen[name] and #names < Probe.REFERRALS_MAX then
            seen[name] = true
            names[#names + 1] = name
        end
    end
    return names
end

-- Forgets this session's password requests (see Joining), so the smoke
-- tests can join the realm channel again after testing one.
function Drops.ForgetPasswordRequest()
    wipe(passwordAskedChannels)
end
-- Starts the session's count of chat number moves over, so the smoke tests
-- can test the cap (see Chat number).
function Drops.ForgetChatNumberMoves()
    ChatNumber.moves = 0
end

-- The message log, newest last, in NeedRollDB.dropTalk: { at = <time()>,
-- dir = "in" or "out", chat = "GUILD", "PARTY", ..., from = "Name-Realm"
-- (heard ones), text = the message, status }. status is "own" or "relay"
-- for sent ones, and "new", "known" (already saved) or "bad" (not a drop
-- message this version can read) for heard ones. result is
-- SendAddonMessage's answer for sent ones (0 = sent; see
-- Enum.SendAddonMessageResult). Logs from older dev builds can also hold
-- realm channel pings, "echo" (one of the player's own realm channel
-- messages coming back) and "listen" (heard in their listen mode). An N1
-- referral is logged without its names, as "N1:<names>" when sent and, by
-- the pull, "N1:<names>:<new to the pull>" when taken (status "referral").
local LOG_MAX = 2000

function Drops.Log(dir, chat, from, text, status, result)
    local log = ns.db.dropTalk or {}
    ns.db.dropTalk = log
    if type(result) == "boolean" then result = result and 0 or 9 end
    table.insert(log, { at = time(), dir = dir, chat = chat, from = from, text = text, status = status,
        result = result })
    while #log > LOG_MAX do table.remove(log, 1) end
    if ns.DropTalkWindow then ns.DropTalkWindow:Refresh() end
end

-- The name of a SendAddonMessage result code ("Success", "InvalidChannel", ...).
function Drops:ResultName(result)
    return AddonMessages.ResultName(result) or tostring(result)
end

-- A true or false answer reads as 0 (sent) or 9, as Drops.Log stores them.
local function SendAnswerText(result)
    if type(result) ~= "number" then result = result == false and 9 or 0 end
    return Drops:ResultName(result)
end

local isUnlistedWarned = false -- the "won't answer" line was printed this session

function Drops.Heard(text, _, sender, own)
    -- Roll call answers are counted, not logged: the log would keep names.
    if text:match("^U1:%d+:") then
        Drops:CountRollCallAnswer(text, sender)
        return true
    end
    -- The player's own roll call coming back: say so (once a session) when
    -- other copies won't answer this character.
    if own and not isUnlistedWarned and text:match("^U1:%d+$") and not IsProber(sender) then
        isUnlistedWarned = true
        ns:Print(("Other copies won't answer %s yet. Its key, for PROBERS in Core/Drops.lua: %s"):format(sender,
            Drops:ProberKey(Drops.WithoutRealm(sender))))
    end
end

-- The dev command's roll call goes at once instead of through the outbox,
-- but not when the outbox couldn't send either:
-- after throttled answers stopped sending this session, once a newer
-- message format was heard (see Outdated), or during a lockdown. Then this
-- prints why `what` wasn't sent and says true.
local function RefusesDevSend(what)
    local reason
    if AddonMessages.isStoppedThisSession then
        reason = "the game said throttled too often this session; /reload to send again"
    elseif Outdated() then
        reason = "other players' copies send a newer message format; update NeedRoll"
    elseif AddonMessages:WaitsOnLockdown() then
        reason = "the game is blocking addon messages right now"
    end
    if reason then ns:Print(("%s not sent: %s."):format(what, reason)) end
    return reason ~= nil
end

-- While drop sharing is switched off for everyone (see Switch) the dev
-- commands send nothing either: this says so and says true.
local function RefusesWhileSwitchedOff()
    if Drops.isSharingEnabled then return false end
    ns:Print("Drop sharing is switched off in this NeedRoll (Drops.isSharingEnabled in Core/Drops.lua),"
        .. " so nothing is sent.")
    return true
end

-- /nr users prints how many players are in the realm channel (every copy
-- with Share drops on, of the releases that join NRDropTalk; the game
-- counts them, nothing is sent), then sends a roll call (see Roll call
-- above) to the guild and, RollCall.WAIT seconds later, prints how many
-- copies answered and on which versions; answers arriving later still
-- count. /nr users history prints past roll
-- calls, kept in NeedRollDB.rollCalls (newest last, at most RollCall.SAVED_MAX):
-- { at = <time()>, id = "<random>", where = "<realm> <faction>",
-- answers = <count>, versions = { ["v0.17.0"] = <count> } }. Only counts are
-- kept. Who answered is held for this session only, as hashed keys
-- (Drops:ProberKey), so each player counts once.
RollCall.WAIT = 180 -- seconds
RollCall.SAVED_MAX = 100
RollCall.open = nil -- { record = <the NeedRollDB.rollCalls entry>, answerers = { [key] = true } }

-- The realm and faction a roll call was made from, as its history lists it.
local function RollCallWhere()
    return ("%s %s"):format(GetNormalizedRealmName() or "?", UnitFactionGroup("player") or "?")
end

-- "12 answered (v0.17.0 10, v0.16.2 2)", most used version first.
local function RollCallSummary(record)
    local versions = {}
    for version, count in pairs(record.versions) do versions[#versions + 1] = { name = version, count = count } end
    table.sort(versions, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.name > b.name
    end)
    local parts = {}
    for i, version in ipairs(versions) do parts[i] = version.name .. " " .. version.count end
    local breakdown = #parts > 0 and " (" .. table.concat(parts, ", ") .. ")" or ""
    return ("%d answered%s"):format(record.answers, breakdown)
end

-- Counts a heard answer to this copy's open roll call, once per player
-- (Drops.Heard passes every answer here).
function Drops:CountRollCallAnswer(text, sender)
    local callID, version = text:match("^U1:(%d+):(v[%w%.%-]+)$")
    local openCall = RollCall.open
    if not (callID and openCall and openCall.record.id == callID) then return end
    local key = Drops:ProberKey(sender)
    if openCall.answerers[key] then return end
    openCall.answerers[key] = true
    local record = openCall.record
    version = version:sub(1, 24)
    record.answers = record.answers + 1
    record.versions[version] = (record.versions[version] or 0) + 1
end

-- The newest roll call this account made from the realm and faction it's on now.
local function LastRollCallHere()
    local calls, where = ns.db.rollCalls or {}, RollCallWhere()
    for i = #calls, 1, -1 do
        if calls[i].where == where then return calls[i] end
    end
end

-- The row of `channel` (CHANNEL, or another of MemberListChannels) in the
-- game's channel list (Social > Chat Channels), or nil when this copy isn't
-- in it or the list doesn't show it. Dot functions, as the pull
-- (Core/DropPull.lua) reads the channels' members too.
function Drops.ChannelListIndex(channel)
    if not JoinedNumber(channel) then return nil end
    for index = 1, GetNumDisplayChannels() do
        local name, isHeader = GetChannelDisplayInfo(index)
        if not isHeader and OurChannel(name) == channel then return index end
    end
end

-- How many players the game says are in `channel`, or nil when it hasn't
-- said.
function Drops.ChannelMemberCount(channel)
    local index = Drops.ChannelListIndex(channel)
    if not index then return nil end
    local count = Plain((select(5, GetChannelDisplayInfo(index))))
    return type(count) == "number" and count or nil
end

local MEMBER_COUNT_WAIT = 3 -- seconds for the game to send a count it didn't have

local function PrintMemberCount(count)
    if not count then
        ns:Print("The game didn't give the realm channel's member count. Social > Chat Channels lists its members.")
        return
    end
    ns:Print(("NRDropTalk on %s: %d players with NeedRoll and Share drops on, you included.")
        :format(RollCallWhere(), count))
end

-- Prints the realm channel's member count. The game may send a channel's
-- count only once it's picked in its channel list, so that's done when the
-- count isn't there yet (it only changes which channel the list shows).
function Drops:PrintChannelMembers()
    local index = Drops.ChannelListIndex(CHANNEL)
    if not index then
        ns:Print("The game doesn't list the realm channel, so there's no member count.")
        return
    end
    local count = Drops.ChannelMemberCount(CHANNEL)
    if count then return PrintMemberCount(count) end
    SetSelectedDisplayChannel(index)
    C_Timer.After(MEMBER_COUNT_WAIT, function() PrintMemberCount(Drops.ChannelMemberCount(CHANNEL)) end)
end

function Drops:RollCall()
    if RefusesWhileSwitchedOff() then return end
    self:PrintChannelMembers()
    local last = LastRollCallHere()
    local wait = last and last.at + RollCall.GAP - time()
    if wait and wait > 0 then
        ns:Print(("Copies answer one roll call every %d minutes; try again in %d. The last one (%s): %s.")
            :format(RollCall.GAP / 60, math.ceil(wait / 60), date("%H:%M", last.at), RollCallSummary(last)))
        return
    end
    self:SendRollCall()
end

-- Sends a roll call to the guild.
function Drops:SendRollCall()
    if RefusesDevSend("Roll call") then return end
    if not IsInGuild() then
        ns:Print("No roll call sent: not in a guild.")
        return
    end
    local callID = tostring(math.random(100000, 999999))
    local text = RollCall.VERSION .. ":" .. callID
    Drops.sentByMe[text] = true
    local result, refusal = AddonMessages:Send(text, "GUILD")
    Drops.Log("out", "GUILD", nil, text, "roll call", result)
    if refusal then
        ns:Print(("The game didn't send the roll call to the guild: %s."):format(SendAnswerText(result)))
        return
    end
    local record = { at = time(), id = callID, where = RollCallWhere(), answers = 0, versions = {} }
    ns.db.rollCalls = ns.db.rollCalls or {}
    table.insert(ns.db.rollCalls, record)
    while #ns.db.rollCalls > RollCall.SAVED_MAX do table.remove(ns.db.rollCalls, 1) end
    RollCall.open = { record = record, answerers = {} }
    ns:Print(("Roll call sent to the guild; counting answers for %d minutes."):format(RollCall.WAIT / 60))
    C_Timer.After(RollCall.WAIT, function()
        ns:Print(("Roll call on %s: %s, not counting you. Late answers still count in /nr users history.")
            :format(record.where, RollCallSummary(record)))
    end)
end

function Drops:PrintRollCalls()
    local calls = ns.db.rollCalls or {}
    if #calls == 0 then
        ns:Print("No roll calls yet: /nr users sends one.")
        return
    end
    for i = math.max(1, #calls - 19), #calls do
        local call = calls[i]
        ns:Print(("%s %s: %s"):format(date("%m/%d %H:%M", call.at), call.where, RollCallSummary(call)))
    end
end

-- /nr droptalk outbox: how many messages wait to be sent, and what the
-- game's addon message lockdown checks answer right now.
function Drops:OutboxStatus()
    local sent = ns.db.dropSent
    ns:Print(("Outbox: %d waiting%s; %d of %d sent today%s%s."):format(#ns.db.dropOutbox,
        isSending and ", sending" or "", sent and sent.day == date("%Y-%m-%d") and sent.n or 0, DAILY_MAX,
        AddonMessages.isStoppedThisSession and "; stopped (throttled)" or "",
        Outdated() and "; stopped (newer format heard from other players)" or ""))
    if ns.DropPull then ns.DropPull.PrintStatus() end
    for _, name in ipairs(AddonMessages.LOCKDOWN_CHECKS) do
        local answer = { pcall(C_ChatInfo[name]) }
        for i = 1, #answer do answer[i] = tostring(answer[i]) end
        ns:Print(("C_ChatInfo.%s(): %s"):format(name, table.concat(answer, ", ", 2)
            .. (answer[1] == "false" and " (error)" or "")))
    end
end

-- /nr droptalk key <name> prints a name's key, for names not yet in use.
function Drops:PrintKey(name)
    if not name or name == "" then
        ns:Print("Usage: /nr droptalk key <character name>")
        return
    end
    ns:Print(("Key for %s: %s"):format(name, self:ProberKey(name)))
end

-- Each saved drop's link, quality, binding and class, for the scraper's
-- ingest (messages carry only item IDs): NeedRollDB.dropItems[itemID] = {
-- link, quality, bind, class } where bind is the game's Enum.ItemBind (1 =
-- on pickup) and class its item class (12 = quest).
function Drops.NoteItem(itemID)
    local items = ns.db.dropItems or {}
    ns.db.dropItems = items
    if items[itemID] then return end
    ns.Items:Load(itemID, function()
        local _, link, quality, _, _, _, _, _, _, _, _, class, _, bind = C_Item.GetItemInfo(itemID)
        if link then items[itemID] = { link = link, quality = quality, bind = bind, class = class } end
    end)
end

-- How many of the boss's kills are saved (its own and other players'), for
-- the boss names in the loot lists. Kills nobody looted aren't counted.
function Drops:KillCount(npcID)
    local killCount = 0
    for _, instance in pairs(ns.db and ns.db.drops or {}) do
        local boss = instance.bosses[npcID]
        if boss then
            for _ in pairs(boss.kills) do killCount = killCount + 1 end
        end
    end
    return killCount
end

-- A logged message's drops, one per item: a D1 message's one, or every
-- item of a D2 kill; nil when it isn't a drop message.
function Drops:DecodeDrops(text)
    local one = Decode(text)
    if one then return { one } end
    return (DecodeKill(text))
end

-- A logged message's quest fields (nil when it isn't a quest message).
function Drops:DecodeQuest(text)
    return DecodeQuest(text)
end

-- A logged probe's time (nil when it isn't a readable probe).
function Drops:ProbeSince(text)
    return ProbeSince(text)
end

-- Every saved new quest as { quest, title, level, sub, at, listed }, newest
-- first; listed when NeedRoll's data has it since.
function Drops:QuestRows()
    local rows = {}
    for questID, quest in pairs(ns.db.newQuests) do
        rows[#rows + 1] = { quest = questID, title = quest.title, level = quest.level, at = quest.at or 0,
            saved = quest, listed = Listed(questID, quest) }
    end
    table.sort(rows, function(a, b)
        if a.at ~= b.at then return a.at > b.at end
        return a.quest < b.quest
    end)
    return rows
end

-- Whether NeedRoll lists the item: "boss" (in this boss's loot), "elsewhere"
-- (in some other dungeon or raid list) or "no".
function Drops:Listed(itemID, npcID)
    local listed = ns.Data:ListedDrops()
    if npcID and listed.byNpc[npcID] and listed.byNpc[npcID][itemID] then return "boss" end
    return listed.any[itemID] and "elsewhere" or "no"
end

local function ReporterName(kill)
    if not kill.by then return "you" end
    return kill.by == ANON and "anonymous" or Ambiguate(kill.by, "none")
end

-- A boss's kills per item: { [itemID] = { count, kills, by = sorted names,
-- names = a set, last = newest time() } }, and its kill count.
local function TallyBossItems(boss)
    local byItem, killCount = {}, 0
    for _, kill in pairs(boss.kills) do
        killCount = killCount + 1
        for itemID, count in pairs(kill.items) do
            local tally = byItem[itemID] or { count = 0, kills = 0, names = {}, last = 0 }
            byItem[itemID] = tally
            tally.count, tally.kills = tally.count + count, tally.kills + 1
            tally.names[ReporterName(kill)] = true
            tally.last = math.max(tally.last, kill.at or 0)
        end
    end
    for _, tally in pairs(byItem) do
        tally.by = {}
        for name in pairs(tally.names) do table.insert(tally.by, name) end
        table.sort(tally.by)
    end
    return byItem, killCount
end

-- Every saved drop as { item, count, kills, total, by = { names }, boss,
-- npc, place, last }, one per boss and item, newest first.
function Drops:SavedRows()
    local rows = {}
    for instanceID, instance in pairs(ns.db.drops) do
        for npcID, boss in pairs(instance.bosses) do
            local byItem, killCount = TallyBossItems(boss)
            for itemID, row in pairs(byItem) do
                row.item, row.npc, row.total = itemID, npcID, killCount
                row.boss = boss.name or ("NPC " .. npcID)
                row.place = instance.name or ("Instance " .. instanceID)
                table.insert(rows, row)
            end
        end
    end
    table.sort(rows, function(a, b)
        if a.last ~= b.last then return a.last > b.last end
        return a.item < b.item
    end)
    return rows
end

local function ItemText(itemID)
    local link = select(2, C_Item.GetItemInfo(itemID))
    if not link then C_Item.RequestLoadItemDataByID(itemID) end
    return (link or ("item " .. itemID)) .. " |cff808080" .. itemID .. "|r"
end

local function SortedByName(map, nameOf)
    local list = {}
    for id, entry in pairs(map) do table.insert(list, { id = id, entry = entry, name = nameOf(id, entry) }) end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local function PrintBoss(npcID, bossName, boss)
    local byItem, killCount = TallyBossItems(boss)
    print(("    %s |cff808080npc %d%s|r - %d kill%s"):format(ns.Literal(bossName), npcID,
        boss.encounter and (", encounter " .. boss.encounter) or "", killCount, killCount == 1 and "" or "s"))
    local itemIDs = {}
    for itemID in pairs(byItem) do table.insert(itemIDs, itemID) end
    table.sort(itemIDs)
    for _, itemID in ipairs(itemIDs) do
        local tally = byItem[itemID]
        print(("      %s x%d - %d of %d kills - from %s"):format(ItemText(itemID), tally.count, tally.kills,
            killCount, table.concat(tally.by, ", ")))
    end
end

function Drops:Print()
    local drops = ns.db.drops
    local killCount, itemCount = 0, 0
    for _, instance in pairs(drops) do
        for _, boss in pairs(instance.bosses) do
            for _, kill in pairs(boss.kills) do
                killCount = killCount + 1
                for _ in pairs(kill.items) do itemCount = itemCount + 1 end
            end
        end
    end
    ns:Print(("Shared drops: %d kills, %d items, %d messages waiting to send."):format(killCount, itemCount,
        #ns.db.dropOutbox))
    if killCount == 0 then return end
    for _, place in ipairs(SortedByName(drops, function(id, instance) return instance.name or tostring(id) end)) do
        print(("  |cffFCD29F%s|r |cff808080%s %d|r"):format(ns.Literal(place.name), place.entry.type or "", place.id))
        local bosses = SortedByName(place.entry.bosses, function(id, boss) return boss.name or tostring(id) end)
        for _, sortedBoss in ipairs(bosses) do PrintBoss(sortedBoss.id, sortedBoss.name, sortedBoss.entry) end
    end
end

function Drops:Clear()
    wipe(ns.db.drops)
    wipe(ns.db.dropOutbox)
    wipe(ns.db.newQuests)
    ns.db.dropItems = {}
    ns.db.dropTalk = {}
    if ns.DropTalkWindow then ns.DropTalkWindow:Refresh() end
    ns:Print("Shared drops and new quests cleared.")
end

-- Quest log ------------------------------------------------------------------
-- Every quest the player picks up or turns in, known to NeedRoll or not, so
-- NeedRoll can build its own WoW: Forever quest data from what the game
-- shows (the scraper's ingest copies it into scraper/quests/logged.json).
-- Saved in NeedRollDB.questLog, nothing ever pruned:
--     [questID] = { title, level, tag = "Dungeon", group = <suggested group>,
--         build, at = <first seen>, sides = { a = true }, classes = { [classID] = true },
--         objective, description = <the quest window's text>,
--         objectives = { { text, type, need } },
--         accept = { giver, giverID, giverName, dropper, map, x, y, instance, zone,
--             playerLevel, at },
--         rewards = { items = { [itemID] = count }, choice = { [itemID] = count },
--             money, xp, playerLevel },
--         turnin = { npc, npcID, npcName, map, x, y, instance, zone, text, money, xp,
--             playerLevel, at, offered = { [questID] = true } },
--         unlockedAfter = { { at, playerLevel, since, candidates = { questID, ... } } } }
-- giver is n (an NPC), o (an object), i (an item) or - (auto-accepted); npc
-- the same for whoever takes it back. map, x and y are where the player
-- stood (tenths of a percent), next to the giver. The quest window's xp and
-- money are for the player's level then (playerLevel); turnin's are what
-- was really paid. A better giver from a later pick-up replaces a vaguer
-- one; everything else keeps what was seen first. offered and
-- unlockedAfter are clues to quest chains (see Chain clues below); a quest
-- only ever seen offered gets an entry for its unlockedAfter, with no
-- accept or turnin.
local details = {} -- QUEST_DETAIL's view of each quest, until it is accepted

local function QuestLog()
    ns.db.questLog = ns.db.questLog or {}
    return ns.db.questLog
end

-- The open quest window's items of one kind ("reward" or "choice") as
-- { [itemID] = count }.
local function RewardItems(kind, count)
    local items = {}
    for i = 1, math.min(count or 0, 10) do
        local itemID = ns.Items:IDFromLink(Plain(GetQuestItemLink(kind, i)))
        if itemID then items[itemID] = tonumber(Plain((select(3, GetQuestItemInfo(kind, i))))) or 1 end
    end
    return items
end

local function WindowRewards()
    return {
        items = RewardItems("reward", GetNumQuestRewards()),
        choice = RewardItems("choice", GetNumQuestChoices()),
        money = Plain(GetRewardMoney()), xp = Plain(GetRewardXP()),
        playerLevel = Plain(UnitLevel("player")),
    }
end

local function Text(fn)
    local text = fn and Plain(fn())
    return type(text) == "string" and text ~= "" and text or nil
end

-- The quest's entry, made on first sight, with the log's facts filled in.
local function LogEntry(questID)
    local log = QuestLog()
    local quest = log[questID]
    if not quest then
        quest = { at = time(), build = clientBuild, sides = {}, classes = {} }
        log[questID] = quest
    end
    local level, title = QuestInfo(questID)
    quest.title = quest.title or title
    if level > 0 then quest.level = quest.level or level end
    local info = QuestLogInfo(questID)
    if info and (Plain(info.suggestedGroup) or 0) > 0 then quest.group = quest.group or Plain(info.suggestedGroup) end
    if not quest.tag then
        local tagInfo = Drops.QuestTagInfo(questID)
        quest.tag = tagInfo and Plain(tagInfo.tagName) or nil
    end
    if not quest.objectives then
        local list = {}
        for _, o in ipairs(C_QuestLog.GetQuestObjectives(questID) or {}) do
            list[#list + 1] = { text = Plain(o.text), type = Plain(o.type), need = Plain(o.numRequired) }
        end
        if #list > 0 then quest.objectives = list end
    end
    local side = SIDES[Plain(UnitFactionGroup("player"))]
    if side then quest.sides[side] = true end
    local class = Plain(select(3, UnitClass("player")))
    if class then quest.classes[class] = true end
    return quest
end

-- Chain clues -----------------------------------------------------------------
-- The game has no call that says which quest must be done before another,
-- so NeedRoll learns quest chains from what dev builds' characters see (the
-- scraper's chainlinks.py turns these clues into Data/Chains.lua links,
-- mostly for dungeon chains). Two clues, saved in the quest log above:
--   * Offered on its own: right after a quest is handed in, the game often
--     opens the next quest of its chain by itself, from the same NPC or
--     object, with no gossip or greeting window in between. Saved on the
--     handed-in quest as turnin.offered = { [next questID] = true }.
--   * Newly available: whenever an NPC's or object's gossip or greeting
--     window opens, the quests it offers are kept as its snapshot for this
--     character (what a character is offered depends on what it has done).
--     A quest missing from the last snapshot, taken at the same player
--     level, was opened by one of the quests the character handed in since:
--     saved on the new quest as unlockedAfter = { { at, playerLevel, since
--     = the last snapshot's time, candidates = { questID, ... } } }, the
--     newest UNLOCKS_KEPT. One candidate is a strong link; the scraper
--     narrows several down across observations.
-- The snapshots and what each character handed in or dropped are kept in
-- NeedRollDB.questOffers[ns.CharacterKey()] = {
--     npcs = { ["n1234" or "o5678"] = { at, level, quests = { [questID] = true }, isWhole } },
--     history = { { quest, at, done } }, forgotUntil, completedCount }
-- The scraper reads only the quest log, so character names stay here.
-- Quest titles can be secret values; everything is keyed by quest ID.
-- Its numbers and functions share one table: this file's main chunk is
-- close to Lua 5.1's limit of 200 locals.
local ChainClues = {
    FOLLOW_UP_WAIT = 3,   -- seconds from a hand-in to the game's own offer of the next quest
    NPCS_KEPT = 400,      -- NPC snapshots per character; the oldest goes past this
    HISTORY_KEPT = 300,   -- hand-ins and dropped quests per character; the oldest goes past this
    CANDIDATES_MAX = 40,  -- more hand-ins than this between two visits say too little to keep
    UNLOCKS_KEPT = 5,     -- unlockedAfter observations per quest
    sessionStart = time(),
    isGapChecked = false, -- whether ForgetAfterGap ran this session
    -- The hand-in that may bring the next quest: { quest, source, turnedInAt, offered, offeredAt }.
    pendingHandIn = nil,
}
-- So the smoke tests can start a session's gap check over (see ForgetAfterGap).
Drops.ChainClues = ChainClues

-- This character's snapshots and history (see above).
function ChainClues.Character()
    local characters = ns.db.questOffers or {}
    ns.db.questOffers = characters
    local key = ns.CharacterKey()
    characters[key] = characters[key] or { npcs = {}, history = {} }
    return characters[key]
end

-- "n1234" for an NPC, "o5678" for an object (GUIDSource's answer); else nil.
function ChainClues.SourceKey(kind, id)
    if kind then return kind .. id end
end

-- How many quests the game flags done for this character; nil when it doesn't say.
function ChainClues.CompletedCount()
    local completed = C_QuestLog.GetAllCompletedQuestIDs()
    if type(completed) == "table" then return #completed end
end

-- Notes a quest this character handed in (isDone) or that left its quest
-- log otherwise (dropped; the game also says so for a hand-in).
function ChainClues.NoteLeftLog(questID, isDone)
    local mine = ChainClues.Character()
    local history = mine.history
    history[#history + 1] = { quest = questID, at = time(), done = isDone or nil }
    while #history > ChainClues.HISTORY_KEPT do mine.forgotUntil = table.remove(history, 1).at end
end

-- SavedVariables are written only on /reload, logout or exit. After a
-- crash, or a session in a released build (which keeps no history), the
-- game knows hand-ins the history lacks, and a quest they opened would be
-- put down to the wrong ones. Then the game flags more quests done than
-- at the last save plus this session's hand-ins, and this character's
-- snapshots start over. Checked once a session, at the first snapshot,
-- when the game surely has the flags.
function ChainClues.ForgetAfterGap(mine)
    if ChainClues.isGapChecked then return end
    ChainClues.isGapChecked = true
    local count = ChainClues.CompletedCount()
    if not (count and mine.completedCount) then return end
    local handedInThisSession = 0
    for _, entry in ipairs(mine.history) do
        if entry.done and entry.at >= ChainClues.sessionStart then handedInThisSession = handedInThisSession + 1 end
    end
    if count > mine.completedCount + handedInThisSession then wipe(mine.npcs) end
end

-- The quests this character handed in since `since` (a time()), each once:
-- what may have opened `questID`. nil when the history can't tell: some of
-- it is forgotten, or `questID` itself left the log since (dropped, so it
-- came back on its own). Inclusive of `since`, as time() counts whole
-- seconds: an extra candidate only weakens the clue, a missing one breaks it.
function ChainClues.HandInsSince(mine, questID, since)
    if (mine.forgotUntil or 0) >= since then return nil end
    local candidates, isListed = {}, {}
    for _, entry in ipairs(mine.history) do
        if entry.at >= since and entry.quest == questID then return nil end
        if entry.at >= since and entry.done and not isListed[entry.quest] then
            isListed[entry.quest] = true
            candidates[#candidates + 1] = entry.quest
        end
    end
    return candidates
end

-- Saves on `questID`, offered by an NPC whose last snapshot `last` lacked
-- it, the hand-ins since that may have opened it.
function ChainClues.NoteNewcomer(mine, questID, last)
    if C_QuestLog.IsOnQuest(questID) or ns.IsQuestDone(questID) then return end
    local candidates = ChainClues.HandInsSince(mine, questID, last.at)
    if not candidates or #candidates == 0 or #candidates > ChainClues.CANDIDATES_MAX then return end
    local quest = LogEntry(questID)
    local unlocks = quest.unlockedAfter or {}
    quest.unlockedAfter = unlocks
    unlocks[#unlocks + 1] = { at = time(), playerLevel = last.level, since = last.at, candidates = candidates }
    while #unlocks > ChainClues.UNLOCKS_KEPT do table.remove(unlocks, 1) end
end

-- Compares what an NPC or object offers now (`offered`: { [questID] = true })
-- with its last snapshot, saving each newcomer's candidates, then keeps it
-- as the snapshot. A gossip or greeting window lists all it offers
-- (isWhole) and replaces the snapshot. A lone quest window may be one pick
-- from such a list, so it only adds its quest, and a snapshot begun from
-- one can't tell newcomers. A new level can open quests by itself, so a
-- snapshot from another level tells nothing either.
function ChainClues.NoteOffers(sourceKey, offered, isWhole)
    local mine = ChainClues.Character()
    ChainClues.ForgetAfterGap(mine)
    local level = Plain(UnitLevel("player"))
    local last = mine.npcs[sourceKey]
    if last and last.isWhole and last.level == level then
        for questID in pairs(offered) do
            if not last.quests[questID] then ChainClues.NoteNewcomer(mine, questID, last) end
        end
    end
    local seenAt = time()
    if last and not isWhole then
        for questID in pairs(last.quests) do offered[questID] = true end
        -- One quest seen says nothing new about the rest of the list, so the
        -- snapshot keeps the time and level the whole list was seen at: the
        -- hand-ins since then stay candidates. Seen at another level, the
        -- list is no longer known whole.
        isWhole = last.isWhole and last.level == level
        if isWhole then seenAt = last.at end
    end
    mine.npcs[sourceKey] = { at = seenAt, level = level, quests = offered, isWhole = isWhole or nil }
    DropOldest(mine.npcs, ChainClues.NPCS_KEPT)
end

-- Whether an offered quest tells about chains: one a character takes once,
-- not greyed out at the player's level (the game can hide those, as the
-- player chooses, so they come and go).
function ChainClues.IsChainOffer(isTrivial, frequency, isRepeatable)
    if Plain(isTrivial) == true or Plain(isRepeatable) == true then return false end
    return (Plain(frequency) or 0) == 0
end

-- The quests a gossip window offers, as { [questID] = true }; nil when one
-- comes without its ID.
function ChainClues.GossipOffers()
    local offered = {}
    for _, info in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do
        local questID = Plain(info.questID)
        if type(questID) ~= "number" or questID <= 0 then return nil end
        if ChainClues.IsChainOffer(info.isTrivial, info.frequency, info.repeatable) then offered[questID] = true end
    end
    return offered
end

-- The same for a quest greeting window (an NPC with several quests and no gossip).
function ChainClues.GreetingOffers()
    local offered = {}
    for index = 1, Plain(GetNumAvailableQuests()) or 0 do
        local isTrivial, frequency, isRepeatable, _, questID = GetAvailableQuestInfo(index)
        questID = Plain(questID)
        if type(questID) ~= "number" or questID <= 0 then return nil end
        if ChainClues.IsChainOffer(isTrivial, frequency, isRepeatable) then offered[questID] = true end
    end
    return offered
end

-- A gossip or greeting window from `sourceKey` with its whole list. A
-- window in between means the next quest window isn't the game's own
-- offer after a hand-in.
function ChainClues.NoteList(sourceKey, offered)
    ChainClues.pendingHandIn = nil
    if not (ns.db and sourceKey and offered) then return end
    ChainClues.NoteOffers(sourceKey, offered, true)
end

ns:On("GOSSIP_SHOW", function()
    ChainClues.NoteList(ChainClues.SourceKey(GUIDSource(Plain(UnitGUID("npc")))), ChainClues.GossipOffers())
end)

ns:On("QUEST_GREETING", function()
    ChainClues.NoteList(ChainClues.SourceKey(QuestWindowSource()), ChainClues.GreetingOffers())
end)

-- Saves that the game offered `nextQuestID` by itself after `questID` was handed in.
function ChainClues.NoteFollowUp(questID, nextQuestID)
    local turnin = LogEntry(questID).turnin
    if not turnin then return end
    turnin.offered = turnin.offered or {}
    turnin.offered[nextQuestID] = true
end

-- The window that takes `questID` back (QUEST_COMPLETE) from `sourceKey`:
-- a quest window it opens within FOLLOW_UP_WAIT seconds of the hand-in is
-- the next quest of the chain.
function ChainClues.ExpectFollowUp(questID, sourceKey)
    ChainClues.pendingHandIn = sourceKey and { quest = questID, source = sourceKey } or nil
end

-- QUEST_TURNED_IN. The next quest's window may come just before the game
-- says the quest was handed in, so one already open counts too.
function ChainClues.NoteHandIn(questID)
    local handIn = ChainClues.pendingHandIn
    if not (handIn and handIn.quest == questID) then return end
    handIn.turnedInAt = GetTime()
    if not handIn.offered or handIn.turnedInAt - handIn.offeredAt > ChainClues.FOLLOW_UP_WAIT then return end
    ChainClues.pendingHandIn = nil
    ChainClues.NoteFollowUp(questID, handIn.offered)
end

-- A quest window for `questID` from `sourceKey`: the next quest when the
-- same NPC or object took a quest back moments ago.
function ChainClues.CheckFollowUp(questID, sourceKey)
    local handIn = ChainClues.pendingHandIn
    if not (handIn and handIn.source == sourceKey and handIn.quest ~= questID) then return end
    if not handIn.turnedInAt then
        handIn.offered, handIn.offeredAt = questID, GetTime()
        return
    end
    ChainClues.pendingHandIn = nil
    if GetTime() - handIn.turnedInAt > ChainClues.FOLLOW_UP_WAIT then return end
    ChainClues.NoteFollowUp(handIn.quest, questID)
end

-- QUEST_DETAIL: maybe the game's own offer after a hand-in, and one quest
-- its NPC or object offers. Not one from an area the player walked into,
-- nor a daily, repeatable or greyed-out quest (as IsChainOffer).
function ChainClues.NoteQuestWindow(questID)
    local sourceKey = ChainClues.SourceKey(QuestWindowSource())
    if not (ns.db and sourceKey) or QuestIsFromAreaTrigger() then return end
    ChainClues.CheckFollowUp(questID, sourceKey)
    local frequency = (QuestIsDaily() or QuestIsWeekly()) and 1 or 0
    if not ChainClues.IsChainOffer(C_QuestLog.IsQuestTrivial(questID), frequency,
        C_QuestLog.IsRepeatableQuest(questID)) then return end
    ChainClues.NoteOffers(sourceKey, { [questID] = true }, false)
end

ns:On("QUEST_REMOVED", function(questID)
    questID = tonumber(Plain(questID))
    if ns.db and questID and questID > 0 then ChainClues.NoteLeftLog(questID, false) end
end)

ns:On("PLAYER_LOGOUT", function()
    if ns.db then ChainClues.Character().completedCount = ChainClues.CompletedCount() end
end)

ns:On("QUEST_DETAIL", function()
    local questID = OpenQuestID()
    if not questID then return end
    details[questID] = { giver = QuestGiver(questID), rewards = WindowRewards(),
        objective = Text(GetObjectiveText), description = Text(GetQuestText) }
    ChainClues.NoteQuestWindow(questID)
end)

ns:On("QUEST_ACCEPTED", function(...)
    local questID = AcceptedQuestID(...)
    if not ns.db or not questID then return end
    local seen = details[questID] or {}
    details[questID] = nil
    local quest = LogEntry(questID)
    quest.objective = quest.objective or seen.objective
    quest.description = quest.description or seen.description
    quest.rewards = quest.rewards or seen.rewards
    local giver = seen.giver or { kind = "-", id = 0, dropper = 0 }
    local accept = { giver = giver.kind, giverID = giver.id, giverName = giver.name, dropper = giver.dropper or 0,
        playerLevel = Plain(UnitLevel("player")), at = time() }
    accept.map, accept.x, accept.y, accept.instance, accept.zone = Where()
    if not quest.accept or GiverRank(accept) > GiverRank(quest.accept) then quest.accept = accept end
end)

-- The reward window when handing the quest in: who takes it back and where.
ns:On("QUEST_COMPLETE", function()
    local questID = OpenQuestID()
    if not ns.db or not questID then return end
    local quest = LogEntry(questID)
    local kind, npcID, npcName = QuestWindowSource()
    local turnin = quest.turnin or {}
    if kind or not quest.turnin then
        turnin.npc, turnin.npcID, turnin.npcName = kind or "-", npcID or 0, npcName
        turnin.map, turnin.x, turnin.y, turnin.instance, turnin.zone = Where()
    end
    turnin.text = turnin.text or Text(GetRewardText)
    quest.turnin = turnin
    quest.rewards = quest.rewards or WindowRewards()
    ChainClues.ExpectFollowUp(questID, ChainClues.SourceKey(kind, npcID))
end)

-- What the quest really paid, and when.
ns:On("QUEST_TURNED_IN", function(questID, xp, money)
    questID = tonumber(Plain(questID))
    if not ns.db or not questID or questID <= 0 then return end
    local quest = LogEntry(questID)
    local turnin = quest.turnin or { npc = "-", npcID = 0 }
    quest.turnin = turnin
    turnin.xp, turnin.money = Plain(xp), Plain(money)
    turnin.playerLevel, turnin.at = Plain(UnitLevel("player")), time()
    ChainClues.NoteLeftLog(questID, true)
    ChainClues.NoteHandIn(questID)
end)

-- /nr questlog: how many quests are logged, how many carry chain clues
-- (see Chain clues), and the newest ten; /nr questlog clear empties the log.
function Drops:QuestLogPrint()
    local rows, done, followedUp, unlocked = {}, 0, 0, 0
    for questID, quest in pairs(QuestLog()) do
        rows[#rows + 1] = { id = questID, quest = quest }
        if quest.turnin and quest.turnin.at then done = done + 1 end
        if quest.turnin and quest.turnin.offered then followedUp = followedUp + 1 end
        if quest.unlockedAfter then unlocked = unlocked + 1 end
    end
    table.sort(rows, function(a, b) return (a.quest.at or 0) > (b.quest.at or 0) end)
    ns:Print(("Quest log: %d quests, %d turned in. Saved on logout or /reload."):format(#rows, done))
    ns:Print(("Chain clues: %d quests the game followed with the next one, %d quests seen newly offered.")
        :format(followedUp, unlocked))
    for i = 1, math.min(#rows, 10) do
        local quest = rows[i].quest
        local accept = quest.accept or {}
        print(("  %s |cff808080%d|r - %s (%s)%s"):format(quest.title or "?", rows[i].id, accept.giverName or "no giver",
            accept.zone or "?", quest.turnin and quest.turnin.at and " - turned in" or ""))
    end
end

function Drops:QuestLogClear()
    wipe(QuestLog())
    ns:Print("Quest log cleared.")
end
--@end-debug@]==]
