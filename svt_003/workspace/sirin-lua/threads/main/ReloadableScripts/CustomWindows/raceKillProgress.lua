local t = {
	[3] = {
		name = {
			default = "Race Hunt",
		},
		width = 750,
		height = 360,
		layout = {  50, 130, 130, 170, 110 },
		data = {
			-- Row 1
			{
				icon = { 8, 0, 26, 183 },
			},
			{ text = { default = "Race kills", }, },
			{ text = { default = "Your kills", }, },
			{ text = { default = "Место в рейтинге: —", }, },
			{ text = { default = "Claim reward", }, description = { default = "Requires race 10/10 and you 5/5", }, },
			-- Row 2
			{
				icon = { 8, 0, 26, 195 },
			},
			{ text = { default = "Race kills", }, },
			{ text = { default = "Your kills", }, },
			{ text = { default = "Место в рейтинге: —", }, },
			{ text = { default = "Claim reward", }, description = { default = "Requires race 10/10 and you 5/5", }, },
		},
	},
}

return t