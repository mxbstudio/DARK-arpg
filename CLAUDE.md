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
- Autoloads (`scripts/autoload/`): `Balance` (Werte), `Events` (Signal-Bus, u. a. `noise_emitted`), `Game` (Input-Map, Meta-Save in `user://meta.cfg`), `Sfx` (Sound-Synthese und Abspielen).
- Node-Aufbau erfolgt aktuell im Code (`*.new()`), Szenen nur für den Einstieg (`scenes/main.tscn`). Klassen mit `class_name` benennen.
- Lärm, den die KI hören soll, immer über `Events.noise_emitted` senden; hörbare Sounds positionsbezogen über `Sfx.play_at`/`Sfx.play_on` abspielen.
- Kollisionsebenen: 1 = Wände, 2 = Spieler, 3 (Wert 4) = Gegner.
- Lauf-Zustand (Tiefe, Ebene, HP) lebt in `main.gd` bzw. den Akteuren und wird pro Lauf zurückgesetzt; persistenter Meta-Zustand nur in `Game`.
- Sounds und Grafik sind Platzhalter (prozedural). Beim späteren Export muss `data/*.json` in den Export-Filter für Nicht-Ressourcen-Dateien.
- Eingabe: Gameplay liest nur Input-Actions (`Game._setup_input`). Neue Aktionen müssen auch als Touch-Button in `scripts/ui/touch_controls.gd` verfügbar sein (oder bewusst nur Desktop). `Game.touch_mode` schaltet Touch-Zielen, Hilfetexte und das UI-Skalieren um; Maus-Emulation aus Touch ist deaktiviert.
- Web/Handy: Beim Start dürfen keine langen blockierenden Berechnungen laufen (Sfx erzeugt Klänge schrittweise über mehrere Frames, `Sfx.loaded`/`finished_loading` beachten). Neue Dateien, die zur Laufzeit per `FileAccess` gelesen werden (z. B. JSON), müssen in `export_presets.cfg` (`include_filter`) enthalten sein.
- Tests in `tests/test_suite.gd` ergänzen; der Runner `tests/run_tests.gd` lädt die Suite zur Laufzeit, damit Autoloads verfügbar sind.

## Design-Säulen (bei jeder Entscheidung beachten)
1. **Eingeschränkte Sicht**: Dunkelheit ist der Normalzustand. Nichts darf den Sichtradius oder die Dunkelheit aufweichen (keine Minimap-Aufdeckung, keine globale Beleuchtung ohne Rücksprache).
2. **Akustik als Kerninformation**: Gegner und Gefahren müssen hörbar sein, bevor sie sichtbar sind. Audio ist Gameplay, nicht nur Dekoration. Metallrüstung ist lauter als leichte Ausrüstung; Lautstärke/Reichweite von Geräuschen ist ein Spielwert (Datenwert, nicht hartcodiert).
3. **Langsame, skillbasierte Kämpfe**: Angriffe mit Windup, Gewicht und Recovery. Kein Button-Mashing, keine reinen Stat-Checks. Gegner-Telegraphing muss auch über Audio lesbar sein.
4. **Run-Struktur**: Zufallsgenerierte Durchläufe plus Meta-Progression zwischen Runs. Systeme müssen run-basiert gedacht werden (Reset vs. persistenter Zustand sauber trennen).
5. **Ton**: Düster und bedrückend, aber **kein Horror** (keine Jump-Scares, keine Gore-Selbstzweck-Inhalte).

## Arbeitsregeln
- **Sprache**: Dokumentation, Commit-Nachrichten und Kommunikation auf Deutsch; Code, Identifier und Code-Kommentare auf Englisch.
- **Bei fehlenden Infos nachfragen**, statt Annahmen zu Gameplay-Werten oder Scope zu treffen.
- **Datengetrieben**: Gameplay-Werte (Schaden, Lautstärke, Sichtradius, Cooldowns, Drop-Raten) in Daten-/Konfigdateien, nicht im Code verstreut.
- **Kleine, fokussierte Änderungen**; keine unnötigen Refactorings oder Features außerhalb der Aufgabe.
- **Keine Assets mit unklarer Lizenz** einchecken; Herkunft und Lizenz von Assets dokumentieren.
- Große Binärdateien (Audio, Texturen) nicht unnötig committen; ggf. Git LFS nach Rücksprache.
- `README.md` und diese Datei aktuell halten, wenn sich Konzept oder Struktur ändern.

## Git
- Entwicklung auf dem jeweils zugewiesenen Feature-Branch; nicht direkt auf `main` pushen.
- Pull Requests nur auf ausdrückliche Anfrage erstellen.
- Aussagekräftige, knappe Commit-Nachrichten.
