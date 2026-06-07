--[[
	@name styles
	@author dullflowerr
	@time June 7, 2026
]]

local Styles = {}

Styles.Charts = {
	bars = require("@self/bars"),
}

function Styles.chart(name)
	return Styles.Charts[name] or Styles.Charts.bars
end

return Styles
