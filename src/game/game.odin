// Pure rules for Torch Passers of SPLORR!!. No platform imports: this package compiles natively (for tests) and to wasm.
// The clock never appears here; the only outside input is the seed given to new_game.
package game

START_FLAME :: 3
START_COUNTER :: 3
COUNTER_MAX :: 9
HANDOFF_COST :: 1 // every handoff costs this much flame, whatever you carry
EXTRA_CARRY_COST :: 1 // carrying both an item and a grudge costs this much more
EVENTS_PER_GENERATION :: 3
MAX_GENERATIONS :: 8
HEIR_CHOICES :: 3
LEGACY_MAX :: 5 // past dynasties remembered; older ones are forgotten

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
	Borrowed_Bucket,
	Heirloom_Cheese,
	Pocket_Sundial,
	Wedding_Boot,
	Rubber_Duck,
}

Grudge_Id :: enum {
	Goat,
	Stranger,
	Neighbors,
	Sky,
	Cousin,
	Mayor,
	Bakery,
	Heron,
	Tax_Man,
}

Event_Id :: enum {
	Goat_Incident,
	Stranger_Offer,
	Loud_Neighbors,
	Rain,
	Feast,
	Bucket_Loan,
	Cheese_Heirloom,
	Sundial_Seller,
	Wedding,
	Duck,
	Cousin_Gil,
	Permit,
	Baker,
	Heron,
	Fence,
	Choir,
	Tax_Man,
	Moths,
	Bridge,
	Rumor,
	Snack_Cart,
	Echo,
	Stone,
	Bell,
	Hill,
}

// A run draws EVENTS_PER_GENERATION events per generation and never repeats one, so there must be enough.
#assert(len(Event_Id) >= MAX_GENERATIONS * EVENTS_PER_GENERATION)

Heir_Id :: enum {
	Brindle,
	Odo,
	Pim,
	Aunt_Vex,
	Moss,
	Dame_Wren,
	Tobin,
	Little_Sorrel,
	Gus,
	Marigold,
	Third_Cousin,
	Hob,
}

Over_Reason :: enum {
	Flame_Out,
	Dynasty_End,
}

// What the current event is: a normal one from EVENTS, or a relative bringing back something a past dynasty left.
Legacy_Kind :: enum {
	Normal,
	Grudge,
	Item,
}

// Sounds the page can play. The page loads assets/sfx/<lower-case name>.wav, in this order (tools/test.sh checks it).
Sound :: enum {
	Click,
	Flame_Up,
	Flame_Down,
	Handoff,
	Flame_Low,
	Ending,
}

Sounds :: bit_set[Sound]

Screen :: enum {
	Title,
	Event,
	Result,
	Heir,
	Handover_Item,
	Handover_Grudge,
	Handoff,
	Over,
}

// Something you hold. `stage` counts the handoffs it has survived; the words that describe it drift with it.
Held :: struct {
	present: bool,
	stage:   int,
}

// What a finished dynasty left: the oldest item and the oldest grudge it still held. Records age as newer
// dynasties are added, so what is remembered drifts across runs the same way it drifts across handoffs.
Legacy_Record :: struct {
	has_item:     bool,
	item:         Item_Id,
	item_stage:   int,
	has_grudge:   bool,
	grudge:       Grudge_Id,
	grudge_stage: int,
	generations:  int,
	survived:     bool, // the torch was still lit at the end
}

// Newest first.
Legacy :: struct {
	records: [LEGACY_MAX]Legacy_Record,
	count:   int,
}

// A flat value type: no pointers, no heap. Copy it to snapshot a run.
Game :: struct {
	screen:        Screen,
	generation:    int,
	counters:      [Counter]int,
	items:         [Item_Id]Held,
	grudges:       [Grudge_Id]Held,
	carry_item:    Maybe(Item_Id),
	carry_grudge:  Maybe(Grudge_Id),
	left_items:    [Item_Id]Held, // what the last handoff did not carry, for the Handoff screen
	left_grudges:  [Grudge_Id]Held,
	handoff_cost:  int,
	events_seen:   bit_set[Event_Id], // this run, so no event repeats within one
	events_left:   int,
	event:         Event_Id,
	last_option:   int,
	candidates:    [HEIR_CHOICES]Heir_Id,
	heir:          Heir_Id,
	over:          Over_Reason,
	rng:           u64,
	legacy:        Legacy, // survives start_run; the platform loads and saves it separately from the run
	event_kind:    Legacy_Kind,
	legacy_pick:   int, // which record the current Legacy event is about
	legacy_used:   bit_set[0 ..< LEGACY_MAX], // records already brought up this run
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

any_held :: proc(held: [$E]Held) -> bool {
	for h in held {
		if h.present {
			return true
		}
	}
	return false
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
	g.events_seen = {}
	g.candidates = {.Brindle, .Odo, .Pim} // distinct from the start, so a save is valid before the first Heir screen
	g.legacy_used = {}
	g.event_kind = .Normal
	begin_generation(g)
}

begin_generation :: proc(g: ^Game) {
	g.events_left = EVENTS_PER_GENERATION
	begin_event(g)
}

begin_event :: proc(g: ^Game) {
	// From the second generation on, a relative may turn up with something from a past dynasty. It takes the
	// place of the generation's first event, so a generation is still EVENTS_PER_GENERATION events long.
	if g.events_left == EVENTS_PER_GENERATION && g.generation >= 2 && try_legacy_event(g) {
		return
	}
	g.event_kind = .Normal
	unseen: [len(Event_Id)]Event_Id
	n := 0
	for e in Event_Id {
		if e not_in g.events_seen {
			unseen[n] = e
			n += 1
		}
	}
	// The #assert above means a run cannot use them all up; the reset is only a guard.
	if n == 0 {
		g.events_seen = {}
		for e in Event_Id {
			unseen[n] = e
			n += 1
		}
	}
	g.event = unseen[roll(g, n)]
	g.events_seen += {g.event}
	g.screen = .Event
}

apply_delta :: proc(g: ^Game, delta: [Counter]int) {
	for c in Counter {
		g.counters[c] = clamp(g.counters[c] + delta[c], 0, COUNTER_MAX)
	}
}

option_available :: proc(g: Game, o: Option) -> bool {
	if r, ok := o.requires.?; ok {
		return g.counters[r.counter] >= r.at_least
	}
	return true
}

// The indexes (into the event's options) the player can pick right now. Unavailable options are left out.
available_options :: proc(g: Game, out: ^[3]int) -> int {
	event := EVENTS[g.event]
	n := 0
	for i in 0 ..< event.option_count {
		if option_available(g, event.options[i]) {
			out[n] = i
			n += 1
		}
	}
	return n
}

// `index` is an index into the event's options, as given by available_options.
choose_option :: proc(g: ^Game, index: int) {
	if g.event_kind != .Normal {
		choose_legacy_option(g, index)
		return
	}
	option := EVENTS[g.event].options[index]
	apply_delta(g, option.delta)
	// Getting something you already hold keeps its age: it does not make it new again.
	if item, ok := option.item.?; ok && !g.items[item].present {
		g.items[item] = Held{true, 0}
	}
	if grudge, ok := option.grudge.?; ok && !g.grudges[grudge].present {
		g.grudges[grudge] = Held{true, 0}
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
	n := 0
	for h in Heir_Id {
		if g.generation > 1 && h == g.heir {
			continue // the founder is no Heir_Id, but every later ruler cannot succeed themselves
		}
		pool[n] = h
		n += 1
	}
	for i in 0 ..< HEIR_CHOICES { 	// partial Fisher-Yates: the first HEIR_CHOICES entries are distinct
		j := i + roll(g, n - i)
		pool[i], pool[j] = pool[j], pool[i]
		g.candidates[i] = pool[i]
	}
	g.screen = .Heir
}

choose_heir :: proc(g: ^Game, index: int) {
	g.heir = g.candidates[index]
	g.carry_item = nil
	g.carry_grudge = nil
	if any_held(g.items) {
		g.screen = .Handover_Item
	} else {
		after_item_step(g)
	}
}

// Both handover steps are skipped when there is nothing to choose from.
after_item_step :: proc(g: ^Game) {
	if any_held(g.grudges) {
		g.screen = .Handover_Grudge
	} else {
		finish_handover(g)
	}
}

end_run :: proc(g: ^Game, reason: Over_Reason) {
	g.over = reason
	g.screen = .Over
	remember(g)
}

carry_cost :: proc(g: Game) -> int {
	cost := HANDOFF_COST
	if g.carry_item != nil && g.carry_grudge != nil {
		cost += EXTRA_CARRY_COST
	}
	return cost
}

// Exactly one item and one grudge cross, and each is one stage older (so its words drift). Everything else,
// including the other counters, is left behind. The flame always drops.
finish_handover :: proc(g: ^Game) {
	g.handoff_cost = carry_cost(g^)
	g.counters[.Flame] = clamp(g.counters[.Flame] - g.handoff_cost, 0, COUNTER_MAX)
	for c in Counter {
		if c != .Flame {
			g.counters[c] = START_COUNTER
		}
	}
	heir := HEIRS[g.heir]
	g.counters[heir.plus] = clamp(g.counters[heir.plus] + 1, 0, COUNTER_MAX)
	g.counters[heir.minus] = clamp(g.counters[heir.minus] - 1, 0, COUNTER_MAX)

	g.left_items = g.items
	g.left_grudges = g.grudges
	g.items = {}
	g.grudges = {}
	if item, ok := g.carry_item.?; ok {
		g.items[item] = Held{true, min(g.left_items[item].stage + 1, DRIFT_STEPS - 1)}
		g.left_items[item].present = false
	}
	if grudge, ok := g.carry_grudge.?; ok {
		g.grudges[grudge] = Held{true, min(g.left_grudges[grudge].stage + 1, DRIFT_STEPS - 1)}
		g.left_grudges[grudge].present = false
	}
	g.screen = .Handoff
}

// Called when the player acknowledges the Handoff screen.
finish_handoff :: proc(g: ^Game) {
	if g.counters[.Flame] <= 0 {
		end_run(g, .Flame_Out)
		return
	}
	g.generation += 1
	begin_generation(g)
}
