# Review Docs

One file per review, written by the reviewer agent
(`.claude/agents/reviewer.md`). The reviewer runs once per feature release
(`/release-review vX.Y.0`, file `release-vX.Y.0.md`, committed in that
release's fixes PR) and on a branch only when Mike asks
(`<branch>.md`, committed in that PR). Older files here are from when every
PR was reviewed. Each holds the verdict, the checks that ran, and
every finding on readability, WoW: Forever API use, redundant code and
security, with evidence and a fix, plus how each finding was resolved
across review rounds.
