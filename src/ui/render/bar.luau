--[[
	@name bar
	@author dullflowerr
	@time June 10, 2026
]]

local Bar = {}

local function toneColor(render, event)
	return render.theme[event.tone] or render.theme.trace
end

local function barHeight(render)
	return math.max(2, render:scaled(render.config.rowHeight * 0.35))
end

local function padY(render)
	return render:scaled(render.config.padX * 0.49)
end

local function segmentGap(render)
	return math.max(1, render:scaled(1))
end

local function segmentCount(render, width, gap)
	local target = math.max(4, render:scaled(render.config.progressSegmentWidth or 10))
	return math.max(3, math.floor((width + gap) / (target + gap)))
end

local function buildSegments(render, parent, count, transparency)
	local radius = UDim.new(0, render:scaled(2))
	local segments = {}

	for index = 1, count do
		local segment = Instance.new("Frame")
		segment.Name = `Seg{index}`
		segment.BackgroundTransparency = transparency
		segment.BorderSizePixel = 0

		local corner = Instance.new("UICorner")
		corner.CornerRadius = radius
		corner.Parent = segment

		segment.Parent = parent
		segments[index] = segment
	end

	return segments
end

local function build(render, item, progress)
	local track = Instance.new("Frame")
	track.Name = "Progress"
	track.AnchorPoint = Vector2.new(0, 1)
	track.BackgroundTransparency = 1
	track.BorderSizePixel = 0
	track.ZIndex = 2
	track.Parent = item.frame

	local fillClip = Instance.new("Frame")
	fillClip.Name = "FillClip"
	fillClip.BackgroundTransparency = 1
	fillClip.BorderSizePixel = 0
	fillClip.ClipsDescendants = true
	fillClip.Size = UDim2.new(if progress == true then 1 else 0, 0, 1, 0)
	fillClip.ZIndex = 3
	fillClip.Parent = track

	local fillInner = Instance.new("Frame")
	fillInner.Name = "Fill"
	fillInner.BackgroundTransparency = 1
	fillInner.BorderSizePixel = 0
	fillInner.Parent = fillClip

	item.barSegments = {
		track = {},
		fill = {},
	}

	item.barTrack = track
	item.barFill = fillClip
	item.barFillInner = fillInner
end

local function clear(render, item)
	if not item.barTrack then
		return
	end

	render.motion:cancel(item.barFill)
	item.barTrack:Destroy()
	item.barTrack = nil
	item.barFill = nil
	item.barFillInner = nil
	item.barSegments = nil
end

function Bar.extra(render, item)
	local event = item.event
	if not event or event.progress == nil then
		return 0
	end

	return barHeight(render) + padY(render)
end

function Bar.tint(render, item)
	local segments = item.barSegments
	if not segments or not item.event then
		return
	end

	local base = toneColor(render, item.event)
	local count = #segments.fill

	for index, segment in segments.fill do
		local amount = if count > 1 then (index - 1) / (count - 1) * 0.4 else 0
		local color = base:Lerp(render.theme.background, amount)
		segment.BackgroundColor3 = color
		segments.track[index].BackgroundColor3 = color
	end
end

local function rebuildSegments(render, item, count)
	for _, segment in item.barSegments.track do
		segment:Destroy()
	end
	for _, segment in item.barSegments.fill do
		segment:Destroy()
	end

	item.barSegments = {
		track = buildSegments(render, item.barTrack, count, 0.86),
		fill = buildSegments(render, item.barFillInner, count, 0.12),
	}

	Bar.tint(render, item)
end

function Bar.layout(render, item)
	local track = item.barTrack
	if not track then
		return
	end

	local padX = render:scaled(render.config.padX * 1.08)
	local height = barHeight(render)
	local width = math.max(0, math.floor(item.width - padX * 2))

	local gap = segmentGap(render)
	local count = segmentCount(render, width, gap)
	if #item.barSegments.fill ~= count then
		rebuildSegments(render, item, count)
	end

	local segments = item.barSegments
	local available = math.max(count, width - gap * (count - 1))
	local base = math.floor(available / count)
	local remainder = available - base * count

	track.Position = UDim2.new(0, padX, 1, -padY(render))
	track.Size = UDim2.fromOffset(width, height)
	item.barFillInner.Size = UDim2.fromOffset(width, height)

	local x = 0
	for index = 1, count do
		local segmentWidth = base + (if index <= remainder then 1 else 0)
		segments.track[index].Position = UDim2.fromOffset(x, 0)
		segments.track[index].Size = UDim2.fromOffset(segmentWidth, height)
		segments.fill[index].Position = UDim2.fromOffset(x, 0)
		segments.fill[index].Size = UDim2.fromOffset(segmentWidth, height)
		x += segmentWidth + gap
	end
end

function Bar.sync(render, item, fresh)
	local event = item.event
	local progress = event and event.progress

	if progress == nil then
		clear(render, item)
		return
	end

	if not item.barTrack or not item.barTrack.Parent then
		build(render, item, progress)
	end

	Bar.tint(render, item)
	Bar.layout(render, item)

	if progress == true then
		if fresh and not event.sticky then
			item.barFill.Size = UDim2.new(1, 0, 1, 0)
			local tween = render.motion:to(item.barFill, "progress", {
				Size = UDim2.new(0, 0, 1, 0),
			}, event.duration or 3.2, Enum.EasingStyle.Linear)

			tween.Completed:Once(function(state)
				if state == Enum.PlaybackState.Completed then
					render:destroyItem(item)
				end
			end)
		end
	else
		local value = math.clamp(tonumber(progress) or 0, 0, 1)
		render.motion:to(item.barFill, "progress", {
			Size = UDim2.new(value, 0, 1, 0),
		}, render.config.graphTweenTime)
	end
end

return Bar
