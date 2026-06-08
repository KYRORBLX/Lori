--[[
	@name ItemBlacklist
	@author driftingAurora
	@time June 8, 2026
]]

local imports = {
	Service = require("@self/Service"),
}

return {
	New = function()
		local list = setmetatable({ Blacklist = {} }, {
			__type = "Item Blacklist",
		})

		return imports.Service.register(list)
	end,
}
