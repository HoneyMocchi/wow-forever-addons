-- NeedRoll's own text in the player's language. Every string the addon
-- shows goes through ns.L with its English text as the key:
--     label:SetText(L["Shopping List"])
--     L["Requires %s %d"]:format(profession, skill)
-- enUS.lua lists every key (tools/locales.py writes it from the code); each
-- other language's file fills in what has been translated on CurseForge
-- (the packager writes it in at release time). A key with no translation
-- shows its English text, so nothing is ever blank.
-- Names that come from the game (items, spells, factions) are already in
-- the game's language and don't go through here.
-- NeedRoll's text is in the client's language unless the player picks
-- another in Settings (Language). Hundreds of phrases are looked up while
-- the addon's files load, so the choice has to be known then: the .toc's
-- LoadSavedVariablesFirst has the game load NeedRollDB before the files,
-- and a new choice shows after the interface reloads.
local _, ns = ...

-- The languages NeedRoll's text comes in, each named in its own language
-- (Settings' Language menu shows these names, never translated).
ns.LANGUAGES = {
    { code = "enUS", name = "English" },
    { code = "deDE", name = "Deutsch" },
    { code = "esES", name = "Español (España)" },
    { code = "esMX", name = "Español (México)" },
    { code = "frFR", name = "Français" },
    { code = "itIT", name = "Italiano" },
    { code = "ptBR", name = "Português (Brasil)" },
    { code = "ruRU", name = "Русский" },
    { code = "koKR", name = "한국어" },
    { code = "zhCN", name = "简体中文" },
    { code = "zhTW", name = "繁體中文" },
}

-- Whether NeedRoll has text in language `code` ("deDE"): `code` if so,
-- else nil.
function ns.KnownLanguage(code)
    for _, language in ipairs(ns.LANGUAGES) do
        if language.code == code then return code end
    end
    return nil
end

-- The client's language, with British English as English.
function ns.ClientLanguage()
    local client = GetLocale()
    return client == "enGB" and "enUS" or client
end

-- The language picked in Settings (NeedRollDB.language, read before ns.db
-- exists), else the client's: what NeedRoll's text loads in at the next
-- reload. The text on screen now is in ns.loadedLanguage.
function ns.Language()
    local picked = type(NeedRollDB) == "table" and ns.KnownLanguage(NeedRollDB.language)
    return picked or ns.ClientLanguage()
end

-- The language this session's phrases loaded in. It differs from the saved
-- pick after a pick made since the last reload, and when the game loaded
-- NeedRollDB after the files (Core/Init.lua says so at login).
ns.loadedLanguage = ns.Language()

-- The dot NeedRoll writes between the parts of a line ("Vendor · Recipe").
-- The game draws a line of Russian text all in FRIZQT___CYR.TTF, which has
-- no "·" (U+00B7, a box) but has "∙" (U+2219); the other clients' fonts have
-- "·", and the Chinese ones lack "∙". So "∙" wherever Russian text shows: on
-- a Russian client, or with NeedRoll's text in Russian.
local DATA_DOT = "·"  -- as the code, the phrases and the data write it
ns.DOT = (GetLocale() == "ruRU" or ns.loadedLanguage == "ruRU") and "∙" or DATA_DOT

-- `text` with each "·" as ns.DOT.
function ns.WithDots(text)
    if ns.DOT == DATA_DOT or type(text) ~= "string" then return text end
    return (text:gsub(DATA_DOT, ns.DOT))
end

-- A language's own name ("Deutsch") by its code, else the code itself.
function ns.LanguageName(code)
    for _, language in ipairs(ns.LANGUAGES) do
        if language.code == code then return language.name end
    end
    return code
end

-- Whether picking `code` (nil: Game language) changes the text after a
-- reload: not when the text is in that language already.
function ns.LanguageNeedsReload(code)
    return (ns.KnownLanguage(code) or ns.ClientLanguage()) ~= ns.loadedLanguage
end

-- Dev builds keep every English key and every language's phrases, for
-- /nr devedit's language preview (released builds drop this block).
local english, preview
--[==[@debug@
english, preview = {}, {}
--@end-debug@]==]

-- A phrase's text keeps its key's "·" and gets ns.DOT on screen, so
-- translators write "·" in every language.
ns.L = setmetatable({}, {
    __index = function(_, key) return ns.WithDots(key) end,
    -- enUS.lua sets each key to true: the key is its own English text.
    __newindex = function(t, key, value)
        if value == true then
            if english then english[#english + 1] = key end
            value = key
        end
        rawset(t, key, ns.WithDots(value))
    end,
})

-- A phrase written into ns.L, its "·" as ns.DOT. Written straight in: a key
-- enUS.lua has set already wouldn't reach ns.L's __newindex.
local function SetPhrase(key, value)
    rawset(ns.L, key, ns.WithDots(value))
end

-- The table a language file fills. Each file starts
--     local L = ns.Phrases("deDE")
--     if not L then return end
-- and gets a table writing into ns.L when NeedRoll's text is in that
-- language (ns.loadedLanguage), nothing otherwise. Dev builds keep the
-- other languages too, in a table of their own.
function ns.Phrases(locale)
    local isLoaded = ns.loadedLanguage == locale
    if not preview then
        if not isLoaded then return nil end
        return setmetatable({}, { __newindex = function(_, key, value) SetPhrase(key, value) end })
    end
    local phrases = {}
    preview[locale] = phrases
    if not isLoaded then return phrases end
    return setmetatable({}, { __newindex = function(_, key, value)
        phrases[key] = value
        SetPhrase(key, value)
    end })
end

-- Dev builds: show another language's phrases ("enUS" for English) in place
-- of the ones loaded. Only text looked up from now on changes.
function ns.PreviewPhrases(locale)
    if not preview then return false end
    local phrases = preview[locale] or {}
    for _, key in ipairs(english) do rawset(ns.L, key, ns.WithDots(phrases[key] or key)) end
    return true
end

-- "Alliance" or "Horde" (the data's spelling) as the game writes it in the
-- player's language.
function ns.SideName(side)
    if side == "Alliance" then return FACTION_ALLIANCE or side end
    if side == "Horde" then return FACTION_HORDE or side end
    return side
end

-- The side across from `side`: "Horde" for "Alliance", else "Alliance".
function ns.OtherSide(side)
    return side == "Alliance" and "Horde" or "Alliance"
end
