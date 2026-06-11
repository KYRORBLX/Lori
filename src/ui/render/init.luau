--[[
	@name render
	@author dullflowerr
	@time June 7, 2026
]]

local imports = {
	Players = game:GetService("Players"),
	Workspace = game:GetService("Workspace"),

	Bar = require("@self/bar"),
	Format = require("./format"),
	Graph = require("@self/graph"),
	Motion = require("./motion"),
	Tooltip = require("@self/tooltip"),
}

local Render = {}
Render.__index = Render

local function resolveParent(parent)
	if parent then
		return parent
	end

	local player = imports.Players.LocalPlayer
	return player and player:WaitForChild("PlayerGui")
end

function Render.new(config, theme, format, monitorRows)
	return setmetatable({
		motion = imports.Motion.new(config),
		monitorRows = monitorRows or 0,
		viewportConnection = nil,
		cameraConnection = nil,
		mounted = false,
		config = config,
		format = format,
		theme = theme,
		tooltip = nil,
		graph = nil,
		stack = nil,
		scale = 1,
		items = {},
		keyed = {},
		serial = 0,
		gui = nil,
	}, Render)
end

function Render:viewportWidth()
	local camera = imports.Workspace.CurrentCamera
	local width = camera and camera.ViewportSize.X or 0
	if width < 200 then
		width = 1280
	end

	return width
end

local function resolveAnchor(anchor)
	anchor = string.lower(tostring(anchor or "tr"))

	if anchor == "topright" or anchor == "top-right" then
		anchor = "tr"
	elseif anchor == "topleft" or anchor == "top-left" then
		anchor = "tl"
	elseif anchor == "bottomright" or anchor == "bottom-right" then
		anchor = "br"
	elseif anchor == "bottomleft" or anchor == "bottom-left" then
		anchor = "bl"
	end

	if anchor == "tl" then
		return Vector2.new(0, 0), UDim2.new(0, 0, 0, 0)
	elseif anchor == "bl" then
		return Vector2.new(0, 1), UDim2.new(0, 0, 1, 0)
	elseif anchor == "br" then
		return Vector2.new(1, 1), UDim2.new(1, 0, 1, 0)
	end

	return Vector2.new(1, 0), UDim2.new(1, 0, 0, 0)
end

function Render:scaleFactor()
	if self.config.uiScale == false then
		return 1
	end

	if type(self.config.uiScale) == "number" then
		return math.max(0.05, self.config.uiScale)
	end

	local baseWidth = math.max(1, tonumber(self.config.scaleBaseWidth) or 1280)
	local minScale = tonumber(self.config.minScale) or 0.9
	local maxScale = tonumber(self.config.maxScale) or 1.12

	return math.clamp(self:viewportWidth() / baseWidth, minScale, maxScale)
end

function Render:updateScale()
	self.scale = self:scaleFactor()
end

function Render:scaled(value)
	return math.max(1, math.floor(value * self.scale + 0.5))
end

function Render:gap()
	return self:scaled(self.config.gap)
end

function Render:isLeftAligned()
	return self.stack and self.stack.AnchorPoint.X == 0
end

function Render:setVisible(visible)
	self.config.uiVisible = visible ~= false
	if self.gui then
		self.gui.Enabled = self.config.uiVisible
	end
end

function Render:rowAnchorPoint()
	return if self:isLeftAligned() then Vector2.new(0, 0) else Vector2.new(1, 0)
end

function Render:rowX()
	return if self:isLeftAligned() then 0 else 1
end

function Render:cornerRadius()
	local radius = self.config.cornerRadius
	if type(radius) == "number" then
		if radius <= 1 then
			return UDim.new(0, self:scaled(self.config.rowHeight * radius))
		end

		return UDim.new(0, self:scaled(radius))
	end

	return UDim.new(0, self:scaled(self.config.rowHeight * 0.3))
end

function Render:offscreenPosition(width)
	local offset = self:offscreen(width)
	if self:isLeftAligned() then
		return UDim2.new(0, -offset, 0, 0)
	end

	return UDim2.new(1, offset, 0, 0)
end

function Render:viewportLimit()
	return math.max(self:scaled(self.config.minWidth), self:viewportWidth() - self.config.rightOffset * 2 - 24)
end

function Render:maxLineWidth()
	local configured = type(self.config.maxWidth) == "number" and self.config.maxWidth or math.huge
	if configured <= 0 then
		configured = math.huge
	else
		configured = self:scaled(configured)
	end

	return math.max(self:scaled(self.config.minWidth), math.min(configured, self:viewportLimit()))
end

function Render:contentHeight()
	local gap = self:gap()
	local rowsHeight = 0

	for _, item in self.items do
		rowsHeight += self:itemSize(item).Y + gap
	end
	if rowsHeight > 0 then
		rowsHeight -= gap
	end

	return self:monitorOffset() + rowsHeight
end

function Render:updateStackSize()
	if not self.stack then
		return
	end

	self:updateScale()
	local height = math.max(self:scaled(self.config.rowHeight), self:contentHeight())
	self.motion:to(self.stack, "size", {
		Size = UDim2.fromOffset(self:maxLineWidth(), height),
	}, self.config.motionTime)
end

function Render:bindViewport()
	if self.viewportConnection then
		self.viewportConnection:Disconnect()
		self.viewportConnection = nil
	end

	local camera = imports.Workspace.CurrentCamera
	if camera then
		self.viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			self:updateScale()
			self:layout()
		end)
	end

	if not self.cameraConnection then
		self.cameraConnection = imports.Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
			self:bindViewport()
			self:updateScale()
			self:layout()
		end)
	end
end

function Render:offscreen(width)
	return math.max(width or self:maxLineWidth(), self:scaled(self.config.minWidth)) + self:scaled(32)
end

function Render:syncLabel(label)
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Position = UDim2.new()
	label.Size = UDim2.new()
	label.TextSize = self:scaled(self.config.textSize)
end

function Render:syncPadding(padding)
	if not padding then
		return
	end

	local padX = self:scaled(self.config.padX * 1.08)
	local padY = self:scaled(self.config.padX * 0.49)
	padding.PaddingTop = UDim.new(0, padY)
	padding.PaddingBottom = UDim.new(0, padY)
	padding.PaddingLeft = UDim.new(0, padX)
	padding.PaddingRight = UDim.new(0, padX)
end

function Render:rowSize(label)
	return Vector2.new(label.AbsoluteSize.X, label.AbsoluteSize.Y)
end

function Render:monitorOffset()
	return self:graphOffset()
end

function Render:graphOffset()
	return self.graph and self.graph:height() or 0
end

function Render:rowY(index)
	return self:monitorOffset()
end

function Render:buildRow(line, name)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = self:rowAnchorPoint()
	frame.Size = UDim2.new()
	frame.BackgroundColor3 = self.theme.background
	frame.BackgroundTransparency = 0.62
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = true
	frame.Parent = self.stack

	local corner = Instance.new("UICorner")
	corner.CornerRadius = self:cornerRadius()
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "Line"
	label.BackgroundTransparency = 1
	label.FontFace = self.config.font
	label.RichText = true
	label.Text = line
	label.TextColor3 = self.theme.text
	label.TextTruncate = Enum.TextTruncate.None
	label.TextWrapped = false
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = frame
	self:syncLabel(label)

	local padding = Instance.new("UIPadding")
	padding.Parent = label
	self:syncPadding(padding)

	local size = self:rowSize(label)
	frame.Size = UDim2.fromOffset(size.X, size.Y)
	task.defer(function()
		if frame.Parent then
			self:layout()
		end
	end)

	if self.tooltip then
		self.tooltip:attach(frame, label)
	end

	return frame, label, size.X
end

function Render:moveTo(frame, y, size, time)
	frame.AnchorPoint = self:rowAnchorPoint()
	self.motion:to(frame, "move", {
		Position = UDim2.new(self:rowX(), 0, 0, y),
		Size = UDim2.fromOffset(size.X, size.Y),
	}, time)
end

function Render:fadeIn(label)
	self.motion:to(label, "fade", { TextTransparency = 0 }, self.config.fadeTime)
end

function Render:layout()
	self:updateStackSize()

	if self.graph then
		self.graph:layout(self.graph:top())
	end

	local y = self:monitorOffset()
	local gap = self:gap()

	for _, item in ipairs(self.items) do
		if not item.dead then
			self:syncLabel(item.label)
			self:syncPadding(item.label:FindFirstChildOfClass("UIPadding"))
		end

		local size = self:itemSize(item)
		if not item.dead then
			item.width = size.X
			imports.Bar.layout(self, item)
			self:moveTo(item.frame, y, size, self.config.motionTime)
		end

		y += size.Y + gap
	end
end

function Render:applyTheme()
	for _, item in self.items do
		item.frame.BackgroundColor3 = self.theme.background
		item.label.TextColor3 = self.theme.text
		imports.Bar.tint(self, item)
	end
	if self.tooltip then
		self.tooltip:applyTheme()
	end
	if self.graph then
		self.graph:applyTheme()
	end
end

function Render:setMonitorRows(rows)
	self.monitorRows = rows or 0
	self:layout()
end

function Render:dropKey(item)
	if item.key and self.keyed[item.key] == item then
		self.keyed[item.key] = nil
	end
end

function Render:needsLive(event)
	return event.liveInterval or self.format:hasLiveFields(event.fields)
end

function Render:liveDelay(event)
	local delay = if event.liveInterval ~= nil then event.liveInterval else self.config.liveInterval
	return math.max(self.config.minInterval or 0, tonumber(delay) or 0)
end

function Render:refreshItem(item, event)
	local line = self.format:eventLine(event)
	item.label.Text = line
	item.width = self:rowSize(item.label).X
	self:layout()
	task.defer(function()
		if not item.dead then
			self:layout()
		end
	end)
end

function Render:itemSize(item)
	local size = self:rowSize(item.label)
	return Vector2.new(size.X, size.Y + imports.Bar.extra(self, item))
end

function Render:startLive(item)
	if item.liveRunning or not self:needsLive(item.event) then
		return
	end

	item.liveRunning = true
	task.spawn(function()
		while not item.dead do
			local event = item.event
			if not event or not self:needsLive(event) then
				break
			end

			task.wait(self:liveDelay(event))
			if item.dead then
				break
			end

			event = item.event
			if not event or not self:needsLive(event) then
				break
			end

			self:refreshItem(item, event)
		end

		item.liveRunning = false
	end)
end

local function pinnedOrder(item)
	if not item.event or not item.event.pinned then
		return nil
	end

	return tonumber(item.event.order) or 0
end

function Render:insertItem(item)
	local order = pinnedOrder(item)
	if order ~= nil then
		local index = 1
		while index <= #self.items do
			local otherOrder = pinnedOrder(self.items[index])
			if otherOrder == nil or order < otherOrder then
				break
			end
			index += 1
		end

		table.insert(self.items, index, item)
		return
	end

	local index = 1
	while index <= #self.items and pinnedOrder(self.items[index]) ~= nil do
		index += 1
	end

	table.insert(self.items, index, item)
end

function Render:regularItemCount()
	local count = 0
	for _, item in self.items do
		if pinnedOrder(item) == nil then
			count += 1
		end
	end

	return count
end

function Render:trimItems()
	while self:regularItemCount() > self.config.maxItems do
		for index = #self.items, 1, -1 do
			local item = self.items[index]
			if pinnedOrder(item) == nil then
				table.remove(self.items, index)
				item.dead = true
				self.motion:cancel(item.frame)
				self:dropKey(item)
				item.frame:Destroy()
				break
			end
		end
	end
end

function Render:makeItem(event)
	self.serial += 1

	local line = self.format:eventLine(event)
	local frame, label, width = self:buildRow(line, `Lori_{self.serial}`)
	local offscreen = self:offscreenPosition(width)
	frame.Position = UDim2.new(offscreen.X.Scale, offscreen.X.Offset, 0, self:rowY(1))
	label.TextTransparency = 1

	local item = {
		key = event.key,
		frame = frame,
		label = label,
		width = width,
		dead = false,
		event = event,
		liveRunning = false,
	}
	self:insertItem(item)
	if event.key then
		self.keyed[event.key] = item
	end

	self:trimItems()

	imports.Bar.sync(self, item, true)
	self:layout()
	self:fadeIn(label)

	if not event.sticky and event.progress ~= true then
		task.delay(event.duration or 3.2, function()
			self:destroyItem(item)
		end)
	end

	self:startLive(item)
end

function Render:updateItem(item, event)
	item.event = event
	self:refreshItem(item, event)
	imports.Bar.sync(self, item, false)
	self:startLive(item)
end

function Render:destroyItem(item)
	if item.dead then
		return
	end
	item.dead = true

	local frame = item.frame
	local offscreen = self:offscreenPosition(item.width)
	self.motion:to(frame, "move", {
		Position = UDim2.new(offscreen.X.Scale, offscreen.X.Offset, 0, frame.Position.Y.Offset),
	}, self.config.exitTime)

	task.delay(self.config.exitTime + 0.04, function()
		local index = table.find(self.items, item)
		if index then
			table.remove(self.items, index)
		end
		self:dropKey(item)
		self.motion:cancel(frame)
		frame:Destroy()
		self:layout()
	end)
end

function Render:mount(parent)
	parent = resolveParent(parent)
	if not parent then
		return
	end
	if self.mounted and self.gui and self.gui.Parent then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "Lori"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = self.config.displayOrder
	gui.Enabled = self.config.uiVisible ~= false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = parent

	local stack = Instance.new("Frame")
	stack.Name = "Stack"
	local anchorPoint, position = resolveAnchor(self.config.anchor)

	local xOffset = if anchorPoint.X == 1 then -self.config.rightOffset else self.config.leftOffset

	local yOffset = if anchorPoint.Y == 1 then -self.config.bottomOffset else self.config.topOffset

	stack.AnchorPoint = anchorPoint
	stack.Position = position + UDim2.fromOffset(xOffset, yOffset)
	stack.Size = UDim2.fromOffset(self:scaled(self.config.minWidth), self:scaled(self.config.rowHeight))
	stack.BackgroundTransparency = 1
	stack.BorderSizePixel = 0
	stack.Parent = gui

	self.gui = gui
	self.stack = stack
	self.tooltip = imports.Tooltip.new(self)
	self.graph = imports.Graph.new(self)
	
	self:updateScale()
	self:updateStackSize()
	self:bindViewport()
	
	self.mounted = true
end

function Render:unmount()
	for _, item in self.items do
		item.dead = true
	end

	table.clear(self.items)
	table.clear(self.keyed)

	if self.viewportConnection then
		self.viewportConnection:Disconnect()
	end
	if self.cameraConnection then
		self.cameraConnection:Disconnect()
	end

	if self.tooltip then
		self.tooltip:destroy()
	end
	if self.gui then
		self.gui:Destroy()
	end

	self.gui = nil
	self.stack = nil
	self.tooltip = nil
	self.graph = nil
	self.viewportConnection = nil
	self.cameraConnection = nil
	self.scale = 1
	self.mounted = false
end

function Render:push(event)
	if not self.stack then
		return
	end

	local existing = event and event.key and self.keyed[event.key]
	if existing and not existing.dead then
		self:updateItem(existing, event)
		return
	end

	self:makeItem(event or { action = "event" })
end

function Render:dismiss(key)
	local item = self.keyed[key]
	if item then
		self:destroyItem(item)
	end
end

function Render:clear()
	for _, item in ipairs(table.clone(self.items)) do
		self:destroyItem(item)
	end
	if self.graph then
		self.graph:clear()
	end
end

function Render:makeGraph(name, options)
	if self.graph then
		self.graph:make(name, options)
	end
end

function Render:pushGraph(name, value)
	if self.graph then
		self.graph:push(name, value)
	end
end

function Render:rescaleGraph(name, factor)
	if self.graph then
		self.graph:rescale(name, factor)
	end
end

function Render:removeGraph(name)
	if self.graph then
		self.graph:remove(name)
	end
end

return Render
