# DARK arpg

Ein extrem düsteres Action-RPG für den PC im Stil von Diablo – **kein Horror**, sondern drückende, bedrohliche Atmosphäre. Die Spielstruktur folgt dem Run-Prinzip von Hades: kurze, abgeschlossene Durchläufe mit Fortschritt zwischen den Runs.

> Status: frühe Konzeptphase. Engine und Tech-Stack sind noch offen.

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
| Plattform | PC |
| Genre | Action-RPG, Diablo-artig |
| Perspektive | Top-down 2D |
| Ton | Extrem düster, kein Horror |
| Spielstruktur | Run-basiert (Hades-artig) |
| Engine | offen |
| Sprache der Doku | Deutsch (Code/Identifier Englisch) |

## Repository

Aktuell enthält das Repository nur die Projektdokumentation. Struktur und Build-Anleitung folgen, sobald die Engine festgelegt ist.

## Offene Punkte

- Engine / Tech-Stack
- Kamera- und Rendering-Ansatz für die eingeschränkte Sicht (Licht, Sichtkegel, Fog of War)
- Audio-Middleware (z. B. FMOD/Wwise oder engine-eigene Lösung)
- Klassen, Fähigkeiten und Ausrüstungssystem
- Setting, Name und Story
