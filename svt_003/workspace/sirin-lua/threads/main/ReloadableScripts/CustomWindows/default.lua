local t = {
	[1] = { -- [1] window with index 1 is always function window
		name = {
			default = "Function window",
		},
		-- 12 entiries - requires 12 state flags
		data = {
			{
				icon = { 4, 13, 4, 0 },
				clientWindow = 1, -- CHAR INFO
			},
			{
				icon = { 4, 13, 12, 0 },
				clientWindow = 2, -- INVENTORY
			},
			{
				icon = { 4, 13, 5, 0 },
				clientWindow = 3, -- SKILL
			},
			{
				icon = { 4, 13, 6, 0 },
				clientWindow = 4, -- FORCE
			},
			{
				icon = { 4, 13, 7, 0 },
				raceLimit = { 1 },
				clientWindow = 5, -- SUMMON (CORA ONLY)
			},
			{
				icon = { 4, 13, 11, 0 },
				clientWindow = 6, -- MACRO
			},
			{
				icon = { 4, 13, 8, 0 },
				clientWindow = 7, -- PARTY
			},
			{
				icon = { 4, 13, 9, 0 },
				clientWindow = 8, -- GUILD
			},
			{
				icon = { 4, 13, 13, 0 },
				clientWindow = 9, -- MAIL
			},
			{
				icon = { 4, 13, 14, 0 },
				clientWindow = 10, -- REP BELLATO
				raceLimit = { 0 },
				raceBoss = { 0, 1, 5 },
			},
			{
				icon = { 4, 13, 15, 0 },
				clientWindow = 10, -- REP CORA
				raceLimit = { 1 },
				raceBoss = { 0, 1, 5 },
			},
			{
				icon = { 4, 13, 16, 0 },
				clientWindow = 10, -- REP ACCRETIA
				raceLimit = { 2 },
				raceBoss = { 0, 1, 5 },
			},
			{
				icon = { 4, 13, 10, 0 },
				clientWindow = 12, -- QUEST JOURNAL
			},
			{
				icon = { 8, 0, 7, 1 },
				clientWindow = 49, -- REMAIN ORE
			},
			{
				icon = { 4, 13, 3, 0 },
				customWindow = 2, -- demo window
				isGM = true
			},
			{
				icon = { 4, 13, 19, 0 },
				description = { default = "Race Hunt" },
				customWindow = 3,
			},
			-- New: Reload Center button (GM only)
			{
				icon = { 4, 13, 18, 0 },
				description = { default = "Reload Center" },
				customWindow = 10,
			},

		},
	},
}

return t