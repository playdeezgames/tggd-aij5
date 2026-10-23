#+build !js
package game

import "core:fmt"
import "core:log"
import "core:strings"
import "core:testing"

// Plays one scripted policy to the end and returns the final state. Bounded so a bug cannot hang the suite.
Policy :: enum {
	Random,
	Greedy_Flame, // always the option that keeps the torch lit
	Careful, // weighs every resource, and carries things across
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
			testing.expectf(t, !strings.contains(v.lines[i], "%!"), "format error in: %s", v.lines[i])
		}
		for i in 0 ..< v.choice_count {
			testing.expect(t, len(v.choices[i]) > 0)
			testing.expectf(t, !strings.contains(v.choices[i], "%!"), "format error in: %s", v.choices[i])
		}
		if g.screen == .Over && policy != .Random {
			free_all(context.temp_allocator)
			return g
		}
		pick := 0
		switch policy {
		case .Random:
			pick = roll(&g, v.choice_count)
		case .Greedy_Flame, .Careful:
			#partial switch g.screen {
			case .Event:
				if g.event_kind != .Normal {
					break // a relative: take the thing, which is option 0
				}
				open: [3]int
				n := available_options(g, &open)
				best := min(int)
				for i in 0 ..< n {
					o := EVENTS[g.event].options[open[i]]
					score := o.delta[.Flame] * 10
					if policy == .Careful { 	// also weighs the other resources, and eases off the flame when it is high
						for c in Counter {
							if c != .Flame {
								score += o.delta[c] * 3
							}
						}
						if g.counters[.Flame] >= 6 {
							score -= o.delta[.Flame] * 8
						}
					}
					if score > best {
						best = score
						pick = i
					}
				}
			case .Handover_Item, .Handover_Grudge:
				// Greedy hands over nothing (the cheapest handoff); Careful keeps the first thing it can
				pick = v.choice_count - 1 if policy == .Greedy_Flame else 0
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
	count :: proc(held: [$E]Held) -> int {
		n := 0
		for h in held {
			if h.present {
				n += 1
			}
		}
		return n
	}
	for seed in u64(0) ..< 100 {
		g := new_game(seed)
		for _ in 0 ..< MAX_STEPS {
			if g.screen == .Over {
				break
			}
			if g.screen == .Handoff {
				testing.expect(t, count(g.items) <= 1)
				testing.expect(t, count(g.grudges) <= 1)
			}
			v := make_view(g)
			choose(&g, roll(&g, v.choice_count))
			free_all(context.temp_allocator)
		}
	}
}

@(test)
every_handoff_changes_the_words :: proc(t: ^testing.T) {
	for id in Item_Id {
		for stage in 0 ..< DRIFT_STEPS + 2 { 	// past the end too: clamped, and still no panic
			if stage < DRIFT_STEPS - 1 {
				testing.expectf(t, item_text(id, stage) != item_text(id, stage + 1), "%v stage %d", id, stage)
			}
			testing.expect(t, len(item_text(id, stage)) > 0)
		}
	}
	for id in Grudge_Id {
		for stage in 0 ..< DRIFT_STEPS + 2 {
			if stage < DRIFT_STEPS - 1 {
				testing.expectf(t, grudge_text(id, stage) != grudge_text(id, stage + 1), "%v stage %d", id, stage)
			}
			testing.expect(t, len(grudge_text(id, stage)) > 0)
		}
	}
	free_all(context.temp_allocator)
}

@(test)
grudges_lose_their_reason :: proc(t: ^testing.T) {
	for id in Grudge_Id {
		reason := GRUDGE_REASONS[id]
		for stage in 0 ..< DRIFT_STEPS {
			text := grudge_text(id, stage)
			if stage < REASON_LOST_STAGE {
				testing.expectf(t, strings.contains(text, reason), "%v stage %d should say why", id, stage)
			} else {
				testing.expectf(t, !strings.contains(text, reason), "%v stage %d should not say why", id, stage)
				testing.expect(t, strings.contains(text, "nobody remembers why"))
			}
		}
	}
	free_all(context.temp_allocator)
}

@(test)
a_handoff_ages_what_it_carries :: proc(t: ^testing.T) {
	g := new_game(9)
	choose(&g, 0)
	g.items = {}
	g.grudges = {}
	g.items[.Ladle] = Held{true, 0}
	g.items[.Soggy_Hat] = Held{true, 3}
	g.grudges[.Sky] = Held{true, 1}
	g.carry_item = Item_Id.Soggy_Hat
	g.carry_grudge = Grudge_Id.Sky
	g.heir = .Odo
	finish_handover(&g)
	testing.expect_value(t, g.screen, Screen.Handoff)
	testing.expect_value(t, g.items[.Soggy_Hat], Held{true, 4})
	testing.expect_value(t, g.grudges[.Sky], Held{true, 2})
	testing.expect(t, !g.items[.Ladle].present)
	// what was not carried is shown as left behind
	testing.expect(t, g.left_items[.Ladle].present)
	testing.expect(t, !g.left_items[.Soggy_Hat].present)
	free_all(context.temp_allocator)
}

@(test)
the_flame_always_drops_and_carrying_more_costs_more :: proc(t: ^testing.T) {
	cases := [?]struct {
		item:   bool,
		grudge: bool,
		cost:   int,
	}{{false, false, HANDOFF_COST}, {true, false, HANDOFF_COST}, {false, true, HANDOFF_COST}, {true, true, HANDOFF_COST + EXTRA_CARRY_COST}}
	for c in cases {
		g := new_game(2)
		choose(&g, 0)
		g.items[.Ladle] = Held{true, 0}
		g.grudges[.Goat] = Held{true, 0}
		g.carry_item = Item_Id.Ladle if c.item else nil
		g.carry_grudge = Grudge_Id.Goat if c.grudge else nil
		g.heir = .Brindle // does not touch the flame
		before := g.counters[.Flame]
		finish_handover(&g)
		testing.expect_value(t, before - g.counters[.Flame], c.cost)
		testing.expect(t, g.counters[.Flame] < before)
	}
	free_all(context.temp_allocator)
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
	testing.expect_value(t, g.screen, Screen.Handoff)
	free_all(context.temp_allocator)
}

@(test)
no_event_repeats_within_a_run :: proc(t: ^testing.T) {
	for seed in u64(0) ..< 200 {
		g := new_game(seed)
		seen: bit_set[Event_Id]
		was_event := false
		for _ in 0 ..< MAX_STEPS {
			if g.screen == .Over {
				break
			}
			is_event := g.screen == .Event
			if is_event && !was_event { 	// a new event just began
				testing.expectf(t, g.event not_in seen, "seed %d repeated %v", seed, g.event)
				seen += {g.event}
			}
			was_event = is_event
			v := make_view(g)
			choose(&g, roll(&g, v.choice_count))
			free_all(context.temp_allocator)
		}
	}
}

@(test)
requirements_hide_options_until_met :: proc(t: ^testing.T) {
	g := new_game(4)
	choose(&g, 0)
	g.event = .Permit // option 2 (Bribe with cheese) needs 2 Snacks
	g.counters[.Snacks] = 1
	open: [3]int
	testing.expect_value(t, available_options(g, &open), 2)
	g.counters[.Snacks] = 2
	testing.expect_value(t, available_options(g, &open), 3)
	free_all(context.temp_allocator)
}

@(test)
survival_rate_for_random_play_is_reasonable :: proc(t: ^testing.T) {
	// Guardrail on balance, not a spec: random play should neither always die nor always win.
	survived := 0
	total := 1000
	for seed in u64(0) ..< u64(total) {
		g := play(t, seed, .Random)
		if g.over == .Dynasty_End {
			survived += 1
		}
	}
	log.infof("random play survived %d of %d runs", survived, total)
	testing.expect(t, survived * 100 >= total * 2)
	testing.expect(t, survived * 100 <= total * 70)
}

@(test)
content_is_well_formed :: proc(t: ^testing.T) {
	for event in EVENTS {
		testing.expect(t, len(event.prompt) > 0 && len(event.prompt) <= 80)
		testing.expect(t, event.option_count >= 2 && event.option_count <= len(event.options))
		ungated := 0
		for i in 0 ..< event.option_count {
			o := event.options[i]
			if o.requires == nil {
				ungated += 1
			}
			testing.expect(t, len(o.text) > 0 && len(o.text) <= 40)
			testing.expect(t, len(o.result) > 0 && len(o.result) <= 80)
		}
		testing.expect(t, ungated >= 2) // a player is never left with a single choice
	}
	for heir in HEIRS {
		testing.expect(t, heir.plus != heir.minus)
		testing.expect(t, len(heir.name) > 0 && len(heir.trait) > 0)
	}
	testing.expect(t, len(STATUS_LADDER) >= MAX_GENERATIONS && len(INTENSITY_LADDER) >= MAX_GENERATIONS)
	for id in Item_Id {
		for noun in ITEM_NOUNS[id] {
			testing.expect(t, len(noun) > 0)
		}
	}
	for id in Grudge_Id {
		testing.expect(t, len(GRUDGE_REASONS[id]) > 0)
		for target in GRUDGE_TARGETS[id] {
			testing.expect(t, len(target) > 0)
		}
	}
	testing.expect(t, len(Event_Id) > EVENTS_PER_GENERATION)
	testing.expect(t, len(Heir_Id) >= HEIR_CHOICES)
}

@(test)
every_choice_earns_one_matching_sound :: proc(t: ^testing.T) {
	// Flame up and down: Rain option 0 (shelter the hat, +1 flame) and option 1 (pray, -1 flame).
	g := new_game(3)
	choose(&g, 0)
	g.counters[.Flame] = 5
	g.event = .Rain
	g2 := g
	testing.expect_value(t, choose(&g, 0), Sounds{.Flame_Up})
	testing.expect_value(t, choose(&g, 0), Sounds{.Click}) // the result screen
	g2.event = .Rain
	testing.expect_value(t, choose(&g2, 1), Sounds{.Flame_Down})

	// Dropping to the last flame warns instead.
	g3 := new_game(3)
	choose(&g3, 0)
	g3.counters[.Flame] = 2
	g3.event = .Rain
	testing.expect_value(t, choose(&g3, 1), Sounds{.Flame_Low})

	// Running out of flame ends the run with the ending sound.
	g4 := new_game(3)
	choose(&g4, 0)
	g4.counters[.Flame] = 1
	g4.event = .Rain
	choose(&g4, 1)
	testing.expect_value(t, choose(&g4, 0), Sounds{.Ending})

	// An out-of-range choice is silent and changes nothing.
	before := g4
	testing.expect_value(t, choose(&g4, 9), Sounds{})
	testing.expect(t, before == g4)

	// A handoff has its own sound.
	g5 := new_game(3)
	choose(&g5, 0)
	g5.heir = .Odo
	g5.carry_item = nil
	g5.carry_grudge = nil
	g5.screen = .Handover_Grudge // nothing held: the choice is "hand over nothing"
	testing.expect_value(t, choose(&g5, 0), Sounds{.Handoff})
	free_all(context.temp_allocator)
}

@(test)
sound_names_match_the_files_the_page_loads :: proc(t: ^testing.T) {
	names := [?]string{"click", "flame_up", "flame_down", "handoff", "flame_low", "ending"}
	testing.expect_value(t, len(names), len(Sound))
	for s in Sound {
		testing.expect_value(t, strings.to_lower(fmt.tprintf("%v", s), context.temp_allocator), names[int(s)])
	}
	free_all(context.temp_allocator)
}

@(test)
the_scene_follows_the_game :: proc(t: ^testing.T) {
	g := new_game(5)
	testing.expect_value(t, make_view(g).ruler, NO_TILE)
	choose(&g, 0)
	v := make_view(g)
	testing.expect_value(t, v.torch, START_FLAME)
	testing.expect_value(t, v.ruler, FOUNDER_TILE)
	for i in 0 ..< MAX_CHOICES {
		testing.expect_value(t, v.choice_tiles[i], NO_TILE)
	}
	// every heir choice has a distinct face; the outgoing ruler is still shown while choosing
	g.screen = .Heir
	offer_heirs(&g)
	v = make_view(g)
	testing.expect_value(t, v.ruler, FOUNDER_TILE)
	for i in 0 ..< HEIR_CHOICES {
		testing.expect_value(t, v.choice_tiles[i], HEIR_TILES[g.candidates[i]])
	}
	// once chosen, the new heir holds the torch
	choose(&g, 1)
	testing.expect_value(t, make_view(g).ruler, HEIR_TILES[g.heir])
	// a dead torch is drawn as out
	g.screen = .Over
	g.over = .Flame_Out
	testing.expect_value(t, make_view(g).torch, 0)
	free_all(context.temp_allocator)
}

@(test)
heir_faces_are_distinct_and_on_the_sheet :: proc(t: ^testing.T) {
	SHEET_COLUMNS :: 206
	SHEET_ROWS :: 50
	seen: [dynamic][2]int
	defer delete(seen)
	for tile in HEIR_TILES {
		testing.expect(t, tile.x >= 0 && tile.x < SHEET_COLUMNS && tile.y >= 0 && tile.y < SHEET_ROWS)
		testing.expect(t, tile != FOUNDER_TILE)
		for other in seen {
			testing.expect(t, tile != other)
		}
		append(&seen, tile)
	}
}

@(test)
a_thoughtful_player_usually_survives :: proc(t: ^testing.T) {
	// Balance guardrails: a player weighing every resource should win nearly always, a careless one should not.
	careful := 0
	for seed in u64(0) ..< 200 {
		if play(t, seed, .Careful).over == .Dynasty_End {
			careful += 1
		}
	}
	log.infof("a careful policy survived %d of 200 runs", careful)
	testing.expect(t, careful * 100 >= 200 * 85)
}

@(test)
out_of_reach_options_are_named_with_their_price :: proc(t: ^testing.T) {
	g := new_game(4)
	choose(&g, 0)
	g.event = .Permit
	g.counters[.Snacks] = 1
	v := make_view(g)
	found := false
	for i in 0 ..< v.line_count {
		if v.lines[i] == "Not yet: Bribe with cheese. (needs Snacks 2)" {
			found = true
		}
	}
	testing.expect(t, found)
	testing.expect_value(t, v.choice_count, 2)
	g.counters[.Snacks] = 2
	v = make_view(g)
	for i in 0 ..< v.line_count {
		testing.expect(t, !strings.has_prefix(v.lines[i], "Not yet"))
	}
	testing.expect_value(t, v.choice_count, 3)
	free_all(context.temp_allocator)
}

@(test)
the_handoff_screen_shows_the_generation_about_to_begin :: proc(t: ^testing.T) {
	g := new_game(4)
	choose(&g, 0)
	g.generation = 3
	g.heir = .Odo
	g.screen = .Handover_Grudge
	choose(&g, 0) // nothing held
	testing.expect_value(t, g.screen, Screen.Handoff)
	testing.expect(t, strings.has_prefix(make_view(g).lines[0], "Generation 4 of"))
	free_all(context.temp_allocator)
}

@(test)
the_end_shows_only_what_will_be_remembered :: proc(t: ^testing.T) {
	g := new_game(4)
	choose(&g, 0)
	g.generation = 5
	g.items[.Ladle] = Held{true, 1}
	g.items[.Soggy_Hat] = Held{true, 4}
	g.grudges[.Sky] = Held{true, 0}
	end_run(&g, .Flame_Out)
	v := make_view(g)
	text := ""
	for i in 0 ..< v.line_count {
		text = strings.concatenate({text, v.lines[i], "\n"}, context.temp_allocator)
	}
	testing.expect(t, strings.contains(text, "What survived: a cherished hat")) // the oldest thing (hat, stage 4)
	testing.expect(t, !strings.contains(text, "ladle"))
	testing.expect(t, strings.contains(text, "grudge against the sky"))
	free_all(context.temp_allocator)
}

@(test)
a_ruler_is_never_offered_as_their_own_heir :: proc(t: ^testing.T) {
	for seed in u64(0) ..< 200 {
		g := new_game(seed)
		for _ in 0 ..< MAX_STEPS {
			if g.screen == .Heir && g.generation > 1 {
				for c in g.candidates {
					testing.expectf(t, c != g.heir, "seed %d offered the ruler %v", seed, c)
				}
			}
			if g.screen == .Over {
				break
			}
			choose(&g, 0)
			free_all(context.temp_allocator)
		}
	}
}
