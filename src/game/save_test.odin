#+build !js
package game

import "core:strings"
import "core:testing"

// A legacy with `n` records, made the real way (a run ends and remembers).
legacy_with :: proc(n: int) -> Legacy {
	g := new_game(1)
	for i in 0 ..< n {
		g.generation = 1 + i % MAX_GENERATIONS
		g.over = .Flame_Out
		g.items = {}
		g.grudges = {}
		g.items[Item_Id(i % len(Item_Id))] = Held{true, i % DRIFT_STEPS}
		g.grudges[Grudge_Id(i % len(Grudge_Id))] = Held{true, (i + 1) % DRIFT_STEPS}
		remember(&g)
	}
	return g.legacy
}

// Plays random choices from `g` to the end; fails the test if it does not end.
run_to_end :: proc(t: ^testing.T, g: Game) -> Game {
	g := g
	for _ in 0 ..< MAX_STEPS {
		if g.screen == .Over {
			return g
		}
		v := make_view(g)
		testing.expect(t, v.choice_count >= 1 && v.choice_count <= MAX_CHOICES)
		choose(&g, 0 if g.screen == .Title else roll(&g, v.choice_count)) // never "Forget the past"
		free_all(context.temp_allocator)
	}
	testing.fail_now(t, "a loaded run did not end within the step bound")
}

// Replaces token `i` of a save line (or removes it when `with` is nil).
mutate :: proc(text: string, i: int, with: Maybe(string)) -> string {
	toks := strings.split(text, " ", context.temp_allocator)
	out := make([dynamic]string, context.temp_allocator)
	for tok, j in toks {
		if j == i {
			if w, ok := with.?; ok {
				append(&out, w)
			}
		} else {
			append(&out, tok)
		}
	}
	return strings.join(out[:], " ", context.temp_allocator)
}

@(test)
every_state_of_a_run_round_trips :: proc(t: ^testing.T) {
	legacy := legacy_with(3)
	for seed in u64(0) ..< 150 {
		g := new_game(seed)
		g.legacy = legacy
		for _ in 0 ..< MAX_STEPS {
			if g.screen != .Title {
				text := serialize_game(g)
				back, ok := parse_game(text, g.legacy) // the legacy is saved separately
				testing.expectf(t, ok, "seed %d screen %v: %s", seed, g.screen, text)
				testing.expectf(t, back == g, "seed %d screen %v did not round-trip", seed, g.screen)
			}
			if g.screen == .Over {
				break
			}
			v := make_view(g)
			choose(&g, 0 if g.screen == .Title else roll(&g, v.choice_count)) // never "Forget the past"
			free_all(context.temp_allocator)
		}
	}
}

@(test)
the_legacy_round_trips :: proc(t: ^testing.T) {
	for n in 0 ..= LEGACY_MAX {
		l := legacy_with(n)
		back, ok := parse_legacy(serialize_legacy(l))
		testing.expect(t, ok)
		testing.expect_value(t, back.count, n)
		testing.expect(t, back == l)
	}
	free_all(context.temp_allocator)
}

@(test)
damaged_saves_are_rejected :: proc(t: ^testing.T) {
	g := new_game(11)
	choose(&g, 0)
	good := serialize_game(g)
	_, ok := parse_game(good, g.legacy)
	testing.expect(t, ok)

	bad := [?]string {
		"",
		"garbage",
		mutate(good, 0, "PTX"), // wrong tag
		mutate(good, 1, "2"), // other version
		mutate(good, 2, "99"), // screen out of range
		mutate(good, 3, "0"), // generation 0
		mutate(good, 4, "10"), // flame above the maximum
		mutate(good, 4, "-1"),
		mutate(good, 4, "x"),
		mutate(good, 4, nil), // a token missing
		strings.concatenate({good, " 1"}, context.temp_allocator), // a token too many
		good[:len(good) - 3], // cut short
	}
	for text, i in bad {
		_, parsed := parse_game(text, g.legacy)
		testing.expectf(t, !parsed, "damaged save %d was accepted: %s", i, text)
	}
	toks := strings.split(good, " ", context.temp_allocator)
	rng_at := len(toks) - 4 // rng comes before event_kind, legacy_pick and legacy_used
	_, zero := parse_game(mutate(good, rng_at, "0"), g.legacy)
	testing.expect(t, !zero)
	free_all(context.temp_allocator)
}

@(test)
damaged_legacy_is_rejected :: proc(t: ^testing.T) {
	good := serialize_legacy(legacy_with(2))
	_, ok := parse_legacy(good)
	testing.expect(t, ok)
	for text, i in ([?]string{"", "PTL 1", mutate(good, 2, "6"), mutate(good, 2, "1"), mutate(good, 4, "99"), mutate(good, 0, "PTT")}) {
		_, parsed := parse_legacy(text)
		testing.expectf(t, !parsed, "damaged legacy %d was accepted: %s", i, text)
	}
	// a record that says it holds neither an item nor a grudge
	empty := "PTL 1 1 0 0 0 0 0 0 1 0"
	_, parsed := parse_legacy(empty)
	testing.expect(t, !parsed)
	free_all(context.temp_allocator)
}

@(test)
a_save_that_names_a_missing_legacy_record_is_rejected :: proc(t: ^testing.T) {
	g := new_game(5)
	g.legacy = legacy_with(2)
	choose(&g, 0)
	g.event_kind = .Item
	g.legacy_pick = 1
	text := serialize_game(g)
	_, ok := parse_game(text, g.legacy)
	testing.expect(t, ok)
	_, ok = parse_game(text, legacy_with(1)) // the legacy was cleared since
	testing.expect(t, !ok)
	free_all(context.temp_allocator)
}

// Any save that still loads after damage must be playable to the end without a crash.
@(test)
damaged_saves_that_load_still_play :: proc(t: ^testing.T) {
	legacy := legacy_with(3)
	loaded := 0
	total := 0
	for seed in u64(0) ..< 25 {
		g := new_game(seed)
		g.legacy = legacy
		for step in 0 ..< 12 { 	// samples from early and late in a run
			if g.screen != .Title && g.screen != .Over {
				text := serialize_game(g)
				toks := strings.split(text, " ", context.temp_allocator)
				for i in 2 ..< len(toks) {
					for with in ([?]Maybe(string){"0", "1", "2", "3", "7", "-1", "9", nil}) {
						total += 1
						if back, ok := parse_game(mutate(text, i, with), legacy); ok {
							loaded += 1
							_ = run_to_end(t, back)
						}
					}
				}
			}
			if g.screen == .Over {
				break
			}
			v := make_view(g)
			choose(&g, 0 if g.screen == .Title else roll(&g, v.choice_count)) // never "Forget the past"
			free_all(context.temp_allocator)
			_ = step
		}
		free_all(context.temp_allocator)
	}
	testing.expect(t, loaded > 0 && loaded < total) // some damage is harmless, most is caught
}

@(test)
a_finished_dynasty_is_remembered_and_the_oldest_forgotten :: proc(t: ^testing.T) {
	g := new_game(2)
	g.generation = 3
	g.over = .Flame_Out
	g.items[.Ladle] = Held{true, 2}
	g.items[.Soggy_Hat] = Held{true, 5}
	g.grudges[.Sky] = Held{true, 1}
	remember(&g)
	testing.expect_value(t, g.legacy.count, 1)
	rec := g.legacy.records[0]
	testing.expect_value(t, rec.item, Item_Id.Soggy_Hat) // the oldest of what it held
	testing.expect_value(t, rec.item_stage, 5)
	testing.expect_value(t, rec.grudge, Grudge_Id.Sky)
	testing.expect_value(t, rec.generations, 3)
	testing.expect(t, !rec.survived)

	// a second dynasty ages the first record by one stage
	g.generation = 8
	g.over = .Dynasty_End
	remember(&g)
	testing.expect_value(t, g.legacy.count, 2)
	testing.expect_value(t, g.legacy.records[0].generations, 8)
	testing.expect(t, g.legacy.records[0].survived)
	testing.expect_value(t, g.legacy.records[1].item_stage, 6)
	testing.expect_value(t, g.legacy.records[1].grudge_stage, 2)

	// many dynasties: capped, newest first, stages never past the end of the ladder
	for i in 0 ..< 10 {
		g.generation = 1 + i % MAX_GENERATIONS
		remember(&g)
	}
	testing.expect_value(t, g.legacy.count, LEGACY_MAX)
	for i in 0 ..< g.legacy.count {
		testing.expect(t, g.legacy.records[i].item_stage <= DRIFT_STEPS - 1)
		testing.expect(t, g.legacy.records[i].grudge_stage <= DRIFT_STEPS - 1)
	}
	testing.expect_value(t, g.legacy.records[0].generations, 1 + 9 % MAX_GENERATIONS)
}

@(test)
a_dynasty_that_held_nothing_leaves_nothing :: proc(t: ^testing.T) {
	g := new_game(2)
	g.generation = 4
	g.over = .Flame_Out
	remember(&g)
	testing.expect_value(t, g.legacy.count, 0)
}

@(test)
ending_a_run_writes_the_legacy :: proc(t: ^testing.T) {
	g := new_game(3)
	choose(&g, 0)
	g.items[.Ladle] = Held{true, 1}
	end_run(&g, .Flame_Out)
	testing.expect_value(t, g.legacy.count, 1)
	// and the legacy outlives the next run
	choose(&g, 0)
	testing.expect_value(t, g.screen, Screen.Event)
	testing.expect_value(t, g.legacy.count, 1)
	free_all(context.temp_allocator)
}

@(test)
past_dynasties_come_back_as_events :: proc(t: ^testing.T) {
	legacy := legacy_with(2)
	total := 0
	for seed in u64(0) ..< 300 {
		g := new_game(seed)
		g.legacy = legacy
		seen_records: bit_set[0 ..< LEGACY_MAX]
		was_event := false
		for _ in 0 ..< MAX_STEPS {
			if g.screen == .Over {
				break
			}
			is_event := g.screen == .Event
			if is_event && !was_event && g.event_kind != .Normal {
				total += 1
				testing.expectf(t, g.generation >= 2, "seed %d: a relative turned up in generation 1", seed)
				testing.expectf(t, g.legacy_pick not_in seen_records, "seed %d: record %d came up twice", seed, g.legacy_pick)
				seen_records += {g.legacy_pick}
			}
			was_event = is_event
			v := make_view(g)
			choose(&g, 0 if g.screen == .Title else roll(&g, v.choice_count)) // never "Forget the past"
			free_all(context.temp_allocator)
		}
	}
	testing.expect(t, total > 0)
}

@(test)
no_past_means_no_relatives :: proc(t: ^testing.T) {
	for seed in u64(0) ..< 100 {
		g := new_game(seed)
		for _ in 0 ..< MAX_STEPS {
			if g.screen == .Over {
				break
			}
			testing.expect_value(t, g.event_kind, Legacy_Kind.Normal)
			v := make_view(g)
			choose(&g, 0 if g.screen == .Title else roll(&g, v.choice_count)) // never "Forget the past"
			free_all(context.temp_allocator)
		}
	}
}

@(test)
taking_up_an_old_grudge_brings_it_back_at_its_age :: proc(t: ^testing.T) {
	g := new_game(8)
	g.legacy.records[0] = Legacy_Record{has_grudge = true, grudge = .Heron, grudge_stage = 4, generations = 5}
	g.legacy.count = 1
	choose(&g, 0)
	g.event_kind = .Grudge
	g.legacy_pick = 0
	g.screen = .Event
	v := make_view(g)
	testing.expect_value(t, v.choice_count, 3)
	testing.expect(t, strings.contains(v.lines[v.line_count - 1], "herons") || strings.contains(v.lines[v.line_count - 1], "tall birds"))
	choose(&g, 0)
	testing.expect_value(t, g.screen, Screen.Result)
	testing.expect_value(t, g.grudges[.Heron], Held{true, 4})
	// the other options do not
	g2 := g
	g2.grudges = {}
	g2.screen = .Event
	choose(&g2, 1)
	testing.expect(t, !g2.grudges[.Heron].present)
	free_all(context.temp_allocator)
}

@(test)
the_title_remembers_and_can_forget :: proc(t: ^testing.T) {
	g := new_game(6)
	v := make_view(g)
	testing.expect_value(t, v.choice_count, 1)
	g.legacy = legacy_with(LEGACY_MAX)
	v = make_view(g)
	testing.expect_value(t, v.choice_count, 2)
	testing.expect(t, v.line_count <= MAX_LINES)
	choose(&g, 1)
	testing.expect_value(t, g.legacy.count, 0)
	testing.expect_value(t, g.screen, Screen.Title)
	free_all(context.temp_allocator)
}
