# Readable code

How NeedRoll's Lua should read, so a developer who has never seen the addon
can open any file and follow it. These are Mike's rules (2026-10-17). The
implementer agent writes to them and the reviewer agent checks every change
against them (`.claude/agents/`).

The aim is less code, never less addon: cut what is repeated or unused, but
not anything that changes what a player sees, what is saved, or what is sent.

## 1. Meaningful names

A name says what the value is in the game's terms: a boss, an encounter, a
quest, a drop, a row, a pane.

```lua
-- Hard to read: what is d? what is t?
local d = GetTime() - t
if d > 60 then Send(d) end

-- Readable
local secondsSinceLastSend = GetTime() - lastSendTime
if secondsSinceLastSend > SEND_INTERVAL then Send(secondsSinceLastSend) end
```

- Functions are verbs that say what they do (`ShowBossLoot`, `CountUsableItems`),
  values are nouns (`bossName`, `usableCount`).
- Booleans read as a yes/no question: `isOpen`, `hasLoot`, `canShare`.
- Loop variables can be short only when the loop is a few lines and the table
  says what they are (`for _, quest in ipairs(quests)`), never `for k, v` over
  anything that isn't a plain map of unknown keys.
- Fixed numbers get a named constant with the unit in the name or a comment:
  `local SEND_INTERVAL = 60 -- seconds between messages`.

## 2. Consistent formatting

- 4-space indents, LF endings, UTF-8 (`.editorconfig`; the Lua extension's
  formatter in VS Code reads it).
- New and changed lines up to 120 characters. Some older lines run longer;
  shorten them when you touch them. The locale files are generated and keep
  one phrase per line however long it is.
- Game calls are written the way Ketho's WoW API annotations
  (`ketho.wow-api`) and warcraft.wiki.gg write them: `C_Item.GetItemInfo(itemID)`,
  `frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)`, event names in
  capitals as strings. Use the `C_` namespace calls Forever has, not the old
  globals.
- One statement per line, except a one-line guard (`if not frame then return end`).

## 3. Single responsibility functions

A function does one thing its name can say. A function that builds a row,
fills it and also decides what the pane scrolls to is three functions.
When a function grows past a screen (about 60 lines), look for the parts that
have their own name.

## 4. Low indentation and guard clauses

Return early instead of nesting the whole body inside an `if`.

```lua
-- Deep
local function ShowLoot(boss)
    if boss then
        if boss.loot then
            for _, item in ipairs(boss.loot) do ... end
        end
    end
end

-- Flat
local function ShowLoot(boss)
    if not (boss and boss.loot) then return end
    for _, item in ipairs(boss.loot) do ... end
end
```

More than three levels of indentation inside a function is a sign to pull a
piece out.

## 5. Thoughtful comments

Write for someone new to the addon and new to WoW addons. Explain it the
way you would to a friend: plain words, the reason behind the code, and the
game fact that forces it. Don't leave out the substance.

- Say why, not what. `-- Item info may not be loaded yet on first ask, so
  wait for the game to send it` helps; `-- get the item info` doesn't.
- Name the game behaviour behind odd code: secret values, the 60-upvalue
  limit, the 200 locals a file's main chunk can hold, SavedVariables saving
  only on `/reload`, logout or exit.
- No narration of the change ("Now we...", "Updated to...", "Refactored"),
  no restating the line below, no headers over a single line.
- A comment that is wrong is worse than none: fix or delete it with the code.

## 6. Code consistency

Do the same thing the same way everywhere. Before writing a helper, find the
one the addon already has (`Theme:Pill`, `Theme:Row`, `ns:On`, `ns.Items:Load`
and the rest; see `.claude/agents/implementer.md`) and use it. Two copies of
a helper become one.

## 7. Searchable names

Anything used in more than one place has a name you can grep for: constants
instead of repeated numbers or strings, one function instead of the same
three lines in four places. Settings keys and saved-data keys keep their
exact names, since players' SavedVariables use them.

## 8. Avoid mental mapping

A reader shouldn't have to remember that `e` means "encounter" or that `p` is
the pin. Spell it out. The only short names the addon keeps on purpose are
- `_, ns` from `local _, ns = ...` at the top of every file (the addon's
  shared namespace) and `L`, the translations table;
- the short UI aliases listed at the top of `NeedRoll/UI/Theme.lua` (`C`,
  `F`, `UI`), used in thousands of places and explained once there. The
  others in that list are whole words: `Theme` (`ns.Theme`), `Size` (its
  layout sizes), `instance` (a dungeon, raid, vendor list, collection or
  profession), `encounter` (one of its encounters) and `entry` (one item of
  a list: a row's data in a list or loot pane, a shopping or wishlist item,
  an outbox record);
- `W`, the stand-in game client in `tests/smoke/`;
- the usual math and layout names inside a few lines that make them plain:
  `i` for a loop index, `x`/`y`/`w`/`h` for positions and sizes, `r`/`g`/`b`/`a`
  for color channels.

## 9. Avoid disinformation

A name or comment must not say something the code doesn't do. A function
called `GetBoss` that also changes the selection, a `bossList` that is a
map, or a comment about a setting that was removed all mislead the next
reader. Rename or fix them.

## Behaviour stays the same

A readability change keeps:

- what the player sees and can click, pixel for pixel;
- SavedVariables keys and formats (players' saved data must keep loading);
- addon message formats (older copies must still understand them);
- `L["..."]` keys (renaming one breaks every translation of it);
- public names other addons call (`NeedRoll_Show*`, `docs/API.md`).

Generated data under `NeedRoll/Data/` is rewritten by the scraper, so it is
never hand-edited; change the generator instead.
