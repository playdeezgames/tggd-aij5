# Torch Passers of SPLORR!!: devlog 1, a dynasty in a day

Posting for AI Browser Game Jam 5 (theme: TORCH). The jam wants the process shared, so here it is.

## The idea

I asked Claude Code to read the jam page and my notes vault and pitch five ways at the theme. I picked the succession one: you carry a torch through eight generations, and only one thing and one grudge can be handed down with it. Then we went through the open design questions one at a time (how handoffs distort what you carry, whether past runs carry over, the tone, how to cover graphics and sound) and I answered each. The tone answer was "absurd".

## The pipeline

- **Odin to WebAssembly**, my usual recipe: a pure rules package with no platform imports (tested natively with `odin test`), and a thin web layer that draws a view model through a handful of imports. The page is plain DOM plus one small canvas.
- **Milestones**, each one built, tested, played in the browser and committed: scaffold, the dynasty loop, the drift mechanics, content (25 events, 12 heirs), saves and carry-over, torch and faces and sound, a balance pass, then this ship material.
- **Art:** faces from the Urizen 1-bit tileset by vurmux. The torch is drawn by code. **Sound:** jsfxr, run by a script under headless Chrome, because this machine has no node. No image or music generators.

## What the AI did and what I did

Claude Code wrote the code, the tests, the game text and the tooling. I made the design calls, said "no, the cat can't do that" where needed, and decide what ships. I have not hand-edited the content yet, so treat the jokes as a first draft by a model.

## Things that went better or worse than expected

- **Drift is a template, not writing.** Every handoff moves a thing one rung up a shared ladder (a handy, a favorite, a family, a cherished, a sacred...) and, every second time, along its own noun ladder. Grudges lose their reason at the second handoff. A test pins that the words differ at every rung.
- **Bots found a balance problem I would have missed.** Four play policies over a thousand seeds each showed that a careful player could not lose, and that when I made handoffs expensive, handing over nothing became the best strategy, which defeats the point. So handoffs stay cheap, most flame-gaining options need a resource, and the screen now lists what is out of reach and why. Random clicking survives about 14% of runs; a thoughtful player almost always survives.
- **Saves are a line of integers.** Every field is read with its legal range and a damaged save is ignored whole. A fuzz test damages saved runs and plays any that still load, to prove none of them can crash the game.
- **Headless screenshots work with a back door.** The page accepts `?seed=11&keys=1,3,1` for QA, so the screenshots are replays of a scripted game and can be regenerated.

## What is next

Playtesting by a human who is not me, and fixing whatever that finds before the jam closes.
