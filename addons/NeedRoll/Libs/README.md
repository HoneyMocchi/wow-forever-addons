# Embedded libraries

Copied unchanged from other addons' embedded copies (the highest versions
installed on 2026-11-18). NeedRoll uses them for its minimap button
(UI/MinimapButton.lua), so minimap addons such as SexyMap, HidingBar and
ElvUI manage it like any other addon's button.

| Library | Version (LibStub minor) | Licence |
|---|---|---|
| LibStub | 2 | Public domain (see its header) |
| CallbackHandler-1.0 | 8 | Ace3's BSD-style licence, `CallbackHandler-1.0/LICENSE.txt` |
| LibDataBroker-1.1 | 4 | Published freely for embedding by its author, tekkub (github.com/tekkub/libdatabroker-1-1); no licence file ships with it |
| LibDBIcon-1.0 | 57 | Ace3's BSD-style licence, `LibDBIcon-1.0/LICENSE.txt` (the text on its CurseForge licence page, curseforge.com/wow/addons/libdbicon-1-0/license; the copies embedded in other addons leave it out) |

Update a library by copying a newer release over its file and changing the
version here; never edit the library files themselves.
