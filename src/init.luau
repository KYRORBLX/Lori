--[[
	@name Lori
	@author dullflowerr
	@time June 7, 2026
]]

local imports = {
	Client = require("@self/core/client");
	Config = require("@self/core/config");

	ItemBlacklister = require("@self/templates/utils/itemBlacklist");
	Templates = require("@self/templates");
}

local Types = require("@self/core/types") -- . . luau syntax cant reach table fields :( bad design, sorry - kio

export type Client = Types.Client
export type ClientOptions = Types.ClientOptions
export type Event = Types.Event
export type Fields = Types.Fields
export type Tone = Types.Tone
export type Channel = Types.Channel
export type Watch = Types.Watch
export type WatchOptions = Types.WatchOptions
export type GraphHandle = Types.GraphHandle
export type GraphOptions = Types.GraphOptions
export type Theme = Types.Theme

local Lori = {
	Templates = {}
}

do
	local templates = table.clone(imports.Templates) :: { [string]: any }
	templates.ItemBlacklister = imports.ItemBlacklister
	Lori.Templates = table.freeze(templates)

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

function Lori.create(options: Types.ClientOptions?): Types.Client
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
		"progress",
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

return (table.freeze(Lori) :: any) :: Types.LoriApi
