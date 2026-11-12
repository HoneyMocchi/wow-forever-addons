--imports
local WIM = WIM;
local _G = _G;
local CreateFrame = CreateFrame;
local table = table;
local pairs = pairs;
local pcall = pcall;
local type = type;
local math = math;
local tostring = tostring;

--set namespace
setfenv(1, WIM);

-- WIM-owned placement editor: do not modify Blizzard Edit Mode state.
-- settingsCheckButtons is consumed by protected layout refreshes.

db_defaults.historyLoc = {
    left = -1,
    top = -1,
    width = -1,
    height = -1
};
db_defaults.filterLoc = {
    left = -1,
    top = -1,
    width = -1,
    height = -1
};
db_defaults.editModeFrames = {
    window = true,
    history = false,
    filters = false
};

-- Placement helpers shared with the real frames (Modules/History.lua and
-- Modules/Filters.lua call these when the frame is built and after the
-- user drags or resizes it). Negative values mean the stock centered frame.
local function applyPlacement(win, loc)
    if (not loc or not win) then
        return;
    end
    if (loc.width and loc.width > 0) then
        win:SetWidth(loc.width);
        win:SetHeight(loc.height);
    end
    if (loc.left >= 0) then
        local es = win:GetEffectiveScale();
        if (es and es > 0) then
            win:ClearAllPoints();
            win:SetPoint("TOPLEFT", _G.UIParent, "BOTTOMLEFT",
                loc.left / es, loc.top / es);
        end
    end
end

local function savePosition(win, loc)
    if (loc and win and win:GetLeft()) then
        local es = win:GetEffectiveScale();
        loc.left = win:GetLeft() * es;
        loc.top = win:GetTop() * es;
    end
end

function ApplyHistoryWindowPosition(win)
    applyPlacement(win, db and db.historyLoc);
end

function SaveHistoryWindowPosition(win)
    savePosition(win, db and db.historyLoc);
end

function ApplyFilterWindowPosition(win)
    applyPlacement(win, db and db.filterLoc);
end

function SaveFilterWindowPosition(win)
    savePosition(win, db and db.filterLoc);
end

function SaveHistoryWindowSize(win)
    if (db and db.historyLoc and win) then
        db.historyLoc.width = math.ceil(win:GetWidth());
        db.historyLoc.height = math.ceil(win:GetHeight());
    end
end

local entries = {};
local entriesBroken = false;
local selectedEntry;
local dialog;
local inEditMode = false;

-- Frames placed by position and size. Each is a UIParent child with a
-- stock centered size; its live frame is looked up by global name so an
-- unbuilt frame costs nothing.
local PLACED_FRAMES = {
    {
        key = "history", nameKey = "WIM History Viewer",
        loc = "historyLoc", global = "WIM3_HistoryFrame",
        stockWidth = 700, stockHeight = 505,
        minWidth = 600, minHeight = 400,
        maxWidth = 1400, maxHeight = 900,
        apply = function(live) ApplyHistoryWindowPosition(live); end,
    },
    {
        key = "filters", nameKey = "WIM Filter Editor",
        loc = "filterLoc", global = "WIM3_FilterFrame",
        stockWidth = 475, stockHeight = 390,
        minWidth = 475, minHeight = 390,
        maxWidth = 900, maxHeight = 700,
        apply = function(live) ApplyFilterWindowPosition(live); end,
    },
};

-- ------------------------------------------------------------------ dialog

-- The stock EditModeSettingSliderTemplate row is a 343x32 frame with a
-- 100px label box; the label box is widened so the English labels stay
-- on one line (longer locales wrap inside the box instead of spilling
-- out), and the dialog is sized so a full row fits with margins. The
-- buttons stretch to row width, the way the game's own dialog buttons
-- span theirs.
local DIALOG_WIDTH = 400;
local ROW_WIDTH = 365;
local LABEL_WIDTH = 120;

local function dialogButton(parent, text, onClick)
    local ok, btn = pcall(CreateFrame, "Button", nil, parent,
        "EditModeSystemSettingsDialogButtonTemplate");
    if (ok and btn and btn.SetOnClickHandler) then
        btn:SetText(text);
        btn:SetOnClickHandler(onClick);
    else
        btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate");
        btn:SetHeight(22);
        btn:SetText(text);
        btn:SetScript("OnClick", onClick);
    end
    btn:SetWidth(ROW_WIDTH);
    return btn;
end

-- A slider row the way the game's own system dialog builds them; nil when
-- the template is unavailable (the dialog then simply has no sliders).
local function roundedValue(value)
    return math.floor(value + 0.5);
end

local function makeSliderRow(container, label, minValue, maxValue, formatter, onChanged)
    local ok, row = pcall(CreateFrame, "Frame", nil, container,
        "EditModeSettingSliderTemplate");
    if (not ok or not row or not row.Slider) then
        return nil;
    end
    row:SetSize(ROW_WIDTH, 32);
    row.Label:SetSize(LABEL_WIDTH, 32);
    row.Label:SetText(label);
    row.Slider:SetWidth(200);
    if (row.Slider.MinText) then row.Slider.MinText:Hide(); end
    if (row.Slider.MaxText) then row.Slider.MaxText:Hide(); end
    -- The minimum may be a function: the message-window floor comes from
    -- the active skin, and must match what the resize grip enforces, or
    -- a window spawned at a smaller saved size pops out to the floor on
    -- its first ad-hoc resize.
    row.wimMin, row.wimMax = minValue, maxValue;
    row.wimFormatter = formatter;
    row.wimOnChanged = onChanged;
    -- Replace the template's value handler, then rerun OnLoad so the
    -- slider's callback registration captures the replacement.
    row.OnSliderValueChanged = function(self, value)
        if (not self.wimIniting and self.wimOnChanged) then
            self.wimOnChanged(value);
        end
    end;
    pcall(row.OnLoad, row);
    row.WIMSetValue = function(self, value)
        self.wimIniting = true;
        local formatters;
        if (_G.CreateMinimalSliderFormatter and _G.MinimalSliderWithSteppersMixin) then
            formatters = {
                [_G.MinimalSliderWithSteppersMixin.Label.Right] =
                    _G.CreateMinimalSliderFormatter(
                        _G.MinimalSliderWithSteppersMixin.Label.Right,
                        self.wimFormatter or roundedValue),
            };
        end
        local minNow = self.wimMin;
        if (type(minNow) == "function") then
            minNow = minNow();
        end
        if (value < minNow) then
            value = minNow;
        end
        self.Slider:Init(value, minNow, self.wimMax,
            self.wimMax - minNow, formatters);
        self.wimIniting = false;
    end;
    return row;
end

local function layoutDialog()
    if (dialog) then
        if (dialog.Settings and dialog.Settings.Layout) then
            dialog.Settings:Layout();
        end
        if (dialog.Buttons and dialog.Buttons.Layout) then
            dialog.Buttons:Layout();
        end
        if (dialog.Layout) then
            dialog:Layout();
        end
    end
end

local function deselectAll()
    for i = 1, #entries do
        local entry = entries[i];
        entry.ghost:SetMovable(false);
        if (entry.sel) then
            entry.sel.isSelected = false;
            if (inEditMode) then
                entry.sel:ShowHighlighted();
            end
        end
    end
    selectedEntry = nil;
    if (dialog) then
        dialog:Hide();
    end
end

local function ensureDialog()
    if (dialog) then
        return dialog;
    end
    local ok, frame = pcall(CreateFrame, "Frame", nil, _G.UIParent, "ResizeLayoutFrame");
    if (not ok or not frame) then
        return nil;
    end
    dialog = frame;
    dialog:SetSize(DIALOG_WIDTH, 350);
    -- The game's own system dialog is fixed-width; leaving the width to
    -- the resize layout also breaks down entirely when a selection has
    -- no settings widgets.
    dialog.fixedWidth = DIALOG_WIDTH;
    dialog:SetFrameStrata("DIALOG");
    dialog:SetFrameLevel(200);
    dialog:SetClampedToScreen(true);
    dialog:SetDontSavePosition(true);
    dialog:EnableMouse(true);
    dialog:SetMovable(true);
    dialog:RegisterForDrag("LeftButton");
    dialog:SetScript("OnDragStart", dialog.StartMoving);
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing);
    dialog.widthPadding = 40;
    dialog.heightPadding = 40;
    dialog:SetPoint("BOTTOMRIGHT", _G.UIParent, "BOTTOMRIGHT", -250, 250);
    dialog:Hide();

    local border = CreateFrame("Frame", nil, dialog, "DialogBorderTranslucentTemplate");
    border.ignoreInLayout = true;

    dialog.Title = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge");
    dialog.Title:SetPoint("TOP", 0, -15);

    local close = CreateFrame("Button", nil, dialog, "UIPanelCloseButton");
    close:SetPoint("TOPRIGHT");
    close.ignoreInLayout = true;
    close:SetScript("OnClick", deselectAll);

    dialog.Settings = CreateFrame("Frame", nil, dialog, "VerticalLayoutFrame");
    dialog.Settings:SetPoint("TOP", dialog.Title, "BOTTOM", 0, -12);
    dialog.Settings.spacing = 2;

    dialog.Buttons = CreateFrame("Frame", nil, dialog, "VerticalLayoutFrame");
    dialog.Buttons:SetPoint("TOP", dialog.Settings, "BOTTOM", 0, -5);
    dialog.Buttons.spacing = 5;

    dialog.ResetPosition = dialogButton(dialog.Buttons,
        _G.HUD_EDIT_MODE_RESET_POSITION or L["Reset Position"],
        function()
            if (selectedEntry) then
                selectedEntry.resetPosition();
                layoutDialog();
            end
        end);
    dialog.ResetPosition.layoutIndex = 1;

    return dialog;
end

local function showDialogFor(entry)
    if (not ensureDialog()) then
        return;
    end
    dialog.Title:SetText(entry.name);
    local anySettings = false;
    for i = 1, #entries do
        local e = entries[i];
        local shown = (e == entry);
        if (e.sliderRows) then
            for j = 1, #e.sliderRows do
                e.sliderRows[j]:SetShown(shown);
            end
            if (shown and #e.sliderRows > 0) then
                anySettings = true;
            end
        end
        if (e.resetSettings) then
            e.resetSettings:SetShown(shown);
        end
        if (e.extraButton) then
            e.extraButton:SetShown(shown);
        end
    end
    -- An empty settings container must not take part in the layout.
    dialog.Settings:SetShown(anySettings);
    if (entry.refreshSliders) then
        entry.refreshSliders();
    end
    dialog:Show();
    layoutDialog();
end

-- Shared slider construction for an entry's dialog page. defs carry
-- key/label/min/max/formatter; values flow through the passed accessors.
local function addEntrySliders(entry, defs, getValue, onChanged, onReset)
    if (not ensureDialog()) then
        return;
    end
    entry.sliderRows = {};
    for i = 1, #defs do
        local def = defs[i];
        local row = makeSliderRow(dialog.Settings, def.label, def.min, def.max,
            def.formatter,
            function(value) onChanged(def.key, value); end);
        if (row) then
            row.layoutIndex = i;
            row.wimKey = def.key;
            row:Hide();
            table.insert(entry.sliderRows, row);
        end
    end
    if (#entry.sliderRows > 0 and onReset) then
        entry.resetSettings = dialogButton(dialog.Settings,
            _G.RESET_TO_DEFAULT or L["Defaults"], onReset);
        entry.resetSettings.layoutIndex = #entry.sliderRows + 1;
        entry.resetSettings:Hide();
    end
    entry.refreshSliders = function()
        for i = 1, #entry.sliderRows do
            local row = entry.sliderRows[i];
            row:WIMSetValue(getValue(row.wimKey));
        end
        layoutDialog();
    end;
end

-- ------------------------------------------------------------------ ghosts

local function onSelectionDragStart(self)
    if (_G.InCombatLockdown()) then
        return;
    end
    self.parent:StartMoving();
end

local function onSelectionDragStop(self)
    if (_G.InCombatLockdown()) then
        return;
    end
    self.parent:StopMovingOrSizing();
    local entry = self.wimEntry;
    entry.save(entry.ghost);
    entry.apply(entry.ghost);
end

local function onSelectionMouseDown(self)
    if (_G.InCombatLockdown()) then
        return;
    end
    local entry = self.wimEntry;
    if (entry.sel.isSelected) then
        return;
    end
    for i = 1, #entries do
        if (entries[i] ~= entry and entries[i].sel) then
            entries[i].sel.isSelected = false;
            entries[i].sel:ShowHighlighted();
            entries[i].ghost:SetMovable(false);
        end
    end
    entry.ghost:SetMovable(true);
    entry.sel.isSelected = true;
    entry.sel:ShowSelected(true);
    selectedEntry = entry;
    showDialogFor(entry);
end

local function makeGhost(entry)
    local ghost = CreateFrame("Frame", nil, _G.UIParent);
    ghost:SetFrameStrata("DIALOG");
    ghost:SetClampedToScreen(true);
    ghost:SetDontSavePosition(true);
    ghost:Hide();
    local fill = ghost:CreateTexture(nil, "BACKGROUND");
    fill:SetAllPoints();
    fill:SetColorTexture(0, 0, 0, .6);

    local sel = CreateFrame("Frame", nil, ghost, "BackdropTemplate");
    sel:SetAllPoints(ghost);
    sel:EnableMouse(true);
    sel:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2});
    sel.parent = ghost;
    sel.wimEntry = entry;
    local label = sel:CreateFontString(nil, "OVERLAY", "GameFontNormal");
    label:SetPoint("TOP", 0, -6);
    label:SetText(entry.name);
    sel.ShowHighlighted = function(self)
        self:SetBackdropBorderColor(.2, .7, 1, 1);
        self:Show();
    end;
    sel.ShowSelected = function(self)
        self:SetBackdropBorderColor(1, .8, .1, 1);
        self:Show();
    end;
    sel:RegisterForDrag("LeftButton");
    sel:SetScript("OnMouseDown", onSelectionMouseDown);
    sel:SetScript("OnDragStart", onSelectionDragStart);
    sel:SetScript("OnDragStop", onSelectionDragStop);
    sel:Hide();

    entry.ghost = ghost;
    entry.sel = sel;
    return ghost;
end

-- -------------------------------------------------------- the two entries

local function windowSliderChanged(key, value)
    db.winSize[key] = value;
    UpdateAllWindowProps();
    local entry = entries.window;
    if (entry and entry.ghost) then
        entry.apply(entry.ghost);
    end
    options.DebugSetting("editmode", key, value);
end

-- The floor real windows enforce during ad-hoc resizing; a stored size
-- below it would only pop out to this on the window's first resize.
-- The bounds have several writers (the skin's static minimums, the
-- widget-extent pass in UpdateProps, the skinner's layout math), so the
-- only trustworthy number is what a live window is enforcing right now;
-- open windows are asked directly, with the session cache published by
-- UpdateProps and the skin floor behind them.

local function readBounds(win)
    if (win.GetResizeBounds) then
        local ok, w, h = pcall(win.GetResizeBounds, win);
        if (ok) then return w, h; end
    elseif (win.GetMinResize) then
        local ok, w, h = pcall(win.GetMinResize, win);
        if (ok) then return w, h; end
    end
end

local function liveWindowMin()
    local bestWidth, bestHeight = 0, 0;
    local active = windows and windows.active;
    if (type(active) == "table") then
        for _, group in pairs(active) do
            if (type(group) == "table") then
                for _, win in pairs(group) do
                    if (type(win) == "table") then
                        local w, h = readBounds(win);
                        if (w and w > bestWidth) then bestWidth = w; end
                        if (h and h > bestHeight) then bestHeight = h; end
                    end
                end
            end
        end
    end
    return bestWidth, bestHeight;
end

-- The user-invoked measurement: an invisible whisper-type window run
-- through the engine's own creation, skinning and widget layout, asked
-- for the bounds it would enforce, then destroyed. Whisper type
-- matters: the shortcut bar only populates on whisper windows and is
-- what raises the width floor. The measurement waits a beat after
-- showing: the pop-in animation and lazy rectangle resolution leave
-- geometry unstable in the creation frame, which reads back only the
-- unraised skin floor. Bounds are read both before and after the
-- explicit widget pass, because the pass and the skinner each write
-- bounds and neither alone carries both raised axes.
local probing = false;
local function probeWindowMin(callback)
    if (probing or not CreateWhisperWindow or not DestroyWindow) then
        return;
    end
    local ok, win = pcall(CreateWhisperWindow, "WIMProbe");
    if (not ok or not win) then
        options.DebugSetting("editmode", "probe", "create-failed");
        return;
    end
    probing = true;
    win:SetAlpha(0);
    pcall(win.Show, win);
    -- Park it outside the screen so fades and animations can never
    -- flash it; rectangles resolve fine offscreen.
    pcall(win.SetClampedToScreen, win, false);
    win:ClearAllPoints();
    win:SetPoint("TOPLEFT", _G.UIParent, "TOPRIGHT", 200, 0);
    local function finish()
        probing = false;
        local beforeWidth, beforeHeight = readBounds(win);
        if (win.UpdateProps) then
            pcall(win.UpdateProps, win);
        end
        local afterWidth, afterHeight = readBounds(win);
        local minWidth = math.max(beforeWidth or 0, afterWidth or 0);
        local minHeight = math.max(beforeHeight or 0, afterHeight or 0);
        win:SetAlpha(1);
        pcall(win.SetClampedToScreen, win, db.clampToScreen and true or false);
        pcall(DestroyWindow, win);
        options.DebugSetting("editmode", "probeMin",
            tostring(minWidth) .. "x" .. tostring(minHeight));
        if (minWidth > 0) then
            -- Whole numbers only: raw engine bounds are fractional and
            -- would land in saved variables and slider labels as-is.
            minWidth, minHeight = math.ceil(minWidth), math.ceil(minHeight);
            editModeWindowMin = editModeWindowMin or {};
            editModeWindowMin.probe = { width = minWidth, height = minHeight };
            if (callback) then
                callback(minWidth, minHeight);
            end
        end
    end
    if (_G.C_Timer and _G.C_Timer.After) then
        _G.C_Timer.After(.3, finish);
    else
        finish();
    end
end

local function windowMinSize()
    local skin = GetSelectedSkin and GetSelectedSkin();
    local mw = skin and skin.message_window;
    local minWidth = (mw and mw.min_width) or 256;
    local minHeight = (mw and mw.min_height) or 80;
    local liveWidth, liveHeight = liveWindowMin();
    if (liveWidth > minWidth) then minWidth = liveWidth; end
    if (liveHeight > minHeight) then minHeight = liveHeight; end
    if (editModeWindowMin) then
        for _, computed in pairs(editModeWindowMin) do
            if (computed.width and computed.width > minWidth) then
                minWidth = computed.width;
            end
            if (computed.height and computed.height > minHeight) then
                minHeight = computed.height;
            end
        end
    end
    return math.ceil(minWidth), math.ceil(minHeight);
end

local function buildWindowEntry()
    local entry = {
        key = "window",
        name = L["WIM Message Window"],
    };
    entry.apply = function(ghost)
        local minWidth, minHeight = windowMinSize();
        ghost:SetScale((db.winSize.scale or 100) / 100);
        ghost:SetSize(math.max(db.winSize.width, minWidth),
            math.max(db.winSize.height, minHeight));
        local es = ghost:GetEffectiveScale();
        ghost:ClearAllPoints();
        ghost:SetPoint("TOPLEFT", WindowParent, "BOTTOMLEFT",
            db.winLoc.left / es, db.winLoc.top / es);
    end;
    entry.save = function(ghost)
        if (ghost:GetLeft()) then
            local es = ghost:GetEffectiveScale();
            db.winLoc.left = ghost:GetLeft() * es;
            db.winLoc.top = ghost:GetTop() * es;
            options.DebugSetting("editmode", "winLoc",
                tostring(db.winLoc.left) .. "," .. tostring(db.winLoc.top));
        end
    end;
    entry.resetPosition = function()
        db.winLoc.left = db_defaults.winLoc.left;
        db.winLoc.top = db_defaults.winLoc.top;
        entry.apply(entry.ghost);
    end;
    if (not makeGhost(entry)) then
        return nil;
    end

    addEntrySliders(entry, {
        { key = "width",  label = L["Width"],  max = 800,
          min = function() return (windowMinSize()); end },
        { key = "height", label = L["Height"], max = 600,
          min = function() local _, minHeight = windowMinSize(); return minHeight; end },
        { key = "scale",  label = L["Window Scale"],   min = 10,  max = 400,
          formatter = function(value) return value .. "%"; end },
    },
    function(key)
        return db.winSize[key];
    end,
    windowSliderChanged,
    function()
        db.winSize.width = db_defaults.winSize.width;
        db.winSize.height = db_defaults.winSize.height;
        db.winSize.scale = db_defaults.winSize.scale;
        UpdateAllWindowProps();
        entry.apply(entry.ghost);
        entry.refreshSliders();
    end);

    if (dialog) then
        entry.extraButton = dialogButton(dialog.Buttons,
            L["Calculate Minimum Size"],
            function()
                probeWindowMin(function(minWidth, minHeight)
                    if (db.winSize.width < minWidth) then
                        db.winSize.width = minWidth;
                    end
                    if (db.winSize.height < minHeight) then
                        db.winSize.height = minHeight;
                    end
                    UpdateAllWindowProps();
                    entry.apply(entry.ghost);
                    if (selectedEntry == entry) then
                        entry.refreshSliders();
                    end
                end);
            end);
        entry.extraButton.layoutIndex = 2;
        entry.extraButton:Hide();
    end
    return entry;
end

local function placedSize(spec)
    local loc = db[spec.loc];
    if (loc.width > 0) then
        return loc.width, loc.height;
    end
    local live = _G[spec.global];
    if (live) then
        return math.floor(live:GetWidth() + 0.5), math.floor(live:GetHeight() + 0.5);
    end
    return spec.stockWidth, spec.stockHeight;
end

local function buildPlacedEntry(spec)
    local entry = {
        key = spec.key,
        name = L[spec.nameKey],
    };
    local function applyLive()
        local live = _G[spec.global];
        if (live) then
            spec.apply(live);
        end
    end
    entry.apply = function(ghost)
        local loc = db[spec.loc];
        ghost:SetSize(placedSize(spec));
        ghost:ClearAllPoints();
        if (loc.left >= 0) then
            local es = ghost:GetEffectiveScale();
            ghost:SetPoint("TOPLEFT", _G.UIParent, "BOTTOMLEFT",
                loc.left / es, loc.top / es);
        else
            ghost:SetPoint("CENTER");
        end
    end;
    entry.save = function(ghost)
        if (ghost:GetLeft()) then
            local loc = db[spec.loc];
            local es = ghost:GetEffectiveScale();
            loc.left = ghost:GetLeft() * es;
            loc.top = ghost:GetTop() * es;
            applyLive();
            options.DebugSetting("editmode", spec.loc,
                tostring(loc.left) .. "," .. tostring(loc.top));
        end
    end;
    entry.resetPosition = function()
        local loc = db[spec.loc];
        loc.left = -1;
        loc.top = -1;
        entry.apply(entry.ghost);
        local live = _G[spec.global];
        if (live) then
            live:ClearAllPoints();
            live:SetPoint("CENTER");
        end
    end;
    if (not makeGhost(entry)) then
        return nil;
    end

    -- These size the frame itself, not a default for new ones.
    addEntrySliders(entry, {
        { key = "width",  label = L["Width"],
          min = spec.minWidth, max = spec.maxWidth },
        { key = "height", label = L["Height"],
          min = spec.minHeight, max = spec.maxHeight },
    },
    function(key)
        local width, height = placedSize(spec);
        return key == "width" and width or height;
    end,
    function(key, value)
        local loc = db[spec.loc];
        if (loc.width < 0) then
            -- first explicit size: pin both axes so one slider move
            -- does not leave the other at the sentinel
            loc.width, loc.height = placedSize(spec);
        end
        loc[key] = value;
        entry.apply(entry.ghost);
        applyLive();
        options.DebugSetting("editmode", spec.key .. key, value);
    end,
    function()
        local loc = db[spec.loc];
        loc.width = -1;
        loc.height = -1;
        local live = _G[spec.global];
        if (live) then
            live:SetWidth(spec.stockWidth);
            live:SetHeight(spec.stockHeight);
        end
        entry.apply(entry.ghost);
        entry.refreshSliders();
    end);
    return entry;
end

-- Standalone controls. Never invoke or mutate Blizzard's manager.
local editor;
local function applyGhostVisibility()
    for i = 1, #entries do
        local entry = entries[i];
        local shown = db.editModeFrames[entry.key] and true or false;
        entry.ghost:SetShown(shown);
        if (not shown and selectedEntry == entry) then deselectAll(); end
    end
end

local function buildEntries()
    if (entriesBroken or #entries > 0) then return; end
    local entry = buildWindowEntry();
    if (not entry) then entriesBroken = true; return; end
    table.insert(entries, entry);
    entries.window = entry;
    for i = 1, #PLACED_FRAMES do
        local placed = buildPlacedEntry(PLACED_FRAMES[i]);
        if (placed) then
            table.insert(entries, placed);
            entries[placed.key] = placed;
        end
    end
end

local function stopEditing()
    inEditMode = false;
    for i = 1, #entries do
        local entry = entries[i];
        entry.ghost:StopMovingOrSizing();
        entry.ghost:SetMovable(false);
        entry.ghost:Hide();
        entry.sel.isSelected = false;
        entry.sel:Hide();
    end
    selectedEntry = nil;
    if (dialog) then dialog:Hide(); end
end

local function ensureEditor()
    if (editor) then return editor; end
    editor = CreateFrame("Frame", nil, _G.UIParent, "BackdropTemplate");
    editor:Hide();
    editor:SetSize(310, 170);
    editor:SetPoint("TOPLEFT", _G.UIParent, "TOPLEFT", 30, -100);
    editor:SetFrameStrata("DIALOG");
    editor:SetFrameLevel(210);
    editor:SetClampedToScreen(true);
    editor:SetMovable(true);
    editor:EnableMouse(true);
    editor:RegisterForDrag("LeftButton");
    editor:SetScript("OnDragStart", editor.StartMoving);
    editor:SetScript("OnDragStop", editor.StopMovingOrSizing);
    editor:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1});
    editor:SetBackdropColor(.04, .04, .06, .95);
    editor:SetBackdropBorderColor(.2, .7, 1, 1);
    local title = editor:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
    title:SetPoint("TOPLEFT", 12, -12);
    title:SetText("WIM - " .. (_G.HUD_EDIT_MODE or "Window placement"));
    local close = CreateFrame("Button", nil, editor, "UIPanelCloseButton");
    close:SetPoint("TOPRIGHT");
    close:SetScript("OnClick", function() editor:Hide(); end);
    editor.checks = {};
    for i = 1, #entries do
        local entry = entries[i];
        local cb = CreateFrame("CheckButton", nil, editor, "UICheckButtonTemplate");
        cb:SetPoint("TOPLEFT", 12, -35 - (i - 1) * 32);
        local label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
        label:SetPoint("LEFT", cb, "RIGHT", 3, 0);
        label:SetText(entry.name);
        cb:SetScript("OnClick", function(self)
            db.editModeFrames[entry.key] = self:GetChecked() and true or false;
            applyGhostVisibility();
        end);
        editor.checks[entry.key] = cb;
    end
    editor:SetScript("OnHide", stopEditing);
    editor:RegisterEvent("PLAYER_REGEN_DISABLED");
    editor:SetScript("OnEvent", function(self) self:Hide(); end);
    return editor;
end

function ShowEditMode()
    if (_G.InCombatLockdown() or not db) then return; end
    buildEntries();
    if (entriesBroken) then return; end
    local panel = ensureEditor();
    inEditMode = true;
    panel:Show();
    for i = 1, #entries do
        local entry = entries[i];
        panel.checks[entry.key]:SetChecked(db.editModeFrames[entry.key]);
        entry.apply(entry.ghost);
        entry.sel.isSelected = false;
        entry.sel:ShowHighlighted();
    end
    applyGhostVisibility();
end
