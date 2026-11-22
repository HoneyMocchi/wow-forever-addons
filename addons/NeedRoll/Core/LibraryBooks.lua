-- Library Books: where each book stands for this character (handed in, in
-- the bags, in the bank, not found), for the Library tab
-- (UI/LibraryBooks.lua; the books are Data/LibraryBooks.lua).
--
-- A book is handed in once its hand-in quest is done: the game keeps that
-- per character (C_QuestLog.IsQuestFlaggedCompleted). Most books are handed
-- in with the same quest by both sides; some have one per side. Where the
-- data doesn't know a side's quest yet it is learned in game: a book seen
-- in the bags that leaves them in the bag change a quest turn-in brings was
-- handed in with that quest. It is saved account-wide by side
-- (NeedRollDB.libraryBookQuests), since the quest is the same for every
-- character of the side and the game still says per character whether it
-- is done. Dev builds print what they learn, for Mike to add to the data.
--
-- The bank's contents are only known while the bank is open, so "In bank"
-- comes from Core/Shopping.lua's count from the character's last bank
-- visit (ns.Shopping:BankCount).
local _, ns = ...
local L = ns.L

local LibraryBooks = {}
ns.LibraryBooks = LibraryBooks

-- Where a book stands, best first, and how the Library tab and the world
-- map's book markers (UI/WorldMapMarkers.lua) say it.
LibraryBooks.HANDED_IN, LibraryBooks.IN_BAGS, LibraryBooks.IN_BANK, LibraryBooks.NOT_FOUND =
    "HANDED_IN", "IN_BAGS", "IN_BANK", "NOT_FOUND"
LibraryBooks.STATUS_TEXT = {
    [LibraryBooks.HANDED_IN] = L["Handed in"], [LibraryBooks.IN_BAGS] = L["In bags"],
    [LibraryBooks.IN_BANK] = L["In bank"], [LibraryBooks.NOT_FOUND] = L["Not found"],
}

local function Data()
    return ns.Data.libraryBooks
end

-- The quests learned in game for side `side`: book item ID -> quest ID.
local function LearnedQuests(side)
    local learned = ns.db and ns.db.libraryBookQuests
    return learned and learned[side] or {}
end

-- The quest side `side` hands `book` in with: the data's, else the one
-- learned in game; nil when neither knows it.
function LibraryBooks.QuestOf(book, side)
    if book.quest then return book.quest end
    local bySide = book.questBySide and book.questBySide[side]
    return bySide or LearnedQuests(side)[book.item]
end

-- Where `book` stands for this character, of side `side` (LibraryBooks.HANDED_IN ...).
function LibraryBooks.Status(book, side)
    if ns.IsQuestDone(LibraryBooks.QuestOf(book, side)) then return LibraryBooks.HANDED_IN end
    if (C_Item.GetItemCount(book.item) or 0) > 0 then return LibraryBooks.IN_BAGS end
    if ns.Shopping:BankCount(book.item) > 0 then return LibraryBooks.IN_BANK end
    return LibraryBooks.NOT_FOUND
end

-- Whether a book of `status` is held, ready to hand in.
function LibraryBooks.IsHeld(status)
    return status == LibraryBooks.IN_BAGS or status == LibraryBooks.IN_BANK
end

-- The books side `side` can hand in, in the data's order, and how many only
-- the other side can.
function LibraryBooks.ForSide(side)
    local books, otherSideCount = {}, 0
    for _, book in ipairs(Data().books) do
        if not book.side or book.side == side then
            table.insert(books, book)
        else
            otherSideCount = otherSideCount + 1
        end
    end
    return books, otherSideCount
end

-- Whether reward quest `reward` (Data/LibraryBooks.lua's rewards) is done.
function LibraryBooks.IsRewardDone(reward)
    return ns.IsQuestDone(reward.quest)
end

-- Learning hand-in quests --------------------------------------------------------
-- What is saved about the character asks the game for its side
-- (UnitFactionGroup), not ns.PlayerFaction, which a dev build can switch.
--
-- A turn-in and its book leaving the bags come in the same moment, but the
-- game doesn't say whether QUEST_TURNED_IN or the bag change
-- (BAG_UPDATE_DELAYED) comes first. So a turn-in takes the bag change that
-- came just before it, if a book left in that one; else the first bag
-- change after it, if one comes soon. Each bag change answers one turn-in.
-- A saved quest stays for good, so anything that leaves room for doubt
-- learns nothing: two books leaving at once, a second turn-in before the
-- first one's bag change, or the bank, mail or a merchant open (books
-- leave the bags there without a hand-in).
local SAME_MOMENT = 0.5  -- seconds: a bag change this close before a turn-in is the turn-in's
local TURN_IN_WAIT = 1   -- seconds a turn-in waits for its bag change

-- The books in the bags whose hand-in quest isn't known for the
-- character's side, as the last bag change left them: item ID -> count.
local carried = {}
-- The last bag change, until a turn-in takes it: { carriedBefore (the
-- books carried just before it), time }.
local lastBagChange
-- A quest turned in whose bag change hasn't come yet: { questID, side,
-- carriedBefore }.
local pendingTurnIn
-- The windows open that books leave the bags through without a hand-in,
-- by name ("bank", "mail", "merchant").
local openWindows = {}

local function CountCarried(side)
    local counts = {}
    for _, book in ipairs(Data().books) do
        if not LibraryBooks.QuestOf(book, side) then
            local count = C_Item.GetItemCount(book.item) or 0
            if count > 0 then counts[book.item] = count end
        end
    end
    return counts
end

-- Whether `questID` is already a reward's quest, or some book's for side `side`.
local function IsKnownQuest(questID, side)
    local library = Data()
    for _, reward in ipairs(library.rewards) do
        if reward.quest == questID then return true end
    end
    for _, book in ipairs(library.books) do
        if LibraryBooks.QuestOf(book, side) == questID then return true end
    end
    return false
end

-- The books fewer in `carriedNow` than in `carriedBefore` (item IDs).
local function BooksGone(carriedBefore, carriedNow)
    local gone = {}
    for item, count in pairs(carriedBefore) do
        if (carriedNow[item] or 0) < count then table.insert(gone, item) end
    end
    return gone
end

-- Dev builds: a turn-in made carrying books of unknown quest learned
-- nothing, and `reason` says why, so Mike can tell if the events came in an
-- order the learning doesn't expect.
local function ReportNothingLearned(questID, reason)
    --[==[@debug@
    ns:Print(("Library: quest %d was turned in carrying books of unknown quest, but %s: nothing learned.")
        :format(questID, reason))
    --@end-debug@]==]
end

-- Saves the quest of the one book `gone` holds (a turn-in's bag change);
-- none or several, nothing.
local function LearnFrom(turnIn, gone)
    if #gone ~= 1 then
        ReportNothingLearned(turnIn.questID, #gone == 0 and "no book left the bags with it"
            or "more than one book left the bags with it")
        return
    end
    local item = gone[1]
    ns.db.libraryBookQuests[turnIn.side][item] = turnIn.questID
    --[==[@debug@
    ns:Print(("Library book %d was handed in with %s quest %d: add it to Data/LibraryBooks.lua."):format(item,
        turnIn.side, turnIn.questID))
    --@end-debug@]==]
end

-- The character's side as the saved quests are kept, or nil before the game knows it.
local function SavedSide()
    local side = UnitFactionGroup("player")
    if side == "Alliance" or side == "Horde" then return side end
end

-- The books the last bag change took away, if it came at the turn-in's
-- moment (just before it) and took any; the change is then the turn-in's,
-- and no other's.
local function TakeBooksGoneJustBefore()
    local change = lastBagChange
    if not (change and GetTime() - change.time <= SAME_MOMENT) then return nil end
    local gone = BooksGone(change.carriedBefore, carried)
    if #gone == 0 then return nil end
    lastBagChange = nil
    return gone
end

-- Waits for the turn-in's bag change; one that doesn't come soon learns nothing.
local function AwaitBagChange(turnIn)
    pendingTurnIn = turnIn
    C_Timer.After(TURN_IN_WAIT, function()
        if pendingTurnIn ~= turnIn then return end
        pendingTurnIn = nil
        ReportNothingLearned(turnIn.questID, "no bag change came with it")
    end)
end

local function OnQuestTurnedIn(questID)
    local side = SavedSide()
    if not (ns.db and Data() and side) or IsKnownQuest(questID, side) then return end
    if pendingTurnIn then
        ReportNothingLearned(pendingTurnIn.questID, "another quest was turned in before its bag change")
        pendingTurnIn = nil
        return
    end
    if next(openWindows) then
        if next(carried) then ReportNothingLearned(questID, "the bank, mail or a merchant was open") end
        return
    end
    local turnIn = { questID = questID, side = side, carriedBefore = carried }
    local gone = TakeBooksGoneJustBefore()
    if gone then return LearnFrom(turnIn, gone) end
    if next(carried) then AwaitBagChange(turnIn) end
end

local function OnBagChange()
    local side = SavedSide()
    if not (ns.db and Data() and side) then return end
    local carriedNow = CountCarried(side)
    local turnIn = pendingTurnIn
    if not turnIn then
        -- A change with the bank, mail or a merchant open is no turn-in's.
        lastBagChange = nil
        if not next(openWindows) then lastBagChange = { carriedBefore = carried, time = GetTime() } end
        carried = carriedNow
        return
    end
    -- This change is the turn-in's, so no later turn-in takes it.
    pendingTurnIn, lastBagChange = nil, nil
    if next(openWindows) then
        ReportNothingLearned(turnIn.questID, "the bank, mail or a merchant was open")
    else
        LearnFrom(turnIn, BooksGone(turnIn.carriedBefore, carriedNow))
    end
    -- Counted again: a book just learned is no longer one of unknown quest.
    carried = CountCarried(side)
end

ns:On("QUEST_TURNED_IN", OnQuestTurnedIn)
ns:On("BAG_UPDATE_DELAYED", OnBagChange)

-- Keeps openWindows[name] while the window `openEvent` opens is open.
local function TrackWindow(name, openEvent, closeEvent)
    ns:On(openEvent, function() openWindows[name] = true end)
    ns:On(closeEvent, function() openWindows[name] = nil end)
end
TrackWindow("bank", "BANKFRAME_OPENED", "BANKFRAME_CLOSED")
TrackWindow("mail", "MAIL_SHOW", "MAIL_CLOSED")
TrackWindow("merchant", "MERCHANT_SHOW", "MERCHANT_CLOSED")
