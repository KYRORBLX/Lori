--[[
	@name client
	@author dullflowerr
	@time June 7, 2026
]]

local imports = {
	RunService = game:GetService("RunService"),
	Workspace = game:GetService("Workspace"),

	Config = require("./config"),
	Format = require("../ui/format"),
	Perf = require("./perf"),
	Render = require("../ui/render"),
	Templates = require("../templates"),
}

local Client = {}
Client.__index = Client

local CLIENT_DOT_METHODS = {
	"isActive",
	"setTheme",
	"setTemplate",
	"mount",
	"unmount",
	"push",
	"dismiss",
	"begin",
	"finish",
	"record",
	"time",
	"measure",
	"watch",
	"graph",
	"inspect",
	"emit",
	"channel",
	"group",
	"raycast",
	"spherecast",
	"blockcast",
	"trace",
	"info",
	"phase",
	"success",
	"warn",
	"fail",
	"error",
	"clear",
	"destroy",
}

local function resolveTemplate(templateOption)
	if type(templateOption) == "function" then
		return templateOption()
	end
	if type(templateOption) == "table" then
		return templateOption
	end
	return imports.Templates.Empty()
end

local function applyConfig(config, options)
	if type(options) ~= "table" then
		return
	end

	for key, value in options do
		if key ~= "config" and key ~= "theme" and key ~= "template" then
			config[key] = value
		end
	end
	if type(options.config) == "table" then
		for key, value in options.config do
			config[key] = value
		end
	end

	if type(options.monitorInterval) == "number" and type(options.interval) ~= "number" then
		config.interval = options.monitorInterval
	end
	if
		type(options.config) == "table"
		and type(options.config.monitorInterval) == "number"
		and type(options.config.interval) ~= "number"
	then
		config.interval = options.config.monitorInterval
	end

	imports.Config.applyAliases(config)
end

local function configFromOptions(options)
	local configOptions = {}
	applyConfig(configOptions, options)
	return imports.Config.merge(configOptions)
end

local function normalizeEvent(event)
	if type(event) ~= "table" then
		return { tone = "trace", scope = "runtime", action = tostring(event or "event") }
	end
	return event
end

local function bindChannel(channel, method, scope)
	channel[method] = function(self, action, fields, duration)
		local channelSelf = if self == channel then self else channel
		local nextAction = if self == channel then action else self
		return channelSelf._client[method](channelSelf._client, scope, nextAction, fields, duration)
	end
end

local function bindDotMethods(object, source, methods)
	for _, method in methods do
		local callback = source[method]
		object[method] = function(self, ...)
			if self == object then
				return callback(object, ...)
			end
			return callback(object, self, ...)
		end
	end
end

function Client.new(options)
	options = options or {}

	local config = configFromOptions(options)
	local theme = imports.Config.mergeTheme(options.theme or config.theme)
	local template = resolveTemplate(options.template or config.template)
	local format = imports.Format.new(theme)

	local self = setmetatable({
		config = config,
		theme = theme,
		template = template,
		format = format,
		render = imports.Render.new(config, theme, format, template.monitorRows or 0),
		providers = template.providers or {},
		monitor = {
			frameMs = 0,
			heartbeatMs = 0,
		},
		perf = nil,
		mounted = false,
		channels = {},
		watches = {},
	}, Client)

	self.perf = imports.Perf.new(config, function(kind, scope, action, elapsedMs, fields)
		local reportFields = {
			scope = scope,
			action = action,
			ms = string.format("%.2f", elapsedMs),
			kind = kind,
		}
		if type(fields) == "table" then
			for key, value in fields do
				reportFields[key] = value
			end
		end
		self:warn("runtime.perf", "slow", reportFields, 4)
	end)

	bindDotMethods(self, Client, CLIENT_DOT_METHODS)

	return self
end

function Client:isActive()
	if not self.config.enabled then
		return false
	end
	return not self.config.studioOnly or imports.RunService:IsStudio()
end

function Client:setTheme(theme)
	self.theme = imports.Config.mergeTheme(theme)
	self.format = imports.Format.new(self.theme)
	self.render.theme = self.theme
	self.render.format = self.format
	self.render:applyTheme()
end

function Client:setTemplate(templateOption)
	for _, provider in self.providers do
		provider:stop()
	end
	local template = resolveTemplate(templateOption)
	self.template = template
	self.providers = template.providers or {}
	self.render:setMonitorRows(template.monitorRows or 0)
	if self.mounted and self.config.monitorEnabled then
		for _, provider in self.providers do
			provider:start(self)
		end
	end
end

function Client:mount(parent, options)
	if options then
		applyConfig(self.config, options)
		if options.theme then
			self:setTheme(options.theme)
		end
		if options.template then
			self:setTemplate(options.template)
		end
	end
	if not self:isActive() then
		return
	end

	self.render:mount(parent)
	if self.mounted then
		return
	end

	self.mounted = true
	if self.config.monitorEnabled then
		for _, provider in self.providers do
			provider:start(self)
		end
	end
end

function Client:unmount()
	for _, provider in self.providers do
		provider:stop()
	end

	for _, watch in table.clone(self.watches) do
		watch:disconnect()
	end

	table.clear(self.watches)
	self.perf:reset()
	self.monitor.frameMs = 0
	self.monitor.heartbeatMs = 0
	self.render:unmount()
	self.mounted = false
end

function Client:push(event)
	if not self:isActive() then
		return
	end
	local nextEvent = normalizeEvent(event)
	if not self.render.mounted then
		self:mount()
	end
	self.render:push(nextEvent)
end

function Client:dismiss(key)
	self.render:dismiss(key)
end

function Client:begin(scope, action)
	return {
		scope = scope or "runtime",
		action = action or "work",
		started = os.clock(),
	}
end

function Client:finish(token, fields)
	if type(token) ~= "table" then
		return 0
	end

	local elapsedMs = (os.clock() - token.started) * 1000
	self.perf:add("manual", token.scope or "runtime", token.action or "work", elapsedMs, fields)
	return elapsedMs
end

function Client:record(scope, action, elapsedMs, fields)
	self.perf:add("manual", scope or "runtime", action or "work", tonumber(elapsedMs) or 0, fields)
end

function Client:time(scope, action)
	local token = self:begin(scope, action)
	return function(fields)
		return self:finish(token, fields)
	end
end

function Client:measure(scope, action, callback)
	local token = self:begin(scope, action)
	local ok, result = pcall(callback)
	local elapsedMs = self:finish(token)
	if not ok then
		self:fail(scope, action or "measure", { error = result, ms = string.format("%.2f", elapsedMs) }, 6)
		error(result)
	end

	return result, elapsedMs
end

function Client:watch(key, fields, options)
	options = options or {}
	local event = {
		fields = fields,
		liveInterval = if options.interval ~= nil then options.interval else self.config.liveInterval,
		action = options.action or "watch",
		scope = options.scope or key,
		tone = options.tone or "phase",
		sticky = true,
		key = key,
	}
	self:push(event)

	local client = self
	local watch = {}

	function watch:disconnect()
		self.connected = false
		client:dismiss(key)
		client.watches[key] = nil
	end

	watch.connected = true
	bindDotMethods(watch, watch, { "disconnect" })
	self.watches[key] = watch

	return watch
end

function Client:graph(name, options)
	if not self:isActive() then
		local noop = {}
		function noop:push() end
		function noop:rescale() end
		function noop:remove() end
		bindDotMethods(noop, noop, { "push", "rescale", "remove" })
		return noop
	end

	if not self.render.mounted then
		self:mount()
	end

	self.render:makeGraph(name, options)

	local client = self
	local handle = {}

	function handle:push(value)
		client.render:pushGraph(name, value)
	end

	function handle:rescale(factor)
		client.render:rescaleGraph(name, factor)
	end

	function handle:remove()
		client.render:removeGraph(name)
	end

	bindDotMethods(handle, handle, { "push", "rescale", "remove" })

	return handle
end

function Client:inspect(scope, value, duration)
	local fields = {}
	if type(value) == "table" then
		local count = 0
		for key, item in value do
			count += 1
			if count > 12 then
				fields[".."] = "more"
				break
			end
			fields[tostring(key)] = item
		end
	else
		fields.value = value
	end

	self:trace(scope or "inspect", "value", fields, duration or 6)
end

function Client:emit(tone, scope, action, fields, duration)
	self:push({
		fields = fields,
		duration = duration,
		action = action,
		scope = scope,
		tone = tone,
	})
end

function Client:channel(scope)
	local cached = self.channels[scope]
	if cached then
		return cached
	end

	local channel = {}
	for _, method in { "trace", "info", "phase", "success", "warn", "fail", "error" } do
		bindChannel(channel, method, scope)
	end

	function channel:watch(fields, options)
		options = options or {}
		options.scope = scope
		return self._client:watch(scope, fields, options)
	end

	function channel:time(action)
		return self._client:time(scope, action)
	end

	function channel:measure(action, callback)
		return self._client:measure(scope, action, callback)
	end

	channel._client = self
	bindDotMethods(channel, channel, { "watch", "time", "measure" })
	self.channels[scope] = channel

	return channel
end

function Client:group(scope)
	return self:channel(scope)
end

function Client:raycast(scope, origin, direction, params)
	local started = os.clock()
	local result = imports.Workspace:Raycast(origin, direction, params)
	self.perf:add("raycast", scope or "runtime", "raycast", (os.clock() - started) * 1000, {
		hit = result and result.Instance and result.Instance.Name or "none",
	})

	return result
end

function Client:spherecast(scope, origin, radius, direction, params)
	local started = os.clock()
	local result = imports.Workspace:Spherecast(origin, radius, direction, params)
	self.perf:add("spherecast", scope or "runtime", "spherecast", (os.clock() - started) * 1000, {
		hit = result and result.Instance and result.Instance.Name or "none",
	})

	return result
end

function Client:blockcast(scope, cframe, size, direction, params)
	local started = os.clock()
	local result = imports.Workspace:Blockcast(cframe, size, direction, params)
	self.perf:add("blockcast", scope or "runtime", "blockcast", (os.clock() - started) * 1000, {
		hit = result and result.Instance and result.Instance.Name or "none",
	})

	return result
end

function Client:trace(scope, action, fields, duration)
	self:emit("trace", scope, action, fields, duration)
end

function Client:info(scope, action, fields, duration)
	self:trace(scope, action, fields, duration)
end

function Client:phase(scope, action, fields, duration)
	self:emit("phase", scope, action, fields, duration)
end

function Client:success(scope, action, fields, duration)
	self:emit("success", scope, action, fields, duration)
end

function Client:warn(scope, action, fields, duration)
	self:emit("warn", scope, action, fields, duration)
end

function Client:fail(scope, action, fields, duration)
	self:emit("error", scope, action, fields, duration)
end

function Client:error(scope, action, fields, duration)
	self:fail(scope, action, fields, duration)
end

function Client:clear()
	self.render:clear()
end

function Client:destroy()
	self:unmount()
end

return Client
