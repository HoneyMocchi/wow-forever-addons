-- The controls the Wishlist and the Shopping List share for their named
-- lists (Core/SavedLists.lua): the current list's name as a pill by the
-- tab's title that opens the list menu (switch, new empty list, rename,
-- delete), the strip's Save preset, Import, Export and Clear list pills,
-- and the pieces both Import dialogs are built from. Each tab builds its
-- own Import and Export dialogs (pane.importDialog, pane.exportDialog),
-- since what they read and write differs.
local _, ns = ...
local Theme = ns.Theme
local Size = Theme.size
local L = ns.L

local SavedListsUI = {}
ns.UI.SavedLists = SavedListsUI

local MENU_WIDTH = 240
local PASTE_BOX_HEIGHT = 130
local TARGET_NAME_WIDTH = 200 -- Import's name box for a new list
local DIMMED_PILL = 0.4       -- alpha of a pill that can't be used yet

local function AddTooltip(frame, anchor, x, y, title, text)
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, anchor, x, y)
        GameTooltip:AddLine(title)
        local r, g, b = unpack(Theme.tip.text)
        GameTooltip:AddLine(text, r, g, b, true)
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", GameTooltip_Hide)
end

-- Turns a pill on or off (dimmed, ignoring clicks).
function SavedListsUI.EnablePill(pill, on)
    pill:SetEnabled(on)
    pill:SetAlpha(on and 1 or DIMMED_PILL)
end

-- Import's paste box: a scrolling edit box that follows the cursor, with grey text while empty.
-- frame.edit is the edit box, frame.placeholder the grey text.
function SavedListsUI.PasteBox(dialog, width, placeholderText)
    local frame = CreateFrame("Frame", nil, dialog)
    frame:SetSize(width, PASTE_BOX_HEIGHT)
    Theme:Rounded(frame, Theme.native and { 0, 0, 0, 0.6 } or Theme.color.input,
        Theme.native and Theme.color.line or Theme.color.inputEdge)
    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", 8, -6)
    scroll:SetPoint("BOTTOMRIGHT", -8, 6)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(0)
    edit:SetFontObject(Theme.font.small)
    edit:SetWidth(width - 16)
    scroll:SetScrollChild(edit)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math.max(0, edit:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.min(maxScroll, math.max(0, self:GetVerticalScroll() - delta * 20)))
    end)
    frame:EnableMouse(true) -- an edit box takes clicks only on its text; the rest of the box focuses it too
    frame:SetScript("OnMouseDown", function() edit:SetFocus() end)
    edit:SetScript("OnEscapePressed", edit.ClearFocus)
    -- The game gives the cursor's y as a negative offset from the text's top.
    edit:SetScript("OnCursorChanged", function(_, _, cursorY, _, cursorHeight)
        local cursorTop = -cursorY
        local viewTop, viewHeight = scroll:GetVerticalScroll(), scroll:GetHeight()
        if cursorTop < viewTop then
            scroll:SetVerticalScroll(cursorTop)
        elseif cursorTop + cursorHeight > viewTop + viewHeight then
            scroll:SetVerticalScroll(cursorTop + cursorHeight - viewHeight)
        end
    end)
    local placeholder = Theme:Text(frame, Theme.font.small)
    placeholder:SetPoint("TOPLEFT", 10, -8)
    placeholder:SetText(placeholderText)
    Theme:SetTextColor(placeholder, Theme.color.faint)
    edit:SetScript("OnEditFocusGained", function() placeholder:Hide() end)
    edit:SetScript("OnEditFocusLost", function() placeholder:SetShown(edit:GetText() == "") end)
    frame.edit, frame.scroll, frame.placeholder = edit, scroll, placeholder
    return frame
end

-- Export's text box, under the dialog's hint: read only (typing puts the
-- text back), its text selected for Ctrl+C. box:ShowCopyText(text) fills
-- and selects it; Escape or Enter closes the dialog.
function SavedListsUI.AddCopyInput(box, width)
    box.input = Theme:Input(box, width)
    box.input:SetPoint("TOPLEFT", box.hint, "BOTTOMLEFT", Theme.native and 6 or 0, -12)
    box.input:SetMaxLetters(0)
    box.input:SetScript("OnTextChanged", function(self, userInput)
        if userInput and self:GetText() ~= box.text then
            self:SetText(box.text)
            self:HighlightText()
        end
    end)
    box.input:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    box.input:SetScript("OnEscapePressed", function() box:Close() end)
    box.input:SetScript("OnEnterPressed", function() box:Close() end)
    function box:ShowCopyText(text)
        self.text = text
        self.input:SetText(text)
        self.input:SetFocus()
        self.input:HighlightText()
    end
end

-- Import's choice, under `anchor`: what was pasted becomes a new list, named
-- in the box beside the choice, or replaces the current list's items.
-- Adds box.mode and box.name; box:ResetTarget() before the dialog opens,
-- box:SuggestName(name) to fill the name until the player types their own,
-- and box:IsReplacing().
function SavedListsUI.AddImportTarget(box, anchor)
    box.mode = Theme:LabelToggle(box, { L["New list"], L["Replace current"] }, function(name)
        box.mode:SetActive(name)
        box.name:SetShown(name == L["New list"])
    end)
    box.mode:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", box.mode:ContentWidth(), -14)
    box.name = Theme:Input(box, TARGET_NAME_WIDTH)
    box.name:SetPoint("LEFT", box.mode, "RIGHT", 12 + (Theme.native and 6 or 0), 0)
    box.name:SetMaxLetters(ns.SavedLists.MAX_NAME)
    -- A name the player typed stays; until then it follows what was pasted.
    box.name:SetScript("OnTextChanged", function(self, userInput) if userInput then self.edited = true end end)
    box.name:SetScript("OnEnterPressed", box.name.ClearFocus)
    function box:ResetTarget()
        self.name.edited = nil
        self.name:SetText("")
        self.mode:SetActive(L["New list"])
        self.name:Show()
    end
    function box:SuggestName(name)
        if not self.name.edited then self.name:SetText(name) end
    end
    function box:IsReplacing()
        return self.mode.active == L["Replace current"]
    end
end

-- Every saved list (the current one gold, its item count at the right), New
-- empty list, Rename and Delete.
local function CreateMenu(pane, lists, text)
    local menu = Theme:Menu(pane, MENU_WIDTH)
    local anchor = pane.listButton
    menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    menu.anchor = anchor
    local function NewList()
        menu:Hide()
        pane.nameDialog:Ask(L["New list"], text.newListHint, lists:FreeName(text.newListName), function(name)
            if not lists:CleanName(name) then return L["Type a name."] end
            lists:AddList(name, {})
        end)
    end
    local function RenameList()
        menu:Hide()
        local current = lists:Current()
        pane.nameDialog:Ask(L["Rename list"], L["A new name for %s."]:format(current.name), current.name,
            function(typed)
                local name = lists:CleanName(typed)
                if not name then return L["Type a name."] end
                if name ~= current.name and not lists:Rename(name) then return L["Another list has that name."] end
            end)
    end
    function menu:Fill()
        self:Begin()
        local current = lists:Current()
        for _, list in ipairs(lists:Lists()) do
            local row = self:AddRow(list.name, list == current and Theme.color.heading or Theme.color.text,
                function()
                    menu:Hide()
                    lists:Select(list.name)
                end)
            row.count:SetText(#list.items)
            Theme:SetTextColor(row.count, Theme.color.muted)
        end
        self:AddRule()
        self:AddRow(L["New empty list..."], Theme.color.muted, NewList)
        self:AddRow(L["Rename..."], Theme.color.muted, RenameList)
        self:AddConfirmRow(L["Delete list"], L["Click again to delete"], function() lists:Delete() end)
        self:Finish()
    end
    return menu
end

-- The list's name as a pill with a chevron: opens the list menu.
local function CreateListButton(pane, text)
    local pill = Theme:Pill(pane)
    pill.arrow = Theme:SortMark(pill)
    pill.arrow:SetPoint("RIGHT", -9, 0)
    pill.arrow:SetDescending(true)
    local SetLabel = pill.SetLabel
    function pill:SetLabel(label)
        SetLabel(self, label)
        self:SetWidth(self:GetWidth() + 14) -- room for the chevron
    end
    AddTooltip(pill, "ANCHOR_BOTTOMRIGHT", nil, nil, text.listsTitle, text.listsTip)
    pill:SetScript("OnClick", function() pane.menu:SetShown(not pane.menu:IsShown()) end)
    return pill
end

-- Save preset, Import, Export and Clear list, for the pane's strip.
local function CreatePills(pane, lists, text)
    local function Pill(symbol, label, tip, onClick)
        local pill = Theme:Pill(pane, symbol)
        pill:SetLabel(label)
        AddTooltip(pill, "ANCHOR_BOTTOM", 0, -4, label, tip)
        pill:SetScript("OnClick", function()
            pane.menu:Hide()
            onClick()
        end)
        return pill
    end
    pane.clear = Theme:ConfirmPill(pane, "close", L["Clear list"], L["Click again to clear"],
        function() lists:Clear() end)
    pane.export = Pill(nil, L["Export"], text.exportTip, function() pane.exportDialog:Present() end)
    pane.import = Pill(nil, L["Import"], text.importTip, function() pane.importDialog:Present() end)
    pane.save = Pill("plus", L["Save preset"], L["Saves this list under a new name, account-wide."], function()
        pane.nameDialog:Ask(L["Save preset"], L["Saves a copy of this list for every character on the account."],
            lists:FreeName(lists:Current().name), function(name)
                if not lists:CleanName(name) then return L["Type a name."] end
                lists:SavePreset(name)
            end)
    end)
    -- MainFrame puts them in the pane's strip, right to left.
    function pane:PlaceStrip(strip)
        local prev
        for _, pill in ipairs({ self.clear, self.export, self.import, self.save }) do
            pill:SetParent(strip)
            pill:ClearAllPoints()
            if prev then pill:SetPoint("RIGHT", prev, "LEFT", -6, 0) else pill:SetPoint("RIGHT", -Size.pad + 4, 0) end
            prev = pill
        end
    end
end

-- Gives `pane` the list controls for `lists` (ns.Wishlist or ns.Shopping):
-- pane.listButton (the tab places it), pane.menu, pane.nameDialog, the
-- strip pills with pane:PlaceStrip(strip), and pane:UpdateListControls()
-- for the pane's Update. `text` holds the tab's own words: listsTitle and
-- listsTip (the list button's tooltip), newListName and newListHint (New
-- empty list), importTip and exportTip (the pills' tooltips). Hiding the
-- pane closes the menu and every dialog.
function SavedListsUI.Add(pane, lists, text)
    pane.listButton = CreateListButton(pane, text)
    pane.menu = CreateMenu(pane, lists, text)
    pane.nameDialog = Theme:NameDialog(pane, ns.SavedLists.MAX_NAME)
    CreatePills(pane, lists, text)
    pane:HookScript("OnHide", function(self)
        self.menu:Hide()
        self.nameDialog:Close()
        self.importDialog:Close()
        self.exportDialog:Close()
    end)
    function pane:UpdateListControls()
        local list = lists:Current()
        local hasItems = #list.items > 0
        self.listButton:SetLabel(list.name)
        self.clear:SetShown(hasItems)
        SavedListsUI.EnablePill(self.export, hasItems)
        if self.menu:IsShown() then self.menu:Fill() end
    end
end
