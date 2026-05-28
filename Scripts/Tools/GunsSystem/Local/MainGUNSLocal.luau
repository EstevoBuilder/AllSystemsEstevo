local MainGUNSLocal = {}

-- Services
local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

-- Player & Camera Configuration References
local player = game.Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera
local GUNS_MODULE = require(ReplicatedStorage.Modules.GunsInfo)

-- Design Matrices Tuning Parameters
local SMOOTHNESS = 0.15
local CAMERA_OFFSET = Vector3.new(3, 0.5, -2) 
local LOCKED_ZOOM_DISTANCE = 10 
local NORMAL_FOV = 70
local AIM_FOV = 40

--[[
    Handles instance cloning, tracking setups, and self-destruction parameters for 3D audios.
]]
local function playSound(Sound, destin, Speed)
	local CloneSound = Sound:Clone()
	CloneSound.Parent = destin
	CloneSound.PlaybackSpeed = Speed
	CloneSound:Play()
	Debris:AddItem(CloneSound, CloneSound.TimeLength)
end

--[[
    Assembles a physical data exclusion list containing live player models to bypass projectile impacts.
]]
local function getIgnoreList()
	local ignoreList = {}
	
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(ignoreList, p.Character)
		end
	end
	
	return ignoreList
end

--[[
    Core Initialization Pipeline for active weapons containing physics, input mappings, and local simulations.
    @param Tool Tool: The interactive physical item to attach weapon handlers to.
]]
function MainGUNSLocal.GunsLocalFunction(Tool)
	local InfoTool = GUNS_MODULE.GeneralInfo[Tool.Name]
	if not InfoTool then return end
	
	local SoundsTool = InfoTool.Sounds
	local AnimationsTool = InfoTool.Animations
	local loadedTracks = {}
	
	-- Stateful Flag Trackers
	local isEquipped = false
	local isAiming = false 
	local isFiring = false
	local lastShotTime = 0
	local recoilOffset = Vector2.new(0, 0)

	-- Dynamic Active Connections Containers
	local renderConnection = nil
	local inputBeganConnection = nil
	local inputEndedConnection = nil

	-- Helper interpolator handling smooth zoom transition updates
	local function TweenFOV(targetFOV)
		local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(camera, tweenInfo, {FieldOfView = targetFOV}):Play()
	end

	local function StopAllAnimations()
		for _, track in pairs(loadedTracks) do track:Stop() end
	end

	local function LoadAnimations(Character)
		local Humanoid = Character:WaitForChild("Humanoid")
		local Animator = Humanoid:WaitForChild("Animator")
		for _, track in pairs(loadedTracks) do track:Destroy() end
		loadedTracks = {}

		loadedTracks["Hold"] = Animator:LoadAnimation(AnimationsTool.Hold)
		loadedTracks["Aim"] = Animator:LoadAnimation(AnimationsTool.Aim)
		loadedTracks["Fire"] = Animator:LoadAnimation(AnimationsTool.Fire)
		loadedTracks["Reload"] = Animator:LoadAnimation(AnimationsTool.Reload)
	end

	--[[
	    Main Raycast Engine: Gathers center viewport screen coordinates, processes spread vectors, and updates server states.
	]]
	local function shoot()
		local now = tick()
		if now - lastShotTime < InfoTool.Cadence then return end
		if loadedTracks["Reload"] and loadedTracks["Reload"].IsPlaying then return end

		local character = player.Character
		local rootPart = character and character:FindFirstChild("Head")
		local firePart = Tool.Handle:FindFirstChild("FirePart")

		if not rootPart or not firePart then return end

		lastShotTime = now

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = getIgnoreList()

		-- Project crosshair target coordinates directly outwards from viewport center coordinates
		local unitRay = camera:ViewportPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
		local range = InfoTool.Range or 500

		if InfoTool.Shot == "shard" then
			local hitParts = {}
			local endPositions = {}
			local pelletCount = InfoTool.Pellets or 8
			local spreadIntensity = InfoTool.Spread or 0.1

			-- Compute multi-ray scatter directions using random variance vectors
			for i = 1, pelletCount do
				local spread = Vector3.new(
					(math.random() - 0.5) * 2,
					(math.random() - 0.5) * 2,
					(math.random() - 0.5) * 2
				) * spreadIntensity

				local direction = (unitRay.Direction + spread).Unit * range
				local result = workspace:Raycast(rootPart.Position, direction, params)

				table.insert(hitParts, result and result.Instance or false) -- Swapped nil to false for clean RPC table parsing
				table.insert(endPositions, result and result.Position or (rootPart.Position + direction))
			end

			ReplicatedStorage.Events.FireEvent:FireServer(Tool, hitParts, endPositions, firePart.Position)
		else
			local baseDirection = unitRay.Direction * range
			local result = workspace:Raycast(rootPart.Position, baseDirection, params)
			local endPos = result and result.Position or (rootPart.Position + baseDirection)

			ReplicatedStorage.Events.FireEvent:FireServer(Tool, result and result.Instance or false, endPos, firePart.Position)
		end

		if loadedTracks["Fire"] then 
			loadedTracks["Fire"]:Play(0, 1, 1.2) 
		end

		-- Procedural Camera Shake / Recoil Kick Matrices Simulation
		local intensity = (InfoTool.Recoil or 10) / 100
		if isAiming then intensity = intensity * 0.5 end

		local upKick = (math.random(12, 18) / 10) * intensity 
		local sideKick = (math.random(-8, 8) / 10) * intensity
		recoilOffset = recoilOffset + Vector2.new(sideKick, upKick)
	end

	-- Setup Item Draw/Equip Handlers
	Tool.Equipped:Connect(function()
		local Character = player.Character
		if not Character then return end
		local Humanoid = Character:WaitForChild("Humanoid")
		local RootPart = Character:WaitForChild("HumanoidRootPart")

		playSound(SoundsTool["Equip"], Tool.Handle, 1)

		-- Tear down standard Roblox weld mechanics to bind weapon joints manually via Motor6D configurations
		local RightArm = Character:WaitForChild("Right Arm")
		local Grip = RightArm:FindFirstChild("RightGrip")
		if Grip then Grip:Destroy() end
		
		local Motor6D = Tool.Handle:FindFirstChild("Handle")
		if Motor6D then Motor6D.Part0 = RightArm end
		
		PlayerGui.MainGUI.AimFrame.Aim.Visible = true
		UserInputService.MouseIconEnabled = false 
		isEquipped = true
		LoadAnimations(Character)

		if loadedTracks["Hold"] then loadedTracks["Hold"]:Play() end

		player.CameraMaxZoomDistance = LOCKED_ZOOM_DISTANCE
		player.CameraMinZoomDistance = LOCKED_ZOOM_DISTANCE
		Humanoid.CameraOffset = CAMERA_OFFSET
		Humanoid.AutoRotate = false 
	
		if renderConnection then renderConnection:Disconnect() end
		renderConnection = RunService.RenderStepped:Connect(function(dt)
			if isEquipped and Character and RootPart then
				UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
				
				-- Linearly interpolate character horizontal facing angles to face current camera forward targets
				local camLook = camera.CFrame.LookVector
				local targetAngle = math.atan2(-camLook.X, -camLook.Z)
				local targetCFrame = CFrame.new(RootPart.Position) * CFrame.Angles(0, targetAngle, 0)
				RootPart.CFrame = RootPart.CFrame:Lerp(targetCFrame, SMOOTHNESS)

				-- Decay camera recoil offsets smoothly back to baseline coordinate targets over time
				recoilOffset = recoilOffset:Lerp(Vector2.new(0, 0), dt * 10)
				camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(recoilOffset.Y), math.rad(recoilOffset.X), 0)
			end
		end)

		if inputBeganConnection then inputBeganConnection:Disconnect() end
		inputBeganConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed or not isEquipped then return end
			
			if input.UserInputType == Enum.UserInputType.MouseButton2 then
				isAiming = true
				if loadedTracks["Aim"] then loadedTracks["Aim"]:Play(0.1) end
				TweenFOV(AIM_FOV)
			end

			if input.KeyCode == Enum.KeyCode.R then
				local reloadTrack = loadedTracks["Reload"]
				if reloadTrack and not reloadTrack.IsPlaying then
					isFiring = false -- Cease fire simulation sequence instantly upon initiating tool reloads
					if loadedTracks["Fire"] then loadedTracks["Fire"]:Stop() end
					reloadTrack:Play()
					playSound(SoundsTool["Reload"], Tool.Handle, InfoTool.TimerSoundReload)
					ReplicatedStorage.Events.ReloadEvent:FireServer(Tool)
				end
			end
		end)

		if inputEndedConnection then inputEndedConnection:Disconnect() end
		inputEndedConnection = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton2 then
				isAiming = false
				if loadedTracks["Aim"] then loadedTracks["Aim"]:Stop(0.1) end
				TweenFOV(NORMAL_FOV)
			end
			
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				isFiring = false
			end
		end)
	end)

	-- Setup Item Holster/Unequip Handlers
	Tool.Unequipped:Connect(function()
		isEquipped = false
		isAiming = false
		isFiring = false
		recoilOffset = Vector2.new(0, 0)
		
		StopAllAnimations()
		TweenFOV(NORMAL_FOV)
		
		UserInputService.MouseIconEnabled = true
		PlayerGui.MainGUI.AimFrame.Aim.Visible = false 
		
		if renderConnection then renderConnection:Disconnect(); renderConnection = nil end
		if inputBeganConnection then inputBeganConnection:Disconnect(); inputBeganConnection = nil end
		if inputEndedConnection then inputEndedConnection:Disconnect(); inputEndedConnection = nil end
		
		local Character = player.Character
		if Character then
			local Humanoid = Character:FindFirstChild("Humanoid")
			if Humanoid then
				Humanoid.CameraOffset = Vector3.new(0, 0, 0)
				Humanoid.AutoRotate = true
			end
		end

		player.CameraMaxZoomDistance = 128
		player.CameraMinZoomDistance = 0.5
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end)
	
	-- Fire state action loop processing
	Tool.Activated:Connect(function()
		if isEquipped and not isFiring then
			isFiring = true
			
			while isFiring and isEquipped do
				local currentAmmo = Tool:GetAttribute("Ammo") or InfoTool.Magazine
				
				-- Automatically halt firing processing loop configurations if tool clip runs dry
				if currentAmmo <= 0 then
					isFiring = false
					if loadedTracks["Reload"] and not loadedTracks["Reload"].IsPlaying then
						loadedTracks["Reload"]:Play()
						playSound(SoundsTool["Reload"], Tool.Handle, InfoTool.TimerSoundReload)
						ReplicatedStorage.Events.ReloadEvent:FireServer(Tool)
					end
					break 
				end

				shoot()
				task.wait(InfoTool.Cadence)
				
				if InfoTool.TypeState ~= "Automatic" then 
					isFiring = false
					break 
				end
			end
		end
	end)

	-- Absolute cleanup routine to handle structural object destruction cycles
	Tool.Destroying:Connect(function()
		isFiring = false
		isEquipped = false
		if renderConnection then renderConnection:Disconnect() end
		if inputBeganConnection then inputBeganConnection:Disconnect() end
		if inputEndedConnection then inputEndedConnection:Disconnect() end
		for _, track in pairs(loadedTracks) do track:Destroy() end
	end)
end

-- Global tool instantiation connection listeners mapping structural initializers
player.CharacterAdded:Connect(function(char)
	char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child:HasTag("Gun") then
			if not child:GetAttribute("Initialized") then
				child:SetAttribute("Initialized", true)
				MainGUNSLocal.GunsLocalFunction(child)
			end
		end
	end)
end)

return MainGUNSLocal