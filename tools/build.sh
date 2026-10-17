#!/usr/bin/env bash
# Builds the web game into build/web (git-ignored). Usage: tools/build.sh   (ODIN_FLAGS="-o:size" for shipping)
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/web
odin build src/web -collection:tggd=src -target:js_wasm32 -out:build/web/game.wasm -vet-shadowing -vet-unused ${ODIN_FLAGS:--o:speed}
cp "$(odin root)/core/sys/wasm/js/odin.js" build/web/
cp web/index.html build/web/
mkdir -p build/web/assets/sfx
cp assets/urizen.png build/web/assets/
cp assets/sfx/*.wav build/web/assets/sfx/
echo "web build: build/web (serve with tools/serve.sh)"
