#!/usr/bin/env bash
# Writes assets/screenshots/*.png with headless Chrome by replaying seeded games through the page's QA parameters
# (?seed=N&keys=1,2,...; see web/index.html). Needs build/web served: PORT=8093 tools/serve.sh   (default URL below).
# The key list is a scripted game (seed 11) that keeps the torch lit; the numbers are prefixes of it.
set -euo pipefail
cd "$(dirname "$0")/.."
URL="${URL:-http://localhost:8093/}"
ALL="1,3,1,3,1,1,1,1,1,1,2,1,1,1,3,1,1,1,1,1,1,1,3,1,1,1,1,1,1,1,3,1,1,1,3,1,1,1,1,1,1,1,2,1,2,1,1,1,1,1,2,1,3,1,3,1,1,1,1,1,3,1,3,1,1,1,1,1,1,1,1,1,1,1,1,1"
mkdir -p assets/screenshots
shot() { # name, number of keys to play
  q="?seed=11"
  [ "$2" != 0 ] && q="$q&keys=$(echo "$ALL" | cut -d, -f1-"$2")"
  google-chrome --headless=new --no-sandbox --disable-gpu --hide-scrollbars --window-size=800,600 \
    --virtual-time-budget=5000 --screenshot="assets/screenshots/$1.png" "$URL$q" >/dev/null 2>&1
  echo "assets/screenshots/$1.png"
}
shot 01-title 0
shot 02-event 32
shot 03-heirs 16
shot 04-handover 27
shot 05-handoff 19
shot 06-end 76
