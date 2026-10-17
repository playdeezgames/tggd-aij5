#+build !js
package game

import "core:log"
import "core:strings"
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
				open: [3]int
				n := available_options(g, &open)
				best := EVENTS[g.event].options[open[0]].delta[.Flame]
				for i in 1 ..< n {
					if d := EVENTS[g.event].options[open[i]].delta[.Flame]; d > best {
						best = d
						pick = i
					}
				}
			case .Handover_Item, .Handover_Grudge:
				pick = v.choice_count - 1 // hand over nothing: the cheapest handoff
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
