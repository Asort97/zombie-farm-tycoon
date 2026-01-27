local PlayerState = {}

local stateByPlayer = {}

local DEFAULT_INFRA_PPS = 10
local DEFAULT_MULTIPLIER = 1

local function calculateZombiesPPS(state)
	local sum = 0
	for _, zombie in ipairs(state.Zombies) do
		sum += zombie.pps or 0
	end
	state.ZombiesPPS = sum
end

local function createState()
	return {
		Biomass = 0,
		InfraPPS = DEFAULT_INFRA_PPS,
		Zombies = {},
		ZombiesPPS = 0,
		Multiplier = DEFAULT_MULTIPLIER,
		OwnedUpgrades = {},
		Plot = nil,
		lastSeen = 0,
	}
end

function PlayerState.Get(player)
	return stateByPlayer[player]
end

function PlayerState.GetOrCreate(player)
	local state = stateByPlayer[player]
	if not state then
		state = createState()
		stateByPlayer[player] = state
	end
	return state
end

function PlayerState.AssignPlot(player, plot)
	local state = PlayerState.GetOrCreate(player)
	state.Plot = plot
	if state.InfraPPS == 0 then
		state.InfraPPS = DEFAULT_INFRA_PPS
	end
end

function PlayerState.ReleasePlot(player)
	local state = stateByPlayer[player]
	if state then
		state.Plot = nil
	end
end

function PlayerState.RebuildZombies(player, zombies)
	local state = PlayerState.GetOrCreate(player)
	state.Zombies = zombies or {}
	calculateZombiesPPS(state)
end

function PlayerState.AddZombie(player, zombie)
	local state = PlayerState.GetOrCreate(player)
	table.insert(state.Zombies, zombie)
	calculateZombiesPPS(state)
end

function PlayerState.GetTotalPPS(playerOrState)
	local state = type(playerOrState) == "table" and playerOrState or PlayerState.Get(playerOrState)
	if not state then
		return 0
	end
	local infra = state.InfraPPS or DEFAULT_INFRA_PPS
	local zombies = state.ZombiesPPS or 0
	local multiplier = state.Multiplier or DEFAULT_MULTIPLIER
	return (infra + zombies) * multiplier
end

function PlayerState.GetAll()
	return stateByPlayer
end

function PlayerState.Clear(player)
	stateByPlayer[player] = nil
end

PlayerState.DEFAULT_INFRA_PPS = DEFAULT_INFRA_PPS
PlayerState.DEFAULT_MULTIPLIER = DEFAULT_MULTIPLIER

return PlayerState
