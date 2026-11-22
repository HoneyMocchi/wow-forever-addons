-- Class trainers: what WoW: Forever's class trainers really teach. NeedRoll's
-- class spells (Data/ClassSpells.lua) come from Classic's trainers and the
-- changes Blizzard's notes list (scraper/classes/changes.json), but Forever
-- repriced every class's training and added spells whose IDs no source has.
-- So when the player opens their own class trainer, every spell it teaches
-- is read: spell ID, level and cost, and for a spell NeedRoll doesn't list
-- its name and rank. What differs from NeedRoll's data is saved, shown on
-- the Classes tab's Abilities page in place of the shipped level and cost
-- (ns.Data:ClassSpells), so the player sees Forever's numbers before a data
-- update, and sent to other copies through drop sharing (an A1 message, see
-- Trainer ranks in Core/Drops.lua). A copy hearing one saves its ranks
-- marked heard, but doesn't show them: anyone can send a trainer message, so
-- one player's made-up numbers mustn't change every player's page. Heard ranks
-- and spells NeedRoll doesn't list wait for the data update: the scraper's
-- `ingest` folds what was saved into scraper/classes/seen.json, and
-- `trainers` builds the reads from Mike's own accounts into the data, and a
-- heard change to a listed rank once two players' copies agree on it (see
-- Senders); the rest it lists for Mike to check. Once the data says the
-- same, a trainer read drops the saved rank again.
--
-- The game gives a service's level only while the player is below it: a
-- spell they have reached reads level 0 (LEVEL_NOT_GIVEN). Such a read
-- keeps the level already known for the rank (see KnownLevel); 0 is saved
-- only for a spell no level is known for, and never shown.
--
-- The game gives a service's price after the player's reputation discount
-- with the trainer's faction (see Reputation discounts), so the player's
-- standing with the trainer is saved and sent with each rank.
--
-- WoW: Forever gives each race some spells of its own (the priest's racial
-- spells, Data/ClassSpells.lua's race), so the player's race is saved and
-- sent with each rank too: a spell NeedRoll doesn't list could be one race's
-- or every race's, and only the races that report it can tell (see Races).
-- A trainer not showing a spell is never reported: another race's racial
-- spell isn't there for this player, and an unchanged rank isn't saved.
--
-- Saved in NeedRollDB.trainerSpells, with no player names (heard ranks too):
--     [classToken] = { [spellID] = { level = <the level it needs, 0 when not known>, cost = <copper>,
--         name = "Righteous Fury" (English clients only: the scraper files spells by their English
--             names), rank = 2 (nil for a spell without ranks), build = <the game build>,
--         at = <time()>, npc = <the trainer's NPC ID, 0 when not known>,
--         standing = <the reader's standing with the trainer, 1 hated to 8 exalted; nil when not known>,
--         race = <the reader's race, the game's race ID (3 Dwarf); nil when not known>,
--         shared = true (sent, or heard from another copy: not sent again but in a probe's answer),
--         heard = true (heard from another copy, not read here: not shown),
--         viaWhisper = true (heard by whisper, by a dev build's pull: kept out of probe answers),
--         senders = { [<sender key, Drops.SenderKey>] = { build, level, cost, standing, viaWhisper } } (heard
--             only: what each player heard reported, see Senders) } }
local _, ns = ...

local Trainers = {}
ns.Trainers = Trainers

local Plain = ns.Plain

-- The trainer window's filters ("Available", "Unavailable", "Used") hide
-- services from the list the game hands addons too, so a read turns them
-- all on and then puts them back as the player had them.
local SERVICE_FILTERS = { "available", "unavailable", "used" }
-- TRAINER_UPDATE retries a read that found nothing (the list still
-- arriving), but turning the filters on and off fires it too, so a visit
-- reads at most this many times.
local READS_PER_VISIT = 3
local NAME_MAX = 40       -- bytes of a spell's name saved
local SPELLS_MAX = 600    -- ranks saved per class (a class teaches about 250); heard ones past it are dropped
local LEVEL_NOT_GIVEN = 0 -- the level the game gives a service the player has reached
local STANDING_MAX = 8    -- exalted, the highest standing UnitReaction gives
local RACE_MAX = 100      -- the highest race ID taken from the game (its playable races are far below)

local clientBuild = tonumber((select(2, GetBuildInfo()))) -- the game build, saved with each rank read

-- Whether the open trainer trains a class: the game's general trainer type
-- and no profession trainer (weapon masters train as one), so neither a pet
-- trainer nor a riding trainer.
local function IsClassTrainer()
    if Plain(IsTradeskillTrainer()) then return false end
    return Plain(C_Trainer.GetTrainerType()) == Enum.TrainerType.General
end

-- The open trainer's NPC ID, or 0 when its GUID can't be read.
local function TrainerNpcID()
    return ns.NpcIDOf("npc")
end

-- The player's standing with the open trainer's faction, as a number the
-- same in every client's language: 4 neutral, 5 friendly, 6 honored, 7
-- revered, 8 exalted (1 to 3 below neutral). Nil when the game doesn't say.
local function TrainerStanding()
    local standing = Plain(UnitReaction("npc", "player"))
    if type(standing) ~= "number" or standing < 1 or standing > STANDING_MAX then return nil end
    return standing
end

-- The player's race as the game's race ID (UnitRace's third return), the
-- same in every client's language; nil when the game doesn't say.
local function PlayerRaceID()
    local raceID = Plain(select(3, UnitRace("player")))
    if type(raceID) ~= "number" or raceID < 1 or raceID > RACE_MAX then return nil end
    return raceID
end

-- One trainer service as { spellID, level, cost, name, rank }; nil for a
-- header, or a service whose spell the game hasn't sent yet. The spell ID
-- is only in the service's tooltip data.
local function ReadService(index)
    local name, rankText, serviceType = GetTrainerServiceInfo(index)
    if Plain(serviceType) == "header" then return nil end
    local tooltip = C_TooltipInfo.GetTrainerService(index)
    local service = {
        spellID = tooltip and Plain(tooltip.id), level = Plain(GetTrainerServiceLevelReq(index)),
        cost = Plain((GetTrainerServiceCost(index))), name = Plain(name),
    }
    if not (type(service.spellID) == "number" and type(service.level) == "number"
        and type(service.cost) == "number") then
        return nil
    end
    rankText = Plain(rankText)
    -- "Rank 3" in English, "Rang 3" in German: only the number is kept.
    service.rank = type(rankText) == "string" and tonumber(rankText:match("%d+")) or nil
    -- The skill level the service needs, for Core/TrainerShare.lua: a
    -- profession trainer's recipes and the rogue's poisons need one, a class
    -- trainer's spells don't (nil). Its name is in the player's language.
    local skill = Plain((select(2, GetTrainerServiceSkillReq(index))))
    service.skill = type(skill) == "number" and skill or nil
    --[==[@debug@
    -- For Core/TrainerCheck.lua (local checkouts only): the game's rank text
    -- ("Rank 2", "Journeyman"; nil for none) and the needed skill's name.
    service.rankText = type(rankText) == "string" and rankText ~= "" and rankText or nil
    local skillName = Plain((GetTrainerServiceSkillReq(index)))
    service.skillName = type(skillName) == "string" and skillName or nil
    --@end-debug@]==]
    return service
end

local function ReadServices()
    local services = {}
    for index = 1, Plain(GetNumTrainerServices()) or 0 do
        services[#services + 1] = ReadService(index)
    end
    return services
end

-- Runs `read` with every filter on, then puts the filters and the picked
-- service back as they were. It all happens before the game draws the
-- window again, so the player sees nothing change.
local function WithEveryServiceShown(read)
    local wasShown, picked = {}, Plain(GetTrainerSelectionIndex())
    for _, filter in ipairs(SERVICE_FILTERS) do
        wasShown[filter] = GetTrainerServiceTypeFilter(filter) and true or false
        if not wasShown[filter] then SetTrainerServiceTypeFilter(filter, true) end
    end
    local ok, result = pcall(read)
    for _, filter in ipairs(SERVICE_FILTERS) do
        if not wasShown[filter] then SetTrainerServiceTypeFilter(filter, false) end
    end
    if picked and picked > 0 and Plain(GetTrainerSelectionIndex()) ~= picked then SelectTrainerService(picked) end
    if not ok then error(result, 0) end
    return result
end

-- Each class's shipped ranks by spell ID: { level, cost, race } (level and
-- cost nil for a rank 1 no trainer teaches, race nil but for a racial
-- spell), worked out once per class token.
local shippedRanks = {}

local function ShippedRank(classToken, spellID)
    if not shippedRanks[classToken] then
        local bySpellID = {}
        local data = ns.Data:ShippedClassSpells(classToken)
        for _, spell in ipairs(data and data.spells or {}) do
            for _, rank in ipairs(spell.ranks) do
                bySpellID[rank[1]] = { level = rank[2], cost = rank[3], race = spell.race }
            end
        end
        shippedRanks[classToken] = bySpellID
    end
    return shippedRanks[classToken][spellID]
end

-- Races ----------------------------------------------------------------------
-- A racial spell is one race's alone, so NeedRoll lists it only for a
-- reader of that race: for a reader of another race it counts as a spell
-- NeedRoll doesn't list (sent with its name, for the scraper to look at).
-- A reader whose race isn't known (a T1 message from a copy before races
-- were sent, a rank saved before then) is taken as any race.

-- The shipped rank of spell `spellID` as NeedRoll lists it for a reader of
-- race `race`; nil when it lists none for them.
local function ListedRank(classToken, spellID, race)
    local shipped = ShippedRank(classToken, spellID)
    if shipped and shipped.race and race and shipped.race ~= race then return nil end
    return shipped
end

-- Whether a report of spell `spellID` by a reader of race `race` tells
-- what a kept report with the same level and cost doesn't: for a spell
-- NeedRoll doesn't list for that race, that this race is taught it too.
-- Which races are taught such a spell tells one race's spell from every
-- race's, so it's saved and sent.
local function IsNewRace(classToken, spellID, kept, race)
    return race ~= nil and kept.race ~= race and not ListedRank(classToken, spellID, race)
end

-- Reputation discounts -------------------------------------------------------
-- A trainer asks less of a player in good standing with its faction: 5%
-- off at friendly and 5% more each standing up, 20% off at exalted, and
-- GetTrainerServiceCost gives the price after it. So an honored player
-- reads 90 copper for a spell NeedRoll ships at 1 silver, which is the same
-- price, not a change. The percent of the whole price paid, by standing;
-- below friendly the whole price.
local PRICE_PERCENT_BY_STANDING = { [5] = 95, [6] = 90, [7] = 85, [8] = 80 }

-- Whether `cost` is `shippedCost` with `percent` of it paid. Every
-- discounted price players have read so far came out whole (trainers'
-- prices are round), so whether the game rounds a part copper down or to
-- the nearest isn't known: either way counts.
local function IsDiscountedCost(shippedCost, cost, percent)
    local discounted = shippedCost * percent / 100
    return cost == math.floor(discounted) or cost == math.ceil(discounted)
end

-- Whether a player at `standing` pays `cost` for a rank NeedRoll ships at
-- `shippedCost` (nil for a rank shipped without a price). With no standing
-- known (a T1 message from a copy before v1.8.0, a rank saved before
-- standings were, or a game that didn't say), any discount counts.
local function PaysShippedCost(shippedCost, cost, standing)
    if not shippedCost then return false end
    if cost == shippedCost then return true end
    if standing then
        local percent = PRICE_PERCENT_BY_STANDING[standing]
        return percent ~= nil and IsDiscountedCost(shippedCost, cost, percent)
    end
    for _, percent in pairs(PRICE_PERCENT_BY_STANDING) do
        if IsDiscountedCost(shippedCost, cost, percent) then return true end
    end
    return false
end

-- Whether NeedRoll's data gives a reader of race `race` spell `spellID`
-- at this level and cost, the cost as a player at `standing` pays it (see
-- Reputation discounts).
local function MatchesShipped(classToken, spellID, level, cost, standing, race)
    local listed = ListedRank(classToken, spellID, race)
    return listed ~= nil and listed.level == level and PaysShippedCost(listed.cost, cost, standing)
end

-- Whether NeedRoll's data gives a reader of race `race` spell `spellID` at
-- exactly this level and cost.
local function IsShippedExactly(classToken, spellID, level, cost, race)
    local listed = ListedRank(classToken, spellID, race)
    return listed ~= nil and listed.level == level and listed.cost == cost
end

-- A saved rank the player read at their own trainer; nil for none, or for
-- one heard from another copy.
local function OwnRead(seen)
    if seen and not seen.heard then return seen end
    return nil
end

-- The level a trainer gave for spell `spellID`, or for a reached spell
-- (LEVEL_NOT_GIVEN) the one already known: the player's own earlier read,
-- else NeedRoll's data; LEVEL_NOT_GIVEN still when neither has one.
local function KnownLevel(classToken, spellID, level)
    if level ~= LEVEL_NOT_GIVEN then return level end
    local kept = OwnRead((ns.db.trainerSpells[classToken] or {})[spellID])
    if kept and kept.level ~= LEVEL_NOT_GIVEN then return kept.level end
    local shipped = ShippedRank(classToken, spellID)
    return shipped and shipped.level or LEVEL_NOT_GIVEN
end

-- Whether any of `services` is a spell NeedRoll lists for the class. Every
-- class trainer teaches some, so a trainer teaching none (a weapon master
-- or a pet trainer the trainer type didn't give away) isn't read.
local function TeachesListedSpell(classToken, services)
    for _, service in ipairs(services) do
        if ShippedRank(classToken, service.spellID) then return true end
    end
    return false
end

local function SavedRanks(classToken)
    local saved = ns.db.trainerSpells[classToken] or {}
    ns.db.trainerSpells[classToken] = saved
    return saved
end

-- A spell name as saved: English clients only, cut short.
local function SavedName(name)
    if type(name) ~= "string" or not GetLocale():match("^en") then return nil end
    return ns.CutToBytes(name, NAME_MAX)
end

-- Saves what a read service says that NeedRoll's data doesn't, and forgets
-- a saved rank the data has caught up with. True when a rank was saved that
-- other copies haven't heard yet. A rank whose price differs from NeedRoll's
-- only by the player's discount is saved too, so the Abilities page shows
-- what the player pays there, but it isn't a change: it isn't sent (see
-- UnsentGroups) and returns false.
-- The player's own read replaces a heard rank, whatever build it names.
-- `reader` is { npc, standing, race }, each as the read gave it.
local function SaveRead(classToken, service, reader)
    local saved = SavedRanks(classToken)
    if IsShippedExactly(classToken, service.spellID, service.level, service.cost, reader.race) then
        saved[service.spellID] = nil
        return false
    end
    local kept = saved[service.spellID]
    local isSameReport = kept and kept.level == service.level and kept.cost == service.cost
        and not IsNewRace(classToken, service.spellID, kept, reader.race)
    if isSameReport and not kept.heard then return false end
    -- A read agreeing with a heard rank keeps its shared mark: other copies have it already.
    saved[service.spellID] = { level = service.level, cost = service.cost, name = SavedName(service.name),
        rank = service.rank, build = clientBuild, at = time(), npc = reader.npc, standing = reader.standing,
        race = reader.race, shared = isSameReport and kept.shared or nil }
    if isSameReport then return false end
    return not MatchesShipped(classToken, service.spellID, service.level, service.cost, reader.standing, reader.race)
end

-- Live copies ----------------------------------------------------------------
-- ns.Data:ClassSpells hands out a live copy of each class's spells: the
-- shipped ranks with the levels and costs the player read at their own
-- trainer over them (never heard ones). The copy is made once per class and
-- changed in place, so a page that keeps a spell sees a level or cost read
-- later.
local liveSpells = {}

local function CopySpells(shipped)
    local live = {}
    for key, value in pairs(shipped) do live[key] = value end
    live.spells = {}
    for spellIndex, spell in ipairs(shipped.spells) do
        local copy = {}
        for key, value in pairs(spell) do copy[key] = value end
        copy.ranks = {}
        for rankIndex, rank in ipairs(spell.ranks) do copy.ranks[rankIndex] = { rank[1], rank[2], rank[3] } end
        live.spells[spellIndex] = copy
    end
    return live
end

-- Sets each rank of a live copy to the level and cost the player read, or
-- the shipped ones (the shipped level for a read that gave none). A rank 1
-- shipped as coming from a quest or talent (`first`) that a trainer was
-- read teaching, at a level, is a trainer's after all, as the scraper makes
-- it (classspells.py).
local function ApplySaved(classToken, live, shipped)
    local saved = ns.db and ns.db.trainerSpells[classToken] or {}
    for spellIndex, spell in ipairs(live.spells) do
        local shippedSpell = shipped.spells[spellIndex]
        spell.first = shippedSpell.first
        for rankIndex, rank in ipairs(spell.ranks) do
            local shippedRank, read = shippedSpell.ranks[rankIndex], OwnRead(saved[rank[1]])
            local readLevel = read and read.level ~= LEVEL_NOT_GIVEN and read.level or nil
            rank[2] = readLevel or shippedRank[2]
            rank[3] = read and read.cost or shippedRank[3]
            if readLevel and rankIndex == 1 then spell.first = nil end
        end
    end
end

-- Class `classToken`'s live copy of `shipped` (see Live copies).
function Trainers.Live(classToken, shipped)
    if not liveSpells[classToken] then
        liveSpells[classToken] = CopySpells(shipped)
        ApplySaved(classToken, liveSpells[classToken], shipped)
    end
    return liveSpells[classToken]
end

-- Puts the levels and costs the player read for class `classToken` on its
-- live copy again, after a read changed them.
function Trainers.Refresh(classToken)
    local live, shipped = liveSpells[classToken], ns.Data:ShippedClassSpells(classToken)
    if live and shipped then ApplySaved(classToken, live, shipped) end
end

-- Sharing ------------------------------------------------------------------

-- Whether a saved rank differs from NeedRoll's data for the reader by
-- more than their discount.
local function IsChange(classToken, spellID, seen)
    return not MatchesShipped(classToken, spellID, seen.level, seen.cost, seen.standing, seen.race)
end

-- The key of the group a saved report goes in (see Trainers.GroupReports):
-- the fields `groupedBy` lists, joined, 0 for one the report lacks.
local function ReportGroupKey(seen, groupedBy)
    local fields = {}
    for index, field in ipairs(groupedBy) do fields[index] = seen[field] or 0 end
    return table.concat(fields, ":")
end

-- A new group for saved report `seen`: the fields `groupedBy` lists, 0 for
-- one the report lacks, and no ranks yet.
local function NewReportGroup(seen, groupedBy)
    local group = { ranks = {} }
    for _, field in ipairs(groupedBy) do group[field] = seen[field] or 0 end
    return group
end

-- The saved reports of `saved` ([spellID] = report) that `IsWanted(spellID,
-- seen)` picks, grouped by the report fields `groupedBy` lists (a message
-- names each of them once; 0 for one a report lacks), as { <those fields>,
-- ranks = { RankOf(spellID, seen), ... } }: the groups in the order of their
-- keys (ReportGroupKey), each group's ranks in spell ID order. A1 messages are
-- grouped by it here, and P1 messages in Core/TrainerShare.lua.
function Trainers.GroupReports(saved, IsWanted, groupedBy, RankOf)
    local groups, order = {}, {}
    for spellID, seen in pairs(saved) do
        if IsWanted(spellID, seen) then
            local key = ReportGroupKey(seen, groupedBy)
            if not groups[key] then
                groups[key] = NewReportGroup(seen, groupedBy)
                order[#order + 1] = key
            end
            table.insert(groups[key].ranks, RankOf(spellID, seen))
        end
    end
    table.sort(order)
    local sorted = {}
    for _, key in ipairs(order) do
        table.sort(groups[key].ranks, function(a, b) return a.spell < b.spell end)
        sorted[#sorted + 1] = groups[key]
    end
    return sorted
end

-- An A1 message names the build, trainer, standing and race its ranks were read at.
local RANK_GROUP_FIELDS = { "build", "npc", "standing", "race" }

-- The saved ranks of class `classToken` that `IsWanted(spellID, seen)`
-- picks, grouped as A1 messages carry them (Trainers.GroupReports).
local function RankGroups(classToken, saved, IsWanted)
    local function RankOf(spellID, seen)
        return { spell = spellID, level = seen.level, cost = seen.cost, rank = seen.rank, name = seen.name,
            isListed = ListedRank(classToken, spellID, seen.race) ~= nil, saved = seen }
    end
    return Trainers.GroupReports(saved, IsWanted, RANK_GROUP_FIELDS, RankOf)
end

-- Queues the ranks this copy read that no copy has sent yet, marking each
-- one queued shared. What doesn't fit today's trainer messages waits for
-- the next read or login.
function Trainers.Share()
    if not ns.db then return end
    for classToken, saved in pairs(ns.db.trainerSpells) do
        -- Still waiting to be sent: no copy has sent it, and it is a change.
        local function IsUnsentChange(spellID, seen)
            return not seen.shared and IsChange(classToken, spellID, seen)
        end
        for _, group in ipairs(RankGroups(classToken, saved, IsUnsentChange)) do
            for _, message in ipairs(ns.Drops.EncodeTrainerRanks(classToken, group)) do
                if not ns.Drops.QueueLaneMessage("trainer", message.text) then return end
                for _, rank in ipairs(message.ranks) do rank.saved.shared = true end
            end
        end
    end
end

-- Adds trainer messages (each { text, ranks }, as Drops.PackTrainerRanks
-- makes them, each rank's saved report in rank.saved) to a probe's
-- `answers` as { at, isHeard, id, text }, each at the time of the newest
-- report it carries. Core/TrainerShare.lua adds its P1 messages with it too.
function Trainers.AddAnswers(answers, messages, isHeard)
    for _, message in ipairs(messages) do
        local newestAt = 0
        for _, rank in ipairs(message.ranks) do newestAt = math.max(newestAt, rank.saved.at or 0) end
        answers[#answers + 1] = { at = newestAt, isHeard = isHeard, id = message.text:match("^[^\t]*"),
            text = message.text }
    end
end

-- The ranks saved since time() `since` that still differ from NeedRoll's
-- data, as A1 messages for a catch-up probe's answer (see Catch-up probes
-- in Core/Drops.lua): the player's own reads, sent before or not (the
-- prober may not have them), and the ranks heard from other copies, never
-- in the same message. { { at, isHeard, id, text }, ... }.
function Trainers.Answers(since)
    local answers = {}
    if not ns.db then return answers end
    for classToken, saved in pairs(ns.db.trainerSpells) do
        for _, isHeard in ipairs({ false, true }) do
            local function IsAnswerable(spellID, seen)
                return (seen.heard == true) == isHeard and ns.Drops.IsProbeAnswerable(seen, since)
                    and IsChange(classToken, spellID, seen)
            end
            for _, group in ipairs(RankGroups(classToken, saved, IsAnswerable)) do
                Trainers.AddAnswers(answers, ns.Drops.EncodeTrainerRanks(classToken, group), isHeard)
            end
        end
    end
    return answers
end

-- Senders ------------------------------------------------------------------
-- A heard rank or service keeps, for each player heard reporting it, their
-- build, numbers and standing, the price as that player paid it (see
-- Drops.NoteSender), so the scraper can take the discount out of each (two
-- players at different standings pay different prices for the same rank).
-- The saved rank itself stays the one heard last.

-- Keeps what the player with key `senderKey` reported (`report`: build,
-- numbers, standing, viaWhisper) on saved heard rank or service `kept`
-- (Drops.NoteSender). Nothing for a report not saved as heard: the
-- player's own read wins.
function Trainers.NoteSender(kept, senderKey, report)
    if not (kept and kept.heard) then return end
    ns.Drops.NoteSender(kept, senderKey, report)
end

-- Saves one heard rank; true when it changed what was saved. A rank saved
-- with the same level and cost is only marked shared, unless the sender's
-- race is news for it (see IsNewRace). The player's own read keeps its
-- numbers and race whatever is heard, as does a rank heard on a newer build.
local function SaveHeardRank(saved, heard, rank)
    local kept = saved[rank.spell]
    if kept and kept.level == rank.level and kept.cost == rank.cost
        and not IsNewRace(heard.class, rank.spell, kept, heard.race) then
        local wasShared = kept.shared
        kept.shared = true
        return not wasShared
    end
    if OwnRead(kept) then return false end
    if kept and (kept.build or 0) > heard.build then return false end
    if not kept and ns.CountKeys(saved) >= SPELLS_MAX then return false end
    saved[rank.spell] = { level = rank.level, cost = rank.cost, name = rank.name or (kept and kept.name),
        rank = rank.rank or (kept and kept.rank), build = heard.build, at = time(), npc = heard.npc,
        standing = heard.standing, race = heard.race, shared = true, heard = true, viaWhisper = heard.viaWhisper,
        senders = kept and kept.senders }
    return true
end

-- Saves the ranks a trainer message from another copy carried (decoded by
-- Drops.DecodeTrainerRanks, viaWhisper set when a dev build's pull took it
-- by whisper), marked heard, so they wait for the data
-- update instead of showing (see the top of this file), and shared, so this
-- copy doesn't send them again. What came of it: "new" when it changed
-- anything saved, "listed" when NeedRoll's data says the same for every
-- rank (for the sender's race, as they pay it, see Races and Reputation
-- discounts), else "known".
function Trainers.SaveHeard(heard)
    local saved, status = SavedRanks(heard.class), "listed"
    for _, rank in ipairs(heard.ranks) do
        rank.level = KnownLevel(heard.class, rank.spell, rank.level)
        if not MatchesShipped(heard.class, rank.spell, rank.level, rank.cost, heard.standing, heard.race) then
            local isNew = SaveHeardRank(saved, heard, rank)
            Trainers.NoteSender(saved[rank.spell], heard.senderKey, { build = heard.build, level = rank.level,
                cost = rank.cost, standing = heard.standing, viaWhisper = heard.viaWhisper })
            status = (isNew or status == "new") and "new" or "known"
        end
    end
    return status
end

-- Forgets saved ranks that name a build newer than this client's: made up,
-- heard before Drops.DecodeTrainerRanks refused such builds, and they would
-- outrank every heard report after them.
local function ForgetMadeUpBuilds()
    if not clientBuild then return end
    for _, saved in pairs(ns.db.trainerSpells) do
        for spellID, seen in pairs(saved) do
            if (seen.build or 0) > clientBuild then saved[spellID] = nil end
        end
    end
end

-- Reading ------------------------------------------------------------------

local visit -- while a trainer is open: { reads = <tries>, done = true once read, reading = true during one }

-- Reads the open trainer once it's the player's class trainer, saves what
-- differs and shares it.
local function ReadTrainer()
    if not (ns.db and visit) or visit.done or visit.reading or visit.reads >= READS_PER_VISIT then return end
    if not IsClassTrainer() then
        visit.done = true
        return
    end
    local classToken = Plain(select(2, UnitClass("player")))
    if not (classToken and ns.Data:ShippedClassSpells(classToken)) then return end
    visit.reads, visit.reading = visit.reads + 1, true
    local ok, services = pcall(WithEveryServiceShown, ReadServices)
    visit.reading = false
    if not ok then error(services, 0) end
    if not TeachesListedSpell(classToken, services) then return end
    visit.done = true
    local reader, savedAny = { npc = TrainerNpcID(), standing = TrainerStanding(), race = PlayerRaceID() }, false
    for _, service in ipairs(services) do
        service.level = KnownLevel(classToken, service.spellID, service.level)
        savedAny = SaveRead(classToken, service, reader) or savedAny
    end
    Trainers.Refresh(classToken)
    if savedAny then Trainers.Share() end
end

-- For Core/TrainerShare.lua, which reads every other trainer kind with
-- this file's reading and compares prices the way it does.
Trainers.LEVEL_NOT_GIVEN = LEVEL_NOT_GIVEN
Trainers.TrainerNpcID = TrainerNpcID
Trainers.TrainerStanding = TrainerStanding
Trainers.PaysShippedCost = PaysShippedCost
Trainers.SavedName = SavedName

-- Every service the open trainer teaches, whatever its filters show.
function Trainers.ReadEveryService()
    return WithEveryServiceShown(ReadServices)
end

-- Whether spell `spellID` is one of class `classToken`'s spells in NeedRoll's data.
function Trainers.IsListedClassSpell(classToken, spellID)
    return ShippedRank(classToken, spellID) ~= nil
end

ns:On("TRAINER_SHOW", function()
    visit = { reads = 0 }
    ReadTrainer()
end)
ns:On("TRAINER_UPDATE", ReadTrainer)
ns:On("TRAINER_CLOSED", function() visit = nil end)

ns:On("PLAYER_LOGIN", function()
    ForgetMadeUpBuilds()
    for classToken in pairs(liveSpells) do Trainers.Refresh(classToken) end
    -- A while after login, as the rest of drop sharing starts (Core/Drops.lua
    -- picks up what the last session left unsent 20 seconds in).
    C_Timer.After(30, Trainers.Share)
end)
