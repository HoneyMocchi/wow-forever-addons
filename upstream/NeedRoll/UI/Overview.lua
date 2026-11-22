-- The content pane for a dungeon's or raid's Overview, and dungeon quests.
-- Overview (the top row of the middle column): the instance's name, stat
-- boxes (level range, zone, bosses, quests done or a raid's player count),
-- a picture of the layout map that opens it, the entrance with a button
-- that pins it on the world map, then the Description. A raid's ends with
-- its Attunement, shut until clicked: the quests in order, each a link to
-- its page with what to kill or loot, and an Alliance / Horde switch. Its
-- item chains follow the same way, each under its item's name (a dungeon's
-- key, Aqual Quintessence on Molten Core).
-- A quest's page: its name, the level it needs, its chain, who or what
-- starts it, its objective, what to kill or loot, then its rewards. Givers
-- and mobs are links that pin them on the map; ones inside a dungeon read
-- "(inside)" or "in <dungeon>" and pin its entrance.
local _, ns = ...
local Theme = ns.Theme
local Size = Theme.size
local L = ns.L

local HEADER_HEIGHT = 64     -- title and subtitle
local OVERVIEW_TOP = 50      -- an Overview's stat boxes start here, above the header's full height
local COLUMNS = 2
local GAP = 6
local META_PAD = 3          -- space above and below a line of text
local TITLE_BADGE = 30      -- a class quest's class icon left of the page title
local TITLE_INSIDE = 32     -- the dungeon portal after a quest's name, when it starts inside
-- A page's title block, top down: the title (its top INSTANCE_TOP or
-- QUEST_TOP below the pane's), SUB_GAP, the subtitle, LEVEL_GAP, a quest's
-- level line, then PAGE_GAP above a quest's page.
local TITLE = { INSTANCE_TOP = 15, QUEST_TOP = 18, SUB_GAP = 5, LEVEL_GAP = 4, PAGE_GAP = 12 }
local STEP_INDENT = 22      -- an attunement step's detail line under its name; an all-of step's members
-- The map card: a picture of the layout map, with a strip along its bottom naming it.
local CARD = { HEIGHT = 167, BAR = 26, ICON = 18 }
local ENTRANCE_HEIGHT = 40  -- the entrance row under the map card
local ENTRANCE_ICON = 28    -- the entrance row's icon, and the Dungeon or Raid swirl over a map's entrance
local SECTION_HEIGHT = 40   -- a section heading (Description, Attunement, an item chain) with its rule under it
local RULE_GAP = 6          -- extra room between a section heading and its rule, for the side toggle
-- Grouped in tables: the file is near Lua 5.1's 200 locals in one chunk.
-- An Overview stat box: a 16pt label over a 12pt value.
local FACT = { HEIGHT = 50, GAP = 8, PAD_LEFT = 12, PAD_RIGHT = 14 }
-- The drawn part (W x H) of a layout map's 4x3 tiles of TILE px, and the
-- tiles in file name order.
local ART = { W = 1002, H = 668, TILE = 256, TILE_ORDER = { 1, 10, 11, 12, 2, 3, 4, 5, 6, 7, 8, 9 } }
-- The layout map's closest zoom (against fitting the pane), and the step per mouse wheel notch.
local ZOOM = { MAX = 4, STEP = 1.25 }
-- A boss's pin on a layout map: Blizzard's own boss pin (a round portrait
-- in the Adventure Guide's ring), at 80% of its size on the world map.
local PIN_SIZE, PIN_PORTRAIT = 40, 29
local EJ_TEXTURES = "Interface\\EncounterJournal\\UI-EncounterJournalTextures"
local PIN_RING = { 0.84960938, 0.97070313, 0.42871094, 0.48828125 }
-- A patrolling boss (its pin's patrol = { x1, y1, x2, y2, ... }, a closed
-- loop): a badge on its pin, and its route lit while the pin is hovered.
local PATROL_BADGE = 15
local PATROL_BADGE_TEXTURE = "Interface\\Buttons\\UI-RefreshButton"
local ROUTE = {
    STEPS = 8,              -- line segments per stretch between two route points
    GLOW = { 1, 0.84, 0.35, 0.35 },
    CORE = { 1, 0.93, 0.67, 1 },
    ARROW = { 0.47, 0.27, 0, 1 },
    ARROW_GAP = 90,         -- px of route between the arrows showing which way it walks
    ARROW_SIZE = { 11, 7 },  -- an arrowhead along a loop: length, width
    END_SIZE = { 15, 10 },   -- one at each end of a line walked back and forth
    HANDLE = 10,            -- a route point's handle in map edit mode
    -- A marker's area (where its item drops): filled, outlined, no arrows.
    AREA_FILL = { 0.4, 0.85, 1, 0.16 },
    AREA_ROW = 3,           -- px between the fill's lines
    AREA_LINE = { 0.4, 0.85, 1, 0.9 },  -- its outline: one soft line of this color
    AREA_WIDTH = 6,         -- px across, the fade taking most of it
}
local AREA_LINE_TEXTURE = "Interface\\AddOns\\NeedRoll\\Media\\ZoneQuests\\OutlineLine"
local AREA_DOT_TEXTURE = "Interface\\AddOns\\NeedRoll\\Media\\ZoneQuests\\OutlineDot"
local LINK_ICON = 22        -- a green arrow to another level of the map
local LOCK_ICON = 20        -- a door that needs a key or lockpicking
local LOCK_TEXTURE = "Interface\\LFGFrame\\UI-LFG-ICON-LOCK"
local MARKER_ICON = 22      -- where a quest's item, kill, vendor or escort is
local FOCUS_PIN = 28        -- the game's map pin on the spot the map was opened to show (an NPC inside)
-- A link's icon (Data/Maps.lua): stairs or a drop up or down, or a door
-- through to a part of the dungeon drawn on another level.
local LINK_ICONS = {
    up = "poi-door-arrow-up", down = "poi-door-arrow-down",
    door = "poi-door", ["door-up"] = "poi-door-up", ["door-down"] = "poi-door-down",
    ["door-left"] = "poi-door-left", ["door-right"] = "poi-door-right",
}
local CHAT_PREFIX = "|cffFCD29FNeedRoll|r: "

local LINE_HEIGHT = {
    facts = FACT.HEIGHT + 12, heading = 26, meta = 20, label = 20, spacer = 10,
    mapcard = CARD.HEIGHT + 10, entrance = ENTRANCE_HEIGHT + 4,
}

-- Shows the game tooltip on `owner`: `title`, then `hint` (what a click
-- does) in white when there is one.
local function ShowTooltip(owner, anchor, title, hint)
    GameTooltip:SetOwner(owner, anchor)
    GameTooltip:SetText(title)
    if hint then GameTooltip:AddLine(hint, unpack(Theme.tip.text)) end
    GameTooltip:Show()
end

-- Hides the widgets of `pool` from `first` on: the ones a redraw didn't use.
local function HideFrom(pool, first)
    for i = first, #pool do pool[i]:Hide() end
end

-- Widget `i` of `pool`, made by make(...) the first time it's asked for.
local function Pooled(pool, i, make, ...)
    pool[i] = pool[i] or make(...)
    return pool[i]
end

-- Mouse widget `i` of one of a map view's pools (pins, marks, links, badge
-- icons), made by make(view) the first time; a new one goes to
-- view.onNewWidget when the view has one (the world map overlay lets
-- right-clicks through it).
local function MapWidget(view, pool, i, make)
    if pool[i] then return pool[i] end
    pool[i] = make(view)
    if view.onNewWidget then view.onNewWidget(pool[i]) end
    return pool[i]
end

-- A map pin's look, for /nr icondebug's pin previews.
ns.UI.pinLook = { size = PIN_SIZE, portrait = PIN_PORTRAIT, ring = EJ_TEXTURES, coords = PIN_RING }

-- Gives a pin its face: .portrait, masked round, over .back, a black disc
-- (seen behind an icon drawn in place of a face). The caller sizes it.
local function AddPortrait(pin, layer)
    pin.portrait = pin:CreateTexture(nil, layer)
    pin.portrait:SetPoint("CENTER")
    local mask = Theme:MaskRound(pin, pin.portrait)
    pin.back = pin:CreateTexture(nil, layer, nil, -1)
    pin.back:SetColorTexture(0, 0, 0, 1)
    pin.back:SetAllPoints(pin.portrait)
    pin.back:AddMaskTexture(mask)
end

-- Draws an icon in a pin's portrait spot in place of a boss's face (the
-- Ring of Law's crossed swords): a texture path (Interface\...) or an
-- atlas, on a dark disc. No icon hides the disc.
function ns.UI.SetPinIcon(back, portrait, icon)
    back:SetShown(icon ~= nil)
    if not icon then return end
    if icon:find("\\") then
        portrait:SetTexture(icon)
        Theme:CropIcon(portrait)
    else
        portrait:SetAtlas(icon)
    end
end

-- Shows a pin's look on a frame AddPortrait made: an icon (a string), a
-- creature's portrait (its display ID), or the Adventure Guide's blank face.
local function SetPinFace(pin, look)
    local icon = type(look) == "string" and look or nil
    pin.portrait:SetTexCoord(0, 1, 0, 1)
    ns.UI.SetPinIcon(pin.back, pin.portrait, icon)
    if icon then return end
    if look then
        SetPortraitTextureFromCreatureDisplayID(pin.portrait, look)
    else
        pin.portrait:SetTexture("Interface\\EncounterJournal\\UI-EJ-BOSS-Default")
    end
end

-- A small copy of a boss's map pin (the Encounters list shows one on each
-- boss pinned on the floor the map shows): a frame with .portrait, .back
-- and the ring, size px across (SetSize resizes it).
function ns.UI.MiniPin(parent, size)
    local mini = CreateFrame("Frame", nil, parent)
    mini:SetSize(size, size)
    AddPortrait(mini, "ARTWORK")
    -- The portrait keeps its share of the ring as the pin is resized.
    local function Fit(_, width)
        local inner = width * PIN_PORTRAIT / PIN_SIZE
        mini.portrait:SetSize(inner, inner)
    end
    mini:SetScript("OnSizeChanged", Fit)
    Fit(mini, size)
    local ring = mini:CreateTexture(nil, "OVERLAY")
    ring:SetAllPoints()
    ring:SetTexture(EJ_TEXTURES)
    ring:SetTexCoord(unpack(PIN_RING))
    return mini
end

-- Shows pin { encounter, x, y, display ID or icon } on a mini pin.
function ns.UI.SetMiniPin(mini, pin)
    SetPinFace(mini, pin[4])
end

-- Whether `test` holds for the quest's ID or another version's (quest.alt).
local function AnyVersion(quest, test)
    if test(quest.id) then return true end
    for _, id in ipairs(quest.alt or {}) do
        if test(id) then return true end
    end
    return false
end
ns.UI.AnyQuestVersion = AnyVersion  -- the quest givers on the game's map ask it too (UI/WorldMapMarkers.lua)

-- The step of the quest's chain you are on (1 = its first quest) when partway
-- through the quests before it, the chain's length and the ID of the quest
-- you're on. Quests from before chain lists were kept know only the first
-- step; on those, step is false once it is done.
local function ChainStep(quest)
    local chain = quest.chain or (quest.chainStart and { quest.chainStart })
    if not chain then return nil end
    local step, started
    for i, id in ipairs(chain) do
        if C_QuestLog.IsOnQuest(id) then
            step, started = i, true
        elseif C_QuestLog.IsQuestFlaggedCompleted(id) then
            step, started = i + 1, true
        end
    end
    if not started then return nil end
    if quest.chain then
        -- Every quest before it done: this one is next, not an earlier step.
        if step > #chain then return nil end
        return step, #chain + 1, chain[step]
    end
    if C_QuestLog.IsOnQuest(chain[1]) then return 1, quest.chainStep, chain[1] end
    if (quest.chainStep or 2) <= 2 then return nil end  -- the first step done: this one is next
    return false, quest.chainStep
end

-- "Completed", "Accepted" (in the quest log, under any version's ID),
-- "Prior Step" (then ChainStep's details too) or "Incomplete".
local function FreshStatus(quest)
    if AnyVersion(quest, C_QuestLog.IsQuestFlaggedCompleted) then return "Completed" end
    if AnyVersion(quest, C_QuestLog.IsOnQuest) then return "Accepted" end
    local step, chainLength, current = ChainStep(quest)
    if step ~= nil then return "Prior Step", step, chainLength, current end
    return "Incomplete"
end

-- Each quest's status is kept until the quest log changes: rows and counts
-- ask on every redraw (each frame of a group sliding open), and a long chain
-- takes dozens of quest log calls. Its color is looked up per call, so
-- switching the window style recolors kept statuses too.
local statusCache = {}
local STATUS_COLOR = { Completed = "complete", Accepted = "accepted", ["Prior Step"] = "levelHard",
                       Incomplete = "incomplete" }
local STATUS_TEXT = { Completed = L["Completed"], Accepted = L["Accepted"], ["Prior Step"] = L["Prior Step"],
                      Incomplete = L["Incomplete"] }

-- The quest's status and its color, then FreshStatus's chain details.
local function Status(quest)
    local cached = statusCache[quest]
    if not cached then
        cached = { FreshStatus(quest) }
        statusCache[quest] = cached
    end
    return cached[1], Theme.color[STATUS_COLOR[cached[1]]], cached[2], cached[3], cached[4]
end
ns.UI.QuestStatus = Status
ns.UI.QuestStatusText = STATUS_TEXT -- status -> the words shown for it

-- Whether the scraped data says a quest listed for `instance` starts inside
-- it, read the way the quest page's "Started by" line reads it: its giver
-- stands there, its starting item is looted from a chest there, or a mob
-- there drops it (the scraper leaves the map spot and dungeon off mobs in
-- the dungeon itself). A joined instance (Stratholme) counts its parts.
function ns.UI.QuestStartsInsideData(quest, instance)
    local function Here(id) return id ~= nil and ns.Data.instances[id] == instance end
    local function DroppedHere()
        for _, mob in ipairs(quest.droppers or {}) do
            if Here(mob.inside) or not (mob.npc or mob.inside) then return true end
        end
        return false
    end
    if quest.startsFrom then
        return quest.fromObject or DroppedHere() or Here(quest.giverInside)
    elseif quest.giver then
        return Here(quest.giverInside)
    elseif quest.providedItem then
        return quest.fromObject or DroppedHere()
    end
    return false
end

-- Whether a quest listed for `instance` starts inside it: dev edit's marks
-- (local checkouts), then the hand-kept fixes in Data/QuestStarts.lua, then
-- the scraped data.
function ns.UI.QuestStartsInside(quest, instance)
    if not (quest and instance) then return false end
    local marked = ns.MapEdit:QuestMark(instance.id, quest.id)
    if marked ~= nil then return marked end
    local kept = ns.Data:QuestStart(instance.id, quest.id)
    if kept ~= nil then return kept end
    return ns.UI.QuestStartsInsideData(quest, instance) and true or false
end

-- A small icon on a quest's row or page that says what it means when
-- hovered (the portal, the share icon). Mouse clicks pass through to the row
-- or page under it, and hovering it keeps the row under it lit.
function ns.UI.HintIcon(parent, atlas, size, tooltipText)
    local icon = CreateFrame("Frame", nil, parent)
    icon.tex = icon:CreateTexture(nil, "OVERLAY")
    icon.tex:SetPoint("CENTER")
    Theme:FitAtlas(icon.tex, atlas, size)
    icon:SetSize(icon.tex:GetSize())
    icon:Hide()
    icon:EnableMouse(true)
    ns.UI.ClicksReachBeneath(icon)
    icon:SetScript("OnEnter", function(self)
        if parent.hover and not parent.isSelected then parent.hover:Show() end -- still over the row
        ShowTooltip(self, "ANCHOR_CURSOR", tooltipText)
    end)
    icon:SetScript("OnLeave", function()
        if parent.hover then parent.hover:Hide() end
        GameTooltip:Hide()
    end)
    return icon
end

-- The Dungeons tab's portal (the Instances header's icon) beside a quest's
-- name when the quest starts inside the dungeon.
function ns.UI.InsideIcon(parent, size)
    return ns.UI.HintIcon(parent, ns.UI.TabIcon("DUNGEON"), size, L["Starts inside the dungeon"])
end

-- Whether the quest (or another version of it) is in the player's quest log,
-- kept until the log changes: the map asks for every marker it draws.
local onQuest = {}
function ns.UI.OnQuest(quest)
    if onQuest[quest] == nil then onQuest[quest] = AnyVersion(quest, C_QuestLog.IsOnQuest) end
    return onQuest[quest]
end

-- With Settings' "Show only accepted quests" (QUEST_MAP_FILTER) on, a
-- quest's map markers show only while the player is on that quest (Mike,
-- 2026-10-16) or the map was opened to show its spot (`focus`). A marker
-- tied to no quest (an escort's start) always shows, and so does the "!"
-- (`kind` "quest") of a quest that starts inside `instance` until it is done,
-- so it can be found before it's picked up. Dev edit shows them all.
function ns.UI.MarkerShows(quest, focus, id, kind, instance)
    if ns.MapEdit.on or not ns.Modules:IsOn("QUEST_MAP_FILTER") or not (quest or id) then return true end
    if quest and kind == "quest" and ns.UI.QuestStartsInside(quest, instance)
        and not AnyVersion(quest, C_QuestLog.IsQuestFlaggedCompleted) then return true end
    if quest then return quest == focus or ns.UI.OnQuest(quest) end
    return C_QuestLog.IsOnQuest(id)
end

-- A marker with no quest of its own (one placed in dev edit before its
-- quest was picked) takes the quest of a marker put on it (on = true, at
-- its spot): Ragefire's kill spot for Testing an Enemy's Strength, its "!"
-- on it. Returns { [marker] = quest ID }.
function ns.UI.PairedQuests(spots)
    local function SpotKey(spot) return ("%s:%s:%s"):format(spot[1], spot[2], spot[3]) end
    local questAt, paired = {}, {}
    for _, spot in ipairs(spots) do
        if spot.on and spot[5] then questAt[SpotKey(spot)] = spot[5] end
    end
    for _, spot in ipairs(spots) do
        if not spot[5] and not spot.on then paired[spot] = questAt[SpotKey(spot)] end
    end
    return paired
end

-- Forgets every kept status, on the quest events and again on the redraws
-- they schedule: the server flags a quest handed in a moment after.
function ns.UI.ForgetQuestStatus()
    wipe(statusCache)
    wipe(onQuest)
    ns.Data:ForgetQuestShareable()
end

for _, event in ipairs({ "QUEST_LOG_UPDATE", "QUEST_TURNED_IN", "QUEST_ACCEPTED", "QUEST_REMOVED" }) do
    ns:On(event, ns.UI.ForgetQuestStatus)
end

-- A quest's chain: its steps, their names and pages, and their rows. A
-- dungeon's questline page (UI/DungeonQuestlines.lua) takes its steps'
-- light pages from it too.
local Chain = {}
ns.UI.QuestChain = Chain

-- The quest page for a quest earlier in a chain, when it is one of the
-- instance's own quests (under its ID or another version's).
function Chain.Page(instance, id)
    local function IsThisQuest(versionID) return versionID == id end
    for _, quest in ipairs(instance and ns.Data.quests[instance.id] or {}) do
        if AnyVersion(quest, IsThisQuest) then return quest end
    end
end

-- A chain step's name. The game's own title can be a secret value in
-- Forever, unusable in text we build or measure; then it reads "quest <id>".
function Chain.Name(instance, id)
    local page = Chain.Page(instance, id)
    local step = ns.Data.chainSteps[id]
    local known = page and page.name or ns.Data.questNames[id] or step and step.name
    if known then return known end
    return ns.Plain(C_QuestLog.GetTitleForQuestID(id)) or L["quest %s"]:format(id)
end

-- A chain step's name as a link that opens its page (Chain.Open):
-- "[The Tome of Divinity]" in the quest colour, or `color` (a color code).
-- `name`, when given, is shown in place of the step's own.
function Chain.Link(instance, id, name, color)
    return ("|Hneedroll:chainquest:%d|h%s[%s]|r|h"):format(id, color or Theme:ColorCode(Theme.color.quest),
        name or Chain.Name(instance, id))
end

-- A quest's whole chain (Data/Chains.lua) for the Quests switch's side and
-- the player's class: its steps (each a list of quest IDs) and which one
-- the quest is. Without chain data: quest.chain then the quest, one per
-- step. A chain's start page is step 1 of the quest it was made from.
function Chain.Of(quest)
    if not quest then return nil end
    if quest.chainOf then
        local steps = Chain.Of(quest.chainOf)
        for i, step in ipairs(steps or {}) do
            if step[1] == quest.id then return steps, i end
        end
        return nil
    end
    local _, class = UnitClass("player")
    local steps, at = ns.Data:Chain(quest.id, ns.UI.QuestSide(), class)
    if steps or not quest.chain or #quest.chain == 0 then return steps, at end
    steps = {}
    for i, id in ipairs(quest.chain) do steps[i] = { id } end
    steps[#steps + 1] = { quest.id }
    Chain.StartPage(quest)
    return steps, #steps
end

-- A chain step's status: Completed, In log or Not started, with its color.
function Chain.Status(id)
    if C_QuestLog.IsQuestFlaggedCompleted(id) then return L["Completed"], Theme.color.complete end
    if C_QuestLog.IsOnQuest(id) then return L["In log"], Theme.color.accepted end
    return L["Not started"], Theme.color.incomplete
end

-- How far chain quest `id` is, as a mark before its name in the quest
-- page's chain rows: the tick once done, "!" in the accepted colour while
-- it is in the quest log, an empty box until then. The goal's portal marks
-- one of the instance's own quests.
Chain.DONE_MARK = "|A:common-icon-checkmark:14:14|a"
Chain.TO_DO_MARK = "|A:checkbox-minimal:12:12|a"
Chain.GOAL_MARK = ("|A:%s:16:16|a"):format(Theme.portalAtlas)
Chain.THIS_QUEST = "|cff3b875b" -- the page's own quest's link, green

function Chain.Mark(id)
    if C_QuestLog.IsQuestFlaggedCompleted(id) then return Chain.DONE_MARK end
    if C_QuestLog.IsOnQuest(id) then return Theme:ColorCode(Theme.color.accepted) .. "!|r" end
    return Chain.TO_DO_MARK
end

-- Chain quest `id` as its chain row reads it: its mark (Chain.Mark), the
-- goal's portal when it is one of `instance`'s quests, then its link, green
-- for the page's own quest (`isThisQuest`).
function Chain.MarkedLink(instance, id, isThisQuest)
    local goal = Chain.Page(instance, id) and Chain.GOAL_MARK .. " " or ""
    return ("%s %s%s"):format(Chain.Mark(id), goal,
        Chain.Link(instance, id, nil, isThisQuest and Chain.THIS_QUEST or nil))
end

-- Whether chain step `ids` is several different quests to pick one of (a
-- choice of reward quests); several copies of one quest (one name, from
-- different givers) are one quest to the player.
function Chain.IsPickOne(instance, ids)
    if ids.all then return false end
    for _, id in ipairs(ids) do
        if Chain.Name(instance, id) ~= Chain.Name(instance, ids[1]) then return true end
    end
    return false
end

-- The quest of chain step `ids` its row names when it is one quest (or
-- copies of one): the page's own (`atID`), else the copy done or in the
-- quest log, else the first.
function Chain.ShownID(ids, atID)
    local shown = ids[1]
    for _, id in ipairs(ids) do
        if id == atID then return id end
        if C_QuestLog.IsQuestFlaggedCompleted(id) or C_QuestLog.IsOnQuest(id) then shown = id end
    end
    return shown
end

-- Chain step `ids`' row text, its quests as Chain.MarkedLink writes them
-- (`atID` the page's own quest): "Do both: A, B, C" ("Do all: ...") for a
-- step whose quests are all needed, every quest of it in order; "Pick one:
-- A or B" for different quests to pick one of; else its quest.
function Chain.StepText(instance, ids, atID)
    local function Marked(id) return Chain.MarkedLink(instance, id, id == atID) end
    if ids.all and #ids.all > 1 then
        local links = {}
        for _, id in ipairs(ids) do table.insert(links, Marked(id)) end
        return (#ids.all == 2 and L["Do both: %s"] or L["Do all: %s"]):format(table.concat(links, ", "))
    end
    if not Chain.IsPickOne(instance, ids) then return Marked(Chain.ShownID(ids, atID)) end
    local choices
    for _, id in ipairs(ids) do choices = choices and L["%s or %s"]:format(choices, Marked(id)) or Marked(id) end
    return L["Pick one: %s"]:format(choices)
end

-- Whether chain step `ids` holds one of `instance`'s own quests: the goal
-- the chain works towards on that instance's pages.
function Chain.IsGoal(instance, ids)
    for _, id in ipairs(ids) do
        if Chain.Page(instance, id) then return true end
    end
    return false
end

-- "Step 3 of 4 in a chain that starts with [first]", counted as the
-- questline page counts (Data:StepNumbers: steps, not quests, lead-ins a
-- player may skip left out); a breadcrumb or optional quest, which has no
-- number, says what it is instead. `steps` holds the quest at `at`.
function Chain.StartText(steps, at, firstLink)
    local numbers, total = ns.Data:StepNumbers(steps)
    if numbers[at] then
        return L["Step %d of %d in a chain that starts with %s"]:format(numbers[at], total, firstLink)
    end
    if ns.Data:IsBreadcrumb(steps[at][1]) then
        return L["Breadcrumb in a chain that starts with %s"]:format(firstLink)
    end
    return L["Optional quest in a chain that starts with %s"]:format(firstLink)
end

-- A light page for a chain step that isn't one of the instance's quests:
-- its name, levels, giver, turn-in, zone, objective and what it sends you
-- to kill or loot (Data/Chains.lua's steps), made once per quest.
local stepPages = {}
function Chain.Step(id)
    local step = ns.Data.chainSteps[id]
    if not step then return stepPages[id] end
    -- Its classes by name, as dungeon quests have them ("Paladin").
    local classes
    for _, token in ipairs(step.classes or {}) do
        local name = ns.UI.ClassName(token)
        classes = classes and classes .. " / " .. name or name
    end
    stepPages[id] = stepPages[id] or { id = id, name = step.name or L["quest %s"]:format(id), level = step.level,
        minLevel = step.minLevel, side = step.side, classes = classes, giver = step.giver, giverNpc = step.giverNpc,
        giverInside = step.giverInside, startsFrom = step.startItem, startsFromId = step.startItemId,
        droppers = step.droppers, objective = step.objective, kills = step.kills, loot = step.loot,
        named = step.named, turnIn = step.turnIn, turnInNpc = step.turnInNpc, turnInInside = step.turnInInside,
        zone = step.zone, stepOnly = true }
    -- A step each side takes from its own NPCs names the nearest of the
    -- player's side, picked again as they move (UI/Lists.lua's PickGivers).
    stepPages[id].giver, stepPages[id].giverNpc = step.giver, step.giverNpc
    return stepPages[id]
end

-- The light page of a chain's first step that Data/Chains.lua doesn't
-- know, from what the quest says of its chain's start: its name, and the
-- item that starts it and what drops it, or who gives it.
function Chain.StartPage(quest)
    local id = quest.chainStart
    if not id or stepPages[id] or ns.Data.chainSteps[id] then return end
    local item = quest.chainStartItem
    stepPages[id] = { id = id, name = quest.chainStartName or ns.Data.questNames[id] or L["quest %s"]:format(id),
        side = quest.side, classes = quest.classes, startsFrom = item, startsFromId = quest.chainStartItemId,
        droppers = item and (quest.chainDroppers or quest.chainGiver and { { name = quest.chainGiver,
        npc = quest.chainGiverNpc, inside = quest.chainGiverInside } }) or nil,
        giver = not item and quest.chainGiver or nil, giverNpc = not item and quest.chainGiverNpc or nil,
        giverInside = not item and quest.chainGiverInside or nil, chainOf = quest, stepOnly = true }
end

-- Opens the game's quest log at a quest you have. The quest map lives in
-- the world map's Blizzard addon, which may not be loaded until the map is
-- first opened. The log is part of the world map, which NeedRoll never
-- opens in combat: chat says why instead.
function Chain.OpenInLog(id)
    if not (QuestMapFrame_OpenToQuestDetails and C_QuestLog.IsOnQuest(id)) then return end
    if ns.UI.MapLinksInCombat() then return ns.UI.SayNoMapInCombat() end
    ns.UI:WithGameMap(QuestMapFrame_OpenToQuestDetails, id)
end

-- Opens a quest's page, Back returning to where the window was.
local function OpenQuestPage(quest)
    ns.UI:PushBack(ns.UI:Place())
    ns.UI:SelectQuest(quest)
end

-- Opens a boss's page, Back returning to where the window was (`backLabel`,
-- when given, names it on the Back button in place of the page's name).
local function OpenBossPage(encounter, backLabel)
    local place = ns.UI:Place()
    place.label = backLabel or place.label
    ns.UI:PushBack(place)
    ns.UI:SelectEncounter(encounter)
    ns.UI.encounters:ScrollTo(encounter)
end

-- The page `pane` opens for quest `id`: the page's host's own (the Classes
-- tab's class quests, pane.findQuest), else the instance's.
function Chain.PageIn(pane, id)
    return pane.findQuest and pane.findQuest(id) or Chain.Page(pane.instance, id)
end

-- Opens a quest's page where `pane` shows it: the Classes tab opens it in
-- its own pane (pane.openQuest), the Dungeons tab in the content pane.
function Chain.OpenPage(pane, quest)
    if pane.openQuest then return pane.openQuest(quest) end
    OpenQuestPage(quest)
end

-- Opens a chain step: the host's own page for it, its light page, or the
-- game's quest log.
function Chain.Open(pane, id)
    local page = Chain.PageIn(pane, id) or Chain.Step(id)
    if not page then return Chain.OpenInLog(id) end
    Chain.OpenPage(pane, page)
end

-- What a click on a chain step's link does (Chain.Open), for its tooltip;
-- nil when it does nothing.
function Chain.OpenHint(pane, id)
    if Chain.PageIn(pane, id) or Chain.Step(id) then return L["Click to open this quest"] end
    if C_QuestLog.IsOnQuest(id) then return L["Click to open it in your quest log"] end
end

-- A chain step's tooltip: the game's quest tooltip when it knows the
-- quest, else its name; then `hint`, what a click does, when there is one.
function Chain.Tooltip(owner, instance, id, hint)
    GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
    if not pcall(GameTooltip.SetHyperlink, GameTooltip, "quest:" .. id) or GameTooltip:NumLines() == 0 then
        GameTooltip:SetText(Chain.Name(instance, id))
    end
    if hint then GameTooltip:AddLine(hint, unpack(Theme.tip.text)) end
    GameTooltip:Show()
end

-- The quest page's Quest chain rows, a step each ({ text, tint, bar }):
-- "3.  [mark] [Name]" numbered as the questline page numbers its steps
-- (Data:StepNumbers), its quests as Chain.StepText writes them; a lead-in a
-- player may skip has no number and says "Breadcrumb" or "Optional". The
-- page's own quest's row says "this quest" and is tinted, in the goal's
-- purple with its bar when it is one of the instance's quests; such a
-- quest's row says "the goal". A long chain (over 9 steps) shows 3 either
-- side of it and a "Show all" link, unless `all`. Nil without a chain of 2
-- steps or more.
function Chain.Lines(instance, quest, all)
    local steps, at = Chain.Of(quest)
    if not steps or #steps < 2 then return nil end
    local numbers = ns.Data:StepNumbers(steps)
    local first, last = 1, #steps
    local cut = not all and #steps > 9 and at
    if cut then first, last = math.max(1, at - 3), math.min(#steps, at + 3) end
    local rows = {}
    for i = first, last do
        local ids = steps[i]
        local isGoal = numbers[i] ~= nil and Chain.IsGoal(instance, ids)
        local kind = not numbers[i] and (ns.Data:IsBreadcrumb(ids[1]) and L["Breadcrumb"] or L["Optional"]) or nil
        local text = Theme:JoinDots(Chain.StepText(instance, ids, i == at and quest.id or nil), kind,
            isGoal and L["the goal"] or nil, i == at and L["this quest"] or nil)
        local row = { text = numbers[i] and ("%d.  %s"):format(numbers[i], text) or text }
        if i == at then
            row.tint = isGoal and Theme.color.goalFill or Theme.color.hover
            row.bar = isGoal and Theme.color.goal or Theme.color.accent
        end
        table.insert(rows, row)
    end
    if cut and (first > 1 or last < #steps) then
        table.insert(rows, { text = ("|Hneedroll:chainall|h%s%s|r|h"):format(Theme:ColorCode(Theme.color.link),
            L["Show all %d steps"]:format(#steps)) })
    end
    return rows, steps, at
end

-- Where a spot (an NPC, a dungeon entrance) is on the game's own map: from
-- its world position when we have it, as Wowhead's percentages can be for
-- another version of the zone map (Forever's Stormwind takes in the harbor).
local function MapSpot(spot, map)
    if spot.continent then
        local _, pos = C_Map.GetMapPosFromWorldPos(spot.continent, CreateVector2D(spot.worldX, spot.worldY), map)
        if pos and pos.x >= 0 and pos.x <= 1 and pos.y >= 0 and pos.y <= 1 then
            return pos.x, pos.y
        end
    end
    return spot.x, spot.y
end

-- A zone's map ID from its name, for the zones new in Forever whose IDs we
-- don't know (Data/Entrances.lua names them). Looked up once, then kept
-- (false: not found). The world's zones first, then every map ID up to
-- LAST_MAP_ID in case it hangs elsewhere.
local WORLD_MAPS = { 947, 946 }  -- Azeroth, then the Cosmic map
local LAST_MAP_ID = 5000
local zoneMaps = {}
local function ZoneMap(map)
    if type(map) ~= "string" then return map end
    if zoneMaps[map] ~= nil then return zoneMaps[map] or nil end
    local wantedName, found = map:lower(), false
    local function Match(id)
        local info = C_Map.GetMapInfo(id)
        if info and info.name and info.name:lower() == wantedName
            and (not found or info.mapType == Enum.UIMapType.Zone) then
            found = id
        end
    end
    for _, root in ipairs(WORLD_MAPS) do
        for _, info in ipairs(C_Map.GetMapChildrenInfo(root, nil, true) or {}) do Match(info.mapID) end
        if found then break end
    end
    if not found then
        for id = 1, LAST_MAP_ID do Match(id) end
    end
    zoneMaps[map] = found
    return found or nil
end
ns.UI.ZoneMap = ZoneMap  -- the zone button on the game's map names the entrance's zone (UI/WorldMapOverlay.lua)

-- Where a spot goes on the game's map: its map ID and x, y from 0 to 1.
-- Nil, said in chat, when its zone isn't found or that map takes no pins.
-- The secure links that run the game's /mappin (UI/MainFrame.lua) and
-- NeedRoll's own pin (ShowOnMap) both place spots through here.
function ns.UI.MapPoint(spot)
    if not spot then return nil end
    local map = ZoneMap(spot.map)
    if not map then
        print(CHAT_PREFIX .. L["can't find the %s map."]:format(spot.map))
        return nil
    end
    local x, y = MapSpot(spot, map)
    if not x or not C_Map.CanSetUserWaypointOnMap(map) then
        print(CHAT_PREFIX .. L["that map doesn't take pins."])
        return nil
    end
    return map, x, y
end

-- Naming the part of a zone a spot is in (ns.UI.ZoneArea). `cities`: the
-- capital cities' maps, small enough that the city's name is enough.
-- `parts`: a zone map cut in thirds across and down, the north row first.
local ZONE_AREA = {
    cities = {
        [1453] = true, [1454] = true, [1455] = true,  -- Stormwind City, Orgrimmar, Ironforge
        [1456] = true, [1457] = true, [1458] = true,  -- Thunder Bluff, Darnassus, Undercity
    },
    parts = {
        { L["Northwest %s"], L["Northern %s"], L["Northeast %s"] },
        { L["Western %s"], L["Central %s"], L["Eastern %s"] },
        { L["Southwest %s"], L["Southern %s"], L["Southeast %s"] },
    },
}

-- Where a spot is on its zone's map, without a word in chat when it can't
-- tell (ns.UI.MapPoint speaks up, as a click wants): the map's info, then x
-- and y from 0 to 1. Nil when the zone or the spot on it isn't known.
function ns.UI.ZoneSpot(spot)
    local map = spot and ZoneMap(spot.map)
    local info = map and C_Map.GetMapInfo(map)
    if not (info and info.name) then return nil end
    local x, y = MapSpot(spot, map)
    return info, x, y
end

-- A spot's zone and the third of it the spot is in: "Central Wetlands",
-- "Southwest Westfall". A capital city or a map that isn't a zone's (a
-- continent's) gives its name alone: "Ironforge". Nil when the zone isn't known.
function ns.UI.ZoneArea(spot)
    local info, x, y = ns.UI.ZoneSpot(spot)
    if not info then return nil end
    if ZONE_AREA.cities[info.mapID] or info.mapType ~= Enum.UIMapType.Zone or not (x and y) then
        return info.name
    end
    local function Third(fraction) return math.max(1, math.min(3, math.floor(fraction * 3) + 1)) end
    return ZONE_AREA.parts[Third(y)][Third(x)]:format(info.name)
end

-- A link's hint when it pins `spot`: "Click to pin on your map (Wetlands
-- [56.2, 40.4])", or without the place when the zone isn't known.
function ns.UI.PinHint(spot)
    local info, x, y = ns.UI.ZoneSpot(spot)
    if not (info and x and y) then return L["Click to pin on your map"] end
    return L["Click to pin on your map (%s [%.1f, %.1f])"]:format(info.name, x * 100, y * 100)
end

-- In combat NeedRoll's links can't place the game's map pin (a secure
-- button's action can't change then), which a click for one tells the
-- player in chat, and NeedRoll's own pin's tooltip says too.
ns.UI.NO_MAP_PINS_IN_COMBAT =
    L["Forever Addon API blocks addons from linking map pins in combat, please try again when you're out of combat."]
function ns.UI.SayNoMapPinsInCombat()
    print(CHAT_PREFIX .. ns.UI.NO_MAP_PINS_IN_COMBAT)
end

-- Nor does NeedRoll open or move the game's map in combat (UI:OpenZoneMap):
-- a link that would says so in chat instead.
ns.UI.NO_MAP_IN_COMBAT =
    L["Forever Addon API blocks addons from opening the map in combat, please try again when you're out of combat."]
function ns.UI.SayNoMapInCombat()
    print(CHAT_PREFIX .. ns.UI.NO_MAP_IN_COMBAT)
end

-- Nor does it turn the game's map to another floor in combat (the floor
-- chips on the game's map, UI/WorldMapOverlay.lua).
ns.UI.NO_FLOOR_CHANGE_IN_COMBAT =
    L["Forever Addon API blocks addons from changing the map's floor in combat, please try again when you're out of combat."]
function ns.UI.SayNoFloorChangeInCombat()
    print(CHAT_PREFIX .. ns.UI.NO_FLOOR_CHANGE_IN_COMBAT)
end

-- A click on a link that pins a spot, when it reaches NeedRoll's own code:
-- in combat (ns.UI.MapLinksInCombat), with the link's secure button put
-- away. Out of combat that button lies over the link while the mouse is on
-- it, runs the game's /mappin and the click never gets here (see
-- UI.HoverMapLink in UI/MainFrame.lua). NeedRoll never sets the game's pin
-- itself, which would stop the player sharing it, so it draws its own pin
-- there on the world map (UI/WorldMapOverlay.lua), named `name` (the
-- zone's name when nil). It can't open the map there in combat either (that
-- would taint the game's map), so chat says which zone's map holds the pin.
local function ShowOnMap(spot, name)
    local map, x, y = ns.UI.MapPoint(spot)
    if not map then return end
    local info = C_Map.GetMapInfo(map)
    local zoneName = info and info.name or ""
    if not name or name == "" then name = zoneName end
    ns.WorldMapOverlay:ShowPin(map, x, y, name)
    if not ns.UI.MapLinksInCombat() then return end
    ns.UI.SayNoMapPinsInCombat()
    print(CHAT_PREFIX .. L["Pinned %s on your %s map."]:format(name, zoneName))
end
ns.UI.ShowOnMap = ShowOnMap  -- recipe sources in the loot pane pin NPCs too

-- `text` as a link that pins a dungeon's entrance, when we know where it is,
-- in `color` (the link color unless given).
local function EntranceLink(inside, text, color)
    color = ns.Data.entrances[inside] and Theme:ColorCode(color or Theme.color.link) or ""
    return ("|Hneedroll:inside:%s|h%s%s%s|h"):format(inside, color, text, color ~= "" and "|r" or "")
end

-- The marks before a quest giver's name and before a mob that drops an item
-- that starts a quest or teaches a recipe, sized to the line's text. They
-- sit inside the name's link, so clicking either pins the same spot.
local GIVER_ICON = "|A:TaxiNode_Continent_Alliance:0:0|a"
local DROPPER_ICON = "|A:TaxiNode_Continent_Horde:0:0|a"
ns.UI.GIVER_MARK = GIVER_ICON  -- the Classes tab's Overview marks its trainers the same way

-- A boss of the instance the page is in, by NPC ID or else by name: its
-- name then shows the boss on the instance's map (the mark before it still
-- pins the game's map).
local function BossHere(here, npc, name)
    local instance = here and ns.Data:Get(here)
    if not instance then return nil end
    for _, encounter in ipairs(instance.encounters or {}) do
        if not encounter.overview and (npc and encounter.npc == npc or not npc and encounter.name == name) then
            return encounter
        end
    end
end

-- BossHere by NPC ID, else by name (a giver inside is often a boss listed
-- under another NPC ID).
local function BossNamed(here, npc, name)
    return BossHere(here, npc, name) or npc and BossHere(here, nil, name)
end

-- A quest's drop area on an instance's map: the level of its "loot"
-- marker, or nil; `any`: else the level of any marker of the quest, or the
-- map's first for a zone-wide quest.
function ns.UI.QuestDropSpot(here, questID, any)
    local map = here and ns.Data:Map(here)
    if not map then return nil end
    local edit = ns.MapEdit:Spots(here, map)
    local markers = edit and edit.markers or map.markers or {}
    for _, spot in ipairs(markers) do
        if spot[4] == "loot" and spot[5] == questID then return spot[1] end
    end
    if not any then return nil end
    for _, spot in ipairs(markers) do
        if spot[5] == questID then return spot[1] end
    end
    -- A zone-wide quest (kills or drops anywhere inside, Quell the
    -- Uprising): the map's first level, its badge showing the quest.
    for _, entry in ipairs(ns.MapEdit:ZoneQuests(here) or ns.Data:ZoneQuests(here)) do
        if entry[1] == questID then return map.start or 1 end
    end
end

-- The needroll: link pinning an NPC (negative: an object) on the world map.
-- One standing somewhere else for each quest (ns.Data:NpcSpot) names the
-- quest whose page it is on, `questID`, too.
local function NpcTarget(npc, questID)
    local forQuest = questID and ns.Data.questSpots[questID]
    if forQuest and forQuest[npc] then return ("needroll:npc:%d:%d"):format(npc, questID) end
    return "needroll:npc:" .. npc
end

-- Where a click on a giver's name goes, the way Giver links it: a boss of
-- this instance on its map, the NPC's spot on the world map (for quest
-- `questID`), else the entrance of the dungeon they stand in (this one too).
-- nil when nowhere is known.
local function GiverTarget(name, npc, inside, here, questID)
    local boss = BossNamed(here, npc, name)
    if boss then return "needroll:boss:" .. boss.id end
    if ns.Data:NpcSpot(npc, questID) then return NpcTarget(npc, questID) end
    if inside and ns.Data.entrances[inside] then return "needroll:inside:" .. inside end
end

-- Where a click on an NPC or mob named on the page goes, as a needroll:
-- link: this instance's boss on its map, the NPC's spot on the world map,
-- another dungeon's entrance, or this dungeon's map (`inHere`: it stands
-- somewhere in this dungeon, no spot of its own). nil when nowhere is known.
local function PlaceTarget(name, npc, inside, here, inHere, questID)
    local target = GiverTarget(name, npc, inside ~= here and inside or nil, here, questID)
    if target then return target end
    if (inside == here or inHere) and here and ns.Data:Map(here) then return "needroll:dungeonmap" end
end

-- `shown` as a link to `target` in `color`, after `icon` (a giver's or
-- dropper's mark, or "").
local function PlaceLink(target, icon, color, shown)
    return ("|H%s|h%s%s%s|r|h"):format(target, icon, Theme:ColorCode(color), shown)
end

-- A mob the scraper names with neither a map spot nor a dungeon stands in
-- the dungeon the quest is listed for.
local function StandsHere(source)
    return not (source.npc or source.inside)
end

-- A quest giver's name: a link that pins them on the map when we know where
-- they stand. Givers inside a dungeon read "Bijou (inside)", or "(in Dire
-- Maul: West)" for another dungeon; that link pins the dungeon's entrance.
-- `kind` "giver" marks the name with the Alliance flight point, "dropper"
-- (a mob dropping a quest's starting item) with the Horde one in its red;
-- nil (a mob to kill) leaves it plain. `questID`: the quest whose page it is.
local function Giver(name, npc, inside, here, kind, questID)
    local icon = kind == "giver" and GIVER_ICON or kind == "dropper" and DROPPER_ICON or ""
    local color = kind == "dropper" and Theme.color.dropper or Theme.color.link
    local npcSpot = ns.Data:NpcSpot(npc, questID)
    local boss = BossNamed(here, npc, name)
    if boss then
        if icon ~= "" and npcSpot then
            icon = ("|H%s|h%s|h"):format(NpcTarget(npc, questID), icon)
        end
        return icon .. PlaceLink("needroll:boss:" .. boss.id, "", color, name)
    end
    if npcSpot then
        local link = PlaceLink(NpcTarget(npc, questID), icon, color, name)
        if kind ~= "dropper" then return link end
        -- An enemy out in the world says where: "in Southern Wetlands (60.3, 73.8)".
        local area = ns.UI.ZoneArea(npcSpot)
        local _, x, y = ns.UI.ZoneSpot(npcSpot)
        if not (area and x and y) then return link end
        return L["%s in %s"]:format(link, ("%s (%.1f, %.1f)"):format(area, x * 100, y * 100))
    end
    local dungeon = inside and ns.Data:Get(inside)
    if dungeon then
        return EntranceLink(inside, icon .. (inside == here and L["%s (inside)"]:format(name)
            or L["%s (in %s)"]:format(name, dungeon.name)), color)
    end
    if kind ~= "dropper" then return icon .. name end
    -- An enemy somewhere in this dungeon: its map. Nowhere known to pin:
    -- the mark and color without the link.
    if here and ns.Data:Map(here) then return PlaceLink("needroll:dungeonmap", icon, color, name) end
    return icon .. Theme:ColorCode(color) .. name .. "|r"
end

-- Who starts or takes in a quest, and where they stand when their link pins
-- them: "Rethiel the Greenwarden in Central Wetlands", "Gerrig Bonegrip in
-- Ironforge". A boss, or someone with no map spot, reads as Giver alone.
local function GiverInArea(name, npc, inside, here, questID)
    local giver = Giver(name, npc, inside, here, "giver", questID)
    if BossNamed(here, npc, name) then return giver end
    local area = ns.UI.ZoneArea(ns.Data:NpcSpot(npc, questID))
    return area and L["%s in %s"]:format(giver, area) or giver
end

-- A mob with no spot of its own in this dungeon, as a red dropper's link to
-- its quest's place on the dungeon's map (its drop area, else its marker).
local function DropSpotLink(questID, name)
    return PlaceLink("needroll:dropspot:" .. questID, DROPPER_ICON, Theme.color.dropper, name)
end

-- Mobs or chests, { name, npc, inside } each: "A, B and C" (or "A or B"),
-- each a map link like a giver, or "A and B in Lower Blackrock Spire" when
-- all stand in one other dungeon. `word` joins the last two: L["%s and %s"]
-- or L["%s or %s"]. With `quest`, one in this dungeon with no spot of its
-- own links to the quest's place on its map, like Droppers.
local function Places(list, here, word, quest)
    local inside = list[1].inside
    for _, source in ipairs(list) do
        if source.inside ~= inside then inside = nil end
    end
    local dungeon = inside and inside ~= here and ns.Data:Get(inside)
    local names = {}
    local questID = quest and quest.id
    for i, source in ipairs(list) do
        -- Enemies to kill or loot: red, with the red map mark, like droppers.
        names[i] = dungeon and source.name or Giver(source.name, source.npc, source.inside, here, "dropper", questID)
        local inThisDungeon = not dungeon and (source.inside == nil or source.inside == here)
        local hasOwnSpot = ns.Data:NpcSpot(source.npc, questID) or BossHere(here, source.npc, source.name)
        if inThisDungeon and quest and not hasOwnSpot and ns.UI.QuestDropSpot(here, quest.id, true) then
            names[i] = DropSpotLink(quest.id, source.name)
        end
    end
    local text = names[#names]
    if #names > 1 then
        text = word:format(table.concat(names, ", ", 1, #names - 1), text)
    end
    return dungeon and L["%s in %s"]:format(text, EntranceLink(inside, dungeon.name)) or text
end

-- The mobs that drop a quest's starting item, "A or B", each a red map link
-- marked as a dropper (nil when none are known); with `quest`, one with no
-- spot of its own links to the quest's drop area on this instance's map.
-- Second, whether every one is a chest or object out in the world (a
-- negative ID, Henrig Lonebrow's Journal), which the item is looted from
-- rather than dropped by.
local function Droppers(list, here, quest)
    if not list or #list == 0 then return nil end
    local questID = quest and quest.id
    local spot = quest and ns.UI.QuestDropSpot(here, questID)
    local text
    local allObjects = true
    for _, dropper in ipairs(list) do
        local name = Giver(dropper.name, dropper.npc, dropper.inside, here, "dropper", questID)
        if spot and not ns.Data:NpcSpot(dropper.npc, questID) then name = DropSpotLink(questID, dropper.name) end
        text = text and L["%s or %s"]:format(text, name) or name
        allObjects = allObjects and (dropper.npc or 0) < 0
    end
    return text, allObjects
end

-- An item that starts a quest: a link that shows the game's tooltip on
-- hover, in its quality color once the client has it (`onLoad` runs when it
-- arrives), else plain text.
local function ItemLink(name, id, onLoad)
    if not id then return name end
    local color = Theme:ColorCode(Theme.color.text)
    if not C_Item.IsItemDataCachedByID(id) then
        ns.Items:Load(id, onLoad)
    else
        -- Same colors as the loot tables; an item that starts a quest is never junk.
        local r, g, b = Theme:QualityColor(math.max(ns.Items:Quality(id), 1))
        color = Theme:ColorCode({ r, g, b })
    end
    return ("|Hitem:%d|h%s[%s]|r|h"):format(id, color, name)
end

-- Quest text addresses the player: $N / <name> is their name, $C their
-- class, $R their race, and $Gmale:female; picks by their sex.
local function FillTokens(text)
    local name = UnitName("player") or L["adventurer"]
    local class = UnitClass("player") or ""
    local race = UnitRace("player") or ""
    local female = UnitSex("player") == 3
    text = text:gsub("%$[Gg]%s*([^:;]*):%s*([^;]*);", function(male, fem) return female and fem or male end)
    text = text:gsub("%$[Nn]", name):gsub("%$[Cc]", class):gsub("%$[Rr]", race)
    return (text:gsub("<name>", name):gsub("<class>", class):gsub("<race>", race))
end

-- Where `name` stands in `text` as whole words from `from` on (a plural
-- "es" or "s" after it counts, so "Ragefire Troggs" is a Ragefire Trogg):
-- its first and last character, or nil.
local PLURALS = { "es", "s", "" }  -- longest first, so "es" isn't cut to its "e"
local function FindWholeName(text, name, from)
    while true do
        local first, last = text:find(name, from, true)
        if not first then return nil end
        if not text:sub(first - 1, first - 1):find("%w") then
            for _, ending in ipairs(PLURALS) do
                local stop = last + #ending
                if text:sub(last + 1, stop) == ending and not text:sub(stop + 1, stop + 1):find("%w") then
                    return first, stop
                end
            end
        end
        from = first + 1
    end
end

-- The names a quest's objective links, { name, isItem, Link(shown) } each:
-- its givers, turn-in NPC and the NPCs it names (blue, with the giver's
-- mark), the mobs it sends you to kill or loot from and this instance's
-- bosses (red, with the dropper's mark), and the items it asks for or starts
-- with (item links; a click shows where they come from). Names with nowhere
-- to pin are left out.
local MIN_LINKED_NAME = 4  -- characters; a shorter name is too likely a plain word
local function ObjectiveNames(quest, here, onLoad)
    local names = {}
    local function AddPlace(name, target, isEnemy)
        if not (name and target and #name >= MIN_LINKED_NAME) then return end
        local icon = isEnemy and DROPPER_ICON or GIVER_ICON
        local color = isEnemy and Theme.color.dropper or Theme.color.link
        table.insert(names, { name = name, Link = function(shown) return PlaceLink(target, icon, color, shown) end })
    end
    local function AddNpc(npc, isEnemy)
        AddPlace(npc.name, PlaceTarget(npc.name, npc.npc, npc.inside, here, StandsHere(npc), quest.id), isEnemy)
    end
    local function AddItem(name, itemID)
        if not (name and itemID and #name >= MIN_LINKED_NAME) then return end
        table.insert(names, { name = name, isItem = true, Link = function(shown)
            return ItemLink(shown, itemID, onLoad)
        end })
    end
    -- Givers go where Started by sends them; one by a dungeon's door
    -- (Bodley) pins its entrance.
    AddPlace(quest.giver, GiverTarget(quest.giver, quest.giverNpc, quest.giverNear or quest.giverInside, here,
        quest.id))
    AddPlace(quest.chainGiver, GiverTarget(quest.chainGiver, quest.chainGiverNpc, quest.chainGiverInside, here,
        quest.id))
    -- The turn-in NPC links like the NPCs the text names: one inside this
    -- dungeon shows on its map.
    AddPlace(quest.turnIn, PlaceTarget(quest.turnIn, quest.turnInNpc, quest.turnInInside, here, nil, quest.id))
    for _, npc in ipairs(quest.named or {}) do AddNpc(npc, false) end
    for _, mob in ipairs(quest.kills or {}) do AddNpc(mob, true) end
    for _, loot in ipairs(quest.loot or {}) do
        AddItem(loot.name, loot.item)
        for _, source in ipairs(loot.from) do AddNpc(source, true) end
    end
    local instance = here and ns.Data:Get(here)
    for _, encounter in ipairs(instance and instance.encounters or {}) do
        if not encounter.overview then AddPlace(encounter.name, "needroll:boss:" .. encounter.id, true) end
    end
    AddItem(quest.startsFrom, quest.startsFromId)
    AddItem(quest.providedItem, quest.providedItemId)
    return names
end

-- A quest's objective with every name ObjectiveNames gives linked where
-- it first stands as whole words, longest name first so "Spire Spider Eggs"
-- (an item) wins over the Spire Spider in it: An Ancient Grudge's "the
-- spirit of Faldrim Anvilmar" opens his pin on the Hall of Thanes map.
function ns.UI.LinkObjective(text, quest, here, onLoad)
    local names = ObjectiveNames(quest, here, onLoad)
    table.sort(names, function(a, b)
        if #a.name ~= #b.name then return #a.name > #b.name end
        return a.isItem and not b.isItem  -- an item and a chest named alike: the item
    end)
    local spans, linkedNames = {}, {}
    local function IsFree(first, last)
        for _, span in ipairs(spans) do
            if first <= span.last and last >= span.first then return false end
        end
        return true
    end
    for _, entry in ipairs(names) do
        if not linkedNames[entry.name] then
            linkedNames[entry.name] = true
            local first, last = FindWholeName(text, entry.name, 1)
            while first and not IsFree(first, last) do first, last = FindWholeName(text, entry.name, first + 1) end
            if first then table.insert(spans, { first = first, last = last, Link = entry.Link }) end
        end
    end
    table.sort(spans, function(a, b) return a.first < b.first end)
    local parts, from = {}, 1
    for _, span in ipairs(spans) do
        table.insert(parts, text:sub(from, span.first - 1))
        table.insert(parts, span.Link(text:sub(span.first, span.last)))
        from = span.last + 1
    end
    table.insert(parts, text:sub(from))
    return table.concat(parts)
end

-- A loot target's mobs or chests. One every humanoid in the dungeon drops
-- (anyHumanoidChance: Treshala's Pendant) has "any humanoid" for them all,
-- standing anywhere in the dungeon.
local function LootSources(loot)
    if loot.anyHumanoidChance then return { { name = L["any humanoid"] } } end
    return loot.from
end

-- Where an item named on a quest's page comes from: the mobs or chests of
-- its loot target, or the mobs that drop the item that starts the quest or
-- its chain.
local function ItemSources(quest, itemID)
    for _, loot in ipairs(quest.loot or {}) do
        if loot.item == itemID then return LootSources(loot) end
    end
    if itemID == quest.startsFromId or itemID == quest.providedItemId then return quest.droppers end
    if itemID == quest.chainStartItemId then return quest.chainDroppers end
end

-- Where a click on an item named on a quest's page goes, as a needroll:
-- link: the first of its sources that has one. Then that source's name.
local function ItemPlace(quest, itemID, here)
    if not quest then return nil end
    for _, source in ipairs(ItemSources(quest, itemID) or {}) do
        local target = PlaceTarget(source.name, source.npc, source.inside, here, StandsHere(source), quest.id)
        if target then return target, source.name end
    end
end

-- A layout map tile's file ID or texture path (see Data/Maps.lua).
local function TileID(tiles, n)
    if type(tiles) == "table" then return tiles[n] end
    if type(tiles) == "string" then return tiles .. n end
    for position, tileNumber in ipairs(ART.TILE_ORDER) do
        if tileNumber == n then return tiles + position - 1 end
    end
end

-- Puts a layout map level's art on `tiles` (its 12 textures): the first of
-- the level's tile sets the game has. Returns whether it has any.
local function LoadTiles(tiles, level)
    for set = 2, #level do
        local found = 0
        for n, tile in ipairs(tiles) do
            if tile:SetTexture(TileID(level[set], n)) ~= false then found = found + 1 end
        end
        if found > 0 then return true end
    end
    return false
end

-- A layout map level's tile textures on `parent`, art set by LoadTiles.
local function NewTiles(parent)
    local tiles = {}
    for n = 1, #ART.TILE_ORDER do tiles[n] = parent:CreateTexture(nil, "ARTWORK") end
    return tiles
end

-- Lays the tiles out 4 across and 3 down, `size` px each, their top left
-- corner (x, y) from `parent`'s.
local function PlaceTiles(tiles, size, parent, x, y)
    for n, tile in ipairs(tiles) do
        tile:SetSize(size, size)
        tile:ClearAllPoints()
        tile:SetPoint("TOPLEFT", parent, "TOPLEFT", x + ((n - 1) % 4) * size, y - math.floor((n - 1) / 4) * size)
    end
end

-- Level names written in Data/Maps.lua, in the player's language.
local FLOORS = {
    ["Armory"] = L["Armory"], ["Blackmaw Hold"] = L["Blackmaw Hold"],
    ["Blackrock Stadium"] = L["Blackrock Stadium"], ["Cathedral"] = L["Cathedral"],
    ["City of Dalaran"] = L["City of Dalaran"], ["Dalaran Sewers"] = L["Dalaran Sewers"],
    ["Dragonspire Hall"] = L["Dragonspire Hall"], ["Excavation Site"] = L["Excavation Site"],
    ["Graveyard"] = L["Graveyard"], ["Hall of Binding"] = L["Hall of Binding"],
    ["Hall of Thanes"] = L["Hall of Thanes"], ["Library"] = L["Library"],
    ["Ruins of Lordaeron"] = L["Ruins of Lordaeron"],
}

-- A map level's name: the game's own string for it, the name as written,
-- or "Level N".
local function LevelName(level, i)
    local name = level[1]
    return _G["DUNGEON_FLOOR_" .. name] or (name:find("%l") and (FLOORS[name] or name)) or L["Level %d"]:format(i)
end

-- The name of level `index` of the instance's layout map, as its floor tab
-- shows it (the floor chips on the game's map use it too).
function ns.UI.LevelName(instance, index)
    return LevelName(ns.Data:Map(instance.id)[index], index)
end

-- Every layout map level by its art: a level's first tile's file ID ->
-- { { instance, level }, ... }. Worked out once.
local floorsByArt
local function FloorsByArt()
    if floorsByArt then return floorsByArt end
    floorsByArt = {}
    for _, category in ipairs({ "DUNGEON", "RAID" }) do
        for _, instance in ipairs(ns.Data:List(category)) do
            for i, level in ipairs(ns.Data:Map(instance.id) or {}) do
                for set = 2, #level do
                    local file = TileID(level[set], 1)
                    if type(file) == "number" then
                        floorsByArt[file] = floorsByArt[file] or {}
                        table.insert(floorsByArt[file], { instance, i })
                    end
                end
            end
        end
    end
    return floorsByArt
end

-- One of `floors` ({ instance, level } each): `prefer`'s (an instance), else
-- one of the instance the player is inside, else the first. Returns its
-- instance and level.
local function PickFloor(floors, prefer)
    local where, best = ns.Data:PlayerWhereabouts(), nil
    for _, floor in ipairs(floors) do
        if floor[1] == prefer then return floor[1], floor[2] end
        if not best or (ns.Data:IsPlayerInside(floor[1], where) and not ns.Data:IsPlayerInside(best[1], where)) then
            best = floor
        end
    end
    if best then return best[1], best[2] end
end

-- The dungeon or raid level the game's map `uiMap` shows, or nil: the game
-- draws its floors from the same art files as our levels. `prefer` (an
-- instance) wins when a floor belongs to more than one. Returns the instance
-- and the level.
function ns.UI.MapFloor(uiMap, prefer)
    local art = uiMap and C_Map.GetMapArtLayerTextures(uiMap, 1)
    for _, file in ipairs(art or {}) do
        local floors = FloorsByArt()[file]
        if floors then return PickFloor(floors, prefer) end
    end
end

-- The dungeon or raid the player is inside and the level of its layout map
-- they are on, or nil: the game's map for where they stand (MapFloor); the
-- drawings the game lacks (Media/Maps) go by the instance's map ID (else its
-- name) and the floor's name. `prefer` (an instance) wins when a floor
-- belongs to more than one.
function ns.UI.PlayerFloor(prefer)
    --[==[@debug@
    -- Testing outside a dungeon: Crystal Lake in Elwynn Forest stands in for
    -- the Deadmines' Ironclad Cove.
    if GetSubZoneText() == "Crystal Lake" and GetZoneText() == "Elwynn Forest" then
        return ns.Data:Get("DEADMINES"), 2
    end
    --@end-debug@]==]
    if not IsInInstance() then return nil end
    local uiMap = C_Map.GetBestMapForUnit("player")
    local instance, level = ns.UI.MapFloor(uiMap, prefer)
    if instance then return instance, level end
    -- No art in common: the instance by name, on the level named like the
    -- game's floor, else the level its map opens on.
    local info = uiMap and C_Map.GetMapInfo(uiMap)
    local floorName = info and info.name and info.name:lower()
    local found, where = {}, ns.Data:PlayerWhereabouts()
    for _, category in ipairs({ "DUNGEON", "RAID" }) do
        for _, candidate in ipairs(ns.Data:List(category)) do
            local map = ns.Data:Map(candidate.id)
            if map and ns.Data:IsPlayerInside(candidate, where) then
                local floor = math.min(#map, map.start or 1)
                for i = 1, #map do
                    if LevelName(map[i], i):lower() == floorName then floor = i end
                end
                table.insert(found, { candidate, floor })
            end
        end
    end
    return PickFloor(found, prefer)
end

-- A layout map level's boss pins (Data/Maps.lua, or map edit mode's copy),
-- { encounter, x, y, creature display ID, spot } each; a pin without a
-- display ID uses its encounter's. A pin with npc = <creature ID> marks a
-- creature that isn't one of the encounters: only its name and portrait.
local units = {}
local function UnitEncounter(spot)
    local key = spot[1]
    units[key] = units[key] or { id = key, unit = true }
    units[key].name = spot.name or L["Unit %s"]:format(spot.npc)
    return units[key]
end
local function BossPins(instance, map, current)
    local byID = {}
    for _, encounter in ipairs(instance.encounters) do byID[encounter.id] = encounter end
    local pins = {}
    local edit = ns.MapEdit:Spots(instance.id, map)
    for _, spot in ipairs(edit and edit.pins[current] or map[current].pins or {}) do
        local encounter = byID[spot[1]] or spot.npc and UnitEncounter(spot)
        if encounter then table.insert(pins, { encounter, spot[2], spot[3], spot[4] or encounter.display, spot }) end
    end
    return pins
end

-- The quests whose map markers are put on a boss (boss = its key), for
-- its page's Related Quests: the ones the Quests switch's side can take.
function ns.UI.RelatedQuests(instance, encounter)
    local map = instance and encounter and ns.Data:Map(instance.id)
    if not map then return {} end
    local edit = ns.MapEdit:Spots(instance.id, map)
    local related, seen, side = {}, {}, ns.UI.QuestSide()
    for _, spot in ipairs(edit and edit.markers or map.markers or {}) do
        local quest = spot.boss == encounter.id and ns.Data:DungeonQuest(instance.id, spot[5])
        if quest and not seen[quest] and not (quest.side and quest.side ~= side) then
            seen[quest] = true
            table.insert(related, quest)
        end
    end
    return related
end

-- Zone-wide quests (Data/Maps.lua's RegisterZoneQuests) count anywhere in
-- the dungeon, so have no one spot. A map with some gets a soft gold edge
-- with rounded corners and a glow inside it, and a badge in its top left
-- corner with one icon per quest. Hovering an icon deepens the glow and
-- lights the level's walkable-area outlines (Data/Outlines.lua), or washes
-- the whole map without any; its tooltip gives the quest's status and
-- objectives, and a click opens it.
local ZONE_ICONS = { loot = "Crosshair_lootall_96" }  -- besides the map markers' icons
-- The edge: a 2px line just outside the map, its 5px corners close enough
-- that the painting's square corner stays under it.
local ZONE_INSET, ZONE_RADIUS = -1.5, 5
-- The badge: a row of quest icons (their glow larger behind them), padded
-- inside the line round it, its bottom right corner rounded.
local BADGE = { ICON = 22, GLOW = 30, GAP = 6, PAD_LEFT = 8, PAD_RIGHT = 10, PAD_Y = 5, LINE = 2, CORNER = 12 }

-- The highlight color and the badge's fill, by skin.
local function ZoneColors()
    if Theme.native then return { 1, 209 / 255, 0 }, { 20 / 255, 14 / 255, 8 / 255, 0.82 } end
    return { 252 / 255, 210 / 255, 159 / 255 }, { 0, 16 / 255, 33 / 255, 0.86 }
end

-- A rounded corner for a filled shape (the caller colors it): a square in
-- `parent`'s `point` corner, masked by a disc twice its size.
local function QuarterDisc(parent, layer, point, radius)
    local quarter = parent:CreateTexture(nil, layer)
    quarter:SetSize(radius, radius)
    quarter:SetPoint(point)
    local mask = parent:CreateMaskTexture()
    mask:SetSize(radius * 2, radius * 2)
    mask:SetPoint(point)
    mask:SetTexture(Theme.roundMask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    quarter:AddMaskTexture(mask)
    return quarter
end

-- Makes view.zone: over the map (not zoomed with it) the edge, its glow and
-- the badge; under the pins, the wash that lights the map on hover.
local function CreateZoneOverlay(view)
    local zone = {}
    view.zone = zone
    local clip = view.clip
    zone.over = CreateFrame("Frame", nil, view)
    zone.over:SetAllPoints(clip)
    zone.over:SetFrameLevel(clip:GetFrameLevel() + 40)
    zone.frame = CreateFrame("Frame", nil, zone.over)
    zone.frame:SetPoint("TOPLEFT", ZONE_INSET, -ZONE_INSET)
    zone.frame:SetPoint("BOTTOMRIGHT", -ZONE_INSET, ZONE_INSET)
    -- The glow fading inward from each side, short of the corners.
    zone.glows = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local across = side == "TOP" or side == "BOTTOM"
        local glow = zone.frame:CreateTexture(nil, "ARTWORK")
        if across then
            glow:SetPoint(side .. "LEFT", ZONE_RADIUS, 0)
            glow:SetPoint(side .. "RIGHT", -ZONE_RADIUS, 0)
        else
            glow:SetPoint("TOP" .. side, 0, -ZONE_RADIUS)
            glow:SetPoint("BOTTOM" .. side, 0, ZONE_RADIUS)
        end
        glow.side, glow.across = side, across
        table.insert(zone.glows, glow)
    end
    -- The badge: under the edge's line, which runs on over its top and left.
    local badge = CreateFrame("Frame", nil, zone.frame)
    zone.badge = badge
    badge:SetPoint("TOPLEFT")
    badge:SetFrameLevel(zone.frame:GetFrameLevel() + 2)
    badge:SetClipsChildren(true)
    -- Its fill: quarter discs round the top left and bottom right corners,
    -- and three rectangles that don't overlap (the strip under the top left
    -- corner is anchored once the badge's height is known).
    local right = badge:CreateTexture(nil, "BACKGROUND")
    right:SetPoint("TOPLEFT", badge, "TOPLEFT", ZONE_RADIUS, 0)
    right:SetPoint("BOTTOMRIGHT", badge, "BOTTOMRIGHT", 0, BADGE.CORNER)
    badge.leftStrip = badge:CreateTexture(nil, "BACKGROUND")
    local bottomRow = badge:CreateTexture(nil, "BACKGROUND")
    bottomRow:SetPoint("BOTTOMLEFT")
    bottomRow:SetPoint("TOPRIGHT", badge, "BOTTOMRIGHT", -BADGE.CORNER, BADGE.CORNER)
    badge.fills = { right, badge.leftStrip, bottomRow, QuarterDisc(badge, "BACKGROUND", "TOPLEFT", ZONE_RADIUS),
        QuarterDisc(badge, "BACKGROUND", "BOTTOMRIGHT", BADGE.CORNER) }
    badge.icons = {}
    -- The edge's and the badge's lines (DrawZoneLines).
    zone.lineFrame = CreateFrame("Frame", nil, zone.frame)
    zone.lineFrame:SetAllPoints(zone.over)
    zone.lineFrame:SetFrameLevel(badge:GetFrameLevel() + 2)
    zone.lines = {}
    -- A level without outlines, while an icon is hovered: the whole map
    -- inside the edge washed light blue, its corners rounded to match.
    zone.hover = CreateFrame("Frame", nil, view)
    zone.hover:SetAllPoints(zone.frame)
    zone.hover:SetClipsChildren(true)
    zone.hover:SetFrameLevel(view.canvas:GetFrameLevel() + 4)
    local wash = CreateFrame("Frame", nil, zone.hover)
    zone.wash = wash
    wash:SetAllPoints()
    local middle = wash:CreateTexture(nil, "ARTWORK")
    middle:SetPoint("TOPLEFT", wash, "TOPLEFT", ZONE_RADIUS, 0)
    middle:SetPoint("BOTTOMRIGHT", wash, "BOTTOMRIGHT", -ZONE_RADIUS, 0)
    wash.fills = { middle }
    for _, side in ipairs({ "LEFT", "RIGHT" }) do
        local strip = wash:CreateTexture(nil, "ARTWORK")
        strip:SetPoint("TOP" .. side, wash, "TOP" .. side, 0, -ZONE_RADIUS)
        strip:SetPoint("BOTTOM" .. side, wash, "BOTTOM" .. side, 0, ZONE_RADIUS)
        strip:SetWidth(ZONE_RADIUS)
        table.insert(wash.fills, strip)
    end
    for _, corner in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
        table.insert(wash.fills, QuarterDisc(wash, "ARTWORK", corner, ZONE_RADIUS))
    end
    zone.hover:Hide()
    return zone
end

-- The edge's glow, fading from the edge inward: 12px at 0.35 at rest,
-- 22px at 0.55 while an icon is hovered.
local function SetZoneGlow(zone, hovered)
    local depth, alpha = hovered and 22 or 12, hovered and 0.55 or 0.35
    local gold = zone.color
    local solid, clear = CreateColor(gold[1], gold[2], gold[3], alpha), CreateColor(gold[1], gold[2], gold[3], 0)
    for _, glow in ipairs(zone.glows) do
        glow:SetColorTexture(1, 1, 1, 1)
        if glow.across then glow:SetHeight(depth) else glow:SetWidth(depth) end
        local orient = glow.across and "VERTICAL" or "HORIZONTAL"
        if glow.side == "TOP" or glow.side == "RIGHT" then
            glow:SetGradient(orient, clear, solid)
        else
            glow:SetGradient(orient, solid, clear)
        end
    end
end

-- While a badge icon is hovered: the level's walkable-area outlines lit (dev
-- edit shows them all the while), or the wash without any; the glow deepens.
local function LightZone(view, on)
    local zone = view.zone
    zone.hover:SetShown(on and not zone.shapes)
    SetZoneGlow(zone, on)
    if zone.shapes and not ns.MapEdit.on then view.drawRoutes(on and zone.shapes or {}) end
end

-- A badge icon's tooltip: the quest with its status, its objectives, then
-- under a thin rule where it counts and what a click does.
local function ShowZoneQuestTooltip(icon)
    local quest = icon.quest
    local status, color = Status(quest)
    GameTooltip:SetOwner(icon, "ANCHOR_RIGHT")
    GameTooltip:SetText(("%s  -  %s%s|r"):format(quest.name, Theme:ColorCode(color), STATUS_TEXT[status]), 1, 0.82, 0)
    local hasObjectives = false
    for _, objective in ipairs(C_QuestLog.GetQuestObjectives(quest.id) or {}) do
        if objective.text and objective.text ~= "" then
            if not hasObjectives then GameTooltip:AddLine(" ") end
            hasObjectives = true
            local shade = objective.finished and 0.5 or 1
            GameTooltip:AddLine("•  " .. objective.text, shade, shade, shade)
        end
    end
    -- A thin rule across the tooltip on an empty line of its own.
    GameTooltip:AddLine(" ")
    local ruleLine = GameTooltip:NumLines()
    GameTooltip:AddLine(L["Anywhere in %s"]:format(icon.where), 0.13, 1, 0.13)
    if ns.Modules:IsOn("QUESTS") then GameTooltip:AddLine(L["Click to open this quest"], unpack(Theme.tip.text)) end
    GameTooltip:Show()
    local rule = GameTooltip.needRollRule
    if not rule then
        rule = GameTooltip:CreateTexture(nil, "ARTWORK")
        rule:SetHeight(1)
        GameTooltip.needRollRule = rule
        -- Gone when the tooltip shows anything else.
        local function Hide() rule:Hide() end
        GameTooltip:HookScript("OnHide", Hide)
        if GameTooltip:HasScript("OnTooltipCleared") then GameTooltip:HookScript("OnTooltipCleared", Hide) end
    end
    local text = _G["GameTooltipTextLeft" .. ruleLine]
    if not text then return end
    rule:SetColorTexture(0.5, 0.5, 0.5, 0.6)
    rule:ClearAllPoints()
    rule:SetPoint("LEFT", text, "LEFT")
    rule:SetWidth(GameTooltip:GetWidth() - 20)
    rule:Show()
end

-- The badge's icon `i`: hovering lights the zone; a click opens its quest.
local function NewZoneQuestIcon(view)
    local badge = view.zone.badge
    local icon = CreateFrame("Button", nil, badge)
    icon:SetSize(BADGE.ICON, BADGE.ICON)
    icon.glow = icon:CreateTexture(nil, "BACKGROUND")
    icon.glow:SetPoint("CENTER")
    icon.glow:SetBlendMode("ADD")
    icon.glow:Hide()
    icon.icon = icon:CreateTexture(nil, "ARTWORK")
    icon.icon:SetPoint("CENTER")
    icon:SetScript("OnEnter", function(self)
        LightZone(view, true)
        self.glow:Show()
        ShowZoneQuestTooltip(self)
    end)
    icon:SetScript("OnLeave", function(self)
        LightZone(view, false)
        self.glow:Hide()
        GameTooltip:Hide()
    end)
    icon:SetScript("OnClick", function(self)
        GameTooltip:Hide()
        LightZone(view, false)
        view.openQuest(self.quest)
    end)
    return icon
end

-- The edge's rounded rectangle and the badge's right and bottom sides, each
-- piece a faint dark shadow (a touch of vignette), a soft glow and the line.
local function DrawZoneLines(zone, badgeWidth, badgeHeight)
    local gold = zone.color
    local used = 0
    local function NewZoneLine(layer) return zone.lineFrame:CreateLine(nil, layer) end
    local function Segment(x1, y1, x2, y2)
        for pass = 1, 3 do
            used = used + 1
            local line = Pooled(zone.lines, used, NewZoneLine, ({ "BACKGROUND", "BORDER", "OVERLAY" })[pass])
            line:SetStartPoint("TOPLEFT", zone.lineFrame, x1, -y1)
            line:SetEndPoint("TOPLEFT", zone.lineFrame, x2, -y2)
            line:SetThickness(({ 7, 4, 2 })[pass])
            if pass == 1 then
                line:SetColorTexture(0, 0, 0, 0.3)
            else
                line:SetColorTexture(gold[1], gold[2], gold[3], pass == 2 and 0.2 or 0.9)
            end
            line:Show()
        end
    end
    -- A quarter arc around (cx, cy) from one angle to another (radians, y down).
    local function Arc(cx, cy, radius, from, to)
        -- Pieces about 2.5px long: shorter ones don't draw.
        local pieces = math.max(2, math.floor(radius * (to - from) / 2.5 + 0.5))
        for k = 0, pieces - 1 do
            local a1, a2 = from + (to - from) * k / pieces, from + (to - from) * (k + 1) / pieces
            Segment(cx + radius * math.cos(a1), cy + radius * math.sin(a1),
                cx + radius * math.cos(a2), cy + radius * math.sin(a2))
        end
    end
    local width, height = zone.over:GetWidth(), zone.over:GetHeight()
    local left, top, right, bottom = ZONE_INSET, ZONE_INSET, width - ZONE_INSET, height - ZONE_INSET
    local radius = ZONE_RADIUS
    Segment(left + radius, top, right - radius, top)
    Segment(right, top + radius, right, bottom - radius)
    Segment(right - radius, bottom, left + radius, bottom)
    Segment(left, bottom - radius, left, top + radius)
    local pi = math.pi
    Arc(left + radius, top + radius, radius, pi, pi * 1.5)
    Arc(right - radius, top + radius, radius, pi * 1.5, pi * 2)
    Arc(right - radius, bottom - radius, radius, 0, pi * 0.5)
    Arc(left + radius, bottom - radius, radius, pi * 0.5, pi)
    -- The badge's right side and bottom, with its rounded corner.
    local badgeRight, badgeBottom = left + badgeWidth, top + badgeHeight
    local corner = BADGE.CORNER
    Segment(badgeRight, top, badgeRight, badgeBottom - corner)
    Segment(badgeRight - corner, badgeBottom, left, badgeBottom)
    Arc(badgeRight - corner, badgeBottom - corner, corner, 0, pi * 0.5)
    HideFrom(zone.lines, used + 1)
end

-- Draws `instance`'s zone-wide quests on its map's `level` (none: hides it all).
local function DrawZoneQuests(view, instance, level)
    local zone = view.zone or CreateZoneOverlay(view)
    local gold, fill = ZoneColors()
    zone.color = gold
    local side = ns.UI.QuestSide()
    local quests = {}
    for _, entry in ipairs(ns.MapEdit:ZoneQuests(instance.id) or ns.Data:ZoneQuests(instance.id)) do
        local quest = ns.Data:DungeonQuest(instance.id, entry[1])
        local icon = ZONE_ICONS[entry[2]] or ns.Data.markerIcons[entry[2]]
        if quest and icon and not (quest.side and quest.side ~= side)
            and ns.UI.MarkerShows(quest, view.focusQuest) then
            table.insert(quests, { quest = quest, icon = icon })
        end
    end
    zone.over:SetShown(#quests > 0)
    zone.hover:Hide()
    if #quests == 0 then return end

    SetZoneGlow(zone, false)
    local badge = zone.badge
    for _, texture in ipairs(badge.fills) do texture:SetColorTexture(unpack(fill)) end
    for i, entry in ipairs(quests) do
        local icon = MapWidget(view, view.zone.badge.icons, i, NewZoneQuestIcon)
        icon.quest, icon.where = entry.quest, instance.name
        Theme:FitAtlas(icon.icon, entry.icon, BADGE.ICON)
        Theme:FitAtlas(icon.glow, entry.icon, BADGE.GLOW)
        icon.glow:SetDesaturated(true)
        icon.glow:SetVertexColor(gold[1], gold[2], gold[3], 0.8)
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", badge, "TOPLEFT", BADGE.LINE + BADGE.PAD_LEFT + (i - 1) * (BADGE.ICON + BADGE.GAP),
            -(BADGE.LINE + BADGE.PAD_Y))
        icon:Show()
    end
    HideFrom(badge.icons, #quests + 1)
    local badgeWidth = BADGE.LINE + BADGE.PAD_LEFT + #quests * BADGE.ICON + (#quests - 1) * BADGE.GAP
        + BADGE.PAD_RIGHT + BADGE.LINE
    local badgeHeight = BADGE.LINE + BADGE.PAD_Y + BADGE.ICON + BADGE.PAD_Y + BADGE.LINE
    badge:SetSize(badgeWidth, badgeHeight)
    badge.leftStrip:ClearAllPoints()
    badge.leftStrip:SetPoint("TOPLEFT", badge, "TOPLEFT", 0, -ZONE_RADIUS)
    badge.leftStrip:SetPoint("BOTTOMRIGHT", badge, "TOPLEFT", ZONE_RADIUS, -(badgeHeight - BADGE.CORNER))
    DrawZoneLines(zone, badgeWidth, badgeHeight)

    -- What a hover lights: the level's outlines, or the wash without any.
    local outlines = ns.MapEdit:Outlines(instance.id) or ns.Data:Outlines(instance.id)
    zone.shapes = nil
    for _, shape in ipairs(level and outlines[level] or {}) do
        shape.area = true
        zone.shapes = zone.shapes or {}
        table.insert(zone.shapes, shape)
    end
    for _, texture in ipairs(zone.wash.fills) do texture:SetColorTexture(unpack(ROUTE.AREA_FILL)) end
end

-- The giver and dropper markers (NPC links) in a line of text at `size`:
-- half again its size (their art has room around it), centred on the
-- line, with a space before the name.
function ns.UI.SizeMarkers(text, size)
    local icon = math.floor(size * 1.5 + 0.5)
    return (text:gsub("(|A:[^:|]+):0:0|a", ("%%1:%d:%d:0:%d|a "):format(icon, icon,
        -math.floor((icon - size) / 2 + 0.5))))
end

-- The level of an instance's layout map a boss is pinned on, or nil: the
-- Map button on a boss's page shows only for a pinned boss.
function ns.UI.BossFloor(instance, encounter)
    local map = instance and encounter and not encounter.overview and ns.Data:Map(instance.id)
    if not map then return nil end
    local edit = ns.MapEdit:Spots(instance.id, map)
    for level = 1, #map do
        for _, spot in ipairs(edit and edit.pins[level] or map[level].pins or {}) do
            if spot[1] == encounter.id then return level end
        end
    end
    return nil
end

local function PageWidth(pane)
    return pane:GetWidth() - Size.pad * 2
end

-- A quest page's arrows to its chain's previous and next steps, at the top
-- right (each shown when there's a step that way): pane.steps.
local function CreateChainArrows(pane)
    pane.steps = {}
    for i = 1, 2 do
        local atlas = i == 1 and "wowlabs-spectatecycling-arrowleft" or "wowlabs-spectatecycling-arrowright"
        local arrow = CreateFrame("Button", nil, pane)
        arrow:SetSize(32, 32)
        arrow:SetPoint("TOPRIGHT", -Size.pad - (2 - i) * 44, -10)
        -- A soft dark copy behind, a touch down and right, for depth.
        arrow.shadow = arrow:CreateTexture(nil, "BACKGROUND")
        arrow.shadow:SetSize(34, 34)
        arrow.shadow:SetPoint("CENTER", 1.5, -1.5)
        arrow.shadow:SetAtlas(atlas)
        arrow.shadow:SetVertexColor(0, 0, 0, 0.55)
        arrow.icon = arrow:CreateTexture(nil, "ARTWORK")
        arrow.icon:SetAllPoints()
        arrow.icon:SetAtlas(atlas)
        arrow.lit = arrow:CreateTexture(nil, "HIGHLIGHT")
        arrow.lit:SetAllPoints()
        arrow.lit:SetAtlas(atlas)
        arrow.lit:SetBlendMode("ADD")
        arrow.lit:SetAlpha(0.4)
        arrow:SetScript("OnClick", function(self) Chain.Open(pane, self.id) end)
        arrow:SetScript("OnEnter", function(self)
            local label = (i == 1 and L["Previous: %s"] or L["Next: %s"])
            ShowTooltip(self, "ANCHOR_BOTTOMLEFT", label:format(Chain.Name(pane.instance, self.id)))
        end)
        arrow:SetScript("OnLeave", GameTooltip_Hide)
        arrow:Hide()
        pane.steps[i] = arrow
    end
end

-- The Overview's stat boxes, a label over a value each ("Players" in a raid).
local function CreateFacts(canvas)
    local facts = {}
    for i, label in ipairs({ L["Level range"], L["Zone"], L["Encounters"], L["Quests"] }) do
        local box = CreateFrame("Frame", nil, canvas)
        box:SetSize(120, FACT.HEIGHT)
        Theme:StatBackdrop(box)
        box.label = Theme:Text(box, Theme.font.factLabel)
        box.label:SetPoint("TOPLEFT", FACT.PAD_LEFT, -8)
        box.label:SetText(label)
        box.value = Theme:Text(box, Theme.font.factValue)
        box.value:SetPoint("TOPLEFT", box.label, "BOTTOMLEFT", 0, -5)
        facts[i] = box
    end
    return facts
end

-- The map card under the stat boxes: a picture of the layout map's first
-- level, cropped to where its bosses are, under a strip naming it.
-- Clicking anywhere on it runs `onClick` (which opens the map).
local function CreateMapCard(canvas, onClick)
    local card = CreateFrame("Button", nil, canvas)
    card:Hide()
    card.art = CreateFrame("Frame", nil, card)
    card.art:SetAllPoints()
    card.art:SetClipsChildren(true)
    card.tiles = NewTiles(card.art)
    card.top = CreateFrame("Frame", nil, card)  -- the strip and the border, over the picture
    card.top:SetAllPoints()
    card.top:SetFrameLevel(card.art:GetFrameLevel() + 2)
    card.bar = card.top:CreateTexture(nil, "ARTWORK")
    card.bar:SetColorTexture(0, 0, 0, 0.62)
    card.bar:SetPoint("BOTTOMLEFT")
    card.bar:SetPoint("BOTTOMRIGHT")
    card.bar:SetHeight(CARD.BAR)
    card.icon = card.top:CreateTexture(nil, "OVERLAY")
    Theme:FitAtlas(card.icon, "FullMap-up-c60", CARD.ICON)
    card.icon:SetPoint("CENTER", card.bar, "LEFT", 8 + CARD.ICON / 2, 0)
    card.name = Theme:Text(card.top, Theme.font.body)
    card.name:SetPoint("LEFT", card.bar, "LEFT", 14 + CARD.ICON, 0)
    Theme:SetTextColor(card.name, Theme.color.heading)
    card.levels = Theme:Text(card.top, Theme.font.small)  -- "  ·  2 levels"
    card.levels:SetPoint("LEFT", card.name, "RIGHT", 0, 0)
    Theme:SetTextColor(card.levels, Theme.color.muted)
    card.hint = Theme:Text(card.top, Theme.font.small)
    card.hint:SetPoint("RIGHT", card.bar, "RIGHT", -10, 0)
    card.hint:SetText(L["Click to open"])
    Theme:SetTextColor(card.hint, Theme.color.text)
    local gold = Theme.color.heading
    local edgeColor = Theme.native and { gold[1], gold[2], gold[3], 0.45 } or Theme.color.accent
    card.edges = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        table.insert(card.edges, Theme:Edge(card.top, side, edgeColor))
    end
    -- Hovering brightens the picture and lights the border gold.
    local function LightCard(lit)
        local shade = lit and 1 or 0.8
        for _, tile in ipairs(card.tiles) do tile:SetVertexColor(shade, shade, shade) end
        for _, edge in ipairs(card.edges) do
            edge:SetColorTexture(unpack(lit and Theme.color.heading or edgeColor))
        end
    end
    LightCard(false)
    card:SetScript("OnEnter", function() LightCard(true) end)
    card:SetScript("OnLeave", function() LightCard(false) end)
    card:SetScript("OnClick", function()
        LightCard(false)
        onClick()
    end)

    -- Loads the picture for an instance: its map's first level (the one
    -- the map opens on). Returns whether the game has its art.
    function card:LoadArt(instance)
        if self.id == instance.id then return self.found end
        self.id = instance.id
        local map = ns.Data:Map(instance.id)
        local current = math.min(#map, map.start or 1)
        self.found = LoadTiles(self.tiles, map[current])
        -- The middle of the bosses' pins, so the crop shows where they are.
        local left, right, top, bottom = 1, 0, 1, 0
        for _, spot in ipairs(BossPins(instance, map, current)) do
            left, right = math.min(left, spot[2]), math.max(right, spot[2])
            top, bottom = math.min(top, spot[3]), math.max(bottom, spot[3])
        end
        self.cx = left <= right and (left + right) / 2 or 0.5
        self.cy = top <= bottom and (top + bottom) / 2 or 0.5
        self.name:SetText(instance.category == "RAID" and L["Raid map"] or L["Dungeon map"])
        self.levels:SetText(#map > 1 and Theme.DOTS .. L["%d levels"]:format(#map) or "")
        return self.found
    end

    -- Fills the card's width, as much of the map's height as fits, with the
    -- bosses in the middle of the part above the strip.
    function card:PlaceArt(width)
        local room = CARD.HEIGHT - CARD.BAR
        local scale = math.max(width / ART.W, CARD.HEIGHT / ART.H)
        local w, h = ART.W * scale, ART.H * scale
        local dx = math.max(0, math.min(w - width, self.cx * w - width / 2))
        local dy = math.max(0, math.min(h - room, self.cy * h - room / 2))
        PlaceTiles(self.tiles, ART.TILE * scale, self.art, -dx, dy)
    end
    return card
end

-- "Westfall  ·  42.5, 71.8": the entrance's zone and its spot there.
local function EntranceText(spot, instance)
    local id = type(spot.map) == "number" and spot.map
    local info = id and C_Map.GetMapInfo(id)
    local zone = type(spot.map) == "string" and spot.map or (info and info.name) or instance.zone or ""
    local x, y
    if id then x, y = MapSpot(spot, id) end
    if x and y then return zone .. Theme.DOTS .. ("%.1f, %.1f"):format(x * 100, y * 100) end
    return zone
end

-- The entrance row: where the entrance is, and a button that pins it on
-- the world map (the whole row does too). Dimmed, without the button,
-- when the entrance isn't known (some instances new in Forever).
local function CreateEntranceRow(pane, canvas)
    local entrance = CreateFrame("Button", nil, canvas)
    entrance:Hide()
    Theme:StatBackdrop(entrance)
    entrance.icon = entrance:CreateTexture(nil, "ARTWORK")
    Theme:FitAtlas(entrance.icon, "Targeting-down-c60", ENTRANCE_ICON)
    entrance.icon:SetPoint("CENTER", entrance, "LEFT", 10 + ENTRANCE_ICON / 2, 0)
    entrance.label = Theme:Text(entrance, Theme.font.label)
    entrance.label:SetPoint("TOPLEFT", 18 + ENTRANCE_ICON, -6)
    entrance.label:SetText(Theme:Label(L["Entrance"]))
    entrance.value = Theme:Text(entrance, Theme.font.body)
    entrance.value:SetPoint("TOPLEFT", entrance.label, "BOTTOMLEFT", 0, -3)
    entrance.value:SetJustifyH("LEFT")

    local show
    if Theme.native then
        show = CreateFrame("Button", nil, entrance, "UIPanelButtonTemplate")
        show:SetText(L["Show on map"])
        show:SetSize(110, 22)
        function show:SetLit(lit) if lit then self:LockHighlight() else self:UnlockHighlight() end end
    else
        show = CreateFrame("Button", nil, entrance)
        show:SetSize(104, 24)
        Theme:Rounded(show, Theme.color.primary)
        show.text = Theme:Text(show, Theme.font.body)
        show.text:SetPoint("CENTER")
        show.text:SetText(L["Show on map"])
        Theme:SetTextColor(show.text, Theme.color.heading)
        function show:SetLit(lit) self.bg:SetVertexColor(unpack(lit and Theme.color.accent or Theme.color.primary)) end
    end
    show:SetPoint("RIGHT", -8, 0)
    entrance.value:SetPoint("RIGHT", show, "LEFT", -8, 0)
    entrance.button = show

    local function Spot()
        return pane.instance and ns.Data:Entrance(pane.instance.id)
    end
    for _, button in ipairs({ entrance, show }) do
        button:SetScript("OnClick", function() ShowOnMap(Spot(), pane.instance and pane.instance.name) end)
        button:SetScript("OnEnter", function(self)
            ns.UI.HoverMapLink(self, Spot())
            show:SetLit(Spot() ~= nil)
            ShowTooltip(self, "ANCHOR_RIGHT", pane.instance and pane.instance.name or "", Spot()
                and L["Click to pin the entrance on your map"] or L["Where the entrance is isn't known yet"])
        end)
        button:SetScript("OnLeave", function(self)
            ns.UI.LeaveMapLink(self)
            show:SetLit(false)
            GameTooltip:Hide()
        end)
    end

    function entrance:Fill(instance)
        local spot = Spot()
        self.icon:SetDesaturated(not spot)
        self.icon:SetAlpha(spot and 1 or 0.4)
        self.value:SetText(spot and EntranceText(spot, instance) or L["Not known yet"])
        Theme:SetTextColor(self.value, spot and Theme.color.text or Theme:Opaque(Theme.color.muted, Theme.color.panel2))
        show:SetShown(spot ~= nil)
        show:SetLit(false)
    end
    return entrance
end

-- A font string's font size, or `fallback` while it has no font.
local function FontSize(text, fallback)
    local _, size = text:GetFont()
    return size or fallback
end

-- How far along its last line the title's text ends, and which line that is
-- (0 = the first), when the title is `width` px wide: a long name wraps word
-- by word in a narrow window.
local function LastLineWidth(title, width)
    local text = title:GetText() or ""
    local x = title:GetUnboundedStringWidth()
    if width <= 0 or x <= width then return x, 0 end
    local last, line = "", 0
    for word in text:gmatch("%S+") do
        local try = last == "" and word or last .. " " .. word
        title:SetText(try)
        if last ~= "" and title:GetUnboundedStringWidth() > width then
            last, line = word, line + 1
        else
            last = try
        end
    end
    title:SetText(last)
    x = math.min(title:GetUnboundedStringWidth(), width)
    title:SetText(text)
    return x, line
end

-- Puts the dungeon portal just after the title's last word, on whichever
-- line that ends up.
local function PlaceInsideIcon(pane)
    local icon, title = pane.titleInside, pane.title
    if not icon:IsShown() then return end
    local scale = icon:GetScale()
    local x, line = LastLineWidth(title, pane:GetWidth() - pane.titleLeft - Size.pad - icon:GetWidth() * scale)
    local size = FontSize(title, 16)
    icon:ClearAllPoints()
    -- Offsets are in the portal's own scale.
    icon:SetPoint("LEFT", title, "TOPLEFT", (x + 2) / scale,
        (-line * (size + title:GetSpacing()) - size / 2) / scale)
end

-- Lays out the title block (pane:PlaceTitle). An instance's Overview: its
-- name in the bigger instance font. A quest's page: its name at the edge
-- (after its class icon for a class quest). The title stops short of Back
-- when that shows. `class` (a token) puts that class's icon left of a
-- quest's name; `inside` puts the dungeon portal after it.
local function PlaceTitle(pane, isInstance, class, inside)
    local left = Size.pad + 4
    -- A quest's name 1.375x the heading font, its subtitle 1.2x and its
    -- level line 1.1x the small font.
    local title = isInstance and Theme.font.instance or Theme:ScaledFont(Theme.font.heading, 1.375)
    pane.title:SetFontObject(title)
    local muted = Theme:Opaque(Theme.color.muted, Theme.color.panel2)
    pane.sub:SetFontObject(isInstance and Theme.font.small or Theme:ScaledFont(Theme.font.small, 1.2))
    pane.levelLine:SetFontObject(isInstance and Theme.font.small or Theme:ScaledFont(Theme.font.small, 1.1))
    Theme:SetTextColor(pane.sub, muted)
    Theme:SetTextColor(pane.levelLine, muted)
    local titleSize = FontSize(pane.title, 16)
    local subSize, levelSize = FontSize(pane.sub, 10), FontSize(pane.levelLine, 10)
    -- The class icon as tall as the name and the two lines under it,
    -- and the portal sized to the name. Offsets are in their own scale.
    local badge = pane.titleBadge
    local badgeScale = (titleSize + TITLE.SUB_GAP + subSize + TITLE.LEVEL_GAP + levelSize) / TITLE_BADGE
    badge:SetScale(badgeScale)
    pane.titleInside:SetScale(isInstance and 1 or titleSize / 16)
    badge:SetClass(not isInstance and class or nil)
    if badge:IsShown() then
        badge:ClearAllPoints()
        -- Centred on the title and the two lines under it together, its
        -- ring (reaching an eighth of the badge past it) 14px from them.
        local gap = TITLE_BADGE * badgeScale * 0.125 + 14
        badge:SetPoint("RIGHT", pane.title, "LEFT", -gap / badgeScale,
            -(TITLE.SUB_GAP + TITLE.LEVEL_GAP + subSize + levelSize) / 2 / badgeScale)
        left = left + TITLE_BADGE * badgeScale * 1.125 + gap
    end
    pane.title:ClearAllPoints()
    pane.title:SetPoint("TOPLEFT", left, isInstance and -TITLE.INSTANCE_TOP or -TITLE.QUEST_TOP)
    -- The name stops short of the portal's room.
    local showInside = not isInstance and inside or false
    pane.title:SetPoint("RIGHT", -Size.pad - (pane.stepRoom or 0)
        - (showInside and pane.titleInside:GetWidth() * pane.titleInside:GetScale() + 2 or 0), 0)
    pane.titleLeft = left
    pane.titleInside:SetShown(showInside)
    PlaceInsideIcon(pane)
end

-- Around the title: a class quest's class icon, the dungeon portal after a
-- quest that starts inside, the line under it (pane.sub) and a quest page's
-- level line, with the chain link in the line under it.
local function CreateTitleParts(pane)
    pane.titleBadge = Theme:ClassBadge(pane, TITLE_BADGE)
    pane.titleBadge:Hide()
    pane.titleInside = ns.UI.InsideIcon(pane, TITLE_INSIDE)
    pane.PlaceTitle = PlaceTitle
    pane:HookScript("OnSizeChanged", PlaceInsideIcon)

    -- The line under the title, in a frame of its own so its link (the
    -- quest of a chain you're on) can be clicked.
    local subLinks = CreateFrame("Frame", nil, pane)
    pane.sub = Theme:Text(subLinks, Theme.font.small)
    pane.sub:SetPoint("TOPLEFT", pane.title, "BOTTOMLEFT", 0, -TITLE.SUB_GAP)
    Theme:SetTextColor(pane.sub, Theme:Opaque(Theme.color.muted, Theme.color.panel2))
    subLinks:SetAllPoints(pane.sub)
    -- A quest page's "Requires level 9  ·  Quest level 16", under the subtitle in its font.
    pane.levelLine = Theme:Text(pane, Theme.font.small)
    pane.levelLine:SetPoint("TOPLEFT", pane.sub, "BOTTOMLEFT", 0, -TITLE.LEVEL_GAP)
    pane:PlaceTitle(false)
    subLinks:SetHyperlinksEnabled(true)
    subLinks:SetScript("OnHyperlinkClick", function(_, link)
        local id = tonumber(link:match("^needroll:chainquest:(%d+)"))
        if id then Chain.Open(pane, id) end
    end)
    subLinks:SetScript("OnHyperlinkEnter", function(self, link)
        local id = tonumber(link:match("^needroll:chainquest:(%d+)"))
        if id then Chain.Tooltip(self, pane.instance, id, Chain.OpenHint(pane, id)) end
    end)
    subLinks:SetScript("OnHyperlinkLeave", GameTooltip_Hide)
end

-- The layout map, in place of the Overview's lines: a tab per level when
-- there are several, then the level's art fitted to the pane with pins and
-- marks on it (x and y from 0 to 1 across the drawn art). Zoomed, the art's
-- canvas grows inside a clipping window (view.clip); view.cx, view.cy is
-- the fraction of the art at the window's centre.

-- Keeps the window inside the art at the current zoom.
local function ClampCenter(view)
    local half = 0.5 / view.zoom
    view.cx = math.min(math.max(view.cx, half), 1 - half)
    view.cy = math.min(math.max(view.cy, half), 1 - half)
end

-- Sizes the canvas for the zoom, view.cx, view.cy at the window's centre.
local function PlaceCanvas(view)
    local clip, canvas = view.clip, view.canvas
    local w, h = clip:GetWidth() * view.zoom, clip:GetHeight() * view.zoom
    canvas:ClearAllPoints()
    canvas:SetPoint("TOPLEFT", clip, "TOPLEFT", clip:GetWidth() / 2 - view.cx * w, view.cy * h - clip:GetHeight() / 2)
    canvas:SetSize(w, h)
end

-- Centres `frame` on the art's spot (x, y), `dx` px right of it.
local function PlaceOnArt(view, frame, x, y, scale, dx)
    frame:SetPoint("CENTER", view.canvas, "TOPLEFT", x * ART.W * scale + (dx or 0), -y * ART.H * scale)
end

-- Patrol routes, drawn as line segments: a soft glow, a bright core and
-- arrows pointing the way the boss walks (an open route, walked back and
-- forth, gets an arrowhead at each end). Map edit mode shows every route
-- on the level with a handle on each point (NewRouteHandle).
-- A patrol is { x1, y1, x2, y2, ... }; this gives point `point`'s x and y.
local function PointXY(patrol, point)
    return patrol[point * 2 - 1], patrol[point * 2]
end

-- One coordinate on the Catmull-Rom curve from p1 to p2 (p0 and p3 are the
-- points either side, which set its bend). t goes 0 to 1 along the stretch;
-- t2 and t3 are its square and cube.
local function CatmullRom(p0, p1, p2, p3, t, t2, t3)
    return 0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (3 * p1 - p0 - 3 * p2 + p3) * t3)
end

-- Catmull-Rom through the route's points, in canvas units: a closed
-- loop, or an open line from the first point to the last.
local function RoutePath(view, patrol)
    local w, h = view.canvas:GetWidth(), view.canvas:GetHeight()
    local n = math.floor(#patrol / 2)
    local function PointAt(i)
        if patrol.open then
            i = math.min(math.max(i, 1), n)
        else
            i = (i - 1) % n + 1
        end
        local x, y = PointXY(patrol, i)
        return x * w, y * h
    end
    local path = {}
    for i = 1, patrol.open and n - 1 or n do
        local x0, y0 = PointAt(i - 1)
        local x1, y1 = PointAt(i)
        local x2, y2 = PointAt(i + 1)
        local x3, y3 = PointAt(i + 2)
        for step = 0, ROUTE.STEPS - 1 do
            local t = step / ROUTE.STEPS
            local t2, t3 = t * t, t * t * t
            table.insert(path, { CatmullRom(x0, x1, x2, x3, t, t2, t3), CatmullRom(y0, y1, y2, y3, t, t2, t3) })
        end
    end
    if patrol.open then table.insert(path, { PointAt(n) }) end
    return path
end

local function NewRouteLine(canvas)
    return canvas:CreateLine(nil, "OVERLAY")
end

-- One line from the route pool, (x1, y1) to (x2, y2) in canvas units.
local function RouteSegment(view, x1, y1, x2, y2, thickness, color)
    view.routeUsed = view.routeUsed + 1
    local line = Pooled(view.routeLines, view.routeUsed, NewRouteLine, view.canvas)
    line:SetStartPoint("TOPLEFT", view.canvas, x1, -y1)
    line:SetEndPoint("TOPLEFT", view.canvas, x2, -y2)
    line:SetThickness(thickness)
    line:SetColorTexture(unpack(color))
    line:Show()
end

-- A soft-edged textured line for an area's outline, with .dot, a soft dot
-- for its end so the outline never breaks at a joint.
local function NewAreaLine(canvas)
    local line = canvas:CreateLine(nil, "OVERLAY", nil, 6)
    line:SetTexture(AREA_LINE_TEXTURE)
    line:SetThickness(ROUTE.AREA_WIDTH)
    line.dot = canvas:CreateTexture(nil, "OVERLAY", nil, 6)
    line.dot:SetTexture(AREA_DOT_TEXTURE)
    line.dot:SetSize(ROUTE.AREA_WIDTH, ROUTE.AREA_WIDTH)
    return line
end

-- One piece of an area's outline, (x1, y1) to (x2, y2) in canvas units.
local function SoftSegment(view, x1, y1, x2, y2)
    view.areaUsed = view.areaUsed + 1
    local canvas = view.canvas
    local line = Pooled(view.areaLines, view.areaUsed, NewAreaLine, canvas)
    local dot = line.dot
    line:SetStartPoint("TOPLEFT", canvas, x1, -y1)
    line:SetEndPoint("TOPLEFT", canvas, x2, -y2)
    dot:ClearAllPoints()
    dot:SetPoint("CENTER", canvas, "TOPLEFT", x2, -y2)
    for _, texture in ipairs({ line, dot }) do
        texture:SetVertexColor(unpack(ROUTE.AREA_LINE))
        texture:Show()
    end
end

-- A solid arrowhead with its tip at (x, y), pointing along heading: a pale
-- rim, then the dark amber fill, each a fan of lines from the tip across
-- the base.
local function Arrowhead(view, x, y, heading, size)
    local dirX, dirY = math.cos(heading), math.sin(heading)
    for pass = 1, 2 do
        local grow = pass == 1 and 2 or 0
        local len, half = size[1] + grow * 2, size[2] / 2 + grow
        local tipX, tipY = x + dirX * grow, y + dirY * grow
        local baseX, baseY = tipX - dirX * len, tipY - dirY * len
        local steps = math.ceil(half * 2 / 1.5)
        for k = 0, steps do
            local off = -half + 2 * half * k / steps
            RouteSegment(view, tipX, tipY, baseX - dirY * off, baseY + dirX * off, 2,
                pass == 1 and ROUTE.CORE or ROUTE.ARROW)
        end
    end
end

-- An area's fill: rows of lines across it, each between the outline's
-- crossings at its height.
local function FillArea(view, path)
    local top, bottom = math.huge, -math.huge
    for _, point in ipairs(path) do top, bottom = math.min(top, point[2]), math.max(bottom, point[2]) end
    for y = top + ROUTE.AREA_ROW / 2, bottom, ROUTE.AREA_ROW do
        local crossings = {}
        for i, a in ipairs(path) do
            local b = path[i % #path + 1]
            if (a[2] <= y) ~= (b[2] <= y) then
                table.insert(crossings, a[1] + (y - a[2]) / (b[2] - a[2]) * (b[1] - a[1]))
            end
        end
        table.sort(crossings)
        for i = 1, #crossings - 1, 2 do
            RouteSegment(view, crossings[i], y, crossings[i + 1], y, ROUTE.AREA_ROW, ROUTE.AREA_FILL)
        end
    end
end

-- An area (a marker's drop area, a walkable-area outline): filled when it
-- has room, and outlined.
local function DrawArea(view, path)
    if #path > 2 then FillArea(view, path) end
    for i, a in ipairs(path) do
        local b = path[i % #path + 1]
        SoftSegment(view, a[1], a[2], b[1], b[2])
    end
end

-- A loop's arrowheads, ROUTE.ARROW_GAP apart, pointing the way the boss walks.
local function DrawLoopArrows(view, path)
    local walked = ROUTE.ARROW_GAP / 2
    for i, a in ipairs(path) do
        local b = path[i % #path + 1]
        local dx, dy = b[1] - a[1], b[2] - a[2]
        local len = math.sqrt(dx * dx + dy * dy)
        if walked + len >= ROUTE.ARROW_GAP and len > 0 then
            local heading = math.atan2(dy, dx)
            local half = ROUTE.ARROW_SIZE[1] / 2
            Arrowhead(view, a[1] + half * math.cos(heading), a[2] + half * math.sin(heading), heading,
                ROUTE.ARROW_SIZE)
            walked = 0
        else
            walked = walked + len
        end
    end
end

-- A line walked back and forth: an arrowhead at each end.
local function DrawEndArrows(view, path)
    if #path < 2 then return end
    for _, tip in ipairs({ { path[1], path[2] }, { path[#path], path[#path - 1] } }) do
        local a, from = tip[1], tip[2]
        Arrowhead(view, a[1], a[2], math.atan2(a[2] - from[2], a[1] - from[1]), ROUTE.END_SIZE)
    end
end

-- A boss's route: the glow, then the core over it (a line walked back and
-- forth doesn't close back to its start), then its arrows.
local function DrawRoute(view, path, open)
    local last = open and #path - 1 or #path
    for _, pass in ipairs({ { 8, ROUTE.GLOW }, { 2.5, ROUTE.CORE } }) do
        for i = 1, last do
            local a, b = path[i], path[i % #path + 1]
            RouteSegment(view, a[1], a[2], b[1], b[2], pass[1], pass[2])
        end
    end
    if open then DrawEndArrows(view, path) else DrawLoopArrows(view, path) end
end

-- Draws `patrols` (all others hidden): boss routes with their arrows, and
-- areas (area = true) filled and outlined.
local function DrawRoutes(view, patrols)
    view.routeUsed, view.areaUsed = 0, 0
    for _, patrol in ipairs(patrols) do
        local path = #patrol >= 4 and RoutePath(view, patrol) or {}
        if patrol.area then DrawArea(view, path) else DrawRoute(view, path, patrol.open) end
    end
    HideFrom(view.routeLines, view.routeUsed + 1)
    for i = view.areaUsed + 1, #view.areaLines do
        view.areaLines[i]:Hide()
        view.areaLines[i].dot:Hide()
    end
end

-- A route point's coordinate to three places, as Data/Maps.lua writes them.
local function Round3(value)
    return math.floor(value * 1000 + 0.5) / 1000
end

-- A route point's handle in map edit mode (dev text, not translated).
local function NewRouteHandle(view)
    local handle = CreateFrame("Button", nil, view.canvas)
    handle:SetSize(ROUTE.HANDLE, ROUTE.HANDLE)
    handle:SetFrameLevel(view.canvas:GetFrameLevel() + 6)
    handle.dot = handle:CreateTexture(nil, "ARTWORK")
    handle.dot:SetAllPoints()
    handle.dot:SetTexture(Theme.roundMask)
    handle.dot:SetVertexColor(1, 0.82, 0, 1)
    handle:SetHighlightTexture(Theme.roundMask)
    handle:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.6)
    handle:RegisterForClicks("RightButtonUp")
    ns.MapEdit:Draggable(handle, view.canvas)
    handle:SetScript("OnClick", function(self)
        local patrol, point = self.patrol, self.index
        local pointCount = #patrol / 2
        if IsShiftKeyDown() and patrol.owner then
            -- A walkable-area outline: the whole shape goes.
            for shapeIndex, shape in ipairs(patrol.owner) do
                if shape == patrol then table.remove(patrol.owner, shapeIndex) break end
            end
        elseif IsShiftKeyDown() and patrol.area then
            return  -- an area stays closed
        elseif IsShiftKeyDown() then
            patrol.open = not patrol.open or nil
        elseif patrol.open and point == pointCount and not IsAltKeyDown() then
            -- Past the line's end: a new last point carrying it on.
            local x, y = PointXY(patrol, point)
            local prevX, prevY = PointXY(patrol, point - 1)
            table.insert(patrol, Round3(math.min(1, math.max(0, x * 1.5 - prevX * 0.5))))
            table.insert(patrol, Round3(math.min(1, math.max(0, y * 1.5 - prevY * 0.5))))
        elseif IsAltKeyDown() then
            if pointCount <= 2 then return end
            table.remove(patrol, point * 2)
            table.remove(patrol, point * 2 - 1)
        else
            -- A new point halfway to the next one.
            local x, y = PointXY(patrol, point)
            local nextX, nextY = PointXY(patrol, point % pointCount + 1)
            table.insert(patrol, point * 2 + 1, Round3((y + nextY) / 2))
            table.insert(patrol, point * 2 + 1, Round3((x + nextX) / 2))
        end
        view.pane:Refresh()
    end)
    handle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText((self.patrol.area and "Area point %d" or "Route point %d"):format(self.index))
        GameTooltip:AddLine("Drag to move. Right-click: add a point after it.", unpack(Theme.tip.text))
        GameTooltip:AddLine("Alt-right-click: remove it.", unpack(Theme.tip.text))
        if self.patrol.owner then
            GameTooltip:AddLine("Shift-right-click: remove this whole outline.", unpack(Theme.tip.text))
        elseif not self.patrol.area then
            GameTooltip:AddLine(self.patrol.open and "Shift-right-click: make the route a loop."
                or "Shift-right-click: make the route a back-and-forth line.", unpack(Theme.tip.text))
        end
        GameTooltip:Show()
    end)
    handle:SetScript("OnLeave", GameTooltip_Hide)
    return handle
end

-- Map edit mode: every route on the level, with its handles.
local function DrawRouteEdit(view, patrols)
    local editing = ns.MapEdit.on and patrols or {}
    local used = 0
    for _, patrol in ipairs(editing) do
        for point = 1, #patrol / 2 do
            used = used + 1
            local handle = Pooled(view.handles, used, NewRouteHandle, view)
            handle.patrol, handle.index = patrol, point
            -- Draggable writes x and y into spot[2] and spot[3].
            handle.spot = setmetatable({}, { __newindex = function(_, field, value)
                if field == 2 then patrol[point * 2 - 1] = value elseif field == 3 then patrol[point * 2] = value end
            end })
            local x, y = PointXY(patrol, point)
            handle:ClearAllPoints()
            handle:SetPoint("CENTER", view.canvas, "TOPLEFT", x * view.canvas:GetWidth(), -y * view.canvas:GetHeight())
            handle:Show()
        end
    end
    HideFrom(view.handles, used + 1)
    DrawRoutes(view, editing)
end

-- The encounters pinned on the floor the map shows (nil while no map shows),
-- which the Encounters list lights; the list redraws when they change.
local function SetFloor(pane, pins)
    local floor, ids = nil, nil
    if pins then
        floor, ids = {}, {}
        for _, pin in ipairs(pins) do
            floor[pin[1]] = pin
            table.insert(ids, pin[1].id)
        end
    end
    local key = ids and table.concat(ids, ",") or nil
    if key == pane.floorKey and (pins == nil) == (pane.floor == nil) then return end
    pane.floor, pane.floorKey = floor, key
    if ns.UI.encounters then ns.UI.encounters:Refresh() end
end

-- For the Encounters list: whether the window's map shows a floor, and the
-- pin { encounter, x, y, display ID or icon } of a boss on it, for its mini
-- pin. Read through ns.UI.overview: each window style builds its own pane,
-- and switching style back puts the earlier one on screen again.
function ns.UI.MapFloorShown()
    local pane = ns.UI.overview
    return pane ~= nil and pane.floor ~= nil and pane.mapView:IsVisible()
end
function ns.UI.MapFloorPin(encounter)
    return ns.UI.MapFloorShown() and ns.UI.overview.floor[encounter] or nil
end
function ns.UI.OnMapFloor(encounter)
    return ns.UI.MapFloorPin(encounter) ~= nil
end

-- The cursor's spot on the map's canvas, 0 to 1 across and down (past
-- those off its edges). Map edit mode (UI/MapEdit.lua) draws with it too.
function ns.UI.CursorOnCanvas(canvas)
    local x, y = GetCursorPosition()
    local scale = canvas:GetEffectiveScale()
    return (x / scale - canvas:GetLeft()) / canvas:GetWidth(), (canvas:GetTop() - y / scale) / canvas:GetHeight()
end

-- The mouse on the map: the wheel zooms in and out about the point under
-- the cursor, and dragging moves around it while zoomed in. Shift-click
-- prints the spot under the cursor, for placing entrances and links in
-- Data/Maps.lua; in map edit mode a click places the palette's pick there,
-- a drag with a drawing tool draws, and right-click lets go of the pick.
local function AddMapMouse(view)
    local pane, canvas = view.pane, view.canvas
    view.clip:EnableMouseWheel(true)
    view.clip:SetScript("OnMouseWheel", function(self, delta)
        local zoom = math.min(ZOOM.MAX, math.max(1, view.zoom * ZOOM.STEP ^ delta))
        if zoom == view.zoom then return end
        local x, y = GetCursorPosition()
        local scale = self:GetEffectiveScale()
        x, y = x / scale, y / scale
        -- The art under the cursor, and where the cursor is in the window.
        local artX = (x - canvas:GetLeft()) / canvas:GetWidth()
        local artY = (canvas:GetTop() - y) / canvas:GetHeight()
        local cursorX, cursorY = x - self:GetLeft(), self:GetTop() - y
        view.zoom = zoom
        local w, h = self:GetWidth() * zoom, self:GetHeight() * zoom
        view.cx = (artX * w - cursorX + self:GetWidth() / 2) / w
        view.cy = (artY * h - cursorY + self:GetHeight() / 2) / h
        ClampCenter(view)
        pane:Refresh()
    end)
    canvas:RegisterForDrag("LeftButton")
    canvas:SetScript("OnDragStart", function(self)
        if ns.MapEdit:StartStroke(self) or view.zoom <= 1 then return end
        local startX, startY = GetCursorPosition()
        local startCX, startCY = view.cx, view.cy
        local scale = self:GetEffectiveScale()
        self:SetScript("OnUpdate", function()
            local x, y = GetCursorPosition()
            view.cx = startCX - (x - startX) / scale / self:GetWidth()
            view.cy = startCY + (y - startY) / scale / self:GetHeight()
            ClampCenter(view)
            PlaceCanvas(view)
        end)
    end)
    canvas:SetScript("OnDragStop", function(self)
        ns.MapEdit:EndStroke()
        self:SetScript("OnUpdate", nil)
        view.dragged = true  -- the mouse up that ends a drag isn't a click
    end)

    canvas:EnableMouse(true)
    canvas:SetScript("OnMouseDown", function() view.dragged = nil end)
    canvas:SetScript("OnMouseUp", function(self, button)
        if view.dragged then view.dragged = nil return end
        if not pane.instance then return end
        if button == "RightButton" and not ns.MapEdit.on then return end -- that's Back
        if button == "RightButton" and ns.MapEdit:Cancel() then return end -- edit mode: lets go of the pick
        local x, y = ns.UI.CursorOnCanvas(self)
        if ns.MapEdit:Place(x, y) or not IsShiftKeyDown() then return end
        local map = ns.Data:Map(pane.instance.id)
        local current = math.min(#map, pane.levels[pane.instance.id] or map.start or 1)
        print(CHAT_PREFIX .. ("%s, level %d (%s) at %.3f, %.3f"):format(
            pane.instance.name, current, LevelName(map[current], current), x, y))
    end)
end

-- A frame to draw a layout map level on (ns.UI.DrawMapLevel): its art,
-- pins and marks go on view.canvas, cut off at the edges of view.clip, with
-- their pools empty. `pane` is what its level links change: a table with
-- .instance, .levels (the level shown, per instance ID) and :Refresh().
-- The caller places the frames and sets what a click on a boss or quest
-- does: view.openBoss(encounter) and view.openQuest(quest). The window's
-- map (CreateMapView) and the one over the game's world map
-- (UI/WorldMapOverlay.lua) are both made here.
function ns.UI.CreateMapLayer(parent, pane)
    local view = CreateFrame("Frame", nil, parent)
    view.pane = pane
    view.clip = CreateFrame("Frame", nil, view)
    view.clip:SetClipsChildren(true)
    view.canvas = CreateFrame("Frame", nil, view.clip)
    view.canvas:SetClipsChildren(true)  -- the tiles' right and bottom edges are padding
    view.tiles = NewTiles(view.canvas)
    view.pins = {}
    view.entrances, view.links, view.locks, view.markers = {}, {}, {}, {}
    view.routeLines, view.handles = {}, {}
    view.areaLines = {}  -- each with its .dot
    view.drawRoutes = function(patrols) DrawRoutes(view, patrols) end  -- for the zone-wide quests' outlines
    return view
end

-- Makes the window's map view, hidden until a map opens.
local function CreateMapView(pane)
    local view = ns.UI.CreateMapLayer(pane, pane)
    view:Hide()
    view.tabs = {}
    view.zoom, view.cx, view.cy = 1, 0.5, 0.5
    view.missing = Theme:Text(view, Theme.font.small)
    view.missing:SetText(L["This map isn't in your game's files."])
    view.credit = Theme:Text(view, Theme.font.hint)  -- who drew a map that isn't Blizzard's
    view.credit:SetJustifyH("CENTER")
    view.zoomHint = Theme:Text(view, Theme.font.hint)
    -- "Open the world map", under the map at the left while it shows the
    -- instance the player is in: the way back to the game's map from here
    -- (UI/MainFrame.lua clicks the game's own map button for it).
    view.worldMap = Theme:Pill(view)
    view.worldMap:SetLabel(L["Open the world map"])
    view.worldMap:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:AddLine(L["World map"])
        -- Map in dungeons = Game: the world map has no NeedRoll map to describe.
        if ns.db.dungeonMap == "game" then return GameTooltip:Show() end
        local r, g, b = unpack(Theme.tip.text)
        GameTooltip:AddLine(L["In dungeons the game's map shows NeedRoll's map over it: click a boss or quest to open it here, right-click for the zone. Map in dungeons in Settings (top right of the window) turns that off."], r, g, b, true)
        GameTooltip:Show()
    end)
    view.worldMap:HookScript("OnLeave", GameTooltip_Hide)
    view.worldMap:SetScript("OnClick", function() ns.UI:OpenWorldMap() end)
    -- A boss's page or a quest's, Back returning to the map.
    view.openBoss = function(encounter) OpenBossPage(encounter, L["the map"]) end
    view.openQuest = OpenQuestPage
    AddMapMouse(view)
    view:SetScript("OnHide", function()
        SetFloor(pane, nil)
        -- The boss the Map button lit stays lit only until the map closes
        -- (the window closing too: it shows its pins again as they were).
        view.focus, view.focusQuest, view.focusSpot = nil, nil, nil
        for _, pin in ipairs(view.pins) do
            pin.pulse:Stop()
            pin.glow:Hide()
        end
        view.wingKey = nil  -- opening the map again counts as coming to the floor
    end)
    return view
end

-- A boss's pin: hover for its name, click for its loot (view.openBoss).
local function NewBossPin(view)
    local pin = CreateFrame("Button", nil, view.canvas)
    pin:SetSize(PIN_SIZE, PIN_SIZE)
    pin:SetFrameLevel(view.canvas:GetFrameLevel() + 5)
    AddPortrait(pin, "BACKGROUND")
    pin.portrait:SetSize(PIN_PORTRAIT, PIN_PORTRAIT)
    pin:SetNormalTexture(EJ_TEXTURES)
    pin:GetNormalTexture():SetTexCoord(unpack(PIN_RING))
    pin:SetPushedTexture(EJ_TEXTURES)
    pin:GetPushedTexture():SetTexCoord(0.77734375, 0.89843750, 0.26953125, 0.32910156)
    pin:SetHighlightTexture(EJ_TEXTURES)
    pin:GetHighlightTexture():SetTexCoord(0.68945313, 0.81054688, 0.33300781, 0.39257813)
    pin.badgeBack = pin:CreateTexture(nil, "OVERLAY", nil, 1)
    pin.badgeBack:SetSize(PATROL_BADGE, PATROL_BADGE)
    pin.badgeBack:SetPoint("CENTER", pin, "BOTTOMRIGHT", -6, 6)
    pin.badgeBack:SetTexture(Theme.roundMask)
    pin.badgeBack:SetVertexColor(0.1, 0.07, 0.02, 1)
    pin.badge = pin:CreateTexture(nil, "OVERLAY", nil, 2)
    pin.badge:SetSize(PATROL_BADGE - 3, PATROL_BADGE - 3)
    pin.badge:SetPoint("CENTER", pin.badgeBack)
    pin.badge:SetTexture(PATROL_BADGE_TEXTURE)
    -- The glow on the boss a boss page's Map button opened the map for:
    -- the artifact whirl tinted red (Mike's pick), turning slowly under the
    -- pin. Two layers, as one ADD layer is too faint; the purple art goes
    -- grey first so the red comes out clean.
    pin.glow = CreateFrame("Frame", nil, view.canvas)
    pin.glow:SetSize(1, 1)
    pin.glow:SetPoint("CENTER", pin)
    pin.glow:Hide()
    pin.pulse = pin.glow:CreateAnimationGroup()
    pin.pulse:SetLooping("REPEAT")
    for layer = 1, 2 do
        local whirl = pin.glow:CreateTexture(nil, "ARTWORK", nil, layer)
        whirl:SetAtlas("ArtifactsFX-Whirls-Purple")
        whirl:SetBlendMode("ADD")
        whirl:SetSize(PIN_SIZE * 1.3, PIN_SIZE * 1.3)
        whirl:SetDesaturated(true)
        whirl:SetVertexColor(1, 0.2, 0.15, 1)
        whirl:SetPoint("CENTER")
        -- Rotation only turns textures, so each spin targets its layer.
        local spin = pin.pulse:CreateAnimation("Rotation")
        spin:SetTarget(whirl)
        spin:SetDegrees(-360)
        spin:SetDuration(6)
    end
    pin:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.encounter.name)
        if self.patrol then
            GameTooltip:AddLine(L["Patrols %s"]:format(view.floorName), 1, 0.82, 0)
            if not ns.MapEdit.on then DrawRoutes(view, { self.patrol }) end
        end
        if not self.encounter.unit then GameTooltip:AddLine(L["Click to see its loot"], unpack(Theme.tip.text)) end
        GameTooltip:Show()
    end)
    pin:SetScript("OnLeave", function()
        GameTooltip:Hide()
        if not ns.MapEdit.on then DrawRoutes(view, {}) end
    end)
    ns.MapEdit:Draggable(pin, view.canvas)
    pin:HookScript("OnMouseDown", function(self, button) ns.MapEdit:Press(self, button) end)
    pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    pin:SetScript("OnClick", function(self, button)
        if ns.MapEdit.on then return ns.MapEdit:Click(self, button) end
        if button ~= "LeftButton" or self.encounter.unit then return end
        GameTooltip:Hide()
        view.openBoss(self.encounter)
    end)
    return pin
end

-- Draws boss pins, { encounter, x, y, creature display ID } each. Bosses
-- met at the same spot (the Edge of Madness in Zul'Gurub) stand side by
-- side. Keeps where each is (view.pinAt, for markers put on them) and their
-- routes (view.patrols, drawn with the markers' areas).
local function DrawPins(view, pins, scale)
    view.pinAt, view.patrols = {}, {}
    local at, count = {}, {}
    for i, spot in ipairs(pins) do
        local key = math.floor(spot[2] * 50) .. ":" .. math.floor(spot[3] * 50)
        count[key] = (count[key] or 0) + 1
        at[i] = { key, count[key] }
    end
    for i, spot in ipairs(pins) do
        local pin = MapWidget(view, view.pins, i, NewBossPin)
        pin.encounter = spot[1]
        pin.spot = spot[5]
        pin.patrol = spot[5] and spot[5].patrol
        pin.badge:SetShown(pin.patrol ~= nil)
        pin.badgeBack:SetShown(pin.patrol ~= nil)
        local shift = ns.MapEdit.on and 0 or (at[i][2] - (count[at[i][1]] + 1) / 2) * PIN_SIZE * 0.8
        pin:ClearAllPoints()
        PlaceOnArt(view, pin, spot[2], spot[3], scale, shift)
        view.pinAt[spot[1].id] = { spot[2] * ART.W * scale + shift, -spot[3] * ART.H * scale, pin }
        local lit = view.focus ~= nil and spot[1].id == view.focus
        pin.glow:SetShown(lit)
        if not lit then
            pin.pulse:Stop()
        elseif not pin.pulse:IsPlaying() then
            pin.pulse:Play()
        end
        pin:SetFrameLevel(view.canvas:GetFrameLevel() + (lit and 6 or 5))
        pin.glow:SetFrameLevel(pin:GetFrameLevel() - 1)
        SetPinFace(pin, spot[4])
        pin:Show()
        if pin.patrol then table.insert(view.patrols, pin.patrol) end
    end
    for i = #pins + 1, #view.pins do
        view.pins[i]:Hide()
        view.pins[i].glow:Hide()
    end
end

-- A mark on the map with a tooltip: the instance's entrance (the same
-- swirl as by the Instances header), or a lock on a door that needs a
-- key or lockpicking.
local function NewMapMark(view)
    local mark = CreateFrame("Frame", nil, view.canvas)
    mark:EnableMouse(true)
    mark:SetFrameLevel(view.canvas:GetFrameLevel() + 3)
    mark.icon = mark:CreateTexture(nil, "ARTWORK")
    mark.icon:SetPoint("CENTER")
    mark:SetScript("OnEnter", function(self) ShowTooltip(self, "ANCHOR_RIGHT", self.tip) end)
    mark:SetScript("OnLeave", GameTooltip_Hide)
    ns.MapEdit:Draggable(mark, view.canvas)
    mark:SetScript("OnMouseUp", function(self, button)
        if ns.MapEdit.on then ns.MapEdit:Click(self, button) end
    end)
    return mark
end

-- Copies of a marker's icon (art and color set by the caller), nudged out
-- `reaches` px in eight directions per ring, `alphas` strong: a soft edge.
local function IconRings(owner, layer, anchor, reaches, alphas)
    local edges = {}
    for ring, reach in ipairs(reaches) do
        for n = 0, 7 do
            local angle = (n + ring / 2) / 8 * 2 * math.pi
            local edge = owner:CreateTexture(nil, layer)
            edge:SetPoint("CENTER", anchor, "CENTER", reach * math.cos(angle), reach * math.sin(angle))
            edge.alpha = alphas[ring]
            table.insert(edges, edge)
        end
    end
    return edges
end

-- A quest marker's tooltip: its quest, or each quest on a boss's marker,
-- and what a click does (dev edit's own hints in map edit mode).
local function ShowMarkerTooltip(mark)
    local quest = mark.quest
    GameTooltip:SetOwner(mark, "ANCHOR_RIGHT")
    if mark.quests then
        -- Several quests on one boss.
        GameTooltip:SetText(L["Related Quests"])
        for _, related in ipairs(mark.quests) do GameTooltip:AddLine(related.name, 1, 0.82, 0) end
        if ns.Modules:IsOn("QUESTS") then GameTooltip:AddLine(L["Click to see them all"], unpack(Theme.tip.text)) end
        GameTooltip:Show()
        return
    end
    if mark.spot[4] == "escort" then
        GameTooltip:SetText(L["Escort"])
        if quest then GameTooltip:AddLine(quest.name, 1, 0.82, 0) end
    elseif quest then
        GameTooltip:SetText(quest.name, 1, 0.82, 0)
    elseif ns.MapEdit.on then
        GameTooltip:SetText(mark.spot[4] .. ": no quest yet")
    else
        return
    end
    if ns.MapEdit.on then
        GameTooltip:AddLine("Right-click: its quest  ·  shift-right-click: its icon", unpack(Theme.tip.text))
        GameTooltip:AddLine("Click, then a boss: put it on the boss  ·  then the map: take it off",
            unpack(Theme.tip.text))
    elseif quest and ns.Modules:IsOn("QUESTS") then
        GameTooltip:AddLine(L["Click to open this quest"], unpack(Theme.tip.text))
    end
    GameTooltip:Show()
end

-- An icon on the map with a soft dark edge and a gold glow that pulses
-- while lit (mark:SetGlow); PaintMarker gives it its icon.
local function NewGlowMark(view, size)
    local mark = CreateFrame("Frame", nil, view.canvas)
    mark:EnableMouse(true)
    mark:SetSize(size, size)
    mark:SetFrameLevel(view.canvas:GetFrameLevel() + 5)
    mark.icon = mark:CreateTexture(nil, "ARTWORK")
    mark.icon:SetPoint("CENTER")
    -- The icon again in black on three rings, fainter each ring out: a soft
    -- dark edge so it reads on any map art.
    mark.outline = IconRings(mark, "BORDER", mark, { 1.5, 3, 4.5 }, { 0.35, 0.16, 0.07 })
    -- In gold on two rings, on a frame that pulses while a marker for the
    -- same quest is hovered.
    mark.glow = CreateFrame("Frame", nil, mark)
    mark.glow:SetAllPoints()
    mark.glow.edges = IconRings(mark.glow, "BACKGROUND", mark, { 2, 4 }, { 0.9, 0.45 })
    for _, edge in ipairs(mark.glow.edges) do edge:SetBlendMode("ADD") end
    mark.glow.pulse = mark.glow:CreateAnimationGroup()
    mark.glow.pulse:SetLooping("BOUNCE")
    local fade = mark.glow.pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.25)
    fade:SetDuration(0.6)
    fade:SetSmoothing("IN_OUT")
    mark.glow:Hide()
    function mark:SetGlow(on)
        -- Under the marker's own icon.
        self.glow:SetFrameLevel(math.max(0, self:GetFrameLevel() - 1))
        self.glow:SetShown(on)
        if on then self.glow.pulse:Play() else self.glow.pulse:Stop() end
    end
    return mark
end

-- A quest marker: where a quest's item drops, a mob to kill, a vendor,
-- the turn-in or an escort is. Its tooltip names the quest, and a click
-- opens it (view.openQuest). In dev edit, right-click picks the quest (UI/MapEdit.lua).
local function NewQuestMarker(view)
    local mark = NewGlowMark(view, MARKER_ICON)
    -- Whether the marker stands for `quest` (one of the quests on a boss too).
    function mark:HasQuest(quest)
        for _, own in ipairs(self.quests or { self.quest }) do
            if own == quest then return true end
        end
        return false
    end
    -- The other markers on show for any of this one's quests glow.
    function mark:GlowMatches(on)
        for _, other in ipairs(view.markers) do
            if other ~= self and other:IsShown() then
                local shared = false
                for _, quest in ipairs(self.quests or { self.quest }) do
                    if other:HasQuest(quest) then shared = true end
                end
                other:SetGlow(on and shared)
            end
        end
    end
    mark.isMarker = true
    mark:SetScript("OnEnter", function(self)
        self:GlowMatches(true)
        if self.spot.area and not ns.MapEdit.on then
            self.spot.area.area = true
            DrawRoutes(view, { self.spot.area })
        end
        ShowMarkerTooltip(self)
    end)
    mark:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        self:GlowMatches(false)
        if self.spot.area and not ns.MapEdit.on then DrawRoutes(view, {}) end
    end)
    ns.MapEdit:Draggable(mark, view.canvas)
    mark:SetScript("OnMouseDown", function(self, button) ns.MapEdit:Press(self, button) end)
    mark:SetScript("OnMouseUp", function(self, button)
        if ns.MapEdit.on then return ns.MapEdit:Click(self, button) end
        if button ~= "LeftButton" or not self:IsMouseOver() then return end
        if self.quests and self.pin then
            -- The boss's page lists them all.
            GameTooltip:Hide()
            self.pin:GetScript("OnClick")(self.pin, "LeftButton")
        elseif self.quest then
            GameTooltip:Hide()
            view.openQuest(self.quest)
        end
    end)
    return mark
end

-- A marker's icon at `size`, with its dark outline and gold glow.
local function PaintMarker(mark, icon, size)
    Theme:FitAtlas(mark.icon, icon, size)
    for _, edge in ipairs(mark.outline) do
        Theme:FitAtlas(edge, icon, size)
        edge:SetVertexColor(0, 0, 0, edge.alpha)
    end
    for _, edge in ipairs(mark.glow.edges) do
        Theme:FitAtlas(edge, icon, size)
        edge:SetDesaturated(true)
        edge:SetVertexColor(1, 0.82, 0, edge.alpha)  -- gold
    end
end

-- The spot the map was opened to show (view.focusSpot = { level, x, y,
-- name }: an NPC standing inside, from the Professions Overview): the
-- game's gold map pin on it, glowing, their name in its tooltip. On its
-- level only, until the map closes.
local function DrawFocusSpot(view, current, scale)
    local spot = view.focusSpot
    if not (spot and spot[1] == current) then
        if view.focusMark then view.focusMark:Hide() end
        return
    end
    local mark = view.focusMark
    if not mark then
        mark = NewGlowMark(view, FOCUS_PIN)
        PaintMarker(mark, "Waypoint-MapPin-Untracked", FOCUS_PIN)
        mark:SetScript("OnEnter", function(self) ShowTooltip(self, "ANCHOR_RIGHT", self.name) end)
        mark:SetScript("OnLeave", GameTooltip_Hide)
        view.focusMark = mark
    end
    mark.name = spot.name
    mark:ClearAllPoints()
    PlaceOnArt(view, mark, spot[2], spot[3], scale)
    -- Above everything else on the map, as the quest markers.
    mark:SetFrameLevel(view.canvas:GetFrameLevel() + 30)
    mark:SetGlow(true)
    mark:Show()
end

-- Shows the map's `level` (a level tab or a link to another level clicked).
local function ShowLevel(view, level)
    view.pane.levels[view.pane.instance.id] = level
    view.pane:Refresh()
end

-- A spot that leads to another level: a green arrow like the game's own
-- map links; clicking it shows that level.
local function NewLevelLink(view)
    local arrow = CreateFrame("Button", nil, view.canvas)
    arrow:SetSize(LINK_ICON, LINK_ICON)
    arrow:SetFrameLevel(view.canvas:GetFrameLevel() + 4)
    arrow.icon = arrow:CreateTexture(nil, "ARTWORK")
    arrow.icon:SetPoint("CENTER")
    arrow.glow = arrow:CreateTexture(nil, "HIGHLIGHT")
    arrow.glow:SetPoint("CENTER")
    arrow.glow:SetBlendMode("ADD")
    arrow.glow:SetAlpha(0.5)
    arrow:SetScript("OnEnter", function(self)
        ShowTooltip(self, "ANCHOR_RIGHT", self.name, L["Click to go to this level"])
    end)
    arrow:SetScript("OnLeave", GameTooltip_Hide)
    arrow.isLink = true
    arrow:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    ns.MapEdit:Draggable(arrow, view.canvas)
    arrow:SetScript("OnClick", function(self, button)
        if ns.MapEdit.on then return ns.MapEdit:Click(self, button) end
        if button ~= "LeftButton" then return end -- right-click is Back
        GameTooltip:Hide()
        ShowLevel(view, self.level)
    end)
    return arrow
end

-- Draws a mark from `pool` on each of `spots` on level `current`, fill(mark, spot) each.
local function DrawMarks(view, pool, spots, current, scale, fill)
    local count = 0
    for _, spot in ipairs(spots) do
        if spot[1] == current then
            count = count + 1
            local mark = MapWidget(view, pool, count, NewMapMark)
            mark.spot = spot
            fill(mark, spot)
            mark:ClearAllPoints()
            PlaceOnArt(view, mark, spot[2], spot[3], scale)
            mark:Show()
        end
    end
    HideFrom(pool, count + 1)
end

-- The quest a marker stands for: its own, or that of the marker it's put on.
local function MarkerQuest(instance, spot, paired)
    return ns.Data:DungeonQuest(instance.id, spot[5] or paired[spot])
end

-- The level's quest markers. Ones for one side's quests show only while
-- the Quests switch is on that side (all of them in dev edit, the other
-- side's faded). Markers put on the same boss: the first stands for them
-- all, its tooltip naming each quest and a click opening the boss's page
-- (Related Quests). Dev edit fans them out, so each can be picked.
local function DrawQuestMarkers(view, instance, current, scale, spots, paired)
    local side = ns.UI.QuestSide()
    local function Visible(spot, quest)
        local otherSide = quest and quest.side and quest.side ~= side
        return spot[1] == current and ns.Data.markerIcons[spot[4]] and (not otherSide or ns.MapEdit.on)
            and ns.UI.MarkerShows(quest, view.focusQuest, spot[5] or paired[spot], spot[4], instance), otherSide
    end
    -- What a marker is put on: a boss's pin (boss = its key), or the
    -- marker at its own spot (on = true).
    local function Host(spot)
        if spot.boss then return view.pinAt and view.pinAt[spot.boss] and "boss:" .. spot.boss end
        if spot.on then return ("on:%s:%s"):format(spot[2], spot[3]) end
    end
    local questsOnHost, nth = {}, {}
    for _, spot in ipairs(spots) do
        local quest = MarkerQuest(instance, spot, paired)
        local host = Visible(spot, quest) and Host(spot)
        if host then
            questsOnHost[host] = questsOnHost[host] or {}
            if quest then table.insert(questsOnHost[host], quest) end
        end
    end
    local count = 0
    for _, spot in ipairs(spots) do
        local quest = MarkerQuest(instance, spot, paired)
        local visible, otherSide = Visible(spot, quest)
        local host = visible and Host(spot)
        local pin = host and spot.boss and view.pinAt[spot.boss]
        if host then nth[host] = (nth[host] or 0) + 1 end
        local n = host and nth[host] or 1
        if visible and (n == 1 or ns.MapEdit.on) then
            count = count + 1
            local mark = MapWidget(view, view.markers, count, NewQuestMarker)
            mark.spot = spot
            mark.quest = quest
            local all = host and questsOnHost[host]
            mark.quests = all and #all > 1 and not ns.MapEdit.on and all or nil
            mark.pin = pin and pin[3]
            mark:SetAlpha(otherSide and 0.4 or 1)
            -- One put on a boss sits smaller on the pin's upper right,
            -- wherever the pin is; one put on a marker, smaller still on
            -- that marker's.
            PaintMarker(mark, ns.Data.markerIcons[spot[4]],
                pin and MARKER_ICON * 0.8 or host and MARKER_ICON * 0.7 or MARKER_ICON)
            -- Lit while the map is opened to show this quest's spot.
            mark:SetGlow(view.focusQuest ~= nil and quest == view.focusQuest)
            mark:ClearAllPoints()
            if pin then
                mark:SetPoint("CENTER", view.canvas, "TOPLEFT", pin[1] + PIN_SIZE * 0.28 - (n - 1) * 12,
                    pin[2] + PIN_SIZE * 0.28)
            elseif host then
                mark:SetPoint("CENTER", view.canvas, "TOPLEFT",
                    spot[2] * ART.W * scale + MARKER_ICON * 0.45 - (n - 1) * 10,
                    -spot[3] * ART.H * scale + MARKER_ICON * 0.45)
            else
                PlaceOnArt(view, mark, spot[2], spot[3], scale)
            end
            -- Above everything else on the map: pins (a lit one too),
            -- their glows and badges, swirls and links.
            mark:SetFrameLevel(view.canvas:GetFrameLevel() + 30)
            mark:Show()
        end
    end
    HideFrom(view.markers, count + 1)
end

-- Draws the level's entrances, locked doors, quest markers, zone-wide quests,
-- routes and areas, and links to other levels (none while `shown` is false).
local function DrawSpots(view, instance, map, current, scale, shown)
    local edit = ns.MapEdit:Spots(instance.id, map)
    local atlas = instance.category == "RAID" and "Raid" or "Dungeon"
    DrawMarks(view, view.entrances, shown and (edit and edit.entrances or map.entrances) or {}, current, scale,
        function(mark, spot)
            local raid = spot[4] == "raid"  -- a raid's entrance inside a dungeon
            mark.tip = raid and L["Raid entrance"] or L["Entrance"]
            Theme:FitAtlas(mark.icon, raid and "Raid" or atlas, ENTRANCE_ICON)
            mark:SetSize(ENTRANCE_ICON, ENTRANCE_ICON)
        end)
    DrawMarks(view, view.locks, shown and (edit and edit.locks or map.locks) or {}, current, scale,
        function(mark)
            mark.tip = L["Locked: needs a key or lockpicking"]
            mark.icon:SetTexture(LOCK_TEXTURE)
            mark.icon:SetSize(LOCK_ICON, LOCK_ICON)
            mark:SetSize(LOCK_ICON, LOCK_ICON)
        end)
    local spots = shown and (edit and edit.markers or map.markers) or {}
    local paired = ns.UI.PairedQuests(spots)
    DrawQuestMarkers(view, instance, current, scale, spots, paired)
    DrawZoneQuests(view, instance, current)
    -- The boss routes, this level's marker areas (a marker's area = { x1,
    -- y1, ... }, lit while it's hovered) and, in map edit mode, its
    -- walkable-area outlines (edited in a copy of the data's).
    local routes = {}
    for _, patrol in ipairs(view.patrols or {}) do table.insert(routes, patrol) end
    if ns.MapEdit.on and shown then
        local outlines = ns.MapEdit:Outlines(instance.id, true)
        for _, shape in ipairs(outlines[current] or {}) do
            shape.area, shape.owner = true, outlines[current]
            table.insert(routes, shape)
        end
    end
    for _, spot in ipairs(spots) do
        if spot.area and spot[1] == current
            and ns.UI.MarkerShows(MarkerQuest(instance, spot, paired), view.focusQuest, spot[5] or paired[spot],
                spot[4], instance) then
            spot.area.area = true
            table.insert(routes, spot.area)
        end
    end
    DrawRouteEdit(view, routes)
    -- The world map overlay leaves floors to the game's floor dropdown (view.noLevelLinks).
    local links = shown and not view.noLevelLinks and (edit and edit.links[current] or map[current].links) or {}
    for i, spot in ipairs(links) do
        local arrow = MapWidget(view, view.links, i, NewLevelLink)
        arrow.spot = spot
        arrow.level = spot[1]
        arrow.name = map[spot[1]] and LevelName(map[spot[1]], spot[1]) or ""
        -- The icon the link names (Data/Maps.lua), else down to a later
        -- level and up to an earlier one.
        local icon = LINK_ICONS[spot[4]] or (spot[1] > current and "poi-door-arrow-down" or "poi-door-arrow-up")
        Theme:FitAtlas(arrow.icon, icon, LINK_ICON)
        Theme:FitAtlas(arrow.glow, icon, LINK_ICON)
        arrow:ClearAllPoints()
        PlaceOnArt(view, arrow, spot[2], spot[3], scale)
        arrow:Show()
    end
    HideFrom(view.links, #links + 1)
end

-- A level's tab: a text tab chip (UI/RecipeBand.lua), the shown floor gold
-- with an underline fading to the word's ends, a faint one on hover.
local function NewLevelTab(view)
    local tab = ns.RecipeBand.Chip(view)
    tab:SetScript("OnClick", function(self) ShowLevel(view, self.index) end)
    return tab
end

-- Level tabs on balanced, centred lines, as the recipe chips. Returns their height.
local function DrawLevelTabs(view, map, current, width)
    local tabs = {}
    for i = 1, #map > 1 and #map or 0 do
        local tab = Pooled(view.tabs, i, NewLevelTab, view)
        tab.index = i
        tab:SetLabel(Theme:Label(LevelName(map[i], i)))
        tab.active = i == current
        tab:Show()
        tabs[i] = tab
    end
    HideFrom(view.tabs, #tabs + 1)
    local top = #tabs > 0 and ns.RecipeBand.PlaceLines(view, tabs, width, 0) or 0
    for _, tab in ipairs(tabs) do tab:Paint(tab.active) end
    return top
end

-- A dungeon made of wings (Stratholme) opens the wing most of the floor's
-- bosses belong to, each time the map comes to a floor.
local function OpenFloorsWing(view, instance, current, pins)
    local floorKey = instance.id .. ":" .. current
    if view.wingKey == floorKey then return end
    view.wingKey = floorKey
    local count, best = {}, nil
    for _, pin in ipairs(pins) do
        local wing = pin[1].wing
        if wing then
            count[wing] = (count[wing] or 0) + 1
            if not best or count[wing] > count[best] then best = wing end
        end
    end
    if best and ns.UI.encounters then ns.UI.encounters:OpenWing(best) end
end

-- The scale that fits a layout map's art in `width` x `height` px.
function ns.UI.ArtScale(width, height)
    return math.min(width / ART.W, height / ART.H)
end

-- Re-sizes the art on a view from ns.UI.CreateMapLayer to `scale`, leaving
-- pins and marks where they are: cheap enough for every frame of the world
-- map's eased zoom, with a full DrawMapLevel once it settles.
function ns.UI.PlaceMapArt(view, scale)
    PlaceTiles(view.tiles, ART.TILE * scale, view.canvas, 0, 0)
end

-- Draws level `current` of the instance's layout map on a view from
-- ns.UI.CreateMapLayer, its art `scale` times its size from the canvas's top
-- left corner: the art, boss pins, entrances, locked doors, quest markers,
-- zone-wide quests, routes, areas and links to other levels. Returns whether
-- the game has the level's art, and the pins drawn.
function ns.UI.DrawMapLevel(view, instance, current, scale)
    local map = ns.Data:Map(instance.id)
    ns.UI.PlaceMapArt(view, scale)
    local found = LoadTiles(view.tiles, map[current])
    view.floorName = LevelName(map[current], current)
    local pins = found and BossPins(instance, map, current) or {}
    DrawPins(view, pins, scale)
    DrawSpots(view, instance, map, current, scale, found)
    DrawFocusSpot(view, current, scale)
    return found, pins
end

-- Draws the instance's layout map from y down, on the level last shown.
local function DrawMap(pane, instance, y)
    local view = pane.mapView
    local map = ns.Data:Map(instance.id)
    local width = PageWidth(pane)
    local current = math.min(#map, pane.levels[instance.id] or map.start or 1)
    view:ClearAllPoints()
    view:SetPoint("TOPLEFT", Size.pad, -y)
    view:SetSize(width, pane:GetHeight() - y - Size.pad)
    view:Show()
    local top = DrawLevelTabs(view, map, current, width)

    -- The art, as large as fits over the zoom hint's line, and the credit's
    -- above it when the map has one (both on one line would collide once
    -- the hint shows the zoom).
    local worldMap = ns.UI.PlayerFloor(instance) == instance
    local below = (map.credit and 36 or 20) + (worldMap and 8 or 0)
    local fit = ns.UI.ArtScale(width, view:GetHeight() - top - below)
    -- Another map or level starts zoomed out.
    local key = instance.id .. ":" .. current
    if view.zoomKey ~= key then
        view.zoomKey, view.zoom, view.cx, view.cy = key, 1, 0.5, 0.5
    end
    local clip = view.clip
    clip:ClearAllPoints()
    clip:SetPoint("TOP", view, "TOP", 0, -top)
    clip:SetSize(ART.W * fit, ART.H * fit)
    ClampCenter(view)
    PlaceCanvas(view)
    local found, pins = ns.UI.DrawMapLevel(view, instance, current, fit * view.zoom)
    clip:SetShown(found)
    local zoomPercent = math.floor(view.zoom * 100 + 0.5)
    view.zoomHint:SetText(view.zoom > 1 and L["%d%%  ·  Scroll to zoom, drag to move"]:format(zoomPercent)
        or L["Scroll to zoom"])
    view.zoomHint:ClearAllPoints()
    view.zoomHint:SetPoint("TOPRIGHT", clip, "BOTTOMRIGHT", 0, map.credit and -22 or -6)
    view.zoomHint:SetShown(found)
    view.worldMap:ClearAllPoints()
    view.worldMap:SetPoint("TOPLEFT", clip, "BOTTOMLEFT", 0, map.credit and -20 or -4)
    view.worldMap:SetShown(worldMap and found)
    SetFloor(pane, pins)
    if ns.MapEdit.on then ns.MapEdit:ShowBosses(instance, map, current) end
    OpenFloorsWing(view, instance, current, pins)
    view.credit:ClearAllPoints()
    view.credit:SetPoint("TOP", clip, "BOTTOM", 0, -6)
    view.credit:SetText(map.credit or "")
    view.credit:SetShown(map.credit ~= nil and found)
    view.missing:ClearAllPoints()
    view.missing:SetPoint("TOPLEFT", 4, -top - 4)
    view.missing:SetShown(not found)
end

-- A boss named on the page: shown on the instance's map, or its page if unpinned.
local function ShowNamedBoss(instance, bossID)
    for _, encounter in ipairs(instance and instance.encounters or {}) do
        if encounter.id == bossID then
            if ns.UI:ShowBossOnMap(encounter) == false then OpenBossPage(encounter) end
            return
        end
    end
end

-- A raid's attunement and an instance's item chains (a dungeon's key, Aqual
-- Quintessence) on its Overview: a section each under a heading that opens
-- and shuts it, its note and its steps (filled in further down).
local Attunement = {}

-- The links in a page's text (the text builders below write them): where
-- they pin, what a click does and their tooltips.
local PageLink = {}

-- The spot on the world map a needroll: link pins and the name NeedRoll's
-- pin there shows: an NPC's spot (named by the link's text, `shownText`)
-- or a dungeon's entrance (named by the dungeon). Nil for other links.
function PageLink.PlaceSpot(link, shownText)
    local npc, questID = link:match("^needroll:npc:(%-?%d+):?(%d*)")
    if npc then
        return ns.Data:NpcSpot(tonumber(npc), tonumber(questID)), shownText and Theme:PlainText(shownText)
    end
    local inside = link:match("^needroll:inside:(.+)")
    if not inside then return nil end
    local dungeon = ns.Data:Get(inside)
    return ns.Data:Entrance(inside), dungeon and dungeon.name
end

-- PageLink.PlaceSpot for any link in the page's text: an item's is where it comes from.
function PageLink.Spot(pane, link, shownText)
    local itemID = tonumber(link:match("^item:(%d+)") or "")
    if itemID then
        link, shownText = ItemPlace(pane.quest, itemID, pane.instance and pane.instance.id)
        if not link then return nil end
    end
    return PageLink.PlaceSpot(link, shownText)
end

-- Runs `show` (a boss or the map of the page's dungeon) on the Dungeons
-- tab, which shows the maps: from the Classes tab's quest page
-- (pane.openInDungeon) that dungeon opens there first.
function PageLink.InDungeon(pane, show)
    if not pane.openInDungeon then return show() end
    if pane.instance then pane.openInDungeon(pane.instance, show) end
end

-- A click on a link in the page's text, shown as `shownText`.
function PageLink.OnClick(pane, link, shownText)
    local spot, name = PageLink.PlaceSpot(link, shownText)
    if spot then return ShowOnMap(spot, name) end
    local shownQuest = pane.quest
    -- Somewhere in this dungeon: the quest's drop area or marker when it
    -- has one, else the floor the map opens on.
    if link == "needroll:dungeonmap" then
        return PageLink.InDungeon(pane, function()
            if shownQuest and ns.UI:ShowQuestOnMap(shownQuest) ~= false then return end
            ns.UI:ShowInstanceMap()
        end)
    end
    -- A drop area: the map on its floor, its marker lit.
    if link:match("^needroll:dropspot:%d+") then
        if shownQuest then PageLink.InDungeon(pane, function() ns.UI:ShowQuestOnMap(shownQuest) end) end
        return
    end
    local bossID = link:match("^needroll:boss:(.+)")
    if bossID then
        local instance = pane.instance
        return PageLink.InDungeon(pane, function() ShowNamedBoss(instance, bossID) end)
    end
    -- An attunement's or item chain's step (Attunement.QuestLink) opens its page.
    if link:match("^needroll:quest:") then
        local quest = Attunement.LinkedQuest(link)
        if quest then Chain.OpenPage(pane, quest) end
        return
    end
    -- A step of the quest's chain; "Show all" its every step.
    local chainStep = tonumber(link:match("^needroll:chainquest:(%d+)") or "")
    if chainStep then return Chain.Open(pane, chainStep) end
    if link == "needroll:chainall" then
        if not pane.quest then return end
        pane.chainAll[pane.quest] = not pane.chainAll[pane.quest] or nil
        return pane:Refresh()
    end
    local itemID = tonumber(link:match("^item:(%d+)") or "")
    if not itemID then return end
    if IsModifiedClick() then
        local _, full = C_Item.GetItemInfo(link)
        if full then HandleModifiedItemClick(full) end  -- shift-click links it in chat
        return
    end
    -- A plain click: where the item comes from.
    local place, sourceName = ItemPlace(pane.quest, itemID, pane.instance and pane.instance.id)
    if place then PageLink.OnClick(pane, place, sourceName) end
end

-- What a click on each kind of needroll: link in the page's text does.
local LINK_HINTS = {
    dropspot = L["Click to see where they drop it on the map"], boss = L["Click to see this boss on the map"],
    quest = L["Click to open this quest"], dungeonmap = L["Click to open the map"],
}

-- A link's tooltip: an item's own, a chain step's quest, the dungeon whose
-- entrance it pins, or what a click does.
function PageLink.ShowTooltip(owner, pane, link)
    local itemID = tonumber(link:match("^item:(%d+)") or "")
    if itemID then
        GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
        GameTooltip:SetHyperlink(link)
        if ItemPlace(pane.quest, itemID, pane.instance and pane.instance.id) then
            GameTooltip:AddLine(L["Click to see where it comes from"], unpack(Theme.tip.text))
        end
        GameTooltip:Show()
        return
    end
    local chainStep = tonumber(link:match("^needroll:chainquest:(%d+)") or "")
    if chainStep then return Chain.Tooltip(owner, pane.instance, chainStep, Chain.OpenHint(pane, chainStep)) end
    local inside = link:match("^needroll:inside:(.+)")
    if inside then
        local dungeon = ns.Data:Get(inside)
        return ShowTooltip(owner, "ANCHOR_CURSOR", dungeon and L["Inside %s"]:format(dungeon.name)
            or L["Inside the dungeon"], ns.Data.entrances[inside] and L["Click to pin the entrance on your map"] or nil)
    end
    -- An NPC's link names the zone and spot it pins.
    if link:match("^needroll:npc:") then
        return ShowTooltip(owner, "ANCHOR_CURSOR", ns.UI.PinHint(PageLink.PlaceSpot(link)))
    end
    local hint = LINK_HINTS[link:match("^needroll:(%a+)") or ""]
    if hint then ShowTooltip(owner, "ANCHOR_CURSOR", hint) end
end

-- A line of the page's text (pooled): .left holds it, links and all, and
-- wraps when long; .right is an empty column at the right edge.
local function NewTextLine(canvas, pane)
    local line = CreateFrame("Frame", nil, canvas)
    line.right = Theme:Text(line, Theme.font.small)
    line.right:SetPoint("TOPRIGHT", -2, -META_PAD)
    Theme:SetTextColor(line.right, Theme.color.text)
    line.left = Theme:Text(line, Theme.font.small)
    line.left:SetPoint("TOPLEFT", 0, -META_PAD)
    line.left:SetPoint("RIGHT", line.right, "LEFT", -12, 0)
    line.left:SetJustifyH("LEFT")
    line.left:SetWordWrap(true)
    -- A line can be tinted with a bar down its left: the quest page's own
    -- quest among its chain's rows (Chain.Lines).
    line.tint = line:CreateTexture(nil, "BACKGROUND")
    line.tint:SetAllPoints()
    line.bar = line:CreateTexture(nil, "ARTWORK")
    line.bar:SetPoint("TOPLEFT", -4, 0)
    line.bar:SetPoint("BOTTOMLEFT", -4, 0)
    line.bar:SetWidth(3)
    -- Solid, so the links and colored words in the line show at full strength.
    Theme:SetTextColor(line.left, Theme:Opaque(Theme.color.muted, Theme.color.panel2))
    line:SetHyperlinksEnabled(true)
    line:SetScript("OnHyperlinkClick", function(_, link, text) PageLink.OnClick(pane, link, text) end)
    line:SetScript("OnHyperlinkEnter", function(self, link, text)
        PageLink.ShowTooltip(self, pane, link)
        -- A modified click on an item still links it in chat (PageLink.OnClick).
        local onModifiedClick = link:match("^item:") and function() PageLink.OnClick(pane, link, text) end or nil
        ns.UI.HoverMapLink(self, PageLink.Spot(pane, link, text), onModifiedClick,
            function() PageLink.ShowTooltip(self, pane, link) end)
    end)
    line:SetScript("OnHyperlinkLeave", function(self)
        GameTooltip:Hide()
        ns.UI.LeaveMapLink(self)
    end)
    return line
end

-- "Requires level 9 · Quest level 16 · Shareable" ("· Weekly" before
-- Shareable for a weekly quest), each level the player hasn't reached yet
-- in red. Whether it can be shared is left out when no source knows
-- (ns.Data:QuestShareable).
local function LevelText(quest)
    local function LevelColor(level)
        return Theme:ColorCode(ns.PlayerLevel() >= level and Theme.color.available or Theme.color.incomplete)
    end
    local parts = {}
    local need = quest.minLevel or quest.level
    if need then
        table.insert(parts, L["Requires level %s"]:format(("%s%d|r"):format(LevelColor(need), need)))
    end
    -- A level suggested to complete it, above the one needed to take it.
    if quest.suggestedLevel then
        local text = L["Suggested level %d"]:format(quest.suggestedLevel):gsub("%d+", function(level)
            return ("%s%s|r"):format(LevelColor(quest.suggestedLevel), level)
        end, 1)
        table.insert(parts, text)
    end
    if quest.level then table.insert(parts, L["Quest level %d"]:format(quest.level)) end
    if quest.classes then table.insert(parts, L["%s only"]:format(quest.classes)) end
    if #parts == 0 then table.insert(parts, L["No level requirement"]) end
    -- One the game offers again each week (the Tarnished Undermine Real's "In Demand" quests).
    if quest.weekly then table.insert(parts, L["Weekly"]) end
    local shareable = ns.Data:QuestShareable(quest)
    if shareable ~= nil then table.insert(parts, shareable and L["Shareable"] or L["Not shareable"]) end
    return Theme:JoinDots(unpack(parts))
end

-- "Step 7 of a chain that starts with [The Defias Brotherhood] from Gryan
-- Stoutmantle" (or "from [Dark Iron Map] dropped by Dark Iron Spy", "from
-- [Henrig Lonebrow's Journal] looted from Henrig Lonebrow's Journal"); with
-- the whole chain known (`steps`, the quest at `at`) "Step 3 of 7 in ...".
local function ChainText(quest, instance, steps, at, onLoad)
    local here = instance and instance.id
    local start
    if steps then
        local first = steps[1][1]
        local step = ns.Data.chainSteps[first] or {}
        start = Chain.StartText(steps, at, Chain.Link(instance, first))
        -- Who (or what) starts its first step, from the chain data, so
        -- every step's page says the same; the quest's own data only
        -- when the chain data names nobody.
        if step.giver then
            return L["%s from %s"]:format(start, Giver(step.giver, step.giverNpc, nil, here, "giver", first))
        elseif step.startItem then
            -- A chain an item starts: "from [Tome of Valor]", and what drops
            -- or holds the item when the chain data knows.
            local item = ItemLink(step.startItem, step.startItemId, onLoad)
            local droppers, fromObjects = Droppers(step.droppers, here)
            if not droppers then return L["%s from %s"]:format(start, item) end
            local phrase = fromObjects and L["%s from %s looted from %s"] or L["%s from %s dropped by %s"]
            return phrase:format(start, item, droppers)
        end
    else
        if not quest.chainStart then return L["Not part of a chain"] end
        -- Its first step's light page, for the link to open.
        Chain.StartPage(quest)
        start = L["Step %d of a chain that starts with %s"]:format(quest.chainStep or 2,
            Chain.Link(instance, quest.chainStart, quest.chainStartName))
    end
    local item = quest.chainStartItem and ItemLink(quest.chainStartItem, quest.chainStartItemId, onLoad)
    local droppers, fromObjects = Droppers(item and quest.chainDroppers, here)
    if item and not droppers and quest.chainGiver then
        droppers = Giver(quest.chainGiver, quest.chainGiverNpc, quest.chainGiverInside, here, "dropper", quest.id)
    end
    if droppers then
        local phrase = fromObjects and L["%s from %s looted from %s"] or L["%s from %s dropped by %s"]
        return phrase:format(start, item, droppers)
    elseif item then
        return (quest.chainStartItemId and L["%s from %s"] or L["%s from %s (item)"]):format(start, item)
    elseif quest.chainGiver then
        local giver = Giver(quest.chainGiver, quest.chainGiverNpc, quest.chainGiverInside, here, "giver", quest.id)
        return L["%s from %s"]:format(start, giver)
    end
    return start
end

-- Where a hard-to-find giver stands, a link that pins the entrance they
-- stand by, and the item it takes to see them: ", on the balcony ... .
-- Only visible with [Item]".
local function GiverSpot(quest, onLoad)
    local text = ""
    if quest.giverWhere then
        text = ", " .. (quest.giverNear and EntranceLink(quest.giverNear, quest.giverWhere) or quest.giverWhere)
    end
    if quest.giverSee then
        text = text .. L[". Only visible with %s"]:format(ItemLink(quest.giverSeeName, quest.giverSee, onLoad))
    end
    return text
end

-- The item that starts a quest: its link, or its name in brackets when its
-- ID isn't known.
local function StartingItem(quest, onLoad)
    return quest.startsFromId and ItemLink(quest.startsFrom, quest.startsFromId, onLoad)
        or ("[%s]"):format(quest.startsFrom)
end

-- Who or what offers the quest: a giver, an item (and what drops it), or
-- an item looted inside the dungeon.
local function StartText(quest, instance, onLoad)
    local here = instance and instance.id
    -- A start kept by hand (Data/QuestStarts.lua): someone or something
    -- inside the dungeon, which the link pins the entrance of.
    local _, kept = ns.Data:QuestStart(here, quest.id)
    local dungeon = kept and ns.Data:Get(here)
    if dungeon and kept.giver then
        return L["From %s within %s"]:format(EntranceLink(here, GIVER_ICON .. kept.giver),
            EntranceLink(here, dungeon.name))
    elseif dungeon and kept.looted and quest.startsFrom then
        return L["Started from %s looted within %s %s"]:format(StartingItem(quest, onLoad),
            EntranceLink(here, dungeon.name), kept.looted)
    end
    -- A class quest's page has no dungeon: The Ancient Leaf's item, looted
    -- from a chest, says only what starts it.
    if quest.startsFrom and quest.fromObject and instance then
        -- Looted from a chest or object in the dungeon; taking it offers the quest.
        return L["Started from %s within %s"]:format(StartingItem(quest, onLoad), instance.name)
    elseif quest.startsFrom then
        local droppers, fromObjects = Droppers(quest.droppers, here, quest)
        if not droppers and quest.giver then
            droppers = Giver(quest.giver, quest.giverNpc, quest.giverInside, here, "dropper", quest.id)
        end
        local item = StartingItem(quest, onLoad)
        if not droppers then return L["Starts from %s"]:format(item) end
        local phrase = fromObjects and L["Starts from %s, looted from %s"] or L["Starts from %s, dropped by %s"]
        return phrase:format(item, droppers)
    elseif quest.giver then
        local giver = GiverInArea(quest.giver, quest.giverNpc, quest.giverInside, here, quest.id)
        return L["From %s"]:format(giver) .. GiverSpot(quest, onLoad)
    elseif quest.providedItem and quest.droppers then
        -- The item comes off mobs, or out of a chest, and starts the quest when used.
        local droppers, fromObjects = Droppers(quest.droppers, here)
        local phrase = fromObjects and L["Starts from %s, looted from %s"] or L["Starts from %s, dropped by %s"]
        return phrase:format(ItemLink(quest.providedItem, quest.providedItemId, onLoad), droppers)
    elseif quest.providedItem and quest.fromObject and instance then
        return L["Started from %s within %s"]:format(
            ItemLink(quest.providedItem, quest.providedItemId, onLoad), instance.name)
    elseif quest.providedItem then
        -- Nothing known drops or holds it, only that the quest hands it over.
        return L["Comes with %s"]:format(ItemLink(quest.providedItem, quest.providedItemId, onLoad))
    elseif quest.chainStart then
        return L["Offered when you finish the quest before it in the chain"]
    end
    return L["Not known yet"]
end

-- A loot target's line: "Loot [Item] from A or B" with every mob a map
-- link. An object named for the item reads "Loot [Item] in <dungeon>" in
-- another dungeon, or "Loot [Item], found here" out in the world, the link
-- pinning it; an item nothing is known to drop is "Loot [Item]" alone.
-- One any humanoid drops says how often: "Loot [Item] from any humanoid
-- (~1% chance)", the link opening the dungeon's map.
local function LootLine(loot, here, quest, onLoad)
    local item, from = ItemLink(loot.name, loot.item, onLoad), LootSources(loot)
    if loot.anyHumanoidChance then
        local chance = ("%.0f%%"):format(loot.anyHumanoidChance * 100)
        return L["Loot %s from %s (~%s chance)"]:format(item, Places(from, here, L["%s or %s"], quest), chance)
    end
    if #from == 0 then return L["Loot %s"]:format(item) end
    local object = #from == 1 and from[1].name == loot.name and from[1]
    local dungeon = object and object.inside and ns.Data:Get(object.inside)
    if dungeon then return L["Loot %s in %s"]:format(item, EntranceLink(object.inside, dungeon.name)) end
    local questID = quest and quest.id
    if object and ns.Data:NpcSpot(object.npc, questID) then
        local found = PlaceLink(NpcTarget(object.npc, questID), GIVER_ICON, Theme.color.link, L["found here"])
        return L["Loot %s, %s"]:format(item, found)
    end
    return L["Loot %s from %s"]:format(item, Places(from, here, L["%s or %s"], quest))
end

-- What a quest sends you to kill or fetch, a line each: "Kill A, B and C",
-- then its loot lines.
local function TargetLines(quest, here, onLoad)
    local targets = {}
    if quest.kills and #quest.kills > 0 then
        table.insert(targets, L["Kill %s"]:format(Places(quest.kills, here, L["%s and %s"], quest)))
    end
    for _, loot in ipairs(quest.loot or {}) do table.insert(targets, LootLine(loot, here, quest, onLoad)) end
    return targets
end

-- What a step asks at each standing, when its versions go by reputation
-- (Naxxramas: Honored, Revered, Exalted with the Argent Dawn). The line
-- for the player's own standing is bright with its standing in gold.
local function CostLines(quest, onLoad)
    local lines = {}
    if not quest.costs then return lines end
    local mine = ns.UI.PlayerStanding(quest.costFaction) or 0
    local yours
    for i, cost in ipairs(quest.costs) do
        if cost.standing <= mine then yours = i end
    end
    for i, cost in ipairs(quest.costs) do
        local asks = {}
        if cost.money > 0 then table.insert(asks, ns.Money(cost.money)) end
        for _, ask in ipairs(cost.items) do
            local icon = C_Item.GetItemIconByID(ask.item)
            table.insert(asks, ("%d %s%s"):format(ask.count, icon and ("|T%s:0|t "):format(icon) or "",
                ItemLink(ask.name, ask.item, onLoad)))
        end
        local standing = _G["FACTION_STANDING_LABEL" .. cost.standing] or tostring(cost.standing)
        if i == yours then standing = Theme:ColorCode(Theme.color.heading) .. standing .. "|r" end
        local text = standing .. Theme.DOTS .. (#asks > 0 and table.concat(asks, ", ") or L["Free"])
        table.insert(lines, { text = text, color = i == yours and Theme.color.text or nil })
    end
    return lines
end

-- Fills the stat boxes and works out where each goes (side by side, onto a
-- new row when the pane is too narrow): { x, row } per box, and the rows.
-- A dungeon has no Quests box while the Quests module is off.
local function LayoutFacts(pane, instance)
    local range = instance.levelRange
    local last
    if instance.category == "RAID" then
        pane.facts[4].label:SetText(L["Players"])
        last = tostring(instance.groupSize or 5)
    else
        pane.facts[4].label:SetText(L["Quests"])
        local done, total, others = ns.UI.QuestCount(instance)
        last = L["%d of %d complete"]:format(done, total)
        if total == 0 then
            -- Only other classes' quests here: say whose they aren't.
            local class = others > 0 and UnitClass("player")
            last = class and L["None for a %s"]:format(class) or L["None"]
        end
    end
    local values = {
        not range and "-" or range[1] == range[2] and tostring(range[1])
            or ("%d-%d"):format(range[1], range[2]),
        instance.zone or "-",
        tostring(ns.Data:BossCount(instance)),
        last,
    }
    local width, x, row, spots = PageWidth(pane), 0, 0, {}
    local count = (instance.category == "RAID" or ns.Modules:IsOn("QUESTS")) and #pane.facts or #pane.facts - 1
    for i = 1, count do
        local box = pane.facts[i]
        box.value:SetText(values[i])
        local w = math.max(110, math.max(box.label:GetStringWidth(), box.value:GetStringWidth())
            + FACT.PAD_LEFT + FACT.PAD_RIGHT)
        box:SetWidth(w)
        if x > 0 and x + w > width then x, row = 0, row + 1 end
        spots[i] = { x, row }
        x = x + w + FACT.GAP
    end
    return spots, row + 1
end

local function FactsHeight(pane, instance)
    local spots, rows = LayoutFacts(pane, instance)
    pane.factSpots = spots  -- the boxes are drawn where this put them
    return rows * FACT.HEIGHT + (rows - 1) * FACT.GAP + 12
end

-- A line of text's height: one line, or more when it wraps.
-- `spacing`: extra room between its lines when it wraps.
local function TextHeight(pane, text, font, indent, spacing)
    local measure = pane.measure
    measure:SetFontObject(font)
    measure:SetSpacing(spacing or 0)
    measure:SetWidth(math.max(PageWidth(pane) - 20 - (indent or 0), 50))  -- the text line's width
    measure:SetText(text)
    return math.max(LINE_HEIGHT.meta, math.ceil(measure:GetStringHeight() or 0) + META_PAD * 2)
end

local function LineHeight(line)
    return line.height or LINE_HEIGHT[line.kind]
end

-- A section heading (Description, Attunement) over its rule.
local function Section(lines, text, extra)
    -- A bigger heading font needs the room above it.
    local _, size = Theme.font.ruled:GetFont()
    local _, base = Theme.font.label:GetFont()
    local line = { kind = "heading", text = text, rule = true, font = Theme.font.ruled,
        height = SECTION_HEIGHT + math.max(0, size - base) }
    for k, v in pairs(extra or {}) do line[k] = v end
    table.insert(lines, line)
end

-- A line of a quest's or an attunement step's text: 7/6 the body font (14pt
-- native), its NPC marks sized to it, a little room between wrapped lines.
local function AddTextLine(pane, lines, text, color, indent)
    local font = Theme:ScaledFont(Theme.font.body, 7 / 6)
    local _, size = font:GetFont()
    text = ns.UI.SizeMarkers(text, size)
    table.insert(lines, { kind = "meta", text = text, color = color, indent = indent, font = font, spacing = 3,
        height = TextHeight(pane, text, font, indent, 3) })
end

-- The Alliance / Horde switch's tooltip words: the raid's Attunement names
-- itself; an item chain's switch shows a side's steps.
Attunement.TIPS = { shown = L["%s attunement"], click = L["Click to see the %s attunement"] }
Attunement.CHAIN_TIPS = { shown = L["Showing %s"], click = L["Click to show %s"] }

-- The attunement (`chainIndex` 0) or item chain (1 and up) of an instance.
function Attunement.Chain(instanceID, chainIndex)
    if chainIndex == 0 then return ns.Data:Attunement(instanceID) end
    return ns.Data:ItemChains(instanceID)[chainIndex]
end

-- A step's quest as a link that opens its page:
-- needroll:quest:<instance>:<side>:<step>:<quest of the step>:<chain>.
-- `at`: the section's { instance, chainIndex, side }.
function Attunement.QuestLink(at, stepIndex, questIndex, quest)
    return ("|Hneedroll:quest:%s:%s:%d:%d:%d|h%s[%s]|r|h"):format(at.instance.id, at.side, stepIndex, questIndex,
        at.chainIndex, Theme:ColorCode(Theme.color.quest), quest.name)
end

-- The quest a step's link (Attunement.QuestLink) opens, or nil. A link
-- without the last two parts is the attunement's, its step's only quest.
function Attunement.LinkedQuest(link)
    local instanceID, side, stepIndex, questIndex, chainIndex =
        link:match("^needroll:quest:([^:]+):([^:]+):(%d+):?(%d*):?(%d*)")
    local chain = instanceID and Attunement.Chain(instanceID, tonumber(chainIndex) or 0)
    local step = chain and chain[side] and chain[side][tonumber(stepIndex)]
    return step and ns.Data:StepQuests(step)[tonumber(questIndex) or 1]
end

-- An attunement's or item chain's status: Complete with its last step's
-- quests done, In Progress with any quest done, taken or partway through
-- its chain, else Incomplete. Nil without steps.
function Attunement.Status(steps)
    if #steps == 0 then return nil end
    local isComplete = true
    for _, quest in ipairs(ns.Data:StepQuests(steps[#steps])) do
        isComplete = isComplete and Status(quest) == "Completed"
    end
    if isComplete then return L["Complete"], Theme.color.complete end
    for _, step in ipairs(steps) do
        for _, quest in ipairs(ns.Data:StepQuests(step)) do
            if Status(quest) ~= "Incomplete" then return L["In Progress"], Theme.color.accepted end
        end
    end
    return L["Incomplete"], Theme.color.incomplete
end

-- The status of a step whose quests are all needed: Completed once every
-- one is, how many are done ("1/3") once one is done, taken or partway
-- through its chain, else Incomplete.
function Attunement.AllOfStatus(quests)
    local doneCount, isStarted = 0, false
    for _, quest in ipairs(quests) do
        local status = Status(quest)
        if status == "Completed" then doneCount = doneCount + 1 end
        isStarted = isStarted or status ~= "Incomplete"
    end
    if doneCount == #quests then return STATUS_TEXT.Completed, Theme.color.complete end
    if not isStarted then return STATUS_TEXT.Incomplete, Theme.color.incomplete end
    return ("%d/%d"):format(doneCount, #quests), Theme.color.accepted
end

-- A boss named in a note ({boss:INSTANCE:ENCOUNTER}), linked as a quest
-- giver's name is: on this instance's map, or "Arcanist Doan (in Scarlet
-- Monastery: Library)" pinning another instance's entrance.
function Attunement.BossLink(instanceID, encounterID, here)
    local instance = ns.Data:Get(instanceID)
    for _, encounter in ipairs(instance and instance.encounters or {}) do
        if encounter.id == encounterID then return Giver(encounter.name, encounter.npc, instanceID, here) end
    end
    return encounterID
end

-- A note as page text: {item:ID:Name} an item link, {quest:ID:Name} a link
-- that opens the quest's page and {boss:INSTANCE:ENCOUNTER} the boss's
-- name (Attunement.BossLink), each named as the game or the boss list has it.
function Attunement.NoteText(note, instance, onLoad)
    note = note:gsub("{item:(%d+):([^}]+)}", function(id, name)
        return ItemLink(C_Item.GetItemNameByID(tonumber(id)) or name, tonumber(id), onLoad)
    end)
    note = note:gsub("{quest:(%d+):[^}]+}", function(id) return Chain.Link(instance, tonumber(id)) end)
    return (note:gsub("{boss:([%w_]+):([%w_]+)}", function(instanceID, encounterID)
        return Attunement.BossLink(instanceID, encounterID, instance.id)
    end))
end

-- One quest of a step: "<label>  [Quest]" at `indent`, then under it who
-- starts it and its status, what it costs at each standing or else what
-- it sends you to kill or fetch. `at`: the section's { instance,
-- chainIndex, side }.
function Attunement.QuestLines(pane, lines, at, label, link, quest, indent)
    local onLoad = pane.onItemLoaded
    local function Say(text, color, extraIndent) AddTextLine(pane, lines, text, color, indent + extraIndent) end
    Say(("%s  %s"):format(label, link), Theme.color.text, 0)
    local status, color = Status(quest)
    Say(("%s%s%s%s|r"):format(StartText(quest, at.instance, onLoad), Theme.DOTS, Theme:ColorCode(color),
        STATUS_TEXT[status]), nil, STEP_INDENT)
    for _, cost in ipairs(CostLines(quest, onLoad)) do Say(cost.text, cost.color, STEP_INDENT) end
    -- A step priced by standing (Naxxramas) lists what it costs, not
    -- where to find it; its quest page still has the Targets.
    if quest.costs then return end
    for _, text in ipairs(TargetLines(quest, at.instance.id, onLoad)) do Say(text, nil, STEP_INDENT) end
end

-- A step's lines: "1.  [Quest]" and its details. A step whose quests are
-- all needed reads "8.  All 3, any order  ·  1/3", its members lettered
-- under it ("a.", or "b1.", "b2." for a member that is a run of quests
-- done in order).
function Attunement.StepLines(pane, lines, at, stepIndex, step)
    if not step.all then
        return Attunement.QuestLines(pane, lines, at, stepIndex .. ".", Attunement.QuestLink(at, stepIndex, 1, step),
            step, 0)
    end
    local status, color = Attunement.AllOfStatus(ns.Data:StepQuests(step))
    AddTextLine(pane, lines, ("%d.  %s"):format(stepIndex, Theme:JoinDots(L["All %d, any order"]:format(#step.all),
        Theme:ColorCode(color) .. status .. "|r")), Theme.color.text)
    local questIndex = 0
    for memberIndex, member in ipairs(step.all) do
        local run = member.id and { member } or member
        local letter = string.char(("a"):byte() + memberIndex - 1)
        for runIndex, quest in ipairs(run) do
            questIndex = questIndex + 1
            local label = #run > 1 and letter .. runIndex .. "." or letter .. "."
            Attunement.QuestLines(pane, lines, at, label, Attunement.QuestLink(at, stepIndex, questIndex, quest),
                quest, STEP_INDENT)
        end
    end
end

-- One section: a heading that opens and shuts it (its status after the
-- words; open, with the side switch when the sides' steps differ), then
-- its note and steps. `at`: { instance, chainIndex } (0: the attunement);
-- `chain` nil is a raid whose attunement isn't known.
function Attunement.Section(pane, lines, at, chain, title)
    local foldKey = at.chainIndex == 0 and at.instance.id or ("%s:%d"):format(at.instance.id, chain.item)
    local open = pane.attuneOpen[foldKey] or false
    local split = chain and chain.Alliance and chain.Horde and true
    if chain and not pane.attuneSide then
        pane.attuneSide = ns.PlayerFaction()
    end
    at.side = chain and (split and pane.attuneSide or (chain.both and "both")
        or (chain.Alliance and "Alliance") or "Horde")
    local steps = chain and chain[at.side] or {}
    local status, statusColor = Attunement.Status(steps)
    table.insert(lines, { kind = "spacer" })
    Section(lines, title, { fold = true, foldKey = foldKey, open = open, toggle = open and split,
        toggleTips = at.chainIndex == 0 and Attunement.TIPS or Attunement.CHAIN_TIPS,
        status = status, statusColor = statusColor })
    if not open then return end
    if not chain then return AddTextLine(pane, lines, L["Not known yet."]) end
    if chain.note then AddTextLine(pane, lines, Attunement.NoteText(chain.note, at.instance, pane.onItemLoaded)) end
    for stepIndex, step in ipairs(steps) do Attunement.StepLines(pane, lines, at, stepIndex, step) end
end

-- An item chain's heading: its item's name, the game's once it has the item.
function Attunement.ChainTitle(chain, onLoad)
    if not C_Item.IsItemDataCachedByID(chain.item) then ns.Items:Load(chain.item, onLoad) end
    return C_Item.GetItemNameByID(chain.item) or chain.name
end

-- An instance's sections: a raid's Attunement first (none for a raid
-- anyone can walk into), then each item chain under its item's name.
function Attunement.Lines(pane, lines, instance)
    local attunement = ns.Data:Attunement(instance.id)
    if instance.category == "RAID" and not (attunement and attunement.none) then
        Attunement.Section(pane, lines, { instance = instance, chainIndex = 0 }, attunement, L["Attunement"])
    end
    for chainIndex, chain in ipairs(ns.Data:ItemChains(instance.id)) do
        Attunement.Section(pane, lines, { instance = instance, chainIndex = chainIndex }, chain,
            Attunement.ChainTitle(chain, pane.onItemLoaded))
    end
end

-- An instance's Overview, as page lines.
local function OverviewLines(pane, instance)
    local lines = { { kind = "facts", height = instance and FactsHeight(pane, instance) } }
    if instance and ns.Data:Map(instance.id) and pane.mapCard:LoadArt(instance) then
        table.insert(lines, { kind = "mapcard" })
    end
    if instance then table.insert(lines, { kind = "entrance" }) end
    local lore = instance and ns.Data:Lore(instance.id) or L["Not written yet."]
    Section(lines, L["Description"])
    table.insert(lines, { kind = "meta", text = lore, color = Theme.color.text,
        height = TextHeight(pane, lore, Theme.font.body) })
    if instance and ns.Modules:IsOn("QUESTS") then Attunement.Lines(pane, lines, instance) end
    return lines
end

-- A heading on a quest's page: 1.64x the label font (18pt in the native skin).
local function AddHeading(lines, label)
    local _, labelSize = Theme.font.label:GetFont()
    local font = Theme:ScaledFont(Theme.font.label, 1.64)
    local _, size = font:GetFont()
    table.insert(lines, { kind = "heading", text = Theme:Label(label), font = font,
        height = LINE_HEIGHT.heading + math.ceil(size - labelSize) })
end

-- A quest's page above its rewards (a chain step's light page has who takes
-- it back, and where).
local function AddQuestDetails(pane, lines, instance, quest)
    local here = instance and instance.id
    local onLoad = pane.onItemLoaded
    local function Text(text, color) AddTextLine(pane, lines, text, color) end
    local function Field(label, text, color)
        AddHeading(lines, label)
        Text(text, color)
    end
    -- The chain line; with the whole chain known, a button under it
    -- that opens (and shuts) every step's row.
    local chainLines, steps, at = Chain.Lines(instance, quest, true)
    Field(L["Chain"], ChainText(quest, instance, chainLines and at and steps, at, onLoad))
    if chainLines and at then
        local open = pane.chainAll[quest]
        Text(("|Hneedroll:chainall|h|A:QuestLog-up-c60:24:24:0:-5|a %s%s|r|h"):format(Theme:ColorCode(Theme.color.link),
            open and L["Click to hide full quest chain"] or L["Click to see full quest chain"]))
        if open then
            for _, row in ipairs(chainLines) do
                Text(row.text)
                lines[#lines].tint, lines[#lines].bar = row.tint, row.bar
            end
        end
    end
    Field(L["Started by"], StartText(quest, instance, onLoad))
    if quest.objective then
        Field(L["Objective"], ns.UI.LinkObjective(FillTokens(quest.objective), quest, here, onLoad), Theme.color.text)
    end
    local targets = TargetLines(quest, here, onLoad)
    if #targets > 0 then Field(L["Targets"], table.concat(targets, "\n")) end
    if quest.turnIn then
        Field(L["Turn in"], GiverInArea(quest.turnIn, quest.turnInNpc, quest.turnInInside, here, quest.id))
    end
    local zone = quest.zone and C_Map.GetAreaInfo(quest.zone)
    if zone then Field(L["Zone"], zone) end
end

-- A quest's rewards: its XP and money, then the items to choose from and
-- the ones that come anyway, in rows of cells like a dungeon's loot grid.
-- XP shows only when confirmed (ns.Data:QuestXP). "None" means the quest is
-- known to pay nothing, so it needs its XP confirmed as none; with nothing
-- known at all there is no Rewards heading.
local function AddRewards(pane, lines, quest)
    local xp = ns.Data:QuestXP(quest)
    local paid = {}
    if xp and xp > 0 then table.insert(paid, L["%s XP"]:format(BreakUpLargeNumbers(xp))) end
    if quest.money and quest.money > 0 then table.insert(paid, ns.Money(quest.money)) end
    local hasItems = (quest.choice and #quest.choice > 0) or (quest.rewards and #quest.rewards > 0)
    if #paid == 0 and not hasItems and xp ~= 0 then return end
    AddHeading(lines, L["Rewards"])
    if #paid > 0 then
        AddTextLine(pane, lines, Theme:JoinDots(unpack(paid)), Theme.color.text)
    elseif not hasItems then
        AddTextLine(pane, lines, L["None"], Theme.color.text)
    end
    local function Items(label, ids)
        if not ids or #ids == 0 then return end
        -- "Choose one" 1.4x the small font (14pt native), with room for it.
        table.insert(lines, { kind = "label", text = label, height = LINE_HEIGHT.label + 4 })
        for i = 1, #ids, COLUMNS do
            local row = {}
            for c = i, math.min(i + COLUMNS - 1, #ids) do
                table.insert(row, { itemID = ids[c] })
            end
            -- As tall as a dungeon's loot grid row, drawn smaller.
            local zoom = ns.UI.smallGridScale or 1
            table.insert(lines, { kind = "items", entries = row,
                height = ns.UI.LootRowHeight(ns.UI.LootGridFonts(zoom)) * zoom + 4 })
        end
    end
    local both = quest.choice and quest.rewards and #quest.choice > 0 and #quest.rewards > 0
    Items(L["Choose one"], quest.choice)
    Items(both and L["You also get"] or L["You get"], quest.rewards)
end

-- The page as a list of lines, each { kind, ... }; scrolling moves by
-- line. The open map takes the Overview's place, so it has none.
local function PageLines(pane)
    local instance, quest = pane.instance, pane.quest
    if quest then
        local lines = {}
        AddQuestDetails(pane, lines, instance, quest)
        -- A chain step's light page has no rewards. Nor has a class quest
        -- whose rewards no source knows: "None" would be wrong.
        if not (quest.stepOnly or quest.rewardsUnknown) then AddRewards(pane, lines, quest) end
        table.insert(lines, { kind = "spacer" })
        return lines
    end
    if pane.showMap then return {} end
    return OverviewLines(pane, instance)
end

-- The line under a quest's title: "The Deadmines  ·  Alliance only  ·
-- Prior Step (2 of 3): [Quest]", the quest of its chain you're on a link.
-- A class quest with no dungeon names the zone of its giver's map spot.
local function QuestSubtitle(instance, quest)
    local status, color, step, chainLength, current = Status(quest)
    status = Theme:ColorCode(color) .. STATUS_TEXT[status]
    if step and chainLength then status = ("%s (%d of %d)"):format(status, step, chainLength) end
    if current then
        status = ("%s:|r %s"):format(status, Chain.Link(instance, current))
    end
    local side = quest.side and (quest.side == "Alliance" and L["Alliance only"]
        or quest.side == "Horde" and L["Horde only"] or L["%s only"]:format(ns.SideName(quest.side)))
        or L["Alliance and Horde"]
    local place = instance and instance.name
    if not place then
        local giver = ns.Data:NpcSpot(quest.giverNpc, quest.id)
        local map = giver and giver.map and C_Map.GetMapInfo(giver.map)
        place = map and map.name
    end
    return Theme:JoinDots(place, side) .. Theme.DOTS .. status .. "|r"
end

-- Places a reward cell (drawn at the loot grid's scale, so `x` and `y` are
-- turned into its units) and its icon on whole pixels: between pixels, the
-- 1px quality border's top or bottom edge drops out.
local function PlaceCell(pane, cell, x, y)
    local scale = cell:GetScale()
    local unit = PixelUtil.GetPixelToUIUnitFactor() / cell:GetEffectiveScale()
    local function Snap(v) return math.floor(v / unit + 0.5) * unit end
    cell:SetPoint("TOPLEFT", pane, "TOPLEFT", Snap(x / scale), Snap(y / scale))
    local size = Snap(cell.iconSize or 38)
    cell.iconBorder:ClearAllPoints()
    cell.iconBorder:SetPoint("TOPLEFT", Snap(6), -Snap(7))
    cell.iconBorder:SetSize(size, size)
    if not Theme.native then
        cell.icon:ClearAllPoints()
        cell.icon:SetPoint("TOPLEFT", cell.iconBorder, unit, -unit)
        cell.icon:SetPoint("BOTTOMRIGHT", cell.iconBorder, -unit, unit)
    end
end

-- A heading or label on the page (pooled).
local function NewPageText(canvas, font)
    local text = Theme:Text(canvas, font)
    text:SetJustifyH("LEFT")
    return text
end

-- The rule under a section heading: fading in over its first tenth,
-- solid, then fading out over its last tenth.
local function NewRule(canvas)
    local rule = CreateFrame("Frame", nil, canvas)
    rule.fadeIn = rule:CreateTexture(nil, "ARTWORK")
    rule.fadeIn:SetPoint("TOPLEFT")
    rule.fadeIn:SetPoint("BOTTOMLEFT")
    rule.fadeIn:SetColorTexture(1, 1, 1, 1)
    rule.fadeOut = rule:CreateTexture(nil, "ARTWORK")
    rule.fadeOut:SetPoint("TOPRIGHT")
    rule.fadeOut:SetPoint("BOTTOMRIGHT")
    rule.fadeOut:SetColorTexture(1, 1, 1, 1)
    rule.solid = rule:CreateTexture(nil, "ARTWORK")
    rule.solid:SetPoint("TOPLEFT", rule.fadeIn, "TOPRIGHT")
    rule.solid:SetPoint("BOTTOMRIGHT", rule.fadeOut, "BOTTOMLEFT")
    function rule:SetColor(c)
        local solid, clear = CreateColor(c[1], c[2], c[3], c[4] or 1), CreateColor(c[1], c[2], c[3], 0)
        self.solid:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
        self.fadeIn:SetGradient("HORIZONTAL", clear, solid)
        self.fadeOut:SetGradient("HORIZONTAL", solid, clear)
    end
    function rule:SetLength(w, h)
        self:SetSize(w, h)
        self.fadeIn:SetWidth(w * 0.1)
        self.fadeOut:SetWidth(w * 0.1)
    end
    return rule
end

function ns.UI.CreateOverview(parent)
    local pane = Theme:CreatePanel(parent, "loot")
    pane.offset = 0
    pane.pools = { heading = {}, meta = {}, label = {}, cell = {}, rule = {}, fold = {}, foldStatus = {},
                   sideToggle = {} }

    pane.title = Theme:Text(pane, Theme.font.heading)
    pane.title:SetPoint("RIGHT", -Size.pad, 0)
    pane.title:SetJustifyH("LEFT")
    -- Which quests' chains have "Show all" open.
    pane.chainAll = setmetatable({}, { __mode = "k" })
    CreateChainArrows(pane)

    -- The page's canvas, clipped below the title so lines gliding past are
    -- cut off (Refresh moves its top edge to where the page starts).
    local canvas = Theme:ScrollView(pane, HEADER_HEIGHT, Size.scrollBottom)
    pane.facts = CreateFacts(canvas)

    -- Opens the layout map in place of the Overview's lines. That leaves the
    -- Overview, so Back can return to it (so does picking Overview again).
    local function OpenMap()
        local place = ns.UI:Place()
        place.label, place.map = L["Overview"], true
        ns.UI:PushBack(place)
        pane.showMap = true
        pane.offset = 0
        ns.UI:Refresh()
    end

    -- Opens the map on one of its levels (the player's, UI:FollowPlayer).
    function pane:ShowFloor(level)
        self.levels[self.instance.id] = level
        if self.showMap then ns.UI:Refresh() else OpenMap() end
    end

    -- Readies the map on the level a boss is pinned on, its pin lit, for
    -- the Map button on the boss's page (UI:ShowBossOnMap shows it).
    function pane:ShowBoss(instance, encounter, level)
        if instance ~= self.instance then self.offset = 0 end
        self.instance, self.quest = instance, nil
        self:HideSteps()
        self.levels[instance.id] = level
        self.showMap = true
        self.mapView.focus = encounter.id
        self.mapView.focusSpot = nil
    end

    pane.mapCard = CreateMapCard(canvas, OpenMap)
    pane.entranceRow = CreateEntranceRow(pane, canvas)
    CreateTitleParts(pane)

    -- The heading of an attunement or item chain section (Attunement.Section)
    -- opens and shuts it. Each starts shut and keeps its own state (its fold
    -- key -> true while open: the raid's ID for its Attunement, "<instance
    -- ID>:<item ID>" for an item chain), as Settings' "Remember sections"
    -- says (ns.SectionMemory's "attunement" area).
    pane.attuneOpen = ns.SectionMemory.Area("attunement")
    ns.SectionMemory.OnModeChange(function() pane.attuneOpen = ns.SectionMemory.Area("attunement") end)
    -- The widgets a section heading adds, pooled per kind: the button over
    -- the heading with its arrow, its status after the words, and the
    -- switch picking which side's steps every section shows (pane.attuneSide).
    pane.newFoldWidget = {
        fold = function(holder)
            local header = CreateFrame("Button", nil, holder)
            header.arrow = Theme:Arrow(header)
            header.arrow:SetPoint("LEFT", 0, 0)
            header:SetScript("OnClick", function(self)
                pane.attuneOpen[self.foldKey] = not pane.attuneOpen[self.foldKey] or nil
                pane:Refresh()
            end)
            return header
        end,
        foldStatus = function(holder) return Theme:Text(holder, Theme.font.body) end,
        sideToggle = function(holder)
            return Theme:FactionToggle(holder, function(side)
                pane.attuneSide = side
                pane:Refresh()
            end)
        end,
    }

    local view = CreateMapView(pane)
    pane.mapView, pane.view = view, view  -- .view: the smoke tests' name for it
    pane.levels = {}  -- the level last shown, per instance

    -- While the map shows: the markers for `quest` (any it's on, a boss's
    -- or another marker's included) pulse gold; nil stops them. For a
    -- quest row hovered in the Quests list.
    function pane:GlowQuest(quest)
        if not (self.showMap and view:IsVisible()) then return end
        for _, mark in ipairs(view.markers) do
            if mark:IsShown() then mark:SetGlow(mark:HasQuest(quest)) end
        end
    end

    -- An item asked for arrives a moment later: redrawn in its quality color.
    function pane.onItemLoaded()
        if pane:IsVisible() then pane:Refresh() end
    end

    -- Text lines wrap when long; this hidden string measures them.
    pane.measure = Theme:Text(pane, Theme.font.small)
    pane.measure:SetWordWrap(true)
    pane.measure:SetAlpha(0)  -- shown (hidden strings may not measure), but never seen

    -- Widgets are pooled per kind and handed out in order on each redraw;
    -- a new one is make(canvas, ...).
    local used
    local function Take(kind, make, ...)
        used[kind] = (used[kind] or 0) + 1
        local widget = Pooled(pane.pools[kind], used[kind], make, canvas, ...)
        widget:ClearAllPoints()
        widget:Show()
        return widget
    end

    -- Where a quest's page starts: under its name (which can wrap), the
    -- subtitle and the level line.
    function pane:QuestTop()
        return math.ceil(TITLE.QUEST_TOP + self.title:GetStringHeight() + TITLE.SUB_GAP + FontSize(self.sub, 10)
            + TITLE.LEVEL_GAP + FontSize(self.levelLine, 10) + TITLE.PAGE_GAP)
    end

    -- The scroll position that shows the page's last line at the bottom.
    -- `lines`: the page's lines when the caller has them already. An
    -- Overview draws from OVERVIEW_TOP but this counts from HEADER_HEIGHT, so
    -- its last line stops HEADER_HEIGHT - OVERVIEW_TOP px short of the bottom.
    local function MaxOffset(lines)
        lines = lines or pane.lines or PageLines(pane)
        local top = pane.quest and pane:QuestTop() or HEADER_HEIGHT
        local room, need = pane:GetHeight() - top - Size.pad, 0
        for i = #lines, 1, -1 do
            local h = LineHeight(lines[i])
            if need + h > room then return i end
            need = need + h
        end
        return 0
    end

    -- Each kind of page line, drawn at (x, y) down from the pane's top.
    local function DrawFacts(x, y)
        pane.factSpots = pane.factSpots or LayoutFacts(pane, pane.instance)
        for i, spot in ipairs(pane.factSpots) do
            local box = pane.facts[i]
            box:ClearAllPoints()
            box:SetPoint("TOPLEFT", x + spot[1], -y - spot[2] * (FACT.HEIGHT + FACT.GAP))
            box:Show()
        end
    end
    local function DrawHeading(line, x, y, h, width)
        local heading = Take("heading", NewPageText, Theme.font.label)
        -- A section heading sits higher, over a one-pixel rule as wide as the page.
        local lift = line.rule and 10 + RULE_GAP or 4
        local arrowRoom = line.fold and 16 or 0
        heading:SetPoint("BOTTOMLEFT", pane, "TOPLEFT", x + 4 + arrowRoom, -y - h + lift)
        heading:SetFontObject(line.font or Theme.font.label)
        heading:SetText(line.text)
        heading.devLabel = ("Overview: %s heading"):format(line.text)
        if line.fold then
            -- The whole heading opens and shuts the section; the arrow shows which.
            local header = Take("fold", pane.newFoldWidget.fold)
            header.foldKey = line.foldKey
            header:SetPoint("BOTTOMLEFT", pane, "TOPLEFT", x + 4, -y - h + lift - 2)
            header:SetSize(arrowRoom + heading:GetStringWidth() + 4, heading:GetStringHeight() + 4)
            header.arrow:SetOpen(line.open)
        end
        if line.status then
            -- Its status sits on the heading's line, just after the words.
            local status = Take("foldStatus", pane.newFoldWidget.foldStatus)
            status:SetPoint("BOTTOMLEFT", heading, "BOTTOMRIGHT", 12, 2)
            status:SetText(line.status)
            Theme:SetTextColor(status, line.statusColor)
        end
        if line.rule then
            local rule = Take("rule", NewRule)
            local _, pixel = Theme:LineWidth(pane)
            rule:SetColor(Theme.color.rule)
            rule:SetPoint("TOPLEFT", pane, "TOPLEFT", x - 4, -y - h + lift - RULE_GAP - 3)
            rule:SetLength(width + 12, pixel)
        end
        if line.toggle then
            -- The side toggle sits on the heading's line, at the right.
            local toggle = Take("sideToggle", pane.newFoldWidget.sideToggle)
            toggle.tips = line.toggleTips
            toggle:SetPoint("RIGHT", pane, "TOPLEFT", x + width, -y - h + lift + 8)
            toggle:SetSide(pane.attuneSide)
        end
    end
    -- `section`: the heading the line is under, naming it for /nr fontdebug.
    local function DrawText(line, x, y, h, width, section)
        local meta = Take("meta", NewTextLine, pane)
        local indent = line.indent or 0
        meta:SetPoint("TOPLEFT", x + 4 + indent, -y)
        meta:SetSize(width - 4 - indent, h)
        meta.left:SetFontObject(line.font or Theme.font.body)
        meta.left:SetSpacing(line.spacing or 0)
        Theme:SetTextColor(meta.left, line.color or Theme:Opaque(Theme.color.muted, Theme.color.panel2))
        meta.left:SetText(line.text)
        meta.left.devLabel = ("Overview: %s text"):format(section)
        meta.right:SetText("")
        meta.tint:SetShown(line.tint ~= nil)
        meta.bar:SetShown(line.bar ~= nil)
        if line.tint then meta.tint:SetColorTexture(unpack(line.tint)) end
        if line.bar then meta.bar:SetColorTexture(unpack(line.bar)) end
    end
    local function DrawLabel(line, x, y)
        local label = Take("label", NewPageText, Theme.font.small)
        label:SetPoint("TOPLEFT", x + 4, -y - 5)
        label:SetFontObject(Theme:ScaledFont(Theme.font.small, 1.4))
        label:SetText(line.text)
        label.devLabel = ("Overview: %s label"):format(line.text)
        Theme:SetTextColor(label, Theme.color.muted)
    end
    -- Rewards look like a dungeon boss's drops: its loot grid's fonts,
    -- icon and row, at its scale.
    local function DrawItems(line, x, y, width)
        local cellWidth = (width - GAP * (COLUMNS - 1)) / COLUMNS
        local zoom = ns.UI.smallGridScale or 1
        local fonts = ns.UI.LootGridFonts(zoom)
        for col, entry in ipairs(line.entries) do
            local cell = Take("cell", ns.UI.CreateItemCell)
            cell:SetScale(zoom)
            if cell.fonts ~= fonts then ns.UI.ApplyCellFonts(cell, fonts) end
            cell:SetHeight(ns.UI.LootRowHeight(fonts))
            PlaceCell(pane, cell, x + (col - 1) * (cellWidth + GAP), -(y + 2))
            cell:SetWidth(cellWidth / zoom)
            cell:SetEntry(entry)
            cell.icon.devLabel, cell.iconBorder.devLabel = "Overview: reward icon", "Overview: reward icon"
        end
    end

    -- `scrolling` (true) when only the scroll position changed: the page's
    -- lines, its scroll limit and the stat boxes' layout are as last built,
    -- so a glide only moves what is on screen. Anything else builds them anew.
    function pane:Refresh(scrolling)
        scrolling = scrolling == true and self.lines ~= nil
        used = {}
        local instance, quest = self.instance, self.quest
        local width = PageWidth(self)
        local bottom = self:GetHeight()
        local y = quest and self:QuestTop() or OVERVIEW_TOP
        canvas:SetTop(y - 4)  -- a little above, so the stat boxes' edges aren't clipped
        for _, box in ipairs(self.facts) do box:Hide() end
        self.mapCard:Hide()
        self.entranceRow:Hide()
        local showMap = self.showMap and instance and not quest and ns.Data:Map(instance.id) ~= nil
        if showMap then DrawMap(self, instance, y) else view:Hide() end
        if quest then
            self.sub:SetText(QuestSubtitle(instance, quest))
            self.levelLine:Show()
        else
            self.sub:SetText("")
            self.levelLine:Hide()
        end
        if not scrolling then
            if quest then self.levelLine:SetText(LevelText(quest)) end
            self.factSpots = nil
            self.lines = PageLines(self)
            self.maxOffset = MaxOffset(self.lines)
            -- A page drawn anew can be shorter (a section shut while scrolled down).
            self.offset = math.min(self.offset, self.maxOffset)
        end
        local lines = self.lines
        -- Mid-glide the first line sits partly above the top edge.
        local first, lift = Theme:ScrollStart(self.offset, function(i)
            return lines[i] and LineHeight(lines[i]) or 0
        end)
        y = y - lift
        local section = "page"
        for lineIndex = 1, first - 1 do
            if lines[lineIndex].kind == "heading" then section = lines[lineIndex].text end
        end
        local x = Size.pad
        for lineIndex = first, #lines do
            local line = lines[lineIndex]
            local h = LineHeight(line)
            -- A line cut off by the bottom edge still shows the part that fits.
            if y >= bottom then break end
            if line.kind == "facts" and instance then
                DrawFacts(x, y)
            elseif line.kind == "mapcard" then
                local card = self.mapCard
                card:ClearAllPoints()
                card:SetPoint("TOPLEFT", x, -y)
                card:SetSize(width, CARD.HEIGHT)
                card:PlaceArt(width)
                card:Show()
            elseif line.kind == "entrance" then
                local entrance = self.entranceRow
                entrance:ClearAllPoints()
                entrance:SetPoint("TOPLEFT", x, -y)
                entrance:SetSize(width, ENTRANCE_HEIGHT)
                entrance:Fill(instance)
                entrance:Show()
            elseif line.kind == "heading" then
                section = line.text
                DrawHeading(line, x, y, h, width)
            elseif line.kind == "meta" then
                DrawText(line, x, y, h, width, section)
            elseif line.kind == "label" then
                DrawLabel(line, x, y)
            elseif line.kind == "items" then
                DrawItems(line, x, y, width)
            end
            y = y + h
        end
        for kind, pool in pairs(self.pools) do
            HideFrom(pool, (used[kind] or 0) + 1)
        end
        local max = self.maxOffset
        self.offset = math.min(self.offset, max)
        self.scrollBar:Update(self.offset, max, #lines - max)
    end

    function pane:ShowInstance(instance)
        if instance ~= self.instance or self.quest then self.offset = 0 end
        -- Another instance opens on its Overview (Back puts a map back after this).
        if instance ~= self.instance or not (instance and ns.Data:Map(instance.id)) then self.showMap = false end
        self.instance, self.quest = instance, nil
        self:HideSteps()
        self.title:SetText(instance and instance.name or "")
        self:PlaceTitle(instance ~= nil)
        self:Refresh()
    end

    -- Off a quest page (an instance's Overview or map): no chain arrows,
    -- which would jump back to the quest's chain.
    function pane:HideSteps()
        for _, arrow in ipairs(self.steps) do
            arrow.id = nil
            arrow:Hide()
        end
        self.stepRoom = 0
    end

    function pane:ShowQuest(instance, quest)
        if quest ~= self.quest then self.offset = 0 end
        self.instance, self.quest = instance, quest
        -- Merged versions of a quest list every ID they cover.
        local ids = { quest.id }
        for _, id in ipairs(quest.alt or {}) do ids[#ids + 1] = id end
        self.title:SetText(Theme:WithIds(quest.name, ids))
        -- The chain's previous and next steps (the first quest of each).
        local steps, at = Chain.Of(quest)
        local prevID = steps and at and steps[at - 1] and steps[at - 1][1]
        local nextID = steps and at and steps[at + 1] and steps[at + 1][1]
        for i, id in ipairs({ prevID or false, nextID or false }) do
            self.steps[i].id = id or nil
            self.steps[i]:SetShown(id ~= false)
        end
        self.stepRoom = (prevID or nextID) and 84 or 0
        self:PlaceTitle(false, Theme:ClassToken(quest.classes), ns.UI.QuestStartsInside(quest, instance))
        self:Refresh()
    end

    Theme:WheelScroll(pane, function() return pane.maxOffset or MaxOffset() end,
        function(scrolling) pane:Refresh(scrolling) end)
    pane.scrollBar = Theme:ScrollBar(pane, HEADER_HEIGHT, Size.pad, function(offset)
        pane.offset = offset
        pane:Refresh(true)
    end)
    pane:SetScript("OnSizeChanged", pane.Refresh)

    -- A quest handed in elsewhere: the server flags it a moment later.
    -- With the window shut, the page redraws when it next shows instead.
    local function Recheck()
        C_Timer.After(1, function()
            ns.UI.ForgetQuestStatus()
            if pane:IsVisible() then pane:Refresh() else pane.questsStale = true end
        end)
    end
    pane:HookScript("OnShow", function()
        if not pane.questsStale then return end
        pane.questsStale = nil
        if pane.instance or pane.quest then pane:Refresh() end
    end)
    ns:On("QUEST_TURNED_IN", Recheck)
    -- Boss portraits draw once the game has made them.
    ns:On("PORTRAITS_UPDATED", function()
        if view:IsVisible() then pane:Refresh() end
    end)
    ns:On("QUEST_ACCEPTED", Recheck)
    ns:On("QUEST_REMOVED", Recheck)  -- abandoned
    ns:On("PLAYER_LEVEL_UP", Recheck)
    return pane
end
