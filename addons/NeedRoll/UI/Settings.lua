-- The Settings page: the Settings button at the top of the window opens it in
-- place of the tabs' panes, with Back to return. General holds the
-- player's settings: the language of NeedRoll's own text (a box opening a
-- menu, switching after a reload), then each a switch between its choices:
-- window style, UI scale, the minimap button, whether the world map shows
-- NeedRoll's map inside a dungeon, the lines naming bosses on item tooltips
-- and quest chains on quest tooltips, the collection ticks after item names,
-- where open and shut sections are remembered; last the key that opens
-- NeedRoll. Modules turns each tab on or off (ns.Modules, Core/Init.lua).
-- The Discord button by the title shows the community's invite, ready to
-- copy. A quiet link under the columns opens the Game hotfixes page
-- (UI/Hotfixes.lua), which shares the page's scrolling.
-- Each window (one per style) builds its own Settings button and page (UI:Build and
-- UI:ShowSettingsPage in MainFrame.lua).
local _, ns = ...
local Theme = ns.Theme
local L = ns.L

local Settings = {}
ns.Settings = Settings

local PAD = 18
Settings.PAD = PAD -- the Game hotfixes page's too (UI/Hotfixes.lua)
local ROW = 30
local MODULE_ROW = 40
local COLUMN_GAP = 36
local HEAD = 44      -- a section's heading (its 36 icon) and the rule under it
local ICON = 29      -- a module's tab icon
local SUB_INDENT = 22 -- a part of a tab (Professions Icons) or setting (Credit my finds), under it
local SAMPLE_ITEM = 118 -- Minor Healing Potion, in Professions Icons' row

-- Share drops and Credit my finds are hidden while drop sharing is switched
-- off for everyone (see Switch in Core/Drops.lua).
local function IsSharingSwitchedOff()
    return not ns.Drops.isSharingEnabled
end

-- The window styles the Settings page offers: each skin that can be shown
-- now (ElvUI only while ElvUI is loaded) by its name as shown.
local function SkinChoices()
    local names = {}
    for _, skin in ipairs(Theme:AvailableSkins()) do table.insert(names, Theme.skinNames[skin]) end
    return names
end

-- A window style's skin ("dark") from its name as shown ("Dark").
local SKIN_BY_NAME = {}
for skin, name in pairs(Theme.skinNames) do SKIN_BY_NAME[name] = skin end

-- Remember sections' choices as shown, by the mode each saves
-- (ns.SectionMemory in Core/Init.lua), and back.
local SECTION_MEMORY_NAMES = {
    character = L["This character"],
    account = L["All characters"],
    off = L["Off"],
}
local SECTION_MEMORY_CHOICES, SECTION_MEMORY_BY_NAME = {}, {}
for _, mode in ipairs(ns.SectionMemory.MODES) do
    table.insert(SECTION_MEMORY_CHOICES, SECTION_MEMORY_NAMES[mode])
    SECTION_MEMORY_BY_NAME[SECTION_MEMORY_NAMES[mode]] = mode
end

-- Each setting: its label, its choices as shown (in order; a function
-- giving them when they depend on what is installed), the choice
-- currently in effect, and what picking one does. `about` is a line under
-- the label, `tip` its tooltip, and `ticks` puts the loot grid's two
-- collection ticks after the label. A setting whose `isHidden` says true
-- gets no row at all, so the rows under it close up.
local OPTIONS = {
    {
        label = L["Window style"],
        names = SkinChoices,
        current = function() return Theme.skinNames[Theme.name] end,
        pick = function(name) ns.UI:SetSkin(SKIN_BY_NAME[name]) end,
    },
    {
        label = L["UI scale"],
        names = { L["Normal"], L["Large"] },
        current = function() return Theme.textSizeNames[ns.db.textSize] or L["Normal"] end,
        pick = function(name) ns.UI:SetTextSize(name == L["Large"] and "large" or "normal") end,
    },
    {
        label = L["Minimap button"],
        names = { L["Shown"], L["Hidden"] },
        current = function() return ns.db.minimap.hide and L["Hidden"] or L["Shown"] end,
        pick = function(name) ns.MinimapButton:SetHidden(name == L["Hidden"]) end,
    },
    {
        label = L["Map in dungeons"],
        names = { "NeedRoll", L["Game"] },
        current = function() return ns.db.dungeonMap == "game" and L["Game"] or "NeedRoll" end,
        pick = function(name)
            ns.db.dungeonMap = name == L["Game"] and "game" or "needroll"
            ns.WorldMapOverlay:Recheck()
        end,
        about = L["Whether the world map shows NeedRoll's map inside a dungeon"],
    },
    {
        label = L["Drop sources on tooltips"],
        names = { L["On"], L["Off"] },
        current = function() return ns.Tooltip:IsOn() and L["On"] or L["Off"] end,
        pick = function(name) ns.Tooltip:SetOn(name == L["On"]) end,
        about = L["Bosses on item tooltips, quest chains on quest tooltips"],
        tip = L["Item tooltips anywhere in the game (bags, inspect, chat links, loot) name the dungeon or raid boss that drops the item. Quest tooltips (chat links, the quest log) name the dungeon or raid whose quest chain the quest is on."],
    },
    {
        label = L["Collection ticks"],
        names = { L["Shown"], L["Hidden"] },
        current = function() return ns.db.collectionTicks == false and L["Hidden"] or L["Shown"] end,
        pick = function(name) ns.UI:SetCollectionTicks(name == L["Shown"]) end,
        about = L["Marks gear whose look you've collected"],
        ticks = true,
        tip = L["A tick after an item's name shows whether you have collected its appearance: in color once collected, grey until then."],
    },
    {
        label = L["Remember sections"],
        names = SECTION_MEMORY_CHOICES,
        current = function() return SECTION_MEMORY_NAMES[ns.SectionMemory.Mode()] end,
        pick = function(name) ns.SectionMemory.SetMode(SECTION_MEMORY_BY_NAME[name]) end,
        about = L["Open or shut, as you left them"],
        tip = L["Loot sections, the middle column's groups and a raid's Attunement heading stay open or shut as you left them, after a reload or logout too. This character keeps each character's own; All characters shares one set; Off forgets them when the game reloads."],
    },
    {
        label = L["Share drops"],
        names = { L["On"], L["Off"] },
        current = function() return ns.Drops:ChannelOn() and L["On"] or L["Off"] end,
        -- An answer to the first-login notice too (UI/Welcome.lua).
        pick = function(name) ns.Welcome:AnswerDropSharing(name == L["On"]) end,
        about = L["Helps fill in loot lists for everyone"],
        isHidden = IsSharingSwitchedOff,
        tip = L["NeedRoll tells other NeedRoll players on your realm and in your guild which items bosses drop, new quests, which spells and recipes trainers teach and what vendors sell (recipes and rare items), through hidden addon messages, to help fill in its lists. Off stops those messages, so its lists fill in more slowly. NeedRoll still tells your guild and group which version it runs, so it can say when an update is out."]
            .. " " .. L["When NeedRoll's developer asks for finds, it also tells him who in your guild or group shared finds in the past week, so he can ask them too."],
    },
    {
        label = L["Credit my finds"],
        names = { L["On"], L["Off"] },
        current = function() return ns.Drops:CreditOn() and L["On"] or L["Off"] end,
        pick = function(name) ns.db.dropCredit = name == L["On"] end,
        -- A part of Share drops, under it as Professions Icons is under
        -- Professions: greyed out, showing Off, while sharing is off (its
        -- own choice is kept for when sharing comes back).
        sub = true,
        needs = function() return ns.Drops:ChannelOn() end,
        needsLabel = L["Share drops"],
        isHidden = IsSharingSwitchedOff,
        about = L["Your character name in NeedRoll's credits"],
        tip = L["On puts your character name, with what you shared, in NeedRoll's credits list. Off stores your finds anonymously."],
    },
}
Settings.OPTIONS = OPTIONS -- for the smoke tests (tests/smoke)

-- A setting's choices as shown, as things are now.
function Settings.Choices(option)
    return type(option.names) == "function" and option.names() or option.names
end

-- The Settings gear (Mike). Where a client hasn't it, the first of
-- FALLBACK_ATLASES it has, else the old options cog.
local SETTINGS_ATLAS = "EditCrossbars-up-c60"
local FALLBACK_ATLASES = { "Crosshair_EngineerSkin_96", "glues-characterSelect-icon-notify-inProgress-hover",
    "QuestLog-icon-setting", "GM-icon-settings" }
local FALLBACK_FILE = "Interface\\Buttons\\UI-OptionsButton"

-- Light blue tooltip lines: what else a choice affects, or where else it is.
local function AddTooltipNote(text)
    local r, g, b = unpack(Theme.tip.info)
    GameTooltip:AddLine(text, r, g, b, true)
end

-- A tooltip: a title, a white description wrapped under it and, if given,
-- a light blue note.
local function ShowTooltip(owner, anchor, title, description, note)
    GameTooltip:SetOwner(owner, anchor)
    GameTooltip:AddLine(title)
    local r, g, b = unpack(Theme.tip.text)
    GameTooltip:AddLine(description, r, g, b, true)
    if note then AddTooltipNote(note) end
    GameTooltip:Show()
end

-- "Settings" with its icon, left of the search box's "!" and boxed like it.
-- The label stays readable at rest so the button is easy to find; hovered,
-- or while the Settings page is open, it lights up gold. A click opens or
-- shuts the page.
-- Drawn like the text tab chips (UI/RecipeBand.lua's Chip): the
-- word in cream, gold and underlined (fading to its ends) while Settings
-- is open, brighter with a faint underline on hover; its gear before it.
local CREAM = { 0.902, 0.863, 0.784 }
local GOLD = { 1, 0.82, 0 }
local BUTTON_HEIGHT = 20 -- the top bar's usual row; SetBarHeight scales from it
local REST_ALPHA = 0.72  -- the label and icon while neither lit nor hovered

-- Draws the gear at `scale` times its usual size: the atlas 20 on its
-- longer side, or on a client without it a fallback icon 16 square.
local function SetButtonIcon(icon, scale)
    if C_Texture.GetAtlasInfo(SETTINGS_ATLAS) then
        Theme:FitAtlas(icon, SETTINGS_ATLAS, 20 * scale)
        return
    end
    icon:SetSize(16 * scale, 16 * scale)
    for _, atlas in ipairs(FALLBACK_ATLASES) do
        if C_Texture.GetAtlasInfo(atlas) then return icon:SetAtlas(atlas) end
    end
    icon:SetTexture(FALLBACK_FILE)
end

-- Sized to its label: 2 before the icon, 4 between it and the word, 7 after.
local function FitButton(button)
    button:SetWidth(2 + button.icon:GetWidth() + 4 + math.ceil(button.text:GetStringWidth()) + 7)
end

local function TintButton(button, lit)
    button.lit = lit
    local hovered = button:IsMouseOver()
    button.icon:SetAlpha((lit or hovered) and 1 or REST_ALPHA)
    local color, textAlpha, underlineAlpha = CREAM, REST_ALPHA, 0
    if lit then
        color, textAlpha, underlineAlpha = GOLD, 1, 1
    elseif hovered then
        textAlpha, underlineAlpha = 1, 0.35
    end
    button.text:SetTextColor(color[1], color[2], color[3], textAlpha)
    button.lines:Set(color, underlineAlpha, 1)
end

-- As tall as the top bar's row wants (UI:SizeTopBar), its text and icon
-- grown to match.
local function SetButtonBarHeight(button, height)
    local scale = height / BUTTON_HEIGHT
    button:SetHeight(height)
    SetButtonIcon(button.icon, scale)
    button.text:SetFontObject(Theme:ScaledFont(Theme.font.small, 1.05 * scale))
    FitButton(button)
    button:Tint(button.lit)
end

function Settings:CreateButton(parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(BUTTON_HEIGHT)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    SetButtonIcon(button.icon, 1)
    button.icon:SetPoint("LEFT", 2, 0)
    button.text = Theme:Text(button, Theme:ScaledFont(Theme.font.small, 1.05))
    button.text:SetPoint("LEFT", button.icon, "RIGHT", 4, 0.5)
    button.text:SetText(L["Settings"])
    button.lines = Theme:ChipUnderline(button, button.text)
    FitButton(button)
    -- Again on show, in case the font arrived late.
    button:HookScript("OnShow", FitButton)
    button.SetBarHeight = SetButtonBarHeight
    button.Tint = TintButton
    button:Tint(false)
    button:SetScript("OnEnter", function()
        button:Tint(ns.UI.settingsOpen)
        ShowTooltip(button, "ANCHOR_BOTTOMLEFT", L["Settings"],
            L["Language, window style, UI scale, the minimap button, the map in dungeons, drop sources on tooltips, a key to open NeedRoll and which tabs to show."])
    end)
    button:SetScript("OnLeave", function()
        button:Tint(ns.UI.settingsOpen)
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", function()
        GameTooltip:Hide()
        ns.UI:ToggleSettings()
    end)
    return button
end

-- A section's heading in gold over a rule, across its column.
-- `atlas`: an icon left of it, 36 on its longer side (as the title's),
-- standing on the rule with the word centred beside it. The rule fades
-- over its last 10% at each end, from full to a quarter (Mike).
local RULE_FADE = 0.1
local function Heading(column, text, atlas)
    local head = CreateFrame("Frame", nil, column)
    head:SetPoint("TOPLEFT")
    head:SetPoint("TOPRIGHT")
    head:SetHeight(HEAD)
    local label = Theme:Text(head, Theme.font.section)
    label:SetPoint("BOTTOMLEFT", 0, 8)
    label:SetText(text)
    if atlas and C_Texture.GetAtlasInfo(atlas) then
        local icon = head:CreateTexture(nil, "ARTWORK")
        Theme:FitAtlas(icon, atlas, 36)
        icon:SetPoint("BOTTOMLEFT", 0, 4)  -- above the rule
        label:ClearAllPoints()
        label:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    end
    -- Three pieces: a fading left end, the solid middle, a fading right end.
    local r, g, b, a = unpack(Theme.color.stripLine)
    a = a or 1
    local solid, faint = CreateColor(r, g, b, a), CreateColor(r, g, b, a * 0.25)
    local rule = {}
    for i = 1, 3 do
        local part = head:CreateTexture(nil, "BORDER")
        part:SetColorTexture(1, 1, 1, 1)
        PixelUtil.SetHeight(part, 1)
        rule[i] = part
    end
    rule[1]:SetPoint("BOTTOMLEFT")
    rule[3]:SetPoint("BOTTOMRIGHT")
    rule[2]:SetPoint("BOTTOMLEFT", rule[1], "BOTTOMRIGHT")
    rule[2]:SetPoint("BOTTOMRIGHT", rule[3], "BOTTOMLEFT")
    rule[1]:SetGradient("HORIZONTAL", faint, solid)
    rule[2]:SetVertexColor(r, g, b, a)
    rule[3]:SetGradient("HORIZONTAL", solid, faint)
    local function SizeRuleEnds(_, width)
        local fadeWidth = math.max(1, (width or 0) * RULE_FADE)
        rule[1]:SetWidth(fadeWidth)
        rule[3]:SetWidth(fadeWidth)
    end
    head:SetScript("OnSizeChanged", SizeRuleEnds)
    SizeRuleEnds(head, head:GetWidth())
    head.rule = rule
    return head
end

-- A row across a column, `y` under its top.
local function ColumnRow(column, y, height)
    local row = CreateFrame("Frame", nil, column)
    row:SetPoint("TOPLEFT", 0, -y)
    row:SetPoint("TOPRIGHT", 0, -y)
    row:SetHeight(height)
    return row
end

-- A row with a switch between `names` at its right.
local function SwitchRow(column, y, height, names, onPick)
    local row = ColumnRow(column, y, height)
    row.switch = Theme:LabelToggle(row, names, onPick)
    -- Its buttons carry 6px of padding at the right edge.
    row.switch:SetPoint("RIGHT", 6, 0)
    -- The switch frame is only its right edge (its words reach left of
    -- it): text beside it stops at its first word.
    row.switchLeft = row.switch.buttons[names[1]]
    return row
end

-- A label with a note under it, stacked about the row's middle, `left`
-- in; the note stops `noteGap` short of the switch.
local function AddLabelAndNote(row, left, noteGap)
    row.label = Theme:Text(row, Theme.font.body)
    row.label:SetPoint("BOTTOMLEFT", row, "LEFT", left, 1)
    row.note = Theme:Text(row, Theme.font.small)
    row.note:SetPoint("TOPLEFT", row, "LEFT", left, -2)
    row.note:SetPoint("RIGHT", row.switchLeft, "LEFT", -noteGap, 0)
    row.note:SetJustifyH("LEFT")
end

-- Hovering a row's label shows `title` and `tip` in a tooltip.
local function AddLabelTooltip(row, title, tip)
    local hit = CreateFrame("Frame", nil, row)
    hit:SetAllPoints(row.label)
    hit:EnableMouseMotion(true)
    hit:SetScript("OnEnter", function() ShowTooltip(hit, "ANCHOR_RIGHT", title, tip) end)
    hit:SetScript("OnLeave", GameTooltip_Hide)
end

-- A row with `label` at its left and, at its right, a box showing the
-- choice (row.box, its text row.box.text): the Language and Key binding
-- rows. The box is unlit until hovered or in use.
local function BoxRow(column, y, label)
    local row = ColumnRow(column, y, ROW)
    row.label = Theme:Text(row, Theme.font.body)
    row.label:SetPoint("LEFT")
    row.label:SetText(label)
    local box = CreateFrame("Button", nil, row)
    box:SetHeight(20)
    box:SetPoint("RIGHT")
    Theme:Rounded(box, Theme.color.hover, Theme.native and Theme.color.line or Theme.color.edge)
    box.bg:Hide()
    box.text = Theme:Text(box, Theme.font.label)
    box.text:SetPoint("CENTER")
    row.box = box
    return row
end

-- A row's box sized to its text: 10 either side, 80 at the least.
local function FitBox(box)
    box:SetWidth(math.max(80, math.ceil(box.text:GetStringWidth()) + 20))
end

-- Greys a switch out (a choice that can't be changed right now) or not.
local function EnableSwitch(switch, enabled)
    switch:SetAlpha(enabled and 1 or 0.35)
    for _, button in pairs(switch.buttons) do button:SetEnabled(enabled) end
end

local function ShowModuleTooltip(row)
    local info = row.info
    GameTooltip:SetOwner(row, "ANCHOR_TOPLEFT")
    GameTooltip:AddLine(info.label)
    local r, g, b = unpack(Theme.tip.text)
    GameTooltip:AddLine(info.about, r, g, b, true)
    if info.detail then GameTooltip:AddLine(info.detail, r, g, b, true) end
    if info.requires then
        local needed = ns.Modules.byKey[info.requires].label
        AddTooltipNote(L["Needs %s: it is off while %s is."]:format(needed, needed))
    end
    -- The modules that need this one to work, as "Shopping List".
    local dependents = {}
    for _, other in ipairs(ns.Modules.list) do
        if other.requires == info.key then table.insert(dependents, other.label) end
    end
    if #dependents > 0 then
        AddTooltipNote(L["Turning it off turns off %s too."]:format(table.concat(dependents, ", ")))
    end
    GameTooltip:Show()
end

-- Key binding --------------------------------------------------------------
-- The key that opens and shuts the window: the game's own binding
-- (Bindings.xml), so this row and the game's Key Bindings always match.
-- Click the box and press a key to set one (Escape cancels); right-click
-- clears it.
local BINDING = "NEEDROLL_TOGGLE"
-- Keys that only modify another key, so capturing waits for the next one.
local MODIFIERS = {
    LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true,
    LALT = true, RALT = true, LMETA = true, RMETA = true, UNKNOWN = true,
}

-- The game won't change bindings in combat: says so and returns true then.
local function BlockedByCombat()
    if not InCombatLockdown() then return false end
    ns:Print(L["Key bindings can't be changed in combat."])
    return true
end

-- Points the binding at `key` alone (nil: no key) and saves it.
local function Bind(key)
    if BlockedByCombat() then return end
    for _, oldKey in ipairs({ GetBindingKey(BINDING) }) do SetBinding(oldKey) end
    if key then
        local action = GetBindingAction(key)
        if action ~= "" and action ~= BINDING then
            local actionName = _G["BINDING_NAME_" .. action] or action
            ns:Print(L["%s was bound to %s. It now toggles NeedRoll."]:format(GetBindingText(key), actionName))
        end
        SetBinding(key, BINDING)
    end
    SaveBindings(GetCurrentBindingSet())
end

-- The box listens for a key only after a click on it: it takes the
-- keyboard (and its key handler) then, and gives both back when a key
-- is set, on Escape, a click anywhere else, the page closing or combat.
-- A key already bound to something else isn't taken until it's pressed
-- a second time.
local OnCapturedKey
local function SetCapturing(row, on)
    local box = row.box
    box.capturing, box.pending = on or nil, nil
    box:SetScript("OnKeyDown", on and OnCapturedKey or nil)
    if on then box:SetPropagateKeyboardInput(false) end
    box:EnableKeyboard(on and true or false)
    if on then row:RegisterEvent("GLOBAL_MOUSE_DOWN") else row:UnregisterEvent("GLOBAL_MOUSE_DOWN") end
    row:Refresh()
end

OnCapturedKey = function(box, key)
    if not box.capturing or MODIFIERS[key] then return end
    local row = box:GetParent()
    if key == "ESCAPE" then return SetCapturing(row, false) end
    local chord = CreateKeyChordStringUsingMetaKeyState(key)
    local action = GetBindingAction(chord)
    if action ~= "" and action ~= BINDING and box.pending ~= chord then
        box.pending = chord
        row:Refresh()
        return
    end
    Bind(chord)
    SetCapturing(row, false)
end

local function OnKeyBoxClick(box, mouseButton)
    GameTooltip:Hide()
    local row = box:GetParent()
    if box.capturing then
        SetCapturing(row, false)
    elseif mouseButton == "RightButton" then
        Bind(nil)
        row:Refresh()
    elseif not BlockedByCombat() then
        SetCapturing(row, true)
    end
end

-- The row: the label at the left and, at the right, the box showing the
-- key, with its clicks, keys and tooltip wired up.
local function KeyRow(column, y)
    local row = BoxRow(column, y, L["Key binding"])
    local box = row.box
    box:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Shows the key, or what to press while listening.
    row.Refresh = function()
        local key = GetBindingKey(BINDING)
        if box.capturing and box.pending then
            box.text:SetText(L["Press %s again to replace it"]:format(GetBindingText(box.pending)))
        elseif box.capturing then
            box.text:SetText(L["Press any button to bind/Escape to exit"])
        else
            box.text:SetText(key and GetBindingText(key) or L["Not set"])
        end
        Theme:SetTextColor(box.text, (box.capturing or key) and Theme.color.heading or Theme.color.muted)
        box.bg:SetShown(box.capturing or box:IsMouseOver())
        FitBox(box)
    end

    box:EnableKeyboard(false)
    box:SetScript("OnClick", OnKeyBoxClick)
    box:SetScript("OnHide", function() if box.capturing then SetCapturing(row, false) end end)
    box:SetScript("OnEnter", function()
        box.bg:Show()
        ShowTooltip(box, "ANCHOR_TOPLEFT", L["Toggle NeedRoll"],
            L["Click, then press a key to open and close NeedRoll with it. Right-click to clear it."],
            L["Also in the game's Key Bindings, under AddOns."])
    end)
    box:SetScript("OnLeave", function()
        GameTooltip:Hide()
        row:Refresh()
    end)
    -- A key set in the game's Key Bindings shows here too. Combat ends
    -- listening (bindings can't change then), and so does a click anywhere
    -- but the box.
    row:RegisterEvent("UPDATE_BINDINGS")
    row:RegisterEvent("PLAYER_REGEN_DISABLED")
    row:SetScript("OnEvent", function(_, event)
        local clickedElsewhere = event == "GLOBAL_MOUSE_DOWN" and not box:IsMouseOver()
        if box.capturing and (event == "PLAYER_REGEN_DISABLED" or clickedElsewhere) then SetCapturing(row, false) end
        row:Refresh()
    end)
    row:Refresh()
    return row
end

-- Language -----------------------------------------------------------------
-- The language of NeedRoll's own text (ns.Language, Locales/Locales.lua):
-- the game's, or one NeedRoll has text in, picked from a menu under the
-- box. NeedRoll looks its text up as its files load, so a new pick shows
-- after the interface reloads, which a dialog offers to do now.
local LANGUAGE_MENU_WIDTH = 200
local RELOAD_DIALOG_WIDTH, RELOAD_DIALOG_HEIGHT = 360, 140

-- The language picked in NeedRollDB.language, nil for the game's.
local function PickedLanguage()
    return ns.KnownLanguage(ns.db.language)
end

-- The picked language by its own name ("Deutsch"), or Game language.
local function PickedLanguageName()
    local picked = PickedLanguage()
    return picked and ns.LanguageName(picked) or L["Game language"]
end

-- Says the new language shows after a reload: Reload now, or Later.
local function CreateReloadDialog(page)
    local dialog = Theme:Dialog(page, RELOAD_DIALOG_WIDTH, RELOAD_DIALOG_HEIGHT, L["Language"])
    dialog:AddHint(L["NeedRoll switches to the new language after the interface reloads."])
    dialog.hint:SetWidth(RELOAD_DIALOG_WIDTH - Theme.size.pad * 2)
    dialog.hint:SetWordWrap(true)
    dialog.hint:SetJustifyH("LEFT")
    dialog:Buttons(L["Reload now"], ReloadUI)
    dialog.cancel:SetLabel(L["Later"])
    return dialog
end

-- Saves `code` (nil: Game language) and offers the reload; the language
-- already picked only closes the menu. No reload is offered (and an offer
-- still up closes) when the text is already in the new pick's language: the
-- client's own language picked by name, or a pick taken back before reloading.
local function PickLanguage(page, row, code)
    row.menu:Hide()
    if code == PickedLanguage() then return end
    ns.db.language = code
    row:Refresh()
    if not ns.LanguageNeedsReload(code) then
        if page.reloadDialog then page.reloadDialog:Close() end
        return
    end
    page.reloadDialog = page.reloadDialog or CreateReloadDialog(page)
    page.reloadDialog:Open()
end

-- Game language, a rule, then each language in its own words, the
-- picked one in the heading color.
local function CreateLanguageMenu(page, row)
    local menu = Theme:Menu(page, LANGUAGE_MENU_WIDTH)
    menu:SetPoint("TOPRIGHT", row.box, "BOTTOMRIGHT", 0, -4)
    menu.anchor = row.box
    function menu:Fill()
        self:Begin()
        local picked = PickedLanguage()
        local function AddLanguage(name, code)
            local color = code == picked and Theme.color.heading or Theme.color.text
            self:AddRow(name, color, function() PickLanguage(page, row, code) end)
        end
        AddLanguage(L["Game language"], nil)
        self:AddRule()
        for _, language in ipairs(ns.LANGUAGES) do AddLanguage(language.name, language.code) end
        self:Finish()
    end
    return menu
end

local function LanguageRow(page, column, y)
    local row = BoxRow(column, y, L["Language"])
    AddLabelTooltip(row, L["Language"],
        L["NeedRoll's own text (labels, buttons, notes, tooltips) changes. Names from the game (items, places, creatures, quests) stay in the game's language."])
    local box = row.box
    row.menu = CreateLanguageMenu(page, row)

    -- Shows the picked language, the box lit while hovered or its menu is open.
    row.Refresh = function()
        box.text:SetText(PickedLanguageName())
        Theme:SetTextColor(box.text, PickedLanguage() and Theme.color.heading or Theme.color.muted)
        box.bg:SetShown(row.menu:IsShown() or box:IsMouseOver())
        FitBox(box)
    end

    box:SetScript("OnClick", function()
        row.menu:SetShown(not row.menu:IsShown())
        row:Refresh()
    end)
    box:SetScript("OnEnter", function() box.bg:Show() end)
    box:SetScript("OnLeave", function() row:Refresh() end)
    row.menu:HookScript("OnHide", function() row:Refresh() end)
    -- Leaving the page shuts the menu and the reload dialog.
    page:HookScript("OnHide", function()
        row.menu:Hide()
        if page.reloadDialog then page.reloadDialog:Close() end
    end)
    row:Refresh()
    return row
end

-- General ------------------------------------------------------------------
local SMALL_LINE = 14 -- a line of small text, for the column's notes
local NOTE_GAP = 8    -- above a column's note

-- The loot grid's two collection ticks after `label`: collected (in
-- color), then not yet (grey).
local function AddCollectionTicks(row, label)
    local previous = label
    for _, collected in ipairs({ true, false }) do
        local tick = row:CreateTexture(nil, "ARTWORK")
        tick:SetAtlas("common-icon-checkmark")
        tick:SetSize(14, 14)
        tick:SetPoint("LEFT", previous, "RIGHT", previous == label and 6 or 2, 0)
        tick:SetDesaturated(not collected)
        previous = tick
    end
end

-- One setting's row, `y` down the column. Returns its height.
local function AddOptionRow(page, column, option, y)
    local height = option.about and MODULE_ROW or ROW
    local row = SwitchRow(column, y, height, Settings.Choices(option), function(name)
        if name ~= option.current() then option.pick(name) end
        -- A new style is a new window, whose own page takes over.
        if page:IsVisible() then page:Refresh() end
    end)
    local left = option.sub and SUB_INDENT or 0
    if option.about then
        AddLabelAndNote(row, left, 8)
        row.note:SetWordWrap(false)
        row.note:SetText(option.about)
        Theme:SetTextColor(row.note, Theme.color.muted)
    else
        row.label = Theme:Text(row, Theme.font.body)
        row.label:SetPoint("LEFT", left, 0)
    end
    row.label:SetText(option.label)
    if option.ticks then AddCollectionTicks(row, row.label) end
    if option.tip then AddLabelTooltip(row, option.label, option.tip) end
    row.option = option
    table.insert(page.general, row)
    return height
end

-- The General column: the player's settings, then the slash commands
-- that do the same. Returns its height.
local function BuildGeneral(page, column)
    Heading(column, L["General"], "EditRadials-up-c60")
    local y = HEAD + 6
    page.languageRow = LanguageRow(page, column, y)
    y = y + ROW
    for _, option in ipairs(OPTIONS) do
        if not (option.isHidden and option.isHidden()) then y = y + AddOptionRow(page, column, option, y) end
    end
    page.keyRow = KeyRow(column, y)
    y = y + ROW
    local hint = Theme:Text(column, Theme.font.hint)
    hint:SetPoint("TOPLEFT", 0, -y - NOTE_GAP)
    hint:SetText(L["Also: /nr style  ·  /nr text  ·  /nr minimap"])
    return y + NOTE_GAP + SMALL_LINE
end

-- Modules ------------------------------------------------------------------
local function AddModuleRow(page, column, info, y)
    local row = SwitchRow(column, y, MODULE_ROW, { L["On"], L["Off"] }, function(name)
        ns.Modules:Set(info.key, name == L["On"])
        if page:IsVisible() then page:Refresh() end
    end)
    row.info = info
    local left = (info.sub and not info.own) and SUB_INDENT or 0
    -- Its tab's icon, or for a part of a tab with no icon of its own a
    -- sample of what it shows (an item in the recipe list's ring).
    if info.sub and not info.atlas then
        row.icon = ns.UI.RecipeIcon(row, ICON + 2)
        row.icon:SetItem(SAMPLE_ITEM)
        row.icon:EnableMouse(false)
    else
        row.icon = row:CreateTexture(nil, "ARTWORK")
        local atlas = info.atlas or ns.UI.TabIcon(info.key)
        if atlas then Theme:FitAtlas(row.icon, atlas, ICON) end
        row.icon:SetShown(atlas ~= nil)
    end
    row.icon:SetPoint("CENTER", row, "LEFT", left + ICON / 2, 0)
    -- A long note wraps before the switch rather than running under it.
    AddLabelAndNote(row, left + ICON + 10, 24)
    row.label:SetText(info.label)
    row.note:SetWordWrap(true)
    row.note:SetMaxLines(2)
    row:EnableMouse(true)
    row:SetScript("OnEnter", ShowModuleTooltip)
    row:SetScript("OnLeave", GameTooltip_Hide)
    table.insert(page.modules, row)
end

-- The Modules column: a row per tab, with its icon, name and what it
-- holds (or why it can't be changed now). Returns its height.
local function BuildModules(page, column)
    Heading(column, L["Modules"], "Spellbook-up-c60")
    local note = Theme:Text(column, Theme.font.small)
    note:SetPoint("TOPLEFT", 0, -HEAD - NOTE_GAP)
    note:SetText(L["Each module is a tab. One turned off is hidden and not loaded."])
    local y = HEAD + NOTE_GAP + SMALL_LINE + 4
    for _, info in ipairs(ns.Modules.list) do
        AddModuleRow(page, column, info, y)
        y = y + MODULE_ROW
    end
    return y
end

-- Discord ----------------------------------------------------------------
-- Addons can't open a browser, so the button shows the invite in a box,
-- selected for Ctrl+C.

local DISCORD_ICON = [[Interface\AddOns\NeedRoll\Media\Discord]]
local DISCORD_COLOR = { 0x58 / 255, 0x65 / 255, 0xF2 / 255, 1 } -- Discord's blurple
local DISCORD_WIDTH, DISCORD_HEIGHT = 440, 176

local function CreateDiscordDialog(page)
    local pad = Theme.size.pad
    local dialog = Theme:Dialog(page, DISCORD_WIDTH, DISCORD_HEIGHT, L["NeedRoll on Discord"])
    dialog.hint = Theme:Text(dialog, Theme.font.small)
    dialog.hint:SetPoint("TOPLEFT", dialog.title, "BOTTOMLEFT", 0, -6)
    dialog.hint:SetWidth(DISCORD_WIDTH - pad * 2)
    dialog.hint:SetWordWrap(true)
    dialog.hint:SetJustifyH("LEFT")
    dialog.hint:SetText(L["Report a bug or a translation mistake, or suggest a feature. Press Ctrl+C to copy the invite, then paste it in your browser."])
    dialog.copied = Theme:Text(dialog, Theme.font.small)
    dialog.copied:SetPoint("BOTTOMLEFT", pad, pad + 4)
    Theme:SetTextColor(dialog.copied, Theme.color.complete)
    dialog.input = Theme:LinkBox(dialog, DISCORD_WIDTH - pad * 2, ns.DISCORD_URL, function()
        dialog.copied:SetText(L["Copied. Paste it in your browser."])
    end)
    dialog.input:SetPoint("TOPLEFT", dialog.hint, "BOTTOMLEFT", Theme.native and 6 or 0, -12)
    dialog.input:SetScript("OnEscapePressed", function() dialog:Close() end)
    dialog.input:SetScript("OnEnterPressed", function() dialog:Close() end)
    dialog:Buttons(nil)
    dialog.cancel:SetLabel(L["Done"])
    function dialog:Present()
        self.copied:SetText("")
        self:Open()
        self.input:Select()
    end
    return dialog
end

-- The Discord logo in a small box, lit on hover like the Settings button.
local function CreateDiscordButton(parent, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(26, 22)
    Theme:Rounded(button, Theme.color.hover, Theme.native and Theme.color.line or Theme.color.edge)
    button.bg:Hide()
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetTexture(DISCORD_ICON)
    button.icon:SetSize(18, 18)
    button.icon:SetPoint("CENTER")
    button.icon:SetVertexColor(unpack(DISCORD_COLOR))
    button:SetScript("OnEnter", function()
        button.bg:Show()
        ShowTooltip(button, "ANCHOR_BOTTOMLEFT", L["NeedRoll on Discord"],
            L["Report bugs and translation mistakes, or suggest a feature."])
    end)
    button:SetScript("OnLeave", function()
        button.bg:Hide()
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", function()
        GameTooltip:Hide()
        onClick()
    end)
    return button
end

-- The page ---------------------------------------------------------------
-- Scrolling (AddScrolling, ScrollPageTo) is the Game hotfixes page's and the
-- Professions tab's filter sidebar's (UI/RecipeBand.lua) too.
local function ScrollPageTo(page, offset)
    local maxOffset = math.max(0, page.canvas:GetHeight() - page.scroll:GetHeight())
    offset = math.min(maxOffset, math.max(0, offset))
    page.offset = offset
    page.scroll:SetVerticalScroll(offset)
    page.scrollBar:Update(offset, maxOffset, page.scroll:GetHeight())
end

-- The scroll frame the page's content sits in, and its bar. Returns the
-- canvas the content goes on.
local function AddScrolling(page)
    local scroll = CreateFrame("ScrollFrame", nil, page)
    scroll:SetPoint("TOPLEFT", 0, -4)
    scroll:SetPoint("BOTTOMRIGHT", 0, 4)
    local canvas = CreateFrame("Frame", nil, scroll)
    canvas:SetSize(1, 1)
    scroll:SetScrollChild(canvas)
    page.scroll, page.canvas = scroll, canvas
    page.scrollBar = Theme:ScrollBar(page, 8, 8, function(offset) ScrollPageTo(page, offset) end)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta) ScrollPageTo(page, page.offset - delta * ROW * 2) end)
    scroll:SetScript("OnSizeChanged", function(_, width)
        canvas:SetWidth(width)
        ScrollPageTo(page, page.offset)
    end)
    return canvas
end
Settings.ScrollPageTo, Settings.AddScrolling = ScrollPageTo, AddScrolling

-- The title with the Settings gear before it (36 on its longer side), the
-- line under it and the Discord button at the right.
local function AddTitle(page, canvas)
    local title = Theme:Text(canvas, Theme.font.heading)
    title:SetPoint("TOPLEFT", PAD, -PAD + 4)
    title:SetText(L["Settings"])
    if C_Texture.GetAtlasInfo(SETTINGS_ATLAS) then
        local icon = canvas:CreateTexture(nil, "ARTWORK")
        Theme:FitAtlas(icon, SETTINGS_ATLAS, 36)
        icon:SetPoint("LEFT", canvas, "TOPLEFT", PAD, -PAD + 4 - 8)
        title:SetPoint("TOPLEFT", PAD + icon:GetWidth() + 6, -PAD + 4)
    end
    local subtitle = Theme:Text(canvas, Theme.font.small)
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText(L["Saved for every character on this account."])
    page.discord = CreateDiscordButton(canvas, function()
        page.discordDialog = page.discordDialog or CreateDiscordDialog(page)
        page.discordDialog:Present()
    end)
    page.discord:SetPoint("TOPRIGHT", -PAD, -PAD + 2)
    -- Leaving the page shuts the invite, so it doesn't greet the next visit.
    page:HookScript("OnHide", function() if page.discordDialog then page.discordDialog:Close() end end)
end

-- Under the columns, small and muted (lit on hover): the way to the Game
-- hotfixes page, kept out of the tabs on purpose. Sized to its word, again
-- on show in case the font arrived late.
local HOTFIXES_LINK_GAP = 16    -- under the taller column
local HOTFIXES_LINK_HEIGHT = 16

local function FitHotfixesLink(link)
    link:SetWidth(math.ceil(link.text:GetStringWidth()))
end

local function AddHotfixesLink(canvas, y)
    local link = CreateFrame("Button", nil, canvas)
    link:SetHeight(HOTFIXES_LINK_HEIGHT)
    link:SetPoint("TOPLEFT", PAD, -y)
    link.text = Theme:Text(link, Theme.font.small)
    link.text:SetPoint("LEFT")
    link.text:SetText(L["Game hotfixes"])
    Theme:SetTextColor(link.text, Theme.color.muted)
    FitHotfixesLink(link)
    link:HookScript("OnShow", FitHotfixesLink)
    link:SetScript("OnEnter", function()
        Theme:SetTextColor(link.text, Theme.color.text)
        ShowTooltip(link, "ANCHOR_TOPLEFT", L["Game hotfixes"],
            L["Blizzard's WoW: Forever hotfixes, in short. Ones Blizzard takes back stay, struck through."],
            L["Also: /nr hotfixes"])
    end)
    link:SetScript("OnLeave", function()
        Theme:SetTextColor(link.text, Theme.color.muted)
        GameTooltip:Hide()
    end)
    link:SetScript("OnClick", function()
        GameTooltip:Hide()
        ns.UI:OpenHotfixes()
    end)
    return link
end

-- A setting whose `needs` isn't met (Credit my finds while sharing is off)
-- shows Off, greyed out, saying what it needs; its own choice is kept.
local function RefreshOptionRow(row)
    local option = row.option
    local isBlocked = option.needs and not option.needs()
    row.switch:SetActive(isBlocked and L["Off"] or option.current())
    if not option.needs then return end
    EnableSwitch(row.switch, not isBlocked)
    Theme:SetTextColor(row.label, isBlocked and Theme.color.faint or Theme.color.text)
    row.note:SetText(isBlocked and L["Needs %s"]:format(option.needsLabel) or option.about)
    Theme:SetTextColor(row.note, isBlocked and Theme.color.note or Theme.color.muted)
end

-- A module that needs one that is off, or the last tab left on, is
-- greyed out, its note saying why.
local function RefreshModuleRow(row)
    local Modules, info = ns.Modules, row.info
    local isOn = Modules:IsOn(info.key)
    local isMissingRequirement = info.requires and not Modules:IsOn(info.requires)
    local isLastOn = isOn and not Modules:CanTurnOff(info.key)
    local whyGreyed = isMissingRequirement and L["Needs %s"]:format(Modules.byKey[info.requires].label)
        or isLastOn and L["One module always stays on"] or nil
    row.switch:SetActive(isOn and L["On"] or L["Off"])
    EnableSwitch(row.switch, not whyGreyed)
    row.icon:SetDesaturated(not isOn)
    row.icon:SetAlpha(isOn and 1 or 0.5)
    Theme:SetTextColor(row.label, isMissingRequirement and Theme.color.faint or Theme.color.text)
    row.note:SetText(whyGreyed or info.about)
    Theme:SetTextColor(row.note, whyGreyed and Theme.color.note or Theme.color.muted)
end

local function RefreshPage(page)
    page.languageRow:Refresh()
    for _, row in ipairs(page.general) do RefreshOptionRow(row) end
    page.keyRow:Refresh()
    for _, row in ipairs(page.modules) do RefreshModuleRow(row) end
    ScrollPageTo(page, page.offset)
end

-- The page, inside a content pane the window draws (with Back in its
-- strip). Its two columns, General and Modules, side by side, scroll when
-- the window is too short for them.
function Settings:CreatePage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page.general, page.modules, page.offset = {}, {}, 0
    page.Refresh = RefreshPage
    local canvas = AddScrolling(page)
    AddTitle(page, canvas)

    local top = PAD + 44 -- under the title, its subtitle and the gap below them
    local left = CreateFrame("Frame", nil, canvas)
    left:SetPoint("TOPLEFT", PAD, -top)
    left:SetPoint("TOPRIGHT", canvas, "TOP", -COLUMN_GAP / 2, -top)
    local right = CreateFrame("Frame", nil, canvas)
    right:SetPoint("TOPLEFT", canvas, "TOP", COLUMN_GAP / 2, -top)
    right:SetPoint("TOPRIGHT", -PAD, -top)
    local height = math.max(BuildGeneral(page, left), BuildModules(page, right))
    left:SetHeight(height)
    right:SetHeight(height)
    page.hotfixesLink = AddHotfixesLink(canvas, top + height + HOTFIXES_LINK_GAP)
    canvas:SetHeight(top + height + HOTFIXES_LINK_GAP + HOTFIXES_LINK_HEIGHT + PAD)
    return page
end
