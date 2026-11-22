-- Camp features: what each profession builds at a campsite, for the
-- Professions tab's Camping list and each profession's Overview
-- (UI/ProfessionOverview.lua). Written by hand (not generated), from the
-- WoW: Forever item pages on Wowhead that Mike saved from the beta on
-- 2026-10-31. The game names each item and gives its icon and tooltip, so
-- only the facts ship, with a short effect for the list. Each feature:
--   item         the item that places it (the Horde's, when each side has its own)
--   allianceItem the Alliance's own item, when each side has one (the Faction Banner)
--   name         its English name (shown until the game sends the item's own)
--   profession   the profession list that makes it
--   skill        the skill its recipe needs
--   effect       what it does, in a few words; "%d" takes the number `scale` gives
--   scale        a number that grows with the character's level: { [from
--                level] = number, ... }, as the item's tooltip reckons it
--   adds         the feature it can be placed over: it gives that one's effect too
--   blueprint    the "Blueprint: ..." item that teaches the recipe, and its
--                English name; without one, trainers teach it
-- Where a blueprint drops comes from the loot tables (the Wishlist's
-- sources), so it follows the daily data. Effects are phrases in
-- Locales/enUS.lua, translated like the rest of NeedRoll's text.
local _, ns = ...
local L = ns.L

ns.Data:RegisterCamping({
    features = {
        -- Taught by trainers (skill 20)
        { item = 279981, name = "Basic Campfire Kit", profession = "COOKING", skill = 20,
          effect = L["cooking fire with room for 3 camp features"] },
        { item = 279944, name = "Sharpening Wheel", profession = "BLACKSMITHING", skill = 20,
          effect = L["+%d Strength"], scale = { [1] = 6, [24] = 11, [38] = 20, [52] = 34 } },
        { item = 279950, name = "Reagent Bot", profession = "ENGINEERING", skill = 20,
          effect = L["sells reagents"] },
        { item = 279956, name = "Mana Well", profession = "ALCHEMY", skill = 20,
          effect = L["+%d mana every 5 sec"], scale = { [1] = 10, [24] = 15, [34] = 20, [44] = 24, [54] = 29 } },
        { item = 279960, name = "Lodestone", profession = "MINING", skill = 20,
          effect = L["+%d Attack Power"],
          scale = { [1] = 12, [12] = 20, [22] = 32, [32] = 49, [42] = 67, [52] = 90 } },
        { item = 279962, name = "Incense Candle", profession = "HERBALISM", skill = 20,
          effect = L["+%d Intellect"], scale = { [1] = 2, [14] = 6, [28] = 12, [42] = 18, [56] = 25 } },
        { item = 279967, name = "Fish Bowl", profession = "FISHING", skill = 20,
          effect = L["+8% to all stats"] },
        { item = 279968, name = "First Aid Kit", profession = "FIRST_AID", skill = 20,
          effect = L["+%d Stamina"], scale = { [1] = 3, [12] = 8, [24] = 21, [36] = 34, [48] = 45, [60] = 56 } },
        { item = 279972, allianceItem = 279973, name = "Faction Banner", profession = "TAILORING", skill = 20,
          effect = L["+%d Spirit"], scale = { [1] = 14, [40] = 19, [50] = 27, [60] = 32 } },
        { item = 279976, name = "Enchanted Lute", profession = "ENCHANTING", skill = 20,
          effect = L["+%d Armor, +13 stats, +22 resistances"],
          scale = { [1] = 28, [10] = 71, [20] = 114, [30] = 163, [40] = 211, [50] = 260, [60] = 308 } },
        { item = 279978, name = "Camp Tent", profession = "LEATHERWORKING", skill = 20,
          effect = L["Rested XP up to 5% of a level"] },
        { item = 279979, name = "Camp Chair", profession = "SKINNING", skill = 20,
          effect = L["+2% critical strike chance"] },

        -- From blueprints
        { item = 279961, name = "Journeyman Campfire Kit", profession = "COOKING", skill = 90,
          effect = L["cooking fire with room for 5 camp features"],
          blueprint = 273087, blueprintName = "Blueprint: Journeyman Campfire" },
        { item = 279940, name = "Toxin Study", profession = "FIRST_AID", skill = 140,
          effect = L["healing potions and anti-venom"], adds = 279968,
          blueprint = 273105, blueprintName = "Blueprint: Toxin Study" },
        { item = 279941, name = "Tanning Rack", profession = "LEATHERWORKING", skill = 140,
          effect = L["makes certain reagents"], adds = 279978,
          blueprint = 273096, blueprintName = "Blueprint: Tanning Rack" },
        { item = 279943, name = "Spinning Wheel", profession = "TAILORING", skill = 140,
          effect = L["makes certain reagents"], adds = 279972,
          blueprint = 273099, blueprintName = "Blueprint: Spinning Wheel" },
        { item = 279948, name = "Rock Garden", profession = "MINING", skill = 140,
          effect = L["grows a mining node"], adds = 279960,
          blueprint = 273097, blueprintName = "Blueprint: Rock Garden" },
        { item = 279949, name = "Repair Bot", profession = "ENGINEERING", skill = 140,
          effect = L["repairs gear and sells reagents"],
          blueprint = 273092, blueprintName = "Blueprint: Repair Bot" },
        { item = 279957, name = "Cookie's Feast", profession = "COOKING", skill = 140,
          effect = L["food that raises Stamina"],
          blueprint = 273102, blueprintName = "Blueprint: Cookie's Feast" },
        { item = 279964, name = "Greenhouse", profession = "HERBALISM", skill = 140,
          effect = L["grows herbs from seeds"], adds = 279962,
          blueprint = 273106, blueprintName = "Blueprint: Greenhouse" },
        { item = 279965, name = "Fishing Rack", profession = "FISHING", skill = 140,
          effect = L["uncommon fish and fishing lures"], adds = 279967,
          blueprint = 273141, blueprintName = "Blueprint: Fishing Rack" },
        { item = 279969, name = "Field Guide", profession = "SKINNING", skill = 140,
          effect = L["Track Beasts"], adds = 279979,
          blueprint = 273098, blueprintName = "Blueprint: Field Guide" },
        { item = 279970, name = "Fermenter", profession = "ALCHEMY", skill = 140,
          effect = L["makes certain reagents"], adds = 279956,
          blueprint = 273085, blueprintName = "Blueprint: Fermenter" },
        { item = 279985, name = "Arcane Salvager", profession = "ENCHANTING", skill = 140,
          effect = L["better disenchanting"], adds = 279976,
          blueprint = 273103, blueprintName = "Blueprint: Arcane Salvager" },
        { item = 279988, name = "Anvil", profession = "BLACKSMITHING", skill = 140,
          effect = L["needed for some recipes"], adds = 279944,
          blueprint = 273086, blueprintName = "Blueprint: Anvil" },
        { item = 279974, name = "Expert Campfire Kit", profession = "COOKING", skill = 200,
          effect = L["cooking fire with room for 10 camp features"],
          blueprint = 273101, blueprintName = "Blueprint: Expert Campfire" },
        { item = 279938, name = "Trapper's Workbench", profession = "SKINNING", skill = 300,
          effect = L["holds 1 trap"], adds = 279979,
          blueprint = 273109, blueprintName = "Blueprint: Trapper's Workbench" },
        { item = 279945, name = "Sewing Machine", profession = "LEATHERWORKING", skill = 300,
          effect = L["needed for some recipes"], adds = 279978,
          blueprint = 273121, blueprintName = "Blueprint: Sewing Machine" },
        { item = 279947, name = "Seed Hybridizer", profession = "HERBALISM", skill = 300,
          effect = L["multiplies and combines seeds"], adds = 279962,
          blueprint = 273120, blueprintName = "Blueprint: Seed Hybridizer" },
        { item = 279951, name = "Plague Doctor's Laboratory", profession = "FIRST_AID", skill = 300,
          effect = L["healing potions and poultices"], adds = 279968,
          blueprint = 273118, blueprintName = "Blueprint: Plague Doctor's Laboratory" },
        { item = 279952, name = "Molten Foundry", profession = "MINING", skill = 300,
          effect = L["needed for some recipes"], adds = 279960,
          blueprint = 273122, blueprintName = "Blueprint: Molten Foundry" },
        { item = 279955, name = "Master Forge", profession = "BLACKSMITHING", skill = 300,
          effect = L["needed for some recipes"], adds = 279944,
          blueprint = 273113, blueprintName = "Blueprint: Master Forge" },
        { item = 279959, name = "Loom", profession = "TAILORING", skill = 300,
          effect = L["needed for some recipes"], adds = 279972,
          blueprint = 273124, blueprintName = "Blueprint: Loom" },
        { item = 279966, name = "Fishing Hut", profession = "FISHING", skill = 300,
          effect = L["rare fish and fishing lures"], adds = 279967,
          blueprint = 273119, blueprintName = "Blueprint: Fishing Hut" },
        { item = 279982, name = "Iron Oven", profession = "COOKING", skill = 300,
          effect = L["needed for the top cooking recipes"],
          blueprint = 273115, blueprintName = "Blueprint: Iron Oven" },
        { item = 279987, name = "Arcane Forge", profession = "ENCHANTING", skill = 300,
          effect = L["needed for some recipes"], adds = 279976,
          blueprint = 273116, blueprintName = "Blueprint: Arcane Forge" },
        { item = 279989, name = "Anarchist's Workbench", profession = "ENGINEERING", skill = 300,
          effect = L["needed for some recipes"],
          blueprint = 273117, blueprintName = "Blueprint: Anarchist's Workbench" },
        { item = 279990, name = "Alchemy Laboratory", profession = "ALCHEMY", skill = 300,
          effect = L["needed for some recipes"], adds = 279956,
          blueprint = 273112, blueprintName = "Blueprint: Alchemy Laboratory" },
    },
})
