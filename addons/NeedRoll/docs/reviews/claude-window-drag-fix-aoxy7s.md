# Review: Main window: drag it from anywhere off a button or list, not only the header

| | |
| --- | --- |
| Branch | `claude/window-drag-fix-aoxy7s` into `dev` (PR number not yet assigned) |
| Commit reviewed | `1795390` (no uncommitted changes besides this doc) |
| Date | 2026-10-18 |
| Round | 2 |
| Verdict | **Ready** (0 blocking, 0 should fix, 1 nit) |
| Needs | `/reload`. Only Lua in `NeedRoll/UI/MainFrame.lua` and `NeedRoll/UI/Theme.lua` changed, with no new files, no TOC change and no SavedVariables change. |

## What the change does

A player reported that the main window wouldn't move, and that a Shift+drag
made it oddly see-through. Before this change, only the header strip
(22 high native, 44 modern) started a move. After it, a left-drag on any part
of the window's own background also moves it: the border, the tab strip, the
footer, and the gaps between panes. The drag code that was inline in
`CreateHeader` is now a local helper, `MoveWindowBy(handle, window)`
(`MainFrame.lua:296`), used for both the header and the window. In the
native style the header is also raised 10 frame levels above the window
(`HEADER_LEVEL`, `MainFrame.lua:627, 871`). The commit's comment says this
lifts it over the template's title bar art. The smoke scenario
"dragging saves the position" now also fires a drag on the window itself.

Round 2 (`1795390`):
- The helper is renamed `MakeDragHandle` (`MainFrame.lua:296`). It no longer
  enables the mouse; each call site does that itself (`:831`, `:869`).
- The header frame-level raise and `HEADER_LEVEL` are gone.
- The window comment now names the spots that drag.
- The scroll bar's track takes the mouse, with a hit rect 4 px wider on each
  side to match the thumb's grip (`Theme.lua:1646-1649`).

## Scope

- `NeedRoll/UI/MainFrame.lua`: adds `MoveWindowBy`, which takes over
  `window:EnableMouse(true)` in `CreateMainWindow`. Adds the `HEADER_LEVEL`
  constant and raises the native header. Rewrites the `CreateHeader` comment.
- `tests/smoke/modules/UI-MainFrame.lua`: the existing drag scenario gains a
  window-background drag that checks the position is saved.
- `NeedRoll/UI/Theme.lua` (round 2): `Theme:ScrollBar` adds
  `bar:EnableMouse(true)` and `bar:SetHitRectInsets(-4, -4, 0, 0)`. This
  affects every scroll bar: the instance and encounter lists, the loot grid,
  the Overview, Settings, DevKit and IconBrowser.
- No generated data, locale or TOC files changed.

## Checks

| Check | Result |
| --- | --- |
| `luac5.1 -p` on changed files (round 2: `MainFrame.lua`, `Theme.lua`, the smoke module) | passed |
| `python3 tools/locales.py --check` | passed (exit 0). No new strings. |
| `python3 tools/translations.py` | ran, exit 0. It lists 50 stale zhTW/other entries, all already on `dev`. None come from this change. |
| `luacheck --no-global -q` (change and base) | **not run**: `luacheck` isn't installed here (`command not found`) |
| `tests/smoke/check.sh` | round 2 at `1795390`: passed, "all passed" in all three runs. Round 1: passed: "all passed" in all three runs (dev, packaged, secret), including "UI/MainFrame: dragging saves the position; the grip and /nr reset put the size back" |
| Scraper unit tests | not applicable (no scraper change) |
| Style: indents, LF, line length | Round 2: no CR bytes in `Theme.lua`, and no added line over 120. Round 1: 4-space indents, no CR bytes (`grep -c $'\r'` = 0). No added line over 120 (the new `HEADER_LEVEL` line is 102). Lines 344 and 347 run over 120 but were already there. |

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | should fix | WoW API / Readability | `MainFrame.lua:627, 861-871` | Header frame-level raise rests on an unverified claim that title bar "art" takes the mouse | fixed in round 2 (`1795390`) |
| R2 | should fix | Readability | `MainFrame.lua:833-835` | Comment says a drag "anywhere off a button or list" moves the window; the content pane doesn't, the list panes do | fixed in round 2 (`1795390`) |
| R3 | should fix | WoW API (behaviour) | `Theme.lua:1638-1651` (because of `MainFrame.lua:835`) | A press on a scroll bar's track, just off the thumb, now drags the whole window | fixed in round 2 (`1795390`) |
| R4 | nit | Readability | `MainFrame.lua:295-297, 835` | `MoveWindowBy` reads as "move by an offset" and hides the window's click-catching `EnableMouse` | fixed in round 2 (`1795390`) |
| R5 | nit | WoW API (smoke coverage) | `tests/smoke/modules/` (fix at `Theme.lua:1646-1649`) | The scroll-track fix has no smoke assertion | fixed (scroll track assert in the drag scenario) |

### R1 · Header frame-level raise rests on an unverified claim that title bar "art" takes the mouse

- **Severity:** should fix
- **Area:** WoW API / Readability
- **Where:** `NeedRoll/UI/MainFrame.lua:627` (`HEADER_LEVEL`), `:861-864` (comment), `:871` (`SetFrameLevel`)
- **Status:** fixed in round 2 (`1795390`). The raise, the constant and the
  "art would take the mouse" sentence are removed, and the `CreateHeader`
  comment is back to dev's wording (`MainFrame.lua:861-862`). Nothing is left
  to verify in game.

**What's wrong.**

```lua
local HEADER_LEVEL = 10  -- the native header's frame levels over the window, above the template's art
...
-- corner. The header sits above the template's own title bar art, which
-- would otherwise take the mouse.
...
if native then header:SetFrameLevel(window:GetFrameLevel() + HEADER_LEVEL) end
```

Art (textures and font strings) never takes the mouse in WoW. Only a
frame that has `EnableMouse(true)`, or mouse scripts set in its XML, does.
Here is what sits over the native title bar:

- the template's `TitleContainer` (a plain Frame holding `TitleText`),
- NeedRoll's own title holder from `AddNativeTitle`
  (`MainFrame.lua:637-638`, `holder:SetFrameLevel(titleBar:GetFrameLevel() + 5)`),
  which never enables the mouse,
- the template's `NineSlice` border.

None of these is known to take the mouse. So the comment reads like a
diagnosed cause when, as far as the code shows, it's a guess. The number 10
also has no stated basis: it isn't "the holder's +5 plus one", for example.

**Why it matters.** There are two cases. If nothing over the title bar
takes the mouse, the raise does nothing, and the comment sends the next
reader looking for a mouse-taking art layer that doesn't exist. That breaks
the "no comments that mislead" rule. If something does take the mouse
(Forever's `TitleContainer` could differ from retail's), then this raise is
what makes the title bar draggable at all. In that case the new
window-background drag can't stand in for it, because a mouse-enabled
`TitleContainer` would catch the press before it reached the window. The
comment should then name that frame. In both cases a reader can't tell
which is true. The smoke stand-in doesn't settle it: `tests/smoke/wow.lua:901`
builds `TitleContainer` as a plain frame, and no scenario checks the header's
level.

**Evidence.**
- Read `AddNativeTitle` (`MainFrame.lua:631-650`) and `CreateHeader`
  (`:865-884`).
- `ButtonFrameTemplate` is in Ketho's `forever` `Templates.lua:456`
  (`inherits = "ButtonFrameBaseTemplate"`). Ketho's lists give inheritance
  only, not XML or mouse flags. I couldn't reach `Gethe/wow-ui-source` from
  this session to read the XML.
- That `TitleContainer` doesn't take the mouse in Forever is **inferred**
  from retail FrameXML, where it has no mouse scripts.

**Fix.** Check it in game, on the native style:

1. Run `/fstack`.
2. Hover the title bar between the NeedRoll name and the X.

If `/fstack` shows `NeedRollNativeFrame.TitleContainer` (or any frame other
than the header) as the mouse focus, keep the raise. Then reword the comment
to name that frame, and tie the number to it, for example "above
TitleContainer and the title holder (+5)". Add a smoke assertion that the
native header's level is above `window.TitleContainer`'s. If `/fstack` shows
the header already, delete `HEADER_LEVEL`, line 871, and the last sentence
of the comment.

### R2 · Comment says a drag "anywhere off a button or list" moves the window; the content pane doesn't, the list panes do

- **Severity:** should fix
- **Area:** Readability
- **Where:** `NeedRoll/UI/MainFrame.lua:833-835`; commit title says the same
- **Status:** fixed in round 2 (`1795390`). `MainFrame.lua:832-834` now says
  "A drag on any spot that takes no clicks of its own (the border, the gaps
  between panes, the list panes' empty space, the footer) moves the window
  too". That matches what takes the mouse. The commit title of `d40d048`
  still says "off a button or list"; a squash or the PR title can say it
  better, but that isn't code.

**What's wrong.**

```lua
-- The window's own background (its border, the gaps between panes, the
-- footer) moves it too, so a drag anywhere off a button or list works.
MoveWindowBy(window, window)
```

What actually happens:

- The content pane's host and its pages take the mouse:
  `host:EnableMouse(true)` (`:527`), `UI.loot:EnableMouse(true)` and
  `UI.overview:EnableMouse(true)` (`:1019-1020`). The Shopping and Wishlist
  hosts are built by the same `CreateHost`. A drag on the loot grid's empty
  background, the content strip, or the Shopping or Wishlist pane's empty
  space doesn't move the window.
- The instance and encounter list panes are `Theme:CreatePanel` frames with
  no `EnableMouse` (`Theme.lua:564-583`). Only their rows take the mouse
  (`Lists.lua:797, 1931`), and marker rows don't even do that. A drag on a
  list's label strip, on the empty space under its last row, or on a marker
  row *does* move the window.

So "off a list" is backwards, and "anywhere" overstates it.

**Why it matters.** The next person to change the content pane's mouse
handling, or to answer a player's "it won't move from here", will believe
this comment and get it wrong.

**Evidence.** I grepped `EnableMouse` in `Lists.lua`, `Theme.lua` and
`MainFrame.lua` and read `CreateHost` (`MainFrame.lua:520-552`).

**Fix.** Name the places that move the window:

```lua
-- Its own background moves it too: the border, the tab strip, the footer,
-- and the list panes' empty space. The content pane keeps its clicks for
-- right-click Back.
```

### R3 · A press on a scroll bar's track, just off the thumb, now drags the whole window

- **Severity:** should fix
- **Area:** WoW API (mouse behaviour the change introduces)
- **Where:** `NeedRoll/UI/Theme.lua:1638-1651` (`Theme:ScrollBar`), which the
  new `MoveWindowBy(window, window)` (`MainFrame.lua:835`) exposes
- **Status:** fixed in round 2 (`1795390`), with `bar:EnableMouse(true)` and
  `bar:SetHitRectInsets(-4, -4, 0, 0)` (`Theme.lua:1648-1649`). The ±4
  matches the thumb's grip (`SCROLL_WIDTH + 8`, centred).
  `SetHitRectInsets` is in the forever `WidgetAPI.lua` (`:634`) and in the
  stand-in (`wow.lua:199`). A press on the track now does nothing rather
  than paging; the "jump to the press" suggestion was optional.

**What's wrong.** The scroll bar's track frame doesn't take the mouse. Only
its thumb does:

```lua
local bar = CreateFrame("Frame", nil, pane)   -- no EnableMouse
...
local thumb = CreateFrame("Frame", nil, bar)
thumb:SetWidth(SCROLL_WIDTH + 8)
thumb:EnableMouse(true)
```

The list panes under the track don't take the mouse either (see R2). So a
press on the track, above or below the thumb, falls through to the window.
Before this change the press did nothing. Now, if the mouse moves, it
starts `window:StartMoving()`.

**Why it matters.** The visible thumb is 1.5 px wide inside a grab area
8 px wider, a small target. A player who reaches for it, lands a few pixels
above or below on the track, and pulls down to scroll sees the whole window
slide down the screen instead, and the new spot is saved. This happens in
the instance and encounter lists, the panes most often scrolled.

**Evidence.** Read `Theme:ScrollBar` (`Theme.lua:1638-1700`). The only
`EnableMouse` in it is the thumb's (`:1651`). The panes it sits on have none
(R2).

**Fix.** Let the track keep its own presses: add `bar:EnableMouse(true)` in
`Theme:ScrollBar`. Better still, jump the thumb to the press, the way the
game's scroll bars page, so a near miss still scrolls. Consider adding a
smoke assertion that the track takes the mouse.

### R4 · `MoveWindowBy` reads as "move by an offset" and hides the window's click-catching `EnableMouse`

- **Severity:** nit
- **Area:** Readability
- **Where:** `NeedRoll/UI/MainFrame.lua:295-297, 835`, `:872`
- **Status:** fixed in round 2 (`1795390`). The helper is renamed
  `MakeDragHandle`, and `EnableMouse(true)` is explicit at both call sites
  (`MainFrame.lua:831`, `:869`), as on dev.

**What's wrong.** `MoveWindowBy(handle, window)` reads like "move the window
by some amount", and the call `MoveWindowBy(window, window)` reads oddly.
The helper also does `handle:EnableMouse(true)`. For the window, that line
used to be its own statement in `CreateMainWindow`. It also stops clicks
in the window's gaps from passing through to the 3D world behind it.
That second job is now hidden inside a helper named for dragging.

**Why it matters.** If someone later drops the background drag (for
example, to fix R3 another way) by removing the `MoveWindowBy(window, window)`
line, clicks on the window's border and gaps start reaching the world
behind it. Nothing at the call site warns them.

**Fix.** Name it for what it makes, for example
`MakeDragHandle(handle, window)` or `DragToMove(handle, window)`. Keep an
explicit `window:EnableMouse(true)` in `CreateMainWindow`, with its own short
reason ("clicks in the gaps don't reach the world"). The helper can still
call `EnableMouse` for the header.

### R5 · The scroll-track fix has no smoke assertion

- **Severity:** nit
- **Area:** WoW API (smoke coverage)
- **Where:** fix at `NeedRoll/UI/Theme.lua:1646-1649`; no scenario in
  `tests/smoke/modules/`
- **Status:** open

**What's wrong.** Round 2 makes the scroll bar's track take the mouse, so a
press beside the thumb no longer falls through to the window's drag. No
smoke scenario checks this. I grepped `tests/smoke/modules/*.lua` for
`track` and `ScrollBar` and found nothing on the bar's mouse.

**Why it matters.** The track is a full-height frame with no scripts. A
later tidy-up could drop `bar:EnableMouse(true)` as looking unused. The
bug from R3 would then come back silently, because only the window drag
notices.

**Evidence.**
- The stand-in records the flag, so a check is cheap:
  `function Widget:EnableMouse(on) self._mouse = on and true or false end`
  (`tests/smoke/wow.lua:586`).
- Smoke runs at `1795390` pass with no scenario touching it.

**Fix.** In the existing drag scenario (or a Lists one), after the window
is shown, assert that the instance list's track takes the mouse:

```lua
assert(ui.instances.scrollBar._mouse, "a press on the scroll track would drag the window")
```

## Questions from the caller

**(1) What in the codebase could make the window semi-transparent or
unmovable on Shift+drag, or block the header drag?**

- **Transparency: nothing in NeedRoll.** I grepped `NeedRoll/` (outside
  `Data/` and the locales) for `SetAlpha`, `GetAlpha`, `UIFrameFade`,
  `IsShiftKeyDown`, `IsModifierKeyDown`, `MODIFIER_STATE_CHANGED` and
  `PLAYER_STARTED_MOVING`.
  - Every `SetAlpha` targets a row, icon, pin or button, never the window or
    a whole pane.
  - The one multiplying alpha, `row:SetAlpha(row:GetAlpha() * 0.4)` at
    `Lists.lua:2007`, runs right after `Lists.lua:402` resets the row's
    alpha in the same draw, so it can't build up.
  - The only Shift checks are in click handlers (`Lists.lua:2034, 2047`,
    `Overview.lua:1865-1872, 2026`, `MapEdit.lua:466-470`). None runs during
    a window drag.
  - Shift while hovering an item shows comparison tooltips (the footer
    hint), which is not transparency.

  My guess, which I couldn't confirm here: the see-through look comes from
  another addon that moves frames (frame-mover addons commonly fade a frame
  while it's dragged, some on Shift or Alt+drag), or from a client feature.
  Both frames are named globals (`NeedRollNativeFrame`, `NeedRollFrame`),
  which is what such addons hook. To confirm, ask the reporter for:
  - their addon list,
  - a repeat with only NeedRoll enabled,
  - `/fstack` over the spot they drag.
- **Unmovable / blocked header:**
  - In the native style, the only candidate is a mouse-enabled
    `TitleContainer` over the title bar (R1). It's unverified and, judging
    from retail FrameXML, unlikely.
  - The secure map-link buttons (`GameMapLink`, `MainFrame.lua:2329-2385`)
    sit only over the world-map pill and Back, not the header.
  - The close button lies outside the header (`TOPRIGHT -26`).
  - Native tabs stand below the tab strip's top edge (`LayoutTabs`,
    `MainFrame.lua:1067-1070`), so they don't overlap the header.
  - A drag can also look "unmovable" if the saved spot fails
    `IsUsableWindowPoint` (`MainFrame.lua:271-281`), because then
    `OnDragStop` puts the window back in the centre. That needs a secret or
    non-number from `GetPoint`, which is unlikely after `StopMovingOrSizing`.
  - The likeliest explanation for "won't move", inferred: before this change
    only the header moved the window, and the reporter grabbed elsewhere,
    such as the tab strip or a gap. This change fixes that case.
- **Frames that already moved fine:** both styles' headers already had the
  same drag scripts on `dev`. That's another reason the Shift+drag report
  looks like it comes from outside NeedRoll.

**(2) Is the frame-level change justified?** Not as written. See R1. It
fixes nothing the code can show, and its comment names a cause (title art
taking the mouse) that art can't have. Keep it only if `/fstack` in game
shows a template frame over the title bar. Otherwise remove it.

## Area notes

### Readability

Round 2:
- I re-read `MakeDragHandle`, `CreateMainWindow`, `CreateHeader` and
  `Theme:ScrollBar` in full.
- The names, comments and both `EnableMouse` call sites read clearly.
- The new `Theme.lua` comment says why (a press beside the thumb would
  otherwise drag the window) and names the file it guards against.
- No new findings.

Round 1:

I re-read `MoveWindowBy`, `CreateMainWindow`, `CreateHeader` and the smoke
scenario in full against `docs/READABLE-CODE.md`.

- Sound:
  - Pulling the duplicated drag scripts into one helper removes the only
    copy, so the job is done one way.
  - `HEADER_LEVEL` is a named constant with its unit in the comment.
  - Guard style matches the file (`if native then ... end`).
  - 4-space indents, LF endings, every name `local`.
  - The `OnDragStop` comment carried over unchanged and is still true.
- Findings: R1 (comment), R2 (comment), R4 (name).
- Lua 5.1 traps: no `and nil or`, no `#` on holed tables, no patterns
  built from data.

### WoW API

Round 2 adds one widget method:

| Call | In Ketho `forever` lists | Where looked |
| --- | --- | --- |
| `Frame:SetHitRectInsets` | yes | `WidgetAPI.lua:634`; stand-in at `wow.lua:199` |

Effects of the track taking the mouse:
- **Right-click Back:** `BACK_CLICKS` (`MainFrame.lua:1635-1650`) uses
  `IsWithin`, which walks parents (`:1619-1627`). The loot grid's and
  Overview's tracks are children of those panes, so Back still fires there.
- **Mouse wheel:** the track doesn't enable it, so scrolling over the track
  is unchanged (inferred from how the client routes wheel events).
- **Row clicks (inferred, acceptable):** while a scroll bar shows, its
  widened track covers about the right 9.5 px of each list row, full height.
  List rows reach to the pane's right edge minus 1 (`Lists.lua:161`). Row
  text and widgets stop at least `Size.pad` (14) in, so only the rows' blank
  right edge stops selecting the row. The thumb's grip already did this
  along its length.

Round 1:

| Call / template | In Ketho `forever` lists | Where looked |
| --- | --- | --- |
| `Frame:EnableMouse` | yes | `WidgetAPI.lua` |
| `Frame:RegisterForDrag` | yes | `WidgetAPI.lua` |
| `Frame:StartMoving` | yes | `WidgetAPI.lua` |
| `Frame:StopMovingOrSizing` | yes | `WidgetAPI.lua` |
| `Frame:SetFrameLevel` / `GetFrameLevel` | yes | `WidgetAPI.lua` |
| `ButtonFrameTemplate` (unchanged use) | yes | `Templates.lua:456` |
| `ButtonFrameTemplate_HidePortrait` (unchanged use) | yes | `FrameXML.lua:327` |

- No new game calls. All of the above were already mirrored in
  `tests/smoke/wow.lua` (`:200`, `:582-583`, `:662`).
- No events added. No async item or spell data. No secret values touched.
- No new globals. The upvalue count in `CreateMainWindow` and `CreateHeader`
  is tiny.
- Taint: `StartMoving` on an addon-owned, non-secure frame is allowed in
  combat. The window holds no secure children, since `GameMapLink`'s secure
  buttons are parented to `UIParent` on purpose.
- Player-facing text: none added.
- Smoke: the scenario covers the new window drag (R1 asks for one on the
  header level, if it stays).
- `docs/STYLE-GUIDE.md`: no size, font, colour, icon or layout changed. Only
  mouse behaviour and an invisible frame level did, so no update is due. Its
  "Header bar" row (`:18`) is still correct.
- Side note, not a finding: StartMoving marks the named window "user
  placed", so the client also caches its spot in `layout-local.txt`.
  `UI:PlaceWindow` sets the spot from `ns.db` on build, so the cache is
  harmless. `SetUserPlaced(false)` after the drop (`MapEdit.lua:334` does
  this) would keep the client from also saving it. `SetUserPlaced` is in
  the forever `WidgetAPI.lua`.

### Redundant code

I compared against the other drag code in the addon: `DevKit.lua:55-57,
84-87`, `Welcome.lua:153-155` (`SetScript("OnDragStart", f.StartMoving)`),
`MapEdit:Draggable` (`MapEdit.lua:320-340`) and `MinimapButton.lua:129-146`.
None saves a window position, so `MoveWindowBy` duplicates nothing. `Theme`
has no drag helper (I grepped `^function Theme:` and `StartMoving` in
`Theme.lua`). No dead code, unused locals or debug prints were added. No
`OnUpdate` was added.

### Security

None. The change touches no addon messages, chat, SavedVariables written by
others, sending, credits or scraper code. The only saved value is the
player's own `ns.db.window.point`, still checked by `IsUsableWindowPoint`
before use.

## Round history

- 2026-10-18 · `d40d048` · Changes needed · opened R1, R2, R3, R4
- 2026-10-18 · `1795390` · Ready (1 nit) · closed R1, R2, R3, R4; opened R5
