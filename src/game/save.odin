// Saving. A run and the legacy are each one line of space-separated integers behind a short tag, so there is no
// allocator to manage and nothing platform-specific. Every field is read with its legal range, and a parse only
// succeeds if the whole line is consumed; a failed parse leaves the caller's game untouched. The two writers and the
// two readers must list the fields in the same order (a round-trip test pins them together).
package game

import "core:fmt"
import "core:strconv"
import "core:strings"

SAVE_VERSION :: 1
RUN_TAG :: "PTT"
LEGACY_TAG :: "PTL"

// ---- writing

put :: proc(sb: ^strings.Builder, v: int) {
	fmt.sbprintf(sb, " %d", v)
}

put_held :: proc(sb: ^strings.Builder, held: [$E]Held) {
	for h in held {
		put(sb, 1 if h.present else 0)
		put(sb, h.stage)
	}
}

// -1 for none, otherwise the enum's position.
put_maybe :: proc(sb: ^strings.Builder, m: Maybe($E)) {
	if id, ok := m.?; ok {
		put(sb, int(id))
	} else {
		put(sb, -1)
	}
}

serialize_game :: proc(g: Game) -> string {
	sb := strings.builder_make(context.temp_allocator)
	fmt.sbprintf(&sb, "%s %d", RUN_TAG, SAVE_VERSION)
	put(&sb, int(g.screen))
	put(&sb, g.generation)
	for c in Counter {
		put(&sb, g.counters[c])
	}
	put_held(&sb, g.items)
	put_held(&sb, g.grudges)
	put_maybe(&sb, g.carry_item)
	put_maybe(&sb, g.carry_grudge)
	put_held(&sb, g.left_items)
	put_held(&sb, g.left_grudges)
	put(&sb, g.handoff_cost)
	seen := 0
	for e in Event_Id {
		if e in g.events_seen {
			seen |= 1 << uint(e)
		}
	}
	put(&sb, seen)
	put(&sb, g.events_left)
	put(&sb, int(g.event))
	put(&sb, g.last_option)
	for h in g.candidates {
		put(&sb, int(h))
	}
	put(&sb, int(g.heir))
	put(&sb, int(g.over))
	fmt.sbprintf(&sb, " %d", g.rng)
	put(&sb, int(g.event_kind))
	put(&sb, g.legacy_pick)
	used := 0
	for i in 0 ..< LEGACY_MAX {
		if i in g.legacy_used {
			used |= 1 << uint(i)
		}
	}
	put(&sb, used)
	return strings.to_string(sb)
}

serialize_legacy :: proc(l: Legacy) -> string {
	sb := strings.builder_make(context.temp_allocator)
	fmt.sbprintf(&sb, "%s %d", LEGACY_TAG, SAVE_VERSION)
	put(&sb, l.count)
	for i in 0 ..< l.count {
		r := l.records[i]
		put(&sb, 1 if r.has_item else 0)
		put(&sb, int(r.item))
		put(&sb, r.item_stage)
		put(&sb, 1 if r.has_grudge else 0)
		put(&sb, int(r.grudge))
		put(&sb, r.grudge_stage)
		put(&sb, r.generations)
		put(&sb, 1 if r.survived else 0)
	}
	return strings.to_string(sb)
}

// ---- reading

Reader :: struct {
	toks: []string,
	i:    int,
	ok:   bool,
}

reader_for :: proc(text: string, tag: string) -> Reader {
	toks := strings.split(text, " ", context.temp_allocator)
	r := Reader {
		toks = toks,
		ok   = true,
	}
	if len(toks) < 2 || toks[0] != tag {
		r.ok = false
		return r
	}
	r.i = 1
	if read_int(&r, SAVE_VERSION, SAVE_VERSION) != SAVE_VERSION {
		r.ok = false
	}
	return r
}

read_int :: proc(r: ^Reader, lo, hi: int) -> int {
	if !r.ok || r.i >= len(r.toks) {
		r.ok = false
		return lo
	}
	v, parsed := strconv.parse_int(r.toks[r.i], 10)
	r.i += 1
	if !parsed || v < lo || v > hi {
		r.ok = false
		return lo
	}
	return v
}

read_bool :: proc(r: ^Reader) -> bool {
	return read_int(r, 0, 1) == 1
}

read_enum :: proc(r: ^Reader, $E: typeid) -> E {
	return E(read_int(r, 0, len(E) - 1))
}

read_held :: proc(r: ^Reader, out: ^[$E]Held) {
	for &h in out {
		h.present = read_bool(r)
		h.stage = read_int(r, 0, DRIFT_STEPS - 1)
	}
}

read_maybe :: proc(r: ^Reader, $E: typeid) -> Maybe(E) {
	v := read_int(r, -1, len(E) - 1)
	if v < 0 {
		return nil
	}
	return E(v)
}

finished :: proc(r: Reader) -> bool {
	return r.ok && r.i == len(r.toks)
}

// Legacy to attach to the loaded game: a legacy event refers to one of its records.
parse_game :: proc(text: string, legacy: Legacy) -> (g: Game, ok: bool) {
	r := reader_for(text, RUN_TAG)
	g.screen = read_enum(&r, Screen)
	g.generation = read_int(&r, 1, MAX_GENERATIONS)
	for c in Counter {
		g.counters[c] = read_int(&r, 0, COUNTER_MAX)
	}
	read_held(&r, &g.items)
	read_held(&r, &g.grudges)
	g.carry_item = read_maybe(&r, Item_Id)
	g.carry_grudge = read_maybe(&r, Grudge_Id)
	read_held(&r, &g.left_items)
	read_held(&r, &g.left_grudges)
	g.handoff_cost = read_int(&r, 0, HANDOFF_COST + EXTRA_CARRY_COST)
	seen := read_int(&r, 0, (1 << uint(len(Event_Id))) - 1)
	for e in Event_Id {
		if seen & (1 << uint(e)) != 0 {
			g.events_seen += {e}
		}
	}
	g.events_left = read_int(&r, 0, EVENTS_PER_GENERATION)
	g.event = read_enum(&r, Event_Id)
	g.last_option = read_int(&r, 0, 2)
	for &h in g.candidates {
		h = read_enum(&r, Heir_Id)
	}
	g.heir = read_enum(&r, Heir_Id)
	g.over = read_enum(&r, Over_Reason)
	if r.ok && r.i < len(r.toks) {
		v, parsed := strconv.parse_u64(r.toks[r.i], 10)
		r.i += 1
		if !parsed || v == 0 { 	// xorshift never leaves zero, so a zero state would stall the rolls
			r.ok = false
		}
		g.rng = v
	} else {
		r.ok = false
	}
	g.event_kind = read_enum(&r, Legacy_Kind)
	g.legacy_pick = read_int(&r, 0, LEGACY_MAX - 1)
	used := read_int(&r, 0, (1 << LEGACY_MAX) - 1)
	for i in 0 ..< LEGACY_MAX {
		if used & (1 << uint(i)) != 0 {
			g.legacy_used += {i}
		}
	}
	if !finished(r) {
		return Game{}, false
	}

	// Cross-field checks: references a view or a choice would follow must be in range.
	g.legacy = legacy
	if g.event_kind != .Normal && g.legacy_pick >= legacy.count {
		return Game{}, false
	}
	if g.event_kind == .Normal && g.last_option >= EVENTS[g.event].option_count {
		return Game{}, false
	}
	for i in 0 ..< HEIR_CHOICES {
		for j in i + 1 ..< HEIR_CHOICES {
			if g.candidates[i] == g.candidates[j] {
				return Game{}, false
			}
		}
	}
	return g, true
}

parse_legacy :: proc(text: string) -> (l: Legacy, ok: bool) {
	r := reader_for(text, LEGACY_TAG)
	l.count = read_int(&r, 0, LEGACY_MAX)
	for i in 0 ..< l.count {
		rec: Legacy_Record
		rec.has_item = read_bool(&r)
		rec.item = read_enum(&r, Item_Id)
		rec.item_stage = read_int(&r, 0, DRIFT_STEPS - 1)
		rec.has_grudge = read_bool(&r)
		rec.grudge = read_enum(&r, Grudge_Id)
		rec.grudge_stage = read_int(&r, 0, DRIFT_STEPS - 1)
		rec.generations = read_int(&r, 1, MAX_GENERATIONS)
		rec.survived = read_bool(&r)
		if !rec.has_item && !rec.has_grudge {
			r.ok = false // remember() never writes an empty record
		}
		l.records[i] = rec
	}
	if !finished(r) {
		return Legacy{}, false
	}
	return l, true
}
