// Pure rules for Pass the Torch. No platform imports: this package compiles natively (for tests) and to wasm.
package game

Game :: struct {
	generation: int,
}

new_game :: proc() -> Game {
	return Game{generation = 1}
}

// The scaffold's one screen: proves the page, the wasm and the rules package are wired together.
headline :: proc(g: Game) -> string {
	if g.generation == 1 {
		return "Generation 1. You have a torch."
	}
	return "Someone else has the torch now."
}
