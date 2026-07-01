--[[
	@name Service
	@author driftingAurora, dullflowerr
	@time June 8, 2026
]]

local module = {}

local blacklistMethods = {
	FPS = "FpsGraph",
	Frame = "Frame",
	Memory = "MemGraph",
	Ping = "PingGraph",
}

function module.register(item)
	function item:addItem(n: string)
		table.insert(item.Blacklist, n)
		return item
	end

	for method, provider in blacklistMethods do
		item[method] = function()
			return item:addItem(provider)
		end
	end

	return item
end

return module
