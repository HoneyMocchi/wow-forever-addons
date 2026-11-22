-- The Classes tab's talent planner (the right pane under Talents > Planner):
-- the class's three trees side by side over the game's own talent art, each
-- talent's rank on it, and the classic rules for planning points (see
-- Core/Talents.lua). Hovering a talent shows the game's own text for its
-- planned rank, so no talent text ships with NeedRoll. The strip's Import and Export pills
-- read and write a plan as a share string (see Core/Talents.lua), and Link
-- puts it in chat as a line other NeedRoll players can click
-- (UI/TalentLinks.lua).
local _, ns = ...
local Theme = ns.Theme
local Size = Theme.size
local L = ns.L
local Talents = ns.Talents

local STRIP_INSET = Size.pad - 4  -- Import, from the strip's left end (as Back's)
local STRIP_BUTTON_GAP = 6        -- between two of Import, Export, Link, Reset and My talents
local SHARE_DIALOG_WIDTH = 520    -- Import and Export, as wide as the Wishlist's
local IMPORT_DIALOG_HEIGHT = 190  -- Import, and Export with a line saying what went wrong
local EXPORT_DIALOG_HEIGHT = 150
local NOTICE_DIALOG_WIDTH = 420   -- the notice before linking where chat links don't work
local NOTICE_DIALOG_HEIGHT = 150
local SHARE_INPUT_GAP = 12        -- between a dialog's hint and its text box
local IMPORT_PROBLEM_GAP = 10     -- between Import's text box and the line saying what's wrong
local HEADING_TOP = 12            -- "Your talents", down from the pane's top
local HEADING_LEFT = 16            -- the heading and the line under it, in from the pane's left
local LINE_GAP = 4                -- between the heading, the points line and the line about the plan
local SPLIT_GAP = 10              -- between the heading and the points per tree
local TREES_GAP = 16              -- between the line about the plan and the trees
local TREES_INSET = 12            -- the trees, in from the pane's sides and bottom
local TREE_GAP = 8                -- between two trees
local TREE_HEADER = 28            -- a tree's name and points, across its top
local TREE_TEXT_INSET = 10        -- the name and points, in from the tree's sides
local TREE_SIDE_ROOM = 8          -- the least room left and right of a tree's grid
local STEP_MOST = 46              -- the grid step at its largest (between two talents' centres)
local NODE_OF_STEP = 0.74         -- a talent's icon, of the grid step
local NODE_LEAST, NODE_MOST = 18, 34  -- a talent's icon, smallest and largest
local NODE_EDGE = 2               -- the coloured frame round a talent's icon
local RANK_PAD = 3                -- the rank badge's black backdrop, past its text (centred on the icon's corner)
local LINE_WIDTH = 3              -- a prerequisite's line
local LINE_ALPHA = 0.55
-- The trees' edge: the section card's outline (sectionEdge), solid down a
-- fifth of the tree, then fading to clear at the bottom.
local TREE_EDGE_SOLID, TREE_EDGE_END = 0.2, 1
-- Forever's own talent window draws each class's art from one atlas, all
-- three trees in one picture.
local BACKGROUND_ATLAS = "talent-background-%s"
-- A talent's state, the same in every style: maxed (the game's gold), has
-- points or can take one (green), its row not open yet (grey).
local MAXED_COLOR = { 1, 0.82, 0 }
local OPEN_COLOR = { 0.25, 0.75, 0.25 }
local LOCKED_COLOR = { 0.33, 0.33, 0.33 }
local LOCKED_TEXT = { 0.53, 0.53, 0.53 }
local LINE_OFF_COLOR = { 0.5, 0.5, 0.5 }
-- The share dialog's hint: for Export, and for a chat link that couldn't be saved.
local EXPORT_HINT = L["Press Ctrl+C to copy, then paste it in chat. Other NeedRoll players paste it into Import."]
local UNSAVED_HINT = L["NeedRoll couldn't save this plan. Press Ctrl+C to copy it, then paste it into Import later."]
-- What the notice before linking says inside an instance and in combat.
local INSTANCE_NOTICE = L["WoW: Forever hides addon chat links inside dungeons and raids."] .. " "
    .. L["While you're in one, your plan shows as a plain import string others can paste into NeedRoll's Import."]
local COMBAT_NOTICE = L["WoW: Forever hides addon chat links in combat."] .. " "
    .. L["Until combat ends, your plan shows as a plain import string others can paste into NeedRoll's Import."]

-- The class's localized name and its token ("MAGE").
local function ClassNames(classID)
    local name, token = GetClassInfo(classID)
    return name or "", token or ""
end

-- The points line under the heading: "Level 60  ·  51 points  ·  0 left", the
-- numbers gold and what's left green.
local function PointsText(level, points, left)
    local gold, green = Theme:ColorCode(MAXED_COLOR), Theme:ColorCode(OPEN_COLOR)
    return L["Level %s  ·  %s points  ·  %s left"]:format(gold .. level .. "|r", gold .. points .. "|r",
        green .. left .. "|r")
end

-- Talent buttons ------------------------------------------------------------

-- What a talent's tooltip adds under the game's text: its rank, and
-- what it still waits for. A set of prerequisites any one of which is
-- enough reads "Requires 5 points in Starlight Wrath", then "or 5 points in
-- Genesis" for each other.
local function AddNodeLines(plan, node)
    GameTooltip:AddLine(L["Rank %d/%d"]:format(Talents.Rank(plan, node), node.maxRanks), unpack(Theme.tip.info))
    local red = Theme.color.incomplete
    local rowNeeds = Talents.RowPoints(node)
    if Talents:GroupSpent(plan, node.group, node.row) < rowNeeds then
        GameTooltip:AddLine(L["Requires %d points in %s"]:format(rowNeeds, node.group.name), red[1], red[2], red[3])
    end
    for _, set in ipairs(Talents.UnmetPrerequisites(plan, node)) do
        for i, needed in ipairs(set) do
            local name = C_Spell.GetSpellName(needed.spellID) or ""
            local line = i == 1 and L["Requires %d points in %s"] or L["or %d points in %s"]
            GameTooltip:AddLine(line:format(needed.maxRanks, name), red[1], red[2], red[3])
        end
    end
end

-- A tooltip data line's colour as r, g, b: the game's colour where it gives
-- one, else the fallback's (a { r, g, b } list).
local function LineColor(color, fallback)
    if type(color) == "table" and color.r then return color.r, color.g, color.b end
    return fallback[1], fallback[2], fallback[3]
end

-- The game's tooltip lines for a talent entry at a rank (C_TooltipInfo), the
-- ones NeedRoll may read, or nil when the game has none. Their text could
-- come back secret like other tooltip text (see ns.Plain), so a line that
-- does is left out. A first line that only repeats the talent's name is
-- dropped too, since the tooltip's title already says it.
local function EntryLines(node, rank)
    if not (node.entryID and C_TooltipInfo.GetTraitEntry) then return nil end
    local ok, data = pcall(C_TooltipInfo.GetTraitEntry, node.entryID, rank)
    local lines = ok and type(data) == "table" and type(data.lines) == "table" and data.lines or {}
    local name = ns.Plain(C_Spell.GetSpellName(node.spellID))
    local readable = {}
    for index, line in ipairs(lines) do
        local left = ns.Plain(line.leftText)
        local isNameLine = index == 1 and left == name
        if type(left) == "string" and not isNameLine then
            table.insert(readable, { left = left, right = ns.Plain(line.rightText),
                leftColor = line.leftColor, rightColor = line.rightColor })
        end
    end
    if #readable == 0 then return nil end
    return readable
end

-- Adds entry lines to the tooltip with the game's colours, the long
-- description lines wrapped; a line with right-hand text (a cost, a range)
-- as a double line.
local function AddEntryLines(lines)
    local white = Theme.tip.text
    for _, line in ipairs(lines) do
        local r, g, b = LineColor(line.leftColor, white)
        if type(line.right) == "string" and line.right ~= "" then
            local rightR, rightG, rightB = LineColor(line.rightColor, white)
            GameTooltip:AddDoubleLine(line.left, line.right, r, g, b, rightR, rightG, rightB)
        else
            GameTooltip:AddLine(line.left, r, g, b, true)
        end
    end
end

-- Opens the tooltip on a talent with its name and the game's text at the
-- planned rank, as its own talent window shows it: rank 1's before any point
-- is planned. The lines are copied from C_TooltipInfo rather than shown with
-- GameTooltip:SetTraitEntry, because the game rebuilds a tooltip it fills
-- itself, wiping the lines added after it and the anchor. True when it shows
-- the entry's text; a client without it gets the spell's (rank 1's values).
local function SetNodeText(button, plan)
    local node = button.node
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    local lines = EntryLines(node, math.max(Talents.Rank(plan, node), 1))
    if not lines then
        GameTooltip:SetSpellByID(node.spellID)
        return false
    end
    local name = ns.Plain(C_Spell.GetSpellName(node.spellID))
    if name then GameTooltip:AddLine(name, unpack(Theme.tip.text)) end
    AddEntryLines(lines)
    return true
end

-- "Next Rank:" and the next rank's entry text, for a talent planned part way.
local function AddNextRankText(plan, node)
    local rank = Talents.Rank(plan, node)
    if rank == 0 or rank >= node.maxRanks then return end
    local lines = EntryLines(node, rank + 1)
    if not lines then return end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(TALENT_BUTTON_TOOLTIP_NEXT_RANK, unpack(Theme.tip.text))
    AddEntryLines(lines)
end

--[==[@debug@
-- Local checkouts: the talent's node ID and grid spot, and each edge into it
-- with the game's edge type (Enum.TraitEdgeType: 0 VisualOnly, 2 Sufficient,
-- 3 Required), to check the planner's rules against a tree in game.
local function AddDevLines(node)
    local quiet = Theme.tip.quiet
    GameTooltip:AddLine(("Node %d  ·  row %d, column %d"):format(node.id, node.row, node.column), unpack(quiet))
    for _, edge in ipairs(node.edgesIn) do
        local from = edge.from
        GameTooltip:AddLine(("Edge from node %d (row %d, column %d), type %s"):format(from.id, from.row,
            from.column, tostring(edge.type)), unpack(quiet))
    end
end
--@end-debug@]==]

local function ShowNodeTooltip(button)
    local plan = Talents:Plan(button.classID)
    if not (plan and button.node) then return end
    local hasEntryText = SetNodeText(button, plan)
    AddNodeLines(plan, button.node)
    if hasEntryText then AddNextRankText(plan, button.node) end
    --[==[@debug@
    AddDevLines(button.node)
    --@end-debug@]==]
    GameTooltip:Show()
end

-- Click adds a point, right-click takes one back; the tooltip follows.
local function OnNodeClick(button, mouseButton)
    if mouseButton == "RightButton" then
        Talents:Remove(button.classID, button.node)
    else
        Talents:Add(button.classID, button.node)
    end
    if button:IsMouseOver() then ShowNodeTooltip(button) end
end

local function CreateNodeButton(panel)
    local button = CreateFrame("Button", nil, panel)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button.edge = button:CreateTexture(nil, "BORDER")
    button.edge:SetAllPoints()
    button.edge:SetColorTexture(1, 1, 1, 1)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", NODE_EDGE, -NODE_EDGE)
    button.icon:SetPoint("BOTTOMRIGHT", -NODE_EDGE, NODE_EDGE)
    Theme:CropIcon(button.icon)
    button.rank = Theme:Text(button, Theme.font.small)
    button.rank:SetPoint("CENTER", button, "BOTTOMRIGHT", 0, 0)
    button.rankBack = button:CreateTexture(nil, "OVERLAY", nil, -1)
    button.rankBack:SetColorTexture(0, 0, 0, 0.85)
    button.rankBack:SetPoint("TOPLEFT", button.rank, "TOPLEFT", -RANK_PAD, 1)
    button.rankBack:SetPoint("BOTTOMRIGHT", button.rank, "BOTTOMRIGHT", RANK_PAD, -1)
    button:SetScript("OnClick", OnNodeClick)
    button:SetScript("OnEnter", ShowNodeTooltip)
    button:SetScript("OnLeave", GameTooltip_Hide)
    return button
end

-- Colours a talent for its state: the edge and rank gold when maxed, green
-- when it has points or can take one, grey (and its icon greyed) while its
-- row isn't open or its prerequisites aren't met.
local function PaintNode(button, plan)
    local node = button.node
    local rank = Talents.Rank(plan, node)
    local isMaxed = rank >= node.maxRanks
    local isOpen = rank > 0 or Talents:IsOpen(plan, node)
    local edge = isMaxed and MAXED_COLOR or isOpen and OPEN_COLOR or LOCKED_COLOR
    button.edge:SetVertexColor(edge[1], edge[2], edge[3], 1)
    button.icon:SetDesaturation(rank > 0 and 0 or isOpen and 0.5 or 1)
    local shade = rank > 0 and 1 or isOpen and 0.85 or 0.55
    button.icon:SetVertexColor(shade, shade, shade)
    button.rank:SetText(("%d/%d"):format(rank, node.maxRanks))
    local text = isMaxed and MAXED_COLOR or isOpen and OPEN_COLOR or LOCKED_TEXT
    button.rank:SetTextColor(text[1], text[2], text[3])
end

-- Trees -----------------------------------------------------------------------

-- One tree's panel: the art behind it, its edge, its name and points, and
-- pools of talent buttons and prerequisite lines.
local function CreateTreePanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel.art = panel:CreateTexture(nil, "BACKGROUND")
    panel.art:SetAllPoints()
    panel.edge = Theme:SectionCard(panel, { noFill = true, edgeSolid = TREE_EDGE_SOLID, edgeEnd = TREE_EDGE_END })
    panel.name = Theme:Text(panel, Theme.font.pane)
    panel.name:SetPoint("LEFT", panel, "TOPLEFT", TREE_TEXT_INSET, -TREE_HEADER / 2)
    panel.spent = Theme:Text(panel, Theme.font.body)
    panel.spent:SetPoint("RIGHT", panel, "TOPRIGHT", -TREE_TEXT_INSET, -TREE_HEADER / 2)
    Theme:SetTextColor(panel.spent, Theme.color.muted)
    panel.buttons, panel.lines = {}, {}
    return panel
end

-- The grid step and icon size that fit `tree` in a panel `width` by `height`.
local function GridFor(tree, width, height)
    local across = (width - TREE_SIDE_ROOM * 2) / math.max(1, tree.columns)
    local down = (height - TREE_HEADER) / math.max(1, tree.rows)
    local step = math.min(STEP_MOST, across, down)
    local node = math.max(NODE_LEAST, math.min(NODE_MOST, math.floor(step * NODE_OF_STEP)))
    return step, node
end

-- Where a talent's centre sits in its panel.
local function NodeCentre(node, grid)
    return grid.left + (node.column - 0.5) * grid.step, TREE_HEADER + (node.row - 0.5) * grid.step
end

-- A line along each edge the game draws into a talent, under the buttons,
-- whether or not the edge gates it.
local function LayLines(panel, group, grid)
    local count = 0
    for _, node in ipairs(group.nodes) do
        local toX, toY = NodeCentre(node, grid)
        for _, edge in ipairs(node.edgesIn) do
            local needed = edge.from
            count = count + 1
            local line = panel.lines[count] or panel:CreateLine(nil, "ARTWORK")
            panel.lines[count] = line
            local fromX, fromY = NodeCentre(needed, grid)
            line:SetThickness(LINE_WIDTH)
            line:SetColorTexture(1, 1, 1, 1)
            line:SetStartPoint("TOPLEFT", panel, fromX, -fromY)
            line:SetEndPoint("TOPLEFT", panel, toX, -toY)
            line.from = needed
            line:Show()
        end
    end
    for i = count + 1, #panel.lines do panel.lines[i]:Hide() end
end

local function LayButtons(panel, group, grid, classID)
    for i, node in ipairs(group.nodes) do
        local button = panel.buttons[i] or CreateNodeButton(panel)
        panel.buttons[i] = button
        button.node, button.classID = node, classID
        button:SetSize(grid.node, grid.node)
        local x, y = NodeCentre(node, grid)
        button:ClearAllPoints()
        button:SetPoint("CENTER", panel, "TOPLEFT", x, -y)
        button.icon:SetTexture(node.icon)
        button:Show()
    end
    for i = #group.nodes + 1, #panel.buttons do panel.buttons[i]:Hide() end
end

-- Lays one tree out in its panel, `width` by `height`.
local function LayTree(panel, group, tree, classID, width, height)
    local step, node = GridFor(tree, width, height)
    local grid = { step = step, node = node, left = (width - tree.columns * step) / 2 }
    panel.name:SetText(group.name)
    LayLines(panel, group, grid)
    LayButtons(panel, group, grid, classID)
    panel.edge:Draw(panel, 0, 0, width, height)
end

-- Shows the class's art across the trees, scaled to cover them all and
-- cropped evenly (never stretched): each panel shows its own slice of the
-- one picture, so it reads as the game's window does.
local function CropArt(panels, count, token, width, height)
    local info = C_Texture.GetAtlasInfo(BACKGROUND_ATLAS:format(token:lower()))
    local file = info and (info.file or info.filename)
    for i = 1, count do panels[i].art:SetShown(file ~= nil) end
    if not file or info.width <= 0 or info.height <= 0 then return end
    local scale = math.max(width / info.width, height / info.height)
    local spanU, spanV = width / (info.width * scale), height / (info.height * scale)
    local startU, startV = (1 - spanU) / 2, (1 - spanV) / 2
    local fileSpanU = info.rightTexCoord - info.leftTexCoord
    local fileSpanV = info.bottomTexCoord - info.topTexCoord
    local top = info.topTexCoord + fileSpanV * startV
    local bottom = info.topTexCoord + fileSpanV * (startV + spanV)
    local panelWidth = (width - TREE_GAP * (count - 1)) / count
    for i = 1, count do
        local fromX = (i - 1) * (panelWidth + TREE_GAP)
        local left = info.leftTexCoord + fileSpanU * (startU + spanU * fromX / width)
        local right = info.leftTexCoord + fileSpanU * (startU + spanU * (fromX + panelWidth) / width)
        panels[i].art:SetTexture(file)
        panels[i].art:SetTexCoord(left, right, top, bottom)
    end
end

-- The pane ----------------------------------------------------------------------

-- The heading over the trees: "Your talents" with the points in each tree;
-- under it the points line, and under that the line saying where the plan
-- came from. The points line sits here, not on the strip, so the strip's
-- five pills have room even in the narrowest window.
local function CreateHeading(page)
    page.title = Theme:Text(page, Theme.font.instance)
    page.title:SetPoint("TOPLEFT", HEADING_LEFT, -HEADING_TOP)
    page.split = Theme:Text(page, Theme.font.body)
    page.split:SetPoint("BOTTOMLEFT", page.title, "BOTTOMRIGHT", SPLIT_GAP, 2)
    Theme:SetTextColor(page.split, Theme.color.muted)
    page.points = Theme:Text(page, Theme.font.body)
    page.points:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -LINE_GAP)
    page.subtitle = Theme:Text(page, Theme.font.body)
    page.subtitle:SetPoint("TOPLEFT", page.points, "BOTTOMLEFT", 0, -LINE_GAP)
    -- It wraps in a narrow pane rather than running past its edge; the trees
    -- hang under it, so a second line moves them down.
    page.subtitle:SetPoint("RIGHT", page, "RIGHT", -HEADING_LEFT, 0)
    page.subtitle:SetJustifyH("LEFT")
    Theme:SetTextColor(page.subtitle, Theme.color.muted)
    page.empty = Theme:Text(page, Theme.font.body)
    page.empty:SetPoint("CENTER", page.trees, "CENTER")
    page.empty:SetText(L["This class's talents aren't available yet. Try again in a moment."])
    Theme:SetTextColor(page.empty, Theme.color.muted)
end

-- Share strings ----------------------------------------------------------------

-- The text box both dialogs show the string in, under the dialog's hint.
local function AddShareInput(box)
    box.input = Theme:Input(box, SHARE_DIALOG_WIDTH - Size.pad * 2)
    box.input:SetPoint("TOPLEFT", box.hint, "BOTTOMLEFT", Theme.native and 6 or 0, -SHARE_INPUT_GAP)
end

-- The line under the text box saying what's wrong (box.problem).
local function AddShareProblem(box)
    box.problem = Theme:Text(box, Theme.font.small)
    box.problem:SetPoint("TOPLEFT", box.input, "BOTTOMLEFT", Theme.native and -6 or 0, -IMPORT_PROBLEM_GAP)
    box.problem:SetWidth(SHARE_DIALOG_WIDTH - Size.pad * 2)
    box.problem:SetJustifyH("LEFT")
    Theme:SetTextColor(box.problem, Theme.color.incomplete)
end

-- Export: the plan on screen as a share string, selected for Ctrl+C.
-- Typing in the box puts the string back. A chat link that couldn't be
-- saved opens it too (box:PresentUnsaved), with the reason under the box.
local function CreateExportDialog(owner)
    local box = Theme:Dialog(owner, SHARE_DIALOG_WIDTH, EXPORT_DIALOG_HEIGHT, L["Export"])
    box:AddHint()
    AddShareInput(box)
    AddShareProblem(box)
    box.input:SetScript("OnTextChanged", function(self, userInput)
        if userInput and self:GetText() ~= box.text then
            self:SetText(box.text)
            self:HighlightText()
        end
    end)
    box.input:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    box.input:SetScript("OnEscapePressed", function() box:Close() end)
    box.input:SetScript("OnEnterPressed", function() box:Close() end)
    box:Buttons(nil)
    box.cancel:SetLabel(L["Done"])
    -- Shows `text` selected, and `problem` under it when there is one.
    function box:ShowString(text, problem)
        self.text = text or ""
        self.problem:SetText(problem or "")
        self:SetHeight(problem and IMPORT_DIALOG_HEIGHT or EXPORT_DIALOG_HEIGHT)
        self:Open()
        self.input:SetText(self.text)
        self.input:SetFocus()
        self.input:HighlightText()
    end
    function box:Present(classID)
        self.title:SetText(L["Export"])
        self.hint:SetText(EXPORT_HINT)
        self:ShowString(Talents:Export(classID))
    end
    function box:PresentUnsaved(text, problem)
        self.title:SetText(L["Talent plan"])
        self.hint:SetText(UNSAVED_HINT)
        self:ShowString(text, problem)
    end
    return box
end

-- What a finished import says on the status line: the class it was for, and
-- how many points didn't fit the rules.
local function ImportedText(classID, leftOut)
    local className = ClassNames(classID)
    if leftOut > 0 then
        return L["Imported a %s plan; %d points broke the talent rules and were left out."]:format(className, leftOut)
    end
    return L["Imported a %s plan."]:format(className)
end

-- Import: a pasted share string loads into its class's planner (the class
-- list switching to it) as an unsaved plan. Anything wrong with the text
-- shows as a calm line in the dialog.
local function CreateImportDialog(owner, onImported)
    local box = Theme:Dialog(owner, SHARE_DIALOG_WIDTH, IMPORT_DIALOG_HEIGHT, L["Import"])
    box:AddHint(L["Paste a talent plan another NeedRoll player exported."])
    AddShareInput(box)
    AddShareProblem(box)
    local function Import()
        local classID, result = Talents:Import(box.input:GetText())
        if not classID then
            box.problem:SetText(result)
            return
        end
        box:Close()
        onImported(classID, ImportedText(classID, result))
    end
    box:Buttons(L["Import"], Import)
    box.input:SetScript("OnEnterPressed", Import)
    box.input:SetScript("OnEscapePressed", function() box:Close() end)
    box.input:SetScript("OnTextChanged", function() box.problem:SetText("") end)
    function box:Present()
        self.input:SetText("")
        self.problem:SetText("")
        self:Open()
        self.input:SetFocus()
    end
    return box
end

-- Linking a plan in chat: Forever skips addons' chat filters for lines
-- whose sender is secret, as every line is inside a dungeon or raid and in
-- combat, so there no one's NeedRoll can turn the line into a link. This
-- says so before the plain line goes in; OK puts it in the chat box.
local function CreateLinkNotice(owner)
    local box = Theme:Dialog(owner, NOTICE_DIALOG_WIDTH, NOTICE_DIALOG_HEIGHT, L["Link in chat"])
    box:AddHint()
    box.hint:SetWidth(NOTICE_DIALOG_WIDTH - Size.pad * 2)
    box.hint:SetJustifyH("LEFT")
    box:Buttons(L["OK"], function()
        box:Close()
        ns.UI.TypeInChat(box.line)
    end)
    function box:Present(line, isInInstance)
        self.line = line
        self.hint:SetText(isInInstance and INSTANCE_NOTICE or COMBAT_NOTICE)
        self:Open()
    end
    return box
end

-- Import, Export, Link, Reset and My talents, for the strip's left.
local function CreateStripButtons(page)
    page.import = Theme:Pill(page)
    page.import:SetLabel(L["Import"])
    page.import:SetScript("OnClick", function() page.importDialog:Present() end)
    page.export = Theme:Pill(page)
    page.export:SetLabel(L["Export"])
    page.export:SetScript("OnClick", function() page.exportDialog:Present(page.classID) end)
    page.link = Theme:Pill(page)
    page.link:SetLabel(L["Link"])
    page.link:SetScript("OnClick", function() page:LinkInChat(page.classID) end)
    page.reset = Theme:Pill(page)
    page.reset:SetLabel(L["Reset"])
    page.reset:SetScript("OnClick", function() Talents:Reset(page.classID) end)
    page.mine = Theme:Pill(page)
    page.mine:SetLabel(L["My talents"])
    page.mine:SetScript("OnClick", function() Talents:LoadMine(page.classID) end)
end

-- The planner page. `parent` is the Classes tab: its dialogs open over the
-- whole tab, and an import shows its class there (tab:PickClass).
function ns.UI.CreateTalentPlanner(parent)
    local page = CreateFrame("Frame", nil, parent)
    page.trees = CreateFrame("Frame", nil, page)
    page.panels = {}
    CreateHeading(page)
    page.trees:SetPoint("TOPLEFT", page.subtitle, "BOTTOMLEFT", TREES_INSET - HEADING_LEFT, -TREES_GAP)
    page.trees:SetPoint("BOTTOMRIGHT", -TREES_INSET, TREES_INSET)
    CreateStripButtons(page)
    page.exportDialog = CreateExportDialog(parent)
    page.importDialog = CreateImportDialog(parent, function(classID, message)
        parent:PickClass(classID)
        ns.UI.status:SetText(message)
    end)
    page.linkNotice = CreateLinkNotice(parent)
    page:SetScript("OnHide", function()
        page.exportDialog:Close()
        page.importDialog:Close()
        page.linkNotice:Close()
    end)

    -- Puts `savedPlan` (else the plan on show for `classID`) in the chat box
    -- as "[NR Talents: <name>] <share string>"; inside an instance or in combat
    -- the notice says first why it will show as plain text.
    function page:LinkInChat(classID, savedPlan)
        local line = Talents:PlanChatLine(classID, savedPlan)
        if not line then return end
        local isInInstance = IsInInstance()
        if isInInstance or InCombatLockdown() then
            self.linkNotice:Present(line, isInInstance)
            return
        end
        ns.UI.TypeInChat(line)
    end

    -- Moves the pills onto the content pane's strip: Import, Export, Link,
    -- Reset and My talents from the left.
    function page:PlaceStrip(strip)
        local pills = { self.import, self.export, self.link, self.reset, self.mine }
        for _, widget in ipairs(pills) do widget:SetParent(strip) end
        self.import:SetPoint("LEFT", STRIP_INSET, 0)
        for i = 2, #pills do pills[i]:SetPoint("LEFT", pills[i - 1], "RIGHT", STRIP_BUTTON_GAP, 0) end
    end

    -- The trees laid out for the class shown at this size, built again only
    -- when the class or the pane's size changed. False while the pane has no
    -- room for them yet.
    function page:Lay(tree, token)
        local width, height = self.trees:GetWidth(), self.trees:GetHeight()
        local count = #tree.groups
        -- Before the pane has its size (the first frame the tab is open) there
        -- is no room for the trees; its size change lays them out again.
        if width <= TREE_GAP * count or height <= 0 then return false end
        local key = ("%s:%d:%d"):format(tostring(tree), math.floor(width + 0.5), math.floor(height + 0.5))
        if key == self.laidOut then return true end
        self.laidOut = key
        local panelWidth = (width - TREE_GAP * (count - 1)) / math.max(1, count)
        for i, group in ipairs(tree.groups) do
            local panel = self.panels[i] or CreateTreePanel(self.trees)
            self.panels[i] = panel
            panel:ClearAllPoints()
            panel:SetPoint("TOPLEFT", (i - 1) * (panelWidth + TREE_GAP), 0)
            panel:SetSize(panelWidth, height)
            LayTree(panel, group, tree, self.classID, panelWidth, height)
            panel:Show()
        end
        for i = count + 1, #self.panels do self.panels[i]:Hide() end
        CropArt(self.panels, count, token, width, height)
        return true
    end

    -- Each talent's state, each tree's points and the heading, for the plan.
    function page:Paint(tree, plan)
        local splits = Talents:Splits(plan, tree)
        for i in ipairs(tree.groups) do
            local panel = self.panels[i]
            panel.spent:SetText(splits[i])
            for _, button in ipairs(panel.buttons) do
                if button:IsShown() then PaintNode(button, plan) end
            end
            for _, line in ipairs(panel.lines) do
                local color = Talents.Rank(plan, line.from) >= line.from.maxRanks and MAXED_COLOR or LINE_OFF_COLOR
                line:SetVertexColor(color[1], color[2], color[3], LINE_ALPHA)
            end
        end
        self.split:SetText(table.concat(splits, " / "))
        local level, points = Talents:Budget(self.classID)
        self.points:SetText(PointsText(level, points, math.max(0, points - Talents:TotalSpent(plan, tree))))
    end

    -- Your own class: "Your talents", loaded from the character until the
    -- plan is changed; any other: the class's name. A saved plan open in the
    -- planner is named under the heading.
    function page:ShowHeading(plan)
        local isMine = self.classID == Talents.PlayerClassID()
        local className = ClassNames(self.classID)
        self.title:SetText(isMine and L["Your talents"] or L["%s talents"]:format(className))
        if plan and plan.saved then
            self.subtitle:SetText(L["Saved plan %s. Click to add a point, right-click to take one back."]
                :format(plan.saved.name))
        elseif isMine and plan and not plan.edited then
            self.subtitle:SetText(L["Loaded from your character. Click to add a point, right-click to take one back."])
        else
            self.subtitle:SetText(L["Click to add a point, right-click to take one back."])
        end
        self.mine:SetShown(isMine)
    end

    function page:ShowClass(classID)
        self.classID = classID
        self:Update()
    end

    -- Draws the class's trees and plan; a calm line in their place while the
    -- game hasn't handed them out.
    function page:Update()
        if not self.classID then return end
        local tree, plan = Talents:Tree(self.classID), Talents:Plan(self.classID)
        local _, token = ClassNames(self.classID)
        self:ShowHeading(plan)
        local hasTree = tree ~= nil and plan ~= nil
        self.trees:SetShown(hasTree)
        self.empty:SetShown(not hasTree)
        self.split:SetShown(hasTree)
        self.points:SetShown(hasTree)
        if not hasTree then return end
        if self:Lay(tree, token) then self:Paint(tree, plan) end
    end

    page:SetScript("OnSizeChanged", function() page:Update() end)
    page.trees:SetScript("OnSizeChanged", function() page:Update() end)
    Talents:OnChange(function()
        if page:IsVisible() then page:Update() end
    end)
    return page
end
