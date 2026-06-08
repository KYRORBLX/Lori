--[[
	@name default
	@author dullflowerr, driftingAurora
	@time June 7, 2026
]]

local imports = {
	FpsGraph = require("./providers/fpsgraph"),
	Frame = require("./providers/frame"),
	MemGraph = require("./providers/memgraph"),
	PingGraph = require("./providers/pinggraph"),
	Pressure = require("./providers/pressure"),
}

local providers = {
	{ name = "Frame", module = imports.Frame, row = 1 },
	{ name = "Pressure", module = imports.Pressure, row = 2 },
	{ name = "PingGraph", module = imports.PingGraph },
	{ name = "FpsGraph", module = imports.FpsGraph },
	{ name = "MemGraph", module = imports.MemGraph },
}

local function toSet(list)
	local set = {}
	if typeof(list) == "table" then
		for _, name in list do
			set[name] = true
		end
	end

	return set
end

return function(blacklistedItems)
	local blacklist = toSet(blacklistedItems)
	local activeProviders = {}

	for _, provider in providers do
		if not blacklist[provider.name] then
			table.insert(activeProviders, provider.module.new(provider.row))
		end
	end

	return {
		id = "performance",
		monitorRows = 2,
		providers = activeProviders,
	}
end
