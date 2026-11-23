# CLAUDE.md – Projektregeln für DARK arpg

Extrem düsteres Top-down-2D-Action-RPG (Diablo-artig, kein Horror, Run-Struktur wie Hades) für den PC. Details: `README.md`.

## Status
- Engine/Tech-Stack ist **noch nicht festgelegt**. Keine Engine-spezifischen Annahmen treffen, keine Engine-Dateien oder Projektgerüste anlegen, ohne vorher nachzufragen.
- Sobald die Engine feststeht: Build-/Test-/Run-Befehle und Projektstruktur hier ergänzen.

## Design-Säulen (bei jeder Entscheidung beachten)
1. **Eingeschränkte Sicht**: Dunkelheit ist der Normalzustand. Nichts darf den Sichtradius oder die Dunkelheit aufweichen (keine Minimap-Aufdeckung, keine globale Beleuchtung ohne Rücksprache).
2. **Akustik als Kerninformation**: Gegner und Gefahren müssen hörbar sein, bevor sie sichtbar sind. Audio ist Gameplay, nicht nur Dekoration. Metallrüstung ist lauter als leichte Ausrüstung; Lautstärke/Reichweite von Geräuschen ist ein Spielwert (Datenwert, nicht hartcodiert).
3. **Langsame, skillbasierte Kämpfe**: Angriffe mit Windup, Gewicht und Recovery. Kein Button-Mashing, keine reinen Stat-Checks. Gegner-Telegraphing muss auch über Audio lesbar sein.
4. **Run-Struktur**: Zufallsgenerierte Durchläufe plus Meta-Progression zwischen Runs. Systeme müssen run-basiert gedacht werden (Reset vs. persistenter Zustand sauber trennen).
5. **Ton**: Düster und bedrückend, aber **kein Horror** (keine Jump-Scares, keine Gore-Selbstzweck-Inhalte).

## Arbeitsregeln
- **Sprache**: Dokumentation, Commit-Nachrichten und Kommunikation auf Deutsch; Code, Identifier und Code-Kommentare auf Englisch.
- **Bei fehlenden Infos nachfragen**, statt Annahmen zu Engine, Gameplay-Werten oder Scope zu treffen.
- **Datengetrieben**: Gameplay-Werte (Schaden, Lautstärke, Sichtradius, Cooldowns, Drop-Raten) in Daten-/Konfigdateien, nicht im Code verstreut.
- **Kleine, fokussierte Änderungen**; keine unnötigen Refactorings oder Features außerhalb der Aufgabe.
- **Keine Assets mit unklarer Lizenz** einchecken; Herkunft und Lizenz von Assets dokumentieren.
- Große Binärdateien (Audio, Texturen) nicht unnötig committen; ggf. Git LFS nach Rücksprache.
- `README.md` und diese Datei aktuell halten, wenn sich Konzept oder Struktur ändern.

## Git
- Entwicklung auf dem jeweils zugewiesenen Feature-Branch; nicht direkt auf `main` pushen.
- Pull Requests nur auf ausdrückliche Anfrage erstellen.
- Aussagekräftige, knappe Commit-Nachrichten.
