-- Trainer sharing: what WoW: Forever's other trainers really teach.
-- Core/Trainers.lua reads the player's class spells at their class trainer;
-- this file reads, a moment after any trainer window opens, every service
-- it teaches and compares it with what NeedRoll's data says:
--   - a profession trainer's recipes against the profession's page
--     (Data/Professions/*.lua: the skill a recipe is learned at, whether a
--     trainer teaches it) and Data/RecipeTrainers.lua (which trainers teach
--     it). Recipe prices aren't in the data, so they aren't compared;
--   - its Apprentice to Artisan ranks against Data/ProfessionGuide.lua
--     (level, cost, which trainers teach them; the guide has no skill for a
--     rank, so that isn't compared);
--   - a hunter pet trainer's abilities against Data/HunterPets.lua (pet
--     level, cost);
--   - at the player's own class trainer, what isn't one of the class's
--     spells, such as the rogue's poisons (Data/Poisons.lua: skill, level,
--     cost). The class's spells, and what NeedRoll doesn't list there, are
--     Core/Trainers.lua's.
-- Riding trainers and weapon masters teach nothing NeedRoll lists, so
-- nothing they teach is kept or sent.
--
-- A price is compared as the player pays it, after their reputation
-- discount with the trainer's faction (Reputation discounts in
-- Core/Trainers.lua), and a level or skill the game gives as 0 (the player
-- has reached it, see LEVEL_NOT_GIVEN there) is never compared.
--
-- What differs from the data, and what the data doesn't list, is saved and
-- sent to other copies through drop sharing as P1 messages (see Trainer
-- services in Core/Drops.lua), in the trainer lane beside A1. A trainer not
-- showing something NeedRoll says it teaches is never saved or sent: the
-- window may hide it for reasons of its own. A copy hearing a P1 saves what
-- differs from its own data, marked heard (anyone can send a trainer
-- message, so a heard report may be made up). Nothing here is shown in
-- game, the player's own reads included: they all wait for the data
-- update. The scraper's `ingest` folds NeedRollDB.trainerServices into
-- scraper/professions/trainer_services.json and lists the differences in
-- the Watcher data pull request, for Mike to check (saying which ones two
-- players' copies agree on, see Senders in Core/Trainers.lua). Once the
-- data says the same, a saved service is forgotten at login, and the
-- player's own read of it also at their next read.
--
-- Dev builds check every service, differences or not, in
-- Core/TrainerCheck.lua (/nr trainercheck), with this file's read and
-- comparing (TrainerShare.OnRead).
--
-- Saved in NeedRollDB.trainerServices, with no player names (heard ones too):
--     [spellID] = { list = "MINING" (the NeedRoll list it is on, or for one NeedRoll doesn't list, the
--             list most of the trainer's services are on: a profession's ID, "PET" or "POISONS"),
--         skill, level (each 0 when the game didn't give it), cost = <copper, as the reader pays it>,
--         name = "Smelt Iron" (English clients only), rank = 2 (a pet ability's rank; nil for none),
--         build = <the game build>, at = <time()>, npc = <the trainer's NPC ID, 0 when not known>,
--         standing = <the reader's standing with the trainer, 1 hated to 8 exalted; nil when not known>,
--         issues = { "skill", ... } (what differs, see TrainerShare.ServiceIssues),
--         listed = { level, skill, cost } (what NeedRoll's data says; nil when it doesn't list it),
--         shared = true (sent, or heard from another copy: not sent again but in a probe's answer),
--         heard = true (heard from another copy, not read here),
--         viaWhisper = true (heard by whisper, by a dev build's pull: kept out of probe answers),
--         senders = { [<sender key, Drops.SenderKey>] = { build, skill, level, cost, standing, viaWhisper } }
--             (heard only: what each player heard reported, see Senders in Core/Trainers.lua) }
local _, ns = ...

local TrainerShare = {}
ns.TrainerShare = TrainerShare

local Plain = ns.Plain
local Trainers = ns.Trainers

local READ_DELAY = 0.5   -- seconds after TRAINER_SHOW: Core/Trainers.lua's own read is over by then
local READ_TRIES = 3     -- reads a visit tries while the list comes back empty (still arriving)
local SERVICES_MAX = 600 -- services saved (a profession trainer teaches about 150); heard ones past it are dropped
local NOT_GIVEN = Trainers.LEVEL_NOT_GIVEN -- a level or skill the game gave as 0: never compared
local PET_LIST = "PET"   -- the list hunter pet abilities are filed under

-- Each profession's rank spells, Apprentice to Artisan, as the scraper's
-- professionguide.py PROFESSIONS has them: Data/ProfessionGuide.lua ships
-- each rank's level, cost and trainers, but not its spell ID.
local PROFESSION_RANK_SPELLS = {
    ALCHEMY = { 2259, 3101, 3464, 11611 },
    BLACKSMITHING = { 2018, 3100, 3538, 9785 },
    COOKING = { 2550, 3102, 3413, 18260 },
    ENCHANTING = { 7411, 7412, 7413, 13920 },
    ENGINEERING = { 4036, 4037, 4038, 12656 },
    FIRST_AID = { 3273, 3274, 7924, 10846 },
    FISHING = { 7620, 7731, 7732, 18248 },
    HERBALISM = { 2366, 2368, 3570, 11993 },
    LEATHERWORKING = { 2108, 3104, 3811, 10662 },
    MINING = { 2575, 2576, 3564, 10248 },
    SKINNING = { 8613, 8617, 8618, 10768 },
    TAILORING = { 3908, 3909, 3910, 12180 },
}

local clientBuild = tonumber((select(2, GetBuildInfo()))) -- the game build, saved with each read

-- What NeedRoll lists ---------------------------------------------------------
-- A listing is what NeedRoll's data says about one spell a trainer may
-- teach: { list = the list it is on ("MINING", "POISONS", "PET"), level,
-- skill, cost (each nil when the data has none), byTrainer (whether the
-- data says a trainer teaches it), isProfession, isRank (Apprentice to
-- Artisan) }.

local listings         -- spell ID -> its listing, built at the first look
local isProfessionList -- list -> true for a profession's, false for another list (pet abilities, poisons)

local function AddListing(spellID, listing)
    listings[spellID] = listings[spellID] or listing
    isProfessionList[listing.list] = listing.isProfession == true
end

-- Recipes: a profession's (its learned line names a trainer for a
-- trainer's, in the player's language on other clients) or a class's own
-- list (Data/Poisons.lua: a trainer's unless a quest gives it).
local function AddRecipeListings(instance, isProfession)
    for _, encounter in ipairs(instance.encounters) do
        if encounter.spellID then
            local byTrainer = not encounter.quests
            if isProfession then byTrainer = ns.Names.IsLearnedFromTrainer(encounter.learned) end
            AddListing(encounter.spellID, { list = instance.id, skill = encounter.skill and encounter.skill[1],
                level = encounter.level, cost = encounter.cost, byTrainer = byTrainer, isProfession = isProfession })
        end
    end
end

-- Apprentice to Artisan: a rank a book or a quest teaches has no trainers.
local function AddRankListings()
    for profession, rankSpells in pairs(PROFESSION_RANK_SPELLS) do
        local guide = ns.Data:ProfessionGuide(profession)
        for rankIndex, rank in ipairs(guide and guide.ranks or {}) do
            AddListing(rankSpells[rankIndex], { list = profession, level = rank.level, cost = rank.cost,
                byTrainer = rank.trainers ~= nil, isProfession = true, isRank = true })
        end
    end
end

-- Hunter pet abilities: each rank { spell ID, pet level, cost }.
local function AddPetListings()
    local pets = ns.Data.hunterPets
    for _, ability in ipairs(pets and pets.abilities or {}) do
        for _, rank in ipairs(ability.ranks) do
            AddListing(rank[1], { list = PET_LIST, level = rank[2], cost = rank[3],
                byTrainer = ability.trainer == true })
        end
    end
end

local function BuildListings()
    if listings then return end
    listings, isProfessionList = {}, {}
    for _, instance in ipairs(ns.Data:List("PROFESSION")) do AddRecipeListings(instance, true) end
    for _, instance in ipairs(ns.Data:List("CLASS")) do AddRecipeListings(instance, false) end
    AddRankListings()
    AddPetListings()
end

-- What NeedRoll's data says about spell `spellID` (see above), nil when it doesn't list it.
function TrainerShare.Listing(spellID)
    BuildListings()
    return listings[spellID]
end

-- Whether `list` is one of NeedRoll's trainer lists ("MINING", "PET", "POISONS").
function TrainerShare.IsKnownList(list)
    BuildListings()
    return isProfessionList[list] ~= nil
end

-- What NeedRoll says, as saved with a service: nil when it doesn't list it.
function TrainerShare.ListedNumbers(listing)
    if not listing then return nil end
    return { level = listing.level, skill = listing.skill, cost = listing.cost }
end

local taughtByTrainer -- trainer NPC ID -> { [spellID] = true }: what the data says each profession trainer teaches

local function AddTaught(npcID, spellID)
    taughtByTrainer[npcID] = taughtByTrainer[npcID] or {}
    taughtByTrainer[npcID][spellID] = true
end

-- What NeedRoll says profession trainer `npcID` teaches (recipes and
-- ranks), or nil for a trainer it doesn't list.
function TrainerShare.TaughtBy(npcID)
    if not taughtByTrainer then
        taughtByTrainer = {}
        for spellID, npcIDs in pairs(ns.Data.recipeTrainers.recipes) do
            for _, trainerID in ipairs(npcIDs) do AddTaught(trainerID, spellID) end
        end
        for profession, rankSpells in pairs(PROFESSION_RANK_SPELLS) do
            local guide = ns.Data:ProfessionGuide(profession)
            for rankIndex, rank in ipairs(guide and guide.ranks or {}) do
                for _, trainerID in ipairs(rank.trainers or {}) do AddTaught(trainerID, rankSpells[rankIndex]) end
            end
        end
    end
    return taughtByTrainer[npcID]
end

function TrainerShare.IsPetTrainerListed(npcID)
    local pets = ns.Data.hunterPets
    for _, trainer in ipairs(pets and pets.trainers or {}) do
        if trainer.npc == npcID then return true end
    end
    return false
end

-- Comparing -------------------------------------------------------------------
-- A trainer, as comparing needs it: { kind = "profession", "pet", "class"
-- or "other", npc, standing (nil when not known), taught (what NeedRoll says
-- this profession trainer teaches; nil for another kind or one it doesn't
-- list), list (the list most of its services are on, see TrainerList) }.

local function IsGiven(number)
    return number ~= nil and number ~= NOT_GIVEN
end

-- Whether NeedRoll doesn't list profession trainer `trainer` as teaching a
-- recipe or rank it teaches. A trainer NeedRoll doesn't list at all teaches
-- all its recipes unlisted, so only its ranks count: they say which ranks
-- a new trainer teaches (what scraper/professions/trainer_ranks.json waits for).
local function IsUnlistedTeacher(spellID, listing, trainer)
    if trainer.kind ~= "profession" or not listing.isProfession then return false end
    if trainer.taught then return not trainer.taught[spellID] end
    return listing.isRank == true
end

-- What differs between `service` ({ spellID, skill, level, cost } as a
-- trainer gave them) at `trainer` and its listing, as a list of issues, or
-- nil when nothing does. An issue is one of
--     missing  - NeedRoll doesn't list the spell
--     skill    - it needs another skill than the recipe is learned at in NeedRoll
--     level    - it needs another level than NeedRoll says
--     cost     - it costs another price than NeedRoll says, as the reader pays it
--     source   - NeedRoll says it is learned another way (a recipe, a quest, taming)
--     taughtBy - NeedRoll doesn't list this trainer for it (see IsUnlistedTeacher)
function TrainerShare.ServiceIssues(service, listing, trainer)
    if not listing then return { "missing" } end
    local issues = {}
    if IsGiven(service.skill) and listing.skill and service.skill ~= listing.skill then
        issues[#issues + 1] = "skill"
    end
    if IsGiven(service.level) and listing.level and service.level ~= listing.level then
        issues[#issues + 1] = "level"
    end
    if listing.cost and not Trainers.PaysShippedCost(listing.cost, service.cost, trainer.standing) then
        issues[#issues + 1] = "cost"
    end
    if not listing.byTrainer then
        issues[#issues + 1] = "source"
    elseif IsUnlistedTeacher(service.spellID, listing, trainer) then
        issues[#issues + 1] = "taughtBy"
    end
    return #issues > 0 and issues or nil
end

-- The value that appears most often in `values` (a list), nil for none.
function TrainerShare.MostCommon(values)
    local counts, best = {}, nil
    for _, value in ipairs(values) do
        counts[value] = (counts[value] or 0) + 1
        if not best or counts[value] > counts[best] then best = value end
    end
    return best
end

-- The open trainer --------------------------------------------------------------

local function PlayerClass()
    return Plain(select(2, UnitClass("player")))
end

local function TeachesClassSpell(services, classToken)
    for _, service in ipairs(services) do
        if Trainers.IsListedClassSpell(classToken, service.spellID) then return true end
    end
    return false
end

-- "profession", "pet", "class" (the player's own class trainer: one
-- teaching any of the class's spells) or "other" (riding trainers, weapon
-- masters and any class trainer of another class).
local function TrainerKind(services)
    if Plain(IsTradeskillTrainer()) then return "profession" end
    if Plain(C_Trainer.GetTrainerType()) == Enum.TrainerType.Pet then return "pet" end
    local classToken = PlayerClass()
    if classToken and TeachesClassSpell(services, classToken) then return "class" end
    return "other"
end

-- Whether a service is left to Core/Trainers.lua: at the player's class
-- trainer, a class spell or a spell NeedRoll doesn't list anywhere.
function TrainerShare.IsTrainersJob(kind, service)
    if kind ~= "class" then return false end
    return Trainers.IsListedClassSpell(PlayerClass(), service.spellID) or not TrainerShare.Listing(service.spellID)
end

-- The list most of a trainer's services are on, worked out from their
-- spell IDs (the game names the trainer's skill in the player's language):
-- a service NeedRoll doesn't list is filed under it. A pet trainer's is
-- always the pet abilities'; nil when none is listed.
local function TrainerList(kind, services)
    if kind == "pet" then return PET_LIST end
    local lists = {}
    for _, service in ipairs(services) do
        local listing = not TrainerShare.IsTrainersJob(kind, service) and TrainerShare.Listing(service.spellID)
        if listing then lists[#lists + 1] = listing.list end
    end
    return TrainerShare.MostCommon(lists)
end

-- The open trainer, its `services` read (see Comparing).
local function DescribeOpenTrainer(services)
    local kind = TrainerKind(services)
    local npcID = Trainers.TrainerNpcID()
    return { kind = kind, npc = npcID, standing = Trainers.TrainerStanding(),
        taught = kind == "profession" and TrainerShare.TaughtBy(npcID) or nil, list = TrainerList(kind, services) }
end

-- Saving --------------------------------------------------------------------------

local function SavedServices()
    return ns.db.trainerServices
end

-- A saved service the player read at a trainer; nil for none, or for one
-- heard from another copy.
local function OwnRead(saved)
    if saved and not saved.heard then return saved end
    return nil
end

-- A level or skill a trainer gave, or for one the player has reached
-- (NOT_GIVEN) the one `known` (an earlier report's) says.
local function KnownNumber(given, known)
    if given ~= NOT_GIVEN or not known then return given end
    return known
end

-- Whether report `report` says what saved report `kept` does: the same
-- numbers, and for a trainer NeedRoll doesn't list for it, the same trainer
-- (which trainers teach it is news).
local function IsSameReport(kept, report)
    if not (kept.skill == report.skill and kept.level == report.level and kept.cost == report.cost) then
        return false
    end
    for _, issue in ipairs(report.issues) do
        if issue == "taughtBy" then return kept.npc == report.npc end
    end
    return true
end

-- Service `spellID` as saved (see the top of this file), with what differs
-- at `trainer`; nil when nothing does, or when it can't be filed under a
-- list. `numbers` is { skill, level, cost } as the trainer gave them, a
-- level or skill not given taken from `known` (an earlier report).
local function NewReport(spellID, numbers, trainer, known)
    local listing = TrainerShare.Listing(spellID)
    local list = listing and listing.list or trainer.list
    if not list then return nil end
    local read = { spellID = spellID, skill = KnownNumber(numbers.skill or NOT_GIVEN, known and known.skill),
        level = KnownNumber(numbers.level, known and known.level), cost = numbers.cost }
    local issues = TrainerShare.ServiceIssues(read, listing, trainer)
    if not issues then return nil end
    return { list = list, skill = read.skill, level = read.level, cost = read.cost, build = clientBuild,
        at = time(), npc = trainer.npc, standing = trainer.standing, issues = issues,
        listed = TrainerShare.ListedNumbers(listing) }
end

-- Saves what read service `service` says that NeedRoll's data doesn't, and
-- forgets the player's own earlier read of it once the data agrees. True
-- when a report was saved that other copies haven't heard yet. The
-- player's own read replaces a heard report, whatever build it names.
local function SaveRead(service, trainer)
    local saved = SavedServices()
    local kept = saved[service.spellID]
    local report = NewReport(service.spellID, service, trainer, OwnRead(kept))
    if not report then
        if OwnRead(kept) then saved[service.spellID] = nil end
        return false
    end
    report.name, report.rank = Trainers.SavedName(service.name), service.rank
    local isSameReport = kept ~= nil and IsSameReport(kept, report)
    if isSameReport and not kept.heard then return false end
    -- A read agreeing with a heard report keeps its shared mark: other copies have it already.
    report.shared = isSameReport and kept.shared or nil
    saved[service.spellID] = report
    return not isSameReport
end

-- Sharing --------------------------------------------------------------------------

-- A P1 message names the list, build, trainer and standing its services were read at.
local SERVICE_GROUP_FIELDS = { "list", "build", "npc", "standing" }

-- A saved service as a P1 message's group carries it.
local function ServiceRank(spellID, seen)
    return { spell = spellID, skill = seen.skill, level = seen.level, cost = seen.cost, rank = seen.rank,
        name = seen.name, isListed = TrainerShare.Listing(spellID) ~= nil, saved = seen }
end

-- The saved services that `IsWanted(spellID, seen)` picks, grouped as P1
-- messages carry them (Trainers.GroupReports).
local function ServiceGroups(saved, IsWanted)
    return Trainers.GroupReports(saved, IsWanted, SERVICE_GROUP_FIELDS, ServiceRank)
end

-- Whether no copy has sent a saved service yet.
local function IsUnsent(_, seen)
    return not seen.shared
end

-- Queues the services this copy read that no copy has sent yet, marking
-- each one queued shared. What doesn't fit today's trainer messages waits
-- for the next read or login.
function TrainerShare.Share()
    if not ns.db then return end
    for _, group in ipairs(ServiceGroups(SavedServices(), IsUnsent)) do
        for _, message in ipairs(ns.Drops.EncodeTrainerServices(group)) do
            if not ns.Drops.QueueLaneMessage("trainer", message.text) then return end
            for _, rank in ipairs(message.ranks) do rank.saved.shared = true end
        end
    end
end

-- The services saved since time() `since`, as P1 messages for a catch-up
-- probe's answer (see Catch-up probes in Core/Drops.lua): the player's own
-- reads, sent before or not (the prober may not have them), and the
-- services heard from other copies, never in the same message. Every saved
-- service differs from NeedRoll's data (see ForgetStale). { { at, isHeard,
-- id, text }, ... }.
function TrainerShare.Answers(since)
    local answers = {}
    if not ns.db then return answers end
    for _, isHeard in ipairs({ false, true }) do
        local function IsAnswerable(_, seen)
            return (seen.heard == true) == isHeard and ns.Drops.IsProbeAnswerable(seen, since)
        end
        for _, group in ipairs(ServiceGroups(SavedServices(), IsAnswerable)) do
            Trainers.AddAnswers(answers, ns.Drops.EncodeTrainerServices(group), isHeard)
        end
    end
    return answers
end

-- Hearing --------------------------------------------------------------------------

-- The trainer a heard P1 message names, as comparing needs it.
local function HeardTrainer(heard)
    BuildListings()
    local isProfession = isProfessionList[heard.list] == true
    return { kind = isProfession and "profession" or "other", npc = heard.npc, standing = heard.standing,
        taught = isProfession and TrainerShare.TaughtBy(heard.npc) or nil, list = heard.list }
end

-- Saves one heard report; true when it changed what was saved. A service
-- saved with the same report is only marked shared. The player's own read
-- keeps its numbers whatever is heard, as does a report heard on a newer build.
local function SaveHeardReport(saved, spellID, report)
    local kept = saved[spellID]
    if kept and IsSameReport(kept, report) then
        local wasShared = kept.shared
        kept.shared = true
        return not wasShared
    end
    if OwnRead(kept) then return false end
    if kept and (kept.build or 0) > report.build then return false end
    if not kept and ns.CountKeys(saved) >= SERVICES_MAX then return false end
    report.name, report.rank = report.name or (kept and kept.name), report.rank or (kept and kept.rank)
    report.senders = kept and kept.senders
    saved[spellID] = report
    return true
end

-- Saves the services a P1 message from another copy carried (decoded by
-- Drops.DecodeTrainerServices, viaWhisper set when a dev build's pull took
-- it by whisper) that differ from this copy's data, marked
-- heard and shared, so this copy doesn't send them again. What came of it:
-- "new" when it changed anything saved, "listed" when NeedRoll's data says
-- the same for every service (as the sender pays it), else "known".
function TrainerShare.SaveHeard(heard)
    local saved, status = SavedServices(), "listed"
    local trainer = HeardTrainer(heard)
    for _, rank in ipairs(heard.ranks) do
        local report = NewReport(rank.spell, rank, trainer, saved[rank.spell])
        if report then
            report.build, report.name, report.rank = heard.build, rank.name, rank.rank
            report.shared, report.heard, report.viaWhisper = true, true, heard.viaWhisper
            local isNew = SaveHeardReport(saved, rank.spell, report)
            Trainers.NoteSender(saved[rank.spell], heard.senderKey, { build = heard.build, skill = report.skill,
                level = report.level, cost = report.cost, standing = heard.standing, viaWhisper = heard.viaWhisper })
            status = (isNew or status == "new") and "new" or "known"
        end
    end
    return status
end

-- Forgets saved services NeedRoll's data now says the same about (a data
-- update caught up), and those naming a build newer than this client's
-- (made up: they would outrank every heard report after them).
local function ForgetStale()
    local saved = SavedServices()
    for spellID, seen in pairs(saved) do
        local trainer = HeardTrainer({ list = seen.list, npc = seen.npc, standing = seen.standing })
        local isMadeUp = clientBuild and (seen.build or 0) > clientBuild
        if isMadeUp or not NewReport(spellID, seen, trainer) then saved[spellID] = nil end
    end
end

-- Visits ----------------------------------------------------------------------------
-- The read comes a moment after the window opens, not on TRAINER_SHOW:
-- Core/Trainers.lua reads a class trainer then, and waiting keeps the two
-- reads apart, each turning the filters on and putting them back. The list
-- can still be arriving, so an empty read is tried again a little later.

local visit -- while a trainer is open: { tries = <reads so far> }

-- Saves what differs among the read `services` of `trainer` and shares it.
local function SaveAndShare(trainer, services)
    if trainer.kind == "other" then return end
    local savedAny = false
    for _, service in ipairs(services) do
        if not TrainerShare.IsTrainersJob(trainer.kind, service) then
            savedAny = SaveRead(service, trainer) or savedAny
        end
    end
    if savedAny then TrainerShare.Share() end
end

local function ReadVisit(thisVisit)
    if visit ~= thisVisit or not ns.db then return end
    thisVisit.tries = thisVisit.tries + 1
    local services = Trainers.ReadEveryService()
    if #services == 0 then
        if thisVisit.tries < READ_TRIES then C_Timer.After(READ_DELAY, function() ReadVisit(thisVisit) end) end
        return
    end
    local trainer = DescribeOpenTrainer(services)
    SaveAndShare(trainer, services)
    -- Set by Core/TrainerCheck.lua in dev builds, which checks every service read.
    if TrainerShare.OnRead then TrainerShare.OnRead(trainer, services) end
end

ns:On("TRAINER_SHOW", function()
    local thisVisit = { tries = 0 }
    visit = thisVisit
    C_Timer.After(READ_DELAY, function() ReadVisit(thisVisit) end)
end)
ns:On("TRAINER_CLOSED", function() visit = nil end)

ns:On("PLAYER_LOGIN", function()
    ForgetStale()
    -- With the class trainer's ranks (Core/Trainers.lua), a while after login.
    C_Timer.After(30, TrainerShare.Share)
end)
