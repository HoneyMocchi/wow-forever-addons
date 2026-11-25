-- Main window: header (title, search, close), category tabs, three panes
-- (instances, encounters, loot) and a footer hint line.
local _, ns = ...
local Theme = ns.Theme
local Size = Theme.size
local L = ns.L

-- history: the places left by following a link inside the window (a
-- material's arrow, a search result's go-to, an attunement quest, a layout
-- map), oldest first, as UI:Place() snapshots; Back walks it in reverse.
-- built: each skin's window once it exists, parked while the other is used.
-- places: where each tab was left ({ instance, encounter, quest, filter, history }),
-- so switching tabs and back returns there.
local UI = { state = {}, history = {}, built = {}, places = {} }
ns.UI = UI

-- Puts `text` in the chat box the player is typing in, or opens the chat
-- box with it, for them to send.
function UI.TypeInChat(text)
    if not ChatFrameUtil.InsertLink(text) then ChatFrameUtil.OpenChat(text) end
end

-- The tabs, in order: one per module (Core/Init.lua) that isn't part of
-- another tab, shown while it is on.
local TABS = {}
for _, info in ipairs(ns.Modules.list) do
    if not info.sub then table.insert(TABS, info) end
end

-- Tabs that fill the whole body with panes of their own, with no list of
-- instances, and the key on UI of each one's pane: Library
-- (UI/LibraryBooks.lua), the Shopping List and the Wishlist (one pane each)
-- and Classes (UI/Classes.lua).
local WHOLE_BODY = { LIBRARY_BOOKS = "library", SHOPPING = "shopping", WISHLIST = "wishlist", CLASSES = "classes" }

-- Tab names by category, for breadcrumbs such as a search result's tooltip.
UI.tabLabels = {}
for _, info in ipairs(TABS) do UI.tabLabels[info.key] = info.label end

local EMPTY_TEXT = {
    DUNGEON = L["No dungeons loaded."],
    RAID = L["Raid loot arrives with the data pipeline."],
    PVP = L["No PvP rewards loaded."],
    FACTION = L["No faction rewards loaded."],
    COLLECTION = L["No collections loaded."],
    PROFESSION = L["No professions loaded."],
}

-- Column labels where "instances" and "encounters" don't fit the tab.
local PANE_LABELS = {
    PVP = { L["Rewards"], L["Requirement"] },
    FACTION = { L["Factions"], L["Standing"] },
    COLLECTION = { L["Collections"], L["Categories"] },
    PROFESSION = { L["Professions"], L["Recipes"] },
}
local DEFAULT_LABELS = { L["Instances"], L["Encounters"] }
-- Left of the first pane's label: the world map's entrance portals, War
-- Mode's crossed swords on PvP, and the micro menu's guild banner, Legacy
-- and Professions buttons.
local PANE_ICONS = {
    DUNGEON = "Dungeon",
    RAID = "Raid",
    PVP = "pvptalents-warmode-swords",
    FACTION = "GuildCommunities-up-c60",
    COLLECTION = "Legacy-up-c60",
    PROFESSION = "Professions-up-c60",
}
-- The entrance portals have empty space around them, so they are drawn
-- larger to fill the strip like the other tabs' icons.
local PANE_ICON_SIZES = { DUNGEON = 34, RAID = 34 }
-- Library, the Shopping List and Wishlist have no first pane; Settings
-- shows each with the first of these the client has (Library: the quest
-- log's lore book). Classes shows its icon in Settings and on its class
-- column's label.
local WHOLE_BODY_ICONS = {
    LIBRARY_BOOKS = { "Campaign-QuestLog-LoreBook" },
    SHOPPING = { "Auctioneer", "Banker" },
    WISHLIST = { "auctionhouse-icon-favorite", "PetJournal-FavoritesIcon" },
    CLASSES = { "Talents-up-c60" },
}

-- A tab's icon (an atlas), for its row in Settings; nil if it has none.
function UI.TabIcon(key)
    if PANE_ICONS[key] then return PANE_ICONS[key] end
    for _, atlas in ipairs(WHOLE_BODY_ICONS[key] or {}) do
        if C_Texture.GetAtlasInfo(atlas) then return atlas end
    end
end

-- Space between the first pane's label and the Alliance / Horde toggle.
local FACTION_GAP = 20

-- The second column's width where it isn't Theme.size.encounterList (the first
-- is Theme.size.instanceList, or the Professions tab's filter sidebar):
-- Dungeons and Raids take Theme.size.questList for quest names, and recipe
-- names are long.
local SECOND_WIDTHS = { DUNGEON = Size.questList, RAID = Size.questList, PROFESSION = 315 }
-- The recipe list's strip: the Filter recipes box from its left edge to the
-- count of recipes listed at its right (UI/RecipeBand.lua), this far apart.
local RECIPE_FILTER = { INSET = 12, COUNT_GAP = 8, HEIGHT = 20 }

-- The tabs that list dungeons and raids: their pages have layout maps,
-- breadcrumbs and one loot row per item name.
local INSTANCE_TABS = { DUNGEON = true, RAID = true }
-- The tabs whose loot pages take the loot filters (Mike).
local LOOT_FILTER_TABS = { DUNGEON = true, RAID = true, PVP = true, COLLECTION = true }

-- Loot pages draw their grid at this size, so a raid boss's list scrolls
-- less; Professions keep full size.
local SMALL_GRID = { DUNGEON = true, RAID = true, PVP = true, FACTION = true, COLLECTION = true }
local SMALL_GRID_SCALE = 0.8
UI.smallGridScale = SMALL_GRID_SCALE  -- quest rewards are drawn like it

-- Game skill colors: orange (learnable), yellow, green, gray.
local SKILL_COLORS = { "ff8040", "ffff00", "40bf40", "808080" }

local function SkillText(skill)
    local parts = {}
    for i, value in ipairs(skill) do
        parts[i] = ("|cff%s%d|r"):format(SKILL_COLORS[i], value)
    end
    return table.concat(parts, "  ")
end
UI.SkillText = SkillText  -- the Classes tab's poison pages (UI/Poisons.lua)

-- `one` ("1 result") for a count of one, else `many` ("%d results") filled in.
local function CountText(count, one, many)
    return count == 1 and one or many:format(count)
end

-- Loot of an encounter whose bosses each drop their own (items carry
-- boss = N): a fold per boss heading its items, in Bosses.lua order. Built
-- once per encounter, so a redraw hands the pane the same list (it keeps
-- the list's trainers in order); the folds' open or shut states are
-- remembered by each boss's NPC ID (UI/LootGrid.lua's FoldMemoryKey).
local function BossFolds(encounter, bosses)
    if encounter.folds ~= nil then return encounter.folds or encounter.loot end
    encounter.folds = false
    if not (bosses and #bosses > 1 and encounter.loot[1] and encounter.loot[1].boss) then return encounter.loot end
    local byBoss = {}
    for _, entry in ipairs(encounter.loot) do
        local bossNumber = entry.boss or 0
        byBoss[bossNumber] = byBoss[bossNumber] or {}
        table.insert(byBoss[bossNumber], entry)
    end
    local out = {}
    for bossNumber, boss in ipairs(bosses) do
        local items = byBoss[bossNumber]
        if items then
            table.insert(out, { fold = true, key = bossNumber, boss = boss, count = #items })
            for _, entry in ipairs(items) do table.insert(out, entry) end
        end
    end
    encounter.folds = out
    return out
end

-- An encounter's loot as the loot pane lists it: on the PvP tab under a
-- fold per class (UI/LootGrid.lua's ClassFolds), elsewhere under a fold per
-- boss when its bosses drop their own (BossFolds), else as it is. Built
-- once per encounter, like BossFolds.
local function LootFolds(instance, encounter, bosses)
    if instance.category ~= "PVP" then return BossFolds(encounter, bosses) end
    if encounter.folds == nil then encounter.folds = UI.ClassFolds(encounter.loot) or false end
    return encounter.folds or encounter.loot
end

-- A dungeon boss's abilities (Data/Abilities.lua) as loot pane entries,
-- under each boss's name when an encounter has several; nil when none are
-- known. Raid bosses are left out for now: Forever is the most likely to
-- have changed them. Built once per encounter; `.count` is how many
-- abilities it lists, the boss headings left out.
local function AbilityEntries(instance, encounter, bosses)
    if instance.category ~= "DUNGEON" or not bosses then return nil end
    if encounter.abilities ~= nil then return encounter.abilities or nil end
    -- boss[1] is the boss's name, boss[5] its NPC ID (Data/Bosses.lua).
    local spellsByBoss, bossesWithSpells = {}, 0
    for i, boss in ipairs(bosses) do
        spellsByBoss[i] = ns.Data:Abilities(boss[5])
        if spellsByBoss[i] then bossesWithSpells = bossesWithSpells + 1 end
    end
    local out, abilityCount = {}, 0
    for i, boss in ipairs(bosses) do
        local spells = spellsByBoss[i]
        -- A boss heading only over several bosses' lists.
        if spells and bossesWithSpells > 1 then table.insert(out, { header = boss[1] }) end
        for _, spellID in ipairs(spells or {}) do
            -- Skip a spell the Forever client doesn't have.
            if C_Spell.DoesSpellExist(spellID) then
                table.insert(out, { ability = spellID, observed = ns.Data:Observed(boss[5], spellID) })
                abilityCount = abilityCount + 1
            end
        end
    end
    out.count = abilityCount
    encounter.abilities = out[1] and out or false
    return encounter.abilities or nil
end

-- Asks the client for each ability's spell data, calling `done` once for
-- the ones not loaded yet (their descriptions show once they arrive).
local function LoadAbilities(entries, done)
    local waiting = 0
    for _, entry in ipairs(entries) do
        local spell = entry.ability and Spell:CreateFromSpellID(entry.ability)
        if spell and not spell:IsSpellDataCached() then
            waiting = waiting + 1
            spell:ContinueOnSpellLoad(function()
                waiting = waiting - 1
                if waiting == 0 then done() end
            end)
        end
    end
end

-- Whether the recipe page lists who teaches `encounter` (trainers of the
-- player's side, or serving both; UI/LootGrid.lua).
local function HasTrainers(encounter)
    return encounter.spellID ~= nil and #ns.UI.RecipeTrainers(encounter.spellID) > 0
end

-- The Learned from box's entries with the recipe's trainers added
-- (taughtBy, drawn by UI/LootGrid.lua): under its last recipe item, a copy
-- so the item's own entry is left as it is, or on their own when no item
-- teaches it.
local function WithTrainers(recipes, spellID)
    if #recipes == 0 then return { { taughtBy = spellID } } end
    local out = {}
    for i, entry in ipairs(recipes) do out[i] = entry end
    local last = {}
    for key, value in pairs(recipes[#recipes]) do last[key] = value end
    last.taughtBy = spellID
    out[#out] = last
    return out
end

-- A profession entry in the loot pane: what it makes and how it is learned
-- (the recipe item that teaches it, and its trainers; side by side when
-- there is one of each), then its materials, each section in a stat box
-- like the Overview's. Items that only need the skill to use (and gathered
-- herbs and fish) are shown on their own.
local function RecipeEntries(encounter)
    local made, recipes = {}, {}
    for _, entry in ipairs(encounter.loot) do
        table.insert(entry.recipe and recipes or made, entry)
    end
    if not encounter.spellID then return made end
    local creates = #made > 0 and L["Creates"] or L["Enchant"]
    if #made == 0 then made = { { spellID = encounter.spellID } } end
    if HasTrainers(encounter) then recipes = WithTrainers(recipes, encounter.spellID) end
    local out = {}
    if #made == 1 and #recipes == 1 then
        -- The product and the recipe that teaches it share a line.
        table.insert(out, { header = creates, header2 = L["Learned from"], box = true })
        table.insert(out, made[1])
        table.insert(out, recipes[1])
    else
        table.insert(out, { header = creates, box = true })
        for _, entry in ipairs(made) do table.insert(out, entry) end
        if #recipes > 0 then
            table.insert(out, { header = L["Learned from"], box = true })
            for _, entry in ipairs(recipes) do table.insert(out, entry) end
        end
    end
    if encounter.reagents and #encounter.reagents > 0 then
        table.insert(out, { header = L["Materials"], box = true })
        for _, reagent in ipairs(encounter.reagents) do
            -- Materials that are crafted themselves link to their recipe.
            local profession, recipe = ns.Data:RecipeFor(reagent.itemID)
            if recipe and recipe ~= encounter then
                reagent = { itemID = reagent.itemID, count = reagent.count, craft = { profession, recipe } }
            end
            table.insert(out, reagent)
        end
    end
    return out
end

-- A Scarce reagent's page: where it is gathered, easiest first, one cell
-- per node or mob (see LootGrid's SetGather), in a stat box like a recipe's.
local function ScarceEntries(instance, encounter)
    local out = { { gap = 10 }, { header = L["Gathered from  ·  %d"]:format(#encounter.sources), box = true } }
    for _, src in ipairs(encounter.sources) do
        table.insert(out, { gather = src, profession = instance })
    end
    return out
end

local function ScarceTitle(encounter)
    local icon = C_Item.GetItemIconByID(encounter.itemID)
    return icon and ("|T%s:20:20:0:0:64:64:5:59:5:59|t  %s"):format(icon, encounter.name) or encounter.name
end

-- How a recipe is learned ("Trainer · Recipe", already in the player's
-- language), less "Trainer" when its Learned from box names the trainers.
local function LearnedText(encounter)
    if not HasTrainers(encounter) then return encounter.learned end
    local kept = {}
    for _, part in ipairs(ns.Names.SplitParts(encounter.learned)) do
        if not ns.Names.IsTrainerPart(part) then table.insert(kept, part) end
    end
    return ns.Names.JoinParts(kept)
end

local function RecipeSubtitle(instance, encounter)
    local parts = { instance.name }
    if encounter.skill and #encounter.skill > 1 then
        table.insert(parts, L["Skill  %s"]:format(SkillText(encounter.skill)))
    elseif encounter.skill then
        table.insert(parts, L["Requires %d"]:format(encounter.skill[1]))
    end
    if encounter.gather then table.insert(parts, L["Mineable at %d"]:format(encounter.gather)) end
    if encounter.note == "new" then
        table.insert(parts, L["New in Forever"])
    elseif encounter.note and encounter.note ~= "use" then
        table.insert(parts, encounter.note)
    end
    if encounter.learned then table.insert(parts, LearnedText(encounter)) end
    return Theme:JoinDots(unpack(parts))
end

-- Lists only one side can use (PvP vendors) are shown for one faction at a
-- time. Returns the filtered list and whether any entry had a faction.
local function ForFaction(list, faction)
    local out, any = {}, false
    for _, instance in ipairs(list) do
        any = any or instance.faction ~= nil
        if not instance.faction or instance.faction == faction then table.insert(out, instance) end
    end
    return out, any
end

-- A saved position on UIParent ({ point, relativePoint, x, y }) the game
-- takes: two anchor names and two plain numbers. Anything else (a secret
-- value, nil, NaN, a far-off number) is dropped, and the window opens
-- centred again (the run tracker's line, UI/RunTracker.lua, goes back under
-- the minimap).
local ANCHOR_POINTS = { TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true, RIGHT = true,
    BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true }
function UI.IsUsablePoint(saved)
    if type(saved) ~= "table" then return false end
    local point, relPoint, x, y = ns.Plain(saved[1]), ns.Plain(saved[2]), ns.Plain(saved[3]), ns.Plain(saved[4])
    if type(point) ~= "string" or type(relPoint) ~= "string" then return false end
    if not (ANCHOR_POINTS[point] and ANCHOR_POINTS[relPoint]) then return false end
    -- x ~= x is true only for NaN.
    if type(x) ~= "number" or type(y) ~= "number" or x ~= x or y ~= y then return false end
    return math.abs(x) < 10000 and math.abs(y) < 10000
end

local function SavePosition(window)
    local point, _, relPoint, x, y = window:GetPoint()
    local saved = { point, relPoint, x, y }
    ns.db.window.point = UI.IsUsablePoint(saved) and saved or nil
end

-- Anchors the window by its top-left corner where it stands. Sizing from the
-- grip drags the bottom-right corner, which only follows the cursor when the
-- top-left is the anchor; from a saved CENTER anchor the window jumped to
-- full size on the first grab (Mike, 2026-10-18). Moving it re-anchored it,
-- which is why a drag first hid the bug.
local function PinTopLeft(window)
    local left, top = window:GetLeft(), window:GetTop()
    if not (left and top) then return end
    window:ClearAllPoints()
    window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
end

local function SaveSize(window)
    ns.db.window.width = math.floor(window:GetWidth() + 0.5)
    ns.db.window.height = math.floor(window:GetHeight() + 0.5)
end

-- Pressing the left button on `handle` moves the window until it's let go,
-- and where it's left is saved. The move starts on the press, not on the
-- game's drag (which waits for the cursor to travel a few pixels), so the
-- window follows the cursor at once. It is pinned by its top-left first:
-- from a saved CENTER anchor a move snapped about (Mike, 2026-10-19), as
-- sizing did (PinTopLeft). While the padlock by the X has locked the window
-- (CreateLockButton), a press moves nothing; the grip still resizes it.
local function MakeDragHandle(handle, window)
    handle:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or ns.db.window.locked then return end
        self.moving = true
        PinTopLeft(window)
        window:StartMoving()
    end)
    handle:SetScript("OnMouseUp", function(self)
        if not self.moving then return end
        self.moving = nil
        window:StopMovingOrSizing()
        SavePosition(window)
        -- A position the game wouldn't hand back as plain numbers: placed
        -- afresh (centred) rather than left where it can't be drawn.
        if not ns.db.window.point then UI:PlaceWindow() end
    end)
end

-- A thin line drawn as a rotated white texture, for drawn icons that don't
-- rely on a glyph the font may lack.
local function AddStroke(parent, width, height, degrees, color)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 1, 1, 1)
    line:SetSize(width, height)
    line:SetRotation(math.rad(degrees))
    line:SetVertexColor(unpack(color))
    return line
end

local function TintStrokes(strokes, color)
    for _, line in ipairs(strokes) do line:SetVertexColor(unpack(color)) end
end

local function CreateCloseButton(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(28, 28)
    local strokes = { AddStroke(btn, 13, 1.5, 45, Theme.color.muted), AddStroke(btn, 13, 1.5, -45, Theme.color.muted) }
    for _, line in ipairs(strokes) do line:SetPoint("CENTER") end
    btn:SetScript("OnEnter", function() TintStrokes(strokes, Theme.color.heading) end)
    btn:SetScript("OnLeave", function() TintStrokes(strokes, Theme.color.muted) end)
    btn:SetScript("OnClick", function() UI:Hide() end)
    return btn
end

-- The padlock left of the window's X, drawn from strokes as the X is, so it
-- looks the same in every style: a filled body under a shackle (two legs
-- and a top). Locked, both legs stand on the body; unlocked, the shackle
-- rises and its left leg lifts clear of the body, an open padlock.
local LOCK = {
    button = 22,          -- the button, square
    bodyWidth = 10,
    bodyHeight = 7,
    bodyDrop = 2.5,       -- the body's centre below the button's, so the whole padlock sits centred
    stroke = 1.5,         -- the shackle's thickness, as the X's strokes
    shackleInset = 1,     -- each leg in from the body's side
    shackleHeight = 5,    -- a leg, from the body's top to the shackle's top
    lift = 3,             -- how far the shackle rises when unlocked
}

-- Puts the shackle down on the body (locked) or raised (unlocked). The right
-- leg stays in the body and grows; the left one moves up off it.
local function DrawLock(lock)
    local lift = ns.db.window.locked and 0 or LOCK.lift
    lock.leftLeg:ClearAllPoints()
    lock.leftLeg:SetPoint("BOTTOMLEFT", lock.body, "TOPLEFT", LOCK.shackleInset, lift)
    lock.rightLeg:SetHeight(LOCK.shackleHeight + lift)
end

-- Names what a click does next, and what that means.
local function ShowLockTooltip(lock)
    GameTooltip:SetOwner(lock, "ANCHOR_BOTTOMLEFT")
    local isLocked = ns.db.window.locked
    GameTooltip:AddLine(isLocked and L["Unlock window"] or L["Lock window"], unpack(Theme.tip.title))
    local r, g, b = unpack(Theme.tip.text)
    if isLocked then
        GameTooltip:AddLine(L["Lets you drag the window to move it."], r, g, b, true)
    else
        GameTooltip:AddLine(L["Stops the window being moved by dragging."], r, g, b, true)
    end
    GameTooltip:Show()
end

-- A click locks or unlocks the window where it stands (ns.db.window.locked,
-- read by MakeDragHandle). Muted, `heading` on hover, as the X.
local function CreateLockButton(parent, window)
    local lock = CreateFrame("Button", nil, parent)
    lock:SetSize(LOCK.button, LOCK.button)
    local muted = Theme.color.muted
    lock.body = AddStroke(lock, LOCK.bodyWidth, LOCK.bodyHeight, 0, muted)
    lock.body:SetPoint("CENTER", 0, -LOCK.bodyDrop)
    lock.leftLeg = AddStroke(lock, LOCK.stroke, LOCK.shackleHeight, 0, muted)
    lock.rightLeg = AddStroke(lock, LOCK.stroke, LOCK.shackleHeight, 0, muted)
    lock.rightLeg:SetPoint("BOTTOMRIGHT", lock.body, "TOPRIGHT", -LOCK.shackleInset, 0)
    local shackleTop = AddStroke(lock, LOCK.stroke, LOCK.stroke, 0, muted)
    shackleTop:SetPoint("TOPLEFT", lock.leftLeg, "TOPLEFT")
    shackleTop:SetPoint("TOPRIGHT", lock.rightLeg, "TOPRIGHT")
    local pieces = { lock.body, lock.leftLeg, lock.rightLeg, shackleTop }
    lock:SetScript("OnEnter", function(self)
        TintStrokes(pieces, Theme.color.heading)
        ShowLockTooltip(self)
    end)
    lock:SetScript("OnLeave", function()
        TintStrokes(pieces, muted)
        GameTooltip_Hide()
    end)
    lock:SetScript("OnClick", function(self)
        ns.db.window.locked = not ns.db.window.locked
        DrawLock(self)
        if GameTooltip:IsOwned(self) then ShowLockTooltip(self) end
    end)
    -- Another style's window may have been locked or unlocked while this
    -- one was put away (UI:SetSkin keeps each style's window).
    window:HookScript("OnShow", function() DrawLock(lock) end)
    DrawLock(lock)
    return lock
end

-- Small "!" next to the search box, a gold pill like Back's. Hover explains
-- why some items can't be obtained, or show little detail, in WoW: Forever.
local function CreateSearchNote(parent)
    local btn = Theme:Pill(parent)
    btn:SetLabel("!")
    btn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:AddLine(L["About some items"], unpack(Theme.tip.title))
        local r, g, b = unpack(Theme.tip.text)
        GameTooltip:AddLine(L["Some items in the game client are leftovers from Season of Discovery. They can turn up in search, but can't be obtained in WoW: Forever."],
            r, g, b, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["Items changed for WoW: Forever are hidden by the game until it has shown them to you, for example once one drops from a boss or you find its recipe. Until then their details can be missing."],
            r, g, b, true)
        GameTooltip:Show()
    end)
    btn:HookScript("OnLeave", GameTooltip_Hide)
    return btn
end

-- The game's top tab (PanelTopTabButtonTemplate): gold text, white and
-- raised when selected.
local function CreateNativeTab(parent, info)
    local tab = CreateFrame("Button", nil, parent, "PanelTopTabButtonTemplate")
    tab.key = info.key
    tab:SetText(info.label)
    PanelTemplates_TabResize(tab, 0)
    function tab:SetActive(on)
        self.active = on
        if on then PanelTemplates_SelectTab(self) else PanelTemplates_DeselectTab(self) end
    end
    tab:SetScript("OnClick", function(self)
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
        UI:SwitchTab(self.key)
    end)
    return tab
end

local function CreateTab(parent, info)
    if Theme.native then return CreateNativeTab(parent, info) end
    local tab = CreateFrame("Button", nil, parent)
    tab.key = info.key
    tab.label = Theme:Text(tab, Theme.font.tab)
    tab.label:SetPoint("CENTER", 0, 1)
    tab.label:SetText(info.label)
    tab:SetSize(tab.label:GetStringWidth() + 28, Size.tabs)
    tab.underline = tab:CreateTexture(nil, "ARTWORK")
    tab.underline:SetColorTexture(unpack(Theme.color.heading))
    tab.underline:SetPoint("BOTTOMLEFT", 12, 0)
    tab.underline:SetPoint("BOTTOMRIGHT", -12, 0)
    tab.underline:SetHeight(2)
    function tab:SetActive(on)
        self.active = on
        self.underline:SetShown(on)
        Theme:SetTextColor(self.label, on and Theme.color.heading or Theme.color.muted)
    end
    tab:SetScript("OnEnter", function(self)
        if not self.active then Theme:SetTextColor(self.label, Theme.color.text) end
    end)
    tab:SetScript("OnLeave", function(self) self:SetActive(self.active) end)
    tab:SetScript("OnClick", function(self) UI:SwitchTab(self.key) end)
    return tab
end

-- Back, at the left of the content pane's strip: a pill naming the place
-- it returns to. Its tooltip lists the whole trail.
local function CreateBackButton(parent)
    local btn = Theme:Pill(parent, "back")
    btn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:AddLine(L["Back"])
        for i = #UI.history, 1, -1 do GameTooltip:AddLine(UI.history[i].label, unpack(Theme.tip.info)) end
        GameTooltip:Show()
    end)
    btn:HookScript("OnLeave", GameTooltip_Hide)
    btn:SetScript("OnClick", function() UI:GoBack() end)
    return btn
end

-- Beside Back: the game's tutorial mouse with its right button lit, and
-- "to go back!", since right-clicking the page also goes back.
local BACK_HINT_ATLAS = "newplayertutorial-icon-mouse-rightbutton"

local function CreateBackHint(parent)
    local hint = CreateFrame("Frame", nil, parent)
    hint:SetSize(1, 20)
    hint.icon = hint:CreateTexture(nil, "ARTWORK")
    Theme:FitAtlas(hint.icon, BACK_HINT_ATLAS, 20)
    hint.icon:SetPoint("LEFT")
    hint.text = Theme:Text(hint, Theme.font.body)
    hint.text:SetPoint("LEFT", hint.icon, "RIGHT", 4, 0)
    hint.text:SetText(L["to go back!"])
    Theme:SetTextColor(hint.text, Theme.color.text)
    hint.text:SetAlpha(0.8)
    hint:SetWidth(hint.icon:GetWidth() + 4 + hint.text:GetStringWidth())
    return hint
end

local STRIP_INSET = Size.pad - 4  -- Back and the right-hand buttons, from the strip's ends
local STRIP_BUTTON_GAP = 6     -- between the buttons at the strip's right
local BACK_HINT_GAP = 10       -- between Back and its hint

local function PlaceBack(back, strip)
    back:SetPoint("LEFT", STRIP_INSET, 0)
    local hint = CreateBackHint(strip)
    hint:SetPoint("LEFT", back, "RIGHT", BACK_HINT_GAP, 0)
    return hint
end

-- "Add to shopping list", at the right of the strip on recipes that make
-- an item. Each click adds one more craft's worth. `Recipe()` gives the
-- recipe's list (a profession, or a class's own recipes) and the recipe.
local function CreateAddButton(parent, Recipe)
    local btn = Theme:Pill(parent, "plus")
    btn:HookScript("OnEnter", function(self)
        local _, encounter = Recipe()
        local made = encounter and encounter.loot[1]
        if not made then return end
        local _, entry = ns.Shopping:Find(made.itemID)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:AddLine(L["Shopping list"])
        local r, g, b = unpack(Theme.tip.text)
        GameTooltip:AddLine(L["Adds %s and its materials to the Shopping List tab."]:format(encounter.name),
            r, g, b, true)
        if entry then GameTooltip:AddLine(L["On your list: %d"]:format(entry.count), unpack(Theme.tip.info)) end
        GameTooltip:Show()
    end)
    btn:HookScript("OnLeave", GameTooltip_Hide)
    btn:SetScript("OnClick", function(self)
        local instance, encounter = Recipe()
        local count = ns.Shopping:Add(instance, encounter)
        if count then UI.status:SetText(L["On shopping list: %dx %s"]:format(count, encounter.name)) end
        if self:IsMouseOver() then self:GetScript("OnEnter")(self) end
    end)
    -- Its label for the recipe: how many are on the list already.
    function btn:UpdateLabel()
        local _, encounter = Recipe()
        local _, entry = ns.Shopping:Find(encounter.loot[1].itemID)
        self:SetLabel(entry and L["Add another  ·  %d on list"]:format(entry.count) or L["Add to shopping list"])
    end
    return btn
end
UI.CreateAddButton = CreateAddButton  -- the Classes tab's poison pages (UI/Poisons.lua)

-- Loot / Abilities, at the right of the strip on a dungeon boss with known
-- abilities: two pills, the page showing filled.
local function CreateBossTab(parent, key)
    local btn = Theme:Pill(parent)
    btn.key = key
    btn:SetScript("OnClick", function(self)
        GameTooltip:Hide()
        UI:SetBossTab(self.key)
    end)
    return btn
end

-- Map, at the right of the strip on a dungeon or raid boss pinned on its
-- layout map: opens the map on the boss's floor with its pin lit.
local MAP_ICON = 14
local function CreateMapButton(parent)
    local btn = Theme:Pill(parent)
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    Theme:FitAtlas(btn.icon, "FullMap-up-c60", MAP_ICON)
    btn.icon:SetPoint("LEFT", 8, 0)
    btn.text:SetPoint("LEFT", 12 + MAP_ICON, 0)
    btn:SetLabel(L["Map"])
    btn:SetWidth(btn:GetWidth() + MAP_ICON + 2)
    btn:HookScript("OnEnter", function(self)
        local encounter = UI.state.encounter
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:AddLine(L["Map"])
        local r, g, b = unpack(Theme.tip.text)
        GameTooltip:AddLine(L["Shows where %s is on the map."]:format(encounter and encounter.name or ""),
            r, g, b, true)
        GameTooltip:Show()
    end)
    btn:HookScript("OnLeave", GameTooltip_Hide)
    btn:SetScript("OnClick", function()
        GameTooltip:Hide()
        UI:ShowBossOnMap()
    end)
    return btn
end

-- A content pane with a strip across its top for Back and the page's
-- actions. The host draws the panel and the strip; the pages inside it
-- (their own backdrops hidden) move down while the strip shows. Shown
-- while any of its pages is. Right-clicking it goes back, like the pages.
local STRIP_HEIGHT = 30

local function CreateHost(parent, pages)
    local host = Theme:CreatePanel(parent, "loot")
    host:SetFrameLevel(parent:GetFrameLevel())
    host.strip = Theme:PaneStrip(host, STRIP_HEIGHT)
    -- Takes clicks on the strip and the pages' empty space, for right-click
    -- Back; a left press there moves the window, as the window's own
    -- background does (the pane would otherwise catch it first).
    host:EnableMouse(true)
    MakeDragHandle(host, UI.frame)
    local function Track()
        local shown = false
        for _, page in ipairs(pages) do shown = shown or page:IsShown() end
        host:SetShown(shown)
    end
    -- Hooked on the calls rather than OnShow/OnHide: a page hidden while
    -- the window is closed (Settings shutting as the window closes) fires
    -- no OnHide, which left its host's strip over the next tab.
    for _, page in ipairs(pages) do
        Theme:Unframe(page)
        page:SetFrameLevel(host:GetFrameLevel() + 2)
        hooksecurefunc(page, "Show", Track)
        hooksecurefunc(page, "Hide", Track)
        hooksecurefunc(page, "SetShown", Track)
    end
    pages[1]:SetPoint("BOTTOMRIGHT", host)
    -- Shows the strip or not, moving the first page (the others are
    -- anchored to it) down under it.
    -- The offset is in the page's own units, so a scaled page (the Shopping
    -- List) divides it by its scale to land right under the strip.
    function host:SetStrip(shown)
        self.strip:SetShown(shown)
        pages[1]:SetPoint("TOPLEFT", self, "TOPLEFT", 0, shown and -STRIP_HEIGHT / pages[1]:GetScale() or 0)
    end
    host:SetStrip(false)
    Track()
    return host
end

-- Alliance / Horde toggle in the first pane's header (Theme:FactionToggle),
-- on the tabs whose lists are one side's at a time.
local function CreateFactionToggle(parent)
    local toggle = Theme:FactionToggle(parent, function(faction) UI:SelectFaction(faction) end)
    function toggle:Refresh() self:SetSide(UI.state.faction) end
    return toggle
end

-- The saved text size ("normal" or "large").
local function TextSize()
    return Theme.textScale[ns.db.textSize] and ns.db.textSize or "normal"
end

-- Bottom-right grip that resizes the window: three short diagonal strokes
-- (modern) or the game's chat-window size grabber (native). Double-click
-- puts the default size back.
local function CreateResizeGrip(window)
    local grip = CreateFrame("Button", nil, window)
    grip:SetFrameLevel(window:GetFrameLevel() + 20)
    if Theme.native then
        grip:SetSize(16, 16)
        grip:SetPoint("BOTTOMRIGHT", -4, 4)
        grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
        grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    else
        grip:SetSize(14, 14)
        grip:SetPoint("BOTTOMRIGHT", -3, 3)
        local strokes = {}
        for _, length in ipairs({ 4, 8, 12 }) do
            local line = AddStroke(grip, length * math.sqrt(2), 1, 45, Theme.color.faint)
            line:SetPoint("CENTER", grip, "BOTTOMRIGHT", -length / 2, length / 2)
            table.insert(strokes, line)
        end
        grip.Tint = function(_, color) TintStrokes(strokes, color) end
    end
    grip:SetScript("OnEnter", function(self)
        if self.Tint then self:Tint(Theme.color.heading) end
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:AddLine(L["Resize"])
        local r, g, b = unpack(Theme.tip.text)
        GameTooltip:AddLine(L["Drag to resize. Double-click for the default size."], r, g, b, true)
        GameTooltip:AddLine(L["Also: /nr reset"], unpack(Theme.tip.quiet))
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function(self)
        if self.Tint and not self.sizing then self:Tint(Theme.color.faint) end
        GameTooltip:Hide()
    end)
    grip:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        GameTooltip:Hide()
        self.sizing = true
        PinTopLeft(window)
        window:StartSizing("BOTTOMRIGHT")
    end)
    grip:SetScript("OnMouseUp", function(self)
        if not self.sizing then return end
        self.sizing = nil
        window:StopMovingOrSizing()
        if self.Tint and not self:IsMouseOver() then self:Tint(Theme.color.faint) end
        SaveSize(window)
        SavePosition(window)
    end)
    grip:SetScript("OnDoubleClick", function() UI:ResetWindow(true) end)
    return grip
end

local TITLE_ICON = "lootroll-toast-icon-need-up"  -- beside the window's name
local NATIVE_HEADER_HEIGHT = 22  -- the native window's title bar
-- The native window's row between the title bar and the tabs, holding the
-- search box, its "!" and Settings, so every tab gets the window's full
-- width (Mike, 2026-10-18). As tall as the tab strip, so they keep their size.
local NATIVE_SEARCH_ROW = Size.tabs

-- The Need roll icon left of the native window's name, centred in the title
-- bar by a holder of their own (the template's title string spans the bar).
local function AddNativeTitle(window)
    -- TitleContainer comes from PortraitFrameBaseTemplate (under ButtonFrameTemplate); older clients had TitleText.
    local templateTitle = window.TitleContainer and window.TitleContainer.TitleText or window.TitleText
    if not templateTitle then return end
    local titleBar = window.TitleContainer or window
    local _, size = templateTitle:GetFont()
    local holder = CreateFrame("Frame", nil, titleBar)
    holder:SetFrameLevel(titleBar:GetFrameLevel() + 5)
    local icon = holder:CreateTexture(nil, "OVERLAY")
    Theme:FitAtlas(icon, TITLE_ICON, math.floor((size or 12) + 6))
    icon:SetPoint("LEFT")
    local name = holder:CreateFontString(nil, "OVERLAY")
    name:SetFontObject(templateTitle:GetFontObject())
    name:SetTextColor(templateTitle:GetTextColor())
    name:SetText("NeedRoll")
    name:SetPoint("LEFT", icon, "RIGHT", 3, 0)
    holder:SetSize(icon:GetWidth() + 3 + name:GetStringWidth(), icon:GetHeight())
    holder:SetPoint("CENTER", window, "TOP", 0, -NATIVE_HEADER_HEIGHT / 2 - 1)
    templateTitle:SetText("")
end

-- The window's scale: 1, or 4/3 with Large text (Theme.textScale). Every pane
-- is laid out in the window's own units, so scaling the whole window grows
-- text, rows, icons and columns together and each pane's fitting (names
-- cut short, the loot grid going one to a line) works as at Normal. Where
-- the screen can't hold the window's smallest size (Theme.size.minWidth /
-- minHeight) that large, it is drawn as large as fits instead, so no pane
-- is ever narrower than it was made for.
function UI:WindowScale()
    local want = (ns.db.window.scale or 1) * Theme.textScale[TextSize()]
    if want <= 1 then return want end
    local fit = math.min(UIParent:GetWidth() / Size.minWidth, UIParent:GetHeight() / Size.minHeight)
    return math.max(1, math.min(want, fit))
end

-- Size and position come from the saved settings, shared by every style.
-- The window can grow to fill the screen but not shrink below the size
-- that still shows everything (Theme.size.minWidth / minHeight).
function UI:PlaceWindow()
    local window = self.frame
    local db = ns.db.window
    window:ClearAllPoints()
    window:SetScale(self:WindowScale())
    local scale = window:GetScale()
    local maxWidth = math.max(Size.minWidth, math.floor(UIParent:GetWidth() / scale))
    local maxHeight = math.max(Size.minHeight, math.floor(UIParent:GetHeight() / scale))
    window:SetResizeBounds(Size.minWidth, Size.minHeight, maxWidth, maxHeight)
    local width = math.min(math.max(db.width or Size.width, Size.minWidth), maxWidth)
    local height = math.min(math.max(db.height or Size.height, Size.minHeight), maxHeight)
    window:SetSize(width, height)
    local point = db.point
    local placed = point and UI.IsUsablePoint(point)
        and pcall(window.SetPoint, window, point[1], UIParent, point[2], point[3], point[4])
    if not placed then
        db.point = nil
        window:ClearAllPoints()
        window:SetPoint("CENTER")
    end
end

-- The search's room on the right: the native template's for its clear
-- button, for typed text and hint alike; the modern hint's, which needs no
-- room for the cross since the cross only shows once there is text.
local NATIVE_SEARCH_RIGHT = 20
local MODERN_HINT_RIGHT = 8

-- The search box, its "!" and Settings, `height` tall (80% of the row they
-- sit in, Mike), their text and icons grown to match.
function UI:SizeTopBar(height)
    local search, note, settings = self.search, self.searchNote, self.settingsButton
    local native = Theme.native
    local growth = height / (native and 20 or 24)  -- the box's own height is 20 (native) or 24
    -- The search box 50 wider than it was; its text 4pt under the grown
    -- size (Mike), so the hint fits on one line.
    search:SetSize(search:GetWidth() + 50, height)
    local function GrownLessFour(font)
        local _, size = font:GetFont()
        return Theme:ScaledFont(font, ((size or 12) * growth - 4) / (size or 12))
    end
    search:SetFontObject(GrownLessFour(Theme.font.body))
    -- The native template's magnifier and hint are its searchIcon and
    -- Instructions; the modern box's are its own icon and hint.
    local icon = native and search.searchIcon or search.icon
    local hint = native and search.Instructions or search.hint
    local iconSize = (native and 14 or 12) * growth * 0.8  -- 80% of the grown size (Mike)
    icon:SetSize(iconSize, iconSize)
    hint:SetFontObject(GrownLessFour(Theme.font.small))
    if native then
        -- The template's edge art has a height of its own: it grows with
        -- the box, so the box looks as tall as Settings and the "!".
        for _, key in ipairs({ "Left", "Middle", "Right" }) do search[key]:SetHeight(height) end
    end
    -- The typed text and the hint start 6 past the magnifier.
    local left = (native and 3 or 9) + icon:GetWidth() + 6
    search:SetTextInsets(left, native and NATIVE_SEARCH_RIGHT or Theme.SEARCH_TEXT_RIGHT, 0, 0)
    hint:ClearAllPoints()
    hint:SetPoint("LEFT", search, "LEFT", left, 0)
    hint:SetPoint("RIGHT", search, "RIGHT", -(native and NATIVE_SEARCH_RIGHT or MODERN_HINT_RIGHT), 0)
    note:SetHeight(height)
    note.text:SetFontObject(Theme:ScaledFont(Theme.font.body, height / 20))
    note:SetLabel("!")
    note:SetWidth(height)  -- round: as wide as tall
    -- The "!" in the middle of the circle (a pill's label sits 12 in from
    -- its left, right of the middle on a pill this narrow).
    note.text:ClearAllPoints()
    note.text:SetPoint("CENTER", note, "CENTER", 0, 0)
    settings:SetBarHeight(height)
end

-- Default size, centered (/nr reset). The grip's double-click resets only
-- the size and keeps the window's top-left corner where it is.
function UI:ResetWindow(sizeOnly)
    local db = ns.db.window
    db.width, db.height = nil, nil
    if not sizeOnly then db.point = nil end
    local window = self.frame
    if not window then return end
    local left, top = window:GetLeft(), window:GetTop()
    self:PlaceWindow()
    if sizeOnly and left then
        window:ClearAllPoints()
        window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        SavePosition(window)
    end
end

-- Large or Normal text (/nr text, the Settings page): the window is
-- scaled in place, keeping its center where it was, and the page is laid
-- out again at the new size (text measured at one scale can be a pixel
-- off at another).
function UI:ApplyScale()
    local window = self.frame
    if not window then return end
    local x, y = window:GetCenter()
    local before = window:GetScale()
    self:PlaceWindow()
    if x then
        local ratio = before / window:GetScale()
        window:ClearAllPoints()
        window:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x * ratio, y * ratio)
        SavePosition(window)
    end
    if window:GetScale() == before then return end
    self.loot:Remeasure()
    self.loot.searchKey = nil -- search results are drawn again too
    self.instances:Refresh()
    self.encounters:Refresh()
    self:Refresh()
end

-- A new game UI scale or resolution changes how large the window can be
-- drawn (UI:WindowScale) and how large it can grow.
ns:On("UI_SCALE_CHANGED", function() UI:ApplyScale() end)
ns:On("DISPLAY_SIZE_CHANGED", function() UI:ApplyScale() end)

function UI:SetTextSize(name)
    if not Theme.textScale[name] then return end
    ns.db.textSize = name
    self:ApplyScale()
end

-- The connector's lines and patch, drawn by UI:UpdateLink.
local function CreateLink(body)
    local link = CreateFrame("Frame", nil, body)
    link:SetAllPoints()
    link:SetFrameLevel(body:GetFrameLevel() + 10)
    local function NewSegment()
        local tex = link:CreateTexture(nil, "OVERLAY")
        tex:SetColorTexture(unpack(Theme.color.accent))
        return tex
    end
    link.out, link.down, link.into = NewSegment(), NewSegment(), NewSegment()
    link.tabTop, link.tabBottom = NewSegment(), NewSegment()
    -- Fills the gap between the selected row and the loot panel, and the
    -- panel's left border there, with the panel color.
    link.cover = link:CreateTexture(nil, "OVERLAY")
    link.cover:SetColorTexture(unpack(Theme.color.panel2))
    link:Hide()
    return link
end

-- The empty window: the game's ButtonFrameTemplate without its portrait
-- (native) or a flat panel (modern), able to move, resize and close on Escape.
local function CreateMainWindow()
    local window
    if Theme.native then
        window = CreateFrame("Frame", Theme:WindowName(Theme.name), UIParent, "ButtonFrameTemplate")
        ButtonFrameTemplate_HidePortrait(window)
        window.Inset:Hide()
        window:SetTitle("NeedRoll")
        AddNativeTitle(window)
        window.CloseButton:SetScript("OnClick", function() UI:Hide() end)
    else
        window = CreateFrame("Frame", Theme:WindowName(Theme.name), UIParent)
        Theme:Fill(window, Theme.color.bg)
        Theme:Border(window, Theme.color.line)
    end
    window:SetFrameStrata("HIGH")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:SetResizable(true)
    window:EnableMouse(true)
    -- A press on any spot that takes no clicks of its own (the border, the
    -- gaps between panes, the list panes' empty space, the footer) moves
    -- the window too, not only the header.
    MakeDragHandle(window, window)
    window:Hide()
    tinsert(UISpecialFrames, window:GetName()) -- Escape closes the window
    -- Opening and closing make the game's own sounds (Mike's picks from
    -- /nr sounds): the professions book opening, the profession window
    -- closing. A style switch swaps windows silently, and hiding the whole
    -- interface (Alt+Z) leaves the window shown, so neither makes a sound.
    -- Hooked, never set: SetScript on the window would drop these hooks.
    window:HookScript("OnShow", function()
        if UI.swapping or UI.soundOpen then return end
        UI.soundOpen = true
        PlaySound(SOUNDKIT.IG_SPELLBOOK_OPEN)
    end)
    -- However the window closes (Escape, the X, /nr), search work stops with
    -- it (opening it catches up) and Settings gives way to the tabs. What it
    -- showed stays loaded, so it all draws at once when it opens again.
    window:HookScript("OnHide", function(self)
        UI:CancelPendingSearch()
        Theme:KeepLoadedUnder(self)
        if not UI.swapping and not self:IsShown() and UI.soundOpen then
            UI.soundOpen = false
            PlaySound(SOUNDKIT.UI_PROFESSIONS_WINDOW_CLOSE)
        end
        if UI.settingsOpen then UI:CloseSettings() end
    end)
    return window
end

-- The header doubles as the drag handle. The native window's title bar is
-- the header; its close button keeps the right corner.
local function CreateHeader(window)
    local native = Theme.native
    local header = CreateFrame("Frame", nil, window)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT", native and -26 or 0, 0)
    header:SetHeight(native and NATIVE_HEADER_HEIGHT or Size.header)
    header:EnableMouse(true)
    MakeDragHandle(header, window)
    if native then return header end
    -- The Need roll icon, then the name.
    local icon = header:CreateTexture(nil, "ARTWORK")
    local _, size = Theme.font.title:GetFont()
    Theme:FitAtlas(icon, TITLE_ICON, math.floor((size or 15) + 5))
    icon:SetPoint("LEFT", Size.pad + 2, 0)
    local title = Theme:Text(header, Theme.font.title)
    title:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    title:SetText("Need|cfffcd29fRoll|r")
    return header
end

-- The native window's search row, under its title bar.
local function CreateSearchRow(window, header)
    local row = CreateFrame("Frame", nil, window)
    row:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    row:SetPoint("TOPRIGHT", window, "TOPRIGHT", 0, -header:GetHeight())
    row:SetHeight(NATIVE_SEARCH_ROW)
    return row
end

-- The strip the tabs sit on, under the header (and the native search row),
-- so the active underline meets the divider. Native tabs stand on the panes'
-- top edge instead.
local function CreateTabBar(window, header)
    local tabBar = CreateFrame("Frame", nil, window)
    local top = header:GetHeight() + (Theme.native and NATIVE_SEARCH_ROW or 0)
    tabBar:SetPoint("TOPLEFT", window, "TOPLEFT", 0, -top)
    tabBar:SetPoint("TOPRIGHT", window, "TOPRIGHT", 0, -top)
    tabBar:SetHeight(Size.tabs)
    if not Theme.native then Theme:Edge(tabBar, "BOTTOM") end
    return tabBar
end

-- The close button and the padlock left of it, then search, its "!" and
-- Settings, right to left: on the search row above the tabs in the native
-- window, in the header (left of the padlock) in the modern one. Either way
-- the tabs below have the window's whole width. The native window's X is
-- the template's, on its title bar; the padlock sits beside it there, as a
-- child of the header, raised to the X's frame level.
local function CreateTopBar(window, header)
    local native = Theme.native
    local bar = native and CreateSearchRow(window, header) or header
    local close = native and window.CloseButton or CreateCloseButton(header)
    if not native then close:SetPoint("RIGHT", -8, 0) end
    UI.lockButton = CreateLockButton(header, window)
    UI.lockButton:SetPoint("RIGHT", close, "LEFT", 0, 0)
    -- On the X's layer: the native window's title bar art is drawn over the
    -- header's children and would hide the padlock (Mike, 2026-11-07).
    UI.lockButton:SetFrameLevel(close:GetFrameLevel())
    UI.search = Theme:SearchBox(bar, L["Search loot, bosses, dungeons, quests"], native and 210 or 220,
        function(text) UI:QueueSearch(text) end, function() UI:ResumeSearch() end)
    if native then
        UI.search:SetPoint("RIGHT", -Size.gutter - 2, 0)
    else
        UI.search:SetPoint("RIGHT", UI.lockButton, "LEFT", -8, 0)
    end
    UI.searchNote = CreateSearchNote(bar)
    -- The native template's left edge art sits a few pixels outside the box.
    UI.searchNote:SetPoint("RIGHT", UI.search, "LEFT", native and -10 or -6, 0)
    UI.settingsButton = ns.Settings:CreateButton(bar)
    UI.settingsButton:SetPoint("RIGHT", UI.searchNote, "LEFT", -6, 0)
    UI:SizeTopBar(math.floor((native and NATIVE_SEARCH_ROW or Size.header) * 0.8))
end

-- The footer: the click hint at the left, the tab's status and the version
-- note at the right, and the resize grip in the corner.
local FOOTER_INSET = Size.pad + 10  -- the hint and the version note, from the footer's ends
local FOOTER_GAP = 18            -- between the hint, the status and the version note

local function CreateFooter(window)
    local native = Theme.native
    -- Native lifts the footer clear of the frame's thick bottom border art.
    local footerLift = native and 6 or 0
    local footer = CreateFrame("Frame", nil, window)
    footer:SetPoint("BOTTOMLEFT", 0, footerLift)
    footer:SetPoint("BOTTOMRIGHT", 0, footerLift)
    footer:SetHeight(Size.footer)
    if not native then Theme:Edge(footer, "TOP") end
    local hint = Theme:Text(footer, Theme.font.hint)
    hint:SetPoint("LEFT", FOOTER_INSET, 0)
    hint:SetText(L["Shift-click to link   ·   Ctrl-click to preview   ·   Hold Shift to compare"])
    UI.footerHint = hint
    CreateResizeGrip(window)
    UI.status = Theme:Text(footer, Theme.font.hint)
    UI.versionNote = Theme:Text(footer, Theme.font.hint)
    -- The inset leaves the corner to the resize grip.
    UI.versionNote:SetPoint("RIGHT", -FOOTER_INSET, 0)
    -- The hint gives way to the notes at the right when they'd run into it.
    local function FitFooter() UI:FitFooter() end
    hooksecurefunc(UI.status, "SetText", FitFooter)
    footer:SetScript("OnSizeChanged", FitFooter)
    UI:UpdateVersionNote()
    return footer
end

-- Puts the second pane right of `firstPane`, a gutter apart and as tall.
local function PlaceSecondPane(firstPane)
    local gutter = Size.gutter
    UI.encounters:ClearAllPoints()
    UI.encounters:SetPoint("TOPLEFT", firstPane, "TOPRIGHT", gutter, 0)
    UI.encounters:SetPoint("BOTTOMLEFT", firstPane, "BOTTOMRIGHT", gutter, 0)
end

-- The first two panes, a gutter apart: the instances (with the Alliance /
-- Horde switch) and their encounters (with the recipe filter, on
-- Professions). On the Professions tab the profession bar runs across the
-- top (UI/ProfessionBar.lua), and under it the filter sidebar
-- (UI/RecipeBand.lua) takes the instance list's place (LayoutLists).
local function CreateLists(body)
    local gutter = Size.gutter
    UI.instances = UI.CreateInstanceList(body)
    UI.instances:SetPoint("TOPLEFT", gutter, -gutter)
    UI.instances:SetPoint("BOTTOMLEFT", gutter, gutter)
    UI.instances:SetWidth(Size.instanceList)
    UI.factionToggle = CreateFactionToggle(UI.instances)
    UI.factionToggle:SetPoint("RIGHT", UI.instances, "TOPRIGHT", -Size.pad, -(Size.paneLabel / 2 + 2))
    UI.professionBar = UI.CreateProfessionBar(body)
    UI.professionBar:SetPoint("TOPLEFT", gutter, -gutter)
    UI.professionBar:SetPoint("TOPRIGHT", -gutter, -gutter)
    UI.encounters = UI.CreateEncounterList(body)
    UI.encounters:SetWidth(Size.encounterList)
    PlaceSecondPane(UI.instances)
    UI.recipeSidebar = ns.RecipeBand:CreateSidebar(body, UI.encounters)
    UI.recipeSidebar:SetPoint("TOPLEFT", UI.professionBar, "BOTTOMLEFT", 0, -gutter)
    UI.recipeSidebar:SetPoint("BOTTOMLEFT", gutter, gutter)
    UI.recipeFilter = Theme:SearchBox(UI.encounters, L["Filter recipes"], 130,
        function(text) UI:SetRecipeFilter(text) end)
    UI.recipeFilter:SetHeight(RECIPE_FILTER.HEIGHT)
    UI.recipeFilter:SetPoint("LEFT", UI.encounters, "TOPLEFT", RECIPE_FILTER.INSET, -Size.paneLabel / 2)
    UI.recipeFilter:SetPoint("RIGHT", UI.encounters.band.count, "LEFT", -RECIPE_FILTER.COUNT_GAP, 0)
end

-- Where a quest or boss page is: "Shadowfang Keep  >  Baron Silverlaine",
-- the instance a link to its Overview. It keeps the strip up on those
-- pages, so Back appearing doesn't move the page.
local function CreateCrumbs(strip)
    local crumbs = CreateFrame("Frame", nil, strip)
    crumbs:SetHeight(20)
    crumbs.text = Theme:Text(crumbs, Theme.font.body)
    crumbs.text:SetPoint("LEFT")
    crumbs.text:SetPoint("RIGHT")
    crumbs.text:SetJustifyH("LEFT")
    crumbs:SetHyperlinksEnabled(true)
    crumbs:SetScript("OnHyperlinkClick", function() UI:OpenOverview() end)
    crumbs:SetScript("OnHyperlinkEnter", function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:SetText(L["Click to open its overview"])
        GameTooltip:Show()
    end)
    crumbs:SetScript("OnHyperlinkLeave", GameTooltip_Hide)
    crumbs:Hide()
    return crumbs
end

-- A layer of `host`'s strip for one of its pages' buttons, shown while the
-- page is. Hooked on the calls, as CreateHost's pages are.
local function StripLayer(host, page)
    local layer = CreateFrame("Frame", nil, host.strip)
    layer:SetAllPoints()
    local function Follow() layer:SetShown(page:IsShown()) end
    hooksecurefunc(page, "Show", Follow)
    hooksecurefunc(page, "Hide", Follow)
    hooksecurefunc(page, "SetShown", Follow)
    Follow()
    return layer
end

-- The third pane: the loot grid, or a dungeon's or a profession's Overview
-- or a dungeon's questline (UI/DungeonQuestlines.lua) in its place, under a
-- strip with Back and the breadcrumb at the left, the page's buttons at the
-- right. A profession's Overview has its own strip parts (its chips, the
-- skill line and the faction toggle) on a layer of it.
local function CreateContent(body)
    local gutter = Size.gutter
    UI.loot = UI.CreateLootGrid(body)
    UI.overview = UI.CreateOverview(body)
    UI.overview:SetAllPoints(UI.loot)
    UI.overview:Hide()
    UI.professionOverview = UI.CreateProfessionOverview(body)
    UI.professionOverview:SetAllPoints(UI.loot)
    UI.professionOverview:Hide()
    UI.questlinePage = UI.CreateDungeonQuestlinePage(body)
    UI.questlinePage:SetAllPoints(UI.loot)
    -- A dungeon's or raid's run report (UI/RunPage.lua): local checkouts only, so nil in a release.
    UI.runPage = ns.RunPage and ns.RunPage.CreateReport(body)
    if UI.runPage then UI.runPage:SetAllPoints(UI.loot) end
    -- Every page of the content pane, in one list so that whatever hides
    -- them all (another tab, the Settings page) hides each one.
    UI.contentPages = { UI.loot, UI.overview, UI.professionOverview, UI.questlinePage, UI.runPage }
    UI.content = CreateHost(body, UI.contentPages)
    UI.content:SetPoint("TOPLEFT", UI.encounters, "TOPRIGHT", gutter, 0)
    UI.content:SetPoint("BOTTOMRIGHT", -gutter, gutter)
    UI.professionOverview:PlaceStrip(StripLayer(UI.content, UI.professionOverview))
    local strip = UI.content.strip
    UI.back = CreateBackButton(strip)
    UI.backHint = PlaceBack(UI.back, strip)
    UI.crumbs = CreateCrumbs(strip)
    UI.addButton = CreateAddButton(strip, function() return UI.state.instance, UI.state.encounter end)
    UI.addButton:SetPoint("RIGHT", -STRIP_INSET, 0)
    UI.abilitiesTab = CreateBossTab(strip, "abilities")
    UI.abilitiesTab:SetPoint("RIGHT", -STRIP_INSET, 0)
    UI.lootTab = CreateBossTab(strip, "loot")
    UI.lootTab:SetPoint("RIGHT", UI.abilitiesTab, "LEFT", -STRIP_BUTTON_GAP, 0)
    UI.mapButton = CreateMapButton(strip)  -- placed by UI:UpdateMapButton
    UI.content:HookScript("OnSizeChanged", function() UI:FitStrip() end)
    -- The pages take clicks on their background too, so a right-click
    -- there lands in the content pane (see BACK_CLICKS below); a left
    -- press there moves the window, as on the host.
    for _, page in ipairs(UI.contentPages) do
        page:EnableMouse(true)
        MakeDragHandle(page, UI.frame)
    end
end

function UI:Build()
    if self.frame then return end
    local window = CreateMainWindow()
    self.frame = window
    UI.HostSecureLinks(window)
    self:PlaceWindow()
    local header = CreateHeader(window)
    local tabBar = CreateTabBar(window, header)
    self.tabBar = tabBar
    self.tabs = {}
    self:LayoutTabs()
    CreateTopBar(window, header)
    local footer = CreateFooter(window)
    local body = CreateFrame("Frame", nil, window)
    body:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT")
    body:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT")
    -- The Library's, Shopping List's, Wishlist's and Classes' panes and the
    -- Settings page are built when first shown (BuildWholeBodyTab,
    -- UI:BuildSettingsPage).
    self.body = body
    CreateLists(body)
    CreateContent(body)
    -- The connector line is part of the modern look only.
    if not Theme.native then
        self.link = CreateLink(body)
        local function Relink() C_Timer.After(0, function() UI:UpdateLink() end) end
        window:HookScript("OnShow", Relink)
        -- Panes move while the window is resized; the line follows them.
        window:HookScript("OnSizeChanged", Relink)
    end
    self.empty = Theme:Text(body, Theme.font.body)
    self.empty:SetPoint("CENTER")
    Theme:SetTextColor(self.empty, Theme.color.muted)
    self.state.faction = self.state.faction or ns.PlayerFaction()
    self:SelectCategory(self.state.category or ns.db.lastTab)
end

-- The tab strip: a tab for each module that is on, in order. A module
-- turned on later gets its tab then.
function UI:LayoutTabs()
    local previous
    for _, info in ipairs(TABS) do
        local tab = self.tabs[info.key]
        if ns.Modules:IsOn(info.key) then
            if not tab then
                tab = CreateTab(self.tabBar, info)
                self.tabs[info.key] = tab
            end
            tab:ClearAllPoints()
            if Theme.native and previous then
                tab:SetPoint("BOTTOMLEFT", previous, "BOTTOMRIGHT", 2, 0)
            elseif Theme.native then
                tab:SetPoint("BOTTOMLEFT", Size.gutter + 4, -Size.gutter)
            elseif previous then
                tab:SetPoint("LEFT", previous, "RIGHT")
            else
                tab:SetPoint("LEFT", Size.pad - 12, 0)
            end
            tab:Show()
            previous = tab
        elseif tab then
            tab:Hide()
        end
    end
end

-- A content pane across the whole body holding `page` (and any further
-- pages, laid over it), each hidden for now.
local function CreateWholeBodyHost(body, page, ...)
    local pages = { page, ... }
    for _, hostedPage in ipairs(pages) do hostedPage:Hide() end
    local host = CreateHost(body, pages)
    host:SetPoint("TOPLEFT", Size.gutter, -Size.gutter)
    host:SetPoint("BOTTOMRIGHT", -Size.gutter, Size.gutter)
    for i = 2, #pages do pages[i]:SetAllPoints(page) end
    return host
end

-- The Classes tab's three columns, the right one a content pane holding the
-- class's Overview, the planner, a spellbook tab's page, a tier set's page,
-- a questline's page, a class quest's page, a poison recipe's page, a
-- hunter's or warlock's pet page or the mage's scrolls page, whose strip
-- holds the buttons of the page that shows. Its host is inside the tab's frame, so hiding the tab hides the
-- host with it.
local function BuildClassesTab()
    UI.classes = UI.CreateClassesTab(UI.body)
    local pages = { UI.classes.planner, UI.classes.overview, UI.classes.spellPage, UI.classes.setPage,
        UI.classes.questlinePage, UI.classes.questPage, UI.classes.poisonPage, UI.classes.petPage,
        UI.classes.demonPage, UI.classes.scrollPage }
    UI.classesHost = CreateHost(UI.classes, pages)
    UI.classesHost:SetPoint("TOPLEFT", UI.classes.sections, "TOPRIGHT", Size.gutter, 0)
    UI.classesHost:SetPoint("BOTTOMRIGHT", -Size.gutter, Size.gutter)
    for i = 2, #pages do pages[i]:SetAllPoints(UI.classes.planner) end
    for _, page in ipairs(pages) do page:PlaceStrip(StripLayer(UI.classesHost, page)) end
    UI.classesHost:SetStrip(true)
end

-- The Library's, the Shopping List's, the Wishlist's or the Classes tab's
-- panes, built the first time the tab shows, with its buttons (All books,
-- Group by zone...; Save preset, Import...; Reset, My talents)
-- in its strip.
local function BuildWholeBodyTab(key)
    if key == "LIBRARY_BOOKS" and not UI.library then
        UI.library = UI.CreateLibraryPage(UI.body)
        UI.libraryHost = CreateWholeBodyHost(UI.body, UI.library)
        UI.library:PlaceStrip(UI.libraryHost.strip)
        UI.libraryHost:SetStrip(true)
        -- Back, while the tab was opened on a book from a search's results
        -- (UI:ShowLibraryBook); the page's chips follow it.
        UI.libraryBack = CreateBackButton(UI.libraryHost.strip)
        UI.libraryBack:SetPoint("LEFT", STRIP_INSET, 0)
        -- The page takes the mouse for the links under its heading; a left
        -- press on its background still moves the window.
        UI.library:EnableMouse(true)
        MakeDragHandle(UI.library, UI.frame)
    elseif key == "SHOPPING" and not UI.shopping then
        UI.shopping = UI.CreateShoppingList(UI.body)
        UI.shoppingHost = CreateWholeBodyHost(UI.body, UI.shopping)
        UI.shopping:PlaceStrip(UI.shoppingHost.strip)
    elseif key == "WISHLIST" and not UI.wishlist then
        UI.wishlist = UI.CreateWishlist(UI.body)
        UI.wishlistHost = CreateWholeBodyHost(UI.body, UI.wishlist)
        UI.wishlist:PlaceStrip(UI.wishlistHost.strip)
    elseif key == "CLASSES" and not UI.classes then
        BuildClassesTab()
    end
end

-- Settings page ------------------------------------------------------------
-- The Settings button opens Settings in place of the tabs' panes, in a pane
-- of its own whose strip holds Back. Back, a right-click on it, Escape, the
-- Settings button or a tab returns to the tab it was opened from. The Game
-- hotfixes page (UI/Hotfixes.lua, from the link at the bottom of Settings or
-- /nr hotfixes) shows in the same pane, in the Settings page's place, while
-- `hotfixesOpen`: there Back, a right-click and Escape return to Settings.

-- A host across the whole body for `page` (and the pages after it, laid over it), with Back
-- and its right-click hint in its strip: the Settings page's, and the run history's
-- (UI/RunHistory.lua, local checkouts only). Back calls `onBack`.
function UI.CreateBackedHost(onBack, page, ...)
    local host = CreateWholeBodyHost(UI.body, page, ...)
    host:SetStrip(true)
    host.back = Theme:Pill(host.strip, "back")
    host.back:SetScript("OnClick", onBack)
    host.hint = PlaceBack(host.back, host.strip)
    return host
end

function UI:BuildSettingsPage()
    if self.settingsPage then return end
    local page = ns.Settings:CreatePage(self.body)
    local hotfixesPage = ns.HotfixPage.CreatePage(self.body)
    local host = UI.CreateBackedHost(function() UI:SettingsBack() end, page, hotfixesPage)
    -- Escape steps back first (the hotfixes to Settings, Settings to the
    -- tab), then shuts the window.
    Theme:OnEscape(host, function() UI:SettingsBack() end)
    self.settingsPage, self.hotfixesPage, self.settingsHost = page, hotfixesPage, host
end

-- Hides the panes the list tabs (Dungeons, Raids, Professions and the like)
-- share: the two lists, every page of the content pane and the empty
-- notice, for a tab that fills the whole body or the Settings page.
function UI:HideListTabPanes()
    for _, pane in ipairs({ self.instances, self.professionBar, self.recipeSidebar, self.encounters, self.empty }) do
        pane:Hide()
    end
    for _, page in ipairs(self.contentPages) do page:Hide() end
end

-- Shows the Settings page in place of everything else in the body while
-- it is open. Returns whether it is.
function UI:ShowSettingsPage()
    local open = self.settingsOpen
    if open then self:BuildSettingsPage() end
    if self.settingsPage then
        self.settingsPage:SetShown(open and not self.hotfixesOpen)
        self.hotfixesPage:SetShown(open and self.hotfixesOpen)
    end
    if not open then return false end
    self:HideListTabPanes()
    for _, paneKey in pairs(WHOLE_BODY) do
        if self[paneKey] then self[paneKey]:Hide() end
    end
    if self.link then self.link:Hide() end
    local label = self.hotfixesOpen and L["Settings"] or self.tabLabels[self.state.category]
    self.settingsHost.back:SetLabel(label and L["Back to %s"]:format(label) or L["Back"])
    if self.hotfixesOpen then self.hotfixesPage:Refresh() else self.settingsPage:Refresh() end
    self.status:SetText("")
    return true
end

function UI:OpenSettings()
    if self.settingsOpen then return end
    self.settingsOpen = true
    self.hotfixesOpen = false
    self.search:ClearFocus()
    for _, tab in pairs(self.tabs) do tab:SetActive(false) end
    self.settingsButton:Tint(true)
    self:Refresh()
end

function UI:CloseSettings()
    if not self.settingsOpen then return end
    self.settingsOpen = false
    for key, tab in pairs(self.tabs) do tab:SetActive(key == self.state.category) end
    self.settingsButton:Tint(false)  -- (hover drawn by Tint itself)
    self:Refresh()
end

function UI:ToggleSettings()
    if self.settingsOpen then self:CloseSettings() else self:OpenSettings() end
end

-- The Game hotfixes page, in the Settings page's place.
function UI:OpenHotfixes()
    self:OpenSettings()
    self.hotfixesOpen = true
    self:Refresh()
end

-- Back on the Settings pane: from the Game hotfixes page to Settings, from
-- Settings to the tab it was opened from.
function UI:SettingsBack()
    if not self.hotfixesOpen then return self:CloseSettings() end
    self.hotfixesOpen = false
    self:Refresh()
end

-- A module turned on or off in Settings: the tabs follow, a tab turned off
-- forgets where it was left and leaves the Back trail, and a window on a
-- tab turned off moves to the first tab still on. Another style's
-- window, if built, catches up when it is next used (UI:SetSkin).
function UI:ApplyModules()
    if not self.frame then return end
    local modules = ns.Modules
    self:LayoutTabs()
    local questsOn = modules:IsOn("QUESTS")
    for key, place in pairs(self.places) do
        if not modules:IsOn(key) then self.places[key] = nil end
        if not questsOn then place.quest, place.questline = nil, nil end
    end
    for i = #self.history, 1, -1 do
        local step = self.history[i]
        if step.category and not modules:IsOn(step.category) then table.remove(self.history, i) end
        if not questsOn then step.quest, step.questline = nil, nil end
    end
    self.loot.searchKey = nil
    -- Wishlist stars come and go on loot rows, changing the names' room;
    -- recipe icons (Professions Icons) on the recipe list; a dungeon's
    -- Quests group with the Quests module.
    self.loot:Remeasure()
    self.encounters:Rebuild()
    local category = self.state.category
    if not modules:IsOn(category) then
        self.state.instance, self.state.encounter, self.state.quest, self.state.questline = nil, nil, nil, nil
        self:ClearHistory()
        self:SelectCategory(modules:Usable(category))
    elseif (self.state.quest or self.state.questline) and not questsOn then
        -- The quest or questline page that was open goes; its dungeon's Overview shows.
        local instance = self.state.instance
        self.state.instance, self.state.quest, self.state.questline = nil, nil, nil
        self:SelectInstance(instance)
    else
        self:Refresh()
    end
end

-- The footer's version note, at the right: whether a newer
-- feature release is out (heard from other players, see Core/Init.lua) or
-- this one is the latest. The tab's status text sits left of it.
function UI:UpdateVersionNote()
    local note = self.versionNote
    if not note then return end
    local mine, newer = ns.Version:Mine(), ns.Version:Newer()
    if newer then
        note:SetText(L["Update available: v%s (you have v%s)"]:format(newer, mine))
        Theme:SetTextColor(note, Theme.color.heading)
    else
        note:SetText(mine and L["v%s  ·  Up to date"]:format(mine) or L["Dev build"])
        Theme:SetTextColor(note, Theme.native and Theme.color.muted or Theme.color.faint)
    end
    self.status:ClearAllPoints()
    self.status:SetPoint("RIGHT", note, "LEFT", -FOOTER_GAP, 0)
    self:FitFooter()
end

-- The footer's hint shows only while it clears the status and version
-- notes at the right (a long status such as "On shopping list: 2x ..." in
-- a narrow window).
function UI:FitFooter()
    local hint = self.footerHint
    if not (hint and self.versionNote) then return end
    local rightWidth = FOOTER_INSET + self.versionNote:GetStringWidth()
    local status = self.status:GetText()
    if status and status ~= "" then rightWidth = rightWidth + FOOTER_GAP + self.status:GetStringWidth() end
    hint:SetShown(FOOTER_INSET + hint:GetStringWidth() + FOOTER_GAP + rightWidth <= hint:GetParent():GetWidth())
end

-- Style switching ---------------------------------------------------------
-- Each skin builds its own window the first time it is used; switching
-- parks the current one and brings the new one in (built, or back from where
-- it was parked) on the same selection, search and position, so no /reload
-- is needed. Windows are kept by Theme.name, the skin shown: a saved ElvUI
-- style without ElvUI shows (and parks) the Dark window.

local SKINNED = {
    "frame", "search", "searchNote", "tabBar", "tabs", "status", "instances", "factionToggle",
    "professionBar", "recipeSidebar", "encounters", "recipeFilter", "loot", "overview", "professionOverview",
    "questlinePage", "runPage", "runsPage", "runsHost", "contentPages", "content",
    "back", "backHint", "crumbs",
    "body", "link", "empty",
    "library", "libraryHost", "shopping", "shoppingHost", "wishlist", "wishlistHost", "classes", "classesHost",
    "addButton", "lootTab", "abilitiesTab", "mapButton",
    "versionNote", "footerHint", "settingsButton", "lockButton", "settingsPage", "hotfixesPage", "settingsHost",
}

-- Shows or hides the transmog ticks after item names. Every built window's
-- names are measured again, since a tick takes room after the name.
function UI:SetCollectionTicks(on)
    if on then ns.db.collectionTicks = nil else ns.db.collectionTicks = false end
    if self.loot then self.loot:Remeasure() end
    for _, parked in pairs(self.built) do if parked.loot then parked.loot:Remeasure() end end
end

-- Switches the window to skin `name` and saves it; a skin that can't be
-- shown now (ElvUI's without ElvUI) is refused, leaving the saved one.
function UI:SetSkin(name)
    if not Theme:IsSkinAvailable(name) then return end
    ns.db.skin = name
    -- Whoever changes the style has found where it lives.
    ns.db.welcomed = true
    if ns.Welcome then ns.Welcome:HideCallout() end
    if not self.frame then
        Theme:SetSkin(name)
        return
    end
    if name == Theme.name then return end
    local shown = self.frame:IsShown()
    local search = self.search:GetText()
    -- A style picked on the Settings page (or /nr style on the Game hotfixes
    -- page): the new window opens on it too.
    local settingsOpen, hotfixesOpen = self.settingsOpen, self.hotfixesOpen
    self:CloseSettings()
    self:ClearRecipeFilter()
    self.swapping = true
    self.frame:Hide()
    local parked = {}
    for _, key in ipairs(SKINNED) do
        parked[key] = self[key]
        self[key] = nil
    end
    self.built[Theme.name] = parked
    Theme:SetSkin(name)
    local saved = self.built[name]
    if saved then
        for key, widget in pairs(saved) do self[key] = widget end
        -- The text size may have changed while this window was put away.
        if self.frame:GetScale() ~= self:WindowScale() then self.loot:Remeasure() end
        self:UpdateVersionNote()
        self:PlaceWindow()
        -- Modules may have been turned on or off meanwhile too.
        self:LayoutTabs()
        self:SelectCategory(self.state.category)
    else
        self:Build()
    end
    -- Quietly, so a search set aside stays aside.
    if self.search:GetText() ~= search then Theme:SetSearchTextQuietly(self.search, search) end
    if shown then self.frame:Show() end
    self.swapping = nil
    if hotfixesOpen then
        self:OpenHotfixes()
    elseif settingsOpen then
        self:OpenSettings()
    end
end

-- Connector ---------------------------------------------------------------
-- An elbow line in the gutter from the selected instance to the selected
-- encounter, and a "tab": the selected encounter row's top and bottom edges
-- run across the next gutter into the loot panel, whose outline opens there.

local MIN_JOG = 12  -- shortest step drawn between two rows; a smaller one becomes a straight line

-- Places connector `segment` `x` right of and `y` up from the body's top
-- left corner, at least a line wide each way.
local function PlaceSegment(segment, x, y, width, height, lineWidth)
    segment:ClearAllPoints()
    segment:SetPoint("TOPLEFT", UI.body, "TOPLEFT", x, y)
    segment:SetSize(math.max(width, lineWidth), math.max(height, lineWidth))
end

-- The elbow from the selected instance row down the gutter to the selected
-- encounter row.
local function PlaceElbow(link, instanceRow, encounterRow, lineWidth, pixel)
    local left, top = UI.body:GetLeft(), UI.body:GetTop()
    local halfLine = lineWidth / 2

    -- The vertical runs down the middle of the gutter between the two panes,
    -- worked out in whole screen pixels so it sits evenly between them.
    local function ToPixels(value) return math.floor(value / pixel + 0.5) end
    local gutterLeft, gutterRight = ToPixels(UI.instances:GetRight()), ToPixels(UI.encounters:GetLeft())
    local linePixels = ToPixels(lineWidth)
    local gutterX = (gutterLeft + math.floor((gutterRight - gutterLeft - linePixels) / 2)) * pixel - left

    -- Body-relative coordinates (y grows downward as negative offsets).
    local fromX, toX = instanceRow:GetRight() - left, encounterRow:GetLeft() - left
    local fromY = math.floor((instanceRow:GetTop() + instanceRow:GetBottom()) / 2 - top)
    local toY = math.floor((encounterRow:GetTop() + encounterRow:GetBottom()) / 2 - top)
    -- Rows of different heights side by side (say both at the top of their
    -- lists) would leave a tiny jog in the gutter. When the rows overlap,
    -- run one straight line through the middle of the overlap instead.
    if math.abs(fromY - toY) < MIN_JOG then
        local overlapTop = math.min(instanceRow:GetTop(), encounterRow:GetTop()) - top
        local overlapBottom = math.max(instanceRow:GetBottom(), encounterRow:GetBottom()) - top
        if overlapTop - overlapBottom > lineWidth * 2 then
            fromY = math.floor((overlapTop + overlapBottom) / 2)
            toY = fromY
        end
    end

    PlaceSegment(link.out, fromX, fromY + halfLine, gutterX + lineWidth - fromX, lineWidth, lineWidth)
    PlaceSegment(link.down, gutterX, math.max(fromY, toY) + halfLine, lineWidth, math.abs(fromY - toY) + lineWidth,
        lineWidth)
    PlaceSegment(link.into, gutterX, toY + halfLine, toX - gutterX, lineWidth, lineWidth)
end

-- The tab: the selected encounter row's top and bottom edges run across the
-- next gutter into the content page, the gap between them filled. Not while
-- the content pane shows search results.
local function PlaceTab(link, encounterRow, lineWidth)
    local left, top = UI.body:GetLeft(), UI.body:GetTop()
    local content = UI.overview:IsShown() and UI.overview
        or UI.professionOverview:IsShown() and UI.professionOverview or UI.loot
    local showTab = not UI.state.search and content:GetLeft()
    for _, segment in ipairs({ link.tabTop, link.tabBottom, link.cover }) do segment:SetShown(showTab) end
    if not showTab then return end
    local toX = encounterRow:GetLeft() - left
    local contentX = content:GetLeft() - left
    local rowTop, rowBottom = encounterRow:GetTop() - top, encounterRow:GetBottom() - top
    PlaceSegment(link.tabTop, toX, rowTop, contentX + lineWidth - toX, lineWidth, lineWidth)
    PlaceSegment(link.tabBottom, toX, rowBottom + lineWidth, contentX + lineWidth - toX, lineWidth, lineWidth)
    local rowRight = encounterRow:GetRight() - left
    PlaceSegment(link.cover, rowRight, rowTop - lineWidth, contentX + lineWidth - rowRight,
        rowTop - rowBottom - lineWidth * 2, lineWidth)
end

-- The Professions tab has no instance list (its filter sidebar stands
-- there), so its recipe row gets the tab without the elbow.
function UI:UpdateLink()
    local link = self.link
    if not link then return end
    local hasElbow = self.instances:IsShown()
    local instanceRow = hasElbow and self.instances:GetSelectedRow()
    local encounterRow = self.encounters:IsShown() and self.encounters:GetSelectedRow()
    local rowsPlaced = encounterRow and self.body:GetLeft() and encounterRow:GetLeft()
        and (not hasElbow or (instanceRow and instanceRow:GetRight()))
    if not rowsPlaced then
        link:Hide()
        return
    end
    -- Same pixel width as the selection bar and the loot outline.
    local lineWidth, pixel = Theme:LineWidth(self.body)
    for _, segment in ipairs({ link.out, link.down, link.into }) do segment:SetShown(hasElbow) end
    if hasElbow then PlaceElbow(link, instanceRow, encounterRow, lineWidth, pixel) end
    PlaceTab(link, encounterRow, lineWidth)
    link:Show()
end

-- Selection ---------------------------------------------------------------

-- Labels, icon, row style and widths of the first two panes on tab `key`.
-- `byFaction`: its list is shown one side at a time, with the switch. On
-- Professions the filter sidebar is the first pane, under the profession
-- bar; the profession list stays behind it, hidden, for the order and the
-- profession a tab opens on (InstanceToOpen).
local function LayoutLists(key, byFaction)
    local labels = PANE_LABELS[key] or DEFAULT_LABELS
    UI.instances.label:SetText(Theme:Label(labels[1]))
    UI.encounters.label:SetText(Theme:Label(labels[2]))
    UI.instances:SetLabelIcon(PANE_ICONS[key], PANE_ICON_SIZES[key])
    -- Profession names need no subtitle; one-line rows show all eleven.
    UI.instances:SetCompact(key == "PROFESSION")
    UI.recipeFilter:SetShown(key == "PROFESSION")
    PlaceSecondPane(key == "PROFESSION" and UI.recipeSidebar or UI.instances)
    -- Drawn first: that sizes it for the text size.
    UI.factionToggle:Refresh()
    local instanceWidth = Size.instanceList
    if byFaction then
        -- Room for the pane label, a clear gap, then the faction toggle.
        -- A safety net only: the toggle fits the standard width.
        local neededWidth = UI.instances:LabelRight() + FACTION_GAP
            + UI.factionToggle:GetWidth() + Size.pad
        instanceWidth = math.max(instanceWidth, math.ceil(neededWidth))
    end
    UI.instances:SetWidth(instanceWidth)
    UI.encounters:SetWidth(SECOND_WIDTHS[key] or Size.encounterList)
    UI.factionToggle:SetShown(byFaction)
end

-- The instance, encounter ID, quest and questline tab `key` opens on: the
-- selection, or its counterpart after a faction switch (Warsong Gulch stays
-- Warsong Gulch); coming from another tab, where it was left; else the first row.
local function InstanceToOpen(key, list)
    local state = UI.state
    local current, currentEncounter = state.instance, state.encounter
    local currentQuest, currentQuestline = state.quest, state.questline
    local place = UI.places[key]
    if place and not (current and current.category == key) then
        current, currentEncounter = place.instance, place.encounter
        currentQuest, currentQuestline = place.quest, place.questline
    end
    local pick, encounterID = UI.instances:FirstInstance() or list[1], nil  -- Classic raids sit below the rest
    for _, instance in ipairs(list) do
        if current and instance.name == current.name and instance.category == current.category then
            pick, encounterID = instance, currentEncounter and currentEncounter.id
            if instance == current then break end
        end
    end
    return pick, encounterID, pick == current and currentQuest, pick == current and currentQuestline
end

function UI:SelectCategory(key)
    local state = self.state
    -- A tab turned off in Settings opens the first one still on.
    key = ns.Modules:Usable(key)
    state.category = key
    ns.db.lastTab = key
    for tabKey, tab in pairs(self.tabs) do tab:SetActive(tabKey == key and not self.settingsOpen) end
    if WHOLE_BODY[key] then
        -- Not a list of instances: the shopping or wishlist pane takes the whole body.
        BuildWholeBodyTab(key)
        state.instance, state.encounter = nil, nil
        self.factionToggle:Hide()
        self:ClearRecipeFilter()
        self:Refresh()
        return
    end
    local list, byFaction = ForFaction(ns.Data:List(key), state.faction)
    LayoutLists(key, byFaction)
    self.instances:SetData(list)
    if key == "PROFESSION" then self.professionBar:SetData(list) end
    self.empty:SetText(EMPTY_TEXT[key])
    if #list == 0 then
        state.instance, state.encounter = nil, nil
        self.encounters:SetData(nil)
        self:Refresh()
        return
    end
    local pick, encounterID, quest, questline = InstanceToOpen(key, list)
    self:SelectInstance(pick, encounterID)
    self.instances:ScrollTo(pick)
    -- A dungeon quest or questline that was open stays open.
    if quest then self:SelectQuest(quest) end
    if questline then self:SelectQuestline(questline) end
end

-- Notes where the current tab is (its selection, recipe filter and Back
-- trail) before another tab takes over.
function UI:RememberPlace()
    local state = self.state
    if not (state.category and state.instance) then return end
    local filter = strtrim(self.recipeFilter:GetText())
    self.places[state.category] = {
        instance = state.instance,
        encounter = state.encounter,
        quest = state.quest,
        questline = state.questline,
        filter = filter ~= "" and filter or nil,
        history = { unpack(self.history) },
    }
end

-- A tab clicked by hand: opens where that tab was left, with its recipe
-- filter and Back trail, if it was open before.
function UI:SwitchTab(key)
    -- The tab Settings was opened from: just back to it, trail and all.
    if self.settingsOpen and key == self.state.category then
        self:CloseSettings()
        return
    end
    self.settingsOpen = false
    self.settingsButton:Tint(false)
    if key ~= self.state.category then self:RememberPlace() end
    self:ClearHistory()
    self:SelectCategory(key)
    local place = self.places[key]
    if not place or self.state.category ~= key then return end
    if place.filter and self.state.instance == place.instance then
        Theme:SetSearchTextQuietly(self.recipeFilter, place.filter)
        self:SetRecipeFilter(place.filter)
    end
    for _, step in ipairs(place.history) do table.insert(self.history, step) end
    self:Refresh()
end

function UI:SelectFaction(faction)
    self.state.search = nil -- browsing sets a search aside
    self.state.faction = faction
    self:SelectCategory(self.state.category)
end

-- Selects `instance`, on the encounter with `encounterID` if it has one.
function UI:SelectInstance(instance, encounterID)
    if instance ~= self.state.instance then self:ClearRecipeFilter() end
    self.state.instance = instance
    self.state.quest, self.state.questline = nil, nil
    -- A profession opens on its Overview (when it has one), like a class;
    -- Skinning lists only Scarce reagents.
    local scarce = ns.Data:Scarce(instance.id)
    local overview = instance.professionOverview
    self.state.encounter = overview or instance.encounters[1] or scarce[1]
    -- The run section (UI/RunPage.lua, local checkouts only) is picked by its ID too, for Back.
    local runEntry = ns.RunPage and ns.RunPage.ListEntry(instance)
    for _, encounters in ipairs({ instance.encounters, scarce, { overview }, { runEntry } }) do
        for _, encounter in ipairs(encounters) do
            if encounter.id == encounterID then self.state.encounter = encounter end
        end
    end
    self.instances:Refresh()
    self.encounters:SetData(instance)
    local list = self.encounters
    -- A set list folded by class opens on a set of the player's class, not
    -- on the list's first set (UI/TierSets.lua's StartingSet).
    if not encounterID then self.state.encounter = list:StartingSet() or self.state.encounter end
    -- A recipe the slot chip or toggles hide: a jump to it puts the list
    -- back to All with the toggles off; else the first recipe listed. The
    -- Overview sits above the list, never on it.
    local onOverview = overview ~= nil and self.state.encounter == overview
    if instance.category == "PROFESSION" and not onOverview and not list:IsListed(self.state.encounter) then
        if encounterID and ns.RecipeBand:Narrowing(instance) then
            ns.RecipeBand:Reset(instance)
            list:SetData(instance)
        else
            self.state.encounter = list:FirstRecipe() or self.state.encounter
        end
    end
    self.encounters:ScrollTo(self.state.encounter)
    self:Refresh()
end

-- A slot chip, toggle or skill bound changed (UI/RecipeBand.lua): the list
-- narrowed again, keeping the selection if it is still listed. With
-- `keepSelection` (a bound being typed) the page stays on the selection
-- even when it is off the list for now.
function UI:RecipeNarrowed(keepSelection)
    local list, state = self.encounters, self.state
    list:SetData(state.instance)
    local listed = list:IsListed(state.encounter)
    if not listed and not keepSelection then state.encounter = list:FirstRecipe() end
    if listed or not keepSelection then list:ScrollTo(state.encounter) end
    list:Refresh()
    self:Refresh()
end

-- Opens a recipe from anywhere (a material's arrow, a Shopping List row):
-- its profession on the Professions tab, the recipe selected and scrolled
-- into view. The place being left goes on the history.
function UI:SelectRecipe(instance, encounter)
    -- A class's own recipe (the rogue's poisons) has its page on the Classes tab.
    if instance.classToken then
        if not ns.Modules:IsOn("CLASSES") then return end
        self:SwitchTab("CLASSES")
        self.classes:ShowClassRecipe(instance, encounter)
        return
    end
    if not ns.Modules:IsOn("PROFESSION") then return end
    local state = self.state
    if state.category ~= "PROFESSION" then self:RememberPlace() end
    self:PushBack(self:Place())
    state.search = nil
    if state.category ~= "PROFESSION" then self:SelectCategory("PROFESSION") end
    -- Reselected even within the same profession, which clears its recipe filter.
    state.instance = nil
    self:SelectInstance(instance, encounter.id)
end

-- Opens a class quest from anywhere (a poison's "Quest:" line): its class
-- on the Classes tab, the quest's page open.
function UI:SelectClassQuest(classToken, quest)
    if not ns.Modules:IsOn("CLASSES") then return end
    self:SwitchTab("CLASSES")
    self.classes:ShowClassQuest(classToken, quest)
end

-- Where the window is now, for Back to return to: the tab and selection, a
-- search's text, how far an Overview was scrolled, and a name for it.
function UI:Place()
    local state = self.state
    local place = {
        category = state.category, faction = state.faction,
        instance = state.instance, encounter = state.encounter, quest = state.quest,
        questline = state.questline, found = state.found, bossTab = state.bossTab,
    }
    if state.search then
        place.search = self.search:GetText()
        place.label = L["search results"]
    elseif WHOLE_BODY[state.category] then
        place.label = self.tabLabels[state.category]
    elseif state.quest then
        place.label = state.quest.name
    elseif state.questline then
        place.label = state.questline.name
    elseif state.encounter and state.encounter.overview then
        place.label = state.instance.name
        place.offset = self.overview.offset
        place.showMap = self.overview.showMap
    elseif state.encounter and state.encounter.professionOverview then
        place.label = state.instance.name
    elseif state.encounter then
        place.label = state.encounter.name
    end
    return place
end

-- Puts a place on the history, for a link that is about to leave it.
function UI:PushBack(place)
    if place.label then table.insert(self.history, place) end
end

-- Returns to a place from UI:Place().
function UI:RestorePlace(place)
    local state = self.state
    if place.category ~= state.category then self:RememberPlace() end
    self:CancelPendingSearch()
    self.search:ClearFocus()
    state.search = nil
    state.faction = place.faction or state.faction
    self:SelectCategory(place.category)
    if place.instance and not WHOLE_BODY[place.category] then
        state.instance = nil -- reselect even when it is already open, clearing its recipe filter
        self:SelectInstance(place.instance, place.encounter and place.encounter.id)
        self.instances:ScrollTo(place.instance)
        if place.quest then self:SelectQuest(place.quest) end
        if place.questline then self:SelectQuestline(place.questline) end
    end
    state.found = place.found
    state.bossTab = place.bossTab
    if place.offset then
        self.overview.showMap = place.showMap
        self.overview.offset = place.offset
    end
    if place.search then
        Theme:SetSearchTextQuietly(self.search, place.search)
        self:SetSearch(strtrim(place.search))
    else
        self:Refresh()
    end
end

function UI:GoBack()
    local step = table.remove(self.history)
    if not step then return end
    if not step.worldMap then return self:RestorePlace(step) end
    -- In combat the world map stays shut, so the way back to it stays too.
    if not self:OpenWorldMap() then table.insert(self.history, step) end
end

-- Whether `frame` is any of the frames given, or inside one of them.
function UI.IsWithin(frame, ...)
    while frame do
        for i = 1, select("#", ...) do
            if frame == select(i, ...) then return true end
        end
        frame = frame:GetParent()
    end
    return false
end

-- Right-clicking anywhere on the content pane goes back while Back shows:
-- its background, the strip, and the rows, pins and buttons on it alike (on
-- the Settings page it closes the page; on the Game hotfixes page it returns
-- to Settings). The Library tab's pane does the same while its own Back
-- shows. Watched for the whole screen, kept to clicks on frames in the
-- pane. Map edit mode keeps its own right-clicks.
local BACK_CLICKS = CreateFrame("Frame")
BACK_CLICKS:RegisterEvent("GLOBAL_MOUSE_UP")
BACK_CLICKS:SetScript("OnEvent", function(_, _, button)
    if button ~= "RightButton" or ns.MapEdit.on then return end
    if not (UI.frame and UI.frame:IsShown()) then return end
    local focus = GetMouseFoci()[1]
    if ns.RunPage and ns.RunPage.TakeBackClick(focus) then return end
    if UI.settingsOpen then
        -- The hotfixes page lies over the pane rather than in it, and its
        -- struck-through hotfixes take the mouse for their tooltips.
        if UI.IsWithin(focus, UI.settingsHost, UI.hotfixesPage) then UI:SettingsBack() end
        return
    end
    local onContent = UI.back and UI.back:IsShown() and UI.IsWithin(focus, UI.content, unpack(UI.contentPages))
    local onLibrary = UI.libraryBack and UI.libraryBack:IsShown() and UI.IsWithin(focus, UI.libraryHost, UI.library)
    if not (onContent or onLibrary) then return end
    -- A control with its own right-click (the loot filters' Types).
    if focus.keepsRightClick then return end
    GameTooltip:Hide()
    UI:GoBack()
end)

-- Choosing something by hand starts a new trail, drops the highlight left
-- by a search result and sets any search aside: its text stays in the box
-- and clicking back into the box brings the results back.
function UI:ClearHistory()
    wipe(self.history)
    self.state.found = nil
    self.state.search = nil
    self:CancelPendingSearch()
    if self.search then self.search:ClearFocus() end
end

-- Clicking into the search box shows the results for its text again.
function UI:ResumeSearch()
    local text = strtrim(self.search:GetText())
    if text ~= "" and self.state.search ~= text:lower() then self:SetSearch(text) end
end

-- A search result's go-to: sets the search aside and opens the page the
-- item is on (its tab, list and encounter, scrolled into view), with the
-- item highlighted until something else is chosen. Without an encounter it
-- opens the instance's Overview; `fold` opens one boss's section of an
-- encounter whose bosses drop their own loot (the Ring of Law).
function UI:GoToSource(instance, encounter, itemID, fold)
    -- Nothing to open on a tab turned off in Settings.
    if not ns.Modules:IsOn(instance.category) then return end
    local from = self:Place()
    if instance.category ~= self.state.category then self:RememberPlace() end
    self:ClearHistory()
    self:PushBack(from)
    if instance.faction then self.state.faction = instance.faction end
    self.state.found = encounter and itemID and { encounter = encounter, itemID = itemID } or nil
    self.state.bossTab = nil -- the item it found is on the loot page
    self:SelectCategory(instance.category)
    self.state.instance = nil -- reselect even when it is already open, clearing its recipe filter
    self:SelectInstance(instance, encounter and encounter.id)
    self.instances:ScrollTo(instance)
    if fold then self.loot:JumpToFold(fold) end
end

-- Opens `instance` on its tab and runs `show` there (a boss or the map,
-- which only the Dungeons and Raids tabs show), for a link on another page:
-- the Classes tab's quest page, a boss's spoiler naming another instance's
-- boss, a profession's Overview. One Back returns to that page.
function UI:ShowInDungeon(instance, show)
    local from = self:Place()
    self:GoToSource(instance)
    if self.state.instance ~= instance then return end -- its tab is turned off
    show()
    wipe(self.history)
    self:PushBack(from)
    self:Refresh()
end

-- Opens what a search result found: an item's first source, a boss's
-- loot, a dungeon's or raid's Overview, a quest's page on its dungeon
-- (or raid, for an attunement step), or a book on the Library tab; Back
-- returns to where search was.
function UI:GoToResult(result)
    if result.kind == "book" then
        self:ShowLibraryBook(result.book)
    elseif result.kind == "place" or result.kind == "quest" then
        self:GoToSource(result.inst)
        if result.quest then self:SelectQuest(result.quest) end
    else
        self:GoToSource(result.inst, result.enc, result.itemID, result.bossFold)
    end
end

function UI:ClearRecipeFilter()
    local box = self.recipeFilter
    if box:GetText() ~= "" then
        Theme:SetSearchTextQuietly(box, "")
        box:ClearFocus()
    end
    self.encounters.filter = nil
end

-- Fills the recipe filter with a recipe's full name (Shift+Click on its
-- row), so the list shows it and its Included In group.
function UI:FilterToRecipe(encounter)
    local instance = self.state.instance
    if not (instance and instance.category == "PROFESSION") or encounter.scarce then return end
    self.recipeFilter:SetText(encounter.name)
    self.recipeFilter:ClearFocus()
end

-- Narrows the recipe list to matches (ShowRecipeMatches). A filter that didn't
-- change leaves the page alone: the game reports a text change when the box
-- first shows (the Professions tab's first opening), and taking that for a
-- new filter swapped the profession's Overview, which the list doesn't
-- hold, for its first recipe.
function UI:SetRecipeFilter(text)
    local filter = text ~= "" and text:lower() or nil
    if filter == self.encounters.filter then return end
    self.encounters:SetFilter(filter)
    self:ShowRecipeMatches()
end

-- Shows the recipe list's matches, keeping the selection if it still
-- matches, else selecting the first match. Also runs when material names the
-- game sent late add matches (UI/Lists.lua).
function UI:ShowRecipeMatches()
    local state = self.state
    if not self.encounters:IsListed(state.encounter) then state.encounter = self.encounters:FirstRecipe() end
    self.encounters:ScrollTo(state.encounter)
    self.encounters:Refresh()
    self:Refresh()
end

function UI:SelectEncounter(encounter)
    -- Picking an instance's Overview shows its Overview, not its open map.
    if encounter and encounter.overview then self.overview.showMap = false end
    self.state.encounter = encounter
    self.state.quest, self.state.questline = nil, nil
    self.encounters:Refresh()
    self:Refresh()
end

-- A dungeon quest picked under Quests in the middle column: it takes the
-- encounter's place, and the content pane shows it. Nothing while the
-- Quests module is off.
function UI:SelectQuest(quest)
    if not ns.Modules:IsOn("QUESTS") then return end
    self.state.quest = quest
    self.state.encounter, self.state.questline = nil, nil
    -- A dungeon quest for one side turns the Quests switch to that side, so
    -- it is listed.
    local instance = self.state.instance
    if quest.side and quest.side ~= self.QuestSide() and instance and instance.category == "DUNGEON" then
        self.state.questSide = quest.side
        self.encounters:Rebuild()
    else
        self.encounters:Refresh()
    end
    -- A quest folded under its questline's row (opened from that
    -- questline's page) slides the fold open so its row shows.
    self.encounters:OpenFoldOf(quest)
    self:Refresh()
end

-- A dungeon questline picked under Quests (UI/DungeonQuestlines.lua): it
-- takes the encounter's place, and the content pane shows its page.
function UI:SelectQuestline(questline)
    if not ns.Modules:IsOn("QUESTS") then return end
    self.state.questline = questline
    self.state.encounter, self.state.quest = nil, nil
    self.encounters:Refresh()
    self:Refresh()
end

-- The Quests header's switch: list the quests that side can take.
function UI:SetQuestSide(side)
    if side == self.QuestSide() then return end
    self.state.questSide = side
    self.encounters:Rebuild()
    self:Refresh()
end

-- Drops a search still waiting on a pause in typing.
function UI:CancelPendingSearch()
    if self.searchTimer then
        self.searchTimer:Cancel()
        self.searchTimer = nil
    end
end

function UI:SetSearch(text)
    self:CancelPendingSearch()
    self.state.search = text ~= "" and text:lower() or nil
    -- Searching leaves the Settings page for the results.
    if self.state.search and self.settingsOpen then
        self:CloseSettings()
        return
    end
    self:Refresh()
end

-- Typing waits for a short pause and then searches once, rather than on
-- every letter. Clearing the box takes effect at once.
local SEARCH_DELAY = 0.3

function UI:QueueSearch(text)
    self:CancelPendingSearch()
    if text == "" then
        self:SetSearch(text)
        return
    end
    self.searchTimer = C_Timer.NewTimer(SEARCH_DELAY, function()
        self.searchTimer = nil
        self:SetSearch(text)
    end)
end

-- Whether the content pane shows a profession's Overview, whose own parts
-- sit in the strip (UI/ProfessionOverview.lua): read from the state, as the
-- strip is set before the page shows.
local function IsProfessionOverviewOpen()
    local state = UI.state
    return not state.search and state.encounter ~= nil and state.encounter.professionOverview == true
end

-- The content pane's strip, shown while Back, the breadcrumb, a button or a
-- profession's Overview is; that page's chips start after Back.
local function RefreshStrip()
    local state = UI.state
    local last = UI.history[#UI.history]
    UI.back:SetShown(last ~= nil and not state.search and not WHOLE_BODY[state.category])
    if last then UI.back:SetLabel(L["Back to %s"]:format(last.label)) end
    UI:UpdateAddButton()
    UI:UpdateBossTabs()
    UI:UpdateMapButton()
    UI:FitStrip()
    UI:UpdateCrumbs()
    UI.professionOverview:FollowBack(UI.back:IsShown() and UI.back or nil)
    UI.content:SetStrip(UI.back:IsShown() or UI.addButton:IsShown() or UI.lootTab:IsShown()
        or UI.mapButton:IsShown() or UI.crumbs:IsShown() or IsProfessionOverviewOpen())
end

-- Library, the Shopping List, the Wishlist (counted on the status line) or
-- Classes across the whole body.
local function ShowWholeBodyTab(category)
    UI:HideListTabPanes()
    UI:UpdateLink()
    if category == "LIBRARY_BOOKS" then
        UI:UpdateLibraryBack()
        UI.library:Refresh()
        UI.status:SetText("")
        return
    end
    if category == "CLASSES" then
        UI.classes:Update()
        UI.status:SetText("")
        return
    end
    if category == "WISHLIST" then
        UI.wishlist:Update()
        UI.wishlistHost:SetStrip(true)
        UI.status:SetText(UI.wishlist.count == 0 and "" or L["%d wished"]:format(UI.wishlist.count))
        return
    end
    UI.shopping:SetScale(Theme.shoppingScale[TextSize()])
    UI.shopping:Update()
    UI.shoppingHost:SetStrip(true)
    local toBuy = UI.shopping.totalCount
    UI.status:SetText(toBuy == 0 and "" or CountText(toBuy, L["1 to buy"], L["%d to buy"]))
end

-- Search results in the loot pane, drawn again only when they differ from
-- what is on screen (rows fill in their own names and icons as those load).
local function ShowSearchResults(search, keepScroll)
    local results, count, key = ns.Search:Find(search)
    if key ~= UI.loot.searchKey then
        UI.loot.searchKey = key
        local resultCount = CountText(count, L["1 result"], L["%d results"])
        UI.loot:ShowItems(L["Search"], L["%s for \"%s\""]:format(resultCount, search), results, true, nil,
            keepScroll)
    end
    UI.status:SetText("")
end

-- A dungeon's or raid's Overview, its quest count on the status line.
local function ShowOverviewPage(instance)
    UI.overview:ShowInstance(instance)
    local questCount = #ns.Data:Quests(instance.id)
    UI.status:SetText(ns.Modules:IsOn("QUESTS") and CountText(questCount, L["1 quest"], L["%d quests"]) or "")
end

-- A Scarce reagent's page. Built once, so a redraw keeps the scroll position.
local function ShowScarcePage(instance, encounter)
    encounter.page = encounter.page or ScarceEntries(instance, encounter)
    UI.loot:ShowItems(ScarceTitle(encounter), L["%s  ·  Scarce reagent"]:format(instance.name), encounter.page,
        nil, nil, UI.loot.entries == encounter.page)
    UI.status:SetText(CountText(#encounter.sources, L["1 source"], L["%d sources"]))
end

-- A recipe's page. Built once, so a redraw keeps the scroll and measurements.
local function ShowRecipePage(instance, encounter, highlight)
    encounter.recipePage = encounter.recipePage or RecipeEntries(encounter)
    UI.loot:ShowItems(encounter.name, RecipeSubtitle(instance, encounter), encounter.recipePage, nil, highlight,
        UI.loot.entries == encounter.recipePage)
    local materialCount = encounter.reagents and #encounter.reagents or 0
    UI.status:SetText(materialCount > 0 and CountText(materialCount, L["1 material"], L["%d materials"]) or "")
end

-- The line under a loot page's title: the instance, its zone and level range.
local function LootSubtitle(instance, encounter)
    if instance.category == "COLLECTION" then
        -- "Tier Sets  ·  T1 · Warlock" says more than "Tier Sets  ·  Item sets".
        return Theme:JoinDots(instance.name, encounter.note or instance.zone)
    end
    local levels = instance.levelRange and L["Level %d-%d"]:format(instance.levelRange[1], instance.levelRange[2])
    return Theme:JoinDots(instance.name, instance.zone, levels)
end

-- Names the Loot / Abilities pills with their pages' counts.
local function LabelBossTabs(itemCount, abilities)
    UI.lootTab:SetLabel(L["Loot  ·  %d"]:format(itemCount))
    UI.abilitiesTab:SetLabel(L["Abilities  ·  %d"]:format(abilities.count))
end

-- A dungeon boss's abilities page (the Abilities pill lit).
local function ShowAbilitiesPage(instance, encounter, abilities, subtitle, bosses)
    -- Redrawn as the loot's names load: keep the scroll.
    UI.loot:ShowItems(encounter.name, subtitle, abilities, nil, nil, UI.loot.entries == abilities, nil, bosses)
    UI.loot:SetRelatedQuests(UI.RelatedQuests(instance, encounter))
    UI.loot:SetSpoiler(ns.Data:BossSpoiler(instance.id, encounter.id))
    UI.status:SetText(CountText(abilities.count, L["1 ability"], L["%d abilities"]))
    LoadAbilities(abilities, function()
        if UI.state.bossTab == encounter and UI.loot.entries == abilities then UI.loot:Refresh() end
    end)
end

-- An encounter's loot page (a boss, a vendor, a faction's standing...), or
-- a dungeon boss's abilities page while that pill is lit.
local function ShowLootPage(instance, encounter, highlight)
    local subtitle = LootSubtitle(instance, encounter)
    -- Factions: a bar with the character's standing, if they have met it.
    local reputation = instance.factionID and { UI.Reputation(instance.factionID) }
    local bosses = ns.Data:Bosses(instance, encounter)
    local entries = LootFolds(instance, encounter, bosses)
    -- The loot filters (whose All drops names where each item comes from).
    local filtered = LOOT_FILTER_TABS[instance.category] or false
    -- Loot in sections: quest items, weapons, armor... Dungeons and raids
    -- show one row per item name; vendor lists keep every level of an item.
    -- A faction's standing gets a section per profession, as its quartermaster
    -- may sell dozens of each profession's recipes.
    encounter.sections = encounter.sections or UI.LootSections(entries, function()
        if UI.state.encounter == encounter then UI:Refresh() end
    end, nil, not INSTANCE_TABS[instance.category], instance.category == "FACTION")
    entries = filtered and UI.FilterLoot(encounter.sections) or encounter.sections
    -- Each item once, though a PvP item several classes can use sits under each.
    local itemCount, counted = 0, {}
    for _, row in ipairs(entries) do
        if not (row.header or row.fold or counted[row]) then
            counted[row] = true
            itemCount = itemCount + 1
        end
    end
    -- Built once per encounter, so this is the list UI:UpdateBossTabs found.
    local abilities = AbilityEntries(instance, encounter, bosses)
    if abilities then LabelBossTabs(itemCount, abilities) end
    if abilities and UI.state.bossTab == encounter then
        ShowAbilitiesPage(instance, encounter, abilities, subtitle, bosses)
        return
    end
    UI.loot:ShowItems(encounter.name, subtitle, entries, encounter.allDrops, highlight, nil,
        reputation and reputation[1] and reputation or nil, bosses)
    UI.loot:ShowFilters(filtered)
    -- Quests whose map markers are on this boss.
    UI.loot:SetRelatedQuests(UI.RelatedQuests(instance, encounter))
    UI.loot:SetSpoiler(ns.Data:BossSpoiler(instance.id, encounter.id))
    UI.status:SetText(L["%d items"]:format(itemCount))
end

-- Redraws the window's panes from the current selection or search.
-- Searching covers every category, so it can show results over an empty tab.
function UI:Refresh()
    local state = self.state
    -- The run history (UI/RunHistory.lua, local checkouts only) lies over a Dungeons or Raids
    -- tab while it is open; it is asked first, so it hides while the Settings page shows.
    local isRunHistoryShown = ns.RunPage ~= nil and ns.RunPage.ShowHistory()
    if self:ShowSettingsPage() or isRunHistoryShown then return end
    RefreshStrip()
    local wholeBodyPane = not state.search and WHOLE_BODY[state.category]
    for _, paneKey in pairs(WHOLE_BODY) do
        if self[paneKey] then self[paneKey]:SetShown(paneKey == wholeBodyPane) end
    end
    if wholeBodyPane then
        ShowWholeBodyTab(state.category)
        return
    end
    local instance, encounter = state.instance, state.encounter
    local hasData = instance ~= nil
    local quest = not state.search and state.quest
    local questline = not state.search and not quest and state.questline or nil
    local overview = not state.search and (quest or encounter and encounter.overview)
    local professionOverview = not state.search and encounter and encounter.professionOverview or false
    local runReport = not state.search and encounter and encounter.runPage or false
    -- The Professions tab shows the profession bar and the filter sidebar in
    -- the instance list's place.
    local isProfessionTab = state.category == "PROFESSION"
    self.instances:SetShown(hasData and not isProfessionTab)
    self.professionBar:SetShown(hasData and isProfessionTab)
    self.recipeSidebar:SetShown(hasData and isProfessionTab)
    if isProfessionTab then self.professionBar:Paint() end
    self.encounters:SetShown(hasData)
    self.loot:SetShown((hasData or state.search ~= nil) and not overview and not professionOverview
        and not questline and not runReport)
    self.overview:SetShown(overview and true or false)
    self.professionOverview:SetShown(professionOverview)
    self.questlinePage:SetShown(questline ~= nil)
    if self.runPage then self.runPage:SetShown(runReport) end
    self.empty:SetShown(not hasData and not state.search)
    self:UpdateLink()
    local small = not state.search and hasData and SMALL_GRID[instance.category]
    self.loot:SetZoom(small and SMALL_GRID_SCALE or 1)
    local found = state.found
    local highlight = found and found.encounter == encounter and found.itemID or nil
    -- The same search redrawn (names arriving) keeps its scroll position.
    local sameSearch = self.shownSearch == state.search
    self.shownSearch = state.search
    if state.search then
        ShowSearchResults(state.search, sameSearch)
        return
    end
    self.loot.searchKey = nil
    if quest then
        self.overview:ShowQuest(instance, quest)
        self.status:SetText("")
    elseif questline then
        self.questlinePage:ShowFold(questline)
        self.status:SetText("")
    elseif overview then
        ShowOverviewPage(instance)
    elseif professionOverview then
        self.professionOverview:ShowProfession(instance)
        self.status:SetText("")
    elseif runReport then
        self.runPage:ShowRun(instance)
        self.status:SetText("")
    elseif encounter and instance.category == "PROFESSION" and encounter.scarce then
        ShowScarcePage(instance, encounter)
    elseif encounter and instance.category == "PROFESSION" then
        ShowRecipePage(instance, encounter, highlight)
    elseif encounter then
        ShowLootPage(instance, encounter, highlight)
    elseif instance then
        -- The recipe filter matched nothing.
        self.loot:ShowItems(L["No matching recipes"], L["Clear the filter to see every recipe"], {})
        self.status:SetText("")
    else
        self.status:SetText("")
    end
end

-- Shows the "Add to shopping list" link when the open recipe makes an item,
-- naming how many are on the list already. Returns whether it shows.
function UI:UpdateAddButton()
    local state = self.state
    local encounter = state.encounter
    local canAdd = state.category == "PROFESSION" and not state.search and ns.Modules:IsOn("SHOPPING")
        and ns.Shopping:CanAdd(encounter)
    self.addButton:SetShown(canAdd and true or false)
    if not canAdd then return false end
    self.addButton:UpdateLabel()
    return true
end

-- Shows the Loot / Abilities pills on a dungeon boss with known abilities,
-- lighting the page that shows.
function UI:UpdateBossTabs()
    local state = self.state
    local encounter, instance = state.encounter, state.instance
    -- Only a boss's own page: the and-chain gives false, not nil, on the
    -- Overview, a quest or a search.
    local abilities = not state.search and not state.quest and encounter and not encounter.overview and instance
        and AbilityEntries(instance, encounter, ns.Data:Bosses(instance, encounter)) or nil
    -- Abilities stay open only on the boss they were opened for: any other
    -- page, or that boss again later, comes up on its loot.
    if state.bossTab and (not abilities or state.bossTab ~= encounter) then state.bossTab = nil end
    self.lootTab:SetShown(abilities ~= nil)
    self.abilitiesTab:SetShown(abilities ~= nil)
    if abilities then
        local abilitiesOpen = state.bossTab ~= nil
        self.abilitiesTab:SetTone(abilitiesOpen and Theme.color.heading or nil)
        self.lootTab:SetTone(not abilitiesOpen and Theme.color.heading or nil)
    end
end

-- Shows Map on a dungeon or raid boss's page when the boss is pinned on
-- the instance's layout map, left of Loot / Abilities when they show.
function UI:UpdateMapButton()
    local state = self.state
    local instance, encounter = state.instance, state.encounter
    local floor = not state.search and not state.quest and instance and encounter
        and INSTANCE_TABS[instance.category] and self.BossFloor(instance, encounter)
    local btn = self.mapButton
    btn:SetShown(floor and true or false)
    if not floor then return end
    btn:ClearAllPoints()
    if self.lootTab:IsShown() then
        btn:SetPoint("RIGHT", self.lootTab, "LEFT", -STRIP_BUTTON_GAP, 0)
    else
        btn:SetPoint("RIGHT", -STRIP_INSET, 0)
    end
end

local function StripButtonsWidth()
    local width = 0
    for _, btn in ipairs({ UI.mapButton, UI.lootTab, UI.abilitiesTab, UI.addButton }) do
        if btn:IsShown() then width = width + btn:GetWidth() + STRIP_BUTTON_GAP end
    end
    return width
end

-- The strip's breadcrumb on a dungeon's or raid's quest, questline or boss
-- page, after Back and its hint and short of the buttons at the right:
-- "Scholomance  >  Barov Family Fortune", a questline's "Scholomance  >
-- Quests  >  The Key to Scholomance".
function UI:UpdateCrumbs()
    local state, crumbs = self.state, self.crumbs
    local instance = state.instance
    local page = not state.search and instance and INSTANCE_TABS[instance.category]
        and (state.quest or state.questline or (state.encounter and not state.encounter.overview and state.encounter))
    crumbs:SetShown(page and true or false)
    if not page then return end
    local muted = Theme:ColorCode(Theme.color.muted)
    local section = page == state.questline and ("%s%s|r  %s>|r  "):format(muted, L["Quests"], muted) or ""
    crumbs.text:SetText(("|Hneedroll:crumb|h%s%s|r|h  %s>|r  %s%s%s|r"):format(Theme:ColorCode(Theme.color.link),
        instance.name, muted, section, Theme:ColorCode(Theme.color.heading), page.name))
    local anchor = self.backHint:IsShown() and self.backHint or self.back:IsShown() and self.back or nil
    crumbs:ClearAllPoints()
    if anchor then
        crumbs:SetPoint("LEFT", anchor, "RIGHT", 14, 0)
    else
        crumbs:SetPoint("LEFT", Size.pad, 0)
    end
    crumbs:SetPoint("RIGHT", self.content.strip, "RIGHT", -Size.pad - StripButtonsWidth(), 0)
end

-- An instance's Overview is its first encounter (flagged overview); nil without one.
local function OverviewOf(instance)
    local first = instance and instance.encounters[1]
    return first and first.overview and first or nil
end

-- A crumb's instance: its Overview, Back returning here.
function UI:OpenOverview()
    local overview = OverviewOf(self.state.instance)
    if not overview then return end
    self:PushBack(self:Place())
    self:SelectEncounter(overview)
    self.encounters:ScrollTo(overview)
end

-- The back hint gives way when the pills at the strip's right would run
-- into it (a long "Back to" in a narrow window), and on a profession's
-- Overview, whose chips follow Back.
function UI:FitStrip()
    local leftWidth = STRIP_INSET + self.back:GetWidth() + BACK_HINT_GAP + self.backHint:GetWidth()
    self.backHint:SetShown(self.back:IsShown() and not IsProfessionOverviewOpen()
        and leftWidth + StripButtonsWidth() + Size.pad <= self.content:GetWidth())
end

-- Opens the instance's map on floor `level`, `encounter`'s pin (or `quest`'s
-- marker, or a gold pin on `spot`) lit, Back returning to the page being left.
local function OpenMapAt(instance, overview, encounter, level, quest, spot)
    UI:PushBack(UI:Place())
    UI.overview:ShowBoss(instance, encounter, level)
    if quest then UI.overview.mapView.focusQuest = quest end
    if spot then UI.overview.mapView.focusSpot = spot end
    UI.state.encounter, UI.state.quest, UI.state.questline = overview, nil, nil
    UI.encounters:ScrollTo(overview)
    UI.encounters:Refresh()
    UI:Refresh()
end

-- The boss page's Map button: the instance's map on the floor the boss is
-- pinned on, its pin lit. Back returns to the boss's page. `encounter` (another
-- of the instance's bosses, from a quest page) shows that boss instead.
-- Returns false when it isn't pinned.
function UI:ShowBossOnMap(encounter)
    local instance = self.state.instance
    encounter = encounter or self.state.encounter
    local level = self.BossFloor(instance, encounter)
    local overview = OverviewOf(instance)
    if not (level and overview) then return false end
    OpenMapAt(instance, overview, encounter, level)
end

-- A quest's drop area (a "loot" marker): the instance's map on its floor,
-- the marker lit. Back returns to the quest's page. Returns false when the
-- quest has none.
function UI:ShowQuestOnMap(quest)
    local instance = self.state.instance
    local level = instance and self.QuestDropSpot(instance.id, quest.id, true)
    local overview = OverviewOf(instance)
    if not (level and overview) then return false end
    OpenMapAt(instance, overview, {}, level, quest)
end

-- Someone standing inside the instance with no boss pin of their own (a
-- trainer the Professions Overview names): the instance's map on their
-- floor, a gold pin lit on their spot. `spot` is { level, x, y } on the
-- layout map (Data/Maps.lua), `name` their name for the pin's tooltip.
-- Back returns to the page. Returns false when the instance has no map.
function UI:ShowSpotOnMap(spot, name)
    local instance = self.state.instance
    local overview = OverviewOf(instance)
    if not (overview and ns.Data:Map(instance.id)) then return false end
    OpenMapAt(instance, overview, {}, spot[1], nil, { spot[1], spot[2], spot[3], name = name })
end

-- The instance's map on the floor it opens on, for something somewhere
-- inside with no pin of its own. Back returns to the page. Returns false
-- when the instance has no map.
function UI:ShowInstanceMap()
    local instance = self.state.instance
    local map = instance and ns.Data:Map(instance.id)
    local overview = OverviewOf(instance)
    if not (map and overview) then return false end
    OpenMapAt(instance, overview, {}, map.start or 1)
end

-- Loot / Abilities pills: which page a dungeon boss shows. state.bossTab
-- is the encounter whose abilities are open (Back returns to them); every
-- other page shows loot first.
function UI:SetBossTab(key)
    local abilitiesEncounter = key == "abilities" and self.state.encounter or nil
    if abilitiesEncounter == self.state.bossTab then return end
    self.state.bossTab = abilitiesEncounter
    self:Refresh()
end

-- The shopping list or a wishlist changed: redraw its tab when it shows,
-- else run `otherwise` (the add link's count, the stars on show).
local function OnListChange(category, otherwise)
    return function()
        if not (UI.frame and UI.frame:IsShown()) then return end
        if UI.state.category == category and not UI.state.search then UI:Refresh() else otherwise() end
    end
end
ns.Shopping:OnChange(OnListChange("SHOPPING", function() UI:UpdateAddButton() end))
ns.Wishlist:OnChange(OnListChange("WISHLIST", function() UI.loot:UpdateStars() end))

function UI:Toggle()
    if self.frame and self.frame:IsShown() then self:Hide() else self:Show() end
end

-- Theme starts in the native skin; until NeedRoll's window is first built,
-- this puts the style saved in Settings in place. Read only once it is
-- needed, not at login, since ElvUI fills in its colors after login. Also
-- for windows that can open before NeedRoll's (the level-up window).
function UI:UseSavedSkin()
    if not self.frame then Theme:SetSkin(ns.db.skin) end
end

function UI:Show()
    self:UseSavedSkin()
    self:Build()
    self:UpdateVersionNote()
    ns.Search:Warm()
    self.frame:Show()
    -- Names that loaded while the window was closed may add search results.
    if self.state.search then self:Refresh() end
    -- First time: point at the Settings button.
    if not ns.db.welcomed then ns.Welcome:Show() end
    self:FollowPlayer()
end

function UI:Hide()
    if self.frame then self.frame:Hide() end
end

-- Inside a dungeon or raid -------------------------------------------------
-- The window opens on the instance's map, on the floor the player is on,
-- the first time it opens after they come in; after that it opens where it
-- was left. While it shows that map, the map follows them to each floor
-- they reach (a floor picked by hand stays until they move to another).
-- The game's map key (M) stays the game's: its world map opens with this
-- map laid over it (UI/WorldMapOverlay.lua), unless the settings say Game.
local lastFloorKey  -- "instance ID:level" where the player was last seen

-- Moves the window to the player's floor: `open` goes there from anywhere;
-- otherwise only a map of that instance already showing changes floor.
function UI:FollowPlayer(open)
    if not (self.frame and self.frame:IsShown()) then return false end
    local instance, level = self.PlayerFloor(self.state.instance)
    if not (instance and ns.Modules:IsOn(instance.category)) then return false end
    local floorKey = instance.id .. ":" .. level
    -- A new instance (or the first floor seen) counts as opening.
    open = open or not lastFloorKey or not lastFloorKey:find("^" .. instance.id .. ":")
    if not open and floorKey == lastFloorKey then return true end
    lastFloorKey = floorKey
    local state = self.state
    local onOverview = state.instance == instance and not state.quest and not state.search
        and state.encounter and state.encounter.overview
    if open then
        -- Back from here goes to the instance's Overview, then to the
        -- game's world map, and no further.
        if not onOverview then self:GoToSource(instance) end
        self:ClearHistory()
        self:StartHistoryAtWorldMap()
        self.overview.showMap = false
        self.overview:ShowFloor(level)
    elseif onOverview and self.overview.showMap then
        self.overview:ShowFloor(level)
    end
    return true
end

-- NeedRoll leaves showing and hiding the game's map to the game wherever
-- it can. When an addon's code shows or hides it, the map's own code runs
-- as the addon's (tainted), and the game then blocks what only it may do:
-- Shift-clicking a map pin into chat also copies it to the clipboard, which
-- came up as "NeedRoll has been blocked from an action only available to
-- the Blizzard UI". So the map key is left to the game, NeedRoll's map is
-- laid over the game's rather than shown in its place, and NeedRoll's links
-- to the game's map click the game's own map button.

-- Whether the game's world map is open (UI/WorldMapOverlay.lua asks too).
function UI.GameMapOpen() return WorldMapFrame ~= nil and WorldMapFrame:IsShown() end

-- Back from here leads to the game's world map and no further.
function UI:StartHistoryAtWorldMap()
    wipe(self.history)
    table.insert(self.history, { label = L["world map"], worldMap = true })
end

-- A boss or quest clicked on NeedRoll's map over the game's world map: the
-- window opens on its page above the map, which stays open (closing it from
-- here would taint it, above). Back is the world map's alone: its secure
-- link finds the map open and just closes the window, back to the map.
function UI:ShowFromWorldMap(instance, encounter, quest)
    self:Show()
    self.frame:Raise()
    self:GoToSource(instance, encounter)
    if encounter then self.encounters:ScrollTo(encounter) end
    if quest then self:SelectQuest(quest) end
    self:StartHistoryAtWorldMap()
    self:Refresh()
end

-- Opens the Library tab on `book` (Data/LibraryBooks.lua): its fold open
-- and scrolled to it (UI/LibraryBooks.lua's page:ShowBook). Back returns to
-- the place left (a search's results). Nothing while the Library is off.
function UI:ShowLibraryBook(book)
    if not ns.Modules:IsOn("LIBRARY_BOOKS") then return end
    local from = self:Place()
    if self.state.category ~= "LIBRARY_BOOKS" then self:RememberPlace() end
    self:ClearHistory()
    self:PushBack(from)
    self:SelectCategory("LIBRARY_BOOKS")
    self.library:ShowBook(book)
end

-- The Library tab's Back: shown while there is a place to return to (the
-- search results a book was opened from, UI:ShowLibraryBook), the page's
-- chips after it. Every other way onto the tab starts with no trail.
function UI:UpdateLibraryBack()
    local last = self.history[#self.history]
    self.libraryBack:SetShown(last ~= nil)
    if last then self.libraryBack:SetLabel(L["Back to %s"]:format(last.label)) end
    self.library:FollowBack(last and self.libraryBack or nil)
end

-- A library book clicked on the game's world map (UI/WorldMapMarkers.lua):
-- the window opens on the Library tab above the map, which stays open. The
-- tab opens with no trail, so it shows no Back to the map.
function UI:ShowLibraryFromWorldMap()
    self:Show()
    self.frame:Raise()
    self:SwitchTab("LIBRARY_BOOKS")
end

-- Runs `open`, which opens the game's map from NeedRoll's code (a quest in
-- the log, the map when the game's map button didn't open it): an opening
-- the game sees as NeedRoll's. Every one goes through here, so a search for
-- WithGameMap finds them all.
function UI:WithGameMap(open, ...)
    open(...)
end

-- The game's map, opened by NeedRoll itself: the window closes and the
-- world map opens, unless it is open already (under the window). NeedRoll's
-- links to it click the game's map button instead (below); this is for
-- when they can't. In combat NeedRoll never opens the game's map: chat says
-- why and the window stays. Returns whether the world map shows.
function UI:OpenWorldMap()
    if not UI.GameMapOpen() and UI.MapLinksInCombat() then
        ns.UI.SayNoMapInCombat()
        return false
    end
    self:Hide()
    if not UI.GameMapOpen() then self:WithGameMap(ShowUIPanel, WorldMapFrame) end
    return true
end

-- Opens the game's map and turns it to zone `uiMapID`: the game's own call,
-- else (a client whose map doesn't answer it) the map opened and turned here.
local function OpenGameMapOn(uiMapID)
    C_Map.OpenWorldMap(uiMapID)
    if not UI.GameMapOpen() then ShowUIPanel(WorldMapFrame) end
    if WorldMapFrame:GetMapID() ~= uiMapID then WorldMapFrame:SetMapID(uiMapID) end
end

-- The game's map opened on zone `uiMapID`, without a pin (a farming zone on
-- the Professions Overview). The map opens below the window (its strata is
-- lower), so the window closes once it shows. In combat NeedRoll never
-- opens or moves the game's map: chat says why.
function UI:OpenZoneMap(uiMapID)
    if UI.MapLinksInCombat() then
        ns.UI.SayNoMapInCombat()
        return
    end
    self:WithGameMap(OpenGameMapOn, uiMapID)
    if UI.GameMapOpen() then self:Hide() end
end

-- The game's own buttons that open its map, by client: the minimap's zone
-- text, the minimap's map button, the micro menu's. The first this client
-- has (and that worked) is clicked.
local GAME_MAP_BUTTONS = { "MinimapCluster.ZoneTextButton", "MiniMapWorldMapButton", "WorldMapMicroButton" }
local failedMapButtons = {}  -- the buttons above that didn't open the map, by path
local function GameMapButton()
    for _, path in ipairs(GAME_MAP_BUTTONS) do
        if not failedMapButtons[path] then
            local button = _G
            for key in path:gmatch("[^.]+") do button = type(button) == "table" and button[key] or nil end
            if type(button) == "table" and button.IsObjectType and button:IsObjectType("Button") then
                return button, path
            end
        end
    end
end

-- Whether NeedRoll's map links act as in combat: their secure buttons put
-- away, and a click reaching NeedRoll's own code, which draws NeedRoll's own
-- pin (ShowOnMap in UI/Overview.lua). Calls the game blocks in combat still
-- ask InCombatLockdown() itself.
function UI.MapLinksInCombat()
    --[==[@debug@
    -- Local checkouts: /nr devedit's "Fake combat" box (UI/MapEdit.lua), to
    -- try NeedRoll's own pin out of combat.
    if UI.fakeCombat then return true end
    --@end-debug@]==]
    return InCombatLockdown()
end

--[==[@debug@
-- Local checkouts: /nr devedit's "View as" boxes (UI/MapEdit.lua). NeedRoll
-- treats the character as `faction` ("Alliance" or "Horde"; nil: its own
-- side) wherever it asks ns.PlayerFaction. The sides the panes had picked
-- go back to following it, and what shows is drawn again.
function UI:ViewAsFaction(faction)
    ns.viewAsFaction = faction
    local state = self.state
    state.questSide, state.faction = nil, ns.PlayerFaction()
    if self.overview then self.overview.attuneSide = nil end
    if self.classes then self.classes:PickQuestSide(nil) end
    if self.instances then self:SelectCategory(state.category) end
end
--@end-debug@]==]

-- Frames made in combat, waiting for it to end to let right-clicks through.
local waitingForRightClicks = {}

-- Lets right-clicks through `widget` to what is under it: NeedRoll's
-- right-click = Back, and on the game's map its own right-click (the game's
-- map pins do the same). SetPassThroughButtons is blocked in combat, so a
-- widget made then (a /reload in combat makes the secure links then) waits
-- for PLAYER_REGEN_ENABLED. This is NeedRoll's only call the game blocks in
-- combat for every frame (a smoke test keeps it so).
function UI.PassRightClicks(widget)
    if InCombatLockdown() then
        table.insert(waitingForRightClicks, widget)
        return
    end
    widget:SetPassThroughButtons("RightButton")
end
ns:On("PLAYER_REGEN_ENABLED", function()
    local waiting = waitingForRightClicks
    waitingForRightClicks = {}
    for _, widget in ipairs(waiting) do UI.PassRightClicks(widget) end
end)

-- Runs `frame`'s own `script` handler (its OnEnter, OnLeave...) with `...`.
local function RunFrameScript(frame, script, ...)
    local handler = frame and frame:GetScript(script)
    if handler then handler(frame, ...) end
end

-- The nearest of `frame`'s parents that takes the mouse: what a click on
-- `frame` would land on without it.
local function MouseTakerBeneath(frame)
    local parent = frame:GetParent()
    while parent and not parent:IsMouseEnabled() do parent = parent:GetParent() end
    return parent
end

-- Makes a small icon with its own tooltip (a row's tick or portal) part of
-- the row or page it sits on: a press and a release on it run that frame's
-- own (a press on a page moves the window), and a click on it clicks a row
-- that is a button. SetPropagateMouseClicks would do the same, but the game
-- blocks it in combat; scripts run in combat too. A right-click goes on to
-- a row only when the row takes them (row.takesRightClicks).
function UI.ClicksReachBeneath(icon)
    icon:SetScript("OnMouseDown", function(self, button)
        RunFrameScript(MouseTakerBeneath(self), "OnMouseDown", button)
    end)
    icon:SetScript("OnMouseUp", function(self, button)
        local beneath = MouseTakerBeneath(self)
        RunFrameScript(beneath, "OnMouseUp", button)
        if not (beneath and beneath:IsObjectType("Button") and self:IsMouseOver()) then return end
        if button == "LeftButton" or (button == "RightButton" and beneath.takesRightClicks) then
            beneath:Click(button)
        end
    end)
end

-- What the mouse wheel over a secure link scrolls: the nearest of `frame`
-- and its parents with an OnMouseWheel script (the page it sits in), inside
-- NeedRoll's window only. The game's map zooms with the wheel too, but its
-- handler run from NeedRoll's code would taint the map.
local function WheelTarget(frame)
    local found
    while frame and frame ~= UIParent do
        found = found or (frame:GetScript("OnMouseWheel") and frame)
        if frame == UI.frame then return found end
        frame = frame:GetParent()
    end
end

-- NeedRoll's secure links: each a secure button laid over something of
-- NeedRoll's that the player clicks, so the click runs as the game's own
-- action rather than NeedRoll's. Each is { over = its secure button,
-- target = a function returning the frame it lies over now (nil: put
-- away), square = nil when it covers all of that frame, else a function
-- returning the part it covers ({ x, y, size }, nil for all of it),
-- frame = the frame it was last laid over, placed = how it was last laid }.
local links = {}

-- The mouse coming onto a link's button: the frame beneath just got its
-- OnLeave, as the button took the mouse from it, so its hover (highlight,
-- tooltip) runs again; and the mouse leaving it ends that hover.
local function ShowFrameHover(link)
    link.hoverFrame = link.frame
    RunFrameScript(link.hoverFrame, "OnEnter", true)
end
local function EndFrameHover(link)
    local frame = link.hoverFrame
    link.hoverFrame = nil
    RunFrameScript(frame, "OnLeave", true)
end

-- A secure link's button. Out of combat it is a child of the frame it lies
-- over: in game a frame outside a window never gets the mouse over that
-- window, whatever its frame level, while a child of the frame beneath does
-- (proven on WoW: Forever, 2026-10-19). A window holding a secure button
-- can't show, hide or move in combat, so as combat starts each button goes
-- back onto UIParent, hidden, until combat ends (one made in combat, by a
-- /reload, starts there); as its action can't be changed in combat either,
-- the frame beneath then takes the click itself. It holds the mouse while
-- it shows: a button that takes clicks only gets none on a frame that has
-- the mouse. So it shows the hover of what is beneath itself
-- (link:ShowHover and link:EndHover), passes right-clicks through and
-- scrolls the page beneath.
local function NewSecureLink(target, square)
    local over = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    over:Hide()
    over:RegisterForClicks("LeftButtonUp")
    over:SetAttribute("useOnKeyDown", false)
    UI.PassRightClicks(over)
    local link = { over = over, target = target, square = square, ShowHover = ShowFrameHover, EndHover = EndFrameHover }
    over:SetScript("OnEnter", function() link:ShowHover() end)
    over:SetScript("OnLeave", function() link:EndHover() end)
    over:SetScript("OnMouseWheel", function(_, delta)
        local page = WheelTarget(link.frame)
        RunFrameScript(page, "OnMouseWheel", delta)
    end)
    table.insert(links, link)
    return link
end

local LINK_LEVELS_UP = 10  -- a secure button's frame level over the frame it lies over

-- Puts a link's button `over` into `frame` as its child, over the frame's
-- `square` ({ x, y, size } in the frame's own units, from its bottom left
-- corner) or, without one, over all of it. It takes the frame's strata
-- with it.
local function PlaceOver(over, frame, square)
    over:SetParent(frame)
    over:SetFrameLevel(frame:GetFrameLevel() + LINK_LEVELS_UP)
    over:ClearAllPoints()
    if not square then return over:SetAllPoints(frame) end
    over:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", square.x, square.y)
    over:SetSize(square.size, square.size)
end

-- Lays a link's secure button over its frame while that shows, out of
-- combat. link.placed remembers how it was laid, so it moves only when that
-- changes.
local function LayOverLink(link)
    local over = link.over
    local frame = not UI.MapLinksInCombat() and link.target()
    if not (frame and frame:IsVisible()) then
        if over:IsShown() and not InCombatLockdown() then over:Hide() end
        link.placed = nil
        return
    end
    link.frame = frame
    local square = link.square and link.square()
    local placed, level = link.placed, frame:GetFrameLevel()
    if not (placed and placed.frame == frame and placed.square == square and placed.level == level) then
        link.placed = { frame = frame, square = square, level = level }
        PlaceOver(over, frame, square)
    end
    over:Show()
end
local function LayOverLinks()
    for _, link in ipairs(links) do LayOverLink(link) end
end

-- The links follow their frames every frame, but only while a frame that can
-- hold one shows: NeedRoll's window (one per style) or the game's world map
-- (NeedRoll's pin on it). A hidden frame gets no OnUpdate, so the rest of the
-- session costs nothing.
local linkLayer = CreateFrame("Frame", nil, UIParent)
linkLayer:Hide()
linkLayer:SetScript("OnUpdate", LayOverLinks)
local linkHosts = {}  -- the frames above

local function UpdateLinkLayer()
    local hostShown = false
    for _, host in ipairs(linkHosts) do hostShown = hostShown or host:IsShown() end
    -- The last pass puts away the buttons over frames that just hid.
    if not hostShown then LayOverLinks() end
    linkLayer:SetShown(hostShown)
end

-- Runs the links while `host` shows. The window calls this as it is built;
-- hooking only watches, so the world map's own scripts still run as the game's.
function UI.HostSecureLinks(host)
    if tContains(linkHosts, host) then return end
    table.insert(linkHosts, host)
    host:HookScript("OnShow", UpdateLinkLayer)
    host:HookScript("OnHide", UpdateLinkLayer)
    UpdateLinkLayer()
end
-- The game's map may load after NeedRoll (Blizzard_WorldMap).
local function HostOnWorldMap()
    if WorldMapFrame then UI.HostSecureLinks(WorldMapFrame) end
end
ns:On("PLAYER_LOGIN", HostOnWorldMap)
ns:On("ADDON_LOADED", function(name) if name == "Blizzard_WorldMap" then HostOnWorldMap() end end)
-- Put away and back onto UIParent as combat starts, the last moment they
-- can be, so no window holds a secure button in combat.
ns:On("PLAYER_REGEN_DISABLED", function()
    if InCombatLockdown() then return end -- too late: the game has locked them already
    for _, link in ipairs(links) do
        link.over:Hide()
        link.over:ClearAllPoints()
        link.over:SetParent(UIParent)
        link.placed = nil
    end
end)

-- NeedRoll's links to the game's map (the pill under this map, Back to the
-- world map) click the game's map button through their secure link, so the
-- map opens as the game's own. In combat the click reaches the link's own
-- script, which leaves the map shut (UI:OpenWorldMap).
-- `target` returns the link's frame, `when` says whether it opens the
-- game's map now, and `before` runs as it is clicked, before the map opens.
local function GameMapLink(target, when, before)
    local over = NewSecureLink(function()
        local frame = target()
        if not (frame and frame:IsVisible() and when()) then return nil end
        return GameMapButton() and frame or nil
    end).over
    local wasOpen, path
    over:SetScript("PreClick", function(self)
        if InCombatLockdown() then return end
        local button
        button, path = GameMapButton()
        wasOpen = UI.GameMapOpen()
        -- Already open, where a click on the game's button would close it.
        self:SetAttribute("type", not wasOpen and button and "click" or nil)
        self:SetAttribute("clickbutton", button)
        before()
    end)
    over:SetScript("PostClick", function()
        if wasOpen or not WorldMapFrame or WorldMapFrame:IsShown() then return end
        -- That button didn't open it: the next one will, and NeedRoll does now.
        if path then failedMapButtons[path] = true end
        UI:WithGameMap(ShowUIPanel, WorldMapFrame)
    end)
end

GameMapLink(function() return UI.overview and UI.overview.mapView and UI.overview.mapView.worldMap end,
    function() return true end,
    function() UI:Hide() end)
GameMapLink(function() return UI.back end,
    function()
        local last = UI.history[#UI.history]
        return last ~= nil and last.worldMap == true
    end,
    function()
        table.remove(UI.history)
        UI:Hide()
    end)

-- NeedRoll's links that pin a spot on the game's map (an NPC or a dungeon
-- entrance named on a page, the Entrance row, a recipe's source, NeedRoll's
-- own pin on the world map). When NeedRoll's code sets the game's map pin
-- (C_Map.SetUserWaypoint), the game remembers the pin as NeedRoll's, and
-- Shift-clicking it to share it is then blocked ("NeedRoll has been
-- blocked"). So out of combat, the link's click runs the game's own
-- /mappin command through a secure macro button laid over the link while
-- the mouse is on it, and the game places the pin (and opens its map
-- there) itself. In combat the button is put away; the link's own click
-- then reaches NeedRoll, which draws its own pin on the world map instead
-- (ns.UI.ShowOnMap).
-- hoveredMapLink: { frame, spot, onModifiedClick, showLinkTooltip, square }
-- while the mouse is on such a link; square, for a link inside a text, is
-- where its button lies in the frame (PlaceOver).
local hoveredMapLink
local mapPinLink

-- A link inside a text has no frame of its own to lie over, so its button
-- is a small square laid where the mouse came onto it. It stays there (it
-- moves with the text as the page scrolls), so the mouse can leave it, and
-- the text then finds the link under the mouse again, if any.
-- The button is the frame's child, so the square is in the frame's units:
-- NeedRoll's window has its own scale (Settings), and the cursor's spot is
-- in the screen's pixels.
local MAP_LINK_HIT_SIZE = 24  -- the square's side, in UIParent's units
local function SquareUnderCursor(frame)
    local left, bottom = frame:GetRect()
    if not left then return nil end
    local scale = frame:GetEffectiveScale()
    local size = MAP_LINK_HIT_SIZE * UIParent:GetEffectiveScale() / scale
    local x, y = GetCursorPosition()
    return { x = x / scale - left - size / 2, y = y / scale - bottom - size / 2, size = size }
end

mapPinLink = NewSecureLink(function()
    local hovered = hoveredMapLink
    if not hovered then return nil end
    -- Its text hid or the mouse left it without saying so (a page redrawn).
    if not (hovered.frame:IsVisible() and (hovered.frame:IsMouseOver() or mapPinLink.over:IsMouseOver())) then
        hoveredMapLink = nil
        return nil
    end
    return hovered.frame
end, function() return hoveredMapLink and hoveredMapLink.square end)

-- The hover shown while the mouse is on the button: a link inside a text
-- shows its tooltip again, any other runs its frame's OnEnter.
function mapPinLink:ShowHover()
    local hovered = hoveredMapLink
    self.shownHover = hovered
    if not hovered then return end
    if hovered.showLinkTooltip then return hovered.showLinkTooltip() end
    RunFrameScript(hovered.frame, "OnEnter", true)
end

-- The mouse left the button: the link's hover ends, and the button goes.
function mapPinLink:EndHover()
    local hovered = self.shownHover
    self.shownHover = nil
    hoveredMapLink = nil
    LayOverLink(self)
    if not hovered then return end
    RunFrameScript(hovered.frame, hovered.showLinkTooltip and "OnHyperlinkLeave" or "OnLeave", true)
end

local placedMapPin = false  -- the last click ran /mappin
mapPinLink.over:SetScript("PreClick", function(self)
    if InCombatLockdown() then return end
    local hovered, macro = hoveredMapLink, nil
    if hovered and hovered.onModifiedClick and IsModifierKeyDown() then
        hovered.onModifiedClick()
    elseif hovered then
        -- The game's /mappin takes the map and x, y from 0 to 100 (its
        -- handler in Blizzard_SharedMapDataProviders' WaypointLocationDataProvider).
        -- The command has its client's own name only (SLASH_MAPPIN1: ruRU
        -- "/координаты", ptBR "/marcar"), so the macro uses that.
        local map, x, y = ns.UI.MapPoint(hovered.spot)
        if map then macro = ("%s %d %.1f %.1f"):format(SLASH_MAPPIN1, map, x * 100, y * 100) end
    end
    self:SetAttribute("type", macro and "macro" or nil)
    self:SetAttribute("macrotext", macro)
    placedMapPin = macro ~= nil
end)
-- Tracked, the pin shows as the arrow on the minimap and the screen too.
-- NeedRoll's window stays open (Mike, 2026-11-12): the game's map opens on
-- the pin below it (its strata is lower), and closing the window shows it.
mapPinLink.over:SetScript("PostClick", function()
    if not placedMapPin then return end
    C_SuperTrack.SetSuperTrackedUserWaypoint(true)
end)

-- The mouse came onto a link that pins `spot` (a spot in Data/Data.lua's
-- shape) on `frame`: a click out of combat now runs /mappin for it.
-- `onModifiedClick`, when given, runs for a click with Shift, Ctrl or Alt
-- held instead (an item link goes into chat). `showLinkTooltip` is given
-- for a link inside a text (OnHyperlinkEnter): it shows the link's tooltip
-- again once the mouse is on the link's button. A nil spot: not such a link.
function UI.HoverMapLink(frame, spot, onModifiedClick, showLinkTooltip)
    hoveredMapLink = spot and {
        frame = frame, spot = spot, onModifiedClick = onModifiedClick, showLinkTooltip = showLinkTooltip,
        square = showLinkTooltip and SquareUnderCursor(frame),
    } or nil
    LayOverLink(mapPinLink)  -- at once, for a click right after the mouse arrives
end

-- The mouse left `frame`'s link. Not when it went onto the link's button
-- (which then has the mouse): the hover goes on there until the mouse
-- leaves the button.
function UI.LeaveMapLink(frame)
    if not (hoveredMapLink and hoveredMapLink.frame == frame) then return end
    if mapPinLink.over:IsShown() and mapPinLink.over:IsMouseOver() then return end
    hoveredMapLink = nil
    LayOverLink(mapPinLink)
end

-- Coming into an instance (or out of one) starts over.
ns:On("PLAYER_ENTERING_WORLD", function() lastFloorKey = nil end)
for _, event in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" }) do
    ns:On(event, function() UI:FollowPlayer() end)
end
