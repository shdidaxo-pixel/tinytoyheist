-- Every mutation: how likely it is, what it pays and what it looks like. Pure data (the review page reads it too);
-- Mutations.luau applies the looks. Rolled once at wake-up, one mutation per toy.
-- Chance is per wake-up (0.05 = 5%). Event mutations only roll while their event is on.
-- Candy, Bubble and Frozen were added on 19 Oct 2026 (the first 7 are from the Day 1 plan).
return {
	Order = { "Gold", "Candy", "Glitter", "Bubble", "Shadow", "Frozen", "Rainbow", "Cosmic", "Glow", "Haunted" },
	List = {
		Gold = {
			Name = "Gold",
			Chance = 0.05,
			Multiplier = 2,
			Color = "#FFC93C",
			Look = "Shiny gold all over, with little glints",
		},
		Candy = {
			Name = "Candy",
			Chance = 0.03,
			Multiplier = 2.5,
			Color = "#FF8FD0",
			Look = "Pink and white candy stripes, sprinkles falling off it",
		},
		Glitter = {
			Name = "Glitter",
			Chance = 0.02,
			Multiplier = 3,
			Color = "#FF9AF0",
			Look = "Its own colours, covered in twinkling sparkles",
		},
		Bubble = {
			Name = "Bubble",
			Chance = 0.015,
			Multiplier = 4,
			Color = "#9FE6FF",
			Look = "Floats inside a shimmering soap bubble, little bubbles rising",
		},
		Shadow = {
			Name = "Shadow",
			Chance = 0.01,
			Multiplier = 5,
			Color = "#7B3FC4",
			Look = "Turned almost black, with a purple outline and dark smoke",
		},
		Frozen = {
			Name = "Frozen",
			Chance = 0.005,
			Multiplier = 7,
			Color = "#9FE0FF",
			Look = "Solid ice, frosty sparkles and cold mist at its feet",
		},
		Rainbow = {
			Name = "Rainbow",
			Chance = 0.002,
			Multiplier = 10,
			Color = "#FF5FA8",
			Look = "Colours cycle through the rainbow, rainbow sparkles",
		},
		Cosmic = {
			Name = "Cosmic",
			Chance = 0.0002,
			Multiplier = 25,
			Color = "#6A2BB8",
			Look = "Deep-space colours with stars inside, sparkles orbiting it",
		},
		Glow = {
			Name = "Glow",
			Chance = 0.1,
			Event = "NightmareNight",
			Multiplier = 2.5,
			Color = "#8CFFA8",
			Look = "Glow-in-the-dark green, lights up the dark",
		},
		Haunted = {
			Name = "Haunted",
			Chance = 0.03,
			Event = "Halloween",
			Multiplier = 4,
			Color = "#BFF6FF",
			Look = "See-through ghostly blue, leaves a wispy trail",
		},
	},
}
