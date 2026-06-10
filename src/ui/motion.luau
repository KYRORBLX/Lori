--[[
	@name motion
	@author dullflowerr
	@time June 7, 2026
]]

local imports = {
	TweenService = game:GetService("TweenService"),
}

local Motion = {}
Motion.__index = Motion

local function sameGoal(goal, other)
	if not goal then
		return false
	end

	for key, value in other do
		if goal[key] ~= value then
			return false
		end
	end
	for key in goal do
		if other[key] == nil then
			return false
		end
	end

	return true
end

function Motion.new(config)
	return setmetatable({
		config = config,
		tracks = setmetatable({}, { __mode = "k" }),
	}, Motion)
end

function Motion:track(instance)
	local track = self.tracks[instance]
	if not track then
		track = {}
		self.tracks[instance] = track
	end

	return track
end

function Motion:to(instance, channel, goal, time, style)
	local track = self:track(instance)
	local active = track[channel]

	if active and not active.done and sameGoal(active.goal, goal) then
		return active.tween
	end

	if active then
		active.tween:Cancel()
	end

	local info = TweenInfo.new(time or self.config.motionTime, style or self.config.motionStyle, Enum.EasingDirection.Out)
	local record = { goal = goal, tween = imports.TweenService:Create(instance, info, goal), done = false }
	track[channel] = record

	record.tween.Completed:Once(function()
		record.done = true
	end)

	record.tween:Play()
	return record.tween
end

function Motion:cancel(instance, channel)
	local track = self.tracks[instance]
	if not track then
		return
	end

	if channel then
		local active = track[channel]
		if active then
			active.tween:Cancel()
			track[channel] = nil
		end

		return
	end

	for _, active in track do
		active.tween:Cancel()
	end

	self.tracks[instance] = nil
end

return Motion
