-- Better Fishing용 장비 전환 버튼. 낚시 시전/기존 설정은 변경하지 않는다.
-- 장비 변경은 사용자가 이 버튼을 누른 순간, 비전투 상태에서만 실행한다.
-- 주무기·보조무기는 캐릭터별로 저장하므로 /reload 후에도 원래 장비로 돌아갈 수 있다.
local frame = CreateFrame("Frame")
local button, state
local MAIN, OFF = 16, 17
local BAG_COUNT = NUM_BAG_SLOTS or 4

local function Say(text)
  DEFAULT_CHAT_FRAME:AddMessage("|cffEEE4AEBetter Fishing:|r " .. text)
end

local function Guid(location)
  if not location or not C_Item.GetItemGUID then return nil end
  local ok, value = pcall(C_Item.GetItemGUID, location)
  return ok and value or nil
end

local function Equipment(slot)
  local link = GetInventoryItemLink("player", slot)
  if not link then return false end -- 빈 슬롯도 명시적으로 기억한다.
  local location = ItemLocation and ItemLocation:CreateFromEquipmentSlot(slot)
  return { link = link, id = GetInventoryItemID("player", slot), guid = Guid(location) }
end

local function BagItem(bag, slot)
  local info = C_Container.GetContainerItemInfo(bag, slot)
  if not info then return nil end
  local location = ItemLocation and ItemLocation:CreateFromBagAndSlot(bag, slot)
  return { bag = bag, slot = slot, link = info.hyperlink, id = info.itemID,
    guid = Guid(location), locked = info.isLocked }
end

local function Same(left, right)
  if not left or not right then return not left and not right end
  -- GUID가 있으면 같은 이름/ID의 다른 개체를 대신 장착하지 않는다.
  if left.guid and right.guid then return left.guid == right.guid end
  return left.link == right.link
end

local function FindItem(wanted)
  if not wanted then return nil end
  for bag = 0, BAG_COUNT do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local item = BagItem(bag, slot)
      if item and Same(wanted, item) then return item end
    end
  end
end

local function IsPole(item)
  if not item then return false end
  local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(item.link or item.id)
  return classID == Enum.ItemClass.Weapon and subclassID == Enum.ItemWeaponSubclass.Fishingpole
end

local function FindPole()
  local remembered = FindItem(state.pole)
  if remembered and IsPole(remembered) then return remembered end
  for bag = 0, BAG_COUNT do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local item = BagItem(bag, slot)
      if item and not item.locked and IsPole(item) then return item end
    end
  end
end

local function FreeSlot()
  -- 화살통/전문 가방에는 무기를 넣지 못할 수 있다. 일반 가방의 빈칸만 선택한다.
  for bag = 0, BAG_COUNT do
    local free, family = C_Container.GetContainerNumFreeSlots(bag)
    if free and free > 0 and family == 0 then
      for slot = 1, C_Container.GetContainerNumSlots(bag) do
        if not C_Container.GetContainerItemInfo(bag, slot) then return bag, slot end
      end
    end
  end
end

local function PutOn(item, slot)
  if item.locked or (IsInventoryItemLocked and IsInventoryItemLocked(slot)) then
    Say("장비가 이동 중입니다. 잠시 후 다시 눌러주세요.")
    return false
  end
  -- 가방에서 정확한 개체를 집어 지정 슬롯과 교환한다. 밀려난 장비가 커서에
  -- 남으면 출발 가방 칸에 넣는다. 커서에 아이템을 버리거나 삭제하는 동작은 없다.
  C_Container.PickupContainerItem(item.bag, item.slot)
  if not CursorHasItem() then return false end
  EquipCursorItem(slot)
  if CursorHasItem() then
    -- 양손 낚싯대를 끼우면서 보조무기가 출발 칸에 먼저 들어올 수 있다.
    -- 그 경우 다른 빈 일반 가방 칸을 사용하여 보조무기를 다시 집어 들지 않는다.
    local bag, free = item.bag, item.slot
    if C_Container.GetContainerItemInfo(bag, free) then bag, free = FreeSlot() end
    if bag then C_Container.PickupContainerItem(bag, free) end
  end
  if CursorHasItem() then ClearCursor() end -- 실패 시 원위치로 돌려놓는다.
  return true
end

local function RestoreSlot(slot, wanted)
  if Same(Equipment(slot), wanted) then return true end
  if wanted then
    local item = FindItem(wanted) -- 앞 슬롯 교환으로 가방 위치가 바뀔 수 있어 다시 찾는다.
    if not item then return false end
    return PutOn(item, slot)
  end
  local bag, free = FreeSlot()
  if not bag then Say("빈 슬롯으로 복귀하려면 일반 가방에 빈칸이 필요합니다."); return false end
  PickupInventoryItem(slot)
  if CursorHasItem() then C_Container.PickupContainerItem(bag, free) end
  if CursorHasItem() then ClearCursor() end
  return true
end

local function Restored()
  return state and state.saved and Same(Equipment(MAIN), state.saved.main)
    and Same(Equipment(OFF), state.saved.off)
end

local function Update()
  if not button or not state then return end
  -- 장착 요청 직후에는 서버/클라이언트 장비 조회가 잠깐 원래 무기를 반환한다.
  -- 이 순간을 '복귀 완료'로 판단하면 원래 장비 기록이 지워진다. 명시적으로
  -- 복귀를 요청한 단계에서만 기록을 정리하고, 낚싯대 전환 단계에서는 보존한다.
  if state.active and state.phase == "entering" and IsPole(Equipment(MAIN)) then
    state.phase = "fishing"
  elseif state.active and state.phase == "restoring" and Restored() then
    state.active, state.saved, state.phase = nil, nil, nil
  end
  button.icon:SetTexture(state.active and "Interface\\Icons\\INV_Sword_04"
    or "Interface\\AddOns\\BetterFishing\\fishingicon.blp")
  button.icon:SetDesaturated(InCombatLockdown() and true or false)
end

local function Toggle()
  if not state then return end
  if InCombatLockdown() then Say("전투가 끝난 뒤 장비 전환 버튼을 눌러주세요."); return end
  if GetCursorInfo() then Say("커서에 든 아이템을 먼저 내려놓으세요."); return end
  local channel, _, _, _, _, _, _, channelID = UnitChannelInfo("player")
  if UnitCastingInfo("player") then
    Say("주문 시전을 끝낸 뒤 눌러주세요."); return
  end
  if channel then
    -- 복귀 버튼을 누르는 행위 자체를 낚시 종료 의도로 취급한다. 다른 집중 주문은
    -- 중단하지 않으며, 장비를 바꾸기 위해 사용자에게 별도 취소 클릭을 요구하지 않는다.
    local fishingName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(7620)
    local fishing = channelID == 7620 or channelID == 7731 or channelID == 7732
      or channelID == 18248 or channelID == 131474 or channelID == 131476
      or channelID == 131490 or (fishingName and channel == fishingName)
    if state.active and state.saved and fishing and SpellStopCasting then
      SpellStopCasting()
    else
      Say("낚시나 주문 시전을 끝낸 뒤 눌러주세요."); return
    end
  end
  if state.active and state.saved then
    -- 저장된 두 슬롯의 장비가 모두 있는지 먼저 검증한다. 하나가 은행/우편에
    -- 있으면 일부만 교체하지 않고 기존 복귀 기록을 보존한다.
    for _, slot in ipairs({ MAIN, OFF }) do
      local wanted
      if slot == MAIN then wanted = state.saved.main else wanted = state.saved.off end
      if wanted and not Same(Equipment(slot), wanted) and not FindItem(wanted) then
        Say("기억한 장비를 가방에서 찾지 못했습니다. 장비를 가져온 뒤 다시 눌러주세요.")
        return
      end
    end
    -- 장비 변경 이벤트가 중간에 발생해도 복귀 대상을 잃지 않도록 지역 참조를 유지한다.
    local saved = state.saved
    state.phase = "restoring"
    if not RestoreSlot(MAIN, saved.main) then return end
    if not RestoreSlot(OFF, saved.off) then return end
    Update()
    if state.active then Say("장비 변경 중입니다. 복귀가 남아 있으면 한 번 더 눌러주세요.") end
  else
    local current = Equipment(MAIN)
    if IsPole(current) then
      state.pole = current
      Say("이미 낚싯대를 장착 중입니다. 원래 무기를 먼저 장착하면 다음 전환부터 기억합니다.")
      return
    end
    local pole = FindPole()
    if not pole then Say("가방에서 낚싯대를 찾지 못했습니다."); return end
    -- 양손 낚싯대를 끼우면 보조무기도 가방으로 이동한다. 먼저 공간을 확보한다.
    if Equipment(OFF) and not FreeSlot() then Say("보조무기를 보관할 일반 가방 빈칸을 1개 확보해주세요."); return end
    state.saved = { main = current, off = Equipment(OFF) }
    state.pole = { link = pole.link, id = pole.id, guid = pole.guid }
    state.active = true -- 장착 실패/재접속 시에도 원래 장비 기록은 덮어쓰지 않는다.
    state.phase = "entering"
    PutOn(pole, MAIN)
    Update()
  end
end

local function Initialize()
  if button then return end
  local key = UnitGUID("player")
  if not key then return end
  BetterFishingDB = BetterFishingDB or {}
  BetterFishingDB.weaponSwap = BetterFishingDB.weaponSwap or {}
  BetterFishingDB.weaponSwap[key] = BetterFishingDB.weaponSwap[key] or {}
  state = BetterFishingDB.weaponSwap[key]
  button = CreateFrame("Button", "BetterFishingWeaponSwapButton", UIParent)
  button:SetSize(28, 28)
  button:SetClampedToScreen(true)
  button:SetMovable(true)
  button:RegisterForClicks("LeftButtonUp")
  button:RegisterForDrag("LeftButton")
  if state.x and state.y then
    button:SetPoint("CENTER", UIParent, "BOTTOMLEFT", state.x, state.y)
  else
    button:SetPoint("TOPRIGHT", Minimap, "BOTTOMLEFT", 0, 0)
  end
  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetPoint("TOPLEFT", 2, -2)
  button.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  button:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
  button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  button:SetScript("OnClick", function()
    if button.draggedAt and GetTime() - button.draggedAt < 0.3 then return end
    Toggle()
  end)
  -- Shift+드래그만 이동으로 취급하여 평소 클릭과 구분한다. 위치는 캐릭터별 저장한다.
  button:SetScript("OnDragStart", function()
    if IsShiftKeyDown() and not InCombatLockdown() then button:StartMoving(); button.moving = true end
  end)
  button:SetScript("OnDragStop", function()
    if not button.moving then return end
    button:StopMovingOrSizing()
    button.moving, button.draggedAt = nil, GetTime()
    state.x, state.y = button:GetCenter()
  end)
  button:SetScript("OnEnter", function()
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText("Better Fishing · 장비 전환")
    GameTooltip:AddLine(state.active and "클릭: 원래 주무기·보조무기로 복귀" or "클릭: 현재 무기를 기억하고 낚싯대 장착", 1, 1, 1, true)
    if state.saved then
      GameTooltip:AddLine("주무기: " .. (state.saved.main and state.saved.main.link or "빈 슬롯"), 0.8, 0.8, 0.8, true)
      GameTooltip:AddLine("보조무기: " .. (state.saved.off and state.saved.off.link or "빈 슬롯"), 0.8, 0.8, 0.8, true)
    end
    GameTooltip:AddLine("Shift+드래그: 위치 이동", 0.6, 0.8, 1)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
  Update()
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then Initialize() else Update() end
end)
if IsLoggedIn() then Initialize() end
