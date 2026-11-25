-- The Classes tab's questlines: a class's quests that run as one line to a
-- spell or a reward (Data/ClassQuests.lua's RegisterClassQuestFolds: the
-- warrior's Defensive Stance, the warlock's Summon Voidwalker). In the
-- Quests section each is a fold: its row names the questline, its progress
-- ("8/13", "✓ 4/4") and where the player stands ("Not started  ·  Level
-- 30"); open, it lists what the questline teaches, then one row per part
-- (the steps everyone does first, each branch, the final steps), each with
-- its progress, a click opening its first quest not done. Clicking the
-- fold's row opens the questline's page in the content pane: what it
-- teaches, a pill per branch, and the questline as numbered steps down a
-- spine: each step a card, or a box holding a step of several quests (the
-- branches side by side, each column's own steps down it; a dungeon
-- chain's step whose quests are all needed), solid gold for "Do both, any
-- order", dashed for "Pick one" (alternatives, one per race or city: the
-- ones not taken dimmed once one is done). Alternatives one per race (the
-- priest's racial spells) put the player's race's first and grey the other
-- races' out. A questline can have a second stage done after the first (its
-- followUp: Defensive Stance's weapon quests, one per race's path), drawn
-- and listed the same way under it, its steps numbered on. Lead-ins and
-- retries a player may skip are optional: a dashed card with an "Optional"
-- tag and no number, a breadcrumb a signpost chip over the step it leads
-- to, and no progress counts them. A step done by any one of several
-- copies of one quest (a version step: the city copies of one breadcrumb)
-- is one card showing the one starting nearest the player; one of several
-- different quests is a "Pick one" box. A card opens its
-- quest's page; the tab keeps the trail followed so ‹ and a right-click go
-- back. The model and the page take their quests from a lookup the
-- questline gives, so the Dungeons tab draws a dungeon's quest chains with
-- the same page (UI/DungeonQuestlines.lua, Questlines.CreatePage).
local _, ns = ...
local Theme = ns.Theme
local Size = Theme.size
local L = ns.L

local Questlines = {}
ns.UI.Questlines = Questlines

local TICK = "|A:common-icon-checkmark:11:11|a"  -- before a done questline's or part's figure
local DIM_ALPHA = 0.4      -- a branch not taken, once another is done
Questlines.DIM_ALPHA = DIM_ALPHA -- also its row in the Classes list's fold (UI/Lists.lua)

-- The questlines ------------------------------------------------------------------

-- The quests of `questIDs` that side `side` can take, each the page
-- findQuest(questID) gives (the questline's own lookup: a class's quests,
-- or a dungeon's with its chain steps).
local function SideQuests(findQuest, questIDs, side)
    local quests = {}
    for _, questID in ipairs(questIDs or {}) do
        local quest = findQuest(questID)
        if quest and (not quest.side or quest.side == side) then table.insert(quests, quest) end
    end
    return quests
end

-- The steps of `steps` (a fold's list: quest IDs and version steps, see
-- Data's RegisterClassQuestFolds) that side `side` can take: each quest, a
-- version step as the one quest of it the side can take, else as an entry
-- of its versions ({ variants = { quest, ... } }, placed by PlaceVersionSteps).
local function SideSteps(findQuest, steps, side)
    local sideSteps = {}
    for _, step in ipairs(steps or {}) do
        local versions = SideQuests(findQuest, type(step) == "table" and step or { step }, side)
        if #versions == 1 then
            table.insert(sideSteps, versions[1])
        elseif #versions > 1 then
            table.insert(sideSteps, { variants = versions })
        end
    end
    return sideSteps
end

-- Puts in place of each version step's entry in stage `line` the quest it
-- shows, noting in `versionSteps` where it sits: { entry, line, quests (the
-- list holding it), index, isPick }, for PickNearestVersions. `isPick`: the
-- fold's versions are choices (a dungeon's questline, `pickVersions`).
local function PlaceVersionSteps(line, versionSteps, isPick)
    local lists = { line.steps, line.finish }
    for _, branch in ipairs(line.branches) do table.insert(lists, branch.quests) end
    for _, quests in ipairs(lists) do
        for index, step in ipairs(quests) do
            if step.variants then
                table.insert(versionSteps,
                    { entry = step, line = line, quests = quests, index = index, isPick = isPick })
            end
        end
    end
end

-- A version step `entry` as a "Pick one" group (see AddAllOfGroups): each
-- version a member of its own, `shown` (the copy the step shows) among its
-- quests so the page finds the group by it. Nil when every version has the
-- same name: copies of one quest from different givers stay one card.
local function PickGroup(entry, shown)
    local firstName, hasOtherName = entry.variants[1].name, false
    for _, variant in ipairs(entry.variants) do hasOtherName = hasOtherName or variant.name ~= firstName end
    if not hasOtherName then return nil end
    local group = { kind = "pick", members = {}, quests = { shown } }
    for _, variant in ipairs(entry.variants) do
        table.insert(group.members, { variant })
        table.insert(group.quests, variant)
    end
    return group
end

-- Shows each of `versionSteps` (PlaceVersionSteps) as its version starting
-- nearest the player now (ns.UI.PickNearestQuests): a copy reading done
-- once any version is, with versionCount, how many versions there are, and
-- for versions that are choices its "Pick one" group (PickGroup) in its
-- stage's groupOf.
local function PickNearestVersions(versionSteps)
    for _, versionStep in ipairs(versionSteps) do
        local entry, groupOf = versionStep.entry, versionStep.line.groupOf
        if versionStep.shown then groupOf[versionStep.shown] = nil end
        ns.UI.PickNearestQuests({ entry })
        entry.quest.versionCount = #entry.variants
        versionStep.quests[versionStep.index] = entry.quest
        versionStep.shown = entry.quest
        groupOf[entry.quest] = versionStep.isPick and PickGroup(entry, entry.quest) or nil
    end
end

-- Marks the steps of `allOf` whose quests are all needed (a dungeon's
-- questline: Data/Chains.lua's { all = ... }, each a list of runs of quest
-- IDs) as groups of stage `line`: line.groupOf[quest] = { kind = "all",
-- members (a list of quests each, done in order), quests (all of them) },
-- for each quest side `side` can take. The stage's lists hold the quests
-- one after another (each counts towards progress); the page draws them as
-- one step, the members side by side.
local function AddAllOfGroups(line, findQuest, allOf, side)
    for _, runs in ipairs(allOf or {}) do
        local group = { kind = "all", members = {}, quests = {} }
        for _, run in ipairs(runs) do
            local member = SideQuests(findQuest, run, side)
            if #member > 0 then table.insert(group.members, member) end
            for _, quest in ipairs(member) do table.insert(group.quests, quest) end
        end
        if #group.members > 1 then
            for _, quest in ipairs(group.quests) do line.groupOf[quest] = group end
        end
    end
end

-- A stage of a fold (the fold itself, or its followUp) as side `side` can
-- do it: { findQuest, steps = { quest, ... }, branches = { { quests,
-- labelName, races }, ... }, finish = { quest, ... }, oneOf, isOptional (the
-- fold's), groupOf (the steps of several quests drawn as one: a dungeon
-- chain's whose quests are all needed, AddAllOfGroups, and its steps to
-- pick one of, PickGroup) }. A choice left with one branch the side can
-- take is just more steps. Its version steps are noted in `versionSteps`:
-- the Classes tab's are one quest's versions from different givers (the
-- warlock's Gakin's Summons or The Slaughtered Lamb), shown as the one
-- nearest the player; a dungeon fold's (`pickVersions`) are Data/Chains.lua's
-- steps any one of whose quests does, choices when their names differ.
local function BuildStage(findQuest, stage, side, isOptional, versionSteps)
    local line = { findQuest = findQuest, branches = {}, isOptional = isOptional, groupOf = {},
        steps = SideSteps(findQuest, stage.steps, side), finish = SideSteps(findQuest, stage.finish, side) }
    for _, branch in ipairs(stage.branches or {}) do
        local quests = SideSteps(findQuest, branch.quests, side)
        if #quests > 0 then
            table.insert(line.branches, { quests = quests, labelName = branch.labelName, races = branch.races })
        end
    end
    if #line.branches == 1 then
        for _, quest in ipairs(line.branches[1].quests) do table.insert(line.steps, quest) end
        line.branches = {}
    end
    line.oneOf = stage.oneOf and #line.branches > 1
    AddAllOfGroups(line, findQuest, stage.allOf, side)
    PlaceVersionSteps(line, versionSteps, stage.pickVersions)
    return line
end

-- Fold `fold` as side `side` can do it: its first stage (BuildStage) with
-- `fold`, and `followUp`, its second stage, when the side can take any of
-- its quests (with isFollowUp, and labelName: what it rewards), and
-- versionSteps, both stages' version steps. Its cards mark the quests of
-- fold.isHere (by ID) as done in the dungeon the page is about (a dungeon's
-- questline: UI/DungeonQuestlines.lua). Kept per side and fold.
local questlines = {}
local NOWHERE = {} -- a class's questline: no quest is done in "this dungeon"

local function BuildQuestline(findQuest, fold, side)
    local versionSteps = {}
    local line = BuildStage(findQuest, fold, side, fold.isOptional, versionSteps)
    line.fold, line.versionSteps, line.isHere = fold, versionSteps, fold.isHere or NOWHERE
    local followUp = fold.followUp and BuildStage(findQuest, fold.followUp, side, fold.isOptional, versionSteps)
    if followUp and #followUp.steps + #followUp.branches + #followUp.finish > 0 then
        followUp.isFollowUp, followUp.labelName = true, fold.followUp.labelName
        line.followUp = followUp
    end
    return line
end

-- Fold `fold`'s questline on side `side`, its quests looked up by
-- findQuest(questID), each version step showing its version nearest the
-- player now.
function Questlines.Of(fold, side, findQuest)
    questlines[side] = questlines[side] or {}
    questlines[side][fold] = questlines[side][fold] or BuildQuestline(findQuest, fold, side)
    PickNearestVersions(questlines[side][fold].versionSteps)
    return questlines[side][fold]
end

-- Class `classToken`'s fold `fold` on the side the Classes tab's Quests
-- section shows.
local function ClassQuestline(classToken, fold)
    return Questlines.Of(fold, ns.UI.ClassQuestSide(),
        function(questID) return ns.Data:ClassQuest(classToken, questID) end)
end

local function IsDone(quest)
    return ns.UI.QuestStatus(quest) == "Completed"
end

local function DoneCount(quests)
    local done = 0
    for _, quest in ipairs(quests) do
        if IsDone(quest) then done = done + 1 end
    end
    return done
end

local function IsOptional(line, quest)
    return line.isOptional[quest.id] == true
end

-- The quests of `quests` (of stage `line`) that aren't optional: the ones
-- progress counts. A lead-in can't be taken once what it leads to is done,
-- so counting it would hold a finished questline short for good.
local function RequiredQuests(line, quests)
    local required = {}
    for _, quest in ipairs(quests) do
        if not IsOptional(line, quest) then table.insert(required, quest) end
    end
    return required
end

-- The alternative done (its last quest not optional completed), or nil.
local function TakenBranch(line)
    if not line.oneOf then return nil end
    for _, branch in ipairs(line.branches) do
        local required = RequiredQuests(line, branch.quests)
        if IsDone(required[#required] or branch.quests[#branch.quests]) then return branch end
    end
end

-- The alternative for the player's race when `line`'s alternatives are
-- one per race (the priest's racial spells, the warlock's Imp quests),
-- else nil: none is, the side shown isn't the player's, or one was taken
-- already (which then decides what is greyed out).
local function OwnRaceBranch(line)
    if not line.oneOf or TakenBranch(line) then return nil end
    local raceID = select(3, UnitRace("player"))
    for _, branch in ipairs(line.branches) do
        for _, branchRaceID in ipairs(branch.races or {}) do
            if branchRaceID == raceID then return branch end
        end
    end
end

-- Whether `branch` is an alternative of `line` for races other than the
-- player's, who can't take it: greyed out.
local function IsOtherRace(line, branch)
    local own = OwnRaceBranch(line)
    return own ~= nil and branch ~= own and branch.races ~= nil
end

-- The branch of alternatives the player counts: the one taken, else the
-- one furthest along (`preferred` when it is one of those, else the first).
local function CountedBranch(line, preferred)
    local taken = TakenBranch(line)
    if taken then return taken end
    local furthest, mostDone = preferred, preferred and DoneCount(RequiredQuests(line, preferred.quests)) or -1
    for _, branch in ipairs(line.branches) do
        local done = DoneCount(RequiredQuests(line, branch.quests))
        if done > mostDone then furthest, mostDone = branch, done end
    end
    return furthest
end

-- The branch of `stage` for the same races as `branch` (another stage's),
-- or nil: the night elf's weapon quests after the night elf's Defensive Stance.
local function SameRacesBranch(stage, branch)
    local races = branch and branch.races and table.concat(branch.races, ",")
    if not races then return nil end
    for _, candidate in ipairs(stage.branches) do
        if candidate.races and table.concat(candidate.races, ",") == races then return candidate end
    end
end

-- Adds the quests of stage `line` the player does to `parts`, a list each:
-- the steps, every branch (of alternatives only CountedBranch's, with
-- `preferred`), then the final steps. Returns the alternative counted, or nil.
local function AddStageQuests(parts, line, preferred)
    table.insert(parts, line.steps)
    local counted = line.oneOf and CountedBranch(line, preferred or OwnRaceBranch(line))
    if counted then
        table.insert(parts, counted.quests)
    else
        for _, branch in ipairs(line.branches) do table.insert(parts, branch.quests) end
    end
    table.insert(parts, line.finish)
    return counted or nil
end

-- The quests of `parts` in order, a quest two of them share once, the
-- optional ones (of stage `line`'s fold) left out.
local function UniqueQuests(line, parts)
    local quests, isCounted = {}, {}
    for _, part in ipairs(parts) do
        for _, quest in ipairs(RequiredQuests(line, part)) do
            if not isCounted[quest] then
                isCounted[quest] = true
                table.insert(quests, quest)
            end
        end
    end
    return quests
end

-- The quests the player does, in order: the first stage's (AddStageQuests),
-- then the followUp's, whose alternative counted until one is started is
-- the one for the races of the first stage's; the optional ones left out.
local function CountedQuests(line)
    local parts = {}
    local counted = AddStageQuests(parts, line)
    if line.followUp then AddStageQuests(parts, line.followUp, SameRacesBranch(line.followUp, counted)) end
    return UniqueQuests(line, parts)
end

-- How many of the questline's quests are done, and how many there are.
function Questlines.Progress(line)
    local quests = CountedQuests(line)
    return DoneCount(quests), #quests
end

-- The first of `quests` not done, else the first.
local function FirstNotDone(quests)
    for _, quest in ipairs(quests) do
        if not IsDone(quest) then return quest end
    end
    return quests[1]
end

-- The quest to do next of `quests`, one part's steps in order: the first
-- not done after the last one done (a lead-in skipped stays behind), else
-- the first.
local function NextOfPart(quests)
    local lastDone = 0
    for index, quest in ipairs(quests) do
        if IsDone(quest) then lastDone = index end
    end
    return quests[lastDone + 1] or quests[1]
end

-- The steps -------------------------------------------------------------------

-- Whether `quest` (of stage `line`) is a breadcrumb: an optional lead-in
-- that only sends the player to the next quest's giver (Data/Chains.lua's
-- `breadcrumbs`), drawn as a signpost chip rather than a card.
local function IsBreadcrumb(line, quest)
    return IsOptional(line, quest) and ns.Data:IsBreadcrumb(quest.id)
end

-- The steps of `quests` (a stage's steps or final steps), in order: each
-- quest an item of its own ({ quest }), except the quests of a group (a
-- step whose quests are all needed, or one to pick one of; line.groupOf),
-- which are one item ({ group }).
local function RouteItems(line, quests)
    local items, isListed = {}, {}
    for _, quest in ipairs(quests) do
        local group = line.groupOf[quest]
        if not group then
            table.insert(items, { quest = quest })
        elseif not isListed[group] then
            isListed[group] = true
            table.insert(items, { group = group })
        end
    end
    return items
end

-- Stage `line`'s steps down the page, in order: its steps (RouteItems),
-- its branches as one step ({ branches = true }), then its final steps.
local function StageItems(line)
    local items = RouteItems(line, line.steps)
    if #line.branches > 0 then table.insert(items, { branches = true }) end
    for _, item in ipairs(RouteItems(line, line.finish)) do table.insert(items, item) end
    return items
end

-- The quests of step `item` of stage `line` (StageItems).
local function ItemQuests(line, item)
    if item.quest then return { item.quest } end
    if item.group then return item.group.quests end
    local quests = {}
    for _, branch in ipairs(line.branches) do
        for _, quest in ipairs(branch.quests) do table.insert(quests, quest) end
    end
    return quests
end

-- Whether step `item` of stage `line` has a number: every step does but a
-- lone optional quest (a lead-in or retry a player may skip, a breadcrumb).
local function IsNumbered(line, item)
    return not (item.quest and IsOptional(line, item.quest))
end

-- The step numbers of questline `line`, its first stage then its followUp,
-- as its page, its fold and the quest page show them: numbers count steps,
-- not quests, so a step of several quests is one number and an optional
-- quest has none. { total, ofQuest = { [quest] = number }, ofID = { [quest
-- ID, a version's too] = number } }.
function Questlines.StepNumbers(line)
    local numbering = { total = 0, ofQuest = {}, ofID = {} }
    for _, stage in ipairs({ line, line.followUp }) do
        for _, item in ipairs(StageItems(stage)) do
            if IsNumbered(stage, item) then
                numbering.total = numbering.total + 1
                for _, quest in ipairs(ItemQuests(stage, item)) do
                    numbering.ofQuest[quest] = numbering.total
                    numbering.ofID[quest.id] = numbering.total
                    for _, id in ipairs(quest.alt or {}) do numbering.ofID[id] = numbering.total end
                end
            end
        end
    end
    return numbering
end

-- How many numbered steps `quests` (a stage's steps) make (IsNumbered).
local function NumberedCount(line, quests)
    local count = 0
    for _, item in ipairs(RouteItems(line, quests)) do
        if IsNumbered(line, item) then count = count + 1 end
    end
    return count
end

-- The level the questline's first quest can be taken at (the lowest of its quests').
local function Level(line)
    local level
    for _, quest in ipairs(CountedQuests(line)) do
        local questLevel = quest.minLevel or quest.level
        if questLevel and questLevel > 0 then level = math.min(level or questLevel, questLevel) end
    end
    return level
end

-- The side every quest of the questline is for, or nil when either can do it.
local function SideOf(line)
    local side
    for _, quest in ipairs(CountedQuests(line)) do
        if not quest.side or (side and quest.side ~= side) then return nil end
        side = quest.side
    end
    return side
end

-- The zone where `quest`'s giver stands, or nil.
local function GiverZone(quest)
    local spot = ns.Data:NpcSpot(quest.giverNpc, quest.id)
    local map = spot and spot.map and C_Map.GetMapInfo(spot.map)
    return map and map.name
end

local function RaceNames(races)
    local names = {}
    for _, raceID in ipairs(races) do
        local race = C_CreatureInfo.GetRaceInfo(raceID)
        if race then table.insert(names, race.raceName) end
    end
    return table.concat(names, ", ")
end

-- A branch's name: what it makes or binds (Gauntlets, Incubus), the races
-- it is for, the city of its last quest's giver for alternatives, else its
-- first quest's name. Also whether that name is the city.
local function BranchLabel(line, branch)
    if branch.labelName then return branch.labelName, false end
    if branch.races then return RaceNames(branch.races), false end
    local city = line.oneOf and GiverZone(branch.quests[#branch.quests])
    if city then return city, true end
    return branch.quests[1].name, false
end

-- "Bartleby the Drunk to Bartleby's Mug": the first and last of `quests`
-- (the game's fonts have no arrow).
local function QuestNames(quests)
    if #quests == 1 then return quests[1].name end
    return L["%s to %s"]:format(quests[1].name, quests[#quests].name)
end

-- The grey line under a branch's row: its quests, when its name is its city;
-- else its first giver and the zone they stand in.
local function BranchNote(line, branch)
    local _, isCity = BranchLabel(line, branch)
    if isCity then return QuestNames(branch.quests) end
    local first = branch.quests[1]
    return Theme:JoinDots(first.giver, GiverZone(first))
end

-- "8/13", or the tick and "4/4" once all are done; and its colour.
local function FigureText(done, total)
    if done == total then return TICK .. " " .. ("%d/%d"):format(done, total), Theme.color.complete end
    return ("%d/%d"):format(done, total), Theme.color.muted
end
Questlines.FigureText = FigureText

-- "8/13", or the tick and "4/4", for the quests of `quests` (of stage
-- `line`) that progress counts (RequiredQuests); and its colour.
local function PartFigure(line, quests)
    local required = RequiredQuests(line, quests)
    return FigureText(DoneCount(required), #required)
end

-- The first of `quests` in the quest log (and not done), with its status
-- ("Ready" or "Accepted"); nil when none is.
local function FirstInLog(quests)
    for _, quest in ipairs(quests) do
        local status = ns.UI.QuestStatus(quest)
        if ns.UI.IsInLogStatus(status) then return quest, status end
    end
end

-- Where the player stands on the questline, for its fold's row, and its
-- colour: "Completed  ·  Human path", "Ready to turn in: Heart of
-- Disruption" or "Accepted: Heart of Disruption" (a quest of it in the
-- quest log), "After The Affray" (the questline comes after another not
-- done yet), "Not started  ·  Level 30", else the next quest to do.
function Questlines.StatusText(line)
    local done, total = Questlines.Progress(line)
    if done == total then
        local taken = TakenBranch(line)
        local path = taken and L["%s path"]:format((BranchLabel(line, taken)))
        return Theme:JoinDots(L["Completed"], path), Theme.color.complete
    end
    local inLog, status = FirstInLog(CountedQuests(line))
    if status == "Ready" then return L["Ready to turn in: %s"]:format(inLog.name), Theme.color.complete end
    if status == "Accepted" then return L["Accepted: %s"]:format(inLog.name), Theme.color.accepted end
    local after = line.fold.after and line.findQuest(line.fold.after)
    if after and not IsDone(after) then return L["After %s"]:format(after.name), Theme.color.faint end
    if done == 0 then
        local level = Level(line)
        return Theme:JoinDots(L["Not started"], level and L["Level %d"]:format(level)), Theme.color.muted
    end
    return L["Next: %s"]:format(FirstNotDone(CountedQuests(line)).name), Theme.color.muted
end

-- "Defensive Stance, Sunder Armor (Rank 1) and Taunt (Rank 1)": the game's
-- names for the spells fold `fold` teaches. Names the game hasn't sent yet
-- read "" until they come, and `onLoaded` (when given) runs then.
local function SpellNames(fold, onLoaded)
    local names, spellIDs = {}, {}
    for _, taught in ipairs(fold.teaches) do
        local name = C_Spell.GetSpellName(taught.spell) or ""
        if taught.rank then name = L["%s (Rank %d)"]:format(name, taught.rank) end
        table.insert(names, name)
        table.insert(spellIDs, taught.spell)
    end
    if onLoaded then ns.UI.ClassSpells.Load(spellIDs, onLoaded) end
    local last = table.remove(names)
    if #names == 0 then return last end
    return L["%s and %s"]:format(table.concat(names, ", "), last)
end

-- The quests that end the questline: its last final step, else each
-- branch's last quest, else its last step.
local function EndQuests(line)
    if #line.finish > 0 then return { line.finish[#line.finish] } end
    if #line.branches == 0 then return { line.steps[#line.steps] } end
    local ends = {}
    for _, branch in ipairs(line.branches) do table.insert(ends, branch.quests[#branch.quests]) end
    return ends
end

-- The items the questline's last quests give (else let the player choose
-- from), each once, by name; "" for one the game hasn't sent yet, and
-- `onLoaded` (when given) runs as each comes. Nil when they give none.
local function RewardNames(line, onLoaded)
    local names, isNamed = {}, {}
    for _, quest in ipairs(EndQuests(line)) do
        local items = quest.rewards and #quest.rewards > 0 and quest.rewards or quest.choice or {}
        for _, itemID in ipairs(items) do
            if not isNamed[itemID] then
                isNamed[itemID] = true
                if onLoaded and not C_Item.IsItemDataCachedByID(itemID) then ns.Items:Load(itemID, onLoaded) end
                table.insert(names, C_Item.GetItemNameByID(itemID) or "")
            end
        end
    end
    if #names == 0 then return nil end
    local last = table.remove(names)
    if #names == 0 then return last end
    return L["%s and %s"]:format(table.concat(names, ", "), last)
end

-- What the questline is for: "Teaches" and the spells' names, else
-- "Rewards" and the items'; nil, nil when neither.
local function Purpose(line, onLoaded)
    if line.fold.teaches then return L["Teaches"], SpellNames(line.fold, onLoaded) end
    local rewards = RewardNames(line, onLoaded)
    if rewards then return L["Rewards"], rewards end
end

-- "Steps 1–4", "Step 1": the steps everyone does first, numbered as the
-- page numbers them (NumberedCount; "Optional" when none has a number).
local function StepsName(count)
    if count == 0 then return L["Optional"] end
    if count == 1 then return L["Step %d"]:format(1) end
    return L["Steps %d–%d"]:format(1, count)
end

local function FinishName(count)
    return count == 1 and L["Final step"] or L["Final steps"]
end

-- The questline's parts, in order, as its fold rows and the page's pills
-- name them: { name, note, quests, branch (nil for the steps and the final
-- steps), dimmed (a branch not taken) }.
local function Parts(line)
    local parts = {}
    if #line.steps > 0 then
        table.insert(parts, { name = StepsName(NumberedCount(line, line.steps)), note = QuestNames(line.steps),
            quests = line.steps })
    end
    local taken = TakenBranch(line)
    for _, branch in ipairs(line.branches) do
        table.insert(parts, { name = (BranchLabel(line, branch)), note = BranchNote(line, branch),
            quests = branch.quests, branch = branch,
            dimmed = (taken ~= nil and branch ~= taken) or IsOtherRace(line, branch) })
    end
    if #line.finish > 0 then
        table.insert(parts, { name = FinishName(#line.finish), note = QuestNames(line.finish), quests = line.finish })
    end
    return parts
end

-- The line in the fold over its followUp's rows: "Then rewards a weapon of
-- your choice" when it names what it rewards, else "Then one of these"
-- over alternatives, "Then all 3, any order" over parallel branches.
local function FollowUpNote(followUp)
    if followUp.labelName then return L["Then rewards %s"]:format(followUp.labelName) end
    if followUp.oneOf then return L["Then one of these"] end
    return L["Then all %d, any order"]:format(#followUp.branches)
end

-- The Quests section's fold rows --------------------------------------------------

-- What a tentative fold's row and page say: built from Classic guides, it
-- may change in WoW: Forever.
local TENTATIVE_TEXT = L["May not be final for WoW: Forever"]

-- The key of fold `fold`'s row, which its parts' rows name as inFold.
function Questlines.FoldKey(fold)
    return "QUESTFOLD:" .. fold.key
end

-- Each fold row and its rows, by key, kept so a row stays the same row as
-- the list redraws.
local keptPages = {}
local function KeptPage(key)
    keptPages[key] = keptPages[key] or { key = key }
    return keptPages[key]
end

-- Adds a row to `pages` per part of stage `line` of fold row `foldKey`'s
-- questline, alternatives with an "or" between them. `keyPrefix` keeps
-- each stage's rows apart.
local function AddPartPages(pages, foldKey, line, keyPrefix)
    local parts = Parts(line)
    for index, part in ipairs(parts) do
        if index > 1 and line.oneOf and part.branch and parts[index - 1].branch then
            local divider = KeptPage(keyPrefix .. ":OR:" .. index)
            divider.isOr, divider.inFold, divider.name = true, foldKey, L["or"]
            table.insert(pages, divider)
        end
        local partRow = KeptPage(keyPrefix .. ":PART:" .. index)
        partRow.isBranch, partRow.inFold = true, foldKey
        partRow.name, partRow.note, partRow.quests, partRow.dimmed = part.name, part.note, part.quests, part.dimmed
        partRow.figure, partRow.figureColor = PartFigure(line, part.quests)
        table.insert(pages, partRow)
    end
end

-- Adds a fold note to `pages`: a line of text in fold row `foldKey`'s fold.
local function AddNotePage(pages, foldKey, key, text)
    local note = KeptPage(key)
    note.isFoldNote, note.inFold, note.name = true, foldKey, text
    table.insert(pages, note)
end

-- Adds fold `fold`'s rows to `pages`: its row (`questline`: the page it
-- opens), the line saying it may not be final (a tentative fold), the line
-- saying what it teaches or rewards, then a row per part;
-- then for its followUp a line saying what that rewards and a row per its
-- part. `onLoaded` runs as spell and item names arrive.
local function AddFoldPages(pages, classToken, fold, onLoaded)
    local line = ClassQuestline(classToken, fold)
    local foldKey = Questlines.FoldKey(fold)
    local row = KeptPage(foldKey)
    row.isFold, row.name, row.questline = true, fold.name, fold
    row.note, row.noteColor = Questlines.StatusText(line)
    row.figure, row.figureColor = FigureText(Questlines.Progress(line))
    table.insert(pages, row)
    if fold.isTentative then AddNotePage(pages, foldKey, foldKey .. ":TENTATIVE", TENTATIVE_TEXT) end
    local heading, names = Purpose(line, onLoaded)
    if heading then
        AddNotePage(pages, foldKey, foldKey .. ":NOTE",
            fold.teaches and L["Teaches %s"]:format(names) or L["Rewards %s"]:format(names))
    end
    AddPartPages(pages, foldKey, line, foldKey)
    if not line.followUp then return end
    local followUpKey = foldKey .. ":FOLLOW_UP"
    AddNotePage(pages, foldKey, followUpKey .. ":NOTE", FollowUpNote(line.followUp))
    AddPartPages(pages, foldKey, line.followUp, followUpKey)
end

-- The quest a part's row opens: its next to do (NextOfPart).
function Questlines.PartQuest(page)
    return NextOfPart(page.quests)
end

-- The Classes tab's Quests section's pages: ns.UI.ClassQuests's entries,
-- each group's showing its quest nearest the player now, with each fold's
-- rows in place of its quests where the first of them sits. `onLoaded`,
-- when given, runs as the names of spells and items a fold names arrive.
function ns.UI.ClassQuestPages(classToken, onLoaded)
    local entries = ns.UI.ClassQuests(classToken)
    ns.UI.PickNearestQuests(entries)
    local pages, isAdded = {}, {}
    for _, entry in ipairs(entries) do
        local fold = entry.fold
        if not fold then
            table.insert(pages, entry)
        elseif not isAdded[fold] then
            isAdded[fold] = true
            AddFoldPages(pages, classToken, fold, onLoaded)
        end
    end
    return pages
end

-- The trail ---------------------------------------------------------------------

-- Gives `tab` (the Classes tab) a trail of the places a questline's card or
-- a quest page's link left, so ‹ (tab:GoBack) and › (tab:GoForward) step
-- along it. A pick by hand in the class or sections column starts a new
-- one (tab:ClearTrail). tab:AddTrailStrip(page, strip) puts where a page is
-- and ‹ › on its strip.
local PLACE_FIELDS = { "classID", "classPage", "classQuest", "classQuestSide" }
local TRAIL_BUTTON = 20      -- each of ‹ ›
local TRAIL_BUTTON_GAP = 2
local STRIP_INSET = Size.pad - 4  -- ‹ › from the strip's right end (as Back's from its left)

local function Place()
    local place = {}
    for _, field in ipairs(PLACE_FIELDS) do place[field] = ns.UI.state[field] end
    return place
end

-- A ‹ (or ›, `forward`) of two strokes, gold while there is somewhere to go.
local function TrailButton(parent, forward, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(TRAIL_BUTTON, TRAIL_BUTTON)
    button.strokes = {}
    for i, lift in ipairs({ 1.8, -1.8 }) do
        local stroke = button:CreateTexture(nil, "ARTWORK")
        stroke:SetColorTexture(1, 1, 1, 1)
        stroke:SetSize(6, 1.5)
        stroke:SetPoint("CENTER", forward and 1 or -1, lift)
        -- ‹: the upper stroke rises from the tip, the lower falls; › mirrors it.
        local angle = (i == 1) == forward and -45 or 45
        stroke:SetRotation(math.rad(angle))
        button.strokes[i] = stroke
    end
    function button:Paint()
        local color = not self:IsEnabled() and Theme.color.faint
            or self:IsMouseOver() and Theme.color.accent or Theme.color.heading
        for _, stroke in ipairs(self.strokes) do stroke:SetVertexColor(unpack(color)) end
    end
    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", button.Paint)
    button:SetScript("OnLeave", button.Paint)
    return button
end

function Questlines.AddTrail(tab)
    local back, forward = {}, {}
    tab.trailButtons = {}  -- each strip's ‹ ›, as { back, forward }

    function tab:PaintTrail()
        for _, pair in ipairs(self.trailButtons) do
            pair.back:SetEnabled(#back > 0)
            pair.forward:SetEnabled(#forward > 0)
            pair.back:Paint()
            pair.forward:Paint()
        end
    end

    -- Shows `place` (from Place) as it was.
    function tab:RestorePlace(place)
        for _, field in ipairs(PLACE_FIELDS) do ns.UI.state[field] = place[field] end
        self:Update()
        self:PaintTrail()
    end

    -- Before following a card or a link: where it leaves.
    function tab:PushTrail()
        table.insert(back, Place())
        wipe(forward)
        self:PaintTrail()
    end

    function tab:ClearTrail()
        wipe(back)
        wipe(forward)
        self:PaintTrail()
    end

    function tab:GoBack()
        local place = table.remove(back)
        if not place then return end
        table.insert(forward, Place())
        self:RestorePlace(place)
    end

    function tab:GoForward()
        local place = table.remove(forward)
        if not place then return end
        table.insert(back, Place())
        self:RestorePlace(place)
    end

    -- ‹ › at the right of `strip`; returns the frame holding them (its
    -- `back` and `forward`), for the strip's text to stop at.
    function tab:AddTrailButtons(strip)
        local holder = CreateFrame("Frame", nil, strip)
        holder:SetSize(TRAIL_BUTTON * 2 + TRAIL_BUTTON_GAP, TRAIL_BUTTON)
        holder:SetPoint("RIGHT", -STRIP_INSET, 0)
        local pair = { back = TrailButton(holder, false, function() tab:GoBack() end),
            forward = TrailButton(holder, true, function() tab:GoForward() end) }
        pair.back:SetPoint("LEFT")
        pair.forward:SetPoint("RIGHT")
        holder.back, holder.forward = pair.back, pair.forward
        table.insert(self.trailButtons, pair)
        self:PaintTrail()
        return holder
    end

    -- A quest or questline page's strip: where the page is in small text
    -- (`page.crumbs`, "Mage  >  Destroy Morphaz"), then ‹ › (`page.trail`).
    function tab:AddTrailStrip(page, strip)
        page.trail = self:AddTrailButtons(strip)
        page.crumbs = Theme:Text(strip, Theme.font.small)
        page.crumbs:SetPoint("LEFT", Size.pad, 0)
        page.crumbs:SetPoint("RIGHT", page.trail, "LEFT", -Size.pad, 0)
        page.crumbs:SetJustifyH("LEFT")
        page.crumbs:SetWordWrap(false)
    end

    -- A right-click on a questline's or quest's page goes back along the
    -- trail, as one on the Dungeons tab's content pane does. Watched for the
    -- whole screen, kept to clicks on those pages and their pane.
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("GLOBAL_MOUSE_UP")
    watcher:SetScript("OnEvent", function(_, _, button)
        if button ~= "RightButton" or #back == 0 or ns.MapEdit.on then return end
        local host = ns.UI.classesHost
        if not (host and host:IsVisible()) then return end
        local page = tab.questlinePage:IsShown() and tab.questlinePage or tab.questPage:IsShown() and tab.questPage
        if not page then return end
        local focus = GetMouseFoci()[1]
        if not ns.UI.IsWithin(focus, host, page) or focus.keepsRightClick then return end
        GameTooltip:Hide()
        tab:GoBack()
    end)
end

-- The questline page ---------------------------------------------------------------

local PAD = 16             -- the page's content, in from its sides
local TOP = 12             -- the title, down from the top
local SUBTITLE_GAP = 4     -- between the title and the line under it
local HEADING_GAP = 16     -- above each heading
local HEADING_TEXT_GAP = 6 -- between a heading and what follows it
local PILL_GAP = 6         -- between the branches' pills, across and down
local SCROLL_STEP = 40     -- one notch of the mouse wheel
local CARD_HEIGHT = 50     -- a quest's card
local CARD_MAX = 160       -- its widest in a column
local CARD_MIN = 112       -- a column narrower than this goes to the next band (three fit
                           -- in a box beside the spine at the window's default size)
local CARD_PAD = 7         -- its text, in from its edges
local CARD_LINE_GAP = 2    -- between its lines of text
local CARD_GAP = 14        -- between cards one under the other (the arrow's room), and between steps
local SPINE = 12           -- where the arrow between two cards meets them, in from their left
local COLUMN_GAP = 18      -- between columns, the "+" or "or" in its middle
local BAND_GAP = 18        -- between bands of columns
local ARROW = 4            -- an arrowhead's reach back from its tip; it spreads as far each side
local FRINGE_ALPHA = 0.4   -- the faint pixel either side of a line that softens its edges
local CLEAR = { 0, 0, 0, 0 } -- the fill of what is only an outline (a group's box, a card's tag)
-- The route: the steps down the page, each required one numbered in a
-- circle on the spine, the line down the gutter at their left.
local ROUTE = {
    GUTTER = 34,     -- the spine's column, left of the steps
    CIRCLE = 24,     -- a step's circle, centred 12 in from the page's content
    CARD_MAX = 340,  -- a step's card at its widest: two columns and the gap between
    RING = "Mode-Selection-Ring-c60", -- round a step's circle, as round a section's disc (UI/Lists.lua)
}
-- The goal: a step done inside the dungeon whose questline the page shows.
local GOAL = {
    HEIGHT = 62,        -- its card, taller than CARD_HEIGHT
    RIBBON_GAP = 4,     -- between the ribbon over it and the card
    GLOW = 3,           -- how far its glow reaches past the card
    GLOW_ALPHA = 0.3,
    TITLE_SCALE = 1.1,  -- its name, a size up from `body`
}
-- A group's box (a step of several quests), a card's tag, a breadcrumb's chip.
local BOX = { PAD = 8, HEAD_GAP = 6, LABEL_GAP = 4, CORNER = 4, SEPARATOR = 40 }
local TAG = { HEIGHT = 14, PAD = 5 }
local CRUMB = { HEIGHT = 22, PAD = 8, NOTE_GAP = 3 }

-- The page's pools: cards, line strokes and fringes, labels, pills, step
-- circles, group boxes and breadcrumb chips, drawn afresh each time the page
-- is (page:Begin hides them all; each draw takes the next).
local function Take(page, pool, make)
    local used = page.used[pool] + 1
    page.used[pool] = used
    page.pools[pool][used] = page.pools[pool][used] or make(page)
    local item = page.pools[pool][used]
    item:Show()
    return item
end

-- A plain piece of a line: a solid colour.
local function NewStroke(page)
    return page.canvas:CreateTexture(nil, "ARTWORK")
end

-- A line's soft edge: a faint strip beside it, a sublayer under the solid pieces.
local function NewFringe(page)
    return page.canvas:CreateTexture(nil, "ARTWORK", nil, -1)
end

local function NewLabel(page)
    local label = Theme:Text(page.canvas, Theme.font.small)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    return label
end

-- A card's tag ("Optional", "Step 3 of 4", "Accepted"): a word in `small`
-- in a small rounded outline. NewCard places it.
local function NewTag(card)
    local tag = CreateFrame("Frame", nil, card)
    tag:SetHeight(TAG.HEIGHT)
    Theme:Rounded(tag, CLEAR, Theme.color.pillEdge)
    tag.text = Theme:Text(tag, Theme.font.small)
    tag.text:SetPoint("CENTER")
    return tag
end

-- A quest's card: its name (a tick before it once done), its giver in the
-- link colour and its giver's zone (CardZoneText); its outline, fill and
-- tag at its top right say what kind of step it is (PaintCard, SetCardTag),
-- the status tag at its bottom right, on the zone line, whether it is in
-- the quest log (SetStatusTag). A click opens the quest's page.
local function NewCard(page)
    local card = CreateFrame("Button", nil, page.canvas)
    Theme:Rounded(card, Theme.color.shutFill, Theme.color.shutEdge)
    card.fill = Theme.color.shutFill
    card.glow = Theme:Glow(card, Theme.color.goal, GOAL.GLOW)
    card.dashes = Theme:DashedOutline(card, Theme.color.pillEdge, BOX.CORNER)
    card.tag = NewTag(card)
    card.tag:SetPoint("TOPRIGHT", -CARD_PAD + 2, -CARD_PAD + 2)
    local above
    for _, field in ipairs({ "title", "giver", "zone" }) do
        local text = Theme:Text(card, field == "title" and Theme.font.body or Theme.font.small)
        if above then
            text:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -CARD_LINE_GAP)
        else
            text:SetPoint("TOPLEFT", CARD_PAD, -CARD_PAD)
        end
        text:SetPoint("RIGHT", -CARD_PAD, 0)
        text:SetJustifyH("LEFT")
        text:SetWordWrap(false)
        card[field], above = text, text
    end
    -- Its top just under the giver's line, so it is centred on the zone
    -- line on a card of any height, its right edge under the top tag's.
    card.statusTag = NewTag(card)
    card.statusTag:SetPoint("TOPRIGHT", card.giver, "BOTTOMRIGHT", 2, 0)
    card:SetScript("OnClick", function(self) page.onOpenQuest(self.quest) end)
    card:SetScript("OnEnter", function(self) self.bg:SetVertexColor(unpack(Theme.color.hover)) end)
    card:SetScript("OnLeave", function(self) self.bg:SetVertexColor(unpack(self.fill)) end)
    return card
end

local function NewPill(page)
    local pill = Theme:Pill(page.canvas)
    pill:SetScript("OnClick", function(self) page.onOpenQuest(self.quest) end)
    return pill
end

local STATUS_EDGE = { Completed = "complete", Ready = "complete", Accepted = "accepted" }

-- A card's outline and fill. The goal: a purple outline, tint and soft
-- glow. An optional quest: a dashed outline, gold until done (green once
-- done or ready to turn in, yellow while in the quest log), at full
-- strength, so fading is left to steps not taken. Any other: the solid
-- outline in those colours.
local function PaintCard(card, status, isOptional, isGoal)
    local colors = Theme.color
    local statusEdge = STATUS_EDGE[status] and colors[STATUS_EDGE[status]]
    local isDashed = isOptional and not isGoal
    card.fill = isGoal and colors.goalFill or colors.shutFill
    card.bg:SetVertexColor(unpack(card.fill))
    card.border:SetShown(not isDashed)
    card.border:SetVertexColor(unpack(isGoal and colors.goal or statusEdge or colors.shutEdge))
    card.dashes:SetShown(isDashed)
    card.dashes:SetVertexColor(unpack(statusEdge or colors.pillEdge))
    if isDashed then card.dashes:Fit() end
    card.glow:SetShown(isGoal)
    card.glow:SetVertexColor(colors.goal[1], colors.goal[2], colors.goal[3], GOAL.GLOW_ALPHA)
end

-- Card `card`'s tag `tag` showing `text` in `color` in an `edge` outline,
-- or hidden without `text`; the card's line of text `line` beside it stops
-- TAG.PAD short of it, else runs to the card's padding.
local function FillTag(card, tag, line, text, color, edge)
    tag:SetShown(text ~= nil)
    if not text then return line:SetPoint("RIGHT", card, "RIGHT", -CARD_PAD, 0) end
    tag.text:SetText(text)
    Theme:SetTextColor(tag.text, color)
    tag.border:SetVertexColor(unpack(edge))
    tag:SetWidth(math.ceil(tag.text:GetStringWidth()) + TAG.PAD * 2)
    line:SetPoint("RIGHT", tag, "LEFT", -TAG.PAD, 0)
end

-- The tag on card `card`: "Step 3 of 4" in the goal's purple on the goal
-- (`number`: its step), "Optional" in gold on an optional quest, else none.
-- The card's name stops short of it.
local function SetCardTag(page, card, number, isOptional, isGoal)
    local text, edge, color
    if isGoal then
        text, edge, color = L["Step %d of %d"]:format(number, page.numbering.total), Theme.color.goal,
            Theme.color.goalText
    elseif isOptional then
        text, edge, color = L["Optional"], Theme.color.pillEdge, Theme.color.heading
    end
    FillTag(card, card.tag, card.title, text, color, edge)
end

-- The status tag on card `card`, its words and outline in the status's
-- colour (`color`, from QuestStatus): "Accepted" (yellow) or "Ready to turn
-- in" (green) while its quest is in the quest log, and "Completed" (green)
-- on the goal once done, as its outline stays purple. Else none. The zone
-- line stops short of it.
local function SetStatusTag(card, status, color, isGoal)
    local isShown = ns.UI.IsInLogStatus(status) or (isGoal and status == "Completed")
    FillTag(card, card.statusTag, card.zone, isShown and ns.UI.QuestStatusText[status] or nil, color, color)
end

-- "or 2 others" for a version step's card (`quest`, the version shown), else nil.
local function OtherVersionsText(quest)
    local others = (quest.versionCount or 1) - 1
    if others < 1 then return nil end
    return Theme:Plural(others, L["or %d other"], L["or %d others"])
end

-- A card's last line: its giver's zone ("Lordamere Lake, then inside City of
-- Dalaran" on the goal), "or 2 others" for a version step's and "Not
-- needed" (`isNotNeeded`) once another choice of its step is done.
local function CardZoneText(page, quest, isGoal, isNotNeeded)
    local zone = GiverZone(quest)
    if isGoal then
        local dungeon = page.fold.instance.name
        zone = zone and L["%s, then inside %s"]:format(zone, dungeon) or L["Inside %s"]:format(dungeon)
    end
    return Theme:JoinDots(zone, OtherVersionsText(quest), isNotNeeded and L["Not needed"] or nil)
end

-- Quest `quest`'s card at `x`, `y`, `width` wide: dimmed to DIM_ALPHA when
-- `isDimmed`, "Not needed" when `isNotNeeded`. A numbered step done in the
-- dungeon the page is about (page.isHere) is its goal, a taller card.
-- Returns the card and its height.
local function DrawCard(page, quest, x, y, width, isDimmed, isNotNeeded)
    local card = Take(page, "cards", NewCard)
    local status, statusColor = ns.UI.QuestStatus(quest)
    local isOptional = page.isOptional[quest.id] == true
    local number = page.numbering.ofQuest[quest]
    local isGoal = page.isHere[quest.id] == true and number ~= nil
    local height = isGoal and GOAL.HEIGHT or CARD_HEIGHT
    card.quest = quest
    card:ClearAllPoints()
    card:SetPoint("TOPLEFT", page.canvas, "TOPLEFT", x, -y)
    card:SetSize(width, height)
    card:SetAlpha(isDimmed and DIM_ALPHA or 1)
    PaintCard(card, status, isOptional, isGoal)
    card.title:SetFontObject(isGoal and Theme:ScaledFont(Theme.font.body, GOAL.TITLE_SCALE) or Theme.font.body)
    card.title:SetText(status == "Completed" and TICK .. " " .. quest.name or quest.name)
    Theme:SetTextColor(card.title, isGoal and Theme.color.quest or Theme.color.text)
    card.giver:SetText(quest.giver or "")
    Theme:SetTextColor(card.giver, Theme.color.link)
    card.zone:SetText(CardZoneText(page, quest, isGoal, isNotNeeded))
    Theme:SetTextColor(card.zone, Theme.color.muted)
    SetCardTag(page, card, number, isOptional, isGoal)
    SetStatusTag(card, status, statusColor, isGoal)
    return card, height
end

local function DrawLabel(page, text, x, y, width, color)
    local label = Take(page, "labels", NewLabel)
    label:ClearAllPoints()
    label:SetPoint("TOPLEFT", page.canvas, "TOPLEFT", x, -y)
    label:SetWidth(width)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetText(text)
    Theme:SetTextColor(label, color or Theme.color.muted)
    return label
end

-- The lines -----------------------------------------------------------------------

-- The page notes its lines as it lays the steps out (AddSegment) and draws
-- them once it has (DrawLines). Every line runs straight down: the spine
-- from one step's circle to the next, and the arrow from a card to the one
-- under it in a column. Every piece is opaque, Theme:LineWidth wide, its
-- edges on whole pixels, with a screen pixel of its colour at FRINGE_ALPHA
-- along each side to soften the stair-stepped look of thin lines.

-- How a line looks: "done" (green) when it joins two finished steps, else "plain".
local function LineLook(joinsDone)
    return joinsDone and "done" or "plain"
end

local LOOK_COLOR = { plain = "flowLine", done = "flowDone" }

-- A line down from `y1` to `y2` at `x`, with an arrowhead at `y2` when `hasArrow`.
local function AddSegment(page, x, y1, y2, look, hasArrow)
    if y2 <= y1 then return end
    table.insert(page.segments, { x = x, y1 = y1, y2 = y2, look = look, hasArrow = hasArrow })
end

-- What the drawing goes by: a line's width and a screen pixel, on the canvas.
local function NewPen(page)
    local thick, pixel = Theme:LineWidth(page.canvas)
    return { thick = thick, pixel = pixel }
end

-- `position` on the canvas's nearest whole pixel.
local function Snap(pen, position)
    return math.floor(position / pen.pixel + 0.5) * pen.pixel
end

-- A solid rectangle (`alpha`, when given, for a fringe: from its pool, at that alpha).
local function FillRect(page, left, top, right, bottom, color, alpha)
    local stroke = alpha and Take(page, "fringes", NewFringe) or Take(page, "strokes", NewStroke)
    stroke:SetColorTexture(color[1], color[2], color[3], alpha or color[4] or 1)
    stroke:ClearAllPoints()
    stroke:SetPoint("TOPLEFT", page.canvas, "TOPLEFT", left, -top)
    stroke:SetSize(right - left, bottom - top)
end

-- The piece of `segment` from `from` down to `to`, `width` wide on its
-- middle, with a fringe either side.
local function FillAlong(page, pen, segment, from, to, width, color)
    if from == to then return end
    local left = Snap(pen, segment.x - pen.thick / 2) + (pen.thick - width) / 2
    FillRect(page, left, from, left + width, to, color)
    FillRect(page, left - pen.pixel, from, left, to, color, FRINGE_ALPHA)
    FillRect(page, left + width, from, left + width + pen.pixel, to, color, FRINGE_ALPHA)
end

-- A solid arrowhead with its tip at `tip`, pointing down: rows a pixel
-- deep, the tip's 1 or 2 pixels wide (as the line's width allows it to sit
-- on the line's middle), each row 2 pixels wider than the one above,
-- reaching ARROW up. Returns where it starts, for the line to stop there.
local function DrawArrowhead(page, pen, segment, tip, color)
    local rows = math.max(2, math.floor(ARROW / pen.pixel + 0.5))
    local thickPixels = math.floor(pen.thick / pen.pixel + 0.5)
    local tipWidth = (thickPixels % 2 == 0 and 2 or 1) * pen.pixel
    for row = 0, rows - 1 do
        FillAlong(page, pen, segment, tip - (row + 1) * pen.pixel, tip - row * pen.pixel,
            tipWidth + 2 * row * pen.pixel, color)
    end
    return tip - rows * pen.pixel
end

local function DrawSegment(page, pen, segment)
    local from, to = Snap(pen, segment.y1), Snap(pen, segment.y2)
    local color = Theme.color[LOOK_COLOR[segment.look]]
    if segment.hasArrow then to = DrawArrowhead(page, pen, segment, to, color) end
    if to <= from then return end -- no room left above the arrowhead
    FillAlong(page, pen, segment, from, to, pen.thick, color)
end

-- Draws the lines the page noted (page.segments).
local function DrawLines(page)
    local pen = NewPen(page)
    for _, segment in ipairs(page.segments) do DrawSegment(page, pen, segment) end
end

-- The questline's layout --------------------------------------------------------

-- `quests` down the page from `x`, `top`, each card under the one before,
-- joined to it by a line down with an arrowhead (cards dimmed when
-- `isDimmed`, "Not needed" when `isNotNeeded`). Returns the bottom of the last.
local function DrawCardStack(page, quests, x, top, width, isDimmed, isNotNeeded)
    local y = top
    for index, quest in ipairs(quests) do
        if index > 1 then
            local joinsDone = IsDone(quests[index - 1]) and IsDone(quest)
            AddSegment(page, x + SPINE, y - CARD_GAP, y, LineLook(joinsDone), true)
        end
        local _, height = DrawCard(page, quest, x, y, width, isDimmed, isNotNeeded)
        y = y + height + CARD_GAP
    end
    return y - CARD_GAP
end

-- A step's circle on the spine: its number on a round disc in a ring (as
-- a section's disc in the middle column), or for the goal the purple
-- portal in place of the number.
local function NewCircle(page)
    local circle = CreateFrame("Frame", nil, page.canvas)
    circle:SetSize(ROUTE.CIRCLE, ROUTE.CIRCLE)
    circle.face = circle:CreateTexture(nil, "ARTWORK", nil, 0)
    circle.face:SetPoint("CENTER")
    circle.face:SetSize(ROUTE.CIRCLE - 2, ROUTE.CIRCLE - 2)
    Theme:MaskRound(circle, circle.face)
    circle.portal = circle:CreateTexture(nil, "ARTWORK", nil, 1)
    circle.portal:SetPoint("CENTER")
    Theme:FitAtlas(circle.portal, Theme.portalAtlas, ROUTE.CIRCLE - 8)
    circle.ring = circle:CreateTexture(nil, "ARTWORK", nil, 3)
    circle.ring:SetPoint("CENTER")
    Theme:FitAtlas(circle.ring, ROUTE.RING, ROUTE.CIRCLE)
    circle.ring:SetDesaturated(true)
    circle.number = Theme:Text(circle, Theme.font.small)
    circle.number:SetPoint("CENTER", 0.5, 0)
    return circle
end

-- A step circle's ring colour: green once done, yellow for the step to do
-- now, purple for the goal, else gold.
local CIRCLE_RING = { done = "complete", current = "accepted", goal = "goal", ahead = "discRing" }

-- Step `number`'s circle, its middle at `centreY` on the spine, as `state` (CIRCLE_RING).
local function DrawCircle(page, centreY, number, state)
    local circle = Take(page, "circles", NewCircle)
    circle:ClearAllPoints()
    circle:SetPoint("CENTER", page.canvas, "TOPLEFT", PAD + ROUTE.CIRCLE / 2, -centreY)
    local color = Theme.color[CIRCLE_RING[state]]
    circle.ring:SetVertexColor(color[1], color[2], color[3], 1)
    circle.face:SetColorTexture(unpack(Theme.color.disc))
    circle.portal:SetShown(state == "goal")
    circle.number:SetText(state ~= "goal" and number or "")
    Theme:SetTextColor(circle.number, state == "ahead" and Theme.color.heading or color)
    circle.state = state
    return circle
end

-- Whether step `item` of stage `line` (StageItems) is done: its quest;
-- every quest of a step whose quests are all needed; any of one to pick one
-- of; every one of parallel branches, one of alternatives.
local function IsItemDone(line, item)
    if item.quest then return IsDone(item.quest) end
    if item.group and item.group.kind == "pick" then return DoneCount(item.group.quests) > 0 end
    if item.group then return DoneCount(item.group.quests) == #item.group.quests end
    if line.oneOf then return TakenBranch(line) ~= nil end
    for _, branch in ipairs(line.branches) do
        local required = RequiredQuests(line, branch.quests)
        if DoneCount(required) < #required then return false end
    end
    return true
end

-- Draws numbered step `item`'s circle, its middle at `centreY` (the goal's
-- portal when `isGoal`), and notes it for the spine (DrawSpine). The first
-- step not done is the one to do now.
local function MarkStep(page, line, item, centreY, isGoal)
    local isDone = IsItemDone(line, item)
    local state = isGoal and "goal" or isDone and "done" or not page.hasCurrent and "current" or "ahead"
    if not isDone then page.hasCurrent = true end
    DrawCircle(page, centreY, page.numbering.ofQuest[ItemQuests(line, item)[1]], state)
    table.insert(page.stepMarks, { y = centreY, isDone = isDone })
end

-- The spine: a line down the gutter from each step's circle to the next's,
-- green between two steps done.
local function DrawSpine(page)
    local x, radius = PAD + ROUTE.CIRCLE / 2, ROUTE.CIRCLE / 2
    for index = 2, #page.stepMarks do
        local above, below = page.stepMarks[index - 1], page.stepMarks[index]
        AddSegment(page, x, above.y + radius, below.y - radius, LineLook(above.isDone and below.isDone))
    end
end

-- The ribbon over the goal's card at `x`, `y`: the portal, then "The goal
-- ·  Inside City of Dalaran" in the goal's words colour, in capitals as a
-- label is (Theme:Label). Returns the y under it.
local function DrawRibbon(page, x, y, width)
    local text = Theme:Label(Theme:JoinDots(L["The goal"], L["Inside %s"]:format(page.fold.instance.name)))
    local label = DrawLabel(page, Theme.portalMark .. " " .. text, x, y, width, Theme.color.goalText)
    return y + Theme:LineHeight(label) + GOAL.RIBBON_GAP
end

-- Quest step `item` of stage `line` on the route at `x`, `top`: its card,
-- a numbered one with its circle on the spine (an optional quest has
-- neither), the goal's with the ribbon over it. Returns its bottom.
local function DrawRouteQuest(page, line, item, x, top, width)
    local quest, isNumbered = item.quest, IsNumbered(line, item)
    local cardWidth = math.min(ROUTE.CARD_MAX, width)
    local isGoal = isNumbered and page.isHere[quest.id] == true
    local y = isGoal and DrawRibbon(page, x, top, cardWidth) or top
    local _, height = DrawCard(page, quest, x, y, cardWidth)
    if isNumbered then MarkStep(page, line, item, y + height / 2, isGoal) end
    return y + height
end

-- A breadcrumb's chip: a dashed pill holding "Breadcrumb", its name, giver
-- and zone; lit under the mouse, a click opens its page.
local function NewCrumb(page)
    local crumb = CreateFrame("Button", nil, page.canvas)
    crumb:SetHeight(CRUMB.HEIGHT)
    crumb.lit = Theme:Fill(crumb, Theme.color.hover)
    crumb.lit:Hide()
    crumb.dashes = Theme:DashedOutline(crumb, Theme.color.pillEdge, BOX.CORNER)
    crumb.text = Theme:Text(crumb, Theme.font.small)
    crumb.text:SetPoint("LEFT", CRUMB.PAD, 0)
    crumb.text:SetJustifyH("LEFT")
    crumb:SetScript("OnClick", function(self) page.onOpenQuest(self.quest) end)
    crumb:SetScript("OnEnter", function(self) self.lit:Show() end)
    crumb:SetScript("OnLeave", function(self) self.lit:Hide() end)
    return crumb
end

-- Breadcrumb `quest` on the route at `x`, `top`, over the step it leads to:
-- its chip, and under it in `faint` what it is for, `nextQuest` the quest
-- it sends the player to. It has no number and no circle. Returns its bottom.
local function DrawCrumb(page, quest, nextQuest, x, top, width)
    local crumb = Take(page, "crumbs", NewCrumb)
    crumb.quest = quest
    local about = Theme:JoinDots(quest.giver, GiverZone(quest))
    crumb.text:SetText(Theme:ColorCode(Theme.color.heading) .. Theme:Label(L["Breadcrumb"]) .. "|r  " .. quest.name
        .. (about ~= "" and Theme:ColorCode(Theme.color.muted) .. Theme.DOTS .. about .. "|r" or ""))
    Theme:SetTextColor(crumb.text, Theme.color.text)
    local chipWidth = math.min(width, math.ceil(crumb.text:GetUnboundedStringWidth()) + CRUMB.PAD * 2)
    crumb.text:SetWidth(chipWidth - CRUMB.PAD * 2)
    crumb:ClearAllPoints()
    crumb:SetPoint("TOPLEFT", page.canvas, "TOPLEFT", x, -top)
    crumb:SetWidth(chipWidth)
    crumb.dashes:SetVertexColor(unpack(Theme.color.pillEdge))
    crumb.dashes:Fit()
    local leadsTo = nextQuest and (nextQuest.giver or nextQuest.name)
    if not leadsTo then return top + CRUMB.HEIGHT end
    local y = top + CRUMB.HEIGHT + CRUMB.NOTE_GAP
    local note = DrawLabel(page, L["Optional: only sends you to %s. Skip it if you know the way."]:format(leadsTo),
        x, y, width, Theme.color.faint)
    note:SetWordWrap(true)
    return y + math.max(Theme:LineHeight(note), note:GetStringHeight())
end

-- A branch's column's progress and colour, and whether it is dimmed: "✓
-- Completed" once taken, "Other race" for another race's, "Forgone
-- alternative" when another was taken (both dimmed), else its figure.
-- `taken`: stage `line`'s alternative done, or nil.
local function ColumnStatus(line, taken, branch)
    if branch == taken then return TICK .. " " .. L["Completed"], Theme.color.complete, false end
    if IsOtherRace(line, branch) then return L["Other race"], Theme.color.faint, true end
    if taken then return L["Forgone alternative"], Theme.color.faint, true end
    local status, color = PartFigure(line, branch.quests)
    return status, color, false
end

-- `line`'s branches in the order they are drawn: the player's race's
-- first (OwnRaceBranch).
local function DrawnBranches(line, own)
    if not own then return line.branches end
    local branches = { own }
    for _, branch in ipairs(line.branches) do
        if branch ~= own then table.insert(branches, branch) end
    end
    return branches
end

-- The heading over a step whose quests are all needed: "Do both, any
-- order", "Do all 3, any order".
local function AllOfHead(count)
    if count == 2 then return L["Do both, any order"] end
    return L["Do all %d, any order"]:format(count)
end

-- Group `group`'s box (line.groupOf): "Pick one" over a step to pick one
-- of, a column per choice, the others dimmed and "Not needed" once one is
-- done; else the AllOfHead heading with how many members are done ("1 of 2
-- done"), a column per member.
local function GroupBox(group)
    local box = { isPick = group.kind == "pick", columns = {} }
    local taken, doneCount = nil, 0
    for _, member in ipairs(group.members) do
        if DoneCount(member) == #member then
            doneCount = doneCount + 1
            taken = taken or member
        end
    end
    for _, member in ipairs(group.members) do
        local isNotNeeded = box.isPick and taken ~= nil and member ~= taken
        table.insert(box.columns, { quests = member, isDimmed = isNotNeeded, isNotNeeded = isNotNeeded })
    end
    box.head = box.isPick and L["Pick one"] or AllOfHead(#group.members)
    if not box.isPick then box.progress = L["%d of %d done"]:format(doneCount, #group.members) end
    return box
end

-- Stage `line`'s branches' box: "Pick one" over alternatives, else the
-- AllOfHead heading with how many branches are done; a column per branch
-- (DrawnBranches' order), its name and status over it (ColumnStatus).
local function BranchesBox(line)
    local taken, doneCount = TakenBranch(line), 0
    local box = { isPick = line.oneOf, columns = {} }
    for _, branch in ipairs(DrawnBranches(line, OwnRaceBranch(line))) do
        local status, color, isDimmed = ColumnStatus(line, taken, branch)
        local required = RequiredQuests(line, branch.quests)
        if DoneCount(required) == #required then doneCount = doneCount + 1 end
        table.insert(box.columns, { quests = branch.quests, isDimmed = isDimmed, name = (BranchLabel(line, branch)),
            status = status, statusColor = color })
    end
    box.head = line.oneOf and L["Pick one"] or AllOfHead(#line.branches)
    if not line.oneOf then box.progress = L["%d of %d done"]:format(doneCount, #line.branches) end
    return box
end

-- How `count` columns fit across `width`: how many to a band (none
-- narrower than CARD_MIN), each one's width (CARD_MAX at most) and the
-- width a full band takes.
local function ColumnLayout(count, width)
    local perBand = math.max(1, math.min(count, math.floor((width + COLUMN_GAP) / (CARD_MIN + COLUMN_GAP))))
    local columnWidth = math.min(CARD_MAX, (width - (perBand - 1) * COLUMN_GAP) / perBand)
    return perBand, columnWidth, perBand * columnWidth + (perBand - 1) * COLUMN_GAP
end

-- The "+" between the members of a step whose quests are all needed (in
-- gold), or the "or" between choices (in `faint`), centred on `x`, `y`.
local function DrawSeparator(page, text, x, y)
    local label = DrawLabel(page, text, x - BOX.SEPARATOR / 2, y, BOX.SEPARATOR,
        text == "+" and Theme.color.heading or Theme.color.faint)
    label:SetJustifyH("CENTER")
    label:SetPoint("TOPLEFT", page.canvas, "TOPLEFT", x - BOX.SEPARATOR / 2, -(y - Theme:LineHeight(label) / 2))
end

-- A column's name and status at `x`, `top` (a branch's), on two lines when
-- one is too narrow ("Dwarf, Gnome" over "Forgone alternative"). Returns its height.
local function DrawColumnLabel(page, column, x, top, width)
    local name = Theme:ColorCode(Theme.color.heading) .. column.name .. "|r"
    local status = Theme:ColorCode(column.statusColor) .. column.status .. "|r"
    local label = DrawLabel(page, name .. "  " .. status, x, top, width)
    if label:GetUnboundedStringWidth() <= width then return Theme:LineHeight(label) end
    label:SetWordWrap(true)
    label:SetText(name .. "\n" .. status)
    return label:GetStringHeight()
end

-- `columns` side by side from `x`, `top` across `width`, as many to a band
-- as fit (ColumnLayout), the bands one under another, `separator` between
-- the columns: each { quests, isDimmed, isNotNeeded, and for a branch name,
-- status and statusColor, its label over it }. Returns the bottom.
local function DrawColumns(page, columns, x, top, width, separator)
    local perBand, columnWidth = ColumnLayout(#columns, width)
    local y = top
    for first = 1, #columns, perBand do
        if first > 1 then
            DrawSeparator(page, separator, x + columnWidth / 2, y + BAND_GAP / 2)
            y = y + BAND_GAP
        end
        local band = { unpack(columns, first, math.min(#columns, first + perBand - 1)) }
        local labelHeight = 0
        for slot, column in ipairs(band) do
            if column.name then
                local labelX = x + (slot - 1) * (columnWidth + COLUMN_GAP)
                local height = DrawColumnLabel(page, column, labelX, y, columnWidth) + BOX.LABEL_GAP
                labelHeight = math.max(labelHeight, height)
            end
        end
        local bottom = y
        for slot, column in ipairs(band) do
            local columnX = x + (slot - 1) * (columnWidth + COLUMN_GAP)
            if slot > 1 then
                DrawSeparator(page, separator, columnX - COLUMN_GAP / 2, y + labelHeight + CARD_HEIGHT / 2)
            end
            bottom = math.max(bottom, DrawCardStack(page, column.quests, columnX, y + labelHeight, columnWidth,
                column.isDimmed, column.isNotNeeded))
        end
        y = bottom
    end
    return y
end

-- A group's box: a gold outline, solid round a step whose quests are all
-- needed, dashed round one to pick one of. No fill: the cards in it have theirs.
local function NewBox(page)
    local box = CreateFrame("Frame", nil, page.canvas)
    Theme:Rounded(box, CLEAR, Theme.color.pillEdge)
    box.dashes = Theme:DashedOutline(box, Theme.color.pillEdge, BOX.CORNER)
    return box
end

-- `box` (GroupBox's, BranchesBox's) at `x`, `top`, `width` across at most:
-- its heading in gold and its progress at the right, its columns under
-- them, in its outline. As wide as its columns, and at least as a step's
-- card. Returns its bottom.
local function DrawGroupBox(page, box, x, top, width)
    local _, _, bandWidth = ColumnLayout(#box.columns, width - BOX.PAD * 2)
    local boxWidth = math.min(width, math.max(bandWidth + BOX.PAD * 2, ROUTE.CARD_MAX))
    local innerWidth = boxWidth - BOX.PAD * 2
    local head = DrawLabel(page, box.head, x + BOX.PAD, top + BOX.PAD, innerWidth, Theme.color.heading)
    if box.progress then
        DrawLabel(page, box.progress, x + BOX.PAD, top + BOX.PAD, innerWidth):SetJustifyH("RIGHT")
    end
    local columnsTop = top + BOX.PAD + Theme:LineHeight(head) + BOX.HEAD_GAP
    local bottom = DrawColumns(page, box.columns, x + BOX.PAD, columnsTop, innerWidth, box.isPick and L["or"] or "+")
        + BOX.PAD
    local frame = Take(page, "boxes", NewBox)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", page.canvas, "TOPLEFT", x, -top)
    frame:SetSize(boxWidth, bottom - top)
    frame.border:SetShown(not box.isPick)
    frame.border:SetVertexColor(unpack(Theme.color.pillEdge))
    frame.dashes:SetShown(box.isPick)
    frame.dashes:SetVertexColor(unpack(Theme.color.pillEdge))
    if box.isPick then frame.dashes:Fit() end
    return bottom
end

-- Step `item` of stage `line` (StageItems) on the route, from `top`: a
-- breadcrumb's chip over the step it leads to (`nextItem`), a quest's card,
-- or the box of a step of several quests, the steps with a number with
-- their circle on the spine. Returns its bottom.
local function DrawItem(page, line, item, nextItem, top, width)
    local x, routeWidth = PAD + ROUTE.GUTTER, width - ROUTE.GUTTER
    if item.quest and IsBreadcrumb(line, item.quest) then
        local nextQuest = nextItem and ItemQuests(line, nextItem)[1]
        return DrawCrumb(page, item.quest, nextQuest, x, top, routeWidth)
    end
    if item.quest then return DrawRouteQuest(page, line, item, x, top, routeWidth) end
    MarkStep(page, line, item, top + CARD_HEIGHT / 2, false)
    return DrawGroupBox(page, item.group and GroupBox(item.group) or BranchesBox(line), x, top, routeWidth)
end

-- The pill that ends stage `line` on the page: "Teaches Defensive Stance,
-- ..." for a questline that teaches, "Rewards a weapon of your choice" for
-- a followUp naming what it rewards; nil for neither.
local function StagePillText(line)
    if line.isFollowUp then return line.labelName and L["Rewards %s"]:format(line.labelName) end
    if line.fold.teaches then return L["Teaches %s"]:format(SpellNames(line.fold)) end
end

-- Stage `line` from `top`: its steps down the route, then its pill
-- (StagePillText). Returns the bottom.
local function DrawStage(page, line, top, width)
    local items, y = StageItems(line), top
    for index, item in ipairs(items) do
        if index > 1 then y = y + CARD_GAP end
        y = DrawItem(page, line, item, items[index + 1], y, width)
    end
    local text = StagePillText(line)
    if not text then return y end
    local pill = Take(page, "pills", NewPill)
    pill.quest = nil
    pill:EnableMouse(false)
    pill:SetAlpha(1)
    pill:SetLabel(text)
    pill:SetTone(nil)
    y = y + CARD_GAP
    pill:ClearAllPoints()
    pill:SetPoint("TOPLEFT", page.canvas, "TOPLEFT", PAD + ROUTE.GUTTER, -y)
    return y + pill:GetHeight()
end

-- The questline from `top`: its first stage, then its followUp, the spine
-- joining their steps' circles. Returns the bottom.
local function DrawQuestline(page, line, top, width)
    local y = DrawStage(page, line, top, width)
    if line.followUp then y = DrawStage(page, line.followUp, y + CARD_GAP, width) end
    DrawSpine(page)
    return y
end

-- A pill per branch (else one for the steps) with its progress, from `top`,
-- wrapping; a click opens its first quest not done. Returns the bottom.
local function DrawPills(page, line, top, width)
    local x, y, height = PAD, top, 0
    for _, part in ipairs(Parts(line)) do
        if part.branch or #line.branches == 0 then
            local required = RequiredQuests(line, part.quests)
            local isDone = DoneCount(required) == #required
            local pill = Take(page, "pills", NewPill)
            pill.quest = NextOfPart(part.quests)
            pill:EnableMouse(true)
            pill:SetLabel(Theme:JoinDots(part.name, (PartFigure(line, part.quests))))
            pill:SetTone(isDone and Theme.color.complete or nil)
            pill:SetAlpha(part.dimmed and DIM_ALPHA or 1)
            if x > PAD and x + pill:GetWidth() > PAD + width then
                x, y = PAD, y + pill:GetHeight() + PILL_GAP
            end
            pill:ClearAllPoints()
            pill:SetPoint("TOPLEFT", page.canvas, "TOPLEFT", x, -y)
            x, height = x + pill:GetWidth() + PILL_GAP, pill:GetHeight()
        end
    end
    return y + height
end

-- The subtitle: the side, the level and how far the player is ("3 of 13
-- quests done", "Completed on the Human path").
local function SubtitleText(line)
    local done, total = Questlines.Progress(line)
    local progress = L["%d of %d quests done"]:format(done, total)
    if done == total then
        local taken = TakenBranch(line)
        progress = taken and L["Completed on the %s path"]:format((BranchLabel(line, taken))) or L["Completed"]
    end
    local side, level = SideOf(line), Level(line)
    return Theme:JoinDots(side and ns.SideName(side), level and L["Questline level %d"]:format(level), progress)
end

-- The page's title, subtitle and headings: fixed texts placed each draw.
local function CreateTexts(page)
    local canvas = page.canvas
    page.title = Theme:Text(canvas, Theme.font.instance)
    page.subtitle = Theme:Text(canvas, Theme.font.body)
    page.purposeHeading = Theme:Text(canvas, Theme.font.section)
    page.purpose = Theme:Text(canvas, Theme.font.body)
    page.notice = Theme:Text(canvas, Theme.font.body)
    page.notice:SetText(TENTATIVE_TEXT)
    page.itemStepsHeading = Theme:Text(canvas, Theme.font.section)
    page.itemStepsHeading:SetText(L["Outside the quests"])
    page.itemSteps = Theme:Text(canvas, Theme.font.body)
    page.lineHeading = Theme:Text(canvas, Theme.font.section)
    page.lineHeading:SetText(L["Questline"])
    for _, text in ipairs({ page.title, page.subtitle, page.notice, page.purposeHeading, page.purpose,
            page.itemStepsHeading, page.itemSteps, page.lineHeading }) do
        text:SetJustifyH("LEFT")
    end
end

-- The guide at the top of a dungeon's questline page (host.Guide), under
-- the subtitle: the line naming the dungeon's quest the questline leads to
-- (the goal) and how far off it is, in the goal's purple; then the Next
-- step box, edged in `complete` green: what to do now, the quest's
-- objectives and where, and Show on map, which pins who to see the way the
-- page's other NPC links do (out of combat the game's map pin, in combat
-- NeedRoll's own pin and a line in chat: never the game's map opened).
local GUIDE = {
    LEADS_HEIGHT = 20,  -- the Leads to line's outline
    LEADS_PAD = 8,      -- its text, in from its sides
    LEADS_GAP = 6,      -- between the subtitle and it
    NEXT_GAP = 12,      -- between it (or the subtitle) and the Next step box
    BOX_PAD = 10,       -- the box's text and pill, in from its edges
    LINE_GAP = 3,       -- between the box's lines
    FILL_ALPHA = 0.10,  -- the box's green wash
    EDGE_ALPHA = 0.7,   -- its outline
}

-- `color` at `alpha`.
local function Faded(color, alpha)
    return { color[1], color[2], color[3], alpha }
end

local function CreateNextBox(page)
    local box = CreateFrame("Frame", nil, page.canvas)
    local green = Theme.color.complete
    Theme:Rounded(box, Faded(green, GUIDE.FILL_ALPHA), Faded(green, GUIDE.EDGE_ALPHA))
    box.key = Theme:Text(box, Theme.font.small)
    box.key:SetPoint("TOPLEFT", GUIDE.BOX_PAD, -GUIDE.BOX_PAD)
    box.key:SetText(Theme:Label(L["Next step"]))
    Theme:SetTextColor(box.key, green)
    -- Out of combat a secure button lies over the pill while the mouse is
    -- on it and runs the game's /mappin; a click reaching OnClick is one in
    -- combat, which pins NeedRoll's own pin instead (ns.UI.ShowOnMap).
    local show = Theme:Pill(box)
    show:SetLabel(L["Show on map"])
    show:SetPoint("TOPRIGHT", -GUIDE.BOX_PAD, -GUIDE.BOX_PAD)
    show:SetScript("OnClick", function(self) ns.UI.ShowOnMap(self.spot, self.spotName) end)
    show:HookScript("OnEnter", function(self)
        ns.UI.HoverMapLink(self, self.spot)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.spotName or "")
        GameTooltip:AddLine(ns.UI.MapLinksInCombat() and ns.UI.NO_MAP_PINS_IN_COMBAT or ns.UI.PinHint(self.spot),
            unpack(Theme.tip.hint))
        GameTooltip:Show()
    end)
    show:HookScript("OnLeave", function(self)
        ns.UI.LeaveMapLink(self)
        GameTooltip:Hide()
    end)
    box.show = show
    for _, field in ipairs({ "text", "detail" }) do
        local text = Theme:Text(box, field == "text" and Theme.font.body or Theme.font.small)
        text:SetJustifyH("LEFT")
        text:SetWordWrap(true)
        box[field] = text
    end
    box.text:SetPoint("TOPLEFT", box.key, "BOTTOMLEFT", 0, -GUIDE.LINE_GAP)
    box.detail:SetPoint("TOPLEFT", box.text, "BOTTOMLEFT", 0, -GUIDE.LINE_GAP)
    return box
end

local function CreateGuide(page)
    local leadsTo = CreateFrame("Frame", nil, page.canvas)
    leadsTo:SetHeight(GUIDE.LEADS_HEIGHT)
    Theme:Rounded(leadsTo, Theme.color.goalFill, Theme.color.goal)
    leadsTo.text = Theme:Text(leadsTo, Theme.font.small)
    leadsTo.text:SetPoint("LEFT", GUIDE.LEADS_PAD, 0)
    leadsTo.text:SetJustifyH("LEFT")
    page.leadsTo = leadsTo
    page.nextBox = CreateNextBox(page)
end

-- Fills the Next step box with `nextStep` (host.Guide's: text, detail,
-- spot, spotName), `width` across; returns its height.
local function FillNextBox(box, nextStep, width)
    box.show.spot, box.show.spotName = nextStep.spot, nextStep.spotName
    box.show:SetShown(nextStep.spot ~= nil)
    local textWidth = width - GUIDE.BOX_PAD * 2 - (nextStep.spot and box.show:GetWidth() + GUIDE.BOX_PAD or 0)
    box.text:SetWidth(textWidth)
    box.text:SetText(nextStep.text)
    Theme:SetTextColor(box.text, Theme.color.text)
    box.detail:SetWidth(textWidth)
    box.detail:SetText(nextStep.detail or "")
    Theme:SetTextColor(box.detail, Theme.color.muted)
    local height = GUIDE.BOX_PAD * 2 + Theme:LineHeight(box.key) + GUIDE.LINE_GAP
        + math.max(Theme:LineHeight(box.text), box.text:GetStringHeight())
    if nextStep.detail then height = height + GUIDE.LINE_GAP + box.detail:GetStringHeight() end
    box:SetSize(width, math.max(height, box.show:GetHeight() + GUIDE.BOX_PAD * 2))
    return box:GetHeight()
end

-- Places `guide` (host.Guide's: leadsTo, the Leads to line's text, and
-- nextStep, the Next step box's; nil on the Classes tab's pages) from `y`,
-- `width` across. Returns the y under it.
local function PlaceGuide(page, guide, y, width)
    local leadsTo, box = page.leadsTo, page.nextBox
    leadsTo:SetShown(guide ~= nil and guide.leadsTo ~= nil)
    box:SetShown(guide ~= nil and guide.nextStep ~= nil)
    if not guide then return y end
    if guide.leadsTo then
        leadsTo.text:SetText(Theme.portalMark .. " " .. guide.leadsTo)
        Theme:SetTextColor(leadsTo.text, Theme.color.goalText)
        local textWidth = math.min(math.ceil(leadsTo.text:GetUnboundedStringWidth()), width - GUIDE.LEADS_PAD * 2)
        leadsTo.text:SetWidth(textWidth)
        leadsTo:SetWidth(textWidth + GUIDE.LEADS_PAD * 2)
        y = y + GUIDE.LEADS_GAP
        leadsTo:ClearAllPoints()
        leadsTo:SetPoint("TOPLEFT", page.canvas, "TOPLEFT", PAD, -y)
        y = y + GUIDE.LEADS_HEIGHT
    end
    if not guide.nextStep then return y end
    y = y + GUIDE.NEXT_GAP
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", page.canvas, "TOPLEFT", PAD, -y)
    return y + FillNextBox(box, guide.nextStep, width)
end

-- Puts `text` at `y` across the page; returns the y under it.
local function PlaceText(page, text, y, gap)
    text:ClearAllPoints()
    text:SetPoint("TOPLEFT", page.canvas, "TOPLEFT", PAD, -y)
    text:SetPoint("RIGHT", page.canvas, "RIGHT", -PAD, 0)
    return y + math.max(Theme:LineHeight(text), text:GetStringHeight()) + (gap or 0)
end

-- A tentative fold's notice, in the heading colour under the subtitle;
-- returns the y under it (`y` itself when the fold isn't tentative).
local function PlaceNotice(page, y)
    page.notice:SetShown(page.fold.isTentative == true)
    if not page.fold.isTentative then return y end
    Theme:SetTextColor(page.notice, Theme.color.heading)
    return PlaceText(page, page.notice, y, HEADING_GAP)
end

-- The fold's steps that aren't quests, one per line under "Outside the
-- quests"; returns the y under them (`y` itself when it has none).
local function PlaceItemSteps(page, y)
    local steps = page.fold.itemSteps
    page.itemStepsHeading:SetShown(steps ~= nil)
    page.itemSteps:SetShown(steps ~= nil)
    if not steps then return y end
    y = PlaceText(page, page.itemStepsHeading, y, HEADING_TEXT_GAP)
    page.itemSteps:SetText(table.concat(steps, "\n"))
    return PlaceText(page, page.itemSteps, y, HEADING_GAP)
end

-- The scroll frame the page's content sits in, and its bar.
local function ScrollTo(page, offset)
    local most = math.max(0, page.canvas:GetHeight() - page.scroll:GetHeight())
    page.offset = math.min(most, math.max(0, offset))
    page.scroll:SetVerticalScroll(page.offset)
    page.scrollBar:Update(page.offset, most, page.scroll:GetHeight())
end

local function AddScrolling(page)
    local scroll = CreateFrame("ScrollFrame", nil, page)
    scroll:SetAllPoints()
    local canvas = CreateFrame("Frame", nil, scroll)
    canvas:SetSize(1, 1)
    scroll:SetScrollChild(canvas)
    page.scroll, page.canvas, page.offset = scroll, canvas, 0
    page.scrollBar = Theme:ScrollBar(page, 8, 8, function(offset) ScrollTo(page, offset) end)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta) ScrollTo(page, page.offset - delta * SCROLL_STEP) end)
    scroll:SetScript("OnSizeChanged", function()
        if page:IsShown() and page.fold then page:Refresh() end
    end)
end

-- "Classes  >  Warrior  >  Quests  >  Defensive Stance": `words` in the
-- muted colour, then `name` in gold, ">" between them.
local function CrumbsText(words, name)
    local muted = Theme:ColorCode(Theme.color.muted)
    local parts = {}
    for _, word in ipairs(words) do table.insert(parts, muted .. word .. "|r") end
    table.insert(parts, Theme:ColorCode(Theme.color.heading) .. name .. "|r")
    return table.concat(parts, "  " .. muted .. ">|r  ")
end

-- A questline page, on `parent`: both tabs draw theirs with it. `host`
-- holds what differs between them: Questline(page), the questline (built
-- by Questlines.Of) of the fold on show (page.fold); OpenQuest(quest), what
-- a card or a pill does; for a page whose strip has crumbs of its own
-- (page.crumbs, made by the host), Crumbs(page), the words before the
-- questline's name; and for a page with a guide (a dungeon's: PlaceGuide),
-- Guide(page, line, numbering). page:ShowFold(fold) shows fold `fold`'s questline.
function Questlines.CreatePage(parent, host)
    local page = CreateFrame("Frame", nil, parent)
    AddScrolling(page)
    CreateTexts(page)
    CreateGuide(page)
    page.pools = { cards = {}, strokes = {}, fringes = {}, labels = {}, pills = {}, circles = {}, boxes = {},
        crumbs = {} }
    page.used = {}
    page.segments = {}  -- the lines noted while laying the page out (AddSegment)
    page.stepMarks = {} -- the steps' circles, for the spine (MarkStep)
    page.onOpenQuest = function(quest)
        if quest then host.OpenQuest(quest) end
    end

    -- Shows fold `fold`'s questline, from the top when it wasn't on show.
    function page:ShowFold(fold)
        local isNew = self.fold ~= fold
        self.fold = fold
        if isNew then ScrollTo(self, 0) end
        self:Refresh()
    end

    local function Begin()
        wipe(page.segments)
        wipe(page.stepMarks)
        page.hasCurrent = false
        for pool, items in pairs(page.pools) do
            page.used[pool] = 0
            for _, item in ipairs(items) do item:Hide() end
        end
    end

    -- Redraws the page for the quest log as it is now, keeping the scroll.
    function page:Refresh()
        local line = host.Questline(self)
        self.isOptional, self.isHere = line.isOptional, line.isHere
        self.numbering = Questlines.StepNumbers(line)
        if self.crumbs then self.crumbs:SetText(CrumbsText(host.Crumbs(self), self.fold.name)) end
        Begin()
        -- The canvas is as wide as the scroll frame, read here as well as
        -- when that resizes, so the first draw has it.
        self.canvas:SetWidth(math.max(1, self.scroll:GetWidth()))
        local width = math.max(CARD_MIN, self.canvas:GetWidth() - PAD * 2)
        self.title:SetText(self.fold.name)
        local y = PlaceText(self, self.title, TOP, SUBTITLE_GAP)
        self.subtitle:SetText(SubtitleText(line))
        Theme:SetTextColor(self.subtitle, Theme.color.muted)
        y = PlaceText(self, self.subtitle, y)
        y = PlaceGuide(self, host.Guide and host.Guide(self, line, self.numbering), y, width) + HEADING_GAP
        y = PlaceNotice(self, y)
        local heading, names = Purpose(line, function() if self:IsVisible() then self:Refresh() end end)
        self.purposeHeading:SetText(heading or L["Progress"])
        y = PlaceText(self, self.purposeHeading, y, HEADING_TEXT_GAP)
        self.purpose:SetText(names or "")
        self.purpose:SetShown(names ~= nil)
        if names then y = PlaceText(self, self.purpose, y, HEADING_TEXT_GAP) end
        y = DrawPills(self, line, y, width) + HEADING_GAP
        y = PlaceItemSteps(self, y)
        y = PlaceText(self, self.lineHeading, y, HEADING_TEXT_GAP + 4)
        y = DrawQuestline(self, line, y, width)
        DrawLines(self)
        self.canvas:SetHeight(y + PAD)
        ScrollTo(self, self.offset)
    end

    page:Hide()
    return page
end

-- The Classes tab's questline page. `tab` is the tab (its trail and
-- OpenQuest); MainFrame.lua hosts the page in the tab's content pane, with
-- its strip: "Classes > Warrior > Quests > Defensive Stance" and ‹ ›.
function ns.UI.CreateQuestlinePage(tab)
    local page = Questlines.CreatePage(tab, {
        Questline = function(self)
            local _, classToken = GetClassInfo(self.classID)
            return ClassQuestline(classToken, self.fold)
        end,
        Crumbs = function(self) return { L["Classes"], GetClassInfo(self.classID) or "", L["Quests"] } end,
        OpenQuest = function(quest)
            tab:PushTrail()
            tab:OpenQuest(quest)
        end,
    })

    function page:PlaceStrip(strip) tab:AddTrailStrip(self, strip) end

    -- Shows class `classID`'s questline of fold `fold`.
    function page:ShowQuestline(classID, fold)
        self.classID = classID
        self:ShowFold(fold)
    end
    return page
end
