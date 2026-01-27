local PlayerState = {}

local stateByPlayer = {}

local defaultPPS = 10

local function createState()
	return {
		Biomass = 0,
		PPS = defaultPPS,
		Plot = nil,
		OwnedUpgrades = {},
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
	if state.PPS == 0 then
		state.PPS = defaultPPS
	end
end

function PlayerState.ReleasePlot(player)
	local state = stateByPlayer[player]
	if state then
		state.Plot = nil
		state.PPS = 0
	end
end

function PlayerState.Remove(player)
	stateByPlayer[player] = nil
end

function PlayerState.GetAll()
	return stateByPlayer
end

PlayerState.DEFAULT_PPS = defaultPPS

return PlayerState
