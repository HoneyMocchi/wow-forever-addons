-- Shopping List tab: one pane with the current list as a tree on the left
-- (each added item, its materials, and any material opened into its own
-- materials) and everything left to buy on the right, with how many of each
-- the character already has. Under both, the gold on all the player's
-- characters. The header holds the list menu and the strip Save preset,
-- Import, Export and Clear list, as on the Wishlist (UI/SavedLists.lua);
-- Import and Export read and write Auctionator's shopping lists. The lists
-- themselves live in Core/Shopping.lua.
local _, ns = ...
local Theme = ns.Theme
local Size = Theme.size
local Shop = ns.Shopping
local ListUI = ns.UI.SavedLists
local L = ns.L

local HEADER_HEIGHT = 64
local LABEL_HEIGHT = 26  -- column label above each column
local TOP_ROW = 34       -- an added item
local ROW = 28           -- a material
local TOTAL_ROW = 34     -- a line in "To buy"
local SPACER = 8         -- gap between added items
local GOLD_LINE = 22     -- the "Total gold on all characters" line under the columns
local WIDE_DIALOG = 520  -- Import and Export, as wide as the Wishlist's
local IMPORT_HEIGHT = 360
local EXPORT_HEIGHT = 170
local MAX_SKIPPED_NAMES = 5 -- names Import's preview lists as not found, before "+N more"

-- Tree geometry, left to right on a material's row: the line from its
-- parent, a short stub, the open/close box, then its icon. Lines run down
-- from the middle of the parent's icon.
local LEFT = 6
local TOP_ICON, ICON = 24, 20
local STUB, TOGGLE, TOGGLE_GAP = 8, 14, 5

local function IconSize(depth) return depth == 0 and TOP_ICON or ICON end

local IconX, LineX, ToggleX
function LineX(depth) return IconX(depth) + IconSize(depth) / 2 end
function ToggleX(depth) return LineX(depth - 1) + STUB end
function IconX(depth)
    if depth == 0 then return LEFT end
    return ToggleX(depth) + TOGGLE + TOGGLE_GAP
end

-- Two or three thin strokes: "plus", "minus" or "close". Returns a function
-- that recolors them and the strokes themselves.
local function Strokes(frame, kind, size)
    local angles = kind == "close" and { 45, -45 } or { 0, 90 }
    local lines = {}
    for i, angle in ipairs(angles) do
        local line = frame:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(1, 1, 1, 1)
        line:SetSize(size, 1.5)
        line:SetPoint("CENTER")
        line:SetRotation(math.rad(angle))
        lines[i] = line
    end
    if kind == "minus" then lines[2]:Hide() end
    return function(color)
        for _, line in ipairs(lines) do line:SetVertexColor(unpack(color)) end
    end, lines
end

-- Small square button with a symbol that fills on hover (the count and
-- remove buttons on an added item).
local function SymbolButton(parent, kind, tip)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(18, 18)
    btn:SetFrameLevel(parent:GetFrameLevel() + 2)
    Theme:Rounded(btn, Theme.color.hover)
    btn.bg:Hide()
    local Tint = Strokes(btn, kind, kind == "close" and 9 or 8)
    Tint(Theme.color.muted)
    btn:SetScript("OnEnter", function(self)
        self.bg:Show()
        Tint(Theme.color.heading)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 4, 0)
        GameTooltip:AddLine(tip)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        self.bg:Hide()
        Tint(Theme.color.muted)
        GameTooltip:Hide()
    end)
    return btn
end

local function AddCountLine(label, count)
    local r, g, b = unpack(Theme.tip.info)
    GameTooltip:AddDoubleLine(label, count, r, g, b, unpack(Theme.tip.text))
end

-- A crafted row with a subtract box ticked: how many are wanted, how many
-- of those the bags and alts already hold, and how many are left to craft.
local function AddCraftCounts(data)
    GameTooltip:AddLine(" ")
    AddCountLine(L["Wanted"], data.need)
    if Shop:SubtractBags() then AddCountLine(L["In bags"], data.fromBags) end
    if Shop:SubtractAlts() then AddCountLine(L["On alts"], data.fromAlts) end
    AddCountLine(L["To craft"], data.toCraft)
end

local function ShowTreeTooltip(row)
    local data = row.data
    if not data then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT", 4, 0)
    GameTooltip:SetItemByID(data.itemID)
    if data.open and data.fromBags then AddCraftCounts(data) end
    if data.craft then
        local instance, encounter = data.craft[1], data.craft[2]
        GameTooltip:AddLine(" ")
        local skill = encounter.skill and ("  %d"):format(encounter.skill[1]) or ""
        GameTooltip:AddLine(L["Made with %s%s"]:format(instance.name, skill), unpack(Theme.tip.info))
        local hint
        if data.depth == 0 then
            hint = L["Click to open its recipe"]
        elseif data.open then
            hint = L["Click to buy it instead of its materials"]
        else
            hint = L["Click to buy its materials instead"]
        end
        GameTooltip:AddLine(hint, unpack(Theme.tip.hint))
    end
    GameTooltip:Show()
end

-- The open/close box on a crafted material: plus while it is bought as is,
-- minus once it is opened into its own materials.
local function CreateToggle(row)
    local btn = CreateFrame("Button", nil, row)
    btn:SetSize(TOGGLE, TOGGLE)
    btn:SetFrameLevel(row:GetFrameLevel() + 2)
    Theme:Rounded(btn, Theme.native and { 0, 0, 0, 0.45 } or Theme.color.bg, Theme.color.accent)
    local Tint, lines = Strokes(btn, "plus", 7)
    Tint(Theme.color.accent)
    function btn:SetOpen(open) lines[2]:SetShown(not open) end
    btn:SetScript("OnEnter", function()
        Tint(Theme.color.heading)
        row.hover:Show()
        ShowTreeTooltip(row)
    end)
    btn:SetScript("OnLeave", function()
        Tint(Theme.color.accent)
        row.hover:Hide()
        GameTooltip:Hide()
    end)
    btn:SetScript("OnClick", function()
        Shop:Toggle(row.data.index, row.data.path)
    end)
    return btn
end

-- Tree rows ---------------------------------------------------------------

local function CreateTreeRow(column)
    local row = Theme:Row(column, ROW)
    row.lines = {}
    Theme:QualityIcon(row)
    row.toggle = CreateToggle(row)

    row.name = Theme:Text(row, Theme.font.body)
    row.name:SetJustifyH("LEFT")
    row.count = Theme:Text(row, Theme.font.small)
    row.count:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
    -- On a crafted row, how many the bags and alts already hold.
    row.held = Theme:Text(row, Theme.font.small)
    row.held:SetPoint("LEFT", row.count, "RIGHT", 6, 0)
    Theme:SetTextColor(row.held, Theme.color.faint)

    -- An added item's own controls: one craft fewer or more, and remove.
    row.remove = SymbolButton(row, "close", L["Remove from the list"])
    row.remove:SetPoint("RIGHT", -6, 0)
    row.remove:SetScript("OnClick", function() GameTooltip:Hide(); Shop:Remove(row.data.index) end)
    row.plus = SymbolButton(row, "plus", L["One more"])
    row.plus:SetPoint("RIGHT", row.remove, "LEFT", -8, 0)
    row.plus:SetScript("OnClick", function() Shop:ChangeCrafts(row.data.index, 1) end)
    row.minus = SymbolButton(row, "minus", L["One fewer"])
    row.minus:SetPoint("RIGHT", row.plus, "LEFT", -2, 0)
    row.minus:SetScript("OnClick", function() Shop:ChangeCrafts(row.data.index, -1) end)
    row.itemButtons = { row.remove, row.plus, row.minus }

    row:RegisterForClicks("LeftButtonUp")
    row:HookScript("OnEnter", ShowTreeTooltip)
    row:HookScript("OnLeave", GameTooltip_Hide)
    row:SetScript("OnClick", function(self)
        local data = self.data
        if IsModifierKeyDown() then
            ns.Items:HandleModifiedClick(data.itemID)
        elseif data.depth == 0 and data.craft then
            GameTooltip:Hide()
            ns.UI:ClearHistory()
            ns.UI:SelectRecipe(data.craft[1], data.craft[2])
        elseif data.craft then
            Shop:Toggle(data.index, data.path)
        end
    end)
    return row
end

-- The tree's lines on one row: the levels above that carry on past it, its
-- own elbow from its parent, and a drop from its icon when it is open.
local function DrawLines(row, data)
    local rowHeight = data.height
    local used = 0
    local lineWidth = select(2, Theme:LineWidth(row))
    local function Place(x, y, width, height)
        used = used + 1
        local line = row.lines[used]
        if not line then
            line = row:CreateTexture(nil, "BORDER")
            line:SetColorTexture(unpack(Theme.color.accent))
            row.lines[used] = line
        end
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", row, "TOPLEFT", math.floor(x), -y)
        line:SetSize(math.max(width, lineWidth), math.max(height, lineWidth))
        line:Show()
    end
    local depth, middle = data.depth, math.floor(rowHeight / 2)
    for level = 1, depth - 1 do
        if data.rails[level] then Place(LineX(level - 1), 0, lineWidth, rowHeight) end
    end
    if depth > 0 then
        local x = LineX(depth - 1)
        Place(x, 0, lineWidth, data.last and middle or rowHeight)
        local stubEnd = data.craft and ToggleX(depth) or IconX(depth)
        Place(x, middle, stubEnd - math.floor(x), lineWidth)
    end
    if data.open then
        local iconBottom = middle + math.ceil(IconSize(depth) / 2)
        Place(LineX(depth), iconBottom, lineWidth, rowHeight - iconBottom)
    end
    for i = used + 1, #row.lines do row.lines[i]:Hide() end
end

-- What the subtract boxes cover of a crafted row: "7 in bags  ·  3 on alts",
-- or "" when they cover none (or aren't ticked, or the row is bought).
local function HeldText(data)
    if not data.open then return "" end
    local fromBags, fromAlts = data.fromBags or 0, data.fromAlts or 0
    return Theme:JoinDots(fromBags > 0 and L["%d in bags"]:format(fromBags) or nil,
        fromAlts > 0 and L["%d on alts"]:format(fromAlts) or nil)
end

-- The row's count: what is bought, or on a crafted row what is left to
-- craft. What is bought reads in body text; what is crafted along the way
-- is muted, and a craft the bags and alts cover whole says so in green.
local function SetCount(row, data)
    local isAddedItem = data.depth == 0
    local isCovered = data.open and data.toCraft == 0 and data.need > 0
    if isCovered then
        row.count:SetText(L["Covered"])
        Theme:SetTextColor(row.count, Theme.color.complete)
        return
    end
    row.count:SetText(("%dx"):format(data.open and data.toCraft or data.need))
    Theme:SetTextColor(row.count, (data.open and not isAddedItem) and Theme.color.faint or Theme.color.muted)
end

local function SetupTreeRow(row, data)
    local depth = data.depth
    local isAddedItem = depth == 0
    local size, x = IconSize(depth), IconX(depth)
    local nameX = x + size + 8
    row.iconBorder:ClearAllPoints()
    row.iconBorder:SetSize(size, size)
    row.iconBorder:SetPoint("LEFT", x, 0)
    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", nameX, 0)
    row.name:SetFontObject(Theme.font.body)

    row.toggle:SetShown(not isAddedItem and data.craft ~= nil)
    if row.toggle:IsShown() then
        row.toggle:ClearAllPoints()
        row.toggle:SetPoint("LEFT", ToggleX(depth), 0)
        row.toggle:SetOpen(data.open)
    end
    for _, button in ipairs(row.itemButtons) do button:SetShown(isAddedItem) end
    DrawLines(row, data)

    Theme:SetRowItem(row, data.itemID, SetupTreeRow)
    SetCount(row, data)
    row.held:SetText(HeldText(data))

    -- Long names give way to the count, what is held and, on an added item, its buttons.
    local keepClearRight = isAddedItem and 72 or 10
    local heldWidth = row.held:GetText() ~= "" and row.held:GetStringWidth() + 6 or 0
    local width = row:GetWidth()
    if width > 0 then
        local room = width - nameX - row.count:GetStringWidth() - 6 - heldWidth - keepClearRight
        row.name:SetWidth(math.max(1, math.min(row.name:GetUnboundedStringWidth(), room)))
    else
        row.name:SetWidth(0)
    end
    if GameTooltip:IsOwned(row) then ShowTreeTooltip(row) end
end

-- "To buy" rows -----------------------------------------------------------

local NO_CLASS_COLOR = { r = 0.8, g = 0.8, b = 0.8 } -- a character whose class isn't known

local function ClassColor(classToken)
    return classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken] or NO_CLASS_COLOR
end

local function ShowTotalTooltip(row)
    local data = row.data
    if not data then return end
    GameTooltip:SetOwner(row, "ANCHOR_LEFT", -4, 0)
    GameTooltip:SetItemByID(data.itemID)
    GameTooltip:AddLine(" ")
    local bank = Shop:BankCount(data.itemID)
    AddCountLine(L["Needed"], data.need)
    AddCountLine(L["In bags"], C_Item.GetItemCount(data.itemID) or 0)
    if bank > 0 then AddCountLine(L["In bank"], bank) end
    local altTotal, alts = Shop:AltCounts(data.itemID)
    if altTotal > 0 then
        AddCountLine(L["On alts"], altTotal)
        for _, alt in ipairs(alts) do
            local color = ClassColor(alt.class)
            GameTooltip:AddDoubleLine("   " .. alt.name, alt.count, color.r, color.g, color.b, unpack(Theme.tip.text))
        end
    end
    if data.left then AddCountLine(L["Left to buy"], data.left) end
    GameTooltip:Show()
end

local function CreateTotalRow(column)
    local row = Theme:Row(column, TOTAL_ROW)
    Theme:QualityIcon(row)
    row.iconBorder:SetSize(ICON, ICON)
    row.iconBorder:SetPoint("LEFT", 8, 0)
    row.need = Theme:Text(row, Theme.font.body)
    row.need:SetPoint("RIGHT", -10, 0)
    row.name = Theme:Text(row, Theme.font.body)
    row.name:SetJustifyH("LEFT")
    row.name:SetPoint("RIGHT", row.need, "LEFT", -8, 0)
    row.have = Theme:Text(row, Theme.font.small)
    row.have:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
    row.have:SetPoint("RIGHT", row.need, "LEFT", -8, 0)
    row.have:SetJustifyH("LEFT")
    row:RegisterForClicks("LeftButtonUp")
    row:HookScript("OnEnter", ShowTotalTooltip)
    row:HookScript("OnLeave", GameTooltip_Hide)
    row:SetScript("OnClick", function(self)
        if IsModifierKeyDown() then ns.Items:HandleModifiedClick(self.data.itemID) end
    end)
    return row
end

local function SetupTotalRow(row, data)
    Theme:SetRowItem(row, data.itemID, SetupTotalRow)
    -- With a subtract box ticked, toBuy is what the bags (and alts) don't cover.
    row.need:SetText(("%dx"):format(data.toBuy))
    Theme:SetTextColor(row.need, data.toBuy > 0 and Theme.color.text or Theme.color.faint)
    -- How many are in the bags and the bank, when any: green once the
    -- bags cover it.
    local hasSome = data.bags > 0 or data.bank > 0
    row.have:SetShown(hasSome)
    row.have:SetText(L["In bags: %d  ·  In bank: %d"]:format(data.bags, data.bank))
    Theme:SetTextColor(row.have, data.bags >= data.need and Theme.color.complete or Theme.color.muted)
    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", 8 + ICON + 8, hasSome and 6 or 0)
    row.name:SetPoint("RIGHT", row.need, "LEFT", -8, 0)
    if GameTooltip:IsOwned(row) then ShowTotalTooltip(row) end
end

-- A scrolled column (Theme:ScrollColumn) under its label.
local function CreateColumn(pane, label, createRow, setupRow)
    local column = Theme:ScrollColumn(pane, createRow, setupRow)
    column.label = Theme:Text(pane, Theme.font.label)
    column.label:SetPoint("BOTTOMLEFT", column, "TOPLEFT", 4, 9)
    column.label:SetText(Theme:Label(label))
    return column
end

-- The "Subtract what's ..." boxes in the pane's header, labelled at their
-- left; `set(on)` saves the choice.
local function CreateCheck(pane, label, tip, set)
    local box = Theme:CheckBox(pane, label, set, "LEFT")
    box:SetScript("OnEnter", function(self)
        Theme:SetTextColor(self.label, Theme.color.heading)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:AddLine(label)
        local r, g, b = unpack(Theme.tip.text)
        GameTooltip:AddLine(tip, r, g, b, true)
        GameTooltip:Show()
    end)
    box:SetScript("OnLeave", function(self)
        Theme:SetTextColor(self.label, Theme.color.muted)
        GameTooltip:Hide()
    end)
    return box
end

-- Gold line ---------------------------------------------------------------

-- Whether `characters` (from Shop:MoneyOnAllCharacters) live on more than one realm.
local function SpansRealms(characters)
    for _, character in ipairs(characters) do
        if character.realm ~= characters[1].realm then return true end
    end
    return false
end

-- Who has what: one line per character, richest first, the name in its
-- class colour (with the realm when they span more than one).
local function ShowGoldTooltip(line)
    local _, characters = Shop:MoneyOnAllCharacters()
    local showRealm = SpansRealms(characters)
    GameTooltip:SetOwner(line, "ANCHOR_TOPLEFT")
    GameTooltip:AddLine(L["Gold on each character"], unpack(Theme.tip.title))
    for _, character in ipairs(characters) do
        local name = showRealm and (character.name .. "-" .. character.realm) or character.name
        local color = ClassColor(character.class)
        GameTooltip:AddDoubleLine(name, ns.Money(character.money, true), color.r, color.g, color.b,
            unpack(Theme.tip.text))
    end
    GameTooltip:AddLine(" ")
    local r, g, b = unpack(Theme.tip.quiet)
    GameTooltip:AddLine(L["Other characters show the gold they had when you last played them."], r, g, b, true)
    GameTooltip:Show()
end

-- The line under the columns with the gold on all characters; the mouse
-- over it shows who has what.
local function CreateGoldLine(pane)
    local line = CreateFrame("Frame", nil, pane)
    line:SetHeight(GOLD_LINE)
    line:EnableMouse(true)
    line.text = Theme:Text(line, Theme.font.body)
    line.text:SetPoint("LEFT")
    Theme:SetTextColor(line.text, Theme.color.muted)
    line:SetScript("OnEnter", function(self)
        Theme:SetTextColor(self.text, Theme.color.heading)
        ShowGoldTooltip(self)
    end)
    line:SetScript("OnLeave", function(self)
        Theme:SetTextColor(self.text, Theme.color.muted)
        GameTooltip:Hide()
    end)

    function line:Update()
        local total = Shop:MoneyOnAllCharacters()
        self.text:SetText(L["Total gold on all characters: %s"]:format(ns.Money(total, true)))
        -- Only the text takes the mouse, not the empty width beside it.
        self:SetWidth(math.max(1, self.text:GetStringWidth()))
        if GameTooltip:IsOwned(self) then ShowGoldTooltip(self) end
    end
    return line
end

-- How many materials (rows of To buy) still need buying.
local function CountToBuy(totals)
    local count = 0
    for _, total in ipairs(totals) do
        if total.toBuy > 0 then count = count + 1 end
    end
    return count
end

local function ItemCountText(count)
    return Theme:Plural(count, L["%d item"], L["%d items"])
end

-- Import and Export ----------------------------------------------------------

-- "Elixirs, Gems" for the lists Import found items for.
local function ListNames(lists)
    local names = {}
    for _, list in ipairs(lists) do
        if #list.items > 0 then table.insert(names, list.name) end
    end
    return table.concat(names, ", ")
end

-- What Import found in pasted text: the items over every list, and the names
-- it found no item for (as typed, a few then "+N more").
local function CountImport(lists)
    local itemCount, skipped = 0, {}
    for _, list in ipairs(lists) do
        itemCount = itemCount + #list.items
        for _, name in ipairs(list.skipped) do table.insert(skipped, ns.Literal(name)) end
    end
    local shown = { unpack(skipped, 1, math.min(#skipped, MAX_SKIPPED_NAMES)) }
    local skippedText = table.concat(shown, ", ")
    if #skipped > MAX_SKIPPED_NAMES then
        skippedText = skippedText .. " " .. L["+%d more"]:format(#skipped - MAX_SKIPPED_NAMES)
    end
    return itemCount, #skipped > 0 and L["Not found in NeedRoll's professions: %s"]:format(skippedText) or nil
end

-- The first list Import found items for.
local function FirstFound(lists)
    for _, list in ipairs(lists) do
        if #list.items > 0 then return list end
    end
end

-- Import: Auctionator shopping lists, one per line, previewed. The first
-- becomes a new list or replaces the current one's items; every other line
-- becomes a new list.
local function CreateImportDialog(pane)
    local box = Theme:Dialog(pane, WIDE_DIALOG, IMPORT_HEIGHT, L["Import"])
    box:AddHint(L["Paste shopping lists exported from Auctionator (or NeedRoll), one list per line."])
    local paste = ListUI.PasteBox(box, WIDE_DIALOG - Size.pad * 2, L["Paste here (Ctrl+V)"])
    paste:SetPoint("TOPLEFT", box.hint, "BOTTOMLEFT", 0, -10)
    local edit = paste.edit
    box.preview = Theme:Text(box, Theme.font.body)
    box.preview:SetPoint("TOPLEFT", paste, "BOTTOMLEFT", 0, -12)
    box.preview:SetWidth(WIDE_DIALOG - Size.pad * 2)
    box.preview:SetJustifyH("LEFT")
    box.detail = Theme:Text(box, Theme.font.small)
    box.detail:SetPoint("TOPLEFT", box.preview, "BOTTOMLEFT", 0, -4)
    box.detail:SetWidth(WIDE_DIALOG - Size.pad * 2)
    box.detail:SetJustifyH("LEFT")
    ListUI.AddImportTarget(box, box.detail)

    local parsed
    local Preview
    -- Item names still arriving from the game are matched once they have all come.
    local function AwaitNames()
        if box.isAwaitingNames then return true end
        box.isAwaitingNames = Shop:AwaitItemNames(function()
            box.isAwaitingNames = nil
            if box.shade:IsShown() then Preview() end
        end)
        return box.isAwaitingNames
    end
    local function ShowProblem(text)
        parsed = nil
        box.preview:SetText(text or "")
        Theme:SetTextColor(box.preview, Theme.color.incomplete)
        ListUI.EnablePill(box.ok, false)
    end
    function Preview()
        local text = edit:GetText()
        paste.placeholder:SetShown(text == "" and not edit:HasFocus())
        box.detail:SetText("")
        if strtrim(text) == "" then return ShowProblem("") end
        local lists, err = Shop:ParseAuctionator(text)
        if not lists then return ShowProblem(err) end
        local isLoading = AwaitNames()
        local itemCount, skippedText = CountImport(lists)
        Theme:SetTextColor(box.detail, Theme.color.muted)
        box.detail:SetText(Theme:JoinDots(skippedText, isLoading and L["Loading item names..."] or nil))
        if itemCount == 0 then
            return ShowProblem(isLoading and "" or L["None of these items are in NeedRoll's professions."])
        end
        parsed = lists
        box.preview:SetText(Theme:JoinDots(ListNames(lists), ItemCountText(itemCount)))
        Theme:SetTextColor(box.preview, Theme.color.heading)
        box:SuggestName(Shop:FreeName(FirstFound(lists).name))
        ListUI.EnablePill(box.ok, true)
    end
    edit:SetScript("OnTextChanged", Preview)

    local function Import()
        if not parsed then return end
        local firstName = Shop:CleanName(box.name:GetText()) or FirstFound(parsed).name
        local itemCount = Shop:ImportLists(parsed, box:IsReplacing(), firstName)
        ns.UI.status:SetText(L["Imported %s"]:format(ItemCountText(itemCount)))
        box:Close()
    end
    box:Buttons(L["Import"], Import)
    function box:Present()
        edit:SetText("")
        paste.scroll:SetVerticalScroll(0)
        box:ResetTarget()
        Preview()
        self:Open()
        edit:SetFocus()
    end
    return box
end

-- Export: the current list as an Auctionator shopping list, to paste into
-- Auctionator's Import: the materials still to buy (the To buy column), or
-- the items on the list. An item the client hasn't loaded has no name yet,
-- so the text waits for it.
local function CreateExportDialog(pane)
    local box = Theme:Dialog(pane, WIDE_DIALOG, EXPORT_HEIGHT, L["Export"])
    box:AddHint(L["Press Ctrl+C to copy, then paste it into Auctionator's shopping list Import."])
    ListUI.AddCopyInput(box, WIDE_DIALOG - Size.pad * 2)
    box.loading = Theme:Text(box, Theme.font.small)
    box.loading:SetPoint("TOPLEFT", box.input, "BOTTOMLEFT", Theme.native and -6 or 0, -8)
    box.loading:SetText(L["Loading item names..."])
    Theme:SetTextColor(box.loading, Theme.color.muted)
    local isAsked = {} -- items whose names have been asked for

    local Fill
    local function OnNameLoaded(itemID)
        isAsked[itemID] = nil
        if box.shade:IsShown() then Fill() end
    end
    function Fill()
        local what = box.what.active == L["Items on this list"] and "items" or "materials"
        local text, unnamed = Shop:ExportAuctionator(what)
        box.loading:SetShown(text == nil)
        if text then return box:ShowCopyText(text) end
        box:ShowCopyText("")
        for _, itemID in ipairs(unnamed) do
            if not isAsked[itemID] then
                isAsked[itemID] = true
                ns.Items:Load(itemID, OnNameLoaded)
            end
        end
    end
    -- Where the Wishlist's Export has its checkbox, left of Done.
    box.what = Theme:LabelToggle(box, { L["Materials to buy"], L["Items on this list"] }, function(name)
        box.what:SetActive(name)
        Fill()
    end)
    box.what:SetPoint("BOTTOMLEFT", Size.pad + box.what:ContentWidth(), Size.pad + 5)
    box:Buttons(nil)
    box.cancel:SetLabel(L["Done"])
    function box:Present()
        self.what:SetActive(L["Materials to buy"])
        self:Open()
        Fill()
    end
    return box
end

-- The pane's header: the Auctioneer's icon, the title with the list menu
-- by it, the subtitle, and the subtract boxes at the right. Save preset,
-- Import, Export and Clear list (it asks once) go in the strip above
-- (MainFrame calls pane:PlaceStrip).
local function CreateHeader(pane)
    -- The Auctioneer's icon left of the title, the size of the other tabs'
    -- pane header icons.
    pane.icon = pane:CreateTexture(nil, "ARTWORK")
    Theme:FitAtlas(pane.icon, "Auctioneer", 26)
    pane.title = Theme:Text(pane, Theme.font.heading)
    pane.title:SetPoint("TOPLEFT", Size.pad + 4 + pane.icon:GetWidth() + 6, -18)
    pane.icon:SetPoint("RIGHT", pane.title, "LEFT", -6, 0)
    pane.title:SetText(L["Shopping List"])
    pane.subtitle = Theme:Text(pane, Theme.font.small)
    pane.subtitle:SetPoint("TOPLEFT", pane.title, "BOTTOMLEFT", 0, -6)

    ListUI.Add(pane, Shop, {
        listsTitle = L["Your shopping lists"],
        listsTip = L["Saved for every character on this account. Recipes add to the list shown here."],
        newListName = Shop.DEFAULT,
        newListHint = L["An empty list; \"Add to shopping list\" on a recipe adds to it."],
        importTip = L["Add lists exported from Auctionator's shopping lists."],
        exportTip = L["This list as an Auctionator shopping list, to import there."],
    })
    pane.listButton:SetPoint("LEFT", pane.title, "RIGHT", 12, 0)
    pane.importDialog = CreateImportDialog(pane)
    pane.exportDialog = CreateExportDialog(pane)
    -- Level with the title.
    pane.bags = CreateCheck(pane, L["Subtract what's in my bags"],
        L["Crafted items this character carries mean fewer crafts, and materials it carries come off To buy."],
        function(on) Shop:SetSubtractBags(on) end)
    pane.bags:SetPoint("TOPRIGHT", -Size.pad - (Theme.native and 0 or 2), Theme.native and -18 or -22)
    pane.alts = CreateCheck(pane, L["Subtract materials on other characters"],
        L["Also uses what your other characters on this realm and faction hold in their bags and banks, crafted items and materials alike. Each alt is counted from their last login, and their bank from their last bank visit."],
        function(on) Shop:SetSubtractAlts(on) end)
    pane.alts:SetPoint("TOPRIGHT", pane.bags, "BOTTOMRIGHT", 0, Theme.native and 0 or -6)
end

function ns.UI.CreateShoppingList(parent)
    local pane = Theme:CreatePanel(parent, "loot")
    CreateHeader(pane)

    local top = HEADER_HEIGHT + LABEL_HEIGHT
    -- The gold line sits at the pane's bottom, Size.pad - Size.scrollBottom
    -- up, and the columns stand on it. Their rows stop Size.scrollBottom
    -- above the columns' bottom edge, so that much clear space parts the
    -- last row from the gold line.
    local goldBottom = Size.pad - Size.scrollBottom
    local bottom = goldBottom + GOLD_LINE
    pane.gold = CreateGoldLine(pane)
    pane.gold:SetPoint("BOTTOMLEFT", Size.pad + 4, goldBottom)
    pane.totals = CreateColumn(pane, L["To buy"], CreateTotalRow, SetupTotalRow)
    pane.totals:SetPoint("TOPRIGHT", -Size.pad + 4, -top)
    pane.totals:SetPoint("BOTTOMRIGHT", -Size.pad + 4, bottom)
    pane.tree = CreateColumn(pane, L["Crafting"], CreateTreeRow, SetupTreeRow)
    pane.tree:SetPoint("TOPLEFT", Size.pad, -top)
    pane.tree:SetPoint("BOTTOMLEFT", Size.pad, bottom)
    pane.tree:SetPoint("RIGHT", pane.totals, "LEFT", -24, 0)

    -- Hairline between the two columns.
    pane.divider = pane:CreateTexture(nil, "BORDER")
    pane.divider:SetColorTexture(unpack(Theme.color.line))
    pane.divider:SetPoint("TOPRIGHT", pane.totals, "TOPLEFT", -12, LABEL_HEIGHT)
    pane.divider:SetPoint("BOTTOMRIGHT", pane.totals.view, "BOTTOMLEFT", -12, 0)
    pane.divider:SetWidth(1)

    pane.empty = Theme:Text(pane, Theme.font.body)
    pane.empty:SetPoint("CENTER", 0, 10)
    pane.empty:SetText(L["Your shopping list is empty"])
    Theme:SetTextColor(pane.empty, Theme.color.muted)
    pane.emptyHint = Theme:Text(pane, Theme.font.small)
    pane.emptyHint:SetPoint("TOP", pane.empty, "BOTTOM", 0, -8)
    pane.emptyHint:SetText(L["Open a recipe on the Professions tab and click \"Add to shopping list\"."])

    -- The "To buy" column takes about a third of the pane.
    local function Layout(self)
        self.totals:SetWidth(math.floor(math.max(240, self:GetWidth() * 0.36)))
    end
    pane:SetScript("OnSizeChanged", Layout)
    Layout(pane)

    -- Rebuilds both columns from the saved list.
    function pane:Update()
        local treeRows, totals = Shop:BuildTree()
        local itemCount = #Shop:Entries()
        local hasItems = itemCount > 0
        for _, part in ipairs({ self.tree, self.totals, self.tree.label, self.totals.label, self.divider,
            self.bags, self.alts }) do
            part:SetShown(hasItems)
        end
        self:UpdateListControls()
        self.empty:SetShown(not hasItems)
        self.emptyHint:SetShown(not hasItems)
        self.bags:Set(Shop:SubtractBags())
        self.alts:Set(Shop:SubtractAlts())
        local toBuy = CountToBuy(totals)
        local subtitle = L["%s  ·  %s to buy"]:format(Theme:Plural(itemCount, L["%d item"], L["%d items"]),
            Theme:Plural(toBuy, L["%d material"], L["%d materials"]))
        self.subtitle:SetText(hasItems and subtitle or "")
        -- The tree's rows, with a gap before each added item but the first.
        local entries = {}
        for i, row in ipairs(treeRows) do
            local isAddedItem = row.depth == 0
            if isAddedItem and i > 1 then table.insert(entries, { spacer = true, height = SPACER }) end
            row.height = isAddedItem and TOP_ROW or ROW
            table.insert(entries, row)
        end
        for _, total in ipairs(totals) do total.height = TOTAL_ROW end
        self.tree:SetData(entries, true)
        self.totals:SetData(totals, true)
        self.totalCount = toBuy
        self.gold:Update()
    end

    -- Bags and the bank change what the character has, and so what is left
    -- to buy. Core/Shopping.lua scans the bank first on these events.
    local function Recount()
        if pane:IsVisible() then ns.UI:Refresh() end
    end
    ns:On("BAG_UPDATE_DELAYED", Recount)
    ns:On("BANKFRAME_OPENED", Recount)
    ns:On("PLAYERBANKSLOTS_CHANGED", Recount)
    ns:On("PLAYER_MONEY", function()
        if pane:IsVisible() then pane.gold:Update() end
    end)
    return pane
end
