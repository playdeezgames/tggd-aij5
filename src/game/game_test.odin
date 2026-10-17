#+build !js
package game

import "core:testing"

// Plays one scripted policy to the end and returns the final state. Bounded so a bug cannot hang the suite.
Policy :: enum {
	Random,
	Greedy_Flame, // always the option that keeps the torch lit
}

MAX_STEPS :: 2000

play :: proc(t: ^testing.T, seed: u64, policy: Policy) -> Game {
	g := new_game(seed)
	for _ in 0 ..< MAX_STEPS {
		v := make_view(g)
		testing.expect(t, v.line_count > 0 && v.line_count <= MAX_LINES)
		testing.expect(t, v.choice_count >= 1 && v.choice_count <= MAX_CHOICES)
		for i in 0 ..< v.line_count {
			testing.expect(t, len(v.lines[i]) > 0)
		}
		for i in 0 ..< v.choice_count {
			testing.expect(t, len(v.choices[i]) > 0)
		}
		if g.screen == .Over && policy != .Random {
			free_all(context.temp_allocator)
			return g
		}
		pick := 0
		switch policy {
		case .Random:
			pick = roll(&g, v.choice_count)
		case .Greedy_Flame:
			#partial switch g.screen {
			case .Event:
				best := EVENTS[g.event].options[0].delta[.Flame]
				for i in 1 ..< EVENTS[g.event].option_count {
					if d := EVENTS[g.event].options[i].delta[.Flame]; d > best {
						best = d
						pick = i
					}
				}
			case .Heir:
				for i in 0 ..< HEIR_CHOICES {
					if HEIRS[g.candidates[i]].minus != .Flame {
						pick = i
						if HEIRS[g.candidates[i]].plus == .Flame {
							break
						}
					}
				}
			}
		}
		choose(&g, pick)
		free_all(context.temp_allocator)
		if g.screen == .Over && policy == .Random {
			return g
		}
	}
	testing.fail_now(t, "run did not end within the step bound")
}

@(test)
title_begins_a_run :: proc(t: ^testing.T) {
	g := new_game(1)
	testing.expect_value(t, g.screen, Screen.Title)
	choose(&g, 0)
	testing.expect_value(t, g.screen, Screen.Event)
	testing.expect_value(t, g.generation, 1)
	testing.expect_value(t, g.counters[.Flame], START_FLAME)
}

@(test)
out_of_range_choice_does_nothing :: proc(t: ^testing.T) {
	g := new_game(1)
	choose(&g, 7)
	choose(&g, -1)
	testing.expect_value(t, g.screen, Screen.Title)
}

@(test)
random_runs_always_end :: proc(t: ^testing.T) {
	for seed in u64(0) ..< 300 {
		g := play(t, seed, .Random)
		testing.expect_value(t, g.screen, Screen.Over)
	}
}

@(test)
keeping_the_flame_alive_is_possible :: proc(t: ^testing.T) {
	for seed in u64(0) ..< 100 {
		g := play(t, seed, .Greedy_Flame)
		testing.expectf(t, g.over == .Dynasty_End, "seed %d: torch went out in generation %d", seed, g.generation)
		testing.expect_value(t, g.generation, MAX_GENERATIONS)
	}
}

@(test)
only_one_item_and_one_grudge_cross :: proc(t: ^testing.T) {
	for seed in u64(0) ..< 100 {
		g := new_game(seed)
		last_generation := 1
		for _ in 0 ..< MAX_STEPS {
			if g.screen == .Over {
				break
			}
			if g.generation != last_generation {
				// a handover just completed
				testing.expect(t, card(g.items) <= 1)
				testing.expect(t, card(g.grudges) <= 1)
				last_generation = g.generation
			}
			v := make_view(g)
			choose(&g, roll(&g, v.choice_count))
			free_all(context.temp_allocator)
		}
	}
}

@(test)
flame_out_ends_the_run :: proc(t: ^testing.T) {
	g := new_game(3)
	choose(&g, 0)
	g.counters[.Flame] = 1
	// Force an option that costs flame: Let them (Stranger_Offer option 0).
	g.event = .Stranger_Offer
	choose(&g, 0)
	testing.expect_value(t, g.screen, Screen.Result)
	choose(&g, 0)
	testing.expect_value(t, g.screen, Screen.Over)
	testing.expect_value(t, g.over, Over_Reason.Flame_Out)
	free_all(context.temp_allocator)
}

@(test)
non_flame_counters_reset_at_handover :: proc(t: ^testing.T) {
	g := new_game(5)
	choose(&g, 0)
	g.counters[.Snacks] = 9
	g.items = {}
	g.grudges = {}
	g.heir = .Odo
	finish_handover(&g)
	// Odo: +Flame (persistent, so unaffected by the reset), -Snacks from the reset value.
	testing.expect_value(t, g.counters[.Snacks], START_COUNTER - 1)
	testing.expect_value(t, g.counters[.Flame], START_FLAME - HANDOFF_COST + 1)
	free_all(context.temp_allocator)
}

@(test)
content_is_well_formed :: proc(t: ^testing.T) {
	for event in EVENTS {
		testing.expect(t, len(event.prompt) > 0 && len(event.prompt) <= 80)
		testing.expect(t, event.option_count >= 2 && event.option_count <= len(event.options))
		for i in 0 ..< event.option_count {
			o := event.options[i]
			testing.expect(t, len(o.text) > 0 && len(o.text) <= 40)
			testing.expect(t, len(o.result) > 0 && len(o.result) <= 80)
		}
	}
	testing.expect(t, len(Event_Id) > EVENTS_PER_GENERATION)
	testing.expect(t, len(Heir_Id) >= HEIR_CHOICES)
}
