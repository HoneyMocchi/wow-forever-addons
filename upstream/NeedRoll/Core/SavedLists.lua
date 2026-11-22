-- Named lists shared by every character on the account (NeedRollDB is
-- account-wide), as the Wishlist and the Shopping List keep them. One list
-- is current: the tab shows it and new items go on it. Each owner keeps its
-- lists in a saved table of this shape:
--     { current = "Starred items",
--       lists = { { name = "Starred items", note = "Shared from NeedRoll", items = { ... } } } }
-- and SavedLists.AddTo gives the owner the methods that pick, add, copy,
-- rename and delete them. What an item is stays the owner's business.
local _, ns = ...

local SavedLists = {}
ns.SavedLists = SavedLists

SavedLists.MAX_NAME = 40 -- bytes a list name keeps (fewer letters outside English)

local function FindIn(lists, name)
    for i, list in ipairs(lists) do
        if list.name == name then return list, i end
    end
end

-- `name` if no list in `lists` has it, else "name 2", "name 3"...
function SavedLists.FreeName(lists, name)
    if not FindIn(lists, name) then return name end
    local number = 2
    while FindIn(lists, ("%s %d"):format(name, number)) do number = number + 1 end
    return ("%s %d"):format(name, number)
end

-- Gives `owner` (ns.Wishlist, ns.Shopping) OnChange and its lists' methods.
-- `options`:
--   Store()          the owner's saved table, { current, lists }
--   defaultName      the list made whenever there is none
--   fallbackName     a new list's name when the one asked for cleans to nothing
--   CopyItem(item)   a copy of one item, so a preset or an import shares no tables
function SavedLists.AddTo(owner, options)
    owner.listeners = owner.listeners or {}

    -- Runs listener() whenever a list changes.
    function owner:OnChange(listener)
        table.insert(self.listeners, listener)
    end

    function owner:NotifyChange()
        for _, listener in ipairs(self.listeners) do listener() end
    end

    -- The saved table, with at least one list in it.
    local function Store()
        local store = options.Store()
        if #store.lists == 0 then table.insert(store.lists, { name = options.defaultName, items = {} }) end
        return store
    end

    local function CopyItems(items)
        local copy = {}
        for i, item in ipairs(items) do copy[i] = options.CopyItem(item) end
        return copy
    end

    function owner:Lists()
        return Store().lists
    end

    -- The current list; the first one if the saved name is gone.
    function owner:Current()
        local store = Store()
        local list = FindIn(store.lists, store.current)
        if not list then
            list = store.lists[1]
            store.current = list.name
        end
        return list
    end

    function owner:Select(name)
        if not FindIn(self:Lists(), name) then return end
        Store().current = name
        self:NotifyChange()
    end

    function owner:Clear()
        wipe(self:Current().items)
        self:NotifyChange()
    end

    -- A name as lists keep it: trimmed, no colons or "|", not too long
    -- (ns.CleanName). Nil when nothing is left.
    function owner:CleanName(name)
        return ns.CleanName(name, SavedLists.MAX_NAME)
    end

    -- A free name based on `name`: "PvE", then "PvE 2", "PvE 3"...
    function owner:FreeName(name)
        return SavedLists.FreeName(self:Lists(), self:CleanName(name) or options.fallbackName)
    end

    -- Adds a list and makes it current. Returns its name, made unique.
    function owner:AddList(name, items, note)
        name = self:FreeName(name)
        table.insert(Store().lists, { name = name, items = CopyItems(items or {}), note = note })
        Store().current = name
        self:NotifyChange()
        return name
    end

    -- Save preset: the current list's items under a new name, which becomes
    -- current. A name already taken by another list replaces that list.
    function owner:SavePreset(name)
        name = self:CleanName(name)
        if not name then return end
        local current = self:Current()
        if name == current.name then return name end
        local items = CopyItems(current.items)
        local existing = FindIn(self:Lists(), name)
        if existing then
            existing.items, existing.note = items, nil
        else
            table.insert(Store().lists, { name = name, items = items })
        end
        Store().current = name
        self:NotifyChange()
        return name
    end

    function owner:Rename(name)
        name = self:CleanName(name)
        local list = self:Current()
        if not name or name == list.name or FindIn(self:Lists(), name) then return end
        list.name = name
        Store().current = name
        self:NotifyChange()
        return name
    end

    -- Deletes the current list; the one before it (or the first) takes over.
    -- Deleting the last list leaves an empty one under the default name
    -- (Store() adds it).
    function owner:Delete()
        local store = Store()
        local _, index = FindIn(store.lists, self:Current().name)
        table.remove(store.lists, index)
        local nextList = store.lists[math.max(1, index - 1)] or Store().lists[1]
        store.current = nextList.name
        self:NotifyChange()
    end

    -- Replaces the current list's items.
    function owner:Replace(items, note)
        local list = self:Current()
        list.items = CopyItems(items)
        list.note = note
        self:NotifyChange()
    end
end
