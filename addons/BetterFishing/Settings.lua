local addonName = ...
local BetterFishing = {}

-- 한국어 클라이언트에서만 표시 문구를 바꾼다. 옵션 키/기능은 원본과 동일하다.
-- 다른 언어에서는 전달받은 영문을 그대로 사용하므로 기존 동작에 영향을 주지 않는다.
local isKorean = GetLocale() == "koKR"
local translations = {
  ["Better Fishing"] = "Better Fishing · 낚시 도우미",
  ["Always Auto Loot fishing loot (Ignores Settings)"] = "낚시 전리품 항상 자동 획득 (게임 설정 무시)",
  ["Auto-Hide NPC Nameplates and Names (except Hostile) while fishing"] = "낚시 중 NPC 이름·이름표 숨기기 (적대적 NPC 제외)",
  ["Enhance Sounds"] = "낚시 소리 강조",
  ["Double-click to cast"] = "우클릭 더블클릭으로 낚싯줄 던지기",
  ["Allow double-clicking to cast while mounted"] = "탈것에 탄 상태에서도 더블클릭 낚시 허용",
  ["Double-click to recast while fishing (modifier key hooks); inverted when off"] = "낚시 중 더블클릭으로 다시 던지기 (보조키와 함께 누르면 반대 동작)",
  ["Allow fishing while the \"Looking for Lunkers\" (Dragonflight) buff is active"] = "용군단의 \"Looking for Lunkers\" 강화 효과 중에도 낚시 허용",
  ["Disable icon above bobber (visibility varies by nameplate addon)"] = "찌 위의 아이콘 숨기기 (이름표 애드온에 따라 다름)",
}
local function L(text)
  return isKorean and translations[text] or text
end


EventUtil.ContinueOnAddOnLoaded(addonName, function()
  BetterFishingDB = BetterFishingDB or {};
  BetterFishingDB.doubleClickSpeed = BetterFishingDB.doubleClickSpeed or 0.2
  BetterFishing:CreateSettings()
end)

function BetterFishing:CreateSettings()
  local optionsFrame = CreateFrame("Frame", nil, nil, "VerticalLayoutFrame")
  optionsFrame.spacing = 4
  local category, layout = Settings.RegisterCanvasLayoutCategory(optionsFrame, L("Better Fishing") .. " |TInterface/AddOns/BetterFishing/fishingicon.blp:18:18:0:0|t");
  self.CategoryID = category:GetID()
  Settings.RegisterAddOnCategory(category);

  local layoutIndex = 0
  local function GetLayoutIndex()
    layoutIndex = layoutIndex + 1
    return layoutIndex
  end

  ---@class Header : Frame
  local Header = CreateFrame("Frame", nil, optionsFrame)
  Header:SetSize(150, 50)
  local headerText = Header:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
  headerText:SetPoint("TOPLEFT", 7, -22)
  headerText:SetText(L("Better Fishing"))
  local divider = Header:CreateTexture(nil, "ARTWORK")
  divider:SetAtlas("Options_HorizontalDivider", true)
  divider:SetPoint("BOTTOMLEFT", -50)
  Header.layoutIndex = GetLayoutIndex()
  Header.bottomPadding = 10
  local function makeCheckButton(text)
    ---@class checkButton : CheckButton
    local checkButton = CreateFrame("CheckButton", nil, optionsFrame, "SettingsCheckBoxTemplate")
    checkButton.text = checkButton:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    checkButton.text:SetText(text)
    checkButton.text:SetPoint("LEFT", checkButton, "RIGHT", 4, 0)
    checkButton:SetSize(21, 20)
    checkButton.HoverBackground = nil
    return checkButton
  end

  local settingsInfo = {
    { option = "autoLoot", detail = L("Always Auto Loot fishing loot (Ignores Settings)") },
    { option = "hideNamePlates", detail = L("Auto-Hide NPC Nameplates and Names (except Hostile) while fishing") },
    { option = "enhanceSounds", detail = L("Enhance Sounds"), optionType = "soundSlider" },
    { option = "doubleClickEnabled", detail = L("Double-click to cast"), optionType = "speedSlider" },
    { option = "doubleClickForce", detail = L("Allow double-clicking to cast while mounted"), dependency = "doubleClickEnabled" },
    { option = "recastOnDoubleClick", detail = L("Double-click to recast while fishing (modifier key hooks); inverted when off") },
    { option = "overrideLunker", detail = L("Allow fishing while the \"Looking for Lunkers\" (Dragonflight) buff is active"), minExpansion = LE_EXPANSION_DRAGONFLIGHT },
    { option = "objectIconDisabled", detail = L("Disable icon above bobber (visibility varies by nameplate addon)"), minExpansion = LE_EXPANSION_DRAGONFLIGHT },
  }

  local options = {}

  local function UpdateDependencies()
    for _, keyInfo in ipairs(settingsInfo) do
      if keyInfo.dependency and options[keyInfo.option] then
        local option = options[keyInfo.option]
        local isDependencyEnabled = BetterFishingDB[keyInfo.dependency]
        if isDependencyEnabled then
          option.button:Enable()
          option.button.text:SetFontObject("GameFontNormal")
        else
          option.button:Disable()
          option.button.text:SetFontObject("GameFontDisable")
        end
      end
    end
  end

  for _, keyInfo in ipairs(settingsInfo) do
    if not keyInfo.minExpansion or LE_EXPANSION_LEVEL_CURRENT >= keyInfo.minExpansion then
      local checkButton = makeCheckButton(keyInfo.detail)
      checkButton.layoutIndex = GetLayoutIndex()
      keyInfo.ref = checkButton.text
      checkButton:SetHitRectInsets(0, -checkButton.text:GetWidth(), 0, 0)
      checkButton:SetChecked(BetterFishingDB[keyInfo.option])
      options[keyInfo.option] = { button = checkButton }
      checkButton:SetScript("OnClick", function()
        BetterFishingDB[keyInfo.option] = not BetterFishingDB[keyInfo.option]
        checkButton:SetChecked(BetterFishingDB[keyInfo.option])
        UpdateDependencies()
      end)

      if keyInfo.optionType == "soundSlider" then
        local function FormatPercentageRound(value)
          return FormatPercentage(value, true);
        end

        local right = MinimalSliderWithSteppersMixin.Label.Right
        local formatters = {}
        formatters[right] = CreateMinimalSliderFormatter(right, FormatPercentageRound);
        local slider = CreateFrame("Slider", nil, optionsFrame, "MinimalSliderWithSteppersTemplate")
        slider:Init(BetterFishingDB.enhanceSoundsScale or 1, 0, 1, 20, formatters)
        slider:SetPoint("LEFT", checkButton.text, "RIGHT", 10, 0)
        slider:SetHeight(26)
        local function OnValueChanged(_, value)
          BetterFishingDB.enhanceSoundsScale = value
        end
        slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, OnValueChanged)

        options[keyInfo.option].slider = slider
      elseif keyInfo.optionType == "speedSlider" then
        local function RoundTo(value)
          return Round(value / 0.05) * 0.05 .. (isKorean and "초" or "s");
        end

        local right = MinimalSliderWithSteppersMixin.Label.Right
        local formatters = {}
        formatters[right] = CreateMinimalSliderFormatter(right, RoundTo);
        local slider = CreateFrame("Slider", nil, optionsFrame, "MinimalSliderWithSteppersTemplate")
        slider:Init(BetterFishingDB.doubleClickSpeed or 0.2, 0.1, 0.8, 12, formatters)
        slider:SetPoint("LEFT", checkButton.text, "RIGHT", 10, 0)
        slider:SetHeight(26)
        local function OnValueChanged(_, value)
          BetterFishingDB.doubleClickSpeed = value
        end
        slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, OnValueChanged)

        options[keyInfo.option].slider = slider
      end
    end
  end

  UpdateDependencies()

  optionsFrame:Layout()
end

SLASH_BETTERFISHING1, SLASH_BETTERFISHING2 = '/bf', '/betterfishing'
SlashCmdList.BETTERFISHING = function(msg)
  Settings.OpenToCategory(BetterFishing.CategoryID)
end