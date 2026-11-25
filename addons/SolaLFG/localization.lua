-- =========================================================================
-- SolaLFG - English (Base / Fallback) Localization
-- =========================================================================

-- Active Locale Override
-- "koKR" for Korean, "enUS" for English, or nil to auto-detect via GetLocale()
SolaFP_ACTIVE_LOCALE = nil

function SolaFP_GetLocale()
	if SolaFP_ACTIVE_LOCALE then return SolaFP_ACTIVE_LOCALE end
	local loc = (GetLocale and GetLocale())
	if loc == "koKR" then return "koKR" end
	return "enUS"
end

-- Polyfills for WoW API compatibility
if not GetAddOnMetadata and C_AddOns and C_AddOns.GetAddOnMetadata then
	GetAddOnMetadata = C_AddOns.GetAddOnMetadata
end

if not getglobal then
	getglobal = function(name) return _G[name] end
end

function SolaFP_GetVersionString()
	local ver = (C_AddOns and C_AddOns.GetAddOnMetadata and (C_AddOns.GetAddOnMetadata("SolaLFG", "version") or C_AddOns.GetAddOnMetadata("FindParty", "version")))
		or (GetAddOnMetadata and (GetAddOnMetadata("SolaLFG", "version") or GetAddOnMetadata("FindParty", "version")))
		or "1.39"
	return ver
end

function SolaFP_GetPlayerClassName()
	local locCls, clsToken = UnitClass("player")
	if ((SolaFP_GetLocale and SolaFP_GetLocale() or GetLocale()) ~= "koKR") then
		local classMap = {
			WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter",
			ROGUE = "Rogue", PRIEST = "Priest", SHAMAN = "Shaman",
			MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid",
		}
		if clsToken and classMap[clsToken] then
			return classMap[clsToken]
		end
	end
	return locCls or "Class"
end

-- Localization Tables
SolaFP_L = SolaFP_L or {}
setmetatable(SolaFP_L, {
	__index = function(t, k)
		return k
	end,
})

SolaFP_L_EN = {}

-- Common UI & Panel
SolaFP_L_EN["LFG"] = "LFG"
SolaFP_L_EN["Close"] = "Close"
SolaFP_L_EN["Settings"] = "Settings"
SolaFP_L_EN["Refresh"] = "Refresh"
SolaFP_L_EN["Apply"] = "Apply"
SolaFP_L_EN["Apply via Whisper"] = "Apply via Whisper"
SolaFP_L_EN["Send Whisper"] = "Send Whisper"
SolaFP_L_EN["Open Chat (/w)"] = "Open Chat (/w)"
SolaFP_L_EN["Invite"] = "Invite"
SolaFP_L_EN["Who (/who)"] = "Who (/who)"
SolaFP_L_EN["List Group"] = "List Group"
SolaFP_L_EN["Blizzard Group Finder"] = "Blizzard Group Finder"
SolaFP_L_EN["Dungeon Filter"] = "Dungeon Filter"
SolaFP_L_EN["Detailed Filters"] = "Detailed Filters"
SolaFP_L_EN["Reset All Filters"] = "Reset All Filters"
SolaFP_L_EN["All"] = "All"
SolaFP_L_EN["Select All"] = "Select All"
SolaFP_L_EN["Clear"] = "Clear"
SolaFP_L_EN["Clear All"] = "Clear All"
SolaFP_L_EN["Add"] = "Add"
SolaFP_L_EN["Level"] = "Level"
SolaFP_L_EN["Level ▲"] = "Level ▲"
SolaFP_L_EN["Level ▼"] = "Level ▼"
SolaFP_L_EN["Dungeons"] = "Dungeons"
SolaFP_L_EN["Dungeons ▼"] = "Dungeons ▼"
SolaFP_L_EN["ROW_COUNT_FORMAT"] = "(%d groups) (%d players)"
SolaFP_L_EN["Filters ▶"] = "Filters ▶"
SolaFP_L_EN["Filters %s"] = "Filters %s"
SolaFP_L_EN["Filters(%d) %s"] = "Filters(%d) %s"
SolaFP_L_EN["Active filters: %d"] = "Active filters: %d"
SolaFP_L_EN["%d listings found"] = "%d listings found"
SolaFP_L_EN["Groups: %d  ·  Seekers: %d"] = "Groups: %d  ·  Players: %d"
SolaFP_L_EN["Formed Groups  ·  %d"] = "Formed Groups  ·  %d"
SolaFP_L_EN["Individual Seekers"] = "Players LFG"
SolaFP_L_EN["Individual Seekers  ·  %d"] = "Players LFG  ·  %d"
SolaFP_L_EN["No listings found."] = "No listings found."
SolaFP_L_EN["Searching..."] = "Searching..."
SolaFP_L_EN["Initializing LFG (C_LFGList)..."] = "Initializing LFG (C_LFGList)..."
SolaFP_L_EN["Search timed out. Please click [Refresh]."] = "Search timed out. Please click [Refresh]."
SolaFP_L_EN["Search request failed. (Please try again shortly)"] = "Search request failed. (Please try again shortly)"
SolaFP_L_EN["Waiting to refresh... (%ds cooldown)"] = "Waiting to refresh... (%ds cooldown)"
SolaFP_L_EN["Last refreshed: %d sec ago"] = "Last refreshed: %d sec ago"
SolaFP_L_EN["Last refreshed: Never"] = "Last refreshed: Never"
SolaFP_L_EN["Cannot send a whisper to yourself."] = "Cannot send a whisper to yourself."
SolaFP_L_EN["Please select a listing first."] = "Please select a listing first."
SolaFP_L_EN["LFG filters have been reset."] = "LFG filters have been reset."
SolaFP_L_EN["All dungeon filters enabled."] = "All dungeon filters enabled."
SolaFP_L_EN["Page: %d / %d (%d-%d of %d)"] = "Page: %d / %d (%d-%d of %d)"
SolaFP_L_EN["(Currently Active)"] = "(Currently Active)"
SolaFP_L_EN["[Exclude]"] = "[Exclude]"
SolaFP_L_EN["Anonymous"] = "Anonymous"
SolaFP_L_EN["Unnamed"] = "Unnamed"
SolaFP_L_EN["Unknown"] = "Unknown"
SolaFP_L_EN["Unknown Class"] = "Unknown Class"
SolaFP_L_EN["Unspecified Activity"] = "Unspecified Activity"
SolaFP_L_EN["Other Dungeon #%s"] = "Other Dungeon #%s"
SolaFP_L_EN["Hello, inquiring about your LFG listing."] = "Hello, inquiring about your LFG listing."

-- Roles
SolaFP_L_EN["Tank"] = "Tank"
SolaFP_L_EN["Healer"] = "Healer"
SolaFP_L_EN["Damage"] = "Damage"
SolaFP_L_EN["DPS"] = "DPS"
SolaFP_L_EN["Role_Tank_Short"] = "Tank"
SolaFP_L_EN["Role_Healer_Short"] = "Heal"
SolaFP_L_EN["Role_DPS_Short"] = "DPS"
SolaFP_L_EN["Open Roles"] = "Open Roles"
SolaFP_L_EN["Open Tank Slot"] = "Open Tank Slot"
SolaFP_L_EN["Open Healer Slot"] = "Open Healer Slot"
SolaFP_L_EN["Open DPS Slot"] = "Open DPS Slot"
SolaFP_L_EN["Formed Roles"] = "Group Composition"
SolaFP_L_EN["Has Tank"] = "Has Tank"
SolaFP_L_EN["Has Healer"] = "Has Healer"
SolaFP_L_EN["Groups with Tank"] = "Groups with Tank"
SolaFP_L_EN["Groups with Healer"] = "Groups with Healer"
SolaFP_L_EN["Tank Seekers"] = "Tank Players"
SolaFP_L_EN["Healer Seekers"] = "Healer Players"
SolaFP_L_EN["DPS Seekers"] = "DPS Players"

-- Classes
SolaFP_L_EN["Warrior"] = "Warrior"
SolaFP_L_EN["Paladin"] = "Paladin"
SolaFP_L_EN["Hunter"] = "Hunter"
SolaFP_L_EN["Rogue"] = "Rogue"
SolaFP_L_EN["Priest"] = "Priest"
SolaFP_L_EN["Shaman"] = "Shaman"
SolaFP_L_EN["Mage"] = "Mage"
SolaFP_L_EN["Warlock"] = "Warlock"
SolaFP_L_EN["Druid"] = "Druid"

-- Filters & Chips Tooltips
SolaFP_L_EN["Configure role vacancies, seeker roles, levels, and classes."] = "Configure open roles, player roles, levels, and classes."
SolaFP_L_EN["Show groups with an open tank slot."] = "Show groups with an open tank slot."
SolaFP_L_EN["Show groups with an open healer slot."] = "Show groups with an open healer slot."
SolaFP_L_EN["Show groups with an open DPS slot."] = "Show groups with an open DPS slot."
SolaFP_L_EN["Show groups that already have 1 or more tanks."] = "Show groups that already have 1 or more tanks."
SolaFP_L_EN["Show groups that already have 1 or more healers."] = "Show groups that already have 1 or more healers."
SolaFP_L_EN["Show individual players listed as Tank."] = "Show players listed as Tank."
SolaFP_L_EN["Show individual players listed as Healer."] = "Show players listed as Healer."
SolaFP_L_EN["Show individual players listed as DPS."] = "Show players listed as DPS."
SolaFP_L_EN["Hide Groups with Excluded Classes"] = "Hide Groups with Excluded Classes"
SolaFP_L_EN["Hide formed groups that contain unselected classes."] = "Hide formed groups that contain unselected classes."
SolaFP_L_EN["Seeker Level Filter"] = "Level Filter"
SolaFP_L_EN["Seeker Class Filter"] = "Class Filter"
SolaFP_L_EN["%s Class Filter"] = "%s Class Filter"
SolaFP_L_EN["Toggle listings for %s individual seekers."] = "Toggle listings for %s players."
SolaFP_L_EN["Filter: All Levels"] = "Filter: All Levels"
SolaFP_L_EN["Filter: Level-appropriate"] = "Filter: Level-appropriate"
SolaFP_L_EN["Show all dungeon listings regardless of level."] = "Show all dungeon listings regardless of level."
SolaFP_L_EN["Show dungeons appropriate for your current level."] = "Show dungeons appropriate for your current level."
SolaFP_L_EN["Click: Switch to All Levels mode"] = "Click: Switch to All Levels mode"
SolaFP_L_EN["Click: Switch to Level mode"] = "Click: Switch to Level mode"
SolaFP_L_EN["Filter by specific dungeons."] = "Filter by specific dungeons to show interested only."
SolaFP_L_EN["Left-Click: Toggle dungeon filter menu"] = "Left-Click: Toggle dungeon filter menu"
SolaFP_L_EN["Wheel-Click: Toggle View All / Filtered"] = "Wheel-Click: Toggle View All / Interested Dungeons"
SolaFP_L_EN["Right-Click: Clear selected dungeons"] = "Right-Click: Clear selected dungeons (View All)"
SolaFP_L_EN["Reset Selection"] = "Clear Selected"
SolaFP_L_EN["Select Fit"] = "Select Fit"
SolaFP_L_EN["Level-fit Dungeons"] = "Select Level-Fit"
SolaFP_L_EN["Showing all dungeons."] = "Showing all dungeons. (View All)"
SolaFP_L_EN["All dungeon filters cleared."] = "All dungeon filters cleared."
SolaFP_L_EN["Clear Excluded"] = "Reset"
SolaFP_L_EN["Clear Exclusions"] = "Clear Exclusions"
SolaFP_L_EN["Restore all dungeons excluded from the list via Ctrl+Left-Click."] = "Restore all dungeons excluded from the list via Ctrl+Left-Click."
SolaFP_L_EN["Excluded dungeons cleared."] = "Excluded dungeon list cleared. (Showing all)"
SolaFP_L_EN["Currently excluded: %d"] = "|cffFF6666Currently excluded: %d|r"
SolaFP_L_EN["Click: Clear exclusions"] = "|cff66FF99Click|r: Clear exclusions"
SolaFP_L_EN["No dungeons currently excluded."] = "No dungeons currently excluded."
SolaFP_L_EN["Filtered to interested dungeons."] = "Interested dungeon filter enabled."
SolaFP_L_EN["Filtered to interested dungeons (%s)."] = "Interested dungeon filter enabled (%s)."
SolaFP_L_EN["No interested dungeons selected."] = "No interested dungeons selected. Please select interested dungeons from the menu first."
SolaFP_L_EN["Added '%s' to interested dungeons."] = "Added '%s' to interested dungeons."
SolaFP_L_EN["Removed '%s' from interested dungeons."] = "Removed '%s' from interested dungeons."
SolaFP_L_EN["Level-fit dungeons selected (%d)."] = "Selected %d level-fit dungeons."
SolaFP_L_EN["No level-fit dungeons found for your level."] = "No level-fit dungeons found for your level."
SolaFP_L_EN["Filtering Interested Dungeons"] = "Filtering Interested Dungeons"
SolaFP_L_EN["Viewing All Dungeons (Paused)"] = "View All (Interested Filter Paused)"
SolaFP_L_EN["%d dungeons"] = "%d dungeons"
SolaFP_L_EN["Dungeon Level Sorting"] = "Dungeon Level Sorting"
SolaFP_L_EN["Sort dungeon listings in ascending (▲) or descending (▼) level order."] = "Sort dungeon listings in ascending (▲) or descending (▼) level order."
SolaFP_L_EN["Current: Ascending (Low to High)"] = "Current: Ascending (Low to High)"
SolaFP_L_EN["Current: Descending (High to Low)"] = "Current: Descending (High to Low)"
SolaFP_L_EN["Toggle the Blizzard LFGList panel."] = "Toggle the Blizzard LFGList panel."
SolaFP_L_EN["Open or close the default Blizzard LFG window (I key)."] = "Open or close the default Blizzard LFG window (I key)."
SolaFP_L_EN["Click: Toggle filter panel"] = "Click: Toggle filter panel"
SolaFP_L_EN["No dungeons found for your current level."] = "No dungeons found for your current level."
SolaFP_L_EN["Dungeon List Scroll"] = "Dungeon List Scroll"
SolaFP_L_EN["Scroll with mouse wheel or drag slider."] = "Scroll with mouse wheel or drag slider."

-- Row Details & Shortcuts
SolaFP_L_EN["Left-Click: Collapse / Expand"] = "Left-Click: Collapse / Expand"
SolaFP_L_EN["Ctrl + Left-Click: Exclude this dungeon"] = "|cffFF6666[Ctrl + Left-Click]|r: Exclude this dungeon"
SolaFP_L_EN["Status: Interested Dungeon"] = "|cff5ABFBA★ Added to Interested Dungeons|r"
SolaFP_L_EN["Ctrl + Left-Click: Add to interested dungeons"] = "|cff5ABFBA[Ctrl + Left-Click]|r: Add to Interested Dungeons"
SolaFP_L_EN["Ctrl + Left-Click: Remove from interested dungeons"] = "|cffFF6666[Ctrl + Left-Click]|r: Exclude this dungeon"
SolaFP_L_EN["Interested_Add"] = "Add Interest"
SolaFP_L_EN["Interested_Remove"] = "Exclude Interest"
SolaFP_L_EN["Alt+Left-Click: Whisper  ·  Ctrl+Left-Click: Interest  ·  Alt+Right-Click: Chat"] = "|cffD4A745Alt+Left-Click|r: Whisper  |cff8A8580·|r  |cffD4A745Alt+Right-Click|r: Chat  |cff8A8580·|r  |cffFF6666[Ctrl+Left-Click]|r: %s"
SolaFP_L_EN["Shortcut Tip: Ctrl+Click row to toggle interest"] = "|cffFF6666Ctrl+Left-Click|r: Exclude from Interested Dungeons"
SolaFP_L_EN["Shortcut Tip: Ctrl+Click row to exclude"] = "|cffFF6666Ctrl+Left-Click|r: Exclude from Interested Dungeons"
SolaFP_L_EN["Current Zone: %s"] = "Current Zone: %s"
SolaFP_L_EN["Target Activity: %s"] = "Target Activity: %s"
SolaFP_L_EN["Target Role: %s"] = "Target Role: %s"
SolaFP_L_EN["Leader Zone: %s"] = "Leader Zone: %s"
SolaFP_L_EN["Party Members (%d):"] = "Party Members (%d):"
SolaFP_L_EN["Leader: %s%s"] = "Leader: %s%s"
SolaFP_L_EN["Voice Chat: %s"] = "Voice Chat: %s"
SolaFP_L_EN["Alt+Left-Click: Whisper  ·  Ctrl+Left-Click: Exclude  ·  Alt+Right-Click: Chat"] = "Alt+Left-Click: Whisper  ·  Alt+Right-Click: Chat  ·  Ctrl+Left-Click: Interested"
SolaFP_L_EN["Shift+Left-Click: /who  ·  Right-Click: Context Menu"] = "Shift+Left-Click: /who  ·  Right-Click: Context Menu"
SolaFP_L_EN["Send whisper to the party leader.\n(Shortcut: Alt + Click in list or press Enter in input)"] = "Send whisper to the party leader.\n(Shortcut: Alt + Click in list or press Enter in input)"

-- Update Notice Dialog
SolaFP_L_EN["Update Notes"] = "Update Notes"
SolaFP_L_EN["Major Improvements & Feature Updates"] = "Major Improvements & Feature Updates"
SolaFP_L_EN["Confirm & Close"] = "Confirm & Close"
SolaFP_L_EN["UPDATE_NOTICE_P1_TITLE"] = "|cff5ABFBA· Chat [Alt + Left-Click] Party Invite Added|r"
SolaFP_L_EN["UPDATE_NOTICE_P1_DESC"]  = "  You can now [Alt + Left-Click] a player's name in chat to invite them to your party."

-- Minimap & LDB
SolaFP_L_EN["Left-Click"] = "Left-Click"
SolaFP_L_EN["Right-Click"] = "Right-Click"
SolaFP_L_EN["Alt + Click"] = "Alt + Click"
SolaFP_L_EN["Shift + Left-Click"] = "Shift + Left-Click"
SolaFP_L_EN["Toggle Party Finder"] = "Toggle Party Finder"
SolaFP_L_EN["Lock / Unlock Icon"] = "Lock / Unlock Icon"
SolaFP_L_EN["Enable / Disable Addon"] = "Enable / Disable Addon"
SolaFP_L_EN["Active"] = "Active"
SolaFP_L_EN["Inactive"] = "Inactive"
SolaFP_L_EN["Locked"] = "Locked"
SolaFP_L_EN["Movable (Drag)"] = "Movable (Drag)"
SolaFP_L_EN["Addon Status"] = "Addon Status"
SolaFP_L_EN["Icon Position"] = "Icon Position"

-- Key Binding
SolaFP_L_EN["SolaLFG Key Binding"] = "SolaLFG Key Binding"
SolaFP_L_EN["Press a key (or key combination) to bind."] = "Press a key (or key combination) to bind."
SolaFP_L_EN["Waiting for key press..."] = "Waiting for key press..."
SolaFP_L_EN["ESC: Cancel  ·  Right-Click button to unbind"] = "ESC: Cancel  ·  Right-Click button to unbind"
SolaFP_L_EN["Waiting for key"] = "Waiting for key"
SolaFP_L_EN["Key bound to [|cff66FF99%s|r]. (Replaced '%s')"] = "Key bound to [|cff66FF99%s|r]. (Replaced '%s')"
SolaFP_L_EN["Key bound to [|cff66FF99%s|r]."] = "Key bound to [|cff66FF99%s|r]."
SolaFP_L_EN["Key binding cancelled because combat started."] = "Key binding cancelled because combat started."
SolaFP_L_EN["Keybind"] = "Keybind"
SolaFP_L_EN["SolaLFG Toggle Hotkey"] = "SolaLFG Toggle Hotkey"
SolaFP_L_EN["Current Key: |cff66FF99%s|r"] = "Current Key: |cff66FF99%s|r"
SolaFP_L_EN["Saved in WoW Key Bindings to instantly open and close the window."] = "Saved in WoW Key Bindings to instantly open and close the window."
SolaFP_L_EN["Change Keybind"] = "Change Keybind"
SolaFP_L_EN["Unbind"] = "Unbind"
SolaFP_L_EN["No hotkey currently bound."] = "No hotkey currently bound."
SolaFP_L_EN["Click to set a hotkey to quickly open/close SolaLFG."] = "Click to set a hotkey to quickly open/close SolaLFG."
SolaFP_L_EN["Set Keybind"] = "Set Keybind"
SolaFP_L_EN["Cannot change key bindings while in combat."] = "Cannot change key bindings while in combat."
SolaFP_L_EN["Hotkey has been unbound."] = "Hotkey has been unbound."

-- UI Scale & Resize
SolaFP_L_EN["Window Scale (UI Scale)"] = "Window Scale (UI Scale)"
SolaFP_L_EN["Drag the slider to adjust SolaLFG scale (50% ~ 200%)."] = "Drag the slider to adjust SolaLFG scale (50% ~ 200%)."
SolaFP_L_EN["Drag: Resize window | Mouse wheel: Scroll list"] = "Drag: Resize window | Mouse wheel: Scroll list"

-- Whisper Presets & Auto Msg
SolaFP_L_EN["Whisper Msg: "] = "Whisper Msg: "
SolaFP_L_EN["Whisper Message Presets (Click to open)"] = "Whisper Message Presets (Click to open)"
SolaFP_L_EN["Select or delete saved whisper messages.\nSupports [Auto] Level + Class option."] = "Select or delete saved whisper messages.\nSupports [Auto] Level + Class option."
SolaFP_L_EN["Add Whisper Preset"] = "Add Whisper Preset"
SolaFP_L_EN["Saves current input text to the preset list.\n(Up to 5 messages)"] = "Saves current input text to the preset list.\n(Up to 5 messages)"
SolaFP_L_EN["Whisper Message Presets"] = "Whisper Message Presets"
SolaFP_L_EN["Up to 5 saved"] = "Up to 5 saved"
SolaFP_L_EN["Auto"] = "Auto"
SolaFP_L_EN["Selected"] = "Selected"
SolaFP_L_EN["Selected auto level/class message: %s"] = "Selected auto level/class message: %s"
SolaFP_L_EN["Current Level + Class + Inv please"] = "Current Level + Class + Inv please"
SolaFP_L_EN["Automatically updates your level whenever SolaLFG opens."] = "Automatically updates your level whenever SolaLFG opens."
SolaFP_L_EN["Whisper message selected: %s"] = "Whisper message selected: %s"
SolaFP_L_EN["Delete Message"] = "Delete Message"
SolaFP_L_EN["Remove this message from the list."] = "Remove this message from the list."
SolaFP_L_EN["Saved message deleted: %s"] = "Saved message deleted: %s"
SolaFP_L_EN["No saved messages - Register using [Add]"] = "No saved messages - Register using [Add]"
SolaFP_L_EN["Please enter a message to save first."] = "Please enter a message to save first."
SolaFP_L_EN["This message is already saved."] = "This message is already saved."
SolaFP_L_EN["You can save up to 5 preset messages."] = "You can save up to 5 preset messages."
SolaFP_L_EN["Whisper message saved: |cffD4A745%s|r"] = "Whisper message saved: |cffD4A745%s|r"

-- Options Menu
SolaFP_L_EN["Window Scale"] = "Window Scale"
SolaFP_L_EN["Window Color"] = "Window Color"
SolaFP_L_EN["Minimap Icon"] = "Minimap Icon"
SolaFP_L_EN["Close with ESC"] = "Close with ESC"
SolaFP_L_EN["Reset"] = "Reset"
SolaFP_L_EN["Reset Window Position"] = "Reset Window Position"
SolaFP_L_EN["Reset Window Size"] = "Reset Window Size"
SolaFP_L_EN["Reset All Settings"] = "Reset All Settings"
SolaFP_L_EN["View Update Notes"] = "View Update Notes"
SolaFP_L_EN["LFG_ONLY_ON_MSG"] = "Standalone LFG mode activated. (Chat scan stopped)"
SolaFP_L_EN["LFG_ONLY_OFF_MSG"] = "Integrated mode activated. (Chat scan resumed)"

-- Function to apply locale dictionary to SolaFP_L
function SolaFP_ApplyLocale(locale)
	locale = locale or SolaFP_GetLocale()
	if locale == "koKR" and SolaFP_L_KR then
		for k, v in pairs(SolaFP_L_KR) do
			SolaFP_L[k] = v
		end
		if SolaFP_ApplyKoreanLegacyGlobals then SolaFP_ApplyKoreanLegacyGlobals() end
	else
		for k, v in pairs(SolaFP_L_EN) do
			SolaFP_L[k] = v
		end
		if SolaFP_ApplyEnglishLegacyGlobals then SolaFP_ApplyEnglishLegacyGlobals() end
	end
end

function SolaFP_ApplyEnglishLegacyGlobals()
	SolaFP_C_TITLE = "SolaLFG "..SolaFP_GetVersionString()
	SolaFP_DEFAULT_PARTY_CHANNEL = "LookingForGroup"
	SolaFP_DEFAULT_WHISPER = "Inv please (%s %s)"
	SolaFP_TEXT_AUTO_WHISPER_FORMAT = "Inv please (Lv.%d %s)"
	SolaFP_TEXT_AUTO_WHISPER_LABEL = "Current Level + Class + Inv please"
	SolaFP_TEXT_STOPPED = "(Stopped)"
	SolaFP_TEXT_EXCEPTION = "Exclude"
	SolaFP_TEXT_EXCEPTION_DELETE = "Clear Excluded"
	SolaFP_TEXT_WHISPER = "Open Whisper"
	SolaFP_TEXT_WHO = "Who (/who)"
	SolaFP_TEXT_HELP = "Help"
	SolaFP_TEXT_APPLY = "Apply"
	SolaFP_TEXT_START_AD = "Start LFM"
	SolaFP_TEXT_STOP_AD = "Stop LFM"
	SolaFP_TEXT_APPLY_FILTER = "Apply"
	SolaFP_TEXT_IGNORE = "Confirm"
	SolaFP_TEXT_WH_LABEL = "Whisper Msg: "
	SolaFP_TEXT_AD_LABEL = "LFM Msg: "
	SolaFP_TEXT_FILTER_LABEL = "Filter Msg: "
	SolaFP_TEXT_IGNORE_LABEL = "Ignore Msg: "
	SolaFP_TEXT_CLOSE = "Close"
	SolaFP_TEXT_LIST_LABEL = "LFM Messages"
	SolaFP_OPTION = "Settings"
	SolaFP_TEXT_DUNGEON_LABEL = "Dungeon / Raid"
	SolaFP_TEXT_SHOUTER_LABEL = "Name"
	SolaFP_TEXT_MSG_LABEL = "Message"
	SolaFP_TEXT_TIME_LABEL = "Time"
	SolaFP_BTN_WHISPER = "Whisper"
	SolaFP_BTN_WHO = "Who"
	SolaFP_BTN_RESET = "Reset"
	SolaFP_LABEL_FILTER = "Filter:"
	SolaFP_LABEL_IGNORE = "Exclude:"
	SolaFP_LABEL_WH = "Whisper:"
	SolaFP_LABEL_AD = "LFM:"
	SolaFP_TEXT_ADD = "Add"
	SolaFP_TEXT_WH_PRESET_TITLE = "Whisper Presets"
	SolaFP_TEXT_WH_FULL = "You can save up to 5 preset messages."
	SolaFP_TEXT_WH_EXISTS = "This message is already saved."
	SolaFP_TEXT_WH_EMPTY = "Please enter a message to save first."
	SolaFP_TEXT_WH_SAVED = "Whisper message saved: %s"
	SolaFP_TEXT_WH_DELETED = "Saved message deleted."

	-- Dungeon Filter Text
	SolaFP_DUNGEONFILTER_RESETALL = "Clear Selected Dungeons"
	SolaFP_DUNGEONFILTER_SINGLE = "Dungeon: %s"
	SolaFP_DUNGEONFILTER_MULTI = "Dungeons: %d selected"
	SolaFP_DUNGEONFILTER_NOT_FILTERED = "View All"
	SolaFP_DUNGEONFILTER_NONE = "None"

	-- Tooltip & System Messages
	SolaFP_TOOLTIP_CLOSE = "Close Window"
	SolaFP_TOOLTIP_MAXMIZE = "Maximize Window"
	SolaFP_TOOLTIP_MINIMIZE = "Minimize Window"
	SolaFP_TOOLTIP_DECREASE = "Decrease Rows"
	SolaFP_TOOLTIP_INCREASE = "Increase Rows"
	SolaFP_TOOLTIP_OPTION = "Options"
	SolaFP_TOOLTIP_SORT_TIME = "Sort by Time"
	SolaFP_TOOLTIP_ACTIVATE_ON = "Running\nClick to pause"
	SolaFP_TOOLTIP_ACTIVATE_OFF = "Paused\nClick to resume"
	SolaFP_TOOLTIP_POPUP_ON = "Alerts Active\nClick to mute"
	SolaFP_TOOLTIP_POPUP_OFF = "Alerts Muted"
	SolaFP_TOOLTIP_AD_ON = "LFM Advertising\nClick to stop"
	SolaFP_TOOLTIP_AD_OFF = "Click to start LFM advertising"
	SolaFP_TOOLTIP_DUNGEON_FILTER = "|cff6BBF8ALeft-Click|r: Open dungeon menu\n|cffE0C068Wheel-Click|r: Toggle View All / Interested Dungeons\n|cffCF6679Right-Click|r: Reset dungeon filter (Clear)\n\n- Interested Dungeons -\n"
	SolaFP_TOOLTIP_CLASS_FILTER = "Left-Click: Select my class\nRight-Click: Select target classes\nSelected: "
	SolaFP_TOOLTIP_SHORTCUT_ALT = "Shortcut: Alt + Click"
	SolaFP_TOOLTIP_SHORTCUT_ALT_RIGHT = "Shortcut: Alt + Right-Click"
	SolaFP_TOOLTIP_SHORTCUT_CTRL = "Shortcut: Ctrl + Click"
	SolaFP_TOOLTIP_SHORTCUT_SHIFT = "Shortcut: Shift + Click"
	SolaFP_TOOLTIP_IGNORE = "Enter keywords to ignore separated by comma, then press Enter or click button"
	SolaFP_TOOLTIP_DISABLED = "Disabled"

	SolaFP_MESSAGE_POPUP_ACTIVE = "Alerts enabled when listings update."
	SolaFP_MESSAGE_POPUP_DEACTIVE = "Alerts disabled."
	SolaFP_MESSAGE_DUNGEON_RESET = "All dungeon filters cleared."
	SolaFP_MESSAGE_START_AD = "LFM advertising started."
	SolaFP_MESSAGE_STOP_AD = "LFM advertising stopped."
	SolaFP_MESSAGE_NO_AD_TEXT = "Please enter an LFM message first."
	SolaFP_MESSAGE_DISABLE_ANNOUNCE = "MessageQueue addon is not installed.\nInstall MessageQueue from CurseForge to enable auto LFM advertising."
	SolaFP_MESSAGE_EXCEPTION = "Excluded listings from %s."
	SolaFP_MESSAGE_CLEAR_EXCEPTION = "Excluded list reset. All listings will be displayed."
	SolaFP_MESSAGE_START_DUNGEON_FILTER = "Showing selected dungeons only."
	SolaFP_MESSAGE_STOP_DUNGEON_FILTER = "Showing all dungeons."
	SolaFP_MESSAGE_APPLY_CUSTOM_FILTER = "Custom filter keywords applied."
	SolaFP_MESSAGE_CUSTOM_IGNORE = "Listings containing excluded keywords will be hidden."
	SolaFP_MESSAGE_CUSTOM_IGNORE_RESET = "Excluded keywords cleared. All listings will be displayed."
	SolaFP_MESSAGE_APPLY_CUSTOM_IGNORE = "Excluded keyword applied: |cffCF6679%s|r"
	SolaFP_MESSAGE_IGNORE_EMPTY = "Please enter keywords to exclude. (comma separated)"
	SolaFP_MESSAGE_IGNORE_ALL_RESET = "Excluded list reset. All messages will be displayed."
	SolaFP_BADGE_DETECT_ON = "|cff6BBF8AScan ON|r"
	SolaFP_BADGE_DETECT_OFF = "|cffCF6679Scan OFF|r"
	SolaFP_BADGE_SOUND_ON = "|cffE09050Alert ON|r"
	SolaFP_BADGE_SOUND_OFF = "|cff8A8580Alert OFF|r"
	SolaFP_BADGE_AD_ON = "|cff6BBF8ALFM ON|r"
	SolaFP_BADGE_AD_OFF = "|cff8A8580LFM OFF|r"
	SolaFP_OPTIONS_CHANNEL = "Select LFG Channel"
	SolaFP_OPTIONS_INTERVAL = "LFM Interval"
	SolaFP_OPTIONS_VALID = "Message Duration"
	SolaFP_OPTIONS_FONTSIZE = "Font Size"
	SolaFP_OPTIONS_SCALE = "Window Scale"
	SolaFP_OPTIONS_COLOR = "Window Color"
	SolaFP_OPTIONS_ICON = "Minimap Icon"
	SolaFP_OPTIONS_ESC = "Close with ESC"
	SolaFP_OPTIONS_RIGHTBUTTON = "Ctrl+Right-Click to Apply"
	SolaFP_OPTIONS_LFG_ONLY = "Standalone LFG Mode"
	SolaFP_OPTIONS_NORAID = "Disable while in Raid"
	SolaFP_OPTIONS_NOPVP = "Disable while in Battleground"
	SolaFP_OPTIONS_RESET = "Reset Options"
	SolaFP_OPTIONS_RESETPOS = "Window Position"
	SolaFP_OPTIONS_RESETSIZE = "Window Size"
	SolaFP_OPTIONS_RESETALL = "Reset All Settings"
	SolaFP_TEXT_RESIZE_TIP = "Drag: Resize window | Mouse wheel: Scroll list"
	SolaFP_MESSAGE_LFG_ONLY_ON = "Standalone LFG mode activated. (Chat scan stopped)"
	SolaFP_MESSAGE_LFG_ONLY_OFF = "Integrated mode activated. (Chat scan resumed)"
	SolaFP_MESSAGE_NEWVERSION_RESET = "New version detected. Settings have been reset."
	SolaFP_MESSAGE_RESETALL = "Default settings loaded."
	SolaFP_MESSAGE_NOTARGET = "Please select a target from the list first."
	SolaFP_MESSAGE_ICON_LOCK = "Minimap icon locked."
	SolaFP_MESSAGE_ICON_UNLOCK = "Minimap icon can now be moved."
	SolaFP_MESSAGE_ACTIVE = "%s - SolaLFG activated."
	SolaFP_MESSAGE_DEACTIVE = "%s - SolaLFG deactivated."

	BINDING_HEADER_SOLALFG = "SolaLFG"
	BINDING_NAME_SolaFP_TOGGLE = "Toggle SolaLFG Window"
end

-- Initialize English by default
SolaFP_ApplyLocale("enUS")