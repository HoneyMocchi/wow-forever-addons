-- Dungeon quest chains, marked in the game's own quest windows. A quest that
-- is one of a dungeon's quests, or a step of a quest chain that leads into
-- one (ns.Data:DungeonsOfQuest), shows it:
--   * on its quest tooltips (chat links and any other tooltip showing the
--     quest) and on the tooltips of the world map's quest log rows: a line
--     per dungeon, "Shadowfang Keep quest chain" after its tab's icon, like
--     the item tooltips' source lines (Core/Tooltip.lua) and switched off
--     with them in Settings;
--   * in the quest log's details (a quest opened in the world map's quest
--     log): "Shadowfang Keep quest chain" and an "Open in NeedRoll" pill in
--     the bar with the game's Back button. The pill opens NeedRoll on that
--     quest's page in the dungeon (NeedRoll_ShowQuest in API.lua). Settings'
--     "Open in NeedRoll in the quest log" (QUEST_LOG_BUTTON in Core/Init.lua)
--     turns both off, at once even with the quest log open; the tooltip
--     lines stay.
-- Only for quests the player's side can take, on tabs that are on, with
-- Quests on.
--
-- NeedRoll only reads the game's quest log: it hooks the function that fills
-- the details (hooksecurefunc runs NeedRoll's code after the game's, which
-- stays untouched) and listens for the event the log's rows send on hover.
-- The note and pill are plain frames, not secure ones, so they show, hide
-- and click in combat as well; the click opens only NeedRoll's own window,
-- never the game's map.
local _, ns = ...
local Theme = ns.Theme
local L = ns.L

local QuestChainNotes = {}
ns.QuestChainNotes = QuestChainNotes

-- The note and pill sit in a box in the details' top bar (the game's
-- BackFrame, 307 x 52, its Back button at the left, the quest's text from
-- 43 down): from BACK_GAP right of the Back button to BOX_RIGHT_INSET from
-- the bar's right edge (the inset of the game's own notice in that bar), and
-- from BOX_TOP down to BOX_BELOW_BACK under the Back button's bottom. The note
-- fills the box's top line, right-aligned; the pill sits in its bottom right.
local BACK_GAP = 8
local BOX_RIGHT_INSET = 13
local BOX_TOP = -5
local BOX_BELOW_BACK = 6

local detailsNote -- the box in the quest log's details, made the first time a chain quest shows there
local shownQuestID -- the quest the quest log's details showed last, as the game handed it over

-- The dungeons and raids quest `questID` is part of as NeedRoll shows them:
-- for the player's side, on tabs that are on, with Quests on. Entries of
-- ns.Data:DungeonsOfQuest, the one it is a quest of first; empty when none.
function QuestChainNotes.Dungeons(questID)
    if type(questID) ~= "number" or issecretvalue(questID) or not ns.Modules:IsOn("QUESTS") then return {} end
    local shown = {}
    for _, entry in ipairs(ns.Data:DungeonsOfQuest(questID, ns.PlayerFaction())) do
        if ns.Modules:IsOn(entry.instance.category) then shown[#shown + 1] = entry end
    end
    return shown
end

-- "Shadowfang Keep quest chain".
local function ChainText(instance)
    return L["%s quest chain"]:format(instance.name)
end

-- The same after the dungeon's (or raid's) tab icon, for tooltips.
local function ChainLine(instance)
    return ns.Tooltip.SourceIcon(instance.category) .. ChainText(instance)
end

-- Quest `questID`'s chain lines, after each dungeon tab's icon, onto
-- `tooltip`: the first three named, the rest counted. Whether it added any.
local function AddTooltipLines(tooltip, questID)
    local dungeons = QuestChainNotes.Dungeons(questID)
    if #dungeons == 0 or not ns.Tooltip.CanAddLines(tooltip) then return false end
    local texts, lines = {}, {}
    for i, entry in ipairs(dungeons) do texts[i] = ChainLine(entry.instance) end
    ns.Tooltip.AddNamed(lines, texts)
    for _, line in ipairs(lines) do
        local color = line[2]
        tooltip:AddLine(line[1], color[1], color[2], color[3])
    end
    return true
end

-- Every tooltip showing a quest, chat links included (Blizzard's tooltip
-- data processor), but those in NeedRoll's own window (CanAddLines). A
-- client without the processor gets the lines on quest links shown with
-- SetHyperlink, and the tooltip is shown again to grow to fit them.
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum.TooltipDataType
    and Enum.TooltipDataType.Quest then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Quest, function(tooltip, data)
        AddTooltipLines(tooltip, data and data.id)
    end)
else
    local function OnSetHyperlink(tooltip, link)
        if type(link) ~= "string" or issecretvalue(link) then return end
        if AddTooltipLines(tooltip, tonumber(link:match("quest:(%d+)"))) then tooltip:Show() end
    end
    for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip }) do
        if tooltip then hooksecurefunc(tooltip, "SetHyperlink", OnSetHyperlink) end
    end
end

-- A row of the world map's quest log builds its tooltip line by line on
-- hover, then sends this event with the row and its quest ID. The chain
-- lines go under the game's, and the tooltip is shown again to fit them.
local function OnQuestLogRowEnter(_, row, questID)
    if GameTooltip:GetOwner() ~= row then return end
    if AddTooltipLines(GameTooltip, questID) then GameTooltip:Show() end
end
if EventRegistry then
    EventRegistry:RegisterCallback("QuestMapLogTitleButton.OnEnter", OnQuestLogRowEnter, QuestChainNotes)
end

-- The pill's tooltip: what it does, then every dungeon whose chain the quest is part of.
local function ShowPillTooltip(pill)
    GameTooltip:SetOwner(pill, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["Open in NeedRoll"], unpack(Theme.tip.title))
    for _, entry in ipairs(QuestChainNotes.Dungeons(detailsNote.questID)) do
        GameTooltip:AddLine(ChainLine(entry.instance), unpack(Theme.tip.info))
    end
    GameTooltip:AddLine(L["Click to open this quest"], unpack(Theme.tip.hint))
    GameTooltip:Show()
end

-- Opens NeedRoll on the quest's page, in front of the world map it was
-- clicked on (the map stays open behind it, in combat too).
local function OpenInNeedRoll()
    if NeedRoll_ShowQuest(detailsNote.questID) then ns.UI.frame:Raise() end
end

local function CreateDetailsNote(detailsFrame)
    local bar = detailsFrame.BackFrame
    local box = CreateFrame("Frame", nil, bar)
    box:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -BOX_RIGHT_INSET, BOX_TOP)
    box:SetPoint("BOTTOMLEFT", bar.BackButton, "BOTTOMRIGHT", BACK_GAP, -BOX_BELOW_BACK)
    box.note = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    box.note:SetPoint("TOPLEFT")
    box.note:SetPoint("TOPRIGHT")
    box.note:SetJustifyH("RIGHT")
    box.note:SetWordWrap(false)
    Theme:SetTextColor(box.note, Theme.tip.info)
    box.pill = Theme:NativePill(box)
    box.pill:SetPoint("BOTTOMRIGHT")
    box.pill:SetLabel(L["Open in NeedRoll"])
    box.pill:HookScript("OnEnter", ShowPillTooltip)
    box.pill:HookScript("OnLeave", function() GameTooltip:Hide() end)
    box.pill:SetScript("OnClick", OpenInNeedRoll)
    return box
end

-- Shows or hides the note and pill for the quest the details last showed:
-- shown for a quest on a dungeon's chain while Settings' "Open in NeedRoll
-- in the quest log" is on, hidden for any other. The note names the first
-- dungeon (the one the pill opens) and counts the rest. Modules:Set calls it
-- too, so a switch flipped while the quest log is open shows at once.
function QuestChainNotes.Refresh()
    local dungeons = QuestChainNotes.Dungeons(shownQuestID)
    if #dungeons == 0 or not ns.Modules:IsOn("QUEST_LOG_BUTTON") then
        if detailsNote then detailsNote:Hide() end
        return
    end
    detailsNote = detailsNote or CreateDetailsNote(QuestMapFrame.DetailsFrame)
    detailsNote.questID = shownQuestID
    local more = #dungeons > 1 and L["+%d more"]:format(#dungeons - 1) or nil
    detailsNote.note:SetText(Theme:JoinDots(ChainText(dungeons[1].instance), more))
    detailsNote:Show()
end

-- The quest log's details now show quest `questID`.
local function ShowDetailsNote(questID)
    shownQuestID = questID
    QuestChainNotes.Refresh()
end

-- The quest log is part of the game's own UI, which may load before or
-- after NeedRoll; hooked once it is there, and only when it has the Back
-- bar the note sits in.
local isHooked = false
local function HookQuestLog()
    if isHooked or not (QuestMapFrame_ShowQuestDetails and QuestMapFrame and QuestMapFrame.DetailsFrame) then return end
    local bar = QuestMapFrame.DetailsFrame.BackFrame
    if not (bar and bar.BackButton) then return end
    isHooked = true
    hooksecurefunc("QuestMapFrame_ShowQuestDetails", ShowDetailsNote)
end
HookQuestLog()
ns:On("PLAYER_LOGIN", HookQuestLog)
ns:On("ADDON_LOADED", HookQuestLog)
