local UpgradesConfig = {
	{
		id = "upgrade1",
		price = 25,
		addPps = 1,
		addMult = 1,
		requires = {},
	},
	{
		id = "upgrade2",
		price = 50,
		addPps = 1,
		addMult = 1,
		requires = { "upgrade1" },
	},
	{
		id = "upgrade3",
		price = 100,
		addPps = 2,
		addMult = 1,
		requires = { "upgrade2" },
	},
	{
		id = "upgrade4",
		price = 150,
		addPps = 3,
		addMult = 1,
		requires = { "upgrade3" },
	},
	{
		id = "upgrade5",
		price = 300,
		addPps = 5,
		addMult = 1,
		requires = { "upgrade4" },
	},
}

return UpgradesConfig
