local addonName, FT = ...

_G.ForeverThreat = FT

FT.name = addonName
FT.version = "1.7.4"
do
    local clientLocale = type(GetLocale) == "function" and GetLocale() or "enUS"

    if clientLocale == "deDE" then
        FT.defaultLanguage = "DE"
    elseif clientLocale == "enUS" or clientLocale == "enGB" then
        FT.defaultLanguage = "EN"
    elseif clientLocale == "esES" or clientLocale == "esMX" then
        FT.defaultLanguage = "ES"
    elseif clientLocale == "frFR" then
        FT.defaultLanguage = "FR"
    elseif clientLocale == "koKR" then
        FT.defaultLanguage = "KO"
    else
        FT.defaultLanguage = "EN"
    end
end

FT.defaults = {
    visible = true,
    locked = false,
    scale = 1.0,
    point = "CENTER",
    x = 0,
    y = 0,
    minimapAngle = 220, -- legacy migration value
    minimap = {
        hide = false,
        minimapPos = 220,
    },
    frameWidth = 274,
    frameHeight = 140,
    autoShowInCombat = true,
    autoHideOutOfCombat = false,
    soundEnabled = true,
    warningEnabled = true,
    highThreatWarning = true,
    etaWarningEnabled = true,
    highThreatThreshold = 90,
    windowAlpha = 0.97,
    idleDimming = false,
    idleAlpha = 0.35,
    skinStyle = "ORANGE",
    barTexture = "BLIZZARD",
    barStyle = "FLAT",
    windowStyle = "ADDON",
    showHeader = true,
    barHeight = 20,
    fontSize = 12,
    useClassColors = true,
    showThreatValue = true,
    showTPS = false,
    showThreatETA = true,
    showPercent = true,
    showTankMarker = true,
    showThreatDelta = true,
    highlightPlayer = true,
    showPets = false,
    maxRows = 15,
    showMinimapButton = true,
    threatMode = "AUTO",
    dynamicThreatColors = true,
    showTargetTarget = true,
    highlightAggroChanges = true,
    smartAutoHide = false,
    combatLock = true,
    showGapToAggro = true,
    updateInterval = 0.15,
    autoShowOnlyWithThreat = false,
    showAggroChangeMessage = true,

    -- Final feature set
    threatSource = "TARGET",
    tankAggroLossWarning = true,
    tankAggroLossSound = true,
    tauntSwapDetection = true,
    showTankSwapMessage = true,
    threatResetProtection = true,
    clickToTauntEnabled = false,
    tauntButtonPoint = "CENTER",
    tauntButtonX = 0,
    tauntButtonY = -180,

    tankThreatYellow = 70,
    tankThreatOrange = 85,
    tankThreatRed = 95,
    dpsThreatYellow = 70,
    dpsThreatOrange = 85,
    dpsThreatRed = 95,
    healerThreatYellow = 60,
    healerThreatOrange = 75,
    healerThreatRed = 90,

    -- Raid / performance
    adaptiveRaidUpdates = true,
    optimizedRaidScan = false,
    raidTopEnabled = true,
    raidTopRows = 10,
    raidAlwaysShowPlayer = true,
    raidTankViewEnabled = true,
    showRaidPets = false,

    welcomeSeen = false,
    configLastTab = "welcome",
    language = FT.defaultLanguage,
    dbVersion = 28,
}

local function CopyDefaults(source, dest)
    for key, value in pairs(source) do
        if type(value) == "table" then
            dest[key] = dest[key] or {}
            CopyDefaults(value, dest[key])
        elseif dest[key] == nil then
            dest[key] = value
        end
    end
end


local function ResetToDefaults(source, dest)
    for key in pairs(dest) do
        if source[key] == nil then
            dest[key] = nil
        end
    end

    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(dest[key]) ~= "table" then
                dest[key] = {}
            end
            ResetToDefaults(value, dest[key])
        else
            dest[key] = value
        end
    end
end

function FT:IsSecret(value)
    -- IMPORTANT for WoW Forever:
    -- Never perform comparisons or boolean tests on a value before checking
    -- whether Blizzard marked it as secret.
    if type(_G.issecretvalue) == "function" then
        return _G.issecretvalue(value)
    end

    return false
end

function FT:IsSafe(value)
    -- Check secrecy FIRST. A secret boolean/number must not participate in
    -- `and`, `or`, `not`, comparisons, arithmetic, formatting, etc.
    if self:IsSecret(value) then
        return false
    end

    return value ~= nil
end

function FT:SafeText(value)
    if value == nil then
        return "nil"
    end
    if self:IsSecret(value) then
        return "<secret>"
    end
    return tostring(value)
end

function FT:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffef8b2cForeverThreat:|r " .. tostring(message))
end

function FT:ResetPosition()
    if not self.frame then
        return
    end

    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

    self.db.point = "CENTER"
    self.db.x = 0
    self.db.y = 0
end

function FT:IsPlayerInCombat()
    if type(_G.UnitAffectingCombat) ~= "function" then
        return false
    end

    local ok, inCombat = pcall(UnitAffectingCombat, "player")
    if not ok or self:IsSecret(inCombat) then
        return false
    end

    return inCombat == true
end

function FT:IsWindowInteractionLocked()
    if not self.db then
        return false
    end

    if self.db.locked then
        return true
    end

    return self.db.combatLock == true and self:IsPlayerInCombat()
end

function FT:RefreshWindowLockState()
    local locked = self:IsWindowInteractionLocked()

    if self.frame then
        self.frame:SetMovable(not locked)

        if self.frame.SetResizable then
            self.frame:SetResizable(not locked)
        end
    end

    if self.resizeGrip then
        if locked then
            self.resizeGrip:Hide()
        else
            self.resizeGrip:Show()
        end
    end
end

function FT:SetLocked(locked)
    self.db.locked = locked and true or false
    self:RefreshWindowLockState()
    self:Print(self.db.locked and self:L("WINDOW_LOCKED") or self:L("WINDOW_UNLOCKED"))
end

function FT:Toggle()
    if not self.frame then
        return
    end

    if self.frame:IsShown() then
        self.frame:Hide()
        self.db.visible = false
    else
        self.frame:Show()
        self.db.visible = true
        self.smartHideSuppressUntil = GetTime() + 5
        self:Refresh()
    end
end



function FT:SaveFrameSize()
    if not self.frame or not self.db then
        return
    end

    local width = math.floor((self.frame:GetWidth() or 274) + 0.5)
    local height = math.floor((self.frame:GetHeight() or 140) + 0.5)

    self.db.frameWidth = width
    self.db.frameHeight = height
end

function FT:SetFrameSize(width, height)
    if not self.frame then
        return
    end

    width = tonumber(width) or self.db.frameWidth or 274
    height = tonumber(height) or self.db.frameHeight or 140

    width = math.max(183, math.min(800, width))
    height = math.max(95, math.min(600, height))

    self.frame:SetSize(width, height)
    self.db.frameWidth = math.floor(width + 0.5)
    self.db.frameHeight = math.floor(height + 0.5)

    self:Refresh()
end

function FT:ResetFrameSize()
    self:SetFrameSize(274, 140)
    self:Print(self:L("SIZE_RESET_DONE"))
end

function FT:SetAutoCombat(enabled)
    self.db.autoShowInCombat = enabled and true or false
    self.db.autoHideOutOfCombat = false
    self:Print(enabled and self:L("AUTO_ON") or self:L("AUTO_OFF"))
end

function FT:SetSound(enabled)
    self.db.soundEnabled = enabled and true or false
    self:Print(enabled and self:L("SOUND_ON") or self:L("SOUND_OFF"))
end

function FT:SetWarnings(enabled)
    self.db.warningEnabled = enabled and true or false
    self:Print(enabled and self:L("WARNINGS_ON") or self:L("WARNINGS_OFF"))
end


-- Appearance presets only. Threat thresholds, threat bar colors and combat
-- warning colors are intentionally independent of the selected window skin.
local SKIN_PALETTES = {
    ORANGE = {
        background = { 0.025, 0.025, 0.025, 0.97 },
        border = { 0.55, 0.32, 0.12, 1.0 },
        title = { 1.0, 0.55, 0.16 },
        accent = { 1.0, 0.82, 0.25 },
        divider = { 0.55, 0.32, 0.12, 0.70 },
        rowBackground = { 0.045, 0.045, 0.045, 0.95 },
        playerHighlight = { 1.0, 0.82, 0.0, 0.12 },
        neutralBar = { 0.72, 0.42, 0.16 },
    },
    FROST = {
        background = { 0.018, 0.038, 0.060, 0.97 },
        border = { 0.20, 0.49, 0.69, 1.0 },
        title = { 0.43, 0.79, 1.0 },
        accent = { 0.50, 0.82, 1.0 },
        divider = { 0.20, 0.49, 0.69, 0.70 },
        rowBackground = { 0.027, 0.060, 0.093, 0.95 },
        playerHighlight = { 0.40, 0.75, 1.0, 0.12 },
        neutralBar = { 0.29, 0.58, 0.78 },
    },
    CRIMSON = {
        background = { 0.060, 0.020, 0.029, 0.97 },
        border = { 0.64, 0.22, 0.31, 1.0 },
        title = { 0.98, 0.43, 0.48 },
        accent = { 0.98, 0.58, 0.61 },
        divider = { 0.64, 0.22, 0.31, 0.70 },
        rowBackground = { 0.083, 0.033, 0.047, 0.95 },
        playerHighlight = { 0.98, 0.42, 0.49, 0.13 },
        neutralBar = { 0.74, 0.28, 0.36 },
    },
}

function FT:IsValidSkinStyle(style)
    return type(style) == "string" and SKIN_PALETTES[style] ~= nil
end

function FT:GetSkinPalette(style)
    local selected = style or (self.db and self.db.skinStyle) or "ORANGE"
    return SKIN_PALETTES[selected] or SKIN_PALETTES.ORANGE
end

function FT:SetSkinStyle(style, silent)
    style = tostring(style or "ORANGE"):upper()
    if not self:IsValidSkinStyle(style) or not self.db then
        return false
    end

    self.db.skinStyle = style

    if self.ApplySkin then
        self:ApplySkin()
    end

    if self.RefreshConfigControls then
        self:RefreshConfigControls()
    end

    if not silent then
        self:Print(self:L("SKIN_CHANGED", self:L("SKIN_" .. style)))
    end

    return true
end

local VALID_BAR_TEXTURES = {
    BLIZZARD = true,
    SOLID = true,
}

local VALID_BAR_STYLES = {
    FLAT = true,
    GRADIENT = true,
}

local VALID_WINDOW_STYLES = {
    ADDON = true,
    BLIZZARD = true,
    MINIMAL = true,
}

function FT:IsValidBarTexture(style)
    return type(style) == "string" and VALID_BAR_TEXTURES[style] == true
end

function FT:IsValidBarStyle(style)
    return type(style) == "string" and VALID_BAR_STYLES[style] == true
end

function FT:IsValidWindowStyle(style)
    return type(style) == "string" and VALID_WINDOW_STYLES[style] == true
end

function FT:SetBarTexture(style)
    style = tostring(style or "BLIZZARD"):upper()
    if not self:IsValidBarTexture(style) or not self.db then
        return false
    end
    self.db.barTexture = style
    self:ApplySettings()
    if self.RefreshConfigControls then self:RefreshConfigControls() end
    return true
end

function FT:SetBarStyle(style)
    style = tostring(style or "FLAT"):upper()
    if not self:IsValidBarStyle(style) or not self.db then
        return false
    end
    self.db.barStyle = style
    self:ApplySettings()
    if self.RefreshConfigControls then self:RefreshConfigControls() end
    return true
end

function FT:SetWindowStyle(style)
    style = tostring(style or "ADDON"):upper()
    if not self:IsValidWindowStyle(style) or not self.db then
        return false
    end
    self.db.windowStyle = style
    self:ApplySettings()
    if self.RefreshConfigControls then self:RefreshConfigControls() end
    return true
end

function FT:ApplyAppearancePreset(name)
    name = tostring(name or ""):upper()
    if not self.db then
        return false
    end

    if name == "DEFAULT" then
        self.db.barTexture = "BLIZZARD"
        self.db.barStyle = "FLAT"
        self.db.windowStyle = "ADDON"
        self.db.showHeader = true
    elseif name == "BLIZZARD" then
        self.db.barTexture = "BLIZZARD"
        self.db.barStyle = "GRADIENT"
        self.db.windowStyle = "BLIZZARD"
        self.db.showHeader = false
    elseif name == "MINIMAL" then
        self.db.barTexture = "SOLID"
        self.db.barStyle = "FLAT"
        self.db.windowStyle = "MINIMAL"
        self.db.showHeader = false
    else
        return false
    end

    self:ApplySettings()
    if self.RefreshConfigControls then self:RefreshConfigControls() end
    return true
end

local DISPLAY_PRESETS = {
    MINIMAL = {
        threatMode = "AUTO",
        useClassColors = true,
        showThreatValue = false,
        showTPS = false,
        showThreatETA = false,
        showPercent = true,
        showThreatDelta = false,
        showTankMarker = true,
        highlightPlayer = true,
        showPets = false,
        showTargetTarget = false,
        dynamicThreatColors = true,
        highlightAggroChanges = true,
        showGapToAggro = false,
        windowAlpha = 0.95,
        barHeight = 18,
        fontSize = 11,
        maxRows = 10,
    },
    STANDARD = {
        threatMode = "AUTO",
        useClassColors = true,
        showThreatValue = true,
        showTPS = false,
        showThreatETA = true,
        showPercent = true,
        showThreatDelta = true,
        showTankMarker = true,
        highlightPlayer = true,
        showPets = false,
        showTargetTarget = true,
        dynamicThreatColors = true,
        highlightAggroChanges = true,
        showGapToAggro = true,
        windowAlpha = 0.97,
        barHeight = 20,
        fontSize = 12,
        maxRows = 15,
    },
    TANK = {
        threatMode = "TANK",
        useClassColors = true,
        showThreatValue = true,
        showTPS = false,
        showThreatETA = true,
        showPercent = true,
        showThreatDelta = true,
        showTankMarker = true,
        highlightPlayer = true,
        showPets = false,
        showTargetTarget = true,
        dynamicThreatColors = true,
        highlightAggroChanges = true,
        showGapToAggro = true,
        windowAlpha = 0.97,
        barHeight = 20,
        fontSize = 12,
        maxRows = 20,
    },
    DPS = {
        threatMode = "DPS",
        useClassColors = true,
        showThreatValue = false,
        showTPS = false,
        showThreatETA = true,
        showPercent = true,
        showThreatDelta = true,
        showTankMarker = true,
        highlightPlayer = true,
        showPets = false,
        showTargetTarget = true,
        dynamicThreatColors = true,
        highlightAggroChanges = true,
        showGapToAggro = true,
        windowAlpha = 0.97,
        barHeight = 20,
        fontSize = 12,
        maxRows = 15,
    },
    HEALER = {
        threatMode = "HEALER",
        useClassColors = true,
        showThreatValue = false,
        showTPS = false,
        showThreatETA = true,
        showPercent = true,
        showThreatDelta = true,
        showTankMarker = true,
        highlightPlayer = true,
        showPets = false,
        showTargetTarget = true,
        dynamicThreatColors = true,
        highlightAggroChanges = true,
        showGapToAggro = true,
        windowAlpha = 0.97,
        barHeight = 20,
        fontSize = 12,
        maxRows = 15,
    },
}

function FT:ApplyLevel60RaidPreset()
    if not self.db then
        return false
    end

    self.db.showThreatETA = true
    self.db.warningEnabled = true
    self.db.highThreatWarning = true
    self.db.etaWarningEnabled = true
    self.db.tankAggroLossWarning = true
    self.db.threatResetProtection = true
    self.db.tauntSwapDetection = true

    self.db.adaptiveRaidUpdates = true
    self.db.optimizedRaidScan = false
    self.db.raidTopEnabled = true
    self.db.raidTopRows = 10
    self.db.raidAlwaysShowPlayer = true
    self.db.raidTankViewEnabled = true

    self.db.showRaidPets = false
    self.db.showPets = false

    self:ApplySettings()
    if self.RefreshConfigControls then
        self:RefreshConfigControls()
    end
    return true
end

local PROFILE_KEYS = {
    "locked",
    "frameWidth",
    "frameHeight",
    "autoShowInCombat",
    "soundEnabled",
    "warningEnabled",
    "highThreatWarning",
    "etaWarningEnabled",
    "highThreatThreshold",
    "windowAlpha",
    "idleDimming",
    "idleAlpha",
    "skinStyle",
    "barTexture",
    "barStyle",
    "windowStyle",
    "showHeader",
    "barHeight",
    "fontSize",
    "useClassColors",
    "showThreatValue",
    "showTPS",
    "showThreatETA",
    "showPercent",
    "showTankMarker",
    "showThreatDelta",
    "highlightPlayer",
    "showPets",
    "maxRows",
    "showMinimapButton",
    "threatMode",
    "dynamicThreatColors",
    "showTargetTarget",
    "highlightAggroChanges",
    "showAggroChangeMessage",
    "threatSource",
    "tankAggroLossWarning",
    "tankAggroLossSound",
    "tauntSwapDetection",
    "showTankSwapMessage",
    "threatResetProtection",
    "clickToTauntEnabled",
    "tauntButtonPoint",
    "tauntButtonX",
    "tauntButtonY",
    "tankThreatYellow",
    "tankThreatOrange",
    "tankThreatRed",
    "dpsThreatYellow",
    "dpsThreatOrange",
    "dpsThreatRed",
    "healerThreatYellow",
    "healerThreatOrange",
    "healerThreatRed",
    "smartAutoHide",
    "combatLock",
    "showGapToAggro",
    "updateInterval",
    "autoShowOnlyWithThreat",
    "adaptiveRaidUpdates",
    "optimizedRaidScan",
    "raidTopEnabled",
    "raidTopRows",
    "raidAlwaysShowPlayer",
    "raidTankViewEnabled",
    "showRaidPets",
}

local function IsValidThreatMode(mode)
    return mode == "AUTO" or mode == "TANK" or mode == "DPS" or mode == "HEALER"
end

function FT:ExportProfileString()
    if not self.db then
        return ""
    end

    local parts = { "FT1" }

    for _, key in ipairs(PROFILE_KEYS) do
        local value = self.db[key]
        local valueType = type(value)

        if valueType == "boolean" then
            value = value and "1" or "0"
        elseif valueType == "number" or valueType == "string" then
            value = tostring(value)
        else
            value = ""
        end

        parts[#parts + 1] = key .. "=" .. value
    end

    return table.concat(parts, ";")
end

function FT:ImportProfileString(text)
    if type(text) ~= "string" or text == "" then
        return false, self:L("PROFILE_IMPORT_EMPTY")
    end

    text = text:match("^%s*(.-)%s*$") or ""

    if not text:match("^FT1;") then
        return false, self:L("PROFILE_IMPORT_INVALID")
    end

    local incoming = {}

    for token in text:gmatch("[^;]+") do
        local key, value = token:match("^([^=]+)=(.*)$")
        if key and value then
            incoming[key] = value
        end
    end

    local changed = false

    for _, key in ipairs(PROFILE_KEYS) do
        local raw = incoming[key]

        if raw ~= nil and self.defaults[key] ~= nil then
            local defaultType = type(self.defaults[key])
            local parsed = nil

            if defaultType == "boolean" then
                if raw == "1" or raw == "true" then
                    parsed = true
                elseif raw == "0" or raw == "false" then
                    parsed = false
                end
            elseif defaultType == "number" then
                parsed = tonumber(raw)
            elseif defaultType == "string" then
                parsed = raw
            end

            if key == "threatMode" and not IsValidThreatMode(parsed) then
                parsed = nil
            elseif key == "skinStyle" and not self:IsValidSkinStyle(parsed) then
                parsed = nil
            elseif key == "barTexture" and not self:IsValidBarTexture(parsed) then
                parsed = nil
            elseif key == "barStyle" and not self:IsValidBarStyle(parsed) then
                parsed = nil
            elseif key == "windowStyle" and not self:IsValidWindowStyle(parsed) then
                parsed = nil
            end

            if parsed ~= nil then
                self.db[key] = parsed
                changed = true
            end
        end
    end

    if not changed then
        return false, self:L("PROFILE_IMPORT_INVALID")
    end

    self:ApplySettings()

    if self.RefreshConfigControls then
        self:RefreshConfigControls()
    end

    return true, self:L("PROFILE_IMPORT_OK")
end

function FT:ApplyDisplayPreset(name)
    name = tostring(name or ""):upper()
    local preset = DISPLAY_PRESETS[name]

    if not preset or not self.db then
        return false
    end

    for key, value in pairs(preset) do
        self.db[key] = value
    end

    self:ApplySettings()

    if self.RefreshConfigControls then
        self:RefreshConfigControls()
    end

    self:Print(self:L("PRESET_APPLIED", self:L("PRESET_" .. name)))
    return true
end

function FT:ResetAllSettings()
    if not self.db then
        return
    end

    ResetToDefaults(self.defaults, self.db)
    self.db.dbVersion = self.defaults.dbVersion

    if self.frame then
        self.frame:ClearAllPoints()
        self.frame:SetPoint(
            self.db.point or "CENTER",
            UIParent,
            self.db.point or "CENTER",
            self.db.x or 0,
            self.db.y or 0
        )
        self.frame:SetSize(self.db.frameWidth or 274, self.db.frameHeight or 140)

        if self.db.visible then
            self.frame:Show()
        else
            self.frame:Hide()
        end
    end

    self.smartHideSuppressUntil = GetTime() + 5

    if self.RefreshMinimapButton then
        self:RefreshMinimapButton()
    end

    self:ApplySettings()

    if self.RefreshConfigLocale then
        self:RefreshConfigLocale()
    end

    if self.RefreshConfigControls then
        self:RefreshConfigControls()
    end

    self:Print(self:L("ALL_SETTINGS_RESET_DONE"))
end

function FT:SetThreatMode(mode, silent)
    mode = tostring(mode or "AUTO"):upper()

    if mode ~= "AUTO" and mode ~= "TANK" and mode ~= "DPS" and mode ~= "HEALER" then
        return false
    end

    self.db.threatMode = mode

    if self.ApplySettings then
        self:ApplySettings()
    end

    if self.RefreshConfigControls then
        self:RefreshConfigControls()
    end

    if not silent then
        self:Print(self:L("MODE_CHANGED", self:L("MODE_" .. mode)))
    end

    return true
end

function FT:SetThreatSource(source, silent)
    source = tostring(source or "TARGET"):upper()

    if source ~= "TARGET" and source ~= "FOCUS" then
        return false
    end

    if self.db and self.db.clickToTauntEnabled
        and type(_G.InCombatLockdown) == "function"
        and InCombatLockdown() then
        if not silent then
            self:Print(self:L("CLICK_TO_TAUNT_SOURCE_LOCKED"))
        end
        return false
    end

    self.db.threatSource = source
    self.lastAggroHolderName = nil
    self.lastAggroHolderWasPlayer = nil
    self.lastEffectiveThreatMode = nil
    self.lastTargetingPlayer = false
    self.hasSeenNonPlayerTank = false
    self.highThreatWarned = false
    self.threatDirty = true

    if self.ClearThreatDisplay then
        self:ClearThreatDisplay()
    end

    if self.ApplySettings then
        self:ApplySettings()
    end

    if self.RefreshConfigControls then
        self:RefreshConfigControls()
    end

    if not silent then
        self:Print(self:L("SOURCE_CHANGED", self:L("SOURCE_" .. source)))
    end

    return true
end

local function ClampThreshold(value, low, high, fallback)
    value = tonumber(value) or fallback
    value = math.floor(value + 0.5)
    return math.max(low, math.min(high, value))
end

function FT:NormalizeThreatThresholds()
    if not self.db then
        return
    end

    local modes = {
        { "tankThreatYellow", "tankThreatOrange", "tankThreatRed", 70, 85, 95 },
        { "dpsThreatYellow", "dpsThreatOrange", "dpsThreatRed", 70, 85, 95 },
        { "healerThreatYellow", "healerThreatOrange", "healerThreatRed", 60, 75, 90 },
    }

    for _, spec in ipairs(modes) do
        local yellow = ClampThreshold(self.db[spec[1]], 1, 98, spec[4])
        local orange = ClampThreshold(self.db[spec[2]], yellow + 1, 99, spec[5])
        local red = ClampThreshold(self.db[spec[3]], orange + 1, 100, spec[6])

        self.db[spec[1]] = yellow
        self.db[spec[2]] = orange
        self.db[spec[3]] = red
    end
end

function FT:GetThreatThresholds(mode)
    self:NormalizeThreatThresholds()

    mode = tostring(mode or "DPS"):upper()

    if mode == "TANK" then
        return self.db.tankThreatYellow, self.db.tankThreatOrange, self.db.tankThreatRed
    elseif mode == "HEALER" then
        return self.db.healerThreatYellow, self.db.healerThreatOrange, self.db.healerThreatRed
    end

    return self.db.dpsThreatYellow, self.db.dpsThreatOrange, self.db.dpsThreatRed
end

function FT:PlayWarningSound(forceTest)
    if not forceTest and not self.db.soundEnabled then
        return false
    end

    -- WoW's classic raid-warning sound. Prefer the named SoundKit when present.
    local soundID = nil

    if _G.SOUNDKIT and SOUNDKIT.RAID_WARNING then
        soundID = SOUNDKIT.RAID_WARNING
    else
        -- RAID_WARNING SoundKit ID used by WoW clients.
        soundID = 8959
    end

    if type(_G.PlaySound) ~= "function" then
        return false, self:L("SOUND_API_MISSING")
    end

    local ok, played = pcall(PlaySound, soundID, "Master")

    if not ok then
        return false, self:L("SOUND_API_ERROR")
    end

    -- Some client versions return nil even though playback was successfully requested.
    if played == false then
        return false, self:L("SOUND_REJECTED")
    end

    return true
end

function FT:PlayAggroLossSound(forceTest)
    if not forceTest and not self.db.tankAggroLossSound then
        return false
    end

    local soundID = nil

    -- Prefer a different alert sound from the normal RAID_WARNING when the
    -- client exposes it. Fallback keeps the feature functional on Forever
    -- clients with a smaller SoundKit table.
    if _G.SOUNDKIT and SOUNDKIT.ALARM_CLOCK_WARNING_3 then
        soundID = SOUNDKIT.ALARM_CLOCK_WARNING_3
    elseif _G.SOUNDKIT and SOUNDKIT.READY_CHECK then
        soundID = SOUNDKIT.READY_CHECK
    elseif _G.SOUNDKIT and SOUNDKIT.RAID_WARNING then
        soundID = SOUNDKIT.RAID_WARNING
    else
        soundID = 8959
    end

    if type(_G.PlaySound) ~= "function" then
        return false, self:L("SOUND_API_MISSING")
    end

    local ok, played = pcall(PlaySound, soundID, "Master")

    if not ok then
        return false, self:L("SOUND_API_ERROR")
    end

    if played == false then
        return false, self:L("SOUND_REJECTED")
    end

    return true
end

function FT:TestAggroLossSound()
    local success, reason = self:PlayAggroLossSound(true)

    if success then
        self:Print(self:L("AGGRO_LOSS_SOUND_TEST_OK"))
    else
        self:Print(self:L("SOUND_TEST_FAILED", tostring(reason or self:L("UNKNOWN_ERROR"))))
    end
end

function FT:TestWarningSound()
    local success, reason = self:PlayWarningSound(true)

    if success then
        self:Print(self:L("SOUND_TEST_OK"))
    else
        self:Print(self:L("SOUND_TEST_FAILED", tostring(reason or self:L("UNKNOWN_ERROR"))))
    end
end


function FT:IsThreatFrameMouseOver()
    if not self.frame or not self.frame:IsShown() then
        return false
    end

    if self.frame.IsMouseOver then
        local ok, isOver = pcall(self.frame.IsMouseOver, self.frame)
        if ok and not self:IsSecret(isOver) then
            return isOver == true
        end
    end

    return self.frameMouseOver == true
end

function FT:ShouldUseFullWindowAlpha()
    if not self.db or not self.db.idleDimming then
        return true
    end

    if self.testMode or self:IsPlayerInCombat() then
        return true
    end

    if self:IsThreatFrameMouseOver() then
        return true
    end

    if self.lastThreatMeaningful == true then
        return true
    end

    return false
end

function FT:UpdateWindowAlpha()
    if not self.frame or not self.db then
        return
    end

    local fullAlpha = tonumber(self.db.windowAlpha) or 0.97
    fullAlpha = math.max(0.20, math.min(1.00, fullAlpha))

    local idleAlpha = tonumber(self.db.idleAlpha) or 0.35
    idleAlpha = math.max(0.10, math.min(1.00, idleAlpha))

    -- Idle opacity must never be brighter than the user's normal opacity.
    local alpha = self:ShouldUseFullWindowAlpha() and fullAlpha or math.min(idleAlpha, fullAlpha)
    self.frame:SetAlpha(alpha)
end

function FT:ApplySettings()
    self:NormalizeThreatThresholds()
    if self.ApplySkin then
        self:ApplySkin()
    end

    if self.frame then
        self:UpdateWindowAlpha()
        self:RefreshWindowLockState()

        if self.RefreshLayout then
            self:RefreshLayout()
        else
            self:Refresh()
        end
    end

    if self.RefreshMinimapButton then
        self:RefreshMinimapButton()
    end

    if self.RefreshClickToTauntButton then
        self:RefreshClickToTauntButton()
    end
end

function FT:SetWindowAlpha(value)
    value = tonumber(value) or 0.97
    value = math.max(0.20, math.min(1.00, value))
    self.db.windowAlpha = value
    self:ApplySettings()
end

function FT:SetBarHeight(value)
    value = tonumber(value) or 20
    value = math.max(14, math.min(40, math.floor(value + 0.5)))
    self.db.barHeight = value
    self:ApplySettings()
end

function FT:SetFontSize(value)
    value = tonumber(value) or 12
    value = math.max(9, math.min(20, math.floor(value + 0.5)))
    self.db.fontSize = value
    self:ApplySettings()
end

function FT:SetMaxRows(value)
    value = tonumber(value) or 15
    value = math.max(1, math.min(40, math.floor(value + 0.5)))
    self.db.maxRows = value
    self:ApplySettings()
end

function FT:DebugThreat()
    local build, _, _, interface = GetBuildInfo()
    self:Print(self:L("DEBUG_VERSION", self.version, self:SafeText(build), self:SafeText(interface)))

    local sourceUnit = "target"
    if self.GetThreatSourceUnit then
        sourceUnit = self:GetThreatSourceUnit()
    end

    if not UnitExists(sourceUnit) then
        self:Print(sourceUnit == "focus" and self:L("DEBUG_NO_FOCUS") or self:L("DEBUG_NO_TARGET"))
        return
    end

    local sourceName = UnitName(sourceUnit)
    if self:IsSecret(sourceName) or sourceName == nil then
        sourceName = "?"
    end

    self:Print(self:L("DEBUG_SOURCE", self:L(sourceUnit == "focus" and "SOURCE_FOCUS" or "SOURCE_TARGET"), sourceName))

    local ok, isTanking, status, scaled, rawPct, rawThreat =
        pcall(UnitDetailedThreatSituation, "player", sourceUnit)

    if not ok then
        self:Print(self:L("DEBUG_API_ERROR"))
        return
    end

    self:Print(self:L(
        "DEBUG_PLAYER_VALUES",
        self:SafeText(isTanking),
        self:SafeText(status),
        self:SafeText(scaled),
        self:SafeText(rawPct),
        self:SafeText(rawThreat)
    ))

    local groupSize = 1
    if IsInRaid() then
        groupSize = GetNumGroupMembers()
    elseif IsInGroup() then
        groupSize = GetNumSubgroupMembers() + 1
    end

    local effectiveInterval = tonumber(self.db.updateInterval) or 0.15
    if self.GetEffectiveUpdateInterval then
        effectiveInterval = self:GetEffectiveUpdateInterval()
    end

    self:Print(self:L(
        "DEBUG_PERFORMANCE",
        groupSize,
        effectiveInterval,
        self.db.raidTopEnabled and self:L("YES") or self:L("NO")
    ))
end

SLASH_FOREVERTHREAT1 = "/forevertreat"
SLASH_FOREVERTHREAT2 = "/ft"

SlashCmdList.FOREVERTHREAT = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")

    if msg == "" or msg == "toggle" then
        FT:Toggle()
    elseif msg == "show" then
        FT.frame:Show()
        FT.db.visible = true
        FT:Refresh()
    elseif msg == "hide" then
        FT.frame:Hide()
        FT.db.visible = false
    elseif msg == "lock" then
        FT:SetLocked(true)
    elseif msg == "unlock" then
        FT:SetLocked(false)
    elseif msg == "reset" then
        FT:ResetPosition()
        FT:Print(FT:L("POSITION_RESET_DONE"))
    elseif msg == "debug" then
        FT:DebugThreat()
    elseif msg == "debugtaunt" then
        FT.tauntDebug = not FT.tauntDebug
        FT:Print(FT:L(FT.tauntDebug and "DEBUG_TAUNT_ON" or "DEBUG_TAUNT_OFF"))
    elseif msg == "testsound" then
        FT:TestWarningSound()
    elseif msg == "testlosssound" then
        FT:TestAggroLossSound()
    elseif msg == "test" or msg == "testmode" then
        if FT.SetTestMode then
            FT:SetTestMode(not FT.testMode)
        end
    elseif msg == "sound on" then
        FT:SetSound(true)
    elseif msg == "sound off" then
        FT:SetSound(false)
    elseif msg == "warnings on" then
        FT:SetWarnings(true)
    elseif msg == "warnings off" then
        FT:SetWarnings(false)
    elseif msg == "auto on" then
        FT:SetAutoCombat(true)
    elseif msg == "auto off" then
        FT:SetAutoCombat(false)
    elseif msg == "resetsize" then
        FT:ResetFrameSize()
    elseif msg == "config" or msg == "options" then
        if FT.OpenConfig then
            FT:OpenConfig("display")
        end
    elseif msg == "welcome" then
        if FT.OpenConfig then
            FT:OpenConfig("welcome")
        end
    elseif msg == "lang de" or msg == "language de" then
        FT:SetLanguage("DE")
    elseif msg == "lang en" or msg == "language en" then
        FT:SetLanguage("EN")
    elseif msg == "lang es" or msg == "language es" then
        FT:SetLanguage("ES")
    elseif msg == "lang fr" or msg == "language fr" then
        FT:SetLanguage("FR")
    elseif msg == "lang ko" or msg == "language ko" then
        FT:SetLanguage("KO")
    elseif msg == "mode auto" then
        FT:SetThreatMode("AUTO")
    elseif msg == "mode tank" then
        FT:SetThreatMode("TANK")
    elseif msg == "mode dps" then
        FT:SetThreatMode("DPS")
    elseif msg == "mode healer" or msg == "mode heal" then
        FT:SetThreatMode("HEALER")
    elseif msg == "source target" then
        FT:SetThreatSource("TARGET")
    elseif msg == "source focus" then
        FT:SetThreatSource("FOCUS")
    elseif msg == "skin orange" or msg == "skin classic" then
        FT:SetSkinStyle("ORANGE")
    elseif msg == "skin frost" or msg == "skin blue" then
        FT:SetSkinStyle("FROST")
    elseif msg == "skin crimson" or msg == "skin red" then
        FT:SetSkinStyle("CRIMSON")
    elseif msg == "preset minimal" then
        FT:ApplyDisplayPreset("MINIMAL")
    elseif msg == "preset standard" then
        FT:ApplyDisplayPreset("STANDARD")
    elseif msg == "preset tank" then
        FT:ApplyDisplayPreset("TANK")
    elseif msg == "preset dps" then
        FT:ApplyDisplayPreset("DPS")
    elseif msg == "preset healer" or msg == "preset heal" then
        FT:ApplyDisplayPreset("HEALER")
    elseif msg == "profile" or msg == "export" or msg == "import" then
        if FT.OpenConfig then
            FT:OpenConfig("profile")
        end
    elseif msg == "resetall" then
        FT:ResetAllSettings()
    elseif msg == "wowsettings" then
        if FT.OpenBlizzardSettings then
            FT:OpenBlizzardSettings()
        end
    else
        local widthOnly = msg:match("^width%s+(%d+)$")
        local heightOnly = msg:match("^height%s+(%d+)$")
        local sizeW, sizeH = msg:match("^size%s+(%d+)%s+(%d+)$")

        if sizeW and sizeH then
            FT:SetFrameSize(tonumber(sizeW), tonumber(sizeH))
            FT:Print(FT:L("WINDOW_SIZE", FT.db.frameWidth, FT.db.frameHeight))
            return
        elseif widthOnly then
            FT:SetFrameSize(tonumber(widthOnly), FT.db.frameHeight)
            FT:Print(FT:L("WINDOW_WIDTH", FT.db.frameWidth))
            return
        elseif heightOnly then
            FT:SetFrameSize(FT.db.frameWidth, tonumber(heightOnly))
            FT:Print(FT:L("WINDOW_HEIGHT", FT.db.frameHeight))
            return
        end
        FT:Print(FT:L("HELP_TOGGLE"))
        FT:Print(FT:L("HELP_LOCK"))
        FT:Print(FT:L("HELP_RESET"))
        FT:Print(FT:L("HELP_DEBUG"))
        FT:Print(FT:L("HELP_DEBUG_TAUNT"))
        FT:Print(FT:L("HELP_TESTSOUND"))
        FT:Print(FT:L("HELP_TESTMODE"))
        FT:Print(FT:L("HELP_SOURCE"))
        FT:Print(FT:L("HELP_SKIN"))
        FT:Print(FT:L("HELP_SOUND"))
        FT:Print(FT:L("HELP_WARNINGS"))
        FT:Print(FT:L("HELP_AUTO"))
        FT:Print(FT:L("HELP_SIZE"))
        FT:Print(FT:L("HELP_WIDTH"))
        FT:Print(FT:L("HELP_HEIGHT"))
        FT:Print(FT:L("HELP_RESETSIZE"))
        FT:Print(FT:L("HELP_CONFIG"))
        FT:Print(FT:L("HELP_WELCOME"))
        FT:Print(FT:L("HELP_WOWSETTINGS"))
        FT:Print(FT:L("HELP_LANG"))
        FT:Print(FT:L("HELP_MODE"))
        FT:Print(FT:L("HELP_PRESET"))
        FT:Print(FT:L("HELP_RESET_ALL"))
        FT:Print(FT:L("HELP_PROFILE"))
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")

events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        ForeverThreatDB = ForeverThreatDB or {}
        CopyDefaults(FT.defaults, ForeverThreatDB)

        -- v0.4 migration: the meter should stay open after combat.
        if (ForeverThreatDB.dbVersion or 0) < 4 then
            ForeverThreatDB.autoHideOutOfCombat = false
            ForeverThreatDB.frameWidth = ForeverThreatDB.frameWidth or 365
            ForeverThreatDB.frameHeight = ForeverThreatDB.frameHeight or 140
            ForeverThreatDB.dbVersion = 4
        end

        -- v0.5 migration: move the old custom minimap angle into LibDBIcon's DB.
        if (ForeverThreatDB.dbVersion or 0) < 5 then
            ForeverThreatDB.minimap = ForeverThreatDB.minimap or {}
            ForeverThreatDB.minimap.hide = false
            ForeverThreatDB.minimap.minimapPos = ForeverThreatDB.minimapAngle or ForeverThreatDB.minimap.minimapPos or 220
            ForeverThreatDB.dbVersion = 5
        end

        -- v0.6 migration: add display/settings defaults without resetting existing choices.
        if (ForeverThreatDB.dbVersion or 0) < 6 then
            if ForeverThreatDB.windowAlpha == nil then ForeverThreatDB.windowAlpha = 0.97 end
            if ForeverThreatDB.barHeight == nil then ForeverThreatDB.barHeight = 20 end
            if ForeverThreatDB.fontSize == nil then ForeverThreatDB.fontSize = 12 end
            if ForeverThreatDB.useClassColors == nil then ForeverThreatDB.useClassColors = true end
            if ForeverThreatDB.showThreatValue == nil then ForeverThreatDB.showThreatValue = true end
            if ForeverThreatDB.showPercent == nil then ForeverThreatDB.showPercent = true end
            if ForeverThreatDB.showTankMarker == nil then ForeverThreatDB.showTankMarker = true end
            if ForeverThreatDB.maxRows == nil then ForeverThreatDB.maxRows = 15 end
            if ForeverThreatDB.showMinimapButton == nil then ForeverThreatDB.showMinimapButton = true end
            ForeverThreatDB.dbVersion = 6
        end

        -- v0.7 migration: Omen-style threat display options.
        if (ForeverThreatDB.dbVersion or 0) < 7 then
            if ForeverThreatDB.showThreatDelta == nil then ForeverThreatDB.showThreatDelta = true end
            if ForeverThreatDB.highlightPlayer == nil then ForeverThreatDB.highlightPlayer = true end
            if ForeverThreatDB.showPets == nil then ForeverThreatDB.showPets = false end
            ForeverThreatDB.dbVersion = 7
        end

        -- v0.7.1 migration: narrower default window.
        -- Existing users on the old default width (365) are moved to 75% width.
        if (ForeverThreatDB.dbVersion or 0) < 8 then
            if ForeverThreatDB.frameWidth == nil or ForeverThreatDB.frameWidth == 365 then
                ForeverThreatDB.frameWidth = 274
            end
            ForeverThreatDB.dbVersion = 8
        end

        -- v0.8 migration: in-addon configuration center and welcome page.
        if (ForeverThreatDB.dbVersion or 0) < 9 then
            if ForeverThreatDB.welcomeSeen == nil then ForeverThreatDB.welcomeSeen = false end
            if ForeverThreatDB.configLastTab == nil then ForeverThreatDB.configLastTab = "welcome" end
            ForeverThreatDB.dbVersion = 9
        end

        -- v1.0 localization migration: German client -> DE, all other clients -> EN.
        if (ForeverThreatDB.dbVersion or 0) < 10 then
            if ForeverThreatDB.language ~= "DE" and ForeverThreatDB.language ~= "EN" then
                ForeverThreatDB.language = FT.defaultLanguage
            end
            ForeverThreatDB.dbVersion = 10
        end

        -- v1.1 display/role migration.
        if (ForeverThreatDB.dbVersion or 0) < 11 then
            if ForeverThreatDB.threatMode ~= "AUTO"
                and ForeverThreatDB.threatMode ~= "TANK"
                and ForeverThreatDB.threatMode ~= "DPS" then
                ForeverThreatDB.threatMode = "AUTO"
            end
            if ForeverThreatDB.dynamicThreatColors == nil then ForeverThreatDB.dynamicThreatColors = true end
            if ForeverThreatDB.showTargetTarget == nil then ForeverThreatDB.showTargetTarget = true end
            if ForeverThreatDB.highlightAggroChanges == nil then ForeverThreatDB.highlightAggroChanges = true end
            ForeverThreatDB.dbVersion = 11
        end

        -- v1.2 comfort/performance migration. Smart auto-hide remains opt-in
        -- because earlier ForeverThreat releases intentionally stayed open after combat.
        if (ForeverThreatDB.dbVersion or 0) < 12 then
            if ForeverThreatDB.smartAutoHide == nil then ForeverThreatDB.smartAutoHide = false end
            if ForeverThreatDB.combatLock == nil then ForeverThreatDB.combatLock = true end
            if ForeverThreatDB.showGapToAggro == nil then ForeverThreatDB.showGapToAggro = true end
            if type(ForeverThreatDB.updateInterval) ~= "number" then ForeverThreatDB.updateInterval = 0.15 end
            ForeverThreatDB.dbVersion = 12
        end

        -- v1.3 target/preset/auto-show migration.
        if (ForeverThreatDB.dbVersion or 0) < 13 then
            if ForeverThreatDB.autoShowOnlyWithThreat == nil then
                ForeverThreatDB.autoShowOnlyWithThreat = false
            end
            ForeverThreatDB.dbVersion = 13
        end

        -- v1.4 healer/profile/aggro-message migration.
        if (ForeverThreatDB.dbVersion or 0) < 14 then
            if ForeverThreatDB.showAggroChangeMessage == nil then
                ForeverThreatDB.showAggroChangeMessage = true
            end

            local mode = ForeverThreatDB.threatMode
            if mode ~= "AUTO" and mode ~= "TANK" and mode ~= "DPS" and mode ~= "HEALER" then
                ForeverThreatDB.threatMode = "AUTO"
            end

            ForeverThreatDB.dbVersion = 14
        end

        -- v1.5 raid/performance migration.
        if (ForeverThreatDB.dbVersion or 0) < 15 then
            if ForeverThreatDB.adaptiveRaidUpdates == nil then
                ForeverThreatDB.adaptiveRaidUpdates = true
            end
            if ForeverThreatDB.raidTopEnabled == nil then
                ForeverThreatDB.raidTopEnabled = true
            end
            if type(ForeverThreatDB.raidTopRows) ~= "number" then
                ForeverThreatDB.raidTopRows = 10
            end
            ForeverThreatDB.raidTopRows = math.max(1, math.min(40, math.floor(ForeverThreatDB.raidTopRows + 0.5)))
            if ForeverThreatDB.raidAlwaysShowPlayer == nil then
                ForeverThreatDB.raidAlwaysShowPlayer = true
            end
            if ForeverThreatDB.showRaidPets == nil then
                ForeverThreatDB.showRaidPets = false
            end
            ForeverThreatDB.dbVersion = 15
        end

        -- v1.6 final feature migration.
        if (ForeverThreatDB.dbVersion or 0) < 16 then
            if ForeverThreatDB.threatSource ~= "FOCUS" then
                ForeverThreatDB.threatSource = "TARGET"
            end

            if ForeverThreatDB.tankAggroLossWarning == nil then
                ForeverThreatDB.tankAggroLossWarning = true
            end
            if ForeverThreatDB.tankAggroLossSound == nil then
                ForeverThreatDB.tankAggroLossSound = true
            end

            ForeverThreatDB.tankThreatYellow = 70
            ForeverThreatDB.tankThreatOrange = 85
            ForeverThreatDB.tankThreatRed = 95
            ForeverThreatDB.dpsThreatYellow = 70
            ForeverThreatDB.dpsThreatOrange = 85

            -- Preserve a deliberately customized legacy HIGH THREAT threshold.
            local legacyThreshold = tonumber(ForeverThreatDB.highThreatThreshold)
            if legacyThreshold and legacyThreshold ~= 90 then
                ForeverThreatDB.dpsThreatRed = math.max(72, math.min(100, math.floor(legacyThreshold + 0.5)))
            else
                ForeverThreatDB.dpsThreatRed = 95
            end

            ForeverThreatDB.healerThreatYellow = 60
            ForeverThreatDB.healerThreatOrange = 75
            ForeverThreatDB.healerThreatRed = 90
            ForeverThreatDB.dbVersion = 16
        end

        -- v1.6.1 Spanish localization migration.
        if (ForeverThreatDB.dbVersion or 0) < 17 then
            if ForeverThreatDB.language ~= "DE"
                and ForeverThreatDB.language ~= "EN"
                and ForeverThreatDB.language ~= "ES" then
                ForeverThreatDB.language = FT.defaultLanguage
            end
            ForeverThreatDB.dbVersion = 17
        end

        -- v1.6.2 visual skin migration; existing settings are preserved.
        if (ForeverThreatDB.dbVersion or 0) < 18 then
            if not FT:IsValidSkinStyle(ForeverThreatDB.skinStyle) then
                ForeverThreatDB.skinStyle = "ORANGE"
            end
            ForeverThreatDB.dbVersion = 18
        end

        -- v1.6.4 idle-dimming migration.
        if (ForeverThreatDB.dbVersion or 0) < 19 then
            if ForeverThreatDB.idleDimming == nil then
                ForeverThreatDB.idleDimming = false
            end

            local idleAlpha = tonumber(ForeverThreatDB.idleAlpha)
            if not idleAlpha then
                idleAlpha = 0.35
            end
            ForeverThreatDB.idleAlpha = math.max(0.10, math.min(1.00, idleAlpha))
            ForeverThreatDB.dbVersion = 19
        end

        -- v1.6.5 five-language localization migration.
        if (ForeverThreatDB.dbVersion or 0) < 20 then
            local language = ForeverThreatDB.language
            if language ~= "DE" and language ~= "EN" and language ~= "ES"
                and language ~= "FR" and language ~= "KO" then
                ForeverThreatDB.language = FT.defaultLanguage
            end
            ForeverThreatDB.dbVersion = 20
        end

        -- v1.6.6 taunt / tank-swap QoL migration.
        if (ForeverThreatDB.dbVersion or 0) < 21 then
            if ForeverThreatDB.tauntSwapDetection == nil then
                ForeverThreatDB.tauntSwapDetection = true
            end
            if ForeverThreatDB.showTankSwapMessage == nil then
                ForeverThreatDB.showTankSwapMessage = true
            end
            ForeverThreatDB.dbVersion = 21
        end

        -- v1.6.7 threat-reset protection migration.
        if (ForeverThreatDB.dbVersion or 0) < 22 then
            if ForeverThreatDB.threatResetProtection == nil then
                ForeverThreatDB.threatResetProtection = true
            end
            ForeverThreatDB.dbVersion = 22
        end

        -- v1.6.11 appearance customization migration.
        if (ForeverThreatDB.dbVersion or 0) < 23 then
            if ForeverThreatDB.barTexture == nil then ForeverThreatDB.barTexture = "BLIZZARD" end
            if ForeverThreatDB.barStyle == nil then ForeverThreatDB.barStyle = "FLAT" end
            if ForeverThreatDB.windowStyle == nil then ForeverThreatDB.windowStyle = "ADDON" end
            if ForeverThreatDB.showHeader == nil then ForeverThreatDB.showHeader = true end
            ForeverThreatDB.dbVersion = 23
        end

        -- v1.6.12 Threat-per-Second display migration.
        if (ForeverThreatDB.dbVersion or 0) < 24 then
            if ForeverThreatDB.showTPS == nil then ForeverThreatDB.showTPS = false end
            ForeverThreatDB.dbVersion = 24
        end

        -- v1.6.15 secure Click-to-Taunt button migration.
        if (ForeverThreatDB.dbVersion or 0) < 25 then
            if ForeverThreatDB.clickToTauntEnabled == nil then ForeverThreatDB.clickToTauntEnabled = false end
            if ForeverThreatDB.tauntButtonPoint == nil then ForeverThreatDB.tauntButtonPoint = "CENTER" end
            if ForeverThreatDB.tauntButtonX == nil then ForeverThreatDB.tauntButtonX = 0 end
            if ForeverThreatDB.tauntButtonY == nil then ForeverThreatDB.tauntButtonY = -180 end
            ForeverThreatDB.dbVersion = 25
        end

        -- v1.7.0 level-60 endgame migration.
        if (ForeverThreatDB.dbVersion or 0) < 26 then
            if ForeverThreatDB.showThreatETA == nil then ForeverThreatDB.showThreatETA = true end
            if ForeverThreatDB.raidTankViewEnabled == nil then ForeverThreatDB.raidTankViewEnabled = true end
            ForeverThreatDB.dbVersion = 26
        end

        -- v1.7.1 stable raid scan / release polish migration.
        if (ForeverThreatDB.dbVersion or 0) < 27 then
            if ForeverThreatDB.optimizedRaidScan == nil then ForeverThreatDB.optimizedRaidScan = false end
            ForeverThreatDB.dbVersion = 27
        end

        -- v1.7.4 Time-to-Aggro warning migration.
        if (ForeverThreatDB.dbVersion or 0) < 28 then
            if ForeverThreatDB.etaWarningEnabled == nil then ForeverThreatDB.etaWarningEnabled = true end
            ForeverThreatDB.dbVersion = 28
        end

        FT.db = ForeverThreatDB
        if not FT:IsValidSkinStyle(FT.db.skinStyle) then
            FT.db.skinStyle = "ORANGE"
        end
        FT:NormalizeThreatThresholds()
    elseif event == "PLAYER_LOGIN" then
        if not FT.db then
            ForeverThreatDB = ForeverThreatDB or {}
            CopyDefaults(FT.defaults, ForeverThreatDB)
            FT.db = ForeverThreatDB
        end

        FT:CreateUI()
        FT:CreateMinimapButton()

        if FT.InitializeClickToTaunt then
            FT:InitializeClickToTaunt()
        end

        if FT.InitializeSettings then
            FT:InitializeSettings()
        end

        if FT.CreateConfigUI then
            FT:CreateConfigUI()
        end

        if FT.db.visible then
            FT.frame:Show()
        else
            FT.frame:Hide()
        end

        FT:ApplySettings()
        FT:Refresh()
        FT:Print(FT:L("LOADED", FT.version))
    end
end)
