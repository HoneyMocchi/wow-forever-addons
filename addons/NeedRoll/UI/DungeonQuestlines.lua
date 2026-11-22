-- The Dungeons tab's questlines: a dungeon's quests that sit on a quest
-- chain (Data/Chains.lua), drawn as the Classes tab draws a class's
-- questlines (UI/Questlines.lua). Each chain of two steps or more that
-- holds one of the dungeon's quests is a questline, keyed by its first
-- quest; chains that start alike are one questline, their shared steps
-- first, then the steps where they part as branches side by side, then any
-- steps they end on alike. A step whose quests are all needed
-- (Data/Chains.lua's { all = ... }) is one numbered step on the page, its
-- members side by side under "Do both, any order", each quest counted. In
-- the dungeon's Quests list, the dungeon's quests on a chain fold under
-- their questline's row (UI/Lists.lua), each marked as the questline's
-- goal; a click on the row opens the questline's page in the content
-- pane, whose cards open each step's quest page. The page marks the steps
-- done in this dungeon as the goal, and at its top says which of them the
-- questline leads to and how far off it is, and what to do next (Guide).
local _, ns = ...
local Questlines = ns.UI.Questlines
local Theme = ns.Theme
local L = ns.L

local DungeonQuestlines = {}
ns.UI.DungeonQuestlines = DungeonQuestlines

-- Every chain step the player can't take is left out: the player's class
-- token (UnitClass's second return).
local function PlayerClass()
    local _, classToken = UnitClass("player")
    return classToken
end

-- A quest's ID and the IDs of the other versions it covers (quest.alt).
local function QuestIDs(quest)
    local ids = { quest.id }
    for _, id in ipairs(quest.alt or {}) do table.insert(ids, id) end
    return ids
end

-- Where `quest` is on a chain, on side `side`: the first quest of the
-- longest chain it is on (Data:Chain, as the quest page's chain), whose ID
-- keys its questline, and the quest's step on it. Nil when it is on no
-- chain of two steps or more.
local function ChainStartOf(quest, side)
    local steps, at = ns.Data:Chain(quest.id, side, PlayerClass())
    if not steps or #steps < 2 then return nil end
    return steps[1][1], at
end

-- The chains (by their index in Data.chains) side `side` can take that
-- hold one of `instance`'s quests.
local function DungeonChains(instance, side)
    local chains, isListed = {}, {}
    for _, quest in ipairs(ns.Data:Quests(instance.id)) do
        for _, id in ipairs(QuestIDs(quest)) do
            for _, chainIndex in ipairs(ns.Data:ChainsWith(id, side)) do
                if not isListed[chainIndex] then table.insert(chains, chainIndex) end
                isListed[chainIndex] = true
            end
        end
    end
    return chains
end

-- A chain step's quest IDs as one string, to tell steps apart.
local function StepKey(ids)
    return table.concat(ids, ",")
end

-- A chain's steps as one string, to tell chains apart.
local function ChainKey(steps)
    local keys = {}
    for _, ids in ipairs(steps) do table.insert(keys, StepKey(ids)) end
    return table.concat(keys, ";")
end

-- The chains of DungeonChains that start with quest `firstID` and have two
-- steps or more, each as its steps for `side` and the player's class
-- (Data:FittingChain); chains alike after that are one.
local function ChainsFrom(instance, side, firstID)
    local chains, isTaken = {}, {}
    for _, chainIndex in ipairs(DungeonChains(instance, side)) do
        local steps = ns.Data:FittingChain(chainIndex, side, PlayerClass())
        local key = ChainKey(steps)
        if #steps >= 2 and steps[1][1] == firstID and not isTaken[key] then
            isTaken[key] = true
            table.insert(chains, steps)
        end
    end
    return chains
end

-- Step `index` of `chain`, counted from its end when `fromEnd`.
local function StepAt(chain, index, fromEnd)
    return chain[fromEnd and #chain - index + 1 or index]
end

-- How many steps all of `chains` have alike from their start (`fromEnd`:
-- from their end), leaving the first `skip` steps of each out of it.
local function SharedCount(chains, fromEnd, skip)
    local shortest = math.huge
    for _, chain in ipairs(chains) do shortest = math.min(shortest, #chain - skip) end
    for index = 1, shortest do
        local wanted = StepKey(StepAt(chains[1], index, fromEnd))
        for _, chain in ipairs(chains) do
            if StepKey(StepAt(chain, index, fromEnd)) ~= wanted then return index - 1 end
        end
    end
    return shortest
end

-- Steps `first` to `last` of `chain` as a questline's steps: a quest ID,
-- or for a step of several quests to choose from (one per class, or a
-- choice) the list of them, a version step. A step whose quests are all
-- needed puts each of its quests in the list, in order, so each counts
-- towards the questline's progress, and its members ({ { 544, 545 }, { 93680 } })
-- in `allOf`, for the page to draw them as one step (Questlines' AddAllOfGroups).
local function FoldSteps(chain, first, last, allOf)
    local steps = {}
    for index = first, last do
        local ids = chain[index]
        if ids.all then
            for _, id in ipairs(ids) do table.insert(steps, id) end
            table.insert(allOf, ids.all)
        else
            table.insert(steps, #ids == 1 and ids[1] or ids)
        end
    end
    return steps
end

-- The lead-ins a player may skip among `chains`' quests (quest ID ->
-- true), as a fold's isOptional: their cards are drawn as optional and no
-- figure counts them (Seeking Caitlin before Lost in the Thicket Things).
local function OptionalLeadIns(chains)
    local isOptional = {}
    for _, chain in ipairs(chains) do
        for _, ids in ipairs(chain) do
            for _, id in ipairs(ids) do
                if ns.Data:IsOptionalLeadIn(id) then isOptional[id] = true end
            end
        end
    end
    return isOptional
end

-- `chains` (ChainsFrom) as a questline, shaped like a class's fold (see
-- Data's RegisterClassQuestFolds): the steps all of them start with, a
-- branch per chain for the steps where they part, and the steps all of
-- them end with. The branches aren't alternatives: where Data/Chains.lua's
-- chains part (The Defias Brotherhood's Red Silk Bandanas and its last
-- step) each branch is a quest of its own that the player can do as well.
-- The fold keeps `chains`, for the step to do next (NextStepIDs), and
-- allOf, the members of its steps whose quests are all needed (FoldSteps);
-- its version steps are choices (pickVersions: Questlines' PickGroup).
local function MergedSteps(chains)
    local first = chains[1]
    local shared = SharedCount(chains, false, 0)
    local sharedEnd = #chains > 1 and SharedCount(chains, true, shared) or 0
    local allOf = {}
    local fold = { steps = FoldSteps(first, 1, shared, allOf), branches = {}, isOptional = OptionalLeadIns(chains),
        finish = FoldSteps(first, #first - sharedEnd + 1, #first, allOf), allOf = allOf, chains = chains,
        pickVersions = true }
    for _, chain in ipairs(chains) do
        local quests = FoldSteps(chain, shared + 1, #chain - sharedEnd, allOf)
        if #quests > 0 then table.insert(fold.branches, { quests = quests }) end
    end
    return fold
end

-- The quest IDs of `instance`'s quests, the versions they cover included:
-- the steps its questlines' cards mark as done in this dungeon.
local function HereIDs(instance)
    local isHere = {}
    for _, quest in ipairs(ns.Data:Quests(instance.id)) do
        for _, id in ipairs(QuestIDs(quest)) do isHere[id] = true end
    end
    return isHere
end

-- The page a questline step of `instance`'s opens: the dungeon's own quest
-- page for one of its quests, else the step's light page (UI/Overview.lua).
local function StepPage(instance, questID)
    return ns.Data:DungeonQuest(instance.id, questID) or ns.UI.QuestChain.Step(questID)
end

-- The group of `instance`'s quest list a questline's row is under while it
-- shows: Profession Quests when every one of the dungeon's quests on it
-- needs a profession, else Quests.
local function GroupKeyOf(instance, side, firstID)
    for _, quest in ipairs(ns.Data:Quests(instance.id)) do
        local isOnSide = not quest.side or quest.side == side
        if isOnSide and not quest.profession and ChainStartOf(quest, side) == firstID then return "QUESTS" end
    end
    return "PROFQUESTS"
end

-- The name of a questline (MergedSteps): its last quest's, or when its end
-- parts into branches, the last one before they part.
local function QuestlineName(instance, fold)
    local last = fold.finish[#fold.finish] or fold.steps[#fold.steps]
    local questID = type(last) == "table" and last[1] or last
    local quest = StepPage(instance, questID)
    return quest and quest.name or ns.UI.QuestChain.Name(instance, questID)
end

-- `instance`'s questline from chain start `firstID` on side `side`, a
-- fold as MergedSteps makes it with: key, name, instance, side, groupKey,
-- isHere (HereIDs) and findQuest (StepPage). Kept per dungeon and side,
-- like the dungeon's quest lists.
local folds = {}

local function BuildFold(instance, side, firstID)
    local fold = MergedSteps(ChainsFrom(instance, side, firstID))
    fold.key, fold.instance, fold.side = tostring(firstID), instance, side
    fold.name = QuestlineName(instance, fold)
    fold.groupKey = GroupKeyOf(instance, side, firstID)
    fold.isHere = HereIDs(instance)
    fold.findQuest = function(questID) return StepPage(instance, questID) end
    return fold
end

local function FoldOf(instance, side, firstID)
    local key = instance.id .. ":" .. side
    folds[key] = folds[key] or {}
    folds[key][firstID] = folds[key][firstID] or BuildFold(instance, side, firstID)
    return folds[key][firstID]
end

-- Fold `fold`'s questline (UI/Questlines.lua's model), each version step
-- showing its version nearest the player now.
function DungeonQuestlines.Of(fold)
    return Questlines.Of(fold, fold.side, fold.findQuest)
end

-- Brings a questline's row up to date with the quest log: where the
-- player stands under its name (Questlines.StatusText: "Not started  ·
-- Level 30") and its figure ("2/7", the tick and "7/7" once done).
function DungeonQuestlines.UpdateRow(row)
    local line = DungeonQuestlines.Of(row.questline)
    row.note, row.noteColor = Questlines.StatusText(line)
    row.figure, row.figureColor = Questlines.FigureText(Questlines.Progress(line))
end

-- The guide ----------------------------------------------------------------------

-- `name` in the quest colour, as a quest's name reads in the guide.
local function QuestWords(name)
    return Theme:ColorCode(Theme.color.quest) .. name .. "|r"
end

-- `name` in the link colour, as an NPC's name reads in the guide.
local function NpcWords(name)
    return Theme:ColorCode(Theme.color.link) .. name .. "|r"
end

-- The quest IDs of the step to do next on `fold`'s chains: of the first
-- chain not finished, the step Data:NextStepIndex picks, the rule the
-- world map's questline markers (UI/WorldMapMarkers.lua) follow too: past
-- breadcrumbs and optional lead-ins, and a step whose quests are all
-- needed until every one of them is done. Nil once every chain is done.
local function NextStepIDs(fold)
    for _, chain in ipairs(fold.chains) do
        local index = ns.Data:NextStepIndex(chain, C_QuestLog.IsQuestFlaggedCompleted)
        if index then return chain[index] end
    end
end

-- Quest `questID`'s objectives as the quest log has them ("Dalaran
-- Summoner slain: 4/6"), joined by dots; nil without any. The game's text
-- can be a secret value in Forever, which can't be joined into other text,
-- so such a line is left out.
local function ObjectivesText(questID)
    local parts = {}
    for _, objective in ipairs(C_QuestLog.GetQuestObjectives(questID) or {}) do
        local text = ns.Plain(objective.text)
        if text and text ~= "" then table.insert(parts, text) end
    end
    if #parts == 0 then return nil end
    return Theme:JoinDots(unpack(parts))
end

-- Where an NPC stands for quest `questID`, in words: inside a dungeon
-- (`inside`), else the part of the zone their spot is in ("Southern
-- Hillsbrad Foothills"); nil when neither is known.
local function PlaceWords(npc, questID, inside)
    local dungeon = inside and ns.Data:Get(inside)
    if dungeon then return L["Inside %s"]:format(dungeon.name) end
    return npc and ns.UI.ZoneArea(ns.Data:NpcSpot(npc, questID))
end

-- The Next step box on `fold`'s page (Questlines' PlaceGuide): for a
-- quest of the next step (NextStepIDs) in the quest log, "Finish [quest],
-- then hand it in to [NPC]" and its objectives; else "Pick up [quest] from
-- [NPC]". Then where that NPC stands, and their spot and name for Show on
-- map. Nil once every step is done.
local function NextStep(fold)
    local ids = NextStepIDs(fold)
    if not ids then return nil end
    local toPickUp = ns.Data.QuestsToPickUp(ids, C_QuestLog.IsQuestFlaggedCompleted)
    local questID = toPickUp[1]
    for _, id in ipairs(toPickUp) do
        if C_QuestLog.IsOnQuest(id) then questID = id end
    end
    local quest = questID and StepPage(fold.instance, questID)
    if not quest then return nil end
    local isInLog = C_QuestLog.IsOnQuest(questID)
    local npcName, npc, inside = quest.giver, quest.giverNpc, quest.giverInside
    if isInLog then npcName, npc, inside = quest.turnIn, quest.turnInNpc, quest.turnInInside end
    local text
    if isInLog then
        text = npcName and L["Finish %s, then hand it in to %s"]:format(QuestWords(quest.name), NpcWords(npcName))
            or L["Finish %s"]:format(QuestWords(quest.name))
    else
        text = npcName and L["Pick up %s from %s"]:format(QuestWords(quest.name), NpcWords(npcName))
            or L["Pick up %s"]:format(QuestWords(quest.name))
    end
    local detail = Theme:JoinDots(isInLog and ObjectivesText(questID) or nil, PlaceWords(npc, questID, inside))
    local spot = npc and not inside and ns.Data:NpcSpot(npc, questID) or nil
    return { text = text, detail = detail ~= "" and detail or nil, spot = spot, spotName = npcName }
end

-- The goals of questline `line` (the numbered steps done in this dungeon,
-- line.isHere), in step order: { quest, number } each.
local function Goals(line, numbering)
    local lists = { line.steps }
    for _, branch in ipairs(line.branches) do table.insert(lists, branch.quests) end
    table.insert(lists, line.finish)
    local goals = {}
    for _, quests in ipairs(lists) do
        for _, quest in ipairs(quests) do
            local number = numbering.ofQuest[quest]
            if number and line.isHere[quest.id] then table.insert(goals, { quest = quest, number = number }) end
        end
    end
    table.sort(goals, function(a, b) return a.number < b.number end)
    return goals
end

-- The number of the step to do next on `fold`'s chains (NextStepIDs), as
-- the page numbers it (`numbering`, Questlines.StepNumbers), or nil.
local function CurrentNumber(fold, numbering)
    for _, id in ipairs(NextStepIDs(fold) or {}) do
        if numbering.ofID[id] then return numbering.ofID[id] end
    end
end

-- How far goal `quest` (step `number`) is from the step to do now
-- (`currentNumber`): "Done" once it is, "Next step" when it is the step to
-- do now, else "2 steps away"; nil when neither is known.
local function DistanceText(quest, number, currentNumber)
    if ns.UI.QuestStatus(quest) == "Completed" then return L["Done"] end
    if not currentNumber then return nil end
    local away = number - currentNumber
    if away <= 0 then return L["Next step"] end
    return Theme:Plural(away, L["%d step away"], L["%d steps away"])
end

-- The line under the page's title: "Leads to [Heart of Disruption] in City
-- of Dalaran  ·  2 steps away", naming the first goal not done (the last
-- one once all are). Nil for a questline with no goal.
local function LeadsToText(fold, line, numbering)
    local goals = Goals(line, numbering)
    if #goals == 0 then return nil end
    local goal = goals[#goals]
    for _, candidate in ipairs(goals) do
        if ns.UI.QuestStatus(candidate.quest) ~= "Completed" then
            goal = candidate
            break
        end
    end
    return Theme:JoinDots(L["Leads to %s in %s"]:format(QuestWords(goal.quest.name), fold.instance.name),
        DistanceText(goal.quest, goal.number, CurrentNumber(fold, numbering)))
end

-- The guide at the top of `fold`'s page (Questlines' PlaceGuide), for its
-- questline `line` numbered as `numbering`: the Leads to line and the Next
-- step box.
function DungeonQuestlines.Guide(fold, line, numbering)
    return { leadsTo = LeadsToText(fold, line, numbering), nextStep = NextStep(fold) }
end

-- The note on the row of `quest`, one of the dungeon's quests folded under
-- `fold`'s row, when it is a goal (a numbered step): "The goal  ·  Step 3
-- of 4  ·  2 steps away", as the page numbers it. Nil for an optional one.
function DungeonQuestlines.GoalNote(fold, quest)
    local numbering = Questlines.StepNumbers(DungeonQuestlines.Of(fold))
    local number = numbering.ofID[quest.id]
    if not number then return nil end
    return Theme:JoinDots(L["The goal"], L["Step %d of %d"]:format(number, numbering.total),
        DistanceText(quest, number, CurrentNumber(fold, numbering)))
end

-- A questline's row in `instance`'s quest list, `keyPrefix` keeping the
-- list's rows apart from another list's (Quests, Profession Quests, Other
-- classes): { isFold, key, name, questline (the fold), foldQuests (the
-- dungeon's quests on it, as list entries) }.
local function NewFoldRow(fold, keyPrefix)
    local row = { isFold = true, key = "QUESTLINE:" .. keyPrefix .. ":" .. fold.key, name = fold.name,
        questline = fold, foldQuests = {} }
    DungeonQuestlines.UpdateRow(row)
    return row
end

-- Puts the quests of each row's fold in chain order (`stepOf`: each
-- entry's step), ties in the list's own order (`indexOf`).
local function SortFoldQuests(rows, stepOf, indexOf)
    local function IsEarlier(a, b)
        if stepOf[a] ~= stepOf[b] then return stepOf[a] < stepOf[b] end
        return indexOf[a] < indexOf[b]
    end
    for _, row in ipairs(rows) do
        if row.isFold then table.sort(row.foldQuests, IsEarlier) end
    end
end

-- `entries` (a dungeon's quest list entries, { quest = ... }) with each
-- quest on a chain (ChainStartOf) folded under its questline's row, the row
-- where the first of them sits; quests on no chain stay as they are.
-- `keyPrefix` names the list (NewFoldRow).
function DungeonQuestlines.FoldRows(entries, instance, side, keyPrefix)
    local rows, rowOf, stepOf, indexOf = {}, {}, {}, {}
    for index, entry in ipairs(entries) do
        local firstID, step = ChainStartOf(entry.quest, side)
        stepOf[entry], indexOf[entry] = step or 0, index
        if not firstID then
            table.insert(rows, entry)
        else
            if not rowOf[firstID] then
                rowOf[firstID] = NewFoldRow(FoldOf(instance, side, firstID), keyPrefix)
                table.insert(rows, rowOf[firstID])
            end
            table.insert(rowOf[firstID].foldQuests, entry)
        end
    end
    SortFoldQuests(rows, stepOf, indexOf)
    return rows
end

-- The Dungeons tab's questline page, on `parent` (MainFrame.lua hosts it
-- in the content pane, under its strip of Back and the crumbs). A card
-- opens its quest's page, Back returning to the questline: the dungeon's
-- own quest page, or a step's light page for one done outside.
-- page:ShowFold(fold) shows one of FoldRows' questlines.
local QUEST_LOG_DELAY = 1 -- seconds: the server flags a quest handed in a moment later

function ns.UI.CreateDungeonQuestlinePage(parent)
    local page = Questlines.CreatePage(parent, {
        Questline = function(self) return DungeonQuestlines.Of(self.fold) end,
        Guide = function(self, line, numbering) return DungeonQuestlines.Guide(self.fold, line, numbering) end,
        OpenQuest = function(quest)
            ns.UI:PushBack(ns.UI:Place())
            ns.UI:SelectQuest(quest)
        end,
    })
    local function Recheck()
        C_Timer.After(QUEST_LOG_DELAY, function()
            if not page:IsVisible() then return end
            ns.UI.ForgetQuestStatus()
            page:Refresh()
        end)
    end
    ns:On("QUEST_TURNED_IN", Recheck)
    ns:On("QUEST_ACCEPTED", Recheck)
    ns:On("QUEST_REMOVED", Recheck)
    return page
end
