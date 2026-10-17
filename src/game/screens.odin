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

held_items :: proc(items: bit_set[Item_Id], out: ^[len(Item_Id)]Item_Id) -> int {
	n := 0
	for i in Item_Id {
		if i in items {
			out[n] = i
			n += 1
		}
	}
	return n
}

held_grudges :: proc(grudges: bit_set[Grudge_Id], out: ^[len(Grudge_Id)]Grudge_Id) -> int {
	n := 0
	for gr in Grudge_Id {
		if gr in grudges {
			out[n] = gr
			n += 1
		}
	}
	return n
}

// "a ladle, a soggy hat" or "nothing"
item_list :: proc(items: bit_set[Item_Id]) -> string {
	sb := strings.builder_make(context.temp_allocator)
	for i in Item_Id {
		if i in items {
			if strings.builder_len(sb) > 0 {
				strings.write_string(&sb, ", ")
			}
			strings.write_string(&sb, ITEM_NAMES[i])
		}
	}
	if strings.builder_len(sb) == 0 {
		return "nothing"
	}
	return strings.to_string(sb)
}

grudge_list :: proc(grudges: bit_set[Grudge_Id]) -> string {
	sb := strings.builder_make(context.temp_allocator)
	for gr in Grudge_Id {
		if gr in grudges {
			if strings.builder_len(sb) > 0 {
				strings.write_string(&sb, ", ")
			}
			strings.write_string(&sb, GRUDGE_NAMES[gr])
		}
	}
	if strings.builder_len(sb) == 0 {
		return "nothing"
	}
	return strings.to_string(sb)
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
		for i in 0 ..< event.option_count {
			add_choice(&v, event.options[i].text)
		}
	case .Result:
		option := EVENTS[g.event].options[g.last_option]
		add_line(&v, status_line(g))
		add_line(&v, option.result)
		add_line(&v, delta_summary(option.delta))
		if item, ok := option.item.?; ok {
			add_line(&v, fmt.tprintf("You now hold %s.", ITEM_NAMES[item]))
		}
		if grudge, ok := option.grudge.?; ok {
			add_line(&v, fmt.tprintf("You now resent %s.", GRUDGE_NAMES[grudge]))
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
		add_line(&v, "Only one thing can be handed over. Which?")
		add_line(&v, fmt.tprintf("You hold: %s. Whatever you do not choose is left behind.", item_list(g.items)))
		list: [len(Item_Id)]Item_Id
		n := held_items(g.items, &list)
		for i in 0 ..< n {
			add_choice(&v, ITEM_NAMES[list[i]])
		}
		add_choice(&v, "Hand over nothing")
	case .Handover_Grudge:
		add_line(&v, status_line(g))
		add_line(&v, "Only one grudge can be handed over. Which?")
		add_line(&v, fmt.tprintf("You resent: %s. Whatever you do not choose is left behind.", grudge_list(g.grudges)))
		list: [len(Grudge_Id)]Grudge_Id
		n := held_grudges(g.grudges, &list)
		for i in 0 ..< n {
			add_choice(&v, GRUDGE_NAMES[list[i]])
		}
		add_choice(&v, "Hand over nothing")
	case .Over:
		switch g.over {
		case .Flame_Out:
			add_line(&v, fmt.tprintf("The torch goes out in generation %d.", g.generation))
		case .Dynasty_End:
			add_line(&v, "The torch is still lit. Nobody remembers who lit it.")
		}
		add_line(&v, fmt.tprintf("Held at the end: %s.", item_list(g.items)))
		add_line(&v, fmt.tprintf("Resented at the end: %s.", grudge_list(g.grudges)))
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
		choose_option(g, index)
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
	}
}
