// Pure rules for Pass the Torch. No platform imports: this package compiles natively (for tests) and to wasm.
// The clock never appears here; the only outside input is the seed given to new_game.
package game

START_FLAME :: 6
START_COUNTER :: 3
COUNTER_MAX :: 9
HANDOFF_COST :: 1
EVENTS_PER_GENERATION :: 3
MAX_GENERATIONS :: 8
HEIR_CHOICES :: 3

Counter :: enum {
	Flame,
	Pride,
	Livestock,
	Reputation,
	Snacks,
}

Item_Id :: enum {
	Goat_Chewed_Map,
	Soggy_Hat,
	Ladle,
}

Grudge_Id :: enum {
	Goat,
	Stranger,
	Neighbors,
	Sky,
}

Event_Id :: enum {
	Goat_Incident,
	Stranger_Offer,
	Loud_Neighbors,
	Rain,
	Feast,
}

Heir_Id :: enum {
	Brindle,
	Odo,
	Pim,
	Aunt_Vex,
}

Over_Reason :: enum {
	Flame_Out,
	Dynasty_End,
}

Screen :: enum {
	Title,
	Event,
	Result,
	Heir,
	Handover_Item,
	Handover_Grudge,
	Over,
}

// A flat value type: no pointers, no heap. Copy it to snapshot a run.
Game :: struct {
	screen:       Screen,
	generation:   int,
	counters:     [Counter]int,
	items:        bit_set[Item_Id],
	grudges:      bit_set[Grudge_Id],
	carry_item:   Maybe(Item_Id),
	carry_grudge: Maybe(Grudge_Id),
	events_seen:  bit_set[Event_Id], // this generation only, so no event repeats within one
	events_left:  int,
	event:        Event_Id,
	last_option:  int,
	candidates:   [HEIR_CHOICES]Heir_Id,
	heir:         Heir_Id,
	over:         Over_Reason,
	rng:          u64,
}

new_game :: proc(seed: u64) -> Game {
	g := Game{screen = .Title}
	g.rng = seed ~ 0x9E3779B97F4A7C15
	if g.rng == 0 {
		g.rng = 1
	}
	for _ in 0 ..< 8 { 	// close seeds should not start with close rolls
		roll(&g, 2)
	}
	return g
}

// Uniform-ish integer in [0, n). xorshift64; n must be positive.
roll :: proc(g: ^Game, n: int) -> int {
	g.rng ~= g.rng << 13
	g.rng ~= g.rng >> 7
	g.rng ~= g.rng << 17
	return int(g.rng % u64(n))
}

start_run :: proc(g: ^Game) {
	g.generation = 1
	for c in Counter {
		g.counters[c] = START_COUNTER
	}
	g.counters[.Flame] = START_FLAME
	g.items = {}
	g.grudges = {}
	g.carry_item = nil
	g.carry_grudge = nil
	begin_generation(g)
}

begin_generation :: proc(g: ^Game) {
	g.events_seen = {}
	g.events_left = EVENTS_PER_GENERATION
	begin_event(g)
}

begin_event :: proc(g: ^Game) {
	unseen: [len(Event_Id)]Event_Id
	n := 0
	for e in Event_Id {
		if e not_in g.events_seen {
			unseen[n] = e
			n += 1
		}
	}
	// EVENTS_PER_GENERATION is below the number of events, so at least one is always unseen.
	g.event = unseen[roll(g, n)]
	g.events_seen += {g.event}
	g.screen = .Event
}

apply_delta :: proc(g: ^Game, delta: [Counter]int) {
	for c in Counter {
		g.counters[c] = clamp(g.counters[c] + delta[c], 0, COUNTER_MAX)
	}
}

choose_option :: proc(g: ^Game, index: int) {
	option := EVENTS[g.event].options[index]
	apply_delta(g, option.delta)
	if item, ok := option.item.?; ok {
		g.items += {item}
	}
	if grudge, ok := option.grudge.?; ok {
		g.grudges += {grudge}
	}
	g.last_option = index
	g.screen = .Result
}

// Called when the player acknowledges a result.
finish_result :: proc(g: ^Game) {
	if g.counters[.Flame] <= 0 {
		end_run(g, .Flame_Out)
		return
	}
	g.events_left -= 1
	switch {
	case g.events_left > 0:
		begin_event(g)
	case g.generation >= MAX_GENERATIONS:
		end_run(g, .Dynasty_End)
	case:
		offer_heirs(g)
	}
}

offer_heirs :: proc(g: ^Game) {
	pool: [len(Heir_Id)]Heir_Id
	for h in Heir_Id {
		pool[int(h)] = h
	}
	for i in 0 ..< HEIR_CHOICES { 	// partial Fisher-Yates: the first HEIR_CHOICES entries are distinct
		j := i + roll(g, len(pool) - i)
		pool[i], pool[j] = pool[j], pool[i]
		g.candidates[i] = pool[i]
	}
	g.screen = .Heir
}

choose_heir :: proc(g: ^Game, index: int) {
	g.heir = g.candidates[index]
	g.carry_item = nil
	g.carry_grudge = nil
	if g.items != {} {
		g.screen = .Handover_Item
	} else {
		after_item_step(g)
	}
}

// Both handover steps are skipped when there is nothing to choose from.
after_item_step :: proc(g: ^Game) {
	if g.grudges != {} {
		g.screen = .Handover_Grudge
	} else {
		finish_handover(g)
	}
}

end_run :: proc(g: ^Game, reason: Over_Reason) {
	g.over = reason
	g.screen = .Over
}

// Exactly one item and one grudge cross; everything else, including the other counters, is left behind.
finish_handover :: proc(g: ^Game) {
	g.generation += 1
	g.counters[.Flame] = clamp(g.counters[.Flame] - HANDOFF_COST, 0, COUNTER_MAX)
	for c in Counter {
		if c != .Flame {
			g.counters[c] = START_COUNTER
		}
	}
	heir := HEIRS[g.heir]
	g.counters[heir.plus] = clamp(g.counters[heir.plus] + 1, 0, COUNTER_MAX)
	g.counters[heir.minus] = clamp(g.counters[heir.minus] - 1, 0, COUNTER_MAX)
	g.items = {}
	g.grudges = {}
	if item, ok := g.carry_item.?; ok {
		g.items += {item}
	}
	if grudge, ok := g.carry_grudge.?; ok {
		g.grudges += {grudge}
	}
	if g.counters[.Flame] <= 0 {
		end_run(g, .Flame_Out)
		return
	}
	begin_generation(g)
}
