--[[
	@name format
	@author dullflowerr
	@time June 7, 2026
]]

local Format = {}
Format.__index = Format

function Format.new(theme)
	return setmetatable({
		theme = theme,
	}, Format)
end

function Format.escape(value)
	return tostring(value):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
end

function Format.hex(color)
	local r = math.floor(color.R * 255 + 0.5)
	local g = math.floor(color.G * 255 + 0.5)
	local b = math.floor(color.B * 255 + 0.5)
	return string.format("#%02X%02X%02X", r, g, b)
end

function Format:colored(color, text)
	return `<font color="{Format.hex(color)}">{Format.escape(text)}</font>`
end

function Format:field(key, value)
	return `{self:colored(self.theme.key, key)}={self:colored(self.theme.value, value)}`
end

function Format:joinFields(parts)
	return table.concat(parts, self:colored(self.theme.muted, " "))
end

function Format:fields(fields)
	if type(fields) ~= "table" then
		return ""
	end

	local keys = {}
	for key in fields do
		table.insert(keys, key)
	end
	table.sort(keys)

	local parts = {}
	for _, key in keys do
		local value = fields[key]

		if type(value) == "function" then
			local ok, result = pcall(value)
			value = ok and result or "err"
		end

		if value ~= nil then
			table.insert(parts, self:field(key, value))
		end
	end

	return self:joinFields(parts)
end

function Format:hasLiveFields(fields)
	if type(fields) ~= "table" then
		return false
	end
	for _, value in fields do
		if type(value) == "function" then
			return true
		end
	end

	return false
end

function Format.plainText(richText)
	return tostring(richText):gsub("<[^>]->", "")
end

function Format:eventLine(event)
	local tone = event.tone or "trace"
	local scope = event.scope or "runtime"
	local action = event.action or "event"
	local fields = self:fields(event.fields)
	local color = self.theme[tone] or self.theme.trace
	local prefix = self:colored(color, string.upper(tone))
	local head = `{prefix} {self:colored(self.theme.muted, scope)} {self:colored(self.theme.text, action)}`
	return fields ~= "" and `{head} {fields}` or head
end

return Format
