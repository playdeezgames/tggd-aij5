#+build js
package main

import "base:runtime"
import "tggd:game"

foreign import host "env"

@(default_calling_convention = "contextless")
foreign host {
	// The page rebuilds its DOM from these calls. Strings cross as pointer and length.
	dom_clear :: proc() ---
	dom_line :: proc(text: [^]u8, length: i32) ---
	// The torch to draw (flame level, or -1 for none) and the face of whoever holds it (tile column and row, or -1).
	dom_scene :: proc(torch: i32, tile_col: i32, tile_row: i32) ---
	// A choice, with an optional face beside it (tile column and row, or -1).
	dom_choice :: proc(text: [^]u8, length: i32, tile_col: i32, tile_row: i32) ---
	// Plays assets/sfx/<name>.wav for the game.Sound with this position.
	play_sound :: proc(id: i32) ---
	// Milliseconds since the epoch, as f64 (an i64 import would need a BigInt on the JS side).
	now_ms :: proc() -> f64 ---
	// localStorage. storage_get returns the value's byte length, or -1 when the key is missing, unreadable or
	// longer than cap.
	storage_get :: proc(key: [^]u8, key_len: i32, buf: [^]u8, cap: i32) -> i32 ---
	storage_set :: proc(key: [^]u8, key_len: i32, val: [^]u8, val_len: i32) ---
	storage_remove :: proc(key: [^]u8, key_len: i32) ---
}

RUN_KEY :: "ptt-run"
LEGACY_KEY :: "ptt-legacy"

state: game.Game
save_buf: [4096]u8

load_text :: proc(key: string) -> (text: string, ok: bool) {
	n := storage_get(raw_data(key), i32(len(key)), raw_data(save_buf[:]), i32(len(save_buf)))
	if n < 0 {
		return "", false
	}
	return string(save_buf[:n]), true
}

store_text :: proc(key: string, text: string) {
	storage_set(raw_data(key), i32(len(key)), raw_data(text), i32(len(text)))
}

drop_key :: proc(key: string) {
	storage_remove(raw_data(key), i32(len(key)))
}

// A run in progress is saved after every event; a finished run or the title has nothing to resume. The legacy
// is small, so it is written every time.
save_all :: proc() {
	if state.screen == .Title || state.screen == .Over {
		drop_key(RUN_KEY)
	} else {
		store_text(RUN_KEY, game.serialize_game(state))
	}
	store_text(LEGACY_KEY, game.serialize_legacy(state.legacy))
}

// Boot at the title, then try the saves: a valid saved run goes straight back to play. A save that does not
// validate is ignored and left alone.
load_saves :: proc() {
	state = game.new_game(u64(now_ms()))
	if text, ok := load_text(LEGACY_KEY); ok {
		if legacy, valid := game.parse_legacy(text); valid {
			state.legacy = legacy
		}
	}
	if text, ok := load_text(RUN_KEY); ok {
		if saved, valid := game.parse_game(text, state.legacy); valid {
			state = saved
		}
	}
}

redraw :: proc() {
	v := game.make_view(state)
	dom_clear()
	dom_scene(i32(v.torch), i32(v.ruler.x), i32(v.ruler.y))
	for i in 0 ..< v.line_count {
		s := v.lines[i]
		dom_line(raw_data(s), i32(len(s)))
	}
	for i in 0 ..< v.choice_count {
		s := v.choices[i]
		dom_choice(raw_data(s), i32(len(s)), i32(v.choice_tiles[i].x), i32(v.choice_tiles[i].y))
	}
	free_all(context.temp_allocator)
}

main :: proc() {
	load_saves()
	redraw()
}

// odin.js stops after main unless a step export exists; the page is event driven, so it does nothing.
@(export)
step :: proc(dt: f64, c: runtime.Context) -> bool {
	return true
}

@(export)
on_choice :: proc "c" (index: i32) {
	context = runtime.default_context()
	sounds := game.choose(&state, int(index))
	for sound in sounds {
		play_sound(i32(sound))
	}
	save_all()
	redraw()
}
