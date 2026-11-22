-- The Professions tab's Overview: the page a profession opens on (the right
-- pane, in the content pane MainFrame.lua puts round it; the Overview row
-- above the profession's chips picks it, UI/Lists.lua). Its data is
-- Data/ProfessionGuide.lua. It is laid out as the Classes tab's pet pages
-- (UI/HunterPets.lua, whose PetPageKit builds its heading and rows): a strip
-- on top with the character's skill and level and the faction toggle (and on
-- a gathering profession the chips Near my skill and All ranges), the
-- profession's badge and name with one line under it saying where the
-- character stands, then a list of sections:
--   Camping (first, on a profession with camp features, Data/Camping.lua):
--     each feature it builds at a campsite, lowest skill first: the item
--     (a link with its tooltip) and what it does at the character's level,
--     where its recipe comes from under it (trainers, or the blueprint and
--     the bosses that drop it), and the skill it needs at the
--     right, a link to the recipe.
--   Where to mine / gather / skin (Mining, Herbalism, Skinning, first): the
--     zones where the band holding the character's skill (or every band)
--     spawns the most. On a PvP realm (or with War Mode on, ns.IsPvPRealm)
--     the other side's zones are hidden and each zone is tagged safe or
--     contested; on a PvE realm every zone shows, untagged. A zone opens to
--     the nodes found there, each with the skill it needs and where it turns
--     yellow, green and grey (Skinning: the beast levels found there). The
--     busiest zone of the character's band starts open.
--   Where to learn: each rank, Apprentice to Artisan, its range and what it
--     asks; opened, its nearest trainers of the side shown, or the book or
--     the quest that gives it. The next rank to learn starts open.
--   Specialization: each specialization; opened, its quest chain step by
--     step, then its trainers once the chain is done (or the specialization
--     is chosen), a note saying so until then.
--   Quests: the profession's other quests the side shown can take, shut
--     under its heading until clicked open. A quest group (the Membership
--     Card Renewals) is one line.
-- A click on a rank, zone or specialization opens or shuts it, as a click
-- on the Camping and Quests headings does their sections. Each profession
-- keeps those as the player left them (page.openFolds); one never opened
-- or shut starts as above. Every NPC is a link that pins them on the map
-- (the secure /mappin link of UI/MainFrame.lua; in combat NeedRoll's own
-- pin, ShowOnMap in UI/Overview.lua); one standing inside a dungeon opens
-- NeedRoll's map of it on their spot instead. A zone opens the game's map
-- on it (out of combat only). The faction toggle shows the other side's
-- trainers, quests and zones.
-- The Camping list (the last of the professions) opens on a page of its own
-- here: every camp feature under the rank its skill falls in (Apprentice
-- 1–75 to Artisan 225–300), the character's professions' first (lit), then
-- the rest by name; each row as in a profession's Camping section, with the
-- profession and its skill at the right. No faction toggle there.
local _, ns = ...
local Theme = ns.Theme
local Size = Theme.size
local L = ns.L
local ClassSpells = ns.UI.ClassSpells
local PetPageKit = ns.UI.PetPageKit
local Colored, Muted, Link, JoinAnd = PetPageKit.Colored, PetPageKit.Muted, PetPageKit.Link, PetPageKit.JoinAnd
local RowText, ZoneName = PetPageKit.RowText, PetPageKit.ZoneName
local IsQuestDone = ns.IsQuestDone

local STRIP_INSET = Size.pad - 4  -- the chips and the faction toggle, from the strip's ends (as Back's)
local CHIP_GAP = 6                -- between two chips, and between Back and the first chip
local TOGGLE_GAP = 8              -- between the skill line and the faction toggle
local HEADING_LEFT = 16           -- the rows' text, in from the left (the pet page's)
local RIGHT_INSET = 16            -- a row's right column, in from the row's right
local LINE_ROW = PetPageKit.LINE_ROW  -- a rank's, zone's, specialization's or quest's row
local CHILD_ROW = 20              -- a row under an opened rank, zone or specialization (as a spell's rank rows)
local TWO_LINE_ROW = 36           -- a quest with a second line under it (as the pet page's beast rows)
local TEXT_LIFT = 7               -- that quest's name, up from the row's middle, to make room for the line
local SUB_GAP = 2                 -- between the quest's name and its second line
local CHILD_INDENT = 16           -- an opened row's rows, in from its name (as a pet ability's rank rows)
local FOLD_ARROW_ROOM = 16        -- a heading that opens and shuts its section: its arrow, before the title
local TAG_GAP = 5                 -- between a zone's name and its safe or contested tag
local NODES_COLUMN = 80           -- a zone's "306 nodes", at the right
local SIDE_COLUMN = 80            -- its side ("Contested", "Alliance"), left of that
local LEVELS_COLUMN = 64          -- its levels ("Lv 30-40"), left of that
local COLUMN_GAP = 8              -- between those columns
local SKILL_COLUMN = 36           -- each of a node's four skill numbers, right-aligned, the last at the right
local ZONES_SHOWN = 5             -- a band's zones listed
local TRAINERS_SHOWN = 3          -- an opened rank's or specialization's nearest trainers listed

local RANK_NAMES = { L["Apprentice"], L["Journeyman"], L["Expert"], L["Artisan"] }
local RANK_CAPS = { 75, 150, 225, 300 }  -- the most skill each rank allows
-- The next rank is learned this far short of the last one's cap (Journeyman at 50).
local NEXT_RANK_EARLY = 25
-- A beast turns yellow, green and grey (no more skill-ups) this far past the
-- skill it needs, as most nodes do (a node's own numbers are in the guide).
local SKINNING_STEPS = { 25, 50, 100 }
local MAX_BEAST_LEVEL = 63   -- the highest beast level the guide's Skinning bands reach
local NODES_NAMED = 3        -- the nodes the line under the heading names at most

local FARM_HEADINGS = { MINING = L["Where to mine"], HERBALISM = L["Where to gather"], SKINNING = L["Where to skin"] }

-- A node's four skill numbers in the game's node colours: the skill it
-- needs (orange), then where it turns yellow, green and grey.
local SKILL_COLORS = { "levelHard", "levelFair", "levelEasy", "levelTrivial" }

-- The chips of a gathering profession: the zones of the band holding the
-- character's skill (the default), or of every band.
local NEAR_SKILL, ALL_BANDS = "NEAR", "ALL"
local BAND_FILTERS = { NEAR_SKILL, ALL_BANDS }
local CHIP_LABELS = { [NEAR_SKILL] = L["Near my skill"], [ALL_BANDS] = L["All ranges"] }

-- The list's rows, by `kind`: a section heading; a band's skill range (All
-- bands); a zone; a node or beast level under an opened zone; a rank; a
-- specialization; a line of text with a right column (a trainer, a book, a
-- chain's step) under an opened row; a line of muted text; a quest of the
-- Quests section; a camp feature. A rank, zone or specialization has a
-- `foldKey`: a click opens or shuts it (page.openFolds, ToggleFold).
local HEADING, BAND, ZONE, NODE, RANK, SPEC, LINE, NOTE, QUEST, CAMP =
    "HEADING", "BAND", "ZONE", "NODE", "RANK", "SPEC", "LINE", "NOTE", "QUEST", "CAMP"

-- The sections' headings, by `section`.
local LEARN, SPECS, FARM, QUESTS, CAMPING = "LEARN", "SPECS", "FARM", "QUESTS", "CAMPING"

-- The keys a profession's folds are remembered by in page.openFolds,
-- beside its headings' (QUESTS, CAMPING, and CAMPING1 to CAMPING4 on the
-- Camping list's page): IDs and fixed words, never the names shown, which
-- change with the client's language.
local FoldKeys = {}
function FoldKeys.Rank(index) return "RANK:" .. index end  -- 1 Apprentice to 4 Artisan
function FoldKeys.Spec(spec) return "SPEC:" .. spec.spell end
-- A zone is listed once per skill band, each with its own nodes.
function FoldKeys.Zone(band, zone) return ("ZONE:%d:%d"):format(band.low, zone.map) end

-- Before a specialization's name, as the Quests section's icon marks quests.
local QUEST_MARK = "|A:Exclamation-up-c60:0:0|a"

-- Text ---------------------------------------------------------------------------

local function Done(text)
    return Colored(text, Theme.color.complete)
end

-- `marker` (a giver's or quest's mark, "|A:...:0:0|a") sized to the body
-- font, with a space after it (ns.UI.SizeMarkers).
local function Marker(marker)
    local _, size = Theme.font.body:GetFont()
    return ns.UI.SizeMarkers(marker, size or 12)
end

-- Whether `entry` (an NPC, quest or zone of the guide) serves `side`: its own, or both.
local function ServesSide(entry, side)
    return not entry.side or entry.side == side
end

-- "A or B", "A or B or C": `texts` joined as the locale says "or".
local function JoinOr(texts)
    local joined = texts[1] or ""
    for i = 2, #texts do joined = L["%s or %s"]:format(joined, texts[i]) end
    return joined
end

-- An item's name as the game gives it, else the guide's (or, for a camp
-- feature or its blueprint, Data/Camping.lua's), as PetPageKit.ItemName asks.
local function ItemName(page, itemID)
    return PetPageKit.ItemName(page, itemID, page.guide.items[itemID] or ns.Data.camping.names[itemID])
end

-- "Lv 30-40": the levels the game gives zone `map` (C_Map.GetMapLevels);
-- nil when it gives none.
local function ZoneLevelsText(map)
    local lowest, highest = C_Map.GetMapLevels(map)
    if not (lowest and highest and highest > 0) then return nil end
    if lowest == highest then return L["Lv %d"]:format(lowest) end
    return L["Lv %d-%d"]:format(lowest, highest)
end

-- "1–75", "75–150": rank `index`'s skill range.
local function RankRange(index)
    local low = index == 1 and 1 or RANK_CAPS[index - 1]
    return ("%d–%d"):format(low, RANK_CAPS[index])
end

-- The rank whose cap is `maxRank` (the character's current rank); nil without one.
local function RankIndex(maxRank)
    for index, cap in ipairs(RANK_CAPS) do
        if maxRank and maxRank <= cap then return index end
    end
end

-- The next rank to learn: the first without the profession, nil once the
-- character has the last.
local function NextRankIndex(maxRank)
    local index = RankIndex(maxRank)
    if not index then return 1 end
    return index < #RANK_CAPS and index + 1 or nil
end

-- The Skinning skill a beast of `level` needs: (level - 10) x 10 up to level
-- 20 (at least 1), then level x 5 (as the scraper reckons it).
local function SkinningSkill(level)
    if level <= 20 then return math.max(1, (level - 10) * 10) end
    return level * 5
end

-- A beast's four skill numbers: the skill it needs, then the Skinning steps past it.
local function BeastSkills(level)
    local skill = SkinningSkill(level)
    return { skill, skill + SKINNING_STEPS[1], skill + SKINNING_STEPS[2], skill + SKINNING_STEPS[3] }
end

-- A guide node's four skill numbers ({ item, needs, yellow, green, grey }).
local function NodeSkills(node)
    return { node[2], node[3], node[4], node[5] }
end

-- Whether the character's skill `rank` lies in band `band` of `bands`
-- (the last band holds its top skill too).
local function IsInBand(rank, band, bands)
    return (rank >= band.low and rank < band.high) or (band == bands[#bands] and rank == band.high)
end

-- The band of `bands` holding the character's skill `rank` (the first one
-- without the profession), by its place in the list.
local function PlayerBandIndex(bands, rank)
    for index, band in ipairs(bands) do
        if rank and IsInBand(rank, band, bands) then return index end
    end
    return 1
end

-- The zones of `band` the list shows, most nodes first: on a PvP realm the
-- side shown's own and the contested ones, on a PvE realm every one.
local function ShownZones(page, band)
    local zones = {}
    for _, zone in ipairs(band.zones) do
        if #zones == ZONES_SHOWN then break end
        if not page.isPvP or ServesSide(zone, page.shownSide) then table.insert(zones, zone) end
    end
    return zones
end

-- Links ---------------------------------------------------------------------------
-- Each link in the page's text points at page.links[target], set as its
-- text is written: { spot, name } for a map pin, plus what its tooltip
-- shows and what a click opens.

-- Where a link to guide NPC `entry` goes: their map pin, else (one standing
-- inside a dungeon, Data/ProfessionGuide.lua's insideSpot) their spot on
-- the dungeon's map; nil when neither is known.
local function NpcTarget(entry)
    local spot = ns.Data.npcs[entry.npc]
    if spot then return { kind = "npc", spot = spot, name = entry.name, npc = entry } end
    local dungeon = entry.inside and entry.insideSpot and ns.Data:Get(entry.inside)
    if dungeon then return { kind = "insideNpc", dungeon = dungeon, name = entry.name, npc = entry } end
end

-- `npc`'s name as a link (plain text when nowhere is known), after the
-- giver's mark when `isMarked` (inside the link, as quest pages mark NPCs),
-- then their zone (or dungeon) in muted when `withZone`.
local function NpcLink(page, npc, withZone, isMarked)
    local entry = page.guide.npcs[npc]
    if not entry then return "" end
    local target = NpcTarget(entry)
    page.links["npc:" .. npc] = target
    local name = (isMarked and Marker(ns.UI.GIVER_MARK) or "") .. entry.name
    name = target and Link("npc:" .. npc, name) or name
    local zone = withZone and ns.UI.SourceZone(entry)
    return zone and name .. Muted(Theme.DOTS .. zone) or name
end

-- A quest's giver: the dungeon's entrance when they stand inside one, else
-- the NPC with their zone.
local function GiverLink(page, quest)
    local dungeon = quest.inside and ns.Data:Get(quest.inside)
    local entrance = dungeon and ns.Data:Entrance(quest.inside)
    if not entrance then return quest.giver and NpcLink(page, quest.giver, true) or nil end
    local name = page.guide.npcs[quest.giver] and page.guide.npcs[quest.giver].name or dungeon.name
    page.links["inside:" .. quest.inside] = { kind = "inside", spot = entrance, name = dungeon.name }
    return Link("inside:" .. quest.inside, name) .. Muted(Theme.DOTS .. dungeon.name)
end

local function QuestName(page, questID)
    local quest = page.guide.quests[questID]
    return quest and quest.name or ns.Data.questNames[questID] or L["quest %s"]:format(questID)
end

-- Quest `questID`'s name as a link: its tooltip gives the level and what it
-- asks; a click opens NeedRoll's page for it, when there is one.
-- `alternatives`: the other quests that do as well (a chain step's).
local function QuestLink(page, questID, alternatives)
    local target = "quest:" .. questID
    page.links[target] = { kind = "quest", questID = questID, quest = page.guide.quests[questID],
        alternatives = alternatives }
    return Link(target, QuestName(page, questID), Theme.color.quest)
end

-- The recipe of this profession whose spell is `spellID`, as a link that
-- opens its page; its name in muted when the list hasn't it.
local function RecipeLink(page, spellID)
    for _, encounter in ipairs(page.instance.encounters) do
        if encounter.spellID == spellID then
            page.links["recipe:" .. spellID] = { kind = "recipe", encounter = encounter }
            return Link("recipe:" .. spellID, encounter.name)
        end
    end
    local name = C_Spell.GetSpellName(spellID)
    return name and Muted(name) or nil
end

-- An item link (its tooltip; Shift-click links it in chat), with the
-- item's icon before its name when `withIcon`.
local function ItemLink(page, itemID, withIcon)
    local icon = withIcon and C_Item.GetItemIconByID(itemID)
    local name = Colored(ItemName(page, itemID), Theme.color.text)
    return ("|Hitem:%d|h%s%s|h"):format(itemID, icon and ("|T%s:0|t "):format(icon) or "", name)
end

-- `zone` of `band` as a link that opens the game's map on it (its tooltip
-- gives its spawn count), named `text` (the zone's name unless given).
local function ZoneLink(page, band, zone, text)
    local target = ("zone:%d:%d"):format(band.low, zone.map)
    local name = ZoneName(zone.map)
    page.links[target] = { kind = "zone", name = name, zone = zone }
    return Link(target, text or name)
end

-- Tooltips ---------------------------------------------------------------------------

local function ShowNpcTooltip(data)
    GameTooltip:SetText(data.name)
    local zone = ns.UI.SourceZone(data.npc)
    if zone then GameTooltip:AddLine(zone) end
    GameTooltip:AddLine(L["Click to pin on your map"], unpack(Theme.tip.text))
end

local function ShowInsideNpcTooltip(data)
    GameTooltip:SetText(data.name)
    GameTooltip:AddLine(L["Inside %s"]:format(data.dungeon.name))
    GameTooltip:AddLine(L["Click to see where they stand on the map"], unpack(Theme.tip.text))
end

local function ShowInsideTooltip(data)
    GameTooltip:SetText(L["Inside %s"]:format(data.name))
    GameTooltip:AddLine(L["Click to pin the entrance on your map"], unpack(Theme.tip.text))
end

local function ShowQuestTooltip(page, data)
    local quest = data.quest or {}
    GameTooltip:SetText(QuestName(page, data.questID), unpack(Theme.color.quest))
    if quest.level then GameTooltip:AddLine(L["Level %d"]:format(quest.level), 1, 1, 1) end
    for _, need in ipairs(quest.needs or {}) do
        GameTooltip:AddLine(L["%d x %s"]:format(need[2], ItemName(page, need[1])), 1, 1, 1)
    end
    for _, other in ipairs(data.alternatives or {}) do
        GameTooltip:AddLine(L["Or: %s"]:format(QuestName(page, other)))
    end
    if ns.UI.QuestSource(data.questID) then
        GameTooltip:AddLine(L["Click to open this quest"], unpack(Theme.tip.text))
    end
end

local function ShowMoreTooltip(data)
    GameTooltip:SetText(L["Nearest first"])
    for _, trainer in ipairs(data.trainers) do
        GameTooltip:AddDoubleLine(trainer.name, ns.UI.SourceZone(trainer) or "", 1, 1, 1, unpack(Theme.tip.text))
    end
end

local function ShowZoneTooltip(data)
    GameTooltip:SetText(data.name)
    GameTooltip:AddLine(L["%d spawn points"]:format(data.zone.spots), 1, 1, 1)
    GameTooltip:AddLine(data.zone.side and L["Safe for the %s"]:format(ns.SideName(data.zone.side))
        or L["Contested"])
    GameTooltip:AddLine(L["Click to open the map"], unpack(Theme.tip.text))
end

-- A needroll: link's tooltip lines, by what it points at (`data`, its
-- page.links entry); PetPageKit.WireLinks shows the tooltip.
local function FillLinkTooltip(page, data)
    if data.kind == "npc" then
        ShowNpcTooltip(data)
    elseif data.kind == "insideNpc" then
        ShowInsideNpcTooltip(data)
    elseif data.kind == "inside" then
        ShowInsideTooltip(data)
    elseif data.kind == "quest" then
        ShowQuestTooltip(page, data)
    elseif data.kind == "more" then
        ShowMoreTooltip(data)
    elseif data.kind == "zone" then
        ShowZoneTooltip(data)
    elseif data.kind == "recipe" then
        GameTooltip:SetText(data.encounter.name)
        GameTooltip:AddLine(L["Click to open this recipe"], unpack(Theme.tip.text))
    elseif data.kind == "drop" then
        GameTooltip:SetText(data.source.name)
        GameTooltip:AddLine(data.source.inst.name, 1, 1, 1)
        GameTooltip:AddLine(L["Click to open its loot"], unpack(Theme.tip.text))
    elseif data.kind == "skillUps" then
        GameTooltip:SetText(L["Skill-ups now"])
        GameTooltip:AddLine(L["Click to list them"], unpack(Theme.tip.text))
    end
end

-- An NPC standing inside a dungeon: the Dungeons tab on that dungeon's
-- map, on their level with their spot lit; one Back returns here.
local function ShowInsideNpc(data)
    local ui = ns.UI
    ui:ShowInDungeon(data.dungeon, function() ui:ShowSpotOnMap(data.npc.insideSpot, data.name) end)
end

-- Ticks the recipe list's Skill-ups toggle; the list then picks its first
-- recipe (UI:RecipeNarrowed).
local function OpenSkillUps(page)
    ns.RecipeBand:State(page.instance).toggles.SKILLUP = true
    ns.UI:ClearHistory()
    ns.UI:RecipeNarrowed()
end

-- A click on a link that doesn't pin (PetPageKit.WireLinks pins the others
-- and links items in chat): a zone opens the game's map on it (refused in combat,
-- UI:OpenZoneMap); an NPC inside a dungeon, a quest NeedRoll has a page for,
-- a recipe (of any profession) or the boss that drops a blueprint, opens it
-- (Back returns here); the skill-ups opens the recipe list on them.
local function OnLinkClick(page, data)
    if data.kind == "zone" then
        ns.UI:OpenZoneMap(data.zone.map)
    elseif data.kind == "insideNpc" then
        ShowInsideNpc(data)
    elseif data.kind == "quest" then
        ns.UI.OpenItemSource(ns.UI.QuestSource(data.questID))
    elseif data.kind == "skillUps" then
        OpenSkillUps(page)
    elseif data.kind == "drop" then
        ns.UI.OpenItemSource(data.source, data.itemID)
    elseif data.encounter then
        ns.UI:SelectRecipe(data.profession or page.instance, data.encounter)
    end
end

-- The line under the heading -----------------------------------------------------

-- The recipes that give skill-ups at `rank` (orange, yellow or green, as
-- the list's Skill-ups toggle keeps them), and the first orange one: one
-- orange now, else the next to turn orange.
local function SkillUps(instance, rank)
    local count, orangeNow, nextOrange = 0, nil, nil
    for _, encounter in ipairs(instance.encounters) do
        local skill = encounter.spellID and encounter.skill
        if skill and skill[4] then
            if skill[1] <= rank and rank < skill[4] then count = count + 1 end
            if skill[1] <= rank and rank < skill[2] and not (orangeNow and orangeNow.skill[1] <= skill[1]) then
                orangeNow = encounter
            elseif skill[1] > rank and not (nextOrange and nextOrange.skill[1] <= skill[1]) then
                nextOrange = encounter
            end
        end
    end
    return count, orangeNow or nextOrange
end

-- "14 recipes give skill now  ·  next orange: Mithril Tube (195)", the
-- count a link that opens the recipe list with Skill-ups ticked.
local function RecipesNowText(page, rank)
    local count, orange = SkillUps(page.instance, rank)
    page.links.skillUps = { kind = "skillUps" }
    local countText = Theme:Plural(count, L["%d recipe gives skill now"], L["%d recipes give skill now"])
    return Theme:JoinDots(Link("skillUps", countText, Theme.color.muted),
        orange and L["next orange: %s (%d)"]:format(orange.name, orange.skill[1]))
end

-- "Iron Ore, Silver Ore and Tin Ore give skill now": the nodes that give
-- skill-ups at `rank`, hardest first in the game's node colours, each ore
-- once (two veins give Thorium Ore).
local function NodesNowText(page, rank)
    local names, named = {}, {}
    local nodes = page.profession.nodes
    for i = #nodes, 1, -1 do
        local node = nodes[i]
        local item = node[1]
        if node[2] <= rank and rank < node[5] and not named[item] and #names < NODES_NAMED then
            named[item] = true
            table.insert(names, Colored(ItemName(page, item), ns.UI.GatherColor(node[2], rank, NodeSkills(node))))
        end
    end
    if #names == 0 then return L["Nothing gives skill-ups"] end
    return (#names == 1 and L["%s gives skill now"] or L["%s give skill now"]):format(JoinAnd(names))
end

-- "Beasts level 18–29 give skill now": the beast levels that give skill-ups at `rank`.
local function BeastsNowText(rank)
    local lowest, highest
    for level = 1, MAX_BEAST_LEVEL do
        local skills = BeastSkills(level)
        if skills[1] <= rank and rank < skills[4] then lowest, highest = lowest or level, level end
    end
    if not lowest then return L["Nothing gives skill-ups"] end
    return L["Beasts level %d–%d give skill now"]:format(lowest, highest)
end

local function HasRecipes(instance)
    for _, encounter in ipairs(instance.encounters) do
        if encounter.spellID then return true end
    end
    return false
end

-- "Gathering profession  ·  Expert  ·  Iron Ore ... give skill now", "Primary
-- profession  ·  Expert  ·  14 recipes give skill now  ·  next orange: ...":
-- the profession's kind, the character's rank and what gives skill-ups now;
-- the kind and "Not learned" without the profession. The Camping list's
-- page says what it lists.
local function SubtitleText(page, rank, maxRank)
    local instance, profession = page.instance, page.profession
    if instance.camping then return L["What each profession builds at a campsite, yours first"] end
    local kind = profession.farm and L["Gathering profession"] or instance.zone
    if not rank then return Theme:JoinDots(kind, L["Not learned"]) end
    local index = RankIndex(maxRank)
    local now
    if profession.nodes then
        now = NodesNowText(page, rank)
    elseif profession.farm then
        now = BeastsNowText(rank)
    elseif HasRecipes(instance) then
        now = RecipesNowText(page, rank)
    end
    return Theme:JoinDots(kind, index and RANK_NAMES[index], now)
end

-- "Mining 140 / 225  ·  Level 33" at the strip's right; the level alone
-- without the profession.
local function SkillLineText(instance, rank, maxRank)
    return Theme:JoinDots(rank and ("%s %d / %d"):format(instance.name, rank, maxRank),
        L["Level %d"]:format(ns.PlayerLevel()))
end

-- The list: shared rows --------------------------------------------------------------

-- A section's heading with its note (PetPageKit.AddHeading: the divider
-- over every heading but the first), and which section it heads.
local function AddHeading(rows, text, note, section)
    PetPageKit.AddHeading(rows, text, note)
    rows[#rows].section = section
    return rows[#rows]
end

-- The open or shut state of fold `key` (FoldKeys), set on `entry`: open as
-- the player left it in page.openFolds, else as `isOpenAtFirst` says; and
-- that start, for the click that flips it (ToggleFold).
local function SetFoldState(entry, page, key, isOpenAtFirst)
    entry.isOpenAtFirst = isOpenAtFirst
    entry.isOpen = ns.SectionMemory.IsOpen(page.openFolds, key, isOpenAtFirst)
    return entry
end

-- A heading whose arrow opens and shuts its section: `fold` is its key in
-- page.openFolds, `isOpenAtFirst` how it starts. Returns whether the
-- section is open.
local function AddFoldHeading(rows, page, text, note, section, fold, isOpenAtFirst)
    local heading = AddHeading(rows, text, note, section)
    heading.fold = fold
    return SetFoldState(heading, page, fold, isOpenAtFirst).isOpen
end

local function AddNote(rows, text, indent)
    table.insert(rows, { kind = NOTE, height = CHILD_ROW, text = text, indent = indent })
end

-- A row under an opened row: `text`, and `right` at the right.
local function AddLine(rows, text, right)
    table.insert(rows, { kind = LINE, height = CHILD_ROW, text = text, right = right, indent = CHILD_INDENT })
end

-- The guide NPCs `npcs` (IDs) who serve the side shown, nearest first. Kept
-- per list and side while the profession shows (the player moves between
-- showings, ShowProfession starts over).
local function NearestServing(page, npcs)
    if not npcs then return {} end
    local side = page.shownSide
    page.nearest[npcs] = page.nearest[npcs] or {}
    local kept = page.nearest[npcs][side]
    if kept then return kept end
    local serving = {}
    for _, npc in ipairs(npcs) do
        local entry = page.guide.npcs[npc]
        if entry and ServesSide(entry, side) then table.insert(serving, entry) end
    end
    kept = ns.UI.NearestFirst(serving)
    page.nearest[npcs][side] = kept
    return kept
end

-- The nearest of `npcs` (already nearest first) a row each: the giver's
-- mark and their name as a link, their zone at the right ("the only
-- trainer  ·  Tanaris" when they are the only one), the first
-- TRAINERS_SHOWN, then "+4 more trainers" (`moreText`; hovering it lists
-- them all). `noneText` stands in when there are none.
local function AddNpcRows(rows, page, npcs, moreText, noneText)
    if #npcs == 0 then
        AddNote(rows, noneText, CHILD_INDENT)
        return
    end
    for i = 1, math.min(#npcs, TRAINERS_SHOWN) do
        local npc = npcs[i]
        local zone = ns.UI.SourceZone(npc)
        AddLine(rows, NpcLink(page, npc.npc, false, true),
            #npcs == 1 and Theme:JoinDots(L["the only trainer"], zone) or zone)
    end
    if #npcs <= TRAINERS_SHOWN then return end
    local target = "more:" .. npcs[1].npc .. ":" .. #npcs
    page.links[target] = { kind = "more", trainers = npcs }
    AddNote(rows, Link(target, moreText:format(#npcs - TRAINERS_SHOWN), Theme:Opaque(Theme.color.muted)),
        CHILD_INDENT)
end

local function AddTrainerRows(rows, page, npcs)
    AddNpcRows(rows, page, NearestServing(page, npcs), L["+%d more trainers"],
        L["No %s trainer"]:format(ns.SideName(page.shownSide)))
end

-- The list: where to mine, gather or skin ------------------------------------------

-- "skill 125–175  ·  Horde zones hidden  ·  most nodes first" (the skill
-- range only while one band shows).
local function FarmNote(page, band)
    local realmText = page.isPvP and L["%s zones hidden"]:format(ns.SideName(ns.OtherSide(page.shownSide)))
        or L["PvE realm: every zone"]
    return Theme:JoinDots(band and L["skill %d–%d"]:format(band.low, band.high), realmText, L["most nodes first"])
end

-- A zone's row: its name, its tag and its columns (SetupZone). `isLit`: the
-- busiest zone of the character's band.
local function ZoneEntry(page, band, zone, isLit)
    local tag
    if page.isPvP then
        tag = zone.side and Done(L["safe"]) or Colored(L["contested"], Theme.color.levelHard)
    end
    local key = FoldKeys.Zone(band, zone)
    return SetFoldState({ kind = ZONE, height = LINE_ROW, foldKey = key, isLit = isLit,
        text = ZoneLink(page, band, zone), tag = tag, levels = ZoneLevelsText(zone.map),
        side = zone.side and ns.SideName(zone.side) or L["Contested"],
        right = ZoneLink(page, band, zone, L["%d nodes"]:format(zone.spots)) }, page, key, page.openAtFirst[key])
end

-- An opened zone's nodes: each node's icon and item, "rich vein" after the
-- rich one, and its four skill numbers.
local function AddNodeRows(rows, page, zone)
    for _, index in ipairs(zone.nodes or {}) do
        local node = page.profession.nodes[index]
        local text = ItemLink(page, node[1], true)
        if node.rich then text = text .. "  " .. Muted(L["rich vein"]) end
        table.insert(rows, { kind = NODE, height = CHILD_ROW, indent = CHILD_INDENT, text = text,
            skills = NodeSkills(node) })
    end
end

-- An opened Skinning zone's beasts: a row per skill they need, "Level 24
-- beasts" (or "Level 1–10 beasts", the levels that need the same skill),
-- with the four skill numbers.
local function AddBeastRows(rows, zone)
    local levels = zone.levels or {}
    local first = 1
    for i = 1, #levels do
        local level = levels[i]
        if i == #levels or SkinningSkill(levels[i + 1]) ~= SkinningSkill(level) then
            local lowest = levels[first]
            local text = lowest == level and L["Level %d beasts"]:format(level)
                or L["Level %d–%d beasts"]:format(lowest, level)
            table.insert(rows, { kind = NODE, height = CHILD_ROW, indent = CHILD_INDENT, text = text,
                skills = BeastSkills(level) })
            first = i + 1
        end
    end
end

-- A band's zones, each with its nodes under it while open; `isPlayerBand`
-- lights its busiest zone.
local function AddZoneRows(rows, page, band, isPlayerBand)
    for i, zone in ipairs(ShownZones(page, band)) do
        local entry = ZoneEntry(page, band, zone, isPlayerBand and i == 1)
        table.insert(rows, entry)
        if entry.isOpen then
            if page.profession.nodes then
                AddNodeRows(rows, page, zone)
            else
                AddBeastRows(rows, zone)
            end
        end
    end
end

-- Where to mine (gather, skin): the band holding the character's skill, or
-- with All ranges each band's range then its zones.
local function AddFarmRows(rows, page, rank)
    local farm = page.profession.farm
    if not farm then return end
    local playerBand = PlayerBandIndex(farm, rank)
    local showsAll = page.bandFilter == ALL_BANDS
    AddHeading(rows, FARM_HEADINGS[page.instance.id], FarmNote(page, not showsAll and farm[playerBand] or nil), FARM)
    for index, band in ipairs(farm) do
        local isPlayerBand = index == playerBand
        if showsAll then
            table.insert(rows, { kind = BAND, height = LINE_ROW, isPlayerBand = isPlayerBand,
                text = L["Skill %d–%d"]:format(band.low, band.high) })
        end
        if showsAll or isPlayerBand then AddZoneRows(rows, page, band, isPlayerBand) end
    end
end

-- The list: where to learn ---------------------------------------------------------

-- The quest of `quests` the side shown takes; nil when none.
local function QuestForSide(page, quests)
    for _, questID in ipairs(quests or {}) do
        local quest = page.guide.quests[questID]
        if quest and ServesSide(quest, page.shownSide) then return questID, quest end
    end
end

-- "From Dirge Quikcleave: 12 Giant Egg, 10 Zesty Clam Meat", or "From X,
-- ends at Y" when someone else takes it in.
local function QuestSourceText(page, quest)
    local giver = GiverLink(page, quest)
    if not giver then return nil end
    local text = L["From %s"]:format(giver)
    if quest.turnIn and quest.turnIn ~= quest.giver then
        text = L["From %s, ends at %s"]:format(giver, NpcLink(page, quest.turnIn))
    end
    if not quest.needs then return text end
    local needs = {}
    for _, need in ipairs(quest.needs) do
        table.insert(needs, L["%d x %s"]:format(need[2], ItemName(page, need[1])))
    end
    return L["%s: %s"]:format(text, table.concat(needs, ", "))
end

-- What a rank's row says at the right: its range, then "Learned" once the
-- character has it, else from what skill and level, and its cost (or that
-- a book or a quest gives it): "225–300  ·  at 200  ·  Level 35  ·  5g".
local function RankRightText(rank, index, skill, isLearned)
    if isLearned then return Theme:JoinDots(RankRange(index), L["Learned"]) end
    local needed = index > 1 and RANK_CAPS[index - 1] - NEXT_RANK_EARLY
    local source = rank.quests and L["a quest"] or rank.book and L["A book, not a trainer"]
        or rank.cost and ns.Money(rank.cost)
    return Theme:JoinDots(RankRange(index), needed and (skill or 0) < needed and L["at %d"]:format(needed),
        rank.level and L["Level %d"]:format(rank.level), source)
end

-- An opened rank a quest gives: the side shown's quest, "· Completed" once
-- done, then who gives it and what it asks, and the quest leading there.
local function AddQuestRankRows(rows, page, rank)
    local questID, quest = QuestForSide(page, rank.quests)
    if not questID then
        AddNote(rows, L["No quest for the %s"]:format(ns.SideName(page.shownSide)), CHILD_INDENT)
        return
    end
    AddLine(rows, Theme:JoinDots(QuestLink(page, questID), IsQuestDone(questID) and Done(L["Completed"])))
    local source = QuestSourceText(page, quest)
    if source then AddNote(rows, source, CHILD_INDENT) end
    local breadcrumb = QuestForSide(page, rank.breadcrumbs)
    if breadcrumb then AddNote(rows, L["Led there by %s"]:format(QuestLink(page, breadcrumb)), CHILD_INDENT) end
end

-- An opened rank a book teaches: the book, "· Learned" once the character
-- has the rank, its price at the right, then its nearest vendors.
local function AddBookRankRows(rows, page, rank, isLearned)
    AddLine(rows, Theme:JoinDots(ItemLink(page, rank.book, true), isLearned and Done(L["Learned"])),
        rank.cost and ns.Money(rank.cost))
    AddNpcRows(rows, page, NearestServing(page, rank.vendors), L["+%d more vendors"], L["no vendor"])
end

-- A rank's row and, while it is open, what gives it under it. `isLit`: the
-- next rank to learn.
local function AddRankRows(rows, page, index, skill, maxRank)
    local rank = page.profession.ranks[index]
    local isLearned = maxRank ~= nil and maxRank >= RANK_CAPS[index]
    local key = FoldKeys.Rank(index)
    local entry = SetFoldState({ kind = RANK, height = LINE_ROW, foldKey = key, text = RANK_NAMES[index],
        right = RankRightText(rank, index, skill, isLearned), isLit = index == NextRankIndex(maxRank) },
        page, key, page.openAtFirst[key])
    table.insert(rows, entry)
    if not entry.isOpen then return end
    if rank.quests then
        AddQuestRankRows(rows, page, rank)
    elseif rank.book then
        AddBookRankRows(rows, page, rank, isLearned)
    else
        AddTrainerRows(rows, page, rank.trainers)
    end
end

local function AddLearnRows(rows, page, skill, maxRank)
    AddHeading(rows, L["Where to learn"], Theme:JoinDots(ns.SideName(page.shownSide), L["nearest first"]), LEARN)
    for index in ipairs(page.profession.ranks) do AddRankRows(rows, page, index, skill, maxRank) end
end

-- The list: specializations ------------------------------------------------------

-- Whether any quest of the chain's last step is done.
local function IsChainDone(steps)
    for _, questID in ipairs(steps[#steps] or {}) do
        if IsQuestDone(questID) then return true end
    end
    return false
end

-- An opened specialization's chain, step by step: "1. Gnome Engineering"
-- (the step's other quests in its tooltip), "· Completed" once done, and
-- its giver at the right.
local function AddChainRows(rows, page, steps)
    for number, step in ipairs(steps) do
        local questID = step[1]
        local quest = page.guide.quests[questID]
        local name = QuestLink(page, questID, { unpack(step, 2) })
        AddLine(rows, Theme:JoinDots(("%d.  %s"):format(number, name), IsQuestDone(questID) and Done(L["Completed"])),
            quest and GiverLink(page, quest))
    end
end

-- A specialization's row ("Chosen" at the right once known) and, while it
-- is open, its chain, then its trainers once the chain is done or it is
-- chosen, else a note that they show then.
local function AddSpecRows(rows, page, spec)
    local steps = spec[page.shownSide] or {}
    local isChosen = C_SpellBook.IsSpellKnown(spec.spell)
    local key = FoldKeys.Spec(spec)
    local entry = SetFoldState({ kind = SPEC, height = LINE_ROW, foldKey = key,
        text = Marker(QUEST_MARK) .. Colored(spec.name, Theme.color.quest),
        right = Theme:JoinDots(Theme:Plural(#steps, L["%d quest"], L["%d quests"]), L["Level %d"]:format(spec.level),
            ("%s %d"):format(page.instance.name, spec.skill), isChosen and Done(L["Chosen"])) }, page, key, false)
    table.insert(rows, entry)
    if not entry.isOpen or #steps == 0 then return end
    AddChainRows(rows, page, steps)
    if IsChainDone(steps) or isChosen then
        AddTrainerRows(rows, page, spec.trainers)
        return
    end
    AddNote(rows, L["%s trainers show here once %s is done."]:format(spec.name, QuestName(page, steps[#steps][1])),
        CHILD_INDENT)
end

local function AddSpecializationRows(rows, page)
    local specs = page.profession.specs
    if not specs then return end
    AddHeading(rows, L["Specialization"], Theme:JoinDots(("%s %d"):format(page.instance.name, specs[1].skill),
        L["Level %d"]:format(specs[1].level), L["pick one"]), SPECS)
    for _, spec in ipairs(specs) do AddSpecRows(rows, page, spec) end
end

-- The list: quests -------------------------------------------------------------------

-- A quest's need at the right: the profession skill it needs ("Mining
-- 230"), else its level.
local function QuestNeedText(page, quest)
    return quest.skill and ("%s %d"):format(page.instance.name, quest.skill)
        or quest.level and L["Level %d"]:format(quest.level) or nil
end

-- A quest row: `text`, the second line `sub` under it (if any), `right` at the right.
local function QuestRow(text, sub, right)
    return { kind = QUEST, height = sub and TWO_LINE_ROW or LINE_ROW, text = text, sub = sub, right = right }
end

-- A quest of the Quests section: its name, "· Completed" once done, its
-- zone and the recipe it teaches, at the right the skill (else level) it
-- needs, and under it who gives it and what it asks. Also whether it is done.
local function QuestEntry(page, questID, quest)
    local isDone = IsQuestDone(questID)
    local giver = quest.giver and page.guide.npcs[quest.giver]
    local zone = quest.inside and ns.Data:Get(quest.inside) and ns.Data:Get(quest.inside).name
        or giver and ns.UI.SourceZone(giver)
    local teaches = quest.teaches and RecipeLink(page, quest.teaches)
    local text = Theme:JoinDots(QuestLink(page, questID), isDone and Done(L["Completed"]), zone and Muted(zone),
        teaches and Muted(L["teaches %s"]:format(teaches)))
    return QuestRow(text, QuestSourceText(page, quest), QuestNeedText(page, quest)), isDone
end

-- A quest group (gates.json's questGroups: the same quest from several
-- givers, for one purpose) as one line: "Membership Card Renewal  ·
-- Gnomish Engineering", "· Completed" once any is done, and under it the
-- givers of the side shown, nearest first, each with their zone. Also
-- whether it is done; nil when no quest of the group serves the side shown.
local function QuestGroupEntry(page, group)
    local questIDs, givers, isDone = {}, {}, false
    for _, questID in ipairs(group) do
        local quest = page.guide.quests[questID]
        if quest and ServesSide(quest, page.shownSide) then
            table.insert(questIDs, questID)
            isDone = isDone or IsQuestDone(questID)
            if page.guide.npcs[quest.giver] then table.insert(givers, page.guide.npcs[quest.giver]) end
        end
    end
    if #questIDs == 0 then return nil end
    local text = Theme:JoinDots(QuestLink(page, questIDs[1]), Muted(group.label), isDone and Done(L["Completed"]))
    local giverLinks = {}
    for _, giver in ipairs(ns.UI.NearestFirst(givers)) do
        table.insert(giverLinks, NpcLink(page, giver.npc, true))
    end
    local sub = #giverLinks > 0 and L["From %s"]:format(JoinOr(giverLinks)) or nil
    return QuestRow(text, sub, QuestNeedText(page, page.guide.quests[questIDs[1]])), isDone
end

-- A listed quest's line, and whether it is done: nil when the side shown
-- can't take it.
local function QuestListEntry(page, listed)
    if type(listed) == "table" then return QuestGroupEntry(page, listed) end
    local quest = page.guide.quests[listed]
    if not (quest and ServesSide(quest, page.shownSide)) then return nil end
    return QuestEntry(page, listed, quest)
end

-- The Quests section: its heading, with "Alliance Cooking quests  ·  2 of 5
-- done", opens and shuts it; it starts shut.
local function AddQuestRows(rows, page)
    local entries, done = {}, 0
    for _, listed in ipairs(page.profession.quests) do
        local entry, isDone = QuestListEntry(page, listed)
        if entry then
            table.insert(entries, entry)
            if isDone then done = done + 1 end
        end
    end
    if #entries == 0 then return end
    local note = Theme:JoinDots(L["%s %s quests"]:format(ns.SideName(page.shownSide), page.instance.name),
        L["%d of %d done"]:format(done, #entries))
    if not AddFoldHeading(rows, page, L["Quests"], note, QUESTS, QUESTS, false) then return end
    for _, entry in ipairs(entries) do table.insert(rows, entry) end
end

-- The list: camp features -------------------------------------------------------------

-- The number `scale` (a camp feature's: { [from level] = number }) gives a
-- character of `level`: the one from the highest level at or under it.
local function ScaledNumber(scale, level)
    local fromLevel, number = 0, nil
    for from, value in pairs(scale) do
        if from <= level and from > fromLevel then fromLevel, number = from, value end
    end
    return number
end

-- What camp feature `feature` does, its number for the character's level,
-- then what the feature it can be placed over does too: "grows a mining
-- node, +90 Attack Power".
local function CampEffectText(feature)
    local effect = feature.effect
    if feature.scale then effect = effect:format(ScaledNumber(feature.scale, ns.PlayerLevel())) end
    local added = feature.adds and ns.Data.camping.byItem[feature.adds]
    return added and ("%s, %s"):format(effect, CampEffectText(added)) or effect
end

-- The item that places camp feature `feature` for the character's side (the
-- Faction Banner is a different item for each side).
local function CampItem(feature)
    return ns.PlayerFaction() == "Alliance" and feature.allianceItem or feature.item
end

-- `text` as a link that opens the recipe making camp feature `feature`,
-- in its own profession's list; muted when no list has it (Skinning's
-- features: Skinning has no recipes).
local function CampRecipeLink(page, feature, text)
    local profession, encounter = ns.Data:RecipeFor(CampItem(feature))
    if not encounter then return Muted(text) end
    local target = "recipe:" .. encounter.spellID
    page.links[target] = { kind = "recipe", encounter = encounter, profession = profession }
    return Link(target, text)
end

-- The bosses whose loot lists `itemID` (a blueprint), each "Gilnid, The
-- Deadmines" as a link that opens their loot.
local function DropLinks(page, itemID)
    local links = {}
    for _, source in ipairs(ns.Wishlist:Sources(itemID)) do
        if source.kind == "Drop" then
            local target = ("drop:%d:%d"):format(itemID, #links + 1)
            page.links[target] = { kind = "drop", source = source, itemID = itemID }
            table.insert(links, Link(target, ("%s, %s"):format(source.name, source.inst.name)))
        end
    end
    return links
end

-- Where camp feature `feature`'s recipe comes from, under its name:
-- trainers, or its blueprint (an item link) and the bosses that drop it,
-- kept short to fit the line: "Blueprint: Anvil  ·  Gilnid, The Deadmines".
local function CampSourceText(page, feature)
    if not feature.blueprint then return L["Taught by trainers"] end
    local drops = DropLinks(page, feature.blueprint)
    local where = #drops > 0 and JoinOr(drops) or Muted(L["where it comes from isn't known yet"])
    return Theme:JoinDots(ItemLink(page, feature.blueprint), where)
end

-- A camp feature's row: its item (icon and name, a link) and what it does,
-- where its recipe comes from under it, and `right` at the right. `isLit`:
-- one of the character's professions makes it (the Camping list's page).
local function CampEntry(page, feature, right, isLit)
    local text = ("%s%s"):format(ItemLink(page, CampItem(feature), true), Colored(": " .. CampEffectText(feature),
        Theme.color.text))
    return { kind = CAMP, height = TWO_LINE_ROW, text = text, sub = CampSourceText(page, feature), right = right,
        isLit = isLit }
end

-- A profession's Camping section, which opens and shuts (it starts open):
-- each feature it builds, lowest skill first, the skill it needs at the
-- right (a link to the recipe).
local function AddCampRows(rows, page)
    local features = ns.Data:CampFeatures(page.instance.id)
    if #features == 0 then return end
    local note = Theme:Plural(#features, L["%d camp feature"], L["%d camp features"])
    if not AddFoldHeading(rows, page, L["Camping"], note, CAMPING, CAMPING, true) then return end
    for _, feature in ipairs(features) do
        local skillLink = CampRecipeLink(page, feature, L["Skill %d"]:format(feature.skill))
        table.insert(rows, CampEntry(page, feature, skillLink))
    end
end

-- Whether the character has learned profession `professionID`.
local function KnowsProfession(professionID)
    local profession = ns.Data:Get(professionID)
    return profession ~= nil and ns.UI.SkillRanks(profession) ~= nil
end

-- Every camp feature by the rank its skill falls in (RANK_NAMES' index),
-- each as { feature, isOwn (one of the character's professions makes it),
-- name }, the character's first, then each part by name.
local function CampsByRank(page)
    local byRank = {}
    for _, feature in ipairs(ns.Data.camping.features) do
        local index = RankIndex(feature.skill)
        byRank[index] = byRank[index] or {}
        table.insert(byRank[index], { feature = feature, isOwn = KnowsProfession(feature.profession),
            name = ItemName(page, CampItem(feature)) })
    end
    for _, camps in pairs(byRank) do
        table.sort(camps, function(a, b)
            if a.isOwn ~= b.isOwn then return a.isOwn end
            return a.name < b.name
        end)
    end
    return byRank
end

-- A rank's section on the Camping list's page, which opens and shuts (it
-- starts open): its name and the skill range after it, then its features
-- `camps` (CampsByRank), the character's lit. At the right the profession
-- and the skill it needs, "Mining (20)", a link to the recipe.
local function AddCampRankRows(rows, page, index, camps)
    local fold = CAMPING .. index
    if not AddFoldHeading(rows, page, RANK_NAMES[index], RankRange(index), CAMPING, fold, true) then return end
    for _, camp in ipairs(camps) do
        local feature = camp.feature
        local right = ("%s (%d)"):format(ns.Data:Get(feature.profession).name, feature.skill)
        table.insert(rows, CampEntry(page, feature, CampRecipeLink(page, feature, right), camp.isOwn))
    end
end

-- The Camping list's page: a section per rank that has features.
local function CampingPageRows(page)
    local rows = {}
    local byRank = CampsByRank(page)
    for index = 1, #RANK_NAMES do
        if byRank[index] then AddCampRankRows(rows, page, index, byRank[index]) end
    end
    return rows
end

-- The list's rows: the profession's camp features first, then a gathering
-- profession shows where to farm. The Camping list has its own page.
local function ListRows(page, rank, maxRank)
    if page.instance.camping then return CampingPageRows(page) end
    local rows = {}
    AddCampRows(rows, page)
    AddFarmRows(rows, page, rank)
    AddLearnRows(rows, page, rank, maxRank)
    AddSpecializationRows(rows, page)
    AddQuestRows(rows, page)
    return rows
end

-- The rows that start open as a profession shows, by their FoldKeys: the
-- next rank to learn, and the busiest zone of the band holding the
-- character's skill. None on the Camping list's page, which has no guide.
local function OpenAtFirst(page, rank, maxRank)
    local open = {}
    if not page.profession then return open end
    local nextIndex = NextRankIndex(maxRank)
    if nextIndex then open[FoldKeys.Rank(nextIndex)] = true end
    local farm = page.profession.farm
    local playerBand = farm and farm[PlayerBandIndex(farm, rank)]
    local busiest = playerBand and ShownZones(page, playerBand)[1]
    if busiest then open[FoldKeys.Zone(playerBand, busiest)] = true end
    return open
end

-- Opens fold `key` (a section's heading or a rank's, zone's or
-- specialization's row) when shut, shuts it when open, remembered.
local function ToggleFold(page, key, isOpenAtFirst)
    ns.SectionMemory.Toggle(page.openFolds, key, isOpenAtFirst)
    page:Refresh()
end

-- The list's rows, drawn ---------------------------------------------------------------

-- A click on a rank, zone or specialization opens or shuts it; one on a
-- link went to the link (OnHyperlinkClick) and does nothing more here.
local function OnRowClick(row, page)
    local entry = row.data
    if row.overLink or not (entry and entry.foldKey) then return end
    GameTooltip:Hide()
    ToggleFold(page, entry.foldKey, entry.isOpenAtFirst)
end

-- A heading's button that opens and shuts its section (the heading's
-- `fold`), its arrow before the title as the raid Overview's Attunement
-- heading's (Theme:Arrow); SetupHeading sizes it over the arrow and the title.
local function CreateFoldButton(row, page)
    local fold = CreateFrame("Button", nil, row)
    fold.arrow = Theme:Arrow(fold)
    fold.arrow:SetPoint("LEFT", 0, 0)
    fold:SetScript("OnClick", function()
        ToggleFold(page, row.data.fold, row.data.isOpenAtFirst)
    end)
    fold:Hide()
    return fold
end

-- A zone's columns, right to left: its node count (the row's right text), side
-- and levels.
local function CreateZoneColumns(row)
    row.side = RowText(row, Theme.font.body, Theme.color.muted)
    row.side:SetPoint("RIGHT", -(RIGHT_INSET + NODES_COLUMN + COLUMN_GAP), 0)
    row.side:SetWidth(SIDE_COLUMN)
    row.levels = RowText(row, Theme.font.body)
    row.levels:SetPoint("RIGHT", row.side, "LEFT", -COLUMN_GAP, 0)
    row.levels:SetWidth(LEVELS_COLUMN)
end

-- A node's four skill numbers, each right-aligned in its column, the last
-- at the row's right.
local function CreateSkillColumns(row)
    row.skills = {}
    for i = #SKILL_COLORS, 1, -1 do
        local number = RowText(row, Theme.font.body, Theme.color[SKILL_COLORS[i]])
        number:SetJustifyH("RIGHT")
        number:SetWidth(SKILL_COLUMN)
        if i == #SKILL_COLORS then
            number:SetPoint("RIGHT", -RIGHT_INSET, 0)
        else
            number:SetPoint("RIGHT", row.skills[i + 1], "LEFT", 0, 0)
        end
        row.skills[i] = number
    end
end

-- A row of the list: the pet page's row (PetPageKit.CreateListRow: its
-- text, a heading's note and divider, the right column, the open arrow),
-- with the light behind the row lit for the character, a zone's tag and
-- columns, a node's skill numbers, a quest's second line and the Quests
-- heading's fold button. Its texts' links show their tooltips and pin or
-- open what they name; a click on the row opens or shuts it.
local function CreateRow(column, page)
    local row = PetPageKit.CreateListRow(column)
    row.light = row:CreateTexture(nil, "BACKGROUND")
    row.light:SetAllPoints()
    row.light:SetColorTexture(unpack(Theme.color.hover))
    row.tag = RowText(row, Theme.font.small)
    row.sub = RowText(row, Theme.font.small, Theme.color.muted)
    row.sub:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -SUB_GAP)
    row.sub:SetPoint("RIGHT", row.text, "RIGHT")
    CreateZoneColumns(row)
    CreateSkillColumns(row)
    row.fold = CreateFoldButton(row, page)
    PetPageKit.WireLinks(row, page)
    -- Only a row that opens is lit under the mouse: the others' links are what clicks.
    row:SetScript("OnEnter", function(self) self.hover:SetShown(self.data and self.data.foldKey ~= nil) end)
    row:SetScript("OnLeave", function(self) self.hover:Hide() end)
    row:SetScript("OnClick", function(self) OnRowClick(self, page) end)
    row:HookScript("OnHide", function(self) self.overLink = nil end)
    return row
end

-- Empties and hides what only some kinds of row show, for SetupRow to show its kind's.
local function ClearRow(row, entry)
    for _, text in ipairs({ row.note, row.right, row.tag, row.sub, row.side, row.levels, unpack(row.skills) }) do
        text:SetText("")
    end
    row.divider:SetShown(entry.hasDivider == true)
    row.light:SetShown(entry.isLit == true)
    row.fold:Hide()
    row.right:SetFontObject(Theme.font.small)
    Theme:SetTextColor(row.right, Theme.color.muted)
    row:EnableMouse(entry.kind ~= HEADING and entry.kind ~= BAND)
    ClassSpells.ShowRankParts(row, nil)
    ClassSpells.PlaceOpenArrow(row, row.text, nil)
end

-- Places the row's text as the pet page's rows place theirs
-- (PetPageKit.PlaceRowText), moved in by the entry's indent.
local function PlaceText(row, entry, font, color, rightOf, lift)
    PetPageKit.PlaceRowText(row, font, color, rightOf, lift)
    if entry.indent then row.text:SetPoint("LEFT", HEADING_LEFT + entry.indent, lift or 0) end
    row.text:SetText(entry.text)
end

-- A section heading: its title and the note after it. A section that opens
-- and shuts has an arrow before the title, the two one button.
local function SetupHeading(row, entry)
    PlaceText(row, entry, Theme.font.section, Theme.color.heading)
    row.note:SetText(entry.note or "")
    if not entry.fold then return end
    row.text:SetPoint("LEFT", HEADING_LEFT + FOLD_ARROW_ROOM, 0)
    row.fold:ClearAllPoints()
    row.fold:SetPoint("LEFT", HEADING_LEFT, 0)
    row.fold:SetSize(FOLD_ARROW_ROOM + row.text:GetStringWidth(), Theme:LineHeight(row.text) + 4)
    row.fold.arrow:SetOpen(entry.isOpen)
    row.fold:Show()
end

-- A zone: its name (a link), the safe or contested tag after it and the
-- open arrow after that; its levels, side and node count at the right.
local function SetupZone(row, entry)
    PlaceText(row, entry, Theme.font.body, Theme.color.text)
    row.tag:ClearAllPoints()
    row.tag:SetPoint("LEFT", row.text, "RIGHT", TAG_GAP, 0)
    row.tag:SetText(entry.tag or "")
    row.levels:SetText(entry.levels or "")
    row.side:SetText(entry.side)
    row.right:SetFontObject(Theme.font.body)
    row.right:SetText(entry.right)
    ClassSpells.PlaceOpenArrow(row, entry.tag and row.tag or row.text, entry.isOpen)
end

-- A node or beast level under an opened zone, and its four skill numbers.
local function SetupNode(row, entry)
    PlaceText(row, entry, Theme.font.body, Theme.color.text, row.skills[1])
    for i, number in ipairs(row.skills) do number:SetText(entry.skills[i]) end
end

-- A quest of the Quests section or a camp feature: its name, lifted over
-- its second line when it has one.
local function SetupQuest(row, entry)
    row.right:SetText(entry.right or "")
    PlaceText(row, entry, Theme.font.body, Theme.color.text, row.right, entry.sub and TEXT_LIFT)
    row.sub:SetText(entry.sub or "")
end

-- A rank, a specialization, a band's range, or a line or note under an
-- opened row: its text, what it says at the right, and a rank's or
-- specialization's open arrow.
local function SetupLine(row, entry)
    local kind = entry.kind
    local font, color = Theme.font.body, Theme.color.text
    if kind == NOTE then
        font, color = Theme.font.small, Theme.color.muted
    elseif kind == BAND then
        font, color = Theme.font.small, entry.isPlayerBand and Theme.color.heading or Theme.color.muted
    end
    row.right:SetText(entry.right or "")
    PlaceText(row, entry, font, color, row.right)
    if entry.foldKey then ClassSpells.PlaceOpenArrow(row, row.text, entry.isOpen) end
end

local function SetupRow(row, entry)
    ClearRow(row, entry)
    local kind = entry.kind
    if kind == HEADING then
        SetupHeading(row, entry)
    elseif kind == ZONE then
        SetupZone(row, entry)
    elseif kind == NODE then
        SetupNode(row, entry)
    elseif kind == QUEST or kind == CAMP then
        SetupQuest(row, entry)
    else
        SetupLine(row, entry)
    end
end

-- The page ----------------------------------------------------------------------------

-- The strip's parts: the chips (a gathering profession's: Near my skill and
-- All ranges, each with how many zones it lists, the picked one filled, as
-- the pet page's), and at the right the skill line and the faction toggle.
local function CreateStripParts(page)
    page.chips = {}
    for i, filter in ipairs(BAND_FILTERS) do
        local chip = Theme:Pill(page)
        chip.filter = filter
        chip:SetScript("OnClick", function(self)
            page.bandFilter = self.filter
            page:Refresh()
        end)
        page.chips[i] = chip
    end
    page.skillLine = Theme:Text(page, Theme.font.body)
    Theme:SetTextColor(page.skillLine, Theme.color.muted)
    page.toggle = Theme:FactionToggle(page, function(side)
        page.shownSide = side
        page:Refresh()
    end)
end

-- The page. `parent` is the window's body; MainFrame.lua hosts it in the
-- content pane, over the loot grid, its strip parts in the pane's strip.
function ns.UI.CreateProfessionOverview(parent)
    local page = PetPageKit.CreatePage(parent, CreateRow, SetupRow)
    CreateStripParts(page)
    page.links = {}
    page.fillLinkTooltip, page.onLinkClick = FillLinkTooltip, OnLinkClick
    page.nearest = {}
    page.itemsAsked = {}       -- items asked of the game, by ID (ItemName)
    page.bandFilter = NEAR_SKILL
    -- The line under the heading holds the skill-ups link (RecipesNowText).
    PetPageKit.WireLinks(page, page)
    -- The rows that start open (page.openAtFirst) are worked out again each
    -- time the page opens: the next rank may have changed since.
    page:HookScript("OnHide", function(self) self.foldsOpenedFor = nil end)
    -- The profession shown takes its folds from the set the setting now picks.
    ns.SectionMemory.OnModeChange(function()
        if not page.instance then return end
        page.openFolds = ns.SectionMemory.Area("professions", page.instance.id)
        if page:IsVisible() then page:Refresh() end
    end)

    function page:PlaceStrip(strip)
        for _, chip in ipairs(self.chips) do chip:SetParent(strip) end
        self:FollowBack(nil)
        for i = 2, #self.chips do self.chips[i]:SetPoint("LEFT", self.chips[i - 1], "RIGHT", CHIP_GAP, 0) end
        self.toggle:SetParent(strip)
        self.toggle:SetPoint("RIGHT", -STRIP_INSET, 0)
        self.skillLine:SetParent(strip)
        self:ShowToggle(true)
    end

    -- The faction toggle at the strip's right with the skill line left of
    -- it, or (`isShown` false: the Camping list's page, where sides don't
    -- matter) the skill line alone at the right.
    function page:ShowToggle(isShown)
        self.toggle:SetShown(isShown)
        self.skillLine:ClearAllPoints()
        if isShown then
            self.skillLine:SetPoint("RIGHT", self.toggle, "LEFT", -TOGGLE_GAP, 0)
        else
            self.skillLine:SetPoint("RIGHT", self.toggle:GetParent(), "RIGHT", -STRIP_INSET, 0)
        end
    end

    -- The chips start after Back while it shows (MainFrame.lua's strip).
    function page:FollowBack(back)
        local first = self.chips[1]
        first:ClearAllPoints()
        if back then
            first:SetPoint("LEFT", back, "RIGHT", CHIP_GAP, 0)
        else
            first:SetPoint("LEFT", STRIP_INSET, 0)
        end
    end

    -- The chips' labels with how many zones each lists, the picked one
    -- filled; hidden on a profession with nothing to farm (and on the
    -- Camping list's page, which has no guide).
    function page:UpdateChips(rank)
        local farm = self.profession and self.profession.farm
        for _, chip in ipairs(self.chips) do chip:SetShown(farm ~= nil) end
        if not farm then return end
        local nearCount, allCount = #ShownZones(self, farm[PlayerBandIndex(farm, rank)]), 0
        for _, band in ipairs(farm) do allCount = allCount + #ShownZones(self, band) end
        local counts = { [NEAR_SKILL] = nearCount, [ALL_BANDS] = allCount }
        for _, chip in ipairs(self.chips) do
            chip:SetLabel(("%s  %d"):format(CHIP_LABELS[chip.filter], counts[chip.filter]))
            chip:SetTone(chip.filter == self.bandFilter and Theme.color.heading or nil)
        end
    end

    -- Redraws the profession shown for the character as they are now,
    -- keeping the list's scroll while the profession stays.
    function page:Refresh()
        local instance = self.instance
        if not instance then return end
        local rank, maxRank = ns.UI.SkillRanks(instance)
        self.isPvP = ns.IsPvPRealm()
        wipe(self.links)
        self:SetHeading(instance.name, SubtitleText(self, rank, maxRank), ns.UI.ProfessionIcon(instance.id))
        self.skillLine:SetText(SkillLineText(instance, rank, maxRank))
        self:ShowToggle(not instance.camping)
        self.toggle:SetSide(self.shownSide)
        self:UpdateChips(rank)
        self.column:SetData(ListRows(self, rank, maxRank), instance == self.shownInstance)
        self.shownInstance = instance
    end

    -- Shows profession `instance` (a profession list with a guide, or the
    -- Camping list, which has none), from the character's own side, its
    -- folds as the player left them (Settings' "Remember sections",
    -- ns.SectionMemory's "professions" area, by the profession's ID).
    -- Trainers are put nearest first anew each time, as the player moves
    -- between showings.
    function page:ShowProfession(instance)
        if instance ~= self.instance then self.shownSide = ns.PlayerFaction() end
        self.instance = instance
        self.openFolds = ns.SectionMemory.Area("professions", instance.id)
        self.profession = ns.Data:ProfessionGuide(instance.id)
        self.guide = ns.Data.professionGuide
        wipe(self.nearest)
        if self.foldsOpenedFor ~= instance then
            local rank, maxRank = ns.UI.SkillRanks(instance)
            self.isPvP = ns.IsPvPRealm()
            self.openAtFirst = OpenAtFirst(self, rank, maxRank)
            self.foldsOpenedFor = instance
        end
        self:Refresh()
    end

    -- A quest done, a skill-up, a rank or specialization learned, War Mode
    -- changed or an item's name arrived: redrawn once for a burst of them,
    -- while it shows.
    PetPageKit.AddRefreshSoon(page)
    for _, event in ipairs({ "QUEST_LOG_UPDATE", "SKILL_LINES_CHANGED", "SPELLS_CHANGED", "PLAYER_LEVEL_UP",
        "WAR_MODE_STATUS_UPDATE" }) do
        ns:On(event, function() page:RefreshSoon() end)
    end
    return page
end
