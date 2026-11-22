-- The player's reputation with a faction, for the Factions tab: the
-- standing that marks the reached list ("you"), the bar under the loot
-- header and each row's standing in the Factions list. Factions the
-- character hasn't met give nothing, so none of them shows.
local _, ns = ...

-- The client answers for any faction ID, met or not (an unmet one reads as
-- Neutral 0), so "met" means "in the character's reputation list". Met
-- factions stay met; a miss is remembered until the list changes.
local metFactions, missedFactions = {}, {}
local lastHeaderScanTime
-- Whether the factions under collapsed headers were looked at since the list
-- last changed: then a faction not met yet isn't in it at all, so the
-- Factions list's rows don't each open the headers again.
local hasScannedHiddenFactions = false

-- Nested headers open one level per pass; the game's list is never deeper.
local MAX_HEADER_PASSES = 10
-- Our own header scan fires UPDATE_FACTION; one this soon after it is ours.
local OWN_SCAN_SECONDS = 0.5
-- Reputation changes come in bursts (a kill, a turn-in): one redraw each.
local REDRAW_DELAY = 0.2

local function IsCollapsedHeader(faction)
    return faction and faction.isHeader and faction.isCollapsed
end

-- Records every faction in the visible list. Returns whether a collapsed
-- header is hiding some of them.
local function RecordVisibleFactions()
    local hasCollapsedHeader = false
    for index = 1, C_Reputation.GetNumFactions() do
        local faction = C_Reputation.GetFactionDataByIndex(index)
        if faction and faction.factionID and faction.factionID > 0 then metFactions[faction.factionID] = true end
        if IsCollapsedHeader(faction) then hasCollapsedHeader = true end
    end
    return hasCollapsedHeader
end

-- Opens every collapsed header in the list, bottom up so the indices above
-- stay put, noting each by name in `openedHeaders`. Returns whether it
-- opened any.
local function ExpandCollapsedHeaders(openedHeaders)
    local openedAny = false
    for index = C_Reputation.GetNumFactions(), 1, -1 do
        local faction = C_Reputation.GetFactionDataByIndex(index)
        if IsCollapsedHeader(faction) then
            C_Reputation.ExpandFactionHeader(index)
            if faction.name then openedHeaders[faction.name] = true end
            openedAny = true
        end
    end
    return openedAny
end

-- Collapsed headers hide their factions from the list, so open them all,
-- look, and close the ones we opened (bottom up again). Not while the
-- Reputation window is open, where it would flicker.
local function RecordHiddenFactions()
    if ReputationFrame and ReputationFrame:IsVisible() then return end
    lastHeaderScanTime = GetTime()
    local openedHeaders = {}
    for _ = 1, MAX_HEADER_PASSES do
        if not ExpandCollapsedHeaders(openedHeaders) then break end
    end
    RecordVisibleFactions()
    for index = C_Reputation.GetNumFactions(), 1, -1 do
        local faction = C_Reputation.GetFactionDataByIndex(index)
        local reopened = faction and faction.isHeader and not faction.isCollapsed
        if reopened and faction.name and openedHeaders[faction.name] then C_Reputation.CollapseFactionHeader(index) end
    end
    hasScannedHiddenFactions = true
end

local function IsMet(factionID)
    if metFactions[factionID] then return true end
    if missedFactions[factionID] or hasScannedHiddenFactions then return false end
    local hasCollapsedHeader = RecordVisibleFactions()
    if not metFactions[factionID] and hasCollapsedHeader then RecordHiddenFactions() end
    missedFactions[factionID] = not metFactions[factionID] or nil
    return metFactions[factionID] or false
end

-- Standing with a met faction: reaction (4 = Neutral ... 8 = Exalted),
-- progress into the current standing and that standing's size, e.g.
-- 5, 2267, 6000 for Friendly 2267/6000. Nil when the character hasn't met it.
function ns.UI.Reputation(factionID)
    if not factionID or not IsMet(factionID) then return nil end
    local faction = C_Reputation.GetFactionDataByID(factionID)
    if not faction then return nil end
    local standingStart = faction.currentReactionThreshold or 0
    local standingEnd = faction.nextReactionThreshold or standingStart
    return faction.reaction, (faction.currentStanding or 0) - standingStart, standingEnd - standingStart
end

-- The player's standing as a reaction index, or nil for an unmet faction.
function ns.UI.PlayerStanding(factionID)
    return (ns.UI.Reputation(factionID))
end

-- The game's name for standing `reaction` ("Honored"), as its Reputation
-- window writes it.
function ns.UI.StandingWord(reaction)
    return _G["FACTION_STANDING_LABEL" .. reaction] or ""
end

-- The game's colour for standing `reaction`, its Reputation window's bar
-- colour, as { r, g, b }; nil on a client without those colours.
function ns.UI.StandingColor(reaction)
    local color = FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
    return color and { color.r, color.g, color.b } or nil
end

-- How far through its standing `value` of `max` is, from 0 to 1. A standing
-- with no size (the last one) counts as full.
function ns.UI.StandingProgress(value, max)
    if not max or max <= 0 then return 1 end
    return math.max(0, math.min(1, (value or 0) / max))
end

-- Redraws what shows a standing while the window is open: the Factions
-- list's rows, and the open page when its list has a faction (a PvP list
-- can too).
local function RedrawStandings()
    local UI = ns.UI
    if not (UI.frame and UI.frame:IsShown() and UI.state) then return end
    if UI.state.category == "FACTION" then UI.instances:Refresh() end
    local instance = UI.state.instance
    if instance and instance.factionID then
        UI.encounters:SetData(instance)
        UI:Refresh()
    end
end

-- Reputation gained or lost, or a faction met: forget the misses and
-- redraw the Factions list and the open page.
local redrawQueued = false
ns:On("UPDATE_FACTION", function()
    if lastHeaderScanTime and GetTime() - lastHeaderScanTime < OWN_SCAN_SECONDS then return end
    wipe(missedFactions)
    hasScannedHiddenFactions = false
    if redrawQueued then return end
    redrawQueued = true
    C_Timer.After(REDRAW_DELAY, function()
        redrawQueued = false
        RedrawStandings()
    end)
end)
