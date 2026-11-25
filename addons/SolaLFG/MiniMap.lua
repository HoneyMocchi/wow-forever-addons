-- SolaLFG Minimap Button
-- Based on the Hit Assist minimap button

SolaFP_Minimap_Save = {
	ButtonRadius = 78,
	ButtonShown = true,
	ButtonPosition = 336,
	Angle = 0}     -- table, SavedVariable, can't be local

CreateFrame("Button", "SolaFP_Minimap_Button", Minimap)

SolaFP_Minimap_Button:EnableMouse(true)
SolaFP_Minimap_Button:SetMovable(false)
SolaFP_Minimap_Button:SetFrameStrata("LOW")
SolaFP_Minimap_Button:SetWidth(33)
SolaFP_Minimap_Button:SetHeight(33)
SolaFP_Minimap_Button:SetPoint("TOPLEFT", Minimap, "LEFT", 2, 0)
SolaFP_Minimap_Button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

SolaFP_Minimap_Button:CreateTexture("SolaFP_Minimap_ButtonIcon", "BORDER")
SolaFP_Minimap_ButtonIcon:SetWidth(20)
SolaFP_Minimap_ButtonIcon:SetHeight(20)
SolaFP_Minimap_ButtonIcon:SetPoint("CENTER", -2, 1)
SolaFP_Minimap_ButtonIcon:SetTexture("Interface\\AddOns\\SolaLFG\\SIM-Icon") --INV_Misc_Bag_10_Blue

SolaFP_Minimap_Button:CreateTexture("SolaFP_Minimap_ButtonBorder", "OVERLAY")
SolaFP_Minimap_ButtonBorder:SetWidth(52)
SolaFP_Minimap_ButtonBorder:SetHeight(52)
SolaFP_Minimap_ButtonBorder:SetPoint("TOPLEFT")
SolaFP_Minimap_ButtonBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

function SolaFP_Minimap_Button_Init()
	
	SolaFP_Minimap_Save.ButtonRadius = SolaFP_Minimap_Save.ButtonRadius or 78
	SolaFP_Minimap_Save.ButtonPosition = SolaFP_Minimap_Save.ButtonPosition or 345
	SolaFP_Minimap_Button_UpdatePosition()
end

function SolaFP_Minimap_Button_UpdatePosition()
	SolaFP_Minimap_Button:SetPoint(
		"TOPLEFT",
		"Minimap",
		"TOPLEFT",
		54 - (SolaFP_Minimap_Save.ButtonRadius * cos(SolaFP_Minimap_Save.ButtonPosition)),
		(SolaFP_Minimap_Save.ButtonRadius * sin(SolaFP_Minimap_Save.ButtonPosition)) - 55
	)
end

-- Thanks to Yatlas for this code
function SolaFP_Minimap_Button_BeingDragged()
	-- Thanks to Gello for this code
	local xpos,ypos = GetCursorPosition()
	local xmin,ymin = Minimap:GetLeft(), Minimap:GetBottom()

	xpos = xmin-xpos/UIParent:GetScale()+70
	ypos = ypos/UIParent:GetScale()-ymin-70

	local v = math.deg(math.atan2(ypos, xpos))
	if v < 0 then
		v = v + 360
	end
	SolaFP_Minimap_Save.ButtonPosition = v
	SolaFP_Minimap_Button_UpdatePosition()

end

SolaFP_Minimap_Button:RegisterEvent("VARIABLES_LOADED")
SolaFP_Minimap_Button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
SolaFP_Minimap_Button:RegisterForDrag("LeftButton")
SolaFP_Minimap_Button:SetScript("OnDragStart", function(self)
	self:SetScript("OnUpdate", SolaFP_Minimap_Button_BeingDragged)
end)
SolaFP_Minimap_Button:SetScript("OnDragStop", function(self)
	self:SetScript("OnUpdate", nil)
end)
SolaFP_Minimap_Button:SetScript("OnClick", function(self, button)
	SolaFP_IconClicked(self, button);
end)
SolaFP_Minimap_Button:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT");
	local msg = "|cff00ff00왼쪽 클릭: |r파티찾기 도우미 열기";
	msg = msg.."\n|cff00ff00오른쪽 클릭: |r옵션";
	msg = msg.."\n|cff00ff00왼쪽 누르고 드래그 : |r아이콘이동";
	msg = msg.."\n|cff00ff00Alt + 왼쪽 클릭: |r아이콘 고정/해제";
	msg = msg.."\n|cff00ff00Ctrl + 왼쪽 클릭: |r광고 시작/정지";
	msg = msg.."\n|cff00ff00Shift + 왼쪽 클릭: |r기능 정지/작동";
	msg = msg.."\n ";
	msg = msg.."\n현재:";
	if (SolaFP_IsActivated()) then
		msg = msg.." 작동중";
	else
		msg = msg.." 작동정지";
	end

	if (SolaFP_IsAnnoucing and SolaFP_IsAnnoucing()) then
		msg = msg.." 광고중 "
	end

	if (SolaFP_Options.iconLocked) then
		msg = msg.." 아이콘고정"
	end
	GameTooltip:AddLine(msg);
	GameTooltip:Show();
end)
SolaFP_Minimap_Button:SetScript("OnLeave", function(self)
	GameTooltip:Hide();
end)
SolaFP_Minimap_Button:SetScript("OnEvent", SolaFP_Minimap_Button_Init)
