-- The Library Books page: the Library tab, across the window's whole body
-- (UI/MainFrame.lua). Every class can collect library books around the
-- world (Data/LibraryBooks.lua) and hand each in, one quest per book, to
-- their side's librarian; 10, 20, 25 and 38 handed in unlock four reward
-- quests. Only the character's side's books are listed; a line at the end
-- says how many the other side's are.
--
-- Laid out as the Professions Overview (the pet pages' heading and rows,
-- ns.UI.PetPageKit): a strip with the chips All books and Still to find
-- (which leaves out what is handed in), after Back while the tab was
-- opened on a book from NeedRoll's search (page:ShowBook, UI/MainFrame.lua's
-- UI:ShowLibraryBook), and at the right the search box, the Group by zone
-- box (remembered account-wide, NeedRollDB.libraryByZone) and the
-- character's level. Under the badge and the line naming the librarian
-- (a map pin link), the reward bar: green for the books handed in, yellow
-- for those held, ready to hand in, notches at each reward's count; and
-- under it a column per reward quest, its name over how far the character
-- is. A click on a column opens a card under it, over the list (which
-- doesn't move), naming the rewards to choose from as item links; a click
-- on the column again, Escape or the page hiding shuts it. Then the list,
-- scrolling: a fold per level bracket (by the zone's lowest level), the
-- character's own open;
-- or with Group by zone, a box naming the books held (and a pin to the
-- librarian), then a fold per zone, lowest level first, those at the
-- character's level that still have books open and scrolled to. A fold
-- the player opened or shut stays so (Settings' "Remember sections").
-- Text in the search box keeps only the books whose name, zone or place
-- has it in it, each fold with one open and the rest left out; the folds
-- go back as they were once the box is emptied. Each book
-- is two lines: its name (an item link), where it sits and how to get it,
-- its zone and spot as a map pin link, and where it stands
-- (Core/LibraryBooks.lua: handed in, in the bags or bank, not found).
-- Links pin as everywhere else (the secure /mappin link of UI/MainFrame.lua;
-- in combat NeedRoll's own pin, ns.UI.ShowOnMap). The page redraws on a
-- quest turned in, a bag or bank change and a level gained, while it shows.
local _, ns = ...
local Theme = ns.Theme
local Size = Theme.size
local L = ns.L
local LibraryBooks = ns.LibraryBooks
local PetPageKit = ns.UI.PetPageKit
local Colored, Link, JoinAnd = PetPageKit.Colored, PetPageKit.Link, PetPageKit.JoinAnd
local ItemName, RowText, ZoneName = PetPageKit.ItemName, PetPageKit.RowText, PetPageKit.ZoneName

local STRIP_INSET = Size.pad - 4  -- the chips and the level line, from the strip's ends (as Back's)
local CHIP_GAP = 6                -- between two chips
local BOX_GAP = 16                -- between the Group by zone box's label and the level line
local CREST_GAP = 4               -- between the level line and the side's crest
local SEARCH_WIDTH = 160          -- the search box
local SEARCH_GAP = 16             -- between the search box and the Group by zone box
local PAGE_LEFT = 16              -- the bar, the reward columns and the rows, in from the page's sides
local BADGE_ICON = "Interface\\Icons\\INV_Misc_Book_09"
local QUESTION_ICON = 134400      -- a book or reward whose icon the game hasn't sent yet

-- The reward bar and the reward columns under it, between the heading and the list.
local BAR_TOP = 10        -- under the line below the heading, to the bar's labels
local BAR_LABEL_GAP = 4   -- between the labels and the bar
local BAR_HEIGHT = 8
local NOTCH_WIDTH = 2
local NOTCH_REACH = 3     -- a notch, past the bar's top and bottom
local COLUMNS_TOP = 5     -- between the bar and the reward columns
local ROWS_TOP = 5        -- between the columns and the list
local REWARD_GAP = 8      -- between two reward columns
local REWARD_PAD = 3      -- a column's lines, in from its top and bottom (8 from the bar and the list)
local REWARD_INSET = 6    -- a column's lines, in from its sides
local REWARD_LINE_GAP = 2 -- between a column's quest name and its progress under it

-- The card a reward column opens, under it and over the list.
local CARD_GAP = 2        -- between the column and the card
local CARD_RAISE = 20     -- the card's frame level over the list's, so it covers the rows and their links
local CARD_LINE_GAP = 4   -- between two of the card's lines
local CHOICE_GAP = 8      -- between a reward's icon and its name

-- The list's rows.
local FOLD_ROW = 28            -- a level bracket's or zone's fold
local BOOK_ROW = 36            -- a book: its name, and under it where it sits
local NOTE_ROW = 22            -- a line of muted text
local HAND_IN_ROW = 36         -- the box naming the books held (Group by zone)
local HAND_IN_INSET = 3        -- that box, in from its row's top and bottom
local FOLD_ARROW_ROOM = 16     -- a fold's arrow, before its name
local READY_GAP = 8            -- between that note and the "2 ready" pill
local MINI_BAR_WIDTH = 70      -- a fold's own progress bar, at its right
local MINI_BAR_HEIGHT = 6
local FIGURE_GAP = 8           -- between a fold's "8 / 10" and its bar
local TICK_SIZE = 12           -- a handed-in book's tick
local ICON_SIZE = 20           -- a book's icon, and a reward's on its card
local ICON_LEFT = PAGE_LEFT + TICK_SIZE + 4
local TEXT_LEFT = ICON_LEFT + ICON_SIZE + 8
local NAME_LIFT = 7            -- a book's name, up from the row's middle, to make room for the line under it
local SUB_GAP = 2              -- between a book's name and that line
local STATUS_COLUMN = 80       -- "Handed in", "In bags", at the right
local COLUMN_GAP = 12          -- between the spot and the status
local TEXT_ROOM = 12           -- the least room between a book's lines and its spot
local NOT_FOUND_ALPHA = 0.55   -- a book not found: its icon greyed and faded

-- The level brackets the default view folds books into, by the lowest
-- level of the zone each sits in (capital cities count as 1).
local BRACKETS = { { 1, 9 }, { 10, 19 }, { 20, 29 }, { 30, 39 }, { 40, 49 }, { 50, 60 } }

-- The chips: every book, or only those not handed in yet.
local ALL_BOOKS, TO_FIND = "ALL", "TO_FIND"
local CHIPS = { ALL_BOOKS, TO_FIND }
local CHIP_LABELS = { [ALL_BOOKS] = L["All books"], [TO_FIND] = L["Still to find"] }

local TICK = "|A:common-icon-checkmark:11:11|a"  -- after a finished fold's figure

-- The list's rows, by `kind`.
local FOLD, BOOK, HAND_IN, NOTE = "FOLD", "BOOK", "HAND_IN", "NOTE"

-- Text ---------------------------------------------------------------------------

-- A book's name and status color: green handed in, yellow held, else plain text.
local function StatusColor(status)
    if status == LibraryBooks.HANDED_IN then return Theme.color.complete end
    if LibraryBooks.IsHeld(status) then return Theme.color.accepted end
    return Theme.color.text
end

-- A map coordinate (0 to 1) as the guides write it: "48.5", "73".
local function Coordinate(fraction)
    return (("%.1f"):format(fraction * 100):gsub("%.0$", ""))
end

local function SpotText(spot)
    return ("(%s, %s)"):format(Coordinate(spot.x), Coordinate(spot.y))
end

-- The zone `map` (Data/LibraryBooks.lua's zones) as { low, high, continent, isCity }.
local function ZoneOf(map)
    local zone = ns.Data.libraryBooks.zones[map] or {}
    return { low = zone[1] or 1, high = zone[2] or 1, continent = zone[3], isCity = zone[4] }
end

-- Links ---------------------------------------------------------------------------
-- Written as PetPageKit's links (PetPageKit.WireLinks): each needroll: link
-- points at page.links[target], set as its text is written.

-- An item link (its tooltip; Shift-click links it in chat) named `name` in `color`.
local function ItemLink(itemID, name, color)
    return ("|Hitem:%d|h%s|h"):format(itemID, Colored(name, color))
end

-- The side's librarian, their name as a link that pins them.
local function LibrarianLink(page, librarian)
    local target = "npc:" .. librarian.npc
    page.links[target] = { kind = "npc", spot = ns.Data.npcs[librarian.npc], name = librarian.name }
    return Link(target, librarian.name)
end

-- A link to book `book`'s spot `index` (and the spots of `others`, listed in
-- its tooltip), named `text`, that pins the spot.
local function SpotLink(page, book, index, text, others)
    local target = ("spot:%d:%d"):format(book.item, index)
    page.links[target] = { kind = "spot", spot = book.spots[index], others = others,
        name = ItemName(page, book.item, book.name) }
    return Link(target, text)
end

-- Tooltips ---------------------------------------------------------------------------

local function ShowSpotTooltip(data)
    GameTooltip:SetText(data.name)
    GameTooltip:AddLine(("%s %s"):format(ZoneName(data.spot.map), SpotText(data.spot)), 1, 1, 1)
    for _, other in ipairs(data.others or {}) do
        GameTooltip:AddLine(("%s %s"):format(ZoneName(other.map), SpotText(other)), 1, 1, 1)
    end
    GameTooltip:AddLine(ns.UI.PinHint(data.spot), unpack(Theme.tip.text))
end

local function ShowNpcTooltip(data)
    GameTooltip:SetText(data.name)
    local zone = ns.UI.SourceZone({ spot = data.spot })
    if zone then GameTooltip:AddLine(zone) end
    GameTooltip:AddLine(ns.UI.PinHint(data.spot), unpack(Theme.tip.text))
end

-- A reward quest's name: the game's, in the player's language, once
-- Core/Names.lua has it (ns.Data:RegisterLibraryBooks), else the data's.
local function RewardName(reward)
    return ns.Data.questNames[reward.quest] or reward.name
end

-- A reward column's tooltip: how many books unlock its quest, the level
-- its rewards need, the rewards to choose from, and whether it is done.
local function ShowRewardTooltip(page, reward)
    GameTooltip:SetText(RewardName(reward), unpack(Theme.color.quest))
    GameTooltip:AddLine(L["Hand in %d books to the librarian"]:format(reward.books), 1, 1, 1)
    if reward.level then GameTooltip:AddLine(L["Its rewards need level %d"]:format(reward.level), 1, 1, 1) end
    GameTooltip:AddLine(L["Choose one:"])
    for _, itemID in ipairs(reward.choices) do
        local icon = C_Item.GetItemIconByID(itemID)
        GameTooltip:AddLine(("|T%s:0|t %s"):format(icon or QUESTION_ICON, ItemName(page, itemID)), 1, 1, 1)
    end
    if LibraryBooks.IsRewardDone(reward) then GameTooltip:AddLine(L["Completed"], unpack(Theme.color.complete)) end
end

-- A needroll: link's tooltip lines, by what it points at (`data`, its
-- page.links entry); PetPageKit.WireLinks shows the tooltip. Every link
-- here pins what it names, so the page needs no click of its own.
local function FillLinkTooltip(_, data)
    if data.kind == "spot" then
        ShowSpotTooltip(data)
    elseif data.kind == "npc" then
        ShowNpcTooltip(data)
    end
end

-- The books ------------------------------------------------------------------------

-- The side's books, each with where it stands: { book, status, map (its
-- first spot's, the zone it is listed in) }, and the counts: handed in,
-- held, how many the other side's are.
local function TakeStock(side)
    local books, otherSideCount = LibraryBooks.ForSide(side)
    local stock = { entries = {}, handedIn = 0, held = 0, otherSideCount = otherSideCount }
    for _, book in ipairs(books) do
        local status = LibraryBooks.Status(book, side)
        table.insert(stock.entries, { book = book, status = status, map = book.spots[1].map })
        if status == LibraryBooks.HANDED_IN then
            stock.handedIn = stock.handedIn + 1
        elseif LibraryBooks.IsHeld(status) then
            stock.held = stock.held + 1
        end
    end
    return stock
end

-- The bracket (BRACKETS' index) holding level `level`.
local function BracketOfLevel(level)
    for index, bracket in ipairs(BRACKETS) do
        if level <= bracket[2] then return index end
    end
    return #BRACKETS
end

-- The bracket zone `map` falls in, by its lowest level.
local function BracketIndex(map)
    return BracketOfLevel(ZoneOf(map).low)
end

-- The folds' keys, as their open or shut states are kept: "BRACKET:3" (a
-- level bracket's place in BRACKETS), "ZONE:1437" (a zone's map ID).
local function BracketFoldKey(bracketIndex)
    return "BRACKET:" .. bracketIndex
end

local function ZoneFoldKey(map)
    return "ZONE:" .. map
end

-- The key of the fold `book` is listed under: its zone's with Group by
-- zone (`byZone`), else its level bracket's.
local function FoldKeyOf(book, byZone)
    local map = book.spots[1].map
    return byZone and ZoneFoldKey(map) or BracketFoldKey(BracketIndex(map))
end

-- `entries` (TakeStock's) in groups by `keyOf(entry)`, each { key, entries,
-- done, held }, in the order their first book comes.
local function GroupBy(entries, keyOf)
    local groups, byKey = {}, {}
    for _, entry in ipairs(entries) do
        local key = keyOf(entry)
        local group = byKey[key]
        if not group then
            group = { key = key, entries = {}, done = 0, held = 0 }
            byKey[key] = group
            table.insert(groups, group)
        end
        table.insert(group.entries, entry)
        if entry.status == LibraryBooks.HANDED_IN then group.done = group.done + 1 end
        if LibraryBooks.IsHeld(entry.status) then group.held = group.held + 1 end
    end
    return groups
end

local function BracketGroups(stock)
    local groups = GroupBy(stock.entries, function(entry) return BracketIndex(entry.map) end)
    table.sort(groups, function(a, b) return a.key < b.key end)
    return groups
end

-- Zones lowest level first, then those that reach least high, then by name (Mike).
local function ZoneGroups(stock)
    local groups = GroupBy(stock.entries, function(entry) return entry.map end)
    for _, group in ipairs(groups) do group.zone, group.name = ZoneOf(group.key), ZoneName(group.key) end
    table.sort(groups, function(a, b)
        if a.zone.low ~= b.zone.low then return a.zone.low < b.zone.low end
        if a.zone.high ~= b.zone.high then return a.zone.high < b.zone.high end
        return a.name < b.name
    end)
    return groups
end

-- Whether every book of `group` is handed in.
local function IsGroupDone(group)
    return group.done == #group.entries
end

-- The rows ------------------------------------------------------------------------

-- Where the folds' open or shut states are kept: page.openFolds (as
-- Settings' "Remember sections" says), or while the search box has text
-- page.searchFolds, forgotten as the text changes, so a search never
-- changes how the folds are remembered.
local function FoldStates(page)
    return page.query and page.searchFolds or page.openFolds
end

-- A fold's row: its name and note, "2 ready" when books of it are held,
-- and its figure at the right. It is open as the player left it
-- (FoldStates), else as `isOpenAtFirst` says; while the search box has
-- text every fold starts open.
local function FoldEntry(page, key, group, title, note, isOpenAtFirst)
    if page.query then isOpenAtFirst = true end
    return { kind = FOLD, height = FOLD_ROW, foldKey = key, isOpenAtFirst = isOpenAtFirst,
        isOpen = ns.SectionMemory.IsOpen(FoldStates(page), key, isOpenAtFirst),
        title = title, note = note, held = group.held, done = group.done, total = #group.entries,
        hasDivider = true }
end

-- Where a book sits, under its name: "Gallows' Corner  ·  Inside the first
-- tower...", then its other spots as links, one per zone: "also Zephras
-- Isle (8 spots)", or for a zone with one spot its name and coordinates.
local function SubText(page, book)
    local where = (book.place or book.how) and Theme:JoinDots(book.place, book.how)
        or L["Where it sits isn't written up yet"]
    -- One link per map: its first spot, the map's other spots in its tooltip.
    local mapLinks, spotsByMap = {}, {}
    for index = 2, #book.spots do
        local spot = book.spots[index]
        local spotsOnMap = spotsByMap[spot.map]
        if spotsOnMap then
            table.insert(spotsOnMap.others, spot)
        else
            spotsOnMap = { index = index, others = {} }
            spotsByMap[spot.map] = spotsOnMap
            table.insert(mapLinks, spotsOnMap)
        end
    end
    local texts = {}
    for _, spotsOnMap in ipairs(mapLinks) do
        local spot = book.spots[spotsOnMap.index]
        local count = #spotsOnMap.others + 1
        local text = count == 1 and ("%s %s"):format(ZoneName(spot.map), SpotText(spot))
            or L["%s (%d spots)"]:format(ZoneName(spot.map), count)
        table.insert(texts, SpotLink(page, book, spotsOnMap.index, text, spotsOnMap.others))
    end
    if #texts == 0 then return where end
    return Theme:JoinDots(where, L["also %s"]:format(table.concat(texts, ", ")))
end

-- A book's row: its name (an item link in its status color), where it sits
-- under it, its spot at the right (with its zone, unless the fold is the
-- zone) and its status.
local function BookEntry(page, entry, withZone)
    local book, status = entry.book, entry.status
    local color = StatusColor(status)
    local spot = book.spots[1]
    local spotText = withZone and ("%s %s"):format(ZoneName(spot.map), SpotText(spot)) or SpotText(spot)
    return { kind = BOOK, height = BOOK_ROW, book = book, status = status,
        isLit = LibraryBooks.IsHeld(status),
        text = ItemLink(book.item, ItemName(page, book.item, book.name), color),
        sub = SubText(page, book), spot = SpotLink(page, book, 1, spotText) }
end

-- Whether the search box's text (page.query) is in `book`'s name (the
-- game's, else the data's), its place or the name of a zone it sits in,
-- matched as NeedRoll's search matches (ns.Search.Matches).
local function MatchesQuery(page, book)
    local Matches, query = ns.Search.Matches, page.query
    if Matches(ItemName(page, book.item, book.name), query) then return true end
    if book.place and Matches(book.place, query) then return true end
    for _, spot in ipairs(book.spots) do
        if Matches(ZoneName(spot.map), query) then return true end
    end
    return false
end

-- Whether the list shows a book (a TakeStock entry): Still to find leaves
-- out those handed in, and text in the search box those it doesn't match.
local function IsBookShown(page, entry)
    if page.filter == TO_FIND and entry.status == LibraryBooks.HANDED_IN then return false end
    return not page.query or MatchesQuery(page, entry.book)
end

-- A fold's books, while it is open (IsBookShown).
local function AddBookRows(rows, page, group, withZone)
    for _, entry in ipairs(group.entries) do
        if IsBookShown(page, entry) then table.insert(rows, BookEntry(page, entry, withZone)) end
    end
end

-- Whether the list shows `group`: only with a book it shows (IsBookShown).
local function IsGroupShown(page, group)
    for _, entry in ipairs(group.entries) do
        if IsBookShown(page, entry) then return true end
    end
    return false
end

-- The default view: a fold per level bracket, the character's own open.
local function BracketRows(page, stock)
    local rows = {}
    local playerBracket = BracketOfLevel(ns.PlayerLevel())
    for _, group in ipairs(BracketGroups(stock)) do
        if IsGroupShown(page, group) then
            local bracket = BRACKETS[group.key]
            local isPlayers = group.key == playerBracket
            local entry = FoldEntry(page, BracketFoldKey(group.key), group,
                L["Levels %d–%d"]:format(bracket[1], bracket[2]), isPlayers and L["your level"] or nil, isPlayers)
            entry.isBracket = true
            table.insert(rows, entry)
            if entry.isOpen then AddBookRows(rows, page, group, true) end
        end
    end
    return rows
end

-- "Lv 30-40  ·  Eastern Kingdoms", or "City  ·  Kalimdor".
local function ZoneNote(zone)
    local levels = zone.isCity and L["City"] or L["Lv %d-%d"]:format(zone.low, zone.high)
    return Theme:JoinDots(levels, zone.continent and ZoneName(zone.continent))
end

-- The box naming the books held: "Hand in Defensive Magics 101 and
-- Basilisks... to Garion Wendell", and how far that takes the character:
-- "takes you to 14 / 20" (the next reward's count at or over it).
local function HandInEntry(page, stock, librarian)
    local names = {}
    for _, entry in ipairs(stock.entries) do
        if LibraryBooks.IsHeld(entry.status) then
            local book = entry.book
            table.insert(names, ItemLink(book.item, ItemName(page, book.item, book.name), Theme.color.accepted))
        end
    end
    local reached = stock.handedIn + stock.held
    local nextCount
    for _, reward in ipairs(ns.Data.libraryBooks.rewards) do
        if not nextCount and reward.books >= reached then nextCount = reward.books end
    end
    local right = nextCount and L["takes you to %d / %d"]:format(reached, nextCount)
        or L["takes you to %d"]:format(reached)
    return { kind = HAND_IN, height = HAND_IN_ROW,
        text = L["Hand in %s to %s"]:format(JoinAnd(names), LibrarianLink(page, librarian)), right = right }
end

-- Group by zone: the box naming the books held (not while the search box
-- has text: it lists only books), a line saying how the zones are ordered,
-- then a fold per zone. The zones at the character's level that still
-- have books start open.
local function ZoneRows(page, stock, librarian)
    local rows = {}
    if stock.held > 0 and not page.query then table.insert(rows, HandInEntry(page, stock, librarian)) end
    local level = ns.PlayerLevel()
    local folds = {}
    for _, group in ipairs(ZoneGroups(stock)) do
        if IsGroupShown(page, group) then
            local isAtLevel = group.zone.low <= level and level <= group.zone.high and not IsGroupDone(group)
            local entry = FoldEntry(page, ZoneFoldKey(group.key), group, group.name, ZoneNote(group.zone), isAtLevel)
            entry.isAtLevel = isAtLevel
            table.insert(folds, { entry = entry, group = group })
        end
    end
    -- With no zone shown, ListRows says every book is handed in instead.
    if #folds > 0 then
        table.insert(rows, { kind = NOTE, height = NOTE_ROW,
            text = Theme:Plural(#folds, L["%d zone, lowest level first"], L["%d zones, lowest level first"]) })
    end
    for _, fold in ipairs(folds) do
        table.insert(rows, fold.entry)
        if fold.entry.isOpen then AddBookRows(rows, page, fold.group, false) end
    end
    return rows
end

-- "3 Horde-only books hidden": the other side's books, left out.
local function OtherSideNote(stock, side)
    local count = stock.otherSideCount
    if count == 0 then return nil end
    local otherSide = ns.SideName(ns.OtherSide(side))
    local text = (count == 1 and L["%d %s-only book hidden"] or L["%d %s-only books hidden"]):format(count, otherSide)
    return { kind = NOTE, height = NOTE_ROW, text = text }
end

-- The list's rows: by zone or by level bracket, a line when none show
-- (nothing matches the search box, or Still to find with every book handed
-- in), then the other side's books counted.
local function ListRows(page, stock, side, librarian)
    local rows = page.byZone and ZoneRows(page, stock, librarian) or BracketRows(page, stock)
    if rows[1] and rows[1].kind == FOLD then rows[1].hasDivider = false end
    if #rows == 0 then
        local text = page.query and L["No book matches \"%s\"."]:format(page.queryText)
            or L["Every book is handed in."]
        table.insert(rows, { kind = NOTE, height = NOTE_ROW, text = text })
    end
    local footer = OtherSideNote(stock, side)
    if footer then table.insert(rows, footer) end
    return rows
end

-- The rows, drawn -------------------------------------------------------------------

-- A fold's parts: its arrow, the "2 ready" pill, and at the right its
-- figure ("8 / 10") and small bar.
local function CreateFoldParts(row)
    row.arrow = Theme:Arrow(row)
    row.arrow:SetPoint("LEFT", PAGE_LEFT, 0)
    -- Drawn as the strip's chips (Mike, 2026-11-08), but only a label: it
    -- takes no mouse, so a click on it opens or shuts the fold.
    row.ready = Theme:Pill(row)
    row.ready:EnableMouse(false)
    row.miniTrack = row:CreateTexture(nil, "ARTWORK")
    row.miniTrack:SetSize(MINI_BAR_WIDTH, MINI_BAR_HEIGHT)
    row.miniTrack:SetPoint("RIGHT", -PAGE_LEFT, 0)
    row.miniTrack:SetColorTexture(0, 0, 0, 0.5)
    row.miniFill = row:CreateTexture(nil, "OVERLAY")
    row.miniFill:SetHeight(MINI_BAR_HEIGHT)
    row.miniFill:SetPoint("LEFT", row.miniTrack, "LEFT")
    row.miniFill:SetColorTexture(unpack(Theme.color.complete))
end

-- A book's parts: its tick, its icon, the line under its name, its spot and status at the right.
local function CreateBookParts(row)
    row.tick = row:CreateTexture(nil, "ARTWORK")
    row.tick:SetSize(TICK_SIZE, TICK_SIZE)
    row.tick:SetPoint("LEFT", PAGE_LEFT, 0)
    row.tick:SetAtlas("common-icon-checkmark")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.icon:SetPoint("LEFT", ICON_LEFT, 0)
    Theme:CropIcon(row.icon)
    row.sub = RowText(row, Theme.font.small, Theme.color.muted)
    row.sub:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -SUB_GAP)
    row.sub:SetPoint("RIGHT", row.text, "RIGHT")
    row.status = RowText(row, Theme.font.small)
    row.status:SetJustifyH("RIGHT")
    row.status:SetWidth(STATUS_COLUMN)
    row.status:SetPoint("RIGHT", -PAGE_LEFT, 0)
    row.spot = Theme:Text(row, Theme.font.small)
    row.spot:SetJustifyH("RIGHT")
    row.spot:SetPoint("RIGHT", row.status, "LEFT", -COLUMN_GAP, 0)
end

-- The hand-in box: a rounded card edged in green across the row.
local function CreateHandInBox(row)
    row.box = CreateFrame("Frame", nil, row)
    row.box:SetPoint("TOPLEFT", PAGE_LEFT, -HAND_IN_INSET)
    row.box:SetPoint("BOTTOMRIGHT", -PAGE_LEFT, HAND_IN_INSET)
    row.box:SetFrameLevel(row:GetFrameLevel())
    Theme:RoundedOn(row.box, Theme.color.cardFill, Theme.color.complete)
end

-- A click on a fold opens or shuts it; one on a link went to the link.
local function OnRowClick(row, page)
    local entry = row.data
    if row.overLink or not (entry and entry.foldKey) then return end
    GameTooltip:Hide()
    ns.SectionMemory.Toggle(FoldStates(page), entry.foldKey, entry.isOpenAtFirst)
    page:Refresh()
end

-- A row of the list: the pet page's row (PetPageKit.CreateListRow: its
-- text, a note after it, the divider over it, the right column) with the
-- light behind a held book, a fold's and a book's parts and the hand-in
-- box. Its texts' links show their tooltips and pin what they name.
local function CreateRow(column, page)
    local row = PetPageKit.CreateListRow(column)
    row.light = row:CreateTexture(nil, "BACKGROUND")
    row.light:SetAllPoints()
    row.light:SetColorTexture(unpack(Theme.color.hover))
    CreateFoldParts(row)
    CreateBookParts(row)
    CreateHandInBox(row)
    PetPageKit.WireLinks(row, page)
    -- Only a fold is lit under the mouse: elsewhere the links are what clicks.
    row:SetScript("OnEnter", function(self) self.hover:SetShown(self.data and self.data.foldKey ~= nil) end)
    row:SetScript("OnLeave", function(self) self.hover:Hide() end)
    row:SetScript("OnClick", function(self) OnRowClick(self, page) end)
    row:HookScript("OnHide", function(self) self.overLink = nil end)
    return row
end

-- Hides what only some kinds of row show, for SetupRow to show its kind's.
local function ClearRow(row, entry)
    for _, text in ipairs({ row.note, row.right, row.sub, row.spot, row.status }) do text:SetText("") end
    for _, part in ipairs({ row.arrow, row.ready, row.miniTrack, row.miniFill, row.tick, row.icon, row.box }) do
        part:Hide()
    end
    row.divider:SetShown(entry.hasDivider == true)
    row.light:SetShown(entry.isLit == true)
    row.right:SetFontObject(Theme.font.small)
    Theme:SetTextColor(row.right, Theme.color.muted)
    row:EnableMouse(entry.kind ~= NOTE)
    row.text:ClearAllPoints()
end

-- A fold's figure at the right: "2 / 2" and the tick in green once every
-- book is in, else "8 / 10" and its small bar.
local function SetupFoldFigure(row, entry)
    local isDone = entry.done == entry.total
    row.right:ClearAllPoints()
    if isDone then
        row.right:SetPoint("RIGHT", -PAGE_LEFT, 0)
        row.right:SetText(("%d / %d %s"):format(entry.done, entry.total, TICK))
        Theme:SetTextColor(row.right, Theme.color.complete)
        return
    end
    row.right:SetPoint("RIGHT", row.miniTrack, "LEFT", -FIGURE_GAP, 0)
    row.right:SetText(("%d / %d"):format(entry.done, entry.total))
    row.miniTrack:Show()
    row.miniFill:SetShown(entry.done > 0)
    row.miniFill:SetWidth(math.max(1, MINI_BAR_WIDTH * entry.done / entry.total))
end

-- A fold: its arrow, its name (a bracket's in the section font, a zone's in
-- the body font), its note, "2 ready", and its figure.
local function SetupFold(row, entry)
    row.arrow:Show()
    row.arrow:SetOpen(entry.isOpen)
    row.text:SetFontObject(entry.isBracket and Theme.font.section or Theme.font.body)
    Theme:SetTextColor(row.text, entry.isBracket and Theme.color.heading or Theme.color.text)
    row.text:SetPoint("LEFT", PAGE_LEFT + FOLD_ARROW_ROOM, 0)
    row.text:SetText(entry.title)
    row.note:SetText(entry.note or "")
    if entry.held > 0 then
        row.ready:SetLabel(L["%d ready"]:format(entry.held))
        row.ready:ClearAllPoints()
        row.ready:SetPoint("LEFT", entry.note and row.note or row.text, "RIGHT", READY_GAP, 0)
        row.ready:Show()
    end
    SetupFoldFigure(row, entry)
end

-- A book: the tick once handed in, its icon (greyed while not found), its
-- name over where it sits, its spot and its status.
local function SetupBook(row, entry)
    local isFound = entry.status ~= LibraryBooks.NOT_FOUND
    row.tick:SetShown(entry.status == LibraryBooks.HANDED_IN)
    row.icon:SetTexture(C_Item.GetItemIconByID(entry.book.item) or QUESTION_ICON)
    row.icon:SetDesaturated(not isFound)
    row.icon:SetAlpha(isFound and 1 or NOT_FOUND_ALPHA)
    row.icon:Show()
    row.spot:SetText(entry.spot)
    row.status:SetText(LibraryBooks.STATUS_TEXT[entry.status])
    Theme:SetTextColor(row.status, entry.status == LibraryBooks.NOT_FOUND and Theme.color.faint
        or StatusColor(entry.status))
    row.text:SetFontObject(Theme.font.body)
    Theme:SetTextColor(row.text, Theme.color.text)
    row.text:SetPoint("LEFT", TEXT_LEFT, NAME_LIFT)
    row.text:SetPoint("RIGHT", row.spot, "LEFT", -TEXT_ROOM, 0)
    row.text:SetText(entry.text)
    row.sub:SetText(entry.sub)
end

-- The hand-in box: its text, and how far it takes you at the right.
local function SetupHandIn(row, entry)
    row.box:Show()
    row.text:SetFontObject(Theme.font.body)
    Theme:SetTextColor(row.text, Theme.color.text)
    row.right:ClearAllPoints()
    row.right:SetPoint("RIGHT", -(PAGE_LEFT + Size.pad), 0)
    row.right:SetText(entry.right)
    row.text:SetPoint("LEFT", PAGE_LEFT + Size.pad, 0)
    row.text:SetPoint("RIGHT", row.right, "LEFT", -TEXT_ROOM, 0)
    row.text:SetText(entry.text)
end

local function SetupNote(row, entry)
    row.text:SetFontObject(Theme.font.small)
    Theme:SetTextColor(row.text, Theme.color.muted)
    row.text:SetPoint("LEFT", PAGE_LEFT, 0)
    row.text:SetPoint("RIGHT", -PAGE_LEFT, 0)
    row.text:SetText(entry.text)
end

local function SetupRow(row, entry)
    ClearRow(row, entry)
    if entry.kind == FOLD then
        SetupFold(row, entry)
    elseif entry.kind == BOOK then
        SetupBook(row, entry)
    elseif entry.kind == HAND_IN then
        SetupHandIn(row, entry)
    else
        SetupNote(row, entry)
    end
end

-- The reward bar and columns -----------------------------------------------------

-- The mouse came onto a reward column: its quest's tooltip, unless its
-- card is open (which says the same).
local function OnRewardColumnEnter(page, column)
    if page.openReward == column.index then return end
    GameTooltip:SetOwner(column, "ANCHOR_CURSOR")
    ShowRewardTooltip(page, ns.Data.libraryBooks.rewards[column.index])
    GameTooltip:Show()
end

-- Reward `index`'s column: a button lit under the mouse and while its card
-- is open (Theme:Row's hover and selected states), the quest's name over
-- how far the character is. A left click opens or shuts its card.
local function CreateRewardColumn(page, index)
    local column = Theme:Row(page, 1)  -- sized with the bar (PlaceRewardColumns)
    column:RegisterForClicks("LeftButtonUp")
    column.index = index
    column.name = RowText(column, Theme.font.small)
    column.name:SetPoint("TOPLEFT", REWARD_INSET, -REWARD_PAD)
    column.name:SetPoint("TOPRIGHT", -REWARD_INSET, -REWARD_PAD)
    column.progress = RowText(column, Theme.font.small)
    column.progress:SetPoint("TOPLEFT", column.name, "BOTTOMLEFT", 0, -REWARD_LINE_GAP)
    column.progress:SetPoint("TOPRIGHT", column.name, "BOTTOMRIGHT", 0, -REWARD_LINE_GAP)
    column:HookScript("OnEnter", function(self) OnRewardColumnEnter(page, self) end)
    column:HookScript("OnLeave", function() GameTooltip:Hide() end)
    column:SetScript("OnClick", function(self) page:ToggleRewardCard(self.index) end)
    return column
end

-- The bar's parts on `page`: the labels line ("12 handed in + 2 ready" and
-- each reward's count over its notch), the track, the handed-in and held
-- fills, a notch per reward, and a column per reward under it.
local function CreateRewardBar(page, rewards)
    local bar = {}
    bar.label = RowText(page, Theme.font.small)
    bar.track = page:CreateTexture(nil, "ARTWORK")
    bar.track:SetColorTexture(0, 0, 0, 0.45)
    bar.handedIn = page:CreateTexture(nil, "ARTWORK", nil, 1)
    bar.handedIn:SetColorTexture(unpack(Theme.color.complete))
    bar.held = page:CreateTexture(nil, "ARTWORK", nil, 1)
    bar.held:SetColorTexture(unpack(Theme.color.accepted))
    bar.notches, bar.counts, bar.columns = {}, {}, {}
    for i, reward in ipairs(rewards) do
        bar.notches[i] = page:CreateTexture(nil, "ARTWORK", nil, 2)
        bar.notches[i]:SetColorTexture(unpack(Theme.color.heading))
        bar.counts[i] = Theme:Text(page, Theme.font.small)
        bar.counts[i]:SetText(reward.books)
        bar.columns[i] = CreateRewardColumn(page, i)
    end
    return bar
end

-- The most rewards any reward quest gives to choose from: the card's rows.
local function MostChoices(rewards)
    local most = 0
    for _, reward in ipairs(rewards) do most = math.max(most, #reward.choices) end
    return most
end

-- The card a reward column opens, over the list: on the popup color, as it
-- lies over the rows (cardFill would let them show through), edged in
-- `heading`, or `complete` once the quest is done. Its lines are filled by
-- FillRewardCard and stacked by PlaceRewardCard; the rewards' names are
-- item links (PetPageKit.WireLinks: the game's tooltip, Shift-click links
-- one in chat). It takes the mouse, so the rows under it don't, and
-- Escape shuts it (Theme:OnEscape).
local function CreateRewardCard(page, rewards)
    local card = CreateFrame("Frame", nil, page)
    card:SetFrameLevel(page.column:GetFrameLevel() + CARD_RAISE)
    card:EnableMouse(true)
    card:Hide()
    card.edge = select(2, Theme:RoundedOn(card, Theme.color.popup, Theme.color.heading))
    card.title = RowText(card, Theme.font.body)
    card.books = RowText(card, Theme.font.small, Theme.color.muted)
    card.level = RowText(card, Theme.font.small, Theme.color.muted)
    card.chooseOne = RowText(card, Theme.font.small, Theme.color.heading)
    card.chooseOne:SetText(L["Choose one:"])
    card.done = RowText(card, Theme.font.small, Theme.color.complete)
    card.done:SetText(L["Completed"])
    card.choices = {}
    for i = 1, MostChoices(rewards) do
        local icon = card:CreateTexture(nil, "ARTWORK")
        icon:SetSize(ICON_SIZE, ICON_SIZE)
        Theme:CropIcon(icon)
        local text = RowText(card, Theme.font.body)
        text:SetPoint("LEFT", icon, "RIGHT", CHOICE_GAP, 0)
        card.choices[i] = { icon = icon, text = text }
    end
    PetPageKit.WireLinks(card, page)
    Theme:OnEscape(card, function() page:CloseRewardCard() end)
    return card
end

-- "Friend of the Library" in the quest color over "12 / 20" in muted, the
-- note "rewards need Lv 50" added while the character is under the level
-- its rewards need; once the quest is done, the name and "Completed" in
-- green.
local function DrawRewardColumn(column, reward, handedIn)
    column.name:SetText(RewardName(reward))
    if LibraryBooks.IsRewardDone(reward) then
        Theme:SetTextColor(column.name, Theme.color.complete)
        Theme:SetTextColor(column.progress, Theme.color.complete)
        column.progress:SetText(L["Completed"])
        return
    end
    Theme:SetTextColor(column.name, Theme.color.quest)
    Theme:SetTextColor(column.progress, Theme.color.muted)
    local progress = ("%d / %d"):format(math.min(handedIn, reward.books), reward.books)
    local isUnderLevel = reward.level and ns.PlayerLevel() < reward.level
    column.progress:SetText(Theme:JoinDots(progress, isUnderLevel and L["rewards need Lv %d"]:format(reward.level)
        or nil))
end

-- A reward to choose, as an item link in its quality color; "Loading..."
-- in faint text until the game sends the item (ItemName asks for it, and
-- the page redraws once it arrives).
local function ChoiceLink(page, itemID)
    local name = ItemName(page, itemID, L["Loading..."])
    if not C_Item.GetItemNameByID(itemID) then return ItemLink(itemID, name, Theme.color.faint) end
    return ItemLink(itemID, name, { Theme:QualityColor(ns.Items:Quality(itemID)) })
end

-- Fills the card for `reward`, top to bottom: the quest's name (green once
-- done, as the edge), the books it needs, the level its rewards need, "Choose
-- one:", each reward to choose (its icon and ChoiceLink), and "Completed"
-- once done. Returns the lines it shows, in order, each { text, icon (a
-- reward's) }.
local function FillRewardCard(page, card, reward)
    local isDone = LibraryBooks.IsRewardDone(reward)
    card.edge:SetVertexColor(unpack(isDone and Theme.color.complete or Theme.color.heading))
    card.title:SetText(RewardName(reward))
    Theme:SetTextColor(card.title, isDone and Theme.color.complete or Theme.color.quest)
    card.books:SetText(L["Hand in %d books to the librarian"]:format(reward.books))
    card.level:SetText(reward.level and L["Its rewards need level %d"]:format(reward.level) or "")
    card.level:SetShown(reward.level ~= nil)
    card.done:SetShown(isDone)
    local lines = { { text = card.title }, { text = card.books } }
    if reward.level then table.insert(lines, { text = card.level }) end
    table.insert(lines, { text = card.chooseOne })
    for i, choice in ipairs(card.choices) do
        local itemID = reward.choices[i]
        choice.icon:SetShown(itemID ~= nil)
        choice.text:SetShown(itemID ~= nil)
        if itemID then
            choice.icon:SetTexture(C_Item.GetItemIconByID(itemID) or QUESTION_ICON)
            choice.text:SetText(ChoiceLink(page, itemID))
            table.insert(lines, choice)
        end
    end
    if isDone then table.insert(lines, { text = card.done }) end
    return lines
end

-- How wide a line of the card is: its text, after its icon when it has one.
local function CardLineWidth(line)
    local width = ns.Plain(line.text:GetUnboundedStringWidth()) or 0
    if line.icon then width = width + ICON_SIZE + CHOICE_GAP end
    return width
end

-- Stacks the card's `lines` (FillRewardCard's) `pad` in from its top and
-- sides and hangs it under `column`: as wide as its widest line, but no
-- narrower than the column nor wider than the bar; flush with the column's
-- left, or with its right where it would reach past the bar's right end.
local function PlaceRewardCard(page, column, lines)
    local card, pad = page.rewardCard, Size.pad
    local barRight = page:GetWidth() - PAGE_LEFT
    local inner = column:GetWidth() - pad * 2
    for _, line in ipairs(lines) do inner = math.max(inner, CardLineWidth(line)) end
    inner = math.max(1, math.min(inner, barRight - PAGE_LEFT - pad * 2))
    local y = pad
    for index, line in ipairs(lines) do
        if index > 1 then y = y + CARD_LINE_GAP end
        if line.icon then
            line.icon:SetPoint("TOPLEFT", pad, -y)
            line.text:SetWidth(math.max(1, inner - ICON_SIZE - CHOICE_GAP))
            y = y + ICON_SIZE
        else
            line.text:SetPoint("TOPLEFT", pad, -y)
            line.text:SetWidth(inner)
            y = y + Theme:LineHeight(line.text)
        end
    end
    local width = inner + pad * 2
    card:SetSize(width, y + pad)
    card:ClearAllPoints()
    if column.pageLeft + width > barRight then
        card:SetPoint("TOPRIGHT", column, "BOTTOMRIGHT", 0, -CARD_GAP)
    else
        card:SetPoint("TOPLEFT", column, "BOTTOMLEFT", 0, -CARD_GAP)
    end
end

-- Shows the card of the reward open (page.openReward, its place in the
-- rewards) under its column, which stays lit, or hides it with none open.
local function DrawRewardCard(page)
    local card, columns = page.rewardCard, page.rewardBar.columns
    for index, column in ipairs(columns) do column:SetSelected(index == page.openReward) end
    local reward = page.openReward and ns.Data.libraryBooks.rewards[page.openReward]
    if not reward then
        if GameTooltip:IsOwned(card) then GameTooltip:Hide() end
        card:Hide()
        return
    end
    PlaceRewardCard(page, columns[page.openReward], FillRewardCard(page, card, reward))
    card:Show()
end

-- A reward column's height: its two lines and the room above and below them.
local function RewardColumnHeight(column)
    return REWARD_PAD + Theme:LineHeight(column.name) + REWARD_LINE_GAP + Theme:LineHeight(column.progress)
        + REWARD_PAD
end

-- How tall the bar and the reward columns take, from the line under the heading to the list.
local function RewardsHeight(page)
    local bar = page.rewardBar
    return BAR_TOP + Theme:LineHeight(bar.label) + BAR_LABEL_GAP + BAR_HEIGHT + COLUMNS_TOP
        + RewardColumnHeight(bar.columns[1]) + ROWS_TOP
end

-- The reward columns `top` down from the page's top, one per reward, as
-- wide as each other across the bar's width (`width`).
local function PlaceRewardColumns(page, top, width)
    local columns = page.rewardBar.columns
    local columnWidth = math.max(1, (width - REWARD_GAP * (#columns - 1)) / #columns)
    for i, column in ipairs(columns) do
        column.pageLeft = PAGE_LEFT + (i - 1) * (columnWidth + REWARD_GAP)
        column:ClearAllPoints()
        column:SetPoint("TOPLEFT", column.pageLeft, -top)
        column:SetSize(columnWidth, RewardColumnHeight(column))
    end
end

-- Lays the bar out across the page `top` down, as wide as the page is.
local function PlaceRewardBar(page, top)
    local bar, rewards = page.rewardBar, ns.Data.libraryBooks.rewards
    local width = math.max(1, page:GetWidth() - PAGE_LEFT * 2)
    local most = rewards[#rewards].books
    local barTop = top + Theme:LineHeight(bar.label) + BAR_LABEL_GAP
    bar.label:SetPoint("TOPLEFT", PAGE_LEFT, -top)
    bar.track:SetPoint("TOPLEFT", PAGE_LEFT, -barTop)
    bar.track:SetSize(width, BAR_HEIGHT)
    bar.handedIn:SetPoint("TOPLEFT", bar.track, "TOPLEFT")
    bar.held:SetPoint("TOPLEFT", bar.handedIn, "TOPRIGHT")
    for i, reward in ipairs(rewards) do
        local x = PAGE_LEFT + width * reward.books / most - NOTCH_WIDTH / 2
        x = math.min(x, PAGE_LEFT + width - NOTCH_WIDTH)
        bar.notches[i]:SetSize(NOTCH_WIDTH, BAR_HEIGHT + NOTCH_REACH * 2)
        bar.notches[i]:SetPoint("TOPLEFT", x, -(barTop - NOTCH_REACH))
        bar.counts[i]:ClearAllPoints()
        bar.counts[i]:SetPoint(i == #rewards and "TOPRIGHT" or "TOP", page, "TOPLEFT",
            x + (i == #rewards and NOTCH_WIDTH or NOTCH_WIDTH / 2), -top)
    end
    PlaceRewardColumns(page, barTop + BAR_HEIGHT + COLUMNS_TOP, width)
end

-- Fills the bar to the books handed in (green) and held (yellow), the
-- reward counts reached in green, writes the labels and the reward
-- columns, and redraws the open reward's card.
local function DrawRewards(page, stock)
    local bar, rewards = page.rewardBar, ns.Data.libraryBooks.rewards
    local most = rewards[#rewards].books
    local width = bar.track:GetWidth()
    local handedIn = math.min(stock.handedIn, most)
    local held = math.min(stock.held, most - handedIn)
    bar.handedIn:SetSize(math.max(0.01, width * handedIn / most), BAR_HEIGHT)
    bar.handedIn:SetShown(handedIn > 0)
    bar.held:SetSize(math.max(0.01, width * held / most), BAR_HEIGHT)
    bar.held:SetShown(held > 0)
    local label = Colored(L["%d handed in"]:format(stock.handedIn), Theme.color.complete)
    if stock.held > 0 then label = label .. " " .. Colored(L["+ %d ready"]:format(stock.held), Theme.color.accepted) end
    bar.label:SetText(label)
    for i, reward in ipairs(rewards) do
        Theme:SetTextColor(bar.counts[i], stock.handedIn >= reward.books and Theme.color.complete
            or Theme.color.heading)
        DrawRewardColumn(bar.columns[i], reward, stock.handedIn)
    end
    DrawRewardCard(page)
end

-- The page ----------------------------------------------------------------------------

-- "Hand them in to Garion Wendell  ·  Stormwind City, Mage Tower  ·  38
-- books for the Alliance", the librarian a link that pins them.
local function SubtitleText(page, librarian, side, total)
    local spot = ns.Data.npcs[librarian.npc]
    local where = spot and L["%s, %s"]:format(ZoneName(spot.map), librarian.place) or librarian.place
    return Theme:JoinDots(L["Hand them in to %s"]:format(LibrarianLink(page, librarian)), where,
        L["%d books for the %s"]:format(total, ns.SideName(side)))
end

-- The strip's parts: the chips, the search box, the Group by zone box, the
-- level line and the side's crest.
local function CreateStripParts(page)
    page.chips = {}
    for i, filter in ipairs(CHIPS) do
        local chip = Theme:Pill(page)
        chip.filter = filter
        chip:SetScript("OnClick", function(self)
            page.filter = self.filter
            page:Refresh()
        end)
        page.chips[i] = chip
    end
    page.searchBox = Theme:SearchBox(page, L["Search books"], SEARCH_WIDTH, function(text) page:SetQuery(text) end)
    page.byZoneBox = Theme:CheckBox(page, L["Group by zone"], function(on) page:SetByZone(on) end)
    page.levelLine = Theme:Text(page, Theme.font.body)
    Theme:SetTextColor(page.levelLine, Theme.color.muted)
    page.crest = page:CreateTexture(nil, "ARTWORK")
end

-- The first open zone at the character's level (Group by zone), by its place in the list.
local function FirstOpenZoneIndex(rows)
    for index, entry in ipairs(rows) do
        if entry.kind == FOLD and entry.isAtLevel and entry.isOpen then return index end
    end
end

-- Scrolls the list so `book`'s row is in view: its fold's row at the top
-- when the book's row fits under it, else the row just above the book's.
local function ScrollToBook(page, book)
    local column = page.column
    local entries = column.entries
    local foldIndex, bookIndex
    for index, entry in ipairs(entries) do
        if entry.kind == FOLD then foldIndex = index end
        if entry.kind == BOOK and entry.book == book then
            bookIndex = index
            break
        end
    end
    if not (foldIndex and bookIndex) then return end
    local height = 0
    for index = foldIndex, bookIndex do height = height + entries[index].height end
    local first = height <= column.view:GetHeight() and foldIndex or bookIndex - 1
    column.offset = first - 1
    column:SetData(entries, true)  -- kept to the furthest the list scrolls
end

-- The page. `parent` is the window's body; MainFrame.lua hosts it in a
-- content pane across the whole body, its strip parts in the pane's strip.
function ns.UI.CreateLibraryPage(parent)
    local page = PetPageKit.CreatePage(parent, CreateRow, SetupRow)
    CreateStripParts(page)
    page.rewardBar = CreateRewardBar(page, ns.Data.libraryBooks.rewards)
    page.rewardCard = CreateRewardCard(page, ns.Data.libraryBooks.rewards)
    page.links = {}
    page.fillLinkTooltip = FillLinkTooltip
    page.itemsAsked = {}   -- items asked of the game, by ID (ItemName)
    -- The folds opened or shut by hand ("BRACKET:3", "ZONE:1437": a level
    -- bracket's place in BRACKETS or a zone's map ID), kept as Settings'
    -- "Remember sections" says (ns.SectionMemory's "library" area); the
    -- rest start as they do (the character's bracket or level's zones open).
    page.openFolds = ns.SectionMemory.Area("library")
    -- The folds opened or shut while the search box has text (FoldStates).
    page.searchFolds = {}
    ns.SectionMemory.OnModeChange(function()
        page.openFolds = ns.SectionMemory.Area("library")
        if page:IsVisible() then page:Refresh() end
    end)
    page.filter = ALL_BOOKS
    -- The line under the heading holds the librarian's link.
    PetPageKit.WireLinks(page, page)
    -- Each time the page opens the zone view scrolls to the character's
    -- level's zones, and no reward's card is open.
    page:HookScript("OnHide", function(self)
        self.scrollToLevel = true
        self:CloseRewardCard()
    end)
    page.scrollToLevel = true

    -- Opens reward `index`'s card under its column (shutting another's), or
    -- shuts it when it is the one open. Nothing on the page moves: the card
    -- lies over the list.
    function page:ToggleRewardCard(index)
        GameTooltip:Hide()
        self.openReward = self.openReward ~= index and index or nil
        DrawRewardCard(self)
    end

    function page:CloseRewardCard()
        self.openReward = nil
        DrawRewardCard(self)
    end

    -- The rows under the bar and the reward columns, hung from the page itself:
    -- book rows hold map links' secure buttons (Theme:LineHeight).
    function page:PlaceColumn()
        local top = ns.UI.BadgeHeadingBottom(self)
        PlaceRewardBar(self, top + BAR_TOP)
        self.column:ClearAllPoints()
        self.column:SetPoint("TOPLEFT", 0, -(top + RewardsHeight(self)))
        self.column:SetPoint("BOTTOMRIGHT")
    end
    -- Only the bar, the reward columns and the open card follow the page's
    -- width; the list lays itself out again as its view resizes
    -- (Theme:ScrollColumn).
    page:HookScript("OnSizeChanged", function(self)
        if not (self:IsVisible() and self.stock) then return end
        self:PlaceColumn()
        DrawRewards(self, self.stock)
    end)

    function page:PlaceStrip(strip)
        for _, chip in ipairs(self.chips) do chip:SetParent(strip) end
        self:FollowBack(nil)
        for i = 2, #self.chips do self.chips[i]:SetPoint("LEFT", self.chips[i - 1], "RIGHT", CHIP_GAP, 0) end
        for _, part in ipairs({ self.searchBox, self.byZoneBox, self.levelLine, self.crest }) do
            part:SetParent(strip)
        end
        local crestSize = Theme:InsigniaSize(Theme.font.body)
        self.crest:SetSize(crestSize, crestSize)
        self.crest:SetPoint("RIGHT", -STRIP_INSET, 0)
        self.levelLine:SetPoint("RIGHT", self.crest, "LEFT", -CREST_GAP, 0)
        self.byZoneBox:SetPoint("RIGHT", self.levelLine, "LEFT", -(BOX_GAP + self.byZoneBox:FullWidth()
            - self.byZoneBox:GetWidth()), 0)
        -- Hung from the right, so Back showing (and the chips moving after
        -- it) never moves it.
        self.searchBox:SetPoint("RIGHT", self.byZoneBox, "LEFT", -SEARCH_GAP, 0)
    end

    -- The chips start after Back while it shows (UI:UpdateLibraryBack).
    function page:FollowBack(back)
        local first = self.chips[1]
        first:ClearAllPoints()
        if back then
            first:SetPoint("LEFT", back, "RIGHT", CHIP_GAP, 0)
        else
            first:SetPoint("LEFT", STRIP_INSET, 0)
        end
    end

    -- Takes the search box's text (trimmed, `text`) as the query, for the
    -- next Refresh: the list keeps the books it matches (IsBookShown), from
    -- the top, every fold with one open. Emptied, the folds are as they
    -- were and the zone view scrolls to the character's level again.
    -- Returns whether the query changed.
    function page:TakeQuery(text)
        local query = text ~= "" and ns.Search.SearchForm(text) or nil
        if query == self.query then return false end
        self.query, self.queryText = query, text
        wipe(self.searchFolds)
        self.column.offset = 0
        self.scrollToLevel = query == nil
        return true
    end

    -- The search box's text changed (trimmed, `text`).
    function page:SetQuery(text)
        if self:TakeQuery(text) then self:Refresh() end
    end

    -- Shows `book` (UI:ShowLibraryBook): the whole list again (the search
    -- box emptied, All books when Still to find would leave the book out),
    -- the book's fold opened as a click on it would, scrolled to the book.
    -- The box is emptied quietly, so the page is drawn once, here.
    function page:ShowBook(book)
        Theme:SetSearchTextQuietly(self.searchBox, "")
        self:TakeQuery("")
        self.searchBox:ClearFocus()
        if self.filter == TO_FIND and LibraryBooks.Status(book, ns.PlayerFaction()) == LibraryBooks.HANDED_IN then
            self.filter = ALL_BOOKS
        end
        self.openFolds[FoldKeyOf(book, ns.db.libraryByZone == true)] = true
        self:Refresh()
        ScrollToBook(self, book)
    end

    -- Groups by zone (`on`) or level bracket, remembered account-wide;
    -- the zone view opens scrolled to the character's level's zones.
    function page:SetByZone(on)
        ns.db.libraryByZone = on or nil
        self.scrollToLevel = true
        self:Refresh()
    end

    -- The chips' labels with their counts, the picked one filled; the box,
    -- the level line and the crest as the character is now.
    function page:UpdateStrip(stock, side)
        local counts = { [ALL_BOOKS] = #stock.entries, [TO_FIND] = #stock.entries - stock.handedIn }
        for _, chip in ipairs(self.chips) do
            chip:SetLabel(("%s  %d"):format(CHIP_LABELS[chip.filter], counts[chip.filter]))
            chip:SetTone(chip.filter == self.filter and Theme.color.heading or nil)
        end
        self.byZoneBox:Set(self.byZone)
        self.levelLine:SetText(L["Level %d"]:format(ns.PlayerLevel()))
        Theme:FitAtlas(self.crest, Theme:Insignia(side), self.crest:GetWidth())
    end

    -- Redraws the page for the character as they are now, keeping the
    -- list's scroll, except the first draw of the zone view, which scrolls
    -- to the character's level's zones.
    function page:Refresh()
        local side = ns.PlayerFaction()
        local librarian = ns.Data.libraryBooks.librarians[side]
        local stock = TakeStock(side)
        self.stock = stock  -- for the bar, redrawn as the page is resized
        self.byZone = ns.db.libraryByZone == true
        wipe(self.links)
        self:SetHeading(L["Library Books"], SubtitleText(self, librarian, side, #stock.entries), BADGE_ICON)
        DrawRewards(self, stock)
        self:UpdateStrip(stock, side)
        local rows = ListRows(self, stock, side, librarian)
        if not self.scrollToLevel then
            self.column:SetData(rows, true)
            return
        end
        self.scrollToLevel = false
        local index = self.byZone and FirstOpenZoneIndex(rows)
        self.column.offset = index and index - 1 or 0
        self.column:SetData(rows, true)
    end

    -- A quest turned in, a bag or bank change or an item's name arriving:
    -- redrawn once for a burst of them, while the page shows.
    PetPageKit.AddRefreshSoon(page)
    local function RefreshSoon() page:RefreshSoon() end
    for _, event in ipairs({ "QUEST_TURNED_IN", "BAG_UPDATE_DELAYED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED",
        "PLAYERBANKSLOTS_CHANGED" }) do
        ns:On(event, RefreshSoon)
    end
    -- UnitLevel catches up a moment after the event (as the instance list's level line).
    ns:On("PLAYER_LEVEL_UP", function() C_Timer.After(1, RefreshSoon) end)
    return page
end
