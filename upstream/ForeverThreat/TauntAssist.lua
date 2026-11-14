local addonName, FT = ...

-- Deliberately independent from the ForeverThreat window:
-- the secure button is parented and anchored only to UIParent so the dynamic
-- threat window and rows never become protected through secure-frame ancestry.
local CLASS_TAUNTS = {
    WARRIOR = { 355 },       -- Taunt
    DRUID = { 6795 },        -- Growl
    PALADIN = { 62124 },     -- Hand of Reckoning
    DEATHKNIGHT = { 56222 }, -- Dark Command
    MONK = { 115546 },       -- Provoke
    DEMONHUNTER = { 185245 },-- Torment
}

local function IsInCombatLockdown()
    return type(_G.InCombatLockdown) == "function" and InCombatLockdown()
end

local function GetSpellTextureByID(spellId)
    if _G.C_Spell and type(C_Spell.GetSpellTexture) == "function" then
        local ok, texture = pcall(C_Spell.GetSpellTexture, spellId)
        if ok and not FT:IsSecret(texture) and texture then
            return texture
        end
    end

    if type(_G.GetSpellTexture) == "function" then
        local ok, texture = pcall(GetSpellTexture, spellId)
        if ok and not FT:IsSecret(texture) and texture then
            return texture
        end
    end

    if _G.C_Spell and type(C_Spell.GetSpellInfo) == "function" then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellId)
        if ok and type(info) == "table" and not FT:IsSecret(info.iconID) then
            return info.iconID
        end
    end

    return nil
end

local function GetSpellCooldownInfo(spellId)
    if not spellId then
        return nil
    end

    if _G.C_Spell and type(C_Spell.GetSpellCooldown) == "function" then
        local ok, info = pcall(C_Spell.GetSpellCooldown, spellId)
        if ok and type(info) == "table" then
            local startTime = info.startTime
            local duration = info.duration
            local enabled = info.isEnabled
            local modRate = info.modRate

            if FT:IsSecret(startTime) or FT:IsSecret(duration)
                or FT:IsSecret(enabled) or FT:IsSecret(modRate) then
                return nil
            end

            if type(startTime) == "number" and type(duration) == "number" then
                return startTime, duration, enabled ~= false and enabled ~= 0, tonumber(modRate) or 1
            end
        end
    end

    if type(_G.GetSpellCooldown) == "function" then
        local ok, startTime, duration, enabled, modRate = pcall(GetSpellCooldown, spellId)
        if ok and not FT:IsSecret(startTime) and not FT:IsSecret(duration)
            and not FT:IsSecret(enabled) and not FT:IsSecret(modRate)
            and type(startTime) == "number" and type(duration) == "number" then
            return startTime, duration, enabled ~= false and enabled ~= 0, tonumber(modRate) or 1
        end
    end

    return nil
end

function FT:UpdateClickToTauntCooldown()
    local button = self.clickToTauntButton
    if not button or not button:IsShown() or not button.tauntSpellId then
        return
    end

    local startTime, duration, enabled, modRate = GetSpellCooldownInfo(button.tauntSpellId)
    local cooldown = button.cooldown
    local remainingText = button.cooldownText

    if not startTime or not duration or not enabled then
        if cooldown then cooldown:Clear() end
        if remainingText then remainingText:SetText("") end
        if button.icon then button.icon:SetDesaturated(false) end
        return
    end

    -- Do not render the short global cooldown as the taunt cooldown.
    local active = startTime > 0 and duration > 1.6
    if not active then
        if cooldown then cooldown:Clear() end
        if remainingText then remainingText:SetText("") end
        if button.icon then button.icon:SetDesaturated(false) end
        return
    end

    if cooldown then
        cooldown:SetCooldown(startTime, duration, modRate or 1)
    end

    local remaining = math.max(0, (startTime + duration) - GetTime())
    if remainingText then
        if remaining >= 10 then
            remainingText:SetText(tostring(math.ceil(remaining)))
        elseif remaining > 0 then
            remainingText:SetText(string.format("%.1f", remaining))
        else
            remainingText:SetText("")
        end
    end

    if button.icon then
        button.icon:SetDesaturated(remaining > 0)
    end
end

local function GetSpellNameByID(spellId)
    if _G.C_Spell then
        if type(C_Spell.GetSpellName) == "function" then
            local ok, name = pcall(C_Spell.GetSpellName, spellId)
            if ok and type(name) == "string" and name ~= "" then
                return name
            end
        end

        if type(C_Spell.GetSpellInfo) == "function" then
            local ok, info = pcall(C_Spell.GetSpellInfo, spellId)
            if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
                return info.name
            end
        end
    end

    if type(_G.GetSpellInfo) == "function" then
        local ok, name = pcall(GetSpellInfo, spellId)
        if ok and type(name) == "string" and name ~= "" then
            return name
        end
    end

    return nil
end

local function IsKnownSpell(spellId)
    local checked = false

    if type(_G.IsPlayerSpell) == "function" then
        checked = true
        local ok, known = pcall(IsPlayerSpell, spellId)
        if ok and not FT:IsSecret(known) and known == true then
            return true
        end
    end

    if type(_G.IsSpellKnown) == "function" then
        checked = true
        local ok, known = pcall(IsSpellKnown, spellId)
        if ok and not FT:IsSecret(known) and known == true then
            return true
        end
    end

    if _G.C_SpellBook and type(C_SpellBook.IsSpellKnown) == "function" then
        checked = true
        local ok, known = pcall(C_SpellBook.IsSpellKnown, spellId)
        if ok and not FT:IsSecret(known) and known == true then
            return true
        end
    end

    -- Older Forever builds may not expose a known-spell helper.
    return not checked
end

function FT:GetPlayerTauntSpell()
    local _, classToken = UnitClass("player")
    if self:IsSecret(classToken) or not classToken then
        return nil, nil
    end

    local candidates = CLASS_TAUNTS[classToken]
    if not candidates then
        return nil, nil
    end

    for _, spellId in ipairs(candidates) do
        local spellName = GetSpellNameByID(spellId)
        if spellName and IsKnownSpell(spellId) then
            return spellId, spellName
        end
    end

    return nil, nil
end

function FT:SaveClickToTauntButtonPosition()
    local button = self.clickToTauntButton
    if not button or not self.db or IsInCombatLockdown() then
        return
    end

    local point, _, _, x, y = button:GetPoint(1)
    self.db.tauntButtonPoint = point or "CENTER"
    self.db.tauntButtonX = x or 0
    self.db.tauntButtonY = y or -180
end

function FT:RefreshClickToTauntButton()
    local button = self.clickToTauntButton
    if not button or not self.db then
        return
    end

    if IsInCombatLockdown() then
        self.clickToTauntPendingRefresh = true
        return
    end

    self.clickToTauntPendingRefresh = false

    local enabled = self.db.clickToTauntEnabled == true
    local spellId, spellName = self:GetPlayerTauntSpell()
    local sourceUnit = self.db.threatSource == "FOCUS" and "focus" or "target"

    button:ClearAllPoints()
    button:SetPoint(
        self.db.tauntButtonPoint or "CENTER",
        UIParent,
        self.db.tauntButtonPoint or "CENTER",
        self.db.tauntButtonX or 0,
        self.db.tauntButtonY or -180
    )

    if not enabled or not spellId or not spellName then
        button:SetAttribute("type2", nil)
        button:SetAttribute("spell2", nil)
        button:SetAttribute("unit2", nil)
        button.tauntSpellId = nil
        button.tauntSpellName = nil
        button.tauntSourceUnit = nil
        if button.icon then button.icon:SetTexture(nil) end
        if button.cooldown then button.cooldown:Clear() end
        if button.cooldownText then button.cooldownText:SetText("") end
        button:Hide()
        return
    end

    button:SetAttribute("type2", "spell")
    button:SetAttribute("spell2", spellName)
    button:SetAttribute("unit2", sourceUnit)
    button:SetAttribute("useOnKeyDown", false)
    button.tauntSpellId = spellId
    button.tauntSpellName = spellName
    button.tauntSourceUnit = sourceUnit
    button:SetText(self:L("TAUNT_BUTTON"))
    if button.icon then
        button.icon:SetTexture(GetSpellTextureByID(spellId))
    end
    button:Show()
    self:UpdateClickToTauntCooldown()
end

function FT:InitializeClickToTaunt()
    if self.clickToTauntButton then
        self:RefreshClickToTauntButton()
        return
    end

    if IsInCombatLockdown() then
        self.clickToTauntPendingInit = true
        return
    end

    local button = CreateFrame(
        "Button",
        "ForeverThreatSecureTauntButton",
        UIParent,
        "SecureActionButtonTemplate,UIPanelButtonTemplate"
    )

    self.clickToTauntButton = button
    button:SetSize(138, 32)
    button:SetFrameStrata("HIGH")
    button:SetClampedToScreen(true)
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForClicks("RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:Hide()

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(26, 26)
    icon:SetPoint("LEFT", button, "LEFT", 4, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon = icon

    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints(icon)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawBling(false)
    cooldown:SetHideCountdownNumbers(true)
    button.cooldown = cooldown

    local cooldownText = cooldown:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cooldownText:SetPoint("CENTER", cooldown, "CENTER", 0, 0)
    cooldownText:SetText("")
    cooldownText:SetTextColor(1, 1, 1)
    cooldownText:SetShadowOffset(1, -1)
    button.cooldownText = cooldownText

    button:SetScript("OnDragStart", function(self)
        if IsInCombatLockdown() then
            return
        end
        self:StartMoving()
    end)

    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        FT:SaveClickToTauntButtonPosition()
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(FT:L("TAUNT_BUTTON"), 1.0, 0.55, 0.16)
        GameTooltip:AddLine(FT:L("CLICK_TO_TAUNT_TOOLTIP"), 1, 1, 1, true)

        if self.tauntSpellName then
            GameTooltip:AddLine(
                FT:L("CLICK_TO_TAUNT_SPELL", self.tauntSpellName),
                0.82, 0.82, 0.82
            )
        end

        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self:RefreshClickToTauntButton()
end

local cooldownUpdater = CreateFrame("Frame")
cooldownUpdater.elapsed = 0
cooldownUpdater:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed < 0.10 then
        return
    end

    self.elapsed = 0
    if FT.clickToTauntButton and FT.clickToTauntButton:IsShown() then
        FT:UpdateClickToTauntCooldown()
    end
end)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:SetScript("OnEvent", function(_, event)
    if not FT.db then
        return
    end

    if event == "PLAYER_REGEN_ENABLED" and FT.clickToTauntPendingInit then
        FT.clickToTauntPendingInit = false
        FT:InitializeClickToTaunt()
        return
    end

    if IsInCombatLockdown() then
        FT.clickToTauntPendingRefresh = true
        return
    end

    if FT.clickToTauntButton then
        FT:RefreshClickToTauntButton()
    end
end)
