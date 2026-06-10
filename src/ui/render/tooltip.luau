--[[
	@name tooltip
	@author dullflowerr
	@time June 10, 2026
]]

local imports = {
	UserInputService = game:GetService("UserInputService"),
}

local Tooltip = {}
Tooltip.__index = Tooltip

local function isCopyChord()
	local input = imports.UserInputService
	return input:IsKeyDown(Enum.KeyCode.LeftControl)
		or input:IsKeyDown(Enum.KeyCode.RightControl)
		or input:IsKeyDown(Enum.KeyCode.LeftMeta)
		or input:IsKeyDown(Enum.KeyCode.RightMeta)
end

function Tooltip.new(render)
	local self = setmetatable({
		inputConnection = nil,
		render = render,
		copyBox = nil,
		shadow = nil,
		target = nil,
		label = nil,
	}, Tooltip)

	self:build()
	return self
end

function Tooltip:build()
	local render = self.render

	local shadow = Instance.new("ImageLabel")
	shadow.Name = "TooltipShadow"
	shadow.AnchorPoint = Vector2.new(0.5, 1)
	shadow.BackgroundTransparency = 1
	shadow.Image = "rbxassetid://1316045217"
	shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
	shadow.ImageTransparency = 1
	shadow.ScaleType = Enum.ScaleType.Slice
	shadow.SliceCenter = Rect.new(10, 10, 118, 118)
	shadow.Visible = false
	shadow.ZIndex = 5
	shadow.Parent = render.stack

	local label = Instance.new("TextLabel")
	label.Name = "Tooltip"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.FontFace = render.config.font
	label.RichText = false
	label.TextColor3 = render.theme.text
	label.TextSize = render.config.textSize
	label.TextTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Visible = false
	label.ZIndex = 6
	label.Size = UDim2.new()
	label.Parent = render.stack

	local padding = Instance.new("UIPadding")
	padding.Parent = label
	render:syncPadding(padding)

	local corner = Instance.new("UICorner")
	corner.CornerRadius = render:cornerRadius()
	corner.Parent = label

	local copyBox = Instance.new("TextBox")
	copyBox.Name = "CopySource"
	copyBox.BackgroundTransparency = 1
	copyBox.ClearTextOnFocus = false
	copyBox.Size = UDim2.fromOffset(1, 1)
	copyBox.TextEditable = false
	copyBox.TextTransparency = 1
	copyBox.Parent = render.gui

	self.shadow = shadow
	self.label = label
	self.copyBox = copyBox

	self.inputConnection = imports.UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.C and isCopyChord() and copyBox:IsFocused() then
			self:flash("copied")
		end
	end)
end

function Tooltip:position()
	local render = self.render
	local textWidth = self.label.AbsoluteSize.X
	local textHeight = self.label.AbsoluteSize.Y
	local stackPosition = render.stack.AbsolutePosition
	local stackSize = render.stack.AbsoluteSize
	local mouse = imports.UserInputService:GetMouseLocation()

	local x = mouse.X - stackPosition.X
	local y = mouse.Y - stackPosition.Y - textHeight - render:scaled(34)

	x = math.clamp(x, math.floor(textWidth / 2), stackSize.X - math.floor(textWidth / 2))
	y = math.clamp(y, textHeight, stackSize.Y)

	local shadowPad = render:scaled(4)
	self.shadow.Size = UDim2.fromOffset(textWidth + shadowPad, textHeight + shadowPad)

	render.motion:to(self.label, "tooltipMove", {
		Position = UDim2.fromOffset(x, y),
	}, 0.1)

	render.motion:to(self.shadow, "tooltipMove", {
		Position = UDim2.fromOffset(x, y + math.floor(shadowPad / 2)),
	}, 0.1)
end

function Tooltip:show(text)
	local render = self.render
	self.label.Text = text
	self:position()
	self.label.Visible = true
	self.shadow.Visible = true

	render.motion:to(self.label, "fade", {
		TextTransparency = 0,
	}, render.config.fadeTime)

	render.motion:to(self.shadow, "fade", {
		ImageTransparency = 0.88,
	}, render.config.fadeTime)
end

function Tooltip:hide()
	local render = self.render
	self.target = nil

	render.motion:to(self.label, "fade", {
		TextTransparency = 1,
	}, render.config.fadeTime)

	render.motion:to(self.shadow, "fade", {
		ImageTransparency = 1,
	}, render.config.fadeTime)

	task.delay(render.config.fadeTime, function()
		if self.target == nil and self.label.Parent then
			self.label.Visible = false
			self.shadow.Visible = false
		end
	end)
end

function Tooltip:flash(text)
	self:show(text)
	task.delay(1.1, function()
		if self.label.Text == text and self.target == nil then
			self:hide()
		end
	end)
end

function Tooltip:select(text)
	local box = self.copyBox
	box.Text = text
	task.defer(function()
		box:CaptureFocus()
		box.SelectionStart = 1
		box.CursorPosition = #box.Text + 1
	end)
end

function Tooltip:attach(frame, label)
	if self.render.config.copyEnabled == false then
		return
	end

	frame.Active = true

	frame.MouseEnter:Connect(function()
		self.target = frame
		self:select(label.ContentText)
		self:show("ctrl+c")
	end)

	frame.MouseMoved:Connect(function()
		if self.target == frame then
			self:position()
		end
	end)

	frame.MouseLeave:Connect(function()
		if self.target == frame then
			self:hide()
			self.copyBox:ReleaseFocus()
		end
	end)
end

function Tooltip:applyTheme()
	self.label.TextColor3 = self.render.theme.text
end

function Tooltip:destroy()
	if self.inputConnection then
		self.inputConnection:Disconnect()
		self.inputConnection = nil
	end

	self.label:Destroy()
	self.shadow:Destroy()
	self.copyBox:Destroy()
end

return Tooltip
