# Setting up NeedRoll on a new computer

Everything NeedRoll needs on your PC, in order. Run the PowerShell commands
in a normal (not admin) PowerShell window, so the scheduled tasks register
under your own account. Change the paths if WoW: Forever or the clone ends
up somewhere else.

| What | Script or file |
| --- | --- |
| Addon link and auto-updates | [tools/Setup-AutoUpdate.ps1](../tools/Setup-AutoUpdate.ps1) (runs [tools/Update-NeedRoll.ps1](../tools/Update-NeedRoll.ps1)) |
| Combat log watcher | [tools/combatlog/Setup-CombatLogWatcher.ps1](../tools/combatlog/Setup-CombatLogWatcher.ps1) (runs [Watch-WoW.ps1](../tools/combatlog/Watch-WoW.ps1) and [scrape_combatlog.py](../tools/combatlog/scrape_combatlog.py)) |
| Scraper | [scraper/](../scraper/README.md) |

## Before you reformat

The repo is safe on GitHub, and the combat log watcher keeps its data and your
NeedRoll SavedVariables on the `data/watcher` branch
([tools/combatlog](../tools/combatlog/README.md#kept-on-github-imported-there)).
What's left only exists on your PC:

- **Work that isn't on GitHub** in `C:\NeedRoll`:

  ```powershell
  cd C:\NeedRoll
  git status
  git log --branches --not --remotes --oneline   # commits not on GitHub
  git stash list
  ```

  Push anything that shows up (`git push -u origin <branch>`).
- **WoW's `WTF` folder** if it's on the drive you're wiping. It holds your
  devedit saved copy, settings, shopping list, wishlist and keybinds. Send
  Claude a `/nr devexport` too if there are devedit edits you haven't sent.
- **WoW's `Logs` folder**, if you want to keep old combat logs.

`scraper\cache` needn't be kept: everything in it downloads again, and a
build with an empty cache gives the same data files.

## 1. Install the tools

- **Git for Windows**: https://git-scm.com/download/win. Keep the defaults:
  they include Git Credential Manager (the auto-updater and the watcher use
  it to reach the private repo) and Git Bash (runs the smoke tests). Then:

  ```powershell
  git config --global user.name "Mike"
  git config --global user.email "<your GitHub email>"
  ```

- **Python 3.10 or later**: https://www.python.org/downloads/. Tick **Add
  python.exe to PATH** in the installer; it also adds the `py` launcher.
  No pip packages: the scraper and tools only use the standard library.
- **Lua 5.1** (not 5.3 or 5.4). The quest build (which reads QuestieDB) and
  the smoke tests need it. Download
  [lua-5.1.5_Win64_bin.zip](https://sourceforge.net/projects/luabinaries/files/5.1.5/Tools%20Executables/lua-5.1.5_Win64_bin.zip/download)
  from LuaBinaries, unzip it to `C:\Tools\lua51` and add that folder to your
  PATH:

  ```powershell
  [Environment]::SetEnvironmentVariable('Path', [Environment]::GetEnvironmentVariable('Path','User') + ';C:\Tools\lua51', 'User')
  ```

  In a new PowerShell window, `lua5.1 -v` prints `Lua 5.1.5`. For another
  Lua 5.1 build, set `NEEDROLL_LUA` to its full path instead.
- **VS Code** (or Visual Studio). The repo recommends the Lua (sumneko), WoW
  API (Ketho) and Python extensions; VS Code offers them when you open the
  folder.

## 2. Clone the repo to `C:\NeedRoll`

```powershell
git clone https://github.com/mikebvs/NeedRoll C:\NeedRoll
```

The repo is private, so sign in to GitHub in the window that pops up. A fresh
clone is on `dev`, which is what the auto-updater follows.

## 3. Link the addon and turn on auto-updates

```powershell
powershell -ExecutionPolicy Bypass -File C:\NeedRoll\tools\Setup-AutoUpdate.ps1 `
  -AddOnsPath "E:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns"
```

This links `AddOns\NeedRoll` to `C:\NeedRoll\NeedRoll` (it says "Already
linked" when a kept game folder still has the link) and registers the
**NeedRoll Auto-Update** task, which pulls the latest `dev` at logon and
every 10 minutes. Its log is `%LOCALAPPDATA%\NeedRoll\auto-update.log`.

## 4. Turn on combat logging in the game

Start the game (a full start, not `/reload`), check NeedRoll opens with `/nr`, then:

- **System > Network > Advanced Combat Logging**: on. Your clone's dev build
  says at login whether it is, and turns it on if not.
- Type `/combatlog` each time you play (your clone's dev build does this for
  you at login). It stays on until you log out.

## 5. Start the combat log watcher

```powershell
powershell -ExecutionPolicy Bypass -File C:\NeedRoll\tools\combatlog\Setup-CombatLogWatcher.ps1
```

This registers the **NeedRoll Combat Log Watcher** task, which starts at
logon and scrapes new combat log lines each time WoW closes. On a new PC it
first restores what it had collected from the `data/watcher` branch. After
each scrape it pushes its data and your NeedRoll SavedVariables there, and
GitHub opens a "Data from the combat log watcher" pull request into dev.
Pass `-LogsPath "<path>\Logs"` if the game lives somewhere else.

- Collected data: `%LOCALAPPDATA%\NeedRoll\CombatLog`.
- Its log: `%LOCALAPPDATA%\NeedRoll\combatlog-watcher.log`.

## 6. Claude

- **Claude Code** (Remote Control sessions run it on your PC):

  ```powershell
  irm https://claude.ai/install.ps1 | iex
  ```

  It installs to `%USERPROFILE%\.local\bin`. If a new PowerShell window
  doesn't find `claude`, add that folder to your PATH the same way as Lua.
  Run `claude` once in `C:\NeedRoll` and sign in.
- **Claude desktop app**: sign in. Folder access (`C:\NeedRoll`, the game's
  `AddOns\NeedRoll`, `Logs` and `WTF`) and Remote Control are asked for again
  the first time a project thread needs them.

## Check it all worked

- `/nr` opens in game.
- Task Scheduler lists **NeedRoll Auto-Update** and **NeedRoll Combat Log
  Watcher**, both under your user.
- `%LOCALAPPDATA%\NeedRoll\combatlog-watcher.log` says "Watching for WoW".
- `cd C:\NeedRoll\scraper; py -m unittest discover -s tests` passes.
- In Git Bash, `cd /c/NeedRoll && tests/smoke/check.sh` passes.

## Removing it

```powershell
powershell -ExecutionPolicy Bypass -File C:\NeedRoll\tools\Setup-AutoUpdate.ps1 -Uninstall
powershell -ExecutionPolicy Bypass -File C:\NeedRoll\tools\combatlog\Setup-CombatLogWatcher.ps1 -Uninstall
```

Both leave your data in place. Delete `AddOns\NeedRoll` (it's only a link)
to take the addon out of the game.
