local addonName, FT = ...

local DISCORD_SUPPORT_LINK = "https://discord.gg/srPrK7QWGb"

local function AddToSpecialFrames(frameName)
    if not frameName or type(_G.UISpecialFrames) ~= "table" then
        return
    end

    for _, name in ipairs(UISpecialFrames) do
        if name == frameName then
            return
        end
    end

    table.insert(UISpecialFrames, frameName)
end

function FT:ApplySupportSkin()
    local frame = self.supportFrame
    if not frame or not self.GetSkinPalette then
        return
    end

    local skin = self:GetSkinPalette()
    local bg = skin.background
    local border = skin.border
    local title = skin.title
    local divider = skin.divider or skin.border

    frame:SetBackdropColor(bg[1], bg[2], bg[3], 0.99)
    frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)

    if frame.title then
        frame.title:SetTextColor(title[1], title[2], title[3])
    end

    if frame.divider then
        frame.divider:SetColorTexture(divider[1], divider[2], divider[3], divider[4] or 0.8)
    end
end

function FT:RaiseSupportWindow()
    local frame = self.supportFrame
    if not frame then
        return
    end

    -- This window deliberately uses a higher, unprotected strata than the
    -- addon configuration so it can never be hidden behind ForeverThreat.
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(250)

    if frame.SetToplevel then
        pcall(frame.SetToplevel, frame, true)
    end

    if frame.Raise then
        pcall(frame.Raise, frame)
    end
end

function FT:SelectSupportLink()
    local box = self.supportLinkBox
    if not box then
        return
    end

    box._restoringLink = true
    box:SetText(DISCORD_SUPPORT_LINK)
    box._restoringLink = false
    box:SetFocus()
    box:HighlightText()
end

function FT:RefreshSupportLocale()
    local frame = self.supportFrame
    if not frame then
        return
    end

    if frame.title then
        frame.title:SetText(self:L("SUPPORT_TITLE"))
    end
    if frame.description then
        frame.description:SetText(self:L("SUPPORT_DESCRIPTION"))
    end
    if frame.copyHint then
        frame.copyHint:SetText(self:L("SUPPORT_COPY_HINT"))
    end
    if frame.selectButton then
        frame.selectButton:SetText(self:L("SUPPORT_SELECT_LINK"))
    end
end

function FT:CloseSupportWindow()
    local frame = self.supportFrame
    if not frame then
        return
    end

    if self.supportLinkBox then
        self.supportLinkBox:ClearFocus()
    end

    frame:Hide()
end

function FT:CreateSupportUI()
    if self.supportFrame then
        return
    end

    local frame = CreateFrame("Frame", "ForeverThreatSupportFrame", UIParent, "BackdropTemplate")
    self.supportFrame = frame

    frame:SetSize(520, 255)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 70)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(250)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:Hide()

    if frame.SetToplevel then
        pcall(frame.SetToplevel, frame, true)
    end

    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })

    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
        FT:RaiseSupportWindow()
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        FT:RaiseSupportWindow()
    end)

    frame:SetScript("OnMouseDown", function()
        FT:RaiseSupportWindow()
    end)

    frame:SetScript("OnShow", function()
        FT:RefreshSupportLocale()
        FT:ApplySupportSkin()
        FT:RaiseSupportWindow()
        FT:SelectSupportLink()
    end)

    frame:SetScript("OnHide", function()
        if FT.supportLinkBox then
            FT.supportLinkBox:ClearFocus()
        end
    end)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -16)
    frame.title = title

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3)
    close:SetScript("OnClick", function()
        FT:CloseSupportWindow()
    end)

    local divider = frame:CreateTexture(nil, "BORDER")
    divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -45)
    divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -45)
    divider:SetHeight(1)
    frame.divider = divider

    local description = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    description:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -62)
    description:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -62)
    description:SetJustifyH("LEFT")
    description:SetJustifyV("TOP")
    description:SetWordWrap(true)
    frame.description = description

    local linkBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    linkBox:SetSize(474, 30)
    linkBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -132)
    linkBox:SetAutoFocus(false)
    linkBox:SetFontObject("ChatFontNormal")
    linkBox:SetTextInsets(7, 7, 0, 0)
    linkBox:SetMaxLetters(#DISCORD_SUPPORT_LINK)
    linkBox:SetText(DISCORD_SUPPORT_LINK)
    frame.linkBox = linkBox
    self.supportLinkBox = linkBox

    linkBox:SetScript("OnEscapePressed", function()
        FT:CloseSupportWindow()
    end)

    linkBox:SetScript("OnEnterPressed", function()
        FT:SelectSupportLink()
    end)

    linkBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
        FT:RaiseSupportWindow()
    end)

    linkBox:SetScript("OnTextChanged", function(self, userInput)
        if self._restoringLink or not userInput then
            return
        end

        if self:GetText() ~= DISCORD_SUPPORT_LINK then
            self._restoringLink = true
            self:SetText(DISCORD_SUPPORT_LINK)
            self._restoringLink = false
            self:HighlightText()
        end
    end)

    local copyHint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    copyHint:SetPoint("TOPLEFT", linkBox, "BOTTOMLEFT", 1, -7)
    copyHint:SetTextColor(0.72, 0.72, 0.72)
    frame.copyHint = copyHint

    local selectButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    selectButton:SetSize(170, 26)
    selectButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 18)
    selectButton:SetScript("OnClick", function()
        FT:SelectSupportLink()
        FT:RaiseSupportWindow()
    end)
    frame.selectButton = selectButton

    AddToSpecialFrames(frame:GetName())
    self:RefreshSupportLocale()
    self:ApplySupportSkin()
end

function FT:OpenSupportWindow()
    self:CreateSupportUI()

    if not self.supportFrame then
        return
    end

    self:RefreshSupportLocale()
    self:ApplySupportSkin()
    self.supportFrame:Show()
    self:RaiseSupportWindow()
    self:SelectSupportLink()
end
