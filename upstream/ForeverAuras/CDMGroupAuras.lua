-- Copyright (C) 2026 ForeverAuras. Part of ForeverAuras, licensed under the GNU GPL v2 (see LICENSE).
if not WeakAuras.IsLibsOK() then return end
local _, Private = ...
local Group = {}
Private.CDMGroupAuras = Group
local Display = Private.BlizzardAuraDisplay
local key = "FA Group Auras"
-- ForeverAuras (1.4.7-dev.15, Dan: the selector "should work" as the Cooldown trigger's does: a list
-- of the entries with a tick box each): a trigger can follow chosen group auras
-- (trigger.cdmGroupSpells, a set of the entries' spell IDs) in place of the whole list. Nothing
-- ticked follows the whole list, as before. Each distinct choice gets a Spell List of its own, named
-- with this prefix and the chosen spell IDs in order, published the same way as the whole list. A
-- ticked spell is followed whether or not it is under Not Displayed: it was picked by hand.
-- loaded[id] is the list key the display uses; published[key] is the ID list last published under
-- that key. (dev.14 stored one spell in trigger.cdmGroupSpell; Prepare turns it into the set.)
local prefix = key .. ": "
local loaded, queued, published, dirty = {}, false, {}, true
local currentIDs, currentEntries
local CreateFrame = Private.TimedAPI("CDMGroupAuras")
local frame = CreateFrame("Frame")
local events = {"PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "PLAYER_SPECIALIZATION_CHANGED", "COOLDOWN_VIEWER_DATA_LOADED", "COOLDOWN_VIEWER_TABLE_HOTFIXED", "COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED"}

function Group.IsTrigger(trigger)
  return type(trigger) == "table" and trigger.type == "secretAura" and trigger.cdmGroupAuras == true
end

function Group.UsesList(trigger)
  if type(trigger) ~= "table" or trigger.type ~= "secretAura" or type(trigger.secretSpellList) ~= "string" then return false end
  return trigger.secretSpellList == key or trigger.secretSpellList:sub(1, #prefix) == prefix
end

local function Public(value)
  return not (issecretvalue and issecretvalue(value))
end

local function SpellID(value)
  return Public(value) and type(value) == "number" and value > 0 and value < 2147483647 and value == math.floor(value)
end

-- ForeverAuras (1.4.7-dev.25, Astra's dev.23 review): which catalog entries are debuffs. The game's
-- list has no such field, and C_Spell.IsSpellHarmful (dev.23, dev.24) answers a different question,
-- whether the spell can be cast on an enemy: it is false for Weakened Soul (seen in Dan's earlier
-- "/fa cdm" report). So this is a short list of entries seen to be debuffs in game, nothing
-- inferred: 6788 Weakened Soul (Dan's "/fa groupauras" printout listed it under HARMFUL).
local debuffEntries = {[6788] = true}
function Group.IsDebuffEntry(spell)
  return debuffEntries[tonumber(spell) or 0] == true
end

-- Whether the trigger's ticked entries are debuff entries only (at least one, and no buff).
function Group.DebuffOnly(trigger)
  if type(trigger) ~= "table" or type(trigger.cdmGroupSpells) ~= "table" then return false end
  local any = false
  for spell, on in pairs(trigger.cdmGroupSpells) do
    if on then
      if not Group.IsDebuffEntry(spell) then return false end
      any = true
    end
  end
  return any
end

-- The Spell List a trigger follows: the whole list, or the list of its chosen spells. A debuff
-- entry is never part of a buff list (a selection saved with one keeps its tick, so it can be
-- unticked, but the entry is not asked for).
function Group.Key(trigger)
  local chosen = {}
  if type(trigger) == "table" and type(trigger.cdmGroupSpells) == "table" then
    for spell, on in pairs(trigger.cdmGroupSpells) do
      spell = tonumber(spell)
      if on and SpellID(spell) and not Group.IsDebuffEntry(spell) then chosen[#chosen + 1] = spell end
    end
  end
  if #chosen == 0 then return key end
  table.sort(chosen)
  return prefix .. table.concat(chosen, ",")
end

-- Returns the IDs of every entry under Group Frame Buffs (the whole list), and every entry of the
-- class by its spell ID: {ids, name, icon, hidden}, hidden ones included (the selector lists them,
-- and a chosen spell is followed either way).
function Group.Read()
  if not (C_CooldownViewer and C_CooldownViewer.GetGroupBuffItems and C_UnitAuras and C_UnitAuras.GetHiddenGroupBuffs) then return nil, "Group Auras are not available on this client." end
  local ok, ids, entries = pcall(function()
    local items, hidden = C_CooldownViewer.GetGroupBuffItems(), C_UnitAuras.GetHiddenGroupBuffs()
    assert(Public(items) and type(items) == "table" and Public(hidden) and type(hidden) == "table")
    local excluded, selected, result, bySpell = {}, {}, {}, {}
    for _, id in pairs(hidden) do
      assert(SpellID(id))
      excluded[id] = true
    end
    for index, item in ipairs(items) do
      assert(Public(item) and type(item) == "table" and SpellID(item.spellID))
      local spell, displayed = item.spellID, item.displaySpellID
      assert(Public(displayed) and (displayed == nil or SpellID(displayed)))
      local ranks = Private.GetAuraSpellRanks(spell) or {}
      local hiddenItem = excluded[spell] or (displayed and excluded[displayed]) or false
      for _, rank in ipairs(ranks) do if excluded[rank] then hiddenItem = true end end
      local own, seen = {}, {}
      local function Add(id)
        assert(SpellID(id))
        if not seen[id] then seen[id] = true; own[#own + 1] = id end
        if not hiddenItem and not selected[id] then selected[id] = true; result[#result + 1] = id end
      end
      Add(spell)
      for _, rank in ipairs(ranks) do Add(rank) end
      if displayed then
        Add(displayed)
        for _, rank in ipairs(Private.GetAuraSpellRanks(displayed) or {}) do Add(rank) end
      end
      table.sort(own)
      local name, icon = item.name, item.iconID
      if not (Public(name) and type(name) == "string") then name = nil end
      if not (Public(icon) and type(icon) == "number") then icon = nil end
      local known = item.isKnown
      if not Public(known) then known = nil end
      bySpell[spell] = {ids = own, name = name, icon = icon, hidden = hiddenItem, order = index, spellID = spell, displaySpellID = displayed, known = known ~= false}
    end
    table.sort(result)
    return result, bySpell
  end)
  if not ok then return nil, "The game could not provide the Group Auras list." end
  return ids, entries
end

local function Publish(listKey, ids, name, icon)
  local old = published[listKey]
  local same = old and #old == #ids
  if same then
    for i, id in ipairs(ids) do if old[i] ~= id then same = false; break end end
  end
  if same then return end
  ForeverAuras.SetAuraSpellList(listKey, {spellIDs = ids, name = name, icon = icon})
  published[listKey] = ids
end

local function PublishList(listKey, ids, entries)
  if listKey == key then
    Publish(key, ids, "Group Auras", 135995)
  else
    -- A chosen spell the class does not list adds nothing; a choice of only such spells matches nothing.
    local chosenIDs, seen, first, count = {}, {}, nil, 0
    for spell in listKey:sub(#prefix + 1):gmatch("%d+") do
      local entry = entries[tonumber(spell)]
      count = count + 1
      if entry then
        first = first or entry
        for _, id in ipairs(entry.ids) do
          if not seen[id] then seen[id] = true; chosenIDs[#chosenIDs + 1] = id end
        end
      end
    end
    table.sort(chosenIDs)
    local single = count == 1 and first
    Publish(listKey, chosenIDs, single and single.name or "Group Auras", single and single.icon or 135995)
  end
end

function Group.Refresh()
  queued = false
  if not next(loaded) or not dirty then return end
  local ids, entries = Group.Read()
  Group.problem = not ids and entries or nil
  if not ids then
    if C_CooldownViewer and C_CooldownViewer.GetGroupBuffItems and C_UnitAuras and C_UnitAuras.GetHiddenGroupBuffs then
      frame:RegisterEvent("PLAYER_REGEN_ENABLED")
      frame:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
    end
    return
  end
  frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
  frame:UnregisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
  local wanted = {}
  for _, listKey in pairs(loaded) do wanted[listKey] = true end
  for listKey in pairs(wanted) do PublishList(listKey, ids, entries) end
  currentIDs, currentEntries = ids, entries
  dirty = false
end

function Group.Invalidate()
  dirty = true
  if not next(loaded) or queued then return end
  queued = true
  C_Timer.After(0, Group.Refresh)
end

function Group.Load(id, trigger)
  local first = not next(loaded)
  local listKey = Group.UsesList(trigger) and trigger.secretSpellList or key
  loaded[id] = listKey
  if first then
    for _, event in ipairs(events) do frame:RegisterEvent(event) end
    dirty = true
  end
  if dirty then Group.Refresh()
  elseif currentIDs then PublishList(listKey, currentIDs, currentEntries) end
end

function Group.Unload(id)
  loaded[id] = nil
  if not next(loaded) then frame:UnregisterAllEvents() end
end

function Group.Rename(oldID, newID)
  loaded[newID], loaded[oldID] = loaded[oldID], nil
end

function Group.Configure(data, index)
  local entry = data.triggers[index]
  entry.trigger = {
    type = "secretAura",
    event = "Blizzard CDM Group Auras",
    cdmGroupAuras = true,
    auraTracking = "native",
    unit = "group",
    debuffType = "HELPFUL",
    secretShowOn = "showOnActive",
    secretSpellList = key,
    secretUseSpellIDs = false,
    nativeFilters = {PLAYER = true},
    processedAuraType = "any",
  }
  entry.untrigger = {}
  data.triggers.activeTriggerMode = index
  data.triggers.secretFallback = "none"
  data.progressSource = {-1, ""}
  data.anchorFrameType = "UNITFRAME"
  data.blizzardAuraDisplay = data.blizzardAuraDisplay or {}
  data.blizzardAuraDisplay.growth = "RIGHT"
  data.blizzardAuraDisplay.perRow = nil
  data.blizzardAuraDisplay.unitGlow = nil
  data.blizzardAuraDisplay.sharedDisplay = true
end

function Group.Prepare(trigger)
  if not Group.IsTrigger(trigger) then return end
  if trigger.cdmGroupSpell ~= nil then
    if SpellID(trigger.cdmGroupSpell) then trigger.cdmGroupSpells = {[trigger.cdmGroupSpell] = true} end
    trigger.cdmGroupSpell = nil
  end
  trigger.secretSpellList = Group.Key(trigger)
  -- ForeverAuras (1.4.7-dev.23, Dan: "make the Blizzard CDM -> Group Auras work exactly the same as
  -- Aura Modern for Smart Group / Party / Raid - Disallow debuffs... drop the support of Blizzards
  -- Native CDM stuff entirely within that trigger; BUT do keep the spell selector"; "its just a
  -- skinned aura modern trigger"): a Group Auras trigger is an ordinary Aura (Modern) buff trigger
  -- whose spells come from the tick boxes. Buffs only: dev.6 to dev.22 followed buffs and debuffs
  -- together ("BOTH") through a second aura group, which is gone, and with it every special rule
  -- Group Auras had in the display code. The dev.21/22 renderer choice is dropped; a saved value is
  -- cleared here, and such a display is drawn like any other.
  trigger.debuffType = "HELPFUL"
  trigger.cdmGroupRenderer = nil
  -- ForeverAuras (1.4.7-dev.24, Dan: "just make Own Only clicked on when Weakened Soul is pressed"):
  -- a selection of debuff entries only (Group.DebuffOnly) makes this a debuff trigger with no
  -- spell filter and Own Only on: the debuffs the player cast on the unit. The client refuses a
  -- spell-ID filter for a harmful aura on a unit the player can assist, so the entry's spell cannot
  -- be asked for by ID; without Own Only it would be every debuff on everyone. No Spell List is
  -- used in this state (UsesList is false, so nothing is published or watched for it).
  if Group.DebuffOnly(trigger) then
    trigger.cdmGroupDebuff = true
    trigger.debuffType = "HARMFUL"
    trigger.secretSpellList = nil
    -- (dev.27, Astra's dev.25 review, P3) exclusions are switched off outright: nil would switch a
    -- saved, disabled exclusion list back on (Aura (Modern) reads nil plus a list as enabled).
    trigger.secretUseSpellIDs, trigger.secretUseRankSpellIDs, trigger.secretUseExcludedSpellIDs = false, nil, false
    local filters = {}
    for name, value in pairs(type(trigger.nativeFilters) == "table" and trigger.nativeFilters or {}) do filters[name] = value end
    filters.PLAYER = true
    trigger.nativeFilters = filters
  else
    trigger.cdmGroupDebuff = nil
  end
end

frame:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_ENABLED" or event == "ADDON_RESTRICTION_STATE_CHANGED" then
    if dirty then Group.Invalidate() end
  else
    Group.Invalidate()
  end
end)
if EventRegistry then EventRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", Group.Invalidate, Group) end
if C_UnitAuras and C_UnitAuras.SetHiddenGroupBuffs then hooksecurefunc(C_UnitAuras, "SetHiddenGroupBuffs", Group.Invalidate) end

-- Catalog membership and loaded selections are reported separately from live aura observations.
function Private.PrintCDMGroupAuras()
  local function Say(...) print("|cff9900ffFA groupauras|r", ...) end
  local function Observe(fn, ...)
    local ok, value = pcall(fn, ...)
    if not ok then return "refused" end
    if not Public(value) then return "secret" end
    if value == nil then return "none" end
    return "ok", value
  end
  local function Field(record, key) return record[key] end
  local function Label(status, value)
    if status == "secret" then return "<secret>" end
    if status ~= "ok" then return status end
    return tostring(value)
  end
  local ids, entries = Group.Read()
  local owner, rows = {}, {}
  if ids then
    Say(#ids, "spell IDs under Group Frame Buffs:", table.concat(ids, ", "))
    for _, entry in pairs(entries) do rows[#rows + 1] = entry end
    table.sort(rows, function(a, b) return a.order < b.order end)
    for _, entry in ipairs(rows) do
      for _, id in ipairs(entry.ids) do owner[id] = entry end
      Say("entry", entry.spellID, tostring(entry.name), entry.hidden and "| Not Displayed" or "| displayed", "| catalog IDs:", table.concat(entry.ids, ", "))
    end
  else
    Say("catalog unavailable:", entries)
  end
  local subscribers = {}
  for id in pairs(loaded) do subscribers[#subscribers + 1] = id end
  table.sort(subscribers)
  for _, id in ipairs(subscribers) do
    local listKey = loaded[id]
    local list = published[listKey]
    Say("loaded display", id, "| list", listKey, "| last published IDs:", list and table.concat(list, ", ") or "none")
  end
  Say("Catalog matches do not establish what a display renders. Use /fa modern Display Name for that display's state.")
  if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then Say("this client cannot list your auras by index"); return end
  for _, filter in ipairs({"HELPFUL", "HARMFUL"}) do
    for index = 1, 40 do
      local status, aura = Observe(function() return C_UnitAuras.GetAuraDataByIndex("player", index, filter) end)
      if status == "none" then Say("on you", filter, "scan complete at", index - 1); break end
      if status ~= "ok" then Say("on you", filter, index, "aura record", Label(status), "| scan stopped"); break end
      local idStatus, id = Observe(Field, aura, "spellId")
      local nameStatus, name = Observe(Field, aura, "name")
      local sourceStatus, source = Observe(Field, aura, "sourceUnit")
      local match = "catalog unavailable"
      if ids then
        if idStatus ~= "ok" or not SpellID(id) then match = "catalog match unknown"
        elseif owner[id] then match = "catalog entry " .. owner[id].spellID .. " " .. tostring(owner[id].name)
        else match = "no catalog ID match" end
      end
      Say("on you", filter, index, "name", Label(nameStatus, name), "| spell ID", Label(idStatus, id), "| source unit", Label(sourceStatus, source), "|", match)
      if index == 40 then Say("on you", filter, "scan reached 40; additional auras were not inspected") end
    end
  end
end
