#+build js
package main

import "base:runtime"
import "tggd:game"

foreign import host "env"

@(default_calling_convention = "contextless")
foreign host {
	// Replaces the text of the page's #view element. Strings cross as pointer and length.
	dom_set_text :: proc(text: [^]u8, length: i32) ---
}

state: game.Game

draw :: proc() {
	text := game.headline(state)
	dom_set_text(raw_data(text), i32(len(text)))
}

main :: proc() {
	state = game.new_game()
	draw()
}

// odin.js stops after main unless a step export exists; the page is event driven, so it does nothing.
@(export)
step :: proc(dt: f64, c: runtime.Context) -> bool {
	return true
}
