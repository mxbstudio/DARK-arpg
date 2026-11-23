#!/usr/bin/env bash
# Baut die Web-Version und startet einen lokalen Server (zum Testen im Browser/am Handy im selben WLAN).
# Voraussetzung: Godot 4.7 im PATH (als `godot`) und installierte Web-Export-Templates.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build/web
godot --headless --path . --export-release Web build/web/index.html
PORT="${1:-8080}"
echo "Läuft auf http://localhost:${PORT}  (Handy im selben WLAN: http://<PC-IP>:${PORT})"
echo "Hinweis: Auf dem Handy per http (nicht https) kann der Browser Audio/Vollbild einschränken."
cd build/web && python3 -m http.server "$PORT"
