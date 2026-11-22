# Translations

NeedRoll's own text (buttons, labels, tooltips, chat lines) goes through
`ns.L` with the English text as the key, e.g. `L["Shopping List"]`. Names the
game supplies (items, spells, factions) are already in the game's language.

## NeedRoll's language

NeedRoll's text is in the client's language (`GetLocale()`, with enGB as
English) unless the player picks another in Settings, General, Language:
Game language or one of the 11 languages NeedRoll has (`ns.LANGUAGES` in
`Locales/Locales.lua`, each named in its own language). The pick is saved in
`NeedRollDB.language` (nil for Game language); `/nr language <code|game>`
does the same. `ns.Language()` is the language picked (else the client's,
`ns.ClientLanguage()`): what the text loads in at the next reload.
`ns.loadedLanguage` is the one this session's phrases loaded in, the
language on screen, and `ns.Phrases(locale)` fills `ns.L` only for that
one. `ns.LanguageNeedsReload(code)` says whether a pick would change the
text; Settings and `/nr language` promise a reload only then.

Hundreds of `L[...]` lookups run while the addon's files load, so the
language must be known before they run: the .toc's
`## LoadSavedVariablesFirst: 1` has the game load `NeedRollDB` before the
files (modern clients honour it; whether WoW: Forever does is still to be
checked in game), and a new pick shows after the interface reloads, which
Settings offers in a dialog when the text would change. If the game loaded
the files first, the pick can't apply: `Core/Init.lua` then says so in chat
at login ("NeedRoll couldn't switch to the language picked in Settings on
this client."). Nothing at file scope may overwrite
`NeedRollDB`: only `Core/Init.lua`'s ADDON_LOADED handler fills it in. The
smoke run (`tests/smoke/run.lua`) sets `NeedRollDB` before loading the files
when the .toc has the line.

Only NeedRoll's own phrases switch, the fixed labels in the data among them
(recipe sources, collection groups, wing names, attunement notes; see
"Names in the data"). Names from the game (items, places, creatures,
quests) and the NPC and quest name tables keep following the client
(`GetLocale()`), and so do the recipe list's English rank words
(`UI/RecipeBand.lua`, part of item names). The translation
notice (`UI/Welcome.lua`) follows `ns.loadedLanguage`: a player reading
NeedRoll in English isn't asked to help translate.

## Fonts

NeedRoll's fonts are font families (`CreateFontFamily`, `UI/Theme.lua`), as
the game's own are in its Fonts.xml: a member per alphabet, so a character
the client's own font lacks comes from another member. A player who picks
Russian, Korean or Chinese on another client gets that alphabet from its
member. See `docs/STYLE-GUIDE.md` (Fonts) for the members.

The game draws a whole line of Russian text in the russian member,
`FRIZQT___CYR.TTF`, which has no "·" (U+00B7). Wherever Russian text shows
(a ruRU client, or NeedRoll's language Russian) NeedRoll writes "∙"
(U+2219) instead, `ns.DOT`: every phrase's "·" is swapped as it loads, so
translators keep writing "·". The Chinese fonts have "·" but no "∙", and
the "·" in Chinese NPC and quest names stays.

## Names in the data

The data files stay English. On any other client `Core/Names.lua` asks the
game for each name by its ID after login and rewrites the loaded data in
place, so lists, pages, search and item tooltips show the game's own names:

| What | From |
| --- | --- |
| Dungeons, raids, battlegrounds | `GetRealZoneText(instance map ID)` (`Data/Maps.lua` map IDs) |
| Zones | `C_Map.GetMapInfo(uiMapID)` |
| Factions, PvP reputations | the reputation's name by faction ID |
| Recipes, herbs, fish | spell and item names |
| Bosses, quest givers, droppers, recipe vendors | `Locales/NpcNames/<locale>.lua`, by NPC ID (see below) |
| Quest titles and objectives | `Locales/QuestNames/<locale>.lua`, by quest ID (see below) |
| Item sets | the set line ("Name (0/8)") of the set's first item |
| Standings, class names | the game's own strings |

NPC, quest and set names arrive from the server a moment after the first ask,
so they are asked for in the background (a few a second, never in combat) and
kept in `NeedRollDB.names` for the next session. Fixed labels in the data
(wing names, recipe sources, PvP ranks, collection groups, attunement notes)
are `L["..."]` phrases in `Core/Names.lua`, and map level names in
`UI/Overview.lua`, so they follow NeedRoll's language. Place names the game
has but NeedRoll can't ask it for (the WoW: Forever dungeons still without a
map ID, a few zones such as Blackrock Mountain) are phrases too, in
`Core/Names.lua`'s `PLACES`, but they stand in for the game's names: they
follow the client like the game's, so they are translated only on a client
in another language. On a client in another language with English picked
they read in English, the phrase's own text. An English client asks the game
for nothing and keeps the data's names as written, places included (the
dungeons without a map ID are recognised from inside by the English name
the game gives, `ns.Data:IsPlayerInside`); with another language picked
there, `Core/Names.lua` writes in only the fixed labels (a wing's label
around the client's name for the instance). With English text on an English
client the data is left alone. To test the
game's names on an English client (dev builds only):
`/run NeedRollDB.namesTest = true`, then `/reload`.

WoW: Forever hands addons creature and quest tooltips as a "secret" they
can't read, so NPC names and quest titles and objectives come from the
translated server databases instead: AzerothCore's `*_template_locale`
tables first, then MaNGOS Zero's `Translations/` (both GPL).
`py tools/game_names.py` downloads them (cached in `scraper/cache/game_names`)
and writes one NPC table and one quest table per language for everything the
data names. An NPC missing from a table reads the same as in English; a
quest missing from one (the quests new in WoW: Forever) stays English.
NPCs new in WoW: Forever aren't in either database: the script lists those
in `Locales/NpcNames/Forever.lua` as phrases, so they are translated in
NeedRoll-Locales like the rest. Rerun it after a data change adds NPCs.
Brazilian Portuguese has no tables, and Italian only small ones.

Lore notes (`Data/Lore.lua`), raid attunement notes and quest givers that
are objects are phrases in the list like the rest of the addon's text.

Still English: quest givers inside instances with no NPC ID in the data, Forever instances without a map ID yet (Hall of Thanes, Ruins of
Lordaeron, Excavation Site, City of Dalaran, The Drowned City, Krol'dok
Stronghold, Alcaz Prison, Blackmaw Hold, Shaper's Terrace, Hyjal Summit),
Hyjal bosses without NPC IDs, and Collections bosses and holiday boxes
listed without an ID.

## The phrase list

- `NeedRoll/Locales/enUS.lua` lists every phrase. `py tools/locales.py`
  rewrites it from the code; the Lua check fails a PR that adds an `L["..."]`
  without rerunning it.
- Every other `Locales/<lang>.lua` holds that language's translations, one
  `L["English"] = "Translation"` line each, under the header
  `local L = ns.Phrases("<lang>")` / `if not L then return end`. A phrase
  nobody has translated shows in English.
- Dev builds keep every language's phrases loaded. `/nr devedit` has a
  Language preview button that swaps them in, to check how long text fits.
  Only text drawn after the switch changes: labels set up at login and
  names from the game stay in the client's language, and `/reload` goes
  back. Korean and Chinese may show as boxes in the game's own fonts on
  clients without them.

## Where translations come from

Players translate in the public repository
[mikebvs/NeedRoll-Locales](https://github.com/mikebvs/NeedRoll-Locales),
which holds only the locale files and the translator guide, so the rest of
NeedRoll stays private. The Translations workflow
(`.github/workflows/translations.yml`) links the two:

- When `enUS.lua` changes on dev, it copies it to the public repo (needs the
  `LOCALES_TOKEN` secret: a fine-grained token with Contents read and write
  on NeedRoll-Locales only).
- Every day, and from its "Run workflow" button, it copies the public repo's
  language files here and opens a "[Reload] Translations from
  NeedRoll-Locales" pull request into dev. Merged, they ship with the next
  release like any other change.

Edit translations in the public repo, never here: the next sync would
overwrite them. `py tools/translations.py` checks the language files (also
in the Lua check and in the public repo's own check): each line must be a
plain phrase, so a pull request can't slip code into players' games, and a
translation keeps its key's `%s`/`%d` codes in the same order.

The CurseForge localization page (the packager's `@localization@` keyword)
is no longer used: the v0.9.1 release failed with "You do not have
permission to manage localization on this project".

## Writing new text

- Always a literal key on one line: `L["Requires %s %d"]:format(name, skill)`,
  never `L[var]` or `"Requires " .. name`.
- One key per whole sentence, so translators can reorder it.
- Never translate strings the code compares, stores in SavedVariables or
  sends to other players.

## Locale safety

Everything NeedRoll takes from the game or hands to it has to work on all
11 clients (root `CLAUDE.md`). The Locale tests (`tests/smoke/check.sh
--locale <code>`, see `tests/smoke/README.md`) run the smoke tests as each
client. The sweep of November 2026 (Mike, 2026-11-11) found:

| Where | What depends on the client's language | Status |
| --- | --- | --- |
| `Core/Drops.lua` `Whispers.BouncedName` | Reads the game's "no player named" line (`ERR_CHAT_PLAYER_NOT_FOUND_S`). Korean writes it with a particle pick (`\|1이라는;라는;`), so a bounced whisper was never seen there. | Fixed: `ns.GameTextPatterns` (`Core/Init.lua`) |
| `UI/TierSets.lua` | Set bonus lines (`ITEM_SET_BONUS`, `ITEM_SET_BONUS_GRAY`, Russian with a plural pick). | Safe, now through `ns.GameTextPatterns` |
| `UI/LootGrid.lua` `OtherClassOnly` | Split an item's "Classes:" line on "," only; Chinese clients write "、" or "，". | Fixed: `LIST_DELIMITER`, `PLAYER_LIST_DELIMITER` |
| `UI/Search.lua` | A council boss's result carried `fold`, which a loot list takes for a boss fold row: it errored once it scrolled into view (on any client; first on others, where no dungeon name matched and bosses came first). | Fixed on dev by #884 (`bossFold`) |
| `UI/DevKit.lua`, `UI/IconDebug.lua`, `UI/FrameDebug.lua`, `Data/DevDungeons.lua` | The debug windows' headings and labels and Alcaz Prison's dev map credit had a typed "·", a box on a Russian client. | Fixed: `ns.DOT`, `ns.WithDots` |
| `Locales/zhTW.lua` | One phrase had "魇", the simplified form, which `blei00d.TTF` lacks. | Fixed here to "魘"; needs the same fix in NeedRoll-Locales |
| `UI/MainFrame.lua` map pin macro | `/mappin` has other names (ruRU `/координаты`). | Fixed in #885 (`SLASH_MAPPIN1`); the Locale tests check every macro |
| `UI/RecipeBand.lua` groups and rank lines | Read off the recipes' English names. | Safe by event order: NeedRoll's `ADDON_LOADED` comes before `PLAYER_LOGIN`, where `Core/Names.lua` (and its saved copy) renames; rank words show on English clients only |
| `UI/LootGrid.lua`, `UI/Overview.lua`, `Core/Names.lua` | `ITEM_STARTS_QUEST`, `ITEM_CLASSES_ALLOWED`, `_G[equipLoc]`, `FACTION_STANDING_LABEL*`, `DUNGEON_FLOOR_*`, `LOCALIZED_CLASS_NAMES_*`. | Safe: the game's own strings |
| `UI/Overview.lua` `FillTokens` | `$C` and `$R` come from `UnitClass` and `UnitRace`, in the client's language, also inside English quest text. | Kept: it is the player's own class and race as their game names them |
| `Core/Drops.lua` drop and quest reports | Send `npcName`, `instanceName` (`GetRealZoneText`), quest titles and zones in the sender's language. | Safe: the scraper keys everything by ID; the names only label its unmatched report (`observed.py`) and found list (`quests.py`) |
| `Core/LootLog.lua` | Saves zone and subzone names. | Safe: a local log, compared with the same client's names |
| `Core/Trainers.lua` | Saves names. | Safe: English clients only |
| `API.lua` | Matches `GetRealZoneText` with its own English names table. | Safe |
| `UI/Settings.lua` | `_G["BINDING_NAME_" .. action]`. | Safe: the game's name, the action as fallback |
| `Data/Maps.lua` | Layout maps by file ID. | Safe: the shipped tiles come first; the Locale tests check |
| `UI/Overview.lua` (Crystal Lake), `Core/LootLog.lua` window | English compares and labels. | Left: dev builds only |
| Classes tab: the talent planner's pills at the narrowest window (deDE, esES, esMX, frFR, ptBR); a class questline's column label "Nicht gewählte Alternative" (deDE, frFR, koKR) | Translated text is longer than the room it gets. | Not fixed: needs a layout decision |
