#+build !js
package game

import "core:testing"

@(test)
new_game_starts_at_generation_one :: proc(t: ^testing.T) {
	g := new_game()
	testing.expect_value(t, g.generation, 1)
	testing.expect_value(t, headline(g), "Generation 1. You have a torch.")
}

@(test)
later_generations_change_the_headline :: proc(t: ^testing.T) {
	g := new_game()
	g.generation = 2
	testing.expect(t, headline(g) != headline(new_game()))
}
