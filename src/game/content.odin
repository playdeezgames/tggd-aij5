// Content tables. Data only; the voice lives here. Placeholder-free as of milestone 3, but expect edits.
// These are variables (:=), not constants, because a constant array cannot be indexed by a runtime value.
package game

// An option is offered only while the counter is at least this much. Unavailable options are left out of the view.
Requirement :: struct {
	counter:  Counter,
	at_least: int,
}

Option :: struct {
	text:     string,
	result:   string,
	delta:    [Counter]int,
	item:     Maybe(Item_Id),
	grudge:   Maybe(Grudge_Id),
	requires: Maybe(Requirement),
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

// Drift vocabulary. An item's words come from two ladders: a shared status ladder (one rung per handoff, so the
// text changes every time) and its own noun ladder (one rung per two handoffs). Grudges work the same way, with an
// intensity ladder and a target ladder, and they lose their reason at REASON_LOST_STAGE.
DRIFT_STEPS :: MAX_GENERATIONS // rungs in the shared ladders: a handoff never lands on the same words
NOUN_RUNGS :: 4
REASON_LOST_STAGE :: 2

STATUS_LADDER := [DRIFT_STEPS]string {
	"a",
	"a handy",
	"a favorite",
	"a family",
	"a cherished",
	"a sacred",
	"a forbidden",
	"an unspeakable",
}

INTENSITY_LADDER := [DRIFT_STEPS]string {
	"a grudge",
	"a lasting grudge",
	"an old grudge",
	"a family grudge",
	"an ancestral feud",
	"a sacred feud",
	"a blood feud",
	"an unspeakable feud",
}

ITEM_NOUNS := [Item_Id][NOUN_RUNGS]string {
	.Goat_Chewed_Map = {"goat-chewed map", "map of the goat", "goat map", "goat"},
	.Soggy_Hat = {"soggy hat", "damp hat", "hat", "head"},
	.Ladle = {"ladle", "big spoon", "spoon", "stirring"},
	.Borrowed_Bucket = {"borrowed bucket", "lent bucket", "owed bucket", "obligation"},
	.Heirloom_Cheese = {"family cheese", "old cheese", "cheese-adjacent object", "smell"},
	.Pocket_Sundial = {"pocket sundial", "pocket shadow", "shadow", "evening"},
	.Wedding_Boot = {"wedding boot", "lone boot", "boot story", "story"},
	.Rubber_Duck = {"rubber duck", "wise duck", "duck law", "the Duck"},
}

GRUDGE_TARGETS := [Grudge_Id][NOUN_RUNGS]string {
	.Goat = {"the goat", "goats", "the herd", "everyone with hooves"},
	.Stranger = {"the stranger", "strangers", "anyone with a torch", "torches"},
	.Neighbors = {"the neighbors", "the people next door", "the house next door", "the fence"},
	.Sky = {"the sky", "the weather", "up", "ceilings"},
	.Cousin = {"cousin Gil", "Gil's branch", "the other branch", "branches"},
	.Mayor = {"the mayor", "the mayor's office", "officials", "stamps"},
	.Bakery = {"the baker", "the bakery", "bread", "yeast"},
	.Heron = {"the heron", "herons", "tall birds", "knees"},
}

GRUDGE_REASONS := [Grudge_Id]string {
	.Goat = "eating the map",
	.Stranger = "being dimmer",
	.Neighbors = "the noise",
	.Sky = "the rain",
	.Cousin = "borrowing things",
	.Mayor = "the permit",
	.Bakery = "a short loaf",
	.Heron = "staring at the pond",
}

HEIRS := [Heir_Id]Heir {
	.Brindle = {"Brindle", "who talks to goats", .Livestock, .Reputation},
	.Odo = {"Odo", "who is very warm", .Flame, .Snacks},
	.Pim = {"Pim", "who remembers everything slightly wrong", .Reputation, .Pride},
	.Aunt_Vex = {"Aunt Vex", "who is not technically an heir", .Pride, .Flame},
	.Moss = {"Moss", "who has never been indoors", .Livestock, .Snacks},
	.Dame_Wren = {"Dame Wren", "who files complaints in advance", .Pride, .Reputation},
	.Tobin = {"Tobin", "who is mostly hat", .Reputation, .Livestock},
	.Little_Sorrel = {"Little Sorrel", "who is eleven and in charge", .Flame, .Pride},
	.Gus = {"Gus", "who owns the only chair", .Snacks, .Reputation},
	.Marigold = {"Marigold", "who is feared by geese", .Livestock, .Pride},
	.Third_Cousin = {"Third Cousin", "whose name nobody is sure of", .Snacks, .Livestock},
	.Hob = {"Hob", "who holds torches upside down", .Pride, .Snacks},
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
				requires = Requirement{.Livestock, 3},
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
				requires = Requirement{.Pride, 3},
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
				requires = Requirement{.Pride, 3},
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
				requires = Requirement{.Reputation, 3},
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
	.Bucket_Loan = {
		prompt = "A neighbor lends you a bucket and will not say for how long.",
		option_count = 3,
		options = {
			{
				text = "Accept the bucket.",
				result = "You now own a bucket in every sense but the legal one.",
				delta = #partial {.Livestock = 1, .Pride = -1},
				item = .Borrowed_Bucket,
			},
			{
				text = "Decline.",
				result = "The neighbor leaves it on your step anyway.",
				delta = #partial {.Reputation = -1, .Pride = 1},
			},
			{
				text = "Carry oil in it.",
				requires = Requirement{.Livestock, 3},
				result = "The oil is borrowed too. Nobody asks.",
				delta = #partial {.Flame = 1, .Reputation = -1},
			},
		},
	},
	.Cheese_Heirloom = {
		prompt = "Great-aunt's cheese is found. It is older than the torch.",
		option_count = 3,
		options = {
			{
				text = "Eat it.",
				result = "It fights back. You win, barely.",
				delta = #partial {.Snacks = 2, .Flame = -1},
			},
			{
				text = "Keep it.",
				result = "The cheese settles in with a sigh.",
				delta = #partial {.Reputation = 1},
				item = .Heirloom_Cheese,
			},
			{
				text = "Light it.",
				requires = Requirement{.Snacks, 3},
				result = "Cheese burns longer than expected. The room objects.",
				delta = #partial {.Flame = 1, .Reputation = -2},
			},
		},
	},
	.Sundial_Seller = {
		prompt = "A traveler sells you a sundial small enough to lose.",
		option_count = 3,
		options = {
			{
				text = "Buy it.",
				result = "It tells the time, and only that.",
				delta = #partial {.Snacks = -1, .Pride = 1},
				item = .Pocket_Sundial,
			},
			{
				text = "Haggle.",
				result = "You win. They keep the sundial. You keep the win.",
				delta = #partial {.Pride = 2, .Reputation = -1},
			},
			{
				text = "Read it by torchlight.",
				requires = Requirement{.Reputation, 3},
				result = "The torch is flattered by the attention.",
				delta = #partial {.Flame = 1, .Livestock = -1},
			},
		},
	},
	.Wedding = {
		prompt = "You are invited to a wedding. You are not sure whose.",
		option_count = 3,
		options = {
			{
				text = "Bring a gift.",
				result = "You are given a boot in return. Nobody explains.",
				delta = #partial {.Snacks = -1, .Reputation = 1},
				item = .Wedding_Boot,
			},
			{
				text = "Catch the bouquet.",
				requires = Requirement{.Pride, 3},
				result = "It was a torch. You are holding two torches now.",
				delta = #partial {.Flame = 1, .Pride = -1},
			},
			{
				text = "Leave early.",
				result = "You are remembered as the one who left.",
				delta = #partial {.Reputation = -1, .Snacks = 1},
			},
		},
	},
	.Duck = {
		prompt = "A rubber duck washes up and appears to have opinions.",
		option_count = 3,
		options = {
			{
				text = "Consult the duck.",
				result = "The duck says yes. To what is unclear.",
				delta = #partial {.Pride = 1, .Reputation = -1},
				item = .Rubber_Duck,
			},
			{
				text = "Ignore it.",
				result = "The duck is patient.",
				delta = #partial {.Pride = -1, .Snacks = 1},
			},
			{
				text = "Warm it by the torch.",
				requires = Requirement{.Livestock, 3},
				result = "The duck glows with approval. Then it melts a little.",
				delta = #partial {.Flame = 1, .Livestock = -1},
			},
		},
	},
	.Cousin_Gil = {
		prompt = "Cousin Gil asks to borrow the torch for a minute.",
		option_count = 3,
		options = {
			{
				text = "Refuse.",
				result = "Gil takes it personally. Gil takes everything personally.",
				delta = #partial {.Pride = 1, .Reputation = -1},
				grudge = .Cousin,
			},
			{
				text = "Lend a lit stick.",
				result = "Gil does not notice. You notice for him.",
				delta = #partial {.Pride = 1, .Snacks = -1},
			},
			{
				text = "Go along with Gil.",
				requires = Requirement{.Reputation, 3},
				result = "You walk behind the torch for once.",
				delta = #partial {.Flame = 1, .Livestock = -1},
			},
		},
	},
	.Permit = {
		prompt = "The mayor requires a permit to be on fire.",
		option_count = 3,
		options = {
			{
				text = "Apply.",
				result = "The form is longer than the torch.",
				delta = #partial {.Snacks = -1, .Reputation = 1},
			},
			{
				text = "Burn the form.",
				result = "The form burns well. The mayor is informed.",
				delta = #partial {.Flame = 1, .Reputation = -1},
				grudge = .Mayor,
			},
			{
				text = "Bribe with cheese.",
				result = "The mayor accepts. The cheese is never mentioned again.",
				delta = #partial {.Snacks = -2, .Reputation = 2},
				requires = Requirement{.Snacks, 2},
			},
		},
	},
	.Baker = {
		prompt = "The baker is out of bread and wants to talk about it.",
		option_count = 3,
		options = {
			{
				text = "Listen.",
				result = "You listen for a long time. The torch dims out of respect.",
				delta = #partial {.Flame = -1, .Reputation = 1},
			},
			{
				text = "Buy a short loaf.",
				result = "It is short. You paid full price.",
				delta = #partial {.Snacks = 1, .Pride = -1},
				grudge = .Bakery,
			},
			{
				text = "Bake your own.",
				result = "You bake. The torch helps. Nobody asked it to.",
				delta = #partial {.Flame = 1, .Snacks = 1, .Livestock = -2},
				requires = Requirement{.Livestock, 3},
			},
		},
	},
	.Heron = {
		prompt = "A heron stands in your pond and will not explain.",
		option_count = 3,
		options = {
			{
				text = "Stare back.",
				result = "You win. The heron seems fine about it.",
				delta = #partial {.Pride = 1, .Flame = -1},
			},
			{
				text = "Shoo it.",
				result = "It leaves. It will remember.",
				delta = #partial {.Livestock = 1},
				grudge = .Heron,
			},
			{
				text = "Warm it by the torch.",
				requires = Requirement{.Livestock, 3},
				result = "The heron approves. The pond does not.",
				delta = #partial {.Flame = 1, .Livestock = -1},
			},
		},
	},
	.Fence = {
		prompt = "The fence has moved again. It claims it has not.",
		option_count = 3,
		options = {
			{
				text = "Move it back.",
				result = "The fence goes back. It goes back resentfully.",
				delta = #partial {.Pride = 1, .Snacks = -1},
			},
			{
				text = "Move the house.",
				result = "The house seems to want this.",
				delta = #partial {.Reputation = 2, .Livestock = -1},
				requires = Requirement{.Pride, 2},
			},
			{
				text = "Light the fence.",
				result = "The fence admits nothing but burns well.",
				delta = #partial {.Flame = 1, .Livestock = -1},
			},
		},
	},
	.Choir = {
		prompt = "A choir arrives. They know the words to your funeral.",
		option_count = 3,
		options = {
			{
				text = "Request an encore.",
				result = "They oblige. It is longer this time.",
				delta = #partial {.Reputation = 1, .Snacks = -1},
			},
			{
				text = "Join in.",
				result = "You are better than you expected, which is worse.",
				delta = #partial {.Pride = 1, .Flame = -1},
			},
			{
				text = "Hold the torch up.",
				requires = Requirement{.Pride, 3},
				result = "The choir weeps. The torch takes the credit.",
				delta = #partial {.Flame = 1, .Pride = -1},
			},
		},
	},
	.Tax_Man = {
		prompt = "A man arrives to tax the torch. He is polite about it.",
		option_count = 3,
		options = {
			{
				text = "Pay.",
				result = "The torch is now official.",
				delta = #partial {.Snacks = -2, .Reputation = 1},
			},
			{
				text = "Argue.",
				result = "You argue well. He agrees. He taxes you anyway.",
				delta = #partial {.Pride = 1, .Reputation = -1},
				grudge = .Mayor,
			},
			{
				text = "Tax him back.",
				result = "Nobody has tried this before. It works for an afternoon.",
				delta = #partial {.Flame = 1, .Snacks = -1},
				requires = Requirement{.Reputation, 3},
			},
		},
	},
	.Moths = {
		prompt = "Moths gather. They treat the torch as a personal matter.",
		option_count = 3,
		options = {
			{
				text = "Share the flame.",
				result = "The moths are grateful and also fatally so.",
				delta = #partial {.Flame = -1, .Reputation = 1},
			},
			{
				text = "Swat them.",
				result = "The moths take it as a compliment.",
				delta = #partial {.Pride = 1},
			},
			{
				text = "Hire a moth.",
				requires = Requirement{.Snacks, 3},
				result = "The moth is good at it. The moth is bad at it.",
				delta = #partial {.Flame = 1, .Snacks = -1},
			},
		},
	},
	.Bridge = {
		prompt = "The bridge is out. The river is also out, in a way.",
		option_count = 3,
		options = {
			{
				text = "Wade across.",
				result = "You arrive wet and correct.",
				delta = #partial {.Flame = -1, .Snacks = 1},
			},
			{
				text = "Bridge it with goats.",
				result = "The goats are unsurprised.",
				delta = #partial {.Livestock = -1, .Reputation = 2},
				requires = Requirement{.Livestock, 2},
			},
			{
				text = "Wait by the torch.",
				result = "The river returns. It was never gone.",
				delta = #partial {.Flame = 1, .Snacks = -1},
			},
		},
	},
	.Rumor = {
		prompt = "Someone says you were seen not carrying the torch.",
		option_count = 3,
		options = {
			{
				text = "Deny it.",
				result = "You deny it with a lot of detail.",
				delta = #partial {.Pride = 1, .Reputation = -1},
			},
			{
				text = "Carry it harder.",
				result = "People ask you to stop. You do not.",
				delta = #partial {.Flame = 1, .Reputation = -1},
			},
			{
				text = "Spread a better rumor.",
				result = "Yours has a goat in it. It spreads.",
				delta = #partial {.Reputation = 2, .Snacks = -1},
				requires = Requirement{.Reputation, 2},
			},
		},
	},
	.Snack_Cart = {
		prompt = "A snack cart rolls past unattended.",
		option_count = 3,
		options = {
			{
				text = "Take a snack.",
				result = "The cart does not mind. You mind a little.",
				delta = #partial {.Snacks = 2, .Reputation = -1},
			},
			{
				text = "Leave a note.",
				result = "The note is read by a goat.",
				delta = #partial {.Reputation = 1},
			},
			{
				text = "Ask the cart.",
				requires = Requirement{.Snacks, 3},
				result = "It says to follow the torch. Good cart.",
				delta = #partial {.Flame = 1, .Snacks = -1},
			},
		},
	},
	.Echo = {
		prompt = "The cave echoes your name wrong.",
		option_count = 3,
		options = {
			{
				text = "Correct it.",
				result = "The echo corrects you back. This goes on.",
				delta = #partial {.Pride = 1, .Flame = -1},
			},
			{
				text = "Accept the new name.",
				result = "You answer to it by dinner.",
				delta = #partial {.Reputation = 1, .Pride = -1},
			},
			{
				text = "Shout something useful.",
				requires = Requirement{.Reputation, 3},
				result = "Everyone hears it, including the cave.",
				delta = #partial {.Flame = 1, .Reputation = -1},
			},
		},
	},
	.Stone = {
		prompt = "A stone insists it has always been here. It has not.",
		option_count = 3,
		options = {
			{
				text = "Believe it.",
				result = "The stone is very pleased.",
				delta = #partial {.Reputation = 1, .Pride = -1},
			},
			{
				text = "Move it.",
				result = "It resists, then does not. It was a stone.",
				delta = #partial {.Livestock = -1, .Pride = 1},
			},
			{
				text = "Set the torch on it.",
				requires = Requirement{.Snacks, 3},
				result = "The stone is warm. The torch is quiet.",
				delta = #partial {.Flame = 1, .Snacks = -1},
			},
		},
	},
	.Bell = {
		prompt = "A bell rings. No one rings it. Everyone looks at you.",
		option_count = 3,
		options = {
			{
				text = "Ring it back.",
				result = "The bell has nothing to add.",
				delta = #partial {.Reputation = 1, .Snacks = -1},
			},
			{
				text = "Say you did it.",
				result = "They believe you. You are now responsible.",
				delta = #partial {.Pride = 1, .Reputation = -1},
			},
			{
				text = "Take a bow.",
				requires = Requirement{.Pride, 3},
				result = "They clap. The torch brightens at the noise.",
				delta = #partial {.Flame = 1, .Pride = -1},
			},
		},
	},
	.Hill = {
		prompt = "There is a hill. The torch seems to want you to climb it.",
		option_count = 3,
		options = {
			{
				text = "Climb it.",
				result = "The view is mostly more hill. The torch is thrilled.",
				delta = #partial {.Flame = 1, .Snacks = -2},
				requires = Requirement{.Snacks, 2},
			},
			{
				text = "Go around.",
				result = "The hill pretends not to notice.",
				delta = #partial {.Pride = -1, .Livestock = 1},
			},
			{
				text = "Send a goat.",
				result = "The goat reports back, in its way.",
				delta = #partial {.Livestock = -1, .Reputation = 1},
			},
		},
	},
}

// Options for the visits from relatives. Option 0 takes the old thing back (see choose_legacy_option). The prompts
// are built from the record in screens.odin.
LEGACY_OPTIONS := [Legacy_Kind][3]Option {
	.Normal = {},
	.Grudge = {
		{text = "Take up the grudge.", result = "It fits like it was always yours.", delta = #partial {.Pride = 1, .Reputation = -1}},
		{text = "Ask what it was about.", result = "Nobody knows. It is a pleasant evening.", delta = #partial {.Snacks = 1}},
		{text = "Change the subject.", result = "You change it to goats. It works.", delta = #partial {.Flame = 1, .Reputation = -1}},
	},
	.Item = {
		{text = "Take it.", result = "It has been waiting. It is not sentimental about it.", delta = #partial {.Reputation = 1, .Pride = -1}},
		{text = "Sell it.", result = "It fetches more than it should.", delta = #partial {.Snacks = 2, .Pride = -1}},
		{text = "Hold it to the torch.", result = "The torch is interested. The item is less so.", delta = #partial {.Flame = 1, .Livestock = -1}},
	},
}

// Urizen 1-bit tile (column, row) for each face. Tiles are 12 px with a 1 px gap and a 1 px offset; the page draws
// them. Each row of the people section is one colour, each column one figure.
NO_TILE :: [2]int{-1, -1}
FOUNDER_TILE :: [2]int{105, 0}

HEIR_TILES := [Heir_Id][2]int {
	.Brindle      = {109, 4},
	.Odo          = {106, 5},
	.Pim          = {118, 11},
	.Aunt_Vex     = {117, 17},
	.Moss         = {108, 8},
	.Dame_Wren    = {120, 6},
	.Tobin        = {124, 10},
	.Little_Sorrel = {104, 7},
	.Gus          = {113, 15},
	.Marigold     = {111, 14},
	.Third_Cousin = {122, 2},
	.Hob          = {126, 18},
}
