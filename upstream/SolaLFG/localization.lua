-- =========================================================================
-- SolaLFG - English (Base / Fallback) Localization
-- =========================================================================

-- Active Locale Override
-- "koKR" for Korean, "enUS" for English, or nil to auto-detect via GetLocale()
FP_ACTIVE_LOCALE = nil

function FP_GetLocale()
	if FP_ACTIVE_LOCALE then return FP_ACTIVE_LOCALE end
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

function FP_GetVersionString()
	local ver = (C_AddOns and C_AddOns.GetAddOnMetadata and (C_AddOns.GetAddOnMetadata("SolaLFG", "version") or C_AddOns.GetAddOnMetadata("FindParty", "version")))
		or (GetAddOnMetadata and (GetAddOnMetadata("SolaLFG", "version") or GetAddOnMetadata("FindParty", "version")))
		or "1.39"
	return ver
end

function FP_GetPlayerClassName()
	local locCls, clsToken = UnitClass("player")
	if ((FP_GetLocale and FP_GetLocale() or GetLocale()) ~= "koKR") then
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
FP_L = FP_L or {}
setmetatable(FP_L, {
	__index = function(t, k)
		return k
	end,
})

FP_L_EN = {}

-- Common UI & Panel
FP_L_EN["LFG"] = "LFG"
FP_L_EN["Close"] = "Close"
FP_L_EN["Settings"] = "Settings"
FP_L_EN["Refresh"] = "Refresh"
FP_L_EN["Apply"] = "Apply"
FP_L_EN["Apply via Whisper"] = "Apply via Whisper"
FP_L_EN["Send Whisper"] = "Send Whisper"
FP_L_EN["Open Chat (/w)"] = "Open Chat (/w)"
FP_L_EN["Invite"] = "Invite"
FP_L_EN["Who (/who)"] = "Who (/who)"
FP_L_EN["List Group"] = "List Group"
FP_L_EN["Blizzard Group Finder"] = "Blizzard Group Finder"
FP_L_EN["Dungeon Filter"] = "Dungeon Filter"
FP_L_EN["Detailed Filters"] = "Detailed Filters"
FP_L_EN["Reset All Filters"] = "Reset All Filters"
FP_L_EN["All"] = "All"
FP_L_EN["Select All"] = "Select All"
FP_L_EN["Clear"] = "Clear"
FP_L_EN["Clear All"] = "Clear All"
FP_L_EN["Add"] = "Add"
FP_L_EN["Level"] = "Level"
FP_L_EN["Level ▲"] = "Level ▲"
FP_L_EN["Level ▼"] = "Level ▼"
FP_L_EN["Dungeons"] = "Dungeons"
FP_L_EN["Dungeons ▼"] = "Dungeons ▼"
FP_L_EN["ROW_COUNT_FORMAT"] = "(%d groups) (%d players)"
FP_L_EN["Filters ▶"] = "Filters ▶"
FP_L_EN["Filters %s"] = "Filters %s"
FP_L_EN["Filters(%d) %s"] = "Filters(%d) %s"
FP_L_EN["Active filters: %d"] = "Active filters: %d"
FP_L_EN["%d listings found"] = "%d listings found"
FP_L_EN["Groups: %d  ·  Seekers: %d"] = "Groups: %d  ·  Players: %d"
FP_L_EN["Formed Groups  ·  %d"] = "Formed Groups  ·  %d"
FP_L_EN["Individual Seekers"] = "Players LFG"
FP_L_EN["Individual Seekers  ·  %d"] = "Players LFG  ·  %d"
FP_L_EN["No listings found."] = "No listings found."
FP_L_EN["Searching..."] = "Searching..."
FP_L_EN["Initializing LFG (C_LFGList)..."] = "Initializing LFG (C_LFGList)..."
FP_L_EN["Search timed out. Please click [Refresh]."] = "Search timed out. Please click [Refresh]."
FP_L_EN["Search request failed. (Please try again shortly)"] = "Search request failed. (Please try again shortly)"
FP_L_EN["Waiting to refresh... (%ds cooldown)"] = "Waiting to refresh... (%ds cooldown)"
FP_L_EN["Last refreshed: %d sec ago"] = "Last refreshed: %d sec ago"
FP_L_EN["Last refreshed: Never"] = "Last refreshed: Never"
FP_L_EN["Cannot send a whisper to yourself."] = "Cannot send a whisper to yourself."
FP_L_EN["Please select a listing first."] = "Please select a listing first."
FP_L_EN["LFG filters have been reset."] = "LFG filters have been reset."
FP_L_EN["All dungeon filters enabled."] = "All dungeon filters enabled."
FP_L_EN["Page: %d / %d (%d-%d of %d)"] = "Page: %d / %d (%d-%d of %d)"
FP_L_EN["(Currently Active)"] = "(Currently Active)"
FP_L_EN["[Exclude]"] = "[Exclude]"
FP_L_EN["Anonymous"] = "Anonymous"
FP_L_EN["Unnamed"] = "Unnamed"
FP_L_EN["Unknown"] = "Unknown"
FP_L_EN["Unknown Class"] = "Unknown Class"
FP_L_EN["Unspecified Activity"] = "Unspecified Activity"
FP_L_EN["Other Dungeon #%s"] = "Other Dungeon #%s"
FP_L_EN["Hello, inquiring about your LFG listing."] = "Hello, inquiring about your LFG listing."

-- Roles
FP_L_EN["Tank"] = "Tank"
FP_L_EN["Healer"] = "Healer"
FP_L_EN["Damage"] = "Damage"
FP_L_EN["DPS"] = "DPS"
FP_L_EN["Role_Tank_Short"] = "Tank"
FP_L_EN["Role_Healer_Short"] = "Heal"
FP_L_EN["Role_DPS_Short"] = "DPS"
FP_L_EN["Open Roles"] = "Open Roles"
FP_L_EN["Open Tank Slot"] = "Open Tank Slot"
FP_L_EN["Open Healer Slot"] = "Open Healer Slot"
FP_L_EN["Open DPS Slot"] = "Open DPS Slot"
FP_L_EN["Formed Roles"] = "Group Composition"
FP_L_EN["Has Tank"] = "Has Tank"
FP_L_EN["Has Healer"] = "Has Healer"
FP_L_EN["Groups with Tank"] = "Groups with Tank"
FP_L_EN["Groups with Healer"] = "Groups with Healer"
FP_L_EN["Tank Seekers"] = "Tank Players"
FP_L_EN["Healer Seekers"] = "Healer Players"
FP_L_EN["DPS Seekers"] = "DPS Players"

-- Classes
FP_L_EN["Warrior"] = "Warrior"
FP_L_EN["Paladin"] = "Paladin"
FP_L_EN["Hunter"] = "Hunter"
FP_L_EN["Rogue"] = "Rogue"
FP_L_EN["Priest"] = "Priest"
FP_L_EN["Shaman"] = "Shaman"
FP_L_EN["Mage"] = "Mage"
FP_L_EN["Warlock"] = "Warlock"
FP_L_EN["Druid"] = "Druid"

-- Filters & Chips Tooltips
FP_L_EN["Configure role vacancies, seeker roles, levels, and classes."] = "Configure open roles, player roles, levels, and classes."
FP_L_EN["Show groups with an open tank slot."] = "Show groups with an open tank slot."
FP_L_EN["Show groups with an open healer slot."] = "Show groups with an open healer slot."
FP_L_EN["Show groups with an open DPS slot."] = "Show groups with an open DPS slot."
FP_L_EN["Show groups that already have 1 or more tanks."] = "Show groups that already have 1 or more tanks."
FP_L_EN["Show groups that already have 1 or more healers."] = "Show groups that already have 1 or more healers."
FP_L_EN["Show individual players listed as Tank."] = "Show players listed as Tank."
FP_L_EN["Show individual players listed as Healer."] = "Show players listed as Healer."
FP_L_EN["Show individual players listed as DPS."] = "Show players listed as DPS."
FP_L_EN["Hide Groups with Excluded Classes"] = "Hide Groups with Excluded Classes"
FP_L_EN["Hide formed groups that contain unselected classes."] = "Hide formed groups that contain unselected classes."
FP_L_EN["Seeker Level Filter"] = "Level Filter"
FP_L_EN["Seeker Class Filter"] = "Class Filter"
FP_L_EN["%s Class Filter"] = "%s Class Filter"
FP_L_EN["Toggle listings for %s individual seekers."] = "Toggle listings for %s players."
FP_L_EN["Filter: All Levels"] = "Filter: All Levels"
FP_L_EN["Filter: Level-appropriate"] = "Filter: Level-appropriate"
FP_L_EN["Show all dungeon listings regardless of level."] = "Show all dungeon listings regardless of level."
FP_L_EN["Show dungeons appropriate for your current level."] = "Show dungeons appropriate for your current level."
FP_L_EN["Click: Switch to All Levels mode"] = "Click: Switch to All Levels mode"
FP_L_EN["Click: Switch to Level mode"] = "Click: Switch to Level mode"
FP_L_EN["Filter by specific dungeons."] = "Filter by specific dungeons to show interested only."
FP_L_EN["Left-Click: Toggle dungeon filter menu"] = "Left-Click: Toggle dungeon filter menu"
FP_L_EN["Wheel-Click: Toggle View All / Filtered"] = "Wheel-Click: Toggle View All / Interested Dungeons"
FP_L_EN["Right-Click: Clear selected dungeons"] = "Right-Click: Clear selected dungeons (View All)"
FP_L_EN["Reset Selection"] = "Clear Selected"
FP_L_EN["Select Fit"] = "Select Fit"
FP_L_EN["Level-fit Dungeons"] = "Select Level-Fit"
FP_L_EN["Showing all dungeons."] = "Showing all dungeons. (View All)"
FP_L_EN["All dungeon filters cleared."] = "All dungeon filters cleared."
FP_L_EN["Clear Excluded"] = "Reset"
FP_L_EN["Clear Exclusions"] = "Clear Exclusions"
FP_L_EN["Restore all dungeons excluded from the list via Ctrl+Left-Click."] = "Restore all dungeons excluded from the list via Ctrl+Left-Click."
FP_L_EN["Excluded dungeons cleared."] = "Excluded dungeon list cleared. (Showing all)"
FP_L_EN["Currently excluded: %d"] = "|cffFF6666Currently excluded: %d|r"
FP_L_EN["Click: Clear exclusions"] = "|cff66FF99Click|r: Clear exclusions"
FP_L_EN["No dungeons currently excluded."] = "No dungeons currently excluded."
FP_L_EN["Filtered to interested dungeons."] = "Interested dungeon filter enabled."
FP_L_EN["Filtered to interested dungeons (%s)."] = "Interested dungeon filter enabled (%s)."
FP_L_EN["No interested dungeons selected."] = "No interested dungeons selected. Please select interested dungeons from the menu first."
FP_L_EN["Added '%s' to interested dungeons."] = "Added '%s' to interested dungeons."
FP_L_EN["Removed '%s' from interested dungeons."] = "Removed '%s' from interested dungeons."
FP_L_EN["Level-fit dungeons selected (%d)."] = "Selected %d level-fit dungeons."
FP_L_EN["No level-fit dungeons found for your level."] = "No level-fit dungeons found for your level."
FP_L_EN["Filtering Interested Dungeons"] = "Filtering Interested Dungeons"
FP_L_EN["Viewing All Dungeons (Paused)"] = "View All (Interested Filter Paused)"
FP_L_EN["%d dungeons"] = "%d dungeons"
FP_L_EN["Dungeon Level Sorting"] = "Dungeon Level Sorting"
FP_L_EN["Sort dungeon listings in ascending (▲) or descending (▼) level order."] = "Sort dungeon listings in ascending (▲) or descending (▼) level order."
FP_L_EN["Current: Ascending (Low to High)"] = "Current: Ascending (Low to High)"
FP_L_EN["Current: Descending (High to Low)"] = "Current: Descending (High to Low)"
FP_L_EN["Toggle the Blizzard LFGList panel."] = "Toggle the Blizzard LFGList panel."
FP_L_EN["Open or close the default Blizzard LFG window (I key)."] = "Open or close the default Blizzard LFG window (I key)."
FP_L_EN["Click: Toggle filter panel"] = "Click: Toggle filter panel"
FP_L_EN["No dungeons found for your current level."] = "No dungeons found for your current level."
FP_L_EN["Dungeon List Scroll"] = "Dungeon List Scroll"
FP_L_EN["Scroll with mouse wheel or drag slider."] = "Scroll with mouse wheel or drag slider."

-- Row Details & Shortcuts
FP_L_EN["Left-Click: Collapse / Expand"] = "Left-Click: Collapse / Expand"
FP_L_EN["Ctrl + Left-Click: Exclude this dungeon"] = "|cffFF6666[Ctrl + Left-Click]|r: Exclude this dungeon"
FP_L_EN["Status: Interested Dungeon"] = "|cff5ABFBA★ Added to Interested Dungeons|r"
FP_L_EN["Ctrl + Left-Click: Add to interested dungeons"] = "|cff5ABFBA[Ctrl + Left-Click]|r: Add to Interested Dungeons"
FP_L_EN["Ctrl + Left-Click: Remove from interested dungeons"] = "|cffFF6666[Ctrl + Left-Click]|r: Exclude this dungeon"
FP_L_EN["Interested_Add"] = "Add Interest"
FP_L_EN["Interested_Remove"] = "Exclude Interest"
FP_L_EN["Alt+Left-Click: Whisper  ·  Ctrl+Left-Click: Interest  ·  Alt+Right-Click: Chat"] = "|cffD4A745Alt+Left-Click|r: Whisper  |cff8A8580·|r  |cffD4A745Alt+Right-Click|r: Chat  |cff8A8580·|r  |cffFF6666[Ctrl+Left-Click]|r: %s"
FP_L_EN["Shortcut Tip: Ctrl+Click row to toggle interest"] = "|cffFF6666Ctrl+Left-Click|r: Exclude from Interested Dungeons"
FP_L_EN["Shortcut Tip: Ctrl+Click row to exclude"] = "|cffFF6666Ctrl+Left-Click|r: Exclude from Interested Dungeons"
FP_L_EN["Current Zone: %s"] = "Current Zone: %s"
FP_L_EN["Target Activity: %s"] = "Target Activity: %s"
FP_L_EN["Target Role: %s"] = "Target Role: %s"
FP_L_EN["Leader Zone: %s"] = "Leader Zone: %s"
FP_L_EN["Party Members (%d):"] = "Party Members (%d):"
FP_L_EN["Leader: %s%s"] = "Leader: %s%s"
FP_L_EN["Voice Chat: %s"] = "Voice Chat: %s"
FP_L_EN["Alt+Left-Click: Whisper  ·  Ctrl+Left-Click: Exclude  ·  Alt+Right-Click: Chat"] = "Alt+Left-Click: Whisper  ·  Alt+Right-Click: Chat  ·  Ctrl+Left-Click: Interested"
FP_L_EN["Shift+Left-Click: /who  ·  Right-Click: Context Menu"] = "Shift+Left-Click: /who  ·  Right-Click: Context Menu"
FP_L_EN["Send whisper to the party leader.\n(Shortcut: Alt + Click in list or press Enter in input)"] = "Send whisper to the party leader.\n(Shortcut: Alt + Click in list or press Enter in input)"

-- Update Notice Dialog
FP_L_EN["Update Notes"] = "Update Notes"
FP_L_EN["Major Improvements & Feature Updates"] = "Major Improvements & Feature Updates"
FP_L_EN["Confirm & Close"] = "Confirm & Close"
FP_L_EN["UPDATE_NOTICE_P1_TITLE"] = "|cff5ABFBA· Chat [Alt + Left-Click] Party Invite Added|r"
FP_L_EN["UPDATE_NOTICE_P1_DESC"]  = "  You can now [Alt + Left-Click] a player's name in chat to invite them to your party."

-- Minimap & LDB
FP_L_EN["Left-Click"] = "Left-Click"
FP_L_EN["Right-Click"] = "Right-Click"
FP_L_EN["Alt + Click"] = "Alt + Click"
FP_L_EN["Shift + Left-Click"] = "Shift + Left-Click"
FP_L_EN["Toggle Party Finder"] = "Toggle Party Finder"
FP_L_EN["Lock / Unlock Icon"] = "Lock / Unlock Icon"
FP_L_EN["Enable / Disable Addon"] = "Enable / Disable Addon"
FP_L_EN["Active"] = "Active"
FP_L_EN["Inactive"] = "Inactive"
FP_L_EN["Locked"] = "Locked"
FP_L_EN["Movable (Drag)"] = "Movable (Drag)"
FP_L_EN["Addon Status"] = "Addon Status"
FP_L_EN["Icon Position"] = "Icon Position"

-- Key Binding
FP_L_EN["SolaLFG Key Binding"] = "SolaLFG Key Binding"
FP_L_EN["Press a key (or key combination) to bind."] = "Press a key (or key combination) to bind."
FP_L_EN["Waiting for key press..."] = "Waiting for key press..."
FP_L_EN["ESC: Cancel  ·  Right-Click button to unbind"] = "ESC: Cancel  ·  Right-Click button to unbind"
FP_L_EN["Waiting for key"] = "Waiting for key"
FP_L_EN["Key bound to [|cff66FF99%s|r]. (Replaced '%s')"] = "Key bound to [|cff66FF99%s|r]. (Replaced '%s')"
FP_L_EN["Key bound to [|cff66FF99%s|r]."] = "Key bound to [|cff66FF99%s|r]."
FP_L_EN["Key binding cancelled because combat started."] = "Key binding cancelled because combat started."
FP_L_EN["Keybind"] = "Keybind"
FP_L_EN["SolaLFG Toggle Hotkey"] = "SolaLFG Toggle Hotkey"
FP_L_EN["Current Key: |cff66FF99%s|r"] = "Current Key: |cff66FF99%s|r"
FP_L_EN["Saved in WoW Key Bindings to instantly open and close the window."] = "Saved in WoW Key Bindings to instantly open and close the window."
FP_L_EN["Change Keybind"] = "Change Keybind"
FP_L_EN["Unbind"] = "Unbind"
FP_L_EN["No hotkey currently bound."] = "No hotkey currently bound."
FP_L_EN["Click to set a hotkey to quickly open/close SolaLFG."] = "Click to set a hotkey to quickly open/close SolaLFG."
FP_L_EN["Set Keybind"] = "Set Keybind"
FP_L_EN["Cannot change key bindings while in combat."] = "Cannot change key bindings while in combat."
FP_L_EN["Hotkey has been unbound."] = "Hotkey has been unbound."

-- UI Scale & Resize
FP_L_EN["Window Scale (UI Scale)"] = "Window Scale (UI Scale)"
FP_L_EN["Drag the slider to adjust SolaLFG scale (50% ~ 200%)."] = "Drag the slider to adjust SolaLFG scale (50% ~ 200%)."
FP_L_EN["Drag: Resize window | Mouse wheel: Scroll list"] = "Drag: Resize window | Mouse wheel: Scroll list"

-- Whisper Presets & Auto Msg
FP_L_EN["Whisper Msg: "] = "Whisper Msg: "
FP_L_EN["Whisper Message Presets (Click to open)"] = "Whisper Message Presets (Click to open)"
FP_L_EN["Select or delete saved whisper messages.\nSupports [Auto] Level + Class option."] = "Select or delete saved whisper messages.\nSupports [Auto] Level + Class option."
FP_L_EN["Add Whisper Preset"] = "Add Whisper Preset"
FP_L_EN["Saves current input text to the preset list.\n(Up to 5 messages)"] = "Saves current input text to the preset list.\n(Up to 5 messages)"
FP_L_EN["Whisper Message Presets"] = "Whisper Message Presets"
FP_L_EN["Up to 5 saved"] = "Up to 5 saved"
FP_L_EN["Auto"] = "Auto"
FP_L_EN["Selected"] = "Selected"
FP_L_EN["Selected auto level/class message: %s"] = "Selected auto level/class message: %s"
FP_L_EN["Current Level + Class + Inv please"] = "Current Level + Class + Inv please"
FP_L_EN["Automatically updates your level whenever SolaLFG opens."] = "Automatically updates your level whenever SolaLFG opens."
FP_L_EN["Whisper message selected: %s"] = "Whisper message selected: %s"
FP_L_EN["Delete Message"] = "Delete Message"
FP_L_EN["Remove this message from the list."] = "Remove this message from the list."
FP_L_EN["Saved message deleted: %s"] = "Saved message deleted: %s"
FP_L_EN["No saved messages - Register using [Add]"] = "No saved messages - Register using [Add]"
FP_L_EN["Please enter a message to save first."] = "Please enter a message to save first."
FP_L_EN["This message is already saved."] = "This message is already saved."
FP_L_EN["You can save up to 5 preset messages."] = "You can save up to 5 preset messages."
FP_L_EN["Whisper message saved: |cffD4A745%s|r"] = "Whisper message saved: |cffD4A745%s|r"

-- Options Menu
FP_L_EN["Window Scale"] = "Window Scale"
FP_L_EN["Window Color"] = "Window Color"
FP_L_EN["Minimap Icon"] = "Minimap Icon"
FP_L_EN["Close with ESC"] = "Close with ESC"
FP_L_EN["Reset"] = "Reset"
FP_L_EN["Reset Window Position"] = "Reset Window Position"
FP_L_EN["Reset Window Size"] = "Reset Window Size"
FP_L_EN["Reset All Settings"] = "Reset All Settings"
FP_L_EN["View Update Notes"] = "View Update Notes"
FP_L_EN["LFG_ONLY_ON_MSG"] = "Standalone LFG mode activated. (Chat scan stopped)"
FP_L_EN["LFG_ONLY_OFF_MSG"] = "Integrated mode activated. (Chat scan resumed)"

-- Function to apply locale dictionary to FP_L
function FP_ApplyLocale(locale)
	locale = locale or FP_GetLocale()
	if locale == "koKR" and FP_L_KR then
		for k, v in pairs(FP_L_KR) do
			FP_L[k] = v
		end
		if FP_ApplyKoreanLegacyGlobals then FP_ApplyKoreanLegacyGlobals() end
	else
		for k, v in pairs(FP_L_EN) do
			FP_L[k] = v
		end
		if FP_ApplyEnglishLegacyGlobals then FP_ApplyEnglishLegacyGlobals() end
	end
end

function FP_ApplyEnglishLegacyGlobals()
	FP_C_TITLE = "SolaLFG "..FP_GetVersionString()
	FP_DEFAULT_PARTY_CHANNEL = "LookingForGroup"
	FP_DEFAULT_WHISPER = "Inv please (%s %s)"
	FP_TEXT_AUTO_WHISPER_FORMAT = "Inv please (Lv.%d %s)"
	FP_TEXT_AUTO_WHISPER_LABEL = "Current Level + Class + Inv please"
	FP_TEXT_STOPPED = "(Stopped)"
	FP_TEXT_EXCEPTION = "Exclude"
	FP_TEXT_EXCEPTION_DELETE = "Clear Excluded"
	FP_TEXT_WHISPER = "Open Whisper"
	FP_TEXT_WHO = "Who (/who)"
	FP_TEXT_HELP = "Help"
	FP_TEXT_APPLY = "Apply"
	FP_TEXT_START_AD = "Start LFM"
	FP_TEXT_STOP_AD = "Stop LFM"
	FP_TEXT_APPLY_FILTER = "Apply"
	FP_TEXT_IGNORE = "Confirm"
	FP_TEXT_WH_LABEL = "Whisper Msg: "
	FP_TEXT_AD_LABEL = "LFM Msg: "
	FP_TEXT_FILTER_LABEL = "Filter Msg: "
	FP_TEXT_IGNORE_LABEL = "Ignore Msg: "
	FP_TEXT_CLOSE = "Close"
	FP_TEXT_LIST_LABEL = "LFM Messages"
	FP_OPTION = "Settings"
	FP_TEXT_DUNGEON_LABEL = "Dungeon / Raid"
	FP_TEXT_SHOUTER_LABEL = "Name"
	FP_TEXT_MSG_LABEL = "Message"
	FP_TEXT_TIME_LABEL = "Time"
	FP_BTN_WHISPER = "Whisper"
	FP_BTN_WHO = "Who"
	FP_BTN_RESET = "Reset"
	FP_LABEL_FILTER = "Filter:"
	FP_LABEL_IGNORE = "Exclude:"
	FP_LABEL_WH = "Whisper:"
	FP_LABEL_AD = "LFM:"
	FP_TEXT_ADD = "Add"
	FP_TEXT_WH_PRESET_TITLE = "Whisper Presets"
	FP_TEXT_WH_FULL = "You can save up to 5 preset messages."
	FP_TEXT_WH_EXISTS = "This message is already saved."
	FP_TEXT_WH_EMPTY = "Please enter a message to save first."
	FP_TEXT_WH_SAVED = "Whisper message saved: %s"
	FP_TEXT_WH_DELETED = "Saved message deleted."

	-- Dungeon Filter Text
	FP_DUNGEONFILTER_RESETALL = "Clear Selected Dungeons"
	FP_DUNGEONFILTER_SINGLE = "Dungeon: %s"
	FP_DUNGEONFILTER_MULTI = "Dungeons: %d selected"
	FP_DUNGEONFILTER_NOT_FILTERED = "View All"
	FP_DUNGEONFILTER_NONE = "None"

	-- Tooltip & System Messages
	FP_TOOLTIP_CLOSE = "Close Window"
	FP_TOOLTIP_MAXMIZE = "Maximize Window"
	FP_TOOLTIP_MINIMIZE = "Minimize Window"
	FP_TOOLTIP_DECREASE = "Decrease Rows"
	FP_TOOLTIP_INCREASE = "Increase Rows"
	FP_TOOLTIP_OPTION = "Options"
	FP_TOOLTIP_SORT_TIME = "Sort by Time"
	FP_TOOLTIP_ACTIVATE_ON = "Running\nClick to pause"
	FP_TOOLTIP_ACTIVATE_OFF = "Paused\nClick to resume"
	FP_TOOLTIP_POPUP_ON = "Alerts Active\nClick to mute"
	FP_TOOLTIP_POPUP_OFF = "Alerts Muted"
	FP_TOOLTIP_AD_ON = "LFM Advertising\nClick to stop"
	FP_TOOLTIP_AD_OFF = "Click to start LFM advertising"
	FP_TOOLTIP_DUNGEON_FILTER = "|cff6BBF8ALeft-Click|r: Open dungeon menu\n|cffE0C068Wheel-Click|r: Toggle View All / Interested Dungeons\n|cffCF6679Right-Click|r: Reset dungeon filter (Clear)\n\n- Interested Dungeons -\n"
	FP_TOOLTIP_CLASS_FILTER = "Left-Click: Select my class\nRight-Click: Select target classes\nSelected: "
	FP_TOOLTIP_SHORTCUT_ALT = "Shortcut: Alt + Click"
	FP_TOOLTIP_SHORTCUT_ALT_RIGHT = "Shortcut: Alt + Right-Click"
	FP_TOOLTIP_SHORTCUT_CTRL = "Shortcut: Ctrl + Click"
	FP_TOOLTIP_SHORTCUT_SHIFT = "Shortcut: Shift + Click"
	FP_TOOLTIP_IGNORE = "Enter keywords to ignore separated by comma, then press Enter or click button"
	FP_TOOLTIP_DISABLED = "Disabled"

	FP_MESSAGE_POPUP_ACTIVE = "Alerts enabled when listings update."
	FP_MESSAGE_POPUP_DEACTIVE = "Alerts disabled."
	FP_MESSAGE_DUNGEON_RESET = "All dungeon filters cleared."
	FP_MESSAGE_START_AD = "LFM advertising started."
	FP_MESSAGE_STOP_AD = "LFM advertising stopped."
	FP_MESSAGE_NO_AD_TEXT = "Please enter an LFM message first."
	FP_MESSAGE_DISABLE_ANNOUNCE = "MessageQueue addon is not installed.\nInstall MessageQueue from CurseForge to enable auto LFM advertising."
	FP_MESSAGE_EXCEPTION = "Excluded listings from %s."
	FP_MESSAGE_CLEAR_EXCEPTION = "Excluded list reset. All listings will be displayed."
	FP_MESSAGE_START_DUNGEON_FILTER = "Showing selected dungeons only."
	FP_MESSAGE_STOP_DUNGEON_FILTER = "Showing all dungeons."
	FP_MESSAGE_APPLY_CUSTOM_FILTER = "Custom filter keywords applied."
	FP_MESSAGE_CUSTOM_IGNORE = "Listings containing excluded keywords will be hidden."
	FP_MESSAGE_CUSTOM_IGNORE_RESET = "Excluded keywords cleared. All listings will be displayed."
	FP_MESSAGE_APPLY_CUSTOM_IGNORE = "Excluded keyword applied: |cffCF6679%s|r"
	FP_MESSAGE_IGNORE_EMPTY = "Please enter keywords to exclude. (comma separated)"
	FP_MESSAGE_IGNORE_ALL_RESET = "Excluded list reset. All messages will be displayed."
	FP_BADGE_DETECT_ON = "|cff6BBF8AScan ON|r"
	FP_BADGE_DETECT_OFF = "|cffCF6679Scan OFF|r"
	FP_BADGE_SOUND_ON = "|cffE09050Alert ON|r"
	FP_BADGE_SOUND_OFF = "|cff8A8580Alert OFF|r"
	FP_BADGE_AD_ON = "|cff6BBF8ALFM ON|r"
	FP_BADGE_AD_OFF = "|cff8A8580LFM OFF|r"
	FP_OPTIONS_CHANNEL = "Select LFG Channel"
	FP_OPTIONS_INTERVAL = "LFM Interval"
	FP_OPTIONS_VALID = "Message Duration"
	FP_OPTIONS_FONTSIZE = "Font Size"
	FP_OPTIONS_SCALE = "Window Scale"
	FP_OPTIONS_COLOR = "Window Color"
	FP_OPTIONS_ICON = "Minimap Icon"
	FP_OPTIONS_ESC = "Close with ESC"
	FP_OPTIONS_RIGHTBUTTON = "Ctrl+Right-Click to Apply"
	FP_OPTIONS_LFG_ONLY = "Standalone LFG Mode"
	FP_OPTIONS_NORAID = "Disable while in Raid"
	FP_OPTIONS_NOPVP = "Disable while in Battleground"
	FP_OPTIONS_RESET = "Reset Options"
	FP_OPTIONS_RESETPOS = "Window Position"
	FP_OPTIONS_RESETSIZE = "Window Size"
	FP_OPTIONS_RESETALL = "Reset All Settings"
	FP_TEXT_RESIZE_TIP = "Drag: Resize window | Mouse wheel: Scroll list"
	FP_MESSAGE_LFG_ONLY_ON = "Standalone LFG mode activated. (Chat scan stopped)"
	FP_MESSAGE_LFG_ONLY_OFF = "Integrated mode activated. (Chat scan resumed)"
	FP_MESSAGE_NEWVERSION_RESET = "New version detected. Settings have been reset."
	FP_MESSAGE_RESETALL = "Default settings loaded."
	FP_MESSAGE_NOTARGET = "Please select a target from the list first."
	FP_MESSAGE_ICON_LOCK = "Minimap icon locked."
	FP_MESSAGE_ICON_UNLOCK = "Minimap icon can now be moved."
	FP_MESSAGE_ACTIVE = "%s - SolaLFG activated."
	FP_MESSAGE_DEACTIVE = "%s - SolaLFG deactivated."

	BINDING_HEADER_SOLALFG = "SolaLFG"
	BINDING_NAME_FP_TOGGLE = "Toggle SolaLFG Window"
end

-- Initialize English by default
FP_ApplyLocale("enUS")