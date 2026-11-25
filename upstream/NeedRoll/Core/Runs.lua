-- Run tracker: one record for each run through a dungeon or raid, with the bosses killed, the
-- items that dropped and what everyone in the group rolled on them. Players asked for it; Mike
-- keeps it to local checkouts for now (2026-11-19). A dungeon's or raid's page shows its run
-- (UI/RunPage.lua: "This run" and its roll grid), its All runs pill the history of every run
-- (UI/RunHistory.lua), a line under the minimap and a card at each kill show its progress
-- (UI/RunTracker.lua), and /nr runs prints what is recorded. The CurseForge packager turns the
-- debug block below into a comment and leaves those pages out, so a released build records
-- nothing, Runs.available stays false and /nr runs acts as plain /nr.
--
-- Saved per character in NeedRollDB.runs[ns.CharacterKey()]: a list, newest run last, at most
-- RUNS_KEPT. It keeps the names of everyone in the group as this client saw them. They stay in
-- the player's own SavedVariables: nothing here is ever sent to other players (Core/Drops.lua
-- shares drops on its own), and the scraper's ingest never reads this table. A run:
--   mapID, name, type ("party" or "raid"), difficulty, difficultyName: GetInstanceInfo's (the
--       name and difficulty name in the client's language, for show only);
--   instance: NeedRoll's ID for the place ("STOCKADE"), nil when NeedRoll doesn't list it. Where
--       one map holds several wings NeedRoll lists (Blackrock Spire's Lower and Upper,
--       Stratholme's Live and Undead: RunPlaces), the first listed until a boss dies, then the
--       wing of the run's first boss kill that decides one (SettleWing);
--   serverID, zoneUID: the copy of the dungeon, read from a creature's GUID (nil until one was
--       readable); identityFrom: which GUID source showed them first; lockoutID: a raid's
--       lockout ID (GetSavedInstanceInfo), once the player is saved to it;
--   why: why NeedRoll took it for a new run (WHY_NEW_TEXT); startedAt, lastSeenAt: time() of
--       its start and of the last time the player was seen inside;
--   closed: "reset" once the game said the place was reset, "manual" after /nr runs new; a
--       closed run takes no one back. cleared: true once every boss NeedRoll lists there (rare
--       spawns aside) has died;
--   visits = { { entered, left, leftAs = "walked" | "ghost" (released after dying) | "logout"
--       | "split" (a new run took over inside), back = why coming back continued this run
--       ("window", "lockout"), confirmedBy = the GUID source that showed the same copy } };
--   roster = { [name] = class token, or false when the class couldn't be read }: everyone
--       seen in the group during the run, by their whole name as loot lines write it (UnitNameOf);
--   kills = { { at, encounter = ENCOUNTER_END's encounter ID, name = its encounter name (for
--       show), npcs = { boss NPC IDs }, boss = NeedRoll's encounter ID ("TARGORR_THE_DREAD"),
--       from = "encounter" | "corpse" (a boss's corpse in the loot window, no ENCOUNTER_END) } };
--   drops = { { at, item, link, quality, count, kill = its boss's index in kills (nil: Other
--       drops), corpse = the spawn key of the corpse or chest it was looted from, lootMethod
--       (Enum.LootMethod), rollID (START_LOOT_ROLL's), historyID (the number in the loot lines'
--       [Loot] link), offered = true when the game offered the player a roll, rolls = { [name] =
--       { choice = "need" | "greed" | "disenchant" | "pass" | "notOffered", roll = the number
--       rolled, auto = true when the game passed for them } }, winner = name, how = "roll" |
--       "master" (handed out by the master looter) | "noRoll" (looted without a roll) |
--       "allPassed", received = who the "receives loot" line named } };
--   probe = { [source] = { readable, secret, ... } }: how often each GUID source could be read
--       in this run (boss units, loot window corpses, target, mouseover, nameplates, PARTY_KILL's
--       target, other units' and the player's own spell cast GUIDs), so Mike can confirm what
--       WoW: Forever hides; copyPairs = { agree, differ }: how often two creatures read one after
--       the other named the same copy (CopyAgreed); historyID = { rollID, other }: whether the
--       loot lines' number was the roll's ID.
--
-- One run or two: WoW: Forever has no combat log, so the copy of a dungeon is read from the
-- GUIDs of its creatures ("Creature-0-<server>-<map>-<zoneUID>-..."). Up to game build 70959 the
-- zoneUID was a small number other runs of the same dungeon got again later, so it could only
-- tell runs apart, never prove two visits are one run. Since build 71037 (2026-11-21) each
-- creature's GUID has a server and zoneUID of its own, so they name no copy at all. A copy counts
-- as read only once two different creatures agree on it (CopyAgreed), which they no longer do:
-- the GUIDs then decide nothing, and rules 2 to 6 tell the runs apart. In this order:
--   1. Two creatures that agree on another server or zoneUID than the run's start a new run.
--   2. The game's reset line for the place (CHAT_MSG_SYSTEM, read with its own strings), or
--      /nr runs new, closes the run: the next visit starts a new one.
--   3. Coming back after AWAY_WINDOW outside starts a new run, and so does coming back once every
--      boss is dead. A cleared run stays the current one for CLEARED_WINDOW after leaving.
--   4. Otherwise coming back to the same map and difficulty continues the run: a corpse run or a
--      repair trip. Each exit and return is kept in visits.
--   5. Until the copy is read after coming back, kills and loot go on the continued run; if the
--      GUIDs then show another copy, what was recorded since the return moves to a new run.
--   6. In a raid, the lockout ID (GetSavedInstanceInfo, after RequestRaidInfo) wins over all of
--      the above: the same lockout is the same run, another lockout another run.
local _, ns = ...

local Runs = { available = false }
ns.Runs = Runs
--[==[@debug@
Runs.available = true

-- Unit names and GUIDs, chat lines and instance facts can be secret in some instances (see ns.Plain).
local Plain = ns.Plain

local RUNS_KEPT = 100              -- runs saved per character; the oldest goes first
local AWAY_WINDOW = 90 * 60        -- seconds outside after which coming back starts a new run
local CLEARED_WINDOW = 20 * 60     -- seconds a cleared run stays the current one after leaving
local BOSS_LOOT_WINDOW = 3 * 60    -- seconds after a kill that an item on its loot list is taken for its drop
local DROP_MATCH_WINDOW = 10 * 60  -- seconds a roll or loot line can still be about a drop recorded earlier
local PROBE_SAMPLES = 25           -- GUIDs the frequent sources count per run before they stop
local RUNS_LISTED = 10             -- runs /nr runs list prints

-- GUID types made in the dungeon's own copy. Up to game build 70959 their server and zoneUID
-- named that copy; since build 71037 each creature's are its own (CopyAgreed then never agrees).
-- Players and their pets come from elsewhere.
local COPY_TYPES = { Creature = true, Vehicle = true, GameObject = true }

-- The type, server, map and zoneUID a creature, object or spell cast GUID carries. Creature,
-- Vehicle and GameObject GUIDs ("Creature-0-<server>-<map>-<zoneUID>-<ID>-<spawnUID>") and cast
-- GUIDs ("Cast-<kind>-<server>-<map>-<zoneUID>-<spell>-<castUID>") give their type, then the
-- server, map and zoneUID as numbers; nil for anything else. Since build 71037 they no longer
-- tell copies apart (COPY_TYPES); this file keeps them only to watch for that changing. Pass the
-- GUID through Plain first.
local function GUIDCopy(guid)
    if type(guid) ~= "string" then return nil end
    local unitType, serverID, mapID, zoneUID = guid:match("^(%a+)%-%d+%-(%d+)%-(%d+)%-(%d+)%-%d+%-")
    if not unitType then return nil end
    return unitType, tonumber(serverID), tonumber(mapID), tonumber(zoneUID)
end

-- While the player is inside a dungeon or raid: the run, the place (CurrentPlace's facts), and
-- what this stay inside has learned. stayStart: where this stay's records begin in the run's
-- lists ({ visit, kill, drop }, the index of the first of each), so a split can take them along.
-- isConfirmed: creature GUIDs showed the run's copy since entering. isPending: the stay
-- continues an earlier visit's run and no GUID has confirmed the copy yet (rule 5).
-- lastCopy: the last creature GUID read and the copy it named, for CopyAgreed; copyMisses: how
-- often two creatures named different copies during this stay. fight: the encounter in progress,
-- with the NPC IDs of its boss units. Empty outside.
local here = {}

-- The pages that show runs (UI/RunPage.lua) redraw when what is recorded changes. A burst of
-- changes (a loot window's slots, every roll line of one item) is told to them once, CHANGE_DELAY
-- after the first of it, so an open page redraws a few times a minute at most, never each frame.
local CHANGE_DELAY = 0.25 -- seconds
local changeListeners = {}
local isChangeQueued = false

-- The run tracker's kill card (UI/RunTracker.lua) shows as a boss dies: `listener(run, kill)`
-- runs at once for each kill added to a run, never for one folded into the same boss's kill.
local killListeners = {}

local function TellListeners()
    isChangeQueued = false
    for _, listener in ipairs(changeListeners) do listener() end
end

local function Changed()
    if isChangeQueued then return end
    isChangeQueued = true
    C_Timer.After(CHANGE_DELAY, TellListeners)
end

-- The dungeon or raid the player is in, from GetInstanceInfo, or nil anywhere else.
local function CurrentPlace()
    local name, instanceType, difficulty, difficultyName, _, _, _, mapID = GetInstanceInfo()
    instanceType, mapID = Plain(instanceType), Plain(mapID)
    if (instanceType ~= "party" and instanceType ~= "raid") or not mapID then return nil end
    return { name = Plain(name), type = instanceType, difficulty = Plain(difficulty) or 0,
        difficultyName = Plain(difficultyName), mapID = mapID }
end

-- A unit's whole name as loot lines write it, or nil when it can't be read. WoW: Forever's
-- UnitName gives a character's first name and, in its second value (a realm's place elsewhere),
-- the rest of it: "Flow", "State" for the "Flow State" of the loot lines (Mike's runs, 2026-11-22).
local function UnitNameOf(unit)
    local name, rest = UnitName(unit)
    name, rest = Plain(name), Plain(rest)
    if not name or name == "" or name == UNKNOWNOBJECT then return nil end
    if rest and rest ~= "" then name = name .. " " .. rest end
    return name
end

-- Boss NPCs NeedRoll lists ------------------------------------------------------
-- byNpc: NPC ID -> { instance = NeedRoll's instance ID, encounter = its encounter ID }. byName:
-- a boss's name -> its NPC ID, for an encounter whose boss units couldn't be read. Built at the
-- first ask.
local bossIndex

-- The dungeons a run can be in where NeedRoll lists `instance`: for an instance shown as one
-- (Data/Data.lua's MergeWings: Stratholme) each of its parts, Live and Undead, else itself. Runs
-- and kills go by these IDs, so a Stratholme run counts one side's bosses.
local function RunPlaces(instance)
    if not instance.wingIDs then return { instance } end
    local parts = {}
    for i, wingID in ipairs(instance.wingIDs) do parts[i] = ns.Data:Wing(wingID) end
    return parts
end

-- Whether `instanceID` is the ID of an instance shown as one ("STRATHOLME"), not a run place's.
local function IsJoinedID(instanceID)
    local instance = ns.Data:Wing(instanceID)
    return instance ~= nil and instance.wingIDs ~= nil
end

local function AddBoss(instanceID, encounterID, npcID, name)
    if not npcID or bossIndex.byNpc[npcID] then return end
    bossIndex.byNpc[npcID] = { instance = instanceID, encounter = encounterID }
    if name then bossIndex.byName[name] = npcID end
end

local function BossIndex()
    if bossIndex then return bossIndex end
    bossIndex = { byNpc = {}, byName = {} }
    -- Data/Bosses.lua: instance = { encounter = { { name, display, level, rank, NPC ID }, ... } }
    for instanceID, encounters in pairs(ns.Data.bosses) do
        if not IsJoinedID(instanceID) then
            for encounterID, bosses in pairs(encounters) do
                for _, boss in ipairs(bosses) do AddBoss(instanceID, encounterID, boss[5], boss[1]) end
            end
        end
    end
    for _, category in ipairs({ "DUNGEON", "RAID" }) do
        for _, listed in ipairs(ns.Data:List(category)) do
            for _, instance in ipairs(RunPlaces(listed)) do
                for _, encounter in ipairs(instance.encounters) do
                    AddBoss(instance.id, encounter.id, encounter.npc, encounter.name)
                end
            end
        end
    end
    return bossIndex
end

-- A place (CurrentPlace's facts, or a run's own name and mapID) as ns.Data:IsPlayerInside reads it.
local function WhereaboutsOf(place)
    return { name = (place.name or ""):lower(), mapID = place.mapID }
end

-- NeedRoll's ID for the dungeon or raid at `place` (by map ID, or by name for the places new in
-- WoW: Forever): the first NeedRoll lists there, so the first wing of a map that holds several
-- (SettleWing); nil when NeedRoll doesn't list it.
local function ListedInstanceID(place)
    local where = WhereaboutsOf(place)
    for _, category in ipairs({ "DUNGEON", "RAID" }) do
        for _, instance in ipairs(ns.Data:List(category)) do
            if ns.Data:IsPlayerInside(instance, where) then return RunPlaces(instance)[1].id end
        end
    end
end

local function EncounterOf(instanceID, encounterID)
    local instance = instanceID and ns.Data:Wing(instanceID)
    if not (instance and encounterID) then return nil end
    for _, encounter in ipairs(instance.encounters) do
        if encounter.id == encounterID then return encounter end
    end
end

-- Whether the item is on NeedRoll's loot list for the boss of `kill`.
local function IsOnBossLoot(run, kill, itemID)
    local encounter = EncounterOf(run.instance, kill.boss)
    for _, entry in ipairs(encounter and encounter.loot or {}) do
        if entry.itemID == itemID then return true end
    end
    return false
end

-- The encounters of NeedRoll's instance that must die for the place to count as cleared: every
-- boss but the rare spawns. Empty when NeedRoll doesn't list the place.
local function RequiredBosses(instanceID)
    local required = {}
    local instance = instanceID and ns.Data:Wing(instanceID)
    if not instance then return required end
    for _, encounter in ipairs(instance.encounters) do
        if ns.Data:IsBoss(encounter) and not ns.Data:IsRareSpawn(instance, encounter) then
            required[encounter.id] = true
        end
    end
    return required
end

local function UpdateCleared(run)
    local required = RequiredBosses(run.instance)
    if not next(required) then return end
    for _, kill in ipairs(run.kills) do
        if kill.boss then required[kill.boss] = nil end
    end
    run.cleared = next(required) == nil or nil
end

-- NeedRoll's encounter ID for a kill and the ID of the instance NeedRoll lists it in: by a boss
-- unit's NPC ID, else by the encounter's name. Nil when NeedRoll doesn't list the boss.
local function NeedRollBoss(npcIDs, encounterName)
    local index = BossIndex()
    for _, npcID in ipairs(npcIDs) do
        local boss = index.byNpc[npcID]
        if boss then return boss.encounter, boss.instance end
    end
    local npcID = encounterName and index.byName[encounterName]
    if not npcID then return nil end
    return index.byNpc[npcID].encounter, index.byNpc[npcID].instance
end

-- Wings that share one map ------------------------------------------------------
-- NeedRoll lists some places as two or more dungeons that are one map to the game, so
-- GetInstanceInfo's map ID can't tell which one the group is doing: Blackrock Spire (Lower and
-- Upper), Scarlet Monastery (Graveyard, Library, Armory, Cathedral), Dire Maul (East, West,
-- North) and Stratholme (Live and Undead sides; one page in NeedRoll, but two run places, see
-- RunPlaces). A run starts on the first wing NeedRoll lists there (ListedInstanceID), since
-- nothing tells them apart before a boss dies. Its first kill of a boss of one of the map's
-- wings then moves the run to that wing, so its pages count and show only that wing's bosses
-- (Mike, 2026-11-24). A later kill of another wing's boss doesn't move it again: it shows as a
-- kill NeedRoll doesn't list there. A boss in EITHER_WING_BOSSES never decides the wing: the run
-- stays where it is until another boss dies.

-- Bosses that never decide a wing, by NeedRoll's instance and encounter ID: groups kill them on
-- either wing's run. The Unforgiven stands between Stratholme's Live and Undead sides, so Undead
-- runs often kill him too (Mike, 2026-11-24).
local EITHER_WING_BOSSES = {
    STRAT_LIVE = { THE_UNFORGIVEN = true },
}

-- Whether NeedRoll's instance `instanceID` is at `run`'s place: the run's own one or another
-- wing of its map.
local function IsWingOf(run, instanceID)
    local instance = instanceID and ns.Data:Get(instanceID)
    return instance ~= nil and ns.Data:IsPlayerInside(instance, WhereaboutsOf(run))
end

-- The wing of `run`'s map that `kill` puts the run on: the wing its boss belongs to, unless that
-- boss dies on either wing's run. Nil when the kill doesn't decide the wing.
local function WingDecidedBy(run, kill)
    if not kill.boss then return nil end
    local encounterID, bossInstance = NeedRollBoss(kill.npcs, kill.name)
    if not IsWingOf(run, bossInstance) then return nil end
    local eitherWing = EITHER_WING_BOSSES[bossInstance]
    if eitherWing and eitherWing[encounterID] then return nil end
    return bossInstance
end

-- Puts `run` on the wing its first deciding kill names, when that is another wing than its own.
local function SettleWing(run)
    for _, kill in ipairs(run.kills) do
        local wing = WingDecidedBy(run, kill)
        if wing then
            if wing == run.instance then return end
            run.instance = wing
            UpdateCleared(run)
            return
        end
    end
end

-- The saved list SettleWing last went through. Runs saved before the wings were told apart
-- (every Blackrock Spire run was Lower's, every Stratholme run "STRATHOLME", both sides) are
-- settled once, the first time the list is read in a session; the list table stays the same
-- until the next /reload.
local settledList

local function SettleSavedWings(list)
    if list == settledList then return end
    settledList = list
    for _, run in ipairs(list) do SettleWing(run) end
end

-- This character's runs, oldest first.
local function RunList()
    local key = ns.CharacterKey()
    ns.db.runs[key] = ns.db.runs[key] or {}
    SettleSavedWings(ns.db.runs[key])
    return ns.db.runs[key]
end

-- /nr runs demo (UI/RunDemo.lua): made-up runs the pages show in place of the saved ones until
-- /nr runs demo off or a /reload. Kept in memory only; recording still goes to RunList.
local demoRuns

-- The runs the pages show, oldest first: the demo's while it is on, else the saved ones.
local function ShownRuns()
    return demoRuns or RunList()
end

-- The group ---------------------------------------------------------------------
local function NoteMember(run, unit)
    if not Plain(UnitExists(unit)) then return end
    local name = UnitNameOf(unit)
    if not name then return end
    local class = Plain((select(2, UnitClass(unit)))) or run.roster[name] or false
    if run.roster[name] == class then return end
    run.roster[name] = class
    Changed()
end

-- Everyone in the player's group goes into the run's roster; those who leave stay in it.
local function NoteRoster()
    local run = here.run
    if not run then return end
    local prefix, count = "party", 4
    if IsInRaid() then prefix, count = "raid", 40 end
    NoteMember(run, "player")
    for i = 1, count do NoteMember(run, prefix .. i) end
end

ns:On("GROUP_ROSTER_UPDATE", NoteRoster)

-- Starting, continuing and splitting runs -----------------------------------------
-- Where the next visit, kill and drop of `run` will go in its lists: a stay's records begin there.
local function NextMarks(run)
    return { visit = #run.visits + 1, kill = #run.kills + 1, drop = #run.drops + 1 }
end

-- Removes the entries of `list` from index `first` on and returns them in order.
local function CutTail(list, first)
    local tail = {}
    for i = first, #list do table.insert(tail, list[i]) end
    for i = #list, first, -1 do list[i] = nil end
    return tail
end

-- Moves what `from` recorded from the marks `start` on (visits, kills, drops) to the new run
-- `to`: a return that turned out to be another copy of the dungeon takes its records along.
local function MoveTail(from, to, start)
    to.kills, to.drops, to.visits =
        CutTail(from.kills, start.kill), CutTail(from.drops, start.drop), CutTail(from.visits, start.visit)
    for _, drop in ipairs(to.drops) do
        drop.kill = drop.kill and drop.kill >= start.kill and drop.kill - start.kill + 1 or nil
    end
    for _, drop in ipairs(from.drops) do
        if drop.kill and drop.kill >= start.kill then drop.kill = nil end
    end
    if to.visits[1] then to.visits[1].back, to.visits[1].confirmedBy = nil, nil end
    SettleWing(to)
    UpdateCleared(from)
    UpdateCleared(to)
end

-- Ends the run's visit still open (if any): how the player left, or "logout" at the last time
-- NeedRoll saw them inside when they logged out or the game closed there.
local function EndVisit(run, leftAs, at)
    local visit = run.visits[#run.visits]
    if visit and not visit.left then visit.left, visit.leftAs = at or run.lastSeenAt, leftAs end
end

-- Starts a new run at the player's place and makes it the current one. With `start` (the
-- current stay's marks), what the current run recorded during this stay moves to the new one.
local function StartRun(why, start)
    local now = time()
    local previous = here.run
    local run = { mapID = here.place.mapID, name = here.place.name, type = here.place.type,
        difficulty = here.place.difficulty, difficultyName = here.place.difficultyName,
        instance = ListedInstanceID(here.place), why = why, lastSeenAt = now,
        visits = {}, roster = {}, kills = {}, drops = {}, probe = {} }
    if previous then
        if start then MoveTail(previous, run, start) end
        EndVisit(previous, "split", now)
    end
    if #run.visits == 0 then run.visits = { { entered = now } } end
    run.startedAt = run.visits[1].entered
    local list = RunList()
    table.insert(list, run)
    while #list > RUNS_KEPT do table.remove(list, 1) end
    -- Whatever the new run holds was recorded during this stay.
    here.run, here.stayStart = run, { visit = 1, kill = 1, drop = 1 }
    here.isConfirmed, here.isPending = false, false
    NoteRoster()
    Changed()
    return run
end

-- Adds everything `from` recorded to the earlier run `into` and takes `from` off the list: a
-- raid lockout showed they are one run.
local function MergeRun(into, from)
    local killOffset = #into.kills
    for _, kill in ipairs(from.kills) do table.insert(into.kills, kill) end
    for _, drop in ipairs(from.drops) do
        drop.kill = drop.kill and drop.kill + killOffset
        table.insert(into.drops, drop)
    end
    for _, visit in ipairs(from.visits) do table.insert(into.visits, visit) end
    for name, class in pairs(from.roster) do into.roster[name] = into.roster[name] or class end
    for source, counts in pairs(from.probe) do
        local kept = into.probe[source] or {}
        into.probe[source] = kept
        for field, count in pairs(counts) do
            if type(count) == "number" then kept[field] = (kept[field] or 0) + count end
        end
    end
    into.lastSeenAt = math.max(into.lastSeenAt, from.lastSeenAt)
    UpdateCleared(into)
    local list = RunList()
    for i = #list, 1, -1 do
        if list[i] == from then table.remove(list, i) end
    end
    Changed()
end

-- How long the player has been outside `run`: since its last visit ended, or since NeedRoll
-- last saw them inside (a logout inside leaves the visit open).
local function SecondsOutside(run, now)
    local visit = run.visits[#run.visits]
    return now - (visit and visit.left or run.lastSeenAt)
end

-- Why coming back to `run`'s place starts a new run (rules 2 and 3), or nil when it continues.
local function WhyNewRun(run, now)
    if not run then return "first" end
    if run.closed then return run.closed end
    if run.cleared then return "cleared" end
    if SecondsOutside(run, now) > AWAY_WINDOW then return "away" end
end

-- The latest run at this place and difficulty: the one coming back might continue.
local function LatestRunAt(place)
    local list = RunList()
    for i = #list, 1, -1 do
        local run = list[i]
        if run.mapID == place.mapID and run.difficulty == place.difficulty then return run end
    end
end

-- Raid lockouts (rule 6) --------------------------------------------------------
-- The player's lockout ID for the raid at `place`, from the saved instances the game last sent
-- (RequestRaidInfo asks again), or nil. The fourteenth value, the map ID, is matched when the
-- game gives it, else the raid's name. Each raid has one difficulty on WoW: Forever, and
-- GetSavedInstanceInfo may number difficulties another way than GetInstanceInfo, so it isn't compared.
local function LockoutOf(place)
    for i = 1, GetNumSavedInstances() do
        local name, lockoutID, _, _, isLocked, _, _, _, _, _, _, _, _, mapID = GetSavedInstanceInfo(i)
        name, mapID = Plain(name), Plain(mapID)
        local isThisRaid = mapID == place.mapID or (place.name ~= nil and name == place.name)
        if Plain(isLocked) and isThisRaid then return Plain(lockoutID) end
    end
end

local function EarlierRunWithLockout(lockoutID)
    local list = RunList()
    for i = #list, 1, -1 do
        local run = list[i]
        local isOpen = run ~= here.run and not run.closed
        if isOpen and run.mapID == here.place.mapID and run.lockoutID == lockoutID then return run end
    end
end

-- Checks the current raid run against the player's lockout: kept on the run the first time,
-- joined to an earlier run with the same lockout, or split off when the lockout is another.
local function CheckLockout()
    local run = here.run
    if not run or run.type ~= "raid" then return end
    local lockoutID = LockoutOf(here.place)
    if not lockoutID or lockoutID == run.lockoutID then return end
    if run.lockoutID then
        local newRun = StartRun("lockout", here.stayStart)
        newRun.lockoutID = lockoutID
        return
    end
    local earlier = EarlierRunWithLockout(lockoutID)
    if not earlier then
        run.lockoutID = lockoutID
        Changed()
        return
    end
    local stayStart = NextMarks(earlier)
    MergeRun(earlier, run)
    earlier.visits[stayStart.visit].back = "lockout"
    here.run, here.stayStart = earlier, stayStart
end

ns:On("UPDATE_INSTANCE_INFO", CheckLockout)

-- Entering and leaving ----------------------------------------------------------
local function Enter(place, isReload)
    local now = time()
    here.place = place
    local run = LatestRunAt(place)
    local visit = run and run.visits[#run.visits]
    if isReload and visit and not visit.left then
        -- A /reload inside: the same visit goes on, and the copy can't have changed. What was
        -- recorded before the reload stays put in any split.
        here.run, here.isConfirmed = run, run.zoneUID ~= nil
        here.stayStart = { visit = #run.visits, kill = #run.kills + 1, drop = #run.drops + 1 }
    else
        local why = WhyNewRun(run, now)
        if run then EndVisit(run, "logout") end
        if why then
            StartRun(why)
        else
            here.run, here.stayStart, here.isConfirmed, here.isPending = run, NextMarks(run), false, true
            table.insert(run.visits, { entered = now, back = "window" })
        end
    end
    here.run.lastSeenAt = now
    NoteRoster()
    Changed()
    if place.type ~= "raid" then return end
    CheckLockout()
    RequestRaidInfo()
end

local function Leave()
    local run = here.run
    run.lastSeenAt = time()
    -- A player who released after dying arrives outside as a ghost.
    EndVisit(run, Plain(UnitIsGhost("player")) and "ghost" or "walked", run.lastSeenAt)
    wipe(here)
    Changed()
end

-- A loading screen: into a dungeon or raid, out of one, or a /reload. A loading screen that
-- stays in the same place changes nothing.
ns:On("PLAYER_ENTERING_WORLD", function(_, isReloadingUi)
    if not ns.db then return end
    local place = CurrentPlace()
    local isSamePlace = here.run and place and place.mapID == here.place.mapID
        and place.difficulty == here.place.difficulty
    if isSamePlace then return end
    if here.run then Leave() end
    if place then Enter(place, isReloadingUi) end
end)

-- Logging out or reloading inside: when NeedRoll last saw the player there.
ns:On("PLAYER_LEAVING_WORLD", function()
    if here.run then here.run.lastSeenAt = time() end
end)

-- The run's copy, from GUIDs (rules 1, 4 and 5) ----------------------------------
local function ProbeCounts(run, source)
    run.probe[source] = run.probe[source] or { readable = 0, secret = 0 }
    return run.probe[source]
end

-- Whether a frequent GUID source has nothing left to tell during this stay: the probe has its
-- samples, and the copy is confirmed or the creatures disagreed on it PROBE_SAMPLES times.
-- Nameplates, target and mouseover then cost nothing, in combat or out.
local function IsSampled(source)
    local counts = here.run.probe[source]
    local isCopySettled = here.isConfirmed or (here.copyMisses or 0) >= PROBE_SAMPLES
    return isCopySettled and counts ~= nil and counts.readable + counts.secret >= PROBE_SAMPLES
end

-- Whether the creature `guid`, of the copy `serverID`/`zoneUID`, agrees with the last other
-- creature read during this stay; counted in the run's copyPairs for the probe. The same creature
-- read again (a target that is also under the mouse) tells nothing. One loading screen can't
-- change the copy, so creatures that disagree show GUIDs that name none (build 71037 on).
local function CopyAgreed(guid, serverID, zoneUID)
    local last = here.lastCopy
    if last and last.guid == guid then return false end
    here.lastCopy = { guid = guid, serverID = serverID, zoneUID = zoneUID }
    if not last then return false end
    local agrees = last.serverID == serverID and last.zoneUID == zoneUID
    local copyPairs = here.run.probe.copyPairs or { agree = 0, differ = 0 }
    here.run.probe.copyPairs = copyPairs
    if agrees then
        copyPairs.agree = copyPairs.agree + 1
    else
        copyPairs.differ = copyPairs.differ + 1
        here.copyMisses = (here.copyMisses or 0) + 1
    end
    return agrees
end

-- Two creatures or objects agreed on this place's copy `serverID`/`zoneUID`, the second read from
-- `source`. The first copy read names the run's; another copy starts a new run that takes along
-- what was recorded since coming back; a raid's lockout outranks the GUIDs.
local function CheckCopy(serverID, zoneUID, source)
    local run = here.run
    local isSameCopy = run.serverID == serverID and run.zoneUID == zoneUID
    if here.isConfirmed and isSameCopy then return end
    if run.zoneUID == nil then
        run.serverID, run.zoneUID, run.identityFrom = serverID, zoneUID, source
    elseif isSameCopy then
        if here.isPending then run.visits[#run.visits].confirmedBy = source end
    elseif run.lockoutID then
        run.serverID, run.zoneUID = serverID, zoneUID
    else
        local newRun = StartRun("zone", here.isPending and here.stayStart or nil)
        newRun.serverID, newRun.zoneUID, newRun.identityFrom = serverID, zoneUID, source
    end
    here.isConfirmed, here.isPending = true, false
    Changed()
end

-- A GUID from one of the sources: counted for the probe, and checked against the run's copy
-- when it is a creature's or object's here that agrees with the one before. Players and pets
-- aren't counted.
local function NoteGUID(source, guid)
    if not here.run then return end
    if issecretvalue(guid) then
        local counts = ProbeCounts(here.run, source)
        counts.secret = counts.secret + 1
        return
    end
    local unitType, serverID, mapID, zoneUID = GUIDCopy(guid)
    if not COPY_TYPES[unitType] then return end
    local counts = ProbeCounts(here.run, source)
    counts.readable = counts.readable + 1
    if mapID ~= here.place.mapID then
        -- Kept to see whether the GUID's map is ever another than GetInstanceInfo's.
        counts.otherMap = (counts.otherMap or 0) + 1
        return
    end
    if CopyAgreed(guid, serverID, zoneUID) then CheckCopy(serverID, zoneUID, source) end
end

local function NoteUnit(source, unit)
    if not here.run or IsSampled(source) then return end
    NoteGUID(source, UnitGUID(unit))
end

ns:On("PLAYER_TARGET_CHANGED", function() NoteUnit("target", "target") end)
ns:On("UPDATE_MOUSEOVER_UNIT", function() NoteUnit("mouseover", "mouseover") end)
ns:On("NAME_PLATE_UNIT_ADDED", function(unit) NoteUnit("nameplate", unit) end)
ns:On("PARTY_KILL", function(_, targetGUID) NoteGUID("partyKill", targetGUID) end)

-- A spell cast GUID ("Cast-<kind>-<server>-<map>-<zoneUID>-<spell>-<castUID>"): only counted for
-- the probe, with whether its server and zoneUID agree with the run's copy and the last one
-- read (sample). Whether WoW: Forever writes the copy into cast GUIDs the same way isn't known
-- yet, so they don't decide runs. Casts come many a second in a fight: each source stops after
-- PROBE_SAMPLES.
local function NoteCast(unit, castGUID)
    local run = here.run
    if not run then return end
    local counts = ProbeCounts(run, unit == "player" and "ownCast" or "cast")
    if counts.readable + counts.secret >= PROBE_SAMPLES then return end
    if issecretvalue(castGUID) then
        counts.secret = counts.secret + 1
        return
    end
    local unitType, serverID, mapID, zoneUID = GUIDCopy(castGUID)
    if unitType ~= "Cast" then return end
    counts.readable = counts.readable + 1
    counts.sample = ("%d-%d-%d"):format(serverID, mapID, zoneUID)
    if not run.zoneUID then return end
    local agrees = serverID == run.serverID and zoneUID == run.zoneUID
    local field = agrees and "agrees" or "differs"
    counts[field] = (counts[field] or 0) + 1
end

ns:On("UNIT_SPELLCAST_START", NoteCast)
ns:On("UNIT_SPELLCAST_SUCCEEDED", NoteCast)

-- The game's reset line (rule 2) ------------------------------------------------
-- The lines the game writes when the group leader resets the group's instances. A failed
-- reset because a player is still inside or zoning in still counts as a reset for those outside.
local RESET_FORMATS = { INSTANCE_RESET_SUCCESS, INSTANCE_RESET_FAILED, INSTANCE_RESET_FAILED_ZONING }

-- The place named `instanceName` was reset: its open runs (but the one the player is in) close.
local function CloseResetRuns(instanceName)
    for _, run in ipairs(RunList()) do
        if run.name == instanceName and run ~= here.run and not run.closed then run.closed = "reset" end
    end
    Changed()
end

ns:On("CHAT_MSG_SYSTEM", function(text)
    text = Plain(text)
    if not ns.db or type(text) ~= "string" then return end
    for _, format in ipairs(RESET_FORMATS) do
        local values = ns.ReadGameText(text, format)
        if values then return CloseResetRuns(values[1]) end
    end
end)

-- Boss kills --------------------------------------------------------------------
local function AddNpcs(kill, npcIDs)
    for _, npcID in ipairs(npcIDs) do
        if not tContains(kill.npcs, npcID) then table.insert(kill.npcs, npcID) end
    end
end

-- Adds a kill to the current run, or folds it into the same boss's kill already there (each
-- boss dies once in a copy); returns its index in run.kills.
local function AddKill(kill)
    local run = here.run
    kill.boss = NeedRollBoss(kill.npcs, kill.name)
    for i, earlier in ipairs(run.kills) do
        local isSameEncounter = kill.encounter ~= nil and earlier.encounter == kill.encounter
        if isSameEncounter or (kill.boss ~= nil and earlier.boss == kill.boss) then
            AddNpcs(earlier, kill.npcs)
            earlier.encounter, earlier.name = earlier.encounter or kill.encounter, earlier.name or kill.name
            Changed()
            return i
        end
    end
    kill.at = time()
    table.insert(run.kills, kill)
    run.lastSeenAt = kill.at
    -- Before UpdateCleared and the kill listeners: the first boss of a shared map's wing decides
    -- which wing's bosses the run tracker draws.
    SettleWing(run)
    UpdateCleared(run)
    Changed()
    for _, listener in ipairs(killListeners) do listener(run, kill) end
    return #run.kills
end

-- The fight's boss units, read when it starts and as each boss joins.
local function NoteBossUnits()
    if not here.fight then return end
    for i = 1, 5 do
        local guid = UnitGUID("boss" .. i)
        NoteGUID("boss", guid)
        local unitType, npcID = ns.ParseGUID(Plain(guid))
        if unitType == "Creature" or unitType == "Vehicle" then here.fight.npcs[npcID] = true end
    end
end

ns:On("ENCOUNTER_START", function()
    if not here.run then return end
    here.fight = { npcs = {} }
    NoteBossUnits()
end)
ns:On("INSTANCE_ENCOUNTER_ENGAGE_UNIT", NoteBossUnits)

ns:On("ENCOUNTER_END", function(encounterID, encounterName, _, _, success)
    if not here.run then return end
    NoteBossUnits()
    local fightNpcs = here.fight and here.fight.npcs or {}
    here.fight = nil
    if Plain(success) ~= 1 then return end
    local npcIDs = {}
    for npcID in pairs(fightNpcs) do table.insert(npcIDs, npcID) end
    table.sort(npcIDs)
    AddKill({ encounter = Plain(encounterID), name = Plain(encounterName), npcs = npcIDs, from = "encounter" })
    -- A raid saves the player at the first kill: ask for the lockout.
    if here.place.type == "raid" then RequestRaidInfo() end
end)

-- The kill a corpse in the loot window belongs to (its index in run.kills): one whose boss units
-- included it, else a boss NeedRoll lists, added from the corpse when no ENCOUNTER_END came.
-- Nil for any other creature.
local function KillOfCorpse(npcID)
    for i, kill in ipairs(here.run.kills) do
        if tContains(kill.npcs, npcID) then return i end
    end
    if not BossIndex().byNpc[npcID] then return nil end
    return AddKill({ npcs = { npcID }, from = "corpse" })
end

-- The kill an item with no corpse to tell comes from: the latest kill of the last few minutes
-- whose NeedRoll loot list has the item; nil (Other drops) when none.
local function KillForItem(run, itemID)
    local now = time()
    for i = #run.kills, 1, -1 do
        local kill = run.kills[i]
        if now - kill.at > BOSS_LOOT_WINDOW then return nil end
        if IsOnBossLoot(run, kill, itemID) then return i end
    end
end

-- Drops -------------------------------------------------------------------------
local function NewDrop(run, itemID, link, quality)
    if not quality and C_Item.IsItemDataCachedByID(itemID) then quality = ns.Items:Quality(itemID) end
    local drop = { at = time(), item = itemID, link = link, quality = quality, rolls = {},
        lootMethod = Plain((C_PartyInfo.GetLootMethod())) }
    table.insert(run.drops, drop)
    run.lastSeenAt = drop.at
    Changed()
    return drop
end

local function IsSettled(drop)
    return drop.winner ~= nil or drop.how ~= nil
end

-- A drop seen in the loot window, recorded when Uncommon or better or on its boss's loot list.
-- One corpse's item is recorded once however often its window opens, and it joins the drop a
-- roll already started for it (START_LOOT_ROLL can come before the window is read).
local function AddLootedItem(item, kill, corpse)
    local run = here.run
    local isWanted = (item.quality or 0) >= Enum.ItemQuality.Uncommon
        or (kill ~= nil and IsOnBossLoot(run, run.kills[kill], item.id))
    if not isWanted then return end
    local now, unclaimed = time(), nil
    for _, drop in ipairs(run.drops) do
        if drop.item == item.id and now - drop.at <= DROP_MATCH_WINDOW then
            if drop.corpse ~= nil and drop.corpse == corpse then return end
            if not unclaimed and drop.corpse == nil and not IsSettled(drop) then unclaimed = drop end
        end
    end
    if unclaimed then
        -- A readable corpse settles which creature dropped it, boss or not.
        if corpse ~= nil then unclaimed.corpse, unclaimed.kill = corpse, kill end
        Changed()
        return
    end
    local drop = NewDrop(run, item.id, item.link, item.quality)
    drop.kill, drop.corpse, drop.count = kill, corpse, item.count
end

local scannedSlots = {} -- "<slot>:<item ID>" read in the loot window open now (LOOT_READY and LOOT_OPENED both come)

-- One loot window slot: each corpse or chest it pools (area loot gives guid1, count1, guid2, ...)
-- is noted for the probe and the run's copy, and the item recorded under its boss.
local function ScanLootSlot(slot)
    local link = GetLootSlotType(slot) == Enum.LootSlotType.Item and Plain(GetLootSlotLink(slot))
    local itemID = link and ns.Items:IDFromLink(link)
    if not itemID or scannedSlots[slot .. ":" .. itemID] then return end
    scannedSlots[slot .. ":" .. itemID] = true
    local _, _, slotCount, _, quality = GetLootSlotInfo(slot)
    local item = { id = itemID, link = link, quality = Plain(quality), count = Plain(slotCount) or 1 }
    local sources, isSourceKnown = { GetLootSourceInfo(slot) }, false
    for i = 1, #sources, 2 do
        NoteGUID("loot", sources[i])
        local unitType, npcID, spawnKey = ns.ParseGUID(Plain(sources[i]))
        if unitType then
            isSourceKnown = true
            local isCreature = unitType == "Creature" or unitType == "Vehicle"
            item.count = tonumber(Plain(sources[i + 1])) or item.count
            AddLootedItem(item, isCreature and KillOfCorpse(npcID) or nil, spawnKey)
        end
    end
    if not isSourceKnown then AddLootedItem(item, KillForItem(here.run, itemID), nil) end
end

local function ScanLootWindow()
    if not here.run then return end
    for slot = 1, GetNumLootItems() do ScanLootSlot(slot) end
end

ns:On("LOOT_READY", ScanLootWindow)
ns:On("LOOT_OPENED", ScanLootWindow)
ns:On("LOOT_CLOSED", function() wipe(scannedSlots) end)

-- A roll the game offers the player: it joins the item's drop from the loot window, if the
-- player looted the corpse, else starts the drop.
ns:On("START_LOOT_ROLL", function(rollID)
    local run = here.run
    rollID = Plain(rollID)
    if not (run and rollID) then return end
    local link = Plain(GetLootRollItemLink(rollID))
    local itemID = link and ns.Items:IDFromLink(link)
    if not itemID then return end
    local _, _, count, quality = GetLootRollItemInfo(rollID)
    local now, drop = time(), nil
    for _, earlier in ipairs(run.drops) do
        local isOpenForRoll = earlier.item == itemID and not earlier.rollID and not IsSettled(earlier)
            and now - earlier.at <= DROP_MATCH_WINDOW
        if earlier.rollID == rollID or (not drop and isOpenForRoll) then drop = earlier end
    end
    if not drop then
        drop = NewDrop(run, itemID, link, Plain(quality))
        drop.kill = KillForItem(run, itemID)
    end
    drop.rollID, drop.offered, drop.count = rollID, true, Plain(count) or drop.count
    Changed()
end)

-- Loot lines (CHAT_MSG_LOOT) ----------------------------------------------------
-- What the game writes about rolls and loot, read with the client's own strings, tried in this
-- order: a line can also fit a later, looser format ("x receives loot: [item]x2." fits LOOT_ITEM
-- as well as LOOT_ITEM_MULTIPLE), so the narrower ones come first. `fields` names the format's
-- values in its argument order: history (the number in the line's [Loot] link), player, item,
-- roll, count. kind: "choice" (Need, Greed, Disenchant, Pass), "roll" (the number rolled),
-- "won", "allPassed" or "received". isOwn: the line is about the player ("You ..."). A format
-- this client lacks is left out.
local LOOT_LINES = {}
local function AddLootLine(format, kind, fields, choice, isOwn, isAuto, isIneligible)
    if not format then return end
    table.insert(LOOT_LINES, { format = format, kind = kind, fields = fields, choice = choice, isOwn = isOwn,
        isAuto = isAuto, isIneligible = isIneligible })
end
local OWN_WON_FIELDS, WON_FIELDS = { "history", "roll", "item" }, { "history", "player", "roll", "item" }
AddLootLine(LOOT_ROLL_YOU_WON_NO_SPAM_NEED, "won", OWN_WON_FIELDS, "need", true)
AddLootLine(LOOT_ROLL_YOU_WON_NO_SPAM_GREED, "won", OWN_WON_FIELDS, "greed", true)
AddLootLine(LOOT_ROLL_YOU_WON_NO_SPAM_DE, "won", OWN_WON_FIELDS, "disenchant", true)
AddLootLine(LOOT_ROLL_WON_NO_SPAM_NEED, "won", WON_FIELDS, "need")
AddLootLine(LOOT_ROLL_WON_NO_SPAM_GREED, "won", WON_FIELDS, "greed")
AddLootLine(LOOT_ROLL_WON_NO_SPAM_DE, "won", WON_FIELDS, "disenchant")
AddLootLine(LOOT_ROLL_YOU_WON, "won", { "history", "item" }, nil, true)
AddLootLine(LOOT_ROLL_WON, "won", { "history", "player", "item" })
AddLootLine(LOOT_ROLL_ALL_PASSED, "allPassed", { "history", "item" })
AddLootLine(LOOT_ROLL_ROLLED_NEED, "roll", { "history", "roll", "item", "player" }, "need")
AddLootLine(LOOT_ROLL_ROLLED_GREED, "roll", { "history", "roll", "item", "player" }, "greed")
AddLootLine(LOOT_ROLL_ROLLED_DE, "roll", { "roll", "item", "player" }, "disenchant")
AddLootLine(LOOT_ROLL_PASSED_SELF_AUTO, "choice", { "history", "item" }, "pass", true, true)
AddLootLine(LOOT_ROLL_PASSED_AUTO, "choice", { "player", "item" }, "pass", false, true)
AddLootLine(LOOT_ROLL_PASSED_AUTO_FEMALE, "choice", { "player", "item" }, "pass", false, true)
AddLootLine(LOOT_ROLL_NEED_SELF, "choice", { "history", "item" }, "need", true)
AddLootLine(LOOT_ROLL_GREED_SELF, "choice", { "history", "item" }, "greed", true)
AddLootLine(LOOT_ROLL_DISENCHANT_SELF, "choice", { "history", "item" }, "disenchant", true)
AddLootLine(LOOT_ROLL_PASSED_SELF, "choice", { "history", "item" }, "pass", true)
AddLootLine(LOOT_ROLL_NEED, "choice", { "history", "player", "item" }, "need")
AddLootLine(LOOT_ROLL_GREED, "choice", { "history", "player", "item" }, "greed")
AddLootLine(LOOT_ROLL_DISENCHANT, "choice", { "player", "item" }, "disenchant")
AddLootLine(LOOT_ROLL_PASSED, "choice", { "history", "player", "item" }, "pass")
-- Shown when the player can't loot the item (an item only some can, as a Corrupted Scourgestone
-- without the Argent Dawn trinket): the item comes after the game's no-loot icon.
AddLootLine(LOOT_ITEM_WHILE_PLAYER_INELIGIBLE, "received", { "player", "item" }, nil, false, false, true)
AddLootLine(LOOT_ITEM_SELF_MULTIPLE, "received", { "item", "count" }, nil, true)
AddLootLine(LOOT_ITEM_SELF, "received", { "item" }, nil, true)
AddLootLine(LOOT_ITEM_MULTIPLE, "received", { "player", "item", "count" })
AddLootLine(LOOT_ITEM, "received", { "player", "item" })

-- An item link's place while a loot line is read: an item's name can hold any of the line's own
-- words (" by " in English), so the line is read with this mark where the link was.
local LINK_MARK = "\002"

-- The values of a matched loot line by field name, checked: the item where the link was, a
-- player name with no link or code in it, numbers that are numbers. Nil when they don't fit.
local function ReadFields(line, values)
    local read = {}
    for argument, field in ipairs(line.fields) do
        local value = values[argument]
        if not value then return nil end
        if field == "item" then
            if not value:find(LINK_MARK, 1, true) then return nil end
        elseif field == "player" then
            if value:find(LINK_MARK, 1, true) or value:find("|", 1, true) then return nil end
            read.player = value
        else
            read[field] = tonumber(value)
            if not read[field] then return nil end
        end
    end
    return read
end

-- The loot line `text`: its LOOT_LINES entry and its values (read.link: the item link it
-- names); nil when it isn't one of them or doesn't name exactly one item.
local function ReadLootLine(text)
    local links = {}
    local marked = text:gsub("|c[^|]*(|Hitem:[^|]*|h.-|h)|r", "%1"):gsub("|Hitem:[^|]*|h.-|h", function(link)
        table.insert(links, link)
        return LINK_MARK
    end)
    if #links ~= 1 then return nil end
    for _, line in ipairs(LOOT_LINES) do
        local values = ns.ReadGameText(marked, line.format)
        local read = values and ReadFields(line, values)
        if read then
            read.link = text:match("|c[^|]*|Hitem:[^|]*|h.-|h|r") or links[1]
            return line, read
        end
    end
end

-- Whether a loot line with no history number of its own drop can be about `drop`: not a drop of
-- another roll's, and not settled yet. A "receives loot" line also fits the drop its player won.
local function CanTakeLine(drop, history, kind, player)
    if history and drop.historyID then return false end
    if kind == "received" then return not drop.received and (drop.winner == nil or drop.winner == player) end
    return not IsSettled(drop)
end

-- The drop a loot line is about: the one with the line's history number (or whose roll ID it
-- is), else the oldest recent drop of the item the line can still be about; nil when none.
local function DropOfLine(run, itemID, history, kind, player)
    local now, open = time(), nil
    for _, drop in ipairs(run.drops) do
        if drop.item == itemID and now - drop.at <= DROP_MATCH_WINDOW then
            local isSameRoll = history ~= nil and (drop.historyID == history
                or (drop.historyID == nil and drop.rollID == history))
            if isSameRoll then return drop end
            if not open and CanTakeLine(drop, history, kind, player) then open = drop end
        end
    end
    return open
end

-- The player's own entry on an item the game rolled for without offering it to them.
local function MarkNotOffered(drop, isIneligible)
    local name = UnitNameOf("player")
    if not name or drop.rolls[name] or (drop.offered and not isIneligible) then return end
    drop.rolls[name] = { choice = "notOffered" }
end

local function NoteHistoryNumber(run, drop, history)
    drop.historyID = history
    if not drop.rollID then return end
    local counts = run.probe.historyID or {}
    run.probe.historyID = counts
    local field = history == drop.rollID and "rollID" or "other"
    counts[field] = (counts[field] or 0) + 1
end

-- `player` received the drop: its winner too when there was none, handed out by the master
-- looter or looted without a roll when nobody rolled.
local function NoteReceived(drop, player, isIneligible)
    local hasRolls = next(drop.rolls) ~= nil
    drop.received = player
    if not drop.winner then
        drop.winner = player
        local isMasterLoot = drop.lootMethod == Enum.LootMethod.Masterlooter
        drop.how = drop.how or (hasRolls and "roll") or (isMasterLoot and "master") or "noRoll"
    end
    if isIneligible or hasRolls then MarkNotOffered(drop, isIneligible) end
end

local function ApplyLootLine(run, drop, line, read, player)
    if read.history and not drop.historyID then NoteHistoryNumber(run, drop, read.history) end
    drop.count = read.count or drop.count
    if line.choice and player then
        local entry = drop.rolls[player] or {}
        drop.rolls[player] = entry
        entry.choice, entry.roll, entry.auto = line.choice, read.roll or entry.roll, line.isAuto or entry.auto
    end
    if line.kind == "won" then
        drop.winner, drop.how = player, "roll"
        MarkNotOffered(drop)
    elseif line.kind == "allPassed" then
        drop.how = "allPassed"
        MarkNotOffered(drop)
    elseif line.kind == "received" then
        NoteReceived(drop, player, line.isIneligible)
    end
    Changed()
end

-- A loot line inside a run, or just after leaving one (a roll can end outside): it joins the drop
-- it is about, or starts one inside. Every item rolled on is recorded; one only received, when
-- Uncommon or better.
local function OnLootLine(text)
    text = Plain(text)
    if not ns.db or type(text) ~= "string" or not text:find("|Hitem:", 1, true) then return end
    local run = here.run or Runs:Current()
    if not run then return end
    local line, read = ReadLootLine(text)
    if not line then return end
    local itemID = ns.Items:IDFromLink(read.link)
    local player = line.isOwn and UnitNameOf("player") or read.player
    local drop = DropOfLine(run, itemID, read.history, line.kind, player)
    if drop then return ApplyLootLine(run, drop, line, read, player) end
    if run ~= here.run then return end
    if line.kind ~= "received" then
        drop = NewDrop(run, itemID, read.link)
        drop.kill = KillForItem(run, itemID)
        return ApplyLootLine(run, drop, line, read, player)
    end
    ns.Items:Load(itemID, function()
        local quality = ns.Items:Quality(itemID)
        if here.run ~= run or quality < Enum.ItemQuality.Uncommon then return end
        local newDrop = NewDrop(run, itemID, read.link, quality)
        newDrop.kill = KillForItem(run, itemID)
        ApplyLootLine(run, newDrop, line, read, player)
    end)
end

ns:On("CHAT_MSG_LOOT", OnLootLine)

-- For the run pages (UI/RunPage.lua, UI/RunHistory.lua) ------------------------------
-- The run the player is in, or the latest one while it may still go on (outside for less than
-- AWAY_WINDOW, or CLEARED_WINDOW once cleared, and not closed); nil when there is none.
function Runs.Current()  -- called as Runs:Current()
    if here.run and not demoRuns then return here.run end
    if not ns.db then return nil end
    local list = ShownRuns()
    local latest = list[#list]
    if not latest or latest.closed then return nil end
    local window = latest.cleared and CLEARED_WINDOW or AWAY_WINDOW
    if SecondsOutside(latest, time()) <= window then return latest end
end

-- The player's whole name, as the roster and the rolls keep it ("Flow State").
function Runs.PlayerName()  -- called as Runs:PlayerName()
    return UnitNameOf("player")
end

-- This character's runs, oldest first (the saved list itself, or the demo's while it is on).
function Runs.List()  -- called as Runs:List()
    return ShownRuns()
end

-- Shows the made-up `runs` (oldest first) in place of the saved ones; nil puts the saved back.
function Runs.ShowDemo(_, runs)  -- called as Runs:ShowDemo(runs)
    demoRuns = runs
    Changed()
end

function Runs.IsDemo()  -- called as Runs:IsDemo()
    return demoRuns ~= nil
end

-- Whether the player is inside `run` now.
function Runs.IsInside(_, run)  -- called as Runs:IsInside(run)
    return run ~= nil and here.run == run
end

-- `listener()` runs (once per burst, CHANGE_DELAY late) whenever a run is started, joined,
-- closed or recorded into.
function Runs.OnChange(_, listener)  -- called as Runs:OnChange(listener)
    table.insert(changeListeners, listener)
end

-- `listener(run, kill)` runs as soon as a boss kill is added to the run the player is in: a new
-- kill only, not a second look at a boss already in the run's kills.
function Runs.OnKill(_, listener)  -- called as Runs:OnKill(listener)
    table.insert(killListeners, listener)
end

-- Whether `run` shows on the page of NeedRoll's dungeon or raid `instanceID`: a Stratholme run
-- is in one of its parts (RunPlaces), both shown as "STRATHOLME".
function Runs.IsIn(_, run, instanceID)  -- called as Runs:IsIn(run, instanceID)
    local instance = run.instance and ns.Data:Get(run.instance)
    return instance ~= nil and instance.id == instanceID
end

-- The latest run in NeedRoll's dungeon or raid `instanceID`, or nil when there is none.
function Runs.LatestIn(_, instanceID)  -- called as Runs:LatestIn(instanceID)
    local list = ShownRuns()
    for i = #list, 1, -1 do
        if Runs:IsIn(list[i], instanceID) then return list[i] end
    end
end

-- NeedRoll's encounter for `kill` of `run` (its boss's loot list and name), or nil for a boss
-- NeedRoll doesn't list there.
function Runs.EncounterOf(_, run, kill)  -- called as Runs:EncounterOf(run, kill)
    return EncounterOf(run.instance, kill.boss)
end

-- How many of the bosses that must die for a clear (RequiredBosses: rare spawns aside) died in
-- `run`, and how many there are: 0 of 0 where NeedRoll doesn't list the place.
function Runs.BossesDown(_, run)  -- called as Runs:BossesDown(run)
    local required, total, down = RequiredBosses(run.instance), 0, 0
    for _ in pairs(required) do total = total + 1 end
    for _, kill in ipairs(run.kills) do
        if kill.boss and required[kill.boss] then
            required[kill.boss] = nil
            down = down + 1
        end
    end
    return down, total
end

-- /nr runs new: the run the player is in closes and a new one starts; outside, the latest run
-- closes, so the next dungeon or raid entered starts a new one.
function Runs.StartNew()  -- called as Runs:StartNew()
    if here.run and not demoRuns then
        here.run.closed = "manual"
        StartRun("manual")
        ns:Print(("New run started in %s."):format(here.run.name or "?"))
        return
    end
    local list = ShownRuns()
    if list[#list] then list[#list].closed = "manual" end
    Changed()
    ns:Print(demoRuns and "The demo's run is closed." or "The next dungeon or raid you enter starts a new run.")
end

-- /nr runs ------------------------------------------------------------------------
-- Local checkouts only, so in English like the other dev commands' output.
local WHY_NEW_TEXT = {
    first = "first run here", zone = "its creatures agree on another copy (server or zoneUID)",
    reset = "the game said it was reset", away = "back after more than 90 minutes outside",
    cleared = "back after every boss was dead", manual = "started with /nr runs new",
    lockout = "another raid lockout",
}
local BACK_TEXT = { window = "back within 90 minutes", lockout = "same raid lockout" }
local LEFT_TEXT = { walked = "walked out", ghost = "released as a ghost", logout = "logged out",
    split = "a new run took over" }
local CHOICE_TEXT = { need = "Need", greed = "Greed", disenchant = "Disenchant", pass = "Pass",
    notOffered = "not offered" }
local HOW_TEXT = { roll = "won the roll", master = "given by the master looter", noRoll = "looted, no roll",
    allPassed = "everyone passed" }
local PROBE_ORDER = { "boss", "loot", "target", "mouseover", "nameplate", "partyKill", "cast", "ownCast" }

local function Clock(at)
    return date("%H:%M", at)
end

local function CopyText(run)
    local copy = run.zoneUID and ("server %d, zoneUID %d (from %s)"):format(run.serverID, run.zoneUID,
        run.identityFrom or "?") or "copy not known (no two creature GUIDs agreed on one)"
    if run.lockoutID then copy = copy .. (", lockout %s"):format(tostring(run.lockoutID)) end
    return copy
end

local function PrintVisits(run)
    for _, visit in ipairs(run.visits) do
        local parts = { "in " .. Clock(visit.entered) }
        if visit.back then table.insert(parts, "same run: " .. BACK_TEXT[visit.back]) end
        if visit.confirmedBy then table.insert(parts, "same copy seen on " .. visit.confirmedBy) end
        if visit.left then table.insert(parts, ("out %s (%s)"):format(Clock(visit.left), LEFT_TEXT[visit.leftAs])) end
        print("    " .. table.concat(parts, ", "))
    end
end

local function PrintRoster(run)
    local members = {}
    for name, class in pairs(run.roster) do table.insert(members, name .. (class and (" " .. class) or "")) end
    table.sort(members)
    print("  Group: " .. (#members > 0 and table.concat(members, ", ") or "nobody seen"))
end

local function BossName(run, kill)
    local encounter = EncounterOf(run.instance, kill.boss)
    return kill.name or (encounter and encounter.name) or ("NPC " .. tostring(kill.npcs[1]))
end

local function RollsText(drop)
    local rolls = {}
    for name, entry in pairs(drop.rolls) do
        local text = name .. " " .. CHOICE_TEXT[entry.choice]
        if entry.roll then text = text .. " " .. entry.roll end
        if entry.auto then text = text .. " (auto)" end
        table.insert(rolls, text)
    end
    table.sort(rolls)
    return table.concat(rolls, ", ")
end

local function PrintDrop(drop)
    local outcome = drop.winner and (drop.winner .. ": " .. HOW_TEXT[drop.how or "roll"])
        or (drop.how and HOW_TEXT[drop.how]) or "not settled yet"
    local count = (drop.count or 1) > 1 and ("x" .. drop.count) or ""
    print(("      %s%s  %s"):format(drop.link or ("item " .. drop.item), count, outcome))
    if next(drop.rolls) then print("          " .. RollsText(drop)) end
end

local function PrintKillsAndDrops(run)
    print(("  Bosses: %d down%s"):format(#run.kills, run.cleared and ", cleared" or ""))
    for i, kill in ipairs(run.kills) do
        local npcs = #kill.npcs > 0 and table.concat(kill.npcs, " ") or "none read"
        print(("    %s %s (encounter %s, NPC %s, from %s)"):format(Clock(kill.at), BossName(run, kill),
            tostring(kill.encounter or "?"), npcs, kill.from))
        for _, drop in ipairs(run.drops) do
            if drop.kill == i then PrintDrop(drop) end
        end
    end
    print("    Other drops:")
    for _, drop in ipairs(run.drops) do
        if not drop.kill then PrintDrop(drop) end
    end
end

local function PrintProbe(run)
    local parts = {}
    for _, source in ipairs(PROBE_ORDER) do
        local counts = run.probe[source]
        if counts then
            local text = ("%s %d/%d"):format(source, counts.readable, counts.secret)
            if counts.agrees or counts.differs then
                text = text .. (" (agrees %d, differs %d)"):format(counts.agrees or 0, counts.differs or 0)
            end
            if counts.otherMap then text = text .. (" (other map %d)"):format(counts.otherMap) end
            if counts.sample then text = text .. (" (last %s)"):format(counts.sample) end
            table.insert(parts, text)
        end
    end
    print("  GUIDs readable/secret: " .. (#parts > 0 and table.concat(parts, ", ") or "none seen"))
    local copyPairs = run.probe.copyPairs
    if copyPairs then
        print(("  Creatures one after another: same copy %d, another copy %d"):format(copyPairs.agree,
            copyPairs.differ))
    end
    local history = run.probe.historyID
    if history then
        print(("  Loot line numbers: roll ID %d, other %d"):format(history.rollID or 0, history.other or 0))
    end
end

function Runs.PrintCurrent()  -- called as Runs:PrintCurrent()
    local run = Runs:Current()
    if not run then
        ns:Print("No current run: one starts when you enter a dungeon or raid. /nr runs list shows past runs.")
        return
    end
    ns:Print(("Run: %s (%s, %s), map %d, %s"):format(run.name or "?", run.type,
        run.difficultyName or tostring(run.difficulty), run.mapID, CopyText(run)))
    local closed = run.closed and (", closed: " .. run.closed) or ""
    print(("  New run at %s: %s%s"):format(Clock(run.startedAt), WHY_NEW_TEXT[run.why], closed))
    PrintVisits(run)
    PrintRoster(run)
    PrintKillsAndDrops(run)
    PrintProbe(run)
end

function Runs.PrintList()  -- called as Runs:PrintList()
    local list = RunList()
    if #list == 0 then
        ns:Print("No runs recorded yet.")
        return
    end
    ns:Print(("The last %d of %d runs, newest first:"):format(math.min(#list, RUNS_LISTED), #list))
    for i = #list, math.max(1, #list - RUNS_LISTED + 1), -1 do
        local run = list[i]
        print(("  %s %s (%s): %d bosses, %d drops, %s%s"):format(date("%m-%d %H:%M", run.startedAt),
            run.name or "?", run.difficultyName or tostring(run.difficulty), #run.kills, #run.drops,
            WHY_NEW_TEXT[run.why], run.closed and (", closed: " .. run.closed) or ""))
    end
end
--@end-debug@]==]
