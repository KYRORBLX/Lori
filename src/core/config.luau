--[[
	@name config
	@author dullflowerr
	@time June 7, 2026
]]

local Config = {}

Config.theme = table.freeze({
	trace = Color3.fromRGB(135, 203, 255),
	phase = Color3.fromRGB(181, 146, 255),
	success = Color3.fromRGB(94, 232, 141),
	warn = Color3.fromRGB(255, 203, 107),
	error = Color3.fromRGB(255, 104, 120),

	key = Color3.fromRGB(116, 204, 255),
	value = Color3.fromRGB(255, 213, 126),
	muted = Color3.fromRGB(148, 156, 166),

	text = Color3.fromRGB(235, 239, 245),
	background = Color3.fromRGB(0, 0, 0),
})

Config.groups = {
	runtime = {
		enabled = true,
		studioOnly = true,
		template = nil,
		theme = nil,
	},

	ui = {
		rightOffset = 12,
		leftOffset = 12,
		bottomOffset = 5,
		anchor = "tr", -- tr/tl/br/bl, also supports topRight, top-right, bottomLeft, bottom-left, etc.
		topOffset = 52,
		maxWidth = 0,
		minWidth = 118,
		rowHeight = 17,
		gap = 5,
		padX = 7,
		cornerRadius = 0.3,
		textSize = 10,
		displayOrder = 118,
		font = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
		measureFont = Enum.Font.RobotoMono,
	},

	scale = {
		uiScale = true,
		scaleBaseWidth = 1280,
		minScale = 0.9,
		maxScale = 1.12,
	},

	rows = {
		maxItems = 30,
		liveInterval = 0.5,
		copyEnabled = true,
		progressSegmentWidth = 10,
	},

	motion = {
		motionTime = 0.46,
		exitTime = 0.66,
		fadeTime = 0.22,
		motionStyle = Enum.EasingStyle.Quint,
	},

	graphs = {
		graphWidth = 220,
		graphHeight = 30,
		graphColumns = 40,
		graphTweenTime = 0.18,
	},

	monitor = {
		monitorEnabled = true,
		interval = 0.1,
		minInterval = 0.04,
		spikeMs = 85,
		spikeHoldSeconds = 6,
		slowTraceMs = 8,
		slowTraceCooldown = 4,
	},
}

local function flatten(groups)
	local flat = {}
	for _, group in groups do
		for key, value in group do
			flat[key] = value
		end
	end

	return flat
end

Config.default = flatten(Config.groups)

local function clampDelay(value, fallback, minimum)
	local delay = tonumber(value) or tonumber(fallback) or 0
	return math.max(tonumber(minimum) or 0, delay)
end

Config.delay = clampDelay

function Config.applyAliases(config)
	if typeof(config.position) == "Vector2" then
		config.rightOffset = config.position.X
		config.topOffset = config.position.Y
	end

	if type(config.leftOffset) ~= "number" then
		config.leftOffset = config.rightOffset
	end

	if type(config.bottomOffset) ~= "number" then
		config.bottomOffset = config.gap
	end

	if type(config.anchor) == "string" then
		config.anchor = string.lower(config.anchor)
	end

	if type(config.width) == "number" then
		config.maxWidth = config.width
	end

	if type(config.fontSize) == "number" then
		config.textSize = config.fontSize
	end

	if type(config.monitorInterval) == "number" then
		config.interval = config.monitorInterval
	end

	config.minInterval = clampDelay(config.minInterval, 0.04, 0)
	config.interval = clampDelay(config.interval, 0.1, config.minInterval)
	config.liveInterval = clampDelay(config.liveInterval, config.interval, config.minInterval)
	config.monitorInterval = config.interval
end

function Config.merge(options)
	local config = table.clone(Config.default)
	if type(options) == "table" then
		for key, value in options do
			config[key] = value
		end
	end

	Config.applyAliases(config)
	return config
end

function Config.mergeTheme(theme)
	local merged = table.clone(Config.theme)
	if type(theme) == "table" then
		for key, value in theme do
			merged[key] = value
		end
	end

	return merged
end

return Config
