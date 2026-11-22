-- The look every UI module shares: the skins' palettes, fonts and corners, the
-- tooltip colors (Core/Tooltip.lua uses them too), skin-aware widgets
-- (pills, search boxes, tick boxes, faction toggles, panes, dialogs, scroll bars), the list rows and
-- scrolled columns the panes share, and small text helpers (dot joins,
-- plurals, IDs). Helpers with no look of their own go on `ns` in
-- Core/Init.lua instead. Dark colors are surfaces, light colors are text
-- and accents.
--
-- Aliases used across the addon's files:
--   Theme      this theme (ns.Theme): its colors, fonts, sizes and widgets
--   Size       Theme.size, the shared layout sizes (Size.pad, Size.row, ...)
--   C, F       a fixed skin's colors and fonts (Theme:Palette / Theme:Fonts)
--              in windows that don't follow the style switch (welcome, debug)
--   UI         the main window module (ns.UI)
--   instance   a dungeon, raid, vendor list, collection or profession (see
--              Data/Data.lua; ns.Data.instances, UI.state.instance)
--   encounter  one of an instance's encounters: a boss, loot pool, rank or
--              recipe
--   entry      one item of a list: a row's data in a list or loot pane, a
--              shopping or wishlist item, an outbox record
local _, ns = ...
local L = ns.L

local function Hex(hex, a)
    local r = tonumber(hex:sub(1, 2), 16) / 255
    local g = tonumber(hex:sub(3, 4), 16) / 255
    local b = tonumber(hex:sub(5, 6), 16) / 255
    return { r, g, b, a or 1 }
end

local Theme = {}
ns.Theme = Theme

-- Four skins share every layout and differ in surfaces, fonts, colors and
-- corners: "native" (the default: Blizzard's own frame templates and
-- textures, so the window matches the game's windows) and three of
-- NeedRoll's own flat panels: "modern" (navy), "dark" (the same in neutral
-- greys) and "elvui" (square corners in ElvUI's colors and font, offered
-- while ElvUI is loaded). SKINS below says what makes each one. Comments
-- across the addon that say "modern" (or "native") about a look mean the
-- flat path all three take (`not Theme.native`).
-- Theme:SetSkin swaps Theme.color, Theme.font and Theme.corners; widgets
-- built afterwards use them.
Theme.skins = { "native", "modern", "dark", "elvui" }
Theme.skinNames = { native = L["Native"], modern = L["Modern"], dark = L["Dark"], elvui = L["ElvUI"] }

local palettes = {
    modern = {
        bg       = Hex("001021"),        -- window
        panel    = Hex("071B2F"),        -- list panes, a step above the window
        panel2   = Hex("0A2136"),        -- loot pane, one step brighter
        popup    = Hex("0A2136"),        -- dialogs, menus and notices that open over the window
        edge     = Hex("C1EEFF", 0.12),  -- pane borders
        line     = Hex("C1EEFF", 0.08),  -- hairline dividers
        primary  = Hex("3E607F"),        -- selected rows
        input    = Hex("3E607F"),        -- text and search boxes (and `inputEdge` their outline, if any)
        hover    = Hex("3E607F", 0.45),
        text     = Hex("C1EEFF"),        -- body text
        muted    = Hex("C1EEFF", 0.50),  -- secondary text
        faint    = Hex("C1EEFF", 0.28),
        heading  = Hex("FCD29F"),        -- titles, active tab
        -- The content pane's top strip (Back, Add to shopping list, Clear
        -- list): its fill, the line under it, and its outlined pill buttons.
        strip     = Hex("3E607F", 0.28),
        stripLine = Hex("3B875B"),
        pillEdge  = Hex("FCD29F", 0.55),
        pillFill  = Hex("3E607F"),
        accent   = Hex("3B875B"),        -- selection bar, connector, loot outline, drop rates
        selectedText = Hex("FCD29F"),    -- title of a selected row
        rate     = Hex("3B875B"),        -- drop chance
        note     = Hex("3B875B"),        -- "rare", "zone-wide" under an encounter name
        scrollTrack = Hex("C1EEFF", 0.05), -- scroll bar groove
        scrollThumb = Hex("3E607F"),       -- scroll bar handle
        scrollThumbHover = Hex("3B875B"),
        -- Dungeon quests: done, not done (and levels too high), in your log, and
        -- levels you can take.
        complete   = Hex("5FCB86"),
        incomplete = Hex("E5636B"),
        accepted   = Hex("F2D45C"),
        available  = Hex("F2D45C"),
        link       = Hex("FCD29F"),        -- quest givers you can click to pin on the map
        dropper    = Hex("E5463B"),        -- mobs that drop a quest starter or recipe: TaxiNode_Continent_Horde's red
        quest      = Hex("FFFF00"),        -- quest names: the yellow of a quest link in chat
        factFill   = Hex("C1EEFF", 0.05),  -- Overview fact boxes
        -- A dungeon's active section (Overview, Quests or Encounters): its
        -- card's outline and fill (both fade out downward), and the round
        -- disc behind each section icon, ringed when its section is active.
        sectionEdge    = Hex("3B875B"),
        sectionFill    = Hex("3E607F", 0.55),
        sectionFillMid = Hex("3E607F", 0.22),
        -- A recipe page's boxed sections: the same card on its side, its
        -- fill fading from black at the left to clear (Theme:CardBackdrop).
        cardFill       = Hex("000000", 0.50),
        cardFillMid    = Hex("000000", 0.22),
        disc           = Hex("0D2740"),
        discRing       = Hex("FCD29F"),
        -- The other sections' headers: each a thin closed card, lit in the
        -- section edge color under the mouse.
        shutFill       = Hex("C1EEFF", 0.04),
        shutEdge       = Hex("C1EEFF", 0.18),
        shutFillLit    = Hex("3E607F", 0.30),
        -- The questline page's lines between cards: the cards' shutEdge as it
        -- shows over the content pane (panel2), made opaque so lines that
        -- meet don't brighten, and the accent green where a line joins two
        -- finished quests.
        flowLine       = Hex("2B465A"),
        flowDone       = Hex("3B875B"),
        -- A questline's goal, its step done inside the dungeon whose page it
        -- is: a purple no other mark uses, its card's outline and glow
        -- (`goal`), the card's tint (`goalFill`) and the words beside it
        -- (`goalText`).
        goal           = Hex("B48CFF"),
        goalFill       = Hex("B48CFF", 0.14),
        goalText       = Hex("D9C6FF"),
        rule       = Hex("3B875B"),        -- the heavy line under a section heading (Attunement)
        divider    = Hex("FFD100"),        -- the thin rule between a page's sections (Theme:Divider)
        -- Common (white) item names; the game's own white reads as grey here,
        -- too close to Poor. The native skin leaves this unset and uses the game's.
        common     = Hex("F0F0F0"),
        -- An instance's levels against yours: far below, below, in range,
        -- a little above, well above (the game's quest difficulty colors, softened).
        levelTrivial    = Hex("C1EEFF", 0.40),
        levelEasy       = Hex("5FCB86"),
        levelFair       = Hex("F2D45C"),
        levelHard       = Hex("F0A35E"),
        levelImpossible = Hex("E5636B"),
        band       = Hex("C1EEFF", 0.035), -- every other instance row
        -- An open group's members: a panel dark at the left fading to clear,
        -- with a tree line down its left edge; the open header is lit.
        wingFade   = Hex("000814", 0.67),
        wingLine   = Hex("3B875B", 0.90),
        groupLit   = Hex("C1EEFF", 0.05),
    },
    -- Dark's palette is modern's with greys (palettes.dark below); the
    -- ElvUI style's is read from ElvUI when it is first used (ElvUIPalette).
    -- Game font colors: gold headers (GameFontNormal), white body
    -- (GameFontHighlight), grey secondary (GameFontDisable).
    native = {
        bg       = Hex("000000"),
        panel    = Hex("000000", 0),
        panel2   = Hex("000000", 0),
        popup    = Hex("000000", 0.92),  -- near black: the panes are see-through here
        edge     = Hex("000000"),
        line     = Hex("FFD100", 0.18),
        primary  = Hex("3E607F"),
        hover    = Hex("FFFFFF", 0.10),
        text     = Hex("FFFFFF"),
        muted    = Hex("A0A0A0"),
        faint    = Hex("808080"),
        heading  = Hex("FFD100"),
        strip     = Hex("000000", 0.35),
        stripLine = Hex("FFD100", 0.25),
        pillEdge  = Hex("FFD100", 0.55),
        pillFill  = Hex("FFD100", 0.22),
        accent   = Hex("FFD100"),
        selectedText = Hex("FFFFFF"),
        rate     = Hex("FFFFFF"),
        note     = Hex("A0A0A0"),
        scrollTrack = Hex("FFFFFF", 0.06),
        scrollThumb = Hex("808080", 0.80),
        scrollThumbHover = Hex("FFD100", 0.80),
        -- The game's GREEN_FONT_COLOR, RED_FONT_COLOR and YELLOW_FONT_COLOR.
        complete   = Hex("1AFF1A"),
        incomplete = Hex("FF2020"),
        accepted   = Hex("FFFF00"),
        available  = Hex("FFFF00"),
        link       = Hex("71D5FF"),        -- the blue of in-game links
        dropper    = Hex("E5463B"),        -- mobs that drop a quest starter or recipe: TaxiNode_Continent_Horde's red
        quest      = Hex("FFFF00"),        -- the yellow of a quest link in chat
        rule       = Hex("FFD100"),        -- the game's gold, like the headings
        divider    = Hex("FFD100"),
        sectionEdge    = Hex("FFD100", 0.55),
        sectionFill    = Hex("FFD100", 0.16),
        sectionFillMid = Hex("FFD100", 0.06),
        cardFill       = Hex("000000", 0.50),
        cardFillMid    = Hex("000000", 0.22),
        disc           = Hex("1C1611"),
        discRing       = Hex("E8B94A"),
        shutFill       = Hex("FFFFFF", 0.035),
        shutEdge       = Hex("FFFFFF", 0.20),
        shutFillLit    = Hex("FFD100", 0.07),
        -- The questline page's lines: the cards' shutEdge as it shows over
        -- the panes' dimmed parchment, made opaque, and the game's green
        -- (as `complete`) where a line joins two finished quests.
        flowLine       = Hex("4A4540"),
        flowDone       = Hex("1AFF1A"),
        -- A questline's goal: modern's purple, its tint a touch stronger to
        -- show over the parchment.
        goal           = Hex("B48CFF"),
        goalFill       = Hex("B48CFF", 0.18),
        goalText       = Hex("D9C6FF"),
        -- The game's QuestDifficultyColors.
        levelTrivial    = Hex("808080"),
        levelEasy       = Hex("40BF40"),
        levelFair       = Hex("FFD100"),
        levelHard       = Hex("FF8040"),
        levelImpossible = Hex("FF1A1A"),
        band       = Hex("FFFFFF", 0.04),
        -- Like the Overview stat boxes: the same wash and gold rule.
        wingFade   = Hex("000000", 0.28),
        wingLine   = Hex("FFD100", 0.45),
        groupLit   = Hex("FFFFFF", 0.06),
    },
}

-- A copy of palette `base` with the colors in `changes` in place of its own.
local function PaletteWith(base, changes)
    local palette = CopyTable(base)
    for key, color in pairs(changes) do palette[key] = color end
    return palette
end

-- Modern in neutral greys: modern's own gold headings, green accent and
-- quest, link and level colors, with the navy surfaces turned grey and the
-- pale blue text off-white (E6E6E6) at modern's alphas. Only the colors that
-- differ from modern's are listed.
palettes.dark = PaletteWith(palettes.modern, {
    bg       = Hex("121212"),
    panel    = Hex("1A1A1A"),
    panel2   = Hex("1E1E1E"),
    popup    = Hex("1E1E1E"),
    edge     = Hex("E6E6E6", 0.12),
    line     = Hex("E6E6E6", 0.08),
    primary  = Hex("333333"),        -- a step over the panes, so a selected row stands out
    input    = Hex("333333"),
    hover    = Hex("333333", 0.45),
    text     = Hex("E6E6E6"),
    muted    = Hex("E6E6E6", 0.50),
    faint    = Hex("E6E6E6", 0.28),
    strip     = Hex("333333", 0.28),
    pillFill  = Hex("333333"),
    scrollTrack = Hex("E6E6E6", 0.05),
    scrollThumb = Hex("4A4A4A"),       -- lighter than `primary`, to show on the panes
    factFill   = Hex("E6E6E6", 0.05),
    sectionFill    = Hex("333333", 0.55),
    sectionFillMid = Hex("333333", 0.22),
    disc           = Hex("262626"),
    shutFill       = Hex("E6E6E6", 0.04),
    shutEdge       = Hex("E6E6E6", 0.18),
    shutFillLit    = Hex("333333", 0.30),
    flowLine       = Hex("3A3A3A"),
    levelTrivial    = Hex("E6E6E6", 0.40),
    band       = Hex("E6E6E6", 0.035),
    wingFade   = Hex("000000", 0.67),
    groupLit   = Hex("E6E6E6", 0.05),
})

-- Tooltip text colors, the same in every skin. title: the first line.
-- info (pale blue): places, labels beside a value and side notes. hint: what
-- a click does. quiet (grey): IDs and asides. text: white values and plain
-- lines. good: good news (a drop chance, a collected look).
Theme.tip = {
    title = { 0.99, 0.82, 0.62 },
    info = { 0.76, 0.93, 1 },
    hint = { 0.5, 0.6, 0.65 },
    quiet = { 0.6, 0.6, 0.6 },
    text = { 1, 1, 1 },
    good = { 0.35, 0.77, 0.52 },
}

-- Text size, a setting of its own beside the skin: Large draws the whole
-- window (text, rows, icons, columns) bigger, for players who want bigger
-- print. Layouts are untouched; the window is scaled (see UI:WindowScale
-- in MainFrame.lua). Theme.textScale.large is set below the window metrics.
Theme.textSizes = { "normal", "large" }
Theme.textSizeNames = { normal = L["Normal"], large = L["Large"] }
Theme.textScale = { normal = 1 }

-- Window metrics.
Theme.size = {
    width = 1040, height = 540,
    -- Smallest the window can be dragged to: item names in the two-column
    -- loot grid and the footer hint still fit, and every pane keeps a few rows.
    minWidth = 960, minHeight = 460,
    header = 44, tabs = 34, footer = 32,
    paneLabel = 42,  -- the strip at the top of the two list panes (label, faction switch)
    instanceList = 260, encounterList = 190,  -- instanceList: the first pane on every tab
    -- The second pane where it lists quests by name (Dungeons, Raids and the
    -- Classes tab's sections), wider than encounterList so they fit.
    questList = 263,
    row = 30, itemRow = 54, pad = 14, gutter = 12, edge = 8,
}

-- How far above a pane's bottom edge its scrolled rows are cut off
-- (Theme:ScrollView, Theme:ScrollColumn): a row half in view ends inside the
-- pane, clear of its border and rounded corners, rather than on them.
Theme.size.scrollBottom = Theme.size.pad / 2

-- Large text: as big as lets the smallest window still fit a Steam Deck's
-- 1280x800 screen (4/3: the width is what limits it).
Theme.textScale.large = math.min(1280 / Theme.size.minWidth, 800 / Theme.size.minHeight)

-- The Shopping List pane on top of the window's scale: 1.15x bigger at
-- Normal; at Large the window's own 4/3 is already bigger than that, so it
-- adds nothing (1.15 on top would make it 1.53x and crowd the 1280x800 screen).
Theme.shoppingScale = { normal = 1.15, large = 1 }

local FONT = STANDARD_TEXT_FONT

-- ElvUI -----------------------------------------------------------------------
-- The ElvUI style takes its colors and font from the player's own ElvUI,
-- read at run time. ElvUI's code, textures and fonts are its own (all rights
-- reserved), so NeedRoll copies none of them, calls none of its skinning
-- code and draws the look itself. ElvUI fills in its media as it starts
-- (after login), so they are read the first time the style is used; a
-- change to ElvUI's colors or font shows in NeedRoll after a /reload.

-- ElvUI's defaults, for anything a player's ElvUI doesn't give: its
-- backdrop (the panes), the see-through backdrop of its "Transparent"
-- template (the window), its border, its "value color" accent (1784D1) and
-- its font style.
local ELVUI_DEFAULTS = {
    backdrop = { 0.1, 0.1, 0.1, 1 },
    backdropFade = { 0.06, 0.06, 0.06, 0.8 },
    border = { 0, 0, 0, 1 },
    value = { 0.09, 0.52, 0.82, 1 },
    fontStyle = "OUTLINE",
}

-- ElvUI's engine (the E in `local E = unpack(ElvUI)`) once its media are
-- filled in, or nil while ElvUI isn't loaded or doesn't look as expected.
local function ElvUIEngine()
    if not C_AddOns.IsAddOnLoaded("ElvUI") then return nil end
    local addon = _G.ElvUI
    local engine = type(addon) == "table" and addon[1]
    if type(engine) ~= "table" or type(engine.media) ~= "table" then return nil end
    return engine
end

-- An ElvUI color ({ r, g, b[, a] }) as a palette color, or `default` when
-- it isn't one.
local function ElvUIColor(value, default)
    if type(value) ~= "table" then return default end
    local r, g, b, a = value[1], value[2], value[3], value[4]
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return default end
    return { r, g, b, type(a) == "number" and a or default[4] }
end

-- ElvUI's colors, font file and font style, its defaults filling any gap.
-- Every field is checked, since ElvUI's insides can change between versions.
local function ReadElvUIMedia()
    local engine = ElvUIEngine()
    local media = engine and engine.media or {}
    local settings = engine and type(engine.db) == "table" and engine.db
    local general = settings and type(settings.general) == "table" and settings.general or {}
    return {
        backdrop = ElvUIColor(media.backdropcolor, ELVUI_DEFAULTS.backdrop),
        backdropFade = ElvUIColor(media.backdropfadecolor, ELVUI_DEFAULTS.backdropFade),
        border = ElvUIColor(media.bordercolor, ELVUI_DEFAULTS.border),
        value = ElvUIColor(media.rgbvaluecolor, ELVUI_DEFAULTS.value),
        font = type(media.normFont) == "string" and media.normFont or FONT,
        fontStyle = type(general.fontStyle) == "string" and general.fontStyle or ELVUI_DEFAULTS.fontStyle,
    }
end

-- ElvUI's font style ("OUTLINE", "SHADOWOUTLINE", "NONE" and so on) as the
-- game's font flags, and whether text keeps its drop shadow: ElvUI's
-- SHADOW styles are a shadow rather than a flag, and an outline needs none.
local function ElvUIFontFlags(style)
    local hasShadow = style:find("SHADOW") ~= nil
    local flags = style:gsub("SHADOW", "")
    if flags == "NONE" then flags = "" end
    return flags, hasShadow or not flags:find("OUTLINE")
end

-- The ElvUI style's palette: ElvUI's backdrops, border and value color,
-- white text and grey secondary text, modern's quest, link and level colors.
local function ElvUIPalette(media)
    local modern = palettes.modern
    local function Value(alpha)
        return { media.value[1], media.value[2], media.value[3], alpha }
    end
    return {
        bg       = media.backdropFade,
        panel    = media.backdrop,
        panel2   = media.backdrop,
        popup    = media.backdrop,
        edge     = media.border,
        line     = media.border,
        primary  = Value(0.35),
        input    = media.backdrop,
        inputEdge = media.border,
        hover    = Value(0.18),
        text     = Hex("FFFFFF"),
        muted    = Hex("B0B0B0"),
        faint    = Hex("808080"),
        heading  = Hex("FFFFFF"),
        strip     = Hex("000000", 0.25),
        stripLine = Value(1),
        pillEdge  = Value(0.55),
        pillFill  = Hex("FFFFFF", 0.18),  -- only its alpha counts: a pill fills in its text's color
        accent   = Value(1),
        selectedText = Hex("FFFFFF"),
        rate     = Value(1),
        note     = Value(1),
        scrollTrack = Hex("FFFFFF", 0.05),
        scrollThumb = Hex("666666"),
        scrollThumbHover = Value(1),
        complete   = modern.complete,
        incomplete = modern.incomplete,
        accepted   = modern.accepted,
        available  = modern.available,
        link       = modern.link,
        dropper    = modern.dropper,
        quest      = modern.quest,
        factFill   = Hex("FFFFFF", 0.04),
        sectionEdge    = Value(1),
        sectionFill    = Value(0.20),
        sectionFillMid = Value(0.08),
        cardFill       = Hex("000000", 0.50),
        cardFillMid    = Hex("000000", 0.22),
        disc           = Hex("262626"),
        discRing       = Value(1),
        shutFill       = Hex("FFFFFF", 0.04),
        shutEdge       = media.border,
        shutFillLit    = Value(0.18),
        flowLine       = media.border,  -- the cards' shutEdge, as modern's
        flowDone       = modern.complete,
        goal           = modern.goal,
        goalFill       = modern.goalFill,
        goalText       = modern.goalText,
        rule       = Value(1),
        divider    = Value(1),
        common     = modern.common,
        levelTrivial    = Hex("808080"),
        levelEasy       = modern.levelEasy,
        levelFair       = modern.levelFair,
        levelHard       = modern.levelHard,
        levelImpossible = modern.levelImpossible,
        band       = Hex("FFFFFF", 0.035),
        wingFade   = Hex("000000", 0.67),
        wingLine   = Value(0.90),
        groupLit   = Hex("FFFFFF", 0.05),
    }
end

Theme.ReadElvUIMedia = ReadElvUIMedia -- for the smoke tests (tests/smoke)

-- Reads the ElvUI style's palette and font from ElvUI into `skin` (SKINS.elvui).
local function LoadElvUI(skin)
    local media = ReadElvUIMedia()
    palettes.elvui = ElvUIPalette(media)
    skin.fontFace = media.font
    skin.fontFlags, skin.fontShadow = ElvUIFontFlags(media.fontStyle)
end

-- Skins ---------------------------------------------------------------------
-- What makes each skin, one entry per name in Theme.skins:
--   native      true: the game's frame templates; every other skin draws
--               NeedRoll's own flat panels (the code's `not Theme.native` path)
--   corners     "rounded" (NeedRoll's rounded media) or "square" (plain fills
--               and 1px lines, as ElvUI draws)
--   namePrefix  starts the names the game keeps global (its fonts and its
--               window, Theme:WindowName), so each skin's are its own
--   fontFace, fontFlags, fontShadow  its fonts' file for roman text and the
--               client's own alphabet (the game's fonts when unset, see
--               FontMembers), flags, and false to draw them without a drop shadow
--   IsAvailable whether it can be shown now (always, when unset); while it
--               can't, `fallback` shows instead and the saved choice stays
--   Load        reads its palette and font the first time it is used
local SKINS = {
    native = { native = true, corners = "rounded", namePrefix = "Native" },
    modern = { corners = "rounded", namePrefix = "" },
    dark = { corners = "rounded", namePrefix = "Dark" },
    elvui = {
        corners = "square", namePrefix = "ElvUI",
        IsAvailable = function() return ElvUIEngine() ~= nil end, fallback = "dark",
        Load = LoadElvUI,
    },
}

-- Each font's key in its skin's fonts ("title", "body"), by font object,
-- for /nr fontdebug.
Theme.fontKeys = {}

-- Font families ---------------------------------------------------------------
-- Each NeedRoll font is a font family, as the game's own fonts are
-- (Fonts.xml): a member per alphabet, so a character the client's own font
-- lacks comes from another member. The Russian client's font has no "·",
-- which NeedRoll writes between facts; the roman member draws it. A player
-- who switches NeedRoll's language (Settings) gets Cyrillic, Hangul or
-- Chinese text from its member too.

-- The game's file for each alphabet, as Fonts.xml uses them.
local ALPHABET_FILES = {
    { alphabet = "roman", file = "Fonts\\FRIZQT__.TTF" },
    { alphabet = "russian", file = "Fonts\\FRIZQT___CYR.TTF" },
    { alphabet = "korean", file = "Fonts\\2002.TTF" },
    { alphabet = "simplifiedchinese", file = "Fonts\\ARKai_T.ttf" },
    { alphabet = "traditionalchinese", file = "Fonts\\blei00d.TTF" },
}

-- The alphabet each client's own language is written in; roman for the rest.
local CLIENT_ALPHABETS = { ruRU = "russian", koKR = "korean", zhCN = "simplifiedchinese", zhTW = "traditionalchinese" }

-- A family's members, each `height` tall with `flags`. A skin's own `face`
-- (ElvUI's font) draws roman text and the client's own alphabet, so the skin
-- looks as it always has. Without one, the client's alphabet is drawn in
-- STANDARD_TEXT_FONT and every other alphabet in the game's file for it.
local function FontMembers(face, height, flags)
    local clientAlphabet = CLIENT_ALPHABETS[GetLocale()] or "roman"
    local members = {}
    for _, alphabetFile in ipairs(ALPHABET_FILES) do
        local alphabet, file = alphabetFile.alphabet, alphabetFile.file
        if alphabet == clientAlphabet then
            file = face or FONT
        elseif alphabet == "roman" and face then
            file = face
        end
        table.insert(members, { alphabet = alphabet, file = file, height = height, flags = flags })
    end
    return members
end

-- What each of NeedRoll's fonts was made from, by font object: its skin's
-- own face (nil: the game's fonts), size, flags, color and shadow.
-- Theme:ScaledFont makes a bigger or smaller family from it.
local fontRecipes = {}

-- A font family from `recipe`, under the global name `name` (the game keeps
-- a font's name global, so each is made once).
local function FamilyFont(name, recipe)
    local family = CreateFontFamily(name, FontMembers(recipe.face, recipe.size, recipe.flags))
    family:SetTextColor(unpack(recipe.color))
    family:SetShadowColor(0, 0, 0, recipe.shadowAlpha)
    family:SetShadowOffset(recipe.shadowOffset, -recipe.shadowOffset)
    fontRecipes[family] = recipe
    return family
end

-- The skin's own font file, or nil for the game's fonts: also when the game
-- can't load the file (one moved out of ElvUI), which leaves a font with
-- none. It is tried on a plain font first, where a file that fails shows.
local function UsableFace(skin)
    if not skin.fontFace then return nil end
    local probe = CreateFont("NeedRollFontProbe" .. skin.namePrefix)
    probe:SetFont(skin.fontFace, 12, skin.fontFlags or "")
    if not probe:GetFont() then return nil end
    return skin.fontFace
end

-- Every font has a black shadow down and right: the native skin's headings
-- and body text a full one 2px off, the rest a fainter one 1px off, to lift
-- them off the page. Outlined fonts (ElvUI's) have none.
local function MakeFont(skin, face, name, size, color, shadow)
    local recipe = { face = face, size = size, flags = skin.fontFlags or "", color = color,
        shadowAlpha = 0.7, shadowOffset = 1 }
    if skin.fontShadow == false then
        recipe.shadowAlpha, recipe.shadowOffset = 0, 0
    elseif shadow then
        recipe.shadowAlpha, recipe.shadowOffset = 1, 2
    end
    local f = FamilyFont("NeedRollFont" .. skin.namePrefix .. name, recipe)
    Theme.fontKeys[f] = name:lower()
    return f
end

local function BuildFonts(skinName)
    local skin, c = SKINS[skinName], palettes[skinName]
    local face = UsableFace(skin)
    local function Font(name, size, color, shadow)
        return MakeFont(skin, face, name, size, color, shadow)
    end
    if skin.native then
        return {
            title   = Font("Title", 13, c.heading, true),
            heading = Font("Heading", 16, c.heading, true),
            tab     = Font("Tab", 12, c.heading, true),
            body    = Font("Body", 12, c.text, true),
            suffix  = Font("Suffix", 8, c.text, true),  -- 4pt under body, e.g. "(40 players)"
            small   = Font("Small", 10, c.muted),
            source  = Font("Source", 12, c.muted),  -- 2pt over small: where a recipe comes from
            note    = Font("Note", 10, c.note),  -- 2pt under body, e.g. "rare" under a boss
            label   = Font("Label", 11, c.heading, true),
            pane    = Font("Pane", 13.75, c.heading, true),  -- pane labels, faction toggles; 1.25x label
            ruled   = Font("Ruled", 18, c.heading, true),  -- a heading over a rule (Description, Attunement)
            instance = Font("Instance", 22, c.heading, true),  -- a dungeon's or raid's name on its Overview
            factLabel = Font("FactLabel", 16, c.heading, true),  -- Overview stat box label, 4pt over its value
            factValue = Font("FactValue", 12, c.text, true),
            section = Font("Section", 14, c.heading, true),  -- Overview "Alliance quests" headers
            hint    = Font("Hint", 10, c.muted),
        }
    end
    return {
        title   = Font("Title", 15, c.text),
        heading = Font("Heading", 17, c.heading),
        tab     = Font("Tab", 12, c.muted),
        body    = Font("Body", 12, c.text),
        suffix  = Font("Suffix", 8, c.text),  -- 4pt under body, e.g. "(40 players)"
        small   = Font("Small", 10, c.muted),
        source  = Font("Source", 12, c.muted),  -- 2pt over small: where a recipe comes from
        note    = Font("Note", 10, c.note),  -- 2pt under body, e.g. "rare" under a boss
        label   = Font("Label", 10, c.heading),  -- section headers, gold like the loot title
        pane    = Font("Pane", 12.5, c.heading),  -- pane labels, faction toggles; 1.25x label
        ruled   = Font("Ruled", 18, c.heading),  -- a heading over a rule (Description, Attunement)
        instance = Font("Instance", 22, c.heading),  -- a dungeon's or raid's name on its Overview
        factLabel = Font("FactLabel", 16, c.heading),  -- Overview stat box label, 4pt over its value
        factValue = Font("FactValue", 12, c.text),
        section = Font("Section", 13, c.heading),  -- Overview "Alliance quests" headers
        hint    = Font("Hint", 10, c.faint),
    }
end

local fonts = {}

-- `name` if it can be shown now; the skin shown in its place if not (the
-- ElvUI style without ElvUI: dark); native for a name that isn't a skin.
local function ShownSkin(name)
    local skin = SKINS[name]
    if not skin then return "native" end
    if skin.IsAvailable and not skin.IsAvailable() then return skin.fallback end
    return name
end

-- Reads a skin's palette and makes its fonts, the first time it is used.
local function LoadSkin(name)
    local skin = SKINS[name]
    if skin.Load and not palettes[name] then skin.Load(skin) end
    fonts[name] = fonts[name] or BuildFonts(name)
end

-- Switches to skin `name`, or to the one shown in its place while it can't
-- be shown (see ShownSkin); Theme.name is the skin in use.
function Theme:SetSkin(name)
    name = ShownSkin(name)
    LoadSkin(name)
    local skin = SKINS[name]
    self.name = name
    self.native = skin.native == true
    self.corners = skin.corners
    self.color = palettes[name]
    self.font = fonts[name]
end

-- The global name of skin `name`'s main window: "NeedRollFrame" (modern),
-- "NeedRollNativeFrame", "NeedRollDarkFrame" or "NeedRollElvUIFrame". Each
-- window needs its own: Escape finds the window to close by its name.
function Theme.WindowName(_, name)  -- called as Theme:WindowName(name)
    return "NeedRoll" .. SKINS[name].namePrefix .. "Frame"
end

-- Whether skin `name` can be shown now: Settings and /nr style offer only these.
function Theme.IsSkinAvailable(_, name)  -- called as Theme:IsSkinAvailable(name)
    return ShownSkin(name) == name
end

-- The skins that can be shown now, in Theme.skins order.
function Theme:AvailableSkins()
    local names = {}
    for _, name in ipairs(self.skins) do
        if self:IsSkinAvailable(name) then table.insert(names, name) end
    end
    return names
end

Theme:SetSkin("native")

-- `font` (one of NeedRoll's) at `scale` times its size: a family of the same
-- faces, color and shadow, made once per font and scale.
-- Theme.scaledFrom[scaled font] is { font, scale }, for /nr fontdebug.
local scaled = {}
Theme.scaledFrom = {}
local scaledCount = 0
function Theme:ScaledFont(font, scale)
    if scale == 1 then return font end
    scaled[font] = scaled[font] or {}
    local key = math.floor(scale * 1000 + 0.5)
    if not scaled[font][key] then
        scaledCount = scaledCount + 1
        local recipe = {}
        for field, value in pairs(fontRecipes[font]) do recipe[field] = value end
        recipe.size = recipe.size * scale
        local f = FamilyFont("NeedRollScaledFont" .. scaledCount, recipe)
        scaled[font][key] = f
        Theme.scaledFrom[f] = { font, scale }
    end
    return scaled[font][key]
end

-- A skin's colors and fonts without switching to it, for frames that keep
-- one look whatever the window uses (the first-run style picker).
function Theme:Palette(name)
    LoadSkin(name)
    return palettes[name]
end

function Theme:Fonts(name)
    LoadSkin(name)
    return fonts[name]
end

-- Pane and section labels: small caps in the modern skin, as written in
-- the native one ("Instances", like the game's own panel headers).
function Theme:Label(text)
    return self.native and text or text:upper()
end

-- "|cffrrggbb" escape for `color`, for inline colored text.
function Theme:ColorCode(color)
    local function Byte(v) return math.floor(v * 255 + 0.5) end
    return ("|cff%02x%02x%02x"):format(Byte(color[1]), Byte(color[2]), Byte(color[3]))
end

-- Text with its color, link, texture and atlas codes taken out: a link's
-- words as the player reads them.
function Theme:PlainText(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H[^|]*|h", ""):gsub("|h", "")
        :gsub("|T[^|]*|t", ""):gsub("|A[^|]*|a", ""))
end

-- Quest and NPC IDs after their names, for local checkouts only. The
-- CurseForge packager turns the debug block below into a comment.
Theme.showIds = false
--[==[@debug@
Theme.showIds = true
--@end-debug@]==]

-- The dots between the parts of a line of text ("Cloth  ·  Back"; ns.DOT,
-- "∙" where Russian text shows).
Theme.DOTS = "  " .. ns.DOT .. "  "

-- `text`, then Theme.DOTS and `ids` (a number or a list) in the muted color
-- while IDs show; just `text` otherwise or without IDs.
function Theme:WithIds(text, ids)
    if type(ids) ~= "table" then ids = { ids } end
    if not self.showIds or #ids == 0 then return text end
    return text .. self.DOTS .. self:ColorCode(self:Opaque(self.color.muted, self.color.panel2))
        .. table.concat(ids, ", ") .. "|r"
end

-- Joins the parts that aren't nil or empty with dots ("Cloth  ·  Back"), so
-- a lone part gets no dangling dot.
function Theme:JoinDots(...)
    local parts = {}
    for i = 1, select("#", ...) do
        local part = select(i, ...)
        if part and part ~= "" then table.insert(parts, part) end
    end
    return table.concat(parts, self.DOTS)
end

-- `count` written into `one` or `many` ("%d item", "%d items") as it is 1 or not.
function Theme:Plural(count, one, many)
    return (count == 1 and one or many):format(count)
end

-- A see-through color as the solid color it shows over base (the window by
-- default). Inline |c color codes can't lift a font string's own alpha, so a
-- line mixing muted prose with colored links needs its muted color solid.
function Theme:Opaque(color, base)
    local a = color[4] or 1
    if a >= 1 then return color end
    base = base or self.color.bg
    local mixed = { 0, 0, 0, 1 }
    for i = 1, 3 do mixed[i] = color[i] * a + base[i] * (1 - a) end
    return mixed
end

-- An item quality's color as r, g, b: the skin's Common white where it has
-- one (the game's reads as grey on the modern background), else the game's.
function Theme:QualityColor(quality)
    if quality == 1 and self.color.common then  -- Enum.ItemQuality.Common
        return self.color.common[1], self.color.common[2], self.color.common[3]
    end
    local r, g, b = C_Item.GetItemQualityColor(quality)
    if r then return r, g, b end
    return self.color.text[1], self.color.text[2], self.color.text[3]
end

-- Solid color texture filling `parent` (or the given anchors).
function Theme:Fill(parent, color, layer)
    local tex = parent:CreateTexture(nil, layer or "BACKGROUND")
    tex:SetColorTexture(unpack(color))
    tex:SetAllPoints()
    return tex
end

-- 1px line along one edge of `parent`: "TOP", "BOTTOM", "LEFT" or "RIGHT".
function Theme:Edge(parent, side, color)
    local tex = parent:CreateTexture(nil, "BORDER")
    tex:SetColorTexture(unpack(color or self.color.line))
    if side == "TOP" or side == "BOTTOM" then
        tex:SetPoint(side .. "LEFT")
        tex:SetPoint(side .. "RIGHT")
        PixelUtil.SetHeight(tex, 1)
    else
        tex:SetPoint("TOP" .. side)
        tex:SetPoint("BOTTOM" .. side)
        PixelUtil.SetWidth(tex, 1)
    end
    return tex
end

-- Accent line width: 2 UI units rounded UP to whole screen pixels for
-- `region`, so every accent line (selection bar, connector, loot outline)
-- draws the same number of pixels at any UI scale instead of some rounding
-- to 2 and others to 3. Also returns the size of one screen pixel.
Theme.lineWidth = 2

function Theme:LineWidth(region)
    local unit = PixelUtil.GetPixelToUIUnitFactor() / region:GetEffectiveScale()
    return math.ceil(self.lineWidth / unit - 0.01) * unit, unit
end

-- Shows an atlas at its own shape, its longer side `size` long. Radial
-- icons like FullMap-up-c60 aren't square.
function Theme:FitAtlas(tex, atlas, size)
    Theme:KeepLoaded(atlas)
    tex:SetAtlas(atlas)
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
    if info and info.width > 0 and info.height > 0 then
        local scale = size / math.max(info.width, info.height)
        tex:SetSize(info.width * scale, info.height * scale)
    else
        tex:SetSize(size, size)
    end
end

-- Trims the border baked into Blizzard's square icons: 8% off each side.
Theme.iconCrop = { 0.08, 0.92, 0.08, 0.92 }

function Theme:CropIcon(texture)
    texture:SetTexCoord(unpack(self.iconCrop))
end

-- The character frame's round portrait mask: a mask that clips to a circle,
-- or drawn as a texture, a soft-edged disc.
Theme.roundMask = [[Interface\CharacterFrame\TempPortraitAlphaMask]]

-- Clips `texture` (drawn on `owner`) to a circle, hiding an icon's square
-- edge. Returns the mask, which other textures can share.
function Theme:MaskRound(owner, texture)
    local mask = owner:CreateMaskTexture()
    mask:SetTexture(self.roundMask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(texture)
    texture:AddMaskTexture(mask)
    return mask
end

-- A plain icon with no ring around it (a profession's beside its name):
-- clipped round, or left square in a skin with square corners, as ElvUI
-- draws icons. An icon in a ring stays round (Theme:MaskRound).
function Theme:ShapeIcon(owner, texture)
    if self.corners == "square" then return end
    self:MaskRound(owner, texture)
end

local MEDIA = [[Interface\AddOns\NeedRoll\Media\]]
Theme.media = {
    rounded = MEDIA .. "Rounded",
    roundedBorder = MEDIA .. "RoundedBorder",
    roundedBorder2 = MEDIA .. "RoundedBorder2", -- 2px, for the active loot panel
}

-- The client drops an image file once nothing on screen shows it, and
-- loads it again (a frame or two late) when something does. So each time
-- the window opened, art from sheets the game's own UI isn't showing drew
-- blank for a moment: Forever's c60 icons and rings, and in the native
-- style the panes' dark parchment, leaving the window's light marble
-- showing through like a white film. Every atlas sheet and file the window
-- shows keeps one 1px, all but transparent copy shown on UIParent, so it
-- stays loaded: one texture per file, local files only, nothing asked of
-- the server.
local keeper, kept = nil, {}
Theme.kept = kept -- file -> its keeper texture

function Theme:KeepLoaded(atlas, file)
    local info = atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
    local key = file or (info and (info.file or info.filename)) or atlas
    if not key or kept[key] then return end
    if not keeper then
        keeper = CreateFrame("Frame", nil, UIParent)
        keeper:SetFrameStrata("BACKGROUND")
        keeper:SetSize(1, 1)
        keeper:SetPoint("BOTTOMLEFT")
        keeper:SetAlpha(0.01)
        keeper:EnableMouse(false)
    end
    local tex = keeper:CreateTexture(nil, "BACKGROUND")
    tex:SetAllPoints()
    if file then tex:SetTexture(file) else tex:SetAtlas(atlas) end
    kept[key] = tex
end

-- What a texture draws, for KeepLoaded: its atlas, or else its file (a
-- game file ID, or the path of one of NeedRoll's own). Colour fills draw
-- no file and give nothing.
local function DrawnImage(texture)
    local atlas = texture:GetAtlas()
    if atlas then return atlas, nil end
    local fileID = texture:GetTextureFileID()
    if fileID and fileID > 0 then return nil, fileID end
    local path = texture:GetTextureFilePath()
    if type(path) == "string" and path:lower():find("^interface[\\/]") then return nil, path end
    return nil, nil
end

-- Keeps every image under `frame` loaded that would be on screen with
-- `frame` shown: the shown textures of its shown children, all the way down.
-- The main window calls it as it closes, so whatever was on screen draws at
-- once the next time it opens.
function Theme:KeepLoadedUnder(frame)
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsShown() and region:IsObjectType("Texture") then
            local atlas, file = DrawnImage(region)
            if atlas or file then self:KeepLoaded(atlas, file) end
        end
    end
    for _, child in ipairs({ frame:GetChildren() }) do
        if child:IsShown() then self:KeepLoadedUnder(child) end
    end
end

-- What the window shows as soon as it opens, kept from login so even the
-- first open has them (it's built on first open; FitAtlas keeps the rest as
-- they're first used, and closing the window keeps whatever it showed).
local PRELOAD_ATLASES = {
    "GameMenu-up-c60", "Exclamation-up-c60", "AdventureGuide-up-c60",
    "FullMap-up-c60", "Targeting-down-c60", "Mode-Selection-Ring-c60",
    "Mode-Selection-Ring-Disable-c60", "GuildCommunities-up-c60",
    "Legacy-up-c60", "Professions-up-c60", "Bags-up-c60", "Spellbook-up-c60",
    "collections-background-tile", -- the native panes' parchment
}

ns:On("PLAYER_LOGIN", function()
    C_Timer.After(2, function()
        for _, atlas in ipairs(PRELOAD_ATLASES) do Theme:KeepLoaded(atlas) end
        for _, file in pairs(Theme.media) do Theme:KeepLoaded(nil, file) end
    end)
end)

-- White 16px texture stretched as a nine-slice, so the 4px corners keep
-- their size at any frame size; tinted with `color`.
local function SlicedTexture(parent, file, color, layer)
    local tex = parent:CreateTexture(nil, layer)
    tex:SetTexture(file)
    tex:SetTextureSliceMargins(5, 5, 5, 5)
    tex:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    tex:SetVertexColor(unpack(color))
    tex:SetAllPoints()
    return tex
end

-- A fill for `parent` in the skin's corners (`theme` is Theme): the rounded
-- media, or for square corners a plain color. Either takes SetVertexColor.
local function CornerFill(theme, parent, color, layer)
    if theme.corners ~= "square" then return SlicedTexture(parent, theme.media.rounded, color, layer) end
    local tex = parent:CreateTexture(nil, layer)
    tex:SetColorTexture(1, 1, 1, 1)
    tex:SetVertexColor(unpack(color))
    tex:SetAllPoints()
    return tex
end

-- Round-ended bar piece (a standing bar's track or fill): the rounded panel
-- texture sliced at `radius`, half the bar's height, so each end is a half
-- circle. Tint it with SetVertexColor.
function Theme:RoundedBarTexture(parent, layer, radius)
    local tex = parent:CreateTexture(nil, layer)
    tex:SetTexture(self.media.rounded)
    tex:SetTextureSliceMargins(radius, radius, radius, radius)
    tex:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    return tex
end

-- Standing bars on the native skin (the Factions page's and the Factions
-- list's): a dark see-through track, and the fill a little see-through so
-- it sits in the parchment.
Theme.nativeBar = { track = { 0, 0, 0, 0.35 }, fillAlpha = 0.8 }

local function TintOutline(outline, r, g, b, a)
    for _, line in ipairs(outline.lines) do line:SetVertexColor(r, g, b, a) end
end

-- Draws a thick square outline's lines Theme:LineWidth wide: lines 1 and 2
-- run across the top and bottom (Theme:Border's order), 3 and 4 down the sides.
local function FitThickOutline(outline)
    local width = Theme:LineWidth(outline)
    for i, line in ipairs(outline.lines) do
        if i <= 2 then line:SetHeight(width) else line:SetWidth(width) end
    end
end

-- The square corners' outline: Theme:Border's four 1px lines (Theme:LineWidth
-- wide if `thick`) on a frame over `parent`, at its frame level so it stays
-- under the content. It stands in for the rounded outline texture, so it
-- takes SetVertexColor too, tinting all four lines, as well as the frame's
-- own SetShown and SetPoint.
local function SquareOutline(parent, color, thick)
    local outline = CreateFrame("Frame", nil, parent)
    outline:SetAllPoints(parent)
    outline:SetFrameLevel(parent:GetFrameLevel())
    outline.lines = Theme:Border(outline, { 1, 1, 1, 1 })
    outline.SetVertexColor = TintOutline
    outline:SetVertexColor(unpack(color))
    if thick then
        FitThickOutline(outline)
        outline:SetScript("OnShow", FitThickOutline)
    end
    return outline
end

-- A 1px outline for `frame` in the skin's corners (`theme` is Theme): the
-- rounded outline texture, or a SquareOutline.
local function CornerOutline(theme, frame, color)
    if theme.corners == "square" then return SquareOutline(frame, color) end
    return SlicedTexture(frame, theme.media.roundedBorder, color, "BORDER")
end

-- A fill and 1px outline in the skin's corners (named for the rounded
-- ones), drawn on `frame` itself, under its text, for frames that show
-- them only sometimes. Returns both.
function Theme:RoundedOn(frame, fill, border)
    return CornerFill(self, frame, fill, "BACKGROUND"), CornerOutline(self, frame, border)
end

-- Scales the thick border's holder so its 2-texel stroke spans exactly
-- Theme:LineWidth, matching the connector lines that run into it.
local function FitThickBorder(parent)
    local holder = parent.borderHolder
    holder:SetScale(Theme:LineWidth(parent) / Theme.lineWidth)
end

-- A fill with an optional outline (1px, or the accent line width if
-- `thick`) in the skin's corners: rounded, as the name says, or square.
-- parent.bg is the fill, parent.border the outline and, when thick,
-- parent.borderHolder the frame holding it.
function Theme:Rounded(parent, fill, border, thick)
    parent.bg = CornerFill(self, parent, fill, "BACKGROUND")
    if border and self.corners == "square" then
        parent.border = SquareOutline(parent, border, thick)
        if thick then parent.borderHolder = parent.border end
    elseif border and thick then
        local holder = CreateFrame("Frame", nil, parent)
        holder:SetAllPoints(parent)
        holder:SetFrameLevel(parent:GetFrameLevel()) -- under the pane's content
        parent.borderHolder = holder
        parent.border = SlicedTexture(holder, self.media.roundedBorder2, border, "BORDER")
        FitThickBorder(parent)
        parent:HookScript("OnShow", FitThickBorder)
    elseif border then
        parent.border = SlicedTexture(parent, self.media.roundedBorder, border, "BORDER")
    end
end

-- A content pane: a flat panel (the flat skins), or the game's inset frame with
-- its dark bevel over brown parchment (native). The parchment is the
-- Collections window's seamless tile, repeated at its own size, so resizing
-- shows more or less of it instead of stretching it; tinted down to the tone
-- of the Professions recipe list. `kind` is "list" or "loot"; a flat
-- skin's loot pane gets the 2px accent outline.
function Theme:CreatePanel(parent, kind)
    if self.native then
        local pane = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
        pane.Bg:Hide() -- the template's tiled marble
        pane.parchment = pane:CreateTexture(nil, "BACKGROUND", nil, -5)
        pane.parchment:SetAtlas("collections-background-tile")
        pane.parchment:SetHorizTile(true)
        pane.parchment:SetVertTile(true)
        pane.parchment:SetVertexColor(0.55, 0.55, 0.55)
        pane.parchment:SetAllPoints()
        return pane
    end
    local pane = CreateFrame("Frame", nil, parent)
    if kind == "loot" then
        self:Rounded(pane, self.color.panel2, self.color.accent, true)
    else
        self:Rounded(pane, self.color.panel, self.color.edge)
    end
    return pane
end

-- Hides a pane's own backdrop, for a page drawn inside another pane (the
-- content pane, which also draws the strip over the page).
function Theme:Unframe(pane)
    for _, key in ipairs({ "bg", "borderHolder", "border", "parchment", "NineSlice", "Bg" }) do
        if pane[key] then pane[key]:Hide() end
    end
end

-- The strip across the top of a content pane, inside its outline: a fill
-- (rounded at the top in the rounded skins; the clip cuts off its lower corners) and a
-- line along its bottom. Hidden until shown.
function Theme:PaneStrip(pane, height)
    local colors = self.color
    local inset = self.native and 3 or 2
    local strip = CreateFrame("Frame", nil, pane)
    strip:SetPoint("TOPLEFT", inset, -inset)
    strip:SetPoint("TOPRIGHT", -inset, -inset)
    strip:SetHeight(height - inset)
    strip:SetClipsChildren(true)
    if self.native then
        self:Fill(strip, colors.strip)
    else
        local fill = CornerFill(self, strip, colors.strip, "BACKGROUND")
        fill:ClearAllPoints()
        fill:SetPoint("TOPLEFT")
        fill:SetPoint("BOTTOMRIGHT", 0, -8)
    end
    self:Edge(strip, "BOTTOM", colors.stripLine)
    strip:Hide()
    return strip
end

-- An outlined pill button for the strip: a thin gold outline, a small
-- stroke symbol ("back", "plus", "close" or nil for none) and a gold
-- label, filled on hover. pill:SetLabel(text) sizes it to fit; pill:SetTone(color) recolors
-- it (nil for gold), as Clear list does while it waits for a second click.
local PILL_HEIGHT = 20
local PILL_SYMBOLS = {
    back = { { 6, 45, -1, 1.8 }, { 6, -45, -1, -1.8 } },
    plus = { { 8, 0, 0, 0 }, { 8, 90, 0, 0 } },
    close = { { 8, 45, 0, 0 }, { 8, -45, 0, 0 } },
}

-- Draws `symbol` (a PILL_SYMBOLS key) on `owner` as white strokes centred
-- `x` px right of its `point`; returns them for the caller to tint.
local function SymbolStrokes(owner, symbol, point, x)
    local strokes = {}
    for i, spec in ipairs(PILL_SYMBOLS[symbol] or {}) do
        local line = owner:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(1, 1, 1, 1)
        line:SetSize(spec[1], 1.5)
        line:SetPoint("CENTER", owner, point, x + spec[3], spec[4])
        line:SetRotation(math.rad(spec[2]))
        strokes[i] = line
    end
    return strokes
end

function Theme:Pill(parent, symbol)
    local colors = self.color
    local pill = CreateFrame("Button", nil, parent)
    pill:SetHeight(PILL_HEIGHT)
    pill.fill = CornerFill(self, pill, colors.pillFill, "BACKGROUND")
    pill.fill:Hide()
    pill.edge = CornerOutline(self, pill, colors.pillEdge)
    pill.text = self:Text(pill, self.font.body)
    pill.text:SetPoint("LEFT", symbol and 20 or 12, 0)
    local padding = symbol and 30 or 24
    local strokes = SymbolStrokes(pill, symbol, "LEFT", 11)
    function pill:Paint()
        local tone = self.tone or colors.heading
        local edge = self.tone or colors.pillEdge
        self.fill:SetShown(self.hover or self.tone ~= nil)
        self.fill:SetVertexColor(tone[1], tone[2], tone[3], self.tone and 0.18 or colors.pillFill[4] or 1)
        self.edge:SetVertexColor(edge[1], edge[2], edge[3], self.hover and 1 or edge[4] or 1)
        for _, line in ipairs(strokes) do line:SetVertexColor(tone[1], tone[2], tone[3], 1) end
        Theme:SetTextColor(self.text, tone)
    end
    function pill:SetLabel(text)
        self.text:SetText(text)
        self:SetWidth(math.ceil(self.text:GetStringWidth()) + padding)
    end
    function pill:SetTone(color)
        self.tone = color
        self:Paint()
    end
    pill:SetScript("OnEnter", function(self) self.hover = true; self:Paint() end)
    pill:SetScript("OnLeave", function(self) self.hover = nil; self:Paint() end)
    pill:Paint()
    return pill
end

-- A pill in the Native style, whatever style NeedRoll's window uses: for
-- NeedRoll's buttons in the game's own windows (the quest log, the world
-- map), which look like the game's around them. A pill keeps the colors and
-- font it was made with, so the style is switched to Native only while it is
-- made, and a later change of style leaves it as it is.
function Theme:NativePill(parent, symbol)
    local skinInUse = self.name
    self:SetSkin("native")
    local pill = self:Pill(parent, symbol)
    self:SetSkin(skinInUse)
    return pill
end

-- A pill that asks once before it acts, as "Clear list" does: the first
-- click turns it red and shows `confirmLabel` for CONFIRM_SECONDS, or until
-- it is hidden; a second click in that time calls `onConfirm`.
local CONFIRM_SECONDS = 3

function Theme:ConfirmPill(parent, symbol, label, confirmLabel, onConfirm)
    local pill = self:Pill(parent, symbol)
    local function Reset()
        pill.armed = nil
        pill:SetLabel(label)
        pill:SetTone(nil)
    end
    pill:SetScript("OnClick", function()
        if pill.armed then
            Reset()
            onConfirm()
            return
        end
        pill.armed = true
        pill:SetLabel(confirmLabel)
        pill:SetTone(Theme.color.incomplete)
        -- Only this click's timer resets it, not one left from an earlier click.
        local token = {}
        pill.token = token
        C_Timer.After(CONFIRM_SECONDS, function()
            if pill.token == token and pill.armed then Reset() end
        end)
    end)
    pill:SetScript("OnHide", Reset)
    Reset()
    return pill
end

-- A tick box with `label` beside it, at its right (or at its left when
-- `labelSide` is "LEFT"): a box in the skin's corners that fills with the
-- accent and shows a tick (the flat skins), or the game's check button (native). Clicking the box or its
-- label ticks or unticks it and calls `onClick(on)`; box:Set(on) sets it
-- without a call, box:IsOn() reads it and box:FullWidth() is the box and
-- its label together. box:SetMarkMuted(true) greys the tick out, for a box
-- with a half step (the recipe list's Learnable): the game's gold tick
-- desaturated, or the flat skins' tick in `muted` with no accent fill.
local CHECK_STROKES = { { 4, -45, -2, -1 }, { 7, 45, 1, 0.5 } } -- the tick: length, angle, x, y

function Theme:CheckBox(parent, label, onClick, labelSide)
    local native = self.native
    local box
    if native then
        box = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        box:SetSize(22, 22)
        function box:Set(on) self:SetChecked(on) end
        function box:IsOn() return self:GetChecked() and true or false end
        function box:SetMarkMuted(muted) self:GetCheckedTexture():SetDesaturated(muted) end
    else
        box = CreateFrame("Button", nil, parent)
        box:SetSize(14, 14)
        self:Rounded(box, self.color.accent, self.color.muted)
        local strokes = {}
        for i, spec in ipairs(CHECK_STROKES) do
            local line = box:CreateTexture(nil, "ARTWORK")
            line:SetColorTexture(unpack(self.color.text))
            line:SetSize(spec[1], 1.5)
            line:SetPoint("CENTER", spec[3], spec[4])
            line:SetRotation(math.rad(spec[2]))
            strokes[i] = line
        end
        function box:Set(on)
            self.checked = on and true or false
            self.bg:SetShown(self.checked and not self.markMuted)
            self.border:SetVertexColor(unpack(self.checked and Theme.color.accent or Theme.color.muted))
            for _, line in ipairs(strokes) do
                line:SetColorTexture(unpack(self.markMuted and Theme.color.muted or Theme.color.text))
                line:SetShown(self.checked)
            end
        end
        function box:IsOn() return self.checked end
        function box:SetMarkMuted(muted)
            self.markMuted = muted
            self:Set(self.checked)
        end
    end
    box:SetScript("OnClick", function()
        -- The native check button has already ticked or unticked itself.
        if not native then box:Set(not box.checked) end
        if onClick then onClick(box:IsOn()) end
    end)
    box.label = self:Text(box, self.font.small)
    box.label:SetText(label)
    self:SetTextColor(box.label, self.color.muted)
    local gap, lift = native and 2 or 6, native and 1 or 0
    -- The label is part of the button, so clicking the words works too.
    local labelRoom = -(box.label:GetStringWidth() + 8)
    if labelSide == "LEFT" then
        box.label:SetPoint("RIGHT", box, "LEFT", -gap, lift)
        box:SetHitRectInsets(labelRoom, 0, -3, -3)
    else
        box.label:SetPoint("LEFT", box, "RIGHT", gap, lift)
        box:SetHitRectInsets(0, labelRoom, -3, -3)
    end
    function box:FullWidth() return self:GetWidth() + gap + self.label:GetStringWidth() end
    box:Set(false)
    return box
end

local CARD_CORNER = 5        -- a recipe card's rounded left corners (the Rounded media's slice)
local CARD_FILL_MID = 0.35  -- its fill fades to its mid tone by here,
local CARD_EDGE_SOLID = 0.12 -- its top and bottom edges are solid out to here,
local CARD_EDGE_END = 0.8   -- then fade out by here
local CARD_EDGE_LIFT = 6    -- its outline's frame sits this far above the box, over the
                            -- loot grid's cells and their buttons, so they scroll beneath it

-- Backdrop for a recipe page's boxed section (Creates, Learned from,
-- Materials): the dungeon active-section card turned on its side. A fill
-- fading from dark at the left to clear, and a rounded outline crisp down
-- the left edge whose top and bottom edges fade out to the right.
-- `zoomed` is a frame drawn smaller (the loot grid's canvas): the card is
-- drawn at full size inside it, since its 1px lines shrunk below a pixel
-- vanish at some positions. box:FitCard() follows a change in its scale.
-- With square corners the corner slices are cut from the media's straight
-- left edge instead, and the top and bottom edges run from the left edge.
function Theme:CardBackdrop(box, zoomed)
    local colors = self.color
    local corner = CARD_CORNER
    local scale = corner / 16
    local isSquare = self.corners == "square"
    local edgeStart = isSquare and 0 or corner  -- where the top and bottom edges start
    local holder = CreateFrame("Frame", nil, box)
    holder:SetAllPoints(box)
    holder:SetFrameLevel(box:GetFrameLevel())
    -- The outline is drawn over what the box holds: a box scrolled partly
    -- out of view keeps its top edge pinned, and the icons pass under it.
    local outline = CreateFrame("Frame", nil, holder)
    outline:SetAllPoints(holder)
    outline:SetFrameLevel(box:GetFrameLevel() + CARD_EDGE_LIFT)
    local function Clear(color)
        return CreateColor(color[1], color[2], color[3], 0)
    end
    local function Solid(color)
        return CreateColor(color[1], color[2], color[3], color[4] or 1)
    end
    -- The media's left column: top corner, edge, bottom corner (all three
    -- the edge for square corners).
    local rows = { { 0, scale }, { scale, 1 - scale }, { 1 - scale, 1 } }
    if isSquare then rows = { rows[2], rows[2], rows[2] } end
    local function Slices(parent, file, layer, color)
        local pieces = {}
        for i, coords in ipairs(rows) do
            local tex = parent:CreateTexture(nil, layer)
            tex:SetTexture(file)
            tex:SetTexCoord(0, scale, coords[1], coords[2])
            tex:SetVertexColor(unpack(color))
            tex:SetWidth(corner)
            pieces[i] = tex
        end
        pieces[1]:SetPoint("TOPLEFT")
        pieces[1]:SetHeight(corner)
        pieces[3]:SetPoint("BOTTOMLEFT")
        pieces[3]:SetHeight(corner)
        pieces[2]:SetPoint("TOPLEFT", pieces[1], "BOTTOMLEFT")
        pieces[2]:SetPoint("BOTTOMLEFT", pieces[3], "TOPLEFT")
        return pieces
    end
    local fillLeft = Slices(holder, self.media.rounded, "BACKGROUND", colors.cardFill)
    Slices(outline, self.media.roundedBorder, "BORDER", colors.sectionEdge)
    local function Plain(layer)
        local tex = holder:CreateTexture(nil, layer)
        tex:SetColorTexture(1, 1, 1, 1)
        return tex
    end
    local fillInner, fillOuter = Plain("BACKGROUND"), Plain("BACKGROUND")
    fillInner:SetPoint("TOPLEFT", fillLeft[1], "TOPRIGHT")
    fillInner:SetPoint("BOTTOMLEFT", fillLeft[3], "BOTTOMRIGHT")
    fillInner:SetGradient("HORIZONTAL", Solid(colors.cardFill), Solid(colors.cardFillMid))
    fillOuter:SetPoint("TOPLEFT", fillInner, "TOPRIGHT")
    fillOuter:SetPoint("BOTTOMRIGHT")
    fillOuter:SetGradient("HORIZONTAL", Solid(colors.cardFillMid), Clear(colors.cardFillMid))
    -- The top and bottom edges are the media's straight edge slices, as
    -- tall as a corner, like the left edge: a 1px plain line could round
    -- away to nothing at some scroll positions.
    local edges = {}
    for i, side in ipairs({ "TOP", "BOTTOM" }) do
        local top, bottom = 0, scale
        if side == "BOTTOM" then top, bottom = 1 - scale, 1 end
        local function Edge()
            local tex = outline:CreateTexture(nil, "BORDER")
            tex:SetTexture(self.media.roundedBorder)
            tex:SetTexCoord(scale, 1 - scale, top, bottom)
            tex:SetHeight(corner)
            return tex
        end
        local solid, fade = Edge(), Edge()
        solid:SetPoint(side .. "LEFT", edgeStart, 0)
        solid:SetVertexColor(unpack(colors.sectionEdge))
        fade:SetPoint(side .. "LEFT", solid, side .. "RIGHT")
        fade:SetGradient("HORIZONTAL", Solid(colors.sectionEdge), Clear(colors.sectionEdge))
        edges[i] = { solid = solid, fade = fade }
    end
    -- The fades are fractions of the box's width, which changes with the pane.
    local function Fit()
        local width = holder:GetWidth()
        local solid = math.max(corner, width * CARD_EDGE_SOLID)
        fillInner:SetWidth(math.max(0.01, math.max(corner, width * CARD_FILL_MID) - corner))
        for _, edge in ipairs(edges) do
            edge.solid:SetWidth(math.max(0.01, solid - edgeStart))
            edge.fade:SetWidth(math.max(0.01, math.max(solid, width * CARD_EDGE_END) - solid))
        end
    end
    holder:SetScript("OnSizeChanged", Fit)
    function box:FitCard()
        local zoom = zoomed and zoomed:GetScale() or 1
        if holder:GetScale() ~= 1 / zoom then holder:SetScale(1 / zoom) end
        Fit()
    end
    box:FitCard()
end

-- The card upright: a rounded outline crisp across the top, its sides solid
-- down to `edgeSolid` of its height and faded out by `edgeEnd`, over a fill
-- fading from sectionFill at the top to clear. A dungeon list's active
-- section sits in one (UI/Lists.lua), and each talent tree has its outline
-- alone (UI/TalentPlanner.lua). A `closed` card (a dungeon's Overview row)
-- has its whole outline, unfaded, bottom edge too. The textures go on
-- `parent` and stay hidden until card:Draw places them. `options`: noFill
-- (the outline alone), edgeSolid and edgeEnd (fractions of the height).
-- With square corners the corner slices are cut from the media's straight
-- top and bottom edges, and the sides run the whole height.
function Theme:SectionCard(parent, options)
    options = options or {}
    local card = {
        all = {},
        edgeSolid = options.edgeSolid or CARD_EDGE_SOLID,
        edgeEnd = options.edgeEnd or CARD_EDGE_END,
        hasFill = not options.noFill,
        isSquare = self.corners == "square",
    }
    local function Add(tex)
        table.insert(card.all, tex)
        tex:Hide()
        return tex
    end
    local function Plain(layer)
        local tex = Add(parent:CreateTexture(nil, layer))
        tex:SetColorTexture(1, 1, 1, 1)
        return tex
    end
    local cornerFraction = CARD_CORNER / 16
    local edge = 1 - cornerFraction
    local sliceColumns = { { 0, cornerFraction }, { cornerFraction, edge }, { edge, 1 } }
    if card.isSquare then sliceColumns = { sliceColumns[2], sliceColumns[2], sliceColumns[2] } end
    -- A row of slices: the media's top edge, or (`bottom`) its bottom edge.
    local function Slices(file, layer, bottom)
        local coordTop, coordBottom = 0, cornerFraction
        if bottom then coordTop, coordBottom = 1 - cornerFraction, 1 end
        local pieces = {}
        for i, coords in ipairs(sliceColumns) do
            pieces[i] = Add(parent:CreateTexture(nil, layer))
            pieces[i]:SetTexture(file)
            pieces[i]:SetTexCoord(coords[1], coords[2], coordTop, coordBottom)
        end
        return pieces
    end
    card.fillTop = Slices(self.media.rounded, "BACKGROUND")
    card.edgeTop = Slices(self.media.roundedBorder, "BORDER")
    card.edgeBottom = Slices(self.media.roundedBorder, "BORDER", true)
    card.fillUpper, card.fillLower = Plain("BACKGROUND"), Plain("BACKGROUND")
    card.sides = {}
    for i = 1, 2 do card.sides[i] = { solid = Plain("BORDER"), fade = Plain("BORDER") } end

    local function Fade(tex, top, bottom)
        tex:SetGradient("VERTICAL", CreateColor(unpack(bottom)), CreateColor(unpack(top)))
    end
    local function Transparent(color)
        return { color[1], color[2], color[3], 0 }
    end

    -- Lays the card out `width` by `height`, its top left corner `left`
    -- right of and `top` below `anchor`'s.
    function card.Draw(_, anchor, left, top, width, height, closed)
        local function PlaceAt(tex, x, y, w, h)
            tex:ClearAllPoints()
            tex:SetPoint("TOPLEFT", anchor, "TOPLEFT", left + x, -(top + y))
            tex:SetSize(math.max(w, 0.01), math.max(h, 0.01))
        end
        local colors = Theme.color
        local corner = CARD_CORNER
        local sliceRows = {
            { card.fillTop, colors.sectionFill, 0 },
            { card.edgeTop, colors.sectionEdge, 0 },
            { card.edgeBottom, colors.sectionEdge, height - corner },
        }
        for _, sliceRow in ipairs(sliceRows) do
            local pieces, color, y = sliceRow[1], sliceRow[2], sliceRow[3]
            PlaceAt(pieces[1], 0, y, corner, corner)
            PlaceAt(pieces[2], corner, y, width - corner * 2, corner)
            PlaceAt(pieces[3], width - corner, y, corner, corner)
            for _, tex in ipairs(pieces) do tex:SetVertexColor(unpack(color)) end
        end
        local middle = math.max(corner, height * CARD_FILL_MID)
        PlaceAt(card.fillUpper, 0, corner, width, middle - corner)
        Fade(card.fillUpper, colors.sectionFill, colors.sectionFillMid)
        PlaceAt(card.fillLower, 0, middle, width, height - middle)
        Fade(card.fillLower, colors.sectionFillMid, Transparent(colors.sectionFillMid))
        -- Rounded corners draw the sides' top (and a closed card's bottom) `corner`.
        local sideInset = card.isSquare and 0 or corner
        local solid = math.max(corner, closed and height - sideInset or height * card.edgeSolid)
        local fadeEnd = closed and solid or math.max(solid, height * card.edgeEnd)
        for i, side in ipairs(card.sides) do
            local x = i == 1 and 0 or width - 1
            PlaceAt(side.solid, x, sideInset, 1, solid - sideInset)
            Fade(side.solid, colors.sectionEdge, colors.sectionEdge)
            PlaceAt(side.fade, x, solid, 1, fadeEnd - solid)
            Fade(side.fade, colors.sectionEdge, Transparent(colors.sectionEdge))
        end
        for _, tex in ipairs(card.all) do tex:Show() end
        for _, tex in ipairs(card.edgeBottom) do tex:SetShown(closed) end
        if card.hasFill then return end
        for _, tex in ipairs(card.fillTop) do tex:Hide() end
        card.fillUpper:Hide()
        card.fillLower:Hide()
    end

    function card.Hide()
        for _, tex in ipairs(card.all) do tex:Hide() end
    end
    return card
end

-- Backdrop for a small stat box such as the Overview's "Level range": a
-- rounded fill (modern), or a soft shadow fading out to the right with a
-- thin gold rule on its left edge, so it reads as part of the parchment
-- rather than a box cut into it (native).
function Theme:StatBackdrop(box)
    if not self.native then
        self:Rounded(box, self.color.factFill)
        return
    end
    local wash = box:CreateTexture(nil, "BACKGROUND")
    wash:SetColorTexture(1, 1, 1, 1)
    wash:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 0.28), CreateColor(0, 0, 0, 0))
    wash:SetAllPoints()
    local rule = box:CreateTexture(nil, "BORDER")
    local gold = self.color.heading
    rule:SetColorTexture(gold[1], gold[2], gold[3], 0.45)
    rule:SetPoint("TOPLEFT", 0, -4)
    rule:SetPoint("BOTTOMLEFT", 0, 4)
    rule:SetWidth(1)
end

-- 1px border on all four sides; returns its four lines.
function Theme:Border(parent, color)
    local edges = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        table.insert(edges, self:Edge(parent, side, color))
    end
    return edges
end

-- A dashed 1px outline round `frame` (an optional quest's card, a "Pick
-- one" box, a breadcrumb's chip on the questline page), in `color` (else
-- the pills' gold outline, pillEdge); the game has no dashed line, so it is
-- dashes of plain colour. Each corner is left `cornerGap` clear, which
-- reads as a rounded corner. Its dashes are laid out by :Fit() once the
-- frame has its size; it takes SetVertexColor, SetShown and IsShown like
-- the solid outlines.
local DASH_LENGTH, DASH_GAP = 4, 3

local function FitDashes(outline)
    local frame, used = outline.frame, 0
    local width, height = frame:GetSize()
    local gap = outline.cornerGap
    local function Dash(point, x, y, w, h)
        used = used + 1
        local dash = outline.dashes[used] or frame:CreateTexture(nil, "BORDER")
        outline.dashes[used] = dash
        dash:SetColorTexture(1, 1, 1, 1)
        dash:SetVertexColor(unpack(outline.color))
        dash:ClearAllPoints()
        dash:SetPoint(point, frame, point, x, y)
        PixelUtil.SetSize(dash, w, h)
        dash:SetShown(outline.shown)
    end
    for offset = gap, width - gap - 1, DASH_LENGTH + DASH_GAP do
        local length = math.min(DASH_LENGTH, width - gap - offset)
        Dash("TOPLEFT", offset, 0, length, 1)
        Dash("BOTTOMLEFT", offset, 0, length, 1)
    end
    for offset = gap, height - gap - 1, DASH_LENGTH + DASH_GAP do
        local length = math.min(DASH_LENGTH, height - gap - offset)
        Dash("TOPLEFT", 0, -offset, 1, length)
        Dash("TOPRIGHT", 0, -offset, 1, length)
    end
    for index = used + 1, #outline.dashes do outline.dashes[index]:Hide() end
    outline.used = used
end

local function SetDashesColor(outline, r, g, b, a)
    outline.color = { r, g, b, a or 1 }
    for index = 1, outline.used do outline.dashes[index]:SetVertexColor(r, g, b, a or 1) end
end

local function SetDashesShown(outline, shown)
    outline.shown = shown == true
    for index = 1, outline.used do outline.dashes[index]:SetShown(outline.shown) end
end

local function AreDashesShown(outline)
    return outline.shown
end

function Theme:DashedOutline(frame, color, cornerGap)
    return { frame = frame, color = color or self.color.pillEdge, cornerGap = cornerGap or 4, dashes = {}, used = 0,
        shown = true, Fit = FitDashes, SetVertexColor = SetDashesColor, SetShown = SetDashesShown,
        IsShown = AreDashesShown }
end

-- A soft glow round `frame`: a rounded fill in `color` reaching `reach`
-- past each of its edges, under everything the frame draws (the goal card
-- of a dungeon's questline). Textures draw past their frame's edges, so
-- the glow needs no frame of its own.
function Theme:Glow(frame, color, reach)
    local glow = CornerFill(self, frame, color, "BACKGROUND")
    glow:SetDrawLayer("BACKGROUND", -8)
    glow:ClearAllPoints()
    glow:SetPoint("TOPLEFT", -reach, reach)
    glow:SetPoint("BOTTOMRIGHT", reach, -reach)
    return glow
end

-- The purple portal that marks a questline's goal (a step done inside the
-- dungeon whose questline it is) on its page, its fold and the quest page.
Theme.portalAtlas = "PortalPurple"
Theme.portalMark = ("|A:%s:0:0|a"):format(Theme.portalAtlas) -- in a line of text, as tall as the text

-- A chip's underline (the recipe chips, the map's floor tabs, Settings):
-- as wide as `text`, 1.5 under it, solid across its middle 40% and fading
-- out over the 30% at each end. Returns its three parts (left fade, solid,
-- right fade) with :Set(color, alpha, thick) and :Hide().
local UNDERLINE_SOLID = 0.4
function Theme:ChipUnderline(owner, text)
    local parts = {}
    for i = 1, 3 do
        local part = owner:CreateTexture(nil, "ARTWORK")
        part:SetColorTexture(1, 1, 1, 1)
        part:Hide()
        parts[i] = part
    end
    parts[2]:SetPoint("TOP", text, "BOTTOM", 0, -1.5)
    parts[1]:SetPoint("TOPRIGHT", parts[2], "TOPLEFT")
    parts[3]:SetPoint("TOPLEFT", parts[2], "TOPRIGHT")
    function parts:Set(color, alpha, thick)
        local width = math.max(2, text:GetStringWidth())
        local solid, clear = CreateColor(color[1], color[2], color[3], alpha), CreateColor(color[1], color[2], color[3], 0)
        local fade = width * (1 - UNDERLINE_SOLID) / 2
        self[1]:SetSize(fade, thick)
        self[2]:SetSize(width * UNDERLINE_SOLID, thick)
        self[3]:SetSize(fade, thick)
        self[1]:SetGradient("HORIZONTAL", clear, solid)
        self[2]:SetVertexColor(color[1], color[2], color[3], alpha)
        self[3]:SetGradient("HORIZONTAL", solid, clear)
        for i = 1, 3 do self[i]:SetShown(alpha > 0) end
    end
    function parts:Hide()
        for i = 1, 3 do self[i]:Hide() end
    end
    return parts
end

-- The thin rule between a page's sections (under the recipe list's
-- chips, between the pet pages' and the class Overview's sections): 1 high,
-- the skin's `divider` (gold `FFD100`; ElvUI's value color) at 35% in its
-- middle, fading out to both ends. A frame of its own, which the caller
-- places and sizes; it takes no mouse.
local DIVIDER_ALPHA = 0.35
function Theme:Divider(parent)
    local divider = CreateFrame("Frame", nil, parent)
    divider:SetHeight(1)
    local r, g, b = unpack(self.color.divider)
    local middle, clear = CreateColor(r, g, b, DIVIDER_ALPHA), CreateColor(r, g, b, 0)
    local left = divider:CreateTexture(nil, "ARTWORK")
    left:SetColorTexture(1, 1, 1, 1)
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMRIGHT", divider, "BOTTOM")
    left:SetGradient("HORIZONTAL", clear, middle)
    local right = divider:CreateTexture(nil, "ARTWORK")
    right:SetColorTexture(1, 1, 1, 1)
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMLEFT", divider, "BOTTOM")
    right:SetGradient("HORIZONTAL", middle, clear)
    return divider
end

function Theme:Text(parent, font, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFontObject(font)
    fs:SetWordWrap(false)
    return fs
end

-- How tall one line of `fs` is, in whole units: for a frame hung from the
-- page by a measured offset instead of from a text above it. A frame that
-- holds a map link's secure button can't be anchored, through any chain, to
-- a text or texture ("Cannot anchor protected frames to regions").
function Theme:LineHeight(fs)
    local _, size = fs:GetFont()
    return math.ceil(size or 0)
end

function Theme:SetTextColor(fs, color)
    fs:SetTextColor(color[1], color[2], color[3], color[4])
end

-- A one-line text box: filled with `input` in the skin's corners (the flat
-- skins), or the game's input box (native).
function Theme:Input(parent, width)
    local box
    if Theme.native then
        box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        box:SetSize(width - 8, 22)
    else
        box = CreateFrame("EditBox", nil, parent)
        box:SetSize(width, 24)
        box:SetFontObject(Theme.font.body)
        box:SetTextInsets(8, 8, 0, 0)
        Theme:Rounded(box, Theme.color.input, Theme.color.inputEdge)
    end
    box:SetAutoFocus(false)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    return box
end

-- A read-only box holding `url`, for the player to copy with Ctrl+C: addons
-- can't open a browser. Typing in it puts the address back, and focusing it
-- selects the whole address. box:Select() focuses and selects it.
-- `onCopy`, if given, runs when Ctrl+C is pressed in it.
function Theme:LinkBox(parent, width, url, onCopy)
    local box = Theme:Input(parent, width)
    box:SetText(url)
    function box.Select()
        box:SetText(url)
        box:SetFocus()
        box:HighlightText()
    end
    box:SetScript("OnTextChanged", function(_, byPlayer)
        if byPlayer and box:GetText() ~= url then box:Select() end
    end)
    box:SetScript("OnEditFocusGained", function() box:HighlightText() end)
    box:SetScript("OnKeyDown", function(_, key)
        if onCopy and key == "C" and IsControlKeyDown() then onCopy() end
    end)
    return box
end

-- Escape frames (Theme:OnEscape). Out of combat one passes on every key but
-- Escape. The game won't let a frame change which keys it passes on in
-- combat, so as combat starts (PLAYER_REGEN_DISABLED comes just before the
-- lockdown) every one is set to pass all keys: one left holding keys after
-- its last Escape would otherwise keep every key from the game while it
-- shows in combat. There Escape reaches the game too. A frame made in
-- combat can't be set up yet, so it takes no keys until combat ends.
local escapeFrames, escapeFramesWaiting = {}, {}

local function ListenForEscape(frame)
    frame:EnableKeyboard(true)
    frame:SetPropagateKeyboardInput(true)
    table.insert(escapeFrames, frame)
end

ns:On("PLAYER_REGEN_DISABLED", function()
    if InCombatLockdown() then return end
    for _, frame in ipairs(escapeFrames) do frame:SetPropagateKeyboardInput(true) end
end)

ns:On("PLAYER_REGEN_ENABLED", function()
    for _, frame in ipairs(escapeFramesWaiting) do ListenForEscape(frame) end
    escapeFramesWaiting = {}
end)

-- Escape, while `frame` shows, runs `onEscape` and goes no further; every
-- other key goes on to the game (see escapeFrames for combat).
function Theme:OnEscape(frame, onEscape)
    frame:SetScript("OnKeyDown", function(_, key)
        if not InCombatLockdown() then frame:SetPropagateKeyboardInput(key ~= "ESCAPE") end
        if key == "ESCAPE" then onEscape() end
    end)
    if InCombatLockdown() then
        table.insert(escapeFramesWaiting, frame)
    else
        ListenForEscape(frame)
    end
end

-- The modern search box's room on the right for its typed text, clear of
-- the cross. (The native template keeps 20 for its own clear button.)
Theme.SEARCH_TEXT_RIGHT = 22

-- Empties a search box and leaves it, as Escape and the clear cross do.
local function ClearSearch(box)
    box:SetText("")
    box:ClearFocus()
end

-- Escape empties a search box and leaves it; Enter just leaves it.
local function SetSearchKeys(box)
    box:SetScript("OnEscapePressed", ClearSearch)
    box:SetScript("OnEnterPressed", box.ClearFocus)
end

-- The game's search box (magnifier, grey instructions, clear button).
local function NativeSearchBox(parent, hintText, width, onChange, onFocus)
    local box = CreateFrame("EditBox", nil, parent, "SearchBoxTemplate")
    box:SetSize(width, 20)
    box.Instructions:SetText(hintText)
    SetSearchKeys(box)
    box:HookScript("OnTextChanged", function(self)
        if not self.quiet then onChange(strtrim(self:GetText())) end
    end)
    if onFocus then box:HookScript("OnEditFocusGained", onFocus) end
    return box
end

local SEARCH_CLEAR_SIZE = 14

-- The modern search box's clear button: a cross in `colors.muted` inside
-- its right end, shown while there is text, as the game's own search box
-- has one. Named clearButton as the game's template names its own.
local function AddClearButton(box, colors)
    local clear = CreateFrame("Button", nil, box)
    clear:SetSize(SEARCH_CLEAR_SIZE, SEARCH_CLEAR_SIZE)
    clear:SetPoint("RIGHT", -5, 0)
    local strokes = SymbolStrokes(clear, "close", "CENTER", 0)
    local function Tint(color)
        for _, line in ipairs(strokes) do line:SetVertexColor(color[1], color[2], color[3], 1) end
    end
    clear:SetScript("OnEnter", function() Tint(colors.heading) end)
    clear:SetScript("OnLeave", function() Tint(colors.muted) end)
    clear:SetScript("OnClick", function() ClearSearch(box) end)
    Tint(colors.muted)
    clear:Hide()
    box.clearButton = clear
end

-- A search box `width` wide with `hintText` in it while empty: the game's
-- own (native) or a filled one in the skin's corners with a magnifier and
-- a clear button (the flat skins). It takes the addon's skin unless `skin` names one, as the
-- debug windows do to stay modern. `onChange(text)` gets the trimmed text as
-- it is typed, and `onFocus`, if given, runs when the box is clicked into.
-- Escape clears it. Text set with Theme:SetSearchTextQuietly (box.quiet) doesn't call onChange.
function Theme:SearchBox(parent, hintText, width, onChange, onFocus, skin)
    skin = skin or self.name
    if skin == "native" then return NativeSearchBox(parent, hintText, width, onChange, onFocus) end
    local colors, skinFonts = self:Palette(skin), self:Fonts(skin)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetSize(width, 24)
    box:SetAutoFocus(false)
    box:SetFontObject(skinFonts.body)
    box:SetTextInsets(26, Theme.SEARCH_TEXT_RIGHT, 0, 0)
    self:Rounded(box, colors.input, colors.inputEdge)
    local icon = box:CreateTexture(nil, "ARTWORK")
    icon:SetAtlas("common-search-magnifyingglass")
    icon:SetSize(12, 12)
    icon:SetPoint("LEFT", 9, 0)
    icon:SetVertexColor(unpack(colors.muted))
    local hint = self:Text(box, skinFonts.small)
    hint:SetPoint("LEFT", 26, 0)
    hint:SetText(hintText)
    box.icon, box.hint = icon, hint
    AddClearButton(box, colors)
    SetSearchKeys(box)
    box:SetScript("OnTextChanged", function(editBox)
        local text = strtrim(editBox:GetText())
        hint:SetShown(text == "" and not editBox:HasFocus())
        editBox.clearButton:SetShown(editBox:GetText() ~= "")
        if not editBox.quiet then onChange(text) end
    end)
    box:SetScript("OnEditFocusGained", function(editBox)
        hint:Hide()
        if onFocus then onFocus(editBox) end
    end)
    box:SetScript("OnEditFocusLost", function(editBox) hint:SetShown(editBox:GetText() == "") end)
    return box
end

-- Sets a search box's (Theme:SearchBox) text without running its search.
function Theme.SetSearchTextQuietly(_, box, text)  -- called as Theme:SetSearchTextQuietly(box, text)
    box.quiet = true
    box:SetText(text)
    box.quiet = false
end

-- dialog:AddHint(text): a line in `small` under the title saying what the
-- dialog is for (dialog.hint).
local function AddDialogHint(box, text)
    box.hint = Theme:Text(box, Theme.font.small)
    box.hint:SetPoint("TOPLEFT", box.title, "BOTTOMLEFT", 0, -6)
    if text then box.hint:SetText(text) end
end

-- A box in the middle of the pane over a dimmed backdrop that takes every
-- click, so nothing behind it can be used while it is open. Escape shuts it.
function Theme:Dialog(pane, width, height, title)
    local shade = CreateFrame("Frame", nil, pane)
    shade:SetAllPoints()
    shade:SetFrameLevel(pane:GetFrameLevel() + 40)
    shade:EnableMouse(true)
    shade:EnableMouseWheel(true)
    shade:SetScript("OnMouseWheel", function() end)
    Theme:Fill(shade, { 0, 0, 0, 0.45 })
    shade:Hide()
    local box = CreateFrame("Frame", nil, shade)
    box:SetSize(width, height)
    box:SetPoint("CENTER")
    box:EnableMouse(true)
    Theme:Rounded(box, Theme.color.popup, Theme.color.accent, true)
    box.title = Theme:Text(box, Theme.font.heading)
    box.title:SetPoint("TOPLEFT", Theme.size.pad, -Theme.size.pad)
    box.title:SetText(title)
    box.shade = shade
    function box:Open() shade:Show() end
    function box:Close() shade:Hide() end
    box.AddHint = AddDialogHint
    Theme:OnEscape(shade, function() shade:Hide() end)
    -- The buttons along the bottom right: OK (named) and Cancel.
    function box:Buttons(okLabel, onOK)
        self.cancel = Theme:Pill(self)
        self.cancel:SetLabel(L["Cancel"])
        self.cancel:SetPoint("BOTTOMRIGHT", -Theme.size.pad, Theme.size.pad)
        self.cancel:SetScript("OnClick", function() box:Close() end)
        if okLabel then
            self.ok = Theme:Pill(self)
            self.ok:SetLabel(okLabel)
            self.ok:SetPoint("RIGHT", self.cancel, "LEFT", -8, 0)
            self.ok:SetScript("OnClick", function() onOK() end)
        end
    end
    return box
end


local NAME_DIALOG_WIDTH, NAME_DIALOG_HEIGHT = 360, 150

-- A dialog that asks for a name (a new wishlist, a renamed list or talent
-- plan), at most `maxLetters` long. dialog:Ask(title, hint, name, onName)
-- opens it with `name` typed in; Save or Enter calls `onName(text)`, which
-- returns an error to show under the box, or nothing to close it.
local function FillNameDialog(box, maxLetters)
    box:AddHint()
    box.input = Theme:Input(box, NAME_DIALOG_WIDTH - Theme.size.pad * 2)
    box.input:SetPoint("TOPLEFT", box.hint, "BOTTOMLEFT", Theme.native and 6 or 0, -10)
    box.input:SetMaxLetters(maxLetters)
    box.error = Theme:Text(box, Theme.font.small)
    box.error:SetPoint("BOTTOMLEFT", Theme.size.pad, Theme.size.pad + 4)
    Theme:SetTextColor(box.error, Theme.color.incomplete)
    local function Submit()
        local err = box.onName(box.input:GetText())
        if err then box.error:SetText(err) else box:Close() end
    end
    box:Buttons(L["Save"], Submit)
    box.input:SetScript("OnEnterPressed", Submit)
    box.input:SetScript("OnEscapePressed", function() box:Close() end)
    function box:Ask(title, hint, name, onName)
        self.title:SetText(title)
        self.hint:SetText(hint)
        self.error:SetText("")
        self.onName = onName
        self.input:SetText(name or "")
        self:Open()
        self.input:SetFocus()
        self.input:HighlightText()
    end
    return box
end

function Theme:NameDialog(pane, maxLetters)
    return FillNameDialog(self:Dialog(pane, NAME_DIALOG_WIDTH, NAME_DIALOG_HEIGHT, ""), maxLetters)
end

local MENU_ROW = 24   -- a menu's row
local MENU_PAD = 6    -- above the first row and below the last
local MENU_INSET = 4  -- the rows, in from the menu's sides
local MENU_RULE_GAP = 4  -- between a menu's last row and its rule, and (+1) from the rule to the next row

local function CreateMenuRow(menu)
    local row = Theme:Row(menu, MENU_ROW)
    row.text = Theme:Text(row, Theme.font.body)
    row.text:SetPoint("LEFT", 10, 0)
    row.text:SetPoint("RIGHT", -40, 0)
    row.text:SetJustifyH("LEFT")
    row.count = Theme:Text(row, Theme.font.small)
    row.count:SetPoint("RIGHT", -10, 0)
    return row
end

-- The menu's rows and how it opens and closes (see Theme:Menu).
local function AddMenuRows(menu)
    menu.rows = {}

    function menu:Begin()
        self.used, self.y = 0, -MENU_PAD
        self.rule:Hide()
    end

    -- The next row: `text` in `color`, `onClick(row)` on a click; row.count
    -- is the figure at its right.
    function menu:AddRow(text, color, onClick)
        self.used = self.used + 1
        local row = self.rows[self.used] or CreateMenuRow(self)
        self.rows[self.used] = row
        row:ClearAllPoints()
        row.count:SetText("")
        row.armed = nil
        row.text:SetText(text)
        Theme:SetTextColor(row.text, color)
        row:SetScript("OnClick", onClick)
        row:Show()
        row:SetPoint("TOPLEFT", MENU_INSET, self.y)
        row:SetPoint("RIGHT", -MENU_INSET, 0)
        self.y = self.y - MENU_ROW
        return row
    end

    -- A row that asks once, as "Delete list" does: the first click shows
    -- `confirmLabel` in red, a second closes the menu and calls `onConfirm`.
    function menu:AddConfirmRow(label, confirmLabel, onConfirm)
        return self:AddRow(label, Theme.color.muted, function(row)
            if not row.armed then
                row.armed = true
                row.text:SetText(confirmLabel)
                Theme:SetTextColor(row.text, Theme.color.incomplete)
                return
            end
            self:Hide()
            onConfirm()
        end)
    end

    -- A hairline across the menu under the rows so far.
    function menu:AddRule()
        self.rule:SetPoint("TOPLEFT", 10, self.y - MENU_RULE_GAP)
        self.rule:SetPoint("TOPRIGHT", -10, self.y - MENU_RULE_GAP)
        self.rule:Show()
        self.y = self.y - MENU_RULE_GAP * 2 - 1
    end

    function menu:Finish()
        for i = self.used + 1, #self.rows do self.rows[i]:Hide() end
        self:SetHeight(-self.y + MENU_PAD)
    end

    menu:SetScript("OnShow", function(self)
        self:Fill()
        self:RegisterEvent("GLOBAL_MOUSE_DOWN")
    end)
    menu:SetScript("OnHide", function(self) self:UnregisterAllEvents() end)
    menu:SetScript("OnEvent", function(self)
        if not (self:IsMouseOver() or (self.anchor and self.anchor:IsMouseOver())) then self:Hide() end
    end)
    Theme:OnEscape(menu, function() menu:Hide() end)
    return menu
end

-- A small menu that opens over `parent` (the Wishlist's list menu, a saved
-- talent plan's menu): rows of text on the popup colour, outlined in
-- the accent colour, `width` wide. Place it with menu:SetPoint and set menu.anchor to
-- the frame that opened it; a click anywhere but the menu or its anchor
-- closes it, and so does Escape. Fill it in menu:Fill(), which runs as it
-- opens: menu:Begin(), then menu:AddRow, menu:AddConfirmRow and
-- menu:AddRule in order, then menu:Finish().
function Theme:Menu(parent, width)
    local menu = CreateFrame("Frame", nil, parent)
    menu:SetFrameLevel(parent:GetFrameLevel() + 30)
    menu:SetWidth(width)
    menu:EnableMouse(true)
    menu:Hide()
    self:Rounded(menu, self.color.popup, self.color.accent, true)
    menu.rule = menu:CreateTexture(nil, "ARTWORK")
    menu.rule:SetColorTexture(unpack(self.color.line))
    menu.rule:SetHeight(1)
    menu.rule:Hide()
    return AddMenuRows(menu)
end

local UNDERLINE_RUN = 6  -- how far a switch's underline fades out past its word

-- The faction crest NeedRoll shows for "Alliance" or "Horde" (switches, the
-- other faction's entrance pin): the honor icon from the character pane.
-- Every crest in the addon comes from here, so swapping the pair is one line.
-- Size it with Theme:FitAtlas.
function Theme:Insignia(side)
    return "UI-Character-Info-Honor-Icon-" .. (side:lower() == "horde" and "Horde" or "Alliance")
end

local CLASS_CIRCLES = [[Interface\TargetingFrame\UI-Classes-Circles]]
-- FrameXML's CLASS_ICON_TCOORDS, for a client that lacks the global.
local CLASS_TCOORDS = {
    WARRIOR = { 0, 0.25, 0, 0.25 }, MAGE = { 0.25, 0.49609375, 0, 0.25 },
    ROGUE = { 0.49609375, 0.7421875, 0, 0.25 }, DRUID = { 0.7421875, 0.98828125, 0, 0.25 },
    HUNTER = { 0, 0.25, 0.25, 0.5 }, SHAMAN = { 0.25, 0.49609375, 0.25, 0.5 },
    PRIEST = { 0.49609375, 0.7421875, 0.25, 0.5 }, WARLOCK = { 0.7421875, 0.98828125, 0.25, 0.5 },
    PALADIN = { 0, 0.25, 0.5, 0.75 },
}
local BADGE_OPENING = 0.84 * 1.15 * 1.15  -- a class badge's icon, of the badge's width
local BADGE_ATLAS_SHARE = 0.8             -- an atlas in a badge (badge:SetIcon), of that icon's width

-- The class token ("WARLOCK") for a class name in the data ("Warlock").
function Theme:ClassToken(name)
    return name and (name:upper():gsub("%s", "")) or nil
end

-- A class's round icon (the target frame's class circles) inside WoW:
-- Forever's Mode-Selection-Ring, `size` px across with the ring. badge:SetClass(token) picks the
-- class; nil hides it.
function Theme:ClassBadge(parent, size)
    local badge = CreateFrame("Frame", nil, parent)
    badge:SetSize(size, size)
    -- A dark round backdrop the ring's size, its vignette reaching 2-3px
    -- past the ring, down and to the right: faint discs shifted that way a
    -- quarter pixel more and fainter each, stacked, for a soft falloff.
    -- (The ring art has a margin: its gold edge is 92% of the atlas across.)
    local ring = size * 1.25 * 0.92
    badge.backdrop = {}
    for i = 0, 12 do
        local disc = badge:CreateTexture(nil, "BACKGROUND", nil, i == 0 and 1 or 0)
        disc:SetSize(ring, ring)
        disc:SetPoint("CENTER", 0.25 * i, -0.25 * i)
        disc:SetTexture(Theme.roundMask)
        disc:SetVertexColor(0, 0, 0, i == 0 and 0.6 or 0.16 * (1 - i / 13))
        badge.backdrop[#badge.backdrop + 1] = disc
    end
    -- The ring over the icon, 1.25x the badge, reaching a little past it.
    badge.ring = badge:CreateTexture(nil, "ARTWORK", nil, 3)
    badge.ring:SetPoint("CENTER")
    badge.ring:SetSize(size * 1.25, size * 1.25)
    badge.ring:SetAtlas("Mode-Selection-Ring")
    badge.icon = badge:CreateTexture(nil, "ARTWORK", nil, 2)
    badge.icon:SetPoint("CENTER")
    badge.icon:SetSize(size * BADGE_OPENING, size * BADGE_OPENING)
    badge.icon:SetTexture(CLASS_CIRCLES)
    function badge:SetClass(token)
        local coords = token and ((CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[token]) or CLASS_TCOORDS[token])
        self:SetShown(coords ~= nil)
        if not coords then return end
        self.icon:SetTexCoord(unpack(coords))
    end
    -- Another icon in the ring instead of a class (a hunter pet family's),
    -- clipped round: a square icon file filling the opening, cropped of its
    -- baked border, or with `isAtlas` an atlas fitted whole a little inside.
    -- A badge shows classes or these icons, not both.
    -- (Written on `badge` itself, not `self`, which here is the Theme.)
    function badge.SetIcon(_, icon, isAtlas)
        badge:Show()
        badge.iconMask = badge.iconMask or Theme:MaskRound(badge, badge.icon)
        if isAtlas then
            badge.icon:SetTexCoord(0, 1, 0, 1)
            Theme:FitAtlas(badge.icon, icon, size * BADGE_OPENING * BADGE_ATLAS_SHARE)
            return
        end
        badge.icon:SetTexture(icon)
        badge.icon:SetSize(size * BADGE_OPENING, size * BADGE_OPENING)
        Theme:CropIcon(badge.icon)
    end
    return badge
end

-- The insignia's height beside text in `font` (30px by 14pt text).
function Theme:InsigniaSize(font)
    local _, size = (font or self.font.label):GetFont()
    return math.floor((size + 2) * 1.875 + 0.5)
end

-- Shows `text` on a label toggle's word button, the button as wide as the
-- word plus 6 each side.
local function SetToggleWord(btn, text)
    btn.text:SetText(Theme:Label(text))
    btn:SetWidth(btn.text:GetStringWidth() + 12)
end

-- Words in the label font side by side, like "OVERVIEW  DETAILS"; the
-- chosen one is gold and underlined, the line fading out just past both
-- ends. A click calls `onSelect(name)`; bar:SetActive(name) marks one,
-- bar:Relabel(name, text) shows other words on one (a match count) while
-- `name` still picks it, and bar:ContentWidth() is the buttons' width (the
-- bar itself is only an anchor, at the right edge of the last word). `font`
-- replaces the label font. Alliance / Horde switches use Theme:FactionToggle
-- instead.
function Theme:LabelToggle(parent, names, onSelect, font)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetSize(1, 20)
    bar.buttons = {}
    local prev
    for i = #names, 1, -1 do
        local name = names[i]
        local btn = CreateFrame("Button", nil, bar)
        btn.text = Theme:Text(btn, font or Theme.font.label)
        btn.text:SetPoint("RIGHT", -6, 0)
        btn:SetHeight(20)
        SetToggleWord(btn, name)
        -- The underline is solid under the whole word and fades out just
        -- past each end of it.
        btn.underline = CreateFrame("Frame", nil, btn)
        btn.underline:SetPoint("TOPLEFT", btn.text, "BOTTOMLEFT", -UNDERLINE_RUN, -2)
        btn.underline:SetPoint("TOPRIGHT", btn.text, "BOTTOMRIGHT", UNDERLINE_RUN, -2)
        btn.underline:SetHeight(1)
        local heading, tenth = Theme.color.heading, UNDERLINE_RUN
        local clear, solid = CreateColor(heading[1], heading[2], heading[3], 0),
            CreateColor(heading[1], heading[2], heading[3], heading[4] or 1)
        local left = btn.underline:CreateTexture(nil, "ARTWORK")
        left:SetColorTexture(1, 1, 1, 1)
        left:SetGradient("HORIZONTAL", clear, solid)
        left:SetPoint("TOPLEFT")
        left:SetPoint("BOTTOMLEFT")
        left:SetWidth(tenth)
        local right = btn.underline:CreateTexture(nil, "ARTWORK")
        right:SetColorTexture(1, 1, 1, 1)
        right:SetGradient("HORIZONTAL", solid, clear)
        right:SetPoint("TOPRIGHT")
        right:SetPoint("BOTTOMRIGHT")
        right:SetWidth(tenth)
        local middle = btn.underline:CreateTexture(nil, "ARTWORK")
        middle:SetColorTexture(heading[1], heading[2], heading[3], heading[4] or 1)
        middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
        middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
        if prev then btn:SetPoint("RIGHT", prev, "LEFT") else btn:SetPoint("RIGHT") end
        btn:SetScript("OnClick", function() onSelect(name) end)
        btn:SetScript("OnEnter", function(self)
            if not self.active then Theme:SetTextColor(self.text, Theme.color.text) end
        end)
        btn:SetScript("OnLeave", function() bar:SetActive(bar.active) end)
        bar.buttons[name] = btn
        prev = btn
    end

    function bar:ContentWidth()
        local w = 0
        for _, btn in pairs(self.buttons) do w = w + btn:GetWidth() end
        return w
    end

    function bar:Relabel(name, text)
        SetToggleWord(self.buttons[name], text)
    end

    function bar:SetActive(active)
        self.active = active
        for name, btn in pairs(self.buttons) do
            btn.active = name == active
            btn.underline:SetShown(btn.active)
            Theme:SetTextColor(btn.text, btn.active and Theme.color.heading or Theme.color.faint)
        end
    end
    return bar
end

-- Faction insignia ----------------------------------------------------------

Theme.BOTH_SIDES = "BOTH"  -- Theme:DrawCrests: the Alliance and Horde insignia stacked
local STACKED_CREST = 0.83 -- each of the stacked insignia, of a lone one's size
local CREST_STACK_WIDTH = 1.15 -- the stack's slot, of its height: a little wider, more apart side to side
local GREYED_CREST = 0.6   -- alpha of the greyed insignia behind a faction toggle's front one

-- The insignia of both sides on `owner` (a quest row, a faction toggle),
-- hidden until Theme:DrawCrests draws them in owner.crestStack, a slot as
-- wide as the stacked pair. `greyBack` greys out the insignia behind.
function Theme:NewCrests(owner, greyBack)
    owner.crests = {}
    owner.greyBack = greyBack or false
    for _, side in ipairs({ "Alliance", "Horde" }) do
        local crest = owner:CreateTexture(nil, "ARTWORK")
        self:FitAtlas(crest, self:Insignia(side), self:InsigniaSize(self.font.pane))
        crest:Hide()
        -- A very slight shadow behind a lone insignia, for depth.
        crest.shadow = owner:CreateTexture(nil, "ARTWORK", nil, -2)
        crest.shadow:SetVertexColor(0, 0, 0, 0.35)
        crest.shadow:Hide()
        owner.crests[side] = crest
    end
    owner.crestStack = owner:CreateTexture(nil, "BACKGROUND")
    -- A soft shadow of the front insignia on the one behind, so they read as two.
    owner.crestShadow = owner:CreateTexture(nil, "ARTWORK", nil, 1)
    owner.crestShadow:SetVertexColor(0, 0, 0, 0.55)
    -- And a smaller one under the insignia behind.
    owner.backShadow = owner:CreateTexture(nil, "ARTWORK", nil, -1)
    owner.backShadow:SetVertexColor(0, 0, 0, 0.45)
end

local function ShadowUnder(shadow, crest, side, size, offset)
    Theme:FitAtlas(shadow, Theme:Insignia(side), size)
    shadow:ClearAllPoints()
    shadow:SetPoint("CENTER", crest, "CENTER", offset, -offset)
end

-- Draws `owner`'s insignia (Theme:NewCrests) in its crestStack, as tall as
-- Theme:InsigniaSize(Theme.font.pane). `sides` is Theme.BOTH_SIDES for the
-- pair stacked like Crosshair_PVP_96, `front`'s at the top left in front,
-- the other at the bottom right behind; "Alliance" or "Horde" for that one
-- alone, centred in the same slot; nil hides them.
function Theme:DrawCrests(owner, sides, front)
    local size = self:InsigniaSize(self.font.pane)
    local both = sides == self.BOTH_SIDES
    owner.crestShadow:SetShown(both)
    owner.backShadow:SetShown(both)
    owner.crestStack:SetShown(sides ~= nil)
    owner.crestStack:SetSize(math.floor(size * CREST_STACK_WIDTH + 0.5), size)
    local stackedSize = math.floor(size * STACKED_CREST + 0.5)
    for _, side in ipairs({ "Horde", "Alliance" }) do
        local crest = owner.crests[side]
        local shown = both or sides == side
        local greyed = both and owner.greyBack and side ~= front
        crest:SetShown(shown)
        crest.shadow:SetShown(shown and not both)
        crest:SetDesaturated(greyed)
        crest:SetAlpha(greyed and GREYED_CREST or 1)
        if shown then
            crest:ClearAllPoints()
            if both then
                self:FitAtlas(crest, self:Insignia(side), stackedSize)
                crest:SetDrawLayer("ARTWORK", side == front and 2 or 0)
                crest:SetPoint(side == front and "TOPLEFT" or "BOTTOMRIGHT", owner.crestStack)
                if side == front then
                    ShadowUnder(owner.crestShadow, crest, side, stackedSize + 2, 1.5)
                else
                    ShadowUnder(owner.backShadow, crest, side, stackedSize, 1)
                    owner.backShadow:SetAlpha(greyed and GREYED_CREST or 1)
                end
            else
                self:FitAtlas(crest, self:Insignia(side), size)
                ShadowUnder(crest.shadow, crest, side, size + 1, 1)
                crest:SetPoint("CENTER", owner.crestStack)
            end
        end
    end
end

-- A faction toggle's tooltip: the side shown, then (in Theme.tip.text) that
-- a click shows the other's.
local function ShowFactionToggleTip(toggle)
    GameTooltip:SetOwner(toggle, "ANCHOR_TOP")
    GameTooltip:AddLine(toggle.tips.shown:format(ns.SideName(toggle.side)))
    local r, g, b = unpack(Theme.tip.text)
    GameTooltip:AddLine(toggle.tips.click:format(ns.SideName(ns.OtherSide(toggle.side))), r, g, b)
    GameTooltip:Show()
end

-- Every Alliance / Horde switch in NeedRoll: one button wearing the stacked
-- pair a quest both sides take wears (Theme:DrawCrests), the side shown at
-- the top left in front in colour, the other at the bottom right behind it
-- greyed out. A click runs toggle.onPick with the other side; the caller
-- then draws it with toggle:SetSide(side), which brings that side to the
-- front. The button is exactly the pair's size. `tips` words the tooltip
-- for its place, two "%s" phrases taking a side's name:
-- { shown = L["%s quests"], click = L["Click to see %s quests"] }; without
-- it, "Showing Alliance" and "Click to show Horde".
function Theme:FactionToggle(parent, onPick, tips)
    local toggle = CreateFrame("Button", nil, parent)
    self:NewCrests(toggle, true)
    toggle.crestStack:SetPoint("CENTER")
    toggle.onPick = onPick
    toggle.tips = tips or { shown = L["Showing %s"], click = L["Click to show %s"] }
    toggle:SetScript("OnClick", function(button) button.onPick(ns.OtherSide(button.side)) end)
    toggle:SetScript("OnEnter", ShowFactionToggleTip)
    toggle:SetScript("OnLeave", GameTooltip_Hide)
    function toggle:SetSide(side)
        self.side = side
        Theme:DrawCrests(self, Theme.BOTH_SIDES, side)
        self:SetSize(self.crestStack:GetWidth(), self.crestStack:GetHeight())
        -- Hovered while clicked: the tooltip names the new side.
        if GameTooltip:IsOwned(self) then ShowFactionToggleTip(self) end
    end
    -- Sized from the start, so callers can measure it before picking a side.
    toggle:SetSide(ns.PlayerFaction())
    return toggle
end

-- A small open/closed marker: a chevron drawn from two strokes (modern), or
-- a plain gold plus that loses its upright stroke when open (native).
-- `chevron` (the dungeon section headers) draws the Renown page arrow in
-- every skin instead: pointing right when shut, down when open.
-- arrow:SetOpen(open) flips it. `size` sets the chevron's longer side
-- (default SECTION_ARROW_SIZE); arrow:Resize(size) changes it later.
local SECTION_ARROW = "CovenantSanctum-Renown-Arrow-Depressed"
local SECTION_ARROW_SIZE = 21  -- its longer side
local SECTION_ARROW_TURN = math.pi -- the art points left: turned to point right

function Theme:Arrow(parent, chevron, size)
    local arrow = CreateFrame("Frame", nil, parent)
    arrow:SetSize(10, 10)
    if chevron then
        local tex = arrow:CreateTexture(nil, "ARTWORK")
        tex:SetPoint("CENTER")
        -- As big as the art, so its right edge stays where the row anchors it.
        function arrow:Resize(long)
            if self.long == long then return end
            self.long = long
            self:SetSize(long, long)
            Theme:FitAtlas(tex, SECTION_ARROW, long)
        end
        arrow:Resize(size or SECTION_ARROW_SIZE)
        function arrow:SetOpen(open)
            -- A quarter turn clockwise when open, so it points down.
            tex:SetRotation(SECTION_ARROW_TURN - (open and math.pi / 2 or 0))
        end
        return arrow
    end
    if self.native then
        arrow.bars = {}
        for i = 1, 2 do
            local bar = arrow:CreateTexture(nil, "ARTWORK")
            bar:SetColorTexture(unpack(self.color.heading))
            bar:SetPoint("CENTER")
            arrow.bars[i] = bar
        end
        function arrow:SetOpen(open)
            -- Snapped to whole screen pixels so both strokes stay crisp and even.
            local thick = Theme:LineWidth(self)
            self.bars[1]:SetSize(9, thick)
            self.bars[2]:SetSize(thick, 9)
            self.bars[2]:SetShown(not open)
        end
        return arrow
    end
    arrow.strokes = {}
    for i = 1, 2 do
        local line = arrow:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(1, 1, 1, 1)
        line:SetSize(6, 1.5)
        line:SetVertexColor(unpack(self.color.accent))
        arrow.strokes[i] = line
    end
    -- Open: "v" (strokes side by side); closed: ">" (stacked).
    local spread = 1.8
    function arrow:SetOpen(open)
        local first, second = self.strokes[1], self.strokes[2]
        first:ClearAllPoints()
        second:ClearAllPoints()
        if open then
            first:SetPoint("CENTER", -spread, 0)
            second:SetPoint("CENTER", spread, 0)
        else
            first:SetPoint("CENTER", 0, spread)
            second:SetPoint("CENTER", 0, -spread)
        end
        first:SetRotation(math.rad(-45))
        second:SetRotation(math.rad(45))
    end
    return arrow
end

-- Points a sort mark's chevron down (`descending`) or up.
local function PointSortMark(mark, descending)
    mark.strokes[1]:SetRotation(math.rad(descending and -45 or 45))
    mark.strokes[2]:SetRotation(math.rad(descending and 45 or -45))
end

-- A small up or down chevron in `heading`, 10 square: beside the Wishlist's
-- sorted column's name, and pointing down on a box that opens a menu (the
-- Wishlist's list pill, the recipe list's Buff box). mark:SetDescending(true)
-- points it down.
function Theme:SortMark(parent)
    local mark = CreateFrame("Frame", nil, parent)
    mark:SetSize(10, 10)
    mark.strokes = {}
    for i = 1, 2 do
        local line = mark:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(1, 1, 1, 1)
        line:SetSize(5, 1.5)
        line:SetVertexColor(unpack(self.color.heading))
        mark.strokes[i] = line
    end
    mark.strokes[1]:SetPoint("CENTER", -1.6, 0)
    mark.strokes[2]:SetPoint("CENTER", 1.6, 0)
    mark.SetDescending = PointSortMark
    return mark
end

-- The wishlist star: an empty star, gold once the item is on the wishlist.
-- The Auction House's favorite stars where the client has them, else the
-- Pet Journal's gold star, greyed out when off. star:SetOn(on) switches
-- it; star:SetLit(lit) brightens an empty star while its row is hovered.
local STAR_ON, STAR_OFF = "auctionhouse-icon-favorite", "auctionhouse-icon-favorite-off"
local STAR_FALLBACK = "PetJournal-FavoritesIcon"

function Theme:Star(parent, size)
    local star = CreateFrame("Button", nil, parent)
    star:SetSize(size, size)
    star:SetFrameLevel(parent:GetFrameLevel() + 2)
    star.tex = star:CreateTexture(nil, "OVERLAY")
    star.tex:SetAllPoints()
    local own = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(STAR_ON) ~= nil
    function star:Paint()
        local on = self.on
        if own then
            self.tex:SetAtlas(on and STAR_ON or STAR_OFF)
            self.tex:SetDesaturated(false)
        else
            self.tex:SetAtlas(STAR_FALLBACK)
            self.tex:SetDesaturated(not on)
        end
        self.tex:SetAlpha((on or self.lit or self:IsMouseOver()) and 1 or 0.45)
    end
    function star:SetOn(on)
        self.on = on and true or false
        self:Paint()
    end
    function star:SetLit(lit)
        self.lit = lit
        self:Paint()
    end
    star:HookScript("OnEnter", star.Paint)
    star:HookScript("OnLeave", star.Paint)
    star:SetOn(false)
    return star
end

-- Selectable list row: hover wash, selected fill and a left accent bar
-- (modern), or the quest log's title highlight, blue when selected (native).
local QUEST_HIGHLIGHT = [[Interface\QuestFrame\UI-QuestTitleHighlight]]
local QUEST_SELECTED = [[Interface\QuestFrame\UI-QuestLogTitleHighlight]]

local function Highlight(row, file, r, g, b, a)
    local tex = row:CreateTexture(nil, "BACKGROUND")
    tex:SetTexture(file)
    tex:SetBlendMode("ADD")
    tex:SetVertexColor(r, g, b, a)
    tex:SetAllPoints()
    return tex
end

function Theme:Row(parent, height)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(height)

    if self.native then
        row.hover = Highlight(row, QUEST_HIGHLIGHT, 1, 1, 1, 0.5)
        row.selected = Highlight(row, QUEST_SELECTED, 0.35, 0.55, 1, 1)
    else
        row.hover = self:Fill(row, self.color.hover)
        row.selected = self:Fill(row, self.color.primary)
    end
    row.hover:Hide()
    row.selected:Hide()

    row.bar = row:CreateTexture(nil, "ARTWORK")
    row.bar:SetColorTexture(unpack(self.color.accent))
    row.bar:SetPoint("TOPLEFT")
    row.bar:SetPoint("BOTTOMLEFT")
    row.bar:SetWidth(self.lineWidth)
    row.bar:Hide()
    local showBar = not self.native

    row:SetScript("OnEnter", function(self) if not self.isSelected then self.hover:Show() end end)
    row:SetScript("OnLeave", function(self) self.hover:Hide() end)

    function row:SetSelected(on)
        self.isSelected = on
        self.selected:SetShown(on)
        self.bar:SetShown(on and showBar)
        if on and showBar then self.bar:SetWidth((Theme:LineWidth(self))) end
        if on then self.hover:Hide() end
    end

    return row
end

-- An item icon with a quality-colored edge on `owner`: a 1px square behind
-- it (modern), or the game's white icon frame tinted over it, as on bag
-- slots (native). Makes owner.iconBorder (the caller sizes and places it)
-- and owner.icon inside it; owner:SetBorderColor(r, g, b, a) tints the edge.
local function TintIconFrame(owner, r, g, b, a) owner.iconBorder:SetVertexColor(r, g, b, a or 1) end
local function FillIconSquare(owner, r, g, b, a) owner.iconBorder:SetColorTexture(r, g, b, a) end

function Theme:QualityIcon(owner)
    local native = self.native
    owner.iconBorder = owner:CreateTexture(nil, native and "OVERLAY" or "ARTWORK", nil, native and 1 or 0)
    if native then owner.iconBorder:SetTexture([[Interface\Common\WhiteIconFrame]]) end
    owner.icon = owner:CreateTexture(nil, "OVERLAY")
    local inset = native and 2 or 1 -- native: inside the frame's rounded edge, so no corner pokes out
    owner.icon:SetPoint("TOPLEFT", owner.iconBorder, inset, -inset)
    owner.icon:SetPoint("BOTTOMRIGHT", owner.iconBorder, -inset, inset)
    self:CropIcon(owner.icon)
    owner.SetBorderColor = native and TintIconFrame or FillIconSquare
end

-- An item's icon (Theme:QualityIcon) and name in its quality color on a list
-- row (row.name). While the game hasn't sent the name yet the row reads
-- "Loading...", and `redraw(row, row.data)` runs once it arrives, if the
-- row still shows that entry.
function Theme:SetRowItem(row, itemID, redraw)
    row.icon:SetTexture(C_Item.GetItemIconByID(itemID))
    local name = C_Item.GetItemNameByID(itemID)
    if not name then
        row.name:SetText(L["Loading..."])
        self:SetTextColor(row.name, self.color.faint)
        row:SetBorderColor(unpack(self.color.line))
        local data = row.data
        ns.Items:Load(itemID, function()
            if row.data == data and row:IsShown() then redraw(row, data) end
        end)
        return
    end
    local r, g, b = self:QualityColor(ns.Items:Quality(itemID))
    row.name:SetText(name)
    row.name:SetTextColor(r, g, b, 1)
    row:SetBorderColor(r, g, b, 0.9)
end

-- Scrolling glides rather than jumps, so the eye can follow the list.
-- `frame.offset` counts rows (or lines) from the top and is fractional
-- mid-glide: a pane draws the row at floor(offset) shifted up by the
-- fraction of its height, in a clipped view (Theme:ScrollView).
--
-- The glide chases its target: each frame it closes the same share of the
-- distance left, measured by the frame's real duration. So it keeps moving
-- smoothly when wheel notches pile up (each one only moves the target), and
-- a slow frame doesn't make it lurch to catch up with a timeline.
local GLIDE_TAU = 0.045  -- seconds for the glide to close ~63% of the gap
local GLIDE_REST = 0.02  -- rows; closer than this, the glide lands on its target

-- Moves `frame.offset` to `target`, gliding while the frame is shown, and
-- redraws through `frame.scrollRefresh(true)` at each step (true: only the
-- scroll position changed). A glide stops when anything else sets the
-- offset (new data, a jump, the scroll bar).
function Theme:GlideTo(frame, target, instant)
    local glide = frame.glide
    if not glide then
        glide = CreateFrame("Frame", nil, frame)
        frame.glide = glide
    end
    if instant or not frame:IsVisible() or target == frame.offset then
        glide:SetScript("OnUpdate", nil)
        glide.target = nil
        if target ~= frame.offset then
            frame.offset = target
            frame.scrollRefresh(true)
        end
        return
    end
    glide.target = target
    if glide:GetScript("OnUpdate") and glide.last == frame.offset then return end
    glide.last = frame.offset
    glide:SetScript("OnUpdate", function(self, elapsed)
        if frame.offset ~= self.last then
            self:SetScript("OnUpdate", nil)
            self.target = nil
            return
        end
        -- Frames can't be longer than a tenth of a second here, so a hitch
        -- (a loading screen, a busy moment) doesn't skip the glide.
        local step = 1 - math.exp(-math.min(elapsed, 0.1) / GLIDE_TAU)
        local offset = frame.offset + (self.target - frame.offset) * step
        if math.abs(self.target - offset) < GLIDE_REST then
            offset = self.target
            self:SetScript("OnUpdate", nil)
            self.target = nil
        end
        frame.offset, self.last = offset, offset
        frame.scrollRefresh(true)
    end)
end

-- Mouse-wheel scrolling over a fixed pool of rows: each notch glides one
-- row, and notches in quick succession add up. `refresh()` redraws.
function Theme:WheelScroll(frame, getMax, refresh)
    frame.offset = 0
    frame.scrollRefresh = refresh
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(self, delta)
        local max = math.max(0, getMax())
        local from = self.glide and self.glide.target or self.offset
        -- Whole rows, so a glide always comes to rest on a row's edge.
        local target = delta > 0 and math.ceil(from - delta) or math.floor(from - delta)
        target = math.min(max, math.max(0, target))
        if target ~= from then Theme:GlideTo(self, target) end
    end)
end

-- Where a pane draws the row at a fractional `offset`: the first row's
-- index (from 1) and how far it sits above the top, in whole UI units so
-- text doesn't shimmer. `height(i)` is row i's height.
function Theme:ScrollStart(offset, height)
    local base = math.floor(offset)
    local frac = offset - base
    if frac <= 0 then return base + 1, 0 end
    return base + 1, math.floor(frac * height(base + 1) + 0.5)
end

-- A clipped window over `pane`, `top` px under its top edge down to
-- `bottom` px above its bottom edge, holding a canvas laid exactly over the
-- pane. What's drawn on the canvas keeps the pane's coordinates, and rows
-- gliding past the window's edges are cut off there. canvas:SetTop(top)
-- moves the window's top edge.
function Theme:ScrollView(pane, top, bottom)
    local view = CreateFrame("Frame", nil, pane)
    view:SetClipsChildren(true)
    view:SetPoint("BOTTOMRIGHT", 0, bottom)
    view:SetPoint("TOPLEFT", 0, -top)
    local canvas = CreateFrame("Frame", nil, view)
    canvas:SetAllPoints(pane)
    function canvas:SetTop(y)
        view:SetPoint("TOPLEFT", 0, -y)
    end
    return canvas
end

-- Slim scroll bar inside the right edge of `pane`, between `top` and
-- `bottom` px from its edges. Hidden while everything fits. The thumb can be
-- dragged; `onScroll(offset)` is called with the new offset.
-- Call bar:Update(offset, max, visible) after each redraw: `max` is the
-- highest offset and `visible` how many offset steps fit on screen.
local SCROLL_WIDTH = 1.5
local SCROLL_INSET = 4

function Theme:ScrollBar(pane, top, bottom, onScroll)
    local colors = self.color
    local bar = CreateFrame("Frame", nil, pane)
    bar:SetPoint("TOPRIGHT", -SCROLL_INSET, -top)
    bar:SetPoint("BOTTOMRIGHT", -SCROLL_INSET, bottom)
    bar:SetWidth(SCROLL_WIDTH)  -- until Update sets the accent line's width in whole pixels
    bar:SetFrameLevel(pane:GetFrameLevel() + 5)
    self:Fill(bar, colors.scrollTrack)
    -- The track takes presses as wide as the thumb's grip, so one beside
    -- the thumb doesn't fall through and drag the window (UI/MainFrame.lua).
    bar:EnableMouse(true)
    bar:SetHitRectInsets(-4, -4, 0, 0)
    bar:Hide()

    -- The handle: drawn 1.5px wide, with a wider invisible grip.
    local thumb = CreateFrame("Frame", nil, bar)
    thumb:SetWidth(SCROLL_WIDTH + 8)
    thumb:EnableMouse(true)
    local tex = thumb:CreateTexture(nil, "ARTWORK")
    tex:SetColorTexture(unpack(colors.scrollThumb))
    tex:SetPoint("TOP")
    tex:SetPoint("BOTTOM")
    tex:SetWidth(SCROLL_WIDTH)
    bar.thumb = thumb

    local function Paint()
        tex:SetColorTexture(unpack((thumb:IsMouseOver() or bar.dragging) and colors.scrollThumbHover or colors.scrollThumb))
    end
    thumb:SetScript("OnEnter", Paint)
    thumb:SetScript("OnLeave", Paint)

    -- Dragging maps the thumb's top edge along the free track to 0..max.
    local function Drag()
        local scale = bar:GetEffectiveScale()
        local _, y = GetCursorPosition()
        local thumbTop = bar:GetTop() - y / scale - bar.grab
        local free = bar:GetHeight() - thumb:GetHeight()
        local fraction = free > 0 and math.min(1, math.max(0, thumbTop / free)) or 0
        -- Follows the cursor smoothly; comes to rest on a whole row on release.
        local offset = fraction * bar.max
        if offset ~= bar.offset then onScroll(offset) end
    end
    thumb:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        local _, y = GetCursorPosition()
        bar.grab = self:GetTop() - y / self:GetEffectiveScale()
        bar.dragging = true
        self:SetScript("OnUpdate", Drag)
        Paint()
    end)
    thumb:SetScript("OnMouseUp", function(self)
        bar.dragging = false
        self:SetScript("OnUpdate", nil)
        Paint()
        local offset = pane.offset or 0
        local settle = math.floor(offset + 0.5)
        if settle ~= offset and pane.scrollRefresh then Theme:GlideTo(pane, settle) end
    end)

    function bar:Update(offset, max, visible)
        self.offset, self.max = offset, max
        if max <= 0 then
            self:Hide()
            return
        end
        self:Show()
        -- The accent line's width in whole screen pixels, so the bar keeps one width as the thumb moves.
        local width = Theme:LineWidth(self)
        self:SetWidth(width)
        tex:SetWidth(width)
        local height = self:GetHeight()
        local size = math.max(16, height * visible / (visible + max))
        local y = (height - size) * math.min(1, offset / max)
        thumb:SetHeight(size)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", self, "TOP", 0, -y)
    end

    return bar
end

-- A scrolled column of rows of varying height, for lists whose rows differ
-- (the Shopping List, the Wishlist, the Classes tab's pages): each entry
-- carries its own `height`, and entries marked `spacer` leave a gap.
-- createRow(view) makes a row on the column's clipped view; setupRow(row,
-- entry) fills it. column:SetData(entries, keep) shows a new list, from the
-- top unless `keep` (then where it was, as far as it goes).
function Theme:ScrollColumn(parent, createRow, setupRow)
    local column = CreateFrame("Frame", nil, parent)
    column.rows, column.entries = {}, {}
    -- Rows gliding past the view's edges are cut off there. Its bottom edge
    -- stops short of the column's, which is often a pane's bottom edge.
    local view = CreateFrame("Frame", nil, column)
    view:SetClipsChildren(true)
    view:SetPoint("TOPLEFT")
    view:SetPoint("BOTTOMRIGHT", 0, self.size.scrollBottom)
    column.view = view

    -- The furthest it scrolls: the last entries just fill the view.
    local function MaxOffset()
        local room, used, fitCount = view:GetHeight(), 0, 0
        for i = #column.entries, 1, -1 do
            used = used + column.entries[i].height
            if used > room then break end
            fitCount = fitCount + 1
        end
        return math.max(0, #column.entries - math.max(1, fitCount))
    end

    -- Each full redraw gets a new stamp. A row set up under the current
    -- stamp for the same entry is up to date, so while the column only
    -- scrolls (`scrolling` true) it is just moved.
    local stamp = 0

    function column:Refresh(scrolling)
        if not scrolling then stamp = stamp + 1 end
        -- Mid-glide the first row sits partly above the top edge.
        local first, lift = Theme:ScrollStart(self.offset, function(i)
            return self.entries[i] and self.entries[i].height or 0
        end)
        local room, y, rowsUsed = view:GetHeight(), -lift, 0
        for index = first, #self.entries do
            -- A row cut off by the bottom edge still shows the part that fits.
            if rowsUsed > 0 and y >= room then break end
            local slot = index - first + 1
            local entry = self.entries[index]
            local row = self.rows[slot] or createRow(view)
            self.rows[slot] = row
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -y)
            row:SetPoint("RIGHT", -8, 0)
            row:SetHeight(entry.height)
            if entry.spacer then
                row.data, row.stamp = entry, nil
                row:Hide()
            elseif row.data ~= entry or row.stamp ~= stamp or not row:IsShown() then
                row.data, row.stamp = entry, stamp
                row:Show()
                setupRow(row, entry)
            end
            y, rowsUsed = y + entry.height, slot
        end
        for i = rowsUsed + 1, #self.rows do self.rows[i]:Hide() end
        self.scrollBar:Update(self.offset, MaxOffset(), rowsUsed)
    end

    function column:SetData(entries, keep)
        self.entries = entries
        self.offset = keep and math.min(self.offset or 0, MaxOffset()) or 0
        self:Refresh()
    end

    self:WheelScroll(column, MaxOffset, function(scrolling) column:Refresh(scrolling) end)
    column.scrollBar = self:ScrollBar(column, 0, self.size.scrollBottom, function(offset)
        column.offset = offset
        column:Refresh(true)
    end)
    -- Redrawn when the view gets its size, not the column: a new column's
    -- view still reads 0 tall while the column's own OnSizeChanged runs, and
    -- a redraw then stops after the first row (the Shopping List's tree on
    -- its first showing).
    view:SetScript("OnSizeChanged", function() column:Refresh() end)
    return column
end
