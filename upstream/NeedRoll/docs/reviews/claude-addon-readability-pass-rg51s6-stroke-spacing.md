# Review: Dev edit: drawn routes keep a point every 24 UI units, half as often

| | |
| --- | --- |
| Branch | `stroke-spacing` into `origin/dev` (PR not opened yet) |
| Commit reviewed | `2ca233b` (no uncommitted changes) |
| Date | 2026-10-18 |
| Round | 1 |
| Verdict | **Changes needed** (0 blocking, 1 should fix, 1 nit) |
| Needs | `/reload`: a Lua constant changes, no new files or TOC lines |

## What the change does

Mike asked (2026-10-18) for the dev edit's mouse-drawn patrol, drop-area and
outline lines to drop their points half as often. The drawing code reads the
cursor every frame (`strokeDriver`'s `OnUpdate` → `FollowStroke`), but it only
drops a point once the cursor is `STROKE_SPACING` UI units from the last one
(`AddStrokePoint`). The change doubles that distance from 12 to 24, so a drag
of the same length keeps about half as many points. The per-frame cursor read
stays as it is; "polling" in the request is read as "dropping of pins", which
is what Mike put in brackets. `docs/STYLE-GUIDE.md`'s Drawing row now says 24.

## Scope

- `NeedRoll/UI/MapEdit.lua:129`: `local STROKE_SPACING = 12` → `24`. The comment above it (lines 127-128) is still right.
- `docs/STYLE-GUIDE.md:251`: the Drawing row says "a point each 24 UI units".
- Read around the change: `FewestPoints`, `AddStrokePoint`, `FollowStroke`, `StartStroke`, `EndAtCursor`, `EndStroke` (`MapEdit.lua:580-693`), and the smoke helpers `DragOnMap`, `CheckDrawn` and the drawing scenario (`tests/smoke/modules/UI-MapEdit.lua:207-242, 610-665`).
- No generated files touched. Older review docs that say "12 UI units" (`docs/reviews/claude-addon-readability-pass-rg51s6-devedit.md:28`) are records of their own round and are left as they are.

## Checks

| Check | Result |
| --- | --- |
| `luac5.1 -p NeedRoll/UI/MapEdit.lua` | passed |
| `luacheck --no-global -q` on `MapEdit.lua`, head and `origin/dev` | 1 warning each (`1502:17: unused argument self`), already there before; no new warnings |
| `tests/smoke/check.sh` | passed: dev, packaged and secret-values runs all "all passed" (exit 0); "UI/MapEdit: drawing a patrol, an area and an outline with the mouse" is ok |
| `python3 tools/locales.py --check` | passed (no text changed) |
| `python3 tools/translations.py` | not run: no player-facing text changed |
| Scraper unittests | not run: no scraper change |
| Point counts, before and after | measured in a scratch copy (below) |

### Point counts in the drag scenario

Measured by copying the tree to a scratch folder, setting `STROKE_SPACING` to
12 and to 24, and printing `#route / 2` in `CheckDrawn`. The smoke canvas is
430.5 × 287 UI units; `DragOnMap` moves the cursor 40 frames per leg.

| Route (drag) | Path length | Points at 12 | Points at 24 | Current bound |
| --- | --- | --- | --- | --- |
| Patrol line (0.2,0.3)→(0.6,0.3)→(0.6,0.5) | ~230 units | 19 | 10 | 4..40 (`frames / 2`) |
| Area (0.3,0.3)→(0.5,0.3)→(0.5,0.5)→(0.3,0.5) | ~230 units | 18 | 9 | 3..80 |
| Outline (0.1,0.1)→(0.3,0.1)→(0.2,0.3) | ~158 units | 12 | 7 | 3..60 |

Each route keeps about half the points it did (one start point and the end
point are fixed, so it is a little over half). The game's "Drawn with N
points." print shows the same numbers.

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | should fix | Readability (tests) | `tests/smoke/modules/UI-MapEdit.lua:625, 647, 654` | The smoke bounds don't pin the spacing: 12 and 24 both pass | fixed at integration (bounds 8-12, 7-11, 5-9; fail at 12 with "19 points") |
| R2 | nit | Readability | `NeedRoll/UI/MapEdit.lua:675` | The shortest drag that draws doubles too (6 → 12 units for a line, ~18 → ~36 for a loop) | left as is: the request's intent; noted for Mike |

### R1 · The smoke bounds don't pin the spacing

- **Severity:** should fix
- **Area:** Readability (tests; reviewer rule "a bug fix or feature has a scenario")
- **Where:** `tests/smoke/modules/UI-MapEdit.lua:625`, `:647`, `:654`
- **Status:** open

**What's wrong.** The scenario's bounds are loose enough that the old value
still passes:

```lua
CheckDrawn(patrol, 4, frames / 2)            -- 4..40
CheckDrawn(area, 3, 80)
CheckDrawn(outlines[#outlines], 3, 60)
```

At 12 the routes have 19, 18 and 12 points; at 24 they have 10, 9 and 7. All
six are inside the bounds.

**Why it matters.** Nothing in the tests holds Mike's request. If someone
changes the spacing back to 12, or to 6, the smoke tests still pass and the
editor drops points twice or four times as often again.

**Evidence.** Measured counts in the table above. In a scratch copy with the
tighter bounds below, the scenario passed at 24 in the dev and secret-values
runs (the packaged run doesn't load the dev editor) and failed at 12 with
`UI-MapEdit.lua:240: a drawn route has 19 points`.

**Fix.** Tighten the bounds around the counts at 24, leaving room for one or
two points either way:

```lua
CheckDrawn(patrol, 8, 12)              -- 10 at a point each 24 units
CheckDrawn(area, 7, 11)                -- 9
CheckDrawn(outlines[#outlines], 5, 9)  -- 7
```

and change the comment above `CheckDrawn` ("at least a few apart (not one a
frame)") to say the bounds follow the editor's 24-unit spacing, so the next
person to change `STROKE_SPACING` knows to change them. `frames` at line 622
is then unused, so `local frames =` can go too.

### R2 · The shortest drag that draws doubles too

- **Severity:** nit
- **Area:** Readability (behaviour note)
- **Where:** `NeedRoll/UI/MapEdit.lua:675` (`EndAtCursor`), `:683-687` (`EndStroke`)
- **Status:** left as is: it follows from Mike's request; listed so he knows

**What's wrong.** Nothing is broken. `EndAtCursor` adds the drag's last spot
as a point of its own when it is at least `STROKE_SPACING / 2` from the last
point, otherwise it moves the last point onto it (only when there are two or
more points, `#route < 4` guards that). The half spacing is now 12 instead of
6. So:

- a back-and-forth line (two points) now needs a drag of at least 12 UI units, not 6;
- a loop, area or outline (three points) needs about 24 + 12 = 36 units of drag, not 18;
- the last leg of a route can now be up to 36 units long (24 to the last kept point, plus up to 12 moved onto the cursor), where it was up to 18.

Shorter drags print "Too short to draw: hold the button down and drag
further." and put back what was there, as before.

**Why it matters.** For Mike drawing a small loop round a tight room: 36 UI
units is about a twelfth of the map's width at the smoke size, and less when
zoomed in (the spacing is in map units, so zooming draws finer). Inferred to
be fine.

**Evidence.** Read `EndAtCursor` and `EndStroke` (`MapEdit.lua:671-693`). The
scenario's click-length drag (`DragOnMap` with one point, line 629) still
prints "Too short to draw" and keeps the old patrol at both spacings (both
measured runs). The patrol still ends exactly at (0.6, 0.5) at 24 (assert at
line 627 passes).

**Fix.** None needed. If Mike wants short loops to stay easy, the end check
could keep its own constant (`END_SPACING = 6`) instead of `STROKE_SPACING / 2`,
but that is a second way of saying the same thing and the request doesn't ask
for it.

## Area notes

### Readability

The constant keeps its searchable name, and its comment ("keeps a point each
time the mouse has moved this far ... not one a frame") is still true at 24.
`EndAtCursor` uses `STROKE_SPACING / 2` rather than a second literal, so it
followed the change without an edit. The style guide row is updated with the
value read from the code. 4-space indents and LF endings are unchanged. Only
R1 (tests) is open.

### WoW API

The change adds and newly calls no game function, event, widget method,
template, atlas or `Enum`. The calls on the changed path (`CreateFrame`,
`SetScript("OnUpdate")`, `GetWidth`/`GetHeight`, `IsVisible`) were there
before and are unchanged. Nothing touches secure frames or runs differently in
combat. No new globals, no new upvalues.

| API | In `forever` lists | Where |
| --- | --- | --- |
| (none added) | n/a | n/a |

### Redundant code

No new code. `AddStrokePoint` is still the one place that drops a point, for
every drawing tool (`START_ROUTE` covers patrol, area and outline), so one
constant covers all three, as the request needs. No dead code is added. Once
R1 is fixed, `frames` at `UI-MapEdit.lua:622` would be unused.

### Security

None touched: no addon messages, chat, SavedVariables layout, sharing or
credits. The dev editor's export (`/nr devexport`) only writes fewer
coordinates.

## Round history

- 2026-10-18, `2ca233b`, round 1: Changes needed. Opened R1 (should fix) and R2 (nit, left as is).

## Integration

R1 applied as suggested: the bounds are 8-12, 7-11 and 5-9, the unused `frames` local is gone and the CheckDrawn comment says the bounds pin the spacing. With STROKE_SPACING put back to 12 the scenario fails with "a drawn route has 19 points"; at 24 `tests/smoke/check.sh` passes in all three modes.
