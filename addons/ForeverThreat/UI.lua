local addonName, FT = ...

local DEFAULT_ROW_HEIGHT = 20
local ROW_GAP = 2
local HEADER_HEIGHT = 55
local COMPACT_HEADER_HEIGHT = 34
local WOW_METER_HEADER_HEIGHT = 32
local WOW_METER_ROW_GAP = 4
local MIN_WIDTH = 183
local MIN_HEIGHT = 95
local MAX_WIDTH = 800
local MAX_HEIGHT = 600

-- Common taunt spell IDs used across WoW versions supported by Forever-style
-- clients. Detection intentionally uses UNIT_SPELLCAST_SUCCEEDED instead of
-- COMBAT_LOG_EVENT_UNFILTERED because Forever blocks addons from registering
-- the combat-log event.
local TAUNT_SPELLS = {
    [355] = true,      -- Warrior: Taunt
    [1161] = true,     -- Warrior: Challenging Shout
    [6795] = true,     -- Druid: Growl
    [5209] = true,     -- Druid: Challenging Roar
    [62124] = true,    -- Paladin: Hand of Reckoning
    [56222] = true,    -- Death Knight: Dark Command
    [115546] = true,   -- Monk: Provoke
    [185245] = true,   -- Demon Hunter: Torment
}

local TAUNT_SWAP_WINDOW = 2.5
local THREAT_RESET_CONFIRM_TIME = 0.40

local function HasAtlas(atlas)
    if not atlas or not _G.C_Texture or type(C_Texture.GetAtlasInfo) ~= "function" then
        return false
    end
    local ok, info = pcall(C_Texture.GetAtlasInfo, atlas)
    return ok and info ~= nil
end

local function IsNativeMeterStyle()
    return FT.db and FT.db.windowStyle == "BLIZZARD"
end

local function FormatMeterThreat(value)
    if type(value) ~= "number" then
        return "-"
    end

    local rounded = math.floor(math.max(0, value) + 0.5)
    if type(_G.BreakUpLargeNumbers) == "function" then
        local ok, text = pcall(BreakUpLargeNumbers, rounded)
        if ok and text then
            return tostring(text)
        end
    end

    return FormatThreat(value)
end

local function SafeUnitGUID(unit)
    if type(_G.UnitGUID) ~= "function" then
        return nil
    end

    local ok, guid = pcall(UnitGUID, unit)
    if not ok or FT:IsSecret(guid) or guid == nil then
        return nil
    end

    return guid
end

local function GetClassColor(classToken)
    local color = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
    if color then
        return color.r, color.g, color.b
    end

    return 0.65, 0.65, 0.65
end

local function ApplyFontSize(fontString, size)
    if not fontString or not fontString.GetFont then
        return
    end

    local font, _, flags = fontString:GetFont()
    if font then
        fontString:SetFont(font, size or 12, flags)
    end
end

local function FormatThreat(value)
    if value == nil then
        return "-"
    end

    local absValue = math.abs(value)

    if absValue >= 1000000 then
        return string.format("%.1fm", value / 1000000)
    elseif absValue >= 1000 then
        return string.format("%.1fk", value / 1000)
    end

    return tostring(math.floor(value + 0.5))
end

local function FormatDelta(value)
    if value == nil then
        return "-"
    end

    if math.abs(value) < 0.5 then
        return "0"
    end

    local absValue = math.abs(value)

    if absValue >= 1000000 then
        return string.format("%+.1fm", value / 1000000)
    elseif absValue >= 1000 then
        return string.format("%+.1fk", value / 1000)
    end

    local rounded
    if value >= 0 then
        rounded = math.floor(value + 0.5)
    else
        rounded = math.ceil(value - 0.5)
    end

    return string.format("%+d", rounded)
end

local function FormatThreatGap(value)
    if value == nil then
        return "-"
    end

    if math.abs(value) < 0.5 then
        return "0"
    end

    local compact = FormatThreat(math.max(0, value))
    return FT:L("GAP_SHORT_FORMAT", compact)
end

local function FormatTPS(value)
    if type(value) ~= "number" then
        return "-"
    end

    value = math.max(0, value)

    if value >= 1000000 then
        return string.format("%.1fm/s", value / 1000000)
    elseif value >= 1000 then
        return string.format("%.1fk/s", value / 1000)
    end

    return string.format("%d/s", math.floor(value + 0.5))
end

local function FormatThreatETA(value, isLead)
    if type(value) ~= "number" or value < 0 or value == math.huge then
        return "--"
    end

    local text
    if value > 99.9 then
        text = ">99s"
    elseif value < 10 then
        text = string.format("%.1fs", value)
    else
        text = string.format("%.0fs", value)
    end

    if isLead then
        return "L " .. text
    end

    return text
end

local TPS_SMOOTHING_SECONDS = 1.5
local TPS_MAX_SAMPLE_GAP = 3.0

function FT:ResetTPS()
    self.tpsSamples = {}
    self.tpsSourceKey = nil
    self.tpsTauntIgnoreGUID = nil
    self.tpsTauntIgnoreUntil = nil
end

local function GetSafeUnitName(unit)
    if type(_G.UnitName) ~= "function" then
        return nil
    end

    local ok, name = pcall(UnitName, unit)
    if not ok or FT:IsSecret(name) or not name or name == "" then
        return nil
    end

    return name
end

function FT:GetTPSUnitKey(entry)
    if not entry then
        return nil, nil
    end

    local guid = entry.unit and SafeUnitGUID(entry.unit) or nil
    if guid then
        return guid, guid
    end

    if entry.unit then
        return "unit:" .. tostring(entry.unit), nil
    end

    if entry.name then
        return "name:" .. tostring(entry.name), nil
    end

    return nil, nil
end

function FT:GetTPSSourceKey(sourceUnit)
    local guid = SafeUnitGUID(sourceUnit)
    if guid then
        return guid
    end

    local name = GetSafeUnitName(sourceUnit)
    if name then
        return tostring(sourceUnit) .. ":" .. name
    end

    return tostring(sourceUnit or "target")
end

function FT:UpdateTPS(data, sourceUnit)
    if not self.db or not self.db.showTPS then
        if self.tpsSamples then
            self:ResetTPS()
        end
        for _, entry in ipairs(data or {}) do
            entry.tps = nil
            entry.scaledRate = nil
            entry.threatEta = nil
            entry.etaIsLead = nil
        end
        return
    end

    if not self:IsPlayerInCombat() then
        self:ResetTPS()
        for _, entry in ipairs(data or {}) do
            entry.tps = nil
            entry.scaledRate = nil
            entry.threatEta = nil
            entry.etaIsLead = nil
        end
        return
    end

    local sourceKey = self:GetTPSSourceKey(sourceUnit)
    if self.tpsSourceKey ~= sourceKey then
        self:ResetTPS()
        self.tpsSourceKey = sourceKey
    end

    self.tpsSamples = self.tpsSamples or {}
    local now = GetTime()
    local seen = {}

    for _, entry in ipairs(data or {}) do
        entry.tps = nil

        if type(entry.rawThreat) == "number" then
            local key, guid = self:GetTPSUnitKey(entry)
            if key then
                seen[key] = true
                local sample = self.tpsSamples[key]

                if not sample then
                    sample = {
                        threat = entry.rawThreat,
                        scaled = entry.scaled,
                        time = now,
                        tps = nil,
                        scaledRate = nil,
                    }
                    self.tpsSamples[key] = sample
                else
                    local dt = now - (sample.time or now)

                    if dt >= 0.05 then
                        local delta = entry.rawThreat - (sample.threat or entry.rawThreat)
                        local ignoreTauntJump = guid
                            and self.tpsTauntIgnoreGUID == guid
                            and (self.tpsTauntIgnoreUntil or 0) >= now

                        if dt > TPS_MAX_SAMPLE_GAP then
                            sample.tps = nil
                            sample.scaledRate = nil
                        elseif delta < 0 then
                            -- Threat reductions, wipes and API rebases are not
                            -- negative TPS. Start a fresh baseline instead.
                            sample.tps = 0
                            sample.scaledRate = nil
                        elseif ignoreTauntJump then
                            -- A taunt can jump raw threat to the current tank.
                            -- Do not treat that artificial jump as generated TPS.
                        else
                            local instant = delta / dt
                            local alpha = 1 - math.exp(-dt / TPS_SMOOTHING_SECONDS)

                            if sample.tps == nil then
                                sample.tps = instant
                            else
                                sample.tps = sample.tps + ((instant - sample.tps) * alpha)
                            end

                            if type(entry.scaled) == "number" and type(sample.scaled) == "number" then
                                local scaledInstant = (entry.scaled - sample.scaled) / dt
                                if sample.scaledRate == nil then
                                    sample.scaledRate = scaledInstant
                                else
                                    sample.scaledRate = sample.scaledRate + ((scaledInstant - sample.scaledRate) * alpha)
                                end
                            end
                        end

                        sample.threat = entry.rawThreat
                        sample.scaled = entry.scaled
                        sample.time = now
                    end
                end

                entry.tps = sample.tps
                entry.scaledRate = sample.scaledRate
            end
        end
    end

    for key in pairs(self.tpsSamples) do
        if not seen[key] then
            self.tpsSamples[key] = nil
        end
    end

    if self.tpsTauntIgnoreUntil and self.tpsTauntIgnoreUntil < now then
        self.tpsTauntIgnoreGUID = nil
        self.tpsTauntIgnoreUntil = nil
    end
end

function FT:UpdateThreatETA(data, tankEntry)
    for _, entry in ipairs(data or {}) do
        entry.threatEta = nil
        entry.etaIsLead = false
    end

    if not self.db
        or (self.db.showThreatETA == false
            and self.db.etaWarningEnabled ~= true
            and self.db.tankLeadWarning ~= true)
        or not tankEntry then
        return
    end

    local bestLead

    for _, entry in ipairs(data or {}) do
        if entry ~= tankEntry
            and type(entry.scaled) == "number"
            and type(entry.scaledRate) == "number" then

            local remaining = 100 - entry.scaled
            if remaining <= 0 then
                entry.threatEta = 0
            elseif entry.scaledRate > 0.05 then
                entry.threatEta = remaining / entry.scaledRate
            end

            if entry.threatEta ~= nil
                and entry.threatEta >= 0
                and (bestLead == nil or entry.threatEta < bestLead) then
                bestLead = entry.threatEta
            end
        end
    end

    tankEntry.threatEta = bestLead
    tankEntry.etaIsLead = true
end

local ETA_WARNING_MIN_DROP = 0.05

local function GetETAWarningThreshold()
    local value = FT.db and tonumber(FT.db.etaWarningThreshold) or 5
    return math.max(1, math.min(15, value or 5))
end

function FT:ResetETAWarningState()
    self.lastPlayerThreatEta = nil
    self.etaWarningWarned = false
end

function FT:CheckPlayerETAWarning(data, effectiveMode)
    if not self.db or self.db.etaWarningEnabled ~= true or self.db.warningEnabled ~= true then
        self:ResetETAWarningState()
        return
    end

    if effectiveMode == "TANK" or not self:IsPlayerInCombat() then
        self:ResetETAWarningState()
        return
    end

    local playerEntry
    for _, entry in ipairs(data or {}) do
        if self:IsPlayerThreatEntry(entry) then
            playerEntry = entry
            break
        end
    end

    if not playerEntry
        or playerEntry.isAggroHolder
        or playerEntry.targetTarget
        or type(playerEntry.threatEta) ~= "number"
        or playerEntry.threatEta < 0 then
        self:ResetETAWarningState()
        return
    end

    local eta = playerEntry.threatEta
    local previous = self.lastPlayerThreatEta
    local warningThreshold = GetETAWarningThreshold()
    local rearmThreshold = warningThreshold + 2.0

    if eta > rearmThreshold then
        self.etaWarningWarned = false
    end

    local isClosing = previous ~= nil and eta < (previous - ETA_WARNING_MIN_DROP)

    if not self.etaWarningWarned
        and eta <= warningThreshold
        and isClosing then
        self:ShowLocalizedCombatWarning(
            "AGGRO_IN_TIME",
            { string.format("%.1f", eta) },
            "",
            1.0, 0.32, 0.08,
            1.5,
            "ETA"
        )
        self.etaWarningWarned = true
    end

    self.lastPlayerThreatEta = eta
end

local TANK_LEAD_WARNING_MIN_DROP = 0.05

local function GetTankLeadWarningThreshold()
    local value = FT.db and tonumber(FT.db.tankLeadWarningThreshold) or 5
    return math.max(1, math.min(15, value or 5))
end

function FT:ResetTankLeadWarningState()
    self.lastPlayerTankLeadEta = nil
    self.tankLeadWarned = false
end

function FT:CheckPlayerTankLeadWarning(data, effectiveMode)
    if not self.db or self.db.tankLeadWarning ~= true or self.db.warningEnabled ~= true then
        self:ResetTankLeadWarningState()
        return
    end

    if effectiveMode ~= "TANK" or not self:IsPlayerInCombat() then
        self:ResetTankLeadWarningState()
        return
    end

    local playerEntry
    for _, entry in ipairs(data or {}) do
        if self:IsPlayerThreatEntry(entry) then
            playerEntry = entry
            break
        end
    end

    if not playerEntry
        or playerEntry.etaIsLead ~= true
        or type(playerEntry.threatEta) ~= "number"
        or playerEntry.threatEta < 0 then
        self:ResetTankLeadWarningState()
        return
    end

    local lead = playerEntry.threatEta
    local previous = self.lastPlayerTankLeadEta
    local warningThreshold = GetTankLeadWarningThreshold()
    local rearmThreshold = warningThreshold + 2.0

    if lead > rearmThreshold then
        self.tankLeadWarned = false
    end

    local isClosing = previous ~= nil and lead < (previous - TANK_LEAD_WARNING_MIN_DROP)

    if not self.tankLeadWarned
        and lead <= warningThreshold
        and isClosing then
        self:ShowLocalizedCombatWarning(
            "TANK_LEAD_LOW",
            { string.format("%.1f", lead) },
            "",
            1.0, 0.55, 0.08,
            1.6,
            "TANK_LEAD"
        )
        self.tankLeadWarned = true
    end

    self.lastPlayerTankLeadEta = lead
end

local BAR_TEXTURES = {
    BLIZZARD = "Interface\\TargetingFrame\\UI-StatusBar",
    SOLID = "Interface\\Buttons\\WHITE8X8",
}

function FT:GetThreatHeaderHeight()
    if IsNativeMeterStyle() then
        return WOW_METER_HEADER_HEIGHT
    end

    if self.db and self.db.showHeader == false then
        return COMPACT_HEADER_HEIGHT
    end
    return HEADER_HEIGHT
end

function FT:GetThreatRowGap()
    return IsNativeMeterStyle() and WOW_METER_ROW_GAP or ROW_GAP
end

function FT:ApplyThreatWindowBackdrop()
    if not self.frame then
        return
    end

    local style = self.db and self.db.windowStyle or "BLIZZARD"

    if style == "BLIZZARD" then
        self.frame:SetBackdrop(nil)

        if self.frame.nativeBackground then
            self.frame.nativeBackground:Show()
            if HasAtlas("damagemeters-background") then
                self.frame.nativeBackground:SetAtlas("damagemeters-background")
            else
                self.frame.nativeBackground:SetColorTexture(0, 0, 0, 0.92)
            end
            self.frame.nativeBackground:SetAlpha(0.55)
        end

        if self.frame.nativeHeader then
            self.frame.nativeHeader:Show()
            if HasAtlas("ui-damagemeters-header-bar") then
                self.frame.nativeHeader:SetAtlas("ui-damagemeters-header-bar")
            else
                self.frame.nativeHeader:SetColorTexture(0.12, 0.10, 0.05, 0.98)
            end
        end
        return
    end

    if self.frame.nativeBackground then self.frame.nativeBackground:Hide() end
    if self.frame.nativeHeader then self.frame.nativeHeader:Hide() end

    local backdrop
    if style == "MINIMAL" then
        backdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        }
    else
        backdrop = {
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        }
    end

    self.frame:SetBackdrop(backdrop)
end

function FT:ApplyBarTexture(row)
    if not row then
        return
    end

    local bar = row.bar or row
    if IsNativeMeterStyle() and HasAtlas("UI-HUD-CoolDownManager-Bar") then
        bar:SetStatusBarTexture("UI-HUD-CoolDownManager-Bar")
        return
    end

    local style = self.db and self.db.barTexture or "BLIZZARD"
    bar:SetStatusBarTexture(BAR_TEXTURES[style] or BAR_TEXTURES.BLIZZARD)
end

function FT:ApplyBarColor(row, r, g, b)
    if not row then
        return
    end

    self:ApplyBarTexture(row)

    local bar = row.bar or row
    local texture = bar:GetStatusBarTexture()
    local style = self.db and self.db.barStyle or "FLAT"

    if texture and type(texture.SetGradientAlpha) == "function" then
        row:SetStatusBarColor(1, 1, 1, 1)

        if style == "GRADIENT" then
            -- Darker at the left, full colour at the right. The gradient is
            -- applied to the StatusBar texture itself, so it remains clipped
            -- to the current threat value.
            local ok = pcall(
                texture.SetGradientAlpha,
                texture,
                "HORIZONTAL",
                math.max(0, r * 0.42), math.max(0, g * 0.42), math.max(0, b * 0.42), 0.90,
                r, g, b, 0.95
            )
            if ok then
                return
            end
        else
            local ok = pcall(
                texture.SetGradientAlpha,
                texture,
                "HORIZONTAL",
                r, g, b, 0.82,
                r, g, b, 0.82
            )
            if ok then
                return
            end
        end
    end

    -- Safe fallback for Forever clients without Texture:SetGradientAlpha.
    bar:SetStatusBarColor(r, g, b, IsNativeMeterStyle() and 1.0 or 0.82)
end

-- Apply only frame/window chrome and neutral row backgrounds.
-- The bars and alert colors must remain readable regardless of the theme.
function FT:ApplySkin()
    local skin = self:GetSkinPalette()

    if self.frame then
        self:ApplyThreatWindowBackdrop()

        local bg = skin.background
        local windowStyle = self.db and self.db.windowStyle or "BLIZZARD"
        if windowStyle ~= "BLIZZARD" then
            if windowStyle == "MINIMAL" then
                self.frame:SetBackdropColor(bg[1], bg[2], bg[3], 0.92)
            else
                self.frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
            end

            local border = skin.border
            if windowStyle == "MINIMAL" then
                self.frame:SetBackdropBorderColor(border[1], border[2], border[3], 0.35)
            else
                self.frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
            end
        end
        if self.frame.skinTitle then
            self.frame.skinTitle:SetTextColor(skin.title[1], skin.title[2], skin.title[3])
        end
    end

    if self.rows then
        for _, row in ipairs(self.rows) do
            if row.bg then
                if IsNativeMeterStyle() and HasAtlas("ui-damagemeters-bar-shadowbg") then
                    row.bg:SetAtlas("ui-damagemeters-bar-shadowbg")
                    row.bg:Show()
                    if row.nativeEdge and HasAtlas("ui-damagemeters-bar-shadowedge") then
                        row.nativeEdge:SetAtlas("ui-damagemeters-bar-shadowedge")
                        row.nativeEdge:Show()
                    end
                else
                    local c = skin.rowBackground
                    row.bg:SetColorTexture(c[1], c[2], c[3], c[4])
                    if row.nativeEdge then row.nativeEdge:Hide() end
                end
            end
            if row.playerHighlight then
                local c = skin.playerHighlight
                row.playerHighlight:SetColorTexture(c[1], c[2], c[3], c[4])
            end
        end
    end

    if self.ApplyConfigSkin then
        self:ApplyConfigSkin(skin)
    end

    if self.ApplySupportSkin then
        self:ApplySupportSkin()
    end
end

function FT:CreateRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(self.db.barHeight or DEFAULT_ROW_HEIGHT)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(24, 16)
    row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.icon:Hide()

    row.tankMarker = CreateFrame("Frame", nil, row)
    row.tankMarker:SetSize(12, 12)
    row.tankMarker:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", 2, -2)
    row.tankMarker:SetFrameLevel(row:GetFrameLevel() + 4)
    row.tankMarker:Hide()
    row.tankMarkerTexture = row.tankMarker:CreateTexture(nil, "OVERLAY")
    row.tankMarkerTexture:SetAllPoints()
    row.tankMarkerTexture:SetTexture("Interface\\GroupFrame\\UI-Group-MainTankIcon")

    -- Small optional visual gimmick: the current aggro holder wears the
    -- standard WoW group-leader crown above the class icon.
    row.aggroCrown = CreateFrame("Frame", nil, row)
    row.aggroCrown:SetSize(13, 13)
    row.aggroCrown:SetPoint("TOPRIGHT", row.icon, "TOPRIGHT", 2, 4)
    row.aggroCrown:SetFrameLevel(row:GetFrameLevel() + 5)
    row.aggroCrown:Hide()
    row.aggroCrownTexture = row.aggroCrown:CreateTexture(nil, "OVERLAY")
    row.aggroCrownTexture:SetAllPoints()
    row.aggroCrownTexture:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")

    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetAllPoints(row)
    row.bar:SetMinMaxValues(0, 100)
    row.bar:SetValue(0)
    self:ApplyBarTexture(row)

    row.bg = row.bar:CreateTexture(nil, "BACKGROUND")
    row.bg:SetPoint("TOPLEFT", row.bar, "TOPLEFT", -2, 2)
    row.bg:SetPoint("BOTTOMRIGHT", row.bar, "BOTTOMRIGHT", 2, -2)
    row.bg:SetColorTexture(0.045, 0.045, 0.045, 0.95)

    row.nativeEdge = row.bar:CreateTexture(nil, "OVERLAY", nil, 1)
    row.nativeEdge:SetPoint("TOPLEFT", row.bar, "TOPLEFT", -2, 2)
    row.nativeEdge:SetPoint("BOTTOMRIGHT", row.bar, "BOTTOMRIGHT", 2, -2)
    row.nativeEdge:Hide()

    row.playerHighlight = row.bar:CreateTexture(nil, "ARTWORK")
    row.playerHighlight:SetAllPoints()
    row.playerHighlight:SetColorTexture(1.0, 0.82, 0.0, 0.12)
    row.playerHighlight:Hide()

    row.raidFocusHighlight = row.bar:CreateTexture(nil, "ARTWORK", nil, 1)
    row.raidFocusHighlight:SetAllPoints()
    row.raidFocusHighlight:SetColorTexture(1.0, 0.55, 0.08, 0.14)
    row.raidFocusHighlight:Hide()

    row.threatRaceHighlight = row.bar:CreateTexture(nil, "OVERLAY", nil, 1)
    row.threatRaceHighlight:SetAllPoints()
    row.threatRaceHighlight:Hide()

    row.aggroFlash = row.bar:CreateTexture(nil, "OVERLAY", nil, 2)
    row.aggroFlash:SetAllPoints()
    row.aggroFlash:SetColorTexture(1.0, 0.18, 0.04, 0.36)
    row.aggroFlash:Hide()

    local textFrame = CreateFrame("Frame", nil, row.bar)
    textFrame:SetAllPoints()
    textFrame:SetFrameLevel(row.bar:GetFrameLevel() + 3)
    row.textFrame = textFrame

    row.rank = textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.rank:SetWidth(18)
    row.rank:SetJustifyH("RIGHT")

    row.name = textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.threat = textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.threat:SetWidth(48)
    row.threat:SetJustifyH("RIGHT")

    row.tps = textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.tps:SetWidth(56)
    row.tps:SetJustifyH("RIGHT")

    row.eta = textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.eta:SetWidth(62)
    row.eta:SetJustifyH("RIGHT")

    row.delta = textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.delta:SetWidth(64)
    row.delta:SetJustifyH("RIGHT")

    row.percent = textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.percent:SetWidth(38)
    row.percent:SetJustifyH("RIGHT")

    local headerHeight = self:GetThreatHeaderHeight()
    if index == 1 then
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -headerHeight)
        row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -headerHeight)
    else
        local gap = self:GetThreatRowGap()
        row:SetPoint("TOPLEFT", self.rows[index - 1], "BOTTOMLEFT", 0, -gap)
        row:SetPoint("TOPRIGHT", self.rows[index - 1], "BOTTOMRIGHT", 0, -gap)
    end

    return row
end

local function ApplyNativeRowIcon(row, entry)
    if not row or not row.icon or not entry then
        return
    end

    local atlas = entry.classToken and ("classicon-" .. string.lower(entry.classToken))
    if atlas and HasAtlas(atlas) then
        row.icon:SetAtlas(atlas)
        row.icon:SetTexCoord(0, 1, 0, 1)
    elseif entry.isPet then
        row.icon:SetTexture("Interface\\Icons\\Ability_Hunter_BeastCall")
        row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    else
        row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end
end

function FT:GetEffectiveUpdateInterval()
    local interval = tonumber(self.db and self.db.updateInterval) or 0.15
    interval = math.max(0.05, math.min(0.50, interval))

    if self.db and self.db.adaptiveRaidUpdates and IsInRaid() then
        local count = GetNumGroupMembers()

        if count >= 40 then
            interval = math.max(interval, 0.35)
        elseif count >= 30 then
            interval = math.max(interval, 0.30)
        elseif count >= 20 then
            interval = math.max(interval, 0.25)
        elseif count >= 10 then
            interval = math.max(interval, 0.20)
        end
    end

    return interval
end

function FT:CreateUI()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "ForeverThreatFrame", UIParent, "BackdropTemplate")
    self.frame = frame

    frame:SetSize(self.db.frameWidth or 274, self.db.frameHeight or 140)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetScale(self.db.scale or 1)
    frame:SetResizable(not self:IsWindowInteractionLocked())

    if frame.SetResizeBounds then
        frame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT)
    else
        if frame.SetMinResize then
            frame:SetMinResize(MIN_WIDTH, MIN_HEIGHT)
        end
        if frame.SetMaxResize then
            frame:SetMaxResize(MAX_WIDTH, MAX_HEIGHT)
        end
    end

    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.025, 0.025, 0.025, 0.97)
    frame:SetBackdropBorderColor(0.55, 0.32, 0.12, 1)
    frame:SetAlpha(self.db.windowAlpha or 0.97)

    frame.nativeBackground = frame:CreateTexture(nil, "BACKGROUND")
    frame.nativeBackground:SetAllPoints()
    frame.nativeBackground:Hide()

    frame.nativeHeader = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    frame.nativeHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.nativeHeader:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    frame.nativeHeader:SetHeight(WOW_METER_HEADER_HEIGHT)
    frame.nativeHeader:Hide()

    frame:ClearAllPoints()
    frame:SetPoint(
        self.db.point or "CENTER",
        UIParent,
        self.db.point or "CENTER",
        self.db.x or 0,
        self.db.y or 0
    )

    frame:SetMovable(not self:IsWindowInteractionLocked())
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    frame:SetScript("OnEnter", function()
        FT.frameMouseOver = true
        FT:UpdateWindowAlpha()
    end)

    frame:SetScript("OnLeave", function()
        FT.frameMouseOver = false
        FT:UpdateWindowAlpha()
    end)

    frame:SetScript("OnDragStart", function(f)
        if not FT:IsWindowInteractionLocked() then
            f:StartMoving()
        end
    end)

    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()

        local point, _, _, x, y = f:GetPoint(1)
        FT.db.point = point or "CENTER"
        FT.db.x = x or 0
        FT.db.y = y or 0
    end)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalMed1")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -8)
    title:SetText("FOREVERTHREAT")
    title:SetTextColor(1.0, 0.55, 0.16)
    frame.skinTitle = title

    frame.target = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.target:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    frame.target:SetPoint("RIGHT", frame, "RIGHT", -62, 0)
    frame.target:SetJustifyH("LEFT")
    frame.target:SetText(FT:L("TARGET_FORMAT", FT:L("NO_TARGET")))

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    self.closeButton = close
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    close:SetScript("OnClick", function()
        FT.db.visible = false
        frame:Hide()
    end)

    local configButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    self.configButton = configButton
    configButton:SetSize(26, 20)
    configButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -30, -6)
    configButton:SetText("...")
    configButton:SetScript("OnClick", function()
        if FT.OpenConfig then
            FT:OpenConfig("display")
        end
    end)
    configButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:AddLine(FT:L("CONFIG_TOOLTIP_TITLE"), 1.0, 0.55, 0.16)
        GameTooltip:AddLine(FT:L("CONFIG_TOOLTIP_BODY"), 1, 1, 1)
        GameTooltip:Show()
    end)
    configButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local nativeMinimize = CreateFrame("Button", nil, frame)
    self.nativeMinimizeButton = nativeMinimize
    nativeMinimize:SetSize(18, 19)
    nativeMinimize:ClearAllPoints()
    nativeMinimize:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -57, -6)
    if HasAtlas("ui-questtrackerbutton-red-highlight") and nativeMinimize.SetHighlightAtlas then
        nativeMinimize:SetHighlightAtlas("ui-questtrackerbutton-red-highlight", "ADD")
    else
        local minus = nativeMinimize:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        minus:SetPoint("CENTER", 0, 1)
        minus:SetText("-")
        minus:SetTextColor(1.0, 0.35, 0.15)
        nativeMinimize.fallbackText = minus
    end
    nativeMinimize:SetScript("OnClick", function()
        FT.db.visible = false
        frame:Hide()
    end)
    nativeMinimize:Hide()

    local nativeSettings = CreateFrame("Button", nil, frame)
    self.nativeSettingsButton = nativeSettings
    nativeSettings:SetSize(27, 27)
    nativeSettings:ClearAllPoints()
    nativeSettings:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3)
    if HasAtlas("common-dropdown-a-button-settings-shadowless") and nativeSettings.SetNormalAtlas then
        nativeSettings:SetNormalAtlas("common-dropdown-a-button-settings-shadowless")
        if HasAtlas("common-dropdown-a-button-settings-pressed-shadowless") then
            nativeSettings:SetPushedAtlas("common-dropdown-a-button-settings-pressed-shadowless")
        end
        if HasAtlas("common-dropdown-a-button-settings-hover-shadowless") then
            nativeSettings:SetHighlightAtlas("common-dropdown-a-button-settings-hover-shadowless")
        end
    else
        nativeSettings:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    end
    nativeSettings:SetScript("OnClick", function()
        if FT.OpenConfig then FT:OpenConfig("display") end
    end)
    nativeSettings:Hide()

    local sourceButton = CreateFrame("Button", nil, frame, "BackdropTemplate")
    self.nativeSourceButton = sourceButton
    sourceButton:SetSize(20, 20)
    sourceButton:ClearAllPoints()
    sourceButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -34, -6)
    sourceButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    sourceButton:SetBackdropColor(0.04, 0.04, 0.04, 0.85)
    sourceButton:SetBackdropBorderColor(0.42, 0.34, 0.15, 1)
    sourceButton.text = sourceButton:CreateFontString(nil, "OVERLAY", "GameFontNormalMed1")
    sourceButton.text:SetAllPoints()
    sourceButton.text:SetJustifyH("CENTER")
    sourceButton:SetScript("OnClick", function()
        local nextSource = FT.db.threatSource == "FOCUS" and "TARGET" or "FOCUS"
        FT:SetThreatSource(nextSource)
    end)
    sourceButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(FT:L("THREAT_SOURCE_TITLE"), 1.0, 0.82, 0.25)
        GameTooltip:AddLine(FT:L("SOURCE_TARGET") .. " / " .. FT:L("SOURCE_FOCUS"), 1, 1, 1)
        GameTooltip:Show()
    end)
    sourceButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    sourceButton:Hide()

    local titleButton = CreateFrame("Button", nil, frame)
    self.nativeTitleButton = titleButton
    titleButton:SetSize(20, 22)
    titleButton:ClearAllPoints()
    titleButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -4)
    titleButton.text = titleButton:CreateFontString(nil, "OVERLAY", "GameFontNormalMed1")
    titleButton.text:SetAllPoints()
    titleButton.text:SetText("v")
    titleButton.text:SetTextColor(1.0, 0.82, 0.0)
    titleButton:SetScript("OnClick", function()
        if FT.OpenConfig then FT:OpenConfig("display") end
    end)
    titleButton:Hide()

    local resizeGrip = CreateFrame("Button", nil, frame)
    self.resizeGrip = resizeGrip
    resizeGrip:SetSize(18, 18)
    resizeGrip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
    resizeGrip:SetFrameLevel(frame:GetFrameLevel() + 10)
    resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

    resizeGrip:SetScript("OnMouseDown", function()
        if not FT:IsWindowInteractionLocked() then
            frame:StartSizing("BOTTOMRIGHT")
        end
    end)

    resizeGrip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        FT:SaveFrameSize()
        FT:Refresh()
    end)

    resizeGrip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:AddLine(FT:L("RESIZE_TOOLTIP_TITLE"), 1, 0.55, 0.16)
        GameTooltip:AddLine(FT:L("RESIZE_TOOLTIP_BODY"), 1, 1, 1)
        GameTooltip:Show()
    end)

    resizeGrip:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    if self:IsWindowInteractionLocked() then
        resizeGrip:Hide()
    end

    frame:SetScript("OnSizeChanged", function(_, width, height)
        if FT.db then
            FT.db.frameWidth = math.floor((width or 274) + 0.5)
            FT.db.frameHeight = math.floor((height or 140) + 0.5)
        end

        if FT.RefreshLayout then
            FT:RefreshLayout()
        else
            FT:Refresh()
        end
    end)

    local warningFrame = CreateFrame("Frame", "ForeverThreatWarningFrame", UIParent)
    warningFrame:SetSize(520, 100)
    warningFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    warningFrame:SetFrameStrata("HIGH")
    warningFrame:Hide()

    warningFrame.text = warningFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    warningFrame.text:SetPoint("CENTER")
    warningFrame.text:SetText("")
    warningFrame.text:SetShadowOffset(2, -2)
    warningFrame.text:SetShadowColor(0, 0, 0, 1)

    self.warningFrame = warningFrame
    self.warningDuration = 0

    self:ResetSessionStatistics()
    self.lastAggroState = false
    self.highThreatWarned = false
    self.lastTargetingPlayer = false
    self.hasSeenNonPlayerTank = false
    self.lastAggroHolderName = nil
    self.lastAggroHolderWasPlayer = nil
    self.lastEffectiveThreatMode = nil
    self.aggroFlashName = nil
    self.aggroFlashUntil = 0
    self.combatStartedAt = 0
    self.combatEndedAt = 0

    warningFrame:SetScript("OnUpdate", function(self, elapsed)
        FT.warningDuration = (FT.warningDuration or 0) - elapsed

        if FT.warningDuration <= 0 then
            self:Hide()
            self.text:SetText("")
            FT.warningDuration = 0
            FT.currentWarningKey = nil
            FT.currentWarningArgs = nil
            FT.currentWarningSuffix = nil
        end
    end)

    local funFrame = CreateFrame("Frame", "ForeverThreatFunFrame", UIParent)
    funFrame:SetSize(440, 52)
    funFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 62)
    funFrame:SetFrameStrata("HIGH")
    funFrame:Hide()

    funFrame.text = funFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    funFrame.text:SetPoint("CENTER")
    funFrame.text:SetText("")
    funFrame.text:SetTextColor(1.0, 0.72, 0.20)
    funFrame.text:SetShadowOffset(2, -2)
    funFrame.text:SetShadowColor(0, 0, 0, 1)

    self.funFrame = funFrame
    self.funDuration = 0
    self.funDangerActive = false
    self.funDangerLevel = nil
    self.currentFunKey = nil

    funFrame:SetScript("OnUpdate", function(self, elapsed)
        FT.funDuration = (FT.funDuration or 0) - elapsed

        if FT.funDuration <= 0 then
            self:Hide()
            self.text:SetText("")
            FT.funDuration = 0
            FT.currentFunKey = nil
        end
    end)

    self.rows = {}
    for i = 1, 40 do
        self.rows[i] = self:CreateRow(frame, i)
        self.rows[i]:Hide()
    end

    frame.elapsed = 0
    self.threatDirty = true

    frame:SetScript("OnUpdate", function(_, elapsed)
        frame.elapsed = frame.elapsed + elapsed

        local interval = FT:GetEffectiveUpdateInterval()

        if frame.elapsed >= interval then
            frame.elapsed = 0

            -- UNIT_THREAT_* can fire many times in a short burst. Those events
            -- now only mark the data dirty; the expensive group scan is
            -- coalesced here into at most one refresh per effective interval.
            local needsRefresh = FT.testMode
                or FT.threatDirty
                or FT:IsPlayerInCombat()
                or (FT.db.smartAutoHide and frame:IsShown())

            if needsRefresh then
                FT.threatDirty = false
                FT:Refresh()
            elseif FT.db.idleDimming and frame:IsShown() then
                -- Mouseover/full-opacity updates are cheap and do not require
                -- another threat scan while the meter is idle.
                FT:UpdateWindowAlpha()
            end
        end
    end)

    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    frame:RegisterEvent("UNIT_TARGET")
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("UNIT_PET")
    frame:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
    frame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
    frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")

    frame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            FT:HandleUnitSpellcastTaunt(arg1, arg2, arg3)
            return

        elseif event == "UNIT_THREAT_LIST_UPDATE" or event == "UNIT_THREAT_SITUATION_UPDATE" then
            FT.threatDirty = true
            return

        elseif event == "GROUP_ROSTER_UPDATE" or event == "UNIT_PET" then
            if FT.InvalidateGroupUnitCache then
                FT:InvalidateGroupUnitCache()
            end
            FT.threatDirty = true

        elseif event == "PLAYER_REGEN_DISABLED" then
            FT.cleanTankingStartedAt = nil
            FT.cleanTankingCurrent = 0

            if FT.testMode then
                FT.testMode = false
            end

            FT.combatStartedAt = GetTime()
            FT.lastAggroState = false
            FT.lastTargetingPlayer = false
            FT.hasSeenNonPlayerTank = false
            FT.highThreatWarned = false
            FT.funDangerActive = false
            FT.funDangerLevel = nil
            FT.lastAggroHolderName = nil
            FT.lastAggroHolderWasPlayer = nil
            FT.lastEffectiveThreatMode = nil
            FT.lastTauntSwap = nil
            FT:ResetTPS()
            FT.threatResetPendingAt = nil
            FT.hadActiveThreatForSource = false
            FT.lastThreatResetSourceGUID = nil
            FT.aggroFlashName = nil
            FT.aggroFlashUntil = 0
            FT.combatEndedAt = 0
            FT.threatDirty = true
            FT:RefreshWindowLockState()
            FT:UpdateWindowAlpha()

            if FT.db.autoShowInCombat and not FT.db.autoShowOnlyWithThreat then
                frame:Show()
            end

        elseif event == "PLAYER_REGEN_ENABLED" then
            FT:EndCleanTankingStreak()
            FT.lastAggroState = false
            FT.lastTargetingPlayer = false
            FT.hasSeenNonPlayerTank = false
            FT.highThreatWarned = false
            FT.funDangerActive = false
            FT.funDangerLevel = nil
            FT.funDuration = 0
            if FT.funFrame then
                FT.funFrame:Hide()
                FT.funFrame.text:SetText("")
                FT.currentFunKey = nil
            end
            FT.warningDuration = 0
            FT.lastAggroHolderName = nil
            FT.lastAggroHolderWasPlayer = nil
            FT.lastEffectiveThreatMode = nil
            FT.lastTauntSwap = nil
            FT:ResetTPS()
            FT.threatResetPendingAt = nil
            FT.hadActiveThreatForSource = false
            FT.lastThreatResetSourceGUID = nil
            FT.aggroFlashName = nil
            FT.aggroFlashUntil = 0
            FT.combatEndedAt = GetTime()
            FT.threatDirty = true
            FT:RefreshWindowLockState()
            FT:UpdateWindowAlpha()

            if FT.warningFrame then
                FT.warningFrame:Hide()
                FT.warningFrame.text:SetText("")
                FT.currentWarningKey = nil
                FT.currentWarningArgs = nil
                FT.currentWarningSuffix = nil
            end

        elseif event == "PLAYER_TARGET_CHANGED" then
            if FT.db.threatSource ~= "FOCUS" then
                FT:ClearThreatDisplay()
            end
            FT.threatDirty = true

        elseif event == "PLAYER_FOCUS_CHANGED" then
            if FT.db.threatSource == "FOCUS" then
                FT:ClearThreatDisplay()
            end
            FT.threatDirty = true

        elseif event == "UNIT_TARGET" then
            local sourceUnit = FT.GetThreatSourceUnit and FT:GetThreatSourceUnit() or "target"
            if arg1 == sourceUnit then
                FT.threatDirty = true
            end
        end

        FT:Refresh()
        FT.threatDirty = false
    end)

    self:ApplySkin()
    self:RefreshLayout()
end

function FT:ClearThreatDisplay()
    self.lastThreatMeaningful = false
    self.lastTauntSwap = nil
    self:ResetTPS()
    self:ResetETAWarningState()
    if self.ResetRaidThreatScanCache then
        self:ResetRaidThreatScanCache()
    end
    self.threatResetPendingAt = nil
    self.hadActiveThreatForSource = false
    self.lastThreatResetSourceGUID = nil
    self.lastAggroState = false
    self.lastTargetingPlayer = false
    self.hasSeenNonPlayerTank = false
    self.highThreatWarned = false
    self:ResetETAWarningState()
    self:ResetTankLeadWarningState()
    self.lastAggroHolderName = nil
    self.lastAggroHolderWasPlayer = nil
    self.aggroFlashName = nil
    self.aggroFlashUntil = 0

    if self.warningFrame then
        self.warningFrame:Hide()
        self.warningFrame.text:SetText("")
        self.warningDuration = 0
        self.currentWarningKey = nil
        self.currentWarningArgs = nil
        self.currentWarningSuffix = nil
    end

    for _, row in ipairs(self.rows or {}) do
        row.bar:SetValue(0)
        row.rank:SetText("")
        row.name:SetText("")
        row.playerHighlight:Hide()
        if row.raidFocusHighlight then row.raidFocusHighlight:Hide() end
        if row.threatRaceHighlight then row.threatRaceHighlight:Hide() end
        row.aggroFlash:Hide()
        if row.tankMarker then row.tankMarker:Hide() end
        if row.aggroCrown then row.aggroCrown:Hide() end

        if row.threat then row.threat:SetText("") end
        if row.tps then row.tps:SetText("") end
        if row.eta then row.eta:SetText("") end
        if row.delta then row.delta:SetText("") end
        if row.percent then row.percent:SetText("") end

        row:Hide()
    end
end

function FT:ShowCombatWarning(text, r, g, b, duration, playSound)
    if not self.db.warningEnabled or not self.warningFrame then
        return
    end

    self.warningFrame.text:SetText(text or "")
    self.warningFrame.text:SetTextColor(r or 1, g or 0.2, b or 0.1)
    self.warningDuration = duration or 1.5
    self.warningFrame:Show()

    if playSound then
        local soundKind = type(playSound) == "string" and playSound or "AGGRO"
        self:PlayCombatWarningSound(soundKind, false)
    end
end

function FT:ShowLocalizedCombatWarning(key, args, suffix, r, g, b, duration, playSound)
    args = args or {}
    suffix = suffix or ""

    self.currentWarningKey = key
    self.currentWarningArgs = args
    self.currentWarningSuffix = suffix

    local unpackArgs = _G.unpack or table.unpack
    local text
    if #args > 0 and unpackArgs then
        text = self:L(key, unpackArgs(args))
    else
        text = self:L(key)
    end

    self:ShowCombatWarning((text or "") .. suffix, r, g, b, duration, playSound)
end

function FT:RefreshCombatWarningLocale()
    if self.warningFrame and self.warningFrame:IsShown() and self.currentWarningKey then
        local args = self.currentWarningArgs or {}
        local unpackArgs = _G.unpack or table.unpack
        local text
        if #args > 0 and unpackArgs then
            text = self:L(self.currentWarningKey, unpackArgs(args))
        else
            text = self:L(self.currentWarningKey)
        end

        self.warningFrame.text:SetText((text or "") .. (self.currentWarningSuffix or ""))
    end

    if self.funFrame and self.funFrame:IsShown() and self.currentFunKey then
        self.funFrame.text:SetText(self:L(self.currentFunKey))
    end
end

function FT:ShowFunDangerMessage(key, duration)
    if not self.db or self.db.funMode ~= true or not self.funFrame then
        return
    end

    self.currentFunKey = key
    self.funFrame.text:SetText(self:L(key))
    self.funDuration = duration or 1.7
    self.funFrame:Show()
end

function FT:ResetFunDangerState()
    self.funDangerActive = false
    self.funDangerLevel = nil
end

function FT:CheckFunDangerMessage(data, effectiveMode)
    if not self.db
        or self.db.funMode ~= true
        or effectiveMode == "TANK"
        or not self:IsPlayerInCombat()
        or (not IsInGroup() and not IsInRaid()) then
        self:ResetFunDangerState()
        return
    end

    local playerEntry
    local someoneElseHasAggro = false

    for _, entry in ipairs(data or {}) do
        if self:IsPlayerThreatEntry(entry) then
            playerEntry = entry
        elseif entry.isAggroHolder
            or entry.targetTarget
            or entry.isTanking
            or (entry.status ~= nil and entry.status >= 2) then
            someoneElseHasAggro = true
        end
    end

    if not playerEntry or not someoneElseHasAggro then
        self:ResetFunDangerState()
        return
    end

    if playerEntry.isAggroHolder or playerEntry.targetTarget then
        self:ResetFunDangerState()
        return
    end

    local scaled = tonumber(playerEntry.scaled)
    if not scaled then
        self:ResetFunDangerState()
        return
    end

    if scaled >= 99 then
        if self.funDangerLevel ~= "CRITICAL" then
            self:ShowFunDangerMessage("FUN_ONE_CRIT_AWAY", 1.8)
            self.funDangerActive = true
            self.funDangerLevel = "CRITICAL"
        end
    elseif scaled >= 97 then
        if not self.funDangerActive then
            self:ShowFunDangerMessage("FUN_LIVING_DANGEROUSLY", 1.8)
            self.funDangerActive = true
            self.funDangerLevel = "DANGER"
        end
    elseif self.funDangerActive and scaled < 90 then
        self:ShowFunDangerMessage("FUN_THAT_WAS_CLOSE", 1.6)
        self:ResetFunDangerState()
    end
end

function FT:CheckPlayerThreatWarning(data, sourceUnit, effectiveMode)
    sourceUnit = sourceUnit or (self.GetThreatSourceUnit and self:GetThreatSourceUnit()) or "target"

    if not UnitAffectingCombat("player") or not UnitExists(sourceUnit) then
        self.lastAggroState = false
        self.lastTargetingPlayer = false
        self.hasSeenNonPlayerTank = false
        self.highThreatWarned = false
        return
    end

    local playerEntry = nil
    local someoneElseHasAggro = false

    for _, entry in ipairs(data) do
        if entry.isPlayer then
            playerEntry = entry
        elseif entry.targetTarget or entry.isTanking or (entry.status ~= nil and entry.status >= 2) then
            someoneElseHasAggro = true
        end
    end

    if someoneElseHasAggro then
        self.hasSeenNonPlayerTank = true
    end

    if not playerEntry then
        return
    end

    local targetingPlayer = false
    local sourceTargetUnit = self.GetThreatSourceTargetUnit and self:GetThreatSourceTargetUnit(sourceUnit) or "targettarget"

    if UnitExists(sourceTargetUnit) then
        local ok, isPlayerTarget = pcall(UnitIsUnit, sourceTargetUnit, "player")

        if ok and not FT:IsSecret(isPlayerTarget) then
            targetingPlayer = isPlayerTarget == true
        end
    end

    if targetingPlayer
        and not self.lastTargetingPlayer
        and self.hasSeenNonPlayerTank then

        self:ShowLocalizedCombatWarning("AGGRO", {}, "!", 1.0, 0.12, 0.05, 1.8, "AGGRO")
        self.highThreatWarned = false
    end

    local warningThreshold = tonumber(self.db.highThreatThreshold) or 90
    warningThreshold = math.max(50, math.min(99, warningThreshold))

    if not targetingPlayer
        and effectiveMode ~= "TANK"
        and self.db.highThreatWarning
        and playerEntry.scaled ~= nil
        and playerEntry.scaled >= warningThreshold
        and not self.highThreatWarned then

        self:ShowLocalizedCombatWarning("HIGH_THREAT_WARNING", {}, "", 1.0, 0.65, 0.05, 1.4, "HIGH")
        self.highThreatWarned = true

    elseif playerEntry.scaled ~= nil
        and playerEntry.scaled < math.max(0, warningThreshold - 10) then

        self.highThreatWarned = false
    end

    self.lastTargetingPlayer = targetingPlayer
    self.lastAggroState = targetingPlayer
end

local function IsSupportedTauntCasterUnit(unit)
    if unit == "player" then
        return true
    end

    if type(unit) ~= "string" then
        return false
    end

    if string.match(unit, "^party%d+$") or string.match(unit, "^raid%d+$") then
        return true
    end

    return false
end

function FT:HandleUnitSpellcastTaunt(unit, castGUID, spellId)
    if not IsSupportedTauntCasterUnit(unit) then
        return
    end

    if self:IsSecret(spellId) or type(spellId) ~= "number" or not TAUNT_SPELLS[spellId] then
        return
    end

    local sourceUnit = self.GetThreatSourceUnit and self:GetThreatSourceUnit() or "target"
    local hostileGUID = SafeUnitGUID(sourceUnit)
    local casterGUID = SafeUnitGUID(unit)

    local sourceName = unit
    if type(_G.UnitName) == "function" then
        local ok, name = pcall(UnitName, unit)
        if ok and not self:IsSecret(name) and name and name ~= "" then
            sourceName = name
        end
    end

    local sourceLabel = self:L(sourceUnit == "focus" and "SOURCE_FOCUS" or "SOURCE_TARGET")

    if not hostileGUID or not casterGUID then
        if self.tauntDebug then
            self:Print(self:L(
                "DEBUG_TAUNT_CAST",
                tostring(sourceName or unit),
                tostring(spellId),
                sourceLabel,
                self:L("DEBUG_TAUNT_NO_GUID")
            ))
        end
        return
    end

    -- UNIT_SPELLCAST_SUCCEEDED does not expose the spell destination.
    -- Only accept a taunt when the caster currently targets the same hostile
    -- Target/Focus that ForeverThreat is tracking.
    local casterTargetUnit = unit == "player" and "target" or (unit .. "target")
    local casterTargetGUID = SafeUnitGUID(casterTargetUnit)

    if not casterTargetGUID or casterTargetGUID ~= hostileGUID then
        if self.tauntDebug then
            self:Print(self:L(
                "DEBUG_TAUNT_CAST",
                tostring(sourceName or unit),
                tostring(spellId),
                sourceLabel,
                self:L("DEBUG_TAUNT_TARGET_MISMATCH")
            ))
        end
        return
    end

    if not self.db or not self.db.tauntSwapDetection then
        if self.tauntDebug then
            self:Print(self:L(
                "DEBUG_TAUNT_CAST",
                tostring(sourceName or unit),
                tostring(spellId),
                sourceLabel,
                self:L("DEBUG_TAUNT_DETECTION_OFF")
            ))
        end
        return
    end

    self.tpsTauntIgnoreGUID = casterGUID
    self.tpsTauntIgnoreUntil = GetTime() + TAUNT_SWAP_WINDOW

    self.lastTauntSwap = {
        time = GetTime(),
        sourceGUID = casterGUID,
        sourceName = sourceName,
        destGUID = hostileGUID,
        spellId = spellId,
    }

    if self.tauntDebug then
        self:Print(self:L(
            "DEBUG_TAUNT_CAST",
            tostring(sourceName or unit),
            tostring(spellId),
            sourceLabel,
            self:L("DEBUG_TAUNT_ACCEPTED")
        ))
    end
end

function FT:IsRecentTauntSwap(tankEntry)
    if not self.db or not self.db.tauntSwapDetection or not tankEntry then
        return false
    end

    local taunt = self.lastTauntSwap
    if not taunt or not taunt.time or (GetTime() - taunt.time) > TAUNT_SWAP_WINDOW then
        self.lastTauntSwap = nil
        return false
    end

    local newTankGUID = SafeUnitGUID(tankEntry.unit)
    if not newTankGUID or newTankGUID ~= taunt.sourceGUID then
        return false
    end

    local sourceUnit = self.GetThreatSourceUnit and self:GetThreatSourceUnit() or "target"
    local hostileGUID = SafeUnitGUID(sourceUnit)
    if not hostileGUID or hostileGUID ~= taunt.destGUID then
        return false
    end

    self.lastTauntSwap = nil
    return true
end

local function FormatStreakTime(seconds)
    seconds = math.max(0, math.floor((tonumber(seconds) or 0) + 0.5))
    local minutes = math.floor(seconds / 60)
    local remaining = seconds % 60

    if minutes >= 60 then
        local hours = math.floor(minutes / 60)
        minutes = minutes % 60
        return string.format("%d:%02d:%02d", hours, minutes, remaining)
    end

    return string.format("%d:%02d", minutes, remaining)
end

function FT:EndCleanTankingStreak()
    if self.cleanTankingStartedAt then
        local elapsed = math.max(0, GetTime() - self.cleanTankingStartedAt)
        self.cleanTankingBest = math.max(tonumber(self.cleanTankingBest) or 0, elapsed)
    end

    self.cleanTankingStartedAt = nil
    self.cleanTankingCurrent = 0
end

function FT:UpdateCleanTankingStreak(tankEntry, effectiveMode)
    if not self.db or self.db.showTankStreak ~= true then
        self:EndCleanTankingStreak()
        return
    end

    local currentIsPlayer = tankEntry and self:IsPlayerThreatEntry(tankEntry) or false
    local shouldRun = self:IsPlayerInCombat()
        and effectiveMode == "TANK"
        and currentIsPlayer

    if shouldRun then
        if not self.cleanTankingStartedAt then
            self.cleanTankingStartedAt = GetTime()
        end

        local elapsed = math.max(0, GetTime() - self.cleanTankingStartedAt)
        self.cleanTankingCurrent = elapsed
        self.cleanTankingBest = math.max(tonumber(self.cleanTankingBest) or 0, elapsed)
    else
        self:EndCleanTankingStreak()
    end
end

function FT:GetCleanTankingStreakText(effectiveMode)
    if not self.db or self.db.showTankStreak ~= true or effectiveMode ~= "TANK" then
        return nil
    end

    local current = tonumber(self.cleanTankingCurrent) or 0
    local best = tonumber(self.cleanTankingBest) or 0

    if self.cleanTankingStartedAt and current > 0 then
        return self:L(
            "TANK_STREAK_ACTIVE_FORMAT",
            FormatStreakTime(current),
            FormatStreakTime(best)
        )
    elseif best > 0 then
        return self:L("TANK_STREAK_BEST_FORMAT", FormatStreakTime(best))
    end

    return nil
end

function FT:ResetSessionStatistics()
    self.sessionStats = {
        startedAt = GetTime(),
        aggroGained = 0,
        aggroLost = 0,
        tankSwaps = 0,
        bestThreatRank = nil,
        highestThreatPercent = 0,
        longestTankLead = 0,
        closestTimeToAggro = nil,
    }

    -- Clean Tanking Streak is also a runtime/session value.
    self.cleanTankingBest = 0
    self.cleanTankingStartedAt = nil
    self.cleanTankingCurrent = 0

    if self.RefreshSessionStatistics then
        self:RefreshSessionStatistics()
    end
end

function FT:GetSessionStatistics()
    if not self.sessionStats then
        self:ResetSessionStatistics()
    end
    return self.sessionStats
end

function FT:UpdateSessionStatistics(data, effectiveMode)
    if self.testMode or not self:IsPlayerInCombat() then
        return
    end

    local stats = self:GetSessionStatistics()
    local playerEntry

    for _, entry in ipairs(data or {}) do
        if self:IsPlayerThreatEntry(entry) then
            playerEntry = entry
            break
        end
    end

    if not playerEntry then
        return
    end

    local rank = tonumber(playerEntry.threatRank)
    if rank and rank > 0 and (stats.bestThreatRank == nil or rank < stats.bestThreatRank) then
        stats.bestThreatRank = rank
    end

    local scaled = tonumber(playerEntry.scaled)
    if scaled and scaled > (stats.highestThreatPercent or 0) then
        stats.highestThreatPercent = math.min(100, scaled)
    end

    local eta = tonumber(playerEntry.threatEta)
    if effectiveMode == "TANK" and playerEntry.etaIsLead == true then
        if eta and eta >= 0 and eta > (stats.longestTankLead or 0) then
            stats.longestTankLead = eta
        end
    elseif eta and eta >= 0 and not playerEntry.isAggroHolder then
        if stats.closestTimeToAggro == nil or eta < stats.closestTimeToAggro then
            stats.closestTimeToAggro = eta
        end
    end
end

function FT:TrackAggroHolder(tankEntry, effectiveMode)
    local currentName = tankEntry and tankEntry.name or nil
    local currentIsPlayer = tankEntry and self:IsPlayerThreatEntry(tankEntry) or false

    if not UnitAffectingCombat("player") then
        self.lastAggroHolderName = currentName
        self.lastAggroHolderWasPlayer = currentIsPlayer
        self.aggroFlashName = nil
        self.aggroFlashUntil = 0
        return
    end

    local changed = currentName
        and self.lastAggroHolderName
        and currentName ~= self.lastAggroHolderName

    if changed and self.db.highlightAggroChanges then
        self.aggroFlashName = currentName
        self.aggroFlashUntil = GetTime() + 3.0
    end

    local lostAggroAsTank = changed
        and self.lastAggroHolderWasPlayer
        and not currentIsPlayer
        and self.lastEffectiveThreatMode == "TANK"

    if changed and currentIsPlayer then
        local stats = self:GetSessionStatistics()
        stats.aggroGained = (stats.aggroGained or 0) + 1
    end

    if lostAggroAsTank then
        local plannedTankSwap = self:IsRecentTauntSwap(tankEntry)
        local stats = self:GetSessionStatistics()

        if plannedTankSwap then
            stats.tankSwaps = (stats.tankSwaps or 0) + 1
            -- A successful taunt by the new aggro holder is treated as an
            -- intentional tank swap: no red loss warning and no loss sound.
            if self.db.showTankSwapMessage then
                self:ShowLocalizedCombatWarning("TANK_SWAP", { currentName }, "", 0.35, 0.82, 1.0, 1.4, false)
            end
        else
            stats.aggroLost = (stats.aggroLost or 0) + 1

            if self.db.tankAggroLossWarning then
                self:ShowLocalizedCombatWarning("TANK_AGGRO_LOST", { currentName }, "", 1.0, 0.18, 0.08, 2.0, false)
            end

            if self.db.tankAggroLossSound then
                self:PlayAggroLossSound(false)
            end
        end

    -- The player's own aggro gain is already handled by the dedicated AGGRO!
    -- warning + sound. Generic handoff messages remain intentionally silent.
    elseif changed
        and self.db.showAggroChangeMessage
        and not currentIsPlayer then

        local warningKey

        if self.lastAggroHolderWasPlayer then
            warningKey = "AGGRO_LOST_TO"
        else
            warningKey = "AGGRO_TO"
        end

        self:ShowLocalizedCombatWarning(warningKey, { currentName }, "", 1.0, 0.55, 0.12, 1.5, false)
    end

    self.lastAggroHolderName = currentName
    self.lastAggroHolderWasPlayer = currentIsPlayer
    self.lastEffectiveThreatMode = effectiveMode
end

local function GetDynamicThreatColor(entry, effectiveMode)
    if not FT.db.dynamicThreatColors or entry.scaled == nil or entry.isAggroHolder then
        return nil
    end

    local isPlayer = FT:IsPlayerThreatEntry(entry)
    local shouldColor = effectiveMode == "TANK"
        or ((effectiveMode == "DPS" or effectiveMode == "HEALER") and isPlayer)

    if not shouldColor then
        return nil
    end

    local yellow, orange, red = FT:GetThreatThresholds(effectiveMode)

    if entry.scaled >= red then
        return 1.0, 0.12, 0.05
    elseif entry.scaled >= orange then
        return 1.0, 0.45, 0.10
    elseif entry.scaled >= yellow then
        return 1.0, 0.82, 0.15
    end

    return nil
end

local function HasMeaningfulThreatData(data)
    for _, entry in ipairs(data or {}) do
        if entry.isTanking
            or entry.targetTarget
            or entry.status ~= nil
            or entry.scaled ~= nil
            or entry.rawPct ~= nil
            or entry.rawThreat ~= nil then
            return true
        end
    end

    return false
end

local function HasActiveThreatData(data)
    for _, entry in ipairs(data or {}) do
        if entry.isTanking or entry.targetTarget then
            return true
        end

        if type(entry.status) == "number" and entry.status > 0 then
            return true
        end

        if type(entry.scaled) == "number" and entry.scaled > 0 then
            return true
        end

        if type(entry.rawPct) == "number" and entry.rawPct > 0 then
            return true
        end

        if type(entry.rawThreat) == "number" and entry.rawThreat > 0 then
            return true
        end
    end

    return false
end

function FT:ResetAggroTrackingAfterThreatReset()
    self.lastAggroState = false
    self.lastTargetingPlayer = false
    self.hasSeenNonPlayerTank = false
    self.highThreatWarned = false
    self.lastAggroHolderName = nil
    self.lastAggroHolderWasPlayer = nil
    self.lastEffectiveThreatMode = nil
    self.lastTauntSwap = nil
    self.aggroFlashName = nil
    self.aggroFlashUntil = 0
end

function FT:UpdateThreatResetState(data, sourceUnit)
    if not self.db or not self.db.threatResetProtection or not self:IsPlayerInCombat() then
        self.threatResetPendingAt = nil
        self.hadActiveThreatForSource = HasActiveThreatData(data)
        self.lastThreatResetSourceGUID = SafeUnitGUID(sourceUnit)
        return self.hadActiveThreatForSource and "ACTIVE" or "IDLE"
    end

    local sourceGUID = SafeUnitGUID(sourceUnit)
    local active = HasActiveThreatData(data)

    -- A source switch is not a threat reset. PLAYER_TARGET_CHANGED /
    -- PLAYER_FOCUS_CHANGED already clears the normal display state, but the
    -- GUID guard also protects against event ordering differences.
    if sourceGUID ~= self.lastThreatResetSourceGUID then
        self.lastThreatResetSourceGUID = sourceGUID
        self.hadActiveThreatForSource = active
        self.threatResetPendingAt = nil
        return active and "ACTIVE" or "IDLE"
    end

    if active then
        self.hadActiveThreatForSource = true
        self.threatResetPendingAt = nil
        return "ACTIVE"
    end

    if not self.hadActiveThreatForSource then
        self.threatResetPendingAt = nil
        return "IDLE"
    end

    local now = GetTime()
    if not self.threatResetPendingAt then
        self.threatResetPendingAt = now
        return "PENDING"
    end

    if (now - self.threatResetPendingAt) < THREAT_RESET_CONFIRM_TIME then
        return "PENDING"
    end

    -- Threat was previously active on this same hostile source and remained
    -- fully absent for the confirmation window. Treat this as a boss/mechanic
    -- threat reset rather than an aggro handoff.
    self.threatResetPendingAt = nil
    self.hadActiveThreatForSource = false
    self:ResetAggroTrackingAfterThreatReset()
    self:ResetTPS()
    return "RESET"
end

function FT:ShouldSmartHide(data)
    -- Idle Dimming is the non-hiding alternative. If both options are enabled,
    -- dimming wins so the threat window remains visible as requested.
    if self.db.idleDimming then
        return false
    end

    if not self.db.smartAutoHide or self:IsPlayerInCombat() then
        return false
    end

    if (self.smartHideSuppressUntil or 0) > GetTime() then
        return false
    end

    if (self.combatEndedAt or 0) > 0 and (GetTime() - self.combatEndedAt) < 1.0 then
        return false
    end

    local sourceUnit = self.GetThreatSourceUnit and self:GetThreatSourceUnit() or "target"

    if not UnitExists(sourceUnit) then
        return true
    end

    local ok, hostile = pcall(UnitCanAttack, "player", sourceUnit)
    if ok and not self:IsSecret(hostile) and hostile ~= true then
        return true
    end

    -- If hostility itself is protected, err on the side of keeping the meter visible.
    if not ok or self:IsSecret(hostile) then
        return false
    end

    return not HasMeaningfulThreatData(data)
end

function FT:SetTestMode(enabled)
    enabled = enabled and true or false

    if enabled and self:IsPlayerInCombat() then
        self:Print(self:L("TEST_MODE_COMBAT_BLOCKED"))
        return false
    end

    self.testMode = enabled
    self.threatDirty = true
    self.smartHideSuppressUntil = GetTime() + 5

    if enabled then
        if self.frame then
            self.frame:Show()
        end
        self:Print(self:L("TEST_MODE_ON"))
    else
        self:ClearThreatDisplay()
        self:Print(self:L("TEST_MODE_OFF"))
    end

    self:Refresh()

    if self.RefreshConfigControls then
        self:RefreshConfigControls()
    end

    return true
end

function FT:RefreshLayout()
    if not self.frame or not self.rows then
        return
    end

    local native = IsNativeMeterStyle()
    local rowHeight = self.db.barHeight or DEFAULT_ROW_HEIGHT
    local fontSize = self.db.fontSize or 12
    local headerHeight = self:GetThreatHeaderHeight()
    local rowGap = self:GetThreatRowGap()

    if native then
        if self.frame.skinTitle then
            self.frame.skinTitle:Show()
            self.frame.skinTitle:SetFontObject(_G.GameFontNormalMed1 or GameFontNormal)
            self.frame.skinTitle:ClearAllPoints()
            self.frame.skinTitle:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 23, -9)
            self.frame.skinTitle:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -82, -9)
            self.frame.skinTitle:SetJustifyH("LEFT")
            self.frame.skinTitle:SetWordWrap(false)
        end
        if self.frame.target then self.frame.target:Hide() end
        if self.configButton then self.configButton:Hide() end
        if self.closeButton then self.closeButton:Hide() end
        if self.nativeMinimizeButton then self.nativeMinimizeButton:Show() end
        if self.nativeSettingsButton then self.nativeSettingsButton:Show() end
        if self.nativeSourceButton then
            self.nativeSourceButton:Show()
            self.nativeSourceButton.text:SetText(self.db.threatSource == "FOCUS" and "F" or "T")
        end
        if self.nativeTitleButton then self.nativeTitleButton:Show() end
    else
        if self.nativeMinimizeButton then self.nativeMinimizeButton:Hide() end
        if self.nativeSettingsButton then self.nativeSettingsButton:Hide() end
        if self.nativeSourceButton then self.nativeSourceButton:Hide() end
        if self.nativeTitleButton then self.nativeTitleButton:Hide() end
        if self.configButton then self.configButton:Show() end
        if self.closeButton then self.closeButton:Show() end

        if self.frame.skinTitle then
            self.frame.skinTitle:SetText("FOREVERTHREAT")
            self.frame.skinTitle:ClearAllPoints()
            self.frame.skinTitle:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, -8)
            if self.db.showHeader == false then
                self.frame.skinTitle:Hide()
            else
                self.frame.skinTitle:Show()
            end
        end

        if self.frame.target then
            self.frame.target:Show()
            self.frame.target:ClearAllPoints()
            if self.db.showHeader == false then
                self.frame.target:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, -9)
            else
                self.frame.target:SetPoint("TOPLEFT", self.frame.skinTitle, "BOTTOMLEFT", 0, -3)
            end
            self.frame.target:SetPoint("RIGHT", self.frame, "RIGHT", -62, 0)
        end
    end

    for i, row in ipairs(self.rows) do
        self:ApplyBarTexture(row)
        row:SetHeight(rowHeight)

        local fontObject = native and (_G.NumberFontNormal or GameFontHighlightSmall) or GameFontHighlightSmall
        row.rank:SetFontObject(fontObject)
        row.name:SetFontObject(fontObject)
        row.threat:SetFontObject(fontObject)
        row.tps:SetFontObject(fontObject)
        row.eta:SetFontObject(fontObject)
        row.delta:SetFontObject(fontObject)
        row.percent:SetFontObject(fontObject)

        ApplyFontSize(row.rank, fontSize)
        ApplyFontSize(row.name, fontSize)
        ApplyFontSize(row.threat, fontSize)
        ApplyFontSize(row.tps, fontSize)
        ApplyFontSize(row.eta, fontSize)
        ApplyFontSize(row.delta, fontSize)
        ApplyFontSize(row.percent, fontSize)

        row.icon:ClearAllPoints()
        row.bar:ClearAllPoints()

        if native then
            row.icon:SetSize(24, math.min(18, rowHeight))
            row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
            row.icon:Show()
            row.bar:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 0, -1)
            row.bar:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 1)
        else
            row.icon:Hide()
            row.tankMarker:Hide()
            if row.aggroCrown then row.aggroCrown:Hide() end
            row.bar:SetAllPoints(row)
        end

        row.rank:ClearAllPoints()
        row.rank:SetPoint("LEFT", row.bar, "LEFT", native and 2 or 5, 0)

        local rightOffset = native and 3 or 6
        local frameWidth = self.frame:GetWidth() or 274

        local showPercentColumn
        local showETAColumn
        local showTPSColumn
        local showDeltaColumn
        local showThreatColumn

        if native then
            -- In the WoW meter look, raw threat + percentage share the native
            -- right-aligned value field. Extra analytics appear as the window grows.
            showPercentColumn = self.db.showPercent or self.db.showThreatValue
            showETAColumn = self.db.showThreatETA and frameWidth >= 330
            showTPSColumn = self.db.showTPS and frameWidth >= 400
            showDeltaColumn = self.db.showThreatDelta and frameWidth >= 480
            showThreatColumn = false
            row.percent:SetWidth(104)
        else
            showPercentColumn = self.db.showPercent
            showETAColumn = self.db.showThreatETA and frameWidth >= 220
            local tpsThreshold = showETAColumn and 300 or 220
            local deltaThreshold = 220
            if self.db.showThreatETA then deltaThreshold = deltaThreshold + 100 end
            if self.db.showTPS then deltaThreshold = deltaThreshold + 110 end
            local threatThreshold = 270
            if self.db.showThreatETA then threatThreshold = threatThreshold + 100 end
            if self.db.showTPS then threatThreshold = threatThreshold + 110 end
            showTPSColumn = self.db.showTPS and frameWidth >= tpsThreshold
            showDeltaColumn = self.db.showThreatDelta and frameWidth >= deltaThreshold
            showThreatColumn = self.db.showThreatValue and frameWidth >= threatThreshold
            row.percent:SetWidth(38)
        end

        row.percent:ClearAllPoints()
        if showPercentColumn then
            row.percent:SetPoint("RIGHT", row.bar, "RIGHT", -rightOffset, 0)
            row.percent:Show()
            rightOffset = rightOffset + (native and 108 or 42)
        else
            row.percent:Hide()
        end

        row.eta:ClearAllPoints()
        if showETAColumn then
            row.eta:SetPoint("RIGHT", row.bar, "RIGHT", -rightOffset, 0)
            row.eta:Show()
            rightOffset = rightOffset + 68
        else
            row.eta:Hide()
        end

        row.tps:ClearAllPoints()
        if showTPSColumn then
            row.tps:SetPoint("RIGHT", row.bar, "RIGHT", -rightOffset, 0)
            row.tps:Show()
            rightOffset = rightOffset + 62
        else
            row.tps:Hide()
        end

        row.delta:ClearAllPoints()
        if showDeltaColumn then
            row.delta:SetPoint("RIGHT", row.bar, "RIGHT", -rightOffset, 0)
            row.delta:Show()
            rightOffset = rightOffset + 68
        else
            row.delta:Hide()
        end

        row.threat:ClearAllPoints()
        if showThreatColumn then
            row.threat:SetPoint("RIGHT", row.bar, "RIGHT", -rightOffset, 0)
            row.threat:Show()
            rightOffset = rightOffset + 52
        else
            row.threat:Hide()
        end

        row.name:ClearAllPoints()
        row.name:SetPoint("LEFT", row.rank, "RIGHT", 4, 0)
        row.name:SetPoint("RIGHT", row.bar, "RIGHT", -rightOffset, 0)

        row:ClearAllPoints()
        if i == 1 then
            row:SetPoint("TOPLEFT", self.frame, "TOPLEFT", native and 5 or 10, -(headerHeight + (native and 2 or 0)))
            row:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", native and -1 or -10, -(headerHeight + (native and 2 or 0)))
        else
            row:SetPoint("TOPLEFT", self.rows[i - 1], "BOTTOMLEFT", 0, -rowGap)
            row:SetPoint("TOPRIGHT", self.rows[i - 1], "BOTTOMRIGHT", 0, -rowGap)
        end
    end

    self:UpdateWindowAlpha()
    self:Refresh()
end

function FT:Refresh()
    if not self.frame then
        return
    end

    local data, targetName, tankEntry, sourceUnit

    if self.testMode then
        data, targetName, tankEntry, sourceUnit = self:GetTestThreatData()

        if not self.frame:IsShown() then
            self.frame:Show()
        end
    elseif not self.frame:IsShown() then
        if not self.db.autoShowInCombat
            or not self.db.autoShowOnlyWithThreat
            or not self:IsPlayerInCombat() then
            return
        end

        data, targetName, tankEntry, sourceUnit = self:GetThreatData()

        if not HasMeaningfulThreatData(data) then
            return
        end

        self.frame:Show()
    else
        data, targetName, tankEntry, sourceUnit = self:GetThreatData()
    end

    self.lastThreatMeaningful = HasMeaningfulThreatData(data)

    if not self.testMode and self:ShouldSmartHide(data) then
        self.frame:Hide()
        return
    end

    self:UpdateWindowAlpha()

    local targetTargetName
    if self.testMode then
        targetTargetName = tankEntry and tankEntry.name or nil
    else
        targetTargetName = self:GetTargetTargetName(sourceUnit)
    end

    local isFocus = not self.testMode and sourceUnit == "focus"

    if IsNativeMeterStyle() then
        if targetTargetName and self.db.showTargetTarget then
            self.frame.skinTitle:SetText(self:L("METER_TITLE_WITH_TARGET_FORMAT", targetName, targetTargetName))
        else
            self.frame.skinTitle:SetText(self:L("METER_TITLE_FORMAT", targetName))
        end
        if self.nativeSourceButton then
            self.nativeSourceButton.text:SetText(isFocus and "F" or "T")
        end
    elseif targetTargetName then
        self.frame.target:SetText(self:L(
            isFocus and "FOCUS_WITH_TARGET_FORMAT" or "TARGET_WITH_TARGET_FORMAT",
            targetName,
            targetTargetName
        ))
    else
        self.frame.target:SetText(self:L(
            isFocus and "FOCUS_FORMAT" or "TARGET_FORMAT",
            targetName
        ))
    end

    local effectiveMode = self:GetEffectiveThreatMode(tankEntry)

    if not self.testMode then
        self:UpdateCleanTankingStreak(tankEntry, effectiveMode)
    else
        self:EndCleanTankingStreak()
    end

    local tankStreakText = self:GetCleanTankingStreakText(effectiveMode)
    if tankStreakText then
        if IsNativeMeterStyle() and self.frame.skinTitle then
            local currentHeader = self.frame.skinTitle:GetText() or ""
            self.frame.skinTitle:SetText(currentHeader .. "  |  " .. tankStreakText)
        elseif self.frame.target and self.frame.target:IsShown() then
            local currentTarget = self.frame.target:GetText() or ""
            self.frame.target:SetText(currentTarget .. "  |  " .. tankStreakText)
        end
    end

    if not self.testMode then
        local threatState = self:UpdateThreatResetState(data, sourceUnit)

        -- During a confirmed/pending reset there is no reliable aggro holder.
        -- Skipping handoff processing prevents false "aggro lost" warnings.
        if threatState == "ACTIVE" then
            self:TrackAggroHolder(tankEntry, effectiveMode)
            self:CheckPlayerThreatWarning(data, sourceUnit, effectiveMode)
            self:CheckFunDangerMessage(data, effectiveMode)
        elseif threatState == "RESET" then
            self.threatDirty = true
        end

        self:UpdateTPS(data, sourceUnit)
        self:UpdateThreatETA(data, tankEntry)
        self:UpdateSessionStatistics(data, effectiveMode)

        if threatState == "ACTIVE" then
            self:CheckPlayerETAWarning(data, effectiveMode)
            self:CheckPlayerTankLeadWarning(data, effectiveMode)
        else
            self:ResetETAWarningState()
            self:ResetTankLeadWarningState()
            self:ResetFunDangerState()
        end
    end

    local rowHeight = self.db.barHeight or DEFAULT_ROW_HEIGHT
    local headerHeight = self:GetThreatHeaderHeight()
    local availableHeight = math.max(rowHeight, self.frame:GetHeight() - headerHeight - 10)
    local maxVisibleRows = math.floor(availableHeight / (rowHeight + self:GetThreatRowGap()))
    maxVisibleRows = math.max(1, math.min(#self.rows, self.db.maxRows or 15, maxVisibleRows))

    local displayData = self:GetDisplayThreatData(data, maxVisibleRows, effectiveMode)
    local skinPalette = self:GetSkinPalette()

    local raidFocusView = IsInRaid() and self.db
        and (self.db.raidDangerViewEnabled or (self.db.raidTankViewEnabled and effectiveMode == "TANK"))
    local nextAggroKey = nil

    if raidFocusView then
        for _, candidate in ipairs(data) do
            if not candidate.isAggroHolder and not candidate.isPet then
                nextAggroKey = candidate.unit or candidate.name
                break
            end
        end
    end

    local visible = 0
    local entriesToShow = math.min(#displayData, maxVisibleRows)

    for i = 1, entriesToShow do
        local entry = displayData[i]
        local row = self.rows[i]
        visible = visible + 1

        local entryKey = entry.unit or entry.name
        local isRaidAggroFocus = raidFocusView and entry.isAggroHolder
        local isRaidNextFocus = raidFocusView and nextAggroKey ~= nil and entryKey == nextAggroKey

        if row.raidFocusHighlight then
            if isRaidAggroFocus then
                row.raidFocusHighlight:SetColorTexture(1.0, 0.82, 0.0, 0.18)
                row.raidFocusHighlight:Show()
            elseif isRaidNextFocus then
                row.raidFocusHighlight:SetColorTexture(1.0, 0.35, 0.08, 0.16)
                row.raidFocusHighlight:Show()
            else
                row.raidFocusHighlight:Hide()
            end
        end

        local r, g, b
        local dynamicR, dynamicG, dynamicB = GetDynamicThreatColor(entry, effectiveMode)

        if dynamicR then
            r, g, b = dynamicR, dynamicG, dynamicB
        elseif entry.isPet then
            r, g, b = 0.62, 0.46, 0.24
        elseif self.db.useClassColors then
            r, g, b = GetClassColor(entry.classToken)
        else
            -- Skin the neutral fallback only. Class colors, pet colors and
            -- dynamic threat warning colors always take precedence.
            r, g, b = skinPalette.neutralBar[1], skinPalette.neutralBar[2], skinPalette.neutralBar[3]
        end

        self:ApplyBarColor(row, r, g, b)
        row.bar:SetValue(self:GetBarValue(entry))

        if IsNativeMeterStyle() then
            ApplyNativeRowIcon(row, entry)
            row.tankMarker:SetShown(self.db.showTankMarker and entry.isAggroHolder)
            if row.aggroCrown then
                row.aggroCrown:SetShown(self.db.showAggroCrown and entry.isAggroHolder)
            end
        else
            row.tankMarker:Hide()
            if row.aggroCrown then row.aggroCrown:Hide() end
        end

        local flashActive = self.db.highlightAggroChanges
            and self.aggroFlashName == entry.name
            and (self.aggroFlashUntil or 0) > GetTime()

        local threatRank = tonumber(entry.threatRank) or i
        local raceActive = self.db.showThreatRace == true
            and threatRank >= 1
            and threatRank <= 3

        if row.threatRaceHighlight then
            if raceActive then
                if threatRank == 1 then
                    row.threatRaceHighlight:SetColorTexture(1.0, 0.82, 0.0, 0.13)
                elseif threatRank == 2 then
                    row.threatRaceHighlight:SetColorTexture(0.75, 0.78, 0.84, 0.11)
                else
                    row.threatRaceHighlight:SetColorTexture(0.78, 0.43, 0.20, 0.10)
                end
                row.threatRaceHighlight:Show()
            else
                row.threatRaceHighlight:Hide()
            end
        end

        if flashActive then
            row.aggroFlash:Show()
            row.rank:SetText("|cffff3b1f!|r")
        else
            row.aggroFlash:Hide()
            if raceActive then
                if threatRank == 1 then
                    row.rank:SetText("|cffffd200#1|r")
                elseif threatRank == 2 then
                    row.rank:SetText("|cffc7ccd6#2|r")
                else
                    row.rank:SetText("|cffc77c48#3|r")
                end
            else
                row.rank:SetText(tostring(threatRank) .. ".")
            end
        end

        local prefix = ""

        if flashActive then
            prefix = prefix .. "|cffff5a1f[!]|r "
        end

        if not IsNativeMeterStyle() and self.db.showTankMarker and entry.isAggroHolder then
            prefix = prefix .. "|cffffd200[T]|r "
        end

        if entry.isPet then
            prefix = prefix .. "|cffc79c6e[P]|r "
        end

        local displayName = prefix .. entry.name

        if entry.dead then
            displayName = displayName .. " |cff888888(" .. self:L("DEAD") .. ")|r"
        elseif not entry.connected then
            displayName = displayName .. " |cff888888(" .. self:L("OFFLINE") .. ")|r"
        end

        row.name:SetText(displayName)

        if self:IsPlayerThreatEntry(entry) and self.db.highlightPlayer then
            row.playerHighlight:Show()
        else
            row.playerHighlight:Hide()
        end

        if flashActive then
            row.name:SetTextColor(1.0, 0.55, 0.12)
        elseif isRaidAggroFocus then
            row.name:SetTextColor(1.0, 0.82, 0.0)
        elseif isRaidNextFocus then
            row.name:SetTextColor(1.0, 0.48, 0.18)
        elseif self:IsPlayerThreatEntry(entry) and self.db.highlightPlayer then
            row.name:SetTextColor(1.0, 0.90, 0.35)
        else
            row.name:SetTextColor(1.0, 1.0, 1.0)
        end

        if row.threat:IsShown() then
            row.threat:SetText(FormatThreat(entry.rawThreat))
        end

        if row.tps:IsShown() then
            row.tps:SetText(FormatTPS(entry.tps))
            if self:IsPlayerThreatEntry(entry) then
                row.tps:SetTextColor(1.0, 0.90, 0.35)
            else
                row.tps:SetTextColor(0.82, 0.82, 0.82)
            end
        end

        if row.eta:IsShown() then
            row.eta:SetText(FormatThreatETA(entry.threatEta, entry.etaIsLead))
            if entry.etaIsLead then
                if entry.threatEta and entry.threatEta <= 5 then
                    row.eta:SetTextColor(1.0, 0.35, 0.15)
                else
                    row.eta:SetTextColor(1.0, 0.82, 0.0)
                end
            elseif entry.threatEta and entry.threatEta <= 5 then
                row.eta:SetTextColor(1.0, 0.25, 0.15)
            elseif entry.threatEta and entry.threatEta <= 10 then
                row.eta:SetTextColor(1.0, 0.72, 0.15)
            else
                row.eta:SetTextColor(0.82, 0.82, 0.82)
            end
        end

        if row.delta:IsShown() then
            if self.db.showGapToAggro then
                row.delta:SetText(FormatThreatGap(entry.threatGap))
            else
                row.delta:SetText(FormatDelta(entry.threatDelta))
            end

            if entry.isAggroHolder then
                row.delta:SetTextColor(1.0, 0.82, 0.0)
            elseif entry.threatDelta ~= nil and entry.threatDelta >= -1000 then
                row.delta:SetTextColor(1.0, 0.45, 0.20)
            else
                row.delta:SetTextColor(0.85, 0.85, 0.85)
            end
        end

        if row.percent:IsShown() then
            if IsNativeMeterStyle() then
                local hasThreat = self.db.showThreatValue and type(entry.rawThreat) == "number"
                local hasPercent = self.db.showPercent and type(entry.scaled) == "number"

                if hasThreat and hasPercent then
                    row.percent:SetText(string.format("%s (%.1f)", FormatMeterThreat(entry.rawThreat), entry.scaled))
                elseif hasThreat then
                    row.percent:SetText(FormatMeterThreat(entry.rawThreat))
                elseif hasPercent then
                    row.percent:SetText(string.format("%.1f%%", entry.scaled))
                else
                    row.percent:SetText(self:GetThreatLabel(entry))
                end
            else
                row.percent:SetText(self:GetThreatLabel(entry))
            end

            if entry.isAggroHolder then
                row.percent:SetTextColor(1.0, 0.82, 0.0)
            elseif dynamicR then
                row.percent:SetTextColor(dynamicR, dynamicG, dynamicB)
            elseif entry.scaled and entry.scaled >= 90 then
                row.percent:SetTextColor(1.0, 0.35, 0.15)
            else
                row.percent:SetTextColor(1.0, 1.0, 1.0)
            end
        end

        row:Show()
    end

    for i = visible + 1, #self.rows do
        self.rows[i].aggroFlash:Hide()
        if self.rows[i].threatRaceHighlight then self.rows[i].threatRaceHighlight:Hide() end
        self.rows[i]:Hide()
    end

    if visible == 0 then
        local row = self.rows[1]

        row.bar:SetStatusBarColor(0.22, 0.22, 0.22, 0.70)
        row.bar:SetValue(0)
        row.rank:SetText("")
        row.name:SetText(self:L("NO_THREAT_DATA"))
        row.name:SetTextColor(1, 1, 1)
        row.playerHighlight:Hide()
        if row.raidFocusHighlight then row.raidFocusHighlight:Hide() end
        if row.threatRaceHighlight then row.threatRaceHighlight:Hide() end
        row.aggroFlash:Hide()
        if row.tankMarker then row.tankMarker:Hide() end
        if row.aggroCrown then row.aggroCrown:Hide() end
        if row.icon and IsNativeMeterStyle() then
            row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        end

        if row.threat:IsShown() then
            row.threat:SetText("")
        end

        if row.tps:IsShown() then
            row.tps:SetText("")
        end

        if row.eta:IsShown() then
            row.eta:SetText("")
        end

        if row.delta:IsShown() then
            row.delta:SetText("")
        end

        if row.percent:IsShown() then
            row.percent:SetText("-")
            row.percent:SetTextColor(1, 1, 1)
        end

        row:Show()
    end
end
