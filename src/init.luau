--[[
	@name Lori
	@author dullflowerr
	@time June 7, 2026
]]

local imports = {
	Client = require("@self/core/client"),
	Config = require("@self/core/config"),

	ItemBlacklister = require("@self/templates/utils/itemBlacklist"),
	Templates = require("@self/templates"),
}

local Lori = {
	Templates = {},
}

do
	imports.Templates.ItemBlacklister = imports.ItemBlacklister
	Lori.Templates = table.freeze(imports.Templates)

	Lori.Themes = {
		Default = imports.Config.theme,
	}
end

local defaultClient = nil

local function getDefaultClient()
	if not defaultClient then
		defaultClient = imports.Client.new()
	end
	return defaultClient
end

local function callDefault(method, ...)
	local client = getDefaultClient()
	return client[method](client, ...)
end

local function forward(method)
	Lori[method] = function(...)
		return callDefault(method, ...)
	end
end

function Lori.create(options)
	return imports.Client.new(options)
end

function Lori.unmount()
	if defaultClient then
		defaultClient:unmount()
	end
end

function Lori.destroy()
	if defaultClient then
		defaultClient:destroy()
		defaultClient = nil
	end
end

for _, method in
	{
		"mount",
		"setTheme",
		"setTemplate",
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
	}
do
	forward(method)
end

return table.freeze(Lori)
