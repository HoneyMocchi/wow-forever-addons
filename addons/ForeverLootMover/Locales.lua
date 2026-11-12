local ADDON_NAME, ns = ...

-- =========================================================
-- TRANSLATIONS
-- =========================================================
-- English is the reference: a missing key falls back to it, so a partial
-- translation is fine. Keep the %s / %d placeholders and the |cff...|r colors.
local L = {
    en = {
        -- Anchor
        ANCHOR_TITLE = "Loot roll bars",
        ANCHOR_HINT = "Drag to move",
        ANCHOR_HINT2 = "Wheel: size  ·  Right-click: done",

        -- Options
        SUBTITLE = "The loot roll bars, where you want them",
        SECTION_GENERAL = "GENERAL",
        SECTION_POSITION = "POSITION",
        ENABLED = "Addon enabled",
        ENABLED_DESC = "Off: the bars go back to where the game puts them after a /reload.",
        MINIMAP_BUTTON = "Minimap button",
        MINIMAP_BUTTON_DESC = "Show the round button around the minimap.",
        GROW_UP = "Stack upwards",
        GROW_UP_DESC = "Off: every new roll bar is added below the previous one.",
        CLAMP = "Keep on screen",
        CLAMP_DESC = "Stops the bars from being dragged off the edge of the screen.",
        ALERTS = "Move the loot toast too",
        ALERTS_DESC = "The \"You received\" panel lands on the anchor too, instead of where the game puts it. Off: a /reload gives it its usual spot back.",
        SMOOTH = "Smooth movement",
        SMOOTH_DESC = "The bars fade in, and the stack slides back into place when a roll is over instead of jumping.",
        SCALE = "Bar size",
        SPACING = "Gap between bars",
        PLACE = "Place the bars",
        TEST = "Test with an item",
        TEST_HIDE = "Stop the test",
        HIDE_PLACE = "Done placing",
        RESET_POSITION = "Default position",
        RESET_ALL = "Reset everything",
        CONFIRM = "Click again",
        LANGUAGE = "Language",
        RESET_DONE = "Settings back to default.",

        -- Chat
        WELCOME = "loaded. |cffffd100/flm|r to place the loot roll bars, |cffffd100/flm options|r for the rest.",
        MOVED = "Bars moved. |cffffd100/flm|r to place them again.",
        SCALE_SET = "Bar size: %d%%",
        SCALE_INVALID = "Give a size between 50 and 300, for example |cffffd100/flm scale 120|r.",
        POSITION_RESET = "Position back to default.",
        PLACING = "Drag the grey bar where you want it. Right-click it when you are done.",
        DISABLED = "ForeverLootMover is off. |cffffd100/flm on|r to turn it back on.",
        TURNED_ON = "ForeverLootMover is on.",
        TEST_SHOWN = "Two test rolls, for 30 seconds. They are not real: nothing is rolled on.",
        TEST_UNAVAILABLE = "This build does not hand out its loot roll template, so a test bar cannot be built. Run |cffffd100/flm scan|r while a real roll is on screen and send me the result.",
        MINIMAP_ON = "Minimap button shown. Cannot see it? Another addon such as HidingBar may have collected it into its own bar.",
        MINIMAP_OFF = "Minimap button hidden.",
        TURNED_OFF = "ForeverLootMover is off. The game keeps the bars where they are until a /reload.",
        NOT_FOUND = "No loot roll bar found in this build yet. Run |cffffd100/flm scan|r while a roll is on screen and send me the result.",

        -- Tooltip
        TT_PLACE = "Left-click: place the bars",
        TT_OPTIONS = "Right-click: options",

        HELP = "|cffffd100/flm|r place the bars  |cff806030.|r  |cffffd100/flm test|r  |cff806030.|r  |cffffd100/flm options|r  |cff806030.|r  |cffffd100/flm scale 120|r  |cff806030.|r  |cffffd100/flm reset|r  |cff806030.|r  |cffffd100/flm scan|r",
    },

    fr = {
        -- Ancre
        ANCHOR_TITLE = "Barres de butin",
        ANCHOR_HINT = "Glisse pour déplacer",
        ANCHOR_HINT2 = "Molette : taille  ·  Clic droit : terminé",

        -- Options
        SUBTITLE = "Les barres de jet de butin, là où tu veux",
        SECTION_GENERAL = "GÉNÉRAL",
        SECTION_POSITION = "POSITION",
        ENABLED = "Addon activé",
        ENABLED_DESC = "Désactivé : les barres retournent à leur place d'origine après un /reload.",
        MINIMAP_BUTTON = "Bouton de minicarte",
        MINIMAP_BUTTON_DESC = "Affiche le bouton rond autour de la minicarte.",
        GROW_UP = "Empiler vers le haut",
        GROW_UP_DESC = "Désactivé : chaque nouvelle barre s'ajoute en dessous de la précédente.",
        CLAMP = "Garder à l'écran",
        CLAMP_DESC = "Empêche de faire sortir les barres du bord de l'écran.",
        ALERTS = "Déplacer aussi le butin reçu",
        ALERTS_DESC = "Le panneau \"Vous recevez\" se place aussi sur l'ancre, au lieu de l'endroit choisi par le jeu. Désactivé : un /reload lui rend sa place habituelle.",
        SMOOTH = "Mouvements fluides",
        SMOOTH_DESC = "Les barres apparaissent en fondu, et la pile se remet en place en glissant quand un jet se termine, au lieu de sauter.",
        SCALE = "Taille des barres",
        SPACING = "Écart entre les barres",
        PLACE = "Placer les barres",
        TEST = "Tester avec un objet",
        TEST_HIDE = "Arrêter le test",
        HIDE_PLACE = "Terminer le placement",
        RESET_POSITION = "Position par défaut",
        RESET_ALL = "Tout réinitialiser",
        CONFIRM = "Clique encore",
        LANGUAGE = "Langue",
        RESET_DONE = "Réglages remis par défaut.",

        -- Chat
        WELCOME = "chargé. |cffffd100/flm|r pour placer les barres de butin, |cffffd100/flm options|r pour le reste.",
        MOVED = "Barres déplacées. |cffffd100/flm|r pour les replacer.",
        SCALE_SET = "Taille des barres : %d%%",
        SCALE_INVALID = "Donne une taille entre 50 et 300, par exemple |cffffd100/flm scale 120|r.",
        POSITION_RESET = "Position remise par défaut.",
        PLACING = "Glisse la barre grise où tu veux. Clic droit dessus quand c'est bon.",
        DISABLED = "ForeverLootMover est désactivé. |cffffd100/flm on|r pour le rallumer.",
        TURNED_ON = "ForeverLootMover est activé.",
        TEST_SHOWN = "Deux jets de test, pendant 30 secondes. Ce ne sont pas de vrais jets : rien n'est lancé.",
        TEST_UNAVAILABLE = "Ce build ne donne pas son modèle de barre de butin, impossible de construire une barre de test. Lance |cffffd100/flm scan|r pendant un vrai jet et envoie-moi le résultat.",
        MINIMAP_ON = "Bouton de minicarte affiché. Tu ne le vois pas ? Un autre addon comme HidingBar l'a peut-être rangé dans sa propre barre.",
        MINIMAP_OFF = "Bouton de minicarte masqué.",
        TURNED_OFF = "ForeverLootMover est désactivé. Le jeu garde les barres en place jusqu'au prochain /reload.",
        NOT_FOUND = "Aucune barre de jet trouvée dans cette version. Lance |cffffd100/flm scan|r pendant qu'un jet est affiché et envoie-moi le résultat.",

        -- Infobulle
        TT_PLACE = "Clic gauche : placer les barres",
        TT_OPTIONS = "Clic droit : les options",

        HELP = "|cffffd100/flm|r placer les barres  |cff806030.|r  |cffffd100/flm test|r  |cff806030.|r  |cffffd100/flm options|r  |cff806030.|r  |cffffd100/flm scale 120|r  |cff806030.|r  |cffffd100/flm reset|r  |cff806030.|r  |cffffd100/flm scan|r",
    },
}

-- 한국어 자동 선택 및 설정창의 수동 한국어 선택을 지원합니다.
-- 실제 저장 언어 코드는 기존 로케일 선택 방식과 같은 두 글자 ko를 사용합니다.
L.ko = {
    ANCHOR_TITLE = "전리품 입찰창",
    ANCHOR_HINT = "드래그하여 이동",
    ANCHOR_HINT2 = "마우스 휠: 크기 · 오른쪽 클릭: 배치 완료",
    SUBTITLE = "원하는 위치에 전리품 입찰창 배치",
    SECTION_GENERAL = "일반",
    SECTION_POSITION = "위치",
    ENABLED = "애드온 사용",
    ENABLED_DESC = "끄면 /reload 후 게임 기본 위치로 돌아갑니다.",
    MINIMAP_BUTTON = "미니맵 버튼",
    MINIMAP_BUTTON_DESC = "미니맵 둘레의 둥근 버튼을 표시합니다.",
    GROW_UP = "위쪽으로 쌓기",
    GROW_UP_DESC = "끄면 새 입찰창이 이전 입찰창 아래에 추가됩니다.",
    CLAMP = "화면 안에 유지",
    CLAMP_DESC = "입찰창을 화면 바깥으로 끌어내지 못하게 합니다.",
    ALERTS = "전리품 획득 알림도 이동",
    ALERTS_DESC = "'아이템 획득' 알림도 지정한 위치에 표시합니다. 끄고 /reload하면 기본 위치로 돌아갑니다.",
    SMOOTH = "부드러운 이동",
    SMOOTH_DESC = "입찰창이 서서히 나타나고, 입찰이 끝나면 남은 창이 빈자리로 부드럽게 이동합니다.",
    SCALE = "입찰창 크기",
    SPACING = "입찰창 사이 간격",
    PLACE = "입찰창 위치 지정",
    TEST = "아이템으로 미리보기",
    TEST_HIDE = "미리보기 종료",
    HIDE_PLACE = "배치 완료",
    RESET_POSITION = "기본 위치 복원",
    RESET_ALL = "모든 설정 초기화",
    CONFIRM = "다시 클릭하여 확인",
    LANGUAGE = "언어",
    RESET_DONE = "설정을 기본값으로 되돌렸습니다.",
    WELCOME = "불러왔습니다. |cffffd100/flm|r으로 입찰창을 배치하고 |cffffd100/flm options|r로 설정합니다.",
    MOVED = "입찰창을 옮겼습니다. |cffffd100/flm|r으로 다시 배치할 수 있습니다.",
    SCALE_SET = "입찰창 크기: %d%%",
    SCALE_INVALID = "50~300 사이의 크기를 입력하세요. 예: |cffffd100/flm scale 120|r",
    POSITION_RESET = "기본 위치로 되돌렸습니다.",
    PLACING = "회색 배치 틀을 원하는 곳으로 끌어놓으세요. 오른쪽 클릭하면 배치를 마칩니다.",
    DISABLED = "ForeverLootMover가 꺼져 있습니다. |cffffd100/flm on|r으로 켜세요.",
    TURNED_ON = "ForeverLootMover를 켰습니다.",
    TEST_SHOWN = "미리보기 입찰창 두 개를 30초 동안 표시합니다. 실제 아이템 입찰은 진행되지 않습니다.",
    TEST_UNAVAILABLE = "이 클라이언트에서는 입찰창 미리보기를 만들 수 없습니다. 실제 입찰창이 표시될 때 |cffffd100/flm scan|r을 실행하여 결과를 제작자에게 제보해 주세요.",
    MINIMAP_ON = "미니맵 버튼을 표시합니다. 보이지 않으면 HidingBar 같은 애드온의 버튼 모음 안을 확인하세요.",
    MINIMAP_OFF = "미니맵 버튼을 숨겼습니다.",
    TURNED_OFF = "ForeverLootMover를 껐습니다. /reload 전까지 입찰창은 현재 위치를 유지합니다.",
    NOT_FOUND = "이 클라이언트의 전리품 입찰창을 아직 찾지 못했습니다. 입찰창이 표시될 때 |cffffd100/flm scan|r을 실행하여 결과를 제작자에게 제보해 주세요.",
    TT_PLACE = "왼쪽 클릭: 입찰창 배치",
    TT_OPTIONS = "오른쪽 클릭: 설정",
    HELP = "|cffffd100/flm|r 입찰창 배치 · |cffffd100/flm test|r 미리보기 · |cffffd100/flm options|r 설정 · |cffffd100/flm scale 120|r 크기 · |cffffd100/flm reset|r 위치 복원 · |cffffd100/flm scan|r 진단",
}
ns.LOCALES = { en = "English", fr = "Français", ko = "한국어" }
ns.LOCALE_ORDER = { "en", "fr", "ko" }

-- A missing key falls back to English, a missing language too
local fallback = L.en
ns.L = setmetatable({}, {
    __index = function(_, key)
        local code = ns.db and ns.db.locale
        if not code or code == "auto" then
            code = (GetLocale() or "enUS"):sub(1, 2)
        end
        local tbl = L[code]
        local value = tbl and tbl[key]
        if value ~= nil then return value end
        return fallback[key] or key
    end,
})

-- Called when the language changes. Every label is read through ns.L, so the
-- panels only have to be told to refresh.
function ns.LanguageChanged()
    if ns.RefreshOptions then ns.RefreshOptions() end
    if ns.Anchor then ns.Anchor.Refresh() end
    if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
end
