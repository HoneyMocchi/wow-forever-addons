-- Talent plans linked in chat (see "Chat lines" in Core/Talents.lua). A chat
-- filter shows each "[NR Talents: Fire] NRT2:..." in a chat line as a gold
-- [NR Talents: Fire] link; clicking one saves the plan as a saved plan of its
-- class and opens it on the Classes tab.
--
-- How Forever gets a click on such a link to NeedRoll: the chat window's
-- OnHyperlinkClick calls SetItemRef, which hands every "addon:" link to
-- Blizzard's AddOn link handler, and that fires EventRegistry's "SetItemRef"
-- event with the link. Only links made on this client get there, which is
-- why the filter makes the link from the plain text each copy receives.
-- Forever runs addons' chat filters only for lines whose sender the addon
-- may read: inside dungeons and raids and in combat, the line stays plain
-- text, which still pastes into Import.
local _, ns = ...
local L = ns.L
local Talents = ns.Talents

local TalentLinks = {}  -- EventRegistry's owner for the click callback

-- A link's data: "addon:NeedRoll:<share string>:<plan name>". The name
-- never holds "|" (Talents.LinkName), so it can't end the link early.
local LINK_PREFIX = "addon:NeedRoll:"  -- the addon's own link type, whatever the tag reads
local LINK_DATA_PATTERN = "^" .. LINK_PREFIX .. "(" .. Talents.SHARE_STRING_PATTERN .. "):(.+)$"
local LINK_COLOR = "|cffffd100"  -- the game's gold, as item and quest links have theirs
-- Where a linked plan starts in a chat line; a line without it is left alone at once.
local TAG_START = "[" .. Talents.CHAT_TAG .. ": "

-- The chat a plan can be linked in: what players type to each other.
local CHAT_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_WHISPER",
    "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_CHANNEL", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
}

-- One linked plan as a gold link showing "[NR Talents: <name>]"; nil (the
-- text stays as it was) when the name has nothing left once cleaned.
local function LinkFor(name, shareString)
    local linkName = Talents.LinkName(name)
    if not linkName then return nil end
    return ("%s|H%s%s:%s|h[%s: %s]|h|r"):format(LINK_COLOR, LINK_PREFIX, shareString, linkName, Talents.CHAT_TAG,
        linkName)
end

-- The chat filter: the message is the first of the event's arguments, and
-- returning false and the arguments again (the message changed) shows the
-- line with its links. The game only calls it when it may be read, and the
-- message is checked again before it is looked at.
local function LinkPlansInChat(_, _, message, ...)
    if not canaccessvalue(message) or type(message) ~= "string" then return false end
    if not (message:find(TAG_START, 1, true) and ns.Modules:IsOn("CLASSES")) then return false end
    return false, (message:gsub(Talents.CHAT_LINE_PATTERN, LinkFor)), ...
end
for _, event in ipairs(CHAT_EVENTS) do
    ChatFrameUtil.AddMessageEventFilter(event, LinkPlansInChat)
end

-- What the status line says once a linked plan is saved.
local function SavedText(classID, savedPlan, leftOut)
    local className = GetClassInfo(classID) or ""
    if leftOut > 0 then
        return L["Saved %s, a %s plan; %d points broke the talent rules and were left out."]:format(savedPlan.name,
            className, leftOut)
    end
    return L["Saved %s, a %s plan."]:format(savedPlan.name, className)
end

-- Opens the window on the Classes tab and saves the linked plan there; if
-- it can't be saved, a box shows the share string to copy and why not.
local function SaveLinkedPlan(shareString, name)
    local classID, result, savedPlan = Talents.SaveShared(shareString, name)
    local UI = ns.UI
    UI:Show()
    UI:SwitchTab("CLASSES")
    if not classID then
        UI.classes.planner.exportDialog:PresentUnsaved(shareString, result)
        return
    end
    UI.classes:ShowPlanner(classID)
    UI.status:SetText(SavedText(classID, savedPlan, result))
end

-- A click on a NeedRoll plan link saves it; a shift-click (the game's
-- "link in chat" click) puts the plain line in the chat box instead.
local function OnLinkClick(_, link)
    if type(link) ~= "string" or not ns.Modules:IsOn("CLASSES") then return end
    local shareString, name = link:match(LINK_DATA_PATTERN)
    if not shareString then return end
    if IsModifiedClick("CHATLINK") then
        ns.UI.TypeInChat(Talents.ChatLine(name, shareString))
        return
    end
    SaveLinkedPlan(shareString, name)
end
EventRegistry:RegisterCallback("SetItemRef", OnLinkClick, TalentLinks)
