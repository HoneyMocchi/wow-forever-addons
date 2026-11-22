# Review: CI: run the scraper tests on pull requests that touch the scraper

| | |
| --- | --- |
| Branch | `scraper-ci` into `dev` (no PR yet) |
| Commit reviewed | `310b54a` (parent `7ab36d1`); no uncommitted changes |
| Date | 2026-10-18 |
| Round | 1 |
| Verdict | **Changes needed** (0 blocking, 2 should fix, 2 nits) |
| Needs | Nothing in game: CI only, no addon file changes |

## What the change does
Before, the scraper's unit tests ran only inside the Daily data update
(`daily-data.yml`, on `main`) and the by-hand loot checks
(`loot-data-check.yml`). A pull request that broke them went unnoticed until
the next daily run failed. The new workflow `.github/workflows/scraper-tests.yml`
runs `python -m unittest discover -s tests` in `scraper/` on every pull request
that changes `scraper/**` or `NeedRoll/UI/LootGrid.lua` (whose
`SKILL_LINE_IDS` table `SkillLineIDsTest` checks against `catalog.py`, the R9
decision on PR #612). It is advisory, read-only, with Python 3.12 and Lua 5.1,
the same steps the two other workflows use.

## Scope
- `.github/workflows/scraper-tests.yml`: new, 32 lines.

`git diff --stat origin/dev...310b54a` shows that one file only (`7ab36d1` is
already on `origin/dev`). No generated files.

## Checks
| Check | Result |
| --- | --- |
| Scraper tests, clean checkout (`git archive 310b54a`, no `scraper/cache`), no network (`unshare -rn`), Python 3.12.3 | passed: `Ran 157 tests ... OK`; no `scraper/cache` created afterwards |
| Same, Python 3.13 | passed, 157 tests |
| Workflow YAML parses (`yaml.safe_load`) | passed; ASCII, LF |
| `actionlint` | not run: not installed |
| `luac5.1 -p`, `luacheck`, `locales.py --check`, `translations.py`, smoke tests | not run: no Lua or locale files changed |
| Branch protection / rulesets (`gh api .../protection`, `/rulesets`) | not readable: HTTP 403 (private repo on the free plan); required checks taken from `smoke-tests.yml`'s comment |

Note on the local run: the first `unshare -rn` run had 4 errors in
`test_release.py`, all `git commit` failing because this machine's global git
config signs commits through a network signer. With `GIT_CONFIG_GLOBAL=/dev/null`
all 157 pass. A runner has no signing config, so this is a local artifact only.

## Findings
| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | should fix | Consistency (path filter) | `scraper-tests.yml:9` | Tests read `NeedRoll/Data/Dungeons` and `Raids`, which the filter leaves out | fixed at integration |
| R2 | should fix | Consistency (path filter) | `scraper-tests.yml:9` | The workflow doesn't trigger on changes to itself, so it never runs on this PR | fixed at integration |
| R3 | nit | Consistency | `scraper-tests.yml:15-16` | No `name:` and no `timeout-minutes:` on the job | fixed at integration |
| R4 | nit | Readability | `scraper-tests.yml:5` | Comment says the tests "only" run in the daily update | fixed at integration |

### R1 · Tests read `NeedRoll/Data/Dungeons` and `Raids`, which the filter leaves out
- **Severity:** should fix
- **Area:** Consistency (path filter)
- **Where:** `.github/workflows/scraper-tests.yml:9`
- **Status:** open

**What's wrong.** `paths: ["scraper/**", "NeedRoll/UI/LootGrid.lua"]` covers
one input outside `scraper/`, but the tests read a second one:
`scraper/tests/test_observed.py:205-210`,

```python
def test_generated_files_read_back_unchanged(self):
    for d in catalog.ALL:
        path = ROOT / "NeedRoll" / "Data" / d.path
        if d.category in ("DUNGEON", "RAID") and path.exists():
```

reads every generated dungeon and raid file (26 `Dungeons/`, 7 `Raids/`
entries in `catalog.py`) and checks that `emit.render(observed.read_instance(text))`
gives the same text back.

**Why it matters.** That round trip is what the daily build relies on to
rewrite those files from observed drops. A PR that hand-edits a generated
file (which the reviewer rules flag) or merges a data file that doesn't
round-trip passes this workflow because it never runs, and the next daily run
on `main` stops at "Test the scraper", losing that day's data and release.

**Evidence.** Grep of `scraper/tests/*.py` for paths outside `scraper/`: only
`test_observed.py:207` (`NeedRoll/Data`) and `test_professions.py:340`
(`LootGrid.lua`); every other file a test touches is a temp fixture. I
indented one line of `NeedRoll/Data/Dungeons/BlackfathomDeeps.lua` in a
scratch copy and `python3 -m unittest tests.test_observed` failed
(`FAILED (failures=1)`).

**Fix.**
```yaml
paths:
  - scraper/**
  - NeedRoll/Data/Dungeons/**
  - NeedRoll/Data/Raids/**
  - NeedRoll/UI/LootGrid.lua
  - .github/workflows/scraper-tests.yml
```
(or `NeedRoll/Data/**`), and name the data folders in the header comment.
Bot data PRs opened with `GITHUB_TOKEN` don't start `pull_request` runs, so
this adds runs only for human PRs that touch the data.

### R2 · The workflow doesn't trigger on changes to itself, so it never runs on this PR
- **Severity:** should fix
- **Area:** Consistency (path filter)
- **Where:** `.github/workflows/scraper-tests.yml:9`
- **Status:** open

**What's wrong.** `.github/workflows/scraper-tests.yml` isn't in `paths`.
This PR into `dev` changes only that file (`git diff --stat origin/dev...310b54a`),
so the new workflow doesn't run on its own PR, and a later edit to it (Python
version, steps) isn't tested either.

**Why it matters.** The first time anyone sees it run is the next scraper
PR, so a broken step only shows up there. `santiago-maps.yml:13-15` lists its
own workflow file in its `pull_request` paths for this reason.

**Evidence.** `santiago-maps.yml` lines 12-15 read; diff stat above.

**Fix.** Add `.github/workflows/scraper-tests.yml` to `paths` (sketch in R1).

### R3 · No `name:` and no `timeout-minutes:` on the job
- **Severity:** nit
- **Area:** Consistency
- **Where:** `.github/workflows/scraper-tests.yml:15-16`
- **Status:** open

**What's wrong.** The job is `test:` with no `name:`, so its check is called
`test` (shown as "Scraper tests / test"). There is no `timeout-minutes:`,
so a hung run holds a runner for GitHub's default 360 minutes.

**Why it matters.** It doesn't clash today: the only checks on a recent `dev`
commit are `Smoke tests` and `compile` (`gh api .../commits/40c36fc/check-runs`),
and `smoke-tests.yml` says branch protection requires `Smoke tests`. But
required checks match by job name, and `test` is the most generic one there
is; `smoke-tests.yml` gives its job `name: Smoke tests` on purpose. The suite
takes under 2 seconds locally.

**Evidence.** `smoke-tests.yml:17-20` (`name: Smoke tests`, `timeout-minutes: 10`);
`daily-data.yml` has `timeout-minutes: 60`.

**Fix.**
```yaml
jobs:
  test:
    name: Scraper tests
    runs-on: ubuntu-latest
    timeout-minutes: 10
```

### R4 · Comment says the tests "only" run in the daily update
- **Severity:** nit
- **Area:** Readability
- **Where:** `.github/workflows/scraper-tests.yml:5`
- **Status:** open

**What's wrong.** "Without this they only run in the daily data update on
main" leaves out `loot-data-check.yml`, which also runs them (by hand).

**Fix.** "Without this they only run when the data is built (the daily
update on main and the by-hand loot checks), where a failure stops that run."

## Area notes

### Readability
Header comment explains why the workflow exists, why `LootGrid.lua` is in
the filter and that it is advisory, at the density of the other workflow
headers. Step names and the Lua comment match `daily-data.yml` word for word.
Only R4.

### WoW API
Not applicable: no addon code. No game functions, events, widgets, templates,
atlases or `Enum`s added.

| API | In `forever` lists | Where looked |
| --- | --- | --- |
| none | n/a | n/a |

### Redundant code
Compared against `daily-data.yml` and `loot-data-check.yml`: checkout,
`setup-python@v5` 3.12, the Lua 5.1 install line and the test step are the
same text. There's no `pip install` step, which is correct:
`scraper/requirements.txt` says the scraper uses only the standard library.
Leaving out `actions/cache` (which both others restore) is right for a PR
check. The repeated steps could be a reusable workflow, but at four short
steps a copy is simpler. Nothing to remove.

### Security
- **Trigger:** `pull_request`, not `pull_request_target`. Fork PRs run with
  a read-only token and no secrets; no `secrets.*` is referenced.
- **Permissions:** `contents: read` at workflow level, least privilege.
- **Injection:** no `${{ github.event.* }}` anywhere; the `run:` lines are fixed text.
- **Cache:** none restored or saved, so a PR can't poison the
  `loot-cache-*` entries the daily build reads, and the tests can't see
  cached Wowhead pages.
- **Network / Wowhead:** the suite passed 157/157 in a network namespace with
  no interface (`unshare -rn`) on a clean `git archive` with no
  `scraper/cache`, so no test needs the network. Wowhead code in
  `sources/wowhead.py` is cache-only (`_fetch` raises `Retired` for an
  uncached page, line 88), and tests that touch it mock `_fetch`/`npc_drops`
  (`test_newinstances.py:139`, `test_pipeline.py:111`). The run prints
  `Wowhead pages (retired, cache only): 1 read, 1 not cached`, from a temp
  fixture cache. The only network use is `apt-get` for Lua 5.1 and the
  `setup-python` download, the same as the other workflows.
- **Actions:** `actions/checkout@v4` and `actions/setup-python@v5` pinned by
  tag, the same as every other workflow here.
- **Names:** the tests read no SavedVariables or `scraper/drops/`, and the
  workflow writes no artifacts, so no character names reach the log.
- **Python:** the tests run `git` via `subprocess.run([...])` with list
  arguments in temp dirs (`test_release.py:147`), no `shell=True`.

## Round history
- 2026-10-18 · `310b54a` · Changes needed · opened R1, R2, R3, R4

## Integration

R1-R4 fixed by the coordinating session before the PR: the path filter adds `NeedRoll/Data/Dungeons/**`, `NeedRoll/Data/Raids/**` and the workflow's own file; the job is named "Scraper tests" with `timeout-minutes: 15`; the comment names both data builds. YAML parses; the scraper tests pass on a clean checkout.
