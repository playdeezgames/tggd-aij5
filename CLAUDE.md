# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Status

Repo for **AI Browser Game Jam 5** (https://itch.io/jam/ai-jam-5). The chosen concept (an absurd menu-driven succession game, "Pass the Torch" as a working title) and its design rules, architecture, milestones and tests are in [PLAN.md](PLAN.md). Milestones 0 (scaffold), 1 (text-only dynasty loop, placeholder content) 2 (one-slot handoff with drift, carry cost, grudges losing their reason) and 3 (content pass: 25 events, 12 heirs, 8 items, 8 grudges, options gated by counters) are done; the next is milestone 4 (saves and carry-over between runs).

## Commands

```bash
tools/test.sh                      # native odin test of src/game, plus a js_wasm32 check of both packages
tools/build.sh                     # builds build/web (ODIN_FLAGS="-o:size" for shipping)
PORT=8093 tools/serve.sh           # serves build/web; wasm needs http, and the port must be free
odin test src/game -collection:tggd=src -define:ODIN_TEST_THREADS=1 -define:ODIN_TEST_NAMES=game.title_begins_a_run   # one test
tools/ship.sh                      # tests, size build, zip; pushes to itch only with --push
```

## Layout

`src/game` is the pure rules package (no platform imports; tests are `#+build !js`): `game.odin` is the flat `Game` struct and transitions, `content.odin` the data tables (variables, with `#partial` enum-array literals; it was generated once from a table and is now edited by hand) including the drift ladders, `drift.odin` the only place words change (`item_text` / `grudge_text` are pure functions of id and stage; every handoff adds one stage, and the shared status/intensity ladders make the text differ every time), `screens.odin` the `Screen` state machine (`make_view` builds the visible lines and choices in `context.temp_allocator`; `choose(index)` runs the transition). The web layer only draws a `View` through `dom_clear/dom_line/dom_choice` imports, sends clicks back through the `on_choice` export, and frees the temp allocator after each draw. `src/web` is `package main` behind `#+build js` and imports it as `tggd:game` (build with `-collection:tggd=src`). `web/index.html` is copied beside `game.wasm` and `odin.js` into `build/web`. The `TARGET` in `tools/ship.sh` is a placeholder until the itch page exists.

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

## Balance guardrails

A run draws 3 events per generation over 8 generations and never repeats one (`#assert` in `game.odin` keeps `Event_Id` large enough). Tests enforce: a flame-maximising policy always survives, random play survives between 2% and 70% of runs (it is about 32% at `START_FLAME` 3), and every event keeps at least two ungated options. Re-run `tools/test.sh` after any content or cost change; the survival rate is logged.
