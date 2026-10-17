// Carry-over between runs: what a finished dynasty leaves behind and how it comes back.
package game

// What a dynasty would leave: the oldest item and the oldest grudge it still holds. false when it holds neither.
make_record :: proc(g: Game) -> (rec: Legacy_Record, ok: bool) {
	rec.generations = g.generation
	rec.survived = g.over == .Dynasty_End
	for id in Item_Id {
		if g.items[id].present && (!rec.has_item || g.items[id].stage > rec.item_stage) {
			rec.has_item = true
			rec.item = id
			rec.item_stage = g.items[id].stage
		}
	}
	for id in Grudge_Id {
		if g.grudges[id].present && (!rec.has_grudge || g.grudges[id].stage > rec.grudge_stage) {
			rec.has_grudge = true
			rec.grudge = id
			rec.grudge_stage = g.grudges[id].stage
		}
	}
	return rec, rec.has_item || rec.has_grudge
}

// Records what the dynasty left. A run that held neither leaves nothing. Existing records age one stage first, so
// older memories drift further.
remember :: proc(g: ^Game) {
	rec, ok := make_record(g^)
	if !ok {
		return
	}
	l := &g.legacy
	for i in 0 ..< l.count {
		l.records[i].item_stage = min(l.records[i].item_stage + 1, DRIFT_STEPS - 1)
		l.records[i].grudge_stage = min(l.records[i].grudge_stage + 1, DRIFT_STEPS - 1)
	}
	for i := min(l.count, LEGACY_MAX - 1); i > 0; i -= 1 { 	// shift older records down; the oldest falls off the end
		l.records[i] = l.records[i - 1]
	}
	l.records[0] = rec
	l.count = min(l.count + 1, LEGACY_MAX)
}

// Maybe turns the generation's first event into a visit from a relative. Half the time, and only for a record
// not yet used this run.
try_legacy_event :: proc(g: ^Game) -> bool {
	unused: [LEGACY_MAX]int
	n := 0
	for i in 0 ..< g.legacy.count {
		if i not_in g.legacy_used {
			unused[n] = i
			n += 1
		}
	}
	if n == 0 || roll(g, 2) != 0 {
		return false
	}
	pick := unused[roll(g, n)]
	rec := g.legacy.records[pick]
	switch {
	case rec.has_item && rec.has_grudge:
		g.event_kind = .Item if roll(g, 2) == 0 else .Grudge
	case rec.has_item:
		g.event_kind = .Item
	case:
		g.event_kind = .Grudge
	}
	g.legacy_pick = pick
	g.legacy_used += {pick}
	g.screen = .Event
	return true
}

// Option 0 takes the old thing back into the run, at the age the record gave it.
choose_legacy_option :: proc(g: ^Game, index: int) {
	option := LEGACY_OPTIONS[g.event_kind][index]
	apply_delta(g, option.delta)
	if index == 0 {
		rec := g.legacy.records[g.legacy_pick]
		switch g.event_kind {
		case .Item:
			if !g.items[rec.item].present {
				g.items[rec.item] = Held{true, rec.item_stage}
			}
		case .Grudge:
			if !g.grudges[rec.grudge].present {
				g.grudges[rec.grudge] = Held{true, rec.grudge_stage}
			}
		case .Normal:
		}
	}
	g.last_option = index
	g.screen = .Result
}
