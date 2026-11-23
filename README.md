# DARK arpg

Ein extrem düsteres Action-RPG für den PC im Stil von Diablo – **kein Horror**, sondern drückende, bedrohliche Atmosphäre. Die Spielstruktur folgt dem Run-Prinzip von Hades: kurze, abgeschlossene Durchläufe mit Fortschritt zwischen den Runs.

> Status: erster spielbarer Prototyp (Godot 4.7, GDScript). Grafik und Sound sind Platzhalter.

## Kernideen

### Stark eingeschränkte Sicht
- Die Spielwelt ist fast vollständig dunkel; der Spieler sieht nur einen kleinen Bereich um die eigene Figur.
- Licht ist eine knappe Ressource und gleichzeitig ein Risiko (Lichtquellen können Gegner anziehen).
- Orientierung erfolgt über Licht, Umgebungsdetails und – vor allem – über Gehör.

### Detaillierte Akustik
- Gegner sind im Dunkeln **hörbar**, bevor sie sichtbar sind (Schritte, Atmen, Waffen, Rüstung).
- Räumliches Audio: Richtung und Entfernung von Geräuschen sind lesbar.
- **Metallrüstung ist lauter**: Schwere Rüstung bietet Schutz, verrät aber die eigene Position. Leichte Ausrüstung ermöglicht leises Vorgehen.
- Untergrund, Raumgröße und Hindernisse beeinflussen Schall und Hall.

### Langsame, skillbasierte Kämpfe
- Bewusstes Tempo statt Button-Mashing: Angriffe haben Gewicht, Aufbau und Erholung.
- Timing, Positionierung und Ausdauer-/Ressourcenmanagement entscheiden über Sieg oder Niederlage.
- Fehler werden bestraft, gutes Spiel wird belohnt.

### Run-Struktur (wie Hades)
- Jeder Run ist ein eigenständiger Abstieg durch zufallsgenerierte Abschnitte.
- Permanenter Fortschritt zwischen den Runs (Meta-Progression), Tod ist Teil des Spielzyklus.
- Build-Entscheidungen innerhalb eines Runs (Ausrüstung, Fähigkeiten, Segen/Flüche o. Ä.).

## Eckdaten

| Punkt | Entscheidung |
|---|---|
| Plattform | PC, zusätzlich Web-Version für den Handy-Browser |
| Genre | Action-RPG, Diablo-artig |
| Perspektive | Top-down 2D |
| Ton | Extrem düster, kein Horror |
| Spielstruktur | Run-basiert (Hades-artig) |
| Engine | Godot 4.7 (GDScript, Renderer: GL Compatibility) |
| Sprache der Doku | Deutsch (Code/Identifier Englisch) |

## Prototyp starten

1. [Godot 4.7](https://godotengine.org/download) herunterladen (kostenlos, Standard-Version, nicht .NET).
2. Godot öffnen → **Importieren** → `project.godot` aus diesem Repository wählen.
3. **F5** startet das Spiel. Kopfhörer empfohlen.

Alternativ per Kommandozeile: `godot --path .`

### Steuerung

| Taste | Aktion |
|---|---|
| WASD | Bewegen |
| Maus | Zielen |
| Linksklick | Schlag (Ausholen → Treffer → Erholung) |
| Leertaste / Rechtsklick | Ausweichen (kurz unverwundbar) |
| F | Fackel an/aus |
| T | Rüstung wechseln Leder ↔ Platte (nur im Prototyp) |
| E | Treppe hinabsteigen |
| R | Neuer Lauf nach dem Tod |
| H | Hilfe ein/aus |

## Am Handy spielen (Web-Version)

Das Spiel läuft als Webseite im Handy-Browser (Querformat), mit Touch-Steuerung:

- **Linke Bildschirmhälfte:** Stick zum Laufen. Er erscheint dort, wo du den Finger aufsetzt.
- **Rechts:** `Schlag`, `Weg` (Ausweichen), `Fackel`, `Treppe` (hinabsteigen); oben `Rüst.` (Rüstung wechseln), `?` (Hilfe) und `[ ]` (Vollbild).
- **Zielen:** automatisch auf den nächsten Gegner in Reichweite, sonst in Laufrichtung.
- Die Steuerung blendet sich bei Maus/Tastatur aus und bei Berührung wieder ein.

**Veröffentlichen (einmalig einrichten):**

1. Im GitHub-Repository unter *Settings → Pages* als Quelle **GitHub Actions** wählen.
2. Änderungen nach `main` mergen. Der Workflow `.github/workflows/web-export.yml` führt die Tests aus, exportiert die Web-Version und veröffentlicht sie. Er lässt sich auch manuell über *Actions → Run workflow* starten (der Branch muss in den Regeln der Umgebung `github-pages` erlaubt sein).
3. Die Adresse (`https://<benutzer>.github.io/DARK-arpg/`) steht danach im Workflow-Lauf. Auf dem Handy öffnen, Kopfhörer anstecken, einmal tippen (Browser starten Audio erst nach einer Berührung).

**Lokal testen:** `./serve_web.sh` (Godot und die Web-Export-Templates müssen installiert sein) baut die Version und startet einen Server auf Port 8080.

Hinweise: Das erste Laden dauert etwas (die Engine ist ca. 10 MB komprimiert, die Klänge werden beim Start erzeugt, dabei läuft ein Ladebalken). Auf schwachen Handys können die Schattenlichter ruckeln.

### Was der Prototyp zeigt

- **Dunkelheit**: Fast alles ist schwarz. Fackel (größerer, warmer Lichtradius) oder ohne Fackel (winziger, kalter Radius). Wände werfen echte Schatten.
- **Akustik**: Gegner sind über positionsbezogenen Sound hörbar (Schritte mit Krallenscharren, Atmen), bevor man sie sieht. Geräusche hinter Wänden klingen gedämpft. Die Treppe nach unten erkennt man an einem kalten Luftzug, Kohlebecken knistern.
- **Lärm als Mechanik**: Eigene Schritte, Schläge und Ausweichrollen erzeugen Lärm, den Gegner hören. Plattenrüstung schützt deutlich besser, ist aber etwa dreimal so weit hörbar und macht langsamer. Ein Knurren signalisiert, dass man gehört wurde.
- **Kampf**: Langsame Schläge mit Ausholphase, Ausdauerkosten und Erholung. Ghule kündigen Angriffe mit einem anschwellenden Knurren an, das genau beim Zuschlagen gipfelt. Während des Angriffs sind sie nicht unterbrechbar, danach verwundbar.
- **Run-Struktur**: Zufallsgenerierte Ebenen, jede Tiefe mehr Gegner. Tod beendet den Lauf. Meta-Fortschritt (Läufe, beste Tiefe, Asche als Währung) wird gespeichert, kann aber noch nicht ausgegeben werden.

Alle Sounds werden zur Laufzeit synthetisiert (keine externen Assets).

## Projektstruktur

```
project.godot          Godot-Projekt
data/balance.json      Alle Gameplay-Werte (Schaden, Lautstärke, Sicht, Tempo …)
scenes/main.tscn       Startszene
scripts/
  main.gd              Run-Steuerung: Ebenen bauen, Tiefe, Tod, Neustart
  autoload/            Balance (Werte), Events (Lärm-Signal), Game (Input, Meta-Save), Sfx (Sound-Synthese)
  world/               Level-Generator, Treppe, Kohlebecken
  actors/              Spieler, Gegner (Ghul)
  ui/                  HUD, Touch-Steuerung
  util/                Licht-Helfer
tests/                 Headless-Tests
export_presets.cfg     Export-Einstellungen (Web)
serve_web.sh           Web-Version lokal bauen und ausliefern
.github/workflows/     Automatischer Web-Export nach GitHub Pages
```

Tests: `godot --headless --path . -s res://tests/run_tests.gd`

## Offene Punkte

- Meta-Progression: Asche ausgeben (Upgrades, Startausrüstung)
- Rüstung, Waffen und Fähigkeiten als Beute bzw. Auswahl im Lauf statt Umschalten per Taste
- Weitere Gegnertypen (z. B. lautlose Jäger, Gegner, die Licht meiden oder anziehen)
- Touch: Zielen per zweitem Stick statt Auto-Zielen (optional), Leistungs-Optionen für schwache Handys
- Echte Grafik und Sounds, ggf. Audio-Middleware (FMOD/Wwise) für Hall und Okklusion
- Setting, Name und Story
