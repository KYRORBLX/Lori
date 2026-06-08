--[[
	@name templates
	@author dullflowerr
	@time June 7, 2026
]]

local imports = {
	Default = require("@self/default"),
	Empty = require("@self/empty"),
}

return {
	Performance = imports.Default,
	Empty = imports.Empty,
}
