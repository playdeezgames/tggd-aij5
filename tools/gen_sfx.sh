#!/usr/bin/env bash
# Regenerates assets/sfx/*.wav from tools/sfx/gen.html (jsfxr under headless Chrome; no node needed). Deterministic.
# Usage: tools/gen_sfx.sh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p assets/sfx
dom="$(google-chrome --headless=new --no-sandbox --disable-gpu --virtual-time-budget=4000 --dump-dom "file://$PWD/tools/sfx/gen.html" 2>/dev/null)"
printf '%s' "$dom" | python3 -I -c '
import sys, re, json, base64
html = sys.stdin.read()
m = re.search(r"<pre id=\"out\">(.*?)</pre>", html, re.S)
data = json.loads(m.group(1))
for name, b64 in data.items():
    open("assets/sfx/%s.wav" % name, "wb").write(base64.b64decode(b64))
    print("assets/sfx/%s.wav" % name, len(base64.b64decode(b64)), "bytes")
'
