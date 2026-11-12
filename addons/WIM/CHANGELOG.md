# WIM

## [3.19.1](https://github.com/Legacy-of-Sylvanaar/wow-instant-messenger/tree/3.19.1) (2026-11-06)
[Full Changelog](https://github.com/Legacy-of-Sylvanaar/wow-instant-messenger/compare/3.19.0...3.19.1) [Previous Releases](https://github.com/Legacy-of-Sylvanaar/wow-instant-messenger/releases)

- Fix progress bar width calculation in HistoryViewer to prevent overflow  
- Refactor dialog handling to use a custom dialog system; replace StaticPopup with WIM.dialog.create in multiple modules and add new dialog templates taints and protected function errors.  
- Merge branch 'master' into alpha  
- Merge pull request #301 from kastorny/fix/cyrillic-skin-fonts  
    Fix Cyrillic names in skin fonts on English clients  
- Guild Invite shortcut modified to prevent execution while in combat. First check to see if `C_GuildInfo` exists before using the deprecated `GuildInvite` function.  
- Fix Cyrillic names in skin fonts on English clients  