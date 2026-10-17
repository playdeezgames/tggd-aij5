#!/usr/bin/env bash
# Native tests of the pure game package, plus a wasm type-check of every package. Usage: tools/test.sh
set -euo pipefail
cd "$(dirname "$0")/.."
# The page's sound list must match game.Sound, and every asset it loads must exist.
python3 -I - <<'PY'
import re, os, sys
game = open("src/game/game.odin").read()
sounds = re.search(r"Sound :: enum \{(.*?)\}", game, re.S).group(1)
names = [n.strip().rstrip(",").lower() for n in sounds.split("\n") if n.strip() and not n.strip().startswith("//")]
page = open("web/index.html").read()
files = re.search(r"SOUND_FILES = \[(.*?)\]", page, re.S).group(1)
listed = [f.strip().strip('"') for f in files.split(",")]
assert names == listed, "game.Sound %s != SOUND_FILES %s" % (names, listed)
for n in names + []:
    assert os.path.exists("assets/sfx/%s.wav" % n), "missing assets/sfx/%s.wav" % n
assert os.path.exists("assets/urizen.png"), "missing assets/urizen.png"
print("sound list and assets agree")
PY
odin test src/game -collection:tggd=src -define:ODIN_TEST_THREADS=1
odin check src/game -collection:tggd=src -target:js_wasm32 -no-entry-point -vet-shadowing -vet-unused
odin check src/web -collection:tggd=src -target:js_wasm32 -vet-shadowing -vet-unused
echo "ALL TESTS PASSED"
