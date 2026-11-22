# ForeverThreat 1.6.1

Eigenständiger Threat-Meter für World of Warcraft: Forever.

## Installation

Den Ordner `ForeverThreat` nach:

`World of Warcraft\_classic_beta_\Interface\AddOns\`

kopieren.

Danach sollte der Pfad so aussehen:

`...\Interface\AddOns\ForeverThreat\ForeverThreat_Camelot.toc`

Bei einem ganz neuen Addon den Forever-Client ggf. bis zur Charakterauswahl neu starten.

## Befehle

- `/ft` oder `/forevertreat` – Fenster ein-/ausblenden
- `/ft lock` – Fenster sperren
- `/ft unlock` – Fenster entsperren
- `/ft reset` – Position zurücksetzen
- `/ft debug` – aktuelle Forever-Threat-API-Werte im Chat ausgeben

## Testziel für v0.1

1. Addon wird geladen.
2. Hauptframe erscheint.
3. Feindliches Ziel auswählen und angreifen.
4. Solo: eigener Threat-Balken erscheint.
5. Gruppe: Gruppenmitglieder erscheinen in Klassenfarben.
6. `/ft debug` während eines Kampfes testen.
7. Falls `GESCHÜTZT` erscheint, ist das kein Lua-Fehler: ForeverThreat hat einen Secret Value erkannt.

## Beta-Hinweis

WoW Forever Beta 1.60.1 nutzt Interface 16001 und die moderne Addon-API.
Die Beta hat derzeit außerdem Berichte über unzuverlässiges Laden von SavedVariables
nach einem vollständigen Client-Neustart. Das ist bei Tests von Position/Lock-Zustand
zu berücksichtigen.


## Änderungen v0.2

- kompaktere Omen-artige Threat-Zeilen
- Rangnummer links
- Klassenfarbiger Balken
- absoluter Threat-Wert rechts
- Scaled-Threat-Prozent ganz rechts
- Tank-Markierung `[T]`
- Warnfarbe ab 90 % Scaled Threat
- `Raw%` wird bewusst nicht als Balkenwert verwendet


## Änderungen v0.3

- Aggro-Warnung groß in der Bildschirmmitte
- eingebauter WoW-Warnsound bei neuem Aggro-Gewinn
- Vorwarnung "HOHE BEDROHUNG!" ab 90 % Scaled Threat
- Warnungen werden nur bei Zustandswechsel ausgelöst, nicht permanent gespammt
- automatisches Anzeigen beim Kampfbeginn
- automatisches Ausblenden nach Kampfende
- neue Befehle:
  - `/ft sound on`
  - `/ft sound off`
  - `/ft warnings on`
  - `/ft warnings off`
  - `/ft auto on`
  - `/ft auto off`

### Test v0.3

1. `/ft auto on`
2. Fenster außerhalb des Kampfes ausblenden lassen.
3. Kampf beginnen -> ForeverThreat sollte erscheinen.
4. Aggro übernehmen -> mittig sollte `AGGRO!` erscheinen und ein Warnsound abgespielt werden.
5. Kampf beenden -> Fenster sollte wieder verschwinden.


## Hotfix v0.3.1

- `AGGRO!` besitzt jetzt einen eigenen Ausblende-Timer.
- Die Warnung hängt nicht mehr vom sichtbaren Hauptfenster ab.
- Beim Kampfende wird eine noch sichtbare Warnung sofort entfernt.
- `AGGRO!` wird weiterhin nur beim Wechsel auf Aggro ausgelöst.


## Hotfix v0.3.2

- fehlende `PlayWarningSound()`-Funktion korrigiert
- interne Core-Bezeichnung auf `FT` vereinheitlicht
- Raid-Warning-Sound wird über `SOUNDKIT.RAID_WARNING` verwendet
- Fallback auf SoundKit-ID `8959`
- neuer Testbefehl: `/ft testsound`
- `/ft sound on|off`, `/ft warnings on|off` und `/ft auto on|off` funktionieren jetzt tatsächlich

### Soundtest

Nach dem Laden:

`/ft testsound`

Es sollte sofort der WoW-Raid-Warning-Sound abgespielt werden.


## Hotfix v0.3.3 – Aggro-Trigger korrigiert

Die Soundwarnung basiert jetzt nicht mehr auf `100 % Threat` oder `Status >= 2`.

Ein `AGGRO!`-Sound wird nur noch ausgelöst, wenn:

1. der Gegner aktuell den eigenen Spieler anvisiert,
2. der Gegner im vorherigen Update noch nicht den eigenen Spieler anvisiert hat,
3. im laufenden Kampf zuvor bereits ein anderer Spieler Aggro hatte.

Dadurch:

- kein Sound beim normalen ersten Pull
- kein Sound nur weil ein anderer Spieler 100 % Threat erreicht
- kein Sound im normalen Solo-Pull
- Sound nur bei echtem Aggro-Wechsel auf den eigenen Spieler
- `HOHE BEDROHUNG!` bleibt weiterhin lautlos


## v0.4.0 – Fensterverhalten & Größe

### Fenster bleibt offen
ForeverThreat wird nach Kampfende nicht mehr automatisch ausgeblendet.
Es bleibt sichtbar, bis du es selbst über X, Minimap-Button oder `/ft` schließt.

`/ft auto on|off` steuert nur noch, ob ein geschlossenes ForeverThreat beim
Kampfbeginn automatisch eingeblendet wird.

### Frei skalierbares Fenster
Unten rechts befindet sich jetzt ein Größen-Griff.

- ziehen = Breite und Höhe frei anpassen
- Größe wird in `ForeverThreatDB` gespeichert
- Fenster-Lock sperrt jetzt Bewegung UND Größenänderung
- je höher das Fenster, desto mehr Spielerzeilen werden angezeigt

Grenzen:
- Breite: 260 bis 700
- Höhe: 95 bis 500

### Größenbefehle
- `/ft size 400 200`
- `/ft width 450`
- `/ft height 250`
- `/ft resetsize`


## v0.4.1 – Eigenes Minimap-Icon

- Das neue ForeverThreat-Icon wird jetzt als Minimap-Button verwendet.
- Enthalten als 32-Bit-TGA unter `Media/MinimapButton.tga`.
- Texture-Pfad im Addon: `Interface\AddOns\ForeverThreat\Media\MinimapButton`


## v0.4.2 – Minimap-Button Position korrigiert

- Die Position des Minimap-Buttons wird jetzt korrekt am Rand der Minimap berechnet.
- Statt eines einfachen festen Radius wird nun die Minimap-Form berücksichtigt
  (`ROUND`, `SQUARE`, `SIDE-*`, `CORNER-*`, `TRICORNER-*`).
- Dadurch sitzt der Button sauber am Rand und nicht zu weit in der Karte.

Falls dein Button noch an einer alten Stelle sitzt, einfach einmal auf der Minimap
neu ziehen – danach wird die korrigierte Position gespeichert.


## v0.4.3 – Lua-Syntaxfix

- Minimap-Form-Schlüssel mit Bindestrichen werden jetzt korrekt als Strings geschrieben.
- Behebt den Fehler:
  `'}' expected ... near '='`


## v0.4.4 – Minimap-Rand endgültig korrigiert

Die bisherige Berechnung verwendete einen festen Radius. Das funktioniert nur,
wenn die Minimap ungefähr die klassische Standardgröße besitzt.

ForeverThreat berechnet die Position jetzt aus der tatsächlich vorhandenen
Minimap-Größe:

- `Minimap:GetWidth() / 2`
- `Minimap:GetHeight() / 2`
- kleiner Rand-Offset von 5
- Form der Minimap wird weiterhin berücksichtigt

Damit folgt die Position demselben Grundprinzip wie moderne LibDBIcon-Versionen
und funktioniert auch bei einer größeren/skalierten Forever-Minimap.

Nach dem Update den Button einmal kurz ziehen, damit die gewünschte Winkelposition
neu gespeichert/angewendet wird.


## v0.5.0 – Minimap-Button auf eingebettetes LibDBIcon umgestellt

ForeverThreat benutzt für den Minimap-Button jetzt nicht mehr die eigene Positionsberechnung.

Mitgeliefert werden direkt im Addon:

- LibStub
- CallbackHandler-1.0
- LibDataBroker-1.1
- LibDBIcon-1.0

Der Benutzer muss **nichts zusätzlich installieren**. BugSack ist ebenfalls nicht erforderlich.

Die Position wird von LibDBIcon in `ForeverThreatDB.minimap` gespeichert. Eine alte
`minimapAngle`-Position aus v0.4.x wird beim ersten Laden automatisch übernommen.

Bedienung:
- Linksklick: ForeverThreat ein-/ausblenden
- Rechtsklick: ForeverThreat-Fenster sperren/entsperren
- Linke Maustaste ziehen: Minimap-Button am Rand verschieben


## v0.6.0 – Einstellungsmenü

ForeverThreat besitzt jetzt ein eigenes Einstellungsmenü in den WoW-Optionen.

Öffnen über:

`/ft config`

oder:

`/ft options`

Einstellbar sind:

- Aggro-Warnsound
- Bildschirmwarnungen
- Hohe-Bedrohung-Warnung
- Warnschwelle 50–100 %
- automatisches Anzeigen bei Kampfbeginn
- Minimap-Button an/aus
- Klassenfarben an/aus
- Threat-Wert an/aus
- Prozentwert an/aus
- Tank-Markierung an/aus
- Fenster-Transparenz
- Balkenhöhe
- Schriftgröße
- maximale Anzahl sichtbarer Spielerzeilen
- Position und Größe zurücksetzen

Die vorhandenen `/ft`-Befehle bleiben zusätzlich erhalten.


## v0.7.0 – Omen-artige Threat-Informationen

Neu:

- `Δ`-Spalte: Threat-Differenz zum aktuellen Aggrohalter
- aktueller Tank/Aggrohalter wird konsequent oben priorisiert
- eigener Spieler kann deutlich hervorgehoben werden
- Pets können optional in die Threat-Liste aufgenommen werden
- Pets erhalten `[P]` als Kennzeichnung
- Tank erhält `[T]` nur noch anhand des ermittelten aktuellen Aggrohalters
- stabilere Sortierung bei sehr ähnlichen Threat-Werten
- Ziel des Gegners (`targettarget`) hat höchste Priorität für die Tank-Erkennung
- Fallback auf `isTanking` / Threat-Status, wenn targettarget nicht verfügbar ist

Neue Einstellungen unter `/ft config`:

- Abstand zum Tank (Δ) anzeigen
- Eigenen Spieler hervorheben
- Pets anzeigen

Beispiel:

`1. [T] Tank       18.4k     0   100%`
`2.     Spieler    15.1k  -3.3k   82%`

Zusätzlich wurden die Zeilen-Erzeugung aus v0.6 und die LibDBIcon-Registrierung
intern aufgeräumt, ohne das bisherige Verhalten zu verändern.


## v0.7.1 – Kompaktere Fensterbreite

- Standardbreite von 365 px auf 274 px reduziert (75 % der bisherigen Breite)
- minimale Breite auf 183 px reduziert (50 % der bisherigen Breite)
- Höhe bleibt unverändert
- bestehende Nutzer mit der alten Standardbreite werden einmalig auf 274 px migriert
- Threat-/Delta-/Prozent-Spalten wurden kompakter gesetzt, damit die kleinere Breite nutzbar bleibt


## v0.8.0 – Konfigurationszentrum & Welcome Screen

ForeverThreat besitzt jetzt ein eigenes In-Addon-Konfigurationszentrum.

Rubriken:

- Willkommen
- Anzeige
- Warnungen
- Allgemein

Neu:

- Welcome Screen beim ersten Start von v0.8
- eigener Einstellungen-Button direkt am Threat-Fenster
- `/ft config` öffnet die Anzeige-Einstellungen
- `/ft welcome` öffnet die Willkommensseite
- `/ft wowsettings` öffnet zusätzlich die WoW-Einstellungskategorie
- Einstellungen direkt im Addon statt ausschließlich über die WoW-Settings
- responsive Spalten: bei sehr kleiner Fensterbreite werden Threat/Delta automatisch reduziert
- Breitenlogik vollständig auf 274 px Standard / 183 px Minimum vereinheitlicht

Die bisherige WoW-Einstellungskategorie bleibt zusätzlich erhalten.


## v0.8.1 – Welcome Screen mit ForeverThreat-Logo

- Der Welcome Screen nutzt jetzt das bereitgestellte ForeverThreat-Bild als großes Logo.
- Das Logo wird rechts im Willkommen-Tab angezeigt.
- Intro- und Schnellstart-Texte wurden so angepasst, dass sie sauber neben dem Logo sitzen.
- Neue Datei: `Media/WelcomeLogo.tga`


## v0.8.2 – Config-Tab Bugfix

- Lua-Fehler beim Öffnen des Konfigurationsfensters behoben.
- `UIPanelButtonTemplate` besitzt kein direktes `SetTextColor()`.
- Tab-Textfarben werden jetzt korrekt über `button.Text:SetTextColor()` gesetzt.


## v0.8.3 – Welcome Screen aufgeräumt

- Redundanten Button `Anzeige einstellen` entfernt.
- Der obere Tab `Anzeige` übernimmt diese Navigation bereits.
- `Warnsound testen` wurde in die frei gewordene Position verschoben.


## v0.8.4 – Welcome Screen bereinigt

- Kleinen zusätzlichen `ForeverThreat`-Schriftzug im Welcome Screen entfernt.
- Der Name steht bereits groß im Logo und wird deshalb nicht doppelt angezeigt.


## v0.8.5 – Forever-Kompatibilitätsfix für Tabs

- Tab-Schriftfarben werden nicht mehr per Button-/FontString-Methode verändert.
- Aktiver Tab wird ausschließlich über `LockHighlight()` markiert.
- Dadurch entfällt die fehleranfällige `SetTextColor()`-Stelle vollständig.
- Für dieses Update den alten `ForeverThreat`-Ordner bitte komplett löschen und frisch installieren.


## v0.8.6 – Einstellungen über den Minimap-Button

- Rechtsklick auf den Minimap-Button öffnet direkt das ForeverThreat-Konfigurationszentrum.
- Linksklick blendet weiterhin das Threat-Fenster ein bzw. aus.
- Ziehen verändert weiterhin die Position des Minimap-Buttons.
- Das Sperren/Entsperren des Threat-Fensters bleibt im Tab `Allgemein`.
- `/ft config` bleibt als alternative Möglichkeit erhalten.


## v0.8.7 – Minimap-Mausbelegung

- Linksklick: Threat-Fenster ein-/ausblenden
- Mittelklick / Mausrad-Klick: Einstellungen öffnen
- Rechtsklick: Threat-Fenster sperren/entsperren
- Ziehen: Minimap-Position ändern


## v1.6.1 – Release Candidate

ForeverThreat wechselt in die Release-Candidate-Phase.

Wichtige Änderung:

- Das Konfigurationsfenster / der Welcome Screen öffnet sich NICHT mehr automatisch beim Login oder nach `/reload`.
- Der Welcome Screen bleibt manuell erreichbar über `/ft welcome`.
- Einstellungen bleiben erreichbar über Mittelklick auf den Minimap-Button, den Einstellungsbutton im Threat-Fenster und `/ft config`.

Aktuelle Minimap-Belegung:

- Linksklick: Threat-Fenster ein-/ausblenden
- Mittelklick / Mausrad-Klick: Einstellungen öffnen
- Rechtsklick: Threat-Fenster sperren/entsperren
- Ziehen: Minimap-Position ändern

### RC-Testfokus vor 1.0

- Solo / Gruppe / Raid
- Aggro-Wechsel
- Δ-Abstand zum Tank
- Zielwechsel
- Pets an/aus
- Fenstergröße / Kompaktmodus
- Einstellungen speichern
- Minimap-Position nach `/reload`
- Clean Install ohne andere Library-Addons
- alte SavedVariables migrieren
- keine Lua-Fehler im normalen Spielbetrieb


## v1.6.1 – WoW-Forever Secret-Value Fix

Behoben:

- `UnitIsUnit("targettarget", ...)` kann in WoW Forever einen `secret boolean` zurückgeben.
- Dieser Wert wurde bisher nach `pcall()` direkt als Boolean ausgewertet und konnte dadurch tausende Lua-Fehler erzeugen.
- `SafeUnitIsUnit()` prüft jetzt zuerst `issecretvalue()` und wertet geschützte Werte nicht mehr aus.
- Die direkte `UnitIsUnit()`-Prüfung der Aggro-Warnung wurde ebenfalls abgesichert.
- `FT:IsSecret()` / `FT:IsSafe()` wurden gehärtet, sodass Secret Values immer vor Vergleichen oder Boolean-Tests erkannt werden.

Wenn `targettarget` geschützt ist, verwendet ForeverThreat weiterhin die verfügbaren
Threat-Daten (`isTanking`, Threat-Status, skalierter Threat) als Fallback.


# ForeverThreat v1.6.1

First stable release.

Validated in real 5-player dungeon gameplay on WoW Forever.

Highlights:
- Live party and raid threat meter
- Tank detection and tank marker
- Scaled threat percentage display
- Absolute threat values where available
- Threat delta display where values are readable
- Player highlighting
- Optional pet display
- Aggro warnings with sound
- High-threat warning
- Resizable and lockable threat window
- Compact layout support
- Integrated settings UI with categories
- Welcome screen available on demand
- Embedded LibStub, CallbackHandler-1.0, LibDataBroker-1.1 and LibDBIcon-1.0
- Standalone installation; no external library addon required
- Minimap button:
  - Left click: show/hide threat window
  - Middle click: open settings
  - Right click: lock/unlock threat window
  - Drag: move minimap button
- Saved position and size
- WoW Forever secret-value protection
- No automatic settings window on login or /reload

Useful commands:
- /ft
- /ft config
- /ft welcome
- /ft wowsettings
- /ft testsound
- /ft auto on
- /ft auto off
- /ft size <width> <height>
- /ft width <width>
- /ft height <height>
- /ft resetsize


## DE / EN Localization

- ForeverThreat starts in German on German (`deDE`) WoW clients.
- All other client languages start in English.
- Language can be switched live under **General → Language** without `/reload`.
- The selected language is saved.
- Slash alternatives: `/ft lang de` and `/ft lang en`.


## v1.6.1

- Added full DE / EN localization.
- German WoW clients start in German.
- All other client languages start in English.
- Language can be switched live without `/reload`.
- Selected language is saved automatically.


## v1.6.1

- SavedVariables persistence is now fully supported in WoW Forever.
- ForeverThreat settings now persist reliably between reloads and game restarts.
- No additional SavedVariables workaround is required.


## v1.6.1

- Added Auto / Tank / DPS threat display modes.
- Auto mode detects whether the player is the current tank and adapts the display behavior.
- Added dynamic threat colors:
  - yellow at 70%+
  - orange at 85%+
  - red at 95%+
- Tank mode emphasizes group members approaching the tank's threat.
- DPS mode emphasizes the player's own threat level.
- Added optional target-of-target display in the header.
- Added a clear aggro-switch marker: the new aggro holder briefly receives a `[!]` marker and row highlight.
- Added settings for dynamic colors, target-of-target and aggro-switch highlighting.
- Added `/ft mode auto|tank|dps`.
- Preserved existing WoW Forever secret-value safety and SavedVariables behavior.


## v1.6.1

- Added Smart Auto-Hide (opt-in): the meter hides outside combat only when no hostile target or usable threat data remains.
- Added automatic Combat Lock for moving/resizing the threat window.
- Added a more readable threat-gap display showing the remaining distance until the current tank/aggro holder.
- Added configurable update interval from 0.05 to 0.50 seconds for performance tuning, especially in larger groups and raids.
- Existing Auto / Tank / DPS modes, dynamic colors, Target-of-Target, localization, SavedVariables and secret-value protection remain supported.


## v1.6.1

- Improved target switching: old threat rows and warning state are cleared immediately when changing targets.
- Added display presets:
  - Minimal
  - Standard
  - Tank
  - DPS
- Added `/ft preset minimal|standard|tank|dps`.
- Added a complete settings reset, including `/ft resetall`.
- The in-addon reset button uses a two-click confirmation to prevent accidental resets.
- Added optional **Auto-Show only with Threat Data**.
  - When enabled together with combat auto-show, ForeverThreat waits until the current hostile target actually provides usable threat data before opening.
- Existing Smart Auto-Hide, Combat Lock, update interval, SavedVariables, DE/EN localization and secret-value safety remain supported.


## v1.6.1

- Added a dedicated Healer threat mode.
  - Healer mode emphasizes the player's own threat.
  - Dynamic warning colors start earlier at 60% / 75% / 90%.
- Added a Healer display preset.
- Added profile export/import as a portable text string.
  - Transfers display, warning and behavior settings.
  - Does not transfer window position, minimap position or language.
- Added `/ft profile`, `/ft mode healer` and `/ft preset healer`.
- Added informative aggro handoff messages:
  - `Aggro → Player`
  - `Aggro lost to Player`
- Added an option to disable aggro handoff messages independently from row highlighting.
- Completed a DE/EN localization key audit for the current UI.
- Localized the debug output.
- Hardened WoW Forever client compatibility:
  - explicit `## AllowLoadGameType: camelot`
  - accepts Interface `16001` and `16002`
- Existing secret-value safety, SavedVariables and the stable threat logic remain unchanged.


## v1.6.1

### Raid & Performance
- Added adaptive raid refresh rates.
  - 10-player raids: at least 0.20 s
  - 20-player raids: at least 0.25 s
  - 30-player raids: at least 0.30 s
  - 40-player raids: at least 0.35 s
  - Your configured update interval remains the base value and can still be slower.
- Threat update events are now coalesced instead of triggering a full group scan for every individual `UNIT_THREAT_*` event.
- Added a cached group roster so static unit metadata is not rebuilt on every threat refresh.
- Target-of-target matching now short-circuits after the actual target is found.
- Added configurable raid Top-X display.
  - Default: Top 10.
  - Optional own-player retention keeps your character visible even outside the Top-X.
  - The original threat rank remains visible when your player is pulled into the displayed list.
- Improved raid pet handling.
  - With pets enabled, your own pet remains available in raids.
  - Scanning every raid pet is now a separate opt-in option to avoid unnecessary work in pet-heavy raids.
- Added `/ft debug` performance information for current group size and effective update rate.
- Existing Tank / DPS / Healer modes, aggro warnings, profile export/import, SavedVariables and WoW Forever secret-value protection remain unchanged.


## v1.6.1

### Final planned feature release
- Added Target / Focus threat source selection.
  - The full meter, target-of-target logic, aggro warnings and debug output follow the selected source.
  - `/ft source target`
  - `/ft source focus`
- Added a dedicated Tank aggro-loss warning.
  - Only triggers after the player actually held aggro and then loses it.
  - Separate on-screen warning and sound toggles.
  - Initial pulls remain silent.
- Added configurable Yellow / Orange / Red threat thresholds for Tank, DPS and Healer modes.
  - DPS / Healer red threshold also controls the HIGH THREAT! warning.
  - Defaults preserve the established behavior:
    - Tank: 70 / 85 / 95
    - DPS: 70 / 85 / 95
    - Healer: 60 / 75 / 90
- Added an in-game UI Test Mode with ten simulated threat entries.
  - Lets users configure size, rows, colors and thresholds without being in combat or a group.
  - `/ft test`
  - Test mode cannot be started in combat and automatically ends when combat starts.
- Profile export/import now includes the new source, tank warning and threshold settings.
- Existing raid/performance optimizations, secret-value protection, DE/EN localization and WoW Forever compatibility remain intact.

This is the final planned feature build. Future releases should focus on bug fixes, client compatibility, performance and real tester feedback.


## v1.6.1

### Spanish Localization
- Added complete Spanish localization for all ForeverThreat UI, warnings, tooltips, settings, profiles, debug text and slash-command help.
- `esES` and `esMX` WoW clients now start in Spanish automatically on a fresh configuration.
- `deDE` continues to start in German.
- All other client languages continue to start in English.
- German / English / Spanish can be switched live without `/reload`.
- Added `/ft lang es`.
- The selected language continues to be saved in SavedVariables.
- Added Spanish addon metadata notes for `esES` and `esMX`.
- No gameplay, threat calculation, raid-performance or secret-value logic was changed.


## v1.6.2 — Three color skins
- Three switchable visual skins: Classic Orange (existing default), Frost Blue and Crimson Red.
- Choose instantly on the Display tab or with `/ft skin orange|frost|crimson`. No reload needed.
- Window backdrop, frame borders, title accents and row-background colors follow the selected skin.
- Class bars, threat warning thresholds and aggro alert colors remain independent and unchanged.
- Skin preference is saved per character and included in profile export/import; older profiles stay compatible.
- Complete German, English and Spanish skin labels and help messages.
- No threat API, raid performance or combat-warning behavior changes.


## v1.6.3 — Font compatibility hotfix

- Replaced the Unicode right-arrow glyph with ASCII `->` in runtime UI text.
- Fixes missing-glyph square/rectangle placeholders in aggro-change warnings on WoW Forever fonts.
- Also applies to Tank aggro-loss and Target/Focus target displays to prevent the same issue there.
- No threat calculation, SavedVariables, skin, localization logic or raid-performance behavior changed.


## v1.6.4 — Idle Dimming QoL

- Added optional Idle Dimming for the main threat window.
- The window remains visible instead of being hidden while Idle Dimming is enabled.
- Full configured opacity is restored automatically when:
  - the player enters combat,
  - meaningful threat data is available,
  - the mouse is over the threat window,
  - UI Test Mode is active.
- Idle opacity is configurable from 10% to 100% (default value: 35%).
- Idle Dimming is disabled by default for existing behavior compatibility.
- If Idle Dimming and Smart Auto-Hide are both enabled, Idle Dimming takes priority so the window stays visible.
- Added DE / EN / ES localization for the new settings.

## v1.6.5 — Five-language localization

- Added complete French (`frFR`) and Korean (`koKR`) localization.
- ForeverThreat now supports exactly five selectable languages:
  - Deutsch
  - English
  - Español
  - Français
  - 한국어
- Replaced the old language buttons with a five-entry language dropdown.
- Client language is detected automatically on first launch only as an internal default:
  - `deDE` -> German
  - `enUS` / `enGB` -> English
  - `esES` / `esMX` -> Spanish
  - `frFR` -> French
  - `koKR` -> Korean
  - every other client locale -> English
- Automatic detection is not exposed as a selectable option.
- Manual language selection is saved in `ForeverThreatDB` and restored on later logins.
- Language switching remains live and does not require `/reload`.
- Added live refresh for active combat warnings, profile status messages, the configuration UI and supported Blizzard Settings labels.
- Added `/ft lang fr` and `/ft lang ko`.
- Missing localization keys continue to fall back to English.
- Existing settings, profiles, skins, threat logic, raid optimizations and SavedVariables are preserved.


## v1.6.6 — Taunt / Tank-Swap QoL

- Added taunt-aware Tank aggro-loss handling.
- ForeverThreat watches the selected Target/Focus for supported taunt combat-log events.
- When the player was the Tank-mode aggro holder and the new aggro holder is the player who just successfully taunted that same enemy:
  - the red aggro-loss warning is suppressed,
  - the aggro-loss sound is suppressed,
  - an optional subtle `TANK SWAP -> Name` message is shown instead.
- Real aggro loss without a matching recent taunt continues to trigger the normal warning and sound.
- Added separate options for taunt/tank-swap detection and the tank-swap message.
- Added full DE / EN / ES / FR / KO localization for the new controls and message.
- The combat-log event does not trigger additional full threat scans, preserving the existing raid-performance behavior.


## v1.6.7 — Threat Reset Protection

- Added optional threat-reset protection for boss/mechanic threat wipes.
- ForeverThreat now distinguishes a sustained complete threat drop from a normal aggro handoff.
- A reset is only confirmed when:
  - the same Target/Focus previously had active threat,
  - the player is still in combat,
  - all usable threat signals remain absent for a short confirmation window.
- While a reset is pending or confirmed, Tank aggro-loss warnings and handoff processing are suppressed.
- A single short API gap does not immediately count as a reset.
- Target/Focus changes are explicitly excluded from reset detection.
- Added a toggle in Warnings and Blizzard Settings.
- Added full DE / EN / ES / FR / KO localization.


## v1.6.8 — Forever Protected-Event Hotfix

- Removed registration of `COMBAT_LOG_EVENT_UNFILTERED`.
  - WoW Forever blocks addons from registering this event and can show the
    "action only available to the Blizzard UI" Disable / Ignore dialog at login.
- Taunt / Tank-Swap detection now uses `UNIT_SPELLCAST_SUCCEEDED`.
- Taunt detection is intentionally conservative:
  - only player / party / raid unit casts are considered,
  - the spell ID must match a supported taunt,
  - the caster must currently target the same hostile Target/Focus tracked by ForeverThreat.
- This avoids suppressing a real aggro-loss warning when another mob is taunted.
- Mouseover/focus-macro taunts where the caster is not targeting the tracked enemy may
  intentionally fall back to the normal aggro-loss warning rather than risk a false tank-swap detection.
- Threat Reset Protection from 1.6.7 remains unchanged.
- No SavedVariables migration is required.


## v1.6.9 — Discord Support Integration

- Added a permanently visible `Discord Support` button to the Welcome tab.
- Added a separate movable Discord Support window.
- Official support link: `https://discord.gg/srPrK7QWGb`
- The link is shown in an EditBox, automatically focused and fully selected whenever the window opens.
- `Ctrl + C` can be used immediately; the link cannot be permanently overwritten.
- Added a localized "Select link" button.
- The support window:
  - uses `FULLSCREEN_DIALOG`,
  - is raised again whenever reopened,
  - stays above ForeverThreat's own windows,
  - closes with X or ESC,
  - clears keyboard focus when closed,
  - never opens automatically.
- Added full DE / EN / ES / FR / KO localization with live language switching.
- No SavedVariables or profile changes.


## v1.6.10 — Taunt Diagnostics & Aggro Visibility

- Added `/ft debugtaunt` as a runtime-only diagnostic mode.
- Taunt diagnostics only logs supported taunt spell casts and reports whether:
  - the cast matches ForeverThreat's current Target/Focus,
  - the taunt was accepted as a tank-swap candidate,
  - tank-swap detection is disabled,
  - required target/player data was unavailable.
- The diagnostic mode is not saved and is disabled again after `/reload`.
- Improved aggro-change visibility:
  - the new aggro holder now receives a stronger red-orange row flash,
  - the rank column temporarily changes to a bright `!`,
  - the existing `[!]` name marker remains visible,
  - the highlight duration is increased from 2 to 3 seconds.
- No Combat Log APIs are used.
- No SavedVariables or profile changes.


## v1.6.11 — Appearance Customization

- Added a new Appearance tab.
- Added selectable threat-bar textures:
  - Blizzard
  - Smooth / Solid
- Added bar rendering styles:
  - Flat
  - Color Gradient
- Added threat-window styles:
  - ForeverThreat
  - Blizzard UI
  - Minimal
- Added an option to hide the `FOREVERTHREAT` header.
  - Hiding the header also compacts the threat list upward.
  - Target text, close button and settings button remain available.
- Added one-click appearance presets:
  - Default
  - Blizzard UI
  - Minimal
- Existing class colors and dynamic threat colors remain unchanged.
- Added DE / EN / ES / FR / KO localization.
- Existing settings and profiles remain compatible.


## v1.6.12 — Threat per Second (TPS)

- Added optional Threat-per-Second tracking for every visible threat entry.
- TPS is calculated from safe `rawThreat` changes over time.
- Added time-based smoothing so the value remains readable instead of jumping on every update.
- Threat decreases and full threat resets are treated as a fresh baseline, never as negative TPS.
- Detected taunt threat jumps are excluded from generated TPS.
- TPS resets automatically on:
  - Target / Focus source changes
  - Combat start / end
  - Confirmed threat resets
- The TPS column is responsive:
  - prioritized at normal compact window width when enabled,
  - Delta and raw Threat columns return automatically when the window is widened.
- TPS is disabled by default to preserve existing layouts.
- Added TPS values to UI Test Mode.
- Added full DE / EN / ES / FR / KO localization.


## v1.6.13 — TPS Setting Visibility Fix

- Moved the **Show Threat per Second (TPS)** option into the main Display checkbox list.
- TPS now appears directly below **Show Threat Value**.
- No TPS calculation or SavedVariables changes.


## v1.6.14 — Display Preset Button Position Fix

- Moved the Display preset buttons slightly further down.
- Shifted the following Display sections down as well to keep spacing clean.
- No logic or SavedVariables changes.


## v1.6.15 — Secure Taunt Assist

- Added an optional separate **Secure Taunt** button.
- Right-click casts the player's supported single-target taunt on ForeverThreat's configured Target / Focus source.
- Supported class taunts: Warrior, Druid, Paladin, Death Knight, Monk and Demon Hunter.
- The secure button is parented and anchored only to `UIParent`; it is never parented or anchored to the dynamic threat window.
- Secure attribute and visibility changes are deferred until combat ends.
- Threat source changes are blocked during combat while Secure Taunt is enabled to prevent stale secure targeting.
- Left-drag moves the button while out of combat.
- Disabled by default.
- Full DE / EN / ES / FR / KO localization.


## v1.7.0 — Level 60 Endgame Pass

### Time to Aggro / Tank Lead
- Added an optional ETA column.
- ETA uses the smoothed change of Blizzard's scaled threat percentage rather than raw threat distance alone.
- Non-tank rows show estimated seconds until reaching the aggro threshold.
- The current aggro holder shows `L` (Lead) with the estimated time before the fastest-closing competitor reaches the threshold.
- Short lead / ETA values receive stronger warning colors.
- ETA is enabled by default and prioritized in compact layouts.

### 40-player Raid Performance
- Added staged threat scanning for raids with 30+ members when Adaptive Raid Updates are enabled.
- The player, current tank/target and previous top threat competitors remain on the fast scan path.
- The remaining raid roster is refreshed with a full scan approximately every 1.25 seconds.
- This reduces repeated `UnitDetailedThreatSituation` calls while preserving fast updates for dangerous threat changes.
- The scan cache resets on roster or threat-source changes.

### Raid Tank View
- Added an optional compact Raid Tank View, enabled by default.
- In Tank mode while raiding, the display is reduced to up to six useful rows:
  - current aggro holder,
  - the player,
  - highest threat competitors.
- Normal Raid Top-X behavior remains available outside Tank mode.

### Compatibility
- Existing TPS, Secure Taunt, Threat Reset Protection, Tank Swap detection and warning logic remain intact.
- SavedVariables migrate to dbVersion 26.
- Full DE / EN / ES / FR / KO localization.

## v1.7.1 — Level 60 Release Polish

- Added a separate **Optimized 40-player scan** option.
- Optimized scanning is disabled by default; the proven full threat scan remains the stable default.
- Added a one-click **Level 60 Raid Preset** with conservative raid settings.
- The raid preset keeps optimized scanning disabled by default.
- SavedVariables migrate to dbVersion 27.
- Full DE / EN / ES / FR / KO localization.

## v1.7.2 — Secure Taunt Cooldown Display

- Added the detected class taunt spell icon to the Secure Taunt button.
- Added a cooldown swipe directly on the taunt icon.
- Added a compact remaining-cooldown seconds display.
- The short global cooldown is intentionally ignored so the display represents the actual taunt cooldown.
- The taunt icon desaturates while the taunt is unavailable.
- No SavedVariables or threat-calculation changes.


## v1.7.3 — Display Layout Fix

- Fixed the final Display option **Show Gap to Aggro** being covered by the Display preset buttons.
- Moved the preset row and the following Source / Skin sections further down.
- No gameplay, threat-calculation or SavedVariables changes.


## v1.7.4 — Time to Aggro Warning

- Added an optional **Time to Aggro warning** for the player's own threat.
- Warns at **5 seconds or less** only while the estimated ETA is still decreasing.
- Uses the existing screen-warning system and warning sound setting.
- Does not warn in Tank mode or while the player already has aggro.
- Rearms after threat distance becomes safe again.
- Resets on target/source changes and confirmed threat resets.
- ETA calculation remains available for the warning even when the ETA column itself is hidden.
- SavedVariables migrate to dbVersion 28.
- Full DE / EN / ES / FR / KO localization.


## v1.8.0 — Native WoW Meter Redesign

- Reworked the main ForeverThreat window to visually match WoW's built-in Damage Meter.
- Uses Blizzard meter atlases when available:
  - native meter header
  - meter background
  - native bar shadow / edge
  - native bar texture
  - class icon atlases
  - Blizzard settings button artwork
- Added compact class icons to threat rows.
- Added a tank marker overlay on the class icon.
- Reworked the header:
  - compact native title bar
  - dynamic `Threat: Target` title
  - T / F source switch
  - native settings button
  - compact hide/minimize area
- Raw threat and percentage now share the native right-aligned meter value field in WoW Meter style.
- ETA / TPS / Delta remain available when the window is widened.
- Old ForeverThreat and Minimal window styles remain available.
- Existing threat logic, TPS, ETA warnings, raid features and Secure Taunt are unchanged.
- SavedVariables migrate to dbVersion 29.


## v1.8.1 — Font Placeholder Hotfix

- Replaced unsupported special characters in the live meter UI.
- Header toggle no longer uses the Unicode triangle glyph.
- Empty / no-value threat placeholders now use a plain hyphen instead of an em dash.
- Fixes the square placeholder boxes visible in some WoW Forever font contexts.


## v1.9.0 — Configuration Redesign

- Reorganized the configuration for first-time users.
- Added a dedicated Raid tab.
- Display now focuses on presets, mode, essential values and optional detail values.
- Appearance now owns all visual style, skin, size and readability controls.
- General now contains window behavior, language, update rate and maintenance only.
- Raid performance and raid list options were removed from General and grouped in the Raid tab.
- Reduced vertical overflow across all main pages.
- No threat calculation or combat logic changes.


## v1.9.1 — Welcome Layout Polish

- Reworked the Welcome page into a centered vertical layout.
- Moved the ForeverThreat logo to the top center.
- Welcome title and intro now use the full content width below the logo.
- Quick Start uses the full page width instead of sharing space with the logo.
- Centered the main action buttons and added subtle separators for clearer visual hierarchy.
- No threat logic or SavedVariables changes.


## v1.9.2 — Header Alignment Fix

- Right-aligned the native meter header control group.
- Target/Focus source button, settings button and hide button now sit together at the far right.
- The dynamic threat title now uses the remaining space to the left of the control group.
- No threat logic or SavedVariables changes.


## v1.9.3 — Native Header Right Alignment

- Anchored the visible native header controls directly to the right edge of the threat window.
- Settings is now the right-most control.
- Target / Focus sits directly to its left.
- Hide / minimize sits directly to the left of the source button.
- The dynamic title uses only the remaining space on the left.
- No threat logic or SavedVariables changes.


## v1.9.4 — Header Anchor Hotfix

- Fixed `SetPoint would result in anchor family connection`.
- Removed all chained anchors between native header controls.
- Settings, Target/Focus, Hide/Minimize and the dynamic title now anchor directly to the main ForeverThreat frame.
- Keeps the header controls right-aligned without creating protected / invalid anchor families.
- No threat logic or SavedVariables changes.


## v1.9.5 — Russian Localization

- Added full **Russian (Русский)** localization.
- Added `ruRU` automatic client-language detection on first setup.
- Added Russian to the live language dropdown.
- Added `/ft lang ru` and `/ft language ru`.
- Russian covers all current UI, tooltips, warnings, raid settings, debug text and profile screens.
- Language selection remains persistent and can be changed live without `/reload`.
- SavedVariables migrate to dbVersion 30.


## v1.9.6 — Russian UI Fit Fix

- Added automatic font fitting for localized configuration buttons.
- Long translated button labels now shrink only as much as needed to remain inside their button.
- The fitting is reapplied automatically when switching language live.
- Added dedicated handling for:
  - top navigation tabs
  - display / mode / source buttons
  - appearance and skin buttons
  - maintenance / reset buttons
  - runtime test / confirmation button text
- Shortened the Russian Welcome tab label to `Старт` so the seven-tab navigation stays readable.
- No threat logic or SavedVariables changes.


## v1.9.7 — Cyrillic Button Font Hotfix

- Fixed square placeholder glyphs on Russian configuration buttons.
- Some Forever clients use a Latin-only font through `UIPanelButtonTemplate`.
- Localized ForeverThreat buttons now use WoW's Cyrillic-capable standard GameFont objects.
- Automatic button text fitting from v1.9.6 remains active.
- The fix also applies to:
  - navigation tabs
  - presets
  - mode / source buttons
  - appearance buttons
  - maintenance buttons
  - language dropdown and language options
- No threat logic or SavedVariables changes.


## v1.9.8 — Direct Cyrillic Font Hotfix

- Fixed Russian button glyphs still appearing as square placeholders.
- Russian configuration buttons now bind directly to Blizzard's Cyrillic Friz font:
  - `Fonts\FRIZQT___CYR.TTF`
- This bypasses the Latin-only font inherited by `UIPanelButtonTemplate` on some non-Russian clients.
- Switching away from Russian restores the normal WoW button font automatically.
- Automatic text fitting from v1.9.6 remains active and now measures the actual Cyrillic font.
- Applies to all localized configuration buttons, tabs and language controls.
- No threat logic or SavedVariables changes.


## v1.9.9 — Korean / Russian Language Button Font Fix

- Fixed square placeholder glyphs on the Korean and Russian entries inside the language dropdown.
- Language option buttons now use a font based on the option itself, not the currently active interface language.
- Korean option uses Blizzard's `Fonts\2002.TTF`.
- Russian option uses Blizzard's `Fonts\FRIZQT___CYR.TTF`.
- Other language options continue to use the normal WoW font.
- Automatic text fitting remains active.
- No threat logic or SavedVariables changes.


## v1.9.10 — Korean Active UI Font Fix

- Fixed square placeholder glyphs when Korean is selected as the active interface language.
- All localized configuration buttons now choose their font from the active UI language:
  - Korean -> `Fonts\2002.TTF`
  - Russian -> `Fonts\FRIZQT___CYR.TTF`
  - DE / EN / ES / FR -> normal WoW font
- Language dropdown options still keep their own per-language fonts independently.
- Automatic button text fitting remains active.
- No threat logic or SavedVariables changes.


## v1.10.0 — Configurable Warning Thresholds

- Added a dedicated High Threat warning threshold.
- Added a configurable Time to Aggro warning threshold (1–15 seconds).
- High Threat alerts are now independent from the red threat-color threshold.
- Time to Aggro warnings keep their existing closing-threat safety check and rearm automatically above the configured threshold.
- Added both controls to the ForeverThreat configuration and Blizzard AddOn Settings.
- Updated all six localizations.
- Existing profiles and positions are preserved through dbVersion 31 migration.


## v1.11.0 — Tank Lead Warning & Distinct Alert Sounds

- Added an optional Tank Lead warning for tanks.
- Added an adjustable Tank Lead warning threshold from 1 to 15 seconds.
- The warning only fires when the calculated tank lead is critically low and still shrinking.
- Aggro, High Threat, Time to Aggro and Tank Lead now use distinct alert sounds.
- Tank aggro-loss keeps its existing separate sound.
- Added the Tank Lead controls to both ForeverThreat and Blizzard AddOn settings.
- Added all new labels and messages to DE / EN / ES / FR / KO / RU.
- Existing settings migrate automatically to dbVersion 32.


## v1.12.0 — Raid Focus & Usability

- Added the optional **Tanks + Danger** raid view.
- The focused raid view keeps assigned tanks, the current aggro holder, the player and only genuinely dangerous threat competitors visible.
- Added clearer visual emphasis for the current aggro holder and next threat competitor in focused raid views.
- Added new presets:
  - Dungeon Tank
  - Raid Tank
  - Raid DPS
- Expanded the in-game help text for TPS, Time to Aggro, Tank Lead, Threat Gap and Optimized Raid Scan.
- Added Tanks + Danger to Blizzard AddOn settings.
- Optimized raid scanning now prioritizes assigned tanks when role information is available.
- Added all new UI text in DE / EN / ES / FR / KO / RU.
- Existing settings migrate automatically to dbVersion 33.


## v1.12.1 — Warning Sound Controls

- Warning sounds are now disabled while playing solo by default.
- Added an optional **Warning sounds while solo** toggle.
- Added a dedicated **Warning sound volume** slider (10–100%).
- Default ForeverThreat warning volume is now 35%.
- Warning sounds now use the SFX channel instead of forcing playback through Master.
- Uses the current WoW Forever sound API's per-playback volume control when available.
- Aggro-loss sounds now also respect the global warning-sound toggle and solo-sound setting.
- Test buttons still work even when normal warnings are disabled.
- Added the new controls to Blizzard AddOn settings.
- Added all new UI text in DE / EN / ES / FR / KO / RU.
- Existing settings migrate automatically to dbVersion 34.


## v1.12.2 — Aggro Crown

- Added the optional **Aggro Crown** visual.
- In WoW Meter style, the current aggro holder now gets a small crown on the class icon.
- The crown sits above the existing tank marker so both indicators remain readable.
- Added an option to enable or disable the crown.
- Added the option to Blizzard AddOn settings.
- Added all new text in DE / EN / ES / FR / KO / RU.
- Existing settings migrate automatically to dbVersion 35.


## v1.12.3 — Clean Tanking Streak

- Added the optional **Clean Tanking Streak** gimmick.
- In Tank mode, ForeverThreat tracks how long you continuously hold aggro.
- The current streak is shown together with the best streak of the current login session.
- The active streak ends when you lose aggro or leave combat.
- Session best is runtime-only and resets on reload/login.
- The feature uses existing threat state and does not use combat-log events.
- Added a toggle to the ForeverThreat display settings and Blizzard AddOn settings.
- Added all new text in DE / EN / ES / FR / KO / RU.
- Existing settings migrate automatically to dbVersion 36.


## v1.12.4 — Threat Race / Top 3

- Added the optional **Threat Race / Top 3** visual.
- The three highest threat positions are now subtly highlighted.
- Top positions use clear `#1`, `#2` and `#3` markers.
- Aggro-change flashes remain higher priority than the Top-3 styling.
- The feature does not change sorting, threat values, warnings or calculations.
- Added a toggle to the ForeverThreat display settings and Blizzard AddOn settings.
- Added all new text in DE / EN / ES / FR / KO / RU.
- Existing settings migrate automatically to dbVersion 37.


## v1.12.5 — Danger Messages / Fun Mode

- Added optional **Danger Messages / Fun Mode**.
- Fun Mode is disabled by default.
- Non-tanks can receive small playful messages when they get extremely close to taking aggro.
- Example situations:
  - `Living dangerously...` around 97% threat.
  - `One crit away...` around 99% threat.
  - `That was close!` after safely dropping back from a dangerous threat level.
- Fun messages use their own display and never replace real aggro, Time to Aggro or Tank Lead warnings.
- Fun messages do not play sounds.
- Fun Mode only reacts to real party/raid threat situations.
- Added the toggle to ForeverThreat display settings and Blizzard AddOn settings.
- Added all new text in DE / EN / ES / FR / KO / RU.
- Existing settings migrate automatically to dbVersion 38.


## v1.13.0 — Session Statistics

- Added a dedicated **Statistics** tab.
- Tracks runtime-only session values:
  - Longest Clean Tanking Streak
  - Aggro Lost
  - Aggro Gained
  - Detected Tank Swaps
  - Longest Tank Lead
  - Best Threat Rank
  - Highest Threat %
  - Closest Time to Aggro
  - Session Time
- Added a **Reset Session Statistics** button.
- Test Mode does not affect statistics.
- Statistics are not written as combat history and reset on reload/login.
- Uses threat data ForeverThreat already calculates; no combat-log event was added.
- Added all new UI text in DE / EN / ES / FR / KO / RU.
- SavedVariables migration updated to dbVersion 39.
