# NeedRoll for addon authors

NeedRoll has global functions other addons can call to open it on a page,
say from a button in your own window. Each one returns `true` when NeedRoll
opened, or `false` when it couldn't, and never prints anything in chat.

## NeedRoll_ShowLoot(instance, boss)

Opens a dungeon's or raid's loot on one boss, or on the instance's Overview
when you leave `boss` out.

```lua
NeedRoll_ShowLoot("The Deadmines", "Edwin VanCleef")
NeedRoll_ShowLoot("Molten Core")            -- the Overview
NeedRoll_ShowLoot(36, 639)                  -- instance map ID, boss NPC ID
NeedRoll_ShowLoot(GetInstanceInfo(), "Edwin VanCleef")  -- the instance you're in
```

**instance** can be:

- its name in English or in the player's language ("Die Todesminen" on a
  German client), as `GetInstanceInfo()` returns it inside;
- its instance map ID (the 8th value of `GetInstanceInfo()`);
- NeedRoll's own ID ("DEADMINES", "SM_LIBRARY").

The dungeons new in WoW: Forever (Hall of Thanes, City of Dalaran and the
others) have no instance map ID in NeedRoll yet, so pass those by their
English name or NeedRoll's ID.

**boss** can be:

- the boss's name in English or in the player's language;
- the boss's NPC ID;
- NeedRoll's encounter ID ("VANCLEEF");
- `nil` or `""` for the Overview.

With a boss you can leave `instance` out (`nil`), and NeedRoll finds the
dungeon or raid the boss is in: `NeedRoll_ShowLoot(nil, 639)`.

Names ignore case, spaces, punctuation and a leading "The", so
"deadmines" and "mr smite" work.

Scarlet Monastery, Dire Maul, Stratholme and Blackrock Spire are split into
wings in NeedRoll. Pass the whole place ("Scarlet Monastery") with a boss and
NeedRoll opens the wing that boss is in. The whole place without a boss opens
its first wing. Bosses that share an encounter, like the Ring of Law in
Blackrock Depths, open that encounter on their own section.

It returns `false` and leaves NeedRoll as it was when:

- the instance or boss isn't one NeedRoll knows (a boss must be in that instance);
- the player turned that tab (Dungeons or Raids) off in NeedRoll's settings.

## NeedRoll_ShowMap(instance, boss)

Opens a dungeon's or raid's layout map. With a boss, the map opens on the
floor the boss is on, with the boss's pin lit. Without one, it opens on the
floor the player last looked at (the first floor at first). `instance` and
`boss` take the same values as `NeedRoll_ShowLoot`.

```lua
NeedRoll_ShowMap("The Deadmines", "Edwin VanCleef")
NeedRoll_ShowMap(409)                       -- Molten Core's map
```

It returns `false` for an instance with no map in NeedRoll, or a boss that
has no pin on it.

## NeedRoll_ShowQuest(quest)

Opens a dungeon quest's page, by its quest ID or its name. By ID it also
opens a step of a quest chain that leads into a dungeon quest (one the
player's side can take): the step's own page on that dungeon, with the
chain's steps listed. A quest that is one of a dungeon's quests opens there
first.

```lua
NeedRoll_ShowQuest(166)                     -- The Defias Brotherhood
NeedRoll_ShowQuest("The Defias Brotherhood")
NeedRoll_ShowQuest(65)                      -- its first step, out in Westfall: on The Deadmines
```

It returns `false` for a quest that isn't one of NeedRoll's dungeon quests
or a step of their chains, or when the player turned Quests off in
NeedRoll's settings.

## NeedRoll_ShowItem(item)

Opens the page where NeedRoll lists an item, with the item highlighted:
the first boss that drops it, else the first vendor list, collection,
recipe that makes it or quest that rewards it. `item` is an item ID or an
item link.

```lua
NeedRoll_ShowItem(5202)                     -- Corsair's Overshirt, on Edwin VanCleef
NeedRoll_ShowItem(itemLink)
```

It returns `false` for an item NeedRoll doesn't list.

## NeedRoll_ShowProfession(profession, recipe)

Opens a profession, on one recipe if you pass it. `recipe` can be its name,
its spell ID, or the item ID of what it makes or of the recipe item that
teaches it.

```lua
NeedRoll_ShowProfession("Alchemy")
NeedRoll_ShowProfession("Alchemy", "Minor Healing Potion")
NeedRoll_ShowProfession("Engineering", 3919)   -- Rough Dynamite's spell ID
```

## NeedRoll_ShowFaction(faction, standing)

Opens a faction's rewards, on one standing if you pass it. `faction` is its
name or faction ID; `standing` is its name ("Revered") or the game's number
for it (4 Neutral to 8 Exalted).

```lua
NeedRoll_ShowFaction("Argent Dawn", "Revered")
NeedRoll_ShowFaction(529, 7)
```

## NeedRoll_ShowPvP(battleground, rank)

Opens a battleground's rewards for the player's side, on one rank or
standing if you pass it.

```lua
NeedRoll_ShowPvP("Alterac Valley")
```

## NeedRoll_ShowCollection(collection, section)

Opens one of the Collections lists (a mount or pet list, item sets, a world
event), on one section if you pass it.

```lua
NeedRoll_ShowCollection("Companions")
```

## Names and numbers everywhere

Every call takes names in English or in the player's language, ignoring
case, spaces, punctuation and a leading "The", and NeedRoll's own IDs. Each
returns `false` without opening anything when the name isn't one NeedRoll
knows, or when the player turned that tab off in NeedRoll's settings.

## Checking that NeedRoll is there

NeedRoll may not be installed, or may load after your addon. Add it to your
`.toc` as an optional dependency so it loads first when it's there:

```
## OptionalDeps: NeedRoll
```

Then check for the function before calling it, and hide your button when it
isn't there:

```lua
if NeedRoll_ShowLoot then
    NeedRoll_ShowLoot("The Deadmines", "Edwin VanCleef")
end
```

Call it from a click or other player action, not while your addon loads:
NeedRoll's window is built the first time it opens.
