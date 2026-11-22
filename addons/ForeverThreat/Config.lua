local addonName, FT = ...

local TAB_ORDER = { "welcome", "display", "warnings", "raid", "appearance", "statistics", "general", "profile" }
local TAB_KEYS = {
    welcome = "TAB_WELCOME",
    display = "TAB_DISPLAY",
    appearance = "TAB_APPEARANCE",
    warnings = "TAB_WARNINGS",
    raid = "TAB_RAID",
    statistics = "TAB_STATISTICS",
    general = "TAB_GENERAL",
    profile = "TAB_PROFILE",
}

-- Exactly six selectable languages. Automatic client detection is handled
-- internally on first launch and is intentionally not exposed as an option.
local LANGUAGE_OPTIONS = {
    { code = "DE", label = "Deutsch" },
    { code = "EN", label = "English" },
    { code = "ES", label = "Español" },
    { code = "FR", label = "Français" },
    { code = "KO", label = "한국어" },
    { code = "RU", label = "Русский" },
}

local function GetLanguageLabel(code)
    for _, option in ipairs(LANGUAGE_OPTIONS) do
        if option.code == code then
            return option.label
        end
    end
    return "English"
end

local function SetTextColor(fs, r, g, b)
    if fs then
        fs:SetTextColor(r, g, b)
    end
end

local CYRILLIC_BUTTON_FONT = "Fonts\\FRIZQT___CYR.TTF"
local KOREAN_BUTTON_FONT = "Fonts\\2002.TTF"

local function ApplyLanguageOptionButtonFont(button, languageCode)
    if not button or type(button.GetFontString) ~= "function" then
        return
    end

    local fs = button:GetFontString()
    if not fs or type(fs.GetFont) ~= "function" or type(fs.SetFont) ~= "function" then
        return
    end

    local _, currentSize, currentFlags = fs:GetFont()
    local size = tonumber(currentSize) or 12
    local flags = currentFlags

    local fontPath
    if languageCode == "RU" then
        fontPath = CYRILLIC_BUTTON_FONT
    elseif languageCode == "KO" then
        fontPath = KOREAN_BUTTON_FONT
    end

    if fontPath then
        pcall(fs.SetFont, fs, fontPath, size, flags)
        button.languageSpecificFont = fontPath
        return
    end

    button.languageSpecificFont = nil
    if _G.GameFontNormal and type(GameFontNormal.GetFont) == "function" then
        local font, normalSize, normalFlags = GameFontNormal:GetFont()
        if font then
            pcall(fs.SetFont, fs, font, normalSize or size, normalFlags)
        end
    end
end

local function ApplyLocalizedButtonFont(button)
    if not button or type(button.GetFontString) ~= "function" then
        return
    end

    if button.languageCode then
        ApplyLanguageOptionButtonFont(button, button.languageCode)
        return
    end

    local fs = button:GetFontString()
    if not fs or type(fs.GetFont) ~= "function" or type(fs.SetFont) ~= "function" then
        return
    end

    local _, currentSize, currentFlags = fs:GetFont()
    local size = tonumber(currentSize) or 12
    local flags = currentFlags
    local language = FT:GetLanguage()

    local fontPath
    if language == "RU" then
        fontPath = CYRILLIC_BUTTON_FONT
    elseif language == "KO" then
        fontPath = KOREAN_BUTTON_FONT
    end

    if fontPath then
        local ok = pcall(fs.SetFont, fs, fontPath, size, flags)
        if ok then
            button.localizedFontPath = fontPath
            return
        end
    end

    button.localizedFontPath = nil

    -- Restore the standard WoW font for Latin-based UI languages.
    if _G.GameFontNormal and type(GameFontNormal.GetFont) == "function" then
        local font, normalSize, normalFlags = GameFontNormal:GetFont()
        if font then
            pcall(fs.SetFont, fs, font, normalSize or size, normalFlags)
        end
    end
end

local function FitLocalizedButtonText(button)
    if not button or type(button.GetFontString) ~= "function" then
        return
    end

    ApplyLocalizedButtonFont(button)

    local fs = button:GetFontString()
    if not fs or type(fs.GetFont) ~= "function" or type(fs.SetFont) ~= "function" then
        return
    end

    local font, _, flags = fs:GetFont()
    if not font then
        return
    end

    local width = tonumber(button:GetWidth()) or 0
    if width <= 0 then
        return
    end

    local maxSize = button.localizedMaxFontSize or 12
    local minSize = button.localizedMinFontSize or 9
    local padding = button.localizedTextPadding or 18
    local available = math.max(20, width - padding)

    fs:SetFont(font, maxSize, flags)

    local size = maxSize
    while size > minSize and fs:GetStringWidth() > available do
        size = size - 1
        fs:SetFont(font, size, flags)
    end
end

local function BindLocale(parent, widget, key)
    local root = parent.configRoot or parent
    root.localeWidgets = root.localeWidgets or {}
    widget.localeKey = key
    root.localeWidgets[#root.localeWidgets + 1] = widget
    widget:SetText(FT:L(key))

    if type(widget.GetObjectType) == "function" and widget:GetObjectType() == "Button" then
        FitLocalizedButtonText(widget)
    end

    return widget
end

local function AddTitle(parent, key, y)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, y or -8)
    BindLocale(parent, title, key)
    title:SetTextColor(1.0, 0.55, 0.16)
    local root = parent.configRoot or parent
    root.skinAccentTitles = root.skinAccentTitles or {}
    root.skinAccentTitles[#root.skinAccentTitles + 1] = { widget = title, role = "title" }
    return title
end

local function AddSectionTitle(parent, key, x, y)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 8, y)
    BindLocale(parent, title, key)
    title:SetTextColor(1.0, 0.82, 0.25)
    local root = parent.configRoot or parent
    root.skinAccentTitles = root.skinAccentTitles or {}
    root.skinAccentTitles[#root.skinAccentTitles + 1] = { widget = title, role = "accent" }
    return title
end

local function AddDescription(parent, key, anchor, yOffset)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset or -8)
    fs:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    fs:SetWordWrap(true)
    BindLocale(parent, fs, key)
    return fs
end

local function CreateButton(parent, key, width, x, y, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 130, 24)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    BindLocale(parent, button, key)
    button:SetScript("OnClick", onClick)
    return button
end

local function CreateCheckbox(parent, key, labelKey, x, y, onChanged)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", check, "RIGHT", 3, 0)
    BindLocale(parent, text, labelKey)

    check.label = text
    check.dbKey = key
    check:SetScript("OnClick", function(self)
        FT.db[key] = self:GetChecked() and true or false
        if onChanged then
            onChanged(FT.db[key])
        else
            FT:ApplySettings()
        end
        FT:RefreshConfigControls()
    end)

    parent.controls[key] = check
    return check
end

local function RoundToStep(value, step)
    if not step or step <= 0 then
        return value
    end
    return math.floor((value / step) + 0.5) * step
end

local function CreateSlider(parent, key, labelKey, x, y, width, minValue, maxValue, step, formatter, onChanged)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    BindLocale(parent, title, labelKey)

    local valueText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    valueText:SetPoint("TOPRIGHT", parent, "TOPLEFT", x + width, y)
    valueText:SetJustifyH("RIGHT")

    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 22)
    slider:SetWidth(width)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end

    slider.dbKey = key
    slider.valueText = valueText
    slider.formatter = formatter
    slider:SetScript("OnValueChanged", function(self, value)
        if self.syncing then
            return
        end

        value = RoundToStep(value, step)
        FT.db[key] = value

        if formatter then
            valueText:SetText(formatter(value))
        else
            valueText:SetText(tostring(value))
        end

        if onChanged then
            onChanged(value)
        else
            FT:ApplySettings()
        end
    end)

    parent.controls[key] = slider
    return slider
end

local function CreateProfileEditBox(parent, x, y, width)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width or 550, 28)
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    box:SetAutoFocus(false)
    box:SetFontObject("ChatFontNormal")
    box:SetTextInsets(6, 6, 0, 0)
    box:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    box:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    return box
end

local function CreatePage(frame, name)
    local page = CreateFrame("Frame", nil, frame)
    page.configRoot = frame
    page:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -92)
    page:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 18)
    page:Hide()
    page.controls = {}
    frame.pages[name] = page
    return page
end

function FT:CreateConfigUI()
    if self.configFrame then
        return
    end

    local frame = CreateFrame("Frame", "ForeverThreatConfigFrame", UIParent, "BackdropTemplate")
    self.configFrame = frame
    frame.configRoot = frame
    frame.localeWidgets = {}
    frame.skinAccentTitles = {}
    frame:SetSize(640, 770)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:Hide()

    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.025, 0.025, 0.025, 0.98)
    frame:SetBackdropBorderColor(0.55, 0.32, 0.12, 1)

    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -15)
    title:SetText("FOREVERTHREAT")
    title:SetTextColor(1.0, 0.55, 0.16)
    frame.skinTitle = title

    frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.subtitle:SetPoint("LEFT", title, "RIGHT", 10, -1)
    frame.subtitle:SetTextColor(0.75, 0.75, 0.75)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3)

    local divider = frame:CreateTexture(nil, "BORDER")
    divider:SetColorTexture(0.55, 0.32, 0.12, 0.7)
    frame.skinDivider = divider
    divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -78)
    divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -78)
    divider:SetHeight(1)

    frame.tabs = {}
    frame.pages = {}

    local tabX = 18
    for _, tabName in ipairs(TAB_ORDER) do
        local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetSize(70, 26)
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", tabX, -46)
        button.localizedMinFontSize = 8
        button.localizedTextPadding = 12
        BindLocale(frame, button, TAB_KEYS[tabName])
        button.tabName = tabName
        button:SetScript("OnClick", function(self)
            FT:SelectConfigTab(self.tabName)
        end)
        frame.tabs[tabName] = button
        tabX = tabX + 74
    end

    -- Welcome
    local welcome = CreatePage(frame, "welcome")

    local logo = welcome:CreateTexture(nil, "ARTWORK")
    logo:SetTexture("Interface\\AddOns\\ForeverThreat\\Media\\WelcomeLogo")
    logo:SetSize(190, 190)
    logo:SetPoint("TOP", welcome, "TOP", 0, -6)

    local welcomeTitle = AddTitle(welcome, "WELCOME_TITLE", -8)
    welcomeTitle:ClearAllPoints()
    welcomeTitle:SetPoint("TOP", logo, "BOTTOM", 0, -8)
    welcomeTitle:SetJustifyH("CENTER")

    local intro = AddDescription(welcome, "WELCOME_INTRO", welcomeTitle, -8)
    intro:ClearAllPoints()
    intro:SetPoint("TOP", welcomeTitle, "BOTTOM", 0, -8)
    intro:SetWidth(540)
    intro:SetJustifyH("CENTER")
    intro:SetJustifyV("TOP")

    local supportButton = CreateButton(welcome, "SUPPORT_BUTTON", 190, 0, 0, function()
        FT:OpenSupportWindow()
    end)
    supportButton:ClearAllPoints()
    supportButton:SetPoint("TOP", intro, "BOTTOM", 0, -14)
    frame.supportButton = supportButton

    local quickTitle = welcome:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    quickTitle:SetPoint("TOPLEFT", welcome, "TOPLEFT", 42, -376)
    quickTitle:SetPoint("RIGHT", welcome, "RIGHT", -42, 0)
    quickTitle:SetJustifyH("LEFT")
    BindLocale(welcome, quickTitle, "QUICKSTART")
    quickTitle:SetTextColor(1.0, 0.82, 0.25)
    frame.skinAccentTitles[#frame.skinAccentTitles + 1] = { widget = quickTitle, role = "accent" }

    local quickDivider = welcome:CreateTexture(nil, "BORDER")
    quickDivider:SetColorTexture(0.55, 0.32, 0.12, 0.55)
    quickDivider:SetPoint("TOPLEFT", quickTitle, "BOTTOMLEFT", 0, -5)
    quickDivider:SetPoint("RIGHT", welcome, "RIGHT", -42, 0)
    quickDivider:SetHeight(1)

    local quick = welcome:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    quick:SetPoint("TOPLEFT", quickDivider, "BOTTOMLEFT", 0, -10)
    quick:SetPoint("RIGHT", welcome, "RIGHT", -42, 0)
    quick:SetJustifyH("LEFT")
    quick:SetJustifyV("TOP")
    quick:SetWordWrap(true)
    BindLocale(welcome, quick, "QUICKSTART_TEXT")

    local showThreatButton = CreateButton(welcome, "SHOW_THREAT_WINDOW", 190, 0, 0, function()
        FT.db.visible = true
        if FT.frame then
            FT.frame:Show()
            FT:Refresh()
        end
    end)
    showThreatButton:ClearAllPoints()
    showThreatButton:SetPoint("TOPRIGHT", welcome, "TOP", -6, -522)

    local testWarningButton = CreateButton(welcome, "TEST_WARNING_SOUND", 190, 0, 0, function()
        FT:TestWarningSound()
    end)
    testWarningButton:ClearAllPoints()
    testWarningButton:SetPoint("TOPLEFT", welcome, "TOP", 6, -522)

    local tipsDivider = welcome:CreateTexture(nil, "BORDER")
    tipsDivider:SetColorTexture(0.55, 0.32, 0.12, 0.38)
    tipsDivider:SetPoint("TOPLEFT", welcome, "TOPLEFT", 42, -568)
    tipsDivider:SetPoint("RIGHT", welcome, "RIGHT", -42, 0)
    tipsDivider:SetHeight(1)

    local tips = welcome:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tips:SetPoint("TOPLEFT", tipsDivider, "BOTTOMLEFT", 0, -10)
    tips:SetPoint("RIGHT", welcome, "RIGHT", -42, 0)
    tips:SetJustifyH("LEFT")
    tips:SetJustifyV("TOP")
    tips:SetWordWrap(true)
    BindLocale(welcome, tips, "WELCOME_TIP")
    SetTextColor(tips, 0.72, 0.72, 0.72)

    -- Display
    local display = CreatePage(frame, "display")
    local displayTitle = AddTitle(display, "DISPLAY_TITLE", -8)
    AddDescription(display, "DISPLAY_DESC", displayTitle, -8)

    AddSectionTitle(display, "PRESETS_TITLE", 8, -88)
    frame.presetButtons = {}
    local presetSpecs = {
        { preset = "MINIMAL", key = "PRESET_MINIMAL", x = 8 },
        { preset = "STANDARD", key = "PRESET_STANDARD", x = 123 },
        { preset = "TANK", key = "PRESET_TANK", x = 238 },
        { preset = "DPS", key = "PRESET_DPS", x = 353 },
        { preset = "HEALER", key = "PRESET_HEALER", x = 468 },
    }
    for _, spec in ipairs(presetSpecs) do
        local button = CreateFrame("Button", nil, display, "UIPanelButtonTemplate")
        button:SetSize(105, 24)
        button:SetPoint("TOPLEFT", display, "TOPLEFT", spec.x, -112)
        BindLocale(display, button, spec.key)
        button.preset = spec.preset
        button:SetScript("OnClick", function(self) FT:ApplyDisplayPreset(self.preset) end)
        frame.presetButtons[spec.preset] = button
    end

    AddSectionTitle(display, "THREAT_MODE_TITLE", 8, -160)
    frame.modeButtons = {}
    local modeSpecs = {
        { mode = "AUTO", key = "MODE_AUTO", x = 8 },
        { mode = "TANK", key = "MODE_TANK", x = 76 },
        { mode = "DPS", key = "MODE_DPS", x = 144 },
        { mode = "HEALER", key = "MODE_HEALER", x = 212 },
    }
    for _, spec in ipairs(modeSpecs) do
        local button = CreateFrame("Button", nil, display, "UIPanelButtonTemplate")
        button:SetSize(62, 24)
        button:SetPoint("TOPLEFT", display, "TOPLEFT", spec.x, -184)
        BindLocale(display, button, spec.key)
        button.mode = spec.mode
        button:SetScript("OnClick", function(self) FT:SetThreatMode(self.mode) end)
        frame.modeButtons[spec.mode] = button
    end

    AddSectionTitle(display, "DISPLAY_BASIC_TITLE", 8, -232)
    AddSectionTitle(display, "DISPLAY_EXTRA_TITLE", 315, -232)

    local basicChecks = {
        { "showThreatValue", "SHOW_THREAT_VALUE" },
        { "showPercent", "SHOW_PERCENT" },
        { "showTankMarker", "SHOW_TANK_MARKER" },
        { "showAggroCrown", "SHOW_AGGRO_CROWN" },
        { "showTankStreak", "SHOW_TANK_STREAK" },
        { "highlightPlayer", "HIGHLIGHT_PLAYER" },
        { "useClassColors", "USE_CLASS_COLORS" },
        { "showPets", "SHOW_PETS" },
        { "showTargetTarget", "SHOW_TARGET_TARGET" },
    }
    local extraChecks = {
        { "showTPS", "SHOW_TPS" },
        { "showThreatETA", "SHOW_THREAT_ETA" },
        { "showThreatDelta", "SHOW_DELTA" },
        { "showGapToAggro", "SHOW_GAP_TO_AGGRO" },
        { "showThreatRace", "SHOW_THREAT_RACE" },
        { "funMode", "FUN_MODE" },
        { "dynamicThreatColors", "DYNAMIC_THREAT_COLORS" },
        { "highlightAggroChanges", "HIGHLIGHT_AGGRO_CHANGES" },
        { "showAggroChangeMessage", "SHOW_AGGRO_CHANGE_MESSAGE" },
    }
    for index, spec in ipairs(basicChecks) do
        CreateCheckbox(display, spec[1], spec[2], 8, -252 - ((index - 1) * 30))
    end
    for index, spec in ipairs(extraChecks) do
        CreateCheckbox(display, spec[1], spec[2], 315, -252 - ((index - 1) * 30))
    end

    AddSectionTitle(display, "DISPLAY_CONTROL_TITLE", 8, -550)
    frame.sourceButtons = {}
    local targetSource = CreateFrame("Button", nil, display, "UIPanelButtonTemplate")
    targetSource:SetSize(105, 24)
    targetSource:SetPoint("TOPLEFT", display, "TOPLEFT", 8, -576)
    BindLocale(display, targetSource, "SOURCE_TARGET")
    targetSource:SetScript("OnClick", function() FT:SetThreatSource("TARGET") end)
    frame.sourceButtons.TARGET = targetSource

    local focusSource = CreateFrame("Button", nil, display, "UIPanelButtonTemplate")
    focusSource:SetSize(105, 24)
    focusSource:SetPoint("TOPLEFT", display, "TOPLEFT", 123, -576)
    BindLocale(display, focusSource, "SOURCE_FOCUS")
    focusSource:SetScript("OnClick", function() FT:SetThreatSource("FOCUS") end)
    frame.sourceButtons.FOCUS = focusSource

    frame.testModeButton = CreateButton(display, "TEST_MODE_START", 170, 315, -576, function()
        FT:SetTestMode(not FT.testMode)
    end)

    local displayInfo = display:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    displayInfo:SetPoint("TOPLEFT", display, "TOPLEFT", 8, -622)
    displayInfo:SetPoint("RIGHT", display, "RIGHT", -8, 0)
    displayInfo:SetJustifyH("LEFT")
    displayInfo:SetWordWrap(true)
    BindLocale(display, displayInfo, "DISPLAY_BEGINNER_INFO")
    SetTextColor(displayInfo, 0.72, 0.72, 0.72)

    -- Appearance
    local appearance = CreatePage(frame, "appearance")
    local appearanceTitle = AddTitle(appearance, "APPEARANCE_TITLE", -8)
    AddDescription(appearance, "APPEARANCE_DESC", appearanceTitle, -8)

    AddSectionTitle(appearance, "WINDOW_STYLE_TITLE", 8, -88)
    frame.windowStyleButtons = {}
    local windowStyleSpecs = {
        { style = "ADDON", key = "WINDOW_STYLE_ADDON", x = 8 },
        { style = "BLIZZARD", key = "WINDOW_STYLE_BLIZZARD", x = 168 },
        { style = "MINIMAL", key = "WINDOW_STYLE_MINIMAL", x = 328 },
    }
    for _, spec in ipairs(windowStyleSpecs) do
        local button = CreateFrame("Button", nil, appearance, "UIPanelButtonTemplate")
        button:SetSize(145, 26)
        button:SetPoint("TOPLEFT", appearance, "TOPLEFT", spec.x, -112)
        BindLocale(appearance, button, spec.key)
        button.appearanceStyle = spec.style
        button:SetScript("OnClick", function(self) FT:SetWindowStyle(self.appearanceStyle) end)
        frame.windowStyleButtons[spec.style] = button
    end

    AddSectionTitle(appearance, "SKIN_STYLE_TITLE", 8, -160)
    frame.skinButtons = {}
    local skinSpecs = {
        { style = "ORANGE", label = "SKIN_ORANGE", x = 8 },
        { style = "FROST", label = "SKIN_FROST", x = 204 },
        { style = "CRIMSON", label = "SKIN_CRIMSON", x = 400 },
    }
    for _, spec in ipairs(skinSpecs) do
        local skinButton = CreateFrame("Button", nil, appearance, "UIPanelButtonTemplate")
        skinButton:SetSize(175, 26)
        skinButton:SetPoint("TOPLEFT", appearance, "TOPLEFT", spec.x, -184)
        skinButton.localizedTextPadding = 34
        BindLocale(appearance, skinButton, spec.label)
        skinButton.skinStyle = spec.style
        skinButton:SetScript("OnClick", function(button) FT:SetSkinStyle(button.skinStyle) end)
        local swatch = skinButton:CreateTexture(nil, "ARTWORK")
        swatch:SetSize(9, 15)
        swatch:SetPoint("LEFT", skinButton, "LEFT", 8, 0)
        local sample = FT:GetSkinPalette(spec.style).title
        swatch:SetColorTexture(sample[1], sample[2], sample[3], 1)
        frame.skinButtons[spec.style] = skinButton
    end

    AddSectionTitle(appearance, "APPEARANCE_BARS_TITLE", 8, -232)
    frame.barTextureButtons = {}
    local barTextureSpecs = {
        { style = "BLIZZARD", key = "BAR_TEXTURE_BLIZZARD", x = 8 },
        { style = "SOLID", key = "BAR_TEXTURE_SOLID", x = 158 },
    }
    for _, spec in ipairs(barTextureSpecs) do
        local button = CreateFrame("Button", nil, appearance, "UIPanelButtonTemplate")
        button:SetSize(135, 26)
        button:SetPoint("TOPLEFT", appearance, "TOPLEFT", spec.x, -256)
        BindLocale(appearance, button, spec.key)
        button.appearanceStyle = spec.style
        button:SetScript("OnClick", function(self) FT:SetBarTexture(self.appearanceStyle) end)
        frame.barTextureButtons[spec.style] = button
    end

    frame.barStyleButtons = {}
    local barStyleSpecs = {
        { style = "FLAT", key = "BAR_STYLE_FLAT", x = 315 },
        { style = "GRADIENT", key = "BAR_STYLE_GRADIENT", x = 465 },
    }
    for _, spec in ipairs(barStyleSpecs) do
        local button = CreateFrame("Button", nil, appearance, "UIPanelButtonTemplate")
        button:SetSize(135, 26)
        button:SetPoint("TOPLEFT", appearance, "TOPLEFT", spec.x, -256)
        BindLocale(appearance, button, spec.key)
        button.appearanceStyle = spec.style
        button:SetScript("OnClick", function(self) FT:SetBarStyle(self.appearanceStyle) end)
        frame.barStyleButtons[spec.style] = button
    end

    CreateCheckbox(appearance, "showHeader", "SHOW_HEADER", 8, -302)

    AddSectionTitle(appearance, "APPEARANCE_SIZING_TITLE", 8, -350)
    CreateSlider(appearance, "windowAlpha", "WINDOW_ALPHA", 8, -378, 250, 0.20, 1.00, 0.05,
        function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end)
    CreateSlider(appearance, "barHeight", "BAR_HEIGHT", 315, -378, 250, 14, 40, 1,
        function(v) return tostring(math.floor(v + 0.5)) .. " px" end)
    CreateSlider(appearance, "fontSize", "FONT_SIZE", 8, -448, 250, 9, 20, 1,
        function(v) return tostring(math.floor(v + 0.5)) .. " pt" end)
    CreateSlider(appearance, "maxRows", "MAX_ROWS", 315, -448, 250, 1, 40, 1,
        function(v) return tostring(math.floor(v + 0.5)) end)

    AddSectionTitle(appearance, "APPEARANCE_PRESETS", 8, -526)
    CreateButton(appearance, "APPEARANCE_PRESET_DEFAULT", 165, 8, -552, function() FT:ApplyAppearancePreset("DEFAULT") end)
    CreateButton(appearance, "APPEARANCE_PRESET_BLIZZARD", 165, 183, -552, function() FT:ApplyAppearancePreset("BLIZZARD") end)
    CreateButton(appearance, "APPEARANCE_PRESET_MINIMAL", 165, 358, -552, function() FT:ApplyAppearancePreset("MINIMAL") end)

    local appearanceInfo = appearance:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    appearanceInfo:SetPoint("TOPLEFT", appearance, "TOPLEFT", 8, -598)
    appearanceInfo:SetPoint("RIGHT", appearance, "RIGHT", -8, 0)
    appearanceInfo:SetJustifyH("LEFT")
    appearanceInfo:SetWordWrap(true)
    BindLocale(appearance, appearanceInfo, "APPEARANCE_INFO")
    SetTextColor(appearanceInfo, 0.72, 0.72, 0.72)

    -- Warnings
    local warnings = CreatePage(frame, "warnings")
    local warnTitle = AddTitle(warnings, "WARNINGS_TITLE", -8)
    AddDescription(warnings, "WARNINGS_DESC", warnTitle, -8)

    CreateCheckbox(warnings, "soundEnabled", "AGGRO_SOUND", 8, -92)
    CreateCheckbox(warnings, "warningEnabled", "SCREEN_WARNINGS", 8, -126)
    CreateCheckbox(warnings, "highThreatWarning", "HIGH_THREAT_WARNING_OPTION", 8, -160)
    CreateCheckbox(warnings, "threatResetProtection", "THREAT_RESET_PROTECTION", 8, -194)
    CreateCheckbox(warnings, "etaWarningEnabled", "ETA_WARNING_OPTION", 8, -228)
    CreateCheckbox(warnings, "soundInSolo", "SOUND_IN_SOLO", 8, -262)

    CreateCheckbox(warnings, "tankAggroLossWarning", "TANK_AGGRO_LOSS_WARNING", 315, -92)
    CreateCheckbox(warnings, "tankAggroLossSound", "TANK_AGGRO_LOSS_SOUND", 315, -126)
    CreateCheckbox(warnings, "tauntSwapDetection", "TAUNT_SWAP_DETECTION", 315, -160)
    CreateCheckbox(warnings, "showTankSwapMessage", "SHOW_TANK_SWAP_MESSAGE", 315, -194)
    CreateCheckbox(warnings, "tankLeadWarning", "TANK_LEAD_WARNING_OPTION", 315, -228)

    CreateSlider(warnings, "soundVolume", "SOUND_VOLUME", 315, -260, 250, 10, 100, 5,
        function(v) return tostring(math.floor(v + 0.5)) .. "%" end,
        function()
            FT:NormalizeSoundSettings()
            FT:ApplySettings()
        end)

    CreateButton(warnings, "TEST_WARNING_SOUND", 160, 8, -300, function()
        FT:TestWarningSound()
    end)
    CreateButton(warnings, "TEST_AGGRO_LOSS_SOUND", 190, 315, -300, function()
        FT:TestAggroLossSound()
    end)

    local warningThresholdsTitle = warnings:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    warningThresholdsTitle:SetPoint("TOPLEFT", warnings, "TOPLEFT", 8, -336)
    BindLocale(warnings, warningThresholdsTitle, "WARNING_THRESHOLDS_TITLE")
    warningThresholdsTitle:SetTextColor(1.0, 0.82, 0.25)
    frame.skinAccentTitles[#frame.skinAccentTitles + 1] = { widget = warningThresholdsTitle, role = "accent" }

    CreateSlider(warnings, "highThreatThreshold", "HIGH_THREAT_WARNING_THRESHOLD", 8, -360, 170, 50, 99, 1,
        function(v) return tostring(math.floor(v + 0.5)) .. "%" end,
        function()
            FT:NormalizeWarningThresholds()
            FT:ApplySettings()
        end)

    CreateSlider(warnings, "etaWarningThreshold", "ETA_WARNING_THRESHOLD", 205, -360, 170, 1, 15, 1,
        function(v) return tostring(math.floor(v + 0.5)) .. " s" end,
        function()
            FT:NormalizeWarningThresholds()
            FT:ResetETAWarningState()
            FT:ApplySettings()
        end)

    CreateSlider(warnings, "tankLeadWarningThreshold", "TANK_LEAD_WARNING_THRESHOLD", 402, -360, 170, 1, 15, 1,
        function(v) return tostring(math.floor(v + 0.5)) .. " s" end,
        function()
            FT:NormalizeWarningThresholds()
            FT:ResetTankLeadWarningState()
            FT:ApplySettings()
        end)

    local warningThresholdsDesc = warnings:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    warningThresholdsDesc:SetPoint("TOPLEFT", warnings, "TOPLEFT", 8, -412)
    warningThresholdsDesc:SetPoint("RIGHT", warnings, "RIGHT", -8, 0)
    warningThresholdsDesc:SetJustifyH("LEFT")
    warningThresholdsDesc:SetWordWrap(true)
    BindLocale(warnings, warningThresholdsDesc, "WARNING_THRESHOLDS_DESC")
    SetTextColor(warningThresholdsDesc, 0.72, 0.72, 0.72)

    local thresholdsTitle = warnings:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    thresholdsTitle:SetPoint("TOPLEFT", warnings, "TOPLEFT", 8, -448)
    BindLocale(warnings, thresholdsTitle, "THRESHOLDS_TITLE")
    thresholdsTitle:SetTextColor(1.0, 0.82, 0.25)
    frame.skinAccentTitles[#frame.skinAccentTitles + 1] = { widget = thresholdsTitle, role = "accent" }

    local thresholdsDesc = warnings:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    thresholdsDesc:SetPoint("TOPLEFT", warnings, "TOPLEFT", 8, -470)
    thresholdsDesc:SetPoint("RIGHT", warnings, "RIGHT", -8, 0)
    thresholdsDesc:SetJustifyH("LEFT")
    thresholdsDesc:SetWordWrap(true)
    BindLocale(warnings, thresholdsDesc, "THRESHOLDS_DESC")
    SetTextColor(thresholdsDesc, 0.72, 0.72, 0.72)

    local modeColumns = {
        { x = 8, title = "TANK_THRESHOLDS", keys = { "tankThreatYellow", "tankThreatOrange", "tankThreatRed" } },
        { x = 205, title = "DPS_THRESHOLDS", keys = { "dpsThreatYellow", "dpsThreatOrange", "dpsThreatRed" } },
        { x = 402, title = "HEALER_THRESHOLDS", keys = { "healerThreatYellow", "healerThreatOrange", "healerThreatRed" } },
    }

    local thresholdLabels = { "THRESHOLD_YELLOW", "THRESHOLD_ORANGE", "THRESHOLD_RED" }
    local thresholdYs = { -526, -566, -606 }

    for _, column in ipairs(modeColumns) do
        local title = warnings:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", warnings, "TOPLEFT", column.x, -504)
        BindLocale(warnings, title, column.title)

        for index, key in ipairs(column.keys) do
            CreateSlider(warnings, key, thresholdLabels[index], column.x, thresholdYs[index], 170, 1, 100, 1,
                function(v) return tostring(math.floor(v + 0.5)) .. "%" end,
                function()
                    FT:NormalizeThreatThresholds()
                    FT:ApplySettings()
                    FT:RefreshConfigControls()
                end)
        end
    end

    local warnInfo = warnings:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    warnInfo:SetPoint("TOPLEFT", warnings, "TOPLEFT", 8, -640)
    warnInfo:SetPoint("RIGHT", warnings, "RIGHT", -8, 0)
    warnInfo:SetJustifyH("LEFT")
    warnInfo:SetWordWrap(true)
    BindLocale(warnings, warnInfo, "WARNING_INFO")
    SetTextColor(warnInfo, 0.72, 0.72, 0.72)

    -- Raid
    local raid = CreatePage(frame, "raid")
    local raidTitle = AddTitle(raid, "RAID_PERFORMANCE_TITLE", -8)
    AddDescription(raid, "RAID_PAGE_DESC", raidTitle, -8)

    CreateButton(raid, "LEVEL60_RAID_PRESET", 220, 8, -92, function() FT:ApplyLevel60RaidPreset() end)

    CreateButton(raid, "PRESET_DUNGEON_TANK", 180, 8, -122, function() FT:ApplyDisplayPreset("DUNGEON_TANK") end)
    CreateButton(raid, "PRESET_RAID_TANK", 180, 203, -122, function() FT:ApplyDisplayPreset("RAID_TANK") end)
    CreateButton(raid, "PRESET_RAID_DPS", 180, 398, -122, function() FT:ApplyDisplayPreset("RAID_DPS") end)

    AddSectionTitle(raid, "RAID_SCAN_TITLE", 8, -166)
    CreateCheckbox(raid, "adaptiveRaidUpdates", "ADAPTIVE_RAID_UPDATES", 8, -192)
    CreateCheckbox(raid, "optimizedRaidScan", "OPTIMIZED_RAID_SCAN", 8, -226)
    CreateCheckbox(raid, "raidDangerViewEnabled", "RAID_DANGER_VIEW", 8, -260)

    AddSectionTitle(raid, "RAID_LIST_TITLE", 315, -166)
    CreateCheckbox(raid, "raidTopEnabled", "RAID_TOP_ENABLED", 315, -192)
    CreateCheckbox(raid, "raidAlwaysShowPlayer", "RAID_ALWAYS_SHOW_PLAYER", 315, -226)
    CreateCheckbox(raid, "showRaidPets", "SHOW_RAID_PETS", 315, -260)
    CreateCheckbox(raid, "raidTankViewEnabled", "RAID_TANK_VIEW", 315, -294)

    CreateSlider(raid, "raidTopRows", "RAID_TOP_ROWS", 315, -350, 250, 1, 40, 1,
        function(v) return tostring(math.floor(v + 0.5)) end)

    local raidPerformanceInfo = raid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    raidPerformanceInfo:SetPoint("TOPLEFT", raid, "TOPLEFT", 8, -438)
    raidPerformanceInfo:SetPoint("RIGHT", raid, "RIGHT", -8, 0)
    raidPerformanceInfo:SetJustifyH("LEFT")
    raidPerformanceInfo:SetWordWrap(true)
    BindLocale(raid, raidPerformanceInfo, "RAID_PERFORMANCE_INFO")
    SetTextColor(raidPerformanceInfo, 0.72, 0.72, 0.72)

    -- Statistics
    local statistics = CreatePage(frame, "statistics")
    local statisticsTitle = AddTitle(statistics, "STATISTICS_TITLE", -8)
    AddDescription(statistics, "STATISTICS_DESC", statisticsTitle, -8)

    AddSectionTitle(statistics, "STATISTICS_TANKING_TITLE", 8, -100)
    AddSectionTitle(statistics, "STATISTICS_THREAT_TITLE", 315, -100)

    frame.statisticsValues = {}

    local function CreateStatLine(parent, key, labelKey, x, y)
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        label:SetWidth(185)
        label:SetJustifyH("LEFT")
        BindLocale(parent, label, labelKey)

        local value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        value:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 192, y)
        value:SetWidth(82)
        value:SetJustifyH("RIGHT")
        value:SetText("-")
        frame.statisticsValues[key] = value
    end

    CreateStatLine(statistics, "longestStreak", "STAT_LONGEST_STREAK", 8, -136)
    CreateStatLine(statistics, "aggroLost", "STAT_AGGRO_LOST", 8, -170)
    CreateStatLine(statistics, "aggroGained", "STAT_AGGRO_GAINED", 8, -204)
    CreateStatLine(statistics, "tankSwaps", "STAT_TANK_SWAPS", 8, -238)
    CreateStatLine(statistics, "longestTankLead", "STAT_LONGEST_TANK_LEAD", 8, -272)

    CreateStatLine(statistics, "bestThreatRank", "STAT_BEST_THREAT_RANK", 315, -136)
    CreateStatLine(statistics, "highestThreatPercent", "STAT_HIGHEST_THREAT_PERCENT", 315, -170)
    CreateStatLine(statistics, "closestTimeToAggro", "STAT_CLOSEST_TIME_TO_AGGRO", 315, -204)
    CreateStatLine(statistics, "sessionTime", "STAT_SESSION_TIME", 315, -238)

    local statsInfo = statistics:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statsInfo:SetPoint("TOPLEFT", statistics, "TOPLEFT", 8, -338)
    statsInfo:SetPoint("RIGHT", statistics, "RIGHT", -8, 0)
    statsInfo:SetJustifyH("LEFT")
    statsInfo:SetWordWrap(true)
    BindLocale(statistics, statsInfo, "STATISTICS_INFO")
    SetTextColor(statsInfo, 0.72, 0.72, 0.72)

    CreateButton(statistics, "STATISTICS_RESET", 190, 8, -430, function()
        FT:ResetSessionStatistics()
        FT:RefreshSessionStatistics()
    end)

    statistics:SetScript("OnUpdate", function(self, elapsed)
        self.statsElapsed = (self.statsElapsed or 0) + elapsed
        if self.statsElapsed >= 0.5 then
            self.statsElapsed = 0
            if self:IsShown() then
                FT:RefreshSessionStatistics()
            end
        end
    end)

    -- General
    local general = CreatePage(frame, "general")
    local generalTitle = AddTitle(general, "GENERAL_TITLE", -8)
    AddDescription(general, "GENERAL_DESC", generalTitle, -8)

    AddSectionTitle(general, "GENERAL_BEHAVIOR_TITLE", 8, -88)
    CreateCheckbox(general, "autoShowInCombat", "AUTO_SHOW", 8, -114)
    CreateCheckbox(general, "showMinimapButton", "SHOW_MINIMAP", 8, -148, function(value) FT:SetMinimapVisible(value) end)
    local lockCheck = CreateCheckbox(general, "locked", "LOCK_WINDOW", 8, -182, function(value) FT:SetLocked(value) end)
    lockCheck.isLockControl = true
    CreateCheckbox(general, "combatLock", "COMBAT_LOCK", 8, -216, function() FT:RefreshWindowLockState() end)
    CreateCheckbox(general, "smartAutoHide", "SMART_AUTO_HIDE", 8, -250)
    CreateCheckbox(general, "autoShowOnlyWithThreat", "AUTO_SHOW_ONLY_WITH_THREAT", 8, -284)
    CreateCheckbox(general, "clickToTauntEnabled", "CLICK_TO_TAUNT", 8, -318)
    CreateCheckbox(general, "idleDimming", "IDLE_DIMMING", 8, -352, function() FT:UpdateWindowAlpha() end)
    CreateSlider(general, "idleAlpha", "IDLE_ALPHA", 8, -398, 250, 0.10, 1.00, 0.05,
        function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end,
        function() FT:UpdateWindowAlpha() end)

    AddSectionTitle(general, "GENERAL_SYSTEM_TITLE", 315, -88)
    frame.languageTitle = general:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.languageTitle:SetPoint("TOPLEFT", general, "TOPLEFT", 315, -118)
    BindLocale(general, frame.languageTitle, "LANGUAGE_TITLE")
    frame.languageTitle:SetTextColor(1.0, 0.82, 0.25)
    frame.skinAccentTitles[#frame.skinAccentTitles + 1] = { widget = frame.languageTitle, role = "accent" }

    local languageDropdown = CreateFrame("Button", nil, general, "UIPanelButtonTemplate")
    ApplyLocalizedButtonFont(languageDropdown)
    languageDropdown:SetSize(250, 26)
    languageDropdown:SetPoint("TOPLEFT", general, "TOPLEFT", 315, -144)
    frame.languageDropdown = languageDropdown
    local dropdownArrow = languageDropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dropdownArrow:SetPoint("RIGHT", languageDropdown, "RIGHT", -10, 0)
    dropdownArrow:SetText("v")

    local languageMenu = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    languageMenu:SetSize(250, (#LANGUAGE_OPTIONS * 28) + 8)
    languageMenu:SetPoint("TOPLEFT", languageDropdown, "BOTTOMLEFT", 0, -2)
    languageMenu:SetFrameStrata("TOOLTIP")
    languageMenu:SetFrameLevel(frame:GetFrameLevel() + 30)
    languageMenu:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    languageMenu:SetBackdropColor(0.025, 0.025, 0.025, 0.99)
    languageMenu:SetBackdropBorderColor(0.55, 0.32, 0.12, 1)
    languageMenu:Hide()
    frame.languageMenu = languageMenu
    frame.languageOptionButtons = {}
    for index, option in ipairs(LANGUAGE_OPTIONS) do
        local optionButton = CreateFrame("Button", nil, languageMenu, "UIPanelButtonTemplate")
        optionButton:SetSize(236, 24)
        optionButton:SetPoint("TOPLEFT", languageMenu, "TOPLEFT", 7, -6 - ((index - 1) * 28))
        optionButton:SetText(option.label)
        optionButton.languageCode = option.code
        ApplyLanguageOptionButtonFont(optionButton, option.code)
        FitLocalizedButtonText(optionButton)
        optionButton:SetScript("OnClick", function(button)
            languageMenu:Hide()
            FT:SetLanguage(button.languageCode)
            FT:RefreshConfigControls()
        end)
        frame.languageOptionButtons[option.code] = optionButton
    end
    languageDropdown:SetScript("OnClick", function()
        if languageMenu:IsShown() then languageMenu:Hide() else languageMenu:Show() end
    end)
    frame.languageInfo = general:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.languageInfo:SetPoint("TOPLEFT", general, "TOPLEFT", 315, -178)
    frame.languageInfo:SetTextColor(0.72, 0.72, 0.72)

    CreateSlider(general, "updateInterval", "UPDATE_INTERVAL", 315, -224, 250, 0.05, 0.50, 0.05,
        function(v) return string.format("%.2f s", v) end)

    AddSectionTitle(general, "GENERAL_MAINTENANCE_TITLE", 315, -298)
    CreateButton(general, "RESET_POSITION", 120, 315, -324, function() FT:ResetPosition() end)
    CreateButton(general, "RESET_SIZE", 120, 445, -324, function() FT:ResetFrameSize(); FT:RefreshConfigControls() end)
    CreateButton(general, "WOW_SETTINGS", 250, 315, -360, function() if FT.OpenBlizzardSettings then FT:OpenBlizzardSettings() end end)

    local resetAllButton
    resetAllButton = CreateButton(general, "RESET_ALL_SETTINGS", 250, 315, -396, function()
        local now = GetTime()
        if resetAllButton.confirmUntil and resetAllButton.confirmUntil > now then
            resetAllButton.confirmUntil = nil
            FT:ResetAllSettings()
            BindLocale(general, resetAllButton, "RESET_ALL_SETTINGS")
        else
            resetAllButton.confirmUntil = now + 5
            resetAllButton:SetText(FT:L("RESET_ALL_CONFIRM"))
            FitLocalizedButtonText(resetAllButton)
        end
    end)
    frame.resetAllButton = resetAllButton

    local sizeInfo = general:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sizeInfo:SetPoint("TOPLEFT", general, "TOPLEFT", 8, -492)
    sizeInfo:SetPoint("RIGHT", general, "RIGHT", -8, 0)
    sizeInfo:SetJustifyH("LEFT")
    sizeInfo:SetWordWrap(true)
    BindLocale(general, sizeInfo, "GENERAL_HELP_INFO")
    SetTextColor(sizeInfo, 0.72, 0.72, 0.72)

    frame.versionInfo = general:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.versionInfo:SetPoint("BOTTOMLEFT", general, "BOTTOMLEFT", 8, 8)
    SetTextColor(frame.versionInfo, 0.55, 0.55, 0.55)

    -- Profile
    local profile = CreatePage(frame, "profile")
    local profileTitle = AddTitle(profile, "PROFILE_TITLE", -8)
    AddDescription(profile, "PROFILE_DESC", profileTitle, -8)

    local exportLabel = profile:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    exportLabel:SetPoint("TOPLEFT", profile, "TOPLEFT", 8, -105)
    BindLocale(profile, exportLabel, "PROFILE_EXPORT_LABEL")

    frame.profileExportBox = CreateProfileEditBox(profile, 8, -132, 565)

    CreateButton(profile, "PROFILE_EXPORT_BUTTON", 170, 8, -174, function()
        local text = FT:ExportProfileString()
        frame.profileExportBox:SetText(text)
        frame.profileExportBox:SetFocus()
        frame.profileExportBox:HighlightText()
        frame.profileStatusKey = "PROFILE_EXPORT_READY"
        frame.profileStatus:SetText(FT:L(frame.profileStatusKey))
        frame.profileStatus:SetTextColor(0.45, 1.0, 0.45)
    end)

    local importLabel = profile:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    importLabel:SetPoint("TOPLEFT", profile, "TOPLEFT", 8, -245)
    BindLocale(profile, importLabel, "PROFILE_IMPORT_LABEL")

    frame.profileImportBox = CreateProfileEditBox(profile, 8, -272, 565)

    CreateButton(profile, "PROFILE_IMPORT_BUTTON", 170, 8, -314, function()
        local importText = frame.profileImportBox:GetText() or ""
        local ok = FT:ImportProfileString(importText)
        if ok then
            frame.profileStatusKey = "PROFILE_IMPORT_OK"
            frame.profileStatus:SetTextColor(0.45, 1.0, 0.45)
        elseif importText:match("^%s*$") then
            frame.profileStatusKey = "PROFILE_IMPORT_EMPTY"
            frame.profileStatus:SetTextColor(1.0, 0.35, 0.25)
        else
            frame.profileStatusKey = "PROFILE_IMPORT_INVALID"
            frame.profileStatus:SetTextColor(1.0, 0.35, 0.25)
        end
        frame.profileStatus:SetText(FT:L(frame.profileStatusKey))
    end)

    frame.profileStatus = profile:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.profileStatus:SetPoint("TOPLEFT", profile, "TOPLEFT", 8, -365)
    frame.profileStatus:SetPoint("RIGHT", profile, "RIGHT", -8, 0)
    frame.profileStatus:SetJustifyH("LEFT")

    local profileHint = profile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    profileHint:SetPoint("TOPLEFT", profile, "TOPLEFT", 8, -405)
    profileHint:SetPoint("RIGHT", profile, "RIGHT", -8, 0)
    profileHint:SetJustifyH("LEFT")
    profileHint:SetWordWrap(true)
    BindLocale(profile, profileHint, "PROFILE_COPY_HINT")
    SetTextColor(profileHint, 0.72, 0.72, 0.72)

    self:RefreshConfigLocale()
    self:SelectConfigTab(self.db.configLastTab or "welcome")
    self:ApplyConfigSkin()
end

function FT:ApplyConfigSkin(palette)
    local frame = self.configFrame
    if not frame then
        return
    end

    local skin = palette or self:GetSkinPalette()
    local bg = skin.background
    frame:SetBackdropColor(bg[1], bg[2], bg[3], 0.98)
    local border = skin.border
    frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4])

    if frame.skinTitle then
        frame.skinTitle:SetTextColor(skin.title[1], skin.title[2], skin.title[3])
    end
    if frame.skinDivider then
        local c = skin.divider
        frame.skinDivider:SetColorTexture(c[1], c[2], c[3], c[4])
    end
    if frame.languageMenu then
        frame.languageMenu:SetBackdropColor(bg[1], bg[2], bg[3], 0.99)
        frame.languageMenu:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
    end

    for _, entry in ipairs(frame.skinAccentTitles or {}) do
        local color = entry.role == "title" and skin.title or skin.accent
        entry.widget:SetTextColor(color[1], color[2], color[3])
    end
end

function FT:RefreshConfigLocale()
    local frame = self.configFrame
    if not frame then
        return
    end

    for _, widget in ipairs(frame.localeWidgets or {}) do
        if widget and widget.localeKey and widget.SetText then
            widget:SetText(self:L(widget.localeKey))

            if type(widget.GetObjectType) == "function" and widget:GetObjectType() == "Button" then
                FitLocalizedButtonText(widget)
            end
        end
    end

    if frame.subtitle then
        frame.subtitle:SetText(self:L("CONFIG_SUBTITLE") .. "  •  v" .. tostring(self.version))
    end

    if frame.languageInfo then
        frame.languageInfo:SetText(self:L("LANGUAGE_CURRENT"))
    end

    if frame.languageDropdown then
        ApplyLocalizedButtonFont(frame.languageDropdown)
        frame.languageDropdown:SetText(GetLanguageLabel(self:GetLanguage()))
        FitLocalizedButtonText(frame.languageDropdown)
    end

    if frame.profileStatus and frame.profileStatusKey then
        frame.profileStatus:SetText(self:L(frame.profileStatusKey))
    end

    if frame.resetAllButton and frame.resetAllButton.confirmUntil
        and frame.resetAllButton.confirmUntil > GetTime() then
        frame.resetAllButton:SetText(self:L("RESET_ALL_CONFIRM"))
        FitLocalizedButtonText(frame.resetAllButton)
    end

    if frame.versionInfo then
        frame.versionInfo:SetText("ForeverThreat v" .. tostring(self.version) .. "  •  /ft config")
    end

    if frame.testModeButton then
        frame.testModeButton:SetText(self:L(self.testMode and "TEST_MODE_STOP" or "TEST_MODE_START"))
        FitLocalizedButtonText(frame.testModeButton)
    end
end

function FT:SelectConfigTab(tabName)
    if not self.configFrame then
        return
    end

    if self.configFrame.languageMenu then
        self.configFrame.languageMenu:Hide()
    end

    if not self.configFrame.pages[tabName] then
        tabName = "welcome"
    end

    self.db.configLastTab = tabName

    for name, page in pairs(self.configFrame.pages) do
        if name == tabName then
            page:Show()
        else
            page:Hide()
        end
    end

    for name, button in pairs(self.configFrame.tabs) do
        if name == tabName then
            button:LockHighlight()
        else
            button:UnlockHighlight()
        end
    end

    self:RefreshConfigControls()
end

local function FormatSessionDuration(seconds)
    seconds = math.max(0, math.floor((tonumber(seconds) or 0) + 0.5))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60

    if hours > 0 then
        return string.format("%d:%02d:%02d", hours, minutes, secs)
    end
    return string.format("%d:%02d", minutes, secs)
end

function FT:RefreshSessionStatistics()
    local frame = self.configFrame
    if not frame or not frame.statisticsValues then
        return
    end

    local stats = self.GetSessionStatistics and self:GetSessionStatistics() or {}
    local values = frame.statisticsValues

    values.longestStreak:SetText(FormatSessionDuration(self.cleanTankingBest or 0))
    values.aggroLost:SetText(tostring(stats.aggroLost or 0))
    values.aggroGained:SetText(tostring(stats.aggroGained or 0))
    values.tankSwaps:SetText(tostring(stats.tankSwaps or 0))

    if (stats.longestTankLead or 0) > 0 then
        values.longestTankLead:SetText(string.format("%.1f s", stats.longestTankLead))
    else
        values.longestTankLead:SetText("-")
    end

    if stats.bestThreatRank then
        values.bestThreatRank:SetText("#" .. tostring(stats.bestThreatRank))
    else
        values.bestThreatRank:SetText("-")
    end

    values.highestThreatPercent:SetText(string.format("%.1f%%", tonumber(stats.highestThreatPercent) or 0))

    if stats.closestTimeToAggro ~= nil then
        values.closestTimeToAggro:SetText(string.format("%.1f s", stats.closestTimeToAggro))
    else
        values.closestTimeToAggro:SetText("-")
    end

    local startedAt = tonumber(stats.startedAt) or GetTime()
    values.sessionTime:SetText(FormatSessionDuration(GetTime() - startedAt))
end

function FT:RefreshConfigControls()
    if not self.configFrame or not self.db then
        return
    end

    for _, page in pairs(self.configFrame.pages) do
        for key, control in pairs(page.controls or {}) do
            if control.GetChecked then
                control:SetChecked(self.db[key] and true or false)
            elseif control.SetValue then
                control.syncing = true
                control:SetValue(self.db[key])
                control.syncing = false

                if control.valueText then
                    if control.formatter then
                        control.valueText:SetText(control.formatter(self.db[key]))
                    else
                        control.valueText:SetText(tostring(self.db[key]))
                    end
                end
            end
        end
    end

    if self.configFrame.languageDropdown then
        ApplyLocalizedButtonFont(self.configFrame.languageDropdown)
        self.configFrame.languageDropdown:SetText(GetLanguageLabel(self:GetLanguage()))
        FitLocalizedButtonText(self.configFrame.languageDropdown)
    end

    if self.configFrame.languageOptionButtons then
        local selectedLanguage = self:GetLanguage()
        for language, button in pairs(self.configFrame.languageOptionButtons) do
            ApplyLanguageOptionButtonFont(button, language)
            FitLocalizedButtonText(button)
            ApplyLanguageOptionButtonFont(button, language)
            if language == selectedLanguage then
                button:LockHighlight()
            else
                button:UnlockHighlight()
            end
        end
    end

    if self.configFrame.modeButtons then
        local selectedMode = self.db.threatMode or "AUTO"
        for mode, button in pairs(self.configFrame.modeButtons) do
            if mode == selectedMode then
                button:LockHighlight()
            else
                button:UnlockHighlight()
            end
        end
    end

    if self.configFrame.skinButtons then
        local selectedSkin = self.db.skinStyle or "ORANGE"
        for style, button in pairs(self.configFrame.skinButtons) do
            if style == selectedSkin then
                button:LockHighlight()
            else
                button:UnlockHighlight()
            end
        end
    end

    if self.configFrame.barTextureButtons then
        local selected = self.db.barTexture or "BLIZZARD"
        for style, button in pairs(self.configFrame.barTextureButtons) do
            if style == selected then button:LockHighlight() else button:UnlockHighlight() end
        end
    end

    if self.configFrame.barStyleButtons then
        local selected = self.db.barStyle or "FLAT"
        for style, button in pairs(self.configFrame.barStyleButtons) do
            if style == selected then button:LockHighlight() else button:UnlockHighlight() end
        end
    end

    if self.configFrame.windowStyleButtons then
        local selected = self.db.windowStyle or "BLIZZARD"
        for style, button in pairs(self.configFrame.windowStyleButtons) do
            if style == selected then button:LockHighlight() else button:UnlockHighlight() end
        end
    end

    if self.configFrame.sourceButtons then
        local selectedSource = self.db.threatSource or "TARGET"
        for source, button in pairs(self.configFrame.sourceButtons) do
            if source == selectedSource then
                button:LockHighlight()
            else
                button:UnlockHighlight()
            end
        end
    end

    if self.configFrame.testModeButton then
        self.configFrame.testModeButton:SetText(self:L(self.testMode and "TEST_MODE_STOP" or "TEST_MODE_START"))
    end

    self:RefreshSessionStatistics()
end

function FT:OpenConfig(tabName)
    self:CreateConfigUI()

    if tabName then
        self:SelectConfigTab(tabName)
    else
        self:SelectConfigTab(self.db.configLastTab or "display")
    end

    self:RefreshConfigLocale()
    self.configFrame:Show()
    self.configFrame:Raise()
    self:RefreshConfigControls()
end

function FT:CloseConfig()
    if self.configFrame then
        if self.configFrame.languageMenu then
            self.configFrame.languageMenu:Hide()
        end
        self.configFrame:Hide()
    end
end

function FT:ShowWelcomeIfNeeded()
    -- Kept for backwards compatibility. The Welcome screen never opens automatically.
    return
end
