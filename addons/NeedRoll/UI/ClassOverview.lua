-- The Classes tab's Overview: the page a class opens on (the right pane,
-- in the content pane MainFrame.lua puts round it). Under the class's
-- badge and name, stat boxes answer what to do now, each opening its
-- section's page: Train now (the ranks your trainers teach you at your
-- level and their cost, from the Abilities data), the next level that
-- brings ranks and what it costs, Quests done of the class's quests, and
-- Talents spent of your points. Under them your side's class trainers,
-- nearest first, each a link that pins them on the map, and Coming up: the
-- next levels' ranks, the class quests that open there and the talent
-- points they bring.
-- Another class has no character to read, so its Overview shows only what
-- the data says: its spells and what all their ranks cost, its quests and
-- the plan on show. Its trainers are left out: the trainers of your own
-- side for a class you aren't playing teach you nothing.
local _, ns = ...
local Theme = ns.Theme
local L = ns.L
local Talents = ns.Talents
local ClassSpells = ns.UI.ClassSpells

local HEADING_LEFT = 16      -- the badge, the line under the heading, the boxes and the list, in from the left
local HEADING_TOP = 12       -- the badge, down from the pane's top (as the spell page's heading)
local TITLE_BADGE = 34       -- the class's ring badge before its name
local TITLE_BADGE_GAP = 10   -- between the badge and the name
local SUBTITLE_GAP = 4       -- between the badge and the line under it
local BOXES_TOP = 12         -- between the line under the heading and the stat boxes
local BOX_HEIGHT = 74        -- a stat box: its label, value and a note of up to two lines
local BOX_GAP = 10           -- between two boxes
local BOX_PAD = 12           -- a box's text, in from its sides
local BOX_LABEL_TOP = 8      -- the label, down from the box's top
local BOX_LINE_GAP = 3       -- between the label, the value and the note
local LIST_TOP = 14          -- between the boxes and the list under them
local HEADING_ROW = 30       -- a heading's row in the list
local LINE_ROW = 22          -- a trainer's or a coming level's row
local HEADING_NOTE_GAP = 8   -- between a heading and the note after it
local LEVEL_COLUMN = 30      -- a Coming up row's level, before its text
local RIGHT_INSET = 16       -- a row's right column, in from the list's right
local TEXT_ROOM = 12         -- the least room between a row's text and its right column
local TOGGLE_ARROW = 10      -- the "N more trainers" arrow (as a recipe's)
local TOGGLE_ARROW_GAP = 4   -- between that text and its arrow
local TRAINERS_SHOWN = 5     -- the nearest trainers listed before "N more trainers"
local COMING_LEVELS = 3      -- how many levels that bring ranks Coming up names
local NAMES_SHOWN = 4        -- ranks named on a Coming up row before "and N more"

-- The list's rows, by `kind`: a heading with a note after it, a trainer, the
-- "N more trainers" toggle, a coming level's ranks, a quest that opens at a
-- level, and a line of muted text.
local HEADING, TRAINER, TOGGLE, RANKS, QUEST, NOTE = "HEADING", "TRAINER", "TOGGLE", "RANKS", "QUEST", "NOTE"

local function ClassToken(classID)
    return select(2, GetClassInfo(classID))
end

local function IsPlayerClass(classID)
    return classID == Talents.PlayerClassID()
end

-- Names ----------------------------------------------------------------------------

-- "Frostbolt 7, Ice Armor 2 and 4 more": the first `shown` of `refs`
-- (ClassSpells.Outlook's ranks) by name, the rest counted.
local function RankNames(refs, shown)
    local names = {}
    for i = 1, math.min(shown, #refs) do table.insert(names, ClassSpells.RankName(refs[i])) end
    local text = table.concat(names, ", ")
    if #refs <= shown then return text end
    return L["%s and %d more"]:format(text, #refs - shown)
end

-- What `refs` cost together.
local function RanksCost(refs)
    local cost = 0
    for _, ref in ipairs(refs) do cost = cost + ref.cost end
    return cost
end

-- `refs` with rank 1s (spells new at that level) first, as a level's new
-- spells are what a player looks for.
local function NewSpellsFirst(refs)
    local sorted = {}
    for i, ref in ipairs(refs) do sorted[i] = { ref = ref, index = i } end
    table.sort(sorted, function(a, b)
        local aNew, bNew = a.ref.rank == 1, b.ref.rank == 1
        if aNew ~= bNew then return aNew end
        return a.index < b.index
    end)
    for i, entry in ipairs(sorted) do sorted[i] = entry.ref end
    return sorted
end

-- "3 ranks  ·  1g 40s"
local function RanksText(refs)
    return Theme:JoinDots(Theme:Plural(#refs, L["%d rank"], L["%d ranks"]), ns.Money(RanksCost(refs)))
end

-- Stat boxes ------------------------------------------------------------------------
-- Each box is { label, value, note, open }: `open` is what a click opens
-- (page.onOpen), { section = "ABILITIES", spellTab, filter }, { section =
-- "QUESTS", quest } or { section = "TALENTS" }.

-- The sections' names, for a box's tooltip.
local SECTION_NAMES = { ABILITIES = L["Abilities"], QUESTS = L["Quests"], TALENTS = L["Talents"] }

local function TrainNowBox(outlook)
    local refs = outlook.trainNow
    return {
        label = L["Train now"],
        value = #refs > 0 and RanksText(refs) or L["Nothing to train"],
        note = RankNames(refs, 1),
        open = { section = "ABILITIES", spellTab = ClassSpells.TRAINABLE },
    }
end

local function NextLevelBox(outlook)
    local level = outlook.aheadLevels[1]
    if not level then
        return { label = L["Next level"], value = L["All ranks trained"], open = { section = "ABILITIES" } }
    end
    local refs = NewSpellsFirst(outlook.ahead[level])
    return {
        label = L["Next at %d"]:format(level),
        value = RanksText(refs), note = RankNames(refs, 1),
        open = { section = "ABILITIES", spellTab = refs[1].tab, filter = ClassSpells.FILTER_NEXT },
    }
end

-- Another class: how many spells it has and what all their ranks cost.
local function AbilitiesBox(classID)
    local spells = ClassSpells.Of(classID)
    return {
        label = L["Abilities"],
        value = Theme:Plural(#spells, L["%d spell"], L["%d spells"]),
        note = L["All ranks: %s"]:format(ns.Money(ClassSpells.AllRanksCost(classID))),
        open = { section = "ABILITIES" },
    }
end

-- The quest to do next: the first not completed whose level you have,
-- else the first not completed. Nil once all are done.
local function NextQuest(entries, level)
    local firstOpen
    for _, entry in ipairs(entries) do
        local quest = entry.quest
        if ns.UI.QuestStatus(quest) ~= "Completed" then
            if (quest.minLevel or quest.level or 1) <= level then return quest end
            firstOpen = firstOpen or quest
        end
    end
    return firstOpen
end

-- Your own class: done of total and the quest to do next. Another class:
-- how many quests it has.
local function QuestsBox(classID)
    local token = ClassToken(classID)
    local entries = ns.UI.ClassQuests(token)
    local first = entries[1] and entries[1].quest
    if not IsPlayerClass(classID) then
        return { label = L["Quests"], open = { section = "QUESTS", quest = first },
            value = Theme:Plural(#entries, L["%d quest"], L["%d quests"]) }
    end
    local done, total = ns.UI.ClassQuestsDone(token)
    local nextQuest = NextQuest(entries, ns.PlayerLevel())
    return {
        label = L["Quests"],
        value = L["%d of %d done"]:format(done, total),
        note = nextQuest and L["Next: %s"]:format(nextQuest.name),
        open = { section = "QUESTS", quest = nextQuest or first },
    }
end

-- Your own class: the points you've spent of those your level gives, and
-- the plan the planner shows. Another class: that plan, planned at 60.
local function TalentsBox(classID)
    local plan = Talents:Plan(classID)
    local split = Talents:SplitText(classID, plan)
    local planText = split and L["Plan: %s"]:format(split)
    local box = { label = L["Talents"], open = { section = "TALENTS" } }
    if not IsPlayerClass(classID) then
        box.value = planText
        box.note = L["%d points at level %d"]:format(Talents.PointsAtLevel(Talents.MAX_LEVEL), Talents.MAX_LEVEL)
        return box
    end
    local tree, myRanks = Talents:Tree(classID), Talents:MyRanks(classID)
    local points = Talents.PointsAtLevel(ns.PlayerLevel())
    if tree and myRanks then
        box.value = L["%d of %d spent"]:format(Talents:TotalSpent({ ranks = myRanks }, tree), points)
    else
        box.value = Theme:Plural(points, L["%d point"], L["%d points"])
    end
    box.note = planText
    return box
end

-- The boxes the class shows, left to right.
local function Boxes(classID, outlook)
    if not outlook then return { AbilitiesBox(classID), QuestsBox(classID), TalentsBox(classID) } end
    return { TrainNowBox(outlook), NextLevelBox(outlook), QuestsBox(classID), TalentsBox(classID) }
end

-- A stat box: its label in `factLabel` over its value in `factValue` and a
-- note in `small`, `muted`, on the Overview stat boxes' backdrop. Lit under
-- the mouse; a click opens its section's page (page.onOpen).
local function CreateBox(page)
    local box = CreateFrame("Button", nil, page)
    box:SetHeight(BOX_HEIGHT)
    Theme:StatBackdrop(box)
    box.lit = box:CreateTexture(nil, "HIGHLIGHT")
    box.lit:SetAllPoints()
    box.lit:SetColorTexture(unpack(Theme.color.hover))
    box.label = Theme:Text(box, Theme.font.factLabel)
    box.label:SetPoint("TOPLEFT", BOX_PAD, -BOX_LABEL_TOP)
    box.label:SetPoint("RIGHT", -BOX_PAD, 0)
    box.label:SetJustifyH("LEFT")
    box.label:SetWordWrap(false)
    box.value = Theme:Text(box, Theme.font.factValue)
    box.value:SetPoint("TOPLEFT", box.label, "BOTTOMLEFT", 0, -BOX_LINE_GAP)
    box.value:SetPoint("RIGHT", -BOX_PAD, 0)
    box.value:SetJustifyH("LEFT")
    box.value:SetWordWrap(false)
    box.note = Theme:Text(box, Theme.font.small)
    box.note:SetPoint("TOPLEFT", box.value, "BOTTOMLEFT", 0, -BOX_LINE_GAP)
    box.note:SetPoint("RIGHT", -BOX_PAD, 0)
    box.note:SetJustifyH("LEFT")
    box.note:SetJustifyV("TOP")
    box.note:SetMaxLines(2)
    Theme:SetTextColor(box.note, Theme.color.muted)
    box:RegisterForClicks("LeftButtonUp")
    box:SetScript("OnClick", function(self) page.onOpen(self.info.open) end)
    box:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM", 0, -4)
        GameTooltip:SetText(self.info.label)
        GameTooltip:AddLine(L["Click to open %s"]:format(SECTION_NAMES[self.info.open.section]),
            unpack(Theme.tip.text))
        GameTooltip:Show()
    end)
    box:SetScript("OnLeave", GameTooltip_Hide)
    return box
end

local function FillBox(box, info)
    box.info = info
    box.label:SetText(info.label)
    box.value:SetText(info.value or "")
    box.note:SetText(info.note or "")
end

-- The list: trainers ---------------------------------------------------------------

-- Those of `trainers` who serve your side (or both), each with a map spot.
local function YourSideTrainers(trainers)
    local side, mine = ns.PlayerFaction(), {}
    for _, trainer in ipairs(trainers) do
        local isYours = not trainer.side or trainer.side == side
        if isYours and ns.Data.npcs[trainer.npc] then table.insert(mine, trainer) end
    end
    return mine
end
ns.UI.YourSideTrainers = YourSideTrainers  -- the pet and demon trainers too (UI/HunterPets.lua, WarlockPets.lua)

-- Your side's trainers of class `classID`.
local function YourTrainers(classID)
    local data = ns.Data:ClassSpells(ClassToken(classID))
    return YourSideTrainers(data and data.trainers or {})
end

-- Whether Your trainers lists all of them ("N more trainers" opened), kept
-- as Settings' "Remember sections" says (ns.SectionMemory's "trainers"
-- area, "CLASS": the same for every class).
local function AreAllTrainersShown()
    return ns.SectionMemory.IsOpen(ns.SectionMemory.Area("trainers"), "CLASS")
end

-- "Your trainers  Alliance  ·  listed by distance  ·  Horde trainers hidden",
-- then the nearest TRAINERS_SHOWN trainers (all of them while
-- AreAllTrainersShown), then the toggle when there are more.
local function AddTrainerRows(rows, trainers)
    if #trainers == 0 then return end
    local side = ns.PlayerFaction()
    local otherSide = side == "Alliance" and "Horde" or "Alliance"
    table.insert(rows, { kind = HEADING, height = HEADING_ROW, text = L["Your trainers"],
        note = Theme:JoinDots(ns.SideName(side), L["listed by distance"],
            L["%s trainers hidden"]:format(ns.SideName(otherSide))) })
    local isOpen = AreAllTrainersShown()
    local listed = isOpen and #trainers or math.min(#trainers, TRAINERS_SHOWN)
    for i = 1, listed do table.insert(rows, { kind = TRAINER, height = LINE_ROW, trainer = trainers[i] }) end
    if #trainers <= TRAINERS_SHOWN then return end
    local more = Theme:Plural(#trainers - TRAINERS_SHOWN, L["%d more trainer"], L["%d more trainers"])
    table.insert(rows, { kind = TOGGLE, height = LINE_ROW, isOpen = isOpen,
        text = isOpen and L["Show fewer"] or more })
end

-- The list: coming up -------------------------------------------------------------

-- Your class's quests not completed yet that open above `level` and up to
-- `lastLevel`, each { level, quest }.
local function QuestsOpening(classID, level, lastLevel)
    local opening = {}
    for _, entry in ipairs(ns.UI.ClassQuests(ClassToken(classID))) do
        local quest = entry.quest
        local opensAt = quest.minLevel or quest.level
        local isAhead = opensAt and opensAt > level and opensAt <= lastLevel
        if isAhead and ns.UI.QuestStatus(quest) ~= "Completed" then
            table.insert(opening, { level = opensAt, quest = quest })
        end
    end
    return opening
end

-- "Coming up": a row for each of the next COMING_LEVELS levels that bring
-- ranks (their names and cost), the class quests that open up to the last
-- of them (to the level cap when no level brings ranks any more), then
-- the talent points up to there. With none of these, a line saying so.
local function AddComingUpRows(rows, classID, outlook)
    local level = ns.PlayerLevel()
    local shownLevels = {}
    for i = 1, math.min(COMING_LEVELS, #outlook.aheadLevels) do shownLevels[i] = outlook.aheadLevels[i] end
    local lastLevel = shownLevels[#shownLevels] or Talents.MAX_LEVEL
    local coming = {}
    for _, shownLevel in ipairs(shownLevels) do
        table.insert(coming, { kind = RANKS, height = LINE_ROW, level = shownLevel,
            refs = NewSpellsFirst(outlook.ahead[shownLevel]) })
    end
    for _, opening in ipairs(QuestsOpening(classID, level, lastLevel)) do
        table.insert(coming, { kind = QUEST, height = LINE_ROW, level = opening.level, quest = opening.quest })
    end
    -- By level; at one level its ranks first, then its quests in the list's order.
    for i, row in ipairs(coming) do row.order = i end
    table.sort(coming, function(a, b)
        if a.level ~= b.level then return a.level < b.level end
        return a.order < b.order
    end)
    table.insert(rows, { kind = HEADING, height = HEADING_ROW, text = L["Coming up"] })
    for _, row in ipairs(coming) do table.insert(rows, row) end
    local points = Talents.PointsAtLevel(lastLevel) - Talents.PointsAtLevel(level)
    if points > 0 then
        local phrase = points == 1 and L["+%d talent point by level %d"] or L["+%d talent points by level %d"]
        table.insert(rows, { kind = NOTE, height = LINE_ROW, text = phrase:format(points, lastLevel) })
    end
    if #coming == 0 and points == 0 then
        table.insert(rows, { kind = NOTE, height = LINE_ROW, text = L["Nothing new ahead."] })
    end
end

-- The list's rows for the class shown: your own class's trainers and
-- Coming up, or a line saying why another class has neither.
local function ListRows(page, outlook)
    local rows = {}
    if not outlook then
        table.insert(rows, { kind = NOTE, height = LINE_ROW,
            text = L["Your trainers and what's coming up show on your own class."] })
        return rows
    end
    page.trainers = page.trainers or ns.UI.NearestFirst(YourTrainers(page.classID))
    AddTrainerRows(rows, page.trainers)
    AddComingUpRows(rows, page.classID, outlook)
    return rows
end

-- The list's rows ------------------------------------------------------------------

-- A trainer's name after the giver's mark, as quest pages mark NPCs, in
-- `link` while they have a spot to pin; after it in `muted`, `tag` (what a
-- demon trainer sells for) or else the one tab a trainer teaches (the
-- mage's portal trainers).
local function TrainerText(trainer, fontString, tag)
    local _, size = fontString:GetFont()
    local name = ns.UI.SizeMarkers(ns.UI.GIVER_MARK .. Theme:ColorCode(Theme.color.link) .. trainer.name .. "|r",
        size or 12)
    tag = tag or (trainer.tab and ClassSpells.TabName(trainer.tab))
    if not tag then return name end
    return ("%s  %s%s|r"):format(name, Theme:ColorCode(Theme:Opaque(Theme.color.muted)), tag)
end
-- The hunter's pet trainers and warlock's demon trainers are named the same
-- way (UI/HunterPets.lua, UI/WarlockPets.lua).
ns.UI.TrainerText = TrainerText

local function ShowTrainerTooltip(row)
    local trainer = row.data.trainer
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT", 4, 0)
    GameTooltip:SetText(trainer.name)
    local zone = ns.UI.SourceZone(trainer)
    if zone then GameTooltip:AddLine(zone) end
    GameTooltip:AddLine(L["Click to pin on your map"], unpack(Theme.tip.text))
    GameTooltip:Show()
end
ns.UI.ShowTrainerTooltip = ShowTrainerTooltip  -- the pet and demon trainers' too

local function ShowRanksTooltip(row)
    local refs = row.data.refs
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT", 4, 0)
    GameTooltip:SetText(L["Level %d"]:format(row.data.level))
    for _, ref in ipairs(refs) do
        GameTooltip:AddDoubleLine(ClassSpells.RankName(ref), ns.Money(ref.cost), 1, 1, 1, unpack(Theme.tip.text))
    end
    GameTooltip:Show()
end

local function OnRowEnter(row)
    local kind = row.data and row.data.kind
    if kind == TRAINER then
        ns.UI.HoverMapLink(row, ns.Data.npcs[row.data.trainer.npc])
        ShowTrainerTooltip(row)
    elseif kind == RANKS then
        ShowRanksTooltip(row)
    elseif kind == QUEST then
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT", 4, 0)
        GameTooltip:SetText(row.data.quest.name)
        GameTooltip:AddLine(L["Click to open this quest"], unpack(Theme.tip.text))
        GameTooltip:Show()
    end
end

local function OnRowLeave(row)
    ns.UI.LeaveMapLink(row)
    GameTooltip:Hide()
end

-- A click in combat on a trainer reaches here (out of combat the map pin
-- link's secure button takes it, UI/MainFrame.lua); the toggle opens or
-- shuts the whole trainer list; a quest opens its page.
local function OnRowClick(row, page)
    local entry = row.data
    GameTooltip:Hide()
    if entry.kind == TRAINER then
        ns.UI.ShowOnMap(ns.Data.npcs[entry.trainer.npc], entry.trainer.name)
    elseif entry.kind == TOGGLE then
        ns.SectionMemory.Toggle(ns.SectionMemory.Area("trainers"), "CLASS")
        page:Refresh()
    elseif entry.kind == QUEST then
        page.onOpen({ section = "QUESTS", quest = entry.quest })
    end
end

-- A row of the list: the level (Coming up), the text and the right column,
-- the toggle's arrow, a heading's divider; set up for its kind by SetupRow.
local function CreateRow(column, page)
    local row = Theme:Row(column, LINE_ROW)
    row.divider = Theme:Divider(row)
    row.divider:SetPoint("TOPLEFT", HEADING_LEFT, 0)
    row.divider:SetPoint("TOPRIGHT", -RIGHT_INSET, 0)
    row.level = Theme:Text(row, Theme.font.body)
    row.level:SetPoint("LEFT", HEADING_LEFT, 0)
    row.level:SetWidth(LEVEL_COLUMN)
    row.level:SetJustifyH("LEFT")
    Theme:SetTextColor(row.level, Theme.color.heading)
    row.right = Theme:Text(row, Theme.font.small)
    row.right:SetPoint("RIGHT", -RIGHT_INSET, 0)
    row.right:SetJustifyH("RIGHT")
    row.text = Theme:Text(row, Theme.font.body)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    row.note = Theme:Text(row, Theme.font.small)
    row.note:SetPoint("LEFT", row.text, "RIGHT", HEADING_NOTE_GAP, 0)
    -- Ends at the row's right, so a long note is cut short in a narrow pane.
    row.note:SetPoint("RIGHT", -RIGHT_INSET, 0)
    row.note:SetJustifyH("LEFT")
    row.note:SetWordWrap(false)
    Theme:SetTextColor(row.note, Theme.color.muted)
    row.arrow = Theme:Arrow(row, true, TOGGLE_ARROW)
    row:RegisterForClicks("LeftButtonUp")
    row:HookScript("OnEnter", OnRowEnter)
    row:HookScript("OnLeave", OnRowLeave)
    row:SetScript("OnClick", function(self) OnRowClick(self, page) end)
    return row
end

-- The text's font, color and left edge (after the level column on Coming
-- up's rows), and what the row shows at its right. `isHeading`: the text is
-- only as wide as its words, so the heading's note follows right after them.
local function PlaceRowText(row, font, color, left, rightText, isHeading)
    row.text:SetFontObject(font)
    Theme:SetTextColor(row.text, color)
    row.text:ClearAllPoints()
    row.text:SetPoint("LEFT", left, 0)
    row.right:SetText(rightText or "")
    Theme:SetTextColor(row.right, Theme.color.muted)
    if isHeading then return end
    if rightText then
        row.text:SetPoint("RIGHT", row.right, "LEFT", -TEXT_ROOM, 0)
    else
        row.text:SetPoint("RIGHT", -RIGHT_INSET, 0)
    end
end

local function SetupRow(row, entry)
    local kind = entry.kind
    local isLevelRow = kind == RANKS or kind == QUEST
    local textLeft = HEADING_LEFT + (isLevelRow and LEVEL_COLUMN or 0)
    row.level:SetText(isLevelRow and tostring(entry.level) or "")
    row.note:SetText(kind == HEADING and entry.note or "")
    row.arrow:SetShown(kind == TOGGLE)
    -- The list's sections come under the stat boxes, so every heading has
    -- the divider over it.
    row.divider:SetShown(kind == HEADING)
    row:EnableMouse(kind ~= HEADING and kind ~= NOTE)
    if kind == HEADING then
        PlaceRowText(row, Theme.font.section, Theme.color.heading, HEADING_LEFT, nil, true)
        row.text:SetText(entry.text)
    elseif kind == TRAINER then
        PlaceRowText(row, Theme.font.body, Theme.color.text, HEADING_LEFT, ns.UI.SourceZone(entry.trainer))
        row.text:SetText(TrainerText(entry.trainer, row.text))
    elseif kind == TOGGLE then
        PlaceRowText(row, Theme.font.body, Theme.color.heading, HEADING_LEFT)
        row.text:SetText(entry.text)
        row.arrow:SetOpen(entry.isOpen)
        row.arrow:ClearAllPoints()
        row.arrow:SetPoint("LEFT", row.text, "LEFT", math.ceil(row.text:GetStringWidth()) + TOGGLE_ARROW_GAP, 0)
    elseif kind == RANKS then
        PlaceRowText(row, Theme.font.body, Theme.color.text, textLeft, ns.Money(RanksCost(entry.refs)))
        row.text:SetText(RankNames(entry.refs, NAMES_SHOWN))
    elseif kind == QUEST then
        PlaceRowText(row, Theme.font.body, Theme.color.quest, textLeft, L["Class quest"])
        row.text:SetText(entry.quest.name)
    else
        PlaceRowText(row, Theme.font.small, Theme.color.muted, HEADING_LEFT)
        row.text:SetText(entry.text)
    end
    if GameTooltip:IsOwned(row) then OnRowEnter(row) end
end

-- The page -------------------------------------------------------------------------

-- The heading: the class's ring badge and name, and the line under it
-- (page.badge, page.title, page.subtitle). The pet pages' heading is the
-- same, the family's icon in the ring (UI/HunterPets.lua).
function ns.UI.CreateBadgeHeading(page)
    page.badge = Theme:ClassBadge(page, TITLE_BADGE)
    page.badge:SetPoint("TOPLEFT", HEADING_LEFT, -HEADING_TOP)
    page.title = Theme:Text(page, Theme.font.instance)
    page.title:SetPoint("LEFT", page.badge, "RIGHT", TITLE_BADGE_GAP, 0)
    page.subtitle = Theme:Text(page, Theme.font.body)
    page.subtitle:SetPoint("TOPLEFT", page.badge, "BOTTOMLEFT", 0, -SUBTITLE_GAP)
    page.subtitle:SetPoint("RIGHT", -HEADING_LEFT, 0)
    page.subtitle:SetJustifyH("LEFT")
    page.subtitle:SetWordWrap(false)
    Theme:SetTextColor(page.subtitle, Theme.color.muted)
end

-- How far down the page that heading reaches: the bottom of the line under it.
function ns.UI.BadgeHeadingBottom(page)
    return HEADING_TOP + TITLE_BADGE + SUBTITLE_GAP + Theme:LineHeight(page.subtitle)
end

-- The line under the heading. Your own class: "6 of 47 spells trained  ·
-- To level 60: 45g 27s". Another class: "47 spells  ·  Alliance and Horde".
local function SubtitleText(classID, outlook)
    if not outlook then
        local spellCount = #ClassSpells.Of(classID)
        return Theme:JoinDots(Theme:Plural(spellCount, L["%d spell"], L["%d spells"]), L["Alliance and Horde"])
    end
    local leftText = outlook.leftCost > 0
        and L["To level %d: %s"]:format(Talents.MAX_LEVEL, ns.Money(outlook.leftCost)) or nil
    return Theme:JoinDots(L["%d of %d spells trained"]:format(outlook.trained, outlook.total), leftText)
end

-- The page. `parent` is the Classes tab; MainFrame.lua hosts the page in
-- the tab's content pane, with its strip. page.onOpen(target) opens what a
-- box or a quest row names (UI/Classes.lua; see Stat boxes above).
function ns.UI.CreateClassOverview(parent)
    local page = CreateFrame("Frame", nil, parent)
    page.onOpen = function() end
    ns.UI.CreateBadgeHeading(page)
    page.boxes = {}
    page.column = Theme:ScrollColumn(page, function(column) return CreateRow(column, page) end, SetupRow)
    page.levelLine = Theme:Text(page, Theme.font.body)
    Theme:SetTextColor(page.levelLine, Theme.color.muted)

    -- "Level 38  ·  Alliance" at the strip's right on your own class, as
    -- the spellbook tab pages have it.
    function page:PlaceStrip(strip)
        self.levelLine:SetParent(strip)
        self.levelLine:SetPoint("RIGHT", -(Theme.size.pad - 4), 0)
    end

    -- The boxes side by side across the page, as wide as the room allows.
    function page:LayOutBoxes()
        local shown = self.shownBoxes or 0
        if shown == 0 then return end
        local room = self:GetWidth() - HEADING_LEFT * 2 - BOX_GAP * (shown - 1)
        local width = math.max(1, room / shown)
        for i = 1, shown do
            local box = self.boxes[i]
            box:ClearAllPoints()
            box:SetPoint("TOPLEFT", self.subtitle, "BOTTOMLEFT", (i - 1) * (width + BOX_GAP), -BOXES_TOP)
            box:SetWidth(width)
        end
    end
    page:SetScript("OnSizeChanged", function(self) self:LayOutBoxes() end)

    function page:ShowBoxes(infos)
        for i, info in ipairs(infos) do
            self.boxes[i] = self.boxes[i] or CreateBox(self)
            FillBox(self.boxes[i], info)
            self.boxes[i]:Show()
        end
        for i = #infos + 1, #self.boxes do self.boxes[i]:Hide() end
        self.shownBoxes = #infos
        self:LayOutBoxes()
        -- Hung from the page itself, not from the boxes: trainer rows hold
        -- map links' secure buttons and the boxes hang from a text
        -- (Theme:LineHeight).
        local top = ns.UI.BadgeHeadingBottom(self) + BOXES_TOP
            + BOX_HEIGHT + LIST_TOP
        self.column:ClearAllPoints()
        self.column:SetPoint("TOPLEFT", 0, -top)
        self.column:SetPoint("BOTTOMRIGHT")
    end

    -- The spells the page names whose names the game hasn't sent yet,
    -- redrawn once they arrive.
    function page:LoadNames(outlook)
        if not outlook then return end
        local spellIDs = {}
        for _, ref in ipairs(outlook.trainNow) do table.insert(spellIDs, ref.spellID) end
        for i = 1, math.min(COMING_LEVELS, #outlook.aheadLevels) do
            for _, ref in ipairs(outlook.ahead[outlook.aheadLevels[i]]) do table.insert(spellIDs, ref.spellID) end
        end
        ClassSpells.Load(spellIDs, function()
            if self:IsVisible() then self:Refresh() end
        end)
    end

    -- Redraws the class shown for the player as they are now: the heading,
    -- the boxes and the list, keeping its scroll while the class stays.
    function page:Refresh()
        local classID = self.classID
        if not classID then return end
        local name, token = GetClassInfo(classID)
        local outlook = IsPlayerClass(classID) and ClassSpells.Outlook(classID, ns.PlayerLevel()) or nil
        self.badge:SetClass(token)
        self.title:SetText(name or "")
        self.subtitle:SetText(SubtitleText(classID, outlook))
        self.levelLine:SetText(outlook and Theme:JoinDots(L["Level %d"]:format(ns.PlayerLevel()),
            ns.SideName(ns.PlayerFaction())) or "")
        self:ShowBoxes(Boxes(classID, outlook))
        self.column:SetData(ListRows(self, outlook), classID == self.shownClassID)
        self.shownClassID = classID
        self:LoadNames(outlook)
    end

    -- Shows class `classID`. Your trainers are put nearest first each time
    -- the page is shown, as the player moves between showings.
    function page:ShowClass(classID)
        self.classID = classID
        self.trainers = nil
        self:Refresh()
    end

    -- The setting changed: the trainer list shows as the new set has it.
    ns.SectionMemory.OnModeChange(function()
        if page:IsVisible() then page:Refresh() end
    end)
    return page
end
