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
	dom_choice :: proc(text: [^]u8, length: i32) ---
	// Milliseconds since the epoch, as f64 (an i64 import would need a BigInt on the JS side).
	now_ms :: proc() -> f64 ---
}

state: game.Game

redraw :: proc() {
	v := game.make_view(state)
	dom_clear()
	for i in 0 ..< v.line_count {
		s := v.lines[i]
		dom_line(raw_data(s), i32(len(s)))
	}
	for i in 0 ..< v.choice_count {
		s := v.choices[i]
		dom_choice(raw_data(s), i32(len(s)))
	}
	free_all(context.temp_allocator)
}

main :: proc() {
	state = game.new_game(u64(now_ms()))
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
	game.choose(&state, int(index))
	redraw()
}
