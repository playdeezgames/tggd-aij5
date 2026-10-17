# Torch Passers of SPLORR!!: dev plan

An absurd, menu-driven succession game: a dynasty of 8 to 12 generations, one literal torch, and one item plus one grudge handed over each time. Decisions so far: template drift for distortion, full carry-over between runs, absurd tone, flickering torch glyph + 1-bit heir portraits + jsfxr sounds.

**Deadline:** jam closes 2026-10-31 03:00 (confirm the time zone on the page; plan to be uploaded by the evening of Oct 30). Today is Oct 17.

## What reifies the metaphor

The mechanic has to say the thing, so these rules are not tunable away:

1. **One slot each.** Exactly one item and one grudge cross each handoff. The UI makes you leave things behind, visibly.
2. **Every handoff drifts.** The inherited item or grudge is always changed by one step on its drift ladder. There is no "faithful copy" option.
3. **The flame always drops.** Carrying costs flame. Refuelling in the Live phase always costs something else you value.
4. **Grudges lose their causes.** After a few generations the grudge text keeps the target but drops the reason.
5. **Carry-over is the same rule at a larger scale.** What a run leaves behind drifts into the next run's world.
6. **No good ending.** The final screen lists what survived, as it is now remembered.

## Architecture

Follows the pure-rules split from `Tech/Odin wasm recipe.md` (Roomba Rights / Shark Attackers / Gwen's Peregrination).

```
src/game/      pure rules, no platform imports, native tests
  rules.odin     flat POD Game struct: counters [Counter]int, torch, heir, items, grudges, rng
  content.odin   constant tables: events, candidates, vocab, drift ladders (data, not logic)
  drift.odin     drift(item/grudge) -> next-stage; the only place meaning changes
  legacy.odin    cross-run record: capped list of survivors, event seeding
  save.odin      JSON save of run + legacy; validate every field, assign only if all pass
  screens.odin   Screen enum, current_choices, choose(i), make_view
src/web/       #+build js
  web.odin       foreign imports, on_choice export, settle() = save then redraw
  index.html     DOM text/buttons + one small canvas (torch, portrait)
tools/         build.sh, test.sh, ship.sh (copy FortuneHunter's), shippit.sh wrapper
```

Rules to keep: the clock and rolls are arguments, never read inside; the RNG lives in the struct; the web build gets `-collection:tggd=src`; tests are `#+build !js`, run with `-define:ODIN_TEST_THREADS=1`; `tools/test.sh` also runs `odin check` on both packages for `js_wasm32`.

## Data model sketch

- **Counters** (enum-indexed array): flame, plus 3 or 4 absurd resources (names are content; start with e.g. Pride, Livestock, Reputation, Snacks). Keep the count small.
- **Item** = `{subject, kind_word, stage}`. `kind_word` climbs a ladder (warning, rule, custom, taboo, ...). `subject` can also swap with a neighbour word at later stages.
- **Grudge** = `{target, reason, stage}`. `reason` becomes empty at a set stage; `target` can drift to a related target.
- **Heir candidate** = `{name, traits[2], hidden_flaw, portrait_seed}`. Traits modify event outcomes; the flaw triggers once.
- **Event** = `{prompt (<=3 short lines), options[2..3], effects, requires}`. Effects are data over counters, item, grudge and the heir.
- **Legacy record** (cross-run, capped at the last 5): `{item, grudge, final_stage, generations_survived}`. Events with a `legacy` tag are eligible only when a record matches.

## Milestones

Each ends with something playable and the tests green. Cut from the bottom if time runs short.

| # | Target | Done when |
|---|---|---|
| 0 | Scaffold | `tools/build.sh` produces `build/web`, a page shows "hello" through the wasm, `test.sh` runs one test. |
| 1 | Core loop, text only | One full dynasty plays through DOM buttons: live, pick heir, hand over, repeat, game over. Placeholder content (5 events, 4 candidates). |
| 2 | The metaphor mechanics | One-slot handoff UI with "left behind" shown; drift ladder; flame cost; grudge reason loss. Drift is covered by unit tests. |
| 3 | Content pass | About 25 events, 12 candidates, item and grudge vocab, ladders. Absurd tone check on every line (short, deadpan). |
| 4 | Saves + carry-over | Resume a run; legacy record written at game over; legacy events appear in later runs. Fuzz test for load. |
| 5 | Graphics + audio | Torch glyph on canvas (flame level drives size and flicker), 1-bit heir portraits from a tinted sheet, jsfxr sounds on handoff, flame low, flame out. |
| 6 | Playtest + balance | Check run length, check a torch-keeping path exists, trim wordiness, fix bugs. |
| 7 | Ship material | `ITCH_DESCRIPTION.md` with the AI-use disclosure and tool credits, `assets/cover.png` (630x500), `assets/screenshots/`, `devlog/YYYYMMDD/devlog.md`, `tools/ship.sh` run **without** `--push`. |

Suggested pacing (two weeks): M0 to M2 in days 1 to 4, M3 and M4 in days 5 to 9, M5 in days 10 to 11, M6 and M7 in days 12 to 14, with buffer. **Cut order if behind:** portraits, then legacy event seeding (keep the record screen), then content count. Never cut the milestone 2 mechanics.

## Testing plan

- **Drift:** every ladder reaches its end without looping; applying drift N times never panics; empty-reason grudges stay empty.
- **Termination fuzz:** play random choices to the end for many seeds, bounded step count; assert every run ends and no state goes out of range.
- **Torch survivability:** a search that proves some choice sequence keeps the flame alive for the full dynasty on each seed class, so no run is unwinnable by accident (the lesson from Roomba Rights: reachability alone is not enough, call the real `choose`).
- **Save:** round trip; tamper with each field and require the load to fail and leave the game untouched.
- **Content lint:** a test that fails if any event line is over the length cap, any effect refers to a missing counter, or any option list is empty.

## Risks and mitigations

- **Carry-over scope.** Cap it at 5 records and one tag-match rule. Land M4 only after M2 and M3 are solid.
- **Too wordy.** Hard cap on event text, enforced by the content lint.
- **Replay value.** Randomised event and candidate pools per generation plus carry-over; track which events were seen this run so none repeats.
- **Infinite loops freeze the tab.** Cap every retry loop (see `Gotchas.md`).
- **Canvas only, no WebGL.** Use a 2D canvas with smoothing off.
- **Absurdity drifting into noise.** Keep a short style sheet of the deadpan rules in `devlog/` as content grows.

## Open items for the user

- Final title and the SPLORR!! suffix.
- The absurd resource names and the first few events (the content is where the voice lives).
- Whether to post the devlog during the jam (the page encourages sharing the process).
