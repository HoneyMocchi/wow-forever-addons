local addonName, FT = ...

local category
local localeEntries = {}
local localeButtonEntries = {}

local SETTING_LOCALE = {
    FOREVERTHREAT_SOUND = { "AGGRO_SOUND", "SETTINGS_SOUND_TIP" },
    FOREVERTHREAT_SOUND_SOLO = { "SOUND_IN_SOLO", "SETTINGS_SOUND_SOLO_TIP" },
    FOREVERTHREAT_SOUND_VOLUME = { "SOUND_VOLUME", "SETTINGS_SOUND_VOLUME_TIP" },
    FOREVERTHREAT_WARNINGS = { "SCREEN_WARNINGS", "SETTINGS_WARNINGS_TIP" },
    FOREVERTHREAT_HIGH_THREAT = { "HIGH_THREAT_WARNING_OPTION", "SETTINGS_HIGH_TIP" },
    FOREVERTHREAT_HIGH_WARNING_THRESHOLD = { "HIGH_THREAT_WARNING_THRESHOLD", "SETTINGS_HIGH_THRESHOLD_TIP" },
    FOREVERTHREAT_ETA_WARNING = { "ETA_WARNING_OPTION", "SETTINGS_ETA_WARNING_TIP" },
    FOREVERTHREAT_ETA_WARNING_THRESHOLD = { "ETA_WARNING_THRESHOLD", "SETTINGS_ETA_THRESHOLD_TIP" },
    FOREVERTHREAT_THREAT_RESET = { "THREAT_RESET_PROTECTION", "SETTINGS_THREAT_RESET_TIP" },
    FOREVERTHREAT_TANK_LOSS_WARNING = { "TANK_AGGRO_LOSS_WARNING", "SETTINGS_TANK_LOSS_TIP" },
    FOREVERTHREAT_TANK_LOSS_SOUND = { "TANK_AGGRO_LOSS_SOUND", "SETTINGS_TANK_LOSS_SOUND_TIP" },
    FOREVERTHREAT_TAUNT_SWAP = { "TAUNT_SWAP_DETECTION", "SETTINGS_TAUNT_SWAP_TIP" },
    FOREVERTHREAT_TANK_SWAP_MESSAGE = { "SHOW_TANK_SWAP_MESSAGE", "SETTINGS_TANK_SWAP_MESSAGE_TIP" },
    FOREVERTHREAT_AUTO_SHOW = { "AUTO_SHOW", "SETTINGS_AUTO_TIP" },
    FOREVERTHREAT_AUTO_SHOW_THREAT = { "AUTO_SHOW_ONLY_WITH_THREAT", "SETTINGS_AUTO_SHOW_THREAT_TIP" },
    FOREVERTHREAT_CLICK_TO_TAUNT = { "CLICK_TO_TAUNT", "SETTINGS_CLICK_TO_TAUNT_TIP" },
    FOREVERTHREAT_MINIMAP = { "SHOW_MINIMAP", "SETTINGS_MINIMAP_TIP" },
    FOREVERTHREAT_CLASS_COLORS = { "USE_CLASS_COLORS", "SETTINGS_CLASS_TIP" },
    FOREVERTHREAT_THREAT_VALUE = { "SHOW_THREAT_VALUE", "SETTINGS_VALUE_TIP" },
    FOREVERTHREAT_TPS = { "SHOW_TPS", "SETTINGS_TPS_TIP" },
    FOREVERTHREAT_ETA = { "SHOW_THREAT_ETA", "SETTINGS_ETA_TIP" },
    FOREVERTHREAT_PERCENT = { "SHOW_PERCENT", "SETTINGS_PERCENT_TIP" },
    FOREVERTHREAT_TANK_MARKER = { "SETTINGS_TANK_LABEL", "SETTINGS_TANK_TIP" },
    FOREVERTHREAT_AGGRO_CROWN = { "SHOW_AGGRO_CROWN", "SETTINGS_AGGRO_CROWN_TIP" },
    FOREVERTHREAT_TANK_STREAK = { "SHOW_TANK_STREAK", "SETTINGS_TANK_STREAK_TIP" },
    FOREVERTHREAT_THREAT_RACE = { "SHOW_THREAT_RACE", "SETTINGS_THREAT_RACE_TIP" },
    FOREVERTHREAT_FUN_MODE = { "FUN_MODE", "SETTINGS_FUN_MODE_TIP" },
    FOREVERTHREAT_THREAT_DELTA = { "SETTINGS_DELTA_LABEL", "SETTINGS_DELTA_TIP" },
    FOREVERTHREAT_HIGHLIGHT_PLAYER = { "HIGHLIGHT_PLAYER", "SETTINGS_HIGHLIGHT_TIP" },
    FOREVERTHREAT_SHOW_PETS = { "SHOW_PETS", "SETTINGS_PETS_TIP" },
    FOREVERTHREAT_TARGET_TARGET = { "SHOW_TARGET_TARGET", "SETTINGS_TARGET_TARGET_TIP" },
    FOREVERTHREAT_DYNAMIC_COLORS = { "DYNAMIC_THREAT_COLORS", "SETTINGS_DYNAMIC_COLORS_TIP" },
    FOREVERTHREAT_AGGRO_CHANGE = { "HIGHLIGHT_AGGRO_CHANGES", "SETTINGS_AGGRO_CHANGE_TIP" },
    FOREVERTHREAT_AGGRO_MESSAGE = { "SHOW_AGGRO_CHANGE_MESSAGE", "SETTINGS_AGGRO_MESSAGE_TIP" },
    FOREVERTHREAT_GAP_TO_AGGRO = { "SHOW_GAP_TO_AGGRO", "SETTINGS_GAP_TIP" },
    FOREVERTHREAT_SMART_AUTO_HIDE = { "SMART_AUTO_HIDE", "SETTINGS_SMART_HIDE_TIP" },
    FOREVERTHREAT_COMBAT_LOCK = { "COMBAT_LOCK", "SETTINGS_COMBAT_LOCK_TIP" },
    FOREVERTHREAT_UPDATE_INTERVAL = { "UPDATE_INTERVAL", "SETTINGS_UPDATE_TIP" },
    FOREVERTHREAT_ADAPTIVE_RAID = { "ADAPTIVE_RAID_UPDATES", "SETTINGS_ADAPTIVE_RAID_TIP" },
    FOREVERTHREAT_OPTIMIZED_RAID_SCAN = { "OPTIMIZED_RAID_SCAN", "SETTINGS_OPTIMIZED_RAID_SCAN_TIP" },
    FOREVERTHREAT_RAID_TOP = { "RAID_TOP_ENABLED", "SETTINGS_RAID_TOP_TIP" },
    FOREVERTHREAT_RAID_TOP_ROWS = { "RAID_TOP_ROWS", "SETTINGS_RAID_TOP_ROWS_TIP" },
    FOREVERTHREAT_RAID_PLAYER = { "RAID_ALWAYS_SHOW_PLAYER", "SETTINGS_RAID_PLAYER_TIP" },
    FOREVERTHREAT_RAID_TANK_VIEW = { "RAID_TANK_VIEW", "SETTINGS_RAID_TANK_VIEW_TIP" },
    FOREVERTHREAT_RAID_PETS = { "SHOW_RAID_PETS", "SETTINGS_RAID_PETS_TIP" },
    FOREVERTHREAT_ALPHA = { "SETTINGS_ALPHA_LABEL", "SETTINGS_ALPHA_TIP" },
    FOREVERTHREAT_IDLE_DIMMING = { "IDLE_DIMMING", "SETTINGS_IDLE_DIMMING_TIP" },
    FOREVERTHREAT_IDLE_ALPHA = { "IDLE_ALPHA", "SETTINGS_IDLE_ALPHA_TIP" },
    FOREVERTHREAT_SHOW_HEADER = { "SHOW_HEADER", "SETTINGS_SHOW_HEADER_TIP" },
    FOREVERTHREAT_BAR_HEIGHT = { "BAR_HEIGHT", "SETTINGS_BAR_TIP" },
    FOREVERTHREAT_FONT_SIZE = { "FONT_SIZE", "SETTINGS_FONT_TIP" },
    FOREVERTHREAT_MAX_ROWS = { "MAX_ROWS", "SETTINGS_MAX_TIP" },
}

local function GetThresholdLocale(variable)
    local mode, color = variable:match("^FOREVERTHREAT_([A-Z]+)_([A-Z]+)$")
    local validMode = mode == "TANK" or mode == "DPS" or mode == "HEALER"
    local validColor = color == "YELLOW" or color == "ORANGE" or color == "RED"
    if not validMode or not validColor then
        return nil
    end

    local modeKey = mode == "TANK" and "TANK_THRESHOLDS" or (mode == "DPS" and "DPS_THRESHOLDS" or "HEALER_THRESHOLDS")
    local colorKey = "THRESHOLD_" .. color
    local tipKey = "SETTINGS_" .. mode .. "_" .. color .. "_TIP"
    return FT:L(modeKey) .. " - " .. FT:L(colorKey), FT:L(tipKey)
end

local function GetSettingLocale(variable)
    local thresholdLabel, thresholdTip = GetThresholdLocale(variable)
    if thresholdLabel then
        return thresholdLabel, thresholdTip
    end

    local spec = SETTING_LOCALE[variable]
    if not spec then
        return nil, nil
    end
    return FT:L(spec[1]), FT:L(spec[2])
end

local function Refresh()
    FT:ApplySettings()
end

local function RegisterCheckbox(variable, key, label, defaultValue, tooltip)
    local setting = Settings.RegisterAddOnSetting(
        category,
        variable,
        key,
        FT.db,
        Settings.VarType.Boolean,
        label,
        defaultValue
    )

    local initializer = Settings.CreateCheckbox(category, setting, tooltip or label)
    localeEntries[variable] = { setting = setting, initializer = initializer }
    setting:SetValueChangedCallback(function()
        Refresh()
    end)

    return setting
end

local function RegisterSlider(variable, key, label, defaultValue, minValue, maxValue, step, tooltip)
    local setting = Settings.RegisterAddOnSetting(
        category,
        variable,
        key,
        FT.db,
        Settings.VarType.Number,
        label,
        defaultValue
    )

    local options = Settings.CreateSliderOptions(minValue, maxValue, step)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
        if step < 1 then
            return string.format("%.2f", value)
        end
        return tostring(math.floor(value + 0.5))
    end)

    local initializer = Settings.CreateSlider(category, setting, options, tooltip or label)
    localeEntries[variable] = { setting = setting, initializer = initializer }

    setting:SetValueChangedCallback(function()
        Refresh()
    end)

    return setting
end

function FT:InitializeSettings()
    if category or not Settings or not Settings.RegisterVerticalLayoutCategory then
        return
    end

    category = Settings.RegisterVerticalLayoutCategory("ForeverThreat")
    self.settingsCategory = category

    RegisterCheckbox("FOREVERTHREAT_SOUND", "soundEnabled", self:L("AGGRO_SOUND"), true, self:L("SETTINGS_SOUND_TIP"))
    RegisterCheckbox("FOREVERTHREAT_SOUND_SOLO", "soundInSolo", self:L("SOUND_IN_SOLO"), false, self:L("SETTINGS_SOUND_SOLO_TIP"))
    RegisterSlider("FOREVERTHREAT_SOUND_VOLUME", "soundVolume", self:L("SOUND_VOLUME"), 35, 10, 100, 5, self:L("SETTINGS_SOUND_VOLUME_TIP"))
    RegisterCheckbox("FOREVERTHREAT_WARNINGS", "warningEnabled", self:L("SCREEN_WARNINGS"), true, self:L("SETTINGS_WARNINGS_TIP"))
    RegisterCheckbox("FOREVERTHREAT_HIGH_THREAT", "highThreatWarning", self:L("HIGH_THREAT_WARNING_OPTION"), true, self:L("SETTINGS_HIGH_TIP"))
    RegisterSlider("FOREVERTHREAT_HIGH_WARNING_THRESHOLD", "highThreatThreshold", self:L("HIGH_THREAT_WARNING_THRESHOLD"), 90, 50, 99, 1, self:L("SETTINGS_HIGH_THRESHOLD_TIP"))
    RegisterCheckbox("FOREVERTHREAT_ETA_WARNING", "etaWarningEnabled", self:L("ETA_WARNING_OPTION"), true, self:L("SETTINGS_ETA_WARNING_TIP"))
    RegisterSlider("FOREVERTHREAT_ETA_WARNING_THRESHOLD", "etaWarningThreshold", self:L("ETA_WARNING_THRESHOLD"), 5, 1, 15, 1, self:L("SETTINGS_ETA_THRESHOLD_TIP"))
    RegisterCheckbox("FOREVERTHREAT_TANK_LEAD_WARNING", "tankLeadWarning", self:L("TANK_LEAD_WARNING_OPTION"), true, self:L("SETTINGS_TANK_LEAD_WARNING_TIP"))
    RegisterSlider("FOREVERTHREAT_TANK_LEAD_THRESHOLD", "tankLeadWarningThreshold", self:L("TANK_LEAD_WARNING_THRESHOLD"), 5, 1, 15, 1, self:L("SETTINGS_TANK_LEAD_THRESHOLD_TIP"))
    RegisterCheckbox("FOREVERTHREAT_THREAT_RESET", "threatResetProtection", self:L("THREAT_RESET_PROTECTION"), true, self:L("SETTINGS_THREAT_RESET_TIP"))
    RegisterCheckbox("FOREVERTHREAT_TANK_LOSS_WARNING", "tankAggroLossWarning", self:L("TANK_AGGRO_LOSS_WARNING"), true, self:L("SETTINGS_TANK_LOSS_TIP"))
    RegisterCheckbox("FOREVERTHREAT_TANK_LOSS_SOUND", "tankAggroLossSound", self:L("TANK_AGGRO_LOSS_SOUND"), true, self:L("SETTINGS_TANK_LOSS_SOUND_TIP"))
    RegisterCheckbox("FOREVERTHREAT_TAUNT_SWAP", "tauntSwapDetection", self:L("TAUNT_SWAP_DETECTION"), true, self:L("SETTINGS_TAUNT_SWAP_TIP"))
    RegisterCheckbox("FOREVERTHREAT_TANK_SWAP_MESSAGE", "showTankSwapMessage", self:L("SHOW_TANK_SWAP_MESSAGE"), true, self:L("SETTINGS_TANK_SWAP_MESSAGE_TIP"))
    RegisterSlider("FOREVERTHREAT_TANK_YELLOW", "tankThreatYellow", self:L("TANK_THRESHOLDS") .. " - " .. self:L("THRESHOLD_YELLOW"), 70, 1, 98, 1, self:L("SETTINGS_TANK_YELLOW_TIP"))
    RegisterSlider("FOREVERTHREAT_TANK_ORANGE", "tankThreatOrange", self:L("TANK_THRESHOLDS") .. " - " .. self:L("THRESHOLD_ORANGE"), 85, 2, 99, 1, self:L("SETTINGS_TANK_ORANGE_TIP"))
    RegisterSlider("FOREVERTHREAT_TANK_RED", "tankThreatRed", self:L("TANK_THRESHOLDS") .. " - " .. self:L("THRESHOLD_RED"), 95, 3, 100, 1, self:L("SETTINGS_TANK_RED_TIP"))
    RegisterSlider("FOREVERTHREAT_DPS_YELLOW", "dpsThreatYellow", self:L("DPS_THRESHOLDS") .. " - " .. self:L("THRESHOLD_YELLOW"), 70, 1, 98, 1, self:L("SETTINGS_DPS_YELLOW_TIP"))
    RegisterSlider("FOREVERTHREAT_DPS_ORANGE", "dpsThreatOrange", self:L("DPS_THRESHOLDS") .. " - " .. self:L("THRESHOLD_ORANGE"), 85, 2, 99, 1, self:L("SETTINGS_DPS_ORANGE_TIP"))
    RegisterSlider("FOREVERTHREAT_DPS_RED", "dpsThreatRed", self:L("DPS_THRESHOLDS") .. " - " .. self:L("THRESHOLD_RED"), 95, 3, 100, 1, self:L("SETTINGS_DPS_RED_TIP"))
    RegisterSlider("FOREVERTHREAT_HEALER_YELLOW", "healerThreatYellow", self:L("HEALER_THRESHOLDS") .. " - " .. self:L("THRESHOLD_YELLOW"), 60, 1, 98, 1, self:L("SETTINGS_HEALER_YELLOW_TIP"))
    RegisterSlider("FOREVERTHREAT_HEALER_ORANGE", "healerThreatOrange", self:L("HEALER_THRESHOLDS") .. " - " .. self:L("THRESHOLD_ORANGE"), 75, 2, 99, 1, self:L("SETTINGS_HEALER_ORANGE_TIP"))
    RegisterSlider("FOREVERTHREAT_HEALER_RED", "healerThreatRed", self:L("HEALER_THRESHOLDS") .. " - " .. self:L("THRESHOLD_RED"), 90, 3, 100, 1, self:L("SETTINGS_HEALER_RED_TIP"))
    RegisterCheckbox("FOREVERTHREAT_AUTO_SHOW", "autoShowInCombat", self:L("AUTO_SHOW"), true, self:L("SETTINGS_AUTO_TIP"))
    RegisterCheckbox("FOREVERTHREAT_AUTO_SHOW_THREAT", "autoShowOnlyWithThreat", self:L("AUTO_SHOW_ONLY_WITH_THREAT"), false, self:L("SETTINGS_AUTO_SHOW_THREAT_TIP"))
    RegisterCheckbox("FOREVERTHREAT_CLICK_TO_TAUNT", "clickToTauntEnabled", self:L("CLICK_TO_TAUNT"), false, self:L("SETTINGS_CLICK_TO_TAUNT_TIP"))
    RegisterCheckbox("FOREVERTHREAT_MINIMAP", "showMinimapButton", self:L("SHOW_MINIMAP"), true, self:L("SETTINGS_MINIMAP_TIP"))
    RegisterCheckbox("FOREVERTHREAT_CLASS_COLORS", "useClassColors", self:L("USE_CLASS_COLORS"), true, self:L("SETTINGS_CLASS_TIP"))
    RegisterCheckbox("FOREVERTHREAT_THREAT_VALUE", "showThreatValue", self:L("SHOW_THREAT_VALUE"), true, self:L("SETTINGS_VALUE_TIP"))
    RegisterCheckbox("FOREVERTHREAT_TPS", "showTPS", self:L("SHOW_TPS"), false, self:L("SETTINGS_TPS_TIP"))
    RegisterCheckbox("FOREVERTHREAT_ETA", "showThreatETA", self:L("SHOW_THREAT_ETA"), true, self:L("SETTINGS_ETA_TIP"))
    RegisterCheckbox("FOREVERTHREAT_PERCENT", "showPercent", self:L("SHOW_PERCENT"), true, self:L("SETTINGS_PERCENT_TIP"))
    RegisterCheckbox("FOREVERTHREAT_TANK_MARKER", "showTankMarker", self:L("SETTINGS_TANK_LABEL"), true, self:L("SETTINGS_TANK_TIP"))
    RegisterCheckbox("FOREVERTHREAT_AGGRO_CROWN", "showAggroCrown", self:L("SHOW_AGGRO_CROWN"), true, self:L("SETTINGS_AGGRO_CROWN_TIP"))
    RegisterCheckbox("FOREVERTHREAT_TANK_STREAK", "showTankStreak", self:L("SHOW_TANK_STREAK"), true, self:L("SETTINGS_TANK_STREAK_TIP"))
    RegisterCheckbox("FOREVERTHREAT_THREAT_RACE", "showThreatRace", self:L("SHOW_THREAT_RACE"), true, self:L("SETTINGS_THREAT_RACE_TIP"))
    RegisterCheckbox("FOREVERTHREAT_FUN_MODE", "funMode", self:L("FUN_MODE"), false, self:L("SETTINGS_FUN_MODE_TIP"))
    RegisterCheckbox("FOREVERTHREAT_THREAT_DELTA", "showThreatDelta", self:L("SETTINGS_DELTA_LABEL"), true, self:L("SETTINGS_DELTA_TIP"))
    RegisterCheckbox("FOREVERTHREAT_HIGHLIGHT_PLAYER", "highlightPlayer", self:L("HIGHLIGHT_PLAYER"), true, self:L("SETTINGS_HIGHLIGHT_TIP"))
    RegisterCheckbox("FOREVERTHREAT_SHOW_PETS", "showPets", self:L("SHOW_PETS"), false, self:L("SETTINGS_PETS_TIP"))
    RegisterCheckbox("FOREVERTHREAT_TARGET_TARGET", "showTargetTarget", self:L("SHOW_TARGET_TARGET"), true, self:L("SETTINGS_TARGET_TARGET_TIP"))
    RegisterCheckbox("FOREVERTHREAT_DYNAMIC_COLORS", "dynamicThreatColors", self:L("DYNAMIC_THREAT_COLORS"), true, self:L("SETTINGS_DYNAMIC_COLORS_TIP"))
    RegisterCheckbox("FOREVERTHREAT_AGGRO_CHANGE", "highlightAggroChanges", self:L("HIGHLIGHT_AGGRO_CHANGES"), true, self:L("SETTINGS_AGGRO_CHANGE_TIP"))
    RegisterCheckbox("FOREVERTHREAT_AGGRO_MESSAGE", "showAggroChangeMessage", self:L("SHOW_AGGRO_CHANGE_MESSAGE"), true, self:L("SETTINGS_AGGRO_MESSAGE_TIP"))
    RegisterCheckbox("FOREVERTHREAT_GAP_TO_AGGRO", "showGapToAggro", self:L("SHOW_GAP_TO_AGGRO"), true, self:L("SETTINGS_GAP_TIP"))
    RegisterCheckbox("FOREVERTHREAT_SMART_AUTO_HIDE", "smartAutoHide", self:L("SMART_AUTO_HIDE"), false, self:L("SETTINGS_SMART_HIDE_TIP"))
    RegisterCheckbox("FOREVERTHREAT_COMBAT_LOCK", "combatLock", self:L("COMBAT_LOCK"), true, self:L("SETTINGS_COMBAT_LOCK_TIP"))
    RegisterSlider("FOREVERTHREAT_UPDATE_INTERVAL", "updateInterval", self:L("UPDATE_INTERVAL"), 0.15, 0.05, 0.50, 0.05, self:L("SETTINGS_UPDATE_TIP"))
    RegisterCheckbox("FOREVERTHREAT_ADAPTIVE_RAID", "adaptiveRaidUpdates", self:L("ADAPTIVE_RAID_UPDATES"), true, self:L("SETTINGS_ADAPTIVE_RAID_TIP"))
    RegisterCheckbox("FOREVERTHREAT_OPTIMIZED_RAID_SCAN", "optimizedRaidScan", self:L("OPTIMIZED_RAID_SCAN"), false, self:L("SETTINGS_OPTIMIZED_RAID_SCAN_TIP"))
    RegisterCheckbox("FOREVERTHREAT_RAID_TOP", "raidTopEnabled", self:L("RAID_TOP_ENABLED"), true, self:L("SETTINGS_RAID_TOP_TIP"))
    RegisterSlider("FOREVERTHREAT_RAID_TOP_ROWS", "raidTopRows", self:L("RAID_TOP_ROWS"), 10, 1, 40, 1, self:L("SETTINGS_RAID_TOP_ROWS_TIP"))
    RegisterCheckbox("FOREVERTHREAT_RAID_PLAYER", "raidAlwaysShowPlayer", self:L("RAID_ALWAYS_SHOW_PLAYER"), true, self:L("SETTINGS_RAID_PLAYER_TIP"))
    RegisterCheckbox("FOREVERTHREAT_RAID_TANK_VIEW", "raidTankViewEnabled", self:L("RAID_TANK_VIEW"), true, self:L("SETTINGS_RAID_TANK_VIEW_TIP"))
    RegisterCheckbox("FOREVERTHREAT_RAID_DANGER_VIEW", "raidDangerViewEnabled", self:L("RAID_DANGER_VIEW"), false, self:L("SETTINGS_RAID_DANGER_VIEW_TIP"))
    RegisterCheckbox("FOREVERTHREAT_RAID_PETS", "showRaidPets", self:L("SHOW_RAID_PETS"), false, self:L("SETTINGS_RAID_PETS_TIP"))
    RegisterSlider("FOREVERTHREAT_ALPHA", "windowAlpha", self:L("SETTINGS_ALPHA_LABEL"), 0.97, 0.20, 1.00, 0.05, self:L("SETTINGS_ALPHA_TIP"))
    RegisterCheckbox("FOREVERTHREAT_IDLE_DIMMING", "idleDimming", self:L("IDLE_DIMMING"), false, self:L("SETTINGS_IDLE_DIMMING_TIP"))
    RegisterSlider("FOREVERTHREAT_IDLE_ALPHA", "idleAlpha", self:L("IDLE_ALPHA"), 0.35, 0.10, 1.00, 0.05, self:L("SETTINGS_IDLE_ALPHA_TIP"))
    RegisterCheckbox("FOREVERTHREAT_SHOW_HEADER", "showHeader", self:L("SHOW_HEADER"), true, self:L("SETTINGS_SHOW_HEADER_TIP"))
    RegisterSlider("FOREVERTHREAT_BAR_HEIGHT", "barHeight", self:L("BAR_HEIGHT"), 20, 14, 40, 1, self:L("SETTINGS_BAR_TIP"))
    RegisterSlider("FOREVERTHREAT_FONT_SIZE", "fontSize", self:L("FONT_SIZE"), 12, 9, 20, 1, self:L("SETTINGS_FONT_TIP"))
    RegisterSlider("FOREVERTHREAT_MAX_ROWS", "maxRows", self:L("MAX_ROWS"), 15, 1, 40, 1, self:L("SETTINGS_MAX_TIP"))

    local resetButton = CreateSettingsButtonInitializer(
        self:L("SETTINGS_RESET_LABEL"),
        self:L("SETTINGS_RESET_BUTTON"),
        function()
            FT:ResetPosition()
            FT:ResetFrameSize()
        end,
        self:L("SETTINGS_RESET_TIP"),
        true
    )

    local resetAllButton = CreateSettingsButtonInitializer(
        self:L("RESET_ALL_SETTINGS"),
        self:L("SETTINGS_RESET_BUTTON"),
        function()
            FT:ResetAllSettings()
        end,
        self:L("SETTINGS_RESET_ALL_TIP"),
        true
    )

    localeButtonEntries = {
        { initializer = resetButton, labelKey = "SETTINGS_RESET_LABEL", buttonKey = "SETTINGS_RESET_BUTTON", tooltipKey = "SETTINGS_RESET_TIP" },
        { initializer = resetAllButton, labelKey = "RESET_ALL_SETTINGS", buttonKey = "SETTINGS_RESET_BUTTON", tooltipKey = "SETTINGS_RESET_ALL_TIP" },
    }

    local layout = SettingsPanel:GetLayout(category)
    layout:AddInitializer(resetButton)
    layout:AddInitializer(resetAllButton)

    Settings.RegisterAddOnCategory(category)
end

function FT:RefreshBlizzardSettingsLocale()
    for variable, entry in pairs(localeEntries) do
        local label, tooltip = GetSettingLocale(variable)
        if label and entry.setting then
            if entry.setting.SetName then
                pcall(entry.setting.SetName, entry.setting, label)
            end
            if type(entry.setting) == "table" then
                entry.setting.name = label
            end
        end

        local initializer = entry.initializer
        if type(initializer) == "table" then
            if initializer.data and type(initializer.data) == "table" then
                if label then initializer.data.name = label end
                if tooltip then initializer.data.tooltip = tooltip end
            end
            if label then initializer.name = label end
            if tooltip then initializer.tooltip = tooltip end
        end
    end

    for _, entry in ipairs(localeButtonEntries) do
        local initializer = entry.initializer
        if type(initializer) == "table" then
            local label = self:L(entry.labelKey)
            local buttonText = self:L(entry.buttonKey)
            local tooltip = self:L(entry.tooltipKey)
            if initializer.data and type(initializer.data) == "table" then
                initializer.data.name = label
                initializer.data.buttonText = buttonText
                initializer.data.tooltip = tooltip
            end
            initializer.name = label
            initializer.buttonText = buttonText
            initializer.tooltip = tooltip
        end
    end

    if SettingsPanel and SettingsPanel.Refresh then
        pcall(SettingsPanel.Refresh, SettingsPanel)
    end
end

function FT:OpenBlizzardSettings()
    if not self.settingsCategory then
        self:InitializeSettings()
    end

    if self.RefreshBlizzardSettingsLocale then
        self:RefreshBlizzardSettingsLocale()
    end

    if self.settingsCategory and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(self.settingsCategory:GetID())
    end
end

function FT:OpenSettings()
    self:OpenBlizzardSettings()
end
