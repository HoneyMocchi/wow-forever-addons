-- Fixes to which dungeon quests start inside their dungeon (the portal after
-- a quest's name), for quests the scraped data gets wrong or doesn't know.
-- Written by hand: mark quests in game with /nr devedit, then paste what
-- /nr devexport gives into the table below.
--   instance ID = { [quest ID] = true (starts inside) or false (doesn't) }
-- A table in place of true also replaces the quest page's "Started by":
--   { giver = "Name" }: "From Name within <dungeon>"
--   { looted = "behind X" }: "Started from [its item] looted within <dungeon> behind X"
local _, ns = ...

ns.Data:RegisterQuestStarts({
    EXCAVATION_SITE_WETLANDS = { [95795] = true },
    HALL_OF_THANES = {
        [96395] = { giver = "Ghostly Attendant" },          -- An Ancient Grudge
        [98423] = { looted = "behind Durgen Dirgehammer" }, -- The Treaty of Understanding
    },
    RUINS_OF_LORDAERON = {
        [92415] = { looted = "near Rath'mael" },            -- Remember That I Love You
        [95250] = { giver = "Captain Truman" },             -- Abominable Creatures
    },
})
