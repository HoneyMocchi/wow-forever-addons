-- Copyright (C) 2026 ForeverAuras. Part of ForeverAuras, licensed under the GNU GPL v2 (see LICENSE).
if not WeakAuras.IsLibsOK() then return end
local _, OptionsPrivate = ...
local L = WeakAuras.L
local views = setmetatable({}, {__mode = "k"})

-- ForeverAuras (1.4.7-dev.23, Dan: "its just a skinned aura modern trigger; that has the spell
-- selector in it; but you cant use custom spell IDs there or names etc, you just have to use from
-- whats available"): the Group Auras page is the Aura (Modern) page (SecretAuraTriggerOptions.lua
-- builds `options` and hands it here) with three differences:
--   * the second Type drop-down, Open CDM / Refresh, and "Blizzard CDM Entries": one tick box per
--     group aura of the class, with icon, name and spell ID, in place of Aura Type and the Name /
--     Spell ID fields. Nothing ticked follows every entry under Group Frame Buffs (entries under
--     Not Displayed left out); ticked entries are followed alone, also when under Not Displayed.
--   * Unit offers Smart Group, Party and Raid.
--   * A debuff entry (Weakened Soul) cannot be followed by spell ID on a friendly unit. Ticking it
--     shows the debuffs the player cast on the unit instead, with Own Only on (dev.24, see Choose).
-- Everything else on the page (unit filters, aura filters, Remaining Time, Total Duration, Stack
-- Count, Show On with all four choices) is Aura (Modern)'s own, unchanged.
-- The entries are read when the options are drawn and on Refresh; nothing is written to the game.
function OptionsPrivate.ApplyCDMGroupAuraOptions(options, data, triggernum)
  local Private = OptionsPrivate.Private
  local trigger = data.triggers[triggernum].trigger
  views[data] = views[data] or {}
  views[data][triggernum] = views[data][triggernum] or {}
  local view = views[data][triggernum]
  local function Save()
    WeakAuras.Add(data)
    Private.UpdateFakeStatesFor(data.id)
    OptionsPrivate.QueueOptionsRefresh(data.id)
  end
  for key in pairs(options) do
    if key:find("^rankspellid") or key:find("^spellid") or key:find("^ignorespellid") then options[key] = nil end
  end
  for _, key in ipairs({"auraTypeLabel", "debuffType", "spellSelectionHeader", "useRankSpellIDs", "useSpellIDs", "useExcludedSpellIDs", "rankCoverage", "spellListNote",
      "specificUnit", "specificUnitSpace", "gainedUnitNote"}) do
    options[key] = nil
  end
  options.event = {
    type = "select", name = "", order = 1.2, width = WeakAuras.normalWidth,
    values = {
      ["Blizzard Cooldown Manager"] = L["Cooldown"],
      ["Blizzard CDM Buff"] = L["Buff/Debuff"],
      ["Blizzard CDM Item"] = L["Item"],
      ["Blizzard CDM Group Auras"] = L["Group Auras"],
    },
    sorting = {"Blizzard Cooldown Manager", "Blizzard CDM Buff", "Blizzard CDM Item", "Blizzard CDM Group Auras"},
    get = function() return "Blizzard CDM Group Auras" end,
    set = function(_, value)
      if value == "Blizzard CDM Group Auras" then return end
      if not Private.category_event_prototype.cdm[value] then return end
      data.triggers[triggernum].trigger = {type = "cdm", event = value, cdmSource = value == "Blizzard CDM Buff" and "buff" or "cooldown"}
      Save()
    end,
  }
  options.alwaysActive = {type = "description", name = L["Note: Trigger Always Active."], order = 1.95, width = "full", fontSize = "medium"}
  local status = options.help and options.help.name
  options.help = {
    type = "description", order = 2, width = "full", fontSize = "small",
    name = function() return Private.CDMGroupAuras.problem or (type(status) == "function" and status()) or "" end,
  }
  options.open = {
    type = "execute", name = L["Open CDM"], order = 2.1, width = WeakAuras.normalWidth,
    disabled = function() return InCombatLockdown() or not C_CooldownViewer end,
    func = function()
      if not C_AddOns.IsAddOnLoaded("Blizzard_CooldownViewer") then C_AddOns.LoadAddOn("Blizzard_CooldownViewer") end
      if CooldownViewerSettings then ShowUIPanel(CooldownViewerSettings) end
    end,
  }
  options.refresh = {
    type = "execute", name = L["Refresh from Blizzard CDM"], order = 2.2, width = WeakAuras.normalWidth,
    func = function() Private.CDMGroupAuras.Invalidate(); OptionsPrivate.QueueOptionsRefresh(data.id) end,
  }
  -- (dev.16, Dan: "this width issue needs fixing") the Type drop-down is double width on the Aura
  -- (Modern) page; here it shares its row with the second drop-down, as on the Cooldown page.
  if options.type then options.type.width = WeakAuras.normalWidth end
  if options.unit then
    -- (dev.16, Dan: "make unit say smart group; not just group") the names Aura (Modern) uses.
    local names = Private.BlizzardAuraDisplay.units or {}
    options.unit.values = {group = names.group or L["Smart Group"], party = names.party or L["Party"], raid = names.raid or L["Raid"]}
    options.unit.sorting = {"group", "party", "raid"}
  end
  -- (dev.16, Dan: the note under Show On named Aura (Modern) on a Group Auras trigger) Same two
  -- notes, naming this trigger and its own section under Display ("Group Auras Settings").
  if options.nativeShowNotice then
    options.nativeShowNotice.name = function()
      if Private.BlizzardAuraDisplay.IsSingle(trigger, data) then return L["One aura is shown, chosen by Sort by under Group Auras Settings in Display."] end
      return L["You cannot control clones with Group Auras. Use the Group Auras Settings under Display."]
    end
  end
  -- (dev.24) Own Only is part of what a ticked debuff entry means; it cannot be taken off then.
  if options.nativePLAYER then
    local disabled = options.nativePLAYER.disabled
    options.nativePLAYER.disabled = function(...)
      if Private.CDMGroupAuras.DebuffOnly(trigger) then return true end
      if type(disabled) == "function" then return disabled(...) end
      return disabled
    end
  end
  options.groupFilters = {type = "header", name = L["Blizzard CDM Filters"], order = 2.3}
  -- (dev.17, Dan: "I dont think a search is necessary in this group auras ever; because its always a
  -- small list for all classes") no Search field here.
  options.groupAvailable = {
    type = "toggle", name = L["Show only available"], order = 2.32, width = WeakAuras.normalWidth,
    get = function() return view.availableOnly or false end,
    set = function(_, value) view.availableOnly = value; OptionsPrivate.QueueOptionsRefresh(data.id) end,
  }
  options.groupEntries = {type = "header", name = L["Blizzard CDM Entries"], order = 2.4}
  local ids, entries = Private.CDMGroupAuras.Read()
  entries = ids and entries or {}
  local function Chosen(spell)
    local set = trigger.cdmGroupSpells
    return type(set) == "table" and (set[spell] or set[tostring(spell)]) and true or false
  end
  -- ForeverAuras (1.4.7-dev.24, Dan: "maybe we shouldn't remove weakened soul... you just make Own
  -- Only clicked on when Weakened Soul is pressed? ... the simplest solution"): a debuff entry can
  -- be ticked. The game does not let an addon pick a debuff on a friendly unit by spell ID, so a
  -- ticked debuff entry turns the trigger into "the debuffs I cast on the unit": a debuff trigger
  -- with no spell filter and Own Only on (CDMGroupAuras.lua, Prepare and Group.DebuffOnly). One
  -- aura is either that or buffs: ticking a debuff entry unticks the buffs, ticking a buff unticks
  -- the debuff entry. The entry's label says what it shows.
  -- (dev.27, Astra's dev.25 review, P2) Decided entry by entry. Unticking removes that entry and
  -- keeps every other tick (dev.25 emptied the set when the unticked entry was of the other kind
  -- than the set as a whole, so unticking Weakened Soul from an old Renew + Weakened Soul
  -- selection lost Renew and fell back to All). Ticking an entry removes the ticks of the other
  -- kind, which also tidies a selection saved with both.
  local function Choose(spell, value, debuff)
    local set = {}
    for id, on in pairs(type(trigger.cdmGroupSpells) == "table" and trigger.cdmGroupSpells or {}) do
      id = tonumber(id)
      if on and id and not (value and Private.CDMGroupAuras.IsDebuffEntry(id) ~= (debuff and true or false)) then set[id] = true end
    end
    set[spell] = value and true or nil
    trigger.cdmGroupSpells = next(set) and set or nil
    Save()
  end
  local rows = {}
  for spell, entry in pairs(entries) do
    local shownID = entry.displaySpellID or spell
    local name = entry.name or C_Spell.GetSpellName(shownID) or tostring(spell)
    local known = entry.known
    -- (dev.25) Which entries are debuffs comes from the short list in CDMGroupAuras.lua.
    local debuff = Private.CDMGroupAuras.IsDebuffEntry(spell)
    rows[#rows + 1] = {spell = spell, name = name, label = name .. " [" .. shownID .. "]", icon = entry.icon or C_Spell.GetSpellTexture(shownID),
      hidden = entry.hidden, known = known, listed = true, debuff = debuff}
  end
  -- A ticked spell the class does not list (an aura made on another class) stays visible so it can be unticked.
  for id, on in pairs(type(trigger.cdmGroupSpells) == "table" and trigger.cdmGroupSpells or {}) do
    local spell = tonumber(id)
    if on and spell and not entries[spell] then
      local name = C_Spell.GetSpellName(spell) or tostring(spell)
      rows[#rows + 1] = {spell = spell, name = name, label = name .. " [" .. spell .. "]", icon = C_Spell.GetSpellTexture(spell), known = false, listed = false}
    end
  end
  table.sort(rows, function(a, b) if a.name ~= b.name then return a.name < b.name end; return a.spell < b.spell end)
  local order = 2.4
  for _, row in ipairs(rows) do
    if (not view.availableOnly or row.known or Chosen(row.spell)) then
      order = order + 0.0001
      local label = row.label
      if row.debuff then label = label .. " |cffffd100" .. L["(shows all your debuffs)"] .. "|r"
      elseif not row.listed then label = "|cffff8800" .. label .. " " .. L["(not a group aura of this class)"] .. "|r"
      elseif row.hidden then label = "|cff808080" .. label .. " " .. L["(Not Displayed)"] .. "|r" end
      options["groupEntry" .. row.spell] = {
        type = "toggle", name = label, order = order, width = "full", image = row.icon, imageWidth = 18, imageHeight = 18,
        desc = row.hidden and L["Under Not Displayed in the Cooldown Manager's Group Frame Buffs. Followed only when ticked."] or L["Group Frame Buffs"],
        get = function() return Chosen(row.spell) end,
        set = function(_, value) Choose(row.spell, value, row.debuff) end,
      }
    end
  end
end
