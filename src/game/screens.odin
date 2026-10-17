// The screen state machine: what is visible (make_view) and what a choice does (choose).
// Dynamic strings are built in context.temp_allocator; the caller frees it after drawing.
package game

import "core:fmt"
import "core:strings"

MAX_LINES :: 8
MAX_CHOICES :: 8

View :: struct {
	lines:        [MAX_LINES]string,
	line_count:   int,
	choices:      [MAX_CHOICES]string,
	choice_count: int,
}

add_line :: proc(v: ^View, s: string) {
	v.lines[v.line_count] = s
	v.line_count += 1
}

add_choice :: proc(v: ^View, s: string) {
	v.choices[v.choice_count] = s
	v.choice_count += 1
}

status_line :: proc(g: Game) -> string {
	c := g.counters
	return fmt.tprintf(
		"Generation %d of %d   Flame %d  Pride %d  Livestock %d  Reputation %d  Snacks %d",
		g.generation,
		MAX_GENERATIONS,
		c[.Flame],
		c[.Pride],
		c[.Livestock],
		c[.Reputation],
		c[.Snacks],
	)
}

delta_summary :: proc(d: [Counter]int) -> string {
	sb := strings.builder_make(context.temp_allocator)
	for c in Counter {
		if d[c] != 0 {
			if strings.builder_len(sb) > 0 {
				strings.write_string(&sb, "  ")
			}
			fmt.sbprintf(&sb, "%v %+d", c, d[c])
		}
	}
	if strings.builder_len(sb) == 0 {
		return "No change."
	}
	return strings.to_string(sb)
}

// Everything held in these sets, as "a ladle; a grudge against the goat for eating the map", or "nothing".
holdings_text :: proc(items: [Item_Id]Held, grudges: [Grudge_Id]Held) -> string {
	sb := strings.builder_make(context.temp_allocator)
	for id in Item_Id {
		if items[id].present {
			if strings.builder_len(sb) > 0 {
				strings.write_string(&sb, "; ")
			}
			strings.write_string(&sb, item_text(id, items[id].stage))
		}
	}
	for id in Grudge_Id {
		if grudges[id].present {
			if strings.builder_len(sb) > 0 {
				strings.write_string(&sb, "; ")
			}
			strings.write_string(&sb, grudge_text(id, grudges[id].stage))
		}
	}
	if strings.builder_len(sb) == 0 {
		return "nothing"
	}
	return strings.to_string(sb)
}

// The held entries in id order, so a choice index maps back to an id.
held_items :: proc(items: [Item_Id]Held, out: ^[len(Item_Id)]Item_Id) -> int {
	n := 0
	for id in Item_Id {
		if items[id].present {
			out[n] = id
			n += 1
		}
	}
	return n
}

held_grudges :: proc(grudges: [Grudge_Id]Held, out: ^[len(Grudge_Id)]Grudge_Id) -> int {
	n := 0
	for id in Grudge_Id {
		if grudges[id].present {
			out[n] = id
			n += 1
		}
	}
	return n
}

make_view :: proc(g: Game) -> View {
	v: View
	switch g.screen {
	case .Title:
		add_line(&v, "PASS THE TORCH")
		add_line(&v, "You have a torch. It does not stay yours.")
		add_choice(&v, "Begin")
	case .Event:
		add_line(&v, status_line(g))
		if g.events_left == EVENTS_PER_GENERATION {
			if g.generation == 1 {
				add_line(&v, "You hold the torch.")
			} else {
				heir := HEIRS[g.heir]
				add_line(&v, fmt.tprintf("%s, %s, holds the torch now.", heir.name, heir.trait))
			}
		}
		event := EVENTS[g.event]
		add_line(&v, event.prompt)
		open: [3]int
		n := available_options(g, &open)
		for i in 0 ..< n {
			add_choice(&v, event.options[open[i]].text)
		}
	case .Result:
		option := EVENTS[g.event].options[g.last_option]
		add_line(&v, status_line(g))
		add_line(&v, option.result)
		add_line(&v, delta_summary(option.delta))
		if item, ok := option.item.?; ok {
			add_line(&v, fmt.tprintf("You now hold %s.", item_text(item, g.items[item].stage)))
		}
		if grudge, ok := option.grudge.?; ok {
			add_line(&v, fmt.tprintf("You now hold %s.", grudge_text(grudge, g.grudges[grudge].stage)))
		}
		add_choice(&v, "Continue")
	case .Heir:
		add_line(&v, status_line(g))
		add_line(&v, "The torch must go to someone. Who?")
		for i in 0 ..< HEIR_CHOICES {
			heir := HEIRS[g.candidates[i]]
			add_choice(&v, fmt.tprintf("%s, %s (+%v, -%v)", heir.name, heir.trait, heir.plus, heir.minus))
		}
	case .Handover_Item:
		add_line(&v, status_line(g))
		add_line(&v, "Only one thing can be handed over, and it will not arrive the same. The rest is left behind.")
		list: [len(Item_Id)]Item_Id
		n := held_items(g.items, &list)
		for i in 0 ..< n {
			add_choice(&v, item_text(list[i], g.items[list[i]].stage))
		}
		add_choice(&v, "Hand over nothing")
	case .Handover_Grudge:
		add_line(&v, status_line(g))
		add_line(&v, "Only one grudge can be handed over, and it will not arrive the same. The rest is left behind.")
		if g.carry_item != nil {
			add_line(&v, fmt.tprintf("Carrying a grudge as well as a thing costs %d more flame.", EXTRA_CARRY_COST))
		}
		list: [len(Grudge_Id)]Grudge_Id
		n := held_grudges(g.grudges, &list)
		for i in 0 ..< n {
			add_choice(&v, grudge_text(list[i], g.grudges[list[i]].stage))
		}
		add_choice(&v, "Hand over nothing")
	case .Handoff:
		heir := HEIRS[g.heir]
		add_line(&v, status_line(g))
		add_line(&v, fmt.tprintf("%s takes the torch. The handoff costs %d flame.", heir.name, g.handoff_cost))
		add_line(&v, fmt.tprintf("Left behind: %s.", holdings_text(g.left_items, g.left_grudges)))
		if item, ok := g.carry_item.?; ok {
			stage := g.items[item].stage
			add_line(&v, fmt.tprintf("It arrives as %s. (It was %s.)", item_text(item, stage), item_text(item, stage - 1)))
		}
		if grudge, ok := g.carry_grudge.?; ok {
			stage := g.grudges[grudge].stage
			add_line(&v, fmt.tprintf("It arrives as %s. (It was %s.)", grudge_text(grudge, stage), grudge_text(grudge, stage - 1)))
		}
		add_choice(&v, "Continue")
	case .Over:
		switch g.over {
		case .Flame_Out:
			add_line(&v, fmt.tprintf("The torch goes out in generation %d.", g.generation))
		case .Dynasty_End:
			add_line(&v, "The torch is still lit. Nobody remembers who lit it.")
		}
		add_line(&v, fmt.tprintf("What survived: %s.", holdings_text(g.items, g.grudges)))
		add_choice(&v, "Begin again")
	}
	return v
}

// Runs the transition for one visible choice. An out-of-range index does nothing.
choose :: proc(g: ^Game, index: int) {
	v := make_view(g^)
	if index < 0 || index >= v.choice_count {
		return
	}
	switch g.screen {
	case .Title, .Over:
		start_run(g)
	case .Event:
		open: [3]int
		_ = available_options(g^, &open)
		choose_option(g, open[index])
	case .Result:
		finish_result(g)
	case .Heir:
		choose_heir(g, index)
	case .Handover_Item:
		list: [len(Item_Id)]Item_Id
		n := held_items(g.items, &list)
		if index < n {
			g.carry_item = list[index]
		}
		after_item_step(g)
	case .Handover_Grudge:
		list: [len(Grudge_Id)]Grudge_Id
		n := held_grudges(g.grudges, &list)
		if index < n {
			g.carry_grudge = list[index]
		}
		finish_handover(g)
	case .Handoff:
		finish_handoff(g)
	}
}
