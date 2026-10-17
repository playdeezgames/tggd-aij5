# Itch.io page text

The page: https://thegrumpygamedev.itch.io/torch-passers-of-splorr
Made for AI Browser Game Jam 5 (https://itch.io/jam/ai-jam-5), theme TORCH.
This file is pasted in by hand; nothing here is published by the repo.

## Short description

A dynasty, one torch, and the few things that survive being handed down.

## Paste this as the page description

You have a torch. It does not stay yours.

Eight generations carry it. In each one, three things happen to you: a goat eats the map, a stranger offers to hold your torch, the mayor wants a permit to be on fire. You decide what to do about each, then you choose an heir and the torch moves on.

**Only one thing and one grudge can come with it, and neither arrives the same.** A ladle becomes a handy ladle, then a favorite big spoon. A grudge loses its reason after two handoffs and is kept anyway. Carrying both costs flame. Everything else, you leave behind.

**The flame is the torch.** It drops at every handoff, and the best ways to feed it cost you something else. Most of them need a resource (Pride, Livestock, Reputation or Snacks), and resources reset with each new heir, so spending one can close a door later. The page tells you what is out of reach and what it costs. If the flame goes out, so does the dynasty.

**Past dynasties come back.** What a finished dynasty still held is remembered, and in later runs a relative may turn up with it, older and stranger than you left it. "Forget the past" on the title screen clears them.

**Controls:** click a choice, or press its number. **Saving:** yer progress is kept in yer browser after every choice, so closing the tab does not lose a run. A full dynasty is about 70 choices.

**Credits and how it was made.** This game was made for a jam that asks for heavy AI assistance, and it got it: the code (Odin compiled to WebAssembly), the game's text and the tests were written with Claude Code, from my design decisions and playtesting. The faces are from the Urizen 1-bit tileset by vurmux (CC0, https://vurmux.itch.io/urizen-onebit-tileset). The torch, the cover and the page are drawn by code. The cover lettering is Public Pixel Font by GGBotNet (CC0). Sound effects were generated with jsfxr (https://sfxr.me) by script. No image or music generators were used.

## Notes (not for the page)

- The page exists and is confirmed by the user. `tools/ship.sh` pushes to `thegrumpygamedev/torch-passers-of-splorr:html`, and only with `--push`.
- On the page's Edit game screen: set "Kind of project" to HTML, tick "This file will be played in the browser" on the html upload, and set the embed to about 800 by 640 (it is a responsive text page, so larger is fine). Submit the page to the jam from the jam page after the upload is processed.
- The cover is `assets/cover.png` (630 by 500, drawn by `tools/make_cover.py`); screenshots are in `assets/screenshots/` (made by `tools/make_screenshots.sh`).
- The AI-use paragraph is a draft in the user's voice. Confirm the wording, in particular "from my design decisions and playtesting", and fill in the page's generative-AI disclosure field to match if it has one.
- The page has QA parameters (`?seed=N&keys=1,2,3`) used for the screenshots. They are not mentioned on the page.
