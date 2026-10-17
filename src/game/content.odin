// Content tables. Data only: placeholder content for milestone 1 (5 events, 4 heirs); the real pass is milestone 3.
// These are variables (:=), not constants, because a constant array cannot be indexed by a runtime value.
package game

Option :: struct {
	text:   string,
	result: string,
	delta:  [Counter]int,
	item:   Maybe(Item_Id),
	grudge: Maybe(Grudge_Id),
}

Event :: struct {
	prompt:       string,
	option_count: int,
	options:      [3]Option,
}

Heir :: struct {
	name:  string,
	trait: string,
	plus:  Counter,
	minus: Counter,
}

ITEM_NAMES := [Item_Id]string {
	.Goat_Chewed_Map = "a goat-chewed map",
	.Soggy_Hat       = "a soggy hat",
	.Ladle           = "a ladle",
}

GRUDGE_NAMES := [Grudge_Id]string {
	.Goat      = "the goat",
	.Stranger  = "the stranger",
	.Neighbors = "the neighbors",
	.Sky       = "the sky",
}

HEIRS := [Heir_Id]Heir {
	.Brindle  = {"Brindle", "who talks to goats", .Livestock, .Reputation},
	.Odo      = {"Odo", "who is very warm", .Flame, .Snacks},
	.Pim      = {"Pim", "who remembers everything slightly wrong", .Reputation, .Pride},
	.Aunt_Vex = {"Aunt Vex", "who is not technically an heir", .Pride, .Flame},
}

EVENTS := [Event_Id]Event {
	.Goat_Incident = {
		prompt = "A goat has eaten the family map.",
		option_count = 3,
		options = {
			{
				text = "Blame the goat.",
				result = "The goat accepts the blame without comment.",
				delta = #partial {.Pride = 1, .Livestock = -1},
				grudge = .Goat,
			},
			{
				text = "Eat the goat.",
				result = "It was a large goat. Everyone is quiet afterward.",
				delta = #partial {.Snacks = 2, .Reputation = -1, .Livestock = -1},
			},
			{
				text = "Follow the goat.",
				result = "The goat leads you in a circle, which is somehow correct.",
				delta = #partial {.Flame = 1, .Snacks = -1},
				item = .Goat_Chewed_Map,
			},
		},
	},
	.Stranger_Offer = {
		prompt = "A stranger offers to hold your torch for a bit.",
		option_count = 3,
		options = {
			{
				text = "Let them.",
				result = "They hold it very seriously. It comes back slightly shorter.",
				delta = #partial {.Flame = -1, .Reputation = 1},
			},
			{
				text = "Refuse politely.",
				result = "You are polite. They are not impressed.",
				delta = #partial {.Pride = 1},
			},
			{
				text = "Hold theirs instead.",
				result = "Theirs is dimmer. You say nothing.",
				delta = #partial {.Flame = 1, .Pride = -1},
				grudge = .Stranger,
			},
		},
	},
	.Loud_Neighbors = {
		prompt = "The neighbors are being loud again.",
		option_count = 3,
		options = {
			{
				text = "Complain.",
				result = "You complain with great skill. It does not help.",
				delta = #partial {.Reputation = -1},
				grudge = .Neighbors,
			},
			{
				text = "Join them.",
				result = "You are loud now too.",
				delta = #partial {.Snacks = 1, .Reputation = 1, .Flame = -1},
			},
			{
				text = "Move the fence.",
				result = "The fence is now further away, if not moved.",
				delta = #partial {.Livestock = 1, .Reputation = -1},
			},
		},
	},
	.Rain = {
		prompt = "It begins to rain on the torch.",
		option_count = 3,
		options = {
			{
				text = "Shelter it with your hat.",
				result = "The hat is ruined. The torch is smug.",
				delta = #partial {.Flame = 1, .Pride = -1},
				item = .Soggy_Hat,
			},
			{
				text = "Pray at the rain.",
				result = "The rain notes your concern.",
				delta = #partial {.Reputation = 1, .Flame = -1},
			},
			{
				text = "Complain at the sky.",
				result = "The sky does not respond. You hold this against it.",
				delta = #partial {.Pride = 1},
				grudge = .Sky,
			},
		},
	},
	.Feast = {
		prompt = "A feast is held in your honor. You are not sure what you did.",
		option_count = 3,
		options = {
			{
				text = "Attend.",
				result = "You eat for two. The torch is neglected.",
				delta = #partial {.Snacks = 2, .Pride = 1, .Flame = -1},
			},
			{
				text = "Skip it.",
				result = "You stay home with the torch. Word gets around.",
				delta = #partial {.Reputation = -1, .Flame = 1},
			},
			{
				text = "Cater it.",
				result = "You stand behind the ladle all night.",
				delta = #partial {.Snacks = -1, .Reputation = 2},
				item = .Ladle,
			},
		},
	},
}
