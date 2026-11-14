local addonName, FT = ...

local LDB = LibStub("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")

function FT:CreateMinimapButton()
    if self.minimapRegistered then
        return
    end

    self.db.minimap = self.db.minimap or {
        hide = false,
        minimapPos = self.db.minimapAngle or 220,
    }

    local launcher = LDB:GetDataObjectByName("ForeverThreat")

    if not launcher then
        launcher = LDB:NewDataObject("ForeverThreat", {
            type = "launcher",
            icon = "Interface\\AddOns\\ForeverThreat\\Media\\MinimapButton",

            OnClick = function(_, button)
                if button == "LeftButton" then
                    FT:Toggle()
                elseif button == "MiddleButton" then
                    if FT.OpenConfig then
                        FT:OpenConfig()
                    end
                elseif button == "RightButton" then
                    FT:SetLocked(not FT.db.locked)
                end
            end,

            OnTooltipShow = function(tooltip)
                tooltip:AddLine("ForeverThreat", 1.0, 0.55, 0.16)
                tooltip:AddLine(FT:L("MINIMAP_LEFT"), 1, 1, 1)
                tooltip:AddLine(FT:L("MINIMAP_MIDDLE"), 1, 1, 1)
                tooltip:AddLine(FT:L("MINIMAP_RIGHT"), 1, 1, 1)
                tooltip:AddLine(FT:L("MINIMAP_DRAG"), 0.8, 0.8, 0.8)
            end,
        })
    end

    self.ldbLauncher = launcher
    self.ldbIcon = LDBIcon
    self.minimapLib = LDBIcon

    if not LDBIcon:IsRegistered("ForeverThreat") then
        LDBIcon:Register("ForeverThreat", launcher, self.db.minimap)
    else
        LDBIcon:Refresh("ForeverThreat", self.db.minimap)
    end

    self.minimapButton = LDBIcon:GetMinimapButton("ForeverThreat")
    self.minimapRegistered = true

    self:RefreshMinimapButton()
end

function FT:SetMinimapVisible(visible)
    if not self.db then
        return
    end

    self.db.showMinimapButton = visible and true or false
    self:RefreshMinimapButton()
end

function FT:RefreshMinimapButton()
    if not self.ldbIcon or not self.db then
        return
    end

    self.db.minimap = self.db.minimap or {}

    if self.db.showMinimapButton == false then
        self.db.minimap.hide = true
        self.ldbIcon:Hide("ForeverThreat")
    else
        self.db.minimap.hide = false
        self.ldbIcon:Show("ForeverThreat")
    end
end
