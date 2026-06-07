--[[
	@name perf
	@author dullflowerr
	@time June 7, 2026
]]

local Perf = {}
Perf.__index = Perf

local function ms(value)
	return value >= 100 and string.format("%.0fms", value) or string.format("%.1fms", value)
end

local function compactSource(name)
	return name == "untracked-frame" and "untracked" or name
end

local function perfName(scope, action)
	return `{scope}.{action}`
end

function Perf.new(config, onSlowTrace)
	return setmetatable({
		config = config,
		onSlowTrace = onSlowTrace,
		window = {},
		sources = {},
		slowestMs = 0,
		slowestName = "none",
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
	local name = perfName(scope, action)
	local bucket = self.window[kind] or { count = 0, totalMs = 0, slowestMs = 0, slowestName = "none" }
	bucket.count += 1
	bucket.totalMs += elapsedMs
	if elapsedMs > bucket.slowestMs then
		bucket.slowestMs = elapsedMs
		bucket.slowestName = name
	end
	self.window[kind] = bucket

	local source = self.sources[name] or { count = 0, totalMs = 0, slowestMs = 0, kind = kind }
	source.count += 1
	source.totalMs += elapsedMs
	source.kind = kind
	if elapsedMs > source.slowestMs then
		source.slowestMs = elapsedMs
	end
	self.sources[name] = source

	if elapsedMs > self.slowestMs then
		self.slowestMs = elapsedMs
		self.slowestName = name
	end

	local now = os.clock()
	if elapsedMs >= self.config.slowTraceMs and now - self.lastSlowTraceAt >= self.config.slowTraceCooldown then
		self.lastSlowTraceAt = now
		if self.onSlowTrace then
			self.onSlowTrace(kind, scope, action, elapsedMs, fields)
		end
	end
end

function Perf:summary()
	local ray = self.window.raycast
	local sphere = self.window.spherecast
	local block = self.window.blockcast
	local manual = self.window.manual
	local casts = (ray and ray.count or 0) + (sphere and sphere.count or 0) + (block and block.count or 0)
	local spikeActive = self.lastSpikeMs > 0 and os.clock() - self.lastSpikeAt <= self.config.spikeHoldSeconds

	return {
		casts = casts,
		ray = ray and ray.count or 0,
		sphere = sphere and sphere.count or 0,
		block = block and block.count or 0,
		manual = manual and manual.count or 0,
		max = self.slowestMs > 0 and `{compactSource(self.slowestName)}:{ms(self.slowestMs)}` or "-",
		spike = spikeActive and ms(self.lastSpikeMs) or "-",
		spikeActive = spikeActive,
	}
end

function Perf:causeSummary(frameMs)
	local topName = "none"
	local topTotal = 0
	local topCount = 0
	local trackedTotal = 0
	local slowName = self.slowestName
	local slowMs = self.slowestMs

	for name, source in self.sources do
		trackedTotal += source.totalMs
		if source.totalMs > topTotal then
			topName = name
			topTotal = source.totalMs
			topCount = source.count
		end
	end

	local spikeActive = self.lastSpikeMs > 0 and os.clock() - self.lastSpikeAt <= self.config.spikeHoldSeconds
	local activeFrameMs = math.max(frameMs or 0, spikeActive and self.lastSpikeMs or 0)
	local untrackedMs = math.max(0, activeFrameMs - trackedTotal)
	if activeFrameMs >= 28 and untrackedMs > math.max(trackedTotal, 4) then
		topName = "untracked-frame"
		topTotal = untrackedMs
		topCount = 1
		slowName = "untracked-frame"
		slowMs = untrackedMs
	elseif spikeActive and topName == "none" then
		topName = "untracked-frame"
		topTotal = self.lastSpikeMs
		topCount = 1
		slowName = "untracked-frame"
		slowMs = self.lastSpikeMs
	end

	return {
		top = compactSource(topName),
		total = topTotal > 0 and ms(topTotal) or "0ms",
		count = topCount,
		max = slowMs > 0 and `{compactSource(slowName)}:{ms(slowMs)}` or "-",
		spike = spikeActive and ms(self.lastSpikeMs) or "-",
		tracked = trackedTotal > 0 and ms(trackedTotal) or "0ms",
		spikeActive = spikeActive,
	}
end

function Perf:resetWindow()
	table.clear(self.window)
	table.clear(self.sources)
	self.slowestMs = 0
	self.slowestName = "none"
end

function Perf:reset()
	self:resetWindow()
	self.lastSpikeMs = 0
	self.lastSpikeAt = 0
	self.lastSlowTraceAt = 0
end

return Perf
