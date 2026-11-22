# Review: Write Mike's readable-code rules down; let each module have its own smoke tests

| | |
| --- | --- |
| Branch | `claude/addon-readability-pass-rg51s6` into `dev` (first PR of several on this branch; PR number not known yet) |
| Commit reviewed | `456b2fe` (round 1: `c0e5c79`; no uncommitted changes besides this doc) |
| Date | 2026-10-17 |
| Round | 2 |
| Verdict | **Changes needed** (0 blocking, 0 should fix, 5 nits; all nine round 1 findings fixed) |
| Needs | Neither `/reload` nor a restart: no file under `NeedRoll/` changed. Claude Code picks up the changed agent files in a new session (or after `/agents`). |

## What the change does

**Round 2 (`456b2fe`).** Fixes the nine round 1 findings: the short-name
list in `docs/READABLE-CODE.md` section 8 is complete, the reviewer's
luacheck baseline uses `git show` only, the loader in `run.lua` reports a
broken module file as `FAIL load` and passes `W, ns` to it, and the doc and
README wording is corrected. The round 1 text below describes the change
as it was first reviewed.

**Round 1 (`c0e5c79`).** Nothing changes for a player. For Mike and the agents, the change writes
down the readability rules Mike asked for (meaningful and searchable names,
consistent formatting, one job per function, guard clauses, plain-words
comments, consistency, no mental mapping, no disinformation, less code
without losing behaviour) in a new `docs/READABLE-CODE.md`, and points
`CLAUDE.md`, the implementer agent and the reviewer agent at it. The
reviewer gets stricter: it checks every rule in the new doc, runs
`luacheck` before and after, and must be stricter each round. The smoke test
runner `tests/smoke/run.lua` now also loads every `tests/smoke/modules/*.lua`
file after `scenarios.lua`, so each addon module can get its own scenario
file later; `tests/smoke/README.md` describes the folder. No module file is
added yet.

## Scope

- `docs/READABLE-CODE.md` (new, 131 lines): the nine pillars with Lua
  examples, plus the "behaviour stays the same" list.
- `CLAUDE.md`: one new bullet, "Readable code", pointing at the doc.
- `.claude/agents/implementer.md`: the style bullet now points at the doc
  and adds a 120-character line limit; a new bullet says a cleanup keeps
  behaviour identical; `luacheck --no-global -q` added to the checks; module
  scenario files named as a place for new scenarios.
- `.claude/agents/reviewer.md`: the Readability section checks every rule
  in the doc (names, disinformation, constants, nesting, narrating comments,
  consistency); `luacheck` before and after added to the checks; a new
  paragraph makes each round stricter than the last.
- `tests/smoke/README.md`: a paragraph on `tests/smoke/modules/`.
- `tests/smoke/run.lua:146-155`: the loader for module scenario files.
- Round 2 (`456b2fe`): `docs/READABLE-CODE.md` (sections 1, 2, 4, 5, 8),
  `.claude/agents/implementer.md:65-66`, `.claude/agents/reviewer.md:43,
  163-165`, `tests/smoke/README.md:17-26`, `tests/smoke/run.lua:146-172`
  (`AddScenarios`, the `pcall` loader). Every changed line and the whole of
  `run.lua` and `READABLE-CODE.md` re-read.

No generated files changed.

## Checks

| Check | Result |
| --- | --- |
| `luac5.1 -p tests/smoke/run.lua` | passed |
| `luac5.1 -p` on addon files | not run: no file under `NeedRoll/` changed |
| `python3 tools/locales.py --check` | passed (exit 0) |
| `python3 tools/translations.py` | passed (exit 0; prints the usual "not used by NeedRoll any more" notes for zhTW, unrelated) |
| `luacheck --no-global -q` on `tests/smoke/run.lua`, before (`git show origin/dev:`) and after | 1 warning both times (`run.lua:122:9: shadowing upvalue i on line 16`, existing code); the change adds none |
| `tests/smoke/check.sh` | passed in all three modes (dev 183 files, packaged 178 files, secret values), "all passed" each |
| Loader with zero module files | passed: on a clean `git archive HEAD` copy the folder doesn't exist at all (see R9); `ls` fails quietly and the run ends "all passed" |
| Loader with module files (in a scratch copy, not committed) | a module file with one passing and one failing scenario: both run, the failing one prints `FAIL module fails` with its traceback, exit 1. A module file with a syntax error, or one that returns nothing: the run aborts with a raw Lua error before any scenario, exit 1 (see R3) |
| Scraper unit tests | not run: no scraper change |
| Round 2: `luac5.1 -p tests/smoke/run.lua` | passed |
| Round 2: `luacheck --no-global -q --no-color tests/smoke/run.lua` | 1 warning, the same existing `run.lua:122:9` shadowing; the change adds none |
| Round 2: `tests/smoke/check.sh` | passed in all three modes (183 / 178 / 183 files, "all passed" each) |
| Round 2: `locales.py --check`, `translations.py` | both passed (exit 0) |
| Round 2: loader, zero module files (`git archive 456b2fe` copy, no `modules/` folder) | passed, exit 0 |
| Round 2: loader with module files (scratch copy, not committed) | a file that reads `local W, ns = ...` and asserts both: loaded, its scenario `ok`. A syntax error, a file with no `return`, a file that calls `error("boom")`: each printed `FAIL load <path>: <reason>` and the other scenarios still ran; exit 1 with "4 failed". A file returning `"oops"` printed `FAIL load .../E-String.lua: oops` (see R12) |

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | should fix | Readability | `docs/READABLE-CODE.md:107-111`, `.claude/agents/reviewer.md:38-40` | The short-name allow-list misses `ns`, `_`, `i` and the geometry/color names, and claims every file explains the aliases | fixed in round 2 (`456b2fe`) |
| R2 | should fix | Readability | `.claude/agents/reviewer.md:162-165` | `git stash` for the "before" luacheck run does nothing on a committed change and edits the tree | fixed in round 2 (`456b2fe`) |
| R3 | nit | Readability | `tests/smoke/run.lua:150-154` | A broken module file aborts the whole run with a raw error, and the file gets no `W, ns` | fixed in round 2 (`456b2fe`) |
| R4 | nit | Readability | `docs/READABLE-CODE.md:86` | "SavedVariables saving only on `/reload`" leaves out logout and exit | fixed in round 2 (`456b2fe`) |
| R5 | nit | Readability | `docs/READABLE-CODE.md:39`, `.claude/agents/implementer.md:65-66` | The 120-character limit doesn't say whether it covers existing lines; 119 addon lines and the locale files already go past it | fixed in round 2 (`456b2fe`) |
| R6 | nit | Readability | `docs/READABLE-CODE.md:75`, `.claude/agents/reviewer.md:43-44` | Doc says three levels of nesting is the sign, reviewer says past three | fixed in round 2 (`456b2fe`) |
| R7 | nit | Readability | `tests/smoke/run.lua:149,153` | The new loader breaks the new rules it ships with (two statements per line, `s`) | fixed in round 2 (`456b2fe`) |
| R8 | nit | Readability | `docs/READABLE-CODE.md:17-24` | The "readable" naming example also changes what the code does | fixed in round 2 (`456b2fe`) |
| R9 | nit | Readability | `tests/smoke/README.md:17-23`, `tests/smoke/modules/` | The folder isn't in the commit, `ls` doesn't exist on Windows, and "every tab has been opened" isn't true under `--only` | fixed in round 2 (`456b2fe`) |
| R10 | nit | Readability | `tests/smoke/README.md:24-25` | "Git Bash" is named as a way to run the tests, but a Windows Lua's `io.popen` uses `cmd.exe` | fixed after round 2, not re-reviewed (nits only) |
| R11 | nit | Readability | `docs/READABLE-CODE.md:39-40` | "shorten them when you touch them" reads as including the locale files, which must not be hand-edited or wrapped | fixed after round 2, not re-reviewed (nits only) |
| R12 | nit | Readability | `tests/smoke/run.lua:164-169` | A module file that returns a non-table value prints that value as if it were an error | fixed after round 2, not re-reviewed (nits only) |
| R13 | nit | Readability | `.claude/agents/implementer.md:84-85` | The implementer's "adds no warnings" luacheck step has no baseline, and most addon files already have warnings | fixed after round 2, not re-reviewed (nits only) |
| R14 | nit | Readability | `docs/READABLE-CODE.md:119`, `tests/smoke/README.md:25` | "colour" where the repo writes "color", and a README line wrapped past the file's width | fixed after round 2, not re-reviewed (nits only) |

### R1 · The short-name allow-list misses `ns`, `_`, `i` and the geometry/color names, and claims every file explains the aliases

- **Severity:** should fix
- **Area:** Readability
- **Where:** `docs/READABLE-CODE.md:107-111`; `.claude/agents/reviewer.md:38-40`
- **Status:** fixed in round 2 (`456b2fe`): section 8 is now a list naming `_, ns`, `L`, the Theme.lua aliases ("explained once there"), `W`, and `i`, `x/y/w/h`, `r/g/b/a`

**What's wrong.** Section 8 says:

> The only short names the addon keeps on purpose are the UI aliases listed
> at the top of `NeedRoll/UI/Theme.lua` (`T`, `S`, `C`, `F`, `UI`, `inst`,
> `enc`) and `L` for the translations table; they're used in thousands of
> places and every file explains them the same way.

and the reviewer now says "A one-letter or cryptic name outside the aliases
`docs/READABLE-CODE.md` allows is a finding."

Two problems:

1. The list leaves out names the repo's own rules require or that are
   standard in WoW code. `ns` and `_` come from `local _, ns = ...`, which
   the same reviewer file requires at the top of every addon file
   (`reviewer.md`, "Repo style"). The smoke tests use `W` for the stand-in
   client everywhere (`scenarios.lua`, `fn = function(W, ns)`, also written
   into the new README paragraph). Numeric `for i = 1, n` loops, `x`/`y`/`w`/`h`
   for frame geometry and `r`/`g`/`b`/`a` for colors (Theme.lua's own `Hex`
   at lines 18-23) are the usual WoW API spellings (`SetPoint(..., x, y)`,
   `SetVertexColor(r, g, b, a)`).
2. "every file explains them the same way" is not true. The legend is only
   in `NeedRoll/UI/Theme.lua:4-13`; the other UI files just write
   `local T = ns.Theme` / `local S = T.size` with no comment
   (`Lists.lua:4-5`, `LootGrid.lua:18-19`, `MainFrame.lua:4-5`, and others).
   A doc whose section 9 is "avoid disinformation" shouldn't carry a false
   statement.

The legend itself is accurate: Theme.lua lists `T`, `S`, `C, F`, `UI`,
`inst` and `enc` with the meanings the doc implies.

**Why it matters.** The reviewer reads this list literally (it is told to be
demanding and stricter every round). On the next PR of this branch it
either flags `local _, ns = ...`, `W`, `for i = 1, #rows` and `r, g, b` as
findings, which the implementer can't fix without breaking the repo's own
header rule and the WoW API's argument names, or it ignores the rule, and
then the rule means nothing. Either way the three-round loop burns rounds on
noise.

**Evidence.** Lines read as quoted. Grep of the addon (Locales and Data
excluded): `local f =` 29 times, `local n =` 24, `local w =` 14, `local y =` 13,
`local x =` 12, `local b =` 12, `local h =` 8, `for k, v in` 9. Some of these
(`f`, `n`, `b`, `t`, `s`) are fair game for the readability PRs; `x`, `y`,
`w`, `h`, `r`, `g`, `b`, `a`, `i` next to the matching API call are not.
`grep -rln "Theme.lua" NeedRoll/UI NeedRoll/Core` finds only `UI/UI.xml`.

**Fix.** Make section 8 a complete, honest list, for example:

```markdown
The short names the addon keeps on purpose:

- `_, ns` from `local _, ns = ...` (the addon's name, unused, and its
  shared namespace) at the top of every file;
- `L`, the translations table;
- the UI aliases explained at the top of `NeedRoll/UI/Theme.lua`: `T`, `S`,
  `C`, `F`, `UI`, `inst`, `enc`;
- `W`, the stand-in client in `tests/smoke/`;
- `i` for a numeric loop index, and the WoW API's own argument names next to
  the call that takes them: `x, y, w, h` for positions and sizes,
  `r, g, b, a` for colors.

Anything else gets a full name.
```

and drop "every file explains them the same way" (or say "Theme.lua
explains them; files that use them don't repeat it"). The reviewer line can
stay as it is once the list is complete.

### R2 · `git stash` for the "before" luacheck run does nothing on a committed change and edits the tree

- **Severity:** should fix
- **Area:** Readability
- **Where:** `.claude/agents/reviewer.md:162-165`
- **Status:** fixed in round 2 (`456b2fe`) for `reviewer.md`: `git stash` is gone and only `git show origin/dev:<file>` is left. The matching `implementer.md` line still has no base to compare with; that part is now R13

**What's wrong.**

```markdown
- `luacheck --no-global -q` on changed Lua files, before and after the
  change (`git stash` or `git show origin/dev:<file>`): new warnings are
  findings
```

`git stash` only takes uncommitted changes. The reviewer normally reviews
`origin/dev...HEAD` with the change already committed (this review: clean
tree on `c0e5c79`), so stashing leaves the changed files in place and the
"before" run is the "after" run. When there are uncommitted changes,
stashing them rewrites the working tree, which the same file forbids
("You never change code", line 9) and which can lose the implementer's work
if the reviewer is stopped before `git stash pop`.

**Why it matters.** A reviewer following the first option reports "no new
warnings" without having compared anything, so a change that adds unused
locals or shadowed names passes the new check.

**Evidence.** `git status` on this branch: "nothing to commit, working tree
clean". This review used the second option: `git show
origin/dev:tests/smoke/run.lua > <tmp>` and luacheck on both copies (1
warning each).

**Fix.** Keep only the read-only way and spell it out:

```markdown
- `luacheck --no-global -q --no-color` on each changed Lua file, and on the
  `origin/dev` copy (`git show origin/dev:<file> > <tmp>/<file>`): warnings
  the change adds are findings. Don't `git stash`.
```

(`--no-color` keeps the ANSI codes out of the output pasted into the
Review Doc.) The implementer's matching line (`implementer.md`, "the change
adds no warnings") needs the same "compare with `origin/dev`" hint, since
most touched files already have warnings.

### R3 · A broken module file aborts the whole run with a raw error, and the file gets no `W, ns`

- **Severity:** nit
- **Area:** Readability
- **Where:** `tests/smoke/run.lua:150-154`
- **Status:** fixed in round 2 (`456b2fe`): `loadfile` plus `pcall(chunk, W, ns)`, a `FAIL load <path>` line, counted in `failures`; checked in a scratch copy (see Checks). A file returning a non-table value gets a confusing message; that is R12

**What's wrong.**

```lua
for path in listing:lines() do
    local moduleScenarios = assert(loadfile(path))()
    for _, s in ipairs(moduleScenarios) do table.insert(scenarios, s) end
end
```

A syntax error in a module file, or a file whose last line isn't `return
{ ... }`, raises outside `W.Call`, so the run stops after login with a bare
traceback (`lua5.1: tests/smoke/run.lua:153: bad argument #1 to 'ipairs'
(table expected, got nil)`) and none of `scenarios.lua`'s scenarios run or
report. The rest of the runner reports load problems as `FAIL load <path>`
and keeps going (`LoadLua`, lines 67-83). The chunk is also called with no
arguments, so a module file that starts with the addon's usual
`local _, ns = ...` gets `ns = nil` at file scope.

**Why it matters.** CI still fails (exit 1, checked), so nothing slips
through. But the person writing the first module file sees an error that
points at `run.lua:153`, not at their file, and loses every other result in
that mode. This is the kind of test-runner friction the module files are
meant to remove.

**Evidence.** Scratch copy of the tree (`git archive HEAD`), with
`tests/smoke/modules/B-Bad.lua` holding `return {` and then `local x = 1`:
both runs aborted as above, exit 1. With a file starting
`local _, ns = ...` the scenario still ran (its `fn` gets `W, ns`), but
`ns` at file scope was nil.

**Fix.** Report it like a load failure and pass the same values the
scenarios get:

```lua
local function LoadModuleScenarios(path)
    local chunk, loadError = loadfile(path)
    local ok, moduleScenarios = false, loadError
    if chunk then ok, moduleScenarios = pcall(chunk, W, ns) end
    if not (ok and type(moduleScenarios) == "table") then
        print("FAIL load " .. path .. ": " .. tostring(moduleScenarios or "returned no scenario list"))
        failures = failures + 1
        return
    end
    for _, scenario in ipairs(moduleScenarios) do table.insert(scenarios, scenario) end
end
```

### R4 · "SavedVariables saving only on `/reload`" leaves out logout and exit

- **Severity:** nit
- **Area:** Readability
- **Where:** `docs/READABLE-CODE.md:86`
- **Status:** fixed in round 2 (`456b2fe`): "on `/reload`, logout or exit"

**What's wrong.** "Name the game behaviour behind odd code: secret values,
the 60-upvalue limit, SavedVariables saving only on `/reload`." The
implementer file says it right: "SavedVariables save only on `/reload`,
logout or exit" (`implementer.md:52-53`).

**Why it matters.** It's a fact a newcomer will copy into a comment, and
it's the doc that tells them a wrong comment is worse than none.

**Evidence.** Lines read; the game writes SavedVariables on reload, logout
and quit (warcraft.wiki.gg "Saving variables between game sessions";
inferred from the implementer file and common knowledge, not from Ketho's
lists, which don't cover it).

**Fix.** "SavedVariables being written only on `/reload`, logout or exit."

### R5 · The 120-character limit doesn't say whether it covers existing lines

- **Severity:** nit
- **Area:** Readability
- **Where:** `docs/READABLE-CODE.md:39`; `.claude/agents/implementer.md:65-66`
- **Status:** fixed in round 2 (`456b2fe`): "New and changed lines up to 120 characters" in both files. The new wording invites shortening locale lines; that is R11

**What's wrong.** "Lines up to 120 characters." is new; nothing in the repo
enforced it before (`.editorconfig` has no `max_line_length`, there is no
`.luacheckrc`). 119 lines in 22 addon files already go past it (Locales and
Data excluded; `UI/Overview.lua` 27, `UI/LootGrid.lua` 13, `Core/Drops.lua` 9,
...), `tests/smoke/scenarios.lua` too (line 1863), and the locale files have
thousands of phrase lines that can't be wrapped.

**Why it matters.** Under "be demanding", the reviewer may flag every long
line in a file the PR touched, and the implementer may wrap long `L["..."]`
lines or long assert messages, churning the diff. Or the rule is quietly
ignored. Either way the rule doesn't say which.

**Evidence.** `awk 'length>120'` over `git ls-files 'NeedRoll/*.lua'`.

**Fix.** Say "New and changed lines up to 120 characters; a readability PR
may wrap the long lines of the file it cleans up. Locale phrase lines and
generated data are exempt." Optionally add `max_line_length = 120` to
`.editorconfig` under `[*.lua]` so the sumneko formatter's line hints match
(inferred: the formatter reads it; check it doesn't reflow whole files on
save before adding it).

### R6 · Doc says three levels of nesting is the sign, reviewer says past three

- **Severity:** nit
- **Area:** Readability
- **Where:** `docs/READABLE-CODE.md:75`; `.claude/agents/reviewer.md:43-44`
- **Status:** fixed in round 2 (`456b2fe`): both files now say "more than three levels"

**What's wrong.** Doc: "Three levels of indentation inside a function is a
sign to pull a piece out." Reviewer: "Nesting past three levels where a
guard clause would flatten it is a finding." One says 3 is the trigger, the
other 4, and it's unclear whether the function body itself counts as a
level.

**Why it matters.** The implementer writes to one number and the reviewer
checks the other, which is the inconsistency section 6 warns about.

**Evidence.** Lines quoted.

**Fix.** Pick one and say how it's counted, in both files, e.g. "More than
three levels of indentation inside a function body (the body itself is
level one)".

### R7 · The new loader breaks the new rules it ships with

- **Severity:** nit
- **Area:** Readability
- **Where:** `tests/smoke/run.lua:149`, `tests/smoke/run.lua:153`
- **Status:** fixed in round 2 (`456b2fe`): `AddScenarios(list)` with `for _, scenario in ipairs(list)`, one statement per line

**What's wrong.**

```lua
for _, s in ipairs(require("scenarios")) do table.insert(scenarios, s) end
...
    for _, s in ipairs(moduleScenarios) do table.insert(scenarios, s) end
```

Section 2 of the new doc: "One statement per line, except a one-line guard."
Section 1: short loop names "only when ... the table says what they are"
(its own example is `for _, quest in ipairs(quests)`, not `q`), and `s`
reads like the `S` size alias.

**Why it matters.** The PR that sets the bar is the first example the
implementer copies. Small, but this branch's next PRs will be held to it.

**Evidence.** Lines quoted. The existing loop at line 157 also uses `s`, so
the rename belongs to whichever PR cleans `run.lua`; the two new lines can
use the full name now.

**Fix.** `for _, scenario in ipairs(...)` with the body on its own line, or
fold both into R3's `LoadModuleScenarios`.

### R8 · The "readable" naming example also changes what the code does

- **Severity:** nit
- **Area:** Readability
- **Where:** `docs/READABLE-CODE.md:17-24`
- **Status:** fixed in round 2 (`456b2fe`): the example now calls `Send(secondsSinceLastSend)`

**What's wrong.**

```lua
-- Hard to read: what is d? what is t?
local d = GetTime() - t
if d > 60 then Send(d) end

-- Readable
local secondsSinceLastSend = GetTime() - lastSendTime
if secondsSinceLastSend > SEND_INTERVAL then SendNext() end
```

The "readable" version calls a different function with different
arguments (`Send(d)` became `SendNext()`).

**Why it matters.** The doc's last section says a readability change keeps
behaviour identical; the headline example shows the opposite. A reader
might take renaming plus re-plumbing a call as what "readable" means.

**Evidence.** Lines quoted.

**Fix.** Keep the call the same, renamed only:
`if secondsSinceLastSend > SEND_INTERVAL then Send(secondsSinceLastSend) end`,
or make both versions call `SendNext()`.

### R9 · The folder isn't in the commit, `ls` doesn't exist on Windows, and "every tab has been opened" isn't true under `--only`

- **Severity:** nit
- **Area:** Readability
- **Where:** `tests/smoke/README.md:17-23`; `tests/smoke/run.lua:150`; `tests/smoke/modules/`
- **Status:** fixed in round 2 (`456b2fe`): the README says the folder appears with the first module file, that the tests need bash, and adds the `--only` caveat. Its "Git Bash" claim is R10

**What's wrong.**

1. `tests/smoke/modules/` exists in the local checkout but is empty, and git
   doesn't track empty folders: `git ls-files tests/smoke/modules` is empty
   and a `git archive HEAD` copy has no such folder. The PR doesn't create
   it; the README describes it as if it does. The loader copes (verified:
   `ls` fails, `2>/dev/null` hides it, zero files load, "all passed"), so
   CI on ubuntu is fine.
2. `io.popen("ls tests/smoke/modules/*.lua 2>/dev/null")` needs a POSIX
   shell. On Windows, Lua's `io.popen` runs `cmd.exe` even from Git Bash,
   where `ls` doesn't exist; the module files would be skipped without a
   word (inferred, not run on Windows). The agents say Lua may not be
   installed on Windows at all, so this only matters if Mike runs the
   smoke tests there.
3. README: "runs after it, so the addon is logged in and every tab has been
   opened once." With `--only <name>` the `scenarios.lua` scenarios are
   filtered out too (`run.lua:158`), and with `--packaged` the `dev = true`
   ones are skipped, so a module scenario can't rely on the tabs having
   been opened.

**Why it matters.** (1) and (3) are small inaccuracies in docs meant for
the next PRs; (3) can make a module scenario pass in a full run and fail
under `--only`, which is how you'd debug it.

**Evidence.** Commands above; `run.lua:157-166` read.

**Fix.** (1) Leave it (the next PR adds the first file) or add a `.gitkeep`
(the `*.lua` glob ignores it). (2) A one-line comment that the listing needs
a POSIX shell, or print a warning when `io.popen` returns nothing while the
folder exists. (3) README: "A module scenario sets up what it needs itself
(open its tab, select its instance); don't rely on scenarios.lua having run,
since `--only` skips it."

### R10 · "Git Bash" is named as a way to run the tests, but a Windows Lua's `io.popen` uses `cmd.exe`

- **Severity:** nit
- **Area:** Readability
- **Where:** `tests/smoke/README.md:24-25`
- **Status:** open

**What's wrong.** "`run.lua` lists it with `ls`, so run the tests from bash
(CI, Git Bash or WSL on Windows)." Lua's `io.popen` doesn't use the shell it
was started from. A native Windows `lua5.1.exe` calls the C runtime's
`_popen`, which runs the command through `cmd.exe` (`%COMSPEC%`), even when
started from Git Bash. There `ls` isn't a command, `2>/dev/null` isn't a
valid path, and the loop gets no lines.

**Why it matters.** Mike follows the README, runs `tests/smoke/check.sh`
in Git Bash, sees "all passed", and his module scenarios never ran. Nothing
says they were skipped. WSL works (a Linux `lua5.1`), and so would an MSYS2
or Cygwin build of Lua.

**Evidence.** Inferred from how Lua 5.1's `io.popen` is built on Windows
(`_popen`); not run on Windows. Round 1 R9 said the same about `cmd.exe`.

**Fix.** Say "(CI, WSL, or an MSYS2/Cygwin Lua on Windows; a native Windows
Lua skips the module files)". Better, make a skip visible: if `io.popen`
returns no paths, print how many module files ran, e.g.
`print(("%d module scenario files"):format(moduleFileCount))`, so a
silent zero shows up.

### R11 · "shorten them when you touch them" reads as including the locale files

- **Severity:** nit
- **Area:** Readability
- **Where:** `docs/READABLE-CODE.md:39-40`
- **Status:** open

**What's wrong.** "New and changed lines up to 120 characters (some older
lines and the generated locale files run longer; shorten them when you
touch them)." "Them" covers both, so it tells the implementer to wrap long
lines in `NeedRoll/Locales/*.lua`.

**Why it matters.** The language files say "This file comes from
https://github.com/mikebvs/NeedRoll-Locales ... edit it there, not here. One
line per phrase" (`NeedRoll/Locales/deDE.lua:2-4`), and
`tools/translations.py:93` rejects any line that isn't one whole
`L["English"] = "Translation"` phrase. A wrapped phrase line fails the Lua
check workflow, and the next Translations PR overwrites the edit anyway.
`enUS.lua` is written by `tools/locales.py`.

**Evidence.** Lines quoted; `translations.py` line 93 read.

**Fix.** "(some older lines run longer; shorten them when you touch them.
The locale files and generated data keep one phrase or entry per line,
however long.)"

### R12 · A module file that returns a non-table value prints that value as if it were an error

- **Severity:** nit
- **Area:** Readability
- **Where:** `tests/smoke/run.lua:164-169`
- **Status:** open

**What's wrong.**

```lua
local ok, moduleScenarios = false, loadError
if chunk then
    ok, moduleScenarios = pcall(chunk, W, ns)
end
if ok and type(moduleScenarios) == "table" then
    AddScenarios(moduleScenarios)
else
    print("FAIL load " .. path .. ": " .. tostring(moduleScenarios or "returned no list of scenarios"))
```

`moduleScenarios` holds three different things: the load error, the
runtime error, or what the file returned. When the file loads and returns
something that isn't a table, the value itself is printed as the reason.
That is the mental mapping and disinformation sections 8 and 9 warn about,
in a small form.

**Why it matters.** `return "Core-Items"` (or `return true`) prints
`FAIL load tests/smoke/modules/Core-Items.lua: Core-Items`, which looks
like an error message, not "you returned the wrong thing".

**Evidence.** Scratch copy with `E-String.lua` holding `return "oops"`:
output `FAIL load tests/smoke/modules/E-String.lua: oops`.

**Fix.** Keep the error and the result apart:

```lua
local chunk, failure = loadfile(path)
local loaded, result = false, nil
if chunk then
    loaded, result = pcall(chunk, W, ns)
    if not loaded then failure = result end
end
if loaded and type(result) ~= "table" then
    failure = "returned " .. type(result) .. ", not a list of scenarios"
end
if failure then
    print("FAIL load " .. path .. ": " .. tostring(failure))
    failures = failures + 1
else
    AddScenarios(result)
end
```

### R13 · The implementer's "adds no warnings" luacheck step has no baseline

- **Severity:** nit
- **Area:** Readability
- **Where:** `.claude/agents/implementer.md:84-85`
- **Status:** open

**What's wrong.** "`luacheck --no-global -q` (when installed) on the Lua
files you touched: the change adds no warnings (unused values, shadowed
names)." The reviewer now compares with `git show origin/dev:<file>`; the
implementer has no way named to tell its warnings from those already
there. This was the second half of R2's fix in round 1 and wasn't done.

**Why it matters.** `luacheck --no-global -q NeedRoll/Core NeedRoll/UI`
reports 339 warnings in 29 files today, so an implementer touching
`UI/Overview.lua` sees dozens of warnings and either can't tell whether it
added one or "fixes" unrelated ones, against the behaviour-stays-the-same
rule for a non-cleanup PR. The reviewer then flags the new ones a round
later.

**Evidence.** Command output above; lines quoted.

**Fix.** Same wording as the reviewer: "...and on the `origin/dev` copy
(`git show origin/dev:<file> > <tmp>.lua`): the change adds no warnings."

### R14 · "colour" where the repo writes "color", and a README line wrapped past the file's width

- **Severity:** nit
- **Area:** Readability
- **Where:** `docs/READABLE-CODE.md:119`; `tests/smoke/README.md:25`
- **Status:** open

**What's wrong.** Section 8 says "`r`/`g`/`b`/`a` for colour channels".
Everywhere else in the doc, in Theme.lua and in `docs/STYLE-GUIDE.md` it's
"color" (98 uses against 2 of "colour" across `docs/`, `.claude/`,
`CLAUDE.md` and `Theme.lua`). And `tests/smoke/README.md:25` ("WSL on
Windows). A scenario checks what the module promises, not only that
nothing") runs to 82 characters while the file wraps near 76.

**Why it matters.** Section 6 asks for one way of doing each thing, and
section 7 for searchable names: a grep for "color" misses the line. Small,
but this is the rules doc.

**Evidence.** `grep -rhow color` / `grep -rho colour` counts; `awk
'length>80'` on the README.

**Fix.** "color channels"; rewrap the README paragraph.

## Area notes

### Readability

Read all of `docs/READABLE-CODE.md`, the full diffs of `CLAUDE.md` and
both agent files, and `tests/smoke/run.lua` in full. Checked the doc's
claims against the repo: the Theme.lua legend (`UI/Theme.lua:4-13`) does
list `T`, `S`, `C, F`, `UI`, `inst`, `enc` with those meanings; `ns:On`
exists (`Core/Init.lua:87`); `ns.Items:Load` exists and is used
(`UI/LootGrid.lua:257` and others); `docs/API.md` exists and lists the
`NeedRoll_Show*` functions; `.editorconfig` sets 4 spaces, LF, UTF-8, and
`sumneko.lua` is recommended in `.vscode/extensions.json`. Checked for
contradictions with the existing agent rules: none found beyond R2, R5 and
R6. "Each round is stricter" fits `CLAUDE.md`'s three-round cap, since Mike
decides what's left after round 3. The behaviour-stays-the-same list
(SavedVariables keys, addon message formats, `L["..."]` keys, public names)
matches what the addon relies on. Comments in the run.lua hunk say why and
match the file's density.

### WoW API

The change adds no game calls. The doc's one API example,
`C_Item.GetItemInfo(itemID)`, is in Ketho's `forever` `GlobalAPI.lua`
(line 2522); the global `GetItemInfo` is not, which matches the doc's
"use the `C_` namespace calls" line.

| API | In `forever` lists | Where looked |
| --- | --- | --- |
| `C_Item.GetItemInfo` (doc example only) | yes | `GlobalAPI.lua` |
| `issecretvalue` (named in the doc's comments section) | yes | `GlobalAPI.lua` |

`run.lua` uses only standard Lua 5.1 (`io.popen`, `loadfile`, `ipairs`,
`table.insert`), which `lua5.1` on ubuntu-latest has; the smoke workflow
installs `lua5.1` from apt and runs `tests/smoke/check.sh` with bash.
No new globals, no `tests/smoke/wow.lua` change needed, no UI change (so no
`docs/STYLE-GUIDE.md` update needed), no player-facing text.

Round 2: re-read section 8's new list against the repo (`local _, ns = ...`
is in every addon file, `W` in every scenario, Theme.lua's legend unchanged
and still accurate). The list now starts right after "keeps on purpose
are" with no blank line; CommonMark lets a `-` list interrupt a paragraph,
so it renders. In `run.lua`, `AddScenarios` does one job and the loader
reads top to bottom with one level of nesting; `ok` is kept as the usual
`pcall` name (R12 suggests clearer names anyway). The existing
`for _, s in ipairs(scenarios)` at `run.lua:172` wasn't touched and is left
for the PR that cleans `run.lua`. No narrating comments; the new comment
at `run.lua:146-149` says why the failure is counted.

### Redundant code

The loader is new: there was no other place that collects scenario files.
Compared with `LoadLua` (`run.lua:67-83`), which already does
load-and-report-failure; R3 suggests the loader follow it. The doc points
at the existing helper list in `implementer.md` instead of copying it. No
dead code added.

Round 2: `AddScenarios` replaces the two copied insert loops, so the
scenarios list is filled one way.

### Security

None. No untrusted input or output: no addon messages, no chat, no
SavedVariables, no names. `io.popen` runs a fixed command string with no
data from outside. `loadfile` runs only files committed under
`tests/smoke/modules/`, in the test runner, never in the addon or a
release (`tests/` isn't packaged). No workflow change. Round 2's `pcall(chunk, W, ns)`
changes nothing here: the chunks are still only committed test files.

## Round history

- 2026-10-17, `c0e5c79`, round 1: **Changes needed** (0 blocking, 2 should
  fix, 7 nits). Opened R1-R9.
- 2026-10-17, `456b2fe`, round 2: **Changes needed** (0 blocking, 0 should
  fix, 5 nits). Closed R1-R9 (R2's implementer half moved to R13). Opened
  R10-R14.
- 2026-10-17, after round 2: R10-R14 (nits) fixed in the next commit by the orchestrating session; no third round was run for nits alone (`.claude/commands/build.md` step 4).
