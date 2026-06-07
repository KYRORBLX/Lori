--[[
	@name pinggraph
	@author dullflowerr
	@time June 7, 2026
]]

local imports = {
	Players = game:GetService("Players"),
	RunService = game:GetService("RunService"),
}

local PingGraph = {}
PingGraph.__index = PingGraph

local function pingMs()
	local player = imports.Players.LocalPlayer
	if not player then
		return 0
	end

	local ok, value = pcall(function()
		return player:GetNetworkPing()
	end)

	return ok and (tonumber(value) or 0) * 1000 or 0
end

function PingGraph.new()
	return setmetatable({
		id = "runtime.pinggraph",
		connection = nil,
		client = nil,
		lastSample = 0,
	}, PingGraph)
end

function PingGraph:start(client)
	if self.connection then
		return
	end

	self.client = client
	client.render:makeGraph("ping", {
		tone = "warn",
		style = "bars",
		unit = "ms",
		warnAt = 120,
		failAt = 220,
	})

	self.connection = imports.RunService.RenderStepped:Connect(function()
		local now = os.clock()
		if now - self.lastSample < client.config.monitorInterval then
			return
		end

		self.lastSample = now
		client.render:pushGraph("ping", pingMs())
	end)
end

function PingGraph:stop()
	if self.connection then
		self.connection:Disconnect()
	end

	if self.client then
		self.client.render:removeGraph("ping")
	end

	self.connection = nil
	self.client = nil
	self.lastSample = 0
end

return PingGraph
