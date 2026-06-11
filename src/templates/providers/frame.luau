--[[
	@name frame
	@author dullflowerr
	@time June 7, 2026
]]

local imports = {
	RunService = game:GetService("RunService"),
}

local Frame = {}
Frame.__index = Frame

function Frame.new(row)
	return setmetatable({
		id = "runtime.frame",
		row = row,
		renderConnection = nil,
		heartbeatConnection = nil,
		client = nil,
		accum = 0,
		framesSeen = 0,
		heartbeatAccum = 0,
		heartbeatFrames = 0,
	}, Frame)
end

function Frame:start(client)
	if self.renderConnection then
		return
	end

	self.client = client
	client:push({
		key = self.id,
		sticky = true,
		pinned = true,
		order = self.row,
		fields = { dt = "--", r = "--", hb = "--", sp = "--" },
		action = "core",
		scope = "runtime.frame",
		tone = "phase",
	})

	self.heartbeatConnection = imports.RunService.Heartbeat:Connect(function(deltaTime)
		self.heartbeatAccum += deltaTime
		self.heartbeatFrames += 1
	end)

	self.renderConnection = imports.RunService.RenderStepped:Connect(function(deltaTime)
		local frameMs = deltaTime * 1000
		client.perf:recordSpike(frameMs)

		self.accum += deltaTime
		self.framesSeen += 1

		if self.accum < client.config.monitorInterval then
			return
		end

		local fps = math.floor((self.framesSeen / self.accum) + 0.5)
		local avgFrameMs = self.accum / math.max(self.framesSeen, 1) * 1000
		client.monitor.frameMs = avgFrameMs

		if self.heartbeatAccum > 0 then
			client.monitor.heartbeatMs = self.heartbeatAccum / math.max(self.heartbeatFrames, 1) * 1000
			self.heartbeatFrames = 0
			self.heartbeatAccum = 0
		end

		local spikeActive = client.perf.lastSpikeMs > 0
			and os.clock() - client.perf.lastSpikeAt <= client.config.spikeHoldSeconds

		local tone = fps >= 55 and avgFrameMs < 19 and not spikeActive and "success"
			or (fps >= 40 and avgFrameMs < 28 and "warn" or "error")

		client:push({
			key = self.id,
			sticky = true,
			pinned = true,
			order = self.row,
			fields = {
				sp = spikeActive and string.format("%.1fms", client.perf.lastSpikeMs) or "-",
				hb = string.format("%.1fms", client.monitor.heartbeatMs),
				r = string.format("%.1fms", avgFrameMs),
				dt = string.format("%.1fms", frameMs),
			},

			scope = "runtime.frame",
			action = "core",
			tone = tone,
		})

		self.accum = 0
		self.framesSeen = 0
	end)
end

function Frame:stop()
	if self.renderConnection then
		self.renderConnection:Disconnect()
	end

	if self.heartbeatConnection then
		self.heartbeatConnection:Disconnect()
	end

	if self.client then
		self.client:dismiss(self.id)
	end

	self.renderConnection = nil
	self.heartbeatConnection = nil
	self.client = nil
	self.accum = 0
	self.framesSeen = 0
	self.heartbeatAccum = 0
	self.heartbeatFrames = 0
end

return Frame
