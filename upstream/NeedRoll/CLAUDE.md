# Notes for Claude

- **Style guide:** any change to the addon's UI (sizes, fonts, colors, icons,
  buttons, layout) must update [docs/STYLE-GUIDE.md](docs/STYLE-GUIDE.md) in
  the same PR, with values read from the code.
- **Player names stay private:** character names and drop-sharing credits
  (SavedVariables copies, the `data/watcher` branch, `scraper/drops/`) live
  only in this private repo. If the addon is ever published on its own as a
  public repo, none of them go there: check any public copy, mirror or
  export for names before it's pushed (Mike, 2026-10-17).
- **Implementer agent:** code changes go through
  `.claude/agents/implementer.md`; `/build <task>` runs it. Everyday PRs get
  no reviewer run and no Review Doc (Mike, 2026-10-18).
- **Reviewer agent, feature releases only:** before the changelog PR of a
  feature release (minor bump, `vX.Y.0`), `/release-review vX.Y.0` runs
  `.claude/agents/reviewer.md` on everything since the last tag. It puts
  readability, security and WoW: Forever API per Ketho's resources first,
  redundant code last.
  At most two review rounds, then Mike decides what's left. Its Review Doc,
  `docs/reviews/release-vX.Y.0.md`, goes in the fixes PR, linked from its
  description. Patch releases, bot PRs (Translations, daily data) and
  everyday PRs skip it, unless Mike asks for a review (Mike, 2026-10-18).
- **Readable code:** every Lua change follows
  [docs/READABLE-CODE.md](docs/READABLE-CODE.md): meaningful, searchable
  names (no `d` for "days"), consistent formatting, one job per function,
  guard clauses over nesting, comments a newcomer can follow, one way of
  doing each thing, no names or comments that mislead. Less code is the goal
  unless it costs fidelity, security or behaviour (Mike, 2026-10-17).
- **Combat-protected calls:** every call the game blocks in combat handles
  the in-combat case on purpose (Mike, 2026-10-20). "Properly" means one of
  three things. **Avoid** the call where a script does the same job (icons
  pass clicks with `ns.UI.ClicksReachBeneath`, not `SetPropagateMouseClicks`).
  **Wait** for PLAYER_REGEN_ENABLED when doing it later is harmless
  (`ns.UI.PassRightClicks`). **Refuse or fall back** and tell the player when
  it isn't (key bindings print a message; map links draw NeedRoll's own pin).
  Never open or switch the game's map from NeedRoll's code in combat. The
  four calls blocked for every frame (`SetPropagateMouseClicks`,
  `SetPropagateMouseMotion`, `SetPassThroughButtons`,
  `SetPropagateKeyboardInput`) may appear only in the spots the smoke
  scenario "calls the game blocks in combat appear only where combat is
  checked" lists. Secure frames and the frames holding them go back to
  UIParent as combat starts. A new restricted call gets a
  `W.BlockIfInCombat` check in `tests/smoke/wow.lua`, so the `--combat`
  smoke run (#685) catches it.
- **Changelogs, two of them:** `CHANGELOG.md` is what players read on
  CurseForge, so its lines are broad strokes: "Updated quest XP values",
  "Updated profession skill level requirements", "Changed how NeedRoll
  finds your nearest trainer". No item, quest or NPC names, numbers or
  before/after values there. The detail goes in `CHANGELOG-DETAILED.md`,
  one `### PR #N: title` heading per pull request under each `## vX.Y.Z`,
  with every change listed ("The Islander XP 610 to 600"). Each release's
  changelog PR updates both (Mike, 2026-11-06).
- **Every client's language:** everything NeedRoll takes from or hands to
  the game works on all 11 client locales (Mike, 2026-11-11). Use the game's
  own globals (`SLASH_*`, `ERR_*`, `ITEM_*`, `FACTION_STANDING_LABEL*`,
  `DUNGEON_FLOOR_*`; `ns.GameTextPatterns` for lines the game writes), never
  English matched against game text. Separators go through `ns.DOT`. A new
  non-ASCII character in shown text must exist in `FRIZQT___CYR` and the
  Chinese and Korean fonts (the Locale tests check it). Textures ship with
  NeedRoll, or are known to be shared by every locale. A new
  locale-dependent call gets coverage in the Locale tests
  (`tests/smoke/check.sh --locale all`).
- **Blizzard hotfixes, every release:** every release, data (daily data,
  ingest, patch) and feature, checks Blizzard's WoW: Forever hotfix post
  (https://us.forums.blizzard.com/en/wow/t/2403040) with
  `tools/hotfixes.py` and writes each new entry in our own words in
  `NeedRoll/Data/Hotfixes.lua`, never Blizzard's text. An entry Blizzard
  drops is never deleted: `--write` marks it removed, so the Game hotfixes
  page shows it struck through. If the cloud can't reach the forum, read it
  through a browser or a saved copy of its raw page (Mike, 2026-11-17).
- **Smoke tests run in CI only for releases:** to save GitHub Actions
  minutes, the "Smoke tests" workflow runs only on the release PR into
  `main` and by hand; PRs into `dev` skip it (a skipped job passes the
  required check). So every addon change runs `tests/smoke/check.sh`
  locally before it's pushed, and the PR says it passed. Bot PRs (watcher
  data, Translations) and the daily data pushes still run it themselves
  (Mike, 2026-11-18).
