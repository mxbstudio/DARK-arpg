# CLAUDE.md – Projektregeln für DARK arpg

Extrem düsteres Top-down-2D-Action-RPG (Diablo-artig, kein Horror, Run-Struktur wie Hades) für den PC. Details: `README.md`.

## Tech-Stack
- **Godot 4.7** (Standard-Build, kein .NET), **GDScript** mit statischer Typisierung, Renderer **GL Compatibility**.
- Keine Plugins/Addons oder C# ohne Rücksprache.
- Zusätzliches Ziel: **Web-Export** (Handy-Browser, Touch-Steuerung). Das Spiel muss auch ohne Maus/Tastatur voll spielbar bleiben.

## Befehle
- Spiel starten: `godot --path .`
- Tests (müssen vor jedem Commit grün sein): `godot --headless --path . -s res://tests/run_tests.gd` (Exit-Code 0 = ok)
- Smoke-Test des Hauptspiels: `godot --headless --path . --quit-after 600` – Ausgabe darf kein `SCRIPT ERROR`/`ERROR` enthalten.
- Web-Export (Templates für Godot 4.7.2 nötig): `./serve_web.sh` oder `godot --headless --path . --export-release Web build/web/index.html`. `build/` ist git-ignoriert. Der Export-Preset steht in `export_presets.cfg`, Single-Thread-Variante (läuft ohne spezielle Server-Header).
- Nach neuen Skripten/Assets einmal `godot --headless --path . --import` ausführen und die erzeugten `.uid`-/`.import`-Dateien mit committen.

## Projektstruktur & Konventionen
- `data/balance.json`: **alle** Gameplay-Werte. Zugriff über das Autoload `Balance.section("...")`. Neue Werte hier eintragen, nicht im Code.
- Weitere Datendateien über `Balance.data_file(path)`: `data/sprites.json` (Sprite-Sheets: Raster, Ankerpunkt, Skalierung, Animationen als Frame-Indizes), `data/camp.json` (Startlager: Bildkoordinaten von Begehfläche, Hindernissen, Tor, Köcher, Feuern), `data/skills.json` (Skill-Reihe: Slots, Krit, alle Skills mit Gewicht, Schaden, Vorbereiter-Mods, Auslösern und SVG-Icon).
- Grafik: `assets/` (Herkunft siehe `assets/README.md`). Figuren nutzen `SheetSprite` (Ursprung = Füße, Blickrichtung per `set_face`). Licht, das Gegner für Auto-Angriffe sichtbar macht, kommt aus Nodes der Gruppe `light_sources` mit `light_reach()`; geprüft über `Lighting.is_lit`.
- Spielfluss in `main.gd`: Modi LOADING → CAMP → RUN → DEAD → CAMP. Menüs (z. B. `LoadoutPanel`) pausieren den Baum und laufen mit `PROCESS_MODE_ALWAYS`.
- Kampf: `SkillRotation` (`scripts/combat/`) feuert die Slots der Reihe nach; `Player.fire_skill` erzeugt `Arrow`s, die Treffer, Krit, Auslöser und Effekte anwenden. Neue Skill-Arten zuerst als Daten in `skills.json`, Logik in `SkillRotation._merge` (Vorbereiter) bzw. `Arrow.hit_enemy` (Auslöser). Kampftext über `FloatText.spawn` (eigene Ebene, nicht abgedunkelt).
- Zeichenreihenfolge: Die Welt ist y-sortiert (wer weiter unten steht, ist vorn). Hintergründe/Böden haben negativen `z_index`.
- Autoloads (`scripts/autoload/`): `Balance` (Werte), `Events` (Signal-Bus, u. a. `noise_emitted`), `Game` (Input-Map, Meta-Save in `user://meta.cfg`), `Sfx` (Sound-Synthese und Abspielen).
- Node-Aufbau erfolgt aktuell im Code (`*.new()`), Szenen nur für den Einstieg (`scenes/main.tscn`). Klassen mit `class_name` benennen.
- Lärm, den die KI hören soll, immer über `Events.noise_emitted` senden; hörbare Sounds positionsbezogen über `Sfx.play_at`/`Sfx.play_on` abspielen.
- Kollisionsebenen: 1 = Wände, 2 = Spieler, 3 (Wert 4) = Gegner.
- Lauf-Zustand (Tiefe, Ebene, HP) lebt in `main.gd` bzw. den Akteuren und wird pro Lauf zurückgesetzt; persistenter Meta-Zustand nur in `Game`.
- Sounds sind Platzhalter (prozedural); Level-Grafik der Zufalls-Ebenen ebenfalls. Beim späteren Export muss `data/*.json` in den Export-Filter für Nicht-Ressourcen-Dateien.
- Eingabe: Gameplay liest nur Input-Actions (`Game._setup_input`). Neue Aktionen müssen auch als Touch-Button in `scripts/ui/touch_controls.gd` verfügbar sein (oder bewusst nur Desktop). `Game.touch_mode` schaltet Touch-Zielen, Hilfetexte und das UI-Skalieren um; Maus-Emulation aus Touch ist aktiv (für UI-Buttons); emulierte Events (`DEVICE_ID_EMULATION`) ignoriert `Game` bei der Touch-Erkennung.
- Web/Handy: Beim Start dürfen keine langen blockierenden Berechnungen laufen (Sfx erzeugt Klänge schrittweise über mehrere Frames, `Sfx.loaded`/`finished_loading` beachten). Neue Dateien, die zur Laufzeit per `FileAccess` gelesen werden (z. B. JSON), müssen in `export_presets.cfg` (`include_filter`) enthalten sein.
- Tests in `tests/test_suite.gd` ergänzen; der Runner `tests/run_tests.gd` lädt die Suite zur Laufzeit, damit Autoloads verfügbar sind.

## Design-Säulen (bei jeder Entscheidung beachten)
1. **Eingeschränkte Sicht**: Dunkelheit ist der Normalzustand. Nichts darf den Sichtradius oder die Dunkelheit aufweichen (keine Minimap-Aufdeckung, keine globale Beleuchtung ohne Rücksprache).
2. **Akustik als Kerninformation**: Gegner und Gefahren müssen hörbar sein, bevor sie sichtbar sind. Audio ist Gameplay, nicht nur Dekoration. Metallrüstung ist lauter als leichte Ausrüstung; Lautstärke/Reichweite von Geräuschen ist ein Spielwert (Datenwert, nicht hartcodiert).
3. **Automatische Angriffe, Können in Bewegung und Aufbau** (wie Death Must Die / Vampire Survivors): Der Held greift von selbst an, aber nur Gegner, die im Licht und in Sichtlinie stehen. Eine Skill-Reihe in Slots, die von links nach rechts feuert (Gewicht statt Cooldowns; Vorbereiter wie „nächster Treffer krit“ wirken auf den nächsten Skill, Auslöser reagieren darauf → Kombos). Das Können liegt in Laufen, Ausweichen, Licht, Position und dem Bau der Reihe. Gegner telegraphieren Angriffe (auch über Audio) und lassen sich davon nicht unterbrechen.
4. **Run-Struktur**: Startlager (sicherer Hub) → Lauf durch zufallsgenerierte Ebenen → Tod führt zurück ins Lager, plus Meta-Progression zwischen Runs. Systeme müssen run-basiert gedacht werden (Reset vs. persistenter Zustand sauber trennen).
5. **Ton**: Düster und bedrückend, aber **kein Horror** (keine Jump-Scares, keine Gore-Selbstzweck-Inhalte).

## Arbeitsregeln
- **Sprache**: Dokumentation, Commit-Nachrichten und Kommunikation auf Deutsch; Code, Identifier und Code-Kommentare auf Englisch.
- **Bei fehlenden Infos nachfragen**, statt Annahmen zu Gameplay-Werten oder Scope zu treffen.
- **Datengetrieben**: Gameplay-Werte (Schaden, Lautstärke, Sichtradius, Cooldowns, Drop-Raten) in Daten-/Konfigdateien, nicht im Code verstreut.
- **Kleine, fokussierte Änderungen**; keine unnötigen Refactorings oder Features außerhalb der Aufgabe.
- **Keine Assets mit unklarer Lizenz** einchecken; Herkunft und Lizenz in `assets/README.md` dokumentieren.
- Große Binärdateien (Audio, Texturen) nicht unnötig committen; ggf. Git LFS nach Rücksprache.
- `README.md` und diese Datei aktuell halten, wenn sich Konzept oder Struktur ändern.

## Git
- Entwicklung auf dem jeweils zugewiesenen Feature-Branch; nicht direkt auf `main` pushen.
- Pull Requests nur auf ausdrückliche Anfrage erstellen.
- Aussagekräftige, knappe Commit-Nachrichten.
