-- First run: the first time the window opens, a callout points at the
-- Settings button for a few seconds, where the window style (Native by
-- default; Modern, Dark or, with ElvUI loaded, ElvUI instead) and text size
-- are switched.
-- /nr welcome shows it again. A few seconds after the first login come the
-- drop sharing notice (while drop sharing is switched on, see Switch in
-- Core/Drops.lua) and, on non-English clients, the translation notice.
local _, ns = ...
local Theme = ns.Theme
local L = ns.L

local Welcome = {}
ns.Welcome = Welcome

function Welcome:Show()
    ns.db.welcomed = true
    self:ShowCallout()
end

-- Callout ---------------------------------------------------------------
-- Points at the Settings button at the top of the window for a few
-- seconds. The native style uses the game's own tutorial pointer
-- (HelpTip) when it is available.

local CALLOUT_TEXT = L["Window style and text size live here."]
local CALLOUT_SECONDS = 12
local BUBBLE_INSET = 12 -- how far the bubble's right edge reaches past the button's

local function CreateBubble()
    local bubble = CreateFrame("Button")
    bubble:SetSize(1, 46)
    bubble.text = Theme:Text(bubble, Theme.font.body)
    bubble.text:SetPoint("TOPLEFT", 12, -10)
    bubble.text:SetText(CALLOUT_TEXT)
    bubble.hint = Theme:Text(bubble, Theme.font.small)
    bubble.hint:SetPoint("TOPLEFT", bubble.text, "BOTTOMLEFT", 0, -4)
    bubble.hint:SetText(L["Or type  /nr style  or  /nr text"])

    -- A square turned 45 degrees over the bubble; its upper half shows as
    -- the arrow, continuing the outline.
    bubble.arrowHolder = CreateFrame("Frame", nil, bubble)
    bubble.arrowHolder:SetAllPoints()
    bubble.arrow = bubble.arrowHolder:CreateTexture(nil, "BACKGROUND")
    bubble.arrow:SetSize(10, 10)
    bubble.arrow:SetColorTexture(1, 1, 1, 1)
    bubble.arrow:SetRotation(math.rad(45))

    bubble.bounce = bubble:CreateAnimationGroup()
    bubble.bounce:SetLooping("BOUNCE")
    local move = bubble.bounce:CreateAnimation("Translation")
    move:SetOffset(0, 4)
    move:SetDuration(0.6)
    move:SetSmoothing("IN_OUT")

    bubble:SetScript("OnClick", function() Welcome:HideCallout() end)
    bubble:SetScript("OnHide", function(self)
        self.bounce:Stop()
        if self.timer then self.timer:Cancel() end
        self.timer = nil
    end)
    return bubble
end

-- Redraws the bubble in the current window style's fonts and colours, once
-- per style change.
local function SkinBubble(bubble)
    if bubble.skin == Theme.name then return end
    bubble.skin = Theme.name
    bubble.text:SetFontObject(Theme.font.body)
    bubble.hint:SetFontObject(Theme.font.small)
    if bubble.bg then bubble.bg:Hide() end
    if bubble.borderHolder then bubble.borderHolder:Hide() end
    Theme:Rounded(bubble, Theme.color.popup, Theme.color.accent, true)
    bubble.arrow:SetVertexColor(unpack(Theme.color.accent))
    Theme:SetTextColor(bubble.text, Theme.color.heading)
    Theme:SetTextColor(bubble.hint, Theme.color.muted)
end

-- The game's tutorial pointer, if this client has it. Returns whether it showed.
local function ShowHelpTip(window, target)
    if not (HelpTip and HelpTip.Show and HelpTip.Point) then return false end
    local shown = HelpTip:Show(window, {
        text = CALLOUT_TEXT,
        buttonStyle = HelpTip.ButtonStyle.Close,
        targetPoint = HelpTip.Point.BottomEdgeCenter,
        alignment = HelpTip.Alignment.Right,
        autoHideWhenTargetHides = true,
    }, target)
    if shown then Welcome.helpTip = { parent = window, text = CALLOUT_TEXT } end
    return shown
end

function Welcome:ShowCallout()
    local window, target = ns.UI.frame, ns.UI.settingsButton
    if not (window and window:IsShown() and target) then return end
    if Theme.native and ShowHelpTip(window, target) then return end

    local bubble = self.bubble or CreateBubble()
    self.bubble = bubble
    -- On the current window (so it hides with it), above it, under
    -- `target` with its arrow pointing at the target's middle. Placed
    -- before the skin: the skin's border takes the bubble's frame level.
    bubble:SetParent(window)
    bubble:SetFrameStrata(window:GetFrameStrata())
    bubble:SetFrameLevel(window:GetFrameLevel() + 40)
    bubble.arrowHolder:SetFrameLevel(bubble:GetFrameLevel() - 1)
    bubble:ClearAllPoints()
    bubble:SetPoint("TOPRIGHT", target, "BOTTOMRIGHT", BUBBLE_INSET, -12)
    bubble.arrow:ClearAllPoints()
    bubble.arrow:SetPoint("CENTER", bubble, "TOPRIGHT", -BUBBLE_INSET - target:GetWidth() / 2, 0)
    SkinBubble(bubble)
    -- As wide as its longer line in the current fonts.
    bubble:SetWidth(math.max(bubble.text:GetStringWidth(), bubble.hint:GetStringWidth()) + 24)
    bubble:Show()
    bubble.bounce:Play()
    if bubble.timer then bubble.timer:Cancel() end
    bubble.timer = C_Timer.NewTimer(CALLOUT_SECONDS, function() Welcome:HideCallout() end)
end

function Welcome:HideCallout()
    if self.bubble then self.bubble:Hide() end
    if self.helpTip and HelpTip then HelpTip:Hide(self.helpTip.parent, self.helpTip.text) end
    self.helpTip = nil
end

-- Drop sharing notice --------------------------------------------------
-- Shown once per account, a few seconds after logging in (out of combat),
-- from v0.14.0 on: says what drop sharing does, lets the player keep it or
-- turn it off (no drop, quest or trainer messages) and asks whether to
-- credit their finds by name (Mike, 2026-10-15). Nothing is shared until
-- the player answers Share drops, or turns Share drops on in Settings
-- (Drops:ChannelOn in Core/Drops.lua). Answered either way, here or in
-- Settings, it doesn't show again (NeedRollDB.shownDroptalkConsent) until
-- the next round. It has no close button and Escape doesn't shut it, so it
-- isn't skipped by accident.
-- A round is one time every account is asked: when drop sharing changes
-- enough to ask again, DROP_NOTICE_ROUND goes up by one, and the first login
-- on an account whose NeedRollDB.dropNoticeRound is lower marks the notice
-- unanswered and takes back a yes from an earlier round, so nothing is sent
-- until the player answers again. A saved Off stays Off. Round 1 began in
-- v0.14.0; round 2 is sharing coming back on after it was switched off for
-- everyone in November 2026 (Mike, 2026-11-08). Switching sharing back on
-- for everyone (Drops.isSharingEnabled) bumps the round; while it is off
-- the notice isn't shown. v1.8.0's vendor and trainer sharing, relayed
-- finds, pushes and referrals stay in round 2: the notice and Settings' tip
-- were reworded for them, with a line about referrals, and a yes from
-- round 2 isn't asked for again (Mike, 2026-11-16).
local DROP_NOTICE_ROUND = 2
local NOTICE_DELAY = 8 -- seconds after logging in
local NOTICE_WIDTH = 460
local NOTICE_GAP = 10    -- between the title, the text and the tick box
local NOTICE_BUTTON_GAP = 14 -- between a notice's last part and its buttons
local CHECKBOX_SIZE = 24

-- A wrapping, left-aligned block of text in the text colour, `width` wide.
local function Paragraph(notice, font, width)
    local text = Theme:Text(notice, font)
    text:SetWidth(width)
    text:SetWordWrap(true)
    text:SetJustifyH("LEFT")
    Theme:SetTextColor(text, Theme.color.text)
    return text
end

-- A first-login notice's panel, named `frameName`: NOTICE_WIDTH wide over
-- the middle of the screen, draggable, with `title` at its top left. The
-- caller sets its height once its parts are placed.
local function NoticePanel(frameName, title)
    local pad = Theme.size.pad
    local notice = CreateFrame("Frame", frameName, UIParent)
    notice:SetFrameStrata("DIALOG")
    notice:SetWidth(NOTICE_WIDTH)
    notice:SetPoint("CENTER", 0, 120)
    notice:EnableMouse(true)
    notice:SetMovable(true)
    notice:RegisterForDrag("LeftButton")
    notice:SetScript("OnDragStart", notice.StartMoving)
    notice:SetScript("OnDragStop", notice.StopMovingOrSizing)
    Theme:Rounded(notice, Theme.color.popup, Theme.color.accent, true)

    notice.title = Theme:Text(notice, Theme.font.heading)
    notice.title:SetPoint("TOPLEFT", pad, -pad)
    notice.title:SetText(title)
    return notice
end

-- Whether the player is in combat. If so, `retry` runs once, when combat
-- ends (one per `waitName`): the notices stay out of fights.
local retriesAfterCombat = {}
local function WaitForCombatEnd(waitName, retry)
    if not (InCombatLockdown() or UnitAffectingCombat("player")) then return false end
    retriesAfterCombat[waitName] = retry
    return true
end
ns:On("PLAYER_REGEN_ENABLED", function()
    local retries = retriesAfterCombat
    retriesAfterCombat = {}
    for _, retry in pairs(retries) do retry() end
end)

local function CreateDropNotice()
    local pad = Theme.size.pad
    local notice = NoticePanel("NeedRollDropNotice", L["NeedRoll DropTalk System Consent"])
    notice.body = Paragraph(notice, Theme.font.body, NOTICE_WIDTH - pad * 2)
    notice.body:SetPoint("TOPLEFT", notice.title, "BOTTOMLEFT", 0, -NOTICE_GAP)
    notice.body:SetText(L["NeedRoll shares the boss drops, new quests, trainer spells and recipes, and vendor finds (recipes and rare items) you see, and its own version, with other NeedRoll players to fill in its lists. It uses hidden addon messages, sends its finds at most one a minute, and never affects your performance or gameplay."]
        .. " " .. L["When NeedRoll's developer asks for finds, it also tells him who in your guild or group shared finds in the past week, so he can ask them too."]
        .. "\n\n" .. L["Turning it on helps map out WoW: Forever, and those finds reach your addon sooner. Turning it off stops the drop, quest, trainer and vendor messages, so its lists fill in more slowly. NeedRoll still tells your guild and group which version it runs, so it can say when an update is out."]
        .. "\n\n" .. L["It's fully opt-in, and you can change it any time in NeedRoll's Settings."])

    notice.credit = CreateFrame("CheckButton", nil, notice, "UICheckButtonTemplate")
    notice.credit:SetSize(CHECKBOX_SIZE, CHECKBOX_SIZE)
    notice.credit:SetPoint("TOPLEFT", notice.body, "BOTTOMLEFT", -4, -NOTICE_GAP)
    notice.creditText = Paragraph(notice, Theme.font.small, NOTICE_WIDTH - pad * 2 - (CHECKBOX_SIZE + 4))
    notice.creditText:SetPoint("LEFT", notice.credit, "RIGHT", 4, 0)
    notice.creditText:SetText(L["Credit my finds by character name (otherwise they're stored anonymously)"])

    notice.decline = Theme:Pill(notice)
    notice.decline:SetLabel(L["Don't share"])
    notice.decline:SetPoint("BOTTOMRIGHT", -pad, pad)
    notice.share = Theme:Pill(notice)
    notice.share:SetLabel(L["Share drops"])
    notice.share:SetPoint("RIGHT", notice.decline, "LEFT", -8, 0)
    local function Answer(share)
        ns.db.dropCredit = notice.credit:GetChecked() and true or false
        Welcome:AnswerDropSharing(share)
    end
    notice.share:SetScript("OnClick", function() Answer(true) end)
    notice.decline:SetScript("OnClick", function() Answer(false) end)

    -- Its parts stacked, then the buttons.
    local height = pad + notice.title:GetStringHeight() + NOTICE_GAP + notice.body:GetStringHeight() + NOTICE_GAP
        + math.max(CHECKBOX_SIZE, notice.creditText:GetStringHeight()) + NOTICE_BUTTON_GAP
        + notice.decline:GetHeight() + pad
    notice:SetHeight(math.ceil(height))
    return notice
end

-- Answered before, or with drop sharing switched off, it goes straight on
-- to the translation notice. The tick box starts as the player's saved
-- Credit my finds (ticked when never chosen).
function Welcome:ShowDropNotice()
    if ns.db.shownDroptalkConsent or not ns.Drops.isSharingEnabled then
        self:ShowTranslationNotice()
        return
    end
    if WaitForCombatEnd("drop", function() Welcome:ShowDropNotice() end) then return end
    self.notice = self.notice or CreateDropNotice()
    self.notice.credit:SetChecked(ns.Drops:CreditOn())
    self.notice:Show()
end

-- The player's answer to drop sharing, from the notice or Settings' Share
-- drops: either one closes this round of asking, and an answer in Settings
-- takes down the notice if it is up.
function Welcome:AnswerDropSharing(share)
    ns.db.shownDroptalkConsent = true
    ns.Drops:SetChannel(share)
    if not (self.notice and self.notice:IsShown()) then return end
    self.notice:Hide()
    self:ShowTranslationNotice()
end

-- Translation notice ---------------------------------------------------
-- Shown once per account while NeedRoll's text is in any language but
-- English (ns.loadedLanguage), after the drop sharing notice is answered (Mike, 2026-10-22): the
-- translations are a first pass, and help is welcome on the Discord or the
-- public NeedRoll-locales repo. Addons can't open a browser, so each link
-- sits in a box selected for Ctrl+C. "Got it" closes it for good
-- (NeedRollDB.shownTranslationNotice).
local TRANSLATIONS_URL = "https://github.com/mikebvs/NeedRoll-locales"
local LINK_LABEL_WIDTH = 64 -- the column holding "Discord" and "GitHub"
local LINK_ROW_GAP = 6

-- Whether NeedRoll's own text is in English (on an English client, or
-- picked in Settings, Language), so nobody reading English is asked.
local function IsTextInEnglish()
    return ns.loadedLanguage == "enUS"
end

-- A row `gap` under `above`: `label` in small text, then a box holding `url`.
local function AddLinkRow(notice, above, gap, label, url)
    local pad = Theme.size.pad
    local row = CreateFrame("Frame", nil, notice)
    row:SetSize(NOTICE_WIDTH - pad * 2, 24)
    row:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -gap)
    row.label = Theme:Text(row, Theme.font.small)
    row.label:SetPoint("LEFT")
    row.label:SetWidth(LINK_LABEL_WIDTH)
    row.label:SetJustifyH("LEFT")
    row.label:SetText(label)
    local boxWidth = NOTICE_WIDTH - pad * 2 - LINK_LABEL_WIDTH
    row.link = Theme:LinkBox(row, boxWidth, url, function()
        notice.copied:SetText(L["Copied. Paste it in your browser."])
    end)
    row.link:SetPoint("LEFT", LINK_LABEL_WIDTH + (Theme.native and 6 or 0), 0)
    return row
end

local function CreateTranslationNotice()
    local pad = Theme.size.pad
    local notice = NoticePanel("NeedRollTranslationNotice", L["Help translate NeedRoll"])
    notice.body = Paragraph(notice, Theme.font.body, NOTICE_WIDTH - pad * 2)
    notice.body:SetPoint("TOPLEFT", notice.title, "BOTTOMLEFT", 0, -NOTICE_GAP)
    notice.body:SetText(L["NeedRoll's translations are a first pass, so some text may read oddly or still be in English. Any and all help with translations is much appreciated! Suggest fixes on our Discord or on the NeedRoll-locales GitHub page."]
        .. "\n\n" .. L["Click a link and press Ctrl+C to copy it, then paste it in your browser."])

    notice.copied = Theme:Text(notice, Theme.font.small)
    Theme:SetTextColor(notice.copied, Theme.color.complete)
    notice.discord = AddLinkRow(notice, notice.body, NOTICE_GAP, L["Discord"], ns.DISCORD_URL)
    notice.github = AddLinkRow(notice, notice.discord, LINK_ROW_GAP, L["GitHub"], TRANSLATIONS_URL)

    notice.done = Theme:Pill(notice)
    notice.done:SetLabel(L["Got it"])
    notice.done:SetPoint("BOTTOMRIGHT", -pad, pad)
    notice.done:SetScript("OnClick", function()
        ns.db.shownTranslationNotice = true
        notice:Hide()
    end)
    notice.copied:SetPoint("LEFT", notice, "BOTTOMLEFT", pad, pad + notice.done:GetHeight() / 2)

    -- Its parts stacked, then the button.
    local height = pad + notice.title:GetStringHeight() + NOTICE_GAP + notice.body:GetStringHeight() + NOTICE_GAP
        + notice.discord:GetHeight() + LINK_ROW_GAP + notice.github:GetHeight() + NOTICE_BUTTON_GAP
        + notice.done:GetHeight() + pad
    notice:SetHeight(math.ceil(height))
    return notice
end

function Welcome:ShowTranslationNotice()
    if ns.db.shownTranslationNotice or IsTextInEnglish() then return end
    if WaitForCombatEnd("translation", function() Welcome:ShowTranslationNotice() end) then return end
    self.translationNotice = self.translationNotice or CreateTranslationNotice()
    self.translationNotice.copied:SetText("")
    self.translationNotice:Show()
end

-- Once a round: marks the drop sharing notice unanswered and takes back a
-- yes from an earlier round, so sharing waits for the new answer (see Drop
-- sharing notice).
local function StartDropNoticeRound()
    if (tonumber(ns.db.dropNoticeRound) or 0) >= DROP_NOTICE_ROUND then return end
    ns.db.shownDroptalkConsent = false
    if ns.db.dropChannel == true then ns.db.dropChannel = nil end
    ns.db.dropNoticeRound = DROP_NOTICE_ROUND
end

ns:On("PLAYER_LOGIN", function()
    StartDropNoticeRound()
    C_Timer.After(NOTICE_DELAY, function() Welcome:ShowDropNotice() end)
end)
