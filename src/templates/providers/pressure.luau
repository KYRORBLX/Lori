--[[
	@name pressure
	@author dullflowerr
	@time June 7, 2026
]]

local imports = {
	RunService = game:GetService("RunService"),
}

local Pressure = {}
Pressure.__index = Pressure

function Pressure.new(row)
	return setmetatable({
		id = "runtime.perf",
		connection = nil,
		client = nil,
		lastPerf = 0,
		row = row,
	}, Pressure)
end

function Pressure:start(client)
	if self.connection then
		return
	end

	self.client = client
	client:push({
		key = self.id,
		sticky = true,
		pinned = true,
		order = self.row,
		fields = { peak = "-", why = "-", t = "0ms", own = "0ms", cast = 0 },
		scope = "runtime.perf",
		action = "pressure",
		tone = "phase",
	})

	self.connection = imports.RunService.RenderStepped:Connect(function()
		local now = os.clock()
		if now - self.lastPerf < client.config.monitorInterval then
			return
		end

		self.lastPerf = now

		local summary = client.perf:summary()
		local cause = client.perf:causeSummary(client.monitor.frameMs)

		client:push({
			key = self.id,
			sticky = true,
			pinned = true,
			order = self.row,
			fields = {
				cast = summary.casts,
				own = cause.tracked,
				peak = summary.max,
				why = cause.top,
				t = cause.total,
			},

			action = "pressure",
			scope = "runtime.perf",
			tone = if cause.spikeActive
				then "error"
				elseif client.monitor.frameMs >= 28 or client.monitor.heartbeatMs >= 28 then "warn"
				else "phase",
		})

		client.perf:resetWindow()
	end)
end

function Pressure:stop()
	if self.connection then
		self.connection:Disconnect()
	end

	if self.client then
		self.client:dismiss(self.id)
	end

	self.connection = nil
	self.client = nil
	self.lastPerf = 0
end

return Pressure
