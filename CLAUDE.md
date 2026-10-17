# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Status

Repo for **AI Browser Game Jam 5** (https://itch.io/jam/ai-jam-5). The chosen concept (an absurd menu-driven succession game, "Pass the Torch" as a working title) and its design rules, architecture, milestones and tests are in [PLAN.md](PLAN.md). Milestone 0 (scaffold) is done: a wasm page renders a headline from the rules package.

## Commands

```bash
tools/test.sh                      # native odin test of src/game, plus a js_wasm32 check of both packages
tools/build.sh                     # builds build/web (ODIN_FLAGS="-o:size" for shipping)
PORT=8093 tools/serve.sh           # serves build/web; wasm needs http, and the port must be free
odin test src/game -collection:tggd=src -define:ODIN_TEST_THREADS=1 -define:ODIN_TEST_NAMES=game.new_game_starts_at_generation_one   # one test
tools/ship.sh                      # tests, size build, zip; pushes to itch only with --push
```

## Layout

`src/game` is the pure rules package (no platform imports; tests are `#+build !js`). `src/web` is `package main` behind `#+build js` and imports it as `tggd:game` (build with `-collection:tggd=src`). `web/index.html` is copied beside `game.wasm` and `odin.js` into `build/web`. The `TARGET` in `tools/ship.sh` is a placeholder until the itch page exists.

## Jam facts

- Submissions: 2026-10-17 03:00 to 2026-10-31 03:00.
- Theme: **TORCH**, a suggestion only ("interpret freely or ignore").
- Must be free and playable in a browser, and heavily AI-assisted. Credit third-party assets and tools, and include an AI-use disclosure in the itch page copy.
- Voting categories: Overall, Fun, Graphics, Audio, Theme, AI Usage. Sharing process (tools, prompts, lessons) is encouraged.

## Toolchain and conventions (from the notes vault)

The user's notes vault is `/home/yermom/git/bok-of-splorr/splorr` (added as a working directory). Read these before writing code or release material:

- `Tech/Odin wasm recipe.md`: Odin `js_wasm32` build using `core/sys/wasm/js/odin.js`, no emscripten. Build with `odin build src -target:js_wasm32 -out:build/web/game.wasm -o:speed` (use `-o:size` for shipping), copy `odin.js` beside `index.html`, and serve over http (not `file://`). The recipe lists several code splits; the newer games keep a pure rules package with no platform imports plus a thin `#+build js` web layer, so `odin test` runs natively (`#+build !js` on tests, `-define:ODIN_TEST_THREADS=1`).
- `Gotchas.md`: use a 2D canvas, never WebGL (it fails on the user's Chrome and in the in-app browser); cap every retry loop (an infinite loop freezes the tab); constant arrays cannot be indexed at runtime (declare with `:=`).
- `Tech/Release standard.md`: itch material layout (`ITCH_DESCRIPTION.md`, `assets/cover.png` at 630x500, `assets/screenshots/`, `devlog/YYYYMMDD/devlog.md`, `tools/ship.sh` plus a one-line `shippit.sh` wrapper, `tools/build.sh`, `tools/test.sh`). Template to copy: `FortuneHunter/tools/ship.sh`. New pages use channel `html`.
- Never run `shippit.sh --push`, `butler push` or `git push` unless the user says to.
