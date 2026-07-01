--[[
	@name perf
	@author dullflowerr
	@time June 7, 2026
]]

local Perf = {}
Perf.__index = Perf

function Perf.new(config, onSlowTrace)
	return setmetatable({
		config = config,
		onSlowTrace = onSlowTrace,
		lastSpikeMs = 0,
		lastSpikeAt = 0,
		lastSlowTraceAt = 0,
	}, Perf)
end

function Perf:recordSpike(frameMs)
	if frameMs >= self.config.spikeMs then
		self.lastSpikeMs = frameMs
		self.lastSpikeAt = os.clock()
	end
end

function Perf:add(kind, scope, action, elapsedMs, fields)
	local now = os.clock()
	if elapsedMs >= self.config.slowTraceMs and now - self.lastSlowTraceAt >= self.config.slowTraceCooldown then
		self.lastSlowTraceAt = now
		if self.onSlowTrace then
			self.onSlowTrace(kind, scope, action, elapsedMs, fields)
		end
	end
end

function Perf:reset()
	self.lastSpikeMs = 0
	self.lastSpikeAt = 0
	self.lastSlowTraceAt = 0
end

return Perf
