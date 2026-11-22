-- Debug page (/nr icondebug, also /nr insigniadebug): WoW: Forever's own
-- icons, so we can see them in the client and pick which ones NeedRoll
-- should use. Shows profession icons, every class icon variant, every
-- Alliance/Horde crest pair at four sizes, the instance portal and entrance
-- icons, the "side tab" icon set (INV_SideTab_*_c60, the Group Finder's
-- eye, magnifier and silhouettes among them) inside the game's side tab
-- frame, the unnamed file IDs between them, the side tab frame atlases and
-- the radial menu icons. In local checkouts an "All icons" view lists every
-- interface icon (atlas) the game has, by category, with a search by name
-- (UI/IconBrowser.lua). A box at the top previews any file ID, texture path
-- or atlas, and a switch shows it all on the modern or the native pane
-- background. Clicking a cell or row prints its path or atlas name to chat.
local _, ns = ...
local Theme = ns.Theme

local IconDebug = {}
ns.IconDebug = IconDebug

local kit = ns.DevKit
local C = Theme:Palette("modern")
local F = Theme:Fonts("modern")

local PAD = kit.PAD
local SCROLL_TOP = 86        -- the scroll area's top, under the title and preview box
local CELL_W, CELL_H = 104, 104
local SECTION_GAP = 12       -- under each grid of cells
local ICON_SIZE = 48         -- a plain texture icon in a cell
local ATLAS_SIZE = 56        -- an atlas cell's longer side
local ICONS = [[Interface\ICONS\]]

-- Names and file IDs from the community file list (wowdev/wow-listfile).
local SIDE_TABS = {
    { "GroupFinder", 8197096 }, { "GroupBrowsing", 8197095 }, { "WhoList", 8197123 }, { "QuestLog", 8197102 },
    { "FullMap", 8197094 }, { "Professions", 8197101 }, { "Reputation2", 8197103 }, { "Honor_Alliance", 8197097 },
    { "Honor_Horde", 8197098 }, { "Currency", 8197078 }, { "Stats", 8197104 }, { "Titles", 8197118 },
    { "Mounts", 8197099 }, { "PetJournal", 8197100 }, { "ToyBox", 8197120 }, { "Bank", 8197077 },
    { "WarbandBank", 8197121 },
}

-- File IDs in the side tab range that the file list has no name for. Some
-- may be more icons from the set; empty or missing files show blank.
local UNNAMED = { 8197076 }
for id = 8197079, 8197093 do UNNAMED[#UNNAMED + 1] = id end
for id = 8197105, 8197117 do UNNAMED[#UNNAMED + 1] = id end
UNNAMED[#UNNAMED + 1] = 8197119
UNNAMED[#UNNAMED + 1] = 8197122

local FRAME_ATLASES = {
    "common-sidetab", "common-sidetab-hover", "common-sidetab-selected", "common-sidetab-mask",
}

-- Instance portals and entrances: the world map's dungeon and raid pins,
-- portal swirls, quest and group finder dungeon/raid icons, delve pins, and
-- the pin NeedRoll's Overview uses for an entrance (Targeting-down-c60).
local PORTALS = {
    "Dungeon", "Raid", "DungeonSkull", "DungeonTargetIndicator",
    "PortalBlue", "PortalPurple", "PortalRed",
    "MagePortalAlliance", "MagePortalHorde",
    "WarlockPortalAlliance", "WarlockPortalHorde", "WarlockPortal-Yellow-32x32",
    "legioninvasion-map-icon-portal", "legioninvasion-map-icon-portal-large",
    "dreamsurge_fire-portal-icon",
    "TeleportationNetwork-32x32", "TeleportationNetwork-Ardenweald-32x32",
    "TeleportationNetwork-Maldraxxus-32x32", "TeleportationNetwork-Revendreth-32x32",
    "questlog-questtypeicon-dungeon", "questlog-questtypeicon-raid",
    "worldquest-icon-dungeon", "worldquest-icon-raid", "worldquest-icon-empoweredraid",
    "ui-ej-icon-empoweredraid-large", "ui-ej-icon-empoweredraid-small",
    "groupfinder-button-dungeons", "ChallengeMode-DungeonIconFrame",
    "evergreen-weeklyrewards-category-dungeons", "evergreen-weeklyrewards-category-raids",
    "delves-regular", "delves-bountiful", "ScenariosIcon", "UI-EventPoi-Cave",
    "Targeting-up-c60", "Targeting-down-c60",
}

-- Crossed swords for the Ring of Law's map pin (in use: Ability_DualWield),
-- shown inside the boss pin ring: texture paths and atlases.
local SWORDS = {
    "Interface\\Icons\\Ability_DualWield", "Interface\\WorldStateFrame\\CombatSwords",
    "questlog-questtypeicon-pvp", "worldquest-icon-pvp-ffa", "Crosshair_PVP_64",
    "Cursor_PVP_64", "ClassHall-CombatIcon-Desaturated", "Mobile-CombatIcon",
    "Mobile-CombatBadgeIcon", "GarrMission_MissionIcon-Combat",
    "AdventureMapIcon-MissionCombat", "ShipMissionIcon-Combat-Map",
}

-- Arrows that could mark a layout map's link to another level: the game's
-- map door arrows (in use: poi-door-arrow-up/down), housing floor arrows,
-- tutorial arrows and other green or map arrows.
local ARROWS = {
    "poi-door-arrow-up", "poi-door-arrow-down", "poi-door", "poi-door-up",
    "poi-door-down", "poi-door-left", "poi-door-right",
    "housing-floor-arrow-up", "housing-floor-arrow-down",
    "housing-floor-arrow-up-default", "housing-floor-arrow-down-default",
    "housing-floor-arrow-up-pressed", "housing-floor-arrow-down-pressed",
    "house-reward-green-arrow-up", "bags-greenarrow",
    "NPE_ArrowUp", "NPE_ArrowDown", "NPE_ArrowLeft", "NPE_ArrowRight",
    "NPE_ArrowUpGlow", "NPE_ArrowDownGlow",
    "MiniMap-PositionArrowUp", "MiniMap-PositionArrowDown",
    "MiniMap-QuestArrow", "Rotating-MinimapGuideArrow",
    "UI-HUD-Minimap-Arrow-GenericDistantPOI", "UI-HUD-Minimap-Arrow-QuestTracking",
    "arrow-short", "arrow-long",
}

-- Forever's radial menu (gamepad / quick menu) icons, "up" state.
local RADIAL = {
    "AdventureGuide", "Bags", "Chat", "Clock", "Collections", "EditCrossbars",
    "EditRadials", "Emotes", "Exclamation", "FullMap", "GameMenu", "Group",
    "GroupFinder", "GuildCommunities", "InspectHUD", "Legacy", "Macros",
    "Professions", "QuestLog", "Shop", "Social", "Spellbook", "Talents", "Targeting",
}

-- Every Alliance/Horde crest pair in Forever's atlases; the one Theme:Insignia
-- returns is marked as in use.
local INSIGNIA_PAIRS = {
    { "charcreatetest-logo-alliance", "charcreatetest-logo-horde" },
    { "QuestPortraitIcon-Alliance", "QuestPortraitIcon-Horde" },
    { "QuestPortraitIcon-Alliance-small", "QuestPortraitIcon-Horde-small" },
    { "talenttree-alliance-cornerlogo", "talenttree-horde-cornerlogo" },
    { "AllianceEmblem", "HordeEmblem" },
    { "pvpqueue-sidebar-honorbar-badge-alliance", "pvpqueue-sidebar-honorbar-badge-horde" },
    { "charactercreate-icon-alliance", "charactercreate-icon-horde" },
    { "charactercreate-icon-alliancebg", "charactercreate-icon-hordebg" },
    { "glues-characterSelect-icon-faction-alliance", "glues-characterSelect-icon-faction-horde" },
    { "glues-characterSelect-icon-faction-alliance-selected", "glues-characterSelect-icon-faction-horde-selected" },
    { "UI-HUD-UnitFrame-Player-PVP-AllianceIcon", "UI-HUD-UnitFrame-Player-PVP-HordeIcon" },
    { "UI-HUD-UnitFrame-SmallCircle-Alliance", "UI-HUD-UnitFrame-SmallCircle-Horde" },
    { "UI-Character-Info-Honor-Icon-Alliance", "UI-Character-Info-Honor-Icon-Horde" },
    { "questlog-questtypeicon-alliance", "questlog-questtypeicon-horde" },
    { "scoreboard-footer-alliance-icon", "scoreboard-footer-horde-icon" },
    { "alliance_icon_and_flag-icon", "horde_icon_and_flag-icon" },
    { "bfa-landingbutton-alliance-up", "bfa-landingbutton-horde-up" },
    { "worldquest-icon-alliance", "worldquest-icon-horde" },
    { "CharacterSelection_Alliance_Icon", "CharacterSelection_Horde_Icon" },
    { "communities-icon-faction-alliance", "communities-icon-faction-horde" },
    { "AllianceSymbol", "HordeSymbol" },
    { "honorsystem-portrait-alliance", "honorsystem-portrait-horde" },
    { "LegionMissionIcon-ZoneSupportAlliance-MapBadge", "LegionMissionIcon-ZoneSupportHorde-MapBadge" },
    { "Quest-Alliance-WaxSeal", "Quest-Horde-WaxSeal" },
    { "nameplates-icon-flag-alliance", "nameplates-icon-flag-horde" },
    { "GarrMission_ClassIcon-Alliance", "GarrMission_ClassIcon-Horde" },
}

-- Profession icons: the general ones (radial menu, micro menu, gathering
-- trackers), then a family per profession for each naming scheme the client
-- may have (world quest icons, companion app icons). Missing ones say so.
local PROFESSION_GENERAL = {
    "Professions-up-c60", "UI-HUD-MicroMenu-Professions-Up", "UI-HUD-MicroMenu-Professions-Mouseover",
    "Professions_Tracking_Herb", "Professions_Tracking_Ore", "Professions_Tracking_Fish",
    "professions-crafting-orders-icon", "Professions-Crafting-Orders-Icon",
}
local PROFESSION_NAMES = {
    "Alchemy", "Blacksmithing", "Enchanting", "Engineering", "Leatherworking", "Tailoring",
    "Cooking", "FirstAid", "Fishing", "Herbalism", "Mining", "Skinning",
}
-- { section title, atlas naming scheme } (see AtlasFromScheme).
local PROFESSION_SCHEMES = {
    { "World quest icons", "worldquest-icon-<name>" },
    { "Companion icons", "Mobile-<Name>" },
    { "Profession icons", "Professions-Icon-<Name>" },
}
-- Blizzard named the companion app's Engineering icon "Mobile-Enginnering".
local ATLAS_TYPOS = { ["Mobile-Engineering"] = "Mobile-Enginnering" }

-- An atlas name from a naming scheme: <name> and <class> are the name in
-- lower case, <Name> and <Class> as `capitalized` writes it.
local function AtlasFromScheme(scheme, capitalized)
    local lower = capitalized:lower()
    local atlas = scheme:gsub("<name>", lower):gsub("<Name>", capitalized)
        :gsub("<class>", lower):gsub("<Class>", capitalized)
    return ATLAS_TYPOS[atlas] or atlas
end

-- Class icons: every naming scheme for a per-class icon, as atlases (the
-- name built from the class token) or as sheets cut with CLASS_ICON_TCOORDS.
-- The classes are the ones the client has (GetClassInfo).
local CLASS_CASE = { DEATHKNIGHT = "DeathKnight", DEMONHUNTER = "DemonHunter" }
-- "PALADIN" as atlas names write it: "Paladin", "DeathKnight".
local function ClassCase(classToken)
    return CLASS_CASE[classToken] or classToken:sub(1, 1) .. classToken:sub(2):lower()
end
local CLASS_SCHEMES = {
    "classicon-<class>", "groupfinder-icon-class-<class>", "groupfinder-icon-class-color-<class>",
    "GarrMission_ClassIcon-<Class>", "ClassHall-Circle-<Class>", "ClassTrial-<Class>-Ring",
    "UI-HUD-UnitFrame-Player-Portrait-ClassIcon-<Class>", "legionmission-landingbutton-<class>-up",
}
local CLASS_SHEETS = {
    [[Interface\GLUES\CHARACTERCREATE\UI-CharacterCreate-Classes]],
    [[Interface\TargetingFrame\UI-Classes-Circles]],
    [[Interface\WorldStateFrame\Icons-Classes]],
}

-- { name = "Paladin", token = "PALADIN" } for each class the client has.
local function Classes()
    local classes = {}
    for classID = 1, GetNumClasses() do
        local name, token = GetClassInfo(classID)
        if name and token then classes[#classes + 1] = { name = name, token = token } end
    end
    return classes
end

local INSIGNIA_SCALES = { 0.75, 1, 1.25, 1.5 }
local NAME_W = 250  -- the insignia rows' atlas names column
local GAP = 10      -- between the two crests of a pair, and around each size's column

local painter = kit.NewPainter()
IconDebug.painter = painter

-- An icon inside the game's side tab frame, built like Blizzard's
-- LargeSideTabButtonTemplate: the tab art behind, the icon trimmed to 50px
-- and clipped to the tab's rounded mask.
local function SideTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetSize(55, 60)
    tab.bg = tab:CreateTexture(nil, "BACKGROUND")
    tab.bg:SetAtlas("common-sidetab", true)
    tab.bg:SetPoint("CENTER")
    tab.icon = tab:CreateTexture(nil, "ARTWORK")
    tab.icon:SetSize(50, 50)
    tab.icon:SetTexCoord(0.03125, 0.96875, 0.03125, 0.96875)
    tab.icon:SetPoint("CENTER", -3, 0)
    tab.mask = tab:CreateMaskTexture()
    tab.mask:SetAtlas("common-sidetab-mask", true)
    tab.mask:SetPoint("CENTER")
    tab.icon:AddMaskTexture(tab.mask)
    return tab
end

-- One grid cell: the art on top, a name and a detail line under it.
-- `copy` is what a click prints to chat.
local function Cell(content, name, detail, copy)
    local cell = kit.ClickCell(content, CELL_W, CELL_H, copy)
    cell.art:SetSize(60, 64)
    cell.name = painter:Paint(Theme:Text(cell, F.small), "text")
    cell.name:SetPoint("TOP", cell.art, "BOTTOM", 0, -4)
    cell.name:SetWidth(CELL_W - 6)
    cell.name:SetText(name)
    cell.detail = painter:Paint(Theme:Text(cell, F.hint), "muted")
    cell.detail:SetPoint("TOP", cell.name, "BOTTOM", 0, -2)
    cell.detail:SetText(detail or "")
    return cell
end

-- A cell showing `texture` (a path or file ID) ICON_SIZE px square, cut to
-- `texCoords` when given.
local function TextureCell(content, name, detail, copy, texture, texCoords)
    local cell = Cell(content, name, detail, copy)
    local icon = cell.art:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("CENTER")
    icon:SetTexture(texture)
    if texCoords then icon:SetTexCoord(unpack(texCoords)) end
    return cell
end

local function SideTabCell(content, name, detail, copy, texture)
    local cell = Cell(content, name, detail, copy)
    local tab = SideTab(cell.art)
    tab:SetPoint("CENTER")
    tab.icon:SetTexture(texture)
    return cell
end

-- An atlas cell per name, fitted to `size`; "missing" when the client lacks
-- it. A cell is labelled `labelOf(atlas, i)` when given, else the atlas.
local function AtlasCells(content, atlases, size, labelOf)
    local cells = {}
    for i, atlas in ipairs(atlases) do
        local cell = Cell(content, labelOf and labelOf(atlas, i) or atlas, "atlas", atlas)
        local tex = cell.art:CreateTexture(nil, "ARTWORK")
        tex:SetPoint("CENTER")
        if not kit.FitAtlas(tex, atlas, size) then cell.detail:SetText("missing") end
        cells[#cells + 1] = cell
    end
    return cells
end

-- A heading, then its cells in a grid; returns the y under them, gap included.
local function GridSection(content, title, cells, y)
    y = painter:Section(content, title, y)
    return kit.Grid(content, cells, y, CELL_W, CELL_H) + SECTION_GAP
end

-- Each profession's skill spell icon, as the profession list shows it.
local function ProfessionSpellCells(content)
    local icons = ns.UI.professionIcons
    local ids = {}
    for professionID in pairs(icons) do ids[#ids + 1] = professionID end
    table.sort(ids)
    local cells = {}
    for _, professionID in ipairs(ids) do
        local spell, file = icons[professionID][1], icons[professionID][2]
        local texture = C_Spell.GetSpellTexture(spell) or ICONS .. file
        cells[#cells + 1] = TextureCell(content, file, "spell " .. spell, ICONS .. file .. "  (spell " .. spell .. ")",
            texture)
    end
    return cells
end

local function ProfessionSections(content, y)
    y = GridSection(content, "Profession icons", AtlasCells(content, PROFESSION_GENERAL, ATLAS_SIZE), y)
    y = GridSection(content, "Profession list icons  ·  each profession's skill spell icon (in use)",
        ProfessionSpellCells(content), y)
    for _, family in ipairs(PROFESSION_SCHEMES) do
        local title, scheme = family[1], family[2]
        local atlases = {}
        for i, name in ipairs(PROFESSION_NAMES) do atlases[i] = AtlasFromScheme(scheme, name) end
        y = GridSection(content, title .. "  ·  atlas " .. scheme, AtlasCells(content, atlases, ATLAS_SIZE), y)
    end
    return y
end

local function ClassSections(content, y)
    local classes = Classes()
    local function ClassName(_, i) return classes[i].name end
    for _, scheme in ipairs(CLASS_SCHEMES) do
        local atlases = {}
        for i, class in ipairs(classes) do atlases[i] = AtlasFromScheme(scheme, ClassCase(class.token)) end
        y = GridSection(content, "Class icons  ·  atlas " .. scheme,
            AtlasCells(content, atlases, ATLAS_SIZE, ClassName), y)
    end

    local cells = {}
    for _, class in ipairs(classes) do
        local path = ICONS .. "ClassIcon_" .. ClassCase(class.token)
        cells[#cells + 1] = TextureCell(content, class.name, "texture", path, path)
    end
    y = GridSection(content, "Class icons  ·  Interface\\ICONS\\ClassIcon_<Class>", cells, y)

    -- CLASS_ICON_TCOORDS is FrameXML's table of each class's square on these
    -- sheets. It isn't in any API list, so a client without it shows "no coords".
    local classCoords = CLASS_ICON_TCOORDS or {}
    for _, sheet in ipairs(CLASS_SHEETS) do
        cells = {}
        for _, class in ipairs(classes) do
            local coords = classCoords[class.token]
            cells[#cells + 1] = TextureCell(content, class.name, coords and "texture" or "no coords",
                sheet .. "  " .. class.token, sheet, coords)
        end
        y = GridSection(content, "Class icons  ·  " .. sheet .. " (CLASS_ICON_TCOORDS)", cells, y)
    end
    return y
end

-- The crest pairs, one row each: names, then the pair at 0.75x, 1x, 1.25x
-- and 1.5x the size a quest row shows a lone crest at (Theme:DrawCrests).
local function InsigniaRows(content, y)
    local baseSize = Theme:InsigniaSize(Theme.font.pane)
    local sizes, columnLefts, rowWidth = {}, {}, NAME_W
    for i, scale in ipairs(INSIGNIA_SCALES) do
        sizes[i] = baseSize * scale
        columnLefts[i] = rowWidth
        rowWidth = rowWidth + sizes[i] * 2 + GAP * 3
    end
    local rowHeight = sizes[#sizes] + 14

    -- Column heads: each size, the current one marked.
    for i, scale in ipairs(INSIGNIA_SCALES) do
        local head = painter:Paint(Theme:Text(content, F.small), scale == 1 and "heading" or "text")
        head:SetPoint("TOP", content, "TOPLEFT", columnLefts[i] + sizes[i] + GAP * 1.5, -y)
        head:SetText(ns.WithDots(("%s  ·  %gpx"):format(scale == 1 and "Current" or scale .. "x", sizes[i])))
    end
    y = y + 20

    for _, pair in ipairs(INSIGNIA_PAIRS) do
        local row = CreateFrame("Button", nil, content)
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetSize(rowWidth, rowHeight)
        kit.Hover(row)
        row:SetScript("OnClick", function() ns:Print(pair[1] .. "  /  " .. pair[2]) end)

        local inUse = pair[1] == Theme:Insignia("Alliance")
        local names = painter:Paint(Theme:Text(row, F.hint), inUse and "heading" or "text")
        names:SetPoint("LEFT", 8, 0)
        names:SetWidth(NAME_W - 16)
        names:SetJustifyH("LEFT")
        local anyMissing = false
        for i, size in ipairs(sizes) do
            for side = 1, 2 do
                local tex = row:CreateTexture(nil, "ARTWORK")
                local center = columnLefts[i] + GAP + size / 2 + (side - 1) * (size + GAP)
                tex:SetPoint("CENTER", row, "LEFT", center, 0)
                if not kit.FitAtlas(tex, pair[side], size) then anyMissing = true end
            end
        end
        names:SetText(pair[1] .. "\n" .. pair[2] .. (inUse and "\n(in use)" or "")
            .. (anyMissing and "\n(missing in this client)" or ""))
        y = y + rowHeight
    end
    return y
end

-- Each crossed swords icon in a copy of a boss's map pin.
local function SwordPinCells(content)
    local cells = {}
    local pinSize = ns.UI.pinLook.size
    for _, icon in ipairs(SWORDS) do
        local isPath = icon:find("\\")
        local cell = Cell(content, isPath and icon:match("[^\\]+$") or icon, isPath and "texture" or "atlas", icon)
        local pin = ns.UI.MiniPin(cell.art, pinSize)
        pin:SetPoint("CENTER")
        ns.UI.SetPinIcon(pin.back, pin.portrait, icon)
        cells[#cells + 1] = cell
    end
    return cells
end

local function PortalSections(content, y)
    y = GridSection(content, "Instance portal and entrance icons", AtlasCells(content, PORTALS, ATLAS_SIZE), y)
    y = GridSection(content, "Ring of Law pin  ·  crossed swords in the boss pin ring", SwordPinCells(content), y)
    return GridSection(content, "Map level arrows", AtlasCells(content, ARROWS, 32), y)
end

local function SideTabSections(content, y)
    local framed, plain = {}, {}
    for _, entry in ipairs(SIDE_TABS) do
        local name, fileID = entry[1], entry[2]
        local path = ICONS .. "INV_SideTab_" .. name .. "_c60"
        framed[#framed + 1] = SideTabCell(content, name, tostring(fileID), path .. "  (" .. fileID .. ")", path)
    end
    y = GridSection(content, "Side tab icons  ·  Interface\\ICONS\\INV_SideTab_<Name>_c60", framed, y)
    -- The same files by file ID, without the frame.
    for _, entry in ipairs(SIDE_TABS) do
        local name, fileID = entry[1], entry[2]
        local path = ICONS .. "INV_SideTab_" .. name .. "_c60"
        plain[#plain + 1] = TextureCell(content, name, tostring(fileID), path, fileID)
    end
    y = GridSection(content, "Same icons, no frame", plain, y)

    local unnamed = {}
    for _, fileID in ipairs(UNNAMED) do
        unnamed[#unnamed + 1] = SideTabCell(content, tostring(fileID), "unnamed", tostring(fileID), fileID)
    end
    y = GridSection(content, "Unnamed file IDs in the same range (blank: no icon there)", unnamed, y)

    return GridSection(content, "Side tab frame atlases", AtlasCells(content, FRAME_ATLASES, 60,
        function(atlas) return (atlas:gsub("^common%-", "")) end), y)
end

local function BuildContent(content)
    local y = 8
    y = ProfessionSections(content, y)
    y = ClassSections(content, y)
    y = painter:Section(content, "Alliance / Horde insignia pairs", y)
    y = InsigniaRows(content, y) + 16
    y = PortalSections(content, y)
    y = SideTabSections(content, y)
    -- The last section, with no gap under it.
    local radial = {}
    for i, name in ipairs(RADIAL) do radial[i] = name .. "-up-c60" end
    y = painter:Section(content, "Radial menu icons  ·  atlas <Name>-up-c60", y)
    local radialCells = AtlasCells(content, radial, ATLAS_SIZE,
        function(atlas) return (atlas:gsub("%-up%-c60$", "")) end)
    y = kit.Grid(content, radialCells, y, CELL_W, CELL_H)
    content:SetHeight(y + PAD)
end

-- The preview box: a number is a file ID, text with a slash is a texture
-- path (Interface\ICONS\ is added when there is none), anything else an
-- atlas when the client has one by that name, else an icon name.
local function BuildPreview(f)
    local box = CreateFrame("EditBox", nil, f)
    box:SetSize(300, 24)
    box:SetPoint("TOPLEFT", PAD, -46)
    box:SetAutoFocus(false)
    box:SetFontObject(F.body)
    box:SetTextInsets(8, 8, 0, 0)
    Theme:Rounded(box, C.primary)

    local hint = Theme:Text(box, F.hint)
    hint:SetPoint("LEFT", 8, 0)
    hint:SetText("File ID, icon name, path or atlas, then Enter")

    local tab = SideTab(f)
    tab:SetPoint("LEFT", box, "RIGHT", 16, 0)
    local plain = f:CreateTexture(nil, "ARTWORK")
    plain:SetSize(ICON_SIZE, ICON_SIZE)
    plain:SetPoint("LEFT", tab, "RIGHT", 10, 0)
    local status = Theme:Text(f, F.small)
    status:SetPoint("LEFT", plain, "RIGHT", 12, 0)
    tab:Hide()

    local function Preview(text)
        text = strtrim(text)
        tab:Hide()
        plain:SetTexture(nil)
        if text == "" then
            status:SetText("")
            return
        end
        local fileID = tonumber(text)
        if not fileID and C_Texture.GetAtlasInfo(text) then
            kit.FitAtlas(plain, text, 60)
            status:SetText("Atlas: " .. text)
            return
        end
        local texture = fileID or (text:find("[/\\]") and text or ICONS .. text)
        tab:Show()
        tab.icon:SetTexture(texture)
        plain:SetTexCoord(0, 1, 0, 1)
        plain:SetSize(ICON_SIZE, ICON_SIZE)
        plain:SetTexture(texture)
        status:SetText("Texture: " .. tostring(texture))
    end

    box:SetScript("OnTextChanged", function(self) hint:SetShown(self:GetText() == "") end)
    box:SetScript("OnEnterPressed", function(self)
        Preview(self:GetText())
        self:ClearFocus()
    end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
end

function IconDebug:SetStyle(style)
    self.style = style
    kit.ShowBackground(self, style)
    --[==[@debug@
    if ns.IconBrowser then ns.IconBrowser:Repaint() end
    --@end-debug@]==]
end

function IconDebug:Build()
    if self.frame then return end
    local f = kit.Window("NeedRollIconDebug", "Icon debug")
    self.frame = f
    BuildPreview(f)
    self.backgrounds = kit.Backgrounds(f, SCROLL_TOP)
    self.switch = kit.StyleSwitch(f, function(style) self:SetStyle(style) end)

    local content, scroll = kit.ScrollArea(f, SCROLL_TOP, CELL_H / 2)
    scroll:SetFrameLevel(self.backgrounds.native:GetFrameLevel() + 2)
    BuildContent(content)

    -- "Curated · All icons" over the list, in local checkouts only (the
    -- packager turns the debug block into a comment, and releases leave out
    -- UI/IconBrowser.lua and Data/IconList.lua).
    --[==[@debug@
    if ns.IconList and ns.IconBrowser then
        local browser = CreateFrame("Frame", nil, f)
        browser:SetPoint("TOPLEFT", PAD, -SCROLL_TOP)
        browser:SetPoint("BOTTOMRIGHT", -PAD, PAD)
        browser:SetFrameLevel(scroll:GetFrameLevel())
        browser:Hide()
        ns.IconBrowser:Build(browser, f:GetWidth() - PAD * 2, f:GetHeight() - SCROLL_TOP - PAD, F)
        self.views = Theme:LabelToggle(f, { "Curated", "All icons" }, function(name)
            self.views:SetActive(name)
            scroll:SetShown(name == "Curated")
            browser:SetShown(name ~= "Curated")
            if browser:IsShown() then ns.IconBrowser:Draw() end
        end, F.small)
        self.views:SetPoint("TOPRIGHT", -PAD + 6, -48)
        self.views:SetActive("Curated")
    end
    --@end-debug@]==]
    self:SetStyle(Theme.native and "native" or "modern")
end

function IconDebug:Toggle()
    self:Build()
    self.frame:SetShown(not self.frame:IsShown())
end
