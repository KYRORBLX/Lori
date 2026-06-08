--[[
	@name fpsgraph
	@author dullflowerr
	@time June 7, 2026
]]

local imports = {
	RunService = game:GetService("RunService"),
}

local FpsGraph = {}
FpsGraph.__index = FpsGraph

function FpsGraph.new()
	return setmetatable({
		id = "runtime.fpsgraph",
		connection = nil,
		client = nil,
		lastSample = 0,
		fps = 60,
	}, FpsGraph)
end

function FpsGraph:start(client)
	if self.connection then
		return
	end

	self.client = client
	client.render:makeGraph("fps", {
		tone = "success",
		unit = "fps",
		style = "bars",
		warnBelow = 45,
		failBelow = 30,
	})

	self.connection = imports.RunService.RenderStepped:Connect(function(deltaTime)
		self.fps += (1 / math.max(deltaTime, 1e-4) - self.fps) * 0.1

		local now = os.clock()
		if now - self.lastSample < client.config.monitorInterval then
			return
		end

		self.lastSample = now
		client.render:pushGraph("fps", self.fps)
	end)
end

function FpsGraph:stop()
	if self.connection then
		self.connection:Disconnect()
	end

	if self.client then
		self.client.render:removeGraph("fps")
	end

	self.connection = nil
	self.client = nil
	self.lastSample = 0
	self.fps = 60
end

return FpsGraph
