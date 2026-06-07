--[[
	@name memgraph
	@author dullflowerr
	@time June 7, 2026
]]

local imports = {
	RunService = game:GetService("RunService"),
	Stats = game:GetService("Stats"),
}

local MemGraph = {}
MemGraph.__index = MemGraph

local function totalMemory()
	local ok, value = pcall(function()
		return imports.Stats:GetTotalMemoryUsageMb()
	end)

	return ok and value or 0
end

function MemGraph.new()
	return setmetatable({
		id = "runtime.memgraph",
		connection = nil,
		client = nil,
		lastSample = 0,
	}, MemGraph)
end

function MemGraph:start(client)
	if self.connection then
		return
	end

	self.client = client
	client.render:makeGraph("mem", {
		tone = "phase",
		style = "bars",
		unit = "mb",
	})

	self.connection = imports.RunService.RenderStepped:Connect(function()
		local now = os.clock()
		if now - self.lastSample < client.config.monitorInterval then
			return
		end

		self.lastSample = now
		client.render:pushGraph("mem", totalMemory())
	end)
end

function MemGraph:stop()
	if self.connection then
		self.connection:Disconnect()
	end

	if self.client then
		self.client.render:removeGraph("mem")
	end

	self.connection = nil
	self.client = nil
	self.lastSample = 0
end

return MemGraph
