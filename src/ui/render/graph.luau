--[[
	@name graph
	@author dullflowerr
	@time June 7, 2026
]]

local imports = {
	Style = require("../styles/bars"),
	UserInputService = game:GetService("UserInputService"),
}

local Graph = {}
Graph.__index = Graph

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

function Graph:top()
	return 0
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
		local anchorPoint = render:rowAnchorPoint()
		local rowX = render:rowX()
		card.frame.AnchorPoint = anchorPoint
		card.textFrame.AnchorPoint = anchorPoint

		render.motion:to(card.frame, "move", {
			Position = UDim2.new(rowX, 0, 0, y),
			Size = UDim2.fromOffset(width, height),
		}, render.config.motionTime)

		render.motion:to(card.textFrame, "move", {
			Position = UDim2.new(rowX, 0, 0, y + height + gap),
			Size = UDim2.fromOffset(card.textSize.X, card.textSize.Y),
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
	if card.failBelow and value <= card.failBelow then
		return "error"
	end
	if card.warnBelow and value <= card.warnBelow then
		return "warn"
	end
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

function Graph:placeColumns(card)
	local gap = card.style.columnGap
	local columnWidth = self:columnWidth(card, gap)
	card.columnWidth = columnWidth

	for index, column in card.columns do
		column.Position = UDim2.new(0, (index - 1) * (columnWidth + gap), 1, 0)
		column.Size = UDim2.new(0, math.ceil(columnWidth), 0, column.Size.Y.Offset)
	end
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
		column.Active = true
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

		column.MouseEnter:Connect(function()
			self:showTooltip(card, index)
		end)
	end
end

function Graph:tooltipText(card, index)
	local value = card.window[index]
	if value == nil then
		return `{card.name}: --`
	end

	return `{card.name} [{index}]: {self:formatValue(card, value)}`
end

function Graph:positionTooltip(card)
	local textWidth = card.tooltip.AbsoluteSize.X
	local textHeight = card.tooltip.AbsoluteSize.Y
	local stackPosition = self.render.stack.AbsolutePosition
	local stackSize = self.render.stack.AbsoluteSize
	local mouse = imports.UserInputService:GetMouseLocation()

	local x = mouse.X - stackPosition.X
	local y = mouse.Y - stackPosition.Y - textHeight - self.render:scaled(34)

	x = math.clamp(x, math.floor(textWidth / 2), stackSize.X - math.floor(textWidth / 2))
	y = math.clamp(y, textHeight, stackSize.Y)

	local shadowPad = self.render:scaled(4)
	card.tooltipShadow.Size = UDim2.fromOffset(textWidth + shadowPad, textHeight + shadowPad)

	self.render.motion:to(card.tooltip, "tooltipMove", {
		Position = UDim2.fromOffset(x, y),
	}, 0.1)

	self.render.motion:to(card.tooltipShadow, "tooltipMove", {
		Position = UDim2.fromOffset(x, y + math.floor(shadowPad / 2)),
	}, 0.1)
end

function Graph:showTooltip(card, index)
	card.tooltip.Text = self:tooltipText(card, index)
	self:positionTooltip(card)
	card.tooltip.Visible = true
	card.tooltipShadow.Visible = true
	card.hoveredIndex = index

	self.render.motion:to(card.tooltip, "fade", {
		TextTransparency = 0,
	}, self.render.config.fadeTime)

	self.render.motion:to(card.tooltipShadow, "fade", {
		ImageTransparency = 0.88,
	}, self.render.config.fadeTime)
end

function Graph:hideTooltip(card)
	card.hoveredIndex = nil

	self.render.motion:to(card.tooltip, "fade", {
		TextTransparency = 1,
	}, self.render.config.fadeTime)

	self.render.motion:to(card.tooltipShadow, "fade", {
		ImageTransparency = 1,
	}, self.render.config.fadeTime)

	task.delay(self.render.config.fadeTime, function()
		if card.hoveredIndex == nil then
			card.tooltip.Visible = false
			card.tooltipShadow.Visible = false
		end
	end)

	self:slice(card)
	self:updateStats(card)
	self:autoRange(card)
	self.render:layout()
end

function Graph:sizeColumn(card, index, height)
	if card.heights[index] == height then
		return
	end
	card.heights[index] = height

	local column = card.columns[index]
	self.render.motion:to(column, "size", {
		Size = UDim2.new(0, math.ceil(card.columnWidth or column.Size.X.Offset), 0, height),
	}, self.render.config.graphTweenTime)
end

function Graph:drawColumns(card)
	local style = card.style
	local plotHeight = self:plotHeight()
	local low, high = card.range[1], card.range[2]
	local span = math.max(high - low, 1e-6)

	self:placeColumns(card)

	local latest = card.samples[#card.samples]
	local emptyColor = self:heatColor(latest and self:thresholdTone(card, latest) or card.tone, 0)

	for index = 1, self.render.config.graphColumns do
		local value = card.window[index]
		local height = style.floor
		local column = card.columns[index]

		if value ~= nil then
			local ratio = math.clamp((value - low) / span, 0, 1)
			height = math.max(style.floor, math.floor(ratio * (plotHeight - 1) + 0.5))
			column.BackgroundColor3 = self:heatColor(self:thresholdTone(card, value), ratio * style.heat)
		else
			column.BackgroundColor3 = emptyColor
		end

		self:sizeColumn(card, index, height)
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
		local stats = render.format:joinFields({
			render.format:field("min", self:formatValue(card, card.minSeen)),
			render.format:field("max", self:formatValue(card, card.maxSeen)),
			render.format:field("avg", self:formatValue(card, card.avgSeen)),
		})
		head ..= ` {stats}`
	end

	return head
end

function Graph:fitText(card)
	local line = self:headLine(card)
	card.head.Text = line
	self.render:syncLabel(card.head)
	self.render:syncPadding(card.head:FindFirstChildOfClass("UIPadding"))
	card.textSize = self.render:rowSize(card.head)
	card.textWidth = card.textSize.X
	task.defer(function()
		if not card.textFrame.Parent then
			return
		end

		local resolvedSize = self.render:rowSize(card.head)
		if resolvedSize == card.textSize then
			return
		end

		card.textSize = resolvedSize
		card.textWidth = resolvedSize.X
		self.render.motion:to(card.textFrame, "move", {
			Size = UDim2.fromOffset(resolvedSize.X, resolvedSize.Y),
		}, self.render.config.motionTime)
	end)
end

function Graph:slice(card)
	local count = self.render.config.graphColumns
	local first = math.max(1, #card.samples - count + 1)
	local sampleCount = #card.samples - first + 1
	local window = {}

	if sampleCount <= 0 then
		card.window = window
		return window
	end

	if sampleCount == 1 then
		local value = card.samples[first]
		for _ = 1, count do
			table.insert(window, value)
		end
	else
		for column = 1, count do
			local position = (column - 1) / math.max(count - 1, 1)
			local samplePosition = position * (sampleCount - 1)
			local leftOffset = math.floor(samplePosition)
			local rightOffset = math.min(leftOffset + 1, sampleCount - 1)
			local alpha = samplePosition - leftOffset
			local left = card.samples[first + leftOffset]
			local right = card.samples[first + rightOffset]
			table.insert(window, left + (right - left) * alpha)
		end
	end

	card.window = window
	return window
end

function Graph:updateStats(card)
	local low = math.huge
	local high = -math.huge
	local total = 0

	for _, sample in card.window do
		low = math.min(low, sample)
		high = math.max(high, sample)
		total += sample
	end

	card.minSeen = low == math.huge and 0 or low
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
		pad = math.max(math.abs(high) * 0.1, 1e-6)
	end

	local rangeLow = if high <= 0 then low - pad else math.max(0, low - pad)
	local rangeHigh = high + pad
	if rangeHigh <= rangeLow then
		rangeHigh = rangeLow + 1e-6
	end
	card.range = { rangeLow, rangeHigh }
end

function Graph:redraw(card)
	self:drawColumns(card)
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
		style = imports.Style,
		unit = options.unit or "",
		format = options.format,
		samples = {},
		window = {},
		columns = {},
		heights = {},
		columnWidth = 1,
		range = { lo, hi },
		fixedRange = options.range ~= nil,
		warnAt = tonumber(options.warnAt),
		failAt = tonumber(options.failAt),
		warnBelow = tonumber(options.warnBelow),
		failBelow = tonumber(options.failBelow),
		hoveredIndex = nil,
		tooltip = nil,
		tooltipShadow = nil,
		display = "--",
		textSize = Vector2.zero,
		textWidth = 0,
		minSeen = 0,
		maxSeen = 0,
		avgSeen = 0,
		dead = false,
	}

	local width = graphWidth(render)
	local height = graphHeight(render)

	local frame = Instance.new("Frame")
	frame.Name = `LoriGraph_{render.serial}`
	frame.AnchorPoint = render:rowAnchorPoint()
	local offscreen = render:offscreenPosition(width)
	frame.Position = UDim2.new(offscreen.X.Scale, offscreen.X.Offset, 0, self:top())
	frame.Size = UDim2.fromOffset(width, height)
	frame.BackgroundColor3 = render.theme.background
	frame.BackgroundTransparency = 0.62
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = true
	frame.Parent = render.stack

	local corner = Instance.new("UICorner")
	corner.CornerRadius = render:cornerRadius()
	corner.Parent = frame

	local plot = Instance.new("Frame")
	plot.Name = "Plot"
	plot.Active = true
	plot.BackgroundTransparency = 1
	plot.BorderSizePixel = 0
	plot.ClipsDescendants = true
	plot.Parent = frame

	plot.MouseLeave:Connect(function()
		if card.hoveredIndex ~= nil then
			self:hideTooltip(card)
		end
	end)

	local textFrame = Instance.new("Frame")
	textFrame.Name = `LoriGraphText_{render.serial}`
	textFrame.AnchorPoint = render:rowAnchorPoint()
	textFrame.Position =
		UDim2.new(offscreen.X.Scale, offscreen.X.Offset, 0, self:top() + height + render:scaled(render.config.gap))
	textFrame.Size = UDim2.new()
	textFrame.BackgroundColor3 = render.theme.background
	textFrame.BackgroundTransparency = 0.62
	textFrame.BorderSizePixel = 0
	textFrame.ClipsDescendants = true
	textFrame.Parent = render.stack

	local textCorner = Instance.new("UICorner")
	textCorner.CornerRadius = render:cornerRadius()
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
	render:syncLabel(head)

	local headPadding = Instance.new("UIPadding")
	headPadding.Parent = head
	render:syncPadding(headPadding)

	local tooltipShadow = Instance.new("ImageLabel")
	tooltipShadow.Name = "TooltipShadow"
	tooltipShadow.AnchorPoint = Vector2.new(0.5, 1)
	tooltipShadow.BackgroundTransparency = 1
	tooltipShadow.Image = "rbxassetid://1316045217"
	tooltipShadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
	tooltipShadow.ImageTransparency = 1
	tooltipShadow.ScaleType = Enum.ScaleType.Slice
	tooltipShadow.SliceCenter = Rect.new(10, 10, 118, 118)
	tooltipShadow.Visible = false
	tooltipShadow.ZIndex = 5
	tooltipShadow.Parent = render.stack

	local tooltip = Instance.new("TextLabel")
	tooltip.Name = "Tooltip"
	tooltip.AnchorPoint = Vector2.new(0.5, 1)
	tooltip.AutomaticSize = Enum.AutomaticSize.XY
	tooltip.BackgroundTransparency = 1
	tooltip.BorderSizePixel = 0
	tooltip.FontFace = render.config.font
	tooltip.RichText = false
	tooltip.TextColor3 = render.theme.text
	tooltip.TextSize = render.config.textSize
	tooltip.TextTransparency = 1
	tooltip.TextXAlignment = Enum.TextXAlignment.Center
	tooltip.TextYAlignment = Enum.TextYAlignment.Center
	tooltip.Visible = false
	tooltip.ZIndex = 6
	tooltip.Size = UDim2.new()
	tooltip.Parent = render.stack

	local tooltipPadding = Instance.new("UIPadding")
	tooltipPadding.Parent = tooltip
	render:syncPadding(tooltipPadding)

	local tooltipCorner = Instance.new("UICorner")
	tooltipCorner.CornerRadius = render:cornerRadius()
	tooltipCorner.Parent = tooltip

	card.textFrame = textFrame
	card.tooltip = tooltip
	card.tooltipShadow = tooltipShadow
	card.frame = frame
	card.plot = plot
	card.head = head

	self:buildColumns(card)
	self:fitText(card)
	self:syncCard(card)

	table.insert(self.order, card)
	self.cards[name] = card
	render:layout()

	render.motion:to(frame, "move", {
		Position = UDim2.new(render:rowX(), 0, 0, frame.Position.Y.Offset),
		Size = UDim2.fromOffset(width, height),
	}, render.config.motionTime)

	render.motion:to(textFrame, "move", {
		Position = UDim2.new(render:rowX(), 0, 0, textFrame.Position.Y.Offset),
		Size = UDim2.fromOffset(card.textSize.X, card.textSize.Y),
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

	if card.hoveredIndex ~= nil then
		return
	end

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

	local offscreen = render:offscreenPosition(graphWidth(render))
	render.motion:to(card.frame, "move", {
		Position = UDim2.new(offscreen.X.Scale, offscreen.X.Offset, 0, card.frame.Position.Y.Offset),
	}, render.config.exitTime)

	render.motion:to(card.textFrame, "move", {
		Position = UDim2.new(offscreen.X.Scale, offscreen.X.Offset, 0, card.textFrame.Position.Y.Offset),
	}, render.config.exitTime)

	task.delay(render.config.exitTime + 0.04, function()
		local index = table.find(self.order, card)
		if index then
			table.remove(self.order, index)
		end

		card.frame:Destroy()
		card.textFrame:Destroy()
		card.tooltip:Destroy()
		card.tooltipShadow:Destroy()
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
		if card.tooltip then
			card.tooltip:Destroy()
		end
		if card.tooltipShadow then
			card.tooltipShadow:Destroy()
		end
	end

	table.clear(self.cards)
	table.clear(self.order)
end

return Graph
