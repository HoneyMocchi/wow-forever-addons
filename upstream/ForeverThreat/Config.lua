local addonName, FT = ...

local TAB_ORDER = { "welcome", "display", "appearance", "warnings", "general", "profile" }
local TAB_KEYS = {
    welcome = "TAB_WELCOME",
    display = "TAB_DISPLAY",
    appearance = "TAB_APPEARANCE",
    warnings = "TAB_WARNINGS",
    general = "TAB_GENERAL",
    profile = "TAB_PROFILE",
}

-- Exactly five selectable languages. Automatic client detection is handled
-- internally on first launch and is intentionally not exposed as an option.
local LANGUAGE_OPTIONS = {
    { code = "DE", label = "Deutsch" },
    { code = "EN", label = "English" },
    { code = "ES", label = "Español" },
    { code = "FR", label = "Français" },
    { code = "KO", label = "한국어" },
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

local function BindLocale(parent, widget, key)
    local root = parent.configRoot or parent
    root.localeWidgets = root.localeWidgets or {}
    widget.localeKey = key
    root.localeWidgets[#root.localeWidgets + 1] = widget
    widget:SetText(FT:L(key))
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
        button:SetSize(94, 26)
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", tabX, -46)
        BindLocale(frame, button, TAB_KEYS[tabName])
        button.tabName = tabName
        button:SetScript("OnClick", function(self)
            FT:SelectConfigTab(self.tabName)
        end)
        frame.tabs[tabName] = button
        tabX = tabX + 98
    end

    -- Welcome
    local welcome = CreatePage(frame, "welcome")
    local welcomeTitle = AddTitle(welcome, "WELCOME_TITLE", -8)
    local intro = AddDescription(welcome, "WELCOME_INTRO", welcomeTitle, -10)

    local logo = welcome:CreateTexture(nil, "ARTWORK")
    logo:SetTexture("Interface\\AddOns\\ForeverThreat\\Media\\WelcomeLogo")
    logo:SetSize(250, 250)
    logo:SetPoint("TOPRIGHT", welcome, "TOPRIGHT", -8, -6)

    intro:ClearAllPoints()
    intro:SetPoint("TOPLEFT", welcomeTitle, "BOTTOMLEFT", 0, -10)
    intro:SetPoint("RIGHT", logo, "LEFT", -18, 0)

    local supportButton = CreateButton(welcome, "SUPPORT_BUTTON", 180, 8, -120, function()
        FT:OpenSupportWindow()
    end)
    supportButton:ClearAllPoints()
    supportButton:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -14)
    frame.supportButton = supportButton

    local quickTitle = welcome:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    quickTitle:SetPoint("TOPLEFT", supportButton, "BOTTOMLEFT", 0, -20)
    BindLocale(welcome, quickTitle, "QUICKSTART")
    quickTitle:SetTextColor(1.0, 0.82, 0.25)
    frame.skinAccentTitles[#frame.skinAccentTitles + 1] = { widget = quickTitle, role = "accent" }

    local quick = welcome:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    quick:SetPoint("TOPLEFT", quickTitle, "BOTTOMLEFT", 0, -8)
    quick:SetPoint("RIGHT", logo, "LEFT", -18, 0)
    quick:SetJustifyH("LEFT")
    quick:SetWordWrap(true)
    BindLocale(welcome, quick, "QUICKSTART_TEXT")

    local showThreatButton = CreateButton(welcome, "SHOW_THREAT_WINDOW", 180, 8, -310, function()
        FT.db.visible = true
        if FT.frame then
            FT.frame:Show()
            FT:Refresh()
        end
    end)
    showThreatButton:ClearAllPoints()
    showThreatButton:SetPoint("TOPLEFT", quick, "BOTTOMLEFT", 0, -22)

    local testWarningButton = CreateButton(welcome, "TEST_WARNING_SOUND", 160, 198, -310, function()
        FT:TestWarningSound()
    end)
    testWarningButton:ClearAllPoints()
    testWarningButton:SetPoint("LEFT", showThreatButton, "RIGHT", 10, 0)

    local tips = welcome:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tips:SetPoint("TOPLEFT", showThreatButton, "BOTTOMLEFT", 0, -28)
    tips:SetPoint("RIGHT", welcome, "RIGHT", -8, 0)
    tips:SetJustifyH("LEFT")
    tips:SetWordWrap(true)
    BindLocale(welcome, tips, "WELCOME_TIP")
    SetTextColor(tips, 0.72, 0.72, 0.72)

    -- Display
    local display = CreatePage(frame, "display")
    local displayTitle = AddTitle(display, "DISPLAY_TITLE", -8)
    AddDescription(display, "DISPLAY_DESC", displayTitle, -8)

    CreateCheckbox(display, "useClassColors", "USE_CLASS_COLORS", 8, -82)
    CreateCheckbox(display, "showThreatValue", "SHOW_THREAT_VALUE", 8, -112)
    CreateCheckbox(display, "showTPS", "SHOW_TPS", 8, -142)
    CreateCheckbox(display, "showThreatETA", "SHOW_THREAT_ETA", 8, -172)
    CreateCheckbox(display, "showPercent", "SHOW_PERCENT", 8, -202)
    CreateCheckbox(display, "showThreatDelta", "SHOW_DELTA", 8, -232)
    CreateCheckbox(display, "showTankMarker", "SHOW_TANK_MARKER", 8, -262)
    CreateCheckbox(display, "highlightPlayer", "HIGHLIGHT_PLAYER", 8, -292)
    CreateCheckbox(display, "showPets", "SHOW_PETS", 8, -322)
    CreateCheckbox(display, "showTargetTarget", "SHOW_TARGET_TARGET", 8, -352)
    CreateCheckbox(display, "dynamicThreatColors", "DYNAMIC_THREAT_COLORS", 8, -382)
    CreateCheckbox(display, "highlightAggroChanges", "HIGHLIGHT_AGGRO_CHANGES", 8, -412)
    CreateCheckbox(display, "showAggroChangeMessage", "SHOW_AGGRO_CHANGE_MESSAGE", 8, -442)
    CreateCheckbox(display, "showGapToAggro", "SHOW_GAP_TO_AGGRO", 8, -472)

    CreateSlider(display, "windowAlpha", "WINDOW_ALPHA", 315, -82, 250, 0.20, 1.00, 0.05,
        function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end)
    CreateSlider(display, "barHeight", "BAR_HEIGHT", 315, -150, 250, 14, 40, 1,
        function(v) return tostring(math.floor(v + 0.5)) .. " px" end)
    CreateSlider(display, "fontSize", "FONT_SIZE", 315, -218, 250, 9, 20, 1,
        function(v) return tostring(math.floor(v + 0.5)) .. " pt" end)
    CreateSlider(display, "maxRows", "MAX_ROWS", 315, -286, 250, 1, 40, 1,
        function(v) return tostring(math.floor(v + 0.5)) end)

    local modeTitle = display:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    modeTitle:SetPoint("TOPLEFT", display, "TOPLEFT", 315, -350)
    BindLocale(display, modeTitle, "THREAT_MODE_TITLE")

    frame.modeButtons = {}
    local modeSpecs = {
        { mode = "AUTO", key = "MODE_AUTO", x = 315 },
        { mode = "TANK", key = "MODE_TANK", x = 379 },
        { mode = "DPS", key = "MODE_DPS", x = 443 },
        { mode = "HEALER", key = "MODE_HEALER", x = 507 },
    }

    for _, spec in ipairs(modeSpecs) do
        local button = CreateFrame("Button", nil, display, "UIPanelButtonTemplate")
        button:SetSize(62, 24)
        button:SetPoint("TOPLEFT", display, "TOPLEFT", spec.x, -374)
        BindLocale(display, button, spec.key)
        button.mode = spec.mode
        button:SetScript("OnClick", function(self)
            FT:SetThreatMode(self.mode)
        end)
        frame.modeButtons[spec.mode] = button
    end

    local presetTitle = display:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    presetTitle:SetPoint("TOPLEFT", display, "TOPLEFT", 315, -510)
    BindLocale(display, presetTitle, "PRESETS_TITLE")

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
        button:SetPoint("TOPLEFT", display, "TOPLEFT", spec.x, -536)
        BindLocale(display, button, spec.key)
        button.preset = spec.preset
        button:SetScript("OnClick", function(self)
            FT:ApplyDisplayPreset(self.preset)
        end)
        frame.presetButtons[spec.preset] = button
    end

    local sourceTitle = display:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    sourceTitle:SetPoint("TOPLEFT", display, "TOPLEFT", 8, -592)
    BindLocale(display, sourceTitle, "THREAT_SOURCE_TITLE")

    frame.sourceButtons = {}

    local targetSource = CreateFrame("Button", nil, display, "UIPanelButtonTemplate")
    targetSource:SetSize(105, 24)
    targetSource:SetPoint("TOPLEFT", display, "TOPLEFT", 8, -616)
    BindLocale(display, targetSource, "SOURCE_TARGET")
    targetSource:SetScript("OnClick", function()
        FT:SetThreatSource("TARGET")
    end)
    frame.sourceButtons.TARGET = targetSource

    local focusSource = CreateFrame("Button", nil, display, "UIPanelButtonTemplate")
    focusSource:SetSize(105, 24)
    focusSource:SetPoint("TOPLEFT", display, "TOPLEFT", 123, -616)
    BindLocale(display, focusSource, "SOURCE_FOCUS")
    focusSource:SetScript("OnClick", function()
        FT:SetThreatSource("FOCUS")
    end)
    frame.sourceButtons.FOCUS = focusSource

    frame.testModeButton = CreateButton(display, "TEST_MODE_START", 170, 315, -616, function()
        FT:SetTestMode(not FT.testMode)
    end)

    local skinTitle = display:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    skinTitle:SetPoint("TOPLEFT", display, "TOPLEFT", 8, -654)
    BindLocale(display, skinTitle, "SKIN_STYLE_TITLE")
    frame.skinAccentTitles[#frame.skinAccentTitles + 1] = { widget = skinTitle, role = "accent" }

    frame.skinButtons = {}
    local skinSpecs = {
        { style = "ORANGE", label = "SKIN_ORANGE", x = 8 },
        { style = "FROST", label = "SKIN_FROST", x = 204 },
        { style = "CRIMSON", label = "SKIN_CRIMSON", x = 400 },
    }

    for _, spec in ipairs(skinSpecs) do
        local skinButton = CreateFrame("Button", nil, display, "UIPanelButtonTemplate")
        skinButton:SetSize(175, 26)
        skinButton:SetPoint("TOPLEFT", display, "TOPLEFT", spec.x, -680)
        BindLocale(display, skinButton, spec.label)
        skinButton.skinStyle = spec.style
        skinButton:SetScript("OnClick", function(button)
            FT:SetSkinStyle(button.skinStyle)
        end)

        local swatch = skinButton:CreateTexture(nil, "ARTWORK")
        swatch:SetSize(9, 15)
        swatch:SetPoint("LEFT", skinButton, "LEFT", 8, 0)
        local sample = FT:GetSkinPalette(spec.style).title
        swatch:SetColorTexture(sample[1], sample[2], sample[3], 1)

        frame.skinButtons[spec.style] = skinButton
    end

    local responsive = display:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    responsive:SetPoint("TOPLEFT", display, "TOPLEFT", 8, -714)
    responsive:SetPoint("RIGHT", display, "RIGHT", -8, 0)
    responsive:SetJustifyH("LEFT")
    responsive:SetWordWrap(true)
    BindLocale(display, responsive, "SKIN_STYLE_INFO")
    SetTextColor(responsive, 0.72, 0.72, 0.72)

    -- Appearance
    local appearance = CreatePage(frame, "appearance")
    local appearanceTitle = AddTitle(appearance, "APPEARANCE_TITLE", -8)
    AddDescription(appearance, "APPEARANCE_DESC", appearanceTitle, -8)

    local barTextureTitle = appearance:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    barTextureTitle:SetPoint("TOPLEFT", appearance, "TOPLEFT", 8, -92)
    BindLocale(appearance, barTextureTitle, "BAR_TEXTURE_TITLE")

    frame.barTextureButtons = {}
    local barTextureSpecs = {
        { style = "BLIZZARD", key = "BAR_TEXTURE_BLIZZARD", x = 8 },
        { style = "SOLID", key = "BAR_TEXTURE_SOLID", x = 168 },
    }
    for _, spec in ipairs(barTextureSpecs) do
        local button = CreateFrame("Button", nil, appearance, "UIPanelButtonTemplate")
        button:SetSize(145, 26)
        button:SetPoint("TOPLEFT", appearance, "TOPLEFT", spec.x, -118)
        BindLocale(appearance, button, spec.key)
        button.appearanceStyle = spec.style
        button:SetScript("OnClick", function(self)
            FT:SetBarTexture(self.appearanceStyle)
        end)
        frame.barTextureButtons[spec.style] = button
    end

    local barStyleTitle = appearance:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    barStyleTitle:SetPoint("TOPLEFT", appearance, "TOPLEFT", 8, -174)
    BindLocale(appearance, barStyleTitle, "BAR_STYLE_TITLE")

    frame.barStyleButtons = {}
    local barStyleSpecs = {
        { style = "FLAT", key = "BAR_STYLE_FLAT", x = 8 },
        { style = "GRADIENT", key = "BAR_STYLE_GRADIENT", x = 168 },
    }
    for _, spec in ipairs(barStyleSpecs) do
        local button = CreateFrame("Button", nil, appearance, "UIPanelButtonTemplate")
        button:SetSize(145, 26)
        button:SetPoint("TOPLEFT", appearance, "TOPLEFT", spec.x, -200)
        BindLocale(appearance, button, spec.key)
        button.appearanceStyle = spec.style
        button:SetScript("OnClick", function(self)
            FT:SetBarStyle(self.appearanceStyle)
        end)
        frame.barStyleButtons[spec.style] = button
    end

    local windowStyleTitle = appearance:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    windowStyleTitle:SetPoint("TOPLEFT", appearance, "TOPLEFT", 8, -256)
    BindLocale(appearance, windowStyleTitle, "WINDOW_STYLE_TITLE")

    frame.windowStyleButtons = {}
    local windowStyleSpecs = {
        { style = "ADDON", key = "WINDOW_STYLE_ADDON", x = 8 },
        { style = "BLIZZARD", key = "WINDOW_STYLE_BLIZZARD", x = 168 },
        { style = "MINIMAL", key = "WINDOW_STYLE_MINIMAL", x = 328 },
    }
    for _, spec in ipairs(windowStyleSpecs) do
        local button = CreateFrame("Button", nil, appearance, "UIPanelButtonTemplate")
        button:SetSize(145, 26)
        button:SetPoint("TOPLEFT", appearance, "TOPLEFT", spec.x, -282)
        BindLocale(appearance, button, spec.key)
        button.appearanceStyle = spec.style
        button:SetScript("OnClick", function(self)
            FT:SetWindowStyle(self.appearanceStyle)
        end)
        frame.windowStyleButtons[spec.style] = button
    end

    CreateCheckbox(appearance, "showHeader", "SHOW_HEADER", 8, -338)

    local appearancePresetTitle = appearance:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    appearancePresetTitle:SetPoint("TOPLEFT", appearance, "TOPLEFT", 8, -392)
    BindLocale(appearance, appearancePresetTitle, "APPEARANCE_PRESETS")

    CreateButton(appearance, "APPEARANCE_PRESET_DEFAULT", 165, 8, -418, function()
        FT:ApplyAppearancePreset("DEFAULT")
    end)
    CreateButton(appearance, "APPEARANCE_PRESET_BLIZZARD", 165, 183, -418, function()
        FT:ApplyAppearancePreset("BLIZZARD")
    end)
    CreateButton(appearance, "APPEARANCE_PRESET_MINIMAL", 165, 358, -418, function()
        FT:ApplyAppearancePreset("MINIMAL")
    end)

    local appearanceInfo = appearance:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    appearanceInfo:SetPoint("TOPLEFT", appearance, "TOPLEFT", 8, -474)
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
    CreateCheckbox(warnings, "tankAggroLossWarning", "TANK_AGGRO_LOSS_WARNING", 315, -92)
    CreateCheckbox(warnings, "tankAggroLossSound", "TANK_AGGRO_LOSS_SOUND", 315, -126)
    CreateCheckbox(warnings, "tauntSwapDetection", "TAUNT_SWAP_DETECTION", 315, -160)
    CreateCheckbox(warnings, "showTankSwapMessage", "SHOW_TANK_SWAP_MESSAGE", 315, -194)

    CreateButton(warnings, "TEST_WARNING_SOUND", 160, 8, -276, function()
        FT:TestWarningSound()
    end)
    CreateButton(warnings, "TEST_AGGRO_LOSS_SOUND", 190, 315, -276, function()
        FT:TestAggroLossSound()
    end)

    local thresholdsTitle = warnings:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    thresholdsTitle:SetPoint("TOPLEFT", warnings, "TOPLEFT", 8, -328)
    BindLocale(warnings, thresholdsTitle, "THRESHOLDS_TITLE")
    thresholdsTitle:SetTextColor(1.0, 0.82, 0.25)
    frame.skinAccentTitles[#frame.skinAccentTitles + 1] = { widget = thresholdsTitle, role = "accent" }

    local thresholdsDesc = warnings:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    thresholdsDesc:SetPoint("TOPLEFT", warnings, "TOPLEFT", 8, -352)
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
    local thresholdYs = { -414, -486, -558 }

    for _, column in ipairs(modeColumns) do
        local title = warnings:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", warnings, "TOPLEFT", column.x, -392)
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
    warnInfo:SetPoint("TOPLEFT", warnings, "TOPLEFT", 8, -632)
    warnInfo:SetPoint("RIGHT", warnings, "RIGHT", -8, 0)
    warnInfo:SetJustifyH("LEFT")
    warnInfo:SetWordWrap(true)
    BindLocale(warnings, warnInfo, "WARNING_INFO")
    SetTextColor(warnInfo, 0.72, 0.72, 0.72)

    -- General
    local general = CreatePage(frame, "general")
    local generalTitle = AddTitle(general, "GENERAL_TITLE", -8)
    AddDescription(general, "GENERAL_DESC", generalTitle, -8)

    CreateCheckbox(general, "autoShowInCombat", "AUTO_SHOW", 8, -92)
    CreateCheckbox(general, "showMinimapButton", "SHOW_MINIMAP", 8, -126,
        function(value) FT:SetMinimapVisible(value) end)

    local lockCheck = CreateCheckbox(general, "locked", "LOCK_WINDOW", 8, -160,
        function(value) FT:SetLocked(value) end)
    lockCheck.isLockControl = true

    CreateCheckbox(general, "combatLock", "COMBAT_LOCK", 8, -194,
        function() FT:RefreshWindowLockState() end)
    CreateCheckbox(general, "smartAutoHide", "SMART_AUTO_HIDE", 8, -228)
    CreateCheckbox(general, "autoShowOnlyWithThreat", "AUTO_SHOW_ONLY_WITH_THREAT", 8, -262)
    CreateCheckbox(general, "clickToTauntEnabled", "CLICK_TO_TAUNT", 8, -296)

    CreateButton(general, "LEVEL60_RAID_PRESET", 220, 8, -336, function()
        FT:ApplyLevel60RaidPreset()
    end)

    -- Language selector lives in the free right-hand side of the General page.
    frame.languageTitle = general:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.languageTitle:SetPoint("TOPLEFT", general, "TOPLEFT", 315, -88)
    BindLocale(general, frame.languageTitle, "LANGUAGE_TITLE")
    frame.languageTitle:SetTextColor(1.0, 0.82, 0.25)
    frame.skinAccentTitles[#frame.skinAccentTitles + 1] = { widget = frame.languageTitle, role = "accent" }

    local languageDropdown = CreateFrame("Button", nil, general, "UIPanelButtonTemplate")
    languageDropdown:SetSize(250, 26)
    languageDropdown:SetPoint("TOPLEFT", general, "TOPLEFT", 315, -116)
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
        tile = true,
        tileSize = 16,
        edgeSize = 12,
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
        optionButton:SetScript("OnClick", function(button)
            languageMenu:Hide()
            FT:SetLanguage(button.languageCode)
            FT:RefreshConfigControls()
        end)
        frame.languageOptionButtons[option.code] = optionButton
    end

    languageDropdown:SetScript("OnClick", function()
        if languageMenu:IsShown() then
            languageMenu:Hide()
        else
            languageMenu:Show()
        end
    end)

    frame.languageInfo = general:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.languageInfo:SetPoint("TOPLEFT", general, "TOPLEFT", 315, -150)
    frame.languageInfo:SetTextColor(0.72, 0.72, 0.72)

    CreateSlider(general, "updateInterval", "UPDATE_INTERVAL", 315, -195, 250, 0.05, 0.50, 0.05,
        function(v) return string.format("%.2f s", v) end)

    local raidPerformanceTitle = general:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    raidPerformanceTitle:SetPoint("TOPLEFT", general, "TOPLEFT", 315, -258)
    BindLocale(general, raidPerformanceTitle, "RAID_PERFORMANCE_TITLE")
    raidPerformanceTitle:SetTextColor(1.0, 0.82, 0.25)
    frame.skinAccentTitles[#frame.skinAccentTitles + 1] = { widget = raidPerformanceTitle, role = "accent" }

    CreateCheckbox(general, "adaptiveRaidUpdates", "ADAPTIVE_RAID_UPDATES", 315, -280)
    CreateCheckbox(general, "optimizedRaidScan", "OPTIMIZED_RAID_SCAN", 315, -314)
    CreateCheckbox(general, "raidTopEnabled", "RAID_TOP_ENABLED", 315, -348)

    CreateSlider(general, "raidTopRows", "RAID_TOP_ROWS", 315, -384, 250, 1, 40, 1,
        function(v) return tostring(math.floor(v + 0.5)) end)

    CreateCheckbox(general, "raidAlwaysShowPlayer", "RAID_ALWAYS_SHOW_PLAYER", 315, -442)
    CreateCheckbox(general, "showRaidPets", "SHOW_RAID_PETS", 315, -476)
    CreateCheckbox(general, "raidTankViewEnabled", "RAID_TANK_VIEW", 315, -510)

    local raidPerformanceInfo = general:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    raidPerformanceInfo:SetPoint("TOPLEFT", general, "TOPLEFT", 315, -546)
    raidPerformanceInfo:SetPoint("RIGHT", general, "RIGHT", -8, 0)
    raidPerformanceInfo:SetJustifyH("LEFT")
    raidPerformanceInfo:SetWordWrap(true)
    BindLocale(general, raidPerformanceInfo, "RAID_PERFORMANCE_INFO")
    SetTextColor(raidPerformanceInfo, 0.72, 0.72, 0.72)

    CreateButton(general, "RESET_POSITION", 220, 8, -374, function()
        FT:ResetPosition()
    end)
    CreateButton(general, "RESET_SIZE", 220, 8, -408, function()
        FT:ResetFrameSize()
        FT:RefreshConfigControls()
    end)
    CreateButton(general, "WOW_SETTINGS", 220, 8, -442, function()
        if FT.OpenBlizzardSettings then
            FT:OpenBlizzardSettings()
        end
    end)

    local resetAllButton
    resetAllButton = CreateButton(general, "RESET_ALL_SETTINGS", 220, 8, -476, function()
        local now = GetTime()

        if resetAllButton.confirmUntil and resetAllButton.confirmUntil > now then
            resetAllButton.confirmUntil = nil
            FT:ResetAllSettings()
            BindLocale(general, resetAllButton, "RESET_ALL_SETTINGS")
        else
            resetAllButton.confirmUntil = now + 5
            resetAllButton:SetText(FT:L("RESET_ALL_CONFIRM"))
        end
    end)
    frame.resetAllButton = resetAllButton

    local sizeInfo = general:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sizeInfo:SetPoint("TOPLEFT", general, "TOPLEFT", 8, -526)
    sizeInfo:SetPoint("RIGHT", general, "LEFT", 292, 0)
    sizeInfo:SetJustifyH("LEFT")
    sizeInfo:SetWordWrap(true)
    BindLocale(general, sizeInfo, "SIZE_INFO")
    SetTextColor(sizeInfo, 0.72, 0.72, 0.72)

    local compactTip = general:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    compactTip:SetPoint("TOPLEFT", general, "TOPLEFT", 8, -590)
    compactTip:SetPoint("RIGHT", general, "LEFT", 292, 0)
    compactTip:SetJustifyH("LEFT")
    compactTip:SetWordWrap(true)
    BindLocale(general, compactTip, "COMPACT_INFO")
    SetTextColor(compactTip, 0.72, 0.72, 0.72)

    CreateCheckbox(general, "idleDimming", "IDLE_DIMMING", 315, -604, function()
        FT:UpdateWindowAlpha()
    end)

    CreateSlider(general, "idleAlpha", "IDLE_ALPHA", 315, -642, 250, 0.10, 1.00, 0.05,
        function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end,
        function()
            FT:UpdateWindowAlpha()
        end)

    local idleInfo = general:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    idleInfo:SetPoint("TOPLEFT", general, "TOPLEFT", 315, -692)
    idleInfo:SetPoint("RIGHT", general, "RIGHT", -8, 0)
    idleInfo:SetJustifyH("LEFT")
    idleInfo:SetWordWrap(true)
    BindLocale(general, idleInfo, "IDLE_DIMMING_INFO")
    SetTextColor(idleInfo, 0.72, 0.72, 0.72)

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
        end
    end

    if frame.subtitle then
        frame.subtitle:SetText(self:L("CONFIG_SUBTITLE") .. "  •  v" .. tostring(self.version))
    end

    if frame.languageInfo then
        frame.languageInfo:SetText(self:L("LANGUAGE_CURRENT"))
    end

    if frame.languageDropdown then
        frame.languageDropdown:SetText(GetLanguageLabel(self:GetLanguage()))
    end

    if frame.profileStatus and frame.profileStatusKey then
        frame.profileStatus:SetText(self:L(frame.profileStatusKey))
    end

    if frame.resetAllButton and frame.resetAllButton.confirmUntil
        and frame.resetAllButton.confirmUntil > GetTime() then
        frame.resetAllButton:SetText(self:L("RESET_ALL_CONFIRM"))
    end

    if frame.versionInfo then
        frame.versionInfo:SetText("ForeverThreat v" .. tostring(self.version) .. "  •  /ft config")
    end

    if frame.testModeButton then
        frame.testModeButton:SetText(self:L(self.testMode and "TEST_MODE_STOP" or "TEST_MODE_START"))
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
        self.configFrame.languageDropdown:SetText(GetLanguageLabel(self:GetLanguage()))
    end

    if self.configFrame.languageOptionButtons then
        local selectedLanguage = self:GetLanguage()
        for language, button in pairs(self.configFrame.languageOptionButtons) do
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
        local selected = self.db.windowStyle or "ADDON"
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
