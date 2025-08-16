local t = {
	[3] = {
		name = {
			default = "Race Hunt",
		},
		width = 750,
		height = 360,
		layout = {  50, 130, 130, 170, 110 },
		data = {
			{
				icon = { 8, 0, 26, 183 },
				description = { -- Optional.
					default = "custom tooltip",
				},
				durability = 0, -- Optional.
				tooltip = { -- Optional.
					name = {
						text = {
							default = "Pseudo name",
							},
						color = 0xFF00FF00,
					},
					info = {
						default = {
							{ "Left 1", "Right 1" },
							{ "Left 2", "Right 2" },
							{ "Left 3", "Right 3" },
						},
					},
				},
			},
			{ text = { default = "Race kills", }, },
			{ text = { default = "Your kills", }, },
			{ text = { default = "Место в рейтинге: —", }, },
			{ text = { default = "Claim reward", }, description = { default = "Requires race 10/10 and you 5/5", }, },
		},
	},
}

return t