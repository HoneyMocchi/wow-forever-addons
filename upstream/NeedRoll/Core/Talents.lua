-- Talent trees and planned talents for the Classes tab (UI/TalentPlanner.lua).
-- Nothing about talents ships with NeedRoll: the trees come from the game.
-- WoW: Forever keeps the classic three trees per class, but the client holds
-- them as one trait tree per class (C_Traits), split into three groups, one
-- per classic tree. Your own class's tree is read from your active talent
-- config; another class's from the game's view config, which
-- C_ClassTalents.InitializeViewLoadout fills for that class's spec (Mike
-- checked both in game, 2026-10-18). The planner's working plan lives for
-- the session; a plan the player saves goes in NeedRollDB.talentPlans
-- (shared by the account) and can be shared as a short string.
local _, ns = ...
local L = ns.L

-- trees: class ID -> its tree, read once. plans: class ID -> its working
-- plan (unsaved). opened: class ID -> the saved plan open in the planner
-- instead, if any.
local Talents = { trees = {}, plans = {}, opened = {}, listeners = {} }
ns.Talents = Talents

-- The classes in the order the Classes tab lists them, by class ID
-- (GetClassInfo): Warrior, Paladin, Hunter, Rogue, Priest, Shaman, Mage,
-- Warlock, Druid.
Talents.CLASS_IDS = { 1, 2, 3, 4, 5, 7, 8, 9, 11 }

Talents.MAX_LEVEL = 60       -- Forever's level cap: other classes are planned at it
local FIRST_TALENT_LEVEL = 10 -- the first point comes at 10, one more each level after
local MAX_POINTS = 51         -- the points a level 60 character has
local POINTS_PER_ROW = 5      -- a tree's row N opens after (N - 1) * 5 points in that tree
-- Node positions are in tenths of a pixel; two closer than this are on the
-- same grid line.
local GRID_SNAP = 100

-- The player's class ID; nil while the game keeps it secret.
function Talents.PlayerClassID()
    return ns.Plain(select(3, UnitClass("player")))
end

-- Reading from the game -----------------------------------------------------
-- Every read of a trait tree goes through here, so a change in how Forever
-- hands them out is fixed in one place.

-- The view config filled with `classID`'s spec at the level cap, and its
-- tree; nil when the game has no spec or tree for it.
local function ViewConfig(classID)
    local specID = GetSpecializationInfoForClassID(classID, 1)
    if not specID then return nil end
    -- A spec the game doesn't know raises an error instead of returning.
    if not pcall(C_ClassTalents.InitializeViewLoadout, specID, Talents.MAX_LEVEL) then return nil end
    local treeID = C_ClassTalents.GetTraitTreeForSpec(specID)
    if not treeID then return nil end
    return Constants.TraitConsts.VIEW_TRAIT_CONFIG_ID, treeID
end

-- The player's active talent config and its tree; nil before the game has
-- loaded it.
local function ActiveConfig()
    local configID = C_ClassTalents.GetActiveConfigID()
    local config = configID and C_Traits.GetConfigInfo(configID)
    local treeID = config and config.treeIDs and config.treeIDs[1]
    if treeID then return configID, treeID end
end

-- Where to read `classID`'s tree from: the active config for your own
-- class, else (or while that isn't loaded) the view config.
local function ConfigFor(classID)
    if classID == Talents.PlayerClassID() then
        local configID, treeID = ActiveConfig()
        if configID then return configID, treeID end
    end
    return ViewConfig(classID)
end

-- The tree's groups (the classic trees) in the game's order, each
-- { id, name, icon, nodes }, and the same groups by group ID.
local function ReadGroups(treeID)
    local groups, byID = {}, {}
    for _, info in ipairs(C_Traits.GetGroupDisplayInfoByTreeID(treeID) or {}) do
        local group = { id = info.groupID, name = info.displayName, icon = info.icon, order = info.orderIndex,
            nodes = {} }
        table.insert(groups, group)
        byID[group.id] = group
    end
    table.sort(groups, function(a, b) return a.order < b.order end)
    return groups, byID
end

-- The spell a node teaches, the icon to show for it and the entry they come
-- from: the entry it has chosen, else its first. The planner's tooltip asks
-- the game for that entry's text at a given rank (the spell alone only gives
-- rank 1's).
local function NodeSpell(configID, info)
    local entryID = info.activeEntry and info.activeEntry.entryID or info.entryIDs[1]
    local entry = entryID and C_Traits.GetEntryInfo(configID, entryID)
    local definition = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
    if not (definition and definition.spellID) then return nil end
    return definition.spellID, definition.overrideIcon or C_Spell.GetSpellTexture(definition.spellID), entryID
end

-- One talent: { id, x, y, maxRanks, spellID, icon, entryID, group, edges },
-- or nil for a node the tree doesn't show or that sits in none of its groups.
-- LinkPrerequisites fills in edgesIn, prerequisites and unlocks.
local function ReadNode(configID, nodeID, groupsByID)
    local info = C_Traits.GetNodeInfo(configID, nodeID)
    if not (info and info.isVisible and info.maxRanks > 0) then return nil end
    local group
    for _, groupID in ipairs(info.groupIDs) do group = group or groupsByID[groupID] end
    local spellID, icon, entryID = NodeSpell(configID, info)
    if not (group and spellID) then return nil end
    return { id = nodeID, x = info.posX, y = info.posY, maxRanks = info.maxRanks, spellID = spellID, icon = icon,
        entryID = entryID, group = group, edges = info.visibleEdges, edgesIn = {}, prerequisites = {},
        unlocks = {} }
end

-- The smallest step between `values` further apart than GRID_SNAP: the
-- distance from one grid line to the next.
local function GridStep(values)
    table.sort(values)
    local step
    for i = 2, #values do
        local gap = values[i] - values[i - 1]
        if gap > GRID_SNAP and (not step or gap < step) then step = gap end
    end
    return step or 1
end

-- Forever's view loadout lists a few talents off the grid that its own
-- talent window doesn't show: the Priest's has one hundreds of pixels under
-- the trees and right of its own tree's columns (Mike's read, 2026-10-20).
-- Fitting the grid around such a talent shrinks every tree into a corner,
-- so a talent more than this many grid steps from every other one (at least
-- two empty grid lines between them) is left out of the tree.
local MAX_STEPS_TO_NEIGHBOUR = 2

-- True when `node` is more than MAX_STEPS_TO_NEIGHBOUR grid steps along
-- `axis` ("x" or "y") from every other node of `nodes`. A node alone in
-- `nodes` has nothing to be cut off from.
local function IsCutOff(node, nodes, axis, step)
    local nearest
    for _, other in ipairs(nodes) do
        if other ~= node then
            local distance = math.abs(other[axis] - node[axis])
            if not nearest or distance < nearest then nearest = distance end
        end
    end
    return nearest ~= nil and nearest > MAX_STEPS_TO_NEIGHBOUR * step + GRID_SNAP
end

local function RemoveValue(list, value)
    for i = #list, 1, -1 do
        if list[i] == value then table.remove(list, i) end
    end
end

-- Takes the nodes of `nodes` cut off from the rest along `axis` out of
-- `tree`: its node list, their group's and byID. They are picked before
-- any goes, so one taken out doesn't change whether another is cut off.
local function DropCutOff(tree, nodes, axis)
    local values = {}
    for _, node in ipairs(nodes) do table.insert(values, node[axis]) end
    local step = GridStep(values)
    local cutOff = {}
    for _, node in ipairs(nodes) do
        if IsCutOff(node, nodes, axis, step) then table.insert(cutOff, node) end
    end
    for _, node in ipairs(cutOff) do
        RemoveValue(tree.nodes, node)
        RemoveValue(node.group.nodes, node)
        tree.byID[node.id] = nil
    end
end

-- Leaves out the talents off the grid (see MAX_STEPS_TO_NEIGHBOUR): first
-- those far down the tree, on y across the whole tree (the three trees
-- share their rows), then those far across their own tree, on x among its
-- other talents. Rows go first so a stray far below can't skew the
-- column step either.
local function DropStrays(tree)
    DropCutOff(tree, tree.nodes, "y")
    for _, group in ipairs(tree.groups) do DropCutOff(tree, group.nodes, "x") end
end

-- Puts each node on the classic grid: its row down the tree (counted across
-- the whole tree, so the three trees' rows line up) and its column within
-- its own tree. Sets tree.rows and tree.columns, the largest of each.
local function PlaceOnGrid(tree)
    local xs, ys, top = {}, {}, math.huge
    local leftOf = {}  -- group -> its leftmost node's x
    for _, node in ipairs(tree.nodes) do
        table.insert(xs, node.x)
        table.insert(ys, node.y)
        top = math.min(top, node.y)
        leftOf[node.group] = math.min(leftOf[node.group] or math.huge, node.x)
    end
    local columnStep, rowStep = GridStep(xs), GridStep(ys)
    tree.rows, tree.columns = 0, 0
    for _, node in ipairs(tree.nodes) do
        node.row = math.floor((node.y - top) / rowStep + 0.5) + 1
        node.column = math.floor((node.x - leftOf[node.group]) / columnStep + 0.5) + 1
        tree.rows = math.max(tree.rows, node.row)
        tree.columns = math.max(tree.columns, node.column)
    end
end

-- How an edge between two talents gates the one it points to
-- (Enum.TraitEdgeType), read as the game's own talent window reads it.
local EDGE_REQUIRED = Enum.TraitEdgeType.RequiredForAvailability
local EDGE_SUFFICIENT = Enum.TraitEdgeType.SufficientForAvailability

-- Records one edge from `source` to `target`. Every edge draws a line
-- (target.edgesIn). A Required edge's source must be maxed, a set of its
-- own in target.prerequisites; the Sufficient edges into a talent share one
-- set, any one of their sources maxed being enough. Other types (VisualOnly,
-- MutuallyExclusive) gate nothing.
local function LinkEdge(source, target, edgeType)
    table.insert(target.edgesIn, { from = source, type = edgeType })
    if edgeType == EDGE_REQUIRED then
        table.insert(target.prerequisites, { source })
    elseif edgeType == EDGE_SUFFICIENT then
        if not target.sufficientSet then
            target.sufficientSet = {}
            table.insert(target.prerequisites, target.sufficientSet)
        end
        table.insert(target.sufficientSet, source)
    else
        return
    end
    table.insert(source.unlocks, target)
end

-- Prerequisites, from the edges the game draws between talents: each node
-- lists the edges leaving it (info.visibleEdges), each to its target node.
local function LinkPrerequisites(tree)
    for _, node in ipairs(tree.nodes) do
        for _, edge in ipairs(node.edges or {}) do
            local target = tree.byID[edge.targetNode]
            if target then LinkEdge(node, target, edge.type) end
        end
    end
end

-- `classID`'s tree as the game hands it out:
-- { id, groups = { { id, name, nodes }, ... }, nodes, byID, rows, columns },
-- or nil when it can't be read (talent data not loaded, or a class the
-- client has no tree for).
local function ReadTree(classID)
    local configID, treeID = ConfigFor(classID)
    if not configID then return nil end
    local groups, groupsByID = ReadGroups(treeID)
    local nodeIDs = C_Traits.GetTreeNodes(treeID) or {}
    local tree = { id = treeID, groups = groups, nodes = {}, byID = {} }
    for _, nodeID in ipairs(nodeIDs) do
        local node = ReadNode(configID, nodeID, groupsByID)
        if node then
            table.insert(tree.nodes, node)
            table.insert(node.group.nodes, node)
            tree.byID[node.id] = node
        end
    end
    DropStrays(tree)
    if #tree.nodes == 0 then return nil end
    PlaceOnGrid(tree)
    LinkPrerequisites(tree)
    -- Share strings (NRT2) list a rank per node ID of the whole tree, in
    -- order, so sender and reader agree whichever nodes their configs show
    -- (your own class's tree is read from your loadout, others' from the
    -- view loadout) and however the game hands the nodes out.
    tree.shareOrder = { unpack(nodeIDs) }
    table.sort(tree.shareOrder)
    return tree
end

-- `classID`'s tree, read once and kept; nil until the game can give it.
function Talents:Tree(classID)
    local tree = self.trees[classID] or ReadTree(classID)
    self.trees[classID] = tree
    return tree
end

-- The ranks your character has bought, by node ID; nil while the active
-- config isn't loaded.
function Talents:MyRanks(classID)
    local tree = self:Tree(classID)
    local configID = ActiveConfig()
    if not (tree and configID) then return nil end
    local ranks = {}
    for _, node in ipairs(tree.nodes) do
        local info = C_Traits.GetNodeInfo(configID, node.id)
        local bought = info and info.ranksPurchased or 0
        if bought > 0 then ranks[node.id] = bought end
    end
    return ranks
end

-- The level a plan needs: one point a level from 10, so 51 points need 60.
local function LevelFor(points)
    if points <= 0 then return 0 end
    return math.min(Talents.MAX_LEVEL, points + FIRST_TALENT_LEVEL - 1)
end

-- The talent points a character has at `level`: one a level from 10, so 51 at 60.
function Talents.PointsAtLevel(level)
    return math.max(0, math.min(MAX_POINTS, level - FIRST_TALENT_LEVEL + 1))
end

-- The level a class's plan is for and the points it may spend. Every plan
-- may spend all 51 points (Mike, 2026-10-18): on your own class the level
-- shown starts at yours and rises as the plan needs more points than you
-- have; any other class, and a saved or imported plan, is at the level cap.
function Talents:Budget(classID)
    local plan = self.opened[classID] or self.plans[classID]
    if classID ~= self.PlayerClassID() or (plan and plan.atMaxLevel) then return self.MAX_LEVEL, MAX_POINTS end
    local tree = self:Tree(classID)
    local spent = (plan and tree) and self:TotalSpent(plan, tree) or 0
    return math.max(ns.PlayerLevel(), LevelFor(spent)), MAX_POINTS
end

-- Plans ---------------------------------------------------------------------
-- A plan is { ranks = { [node ID] = rank }, edited, atMaxLevel, saved }:
-- `edited` once the player added, took back or reset a point, so their own
-- talents changing in game doesn't overwrite it; `atMaxLevel` when it is
-- planned at the level cap whatever your level (see Budget); `saved` the
-- saved plan it shows, whose ranks it changes as you plan.

-- The plan the planner shows for `classID`: the saved plan open there, else
-- the working plan, which for your own class opens on your talents and for
-- every other class empty. Nil while your own talents aren't loaded yet.
function Talents:Plan(classID)
    if self.opened[classID] then return self.opened[classID] end
    if self.plans[classID] then return self.plans[classID] end
    local ranks = {}
    if classID == self.PlayerClassID() then ranks = self:MyRanks(classID) end
    if not ranks then return nil end
    self.plans[classID] = { ranks = ranks, edited = false }
    return self.plans[classID]
end

function Talents.Rank(plan, node)
    return plan.ranks[node.id] or 0
end

-- Points in `group`, only in the rows above `row` when one is given.
function Talents:GroupSpent(plan, group, row)
    local spent = 0
    for _, node in ipairs(group.nodes) do
        if not row or node.row < row then spent = spent + self.Rank(plan, node) end
    end
    return spent
end

function Talents:TotalSpent(plan, tree)
    local spent = 0
    for _, group in ipairs(tree.groups) do spent = spent + self:GroupSpent(plan, group) end
    return spent
end

-- The points in each tree, in the trees' order: { 20, 0, 31 }.
function Talents:Splits(plan, tree)
    local splits = {}
    for i, group in ipairs(tree.groups) do splits[i] = self:GroupSpent(plan, group) end
    return splits
end

-- A plan's points in each tree as text, "20/0/31"; nil before the class's
-- tree loads (the Classes tab's figures and Overview).
function Talents:SplitText(classID, plan)
    local tree = self:Tree(classID)
    if not (tree and plan) then return nil end
    return table.concat(self:Splits(plan, tree), "/")
end

-- The points `node`'s tree needs in the rows above it before its row opens.
function Talents.RowPoints(node)
    return (node.row - 1) * POINTS_PER_ROW
end

local function IsMaxed(plan, node)
    return Talents.Rank(plan, node) >= node.maxRanks
end

-- Whether a talent of `set` other than `without` is maxed.
local function IsSetMet(plan, set, without)
    for _, needed in ipairs(set) do
        if needed ~= without and IsMaxed(plan, needed) then return true end
    end
    return false
end

-- The sets of `node`'s prerequisites (see LinkEdge) with no talent maxed,
-- counting `without` (a talent about to give a point back) as not maxed.
function Talents.UnmetPrerequisites(plan, node, without)
    local unmet = {}
    for _, set in ipairs(node.prerequisites) do
        if not IsSetMet(plan, set, without) then table.insert(unmet, set) end
    end
    return unmet
end

-- Whether `node`'s row is open (enough points in the rows above it, in its
-- tree) and its prerequisites are met.
function Talents:IsOpen(plan, node)
    if self:GroupSpent(plan, node.group, node.row) < self.RowPoints(node) then return false end
    return #self.UnmetPrerequisites(plan, node) == 0
end

function Talents:CanAdd(plan, tree, node, points)
    return self.Rank(plan, node) < node.maxRanks and self:TotalSpent(plan, tree) < points and self:IsOpen(plan, node)
end

-- A point can come back unless a talent with points would lose a
-- prerequisite (one it has another maxed source for keeps it), or a talent
-- further down its tree would lose the points its row needs.
function Talents:CanRemove(plan, node)
    if self.Rank(plan, node) == 0 then return false end
    for _, unlocked in ipairs(node.unlocks) do
        if self.Rank(plan, unlocked) > 0 and #self.UnmetPrerequisites(plan, unlocked, node) > 0 then return false end
    end
    for _, other in ipairs(node.group.nodes) do
        if other.row > node.row and self.Rank(plan, other) > 0 then
            local above = self:GroupSpent(plan, node.group, other.row) - 1
            if above < self.RowPoints(other) then return false end
        end
    end
    return true
end

-- Tells everyone listening (the planner) that a plan or tree changed.
function Talents:OnChange(callback)
    table.insert(self.listeners, callback)
end

local function Changed()
    for _, callback in ipairs(Talents.listeners) do callback() end
end

-- Adds a point to `node` when the rules allow it; returns whether it did.
function Talents:Add(classID, node)
    local plan, tree = self:Plan(classID), self:Tree(classID)
    local _, points = self:Budget(classID)
    if not (plan and tree and self:CanAdd(plan, tree, node, points)) then return false end
    plan.ranks[node.id] = self.Rank(plan, node) + 1
    plan.edited = true
    Changed()
    return true
end

-- Takes a point back from `node` when the rules allow it; returns whether it did.
function Talents:Remove(classID, node)
    local plan = self:Plan(classID)
    if not (plan and self:CanRemove(plan, node)) then return false end
    local rank = self.Rank(plan, node) - 1
    plan.ranks[node.id] = rank > 0 and rank or nil
    plan.edited = true
    Changed()
    return true
end

-- Reset: every point taken back (from the saved plan, when one is open).
function Talents:Reset(classID)
    local opened = self.opened[classID]
    if opened then
        wipe(opened.ranks)
    else
        self.plans[classID] = { ranks = {}, edited = true }
    end
    Changed()
end

-- My talents: the planner goes back to your character's talents (a saved
-- plan open there closes, unchanged).
function Talents:LoadMine(classID)
    self.opened[classID] = nil
    self.plans[classID] = nil
    Changed()
end

-- Your talents changed in game (or you levelled): an untouched plan of your
-- own class follows them.
local function FollowMyTalents()
    local classID = Talents.PlayerClassID()
    if not classID then return end
    local plan = Talents.plans[classID]
    if plan and plan.edited then return end
    Talents.plans[classID] = nil
    Changed()
end
for _, event in ipairs({ "TRAIT_CONFIG_UPDATED", "ACTIVE_COMBAT_CONFIG_CHANGED", "PLAYER_LEVEL_UP" }) do
    ns:On(event, FollowMyTalents)
end

-- Checking plans -------------------------------------------------------------
-- A saved or pasted plan may not fit the tree as the game has it now (a
-- patch moved or removed a talent, or the text was changed), so each is
-- checked before it is shown.

-- The ranks in `ranks` the tree has a talent for, each at most the
-- talent's ranks; anything else (unknown talents, ranks that aren't whole
-- numbers above 0) is left out.
local function KnownRanks(tree, ranks)
    local known = {}
    for nodeID, rank in pairs(ranks) do
        local node = type(nodeID) == "number" and tree.byID[nodeID]
        if node and type(rank) == "number" and rank >= 1 then
            known[nodeID] = math.min(math.floor(rank), node.maxRanks)
        end
    end
    return known
end

local function CountPoints(ranks)
    local count = 0
    for _, rank in pairs(ranks) do count = count + rank end
    return count
end

-- `wanted` (node ID -> rank) placed one point at a time as the classic
-- rules allow (row gates, prerequisites, at most `points`), top rows
-- first, until no more go in: the ranks a plan can legally have.
local function LegalRanks(tree, wanted, points)
    local plan = { ranks = {} }
    local byRow = {}
    for _, node in ipairs(tree.nodes) do
        if wanted[node.id] then table.insert(byRow, node) end
    end
    table.sort(byRow, function(a, b) return a.row < b.row end)
    local isPlacing = true
    while isPlacing do
        isPlacing = false
        for _, node in ipairs(byRow) do
            while Talents.Rank(plan, node) < wanted[node.id] and Talents:CanAdd(plan, tree, node, points) do
                plan.ranks[node.id] = Talents.Rank(plan, node) + 1
                isPlacing = true
            end
        end
    end
    return plan.ranks
end

-- Saved plans ------------------------------------------------------------------
-- NeedRollDB.talentPlans[class ID] = { { name = "Frost 1", class = 8,
--     ranks = { [node ID] = rank } }, ... }, in the order they were saved.
-- Only these facts are kept: no text from the game.

local MAX_PLAN_NAME = 40  -- bytes a plan's name keeps (fewer letters outside English)
Talents.MAX_PLAN_NAME = MAX_PLAN_NAME
-- Saved plans already checked against their class's tree this session
-- (weak keys, so a deleted plan isn't held on to).
local checkedPlans = setmetatable({}, { __mode = "k" })

-- Fits a saved plan to its tree as the game has it now (see Checking plans),
-- in place, so an open plan keeps working on the same ranks table.
local function CheckSavedPlan(savedPlan, tree)
    local legal = LegalRanks(tree, KnownRanks(tree, savedPlan.ranks), MAX_POINTS)
    wipe(savedPlan.ranks)
    for nodeID, rank in pairs(legal) do savedPlan.ranks[nodeID] = rank end
    checkedPlans[savedPlan] = true
end

-- Whether a saved entry has the shape this file writes; SavedVariables can
-- be edited by hand, so anything else is dropped.
local function IsSavedPlan(entry)
    return type(entry) == "table" and type(entry.ranks) == "table" and type(entry.name) == "string"
end

-- `classID`'s saved plans, oldest first, each checked against the tree once
-- a session (once the tree has loaded).
function Talents:SavedPlans(classID)
    local store = ns.db and ns.db.talentPlans
    local savedPlans = store and store[classID]
    if type(savedPlans) ~= "table" then return {} end
    local tree = self:Tree(classID)
    for i = #savedPlans, 1, -1 do
        local savedPlan = savedPlans[i]
        if not IsSavedPlan(savedPlan) then
            table.remove(savedPlans, i)
        elseif tree and not checkedPlans[savedPlan] then
            savedPlan.name = ns.CleanName(savedPlan.name, MAX_PLAN_NAME) or L["Talent plan"]
            CheckSavedPlan(savedPlan, tree)
        end
    end
    return savedPlans
end

-- The saved plan open in `classID`'s planner, or nil.
function Talents:OpenedPlan(classID)
    local opened = self.opened[classID]
    return opened and opened.saved
end

-- Opens a saved plan in the planner: planning there changes it.
function Talents:OpenSaved(classID, savedPlan)
    self.opened[classID] = { ranks = savedPlan.ranks, edited = true, atMaxLevel = true, saved = savedPlan }
    Changed()
end

-- Back to the working plan (the planner's own row).
function Talents:CloseSaved(classID)
    if not self.opened[classID] then return end
    self.opened[classID] = nil
    Changed()
end

-- The names `classID`'s saved plans already have, as a set.
local function TakenNames(classID)
    local taken = {}
    for _, savedPlan in ipairs(Talents:SavedPlans(classID)) do taken[savedPlan.name] = true end
    return taken
end

-- A name for a new plan of `classID`: its top tree's name (the class's name
-- with no points) and the first number no saved plan of the class has:
-- "Frost 1", "Frost 2"...
local function NewPlanName(classID, plan, tree)
    local base, most = GetClassInfo(classID) or "", 0
    for _, group in ipairs(tree.groups) do
        local spent = Talents:GroupSpent(plan, group)
        if spent > most then base, most = group.name, spent end
    end
    local taken = TakenNames(classID)
    local number = 1
    while taken[("%s %d"):format(base, number)] do number = number + 1 end
    return ns.CleanName(("%s %d"):format(base, number), MAX_PLAN_NAME)
end

-- `name` as it is when no saved plan of `classID` has it yet, else with the
-- first free copy number, as a copied file is named: "Fire", "Fire (1)",
-- "Fire (2)"... The name is shortened to leave room for the number.
local function FreePlanName(classID, name)
    local taken = TakenNames(classID)
    if not taken[name] then return name end
    local copy = 1
    while true do
        local suffix = (" (%d)"):format(copy)
        local candidate = strtrim(ns.CutToBytes(name, MAX_PLAN_NAME - #suffix)) .. suffix
        if not taken[candidate] then return candidate end
        copy = copy + 1
    end
end

-- Adds a saved plan for `classID` and opens it. Nil while the saved data
-- isn't loaded.
local function StorePlan(classID, name, ranks)
    local store = ns.db and ns.db.talentPlans
    if not store then return nil end
    if type(store[classID]) ~= "table" then store[classID] = {} end
    local savedPlan = { name = name, class = classID, ranks = ranks }
    table.insert(store[classID], savedPlan)
    checkedPlans[savedPlan] = true
    Talents:OpenSaved(classID, savedPlan)
    return savedPlan
end

-- Saves the plan on show as a new saved plan and opens it. Returns it; nil
-- while the class's tree or the saved data isn't loaded.
function Talents:SaveNew(classID)
    local plan, tree = self:Plan(classID), self:Tree(classID)
    if not (plan and tree) then return nil end
    local ranks = {}
    for nodeID, rank in pairs(plan.ranks) do ranks[nodeID] = rank end
    return StorePlan(classID, NewPlanName(classID, plan, tree), ranks)
end

-- Renames a saved plan; false when `name` has nothing left once cleaned.
function Talents.RenameSaved(savedPlan, name)
    local cleaned = ns.CleanName(name, MAX_PLAN_NAME)
    if not cleaned then return false end
    savedPlan.name = cleaned
    Changed()
    return true
end

function Talents:DeleteSaved(classID, savedPlan)
    local savedPlans = self:SavedPlans(classID)
    for i = #savedPlans, 1, -1 do
        if savedPlans[i] == savedPlan then table.remove(savedPlans, i) end
    end
    if self:OpenedPlan(classID) == savedPlan then self.opened[classID] = nil end
    Changed()
end

-- Share strings -----------------------------------------------------------------
-- Forever's talent window hides the game's own loadout import and export,
-- so plans travel as NeedRoll's own short string, safe to paste in chat:
-- "NRT2:<class ID>:<ranks>", one digit per node of the class's tree in
-- node ID order (tree.shareOrder), the zeros at the end left off: about 60
-- letters for a whole plan. Reading it needs the tree, to know which talent
-- each digit is for. Older copies wrote "NRT1:<class ID>:<talent>.<talent>...",
-- each talent its node ID in base 36 then its rank ("1ay3" is node 1ay,
-- rank 3); those still import. A new format gets a new prefix.

local SHARE_PREFIX = "NRT2"
-- Every prefix this copy reads, and a whole share string as chat lines and
-- links carry it (its own checks come later, in ParseShare).
local READ_PREFIXES = "NRT[12]"
Talents.SHARE_STRING_PATTERN = READ_PREFIXES .. ":%d+:[%w%.]*"
-- Pasted text is read only up to this long: a full 51-point plan is under
-- 300 letters even as NRT1, and a cap keeps junk from costing anything to
-- look at.
local MAX_SHARE_LENGTH = 1000
local MAX_SHARE_RANK = 9  -- the most one digit holds

local function IsPlannedClass(classID)
    for _, listed in ipairs(Talents.CLASS_IDS) do
        if listed == classID then return true end
    end
    return false
end

-- `savedPlan` (else the plan on show for `classID`) as a share string; nil
-- with no tree yet.
function Talents:Export(classID, savedPlan)
    local plan, tree = savedPlan or self:Plan(classID), self:Tree(classID)
    if not (plan and tree) then return nil end
    local digits = {}
    for i, nodeID in ipairs(tree.shareOrder) do
        local node = tree.byID[nodeID]
        digits[i] = node and math.min(self.Rank(plan, node), MAX_SHARE_RANK) or 0
    end
    local ranks = table.concat(digits):gsub("0+$", "")
    return ("%s:%d:%s"):format(SHARE_PREFIX, classID, ranks)
end

-- NRT1's talents, "1ay3.2b5...": ranks by node ID and the points, or nil
-- when the text was cut or changed on the way.
local function ReadCodedRanks(codes)
    if not codes:match("^[%da-z%.]*$") then return nil end
    local ranks, points = {}, 0
    for code in codes:gmatch("[^%.]+") do
        local nodeID = ns.HeardNumber(code:sub(1, -2), nil, 36)
        local rank = ns.HeardNumber(code:sub(-1), MAX_SHARE_RANK)
        if not (nodeID and rank and rank > 0) or ranks[nodeID] then return nil end
        ranks[nodeID] = rank
        points = points + rank
    end
    return ranks, points
end

-- NRT2's digits, one per node of `tree` in share order: ranks by node ID
-- and the points, or nil when the text was cut or changed on the way.
local function ReadDigitRanks(digits, tree)
    if not digits:match("^%d*$") or #digits > #tree.shareOrder then return nil end
    local ranks, points = {}, 0
    for i = 1, #digits do
        local rank = tonumber(digits:sub(i, i))
        if rank > 0 then
            ranks[tree.shareOrder[i]] = rank
            points = points + rank
        end
    end
    return ranks, points
end

-- Reads pasted text (someone else's: never trusted) for a share string,
-- anywhere in it, so a whole chat line can be pasted. Returns
-- { classID, ranks, points }, or nil and a calm line saying why not.
function Talents.ParseShare(text)
    if type(text) ~= "string" or strtrim(text) == "" then return nil, L["Paste a NeedRoll talent plan."] end
    if #text > MAX_SHARE_LENGTH then return nil, L["That's too long to be a NeedRoll talent plan."] end
    -- The string runs to the next space or the end.
    local prefix, classText, codes = text:match("(" .. READ_PREFIXES .. "):(%d+):(%S*)")
    if not prefix then return nil, L["That isn't a NeedRoll talent plan."] end
    local classID = ns.HeardNumber(classText)
    if not (classID and IsPlannedClass(classID)) then
        return nil, L["That talent plan is for a class NeedRoll can't plan."]
    end
    local ranks, points
    if prefix == SHARE_PREFIX then
        local tree = Talents:Tree(classID)
        if not tree then return nil, L["That class's talents aren't available yet. Try again in a moment."] end
        ranks, points = ReadDigitRanks(codes, tree)
    else
        ranks, points = ReadCodedRanks(codes)
    end
    if not ranks then return nil, L["That talent plan is damaged. Copy it again."] end
    return { classID = classID, ranks = ranks, points = points }
end

-- Pasted text fitted to its class's tree as far as the rules allow: the
-- class ID, the ranks and the points left out (talents the tree doesn't
-- have, or that break the rules), or nil and why not.
local function FitShare(text)
    local shared, problem = Talents.ParseShare(text)
    if not shared then return nil, problem end
    local tree = Talents:Tree(shared.classID)
    if not tree then return nil, L["That class's talents aren't available yet. Try again in a moment."] end
    local ranks = LegalRanks(tree, KnownRanks(tree, shared.ranks), MAX_POINTS)
    return shared.classID, ranks, shared.points - CountPoints(ranks)
end

-- Loads pasted text into its class's planner as an unsaved plan at the
-- level cap, as far as the rules allow. Returns the class ID and the points
-- left out, or nil and why not.
function Talents:Import(text)
    local classID, ranks, leftOut = FitShare(text)
    if not classID then return nil, ranks end
    self.opened[classID] = nil
    self.plans[classID] = { ranks = ranks, edited = true, atMaxLevel = true }
    Changed()
    return classID, leftOut
end

-- Saves pasted text as a new saved plan named `name` (made free with a copy
-- number if the class has a plan of that name) and opens it. Returns the
-- class ID, the points left out and the saved plan, or nil and why not.
function Talents.SaveShared(text, name)
    local classID, ranks, leftOut = FitShare(text)
    if not classID then return nil, ranks end
    local cleanName = ns.CleanName(name, MAX_PLAN_NAME) or GetClassInfo(classID) or L["Talent plan"]
    local savedPlan = StorePlan(classID, FreePlanName(classID, cleanName), ranks)
    if not savedPlan then return nil, L["That class's talents aren't available yet. Try again in a moment."] end
    return classID, leftOut, savedPlan
end

-- Chat lines -------------------------------------------------------------------
-- A plan linked in chat travels as plain text, "[NR Talents: Fire] NRT2:8:...",
-- which any player can paste into Import. NeedRoll players outside an
-- instance see it as a clickable link instead (UI/TalentLinks.lua). The tag
-- is never translated: every copy has to recognise it.

Talents.CHAT_TAG = "NR Talents"
-- The game's chat box takes at most this many letters.
local MAX_CHAT_LINE = 255
-- A linked plan in a chat line: its name (no "]" or "|") and its share string.
Talents.CHAT_LINE_PATTERN = "%[" .. Talents.CHAT_TAG .. ": ([^%]|]+)%] (" .. Talents.SHARE_STRING_PATTERN .. ")"

-- A plan's name as a link shows it: cleaned as a saved name is, with no
-- square brackets (they would end the link's text early). Nil when nothing
-- is left.
function Talents.LinkName(name)
    return ns.CleanName((tostring(name or ""):gsub("[%[%]]", " ")), MAX_PLAN_NAME)
end

-- The line a link puts in chat: "[NR Talents: <name>] <share string>".
function Talents.ChatLine(name, shareString)
    local linkName = Talents.LinkName(name)
    if not linkName then return shareString end
    local line = ("[%s: %s] %s"):format(Talents.CHAT_TAG, linkName, shareString)
    -- Only a tree far bigger than any class has could pass the chat box's
    -- limit; the share string alone still imports.
    if #line > MAX_CHAT_LINE then return shareString end
    return line
end

-- The chat line for `savedPlan`, else for the plan on show for `classID`,
-- named for the saved plan (the one open, when none is given) or else the
-- class. Nil with no tree yet.
function Talents:PlanChatLine(classID, savedPlan)
    local shareString = self:Export(classID, savedPlan)
    if not shareString then return nil end
    local named = savedPlan or self:OpenedPlan(classID)
    return self.ChatLine(named and named.name or GetClassInfo(classID), shareString)
end
