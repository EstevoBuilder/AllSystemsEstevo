local TweenService = game:GetService("TweenService")

local TweensModule = {}

-- Track structural debounces locally inside the module environment scope
local dbOpenFrame = false

--[[
    Asynchronously cycles a TextLabel's color properties across the HSV spectrum.
    @param textLabel TextLabel: The user interface graphical text container.
    @param duration number?: Complete cycle lifespan time elapsed before repeating.
]]
function TweensModule.RainbowText(textLabel, duration)
	local cycleDuration = duration or 3 

	task.spawn(function()
		-- Divide the total duration equally across the 3 target color nodes
		local segmentDuration = cycleDuration / 3
		local info = TweenInfo.new(segmentDuration, Enum.EasingStyle.Linear)

		local colors = {
			Color3.fromHSV(0.33, 0.8, 1), -- Green node spectrum boundary
			Color3.fromHSV(0.66, 0.8, 1), -- Blue node spectrum boundary
			Color3.fromHSV(1, 0.8, 1)    -- Red node spectrum boundary
		}

		-- Safe-loop execution boundary checking if UI object lifecycle terminates
		while textLabel and textLabel.Parent do
			for _, targetColor in ipairs(colors) do
				if not (textLabel and textLabel.Parent) then break end

				local tween = TweenService:Create(textLabel, info, {TextColor3 = targetColor})
				tween:Play()
				tween.Completed:Wait() -- Block execution threat context safely until segment arrival
			end
		end
	end)
end

--[[
    Triggers an elastic popup interpolation size animation scaling on an interface canvas frame.
    @param frame GuiObject: The container asset being brought into visibility.
    @param duration number: Total transformation timeframe window.
]]
function TweensModule.OpenFrame(frame, duration)
	if dbOpenFrame then return end
	dbOpenFrame = true
	
	-- Automatically clear layout interaction restrictions when the animation timeline finishes
	task.delay(duration, function()
		dbOpenFrame = false
	end)
	
	frame.Visible = true
	
	-- CRITICAL ARCHITECTURE FIX: Read absolute baseline dimensions safely via attributes
	local originalSize = frame:GetAttribute("BaseSize")
	if not originalSize then
		originalSize = frame.Size
		frame:SetAttribute("BaseSize", originalSize)
	end
	
	frame.Size = UDim2.new(0, 0, 0, 0)

	local info = TweenInfo.new(
		duration, 
		Enum.EasingStyle.Back,
		Enum.EasingDirection.Out
	)

	local goals = {
		Size = originalSize
	}

	local tween = TweenService:Create(frame, info, goals)
	tween:Play()
end

--[[
    Establishes a continuous loop that rotates and scales an object.
    @param Object GuiObject: The interface canvas item to apply environmental idle animations to.
]]
function TweensModule.RotationAndPulse(Object)
	-- Parameters configured with a -1 repetition count and true reverse value for native infinite ping-pong playback loops
	local infoPulse = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

	-- CRITICAL ARCHITECTURE FIX: Store static baseline dimension to prevent multiplicative size explosion bugs
	local baseSize = Object:GetAttribute("BaseSize")
	if not baseSize then
		baseSize = Object.Size
		Object:SetAttribute("BaseSize", baseSize)
	end

	local tamanhoEfeito = baseSize + UDim2.fromScale(0.05, 0.05)

	local tweenRotacionarIcone = TweenService:Create(Object, infoPulse, {Rotation = 90})
	local tweenEfeito = TweenService:Create(Object, infoPulse, {Size = tamanhoEfeito})

	tweenEfeito:Play()
	tweenRotacionarIcone:Play()
end

return TweensModule