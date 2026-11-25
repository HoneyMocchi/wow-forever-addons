# NeedRoll style guide

How NeedRoll looks, taken from the code. **Any change to the UI updates this
file in the same PR.** When the code and this guide disagree, the code is the
truth and this file gets fixed.

Sizes are UI units at window scale 1. "Native" is the default skin (the game's
own frame templates); "modern", "dark" and "elvui" are NeedRoll's own flat
skins, which share one layout and code path (`not Theme.native`). Where this
guide says "modern" about a look, it means that flat path, in whichever flat
skin's palette, fonts and corners (see Skins). Fonts are made in `UI/Theme.lua`
(`BuildFonts`). `Theme:ScaledFont(font, x)` makes a font family at x times the size,
with the same faces, color and shadow. File references are where each value lives.

## Skins

Each skin is one entry in `SKINS` in `UI/Theme.lua`: its code path (`native`),
its corners, its palette (`palettes`), its fonts' face, flags and shadow, and
the prefix of its global names (fonts and window). `Theme:SetSkin` sets
`Theme.name`, `Theme.native`, `Theme.corners`, `Theme.color` and `Theme.font`
from it. Each skin builds its own window the first time it is used, named
`Theme:WindowName`: `NeedRollNativeFrame`, `NeedRollFrame` (modern),
`NeedRollDarkFrame`, `NeedRollElvUIFrame`.

| Skin | Look | Corners | Fonts |
| --- | --- | --- | --- |
| Native (default) | The game's frame templates, parchment panes, gold headings | rounded (its few NeedRoll boxes) | the game's fonts as font families (see Fonts), native sizes |
| Modern | Navy flat panels (`001021` window, `071B2F` panes, `0A2136` loot pane), pale blue `C1EEFF` text, gold `FCD29F` headings, green `3B875B` accent | rounded | the game's fonts as font families (see Fonts), modern sizes |
| Dark | Modern in neutral greys: `121212` window, `1A1A1A` panes, `1E1E1E` loot pane and popups, off-white `E6E6E6` text (muted, faint, edges, lines and washes at modern's alphas), `333333` selected rows, inputs and pill fill (`hover` at 45%), `262626` section discs, `3A3A3A` questline lines, `4A4A4A` scroll thumb; gold headings, green accent, quest, link and level colors as modern | rounded | as Modern |
| ElvUI | ElvUI's own colors, read from the player's ElvUI (below); square corners and 1px outlines | square | ElvUI's font face and style at modern's sizes |

**ElvUI.** Offered (Settings, `/nr style`) only while ElvUI is loaded
(`C_AddOns.IsAddOnLoaded("ElvUI")`, the `ElvUI` global and its engine's
`media`). Its colors and font are read once, the first time the style is
used, from ElvUI's engine (`E.media`, `E.db.general.fontStyle`); a change
to them in ElvUI shows after a `/reload`. Anything missing takes ElvUI's
default (`ELVUI_DEFAULTS`): backdrop 0.1 grey, see-through backdrop 0.06
grey at 80%, black border, value color `1784D1`, font style OUTLINE, the
game's font. NeedRoll copies none of ElvUI's code, textures or fonts and
calls none of its skinning code; it draws the look from those colors
(`ElvUIPalette`):

- Window: the see-through backdrop (`backdropfadecolor`). Panes, loot pane,
  popups, text and search boxes: the backdrop (`backdropcolor`). Outlines,
  hairlines, box outlines (`inputEdge`), closed section cards and questline
  lines: the border color.
- Accent, selection bar, connector, loot outline, strip line, section card
  edge, disc ring, rules and section dividers, drop rates and notes, scroll
  thumb hover: the value color (`rgbvaluecolor`). Selected rows the value
  color at 35%, hover at 18%, pill outline at 55%, the open section card's
  fill 20% fading to 8%.
- Text and headings white, muted `B0B0B0`, faint and trivial levels
  `808080`, pill hover fill white at 18%, scroll thumb `666666`; quest,
  link, level and quest state colors as modern.
- Fonts: ElvUI's `normFont` (the game's font if the file can't be loaded)
  with its style's flags; an outline style has no drop shadow, a SHADOW
  style keeps one.

A saved ElvUI style shows as Dark while ElvUI isn't loaded, without
changing the saved choice, so it comes back when ElvUI does.

**The goal's purple** (a dungeon questline's goal: its card, ribbon, step
circle, Leads to line, fold row and quest page row): `goal` `B48CFF` (the
outline, ring and bar), `goalFill` `B48CFF` at 14% (18% in Native, over the
parchment) for its tint, `goalText` `D9C6FF` for the words beside it. Modern
sets them, Dark and ElvUI take modern's; it reads on navy, grey and
parchment alike.

**Square corners** (`Theme.corners == "square"`): where the rounded skins
draw `Media/Rounded` and its borders as nine-slices, a square skin draws a
plain color fill and a 1px outline of four lines (`SquareOutline`, from
`Theme:Border`), or for a thick outline (the loot pane, dialogs, menus,
notices) four lines `Theme:LineWidth` wide. This covers `Theme:Rounded`,
`Theme:RoundedOn`, pills, tick boxes, search and text boxes, the content
strip, dialogs, menus, the first-run callout, and the recipe and dungeon
section cards (`Theme:CardBackdrop`, `Theme:SectionCard`: their corner
slices cut from the media's straight edges, the outline square). Plain icons
beside a name (professions in the list, a pet family's or demon's on its
page: `Theme:ShapeIcon`) are left square instead of clipped round; icons in
a ring stay round. The questline page's step circles stay round.

## Window

| What | Value | Where |
| --- | --- | --- |
| Default size | 1040 × 540 | `Theme.size` in `UI/Theme.lua` |
| Smallest size | 960 × 460 | `Theme.size.minWidth` / `minHeight` |
| Header bar | 44 high (modern), 22 (native) | `Theme.size.header`, `MainFrame.lua` |
| Native search row | 34 high (the tab strip's height), between the title bar and the tabs | `NATIVE_SEARCH_ROW` in `MainFrame.lua` |
| Tab strip | 34 high; a tab per module that is on, in this order: Dungeons, Raids, PvP, Factions, Collections, Library, Professions, Shopping List, Wishlist, Classes | `Theme.size.tabs`; `ns.Modules.list` in `Core/Init.lua` |
| Footer | 32 high | `Theme.size.footer` |
| Pane label strip | 42 high | `Theme.size.paneLabel` |
| Instance list / encounter list | 260 / 190 wide; the encounter list 263 on Dungeons and Raids, for quest names, and 315 on Professions, where the filter sidebar (236) stands in the instance list's place, under the profession bar (see Professions tab below) | `Theme.size.instanceList` / `encounterList`; `questList`; `SECOND_WIDTHS` in `MainFrame.lua`; `SIDEBAR_WIDTH` in `UI/RecipeBand.lua` |
| Padding / gutter / edge | 14 / 12 / 8 | `Theme.size.pad` / `gutter` / `edge` |
| Scrolled rows' bottom margin | 7 (half the padding): every scrolling list and page (the lists, the loot grid, Overview and quest pages, the Classes tab's pages, the Wishlist, the Shopping List's columns) cuts a row half in view off this far above its pane's bottom edge, inside the border and rounded corners, never on them. A scrolled column's scroll bar stops there too (the lists' 6 up, the loot grid's and Overview's 14). The Shopping List's columns stand on its gold line (7 up, 22 high), so their rows stop 36 up | `Theme.size.scrollBottom`; `Theme:ScrollView`, `Theme:ScrollColumn` |
| Large text | the window scaled up to fit a 1280×800 screen | `Theme.textScale.large` |

**Title.** The `lootroll-toast-icon-need-up` icon, then "NeedRoll". The icon is
the title font's size + 6 (native) or + 5 (modern), 3 units (native) or 4
(modern) from the name. Native: the pair is centred in the header bar.
Modern: it sits at the left, `pad + 2` in. (`MainFrame.lua`, `TITLE_ICON`)

**Top bar** (search box, its "!", Settings): they sit on a row of their own
above the tabs, so the tabs get the window's whole width: the native
window's search row under its title bar, the modern window's header. All
three are 80% of their row's height, which is 27 in the native search row
(the search box 14 in from the right) and 35 in the modern header. Their fonts and icons grow by the same factor, height ÷ 20 native or
height ÷ 24 modern. The "!" is a round pill as wide as it is tall, the "!" centred in it. The search box is 260 wide (native) or
270 (modern). Its typed text and hint are 4pt under the grown size, so the
native ones are about 12pt and 9.5pt. Its edge art is the box's height, and the
magnifier is 80% of the grown size: about 15 native, 14 modern. The typed text and hint start 6 past the
magnifier. Native, both stop 20 short of the right end, clear of the template's clear button. Modern, the typed
text stops 22 short, clear of the cross, and the hint 8 (the cross only shows once the hint is gone).
(`UI:SizeTopBar` in `MainFrame.lua`, `btn:SetBarHeight` in `Settings.lua`)

**Close and lock.** Native: the X is the template's own, at the title bar's
right. Modern: a 28 square button 8 in from the header's right, two 13 × 1.5
strokes at ±45°, `muted`, `heading` on hover; the search box sits 8 left of
the padlock. The padlock is a 22 square button right against the X's left
edge, centred on it, in both styles, a child of the header at the X's frame
level (native: on the title bar, whose art draws over the header's children
at their own level). It is drawn from
strokes, as the X: a filled 10 × 7 body, its centre 2.5 below the button's,
and a shackle of 1.5 thick strokes, two legs 5 high, each 1 in from the
body's sides, joined by a top across them (8 wide). Locked, both legs stand
on the body. Unlocked, the shackle rises 3: the right leg stays in the body
(8 high) and the left one lifts 3 clear of it, an open padlock. `muted`,
every piece `heading` on hover. Its tooltip (`ANCHOR_BOTTOMLEFT`) names the
click, "Lock window" or "Unlock window", in `Theme.tip.title`, then "Stops the
window being moved by dragging." or "Lets you drag the window to move it." in
`Theme.tip.text`. Locked, presses on the window no longer move it; the
resize grip still works. Saved in `NeedRollDB.window.locked`, shared by both
styles. (`CreateCloseButton`, `LOCK`, `CreateLockButton` in `MainFrame.lua`)

**Saved position.** It's only kept when it's two anchor names and two plain
numbers under 10000. Anything else is dropped and the window opens centred.
(`IsUsableWindowPoint` in `MainFrame.lua`)

**Minimap button.** A LibDBIcon-1.0 button (`LibDBIcon10_NeedRoll`, from
the launcher `NeedRoll`), so minimap addons (SexyMap, HidingBar, ElvUI and
the like) gather and skin it with other addons' buttons. LibDBIcon sets its
size, 31 × 31, its place, centre 5 past the minimap's edge (10 short of a
square minimap's corner), the game's minimap highlight under the mouse and
dragging round the edge. NeedRoll restyles it: the NR logo is 25 in Forever's
bronze ring (32, `BRONZE`), else 20 a pixel above the centre in the gold
tracking border (53, from the top left) on a 24 dark disc (`GOLD`), the
whole logo shown, not LibDBIcon's zoomed-in one. Held down or dragged, the
logo moves a pixel down and right. Left-click toggles the window;
right-click opens it on the Settings page, or shuts it when it is already
there. Tooltip (LibDBIcon's, placed by the button's side of the screen):
"NeedRoll", then "Left-click: Open NeedRoll" and "Right-click: Open NeedRoll
Settings" in `Theme.tip.text`, then "Drag to move." in 0.7 grey.
(`UI/MinimapButton.lua`)

## Fonts

Every font is a font family (`CreateFontFamily`), as the game's own fonts
are, with one member per alphabet at the font's size and flags, so text in
another alphabet (a language picked in Settings) draws in its own member:

| Member | File |
| --- | --- |
| roman | `Fonts\FRIZQT__.TTF` |
| russian | `Fonts\FRIZQT___CYR.TTF` |
| korean | `Fonts\2002.TTF` |
| simplifiedchinese | `Fonts\ARKai_T.ttf` |
| traditionalchinese | `Fonts\blei00d.TTF` |

The client's own alphabet (ruRU russian, koKR korean, zhCN
simplifiedchinese, zhTW traditionalchinese, every other client roman) is
`STANDARD_TEXT_FONT` instead, the same file in practice. ElvUI's style puts
ElvUI's font face in the roman member and the client's own alphabet's, with
ElvUI's flags; the other members keep the game's files. (`ALPHABET_FILES`,
`FontMembers` in `UI/Theme.lua`.) The Modern column is every flat skin's
(Modern, Dark, ElvUI), each skin's in its own palette's colors.

**Separator dot.** Parts of a line are joined with "·" (U+00B7: `Theme.DOTS`,
two spaces either side; `Theme:JoinDots`; one space in recipe learned lines
and notes). Wherever Russian text shows (a ruRU client, or NeedRoll's
language Russian) it is "∙" (U+2219) instead, `ns.DOT` in
`Locales/Locales.lua`: the game draws a line of Russian text all in
`FRIZQT___CYR.TTF`, which has no "·" but has "∙" (the Chinese fonts have "·"
and lack "∙"). Phrases, the data and the code keep writing "·"; the swap is
made as phrases load (`ns.L`), in `Theme.DOTS` and in `Core/Names.lua`'s
part separator.

| Key | Native | Modern | Used for |
| --- | --- | --- | --- |
| `title` | 13 | 15 | window title |
| `heading` | 16 | 17 | pane titles (loot, quest pages) |
| `tab` | 12 | 12 | tabs |
| `body` | 12 | 12 | rows, names, text |
| `suffix` | 8 | 8 | "(40 players)" |
| `small` | 10 | 10 | second lines, notes, chips |
| `source` | 12 | 12 | where a recipe comes from |
| `note` | 10 | 10 | "rare" under a boss |
| `label` | 11 | 10 | section headers |
| `pane` | 13.75 | 12.5 | pane label (1.25 × label); sizes the faction toggles |
| `ruled` | 18 | 18 | a heading over a rule (Description, Attunement, an item chain's item name) |
| `instance` | 22 | 22 | a dungeon's name on its Overview, the talent planner's heading |
| `factLabel` / `factValue` | 16 / 12 | 16 / 12 | Overview stat boxes |
| `section` | 14 | 13 | Overview "Alliance quests" headers |
| `hint` | 10 | 10 | footer hints |

**Text shadow.** Every font has a black shadow down and to the right.
- Native fonts marked as shadowed (headings, body, tabs, labels and the like): 100%, offset 2, −2.
- All other fonts (small, source, note, hint, and every modern font): 70%, offset 1, −1.
- ElvUI's fonts with an outline in their style (its default OUTLINE): no shadow.

(`MakeFont` in `UI/Theme.lua`)

**Colors** come from the skin's palette (`palettes` in `UI/Theme.lua`). Native
uses gold `FFD100` for headings, white for text, grey `A0A0A0` for muted text
and red for droppers (`Theme.color.dropper`). The pill edge and fill are `FFD100`
at 0.55 and 0.22.

Dialogs, menus and notices that open over the window (`Theme:Dialog`,
`Theme:NameDialog`, `Theme:Menu`, the first-run callout and notices) fill with
`Theme.color.popup`: black at 0.92 (native), `0A2136` (modern), `1E1E1E`
(dark), ElvUI's backdrop (elvui).

- **Dialog** (`Theme:Dialog`): over a black 45% shade on the pane, rounded
  with a thick `accent` outline; its title in `heading`, `Size.pad` in, and
  the hint line (`dialog:AddHint`) in `small`, 6 under it. OK and Cancel
  pills at the bottom right, 8 apart.
- **Name dialog** (`Theme:NameDialog`): 360 by 150, one text box 10 under
  the hint, the error in `small`, `incomplete` at the bottom left, Save and
  Cancel. The Wishlist's and the Shopping List's New, Rename and Save
  preset, and renaming a saved talent plan.
- **Menu** (`Theme:Menu`): rows 24 high, 4 in from its sides, 6 above the
  first and below the last; each row's text in `body` 10 in, an optional
  figure in `small` 10 from the right; a hairline (`line`) 4 under a row
  group and 4 above the next. A Delete row asks once ("Click again to
  delete" in `incomplete`). Closes on a click elsewhere or Escape. The
  Wishlist's and the Shopping List's list menus (240 wide), a saved talent plan's menu (180 wide),
  Settings' Language menu and the recipe list's Buff menu (200 wide).

- **First-login notices** (`UI/Welcome.lua`): panels of their own on
  UIParent at `DIALOG` strata, 460 wide (`NOTICE_WIDTH`), 120 above the
  screen's middle, draggable, rounded with a thick `accent` outline. The
  title in `heading` `Size.pad` in, the text in `body` 10 under it
  (`NOTICE_GAP`), wrapped to the width less `Size.pad` each side, and the
  pills at the bottom right, 14 under the last part (`NOTICE_BUTTON_GAP`).
  No close button, and Escape doesn't shut them. The drop sharing notice ("NeedRoll DropTalk
  System Consent") has the game's 24 `UICheckButtonTemplate` tick box under the text (label in
  `small`, ticked as the player's saved Credit my finds) and Share drops / Don't share, 8 apart.
  It isn't shown while drop sharing is switched off for everyone (`Drops.isSharingEnabled`). The translation notice
  ("Help translate NeedRoll", non-English clients only, after the drop
  notice) has two link rows 10 under the text and 6 apart
  (`LINK_ROW_GAP`): "Discord" and "GitHub" in `small` in a 64 column
  (`LINK_LABEL_WIDTH`), then a link box filling the rest; "Copied. Paste it
  in your browser." in `small`, `complete`, at the bottom left beside the
  Got it pill.
- **Link box** (`Theme:LinkBox`): a `Theme:Input` holding one address, read
  only (typing puts it back), selected when focused, for Ctrl+C, since
  addons can't open a browser. The Settings Discord dialog and the
  translation notice.

**Tooltip colors** are the same in every skin (`Theme.tip` in `UI/Theme.lua`):
`title` 0.99, 0.82, 0.62 for the first line; `info` 0.76, 0.93, 1 for
places, labels beside a value and side notes; `hint` 0.5, 0.6, 0.65 for what
a click does; `quiet` 0.6 grey for IDs and asides; `text` white (1, 1, 1) for
values and plain lines; `good` 0.35, 0.77, 0.52 for good news (a drop chance,
a collected look).

## Buttons and chips

| Type | Look | Where |
| --- | --- | --- |
| **Pill** (`Theme:Pill`) | 20 high, rounded (square in ElvUI's style), 1px outline in `pillEdge`, body font. Hover fills it with `pillFill`, and `SetTone` tints it. Width is the text + 24 (+ 30 with a symbol). | Back, Add to shopping list, Loot/Abilities, the "!" by search, Class, Types, All classes and Show all in the loot filters, the level-up window's Abilities chip (local checkouts) |
| **Close cross** (`Theme:CloseButton`) | A square button with the pill's `close` strokes (8 long, 1.5 thick) centred on it, in the skin's `muted` (or a given palette's), `heading` on hover. The caller sizes, places and wires it. | The search box's clear button (14), the flat styles' level-up window close button (20, local checkouts) |
| **Native pill** (`Theme:NativePill`) | A pill in the Native style (gold `pillEdge` FFD100 at 55%, gold `pillFill` FFD100 at 22% on hover, Native `body` font, rounded) whatever style NeedRoll's window uses, so NeedRoll's buttons in the game's own windows look like the game's around them. Made once; a later change of style leaves it as it is. | The zone button on the world map, "Open in NeedRoll" in the quest log |
| **Text tab chip** | The word alone, `small` × 1.05 (`CHIP_WORD_SCALE`). Cream `E6DCC8` at 72%. Hover: full cream with a faint 1px underline at 35%. Picked: gold `FFD100` with a 1px underline as wide as the word, solid across its middle 40% and fading out over the 30% at each end (`Theme:ChipUnderline`, shared by every chip underline). 5 units each side, and a 3px gold dot at 50% between neighbours (1.5 left of the gap's middle). | `UI/RecipeBand.lua` (`Chip`): the dungeon map's floor tabs, the Poisons page's chips and the floor chips on the world map |
| **Settings** | The `EditCrossbars-up-c60` icon (20 on its longer side, 2 in, 4 before the word) and "Settings" in the text tab chip style: cream, brighter on hover, gold with the fading underline while Settings is open. | `Settings:CreateButton` in `UI/Settings.lua` |
| **Label toggle** | Words side by side in `label` (or a given font), each button the word's width + 12. The chosen one is gold and underlined, the line fading out 6 past both ends. `Relabel` shows other words on one (the Drop talk window's match counts) and refits its width. Never for Alliance / Horde: those use the faction toggle. | `Theme:LabelToggle` |
| **Faction toggle** | The stacked Alliance / Horde emblem; see Faction toggles below. | `Theme:FactionToggle` |
| **Section arrow** | `Theme:Arrow(parent, true)`, 21 long, turned open or shut. Group headers and folded recipe sets have it. | `Theme:Arrow` |
| **Remembered sections** | Whether a section, fold or "N more trainers" list is open or shut lasts past leaving its page, a reload or logout, as Settings' Remember sections says (This character by default): the loot pane's sections (Quest Items, Weapons, Armor, Accessories, Professions or on a Factions page each profession, Consumables, Miscellaneous; kept by a fixed key, never the shown name), boss folds (the Ring of Law; by the boss's NPC ID) and PvP class folds (by class, the same on every PvP page), a recipe's and the Classes Overview's whole trainer lists, the middle column's groups (each dungeon's, raid's or profession's own: Encounters, Quests, wings, questlines, colour sets; a Collections set list's class folds; the Classes tab's sections and quest folds), the raid list's Classic Raids, each raid's Attunement heading and each dungeon's or raid's item chain heading (by instance and item ID), a spell's or pet ability's ranks (by its first rank's spell ID), each profession's Overview sections, ranks, zones and specializations, and the Library's bracket and zone folds. A section never opened or shut starts as its own part of this guide says; one opened or shut is kept as open or shut, so one that starts open stays shut. On Off, each is kept only until the game reloads, and a dungeon's groups start over each time another shows. Areas and keys: the comment above `SectionMemory` | `ns.SectionMemory` in `Core/Init.lua` |
| **Tick box** | Modern: a 14 rounded (ElvUI: square) box outlined in `muted`, filled with `accent` and a two-stroke tick when on. Native: the game's 22 `UICheckButtonTemplate`. Its label is `small` in `muted`, 6 (modern) or 2 (native) from the box, and clicking the label works too. A box with a half step greys its tick there (`box:SetMarkMuted`): modern, the tick in `muted` with no `accent` fill (outline still `accent`); native, the game's gold tick desaturated. | `Theme:CheckBox`: the Shopping List's Subtract boxes and the Poisons header's Known (label at the left), the Wishlist's "Leave out shirt and tabard", the filter sidebar's Skill-ups / From trainer / Learnable / Hide grey / Have materials |
| **Search box** (`Theme:SearchBox`) | Native: the game's `SearchBoxTemplate`, 20 high, with its magnifier, grey hint and clear button. Modern: 24 high, rounded, filled with `input` (`3E607F` modern, `333333` dark); ElvUI's style square, ElvUI's backdrop with a 1px `inputEdge` (its border color); a 12 `common-search-magnifyingglass` 9 in, tinted `muted`; the hint in `small` 26 in; a clear cross (the pill's `close` strokes, 8 long, 1.5 thick) in a 14 button 5 in from the right, `muted`, `heading` on hover, shown only while there is text. Typed text sits 26 in from the left and 22 from the right (clear of the cross). Escape and the cross both empty the box. It follows the window's skin unless the caller names one. | The top bar search, Filter recipes, the Library tab's "Search books" (160 wide, in its strip left of Group by zone: see Library tab), and the "All icons" view of `/nr icondebug` (local checkouts): always modern, like the rest of the debug window, 260 wide, 8 in, centred in a 32 strip over the list, with the match count ("N of M atlases match", "M atlases" when empty) in `small`, `muted`, 12 to its right; the list's rows start under the strip (`UI/IconBrowser.lua`); and the Drop talk window (`/nr droptalk`, local checkouts): always modern, 220 wide, top right level with the close button (8 down, 40 in from the right edge), hint "Search all tabs". It filters every tab at once; while there is text each tab reads its name and match count ("Messages (4)"), and an empty tab says `Nothing on this tab matches "<text>".` (`UI/DropTalk.lua`) |
| **Ask-once pill** | A pill whose first click turns it red (`incomplete`) with a "Click again to ..." label for 3 seconds; a second click acts. | `Theme:ConfirmPill`: Clear list on the Shopping List and the Wishlist |

**Chip lines** (text tab chips). The fewest lines the chips fit in, then the
split whose widest line is narrowest. Each line is centred, lines 4 apart
(`LINE_GAP` − 2), with 6 (`LINE_GAP`) under the last. (`Balance`,
`PlaceLines` in `UI/RecipeBand.lua`)

**Section divider** (`Theme:Divider`). The one line between a page's
sections: 1 high, the skin's `divider` (gold `FFD100`; ElvUI's value color in ElvUI's style) at 35% in its middle, fading to clear at
both ends (two halves, each a horizontal gradient). The caller places and
sizes it; it takes no mouse. Used between the filter sidebar's sections (8 above and below it,
`SECTION_GAP`), and over a section's heading row on the pet and demon pages
(every heading but the page's first) and the class Overview's list (every
heading, as the stat boxes sit above the first). On those lists it lies
along the heading row's top edge, from 16 in at the left (`HEADING_LEFT`) to
16 in at the right (`RIGHT_INSET`); the row keeps its 30 height, so nothing
moves.

**Faction toggles.** Every setting that picks Alliance or Horde uses the
one stacked emblem, `Theme:FactionToggle`; no word switches, no pair of
crests side by side.

- Look: the stacked pair a quest both sides take wears (`Theme:DrawCrests`).
  The slot is `Theme:InsigniaSize(Theme.font.pane)` high, that is
  (font + 2) × 1.875 (27 modern, 30 native, at the normal text size), and 1.15 × that wide
  (`CREST_STACK_WIDTH`: 31 / 35). Each insignia (`Theme:Insignia`,
  `UI-Character-Info-Honor-Icon-*`) is 0.83 × the height (`STACKED_CREST`:
  22 / 25). The side shown sits at the top left in front in full colour,
  with a black shadow at 55% 2 bigger, 1.5 down and right. The other side
  sits at the bottom right behind it, desaturated at 0.6 alpha
  (`GREYED_CREST`), its own 45% shadow 1 down and right at 0.6 too.
- Size: the button is exactly the slot, with no padding, and the same size
  on either side, so nothing moves when it's clicked.
- Click: runs the place's pick with the other side; the place redraws it
  with `toggle:SetSide(side)`, which brings that side to the front. A new
  toggle starts on `ns.PlayerFaction()` (so `/nr devedit`'s View as works).
- Tooltip (`ANCHOR_TOP`): the side shown, then in `Theme.tip.text` what a
  click shows, both from the place's own `%s` phrases. The default is
  "Showing Alliance" / "Click to show Horde".

| Where | Picks | Placed | Tooltip |
| --- | --- | --- | --- |
| First pane's header, on tabs whose lists are one side's at a time (PvP, Factions) | the list's side (`UI.state.faction`) | right edge `Size.pad` (14) in from the pane's right, centred `Size.paneLabel` / 2 + 2 (23) under its top; the pane widens if its label, 20 (`FACTION_GAP`) and the toggle don't fit | "Showing Alliance" / "Click to show Horde" |
| A dungeon's Quests header, when some quests are one side's | the quests listed (`UI.state.questSide`); a click while Quests is shut also opens it | right edge 4 right of the figure's left (`SIDE_TOGGLE.NUDGE`); the count under the title stops 4 short of it (`SIDE_TOGGLE.GAP`) | "Alliance quests" / "Click to see Horde quests" |
| The Classes tab's Quests header | the class quests listed (`UI.state.classQuestSide`); a click slides the section open | 4 left of the figure (`SIDE_TOGGLE.GAP`) | "Alliance quests" / "Click to see Horde quests" |
| A raid's open Attunement heading, when the sides' steps differ | the steps shown (`pane.attuneSide`) | right edge at the page text's right, centred 8 above the heading text's bottom | "Alliance attunement" / "Click to see the Horde attunement" |
| An open item chain heading (a dungeon's or raid's Overview), when the sides' steps differ | the steps shown (`pane.attuneSide`, shared with the Attunement) | as the Attunement's | "Showing Alliance" / "Click to show Horde" |
| A profession's Overview heading | the trainers, vendors, quests and zones shown (`page.shownSide`; the character's own each time another profession opens) | right edge 16 in from the page's right (`HEADING_LEFT`), centred on the badge (12 + 17 down) | "Showing Alliance" / "Click to show Horde" |

Not faction toggles: `/nr devedit`'s View as boxes (local checkouts only)
stay two tick boxes, since neither ticked (the character's own side) is a
third state.

**Professions tab.** The body's top is the profession bar, across its whole
width; under it, left to right, the filter sidebar (236, `SIDEBAR_WIDTH` in
`UI/RecipeBand.lua`), the recipe list (315, `SECOND_WIDTHS.PROFESSION` in
`MainFrame.lua`) and the recipe page in the rest, a gutter (12) apart. The
connector draws only its tab from the recipe row into the page, no elbow
(no list stands left of the recipes).

**Profession bar** (`UI/ProfessionBar.lua`): a list panel (`Theme:CreatePanel`)
with a badge per profession list, Camping too, in the professions order
(Lists below), sharing the bar's width (less 6 each side, `BAR_INSET`)
evenly. As tall as a badge: 14 + 36 + 2 + the name's line + the skill's
line + 3 + 2 + 4 (`BADGE`).

| Part | Look |
| --- | --- |
| Icon | The profession's icon (`ns.UI.ProfessionIcon`), 28 (`ICON_SIZE`), cropped and clipped round (`Theme:CropIcon`, `Theme:MaskRound`), inside a 36 ring (`Mode-Selection-Ring-c60`, desaturated; its band takes the frame's outer part, so the icon sits within its inner edge, as the list headers' 23 in 30), 14 under the bar's top, clear of the tab strip, centred on the badge. The ring: grey at 35% (`RING_GREY`), 70% under the mouse (`RING_HOVER`); on the profession open, `discRing` |
| Name | `small`, centred 2 under the ring: `heading` on the profession open, `muted` on one the character hasn't learned, else `text` (Camping, which no one learns, too: `ns.UI.HasSkillLine`). Kept 2 in from the badge's sides (`SIDE_ROOM`); one too long shrinks in steps of 0.05 (`NAME_SHRINK_STEP`) to 0.8 at the most (`NAME_MIN_SCALE`), then is cut short ("Lederverarbeitung" fits at 960 wide) |
| Skill | Only for a profession the character has: "87/150" under the name, `small` × 0.9 (`SKILL_SCALE`), `muted` |
| Underline | On the profession open: a `heading` line 2 high (`UNDERLINE_HEIGHT`), 40 wide at the most and never wider than the badge less 4 each side (`UNDERLINE_WIDTH`, `UNDERLINE_MARGIN`), 4 above the bar's bottom |
| Divider | Between the professions the character has and the rest (none when it has all or none): a 1 wide line in `line`, 10 in from the bar's top and bottom (`DIVIDER_INSET`), centred in 13 of room (`DIVIDER_ROOM`) |
| Tooltip | `ANCHOR_BOTTOM`: the name (`tip.title`), then "Skill 87/150" (`tip.text`) or "Not learned" (`tip.quiet`; neither on Camping), then "443 recipes" (`tip.info`) when it lists any |
| Click | Opens the profession as a click on its row did: a new Back trail, its Overview (or the recipe remembered). Opening it any other way (a recipe link, search, Back) lights its badge too. Learning, unlearning or a skill-up (`SKILL_LINES_CHANGED`) lays the bar out again: at once while it shows, else as it next shows |

**Filter sidebar, top to bottom** (`UI/RecipeBand.lua`): a list panel 236
wide that scrolls as the Settings page does (`ns.Settings.AddScrolling`:
60 a mouse-wheel notch, its scroll bar 4 in from the right), back to the
top for another profession. Its filters sit 10 in from its sides
(`SIDEBAR_PAD`), with 10 under the last. Each section under the Overview
row starts with the section divider (`Theme:Divider`) 8 under what is above
(`SECTION_GAP`), then its heading 8 under that, `small` in `heading`, 6 in
(`TEXT_INSET`), with 4 under it (`HEADING_GAP`). Skinning (no recipes) shows
the Overview row alone. A profession's sidebar is as tall whatever is
picked, ticked or typed.

| Section | Look |
| --- | --- |
| Overview row | See Professions Overview below; 6 under the sidebar's top (`RB.SIDEBAR_TOP`) |
| Slot (chips) | Heading "Slot", or "Type" on the professions whose recipes aren't worn gear (`SCHEMES`). The chips two to a line in chip order, each half the band less 6 (`CHIP_COLUMN_GAP`), 20 high (`CHIP_ROW_HEIGHT`), 1 apart (`CHIP_ROW_GAP`), rounded (`Theme:Rounded`). The word `small` × 1.05 (`CHIP_WORD_SCALE`, as the text tabs') in `text`, 6 in, cut short at least 4 before the count (`CHIP_COUNT_GAP`); the count of recipes it would list (under the tick boxes, buff, range and text filter) at the right, 6 in, `small`, `muted`, every count as wide as the profession's whole count. Hover: the `hover` fill. Picked: the word in `heading` on a `heading` fill at 14% (`PICKED_FILL_ALPHA`). A click picks it; the picked one again goes back to All |
| Show (tick boxes) | Skill-ups, From trainer, Learnable, Hide grey, Have materials as tick boxes (`Theme:CheckBox`), under the heading "Show", one to a line, 6 in (`TEXT_INSET`), each line as tall as its box and 20 at the least (`TOGGLE_ROW_HEIGHT`). Only while the character has the profession. From trainer keeps the recipes whose learned line names a trainer. Learnable has three steps, each click moving to the next: empty (off), a greyed tick (every recipe the character doesn't know, whatever its skill), a full tick (only those its skill reaches now), then empty again; known is `C_SpellBook.IsSpellKnown` (`RB:IsKnown`). Its tooltip names the step and what the next click does. Have materials, last, has three steps the same way: empty (off), a greyed tick (every recipe the character holds each material for, at least its count, in the bags and the character bank together: `C_Item.GetItemCount` plus `Shop:BankCount`, which falls back on the last bank visit's saved count), a full tick (the bags alone), then empty again; a recipe with no materials in the data is left out. Its tooltip names the step the same way. While it is on, bag and bank changes (`BAG_UPDATE_DELAYED`, `BANKFRAME_OPENED`, `PLAYERBANKSLOTS_CHANGED`) narrow the list again, once per burst on the next frame. |
| Buff | Only on a profession whose foods give buffs (Cooking: `Data/FoodBuffs.lua`), with or without the profession. Under the heading "Buff", a box 6 in (`TEXT_INSET`), 18 high (`BUFF_BOX_HEIGHT`, the range boxes' height), as wide as its widest choice ("Any buff" or any of the profession's buffs) plus 8 and 16 (`BUFF_TEXT_INSET`, `BUFF_ARROW_ROOM`), 80 at the least (`BUFF_BOX_MIN_WIDTH`) and never past the sidebar's band less 6, so picking another moves nothing. The box is Settings' Language box's: rounded (`Theme:Rounded`), outlined in `line` (native) or `edge` (modern), filled with `hover` while hovered or its menu is open; its text in `small` 8 in from the left: the buff picked in `heading`, or "Any buff" in `muted`; a down chevron (`Theme:SortMark`, 10 square, two 5 × 1.5 strokes in `heading`) 6 in from the right (`BUFF_ARROW_INSET`). A click opens a `Theme:Menu` 200 wide (`BUFF_MENU_WIDTH`), 4 under the box (`BUFF_MENU_GAP`), lined up with its left edge, on the sidebar (so its scrolling doesn't clip it): "Any buff", a rule, then only the buffs the profession's foods give, in this order: Stamina, Spirit, healing, spell damage, Agility, Strength, Intellect, attack power, movement speed, mana regeneration, health regeneration, each named with the game's own word (`SPELL_STAT1_NAME`-`SPELL_STAT5_NAME`, `STAT_SPELLHEALING`, `STAT_SPELLDAMAGE`, `STAT_ATTACK_POWER`, `STAT_MOVEMENT_SPEED`, `MANA_REGEN`, `ITEM_MOD_HEALTH_REGENERATION_SHORT`) and its recipe count in `small`, `muted` at the right; the one picked in `heading`, the rest in `text`. Picking one keeps only the recipes whose food gives it (Any buff: all); it lasts the session, per profession, like the chips. Escape, a click elsewhere, another profession or the sidebar hiding close the menu. "Filter recipes" also finds foods by these words, after the recipes matched by name and by material ("stamina", "Ausdauer" on a German client) |
| Required skill | The heading "Required skill", then "[ ] to [ ]" and a reset arrow from 6 in (`TEXT_INSET`), parts 8 apart (`RANGE_GAP`). The heading is its own phrase, `L["Required skill"]`, as the other section headings. The line's words come from `L["%s to %s"]`, split at the two `%s` where the boxes go, so a translation can put words before, between or after them ("От [ ] до [ ]"), `small` in `muted`. A part that would run past the band starts a new line, 6 under the last (`RANGE_LINE_GAP`), so a long translation wraps inside the sidebar. Bounds typed the wrong way round (200 to 100) narrow and read as 100 to 200; the boxes keep what was typed. While a bound is being typed the list narrows but the page stays on the recipe being read; once the box is left, a recipe still off the list gives way to the first one listed. The boxes are `Theme:Input` at 36 wide (native: the game's input box, 28 plus its edge art) and 18 high, `small`, centred, digits only, up to 3 (1 to 300, Forever's cap). The reset arrow is `Interface\Buttons\UI-RefreshButton`, 14 square, shown only while a bound is set; its room is kept while hidden. Shows on every profession list whose recipes have skill levels, with or without the profession. Each line 18 high. |
| Recipe count | In the recipe list's strip, not the sidebar: "26 recipes" (`L["%d recipes"]`, the recipes listed), `small`, `muted`, right-aligned 12 in from the list's right (`COUNT_INSET`), centred on the strip; as wide as the profession's whole count + 4 (`COUNT_SLACK`), so the Filter recipes box at its left keeps its width as the list narrows |
| Filter recipes | The search box (`Theme:SearchBox`), 20 high, from 12 in (`RECIPE_FILTER.INSET` in `MainFrame.lua`) to 8 before the count (`RECIPE_FILTER.COUNT_GAP`), centred on the recipe list's strip |

## Settings page

| What | Value | Where |
| --- | --- | --- |
| Title | "Settings" in `heading`, with `EditCrossbars-up-c60` before it (36 on its longer side, centred on the word, 6 before it) | `UI/Settings.lua` |
| Language | The first row of General, before Window style, 30 high: "Language" in `body` at the left (its tooltip: NeedRoll's own text changes, names from the game stay in the game's language) and at the right a box as the key binding's: 20 high, the text plus 10 either side and 80 at the least (`FitBox`), rounded, filled with `hover` and outlined in `line` (native) or `edge` (modern) while hovered or its menu is open, the choice in `label`: the language's own name in `heading`, or "Game language" in `muted`. A click opens a `Theme:Menu` 200 wide (`LANGUAGE_MENU_WIDTH`) 4 under the box, right edges lined up: "Game language", a rule, then English, Deutsch, Español (España), Español (México), Français, Italiano, Português (Brasil), Русский, 한국어, 简体中文, 繁體中文 (`ns.LANGUAGES`, never translated), the one picked in `heading`, the rest in `text`. Picking the one already picked only closes the menu; another saves it and, unless the text is already in that language (the client's own picked by name, or Game language again before a reload: then an open dialog closes), opens a `Theme:Dialog` 360 by 140 (`RELOAD_DIALOG_WIDTH`, `RELOAD_DIALOG_HEIGHT`) titled "Language", its hint in `small` wrapped to the dialog's width less `Size.pad` each side, with Reload now and Later (the Cancel pill relabelled) | `LanguageRow` in `UI/Settings.lua` |
| Window style | A label toggle at the row's right: Native, Modern, Dark, and ElvUI while ElvUI is loaded (`Theme:AvailableSkins`, the choices built with the window's page). At the window's smallest width, at either UI scale, all four fit beside the label | `SkinChoices` in `UI/Settings.lua` |
| Section headings | `section` font over a strip line that fades over its last 10% at each end, from full to 25%. 44 high. General has `EditRadials-up-c60` and Modules has `Spellbook-up-c60` before them (36 on their longer side, as the title's, standing 4 above the line, the word centred beside it, 6 after) | `Heading` in `UI/Settings.lua` |
| Module row icons | 29 on the longer side (a recipe ring 31 for Professions Icons), the name 10 after | `ICON` in `UI/Settings.lua` |
| Sub-rows | A part of a module or setting sits right under it, indented 22: Professions Icons under Professions, Credit my finds under Share drops. While its parent is off it shows Off, greyed out (switch at 35%, label `faint`, note "Needs …"), and keeps its own choice for later | `SUB_INDENT` in `UI/Settings.lua` |
| Drop sources on tooltips | A label toggle at the row's right: On, Off. One switch for both the item tooltips' boss lines and the quest tooltips' quest chain lines (Quest tooltip lines under The game's quest tooltips and quest log). The note under the label: "Bosses on item tooltips, quest chains on quest tooltips"; at the window's smallest width, at either UI scale, it fits on one line before the switch. The label's tooltip names where each shows | `OPTIONS` in `UI/Settings.lua` |
| Remember sections | A label toggle at the row's right: This character, All characters, Off (`SECTION_MEMORY_NAMES`), This character picked until changed. The note under the label: "Open or shut, as you left them". At the window's smallest width, at either UI scale, the three fit beside the label. Its row sits between Collection ticks and Share drops | `SECTION_MEMORY_CHOICES` in `UI/Settings.lua` |
| Run tracker settings | Local checkouts only: "Run progress on screen" and "Boss kill cards", after Minimap button, labels and notes in English until the run tracker ships (see Run tracker) | `OPTIONS` in `UI/Settings.lua` |
| Hidden settings | A setting whose `isHidden` says true gets no row, and the rows after it (the key binding row) take its place. Share drops and Credit my finds are hidden while drop sharing is switched off for everyone (`Drops.isSharingEnabled` in `Core/Drops.lua`); the run tracker's two rows in every release (`ns.Runs.available`) | `isHidden` in `UI/Settings.lua` |
| Quests module | A row of its own, not indented, with the `Exclamation-up-c60` icon: it covers both Dungeons and Raids, so it sits under neither (still no tab of its own) | `own` in `Core/Init.lua` |
| World map marker settings | Three rows, on by default. "Quest givers on the world map" over "Marks where to pick up dungeon and raid quests you can take", under Quests (right after Show only accepted quests) with `QuestNormal`; it needs Quests. "Books on the world map" over "Marks the library books you haven't found yet", under Library with `Campaign-QuestLog-LoreBook`; it needs Library. Both indented 22 as other sub-rows. "Portals on the world map" over "Marks the portals to other cities and zones", right after Books on the world map with `PortalPurple`: a row of its own, not indented (as Quests), as it is part of no tab and needs none | `QUEST_GIVER_MARKERS`, `LIBRARY_BOOK_MARKERS`, `PORTAL_MARKERS` in `Core/Init.lua` |
| Quest log setting | "Open in NeedRoll in the quest log" over the note "The quest chain note and Open in NeedRoll button in a quest's details", a sub-row under Quests (right after Quest givers on the world map), indented 22, with `questlog-questtypeicon-dungeon`; it needs Quests. On by default. Off, the quest log's note and pill hide, at once even with the details open (`QuestChainNotes.Refresh` from `Modules:Set`); the quest tooltip lines stay, as they go with Drop sources on tooltips | `QUEST_LOG_BUTTON` in `Core/Init.lua` |
| Quest map setting | "Show only accepted quests" over the note "When enabled: the dungeon map only shows quests you're on or can pick up inside the instance" (a module row's note wraps to a second line, stopping 24 short of the switch's first word, whatever the window's width), a sub-row under Quests with `Crosshair_lootall_96`. Off by default | `QUEST_MAP_FILTER` in `Core/Init.lua` (`off`) |
| Game hotfixes link | Under the taller column, 16 below it (`HOTFIXES_LINK_GAP`), 18 in from the left: "Game hotfixes" in `small`, `muted`, `text` while hovered; 16 high, as wide as the word (again on show, in case the font arrived late). Its tooltip (`ANCHOR_TOPLEFT`): "Game hotfixes", what the page is in white, "Also: /nr hotfixes" in `Theme.tip.info`. A click opens the Game hotfixes page | `AddHotfixesLink` in `UI/Settings.lua` |

## Game hotfixes page

Blizzard's WoW: Forever hotfix list in NeedRoll's own words (`Data/Hotfixes.lua`), opened by the Settings page's
link or `/nr hotfixes`. No tab of its own.

| What | Value | Where |
| --- | --- | --- |
| Place | In the Settings pane, in the Settings page's place (`UI.hotfixesOpen`); the Settings button stays lit. Back reads "Back to Settings"; Back, a right-click anywhere on the pane or the page, and Escape return to Settings (`UI:SettingsBack`); the Settings button or a tab leaves Settings altogether. It scrolls as the Settings page does (`Settings.AddScrolling`: 60 a wheel notch, the slim scroll bar 8 in from the top and bottom) | `UI:OpenHotfixes` in `UI/MainFrame.lua` |
| Title | "Game hotfixes" in `heading`, 18 in and 14 down, as the Settings title (no icon) | `AddHeader` in `UI/Hotfixes.lua` |
| Subtitle | 4 under the title, in `small` (`muted`): "Blizzard's WoW: Forever hotfix list, in short. Last checked" and the date of `checked` | `AddHeader` |
| Address | A `Theme:LinkBox` 380 wide (`LINK_WIDTH`) holding the post's address, 8 under the subtitle (6 further in, native); a click selects it for Ctrl+C. 10 to its right in `small`: "Click the address and press Ctrl+C to copy it." in `muted`, then after Ctrl+C "Copied. Paste it in your browser." in `complete`, back to the first each time the page shows | `ShowCopyHint` |
| List | From 94 down (`LIST_TOP`: 18 + 44 + 32), each line 18 in from the left and wrapping 16 short of the right edge (`TEXT_RIGHT`), left-justified. Lines are built the first time the page shows; a new width only wraps them again, so nothing moves on a reshow | `LayOutRows` |
| Dates | Each day under its date in `section`, `heading`: the game's own full date in the player's language (`FULLDATE` with `WEEKDAY_*` and `FULLDATE_MONTH_*`: "Monday, November 16 2026"). 18 above each but the first (`DAY_GAP`). Newest day first | `FormatDate` |
| Topics | Blizzard's section names joined with `Theme:JoinDots` ("Classes  ·  Priest") in `small`, `muted`, 8 above (`TOPIC_GAP`); once each time the topic changes within a day. English, from the data, never translated | `BuildRows` |
| Hotfixes | `body` in `text`, 10 in from its topic (`ENTRY_INDENT`), 3 above (`ENTRY_GAP`). English data, never translated | `AddEntryRow` |
| Developers' notes | `small` in `muted`, 22 in (`NOTE_INDENT`), 2 above (`NOTE_GAP`), under the hotfix they belong to | `AddEntryRow` |
| Removed hotfixes | Stay where they were, never hidden: text in `faint`, struck through. A line texture in `muted`, 1 screen pixel high (`PixelUtil.SetHeight`), on `OVERLAY` sublevel 7 over the text, crosses each line the text wraps to (the game's `GetNumLines`), 55% of a line's height down from its top (`STRIKE_DROP`, through the lower-case letters), from 1 before the text to 1 past that line's last word (`STRIKE_OVERHANG`). Line widths are measured word by word (`GetUnboundedStringWidthForText`); where that wrap doesn't give the game's line count, each line but the last spans the text's width and the last is measured. Hovering the text (`ANCHOR_TOPLEFT`): "Removed from Blizzard's list on" and the date, in `Theme.tip.info` | `DrawStrikes` |

## Icons

| What | Size | Where |
| --- | --- | --- |
| Pane label icon | 26, 6 from the label | `LABEL_ICON` in `Lists.lua` |
| Group header disc / its icon | 30 / 23 | `DISC`, `DISC_ICON` |
| List icon (the Collections tab's currency list; the hidden profession list) | 21, cropped 8% (`Theme:CropIcon`) and clipped round (square in ElvUI's style, `Theme:ShapeIcon`), centred `Size.pad` + 10.5 in from the row's left; the name moves right by 29 (the icon + 8). A profession shows its skill spell's icon; the Tarnished Undermine Real list, first on the Collections tab, the currency's own (`C_CurrencyInfo.GetCurrencyInfo`'s `iconFileID`), else `Interface\Icons\INV_Misc_Coin_16` | `LIST_ICON`, `ListIcon` in `Lists.lua` |
| Recipe ring | 24, 6 from the name | `RECIPE_ICON`, `RECIPE_GAP` |
| Quest row faction insignia | `Theme:InsigniaSize(Theme.font.pane)`, that is (font + 2) × 1.875. A both-sides quest stacks them in a slot 1.15 × as wide, each at 0.83 ×, the player's side in front (the faction toggle's look, without the greying). A lone one is centred in that same slot, so every row's icons line up. | `Theme:DrawCrests` |
| Starts-inside portal (list) | 26, left of the insignia | `INSIDE_ICON` |
| Share icon (list) | 20 on its longer side: `socialqueuing-icon-group` fitted whole (`Theme:FitAtlas`), 4 left of the portal, or of the insignia on a quest without one. Only on a quest that can be shared; hovering it says "Shareable: whoever has it can share it with their party" and keeps the row lit, and clicks pass to the row (`ns.UI.HintIcon`) | `SHARE` in `Lists.lua` |
| Class badge (list) | 26: `Mode-Selection-Ring` drawn 1.25 × the badge, the class circle about 1.11 ×, and a dark disc behind with a vignette 1–2px down and to the right. The ring sits left of the share icon, portal and insignia. | `CLASS_BADGE`, `Theme:ClassBadge` |
| Pet family badge (pet page) | 34, the class badge's ring, backdrop and opening with the family's icon in it, cropped 8% and clipped round (`badge:SetIcon`); Pet trainer's `StableMaster` mark fitted whole at 80% of the opening (`BADGE_ATLAS_SHARE`) | `TITLE_BADGE` in `HunterPets.lua`, `Theme:ClassBadge` |
| Class badge (quest page) | 30, scaled to the title and its two lines, 14 from the ring's edge | `TITLE_BADGE`, `Overview.lua` |
| Class badge (Classes tab) | 26 in the class column, 9 before the name; 22 before the sections column's label, 8 from it; 34 before the Overview page's heading, 10 from it | `CLASS_BADGE`, `LABEL_BADGE` in `Classes.lua`; `TITLE_BADGE` in `ClassOverview.lua` |
| Chain step circle (the Classes tab's Quests list) | 28: `CovenantChoice-Offering-Ability-Ring-Venthyr` over a dark fill at 80%. The number is `small` × 1.2, or × 1.05 and 1px right for two digits. It sits where the first quest's name starts, with the name 6 after it. A dungeon's Quests list has questline rows instead (Lists). | `CHAIN_CIRCLE`, `CHAIN_GAP` in `Lists.lua` |
| Boss mini pin (list) | up to 36 | `FLOOR_PIN` |
| Map quest marker | 22 (0.8 × on a boss pin, 0.7 × on another marker) | `MARKER_ICON` |
| Map link arrow / lock | 22 / 20 | `LINK_ICON`, `LOCK_ICON` |
| Map entrance swirl | 28 | `ENTRANCE_ICON` |
| World map quest giver / book / portal markers | 20 / 22 / 22 on the longer side, 1.25 × while hovered | `ICON_SIZES`, `HOVER_GROW` in `WorldMapMarkers.lua` |
| Patrol badge | 15 | `PATROL_BADGE` |
| Loot cell icon | as tall as its name and two lines (the loot grid's fonts) | `ApplyFonts` in `LootGrid.lua` |
| Item icons with a quality edge | the icon trimmed of its baked-in border (8% each side), inside a 1px quality-colored square (modern) or the game's `WhiteIconFrame` tinted (native), 1 or 2 in | `Theme:QualityIcon`, `Theme.iconCrop` |
| Round icons and portraits | masked by the character frame's portrait mask | `Theme.roundMask`, `Theme:MaskRound` |
| NPC giver / dropper marks in text | 1.5 × the text size | `ns.UI.SizeMarkers` |

## Lists

| What | Value |
| --- | --- |
| Row / two-line row | 30 / 40 (`Size.row`, `ROW.NOTE`) |
| Group header / child row / child with a note | 40 / 24 / 36 |
| Child indent / fold indent (a wing's encounters, a class questline's parts, a dungeon questline's quests) | 8 / 22 (`INDENT.FOLD`) |
| Set members (folded recipes) | 18 more indent, no note, no skill |
| Class fold (a Collections set list's) / its sets | 40 (`ROW.NOTE`) / 18 more indent (`INDENT.SET_MEMBER`), as set members |
| Recipe skill number (right edge) | `small`. While the character has the profession, in their skill colour for it: `levelImpossible` (can't learn yet), `levelHard` (orange), `levelFair` (yellow), `levelEasy` (green), `levelTrivial` (grey). Otherwise, and for entries without four skill levels, `muted` (`RB:SkillColor`) |
| Group slide | 0.2 s |
| Active section card | 5 in, 5 rounded corners (`Theme:SectionCard`): the outline solid down 12% of the card and faded out by 80%, over a fill fading from `sectionFill` to clear |

**Factions list.** Each row shows the character's standing with its
faction (`STANDING`, `ShowStanding` in `Lists.lua`; the Factions tab only,
not PvP). The name and zone keep their two lines (the name 6 + half the
row's extra height above the middle, so both stay where a 44 row has them).
A faction's row is 50 high (44 + `STANDING.ROOM` 6), met or not.
At the right of the name's line, `Size.pad` (14) in, in `small`: the
standing's name (the game's `FACTION_STANDING_LABEL<n>`) in the game's
colour for it (`FACTION_BAR_COLORS`, `ns.UI.StandingColor`), or "Not met"
in `faint`; the name stops 8 (`LEVEL_GAP`) short of it. Under the zone, 6
(`BAR_GAP`) down, a bar 3 high (`STANDING.BAR`) from the text's left edge to
14 in from the right: a track in `line` (native: black at 35%,
`Theme.nativeBar.track`), the fill through the current standing (value /
max, full at the last standing, at least 3 long) in the standing's colour,
opaque (native: 80%, `Theme.nativeBar.fillAlpha`). Both have round ends
(`Theme:RoundedBarTexture`, radius 1.5) except in the ElvUI style, square.
A faction not met has no bar. The rows
redraw on UPDATE_FACTION, once per burst (`RedrawStandings` in
`UI/Reputation.lua`).

**Professions order.** The profession bar's badges (and the profession
list, which stays hidden behind the filter sidebar) go in one order
(`ns.UI.KnownProfessionsFirst`). The professions the character has learned come
first: their primary ones (Alchemy, Blacksmithing, Enchanting, Engineering,
Herbalism, Leatherworking, Mining, Skinning, Tailoring), then their
secondary ones (Cooking, First Aid, Fishing), then the rest, Camping among
them; each block keeps the data files' order. Known means the skill line's
rank is above 0 (`ns.UI.SkillRank`), and the blocks go by the list's ID, not
its name (`KNOWN_PROFESSION_BLOCK` in `Lists.lua`). The order is set when
the tab shows its list and again only when a profession is learned or
unlearned (`SKILL_LINES_CHANGED`; a skill-up moves nothing, but changes the
bar's skill numbers); the selection stays put. With nothing remembered, the
tab opens on the first profession.

**Quests list.** Rows are ordered in quest data order. From the right
edge, a row shows its insignia slot, then the portal, then the share icon,
then the class badge; the name stops short of the leftmost.
A quest shares (`ns.Data:QuestShareable`) by the game's own answer while it
is in the quest log (`C_QuestLog.IsPushableQuest`), else by the data's
`shareable`; one no source knows shows no icon.
The Quests header shows "n/m complete" under its title, open or shut,
counting the dungeon's own quests, folded ones included.
A collection whose vendor gives quests (the Tarnished Undermine Real's
weekly "In Demand" quests) is grouped like a dungeon, with no Overview row:
the same Quests group (`Exclamation-up-c60`, shut to start), then its
sections (Trinkets, Cloaks ...) under a "Vendor" group with the `Shop-up-c60`
icon, open to start (`VENDOR_HEADERS`, `HasQuestsGroup` in `Lists.lua`).
A quest opens the same quest page as a dungeon's.

**Questline rows** (a dungeon's Quests, Profession Quests and Other classes;
`UI/DungeonQuestlines.lua`, drawn by `Folds.ShowRow` in `Lists.lua` as the
Classes tab's quest folds are). A quest on a chain of two steps or more
(Data/Chains.lua, the longest chain it is on for the side and your class,
as its quest page's chain) is folded under its questline's row, which sits
where the first of them would: a 36 row (`ROW.CHILD_NOTE`), 8 in
(`INDENT.CHILD`), its name in `body`, `heading` gold, even when picked;
under it in `note` font where you stand (`Questlines.StatusText`: "Not
started  ·  Level 14" or "Next: The Defias Brotherhood" in `muted`,
"Completed" in `complete`; while a quest it counts is in the quest log, the
first of them: "Ready to turn in: The Defias Brotherhood" in `complete`
once its objectives are done, else "Accepted: The Defias Brotherhood" in
`accepted`), cut short 14 (`Size.pad`) from the row's right;
at the right the Attunement heading's plus (`Theme:Arrow`) and 6 left of it
the figure in `small`, level with the name (6 up): "2/8" in `muted`, the
tick (`common-icon-checkmark`, 11) and "8/8" in `complete` once done. A
questline is named after its last quest, or where its chains part at the
end, its last step before they do. Shut to start (then as it was left on
that dungeon, Settings' Remember sections). Open, it lists the dungeon's own quests on the chain, in chain
order, as the usual quest rows 22 in (`INDENT.FOLD`). A click opens the
questline's page in the content pane (picked while it shows) and slides
the fold open (0.2 s); while its page shows, a click slides it open or shut.
A quest opened from the questline's page slides its fold open while Quests
is open. Quests on no chain stay rows of their own. A folded quest that is
its questline's goal (a numbered step done in this dungeon) is marked as the
page marks it (`Folds.ShowGoal`): a 3 wide bar in `goal` down the row's left
(`GOAL_BAR`), the row tinted `goalFill` (a background sublayer over the row's
own), the portal (`PortalPurple`, as tall as the text) before its name, and
its note in `goalText`: "The goal  ·  Step 3 of 4  ·  2 steps away" ("Next
step" when it is the step to do now, "Done" once done, "Ready to turn in"
in `complete` or "Accepted" in `accepted` while it is in the quest log;
`DungeonQuestlines.GoalNote`).

**Recipe list folds.** A series (one set of pieces made in several variants:
colours such as Flame ... Silky or Azure/Cloudy, or roles such as Acolyte's
... Veteran's) is one row titled by the picked variant's shared words
("Acolyte's ×9", "Azure Skyforged ×8") with "n pieces". Before the note sit
the variant picker's dots (`RB:ShowPicker`), 2 under the title, 6 before the
note: a 13 button each, 4 apart, a ring (gold `FFD100` on the picked variant,
cream `E6DCC8` at 90% on hover, else at 35%) around a 1px black gap and a 9
dot in the variant's colour (70% unless picked or hovered). Colour words have
their own colours; a role series' variants take gold, blue, green, red,
purple, white and orange in order. Hovering a dot names its variant, the
words of its first recipe's name no other variant uses ("Guard", "Azure"; a
German compound, the whole name), a click picks it and opens the row. With a slot chip
leaving one piece per variant the series shows as a colour set: "×n" and "n
variants" with a 7px dot in each colour; with one variant left (a filter),
as a gear set. Named gear sets with no variants show "×n" and "n pieces".
Alchemy and Enchanting rank lines show "×n" and "Minor to Major · n ranks"
("n ranks" on non-English clients). Each set row has the section arrow, with
its skill just left of it.

**Set lists by class.** On the Collections tab, a list whose sets carry a
class (Tier Sets, Dungeon Sets, Zul'Gurub Sets, Ahn'Qiraj Sets) lists them
under one fold row per class that has sets there, in the game's class order
(Warrior, Paladin, Hunter, Rogue, Priest, Shaman, Mage, Warlock, Druid;
`TierSets.ClassFolds` in `UI/TierSets.lua`, drawn by `Folds.ShowClassRow` in
`Lists.lua`). A class's row is 40 (`ROW.NOTE`): the class's ring badge
(`Theme:ClassBadge`, 26, `CLASS_BADGE`, as the Classes tab's class column),
14 (`Size.pad`) from the row's left, then 9 (`CLASS_NAME_GAP`) to the name:
the game's name for the class in `body`, in the class's colour
(`ns.UI.SetClassColor`, `C_ClassColor.GetClassColor`). Under the name in
`note` font and `muted`, what it holds: its sets' tiers joined with
`Theme.DOTS` ("T1  ·  T2  ·  T2.5  ·  T3", "D1  ·  D2", "AQ20  ·  AQ40"), or
"1 set" / "n sets" when they have no tier (Zul'Gurub's). At the right the
plus (`Theme:Arrow`), as a wing's row. A click slides it open or shut (0.2
s); the row itself is never picked. Its sets sit 18 further in
(`INDENT.SET_MEMBER`), their note the tier as the data writes it ("T1",
"AQ40", "D1"; none for Zul'Gurub's), the class left out. Sets with no class
(Zul'Gurub's Misc ones) follow the classes as plain rows. The player's own
class starts open, the others shut, then as left (Settings' Remember
sections). The list opens on the player's class's first set while that
fold is open, else on the first set on show, else (every class shut) on
the player's class's first set, opening its fold; going to a set in a shut
fold (search, a wishlist source) opens its fold. Other Collections lists are
unchanged.

## Quest page (Overview pane)

From the top:

1. **Header**: the title in `heading` × 1.375, with IDs after it in a local
   checkout. Under it, the subtitle (zone · faction · status) in `small` × 1.2,
   then the level line ("Requires level · Suggested level · Quest level ·
   classes · Weekly · Shareable", or "Not shareable"; "Weekly" only on a
   quest with `weekly`; nothing about sharing when no source knows, the
   Quests list's rule) in `small` × 1.1, 4 below. A class
   quest's badge sits left of the title, sized to all three lines. A
   starts-inside portal follows the name.
2. **Chain arrows**: `wowlabs-spectatecycling-arrowleft/right`, 32px, 44
   apart at the top right with a soft shadow. They only show on a quest page,
   and the title keeps 84 clear for them.
3. **Breadcrumb** in the content strip, for example "Shadowfang Keep > The
   Test of Righteousness".
4. **Sections**, each a heading in `label` × 1.64 with text in `body` × 7/6 and
   line spacing 3:
   - **Chain**: "Step n of m in a chain that starts with [first] from …",
     counted as the questline page counts (`Data:StepNumbers`: steps, not
     quests; lead-ins a player may skip have no number), "Breadcrumb in a
     chain that starts with …" or "Optional quest in a chain that starts
     with …" for one of those (`Chain.StartText`). Then a "Click to see full
     quest chain" toggle that lists every step (`Chain.Lines`): "1.  ✓
     [name]", each quest's mark before its link (`Chain.Mark`: the tick
     `common-icon-checkmark` 14 once done, "!" in `accepted` while in the
     quest log, the empty box `checkbox-minimal` 12 until then) and, on a
     quest of this dungeon, the portal (`PortalPurple` 16) after it. A step
     whose quests are all needed (Data/Chains.lua's `{ all = ... }`) reads
     "2.  Do both: ✓ [A], ! [B]" ("Do all: …" for 3 or more), every quest
     of it in order; a step of different quests to pick one of reads "3.
     Pick one: [A] or [B]"; copies of one quest name the one done, in the
     log or first. A breadcrumb or optional quest (Data/Chains.lua's
     `breadcrumbs`: Trouble in the Deeps, and `optional`: Seeking Caitlin)
     has no number and ends "  ·  Breadcrumb" ("Optional"). A step holding
     one of the dungeon's own quests ends "  ·  the goal", the page's own
     quest's "  ·  this quest", its link in `3B875B`, and that row is tinted
     the whole line (`goalFill` on a goal, else `hover`) with a 3 wide bar
     4 left of its text (`goal`, else `accent`). "[first]" is a link to the
     chain's first step, even when later steps share its name (The Tome of
     Divinity).
   - **Started by**: the giver, start item or dropper.
   - **Objective**. Every NPC, mob and item it names is a link where its whole
     name (or its plural) first appears, the longest name winning where two
     overlap (`ns.UI.LinkObjective`). The quest's givers, turn-in NPC and the
     other NPCs it names are blue with the giver's mark
     (`TaxiNode_Continent_Alliance`); the mobs to kill or loot and this
     dungeon's bosses are red with the red map mark, as in Targets. Each
     opens where it stands: a boss's pin on the dungeon map, an NPC's spot on
     the world map, another dungeon's entrance, or this dungeon's map (on the
     quest's drop area when it has one). Items are item links in their
     quality color; a click shows where they come from, the tooltip ending
     "Click to see where it comes from".
   - **Targets**: "Kill …" and "Loot [item] from …". Enemies are red with the
     red map mark (`TaxiNode_Continent_Horde`). Out in the world, they're
     followed by "in Zone (x, y)" and pin on the world map. A boss of this
     dungeon opens the dungeon map at its pin, a mob with a drop area opens
     it lit there, and any other mob inside opens the dungeon's map. A
     zone-wide quest's mobs (Quell the Uprising) open the map with the quest
     on its zone-wide badge. Item names find their source the way the
     Objective's do. An item from an object out in the world reads "Loot
     [item], found here" ("found here" a blue link with the giver's mark
     that pins it), and one nothing is known to drop reads "Loot [item]".
   - **Turn in**: who takes it back, linked like the giver.
   - **Rewards**: money and XP, "Choose one" in `small` × 1.4, then reward
     cells drawn like a dungeon boss's loot (the loot grid's fonts, icon and
     row, at 0.8 scale). XP shows only when confirmed (`ns.Data:QuestXP`:
     the game's own number while the quest is in the log and the player is
     within full-XP range, else the data's). "None" only for a quest known to
     pay nothing (XP confirmed as 0, no money or items); a quest with nothing
     known has no Rewards heading at all.
5. A chain step's short page (a quest not in this dungeon) shows Zone
   instead of Rewards. Its Started by, Objective, Targets and Turn in link
   NPCs, mobs and items the same way a dungeon quest's page does
   (Data/Chains.lua carries their places).

**Questline page (Dungeons tab).** A questline row's page, in the content
pane in the loot grid's place (`ns.UI.CreateDungeonQuestlinePage`): the
Classes tab's questline page as it is (`Questlines.CreatePage`; see Classes
tab, Questline page), drawn from the chains: the steps they start with down
the page, then where they part a "Do both, any order" box with a column per
chain (each chain's different end), then any steps they end with. A step
of copies of one quest (one per class) is one version card. A step of
different quests to pick one of (the Dire Maul librams) is a "Pick one"
box, a column per choice, "or" between them; once one is done the others
are dimmed to 0.4 and their zone line ends "Not needed". It counts once.
A step whose quests are all needed (Data/Chains.lua's `{ all = ... }`) is
a "Do both, any order" box ("Do all 3, any order"), "1 of 2 done" at its
right, a column per member, "+" between them, a member done in order down
its column (City of Dalaran: Prison Break In then Dalaran Patrols, and Key
to the City); each quest of it counts in the figures. A breadcrumb
(Data/Chains.lua's `breadcrumbs`, `Data:IsBreadcrumb`) is a chip over the
step it leads to, not a card (below). A card opens its quest's page, or a
step's short page for one done outside, Back returning to the questline.

The goal: a numbered step done in the dungeon itself (`isHere`). Its card
is 62 high (`GOAL.HEIGHT`, to `CARD_HEIGHT`'s 50), its outline `goal`, its
fill `goalFill`, with a glow round it (`Theme:Glow`: `goal` at 0.3,
`GOAL.GLOW_ALPHA`, reaching 3 past the card, `GOAL.GLOW`); its name in
`body` × 1.1 (`GOAL.TITLE_SCALE`) in `quest`; its tag "Step 3 of 4" in
`goalText` with a `goal` outline; its zone line "Lordamere Lake, then
inside City of Dalaran" ("Inside City of Dalaran" with no giver's zone).
Its status tag (as every card's, Questline page) also says "Completed" in
`complete` once done, as its outline stays `goal`.
4 over it (`GOAL.RIBBON_GAP`) the ribbon in `small`, `goalText`: the portal
(`PortalPurple`, as tall as the text) then "THE GOAL  ·  INSIDE CITY OF
DALARAN" (`Theme:Label`, so as written in Native). On the spine its circle
shows the portal (`PortalPurple` fitted into 16) in a `goal` ring in place
of the number.

Under the subtitle, the guide (`DungeonQuestlines.Guide`, placed by
`PlaceGuide`; the Classes tab's pages have none):
- **Leads to**: 6 under the subtitle (`GUIDE.LEADS_GAP`), a rounded box 20
  high (`GUIDE.LEADS_HEIGHT`), `goalFill` fill and `goal` outline, as wide
  as its text + 16 (8 in, `GUIDE.LEADS_PAD`; the page's width at most): the
  portal then "Leads to [Heart of Disruption] in City of Dalaran  ·  2
  steps away" in `small`, `goalText`, the quest's name in `quest`. It names
  the first goal not done (the last once all are); "1 step away", "Next
  step" when it is the step to do now, "Ready to turn in" in `complete` or
  "Accepted" in `accepted` while it is in the quest log, "Done" once done.
  None for a questline with no goal.
- **Next step** box: 12 under (`GUIDE.NEXT_GAP`), the page's width, rounded,
  filled `complete` at 0.10 (`GUIDE.FILL_ALPHA`) with a `complete` outline
  at 0.7 (`GUIDE.EDGE_ALPHA`), 10 in (`GUIDE.BOX_PAD`): "NEXT STEP"
  (`Theme:Label`) in `small`, `complete`; 3 under (`GUIDE.LINE_GAP`) in
  `body`, `text`, wrapping: "Finish [quest], then hand it in to [NPC]" for
  a quest of the step in the quest log, "Turn in [quest] to [NPC]" once
  its objectives are done (`C_QuestLog.ReadyForTurnIn`), else "Pick up
  [quest] from [NPC]" ("Finish [quest]", "Turn in [quest]" or "Pick up
  [quest]" with no NPC known), the quest's
  name in `quest`, the NPC's in `link`; 3 under in `small`, `muted`: the
  quest's objectives as the quest log has them ("Dalaran Summoner slain:
  4/6"; a secret line left out) and where the NPC stands ("Southern
  Hillsbrad Foothills", `ns.UI.ZoneArea`, or "Inside Blackrock Depths").
  The step is the one the world map's questline markers pick
  (`Data:NextStepIndex`, `Data.QuestsToPickUp`): past breadcrumbs and
  optional lead-ins, a step whose quests are all needed until every one is
  done. At the box's top right, 10 in, a "Show on map" pill (`Theme:Pill`),
  shown when the NPC has a spot out in the world: a map pin link as the
  page's NPC links (`ns.UI.HoverMapLink`): out of combat the game's
  `/mappin` on the NPC, in combat NeedRoll's own pin and the chat line
  (`ns.UI.ShowOnMap`), never the game's map opened. Its tooltip: the NPC's
  name, then the pin hint (`ns.UI.PinHint`; in combat
  `ns.UI.NO_MAP_PINS_IN_COMBAT`) in `Theme.tip.hint`. None once every step
  is done. The strip has Back and
its hint, then the breadcrumb in `body`, "Scholomance  >  Quests  >  The
Stone Circle": the dungeon in `link` (a click opens its Overview), "Quests"
and the ">"s in `muted`, the questline in `heading`; no ‹ ›. A right-click
on the page goes back; picking another dungeon, a boss or the Overview
leaves it.

**Attunement and item chains (dungeon and raid Overview).** Under the
Overview's facts, map card and entrance (`Attunement.Lines` in
`UI/Overview.lua`): a raid's Attunement first (none for a raid anyone can
walk into), then each item chain (`Data/ItemChains.lua`, kept in
`scraper/quests/itemchains.json`: a dungeon's key, Aqual Quintessence on
Molten Core, the Scepter of the Shifting Sands on AQ40), headed by its
item's name, the game's once it has the item, else the English one. Each
heading is a `SECTION_HEIGHT` (40, more when `ruled` outgrows `label`) section heading in `ruled` over the page
rule, with `Theme:Arrow` 16 before the words (the arrow and words one button
that opens and shuts it), its status 12 after the words and 2 up in `body`
("Complete" in `complete`, "In Progress" in `accepted`, "Incomplete" in
`incomplete`; none for a note-only chain), and, open, the faction toggle
when the sides' steps differ (Faction toggles above). Each starts shut and
is remembered (Settings' Remember sections). Open: the note in `body`, where
`{item:ID:Name}` is an item link, `{quest:ID:Name}` a quest link and
`{boss:INSTANCE:ENCOUNTER}` the boss's name, linked to its pin on this
instance's map or, from another instance's page, to that instance's
entrance ("Arcanist Doan (in Scarlet Monastery: Library)"); then the steps:
"1.  [Quest]", with who starts it and its status under it, 22 in
(`STEP_INDENT`). A step whose quests are all needed reads "1.  All 2, any
order  ·  1/2" (`L["All %d, any order"]`; "Completed" in `complete` once
all are, "1/2" in `accepted` once one is done or taken, else "Incomplete"
in `incomplete`),
its members lettered 22 in: "a.", "b.", or "b1.", "b2." for a member done
in order. A raid whose attunement isn't known reads "Not known yet.".

**Quest links**: the rule for every page that shows a quest (a dungeon's
quests, chain steps, the Classes tab's class quests, and any quest page
added later). Every NPC the page names is a map pin link and every item an
item link; nothing stays plain text when the data says where it stands.
Every quest it names (the chain's start, each chain step, the title line's
"Prior Step: [quest]", an attunement or item chain step, a chain note's
`{quest:...}`) is a link in `quest` that opens
that quest's page (`Chain.Link`); where several quests share a name, the one
meant there. The
scraper gives every quest the same fields (`questie_quests.Builder.quest`
builds the dungeon quests, `Builder.step` the chain steps, `classquests.py`
the class quests: `giverNpc`/`giverInside`, `turnIn`/`turnInNpc`/`turnInInside`,
`kills`, `droppers`, `loot`'s `from`, and `named` for the other NPCs the
objective names), and the page draws them with the functions below in
`UI/Overview.lua`.

| What | Value |
| --- | --- |
| Giver, chain giver, turn-in | Started by "From [name]" and Turn in "[name]": the giver's mark (`TaxiNode_Continent_Alliance`, `GIVER_ICON`) then the name in `link` (modern `FCD29F`, native `71D5FF`), the whole a link that pins their spot (`Giver(..., "giver")`), then where they stand: "in Central Wetlands" (`GiverInArea`, `ns.UI.ZoneArea`: the zone's game name with the third of its map across and down the spot is in, `L["Northwest %s"]` to `L["Southeast %s"]`; the capital cities' maps and maps that aren't a zone's give the name alone, "in Ironforge"). Not in the chain line. One inside a dungeon reads "Name (inside)" or "Name (in Dire Maul: West)" and pins that dungeon's entrance; a boss of the page's dungeon opens its pin on the dungeon map. An object out in the world (a WANTED poster) pins where it stands |
| Quest names | "[The Tome of Divinity]" in `quest` (`FFFF00`), the open page's own step in `3B875B`: a `needroll:chainquest:` link (`Chain.Link`) that opens the quest's page in the pane showing it (the Classes tab's own, else the Dungeons tab's, else the step's short page), its tooltip the game's quest tooltip then "Click to open this quest" |
| Kill targets and droppers | Targets "Kill A, B and C", "Loot [item] from A or B" and Started by "Starts from [item], dropped by A" ("looted from A" when every source is a chest or object out in the world, a negative ID: "Starts from [Henrig Lonebrow's Journal], looted from Henrig Lonebrow's Journal", the chain line of later steps alike): the red map mark (`TaxiNode_Continent_Horde`, `DROPPER_ICON`) then the name in `dropper` (`E5463B`) (`Places`, `Droppers`, `Giver(..., "dropper")`); out in the world followed by "in Southern Wetlands (60.3, 73.8)" (`ns.UI.ZoneArea`, the x and y where the pin goes, `ns.UI.ZoneSpot`). All in one other dungeon: the names then "in Dungeon", the dungeon a link to its entrance. An item every humanoid in the dungeon drops (`anyHumanoidChance` in the quest's `loot`) reads "Loot [item] from any humanoid (~1% chance)" (`LootSources`, `LootLine`): the chance `anyHumanoidChance` × 100 to a whole percent (`%.0f%%`), "any humanoid" a red dropper-marked link to the quest's drop area on the dungeon map (`needroll:dropspot:`, `DropSpotLink`) |
| NPCs inside a dungeon | a boss of the page's dungeon opens its pin on that dungeon's map (`needroll:boss:`), a mob with a drop area opens the map lit there (`needroll:dropspot:`), any other NPC there opens the dungeon's map (`needroll:dungeonmap`); one in another dungeon pins that dungeon's entrance (`needroll:inside:`). A class quest whose targets all stand in one dungeon or raid is set in it (`dungeon`), so its bosses link to that map |
| Names in the objective | `ns.UI.LinkObjective` links every name `ObjectiveNames` gives where its whole words (or plural, or possessive) first stand, longest first: the giver, chain giver, turn-in and `named` NPCs blue with the giver's mark; kill targets, loot sources and the dungeon's bosses red with the red mark; items as item links. Names under 4 characters (`MIN_LINKED_NAME`) and names with nowhere to pin stay plain |
| Items | `ItemLink`: "[Name]" in its quality colour once the game has it (`Theme:QualityColor`, never below common), the game's tooltip on hover, with "Click to see where it comes from" when a source has a spot (`ItemPlace`). A click pins the first source with a spot (the mob or object it's looted from); "Loot [item], found here" for an object out in the world ("found here" a blue giver-marked link); "Loot [item]" alone when nothing is known to drop it |
| Marks | 1.5 × the line's text size (`ns.UI.SizeMarkers`), inside the name's link, so either pins the same spot |
| Tooltips | an NPC (giver or enemy) "Click to pin on your map (Wetlands [56.2, 40.4])": the zone's game name and the spot the pin goes to (`ns.UI.PinHint`), plain "Click to pin on your map" when the zone isn't found; a dungeon "Inside Dungeon" then "Click to pin the entrance on your map"; a boss "Click to see this boss on the map"; the dungeon's map "Click to open the map" (`LINK_HINTS`, `PageLink.ShowTooltip`) |
| Click out of combat | the game's `/mappin` through the secure button (`UI.HoverMapLink`; Map pin links below); the game's map opens on its own pin below NeedRoll's window, which stays open. Shift, Ctrl or Alt on an NPC pins the same way; on an item it links the item in chat (`HandleModifiedItemClick`) |
| Click in combat | NeedRoll's own pin on the world map and the chat line "Forever Addon API blocks addons from linking map pins in combat, please try again when you're out of combat." (`ShowOnMap`); Shift-click on that pin posts "Name located at (x, y) in Zone" in chat |
| Not linked | an NPC with no map spot and no dungeon: QuestieDB has no spawn for it (summoned demons, the Lunaclaw Spirit), or it stands in a zone new in Forever whose map ID the scraper doesn't know (`ZONE_MAPS` in `questie_quests.py`: Riverglades 16591, Shen'dralas 16651, Forever's Mount Hyjal 616). Its name stays plain (red for an enemy) until `forever.json`'s `npcs` places it by hand |

## Search results

The hint reads "Search loot, bosses, dungeons, quests". Results come in groups,
each under its label with a count: Dungeons and Raids, Bosses, Quests, Library
Books, then Items. Each group is sorted by name.

| Row | Icon | Lines under the name | Click |
| --- | --- | --- | --- |
| Dungeon or raid | the `Dungeon` / `Raid` swirl | kind · zone, then levels · boss count | its Overview |
| Boss | its portrait in the boss pins' ring (0.5 ×) | level and rank, then encounter · place | its loot |
| Quest | `Exclamation-up-c60`, as tall as the icon, in its own shape (`QUEST_ATLAS`) | "Quest" or "Attunement" · level, then place · side | its quest page (`UI:SelectQuest`), Back returns to the search |
| Library book | the book's item icon, cropped, its border in the item's quality color (the question mark 134400 until the game sends it) | "Library book" · where it stands ("Not found", "In bags", "In bank", "Handed in": `LibraryBooks.STATUS_TEXT`), then its zone · its place | the Library tab with its fold open and scrolled to it (`UI:ShowLibraryBook`), Back returns to the search; tooltip: its name, "Library  >  Western Plaguelands", "Click to open it in the Library" |
| Item | the item's icon | its sources | its first source, the item lit |
| Item only vendors sell | the item's icon | its slot · level, then nothing (no page to name) | none; Shift-click links it, hover shows the item's tooltip; no go-to button |

Quest results cover dungeon quests (class and profession ones too), raid
attunement steps and item chain steps (shown as "Quest"). A name a place has more than once shows once, with the
player's side's quest. None show while the Quests module is off.

Library book results are the books of the player's side (`LibraryBooks.ForSide`),
matched by the game's name for the book, the data's English name until the
game sends it. None show while the Library module is off.

An item `Data/VendorItems.lua` lists (at most three vendors sell it) gets
the recipe sources' "Sold by" lines under its row (`SOURCE_ROW` 19 high, 2
under the item, `source` font, the 17 crest), in search only for these
items: the vendors of the player's side and those who serve both, each
"Name  ·  Zone" (the zone in `muted`) in `link`, a map pin link (hover:
the zone, "Limited supply" in `Theme.tip.info` when that vendor restocks
it over time, then "Click to pin on your map (Zone [x, y])"). An item a
dungeon or raid quest rewards (`rewards`, or one of `choice`, in
`Data/Quests.lua`) gets the quest lines of the loot rows' quests (see Boss
and loot pages) under its row too, for the quests of the player's side or
both, after any "Sold by" lines. An item no loot list has shows only when
a vendor of the player's side sells it or such a quest rewards it. None of
the quest lines while the Quests module is off. (`UI/Search.lua`,
`cell:SetQuest`, `AddSoldByLines` and `AddQuestLines` in `LootGrid.lua`)

## Boss and loot pages

| What | Value |
| --- | --- |
| Header | 64 high, portrait 58 (single boss), name and subtitle beside it |
| Below the subtitle | Related Quests, then "How to summon (spoiler)", which reveals on click. Its items are item links; quests in `quest` open their page; bosses (this instance's or another's) and dungeons in `link`, a boss shown on its instance's map, a dungeon's entrance pinned on the world map (`OpenSpoilerText` in `UI/LootGrid.lua`) |
| Loot filters (top right) | On dungeon, raid, PvP and Collections loot pages: an "Items I can use" box, a Class pill and a Types pill, in that order, 6 apart. "Items I can use" is the game's 22px check box with three steps, each click moving to the next: empty (off), a grey X (tooltip quiet grey, 0.6 0.6 0.6: items the character's class can't use stay listed but greyed out, the whole cell at 0.4 alpha with its icon desaturated), then a red X (`color.incomplete`, as a "Clear list" pill about to clear: those items are hidden), then empty again. The X is two 12x2px strokes at ±45° in the box's center; the game's own tick never shows. Its tooltip names the step and what the next click does. A tick saved before the grey step counts as the red X. The Types list is a solid rounded card with a gold outline. Ticked types are the only types shown. The pill reads "Types (n)" with n ticked; right-click clears them all, as Show all (its tooltip says so), without going Back. The Class pill opens a card like it listing the nine classes in their class colors, one picked at a time (All classes, picking it again or a right-click clears it); the pill then reads the class's name, and only what that class can use shows, as "Items I can use" does for the character's own class at its red X. |
| Loot grid | 2 columns, 6 apart. Dungeons, raids, PvP, factions and collections draw it at 0.8 with names 16pt, grey lines 12.5% smaller and drop chances at 90% (`ns.UI.LootGridFonts`) |
| Item count ("x1") | A recipe product's or material's count on the right, 1.25 × the drop chance's font, in `text` (`COUNT_SCALE` in `UI/LootGrid.lua`) |
| Price (vendor and reputation rewards) | On the right where a drop chance goes, in the drop chance's font, `muted`: gold as "155" and the gold coin, under a gold as "45" and the silver coin (`ShortCost`); a price in another item (a reputation's tokens, such as the centaur clans' Carved Centaur Totem, or a battleground's marks) as the count and that item's icon, "15" then the icon; a price in a currency (Honor; Merchant's Favor, the Azeroth Commerce Authority's and Durotar Supply and Logistics') as the amount and the currency's icon (the game's `iconFileID` from `C_CurrencyInfo.GetCurrencyInfo`), and Premier gear's honor and marks as both, the currency first, a space between: "9,000" Honor's icon "15" a mark's (`TokenCosts`). Numbers and icons only, so every locale reads it alike. Coins, item and currency icons are inline textures at the text's height, 2 after the number (`GOLD_ICON`). The tooltip adds a blank line, then "Vendor price" in `tip.info` with the cell's price in `tip.text` at the right, the currency's and the item's name (the game's own) after each count once the client has them, the two joined by `Theme.DOTS`: "9,000 Honor  ·  15 Warsong Gulch Mark of Honor" (`TooltipPrice` in `UI/LootGrid.lua`) |
| Boxed section | label 18 in, cells 12 in, 12 between boxes |
| Loot sections | On dungeon, raid, PvP, Factions and Collections loot pages (not the Professions tab's recipe lists), each section a box that folds (its label and the section arrow), only those with items, in this order: Quest Items, Weapons, Armor, Accessories, Professions (every recipe item: plans, patterns, formulas, schematics, manuals, books; one profession's together, by the recipe's subclass), Consumables, Miscellaneous. Within a section, ties keep the scraped order. In a page with folds (a boss's, a PvP class's) each fold has its own sections, open or shut alike in every fold. Professions starts shut, the others open; then each stays as the player left it (Remembered sections, `"loot"`), and a search's go-to opens the item's section (`SECTIONS`, `startsShut`, `LootKey` in `UI/LootGrid.lua`). On a Factions page Professions is split into one section per profession, in Professions' place, labelled with the game's own name for the recipe subclass in the client's language (`C_Item.GetItemSubClassInfo`: Alchemy, Blacksmithing, Enchanting...), sorted by that name, each keeping the data's order (lowest skill first) and starting shut, remembered by `PROFESSION_<subclass ID>`, never the name; a reward that teaches nothing but belongs to one profession (a "<Profession> Certification", `forProfession` in the data) sits in that profession's section (`ProfessionSection`, `SectionKeys`, `PROFESSION_SECTION_PREFIX`) |
| Recipe sources (under a recipe item) | Lines 19 high (`SOURCE_ROW`), 2 under the item, in `source`. A heading ("Drops from", "Sold by", "Taught by", "Nearest vendor", "Quest: Klaven's Tower") in `muted`, except a quest NeedRoll has a page for (a dungeon's, raid's or class's), in `quest`, which a click opens; each mob, vendor or trainer after a 17 icon (`SOURCE_CREST`, 4 before the name): their side's crest (`Theme:Insignia`), `TaxiNode_Continent_Alliance` for anyone, `TaxiNode_Continent_Horde` for a mob. Names that pin a map spot are in `link` (mobs in `dropper`). Hover: the name, its zone (and drop rate), then "Click to pin on your map (Zone [x, y])" (`ns.UI.PinHint`) |
| Companion sources (under a pet, Collections > Companions) | The recipe sources' lines (`SOURCE_ROW`, `SOURCE_CREST`, `source` font), in this order: "Crafted: Engineering" (a heading in `link` that opens the recipe), "Drops from" and its mobs (`dropper`; a boss whose loot NeedRoll lists opens that loot instead of pinning), "Sold by" and the vendors of the player's side or anyone, "Quest: name" (in `quest` when NeedRoll has the quest's page, a dungeon's, raid's or class's, which a click opens, else `muted`) with its giver under it ("Name  ·  Zone", pinned), then "Found in": each item after its own 17 icon in `link` (the item's tooltip on hover, a click opens it where NeedRoll lists it, Shift/Ctrl-click links or tries it on), the first 3 (`CONTAINERS_SHOWN`) then "+N more" in `muted` naming the rest in its tooltip, and objects as "Name  ·  Zone" after the giver mark |
| Quest lines (under a dungeon or raid loot item) | An item a dungeon or raid quest asks for (its `loot` in `Data/Quests.lua`), wherever NeedRoll lists it in a dungeon's or raid's loot (Warchief Rend Blackhand's Chromatic Carapace: both Chromatic quests), gets the recipe sources' lines under its cell (`SOURCE_ROW` 19 high, 2 under the item, `SOURCE_TOP`, `source` font) for each quest of the player's side or both, in list order: "Quest: Breastplate of the Chromatic Flight" in `quest`, which a click opens (its page, `ns.UI.QuestSource`), then its giver ("Catalogue of the Wayward  ·  Western Plaguelands", the zone in `muted`) in `link` after the 17 crest, a map pin link; no giver line for a giver with no map spot. None while the Quests module is off, nor on a page naming each item's source (All drops). (`AddQuestLines` in `UI/LootGrid.lua`, `ns.Data:QuestsAskingFor`) |
| Learned from: Taught by | A recipe trainers teach gets a Learned from box beside Creates (or the trainer lines go under its recipe item). Only trainers of the player's side and those serving both; nearest first. A trainer line is "Name  ·  Zone", the zone in `muted`. The nearest 3 (`TRAINERS_SHOWN`), then "N more trainers" in `heading` with the section arrow (10 long, `TRAINERS_ARROW`) pointing right, 4 after the words; open, every trainer and "Show fewer" with the arrow pointing down, and it stays open for that recipe (Remembered sections, `"trainers"`). In a box of its own the lines start 4 below the cell's top (`TRAINERS_TOP`), level with the item name beside it. Hover: name, zone, "Click to pin on your map (Zone [x, y])"; click pins them (`UI/LootGrid.lua`) |
| Fold row | 42 high (`FOLD_ROW`), 6 under it (`FOLD_HEIGHT` 48), the open/shut arrow 8 in from the right and a one-pixel `rule` along the bottom; the name in `section` 6 from the top, 6 after the portrait's box (38.8 in), the line under it in `small`, 3 below. A boss fold: the boss portrait at 0.4 (`FOLD_SCALE`), the boss's name in `heading`, "Level 54 Elite  ·  4 items" under it. Starts shut; then stays as the player left it, by the boss's NPC ID (Remembered sections, `"bosses"`). A PvP class fold: the class badge (`Theme:ClassBadge`, 26 as the Collections tab's class folds, its ring 1.25×) centred 14 from the row's left where the portrait's ring is (`CLASS_FOLD`), the class's name in its class colour (`ns.UI.SetClassColor`), "4 items" under it; "All classes" has no badge and its name in `heading`. The player's own class and All classes start open, the other classes shut; then each class stays as the player left it on every PvP page, by "CLASS:" and the class token, "CLASS:ALL" for All classes (Remembered sections, `"lootClasses"`) (`CreateFold`, `FoldMemory` in `UI/LootGrid.lua`) |
| PvP class folds | On the PvP tab's loot pages (Honor Ranks, Warsong Gulch, Arathi Basin, Alterac Valley, the Forever PvP factions) with at least one item for a class: a class fold per class with items, in the game's class order (Warrior, Paladin, Hunter, Rogue, Priest, Shaman, Mage, Warlock, Druid), then All classes last for the rest. An item's classes: the data's (`classes`, from the vendor page or Classic-DB), else armor by type to its wearers (cloth: Priest, Mage, Warlock; leather: Rogue, Druid; mail: Hunter, Shaman; plate: Warrior, Paladin; shields: Warrior, Paladin, Shaman; `WEARERS`) and a weapon to every class that can use it (`CAN_USE`), so it sits under each; cloaks, jewelry, off-hand tomes, tabards, consumables and mounts go under All classes. Inside each fold the usual loot sections. A page with nothing for a class lists its items without folds, as before; the status line counts each item once. A search's go-to opens the item's fold, the player's own class's when it sits under several (`ns.UI.ClassFolds`, `ns.UI.ItemClasses` in `UI/LootGrid.lua`; `LootFolds` in `UI/MainFrame.lua`). The PvP tab still lists one side at a time behind the faction toggle |

## Run tracker (local checkouts only)

A dungeon's or raid's run (recorded by `Core/Runs.lua`): the This run section, its report, the
run history, and on the game's screen its progress docked on the Objectives pane or a line under
the minimap, a card at each boss kill and a
one-time intro card. Local checkouts only: releases leave `UI/RunPage.lua`, `UI/RunHistory.lua`
and `UI/RunTracker.lua` out (`.pkgmeta`, a debug block in `UI.xml`), so none of this shows in a
release. `/nr runs demo` (`UI/RunDemo.lua`) fills the pages with made-up runs, kept in memory
only, shows the run tracker for the demo's Blackrock Depths run even outside a dungeon (four
bosses down out of order, one of them Lord Roccor, a rare spawn, shown but not counted), and
opens Blackrock Depths' This run; `/nr runs demo kill` plays the kill card for its latest kill (its roll
settles 2 s later, `ROLL_SECONDS`, so the winner's line shows), `/nr runs demo firsttime` shows
the intro card and clears its saved flag; `/nr runs demo raid` puts the player in Molten Core
tonight instead, so the tracker shows a big raid's bosses; `/nr runs demo off` or a `/reload` ends it, the line
and cards going too. Nothing on the screen ever names a "next" boss: many places can be done
in more than one order (Mike, 2026-11-23). Its words are
English, in each file's `TEXT` table, until the pages ship. Times are the game's clock
(`GameTime_GetFormattedTime`: "8:09 PM", or "20:09" on its 24-hour clock); lengths "47 min",
"1 h 38 min". Choices are written in one color each (`RunPage.ChoiceColor`): Need `complete`,
Greed `levelFair`, Disenchant `goal`, Pass `muted`, not offered `faint`. Players' names are in
their class's color (`C_ClassColor.GetClassColor`, the class the run's group saw), "(you)"
after the player's own. Pages redraw when a run changes (`Runs:OnChange`, at most once each
0.25 s, `CHANGE_DELAY`), never each frame.

| What | Value | Where |
| --- | --- | --- |
| This run section | In a dungeon's or raid's middle column, between Quests (a raid: the Overview) and Encounters, drawn as the Overview row is: 40 high (`ROW.GROUP`), the `Clock-up-c60` icon on the 30 disc, no section arrow; while its page shows, gold title and ring in a closed active card. At the right in `small` (`row.right`): "7 of 8  ·  47 min" (bosses down of those NeedRoll lists, rare spawns aside, and the run's length; the count of kills where NeedRoll doesn't list the place) in `heading` while it is the run the player is in, else `muted`; "No run yet" in `faint` when the place has no run. It shows the run the player is in there (`Runs:Current`), else the place's latest | `RunPage.ListEntry`, `ShowHeaderFigure` in `UI/RunPage.lua`; hooks in `UI/Lists.lua` |
| Kill ticks | An Encounters row whose boss died in that run: at the right in `small`, `complete`, `common-icon-checkmark` (11) and the time it died | `RunPage.ShowKillTime` |
| Report header | In the content pane (in the loot page's place). Title in `heading`, 18 in and 18 down (`REPORT.LEFT`, `TITLE_Y`): "This run  ·  The Deadmines" ("Last run" for a run the player can't go back to). Facts in `small`, `muted`, 44 down: "Started 8:04 PM" (the day before the time when not today), length, players, bosses, drops. Status 62 down: a 7 round dot (`STATUS_DOT`), 6 gap, `small` in `text`: whether it is one copy and why ("Same copy  ·  you released at 8:31 and ran back at 8:35"), the dot `complete` for a run of one visit ("Same copy all along": the copy can't change without a loading screen) or when creatures or the raid lockout showed it, `levelFair` when only the time outside says so, `faint` when closed. Each line sits at a fixed height, so nothing under it moves | `CreateHeader`, `ShowHeader`, `RunPage.CopyStatus` |
| Report pills | 82 down (`PILLS_Y`), 20 high (`Theme:Pill`). By boss and Rolls at the left, 6 apart (`PILL_GAP`), the view showing toned `heading`. At the right, 14 in (`REPORT.RIGHT`): All runs, and 6 left of it New run (an ask-once pill, "Click again to start"; only on the run the player is in or may go back to; it calls `Runs:StartNew`). Those two have tooltips. With no run there, only All runs (when any run is saved) | `CreatePills` |
| By boss | From 112 down (`BODY_Y`), a `Theme:ScrollColumn` to 6 short of the pane's right (its rows 8 short again, for the scroll bar). Each boss with drops: a 28 heading (`ROW.BOSS`), its name in `section`, at the right in `small`, `complete`, the tick and "killed 8:09 PM", a `Theme:Divider` along its top (not the first). Each drop: the item 22 (`ROW.ITEM`: an 18 icon with its quality edge, 6 gap, its name as its link shows it in `body`, quality color; tooltip on hover, Shift-click links it, Ctrl-click tries it on), then 16 (`ROW.OUTCOME`) in `small`, `text`, 24 in: "Won by Brannoc  ·  Need 87" (or "Master looter", "No roll", "Everyone passed", "Not settled yet"), then everyone else's roll as chips, then 8 (`DROP_GAP`). Other drops after the bosses; then each boss that left nothing as one 22 line (`ROW.QUIET`) in `small`, `muted`: "Name  ·  killed 8:44 PM  ·  nothing Uncommon or better" | `ByBossEntries`, `SetupDropRow` |
| Roll chips | 18 high (`CHIP.HEIGHT`), the text plus 6 each side (`CHIP.PAD`), 4 apart (`CHIP.GAP`), lines 4 apart (`CHIP.LINE_GAP`), wrapping at the row's width less the icon's room; a rounded `shutFill` fill with a `shutEdge` outline (`Theme:RoundedOn`); text in `small`: the choice in its color, the number, the name. Need first, then Greed, Disenchant, Pass, not offered, each highest roll first | `NewChip`, `PackChips`, `RunPage.SortedRolls` |
| Rolls grid | Over it a 36 heading (`GRID.HEAD`): "Item" in `small`, `muted`, 2 down; each player's name in `small`, class color, 4 down, and under it (17 down) their class or "(you)" in `muted`, centred on their column. The item column is 140 (`GRID.ITEM_COLUMN`); player columns share the rest evenly, 48 to 84 wide (`MIN_COLUMN`, `MAX_COLUMN`: five fit at 1280x800 with Large text). Order: the player, then those who rolled on or won anything, then the rest, by name. When they don't all fit: "Players 1-5 of 40" and a Next pill along the heading's bottom, which shows the next ones (back to the first after the last). Rows 38 (`ROW.GRID`): the item (icon 18, name in `body`) over its boss in `small`, `muted`; a divider along each but the first. Cells 30 high (`CELL_HEIGHT`), 3 in from their column's sides (`CELL_INSET`): the short choice (Need, Greed, DE, Pass) in its color 3 from the top, the number in `text` 3 from the bottom; a rounded fill in the choice's color at 14% (`FILL_ALPHA`) and its outline at 35% (`EDGE_ALPHA`), none for Pass. The winner's cell: outline in `discRing` at full and `auctionhouse-icon-favorite` (11) and a space before the word ("★ Need"); a winner with no roll reads "ML" (master looter) or "Took". "—" in `faint` where the game offered no roll; nothing for a player the game said nothing about. After the rows a 20 line (`ROW.NOTE`), `small`, `muted`: the star, "— not offered a roll", "DE Disenchant, ML master looter"; then "Totals  ·  Need 18  ·  Greed 13  ·  Pass 15" in `heading` and each winner's count as chips ("Lysette won 4") | `GridColumns`, `RollsEntries`, `CellFace`, `ShowGridHead` |
| Report empty | In `body`, `muted`, wrapping, at the body's top: "No run of The Stockade recorded yet. One starts when you enter it." or "No drops recorded in this run yet." | `ShowBody` |
| Run history | Opened by All runs, across the tab's body in a host like the Settings page's (`UI.CreateBackedHost`: Back with its right-click hint in the strip, "Back to This run"). Back, or a right-click anywhere on it, returns to the tab as it was; another tab or a search closes it, and the Settings page covers it while open | `RunPage.ShowHistory`, `TakeBackClick` in `UI/RunHistory.lua` |
| History list | The left 263 (`Size.questList`), a 1px `line` along its right. "Your runs" in `heading`, 14 in and 14 down; "42 saved" in `small`, `muted`, 14 in from the right. A label toggle (All, Dungeons, Raids) in `label`, 44 down. From 70 down a `Theme:ScrollColumn`: newest first, under "Today", "Yesterday" or "Earlier" (24 high, `label` font, `heading`); each run a `Theme:Row` 56 high (hover, selected): its place in `body` 14 in, 6 down; under it in `small`, `muted`: its start (the date first when before yesterday), length and bosses; under that its drops, what the player won (the item when one) and "reset by the leader" | `ListEntries`, `SetupListRow` |
| History run | 14 right of the list to 14 from the pane's right. Title in `heading`, 14 down: "Molten Core  ·  Yesterday". Facts in `small`, `muted`, 40 down: "7:00 PM to 9:14 PM", length, players, bosses, "Lockout 4120" for a raid saved to one. The status line as the report's, 58 down. From 82 down a `Theme:ScrollColumn`: the boss track, then the drops | `ShowRunHeader` |
| Boss track | NeedRoll's bosses in its order (rare spawns only when they died in the run: a boss whose page says "Rare" or whose rank is rare, `ns.Data:IsRareSpawn`; the line, dock, kill card and counts all use it), then any kill of a boss it doesn't list (`RunPage.TrackBosses`, which the line's, dock's and kill card's faces use too). Lines 52 high (`ROW.TRACK`), each boss a slot at least 72 wide (`TRACK.MIN_SLOT`), spread evenly. A killed boss: a 12 round dot (`TRACK.NODE`) in `discRing`; one not killed: the lists' `Mode-Selection-Ring-c60` at 16, desaturated, in `faint`. A 2 line (`TRACK.LINE`) joins each dot to the one before, `discRing` when both died, else `line`. Under each dot, 4 down, its name in `small` (`text`, `muted` when alive), and under that the time in `complete` or "not killed" in `faint` | `TrackEntries`, `ShowNode` |
| History drops | In the order they fell, 42 high (`ROW.DROP`), a 1px `line` under each: the time in `small`, `muted`; at 46 (`DROP.TIME`) the item (icon 22, name in `body`, quality color, as the report's) over its boss in `small`, `muted`; at 55% of the width (`WINNER_AT`) the winner in `body`, class color, over how in `small`, `muted`; at 74% (`SUMMARY_AT`) in `small`, `muted`: "Need 5  ·  Greed 0  ·  Pass 33", or "given by the master looter, no rolls", "looted with no roll"; the section arrow at the right, 4 in, turned open while its rolls show. A click opens or shuts its rolls | `SetupDropRow` in `UI/RunHistory.lua` |
| Line under the minimap | A plain `Button` on UIParent, kept on the screen (`SetClampedToScreen`): its top 4 under the game's `Minimap`'s bottom, centred (`LINE.GAP`), until the player drags it. as high as its faces and text need (5 above and below, `LINE.PAD_Y`; the text 13, `LINE.TEXT_HEIGHT`), as wide as the wider of its faces (and their shadow) and text plus 8 each side (`LINE.PAD_X`). Nothing behind it: no backdrop, only the faces' and text's own shadows. Shown only while the player is inside a dungeon or raid with a run (`Runs:Current`, `Runs:IsInside`), or while `/nr runs demo` is on, and while Settings shows it, and only when the dock on the Objectives pane doesn't (see Dock on the Objectives pane). 5 from its top (`LINE.PAD_Y`), centred, each boss of the boss track as its face (see Boss faces): 44 across, 3 apart, five at most to a row (`LINE_FACES`): the Deadmines 5 + 3, Molten Core 5 + 5, Naxxramas three rows of five, the demo's Blackrock Depths (17 bosses and the rare it killed) four rows. 4 under them (`LINE.TEXT_GAP`), centred, in the game's `GameFontHighlight` (12, white, `LINE_FONT`) with a black shadow 1 down and 1 right: "4/8 Bosses Killed" where NeedRoll lists the place (bosses down of those it lists, rare spawns aside), else "3 Bosses Killed" ("1 Boss Killed") (`KilledText`, Mike 2026-11-23). Only this text shows the run's tooltip and opens This run on a click (a target sized to it, `NewRunText`); the rest of the line shows nothing, and a drag from anywhere on it, the text too, moves it | `CreateLine`, `ShowLine`, `ShowFaces` in `UI/RunTracker.lua` |
| Boss faces | Each boss of the boss track (`RunPage.TrackBosses`) as its face: the round portrait in the ring NeedRoll's map pins use (`ns.UI.MiniPin`, `ns.UI.SetMiniPin`; the boss's creature display from `Data/Bosses.lua`, a council's first boss), the game's `DungeonSkull` in it for a boss NeedRoll has no face for (a place it doesn't list, a kill of a boss it doesn't list) (`FACE.FALLBACK`). Killed: full colour, with the game's `UI-QuestTracker-Tracker-Check` (NeedRoll's `common-icon-checkmark` without it) at 55% of the face's size centred 2 in from its bottom right corner (`FACE.CHECK_SHARE`). Still up: the portrait desaturated and darkened to 75% (`FACE.UP_SHADE`), the whole face at 60% (`FACE.UP_ALPHA`). Never crossed out or marked with a red X. A rare spawn (shown only once it has died in the run, `ns.Data:IsRareSpawn`, the boss track's `isRare`) wears its ring in silver, the game's color for a rare, where every other boss's is gold: the same ring art greyed (`SetDesaturated`) and tinted 90% red, 95% green, 100% blue (`FACE.RARE_RING_TINT`), so it hugs the face at every size: on the kill card, the dock and the line alike (`ShowRareRing`). Under each, a soft round shadow 1 down and 1 right (`SHADOW_OFFSET`): the game's `gamepad-actionbar-circleslot-dropshadow`, feathered to nothing at its edge, tinted black at 40% (`FACE.SHADOW_ATLAS`, `FACE.SHADOW_ALPHA`), its edge 3 past the face's visible ring on each side (`FACE.SHADOW_REACH`; the ring is 90% of the face's frame, `FACE.RING_SHARE`): 45.6 across under a 44 face, 42 under 40, 34.8 under 32 (`ShadowSize`). Without that art, a plain black disc at 20%. How a row lays out its faces (`FacesPerRow`, `ShowFaces`): every row keeps its faces' size and goes on to more rows, five at most to a row on the line and the dock, eight on the kill card (`PER_ROW`; the dock no more than fit the pane's width less 27). Faces start at the row's left. A face is its own button: hovering it shows the boss's name, "Killed 8:09 PM" (`tip.text`) or "Not killed yet" (`tip.quiet`), and "Click for loot" ("Click: This run" for a skull) in `tip.hint`, over it (`ANCHOR_TOP`); a left-click opens that boss's loot in NeedRoll's window (its instance's page on that boss, as `NeedRoll_ShowLoot` does, the run history and Settings page put away first), and a skull's opens the run as the line's click does; NeedRoll's own window only, so it works in combat. A drag that starts on a face moves the line under it (its release is no click). While the run is off the pane by choice and a pane is there to go back to, the line shows a 14 dock button at its top right, 2 in, only while the mouse is over the line (checked each 0.1 s, `HOVER_CHECK_SECONDS`): the game's `uitools-icon-collapse-window`, tooltip "Dock to objectives" over "Show it on top of your objectives again"; a click docks it back (`RunTracker.SetDockOff`), printing the /nr runs dock line when there's no room there. A right-click on a face on the kill card closes it, as anywhere else on it | `NewFace`, `ShowFace`, `ShowFaces` |
| Line drag | A left-drag moves it (the game's drag, which starts once the cursor has gone a few pixels; a drag never ends in a click), the tooltip hiding as it starts. Where it is left is saved on UIParent as `NeedRollDB.runLinePoint` (`{ point, relativePoint, x, y }`, checked by `UI.IsUsablePoint` as the window's position is), also when it hides mid-drag, and the line hangs there from then on; one the game won't take is dropped. `/nr runs line reset` forgets it and hangs the line under the minimap again ("Run line back under the minimap."). A plain frame, so it moves in combat too | `PlaceLine`, `StartLineDrag`, `StopLineDrag`, `RunTracker.ResetLine` |
| Dock on the Objectives pane | In the line's place while an Objectives pane shows and there is room over it; else the line. Never both. The panes, tried in order (`PANE_NAMES`): the game's `ObjectiveTrackerFrame`, then FlareUI's own quest tracker `FlareUI_ObjectiveTracker`, which takes its place; another replacement is one more name there. Each is looked up when needed, as FlareUI may load and build it after NeedRoll. A pane counts while visible and not parked: a replacement may park the game's pane rather than hide it, so a pane whose top is over 2 screen heights away (`PARKED_DISTANCE`), shrunk under 1% of the interface's scale (`PARKED_SCALE`) or see-through counts as hidden (`IsParked`). The dock keeps the game's look on any pane. NeedRoll's own `Button` on UIParent, its bottom 8 over the pane's top (`DOCK.GAP`), its sides on the pane's, so it follows the pane wherever Edit Mode puts it; not movable itself. NeedRoll only reads the pane and post-hooks it (each pane's `OnShow` and `OnHide`, the game pane's `SetCollapsed`, `EditModeManagerFrame`'s `OnHide`), never adding to it, moving it or calling what changes it (addon code in its layout taints its quest item buttons in combat). Drawn as the pane's own sections (Blizzard_ObjectiveTracker): a header bar of two lines, 66 high (a 22 name line, `DOCK.TITLE_LINE`, over a 37 line of count and buttons, `DOCK.CONTROL_LINE`, then 7 to the bar's bottom edge, `DOCK.CONTROL_PAD`), with the game's `UI-QuestTracker-Secondary-Objective-Header` stretched to the bar exactly, so none of it reaches past the dock. Line one: the place's name 16 in (`DOCK.HEADER_INSET`, inside the visible span of the art's bottom rule, whose ends taper off inside its frame) with a small black text shadow 1 down and 1 right (`AddTextShadow`, set again after each font step), and at the line's right, 16 in, the fold button; the name has the bar's width less 32, the button and 4, never cut off: in `ObjectiveTrackerHeaderFont` (gold 14), or where it doesn't fit, the game's gold `GameFontNormal` (12), then `GameFontNormalSmall` (10) (`TITLE_FONTS`, `FitOneLine`); too long even then, it wraps and the line grows to fit it, 4 above and below (`DOCK.TITLE_WRAP_PAD`). The fold button, 16 (`DOCK.FOLD_BUTTON`), folds the dock as the Objectives pane's own sections fold (below). On line two, at its right, 16 in, a 14 pop-out button (`DOCK.ICON_BUTTON`) with the game's `uitools-icon-external-window` and `UI-QuestTrackerButton-Yellow-Highlight` on hover, tooltip "Pop out" over "Show it on its own, where you drag it" in `tip.hint`: a click takes the run's progress off the pane to the line under the minimap (where it was dragged), remembered through a `/reload` (`NeedRollDB.runDockOff`). The line's own dock button puts it back (to the spot it was in). 4 left of the pop-out button the move button, 37 (`DOCK.MOVE_BUTTON`, as the d-pad art sits small in its frame; centred on line two, which is as tall as it, so it stays inside the bar), with the game's `Gamepad-Xbox1-DOnlyLeft-Normal` above the pane (tooltip "Dock to the left of the objectives" over "Beside your objectives, level with their top") and `Gamepad-Xbox1-DOnlyUp-Flat-Normal` at its left ("Dock above the objectives" over "On top of your objectives"), NeedRoll's section arrow without them: a click moves the dock to the pane's left (its top right 8 left of the pane's top left, `DOCK.SIDE_GAP`, as wide as the pane) or back above it, remembered (`NeedRollDB.runDockSide`). Above the pane with no room there, the dock goes to its left anyway, the choice kept for when room comes back; with no room at the left either (the pane at the screen's left edge, or the minimap in the way), the line. A click that can't put it where asked prints the /nr runs dock line. The fold button: the game's `UI-QuestTrackerButton-Secondary-Collapse` (a minus) while the faces show, `-Expand` (a plus) while they're folded away (and `-Pressed`), `UI-QuestTrackerButton-Yellow-Highlight` on hover; NeedRoll's section arrow without that art. Folded, the dock is its header bar alone, both lines; it stays folded through a `/reload` (`NeedRollDB.runDockCollapsed`). On line two, 16 in, "3/8 Bosses Killed" (`KilledText`, as the line's), never cut off: `ObjectiveTrackerLineFont` (12), else `GameFontHighlight`, then `GameFontHighlightSmall` (`COUNT_FONTS`; "17/17 Bosses Killed" fits at 12 in the 157-167 left of the move button) in `ObjectiveTrackerLineFont` (12) in the tracker's Normal grey `CCCCCC` with the same text shadow, stopping 6 short of the move button (`DOCK.COUNT_GAP`). 6 under the bar (`DOCK.FACES_TOP`), 20 in (`DOCK.LINE_LEFT`), the bosses' faces (see Boss faces): 40 across, 3 apart, five at most to a row and no more than fit the pane's width less 27 (`DOCK_FACES`): a five-boss dungeon takes one row, the Deadmines (5 + 3) and Molten Core (5 + 5) two, the demo's Blackrock Depths four (245 high). 4 under them (`DOCK.BOTTOM_PAD`): 116 high with one row of faces, 159 with two, 202 with three; the height is the run's own. Whether the dock fits over the pane is always judged by that height, folded or not, so the button never switches the run between the dock and the line. Each atlas and font is looked up first (`HasAtlas`, `GameFont`): without the header art a dark rounded backdrop in black at 50% (`BACKDROP`), without the fold art NeedRoll's section arrow, without the check `common-icon-checkmark`, without the tracker's fonts `GameFontNormal` and `GameFontHighlight`. A click on the place's name or the count: This run, as the line's; hovering either, the line's tooltip, beside it. The rest of the dock takes no mouse (`EnableMouse(false)`): no tooltip, no click; the faces and buttons keep their own. Never names a next boss | `ObjectivePane`, `CreateDock`, `AnchorDock`, `FillDock`, `ShowDock`, `WatchObjectivePanes` in `UI/RunTracker.lua` |
| Dock: pane collapsed | The game's pane folded by its own button: the dock folds to its header bar, the place and "1/5 bosses" in it as always, no faces, no button; the room it needs is then the header's | `FillDock` |
| Dock: room | The room over the pane runs from its top up to the screen's top, or to the minimap's bottom when the minimap sits over the pane, less the 4 gap, measured on the screen (`GetEffectiveScale`, as Edit Mode can size the pane). The dock shows above the pane only when its whole height with its faces fits, folded or not (its header's alone with the game's pane collapsed). At the pane's left it needs its width and height on the screen, clear of the minimap (`FitsLeft`). Where neither fits (or the left, chosen, doesn't), the line shows instead. Checked again as a pane shows or hides, the game's pane folds, Edit Mode closes, the interface scale changes, and whenever the run changes | `RoomAbove`, `FitsLeft`, `TrySide` |
| /nr runs dock | Prints one line on where the progress shows and why: "Dock: FlareUI_ObjectiveTracker, docked above it.", "Dock: FlareUI_ObjectiveTracker, docked at its left.", "Dock: FlareUI_ObjectiveTracker, docked at its left: no room above (needs 159 px, has 18 under the minimap).", "Dock: ObjectiveTrackerFrame, no room above (needs 159 px, has 18 under the screen's top) or at its left (needs 260 px, has 10): the line instead.", "Dock: ObjectiveTrackerFrame, no room at its left (needs 260 px, has 10): the line instead.", "Dock: no pane showing (ObjectiveTrackerFrame parked off screen, FlareUI_ObjectiveTracker hidden): the line instead." "Dock: ObjectiveTrackerFrame, popped out, by choice: the line instead. Its dock button puts it back." or "Dock: nothing to show (no run here, and no /nr runs demo)." `/nr runs demo` prints it too, after its own line. Listed in `/nr devcommands` | `RunTracker.DockStatusText` |
| Line tooltip | `GameTooltip` over the text it shows from (the line's count, `ANCHOR_BOTTOM`; the dock's place or count, `ANCHOR_LEFT`, the pane being at the screen's right): the place's name (title, gold); "4/8 Bosses Killed  ·  31 min  ·  5 players" in `Theme.tip.text`; each boss of the track, a boss down with `common-icon-checkmark` (11) and its name in `tip.text` and its time at the right in `tip.quiet`, one alive with the lists' `Mode-Selection-Ring-c60` (11) and its name in `tip.quiet`; "7 drops  ·  you won 1" in `tip.text`; "Last: Brannoc Vale won [Lavishly Jeweled Ring], Need 87" in `tip.quiet`, wrapping (the name in class color, the item in its quality's; only when a drop has a winner); "Click: This run" and, the line only, "Drag to move" in `tip.hint`. It redraws if the run changes under the mouse | `ShowRunTooltip` |
| Line click | A click on the line's count (`line.textTarget`), not elsewhere on it: opens NeedRoll's window on the place's This run, on the Dungeons or Raids tab (`RunPage.OpenThisRun`, the run history and Settings page put away first). For a place NeedRoll doesn't list: the Dungeons or Raids tab with the run history open on that run (its filter goes back to All when it would hide it). With that tab off in Settings, just the window. Works in combat | `OpenRun` |
| Kill card | DevKit's plain card (`DevKit.PlainCard`: the style's fonts and colors, its fading, no frame), straight on the game world with nothing behind it in every style: no panel, no close cross. 277 wide, a row of eight faces (`KILL.WIDTH`), at the upper middle of the screen as the level-up window. Fades in as a boss kill is added to the run the player is in (`Runs:OnKill`; a second look at a boss already killed doesn't count). Laid out top to bottom from its top left (`ShowKill`, `KILL`): the place's name, "Blackrock Depths" (`RunPage.PlaceName`), in `section` (14 Native, 13 flat), `heading`, as the Classes tab's section headings; never cut off: a long name steps down to `label` (`card.placeFonts`, `FitOneLine`). 4 under it (`KILL.DIVIDER_GAP`) a `Theme:Divider` the card's width. 8 under that (`KILL.FACES_GAP`) the bosses' faces (see Boss faces), 32 across and 3 apart, eight to a row, more rows for more bosses, never shrunk (`CARD_FACES`). 8 under them (`KILL.BOSS_GAP`) "Targorr the Dread down" in `body`, `text`, a long boss name stepping down to `small` to fit beside the count (`card.bossDownFonts`); at the card's right, level with its bottom, "4 of 8" in `small`, `muted` ("3 down" where NeedRoll doesn't list the place), at least 8 clear of it (`KILL.COUNT_GAP`). 4 under that (`KILL.WINNER_GAP`) View run (`Theme:Pill`) at the card's right, and left of it, 8 clear (`KILL.PILL_GAP`), up to two lines in `body`, `text`: the kill's latest drop with a winner, "Brannoc Vale won [Lavishly Jeweled Ring], Need 87" (empty until one settles). The card is as tall as all that with two lines' room for the winner (`KILL.WINNER_LINES`), so nothing moves when a roll settles: 107 with one row of faces in Native (106 flat), 35 more for each further row. Every text on it, View run's too, casts the line's 1 down, 1 right black shadow (`AddTextShadow`), so it reads on any ground. Fades out 6 s after it has fully faded in (`KILL.SHOW_SECONDS`), held while the mouse is over it; a right-click anywhere on it, a face's and View run's too, closes it, and View run's click closes it and opens the run's place as the line's click does | `CreateKillCard`, `ShowKill`, `RunTracker.ShowKillCard` |
| Intro card | DevKit's card, 300 wide by 140 high (`INTRO`), no close cross. The first loading screen into a dungeon or raid with the tracker present shows it, once per account (`NeedRollDB.runIntroShown`), unless Boss kill cards is off. Title "NeedRoll is tracking this run"; at the top of the line under the title, 16 in from both sides and wrapping, in `body`, `text`: "Bosses, drops and everyone's rolls, saved on this character. Open it from the run's progress on your screen or the dungeon's page." At the bottom right, 16 in: View run, and 6 left of it Got it (`PILL_GAP`), both closing it (View run also opens the current run's place). It doesn't fade on its own | `CreateIntroCard`, `ShowIntroOnce` |
| Cards together | One card shows at a time: the newer one takes the other's place. Each style gets each card of its own, built the first time it shows in that style (`DevKit.CardsBySkin`) | `RunTracker.ShowKillCard`, `RunTracker.ShowIntro` |
| Settings | Two rows in General, after Minimap button, only in local checkouts (`isHidden`: `ns.Runs.available`), their labels in English: "Run progress on screen" (Shown, Hidden; note "Bosses down, over your objectives or under the minimap"; `NeedRollDB.runProgressLine`, which covers the dock and the line) and "Boss kill cards" (On, Off; note "A short card as each boss dies"; `NeedRollDB.runKillCards`, which covers the intro card too). Both on by default; a change applies at once, cards on show going when turned off | `OPTIONS` in `UI/Settings.lua`, `RunTracker.ApplySettings` |
| Roll bars | Under an open drop, 18 high (`ROW.ROLL`): the name (class color, `body`) at 74; 130 on (`ROLL_NAME`) the choice in `small` in its color; 70 on (`ROLL_CHOICE`) a 6 high bar to 44 from the right (`ROLL_NUMBER`): its track in `line`, its fill in the choice's color, as long as the roll is of 100; 8 after it the number in `small`, `text`, and the star after the winner's. Need first, then Greed and Disenchant, highest first; then "N others passed" and "N not offered a roll" in `small`, `muted` | `RollEntries`, `SetupRollRow` |

## Dungeon map

| What | Value |
| --- | --- |
| Map art | 4 × 3 tiles of 256 per level (`Data/Maps.lua`). The Classic dungeons and raids: Blizzard's world map drawings, shipped as BLP in `Media/Maps/Classic/<map>/` (copied from the game's enUS files; the ruRU, esMX and itIT clients lack them and drew solid green), each level then listing the game's file IDs, which only match the game's own map to a level (`ns.UI.MapFloor`). Upper Blackrock Spire's first two floors and the dungeons new in Forever (Santiago Reyes): TGA in `Media/Maps` |
| Floor tabs | text tab chips (`RB.Chip`, `RB.PlaceLines`): cream words with gold dots between them on balanced, centred lines; the shown floor gold with the underline that fades to the word's ends, a faint cream one on hover |
| Zoom | up to 4 ×, 1.25 × per wheel notch |
| Zone-wide quests badge | top-left, 22px icons 6 apart, rounded corner 12, a gold frame line 2 wide (shadow, glow, core) |
| Quest markers | With Settings' "Show only accepted quests" off (the default) every marker shows. On: every marker tied to a quest ("!", kill, loot, vendor, turn-in and the rest), its drop area and its zone-wide quests icon shows only while that quest is in the quest log, or when the map was opened from that quest's target link (lit). A marker with no quest of its own takes the quest of the "!" put on it; one tied to no quest at all always shows, and so does the "!" of a quest that starts inside the dungeon until it is done. `/nr devedit` shows them all (`ns.UI.MarkerShows` in `Overview.lua`) |
| Drop areas | a scanline fill and a soft outline (`OutlineLine.tga`, 6 wide) |
| Walkable-area outlines | lit while a zone-wide quest is hovered (`Data/Outlines.lua`; master copy in `tools/outlines_master.lua`) |
| Patrols | a glow line 8 wide under a 2.5 core, with arrowheads |
| Edited copies (`/nr devedit`) | markers added to the data after a copy was made join it; ones removed in edit mode stay removed |
| A spot opened to show | Someone standing inside with no boss pin (Annora in Uldaman, from the Professions Overview; `UI:ShowSpotOnMap`): the map opens on their level with the game's `Waypoint-MapPin-Untracked` atlas fitted into 28 (`FOCUS_PIN`) centred on their spot, with the quest markers' dark edge and pulsing gold glow (`NewGlowMark`), at the canvas's frame level + 30; its tooltip (`ANCHOR_RIGHT`) is their name. Only on that level, gone once the map closes |
| World map overlay (`UI/WorldMapOverlay.lua`) | inside a mapped dungeon or raid (Settings' Map in dungeons on NeedRoll) the game's world map shows the player's level drawn over its own: a layer on `WorldMapFrame.ScrollContainer` at the game canvas's frame level + 1 (its clip + 2, its canvas + 3), above the game's map art and under the game's pins (frame level 2000 on). The art fills the game's canvas (scale `min(width / 1002, height / 668)`) and pans and zooms with it; boss pins (40, portrait 29), quest markers (22), locks (20), entrances (28) and the zone-wide quests badge keep the window's map's sizes at every zoom. No level tabs or links to other levels drawn on the art (the game's floor dropdown or the floor chips pick the level), zoom hint, credit or pill other than the zone button. While the game's zoom eases, only the art re-sizes each frame (pins and markers wait); the whole level redraws once the canvas width holds for a frame. Under the window's map, "Open the world map" shows whenever the player is inside the instance shown; its tooltip adds the line about NeedRoll's map over the game's only on Map in dungeons = NeedRoll. Its widgets let right-click through to the game's map (`SetPassThroughButtons("RightButton")`, as the game's own pins do); its empty parts take no mouse at all. A right-click released over the game's map area (`WorldMapFrame.ScrollContainer`, not the quest log beside it) always turns the layer off until the map reopens, also where the game's own right-click goes nowhere (a map with no parent, such as the World map). The zone button: a Native pill (`Theme:NativePill`, 20 high, Native `body` font, gold `pillEdge` outline, width the text + 24, in every style) 10 in from the map area's bottom right corner (`ZONE_BUTTON_INSET`; the map markers' mode button owns the bottom left, the game keeps its floor dropdown and map buttons in the top corners), at the game canvas's frame level + 45 (`ZONE_BUTTON_LEVELS_UP`: over the layer's widgets, under NeedRoll's own pin at + 50 and the game's pins). It doesn't pan or zoom with the map. Its label is the game's name for the zone the dungeon's entrance is in (`C_Map.GetMapInfo`, so localized: Silverpine Forest for Shadowfang Keep); it shows only while the layer does and the entrance and its zone are known. Its tooltip (`ANCHOR_LEFT`, towards the map, away from its right edge) is the dungeon's name, then "Click to pin the entrance on your map" (in combat, why it can't). It is a map pin link: out of combat the secure button lies over it while hovered and runs `/mappin <map> <x> <y>` on the entrance, so the game's map moves to that zone with the game's pin and the layer turns off; in combat its click draws NeedRoll's own pin there. Right-click passes through to the game's map like the layer's other widgets |
| World map floor chips (`UI/WorldMapOverlay.lua`) | while the dungeon map overlay's layer shows a dungeon or raid whose layout map has 2 or more levels: one chip per level of NeedRoll's, in its order and named as the window's floor tabs (`ns.UI.LevelName`), the drawings the game has no floors for too (Blackmaw Hold). Otherwise, whenever the game's world map shows a map of type Dungeon (`C_Map.GetMapInfo`, dungeons and raids) whose map group has 2 or more floors (`C_Map.GetMapGroupID`, `C_Map.GetMapGroupMembersInfo`), with either Map in dungeons setting: one chip per floor, in the game's order. Both in the window's floor tab style (`RB.Chip`, `RB.PlaceLines`: cream words with gold dots between them, the shown floor gold with the fading underline, a faint cream one on hover; labels through `Theme:Label`). A chip's name is NeedRoll's name for its level on that floor (`ns.UI.LevelName`, as the window's tabs: the game's `DUNGEON_FLOOR_*` strings), else the game's floor name, else "Level N". The chips sit on a strip filled black at 60% (`FLOOR_BAR_FILL`) with a 1px gold `FFD100` outline at 38% (`FLOOR_BAR_EDGE`) in the skin's corners (`Theme:Rounded`), 10 left and right of the chips (`FLOOR_BAR_PAD_X`) and 4 above and below (`FLOOR_BAR_PAD_Y`), centred 8 below the map area's top edge (`FLOOR_BAR_TOP`), at the game canvas's frame level + 45 like the zone button (over the layer's widgets, under the game's pins). The chips stay on one line while it fits the map area less 180 at each side (`FLOOR_BAR_SIDE_ROOM`, for the game's floor dropdown at the top left and its map buttons at the top right), else on balanced, centred lines that wide. It doesn't pan or zoom with the map; the strip takes no mouse, so drags around the chips are the game's. A click on a floor the game has (art matched by `ns.UI.MapFloor`) turns the game's map to it with the game's `C_Map.OpenWorldMap` (never the map's own `SetMapID`), and NeedRoll's layer follows; a level the game has no floor for, or the floor the game's map already shows, is only drawn on the layer (in combat too). The picked chip is the layer's level, else the game's floor, and follows the game's floor dropdown and walking too. No tooltip out of combat. In combat a chip that would move the game's map moves nothing: its tooltip (`ANCHOR_BOTTOM`) and a click's chat line say "Forever Addon API blocks addons from changing the map's floor in combat, please try again when you're out of combat." Right-click passes through to the game's map like the layer's other widgets |

**Map pin links** (an NPC or dungeon entrance named on a page, an item whose
source has a spot, the Entrance row and its Show on map button, a recipe's
source line, a dungeon in a boss's spoiler, the zone button on the game's map;
`UI.HoverMapLink` in `UI/MainFrame.lua`, `UI/WorldMapOverlay.lua`):

| What | Value |
| --- | --- |
| Click out of combat | runs the game's `/mappin <uiMapID> <x> <y>` (x, y 0-100, one decimal) from a secure macro button, so the game places its own map pin and opens its map there; NeedRoll then tracks it (minimap arrow). NeedRoll never calls `C_Map.SetUserWaypoint` itself |
| Secure button | one `SecureActionButtonTemplate` button, shown while the mouse is on such a link out of combat. Out of combat it is a child of the link's frame (a button outside NeedRoll's window never gets the mouse over it, whatever its level), in that frame's strata at its frame level + 10 (`LINK_LEVELS_UP`); at `PLAYER_REGEN_DISABLED` it is hidden and goes back onto `UIParent` until combat ends, since a frame holding a secure button can't show, hide or move in combat. A link inside a page's text has no frame of its own: the button is a 24 × 24 square (`MAP_LINK_HIT_SIZE`, in `UIParent`'s units, turned into the line's own units at the window's scale) centred where the mouse came onto the link, fixed there (it scrolls with the text), so leaving the square ends the hover and the text picks up the link under the mouse again. Any other link (the Entrance row, a recipe's source line, NeedRoll's own pin and the zone button on the world map) is covered whole. Left button up only. It takes the mouse (a click-only button gets no click on a frame holding the mouse focus), so it shows the link's hover itself: the link's tooltip, or its frame's OnEnter (highlight and tooltip); the mouse leaving it runs the link's leave. Right-click passes through (`SetPassThroughButtons("RightButton")`; NeedRoll's right-click Back, the game's map's own), and the mouse wheel scrolls the page beneath inside NeedRoll's window (none over NeedRoll's pin on the world map, where calling the map's zoom would taint it). Hidden when its text hides. A click with Shift, Ctrl or Alt on an item link still links the item. Its /mappin opens the game's map (MEDIUM strata, below the window); NeedRoll's window stays open over it, and closing it shows the map. The links to the game's map ("Open the world map", Back to the world map) lie under the same kind of button, covering them whole, with the same hover, right-click and wheel. In combat they leave the game's map shut (NeedRoll never opens it then), the window stays open, chat prints "NeedRoll: Forever Addon API blocks addons from opening the map in combat, please try again when you're out of combat." (`UI:OpenWorldMap`), and Back keeps its way to the world map for after combat. A chain step with no page of its own, which opens the game's quest log, does the same in combat (`Chain.OpenInLog`) |
| The link's frame | can't hang from a text or texture through any chain of anchors (the game refuses: "Cannot anchor protected frames to regions"), so such a frame hangs from its page by a measured offset. A boss's spoiler: from the loot pane's top-left, at the title's left and 4 under the subtitle's bottom (`pane:SubtitleBottom()`: the title's top, its height, 6, the subtitle's height), or with Related Quests 6 + 16 + 4 under it, as when it hung from them. A dungeon in a spoiler NeedRoll doesn't know, or whose entrance it doesn't know, stays plain text; its hover reads "Click to pin the entrance on your map" |
| Click in combat | draws NeedRoll's own pin (below) and prints "NeedRoll: Forever Addon API blocks addons from linking map pins in combat, please try again when you're out of combat." (`CHAT_PREFIX`, `FCD29F`) |
| NeedRoll's own pin | the game's `Waypoint-MapPin-Untracked` atlas fitted into 32 (`PIN_SIZE`), centred on the spot; one at a time, the latest winning, not saved (a reload clears it). Its layer sits on `WorldMapFrame.ScrollContainer` at the game canvas's frame level + 50 (`PIN_LEVELS_UP`; clip + 51, canvas + 52, pin + 53): over the dungeon map overlay (whose widgets reach + 42), under the game's pins (2000 on). Shown while the game's map shows the pin's map or a map above it (continent, Azeroth), there where its zone lies (`C_Map.GetMapRectOnMap`); pans and zooms with it at its size. In combat chat also names the zone's map it's on. Right-click passes through to the game's map |
| Its tooltip | `ANCHOR_RIGHT`: the NPC's or dungeon's name (the zone's when none), then in white (`Theme.tip.text`, wrapped) "Click to pin on your map" (in combat the message above instead) and "Shift-click to post its location in chat" |
| Its clicks | Shift-click (any time) puts "Name located at (x, y) in Zone" (one decimal) in the chat box being typed in, or opens one with it. A plain click out of combat runs `/mappin` for its spot through the secure button; the game's pin then takes its place (it also goes when the player's own pin lands on it). In combat a plain click places nothing and prints the message |

**Dev edit palette** (`/nr devedit`, local checkouts only; `UI/MapEdit.lua`):

| What | Value |
| --- | --- |
| Window | `DevKit.GameWindow` (the game's `BasicFrameTemplateWithInset`), 232 wide, beside the NeedRoll window (8 right of it) |
| Tool buttons | 44 square, four to a row, 52 apart across and 50 down; the game's square highlight under the mouse. Boss and unit buttons 34, six to a row, 36 apart |
| Units row | only for an instance with units listed in `Data/DevDungeons.lua` (`mapEditUnits`): "Units" in `GameFontNormalSmall` 14 in from the left, 8 under the boss buttons; 16 under it the unit buttons, laid out as the boss buttons (34, six to a row, 36 apart), the unit picker following 8 under them. Each shows the unit's portrait by its display ID, the Encounter Journal's default boss face (`UI-EJ-BOSS-Default`) when none is listed; dimmed to 40% when the unit is pinned on the level on show, as the boss buttons are; lit as below while it is the unit picked |
| Picked button | a blue `3D6180` fill inside a 1px gold `FFD100` edge (`Theme:Border`); only one is lit at a time |
| Picked line | `GameFontNormalSmall`, 14 in from the left and 42 up from the bottom, over Export and Done: the pick's name and its next step ("Entrance  ·  click the map") in gold `FFD100`, or "Nothing picked" in grey `999999` |
| Cursor cue | the picked line's text in `GameFontHighlightSmall` on a black strip at 75%, 20 high, the text 6 in and the strip 12 wider than it; its corner 16 right of and 16 below the cursor, in the `TOOLTIP` strata, seen only while the mouse is over the map |
| Letting go | a second click on the picked button, Escape, or a right-click on the map (it never places) clear the fill, edge, picked line and cue together |
| Fake combat | a game check box (`UICheckButtonTemplate`, 22 × 22) 10 in from the left, 10 under the language button, its label "Fake combat" in `GameFontHighlightSmall` 2 right of it; the hint follows 8 under it. Ticked, map pin links act as in combat (no secure button; a click draws NeedRoll's own pin and prints the message). Not saved |
| View as | "View as" in `GameFontNormalSmall` 14 in from the left, 8 under Fake combat; 14 under it two of the same check boxes, Alliance 10 in from the left and Horde 84 right of it (`VIEW_AS_BOX_GAP`), labels as Fake combat's; the hint follows 8 under them. At most one is ticked: NeedRoll shows everything as for that side (`ns.PlayerFaction`), the open panes' picked sides reset to follow it; neither ticked is the character's own side. Not saved |
| Drawing | a drag on the map with a patrol (after its pin is clicked), area (after its marker) or outline tool draws under the cursor, a point each 24 UI units the mouse moves (finer when zoomed in), drawn as it grows in the patrol and area looks above |

## Quest givers, books and portals on the world map

On a zone or city map the game's world map marks where to pick up the
dungeon and raid quests the character can take, where the library books
they haven't found sit and where WoW: Forever's travel portals stand
(`UI/WorldMapMarkers.lua`; the portals from `Data/Portals.lua`). Each
marker shows only on the zone map its spot is on: none on continent or
world views, none on a dungeon's floors. Only quests whose suggested level
(else their level) is within 10 of the character's get a marker
(`LEVEL_WINDOW`; the dungeon quest's level, also for a questline step's
marker); books and portals have no level window. NeedRoll's button in the
map's bottom left corner picks what the markers show: what is still to do
(the default), everything (the rest faded), or nothing. Portals show the
same in the first two.

| What | Value |
| --- | --- |
| Layer | On `WorldMapFrame.ScrollContainer` at the game canvas's frame level + 30 (`MARKER_LEVELS_UP`; clip + 31, canvas + 32, markers + 33, the mode button + 34): over the dungeon map overlay's layer (+ 1), under the zone button and floor chips (+ 45), NeedRoll's own pin (+ 50) and the game's pins (2000 on). Its canvas covers the game's canvas, so the markers pan and zoom with the map at their own size. Laid like NeedRoll's own pin's layer (`WorldMapOverlay.LayOnGameMap`); no map data provider |
| Quest to pick up now | The game's `QuestNormal` atlas fitted into 20 (`ICONS.quest`, `ICON_SIZES`), on the giver of a quest of the character's side and class, not done or in the quest log, with no questline before it or every step done, at or above its minimum level |
| Questline step | `Quest-Campaign-Available` fitted into 20 (`ICONS.chain`), on the giver of the next step of a questline (`Data/Chains.lua`) that leads to such a quest: the step after the last one done, past lead-ins a player may skip, at or above that step's level. A step whose quests are all needed stays the next one until every quest of it is done; its marker is on the giver of the first member not finished, that member's first quest not done (Dalaran Patrols once Prison Break In is done, then Key to the City). None while a step is in the quest log, nor when the step or quest starts from an item or with a giver inside a dungeon |
| One marker per giver | Every quest that sends the player to the same NPC spot is one marker; it takes the `QuestNormal` icon when any of them can be picked up now, else `Quest-Campaign-Available` |
| Library book | `Campaign-QuestLog-LoreBook` fitted into 22 (`ICONS.book`) on each spot of a book of the character's side that is not handed in and in neither the bags nor the bank. Drawn before the quest markers |
| Travel portal | The game's `PortalPurple` atlas (the purple swirl, in no side's colour) fitted into 22 (`ICONS.portal`) on each portal's spot, for both sides: who may take one isn't known. Never faded. Drawn before the books and quest markers. A portal whose destination map the game doesn't know isn't marked |
| Hover | The icon grows to 1.25 × (`HOVER_GROW`: 25, or 27.5 for a book or portal), centred; back to its size as the mouse leaves |
| Quest tooltip | `ANCHOR_RIGHT`: the giver's name (the game's, once `Core/Names.lua` has it); per quest, the one opened by a click first (those not faded, then those to pick up now, then by level): "Collecting Memories  ·  Level 18" in `Theme.tip.text`, then the dungeons it's for ("The Deadmines") in `Theme.tip.info`. A questline step: "The Defias Brotherhood  ·  Level 18" (the step), then "Questline step 1 of 7, leads to The Defias Brotherhood (The Deadmines)" in `Theme.tip.info`, the steps numbered as the questline page numbers them (`Data:StepNumbers`: a breadcrumb or optional lead-in has no number, the dungeon's quest the step after the last). Last, "Click to open it in NeedRoll" in `Theme.tip.hint`. All lines wrap |
| Book tooltip | `ANCHOR_RIGHT`: the book's name (the game's item name, else the data's), where it sits and how to get it joined by the dot in `Theme.tip.text` (when known), then "Click to open the Library" in `Theme.tip.hint` |
| Portal tooltip | `ANCHOR_RIGHT`: "Portal to Orgrimmar" as its title, the destination the game's own name for its map (`C_Map.GetMapInfo`; a town's zone, as the game has no map of the town: "Portal to Hillsbrad Foothills" for Southshore's), then "Click to pin on your map" in `Theme.tip.hint`, in combat the reason it can't (`ns.UI.NO_MAP_PINS_IN_COMBAT`) |
| Click | Left button up. A quest marker opens NeedRoll's window on its first quest's page in its first dungeon, raised above the game's map, which stays open; Back leads to the world map (`UI:ShowFromWorldMap`, as the dungeon map overlay's markers). A book opens the Library tab (`UI:ShowLibraryFromWorldMap`). A portal is a map link (`UI.HoverMapLink`): out of combat the click runs the game's /mappin on it through the secure link laid over the marker, placing the game's pin (tracked); in combat NeedRoll's own pin marks it and chat says why (`ns.UI.ShowOnMap`). NeedRoll's window stays shut. Right-click passes through to the game's map (`SetPassThroughButtons("RightButton")` through `UI.PassRightClicks`, after combat for markers made in it) |
| Mode button | A 26 × 26 button (`MODE_BUTTON_SIZE`) on the markers' layer, 10 in from the map area's bottom left corner (`MODE_BUTTON_INSET`, as the zone button's from the bottom right; the game keeps its own buttons in the top corners), at the game canvas's frame level + 34 (`MODE_BUTTON_LEVELS_UP`: over the markers, under the zone button and NeedRoll's own pin). It doesn't pan or zoom with the map. NeedRoll's dice, the window title's icon `lootroll-toast-icon-need-up`, fitted into 24 and centred; the minimap button's glow (`Interface\Minimap\UI-Minimap-ZoomButton-Highlight`, ADD) under the mouse. Shown on every map while the game's map shows, hidden while Settings' Quest givers on the world map, Books on the world map and Portals on the world map are all off (or the tabs they need) |
| Mode looks | Three modes, a left click going to the next: all, incomplete, off, then all again; saved account-wide (`NeedRollDB.mapMarkers`, "incomplete" by default). All: the dice in full colour, nothing else. Incomplete: the same, with the game's `QuestNormal` "!" fitted into 12 (`MODE_BADGE_SIZE`) at the button's bottom right corner. Off: the dice desaturated at 0.5 alpha (`MODE_OFF_ALPHA`), no badge. A click redraws the markers at once |
| Mode tooltip | `ANCHOR_RIGHT` (towards the map, away from its left edge): "NeedRoll map markers" as its title; the mode in `Theme.tip.text`: "On: every quest giver and book, those done faded", "On: only quests you haven't done and books you haven't found" or "Off"; while on, "Dungeon and raid quests within 10 levels of yours" in `Theme.tip.info`; last "Click to change" in `Theme.tip.hint`. It follows a click. Right-click passes through to the game's map (`UI.PassRightClicks`) |
| Faded markers | Mode all only: a quest done or in the quest log (on its own giver, the `Quest-Campaign-Available` icon when a questline comes before it, else `QuestNormal`), a quest or questline step under the level it needs, and a book handed in, in the bags or in the bank. Drawn desaturated at 0.5 alpha (`FADED_ALPHA`), the same size and hover. A giver's marker holding a quest still to take and a faded one is drawn live, its live quests first in the tooltip. In the tooltip, after the quest's (or book's) lines, why in `Theme.tip.quiet`: "Completed", "In log", "Requires level 14"; "Handed in", "In bags", "In bank" (`LibraryBooks.STATUS_TEXT`, the Library tab's words) |
| Updates | Worked out again when the map opens after quests are taken, abandoned or handed in, bags or the bank change, a level is gained, the zone changes or a Settings switch flips; while the map shows, at most every 0.5 seconds (`REBUILD_GAP`), and again 1 second after a hand-in or level-up (`LATE_FLAG_DELAY`). Drawn again when the shown map or the canvas's size changes |

## Shopping List

The whole pane is drawn at `Theme.shoppingScale` (1.15 at Normal text, 1 at
Large) on top of the window's scale; the values below are in the pane's own
units (`UI/Shopping.lua`).

| What | Value |
| --- | --- |
| Gold line | "Total gold on all characters: 12g 34s 56c" in `body`, `muted` (`heading` while the mouse is on it), at the pane's bottom left: 18 in (`Size.pad` + 4, level with the column labels) and 7 up (`Size.pad` - `Size.scrollBottom`), 22 high (`GOLD_LINE`), only as wide as its text. Shown with or without items on the list. The amount is `ns.Money` with each coin letter in the game's coin colour, "0c" for no money. Both columns stand on it (their bottom edge 29 up, rows cut off 36 up), so it never covers a row. Redrawn with the pane and on `PLAYER_MONEY` while the pane shows |
| List button and strip | As the Wishlist's (`UI/SavedLists.lua`): the current list's name as a pill with a down chevron (`Theme:Pill` + `Theme:SortMark`, 14 wider for it, the chevron 9 in from the right), 12 after the "Shopping List" title, level with it; it opens the 240 wide list menu 4 under it (each list with its item count, New empty list..., Rename..., Delete list). Shown with or without items. The strip holds, right to left from 10 in, 6 apart: Clear list (ask-once, only with items), Export (dimmed to 0.4 alpha on an empty list), Import, Save preset (plus symbol); the strip always shows |
| Crafted row counts | With a subtract box ticked, a crafted row (the added item, or an opened material) counts what is left to craft, "8x", and 6 after it in `small`, `faint` what the bags and alts already hold of it: "7 in bags", "3 on alts" or both joined by `Theme.DOTS`. When they hold every one wanted, the count reads "Covered" in `complete` (modern `5FCB86`, native `1AFF1A`) and its materials read "0x". The name gives way to the note; no row comes or goes when a box is ticked. Unticked, the rows read as before. Its tooltip adds, after the item's lines, a blank line and Wanted, In bags (with the bags box), On alts (with the alts box) and To craft, labels in `Theme.tip.info`, numbers in `Theme.tip.text` |
| Bought entries | An item imported without a NeedRoll recipe is an added row with no open box and no materials, "5x" in `muted`; One more / One fewer step by 1 |
| Import dialog | `Theme:Dialog` 520 by 360 (`WIDE_DIALOG`, `IMPORT_HEIGHT`), the Wishlist's: the hint, the paste box (130 high, `small` text, "Paste here (Ctrl+V)" in `faint` while empty) 10 under it, the preview 12 under the box in `body` ("Elixirs, Herbs  ·  2 items" in `heading`, or what's wrong in `incomplete`), then 4 under it in `small`, `muted` the names not found (5, then "+N more") and "Loading item names..." while the game sends them; the New list / Replace current switch with the name box (200) 14 under that; Import and Cancel |
| Export dialog | `Theme:Dialog` 520 by 170 (`EXPORT_HEIGHT`): the hint, the read-only text box 12 under it with the Auctionator line selected, "Loading item names..." in `small`, `muted` 8 under the box while a name hasn't come; the Materials to buy / Items on this list switch (`Theme:LabelToggle`) at the bottom left where the Wishlist's Export has its tick box, and Done |
| Gold tooltip | `ANCHOR_TOPLEFT` on the gold line: "Gold on each character" in `Theme.tip.title`, then one line per character, richest first: the name in its class colour (`RAID_CLASS_COLORS`, 0.8 grey when unknown), "Name-Realm" when the realm names saved for them differ (a character with no realm name known, as WoW: Forever's build 71037 left `GetRealmName()` empty, shows its name alone; `KnownRealm`, `SpansRealms`), the money at the right in `Theme.tip.text`; a blank line, then "Other characters show the gold they had when you last played them." in `Theme.tip.quiet`, wrapped |

## Wishlist

| What | Value |
| --- | --- |
| Owned item rows | An item this character has (worn, in the bags or in the bank) stays listed, greyed out: its icon desaturated, its quality edge in `line` (modern `C1EEFF` at 8%, native `FFD100` at 18%), and its name and every other text on the row in `faint` (modern `C1EEFF` at 28%, native `808080`). On Overview they leave the runs and facts and sit last in the right column under "Owned (n)", in paper-doll order; on Details they keep their place and their Owned tick (`ShowFaded` in `UI/Wishlist.lua`) |
| Item row star | Every item row on Overview and Details has a 14 star (`Theme:Star`, `STAR`) 6 in from the row's left, centred on the row, in a 28 wide column (`STAR_COLUMN`): Overview's item icon starts 28 in (was 8), its name 28 past that (`ITEM_INDENT`); Details' columns start after it. Run headers, group labels and notes have none. Lit while the item is on the list; hovering it lights the row and shows "Remove from wishlist" (unlit: "Add to wishlist") `ANCHOR_RIGHT` |
| Unstarred item rows | A star clicked off takes the item off the list, but its row stays where it was until the player leaves the page (another tab, Overview/Details, another list, Clear list or Import, closing the window): greyed out as an owned row (`ShowFaded`), its star unlit. Clicking the star again puts the item back in its old place on the list. Nothing moves while rows are unstarred: runs, groups, chips and rows keep their places, and only the counts change (the facts, run headers' "n items", group labels' "(n)", the chips' numbers, the subtitle and the status line count what's still wished). An emptied list keeps its unstarred rows rather than showing the empty hint |
| Item tooltip's sources | Under the game's item tooltip, a blank line, then up to 6 sources ("+N more" after) and "Click to open its source" in `Theme.tip.hint`. Each starts with the icon for how it is got, in an 18 box, then a space: the tab's icon (`UI.TabIcon`; the dungeon and raid entrance portals cut 15% in from each edge so they show bigger, the others fitted keeping their shape) or, for a quest, the maps' quest marker (`Crosshair_Quest_96`). Then "Roogug  ·  Razorfen Kraul" in `Theme.tip.info`, with the drop chance or the kind ("Drop", "Crafted", "Quest"...) at the right in `Theme.tip.good`. The game's own item tooltips use the same icons before their dungeon and raid lines (`Tooltip.SourceIcon` in `Core/Tooltip.lua`) |
| Wished fact | the list's item count ("n items"); when any are owned, "n to get  ·  n owned" instead. The subtitle adds the same "n owned" after the item count, and its "n from dungeons and raids" counts every drop on the list |

## Classes tab

The last tab. Three columns a gutter (12) apart: the classes, the picked
class's sections, and the picked page in a content pane with a strip.
(`UI/Classes.lua`, `UI/ClassOverview.lua`, `UI/ClassSpells.lua`, `UI/TalentPlanner.lua`, `UI/TalentLinks.lua`,
`UI/TierSets.lua`, `UI/Poisons.lua`, `UI/HunterPets.lua`, `UI/WarlockPets.lua`, `UI/MageScrolls.lua`,
`UI/Questlines.lua`, `BuildClassesTab` in `MainFrame.lua`)
Picking another class leaves the columns, the right pane and the sections
column's scroll where they are, and each section open or shut as it was.

| What | Value |
| --- | --- |
| Tab icon | `Talents-up-c60` (the Talents section's icon), on the class column's label and the tab's row in Settings (`WHOLE_BODY_ICONS` in `MainFrame.lua`) |
| Class column | 260 wide, as the instance list (`Theme.size.instanceList`), labelled "Classes"; a 34 row per class (`CLASS_ROW`), its ring badge then its name in the game's class colour (`C_ClassColor.GetClassColor`), even when picked. "You" at the right of your own class in `small`, `muted` |
| Sections column | 263 wide, as the Dungeons and Raids encounter list (`Theme.size.questList`), labelled with the class's badge and name in `pane`. Its sections are the dungeon list's group headers (40 high, the icon on a 30 disc, `section` font, the section arrow, the figure in `small`, `muted`) and its pages child rows (24, 8 in); the active section sits in the section card (`ns.UI.CreateSectionList` in `Lists.lua`). Talents (`Talents-up-c60`) shows the points in each tree of the plan on show, "20/0/31", and holds Planner, the class's saved plans and "+ New plan" |
| Overview section | The first row, above Abilities: a section header (40 high, the dungeon Overview row's `GameMenu-up-c60` on its 30 disc, `section` font) with no figure, no arrow and no pages. A click opens the class's Overview; while it shows, the header sits in a closed section card (its whole outline, as a dungeon's Overview row). The tab opens on it until another page is picked; a page picked (Planner, a tab, a quest, a set) stays picked across classes and tab switches for the session, and a chat plan link still opens the planner |
| Overview page | The right pane's page (`ns.UI.CreateClassOverview`): the class's ring badge (`Theme:ClassBadge`, 34, `TITLE_BADGE`) 16 in and 12 down, its name 10 after it in `instance`; under the badge, 4 down, one line in `body`, `muted`: your own class "6 of 47 spells trained  ·  To level 60: 45g 27s", another class "47 spells  ·  Alliance and Horde". Strip: your own class "Level 30  ·  Alliance" in `body`, `muted` at the right, 10 in (another class: nothing) |
| Overview stat boxes | 12 under that line, side by side across the page 16 in from each side, 10 apart (`BOX_GAP`), each 74 high (`BOX_HEIGHT`) on the Overview stat boxes' backdrop (`Theme:StatBackdrop`: modern a rounded `factFill`, `C1EEFF` at 5%; native a soft shadow with a gold rule on its left). Text 12 in (`BOX_PAD`): the label in `factLabel` 8 down, the value in `factValue` and a note in `small`, `muted` (at most 2 lines), 3 apart. Lit under the mouse in `hover` (modern `3E607F` at 45%, native `FFFFFF` at 10%); the tooltip is the label and "Click to open Abilities" (or Quests, Talents). Your own class: Train now ("3 ranks  ·  1g 40s", the first rank's name, "Frostbolt 7 and 2 more"; "Nothing to train"), Next at 32 (the next level that brings ranks: their count and cost, its new spells named first; "Next level" / "All ranks trained" once none is left), Quests ("4 of 7 done", "Next: <quest>"), Talents ("21 of 21 spent", "Plan: 20/0/1"). Another class: Abilities ("47 spells", "All ranks: 45g"), Quests ("23 quests"), Talents ("Plan: 0/0/0", "51 points at level 60"). Train now opens the Trainable page, Next its tab on the next level's chip, Abilities the first tab on All, Quests the next quest's page (another class's first), Talents the planner; the section slides open so the page's row shows |
| Overview list | 14 under the boxes, scrolling (`Theme:ScrollColumn`), your own class only. Each heading has the section divider along its row's top (`Theme:Divider`, 16 in each side). "Your trainers" in `section`, `heading`, with "Alliance  ·  listed by distance  ·  Horde trainers hidden" in `small`, `muted` 8 after it (one line, cut short at the row's right) (a 30 row, `HEADING_ROW`); then your side's class trainers and those who serve both, nearest first (the recipe trainers' order), 22 rows (`LINE_ROW`) 16 in: the giver's mark (`TaxiNode_Continent_Alliance`, half again the text's size) and the name in `link` (modern `FCD29F`, native `71D5FF`) in `body`, a portal trainer's "Teleports & Portals" in `muted` after it, the zone in `small`, `muted` at the right, 16 in. The whole row is a map pin link (as a recipe's source line): the tooltip names them, their zone and "Click to pin on your map". Five show (`TRAINERS_SHOWN`), then "N more trainers" / "Show fewer" in `heading` with the section arrow 4 after it (10, as a recipe's); opened, the whole list stays open on every class (Remembered sections, `"trainers"`). Then "Coming up" (`section`, `heading`): the next 3 levels that bring ranks (`COMING_LEVELS`), each its level in `heading` in a 30 column, its ranks by name, new spells first, 4 named then "and N more", and their cost in `small`, `muted` at the right (the tooltip lists every rank and its cost); the class quests not done that open by the last of those levels, by level, the name in `quest` (`FFFF00`) with "Class quest" at the right, a click opening its page; then "+6 talent points by level 36" in `small`, `muted`. With nothing ahead, "Nothing new ahead.". Another class: "Your trainers and what's coming up show on your own class." in `small`, `muted` instead (other classes' trainers are left out, both sides') |
| Abilities section | After Talents, before Quests, with the game's spellbook icon (`Spellbook-up-c60`). Its figure is how many of your class's spells you've trained (any rank), "31/47"; on another class, just how many spells it has, "47". Its pages are, on your own class, Trainable first (every spell with a rank to train now, from any tab; no chips; the Overview's Train now box opens it), then the class's spellbook tabs (the three talent trees, then General for weapon and armor skills; the mage's last is Teleports & Portals; the priest's last is Racial Abilities), 24 rows with how many spells each lists in `small`, `muted` at the right. Your own class lists only your side's spells and counts only your race's racial spells (the figure, the rows' counts, Trainable and the Overview); another class lists both sides' and every race's. Picking another class keeps the same tab open when it has one (Protection from paladin to warrior), else opens its first |
| Spellbook tab page | The right pane's page for a picked tab (`ns.UI.CreateClassSpellPage`): the tab's name in `instance`, 16 in and 12 down; under it, 4 down, one line in `body`, `muted`: your own class "Paladin  ·  1 of 18 spells trained  ·  3 ranks to train now (1g 50s)  ·  To level 60: 45g 27s", the training part in `complete` (modern `5FCB86`, native `1AFF1A`); another class "Mage  ·  12 spells  ·  12 ranks  ·  All ranks: 14g 80s". Money is text ("1g 50s", `ns.Money`): the digits in the line's colour, each coin's letter in the game's coin colour, gold `FFD700`, silver `C7C7CF`, copper `EDA55F` (everywhere `ns.Money` writes a cost). The spells scroll 10 under that line (`Theme:ScrollColumn`), a 46 row each (`SPELL_ROW`) with a 1px `line` rule under it: the spell's icon, 32 (`ICON`), 16 in and centred, edged in `line`; 10 after it the spell's name in `body` with the rank in `muted` after two spaces ("Rank 3 of 8", "Not trained", "Trained"; another class "8 ranks"), 7 down (`NAME_TOP`); the first line of the game's description in `small`, `muted`, 25 down (`ABOUT_TOP`), stopping 12 short of the training line. At the right, 16 in (`RIGHT_INSET`): one 7 dot per rank (`DOT`, 3 apart, 10 down; the game's round mask), gold `accepted` (modern `F2D45C`, native `FFFF00`) for ranks known, `complete` for ranks to train now, `faint` for the rest and for every rank of another class; under them, 25 down, the training line in `small`: "Train now: ranks 4 to 5  ·  1g 50s" in `complete`, else "Rank 6 at level 38  ·  1g 60s", "Rank 1 from a talent" (or quest) or "All ranks trained" in `muted`; another class "Levels 1 to 54  ·  10g 80s" in `muted`. A spell no Classic trainer taught, whose price isn't known (the priest's Fear Ward and the racial spells new in WoW: Forever: Divine Grace, Chastise, Confounding Flash, Contingency Plan, Dark Sacrifice), shows no cost: "Train now: rank 1", "Rank 1 at level 10", another class "Level 10". Talent spells come last in their tab. Hover shows the game's tooltip of the rank the training line names; Shift-click links it in chat. A click opens the spell's ranks under it (again shuts them), a 10 chevron (`OPEN_ARROW`, the Overview toggle's `Theme:Arrow`) 6 after the name's words (`OPEN_ARROW_GAP`) pointing right when shut, down when open; the rule then sits under the last rank instead. Rank rows are 20 (`RANK_ROW`) in `small`, from the name's edge: "Rank 3" in `text` in a 64 column (`RANK_NAME_COLUMN`), its level "Level 20" in `muted` in an 84 column (`RANK_LEVEL_COLUMN`), and at the right, 16 in, its state in a 70 column (`RANK_STATE_COLUMN`): "Known" in `accepted`, "Train now" in `complete`, "Later" in `muted` (none on another class, or for a quest or talent rank 1 not known); its cost in `muted` right-aligned 8 before the state (`RANK_COLUMN_GAP`), or "Rank 1 from a talent" (or quest); none for a rank whose price isn't known. Hover shows that rank's tooltip, Shift-click links it. An opened spell stays open on every tab and when the page opens again (Remembered sections, `"spells"`); the list keeps its scroll while the tab and chip stay. Racial Abilities (the priest's) puts a 36 heading row (`RACE_ROW`) before each race's spells, your own race first, then the others in Alliance-then-Horde order (Human, Dwarf, Night Elf, Gnome, Undead, Troll): the race's icon in the class badges' bronze ring (`Theme:ClassBadge`, 24, `RACE_BADGE`), centred where a spell's 32 icon is; the icon is the game's male portrait atlas `raceicon-<race>-male` (the race's file name lowercased, Undead's `undead`), fitted whole at 80% of the opening and clipped round (`badge:SetIcon`), and no badge when the game lacks that atlas; the race's name in `section`, `heading`, level with the spells' names (16 + 32 + 10 in), and its side 8 after it (`RACE_NOTE_GAP`) in `small`, `muted`; no dots, open arrow or rule, and no hover or click. Another race's spells there read as another class's (levels and cost, faint dots; their rank rows show levels and costs but no state), and the line under the page's heading and the chips' Train now and next level count only your race's |
| Spellbook tab strip | Your own class: chips at the left, 10 in, 6 apart (`Theme:Pill`, the picked one filled in `heading` as the Wishlist's): "All  18", "Train now  3" and the next level that brings a rank with how many spells have one there, "Level 32  2" (none once nothing is left). "Level 30  ·  Holy" in `body`, `muted` at the right, 10 in. Another class: no chips, the tab's name at the right. "Nothing to train right now." in `body`, `muted`, 16 in and 10 down when Train now keeps nothing |
| Quests section | After Abilities, before Class Sets, with the dungeon Quests group's icon (`Exclamation-up-c60`). Its figure is how many of your class's quests you've completed, "4/7"; on another class, just how many quests it has, "23". Every class lists one side's quests: yours until the header's faction toggle (see Faction toggles) picks the other. Picking a side slides the section open; a quest page open moves to that side's first quest unless it lists that quest too. Quests teaching the same spell, one per city or side (the warlock's Imp quests and Bindings, the priests' race spells; `group` in Data/ClassQuests.lua), are one row: the quest starting nearest you (its chain's first giver, else its own), named and opened as itself, reading Completed once any of them is done. So are the city copies of one breadcrumb QuestieDB doesn't flag (`breadcrumbs` in `forever.json`: the rogue's Erion's Behest, Kingly Shakedown and SI:7 to The Shiv, now a version step of its Alther's Mill questline) and versions of one quest from different givers (The Tome of Nobility from Duthorian Rall, Tiza Battleforge or Brandur Ironhammer); quests of one name that follow one another (Call of Water's waterskins) are rows of their own. Each quest is a 36 row (`ROW.CHILD_NOTE`) drawn like a dungeon's Quests row: a chain's later step after its numbered circle, the name in `body` (the rogue's poison quest, Alliance The Touch of Zanzil and Horde Hinott's Assistance, follows it with the `icons_64x64_poison` atlas a space after it at the name's line height, inline `|A` markup sized 0:0 so it wraps with the name: `TITLE_ICON_MARKUP` in `UI/Lists.lua`, `Poisons.QuestTitleIcon`), the status under it in `note` font in its quest page colour, then at the right the quest's level in `small`, `muted`, level with the name and 4 (`QUEST_FIGURE_GAP`) left of the dungeon portal (a quest that starts inside its dungeon) and the insignia of the sides that can take it. No class badge on the rows. Picking another class while a quest shows opens that class's first quest |
| Quest folds | A class's questlines picked by hand (`classQuestFolds` in `scraper/quests/forever.json`, Data/ClassQuests.lua's `RegisterClassQuestFolds`; every class has some, the Skyborn's paths labelled "Skyborn") (`UI/Questlines.lua`). Each is one 36 row (`ROW.CHILD_NOTE`) where its first quest would sit: its name in `body` in `heading` gold, as the raid Attunement heading; under it, in `note` font, where you stand: "Completed  ·  Night Elf path" in `complete`, "Ready to turn in: Bartleby's Mug" in `complete` or "Accepted: Bartleby's Mug" in `accepted` (the first quest it counts in the quest log, objectives done or not), "After The Affray" in `faint` (a questline that follows another not done), "Not started  ·  Level 10" or "Next: Bartleby's Mug" in `muted`, cut short at the row's right. At the right the Attunement heading's plus / minus (`Theme:Arrow`) and 6 left of it the figure in `small`, level with the name (6 up): how many of the quests you do are done, "8/13" in `muted`, once all are done the tick (`common-icon-checkmark`, 11) and "4/4" in `complete` (alternatives count the one taken, else the one furthest along; optional quests, lead-ins and retries a player may skip, aren't counted). Shut to start. A click opens the questline page and slides the fold open (0.2 s); once its page shows, a click slides it open or shut. A questline's quest opened from elsewhere (the Overview's Quests box, a chain link, a card) slides its fold open. Open, it lists, 22 in (`INDENT.FOLD`): for a questline built from a Classic guide (`TENTATIVE_CLASS_QUEST_FOLDS` in Data/Data.lua: Benediction, Quel'Serrar) a line as the Teaches one, "May not be final for WoW: Forever"; for a questline that teaches spells a line in `note` font and colour, not a button, "Teaches Defensive Stance, Sunder Armor (Rank 1) and Taunt (Rank 1)" (else "Rewards" and its last quests' items); then a 36 row per part: "Steps 1–4" ("Step 1"; numbered as the questline page's circles, an optional quest having no number, so "Optional" for steps that are all optional), each branch, "Final steps" ("Final step"). A branch is named by what it makes or binds (Gauntlets, Succubus), its races ("Dwarf, Gnome", the game's names), the city of its last giver for alternatives, else its first quest. Under each, in `note` font, `muted`, cut short: the first giver and their zone, or (steps, a city's branch) its first and last quests' names, "Bartleby the Drunk to Bartleby's Mug". Its figure as the fold's, level with the name, 14 in from the right. Alternatives have a 16 row (`ROW.OR`) between them, "or" in `note` font, `faint`, not a button; once one is done the others are dimmed to 0.4 (`Questlines.DIM_ALPHA`, as on the questline page), and alternatives one per race (the priest's level 10 and level 20 racial spells, the warlock's Imp quests) dim the other races' from the start when one is your race's. A branch of alternatives left alone on the side picked is listed as steps. A questline with a second stage (`followUp`: Defensive Stance's weapon quests, one per race's path, named as the first stage's) lists it after the first's rows: a line as the Teaches one, "Then rewards a weapon of your choice" (else "Then one of these"), then its rows the same way, "or" between them, the ones not taken dimmed once one is done. The fold's figure counts each stage's alternatives once: the one taken, else the one furthest along (in the second stage, on a tie, the one for the races of the first stage's). A part's row opens its next quest, the first not done after the last done (a lead-in skipped stays behind), and is picked while one of its quests shows. The side's quests only; a questline with none on the side isn't listed. The Quests figure counts a questline by the quests that end each stage, a stage's alternatives as one |
| Questline page | The right pane's page for a questline (`ns.UI.CreateQuestlinePage`, on `Questlines.CreatePage`, which the Dungeons tab's questline page shares), scrolling (a scroll frame, 40 a wheel notch, `Theme:ScrollBar` 8 from the top and bottom). 16 in (`PAD`): its name in `instance` 12 down; 4 under it in `body`, `muted`: "Alliance  ·  Questline level 10  ·  3 of 13 quests done" (the side only when every quest is one side's; "Completed on the Night Elf path" once done); on a dungeon's page the guide under it (Leads to and Next step: see Dungeons tab, Questline page). For a questline built from a Classic guide, 16 under that "May not be final for WoW: Forever" in `body`, `heading`. 16 under that "Teaches" ("Rewards", else "Progress") in `section`, then 6 under it the spells' or items' names in `body`, then 6 under those a pill per branch (else one for the steps; `Theme:Pill`, 20 high, 6 apart, wrapping): "Human  ·  2/4", toned `complete` once done, 0.4 when not taken; a click opens its first quest not done. For a questline with steps that aren't quests (`CLASS_QUEST_FOLD_ITEM_STEPS` in Data/Data.lua: Benediction's two eyes and the staff), 16 under the pills "Outside the quests" in `section`, then 6 under it one line each in `body`. 16 under the pills (or those lines) "Questline" in `section`, and 10 under it the questline. The questline runs down the page as a route: a 34 gutter at the left (`ROUTE.GUTTER`) holds the spine, and each step sits right of it, 14 under the one before (`CARD_GAP`). Each numbered step has a circle on the spine, level with its card's middle (25 under a box's top, a card's middle): 24 round (`ROUTE.CIRCLE`), centred 12 in from the page's content, a round disc in `disc` (`Theme:MaskRound`) in the section discs' ring (`Mode-Selection-Ring-c60`, desaturated) coloured `complete` once the step is done, `accepted` for the first step not done (the one to do now), `discRing` gold for those after; its number in `small`, in the ring's colour (`heading` for those after). Numbers count steps, not quests (`Questlines.StepNumbers`, as the fold's parts, the quest page's chain and the world map markers count them): a box of several quests is one step, and an optional quest or breadcrumb has none. The spine is a line from each circle to the next, `flowDone` between two steps done. Each quest is a card 50 high (`CARD_HEIGHT`), on the route at most 340 wide (`ROUTE.CARD_MAX`), in a column at most 160 (`CARD_MAX`): a rounded `shutFill` fill (`hover` on hover) and outline, `shutEdge`, `complete` once done or ready to turn in, `accepted` while in the quest log; 7 in (`CARD_PAD`), 2 apart, its name in `body` (the tick before it once done), its giver in `small`, `link`, and its giver's zone in `small`, `muted`. While its quest is in the quest log a status tag sits at its bottom right, on the zone line: as the "Optional" tag (14 high, a rounded outline, the word in `small`, 5 in), its top at the giver line's bottom and its right edge 5 in, under the top tag's; "Accepted" (text and outline `accepted`) or "Ready to turn in" (`complete`, its objectives done, `C_QuestLog.ReadyForTurnIn`), and on the goal "Completed" (`complete`) once done. The zone line stops 5 (`TAG.PAD`) short of it. An optional quest's card (`optional` in the fold, or for a dungeon's questline in Data/Chains.lua's chain: a lead-in or retry a player may skip) is at full strength with a dashed outline in place of the solid one (`Theme:DashedOutline`: 1px dashes 4 long, 3 apart, `DASH_LENGTH`, `DASH_GAP`, each corner left 4 clear, `BOX.CORNER`), `pillEdge` gold until done (`complete` once done or ready to turn in, `accepted` in the quest log), and a tag "Optional": at its top right, 5 in, 14 high (`TAG.HEIGHT`), a rounded `pillEdge` outline, the word in `small`, `heading`, 5 in (`TAG.PAD`), the name stopping 5 short of it. It has no number and no figure counts it. A version step (one step done by any one of several copies of a quest: city copies of one breadcrumb, as the rogue's three to The Shiv, Gakin's Summons or The Slaughtered Lamb) is one card showing the version starting nearest you, as a quest group's row picks it, done once any version is, its zone line ending "or 1 other" ("or 2 others"). A click opens the quest's page. A step of several quests is one box, drawn on the route (`DrawGroupBox`): a rounded `pillEdge` outline, solid round quests all needed (the branches of a questline that aren't alternatives, a dungeon chain's `{ all = ... }`), dashed as an optional card's round alternatives; no fill. 8 in (`BOX.PAD`), its heading in `small`, `heading`: "Do both, any order" ("Do all 3, any order"; with "1 of 2 done" in `small`, `muted` at its right) or "Pick one"; 6 under (`BOX.HEAD_GAP`) its columns, as many to a band as fit at 112 or more (`CARD_MIN`; the rest in bands 18 under, `BAND_GAP`), 18 apart (`COLUMN_GAP`), with "+" in `small`, `heading` gold (all needed) or "or" in `faint` (alternatives) in the gap, level with the cards' middle (between bands, in the band gap). It is as wide as its columns + 16, 340 at least. Each column's name and status over it in `small` (a branch's: the name in `heading`, its figure, "✓ Completed" in `complete`, "Forgone alternative" or "Other race" in `faint`), 4 over its cards (`BOX.LABEL_GAP`), on two lines when too wide ("Dwarf, Gnome" over "Forgone alternative"); its cards down the column 14 apart (`CARD_GAP`), joined by a line down with an arrowhead meeting them 12 in from their left (`SPINE`), dimmed to 0.4 (`DIM_ALPHA`) when not taken. Alternatives one per race, until one is done, put your race's column first; the other races' say "Other race", their cards dimmed to 0.4. On the other side's page, or when none is your race's, they are drawn as any alternatives. A breadcrumb in a dungeon's chain (`Data:IsBreadcrumb`) is a chip, not a card, over the step it leads to: 22 high (`CRUMB.HEIGHT`), its text + 16 wide (8 in, `CRUMB.PAD`; the route's width at most), a dashed `pillEdge` outline, no fill (`hover` under the mouse): "BREADCRUMB" (`Theme:Label`) in `heading`, its name in `text`, then "  ·  giver  ·  zone" in `muted`, all in `small`; 3 under it (`CRUMB.NOTE_GAP`) "Optional: only sends you to Je'neu Sancrea. Skip it if you know the way." in `small`, `faint`, wrapping. No number; a click opens its page. A stage ends, 14 under its last step, at a pill "Teaches Summon Voidwalker" (not a button) in line with the steps; a second stage (`followUp`) follows 14 under, its steps numbered on from the first's: "Pick one" over Defensive Stance's weapon quests, then a pill "Rewards a weapon of your choice" (not a button). Lines are solid and opaque, `Theme:LineWidth` wide (the loot pane's thick border's stroke), their edges on whole pixels, straight down, in both skins: `flowLine` (modern 2B465A, the cards' `shutEdge` over `panel2` made opaque; native 4A4540, the same over the dimmed parchment), `flowDone` where a line joins two finished steps (modern 3B875B, `accent`; native 1AFF1A, `complete`). Each straight piece and arrowhead row has a soft edge: a screen pixel of its colour at 0.4 alpha (`FRINGE_ALPHA`) along each long side, on whole pixels, a sublayer under the solid pieces; no two pieces overlap. Arrowheads are solid stepped triangles in the line's colour: rows one pixel deep, the tip 1 or 2 pixels wide (as centres it on the line), each row 2 pixels wider, reaching 4 back from the tip (`ARROW`). A page of one step (a box) has no line |
| Questline and quest page strips | "Classes  >  Warrior  >  Quests  >  Defensive Stance" in `small`, `muted`, the questline's name in `heading`, 14 in (a quest page: "Warrior  >  Bartleby's Mug"); at the right, 10 in (`STRIP_INSET`), ‹ and › (two 20 buttons 2 apart, each two 6 × 1.5 strokes at 45°) in `heading`, `accent` on hover, `faint` while there's nowhere to go. A card, a pill or a quest page's chain link leaves a trail that ‹ and › walk, as does a right-click on the questline or quest page (as Back on the Dungeons tab); a pick in the class or sections column starts a new trail |
| Quest page | The right pane's page for a picked quest: the Dungeons tab's quest page as it is (`ns.UI.CreateOverview`), set in the dungeon or raid its targets stand in, else under the zone of its giver's map spot. Its bosses and dungeon map links open that dungeon on the Dungeons tab, Back returning here; a chain step it names opens here. A quest whose rewards no source knows has no Rewards heading. The strip reads "Mage  >  Destroy Morphaz" in `small`, the class and ">" in `muted` and the quest in `heading`, `Size.pad` in |
| Saved plans | A 36 row each (`ROW.CHILD_NOTE`), between Planner and + New plan: the plan's name in `body`, "Saved plan" in `note` font, `muted` under it, and its points per tree ("20/0/31") in `small`, `muted` at the right, level with the name. The open plan's row is picked (Planner while none is). "+ New plan" is a 24 row with its name in `muted`. Right-click a saved plan for its menu (`Theme:Menu`, 180 wide, `PLAN_MENU_WIDTH`), 2 under the row and `Size.pad` in: Link in chat, Rename... and Delete plan |
| Planner strip | Import, Export, Link, Reset and My talents pills at the left, in that order (10 in, 6 apart; My talents only on your own class); nothing at the right, so they fit the 960 window |
| Heading | "Your talents" (another class: "Mage talents") in `instance`, 16 in and 12 down; the points per tree ("20 / 0 / 31") in `body`, `muted`, 10 after it; under it, 4 down (`LINE_GAP`), the points line "Level 60  ·  51 points  ·  0 left" in `body`, the numbers gold `FFD100` and what's left green `40BF40`; under that, 4 down, "Loaded from your character. Click to add a point, right-click to take one back." in `body`, `muted` (once the plan is changed, just the second sentence; with a saved plan open, "Saved plan Frost 1." before it), wrapping 16 short of the pane's right edge |
| Import and Export | `Theme:Dialog`s 520 wide (`SHARE_DIALOG_WIDTH`) over the whole tab, the hint in `small` and one text box 12 under it. Export (150 high) shows the plan's share string selected, read only, with Done. Import (190 high) takes a pasted string; what's wrong with it shows in `small`, `incomplete`, 10 under the box, and a good one closes the dialog and says "Imported a Mage plan." on the status line. A chat link that can't be saved opens Export titled "Talent plan", 190 high, with its string and the reason under the box as Import shows one |
| Link in chat | Link (strip) and Link in chat (a saved plan's menu) put "[NR Talents: Fire] NRT2:8:..." in the chat box (`ns.UI.TypeInChat`), named for the saved plan, else the class. Inside an instance or in combat a notice comes first: a `Theme:Dialog` 420 by 150 (`NOTICE_DIALOG_WIDTH`, `NOTICE_DIALOG_HEIGHT`) titled "Link in chat", its hint in `small` wrapped to the dialog's width less `Size.pad` each side, with OK and Cancel |
| Plan links in chat | A received line's "[NR Talents: Fire] NRT2:..." shows as a link reading "[NR Talents: Fire]" in the game's gold `FFD100` (`LINK_COLOR` in `UI/TalentLinks.lua`), the share string hidden in the link. A click opens the window on the Classes tab with the plan saved and open ("Saved Fire, a Mage plan." on the status line); Shift-click puts the plain line in chat |
| Trees | From 16 under the line about the plan (`TREES_GAP`; 82 down while it is one line) to 12 above the pane's bottom, 12 in from its sides, 8 apart, each a third of the room. Each tree's name in `pane` (gold) and its points in `body`, `muted`, 10 in, centred in a 28 strip across its top |
| Tree art | The class's `talent-background-<class>` atlas (all three trees in one picture) scaled to cover the three trees, centred and cropped, never stretched; each tree shows its own slice, at full strength |
| Tree edge | The section card's outline in `sectionEdge` (gold `FFD100` at 55% native, `3B875B` modern) with no fill: crisp across the top with 5 rounded corners, the sides solid down 20% of the tree, then fading to clear at its bottom; no bottom edge (`TREE_EDGE_SOLID`, `TREE_EDGE_END`) |
| Talents | On the game's grid: the step between two talents is at most 46 and fits the tree's rows and columns (a talent the game lists more than 2 grid steps from every other, down the trees or across its own tree, is left out: Forever's own window doesn't show it, `MAX_STEPS_TO_NEIGHBOUR` in `Core/Talents.lua`); the icon is 74% of the step, 18 to 34, inside a 2 frame: gold `FFD100` when maxed, green `40BF40` when it has points or can take one, grey `545454` while its row is shut or its prerequisites aren't met (each Required edge's talent maxed, and one of its Sufficient edges' talents). With no points the icon is half greyed at 85% (can take one) or fully greyed at 55% (shut) |
| Rank badge | "2/5" in `small`, gold, green or grey `878787` like the frame, on black at 85% 3 past the text, centred on the icon's bottom right corner |
| Prerequisite lines | 3 wide, along every edge the game draws (whatever its type), from the source talent's centre to its target's, under the icons: gold `FFD100` at 55% once the needed talent is maxed, grey `808080` at 55% before |
| Talent tooltip | Anchored right of the talent (`ANCHOR_RIGHT`). The talent's name (`C_Spell.GetSpellName`) in `Theme.tip.text` as the title, then the game's lines for the talent at its planned rank (`C_TooltipInfo.GetTraitEntry`; rank 1's at 0 points) copied with `AddLine` (wrapped) or `AddDoubleLine` in the game's own colours (white where it gives none), leaving out a first line that repeats the name; then "Rank 2/5" in `Theme.tip.info` and, while shut, "Requires 10 points in Arcane" lines in `incomplete` (talents any one of which is enough read "Requires 5 points in Starlight Wrath" then "or 5 points in Genesis"); planned part way, a blank line, the game's "Next Rank:" (`TALENT_BUTTON_TOOLTIP_NEXT_RANK`) in `Theme.tip.text` and the next rank's lines copied the same way. A client without entry tooltips, or an entry with no lines, shows the spell's (`GameTooltip:SetSpellByID`) and no next rank. Local checkouts add the node ID, row and column and each edge into it with its type, in `Theme.tip.quiet` |
| Class Sets section | After Quests (named Tier Sets before), with the Collections tab's icon (`Legacy-up-c60`); its figure is how many sets the class has. A 36 row per set (`ROW.CHILD_NOTE`): the set's name in `body`, its tier and where it comes from ("T1  ·  Molten Core", "D1  ·  Dungeons") in `note` font, `muted` under it, and its looks collected ("3/8") in `small`, `muted` at the right, level with the name. Dungeon sets, Zul'Gurub, Ahn'Qiraj 20, then T1, T2, T2.5 and T3; the Ahn'Qiraj 40 sets are listed once, as T2.5. Picking another class keeps the same tier's set open |
| Set page | The right pane's page for a picked set: the loot grid at full size (2 columns, 54 rows, no section boxes), titled with the set's name in `heading` and "T1  ·  Paladin  ·  Molten Core" in `small` under it. Each piece's second grey line names where it comes from: a boss in `dropper` red, a quest in `quest`, anything else in `link`; only the name takes the click, which opens it (Back returns to the set). The grid's look tick and wishlist star as on any loot page |
| Set bonuses | Under the pieces, 14 below them (`BONUS_GAP`), 18 in (`BONUS_LEFT`, level with the set's name): "Set bonuses" in `section`, then 8 down each bonus the game's tooltip lists, 4 apart: the pieces it needs in `body`, `heading`, in a 28 column (`BONUS_COUNT_WIDTH`; empty once reached, as the game writes it), and its text in `body`, wrapping, in the tooltip's own colour. When they don't fit under the pieces they sit 14 above the pane's foot and the pieces scroll above them |
| Set strip | "Wishlist the set" (all on the list: "Remove from wishlist") and "Open Molten Core" (only when every piece comes from one place) pills at the left, 10 in, 6 apart; "2 of 8 appearances collected" in `body`, `muted` at the right, 10 in. The planner's pills hide while a set shows |
| Poisons section | Rogues only, after Class Sets, with the minimap's poison vendor mark (`Poisons` atlas) on its 30 disc. Its figure is your Poisons skill ("220", `C_SkillInfo.GetSkillLineInfoByID(40)`), else how many recipes there are ("20"). While you have the skill the header also holds a "Known" tick box (`Theme:CheckBox`, label at its left), 8 left of the figure (`KNOWN_BOX_GAP`): ticked (the default) the poisons you already know are listed too, unticked they are left out (`C_SpellBook.IsSpellKnown`, through `RB:IsKnown`; saved per character). Clicking it doesn't open or shut the section. Its first page row (24) holds the chips while you have the skill: All, Skill-ups and Learnable now, text tab chips (`RB.Chip`) left to right with gold dots between them, starting 8 in from the rows' text (`CHIPS_LEFT`, level with the recipes' rings); one at a time, they pick the recipe list's Skill-ups narrowing and its Learnable at the second step (not known, and the skill reaches it). Then one 24 row per recipe the chip keeps, lowest skill first: what it makes in the recipe ring (24, 6 from the name, `RECIPE_ICON`, the item's tooltip on hover), the poison's name in `body` (the game's, by item ID), and the skill it is learned at in `small` at the right in your skill colour (`RB:SkillColor`; `muted` without the skill). The yellow, green and grey steps are 15, 30 and 45 above it (`CLASS_RECIPE_SKILL_STEPS` in `Data/Data.lua`), a guess to check in game. A page opened from elsewhere whose row the chip or the Known box hides puts the chips back on All and ticks Known |
| Poison recipe page | The right pane's page for a picked recipe: the loot grid at full size laid out as a profession's recipe page (`ns.UI.CreatePoisonPage`), titled with the poison's name in `heading` and "Poisons  ·  Skill 210  225  240  255  ·  Rogue level 46  ·  Costs 3g 10s" in `small` under it (the skill steps in the game's skill colours, `UI.SkillText`; money as `ns.Money` gives it). Creates (the poison) beside Learned from (Taught by: your side's rogue trainers, nearest first, as a recipe's; the first Instant Poison instead names the poison quest of your side, "Quest: Klaven's Tower", and its giver as a pin link; the Horde's, Hinott's Assistance, is a rogue class quest, so its name is in `quest` and opens its page), then Materials, each with its count ("x3") and under it "Nearest vendor" and the nearest vendor of your side selling it ("Name  ·  Zone", the zone in `muted`, a map pin link) |
| Poison page strip | "Add to shopping list" (the plus pill, `Theme:Pill`, the Professions tab's; "Add another  ·  1 on list" once listed; hidden while the Shopping List is off) at the left, 10 in; "Poisons  220 / 300" in `body`, `muted` at the right, 10 in, while you have the skill. A Shopping List row of a poison opens this page on the Classes tab |
| No talents yet | "This class's talents aren't available yet. Try again in a moment." in `body`, `muted`, centred where the trees go |
| Pets section | The hunter's and the warlock's, after Class Sets (no other class lists it), with the minimap's stable master mark (`StableMaster`); its figure is how many families a hunter can tame, "17" (a warlock: how many demons, "4"). A warlock's pages are Demon trainer, then Imp, Voidwalker, Succubus and Felhunter in the order a warlock gets them, each named and iconed as a family is and with the level it comes at ("10") at the right. Its pages are 24 rows: Pet trainer first, then each family by the game's name for it (`C_CreatureInfo.GetCreatureFamilyInfo`), its icon round, 17 (`PAGE_ICON` in `Lists.lua`, cropped 8%) before the name and 7 from it (`PAGE_ICON_GAP`), and how many of its beasts there are to tame in `small`, `muted` at the right |
| Pet page | The right pane's page for Pet trainer or a family (`ns.UI.CreateHunterPetPage`): the family's icon in the class badges' bronze ring (`Theme:ClassBadge`, 34, `TITLE_BADGE`, as the class Overview's; the icon cropped 8% and clipped round, on Pet trainer the `StableMaster` mark fitted at 80% of the opening) 16 in and 12 down, the name 10 after it (`TITLE_BADGE_GAP`) in `instance`; under the badge, 4 down, one line in `body`, `muted`: a family "Abilities: Bite, Dash, Furious Howl  ·  Diet: Meat  ·  59 beasts to tame", Pet trainer "9 abilities  ·  any pet learns them at a pet trainer" |
| Pet page strip | A family: chips at the left, 10 in, 6 apart (`Theme:Pill`, the picked one filled in `heading`): "Near my level  2" (the default: beasts within 4 levels of yours, `NEAR_LEVELS`; its count is the beasts it lists), "All  59", "Rare  8". Pet trainer: no chips. "Level 30  ·  Pet level 24" (the pet's part with your hunter's pet out) in `body`, `muted` at the right, 10 in |
| Pet page list | 10 under that line (`ROWS_GAP`), scrolling (`Theme:ScrollColumn`). Headings are 30 rows (`HEADING_ROW`) in `section`, `heading`, 16 in, a note in `small`, `muted` 8 after; every heading but the first has the section divider along its row's top (`Theme:Divider`, 16 in each side; `PetPageKit.AddHeading`): a family's "Tame one" ("each teaches the ranks under its name"), "Family abilities" ("learned by taming  ·  a pet has 4 active at most") and "Any pet" ("costs from the pet trainers"); Pet trainer's "Any pet" and "Your pet trainers" ("Alliance"). Other rows are 22 (`LINE_ROW`), 16 in; a beast's is 36 (`BEAST_ROW`). A beast: its name in `body`, 7 up from the row's middle (`BEAST_NAME_LIFT`), a "rare", "elite" or "rare elite" tag after it in `heading` at 80% size; 2 under the name (`TEACHES_GAP`) in `small`, `muted`, the ranks it teaches, "Teaches Bite 3, Cower 2" (the ranks Petopia lists it teaching, by ability, the name alone for rank 1; "Teaches nothing" for a beast Petopia lists teaching none); at the right, 16 in, "28 on map" in `body`, `link` in an 84 column (`MAP_COLUMN`), its zone in `body`, `muted` in a 130 column 8 left of it (`ZONE_COLUMN`, `COLUMN_GAP`), its levels ("Lv 35-36") in a 64 column 8 left of that (`LEVEL_COLUMN`); the zone and count are where you are when it spawns there, else where most of it spawns. The row is a map pin link (as quest pages' NPCs): a click pins that spot; its tooltip is the name, levels and tag, each zone with its count, the "Teaches" line, and "Click to pin on your map". An ability: its name in `body`, and in `small` at the right with no pet out "7 ranks  ·  Pet levels 1 to 60  ·  2g 6s 2c" (the cost only when Classic-DB's trainers price every rank) in `muted`, with your pet out "Rank 2 of 7  ·  Train now: rank 3  ·  4s 40c" in `complete` or "Rank 2 of 7  ·  Rank 3 at pet level 20  ·  4s 40c" in `muted`, "All ranks trained" once done. An ability no trainer sells (every family ability, Cower) names a beast family to tame instead, the game's name for it, with the lowest level of that family's beasts that teach the rank: the page's family when one of its beasts does, else the family of the lowest-level beast that does; "No known source yet" when no beast we list teaches the rank. With no pet out it's for the highest rank at your level (rank 1 below it), "4 ranks  ·  Tame a Wolf of level 25+ and use rank 2 until you learn it" in `muted`; with your pet out "Not trained  ·  Tame a Wolf of level 25+ and use rank 2 until you learn it" in `complete` when its level reaches that rank and a beast teaches it, in `muted` for the next one or one no beast teaches; its tooltip is the game's for that rank, Shift-click links it. A click opens the ability's ranks under it, as a spellbook tab page's spell (the same chevron 6 after the name, the same 20 rank rows, 32 in: `RANK_INDENT` 16 past the name): "Rank 3", "Pet level 20", the cost ("Pet trainer" for a trainer's rank Classic-DB doesn't price, Faster and Slower Attack's) or, for a rank no trainer sells, "Tame a Wolf of level 25+, use it until learned" or "No known source yet", and with your hunter's pet out its state for the pet. A pet trainer: as the Overview's trainers (the giver's mark, the name in `link`, its zone at the right), nearest first, your side's only; a character who isn't a hunter gets "Your pet trainers show on a hunter." in `small`, `muted`. Every chip lists its beasts nearest you first (`ns.UI.NearestFirst` on the spot each row shows: your continent by distance, then the rest). Near my level lists one beast per set of ranks taught, the nearest, plus every rare one, 5 at most (`NEAR_SHOWN`); when it leaves any out, a 22 note row under the last beast in `small`, `muted`: "Select All to see more". With no beast the chip keeps: "None near your level." or "None of these are rare." |
| Demon page | The warlock's page for Demon trainer or a demon (`ns.UI.CreateWarlockPetPage`), built from the pet page's parts (`ns.UI.PetPageKit`): the same heading, the demon's family icon in the class badges' bronze ring (Demon trainer: a grimoire's item icon) and its name; the line under it a demon's "Summon Voidwalker at level 10  ·  4 abilities  ·  21 grimoires", Demon trainer's "59 grimoires  ·  sold by the demon trainers" |
| Demon page strip | No chips. "Level 30  ·  Voidwalker summoned" (the demon's part with your warlock's demon out) in `body`, `muted` at the right, 10 in |
| Demon page list | As the pet page's list (10 under the line, 30 headings with the section divider over all but the first, 22 rows, 16 in, the right column in `small` 16 in). "Summon": a 36 row with the summon spell's icon (28, 16 in, bordered in `line` as the Abilities pages' spell icons, `Theme:QualityIcon`), 10 after it the spell's name in `body`, "Level 10" at the right in `muted` ("Known" in `complete` on your warlock who has it); its tooltip is the spell's, Shift-click links it. Under it "Quest" ("Quests" when there are more than one; no heading for a demon without one): its class quests (the side the Quests section's emblem picks; every quest of a group, the Bindings one per city) in `quest` with "Level 10  ·  Class quest" (your own: the quest's status in its colour); a click opens the quest's page in the Quests section. "Abilities" ("use a grimoire with the demon out to teach it a rank"): each ability's name in `body` with "6 ranks  ·  Levels 10 to 60  ·  6g" at the right in `muted`, with the demon out "Rank 2 of 6  ·  Train now: rank 3  ·  60s" in `complete`, "Rank 2 of 6  ·  Rank 3 at level 30" in `muted` or "All ranks learned"; its tooltip is the game's for the next rank to train (else the last), Shift-click links it. A click opens the ability's ranks under it, as a pet ability's (the same chevron, the same 20 rank rows, 32 in): "Rank 2", "Level 20", then the grimoire as an item link, its icon and its name in its quality's colour ("Loading..." until the game sends it), and its cost, "Grimoire of Torment (Rank 2)  ·  20s", or "comes with the demon" for a rank 1 no grimoire sells, and with the demon out its state ("Known", "Train now", "Later"). A rank's tooltip is its grimoire's (the spell's for one that comes with the demon); Shift-click links the grimoire in chat. "Your demon trainers" ("Alliance"): your side's who sell the demon's grimoires, nearest first, as the pet trainers, with "9 of 10 grimoires" in `muted` after a name that doesn't sell them all (Demon trainer: the demons whose grimoires they sell, "Imp, Voidwalker"); a character who isn't a warlock gets "Your demon trainers show on a warlock." |
| Comprehension section | The mage's alone, after Class Sets (no other class lists it), with the quest log's lore book (`Campaign-QuestLog-LoreBook`); its figure is how many scrolls there are, "22". One page, a 24 row: "Scrolls" with Scroll of Comprehension's icon (`C_Item.GetItemIconByID(215257)`) round, 17 before the name and 7 from it, as a pet family's |
| Scrolls page | The right pane's page (`ns.UI.CreateMageScrollPage`): Scroll of Comprehension's icon (cropped 8%) 30 square (`TITLE_ICON`) 16 in and 12 down, "Comprehension" 10 after it (`TITLE_ICON_GAP`) in `instance`; under the icon, 4 down, one line in `body`, `muted`: "22 scrolls  ·  only a mage can use them  ·  3 in your bags" (the last part while you carry any). Strip: "Level 30" in `body`, `muted` at the right, 10 in. The list scrolls 10 under that line (`ROWS_GAP`, `Theme:ScrollColumn`): a 30 heading per level the scrolls need (`HEADING_ROW`), "Any level" first, then "Level 5", "Level 16", "Level 25", "Level 46", in `section`, `heading`, 16 in, with "5 scrolls" in `small`, `muted` 8 after it; under each its scrolls, 28 rows (`SCROLL_ROW`): the item's icon, 20 (`ITEM_ICON`) with its quality edge (`Theme:QualityIcon`), 16 in; 8 after it (`ITEM_ICON_GAP`) the game's name for it in `body` in its quality colour ("Loading..." in `faint` until the game sends it, `Theme:SetRowItem`); "2 in bags" in `small`, `complete` at the right, 16 in, while you carry any. Hover shows the game's item tooltip; Shift-click links it in chat, Ctrl-click tries it on (`ns.Items:HandleModifiedClick`) |

## Level-up window (local checkouts only)

On reaching an even level (2, 4, 6, ...) a small window fades in with the ranks of your class's
spells a trainer teaches you now: the ones first taught at this level or the one before, and
under a shut "Earlier levels" row those from earlier levels still untrained. Odd levels, and a
level with nothing to train, show nothing. `/nr levelup [level]` shows it for any level (your
own when left out, an odd one taken down to the even one under it, at least 2), with "Nothing
new to train" when there is nothing. Releases leave `UI/LevelUp.lua` out (`.pkgmeta`, a debug
block in `UI.xml`). It takes the style picked for NeedRoll's window (`Theme.name`), also before
that window has ever opened (`UI:UseSavedSkin` puts the saved style in place). Each style gets
a window of its own, built the first time it shows in that style and kept (`DevKit.CardsBySkin`);
after a style change the next one opens in the new style and the old style's window hides. The
frame, its fading and its place are DevKit's card (`DevKit.StyledCard`, `DevKit.FadeInCard` in
`UI/DevKit.lua`'s debug block, `CARD` its sizes), shared with the run tracker's intro card; the
kill card takes the same fading and place without the frame (`DevKit.PlainCard`). An
"Abilities" chip at its top right opens your class's Trainable abilities in NeedRoll's window.

Each style's look (colors and fonts from the style's palette, `Theme.color` / `Theme.font`):

| Style | Frame | Title and the line under it | Close | Rows |
| --- | --- | --- | --- | --- |
| Native | The game's `ButtonFrameTemplate`, its portrait and inset hidden, as NeedRoll's native window: the game's dark background and metal frame | "Level 10" in the template's title bar (the game's `GameFontNormal`, gold); the line under it 16 in and 36 down (`CARD.NATIVE_SUBTITLE_TOP`, where the flat styles' falls) in `small` (10), `muted` `A0A0A0` | The template's own X at the title bar's right | `body` (12, its 2px shadow) in `text` `FFFFFF`; Earlier levels in `heading` `FFD100`; costs and Nothing new in `muted` `A0A0A0`; hover `hover` (white at 10%) |
| Modern | Rounded, filled with `popup` (`0A2136`) inside the 2px `accent` outline (`3B875B`), as `Theme:Dialog` | "Level 10" in `heading` (17, `FCD29F`), 16 in and 16 down (`PAD`, `DevKit.PAD`); under it, 3 down (`CARD.SUBTITLE_GAP`), the line in `small` (10), `muted` (`C1EEFF` at 50%) | `Theme:CloseButton`, 20 square, 8 in from the top right corner (`CARD.CLOSE_SIZE`, `CARD.CLOSE_INSET`), `muted`, `heading` on hover | `body` in `text` `C1EEFF`; Earlier levels in `heading`; costs and Nothing new in `muted`; hover `3E607F` at 45% |
| Dark | As Modern, `popup` `1E1E1E`, the same green `accent` | As Modern, `heading` `FCD29F`, `muted` `E6E6E6` at 50% | As Modern | `text` `E6E6E6`; hover `333333` at 45% |
| ElvUI | Square corners (`Theme.corners`): ElvUI's backdrop (`popup`, default 0.1 grey) inside a 4-line `accent` outline in ElvUI's value color (default `1784D1`) | As Modern in ElvUI's font: `heading` `FFFFFF`, `muted` `B0B0B0` | As Modern | `text` `FFFFFF`; hover the value color at 18% |

| What | Value | Where |
| --- | --- | --- |
| Window | 300 wide (`WIDTH`), on UIParent at `DIALOG` strata, its top 140 below the screen's top, centred (`CARD.SCREEN_TOP`): the upper middle, clear of the action bars. Not draggable. Drawn at the text size's scale (4/3 at Large, `Theme.textScale`). As tall as its list: 58 (`LIST_TOP`) + the list + 16 (`PAD`), in every style; it hangs from its top, so opening Earlier levels grows it downward and nothing above moves | `CreateWindow` in `UI/LevelUp.lua`; `StyledCard`, `CreateNativeCard`, `CreateFlatCard`, `FadeInCard` in `UI/DevKit.lua` |
| Title | "Level 10"; the line under it "Skills to train  ·  4g 10s", the cost being every listed rank's together (left out when nothing costs anything), left-aligned on a line as wide as the list (268, `CreateWindow`). See each style above | `LevelUp:Open` |
| Close | See each style above. A right-click anywhere on the window closes it too | `CreateWindow` |
| Abilities chip | "Abilities" as NeedRoll's chip (`Theme:Pill`, no symbol, in the window's style): 20 high, the word in `body` and `heading` (`FFD100` Native, `FCD29F` Modern and Dark, white in ElvUI) plus 24, inside the 1px `pillEdge` outline (`heading` at 55%; ElvUI's value color at 55%), rounded (square in ElvUI's), filled on hover as every pill. At the top right in every style: its right edge and middle on the right end of the line under the title, which is as wide as the list (`WIDTH` - 2 x `PAD`, 268), so 16 in from the window's right edge and level with "Skills to train". That puts it under the Native title bar and its X, and 3 under the flat styles' close cross (which ends 28 down; the chip spans about 31 to 51 down, the line's place following the title's text height); the list still starts 58 down (`LIST_TOP`), 7 under it. No tooltip, as the Loot and Abilities chips on a boss page. A click opens NeedRoll's window on the Classes tab, your own class, its Abilities section's Trainable page (the Overview's Train now target), and closes this window; it does so in combat too. A right-click closes this window. Hidden while the Classes tab is off in Settings | `CreateAbilitiesChip`, `OpenTrainable` |
| Rank row | 22 high (`ROW`), 16 in from each side: the spell's icon 16 square (`ICON`, cropped 8%), "Frostbolt 7" (`ClassSpells.RankName`) 6 after it (`ICON_GAP`) in `body`, `text`, cut short 8 before (`COST_GAP`) the cost at the row's right in `small`, `muted` (`ns.Money`, its g/s/c in the game's coin colors). New ranks lowest level first, the Abilities order between ranks of one level. Hover fills the row with `hover` and shows the spell's tooltip (`ANCHOR_RIGHT`) | `CreateRow`, `FillRankRow` |
| Earlier levels | A 22 row: "Earlier levels (3)" (the count is its ranks) in `body`, `heading`, the open arrow 6 after the words (10 long, as an Abilities spell's, `ClassSpells.PlaceOpenArrow`), pointing right while shut and down while open. Shut each time the window opens; a click opens or shuts it. Under it its ranks a spell at a time, as a staircase: a spell's lowest rank 12 further in than the new ranks (`EARLIER_INDENT`), each further rank of that spell on the next row 12 further in again (`RANK_STEP`); the spells in the order of their lowest rank's level (the Abilities order between equal levels); a spell with one rank is one row. Indent only, no connector lines. The name is cut short before the cost: 10 ranks deep the icon is 120 in and the name has about 70 left beside a "5g 40s" cost | `AddEarlierEntries`, `FillRow`, `LevelUp:ToggleEarlier` |
| Nothing new | "Nothing new to train" in `body`, `muted` on a 22 row in place of the new ranks, no hover | `FillRow` |
| List height | Up to 10 rows (`MAX_LIST_ROWS`, 220), then it scrolls with the mouse wheel, 22 a notch, gliding (`DevKit.ScrollArea`). At its tallest the window is 294 high, 392 at Large: it fits a 1280x800 screen | `Layout` |
| Fading | Fades in from clear over 0.4 s (`CARD.FADE_IN_SECONDS`); 5 s after it has fully faded in (`SHOW_SECONDS`) it fades out over 0.8 s (`CARD.FADE_OUT_SECONDS`) and hides. While the mouse is over it the 5 s hold, starting again when it leaves, and the mouse coming back while it fades brings it back | `Fade`, `CountDown` in `UI/DevKit.lua` |

## Professions Overview

The page a profession opens on, in the content pane over the loot grid
(`UI/ProfessionOverview.lua`; the Overview row in `UI/Lists.lua`; data from
`Data/ProfessionGuide.lua`). Laid out as the Classes tab's pet page
(`UI/HunterPets.lua`): its heading, rows and open arrows are the pet page's
(`ns.UI.PetPageKit`, `ClassSpells.CreateOpenArrow`), so they share its sizes.

| What | Value |
| --- | --- |
| Overview row | Every profession with a guide (Skinning too): a 40 row (`ROW.GROUP`) at the top of the filter sidebar, 6 under its top (`RB.SIDEBAR_TOP`), 5 in from its sides (`CARD_INSET`), 4 above the filters (`OVERVIEW_ROW_GAP`), scrolling with them; the dungeon Overview row's `GameMenu-up-c60` on its 30 disc and "Overview" in `section`, as a dungeon list's Overview header (`PaintHeader`). While the page shows, the disc is ringed in `discRing` and the row sits in a closed section card; otherwise a thin shut card, lit under the mouse. A profession opens on it; a recipe opened from elsewhere opens on the recipe. Skinning (no recipes) shows no filters and no Recipes header |
| Strip | The content pane's strip (30) shows on the page, its parts on a layer of it (`StripLayer` in `MainFrame.lua`). Mining, Herbalism and Skinning: chips at the left, 10 in (`STRIP_INSET`), 6 apart (`CHIP_GAP`; `Theme:Pill`, the picked one filled in `heading`): "Near my skill  5" (the default: the band holding the character's skill, the first without the profession) and "All ranges  25", each counting the zones it lists. Other professions: no chips. At the right, 10 in, the faction toggle (`Theme:FactionToggle`; it shows the other side's trainers, vendors, quests and zones), and 8 left of it (`TOGGLE_GAP`) "Mining 140 / 225  ·  Level 33" in `body`, `muted` (the level alone without the profession). While Back shows, the chips start 6 after it and Back's hint gives way |
| Heading | As the pet page's: the profession's icon (`ns.UI.ProfessionIcon`) in the class badges' bronze ring (`Theme:ClassBadge`, 34) 16 in and 12 down, its name 10 after it in `instance`; under the badge, 4 down, one line in `body`, `muted`, cut short at the right: the kind ("Gathering profession" for Mining, Herbalism and Skinning), the rank, then what gives skill-ups now. Mining and Herbalism: "Iron Ore, Silver Ore and Tin Ore give skill now", the nodes from orange to green, hardest first, 3 at most (`NODES_NAMED`), each ore once, each in the game's node colour for the character's skill from the node's own numbers (`ns.UI.GatherColor`). Skinning: "Beasts level 18–29 give skill now". Others with recipes: "14 recipes give skill now  ·  next orange: Mithril Tube (195)", the count a link (in `muted`) whose click ticks the recipe list's Skill-ups and opens the list. Without the profession: the kind and "Not learned" |
| List | 10 under that line, scrolling (`Theme:ScrollColumn`). Headings are 30 rows in `section`, `heading`, 16 in, the note in `small`, `muted` 8 after; every heading but the first has the section divider along its top (`PetPageKit.AddHeading`). Rows are 22 (`LINE_ROW`), 16 in, the right column 16 in from the right in `small`, `muted` (12 kept clear before it, `TEXT_ROOM`). A rank, zone or specialization opens and shuts on a click, the pet page's chevron 6 after its name (after a zone's tag) pointing down while open, and is lit in `hover` under the mouse; nothing above it moves. The rows it opens are 20 (`CHILD_ROW`), 16 further in (`CHILD_INDENT`). The row lit in `hover` (`light`) is the next rank to learn and the busiest zone of the character's band. A row never opened or shut starts so: the next rank and that zone open (worked out again each time the page opens), the rest shut; one the player opened or shut stays so, each profession its own (Remembered sections, `"professions"`, `page.openFolds`). A profession's Camping section comes first, then a gathering profession's Where to mine |
| Camping | First on every profession with camp features (`Data/Camping.lua`): "Camping", note "3 camp features", with the Quests heading's arrow and button that open and shut the section (`AddFoldHeading`, `page.openFolds`); it starts open, then stays as the player left it. A row per feature it builds, lowest skill first, laid out as a quest's (36, `TWO_LINE_ROW`; the name 7 up, `TEXT_LIFT`): the item's icon (sized to the text) and name, a link with its tooltip (Shift-click links it), then ": " and what it does in `text`, its number for the character's level ("Lodestone: +32 Attack Power"; the Enchanted Lute "+163 Armor, +13 stats, +22 resistances"); a feature placed over another adds that one's effect ("Rock Garden: grows a mining node, +32 Attack Power"). Under it in `small`, `muted`, 2 down: "Taught by trainers", or the blueprint (an item link) then the bosses that drop it, kept short to fit: "Blueprint: Anvil  ·  Gilnid, The Deadmines" (each boss a link in `link` that opens their loot, joined by "or"; from the loot tables), or "where it comes from isn't known yet" in `muted`. The Faction Banner shows the character's side's own item. At the right "Skill 20", a link that opens the recipe (Skinning has no recipes: `muted`, no link) |
| Where to mine | Mining "Where to mine", Herbalism "Where to gather", Skinning "Where to skin"; note "skill 125–175  ·  Horde zones hidden  ·  most nodes first" (All ranges: no range; on a PvE realm "PvE realm: every zone"). A row per zone, the 5 with the most spawn spots (`ZONES_SHOWN`): on a PvP realm or with War Mode on (`ns.IsPvPRealm`) the side shown's own and contested ones, the other side's hidden, and after the name a tag in `small`, 5 after it (`TAG_GAP`): "safe" in `complete` or "contested" in `levelHard`; on a PvE realm every zone, untagged. The name in `body` is a link that opens the game's map on the zone; at the right in `body` "306 nodes" (the same link) in an 80 column (`NODES_COLUMN`), the zone's side ("Alliance", "Contested") in `muted` in an 80 column 8 left of it (`SIDE_COLUMN`, `COLUMN_GAP`), its levels from the game (`C_Map.GetMapLevels`, "Lv 30-40") in a 64 column 8 left of that (`LEVELS_COLUMN`). With All ranges, each band's "Skill 125–175" in `small` (`heading` on the character's band, else `muted`) before its zones. Opened, a zone lists the nodes found there that give skill-ups somewhere in its band, lowest first: the item's icon and link in `body` ("rich vein" in `muted` after the rich one), and at the right four numbers in `body`, each right-aligned in a 36 column (`SKILL_COLUMN`), the last 16 in: the skill it needs in `levelHard`, where it turns yellow in `levelFair`, green in `levelEasy` and grey in `levelTrivial` (`nodeSkills` in `scraper/professions/farming.json`). Skinning: a row per skill the band's beasts found there need, "Level 24 beasts" ("Level 1–10 beasts" for levels that need the same), with the same four numbers (the skill, then 25, 50 and 100 past it) |
| Where to learn | Note "Alliance  ·  nearest first". A row per rank, its name in `body`, at the right its range then "Learned" once the character has it, else "at 200" (while the character's skill is under it), the level and the cost, "A book, not a trainer" or "a quest": "225–300  ·  at 200  ·  Level 35  ·  5g". Opened, a trainer's rank lists the nearest 3 trainers of the side shown (`TRAINERS_SHOWN`; nearest to where the player stands, `ns.UI.NearestFirst`; a trainer new in Forever is placed in the world from its map): the giver's mark and the name as a link in `link`, the zone at the right ("the only trainer  ·  Tanaris" for one alone), then "+4 more trainers" in `small`, `muted` (hovering lists them all), or "No Alliance trainer". A book: the book (its icon and link), "  ·  Learned" in `complete` once the rank is had, its price at the right, then its nearest vendors the same way ("+2 more vendors"). A quest: its name in `quest`, "  ·  Completed" in `complete` once done, then in `small`, `muted` its giver and what it asks and "Led there by" the side's quest leading to it |
| Specialization | Note "Engineering 200  ·  Level 30  ·  pick one". Each one's row: the quest mark (`Exclamation-up-c60`, sized as the giver's mark) and its name in `quest`, at the right "3 quests  ·  Level 30  ·  Engineering 200", "  ·  Chosen" in `complete` once known. Opened, its chain step by step: "1.  Gnome Engineering" (the quest in `quest`; the step's other quests in its tooltip), "  ·  Completed" once done, its giver as a link with their zone at the right; then "<name> trainers show here once <last quest> is done." in `small`, `muted`, which gives way to its trainers (as a rank's) once the chain is done or the specialization known |
| Quests | Starts shut, then stays as the player left it, each profession its own. Shut: the heading alone, with the raid Overview's Attunement arrow (`Theme:Arrow`) 16 before the title (`FOLD_ARROW_ROOM`), the title moved right by that much; arrow and title are one button that opens and shuts the section (the arrow pointing down when open). Nothing above it moves. Note "Alliance Cooking quests  ·  2 of 3 done". A row per quest of the side shown: its name in `quest`, "  ·  Completed" in `complete` once done, then its zone and "teaches" the recipe (a link opening the recipe) in `muted`; at the right the skill it needs ("Mining 230", else "Level 9"); under it its giver and what it asks in `small`, `muted`, 2 under the name, which then sits 7 up from the row's middle in a 36 row (`TWO_LINE_ROW`, `TEXT_LIFT`, as the pet page's beasts). A quest group (`questGroups` in `scraper/professions/gates.json`: the four Membership Card Renewals) is one row: the quest's name, "  ·  Gnomish Engineering" in `muted`, "  ·  Completed" once any is done, and under it "From" each giver of the side shown, nearest first, with their zone, joined by "or" |
| Camping page | The Camping list, last of the profession lists (its icon the Basic Campfire spell's, 818, `Spell_Fire_Fire`; no recipes, only its Overview row), opens on this page: heading "Camping" with that icon, the line under it "What each profession builds at a campsite, yours first". The strip has no chips and no faction toggle: "Level 33" alone at the right, 10 in (`page:ShowToggle`). A section per rank its features' skill falls in, "Apprentice" with note "1–75" through "Artisan" "225–300", each with the Quests heading's arrow and button that open and shut it on its own, each starting open, then staying as the player left it; in each, the features of the character's professions first (up to 5: 2 primary, 3 secondary), lit in `hover` (`light`), then the rest, each part by name. Each row as in Camping above, with "Mining (20)" at the right, a link that opens the recipe in that profession's list |
| Links | NPCs and a dungeon's entrance are links in `link` that pin them on the map through the secure /mappin link (`ns.UI.HoverMapLink`); in combat a click draws NeedRoll's own pin and says why in chat (`ns.UI.ShowOnMap`). An NPC standing inside a dungeon (Annora) opens the Dungeons tab on NeedRoll's map of it, on their level with their spot lit (see Dungeon map); tooltip "Inside Uldaman" and "Click to see where they stand on the map"; Back returns. A zone opens the game's map on that zone, with no pin (`UI:OpenZoneMap`, `C_Map.OpenWorldMap`), and the window closes so the map shows; tooltip its spawn spots, "Safe for the Alliance" or "Contested", and "Click to open the map". In combat a zone does nothing to the map and prints "NeedRoll: Forever Addon API blocks addons from opening the map in combat, please try again when you're out of combat." (`CHAT_PREFIX`). A click on a link does only what the link does; a click elsewhere on its row opens or shuts the row. Quests are links in `quest` with their level, what they ask and, when NeedRoll has a page for them, "Click to open this quest". Books, nodes, camp features and blueprints are item links (Shift-click links them in chat). A recipe link opens the recipe in its own profession's list, a boss link (a blueprint's drop) their loot, with "Click to open its loot"; Back returns. An item the game hasn't sent yet shows the guide's (or `Data/Camping.lua`'s) name for it and the page redraws once it arrives |

## Library tab

The tab right after Collections, "Library" (`Data/LibraryBooks.lua`; a
module of its own that needs no other, its row in Settings' Modules with
the quest log's lore book `Campaign-QuestLog-LoreBook`, `WHOLE_BODY_ICONS`
in `MainFrame.lua`). Like the Shopping List and the Wishlist it fills the
window's body: one content pane `gutter` (12) in from every side
(`CreateWholeBodyHost`), no lists beside it, holding the Library Books page
(`UI/LibraryBooks.lua`; where each book stands from `Core/LibraryBooks.lua`).
Laid out as the Professions Overview: the pet page's heading and rows
(`ns.UI.PetPageKit`), so they share its sizes. Opened by its tab (or a
book on the world map) it shows no Back, as the Wishlist doesn't; opened
from a book in NeedRoll's search results (`UI:ShowLibraryBook`) it shows
"Back to search results" (see Strip). A page opened from it has "Back to
Library". None of its links opens a page: they pin a spot, or are the
game's item links.

| What | Value |
| --- | --- |
| Strip | The content pane's strip (30), always shown. At the left, 10 in (`STRIP_INSET`), 6 apart (`CHIP_GAP`): the chips "All books  38" (the default) and "Still to find  26" (`Theme:Pill`, the picked one filled in `heading`). At the right, 10 in: the side's crest (`Theme:Insignia`, sized `Theme:InsigniaSize` of `body`), 4 left of it (`CREST_GAP`) "Level 30" in `body`, `muted`, 16 left of that (`BOX_GAP`) the "Group by zone" box (`Theme:CheckBox`; ticked is remembered for every character, `NeedRollDB.libraryByZone`), and 16 left of the box (`SEARCH_GAP`) the search box (`Theme:SearchBox`, the window's style, 160 wide, `SEARCH_WIDTH`; hint "Search books"; see Search box). Opened from a search result, Back (the content pane's Back pill, "Back to search results", its tooltip the trail) sits 10 in at the left and the chips start 6 after it; it has no "to go back!" hint. The search box hangs from the right, so it never moves when Back shows; at the narrowest window (960) both fit between the chips and Group by zone. Back, or a right-click anywhere on the pane or the page, returns to the search (`UI:UpdateLibraryBack` in `MainFrame.lua`) |
| Search box | Text in it (matched as NeedRoll's search matches: lowercase, apostrophes dropped, `ns.Search.Matches`) keeps only the books whose name (the game's, else the data's), place, or a zone any of its spots is in has it in it; Still to find still applies. Each level bracket or zone with such a book shows, open, the rest are left out; Group by zone leaves out the hand-in box while there is text. A fold opened or shut while searching stays so until the text changes, but isn't remembered: emptying the box (Escape, the clear cross) brings the list back with the folds as the player left them, and the zone view scrolls to the character's level again. With no match the list reads `No book matches "<text>".` (22, `NOTE_ROW`, `small`, `muted`), then the footer. It stays as typed while the tab is left; a book opened from a search result empties it |
| Heading | As the pet page's (`ns.UI.CreateBadgeHeading`): the book icon `INV_Misc_Book_09` in the bronze ring (34) 16 in and 12 down, "Library Books" 10 after it in `instance`; under the badge, 4 down, one line in `body`, `muted`: "Hand them in to Garion Wendell  ·  Stormwind City, Mage Tower  ·  38 books for the Alliance" (the Horde: Owen Thadd, Undercity, Magic Quarter, 39), the librarian a link in `link` that pins them |
| Reward bar | 10 under that line (`BAR_TOP`), 16 in from both sides (`PAGE_LEFT`). Labels in `small`: "12 handed in" in `complete`, then "+ 2 ready" in `accepted` while books are held; each reward's count ("10", "20", "25", "38") centred over its notch, the last flush right with it, in `complete` once reached, else `heading`. 4 under them (`BAR_LABEL_GAP`) the bar, 8 high (`BAR_HEIGHT`): the track black at 0.45, the books handed in filled in `complete`, the held ones after them in `accepted`, scaled to 38. A 2 wide notch (`NOTCH_WIDTH`) in `heading` at each reward's count, 3 past the bar's top and bottom (`NOTCH_REACH`) |
| Reward columns | 5 under the bar (`COLUMNS_TOP`), one per reward quest, as wide as each other across the bar's width (16 in from both sides) and 8 apart (`REWARD_GAP`). Each is a button (`Theme:Row`) 3 + two lines + 3 high (`REWARD_PAD`), lit under the mouse as a list row is (`hover`; native: the quest log's highlight) and, while its card is open, in the row's selected state (modern: `primary` fill and the `accent` bar at its left; native: the quest log's selected highlight). Its two lines in `small`, 6 in from its sides (`REWARD_INSET`), one line each, cut short with "...": the quest's name in `quest`, and 2 under it (`REWARD_LINE_GAP`) "12 / 38" in `muted`, adding "  ·  rewards need Lv 50" while the character is under the level the rewards need (the 25 and 38 ones: 40 and 50). Once done the name and "Completed" in `complete`. Tooltip at the cursor, except over the column whose card is open: the name in `quest`, "Hand in 38 books to the librarian", "Its rewards need level 50", "Choose one:" and each reward's icon and name, "Completed" in `complete`. A left click opens its card; on the open column it shuts it, on another it switches to that one. The card is never remembered: the page opens with none |
| Rewards card | Under its column, 2 down (`CARD_GAP`), its frame level 20 over the list's (`CARD_RAISE`), so it covers the rows and nothing on the page moves. Rounded (`Theme:RoundedOn`) in `popup`, not `cardFill`, as it lies over the rows (`cardFill` would show them through), with a 1px edge in `heading`, `complete` once the quest is done. Its lines `pad` (14) in from every side and 4 apart (`CARD_LINE_GAP`): the quest's name in `body`, `quest` (`complete` once done); "Hand in 38 books to the librarian" in `small`, `muted`; "Its rewards need level 50" in `small`, `muted` (a reward with a level); "Choose one:" in `small`, `heading`; each reward to choose: its icon, 20 (`ICON_SIZE`), cropped as a book's, and 8 after it (`CHOICE_GAP`) its name in `body`, an item link in its quality color (the game's tooltip; Shift-click links it in chat), "Loading..." in `faint` until the game sends the item; then "Completed" in `small`, `complete` once done. As wide as its widest line, no narrower than its column nor wider than the bar; flush with the column's left, or with its right where it would reach past the bar's right end (the last column's). It takes the mouse, so the rows under it don't. Shut by a click on its column, Escape, or the page hiding (another tab, the window closing) |
| List | 5 under the reward columns (`ROWS_TOP`), scrolling (`Theme:ScrollColumn`), hung from the page by numbers (its rows hold map links' secure buttons). By level (the default): a fold per level bracket the books' zones start in (1–9, 10–19, 20–29, 30–39, 40–49, 50–60; capitals count as 1), "Levels 30–39" in `section`, `heading`, the note "your level" in `small`, `muted` 8 after on the character's own, which is the one that starts open. Group by zone: when books are held a box first, then "8 zones, lowest level first" (22, `NOTE_ROW`, `small`, `muted`; left out while no zone shows), then a fold per zone, lowest level first, then the lower top level, then by name; the zone's name in `body`, `text`, note "Lv 30-40  ·  Eastern Kingdoms" (a capital: "City  ·  Kalimdor"). Zones the character's level is in that still have books start open, and the list opens scrolled to the first of them. A fold the player opened or shut stays so (Remembered sections, `"library"`); each time the page opens, or the box is ticked, the zone view scrolls to the first open zone at the character's level again. Still to find leaves out the books handed in and the folds whose books all are. A book opened from a search result opens its fold (kept open, as a click would; Still to find gives way to All books when the book is handed in) and the list scrolls so its fold's row is at the top, or, when the book's row wouldn't fit under it, the row just above the book's |
| Fold row | 28 (`FOLD_ROW`), the raid Overview's Attunement arrow (`Theme:Arrow`) 16 in, the name 16 after it (`FOLD_ARROW_ROOM`); every fold but the first has the section divider along its top. While books of it are held, "2 ready" on a pill drawn as the strip's chips (`Theme:Pill`: 20 high, `body` text in `heading`, a `pillEdge` rounded border, no fill), 8 after the note (`READY_GAP`). It takes no mouse, so a click on it opens or shuts the fold. At the right, 16 in: "8 / 10" in `small`, `muted`, 8 (`FIGURE_GAP`) before a 70 × 6 bar (`MINI_BAR_WIDTH`, `MINI_BAR_HEIGHT`), black at 0.5, filled in `complete`; once every book is in, "10 / 10" and a tick (`common-icon-checkmark`, 11) in `complete` with no bar. A click opens or shuts it; lit in `hover` under the mouse |
| Book row | 36 (`BOOK_ROW`). The tick (`common-icon-checkmark`, 12, `TICK_SIZE`) 16 in once handed in; the book's icon, 20 (`ICON_SIZE`), cropped, 4 after the tick's room (`ICON_LEFT`), greyed and at 0.55 (`NOT_FOUND_ALPHA`) while not found. 8 after it (`TEXT_LEFT`) the name, an item link in `body` (its tooltip; Shift-click links it in chat), 7 up from the middle (`NAME_LIFT`), in `complete` handed in, `accepted` held, else `text`. 2 under it (`SUB_GAP`) in `small`, `muted`: "Tower of Azora  ·  On a table halfway up the tower", or "Where it sits isn't written up yet"; a book with more spots adds them as pin links, one per zone: "also Zephras Isle (8 spots)", or a zone with one spot as "also Duskwood (16.6, 28.5)". At the right, 16 in, the status in `small` in an 80 column (`STATUS_COLUMN`): "Handed in" in `complete`, "In bags" and "In bank" in `accepted`, "Not found" in `faint`; 12 before it (`COLUMN_GAP`) the spot as a pin link in `small`: "Elwynn Forest (65.4, 70.1)" by level, "(65.4, 70.1)" in a zone's fold. The name's line keeps 12 clear of the spot (`TEXT_ROOM`). A held book's row is lit in `hover` (`light`) |
| Hand-in box | Group by zone, while books are held: a 36 row (`HAND_IN_ROW`) holding a rounded card (`Theme:RoundedOn`, `cardFill`, edged in `complete`) 16 in from both sides and 3 in from top and bottom (`HAND_IN_INSET`). "Hand in Defensive Magics 101 and Undead Potatoes to Garion Wendell" in `body`, the books as item links in `accepted`, the librarian a pin link, `pad` in from the card's left; at the right, `pad` in, "takes you to 14 / 20" (the next reward's count) in `small`, `muted` |
| Footer | The list's last row (22, `small`, `muted`): "2 Horde-only books hidden" (the Horde: "1 Alliance-only book hidden"). With every book handed in under Still to find, by level or by zone, "Every book is handed in." before it |
| Links | Spots and the librarian are links in `link` that pin through the secure /mappin link (`ns.UI.HoverMapLink`); in combat a click draws NeedRoll's own pin and says why in chat (`ns.UI.ShowOnMap`). A spot's tooltip: the book's name, its zone and spot (and the others it stands for), then the pin hint. An item the game hasn't sent yet shows the data's name and the page redraws once it arrives; the page redraws on a quest turned in, a bag or bank change and a level gained while it shows; resizing the window redraws only the reward bar, its columns and the open card |

## The game's quest tooltips and quest log

A quest that is one of a dungeon's (or raid's) quests, or a step of a quest
chain leading into one, for the player's side, on a tab that is on with
Quests on (`UI/QuestChainNotes.lua`, `ns.Data:DungeonsOfQuest`):

| What | Value |
| --- | --- |
| Quest tooltip lines | Under the game's quest tooltip (chat links and any tooltip showing the quest, through the tooltip data processor) and under a quest log row's tooltip on hover (after the game's own lines, the tooltip shown again to fit), with no blank line before: one line per dungeon, "Shadowfang Keep quest chain" in `Theme.tip.info`, the first three named and "+N more" in `Theme.tip.hint` after (`Tooltip.AddNamed`). Each starts with the dungeon or raid tab's icon in the 18 box and a space, as the item tooltips' source lines (`Tooltip.SourceIcon`: the entrance portal cut 15% in from each edge). The dungeon it is one of the quests of comes first. None in NeedRoll's own window or with Settings' Drop sources on tooltips off |
| Quest log note and pill | In the quest log's details (a quest opened in the world map's quest log), in the game's top bar with the Back button (`BackFrame`, 307 × 52): a box from 8 right of the Back button (`BACK_GAP`) to 13 in from the bar's right edge (`BOX_RIGHT_INSET`), and from 5 under the bar's top (`BOX_TOP`) to 6 under the Back button's bottom (`BOX_BELOW_BACK`). Along its top, right-aligned on one line (cut short with "..." when longer than the box): "Shadowfang Keep quest chain" in `GameFontNormalSmall`, coloured `Theme.tip.info`, with "  ·  +1 more" for each further dungeon counted. In its bottom right corner the pill "Open in NeedRoll" (`Theme:NativePill`: the Native style in every style, as the game's quest log around it; 20 high, Native `body` font, the gold `pillEdge` outline, its text + 24 wide, filled on hover). Both hide for any other quest, and while Settings' "Open in NeedRoll in the quest log" is off; nothing of the game's moves |
| Pill tooltip | `ANCHOR_RIGHT`: "Open in NeedRoll" in `Theme.tip.title`, then every dungeon's line (its tab's icon and "Shadowfang Keep quest chain", `Theme.tip.info`), then "Click to open this quest" in `Theme.tip.hint` |
| Pill click | NeedRoll's window opens on the Dungeons (or Raids) tab at the quest's page in the first dungeon named (`NeedRoll_ShowQuest`): the dungeon's own quest, or for a step out in the world its light step page with the chain's rows (else the dungeon quest the chain leads to), raised in front of the world map, which stays open. In combat the same: it opens only NeedRoll's own window and never shows, hides or turns the game's map |

## Keeping this up to date

- Change a size, font, color, icon or layout? Update the matching row here in
  the same commit or PR.
- New control or pane? Add a row or section here.
- Values come from the code. Read the constant, don't guess.
