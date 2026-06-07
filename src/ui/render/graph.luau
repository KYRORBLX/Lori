--[[
	@name graph
	@author dullflowerr
	@time June 7, 2026
]]

local imports = {
	TweenService = game:GetService("TweenService"),

	Styles = require("../styles"),
}

local Graph = {}
Graph.__index = Graph

local function graphCorner(render)
	return UDim.new(0, math.floor(0.3 * render.config.rowHeight + 0.5))
end

local function graphWidth(render)
	return math.min(render.config.graphWidth, render:maxLineWidth())
end

local function graphHeight(render)
	return render.config.graphHeight
end

local function graphBlockHeight(render)
	return graphHeight(render) + render.config.gap + render.config.rowHeight
end

function Graph.new(render)
	return setmetatable({
		render = render,
		cards = {},
		order = {},
	}, Graph)
end

function Graph:height()
	local count = 0
	for _, card in self.order do
		if not card.dead then
			count += 1
		end
	end

	if count == 0 then
		return 0
	end

	return count * graphBlockHeight(self.render) + count * self.render:scaled(self.render.config.gap)
end

function Graph:layout(y)
	local render = self.render
	local width = graphWidth(render)
	local height = graphHeight(render)
	local gap = render:scaled(render.config.gap)

	for _, card in self.order do
		if card.dead then
			continue
		end

		self:syncCard(card)
		render.motion:to(card.frame, "move", {
			Position = UDim2.new(1, 0, 0, y),
			Size = UDim2.fromOffset(width, height),
		}, render.config.motionTime)

		render.motion:to(card.textFrame, "move", {
			Position = UDim2.new(1, 0, 0, y + height + gap),
			Size = UDim2.fromOffset(card.textWidth, render:scaled(render.config.rowHeight)),
		}, render.config.motionTime)

		y += graphBlockHeight(render) + gap
	end
end

function Graph:applyTheme()
	local render = self.render

	for _, card in self.order do
		card.frame.BackgroundColor3 = render.theme.background
		card.textFrame.BackgroundColor3 = render.theme.background
		card.head.TextColor3 = render.theme.text

		for _, column in card.columns do
			column.BackgroundColor3 = render.theme[card.tone] or render.theme.trace
		end

		self:redraw(card)
	end
end

function Graph:toneColor(card)
	return self.render.theme[card.tone] or self.render.theme.trace
end

function Graph:thresholdTone(card, value)
	if card.warnAt and value >= card.warnAt then
		return card.failAt and value >= card.failAt and "error" or "warn"
	end

	return card.tone
end

function Graph:heatColor(tone, amount)
	return (self.render.theme[tone] or self.render.theme.trace):Lerp(self.render.theme.text, amount)
end

function Graph:plotHeight()
	return graphHeight(self.render) - self.render:scaled(6)
end

function Graph:columnWidth(card, gap)
	local count = math.max(1, self.render.config.graphColumns)
	local gaps = gap * (count - 1)
	return math.max(1, (graphWidth(self.render) - self.render.config.padX * 2 - gaps) / count)
end

function Graph:placeColumns(card, gap)
	local columnWidth = self:columnWidth(card, gap)

	for index, column in card.columns do
		column.Position = UDim2.new(0, (index - 1) * (columnWidth + gap), 1, 0)
		column.Size = UDim2.new(0, math.ceil(columnWidth), 0, column.Size.Y.Offset)
	end

	card.columnWidth = columnWidth
end

function Graph:sizeColumn(card, index, height)
	if card.heights[index] == height then
		return
	end
	card.heights[index] = height

	local column = card.columns[index]
	if card.tweens[index] then
		card.tweens[index]:Cancel()
	end

	card.tweens[index] = imports.TweenService:Create(
		column,
		TweenInfo.new(self.render.config.graphTweenTime, self.render.config.motionStyle, Enum.EasingDirection.Out),
		{ Size = UDim2.new(0, math.ceil(card.columnWidth or column.Size.X.Offset), 0, height) }
	)
	card.tweens[index]:Play()
end

function Graph:buildColumns(card)
	local style = card.style
	local tone = self:toneColor(card)

	for index = 1, self.render.config.graphColumns do
		local column = Instance.new("Frame")
		column.Name = `Col{index}`
		column.AnchorPoint = Vector2.new(0, 1)
		column.BackgroundColor3 = tone
		column.BackgroundTransparency = style.columnTransparency
		column.BorderSizePixel = 0
		column.Parent = card.plot

		if style.gradientFade then
			local gradient = Instance.new("UIGradient")
			gradient.Rotation = 90
			gradient.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, style.gradientFade),
			})
			gradient.Parent = column
		end

		card.columns[index] = column
	end
end

function Graph:drawColumns(card)
	local style = card.style
	local plotHeight = self:plotHeight()
	local low, high = card.range[1], card.range[2]
	local span = math.max(high - low, 1e-6)

	self:placeColumns(card, style.columnGap)

	for index = 1, self.render.config.graphColumns do
		local value = card.window[index]
		local height = style.floor

		if value ~= nil then
			local ratio = math.clamp((value - low) / span, 0, 1)
			height = math.max(style.floor, math.floor(ratio * (plotHeight - 1) + 0.5))
			local tone = self:thresholdTone(card, value)
			card.columns[index].BackgroundColor3 = self:heatColor(tone, ratio * style.heat)
		end

		self:sizeColumn(card, index, height)
	end
end

function Graph:build(card)
	if card.style.build then
		card.style.build(self, card)
	else
		self:buildColumns(card)
	end
end

function Graph:draw(card)
	if card.style.draw then
		card.style.draw(self, card)
	else
		self:drawColumns(card)
	end
end

function Graph:formatValue(card, value)
	if card.format then
		local ok, result = pcall(card.format, value)
		if ok then
			return tostring(result)
		end
	end

	local rounded = math.abs(value) >= 100 and string.format("%.0f", value) or string.format("%.1f", value)
	rounded = rounded:gsub("%.0$", "")
	return card.unit ~= "" and `{rounded}{card.unit}` or rounded
end

function Graph:headLine(card)
	local render = self.render
	local name = render.format:colored(render.theme[card.tone] or render.theme.trace, card.name)
	local value = render.format:colored(render.theme.value, card.display or "--")
	local head = `{name}: {value}`

	if #card.window > 0 then
		local gap = render.format:colored(render.theme.muted, " ")
		local max = `{render.format:colored(render.theme.muted, "max")}={render.format:colored(
			render.theme.value,
			self:formatValue(card, card.maxSeen)
		)}`
		local avg = `{render.format:colored(render.theme.muted, "avg")}={render.format:colored(
			render.theme.value,
			self:formatValue(card, card.avgSeen)
		)}`
		head ..= `{gap}{max}{gap}{avg}`
	end

	return head
end

function Graph:fitText(card)
	local line = self:headLine(card)
	card.head.Text = line
	card.textWidth = self.render:measuredWidth(line)
	self.render:syncLabel(card.head)
end

function Graph:slice(card)
	local count = self.render.config.graphColumns
	local first = math.max(1, #card.samples - count + 1)
	local window = {}

	for index = first, #card.samples do
		table.insert(window, card.samples[index])
	end

	card.window = window
	return window
end

function Graph:updateStats(card)
	local high = -math.huge
	local total = 0

	for _, sample in card.window do
		high = math.max(high, sample)
		total += sample
	end

	card.maxSeen = high == -math.huge and 0 or high
	card.avgSeen = #card.window > 0 and total / #card.window or 0
end

function Graph:autoRange(card)
	if card.fixedRange then
		return
	end

	local low = math.huge
	local high = -math.huge

	for _, value in card.window do
		low = math.min(low, value)
		high = math.max(high, value)
	end

	if low == math.huge then
		return
	end

	local pad = (high - low) * 0.15
	if pad <= 0 then
		pad = math.max(high * 0.1, 1)
	end

	card.range = { math.max(0, low - pad), high + pad }
end

function Graph:redraw(card)
	self:draw(card)
end

function Graph:syncCard(card)
	local render = self.render
	local width = graphWidth(render)
	local height = graphHeight(render)
	local padX = render:scaled(render.config.padX)

	self:fitText(card)
	card.plot.Position = UDim2.fromOffset(padX, render:scaled(3))
	card.plot.Size = UDim2.fromOffset(width - padX * 2, height - render:scaled(6))
	self:redraw(card)
end

function Graph:make(name, options)
	if self.cards[name] then
		return
	end

	local render = self.render
	options = options or {}
	render.serial += 1

	local lo, hi = 0, 1
	if type(options.range) == "table" then
		lo = tonumber(options.range[1]) or lo
		hi = tonumber(options.range[2]) or hi
		if hi <= lo then
			hi = lo + 1
		end
	end

	local card = {
		name = name,
		tone = options.tone or "trace",
		style = imports.Styles.chart(options.style or "bars"),
		unit = options.unit or "",
		format = options.format,
		samples = {},
		window = {},
		columns = {},
		tweens = {},
		heights = {},
		range = { lo, hi },
		fixedRange = options.range ~= nil,
		warnAt = tonumber(options.warnAt),
		failAt = tonumber(options.failAt),
		display = "--",
		textWidth = render:scaled(render.config.minWidth),
		maxSeen = 0,
		avgSeen = 0,
		dead = false,
	}

	local width = graphWidth(render)
	local height = graphHeight(render)

	local frame = Instance.new("Frame")
	frame.Name = `LoriGraph_{render.serial}`
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.Position = UDim2.new(1, render:offscreen(width) + render:scaled(12), 0, render:graphsTop())
	frame.Size = UDim2.fromOffset(width, height)
	frame.BackgroundColor3 = render.theme.background
	frame.BackgroundTransparency = 0.62
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = true
	frame.Parent = render.stack

	local corner = Instance.new("UICorner")
	corner.CornerRadius = graphCorner(render)
	corner.Parent = frame

	local plot = Instance.new("Frame")
	plot.Name = "Plot"
	plot.BackgroundTransparency = 1
	plot.BorderSizePixel = 0
	plot.ClipsDescendants = true
	plot.Parent = frame

	local textFrame = Instance.new("Frame")
	textFrame.Name = `LoriGraphText_{render.serial}`
	textFrame.AnchorPoint = Vector2.new(1, 0)
	textFrame.Position = UDim2.new(
		1,
		render:offscreen(width) + render:scaled(12),
		0,
		render:graphsTop() + height + render:scaled(render.config.gap)
	)
	textFrame.Size = UDim2.fromOffset(width, render:scaled(render.config.rowHeight))
	textFrame.BackgroundColor3 = render.theme.background
	textFrame.BackgroundTransparency = 0.62
	textFrame.BorderSizePixel = 0
	textFrame.ClipsDescendants = true
	textFrame.Parent = render.stack

	local textCorner = Instance.new("UICorner")
	textCorner.CornerRadius = graphCorner(render)
	textCorner.Parent = textFrame

	local head = Instance.new("TextLabel")
	head.Name = "Line"
	head.BackgroundTransparency = 1
	head.FontFace = render.config.font
	head.RichText = true
	head.TextColor3 = render.theme.text
	head.TextTransparency = 1
	head.TextTruncate = Enum.TextTruncate.None
	head.TextWrapped = false
	head.TextXAlignment = Enum.TextXAlignment.Left
	head.TextYAlignment = Enum.TextYAlignment.Center
	head.Parent = textFrame

	card.frame = frame
	card.textFrame = textFrame
	card.plot = plot
	card.head = head

	self:build(card)
	self:fitText(card)
	self:syncCard(card)

	table.insert(self.order, card)
	self.cards[name] = card
	render:layout()

	render.motion:to(frame, "move", {
		Position = UDim2.new(1, 0, 0, frame.Position.Y.Offset),
		Size = UDim2.fromOffset(width, height),
	}, render.config.motionTime)

	render.motion:to(textFrame, "move", {
		Position = UDim2.new(1, 0, 0, textFrame.Position.Y.Offset),
		Size = UDim2.fromOffset(card.textWidth, render:scaled(render.config.rowHeight)),
	}, render.config.motionTime)

	render:fadeIn(head)
end

function Graph:push(name, value)
	local card = self.cards[name]
	if not card or card.dead then
		return
	end

	value = tonumber(value)
	if value == nil then
		return
	end

	table.insert(card.samples, value)
	while #card.samples > self.render.config.graphColumns * 2 do
		table.remove(card.samples, 1)
	end

	card.display = self:formatValue(card, value)
	self:slice(card)
	self:updateStats(card)
	self:autoRange(card)

	self.render:layout()
end

function Graph:rescale(name, factor)
	local card = self.cards[name]
	factor = tonumber(factor) or 1
	if not card or factor <= 0 then
		return
	end

	card.fixedRange = true
	local mid = (card.range[1] + card.range[2]) / 2
	local half = math.max((card.range[2] - card.range[1]) / 2 * factor, 0.5)
	card.range = { mid - half, mid + half }
	self:redraw(card)
end

function Graph:remove(name)
	local card = self.cards[name]
	if not card or card.dead then
		return
	end

	local render = self.render
	card.dead = true
	self.cards[name] = nil

	render.motion:cancel(card.frame)
	render.motion:cancel(card.textFrame)
	for _, tween in card.tweens do
		tween:Cancel()
	end

	local exit = render:offscreen(graphWidth(render)) + render:scaled(12)
	render.motion:to(card.frame, "move", {
		Position = UDim2.new(1, exit, 0, card.frame.Position.Y.Offset),
	}, render.config.exitTime)

	render.motion:to(card.textFrame, "move", {
		Position = UDim2.new(1, exit, 0, card.textFrame.Position.Y.Offset),
	}, render.config.exitTime)

	task.delay(render.config.exitTime + 0.04, function()
		local index = table.find(self.order, card)
		if index then
			table.remove(self.order, index)
		end

		card.frame:Destroy()
		card.textFrame:Destroy()
		render:layout()
	end)
end

function Graph:clear()
	for _, card in self.order do
		if card.frame then
			card.frame:Destroy()
		end
		if card.textFrame then
			card.textFrame:Destroy()
		end
	end

	table.clear(self.cards)
	table.clear(self.order)
end

return Graph
