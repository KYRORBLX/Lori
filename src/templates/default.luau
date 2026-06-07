--[[
	@name default
	@author dullflowerr
	@time June 7, 2026
]]

local imports = {
	FpsGraph = require("./providers/fpsgraph"),
	Frame = require("./providers/frame"),
	MemGraph = require("./providers/memgraph"),
	PingGraph = require("./providers/pinggraph"),
	Pressure = require("./providers/pressure"),
}

return function()
	return {
		id = "performance",
		monitorRows = 2,
		providers = {
			imports.Frame.new(1),
			imports.Pressure.new(2),
			imports.PingGraph.new(),
			imports.FpsGraph.new(),
			imports.MemGraph.new(),
		},
	}
end
