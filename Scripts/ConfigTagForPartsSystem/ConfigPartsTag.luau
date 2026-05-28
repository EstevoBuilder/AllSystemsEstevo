local ConfigPartsTag = {}

-- Services
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local PhysicsService = game:GetService("PhysicsService")

-- Assets
local Sounds = ReplicatedStorage:WaitForChild("Sounds")

-- State Cache & Debounces
local activeDebounces = {}
local configuredObjects = {}
local damageDebounce = {}

--[[
    Configures specific collision groups and ensures designated tagged objects 
    do not collide with each other.
]]
function ConfigPartsTag.SetupCollisionGroups()
	local collisionTags = {
		["Map6NoCollide"] = "NoCollisionMovingGroup",
	}

	for tagName, groupName in pairs(collisionTags) do
		pcall(function()
			PhysicsService:RegisterCollisionGroup(groupName)
		end)

		PhysicsService:CollisionGroupSetCollidable(groupName, groupName, false)

		local function setGroup(instance)
			if instance:IsA("BasePart") then
				instance.CollisionGroup = groupName
			elseif instance:IsA("Model") then
				for _, descendant in ipairs(instance:GetDescendants()) do
					if descendant:IsA("BasePart") then
						descendant.CollisionGroup = groupName
					end
				end
			end
		end

		-- Apply collision groups to existing and newly added tagged instances
		for _, instance in ipairs(CollectionService:GetTagged(tagName)) do
			setGroup(instance)
		end

		CollectionService:GetInstanceAddedSignal(tagName):Connect(setGroup)
	end
end

--[[
    Handles damaging players upon touching a registered kill part.
    Includes custom visual and audio feedback specifically for "Lava" parts.
    @param part BasePart: The physical hazard part.
    @param tagName string: The tag associated with this functional behavior.
]]
function ConfigPartsTag.DamagePart(part: BasePart, tagName: string)
	if not configuredObjects[part] then
		configuredObjects[part] = {}
	end

	if configuredObjects[part][tagName] then
		return
	end

	configuredObjects[part][tagName] = true

	part.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then return end

		local humanoid = character:FindFirstChild("Humanoid")
		local rootPart = character:FindFirstChild("HumanoidRootPart")

		-- Retrieve dynamic damage value from attributes, defaulting to 100 (Instakill)
		local Damage = part:GetAttribute("Damage") or 100

		if humanoid and rootPart and not damageDebounce[character] then
			damageDebounce[character] = true

			humanoid:TakeDamage(Damage)

			-- Custom behavior for special Lava traps
			if part.Name == "Lava" then
				local attachment = Instance.new("Attachment")
				attachment.Orientation = Vector3.new(90, 0, 0)
				attachment.Parent = workspace

				-- Delayed position sync to capture final death location accurately
				task.delay(0.1, function()
					if rootPart and rootPart.Parent then
						attachment.WorldPosition = rootPart.Position
					end
				end)

				local deathLavaSound = Sounds:FindFirstChild("DeathLava")
				if deathLavaSound then
					local SoundClone = deathLavaSound:Clone()
					SoundClone.Parent = rootPart
					SoundClone:Play()
					Debris:AddItem(SoundClone, SoundClone.TimeLength)
				end

				local VFXs = ReplicatedStorage:FindFirstChild("VFX")
				if VFXs and VFXs:FindFirstChild("VFXdeathLava") then
					for _, vfx in VFXs.VFXdeathLava:GetChildren() do
						local clone = vfx:Clone()
						clone.Parent = attachment

						if clone:IsA("ParticleEmitter") then
							clone:Emit(clone:GetAttribute("EmitCount") or 10)
						end
					end
				end

				-- Cosmetic dissolution: Strip clothes/accessories and turn character into charcoal
				for _, item in character:GetDescendants() do
					if item:IsA("Accessory")
						or item:IsA("Shirt")
						or item:IsA("Pants")
						or item:IsA("ShirtGraphic")
						or item:IsA("Decal") then

						item:Destroy()

					elseif item:IsA("BasePart") then
						item.Color = Color3.fromRGB(0, 0, 0)
						item.Material = Enum.Material.CrackedLava
					end
				end

				Debris:AddItem(attachment, 3)
			end

			task.delay(0.5, function()
				damageDebounce[character] = nil
			end)
		end
	end)
end

--[[
    Applies a physics-based directional impulse vector when a player touches the part.
    @param part BasePart: The knockback source.
    @param tagName string: The tag associated with this functional behavior.
]]
function ConfigPartsTag.KnockbackPart(part: BasePart, tagName: string)
	if not configuredObjects[part] then
		configuredObjects[part] = {}
	end

	if configuredObjects[part][tagName] then
		return
	end

	configuredObjects[part][tagName] = true

	part.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then return end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local rootPart = character:FindFirstChild("HumanoidRootPart")

		if rootPart and humanoid and humanoid.Health > 0 and not activeDebounces[character] then
			activeDebounces[character] = true

			local forcePower = part:GetAttribute("KnockbackForce") or 100
			local upwardForce = part:GetAttribute("UpwardForce") or 50

			local bonkSound = Sounds:FindFirstChild("Bonk")
			if bonkSound then
				local SoundClone = bonkSound:Clone()
				SoundClone.Parent = part
				SoundClone:Play()
				Debris:AddItem(SoundClone, SoundClone.TimeLength)
			end

			-- Calculate directional vectors away from the center of the part
			local direction = (rootPart.Position - part.Position).Unit
			local velocityVector = (direction * forcePower) + Vector3.new(0, upwardForce, 0)

			local attachment = Instance.new("Attachment")
			attachment.Parent = rootPart

			-- Apply modern Mover Constraint for reliable physics pushing
			local lv = Instance.new("LinearVelocity")
			lv.MaxForce = 9999999
			lv.VectorVelocity = velocityVector
			lv.RelativeTo = Enum.ActuatorRelativeTo.World
			lv.Attachment0 = attachment
			lv.Parent = rootPart

			Debris:AddItem(lv, 0.5)
			Debris:AddItem(attachment, 0.5)

			task.wait(0.5)
			activeDebounces[character] = nil
		end
	end)
end

--[[
    Simulates a continuous wind zone/fan that forces players upward or outward.
    @param part BasePart: The fan zone detector.
    @param tagName string: The tag associated with this functional behavior.
]]
function ConfigPartsTag.FanPart(part: BasePart, tagName: string)
	if not configuredObjects[part] then
		configuredObjects[part] = {}
	end

	if configuredObjects[part][tagName] then
		return
	end

	configuredObjects[part][tagName] = true

	local objectsInWind = {}

	local windSound = Sounds:FindFirstChild("Wind")
	if windSound then
		local SoundClone = windSound:Clone()
		SoundClone:Play()
		SoundClone.Parent = part
	end

	-- Add characters entering the zone
	part.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then return end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			objectsInWind[character] = rootPart
		end
	end)

	-- Remove characters leaving the zone
	part.TouchEnded:Connect(function(hit)
		local character = hit.Parent
		if not character then return end

		if character:FindFirstChild("HumanoidRootPart") then
			objectsInWind[character] = nil
		end
	end)

	-- WARNING: Performance bottleneck. See code review notes below.
	RunService.Heartbeat:Connect(function()
		local forceAmount = part:GetAttribute("Force") or 100
		local direction = part.CFrame.UpVector

		for character, rootPart in pairs(objectsInWind) do
			if not character or not character.Parent or not rootPart or not rootPart.Parent then
				objectsInWind[character] = nil
			else
				rootPart.AssemblyLinearVelocity = direction * forceAmount
			end
		end
	end)
end

--[[
    Handles linear moving platforms that cycle indefinitely between Point A and Point B.
]]
function ConfigPartsTag.Platform(part, tagName: string)
	if not configuredObjects[part] then
		configuredObjects[part] = {}
	end

	if configuredObjects[part][tagName] then
		return
	end

	configuredObjects[part][tagName] = true

	local Apoint = part:FindFirstChild("A")
	local Bpoint = part:FindFirstChild("B")
	local Platform = part:FindFirstChild("Part")

	if not (Apoint and Bpoint and Platform) then
		return
	end

	local speed = part:GetAttribute("Speed") or 10
	local pauseTime = part:GetAttribute("PauseTime") or 1

	task.spawn(function()
		task.wait()

		Platform.Anchored = true
		Platform.Position = Apoint.Position

		local target = Bpoint

		while part.Parent do
			local distance = (target.Position - Platform.Position).Magnitude
			local timeToTravel = distance / speed

			local tweenInfo = TweenInfo.new(
				timeToTravel,
				Enum.EasingStyle.Linear,
				Enum.EasingDirection.InOut
			)

			local tween = TweenService:Create(Platform, tweenInfo, {
				Position = target.Position
			})

			-- Set linear assembly velocity to smoothly carry standing players with physics
			local direction = (target.Position - Platform.Position).Unit
			Platform.AssemblyLinearVelocity = direction * speed

			tween:Play()
			tween.Completed:Wait()

			Platform.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			task.wait(pauseTime)

			-- Toggle destination target
			target = (target == Bpoint) and Apoint or Bpoint
		end
	end)
end

--[[
    Forces any character who touches this part to transition into a sitting state.
]]
function ConfigPartsTag.Seat(part: BasePart, tagName: string)
	if not configuredObjects[part] then
		configuredObjects[part] = {}
	end

	if configuredObjects[part][tagName] then
		return
	end

	configuredObjects[part][tagName] = true

	part.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then return end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Sit = true
		end
	end)
end

--[[
    Continuously rotates parts on the Y-Axis.
    CRITICAL PERFORMANCE WARNING: See code review notes below regarding this logic.
]]
function ConfigPartsTag.Rotate(part: BasePart, tagName: string)
	if not configuredObjects[part] then
		configuredObjects[part] = {}
	end

	if configuredObjects[part][tagName] then
		return
	end

	configuredObjects[part][tagName] = true

	local ROTATION_SPEED = math.rad(360)

	RunService.Heartbeat:Connect(function(dt)
		local taggedParts = CollectionService:GetTagged("RotateServer")

		for _, instance in ipairs(taggedParts) do
			if instance:IsA("BasePart") then
				instance.CFrame = instance.CFrame * CFrame.Angles(0, ROTATION_SPEED * dt, 0)
			end
		end
	end)
end

--[[
    Handles continuous rotational pivot adjustments for rope/swing obstacles.
]]
function ConfigPartsTag.RotateRope(part: BasePart, tagName: string)
	if not configuredObjects[part] then
		configuredObjects[part] = {}
	end

	if configuredObjects[part][tagName] then
		return
	end

	configuredObjects[part][tagName] = true

	local ROTATION_SPEED = math.rad(90)
	local connection

	connection = RunService.Heartbeat:Connect(function(dt)
		if not part or not part.Parent then
			connection:Disconnect()

			if configuredObjects[part] then
				configuredObjects[part][tagName] = nil
			end
			return
		end

		local currentPivot = part:GetPivot()
		local rotation = CFrame.Angles(ROTATION_SPEED * dt, 0, 0)

		part:PivotTo(currentPivot * rotation)
	end)
end

--[[
    Handles cyclical 90-degree back-and-forth tweening rotations around a center pivot (Eixo).
]]
function ConfigPartsTag.Rotate90(part: BasePart, tagName: string)
	if not configuredObjects[part] then
		configuredObjects[part] = {}
	end

	if configuredObjects[part][tagName] then
		return
	end

	configuredObjects[part][tagName] = true

	local Eixo = part:FindFirstChild("Eixo")
	if not Eixo then return end

	local ROTATION_TIME = 0.5
	local tweenInfo = TweenInfo.new(
		ROTATION_TIME,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut,
		0,
		true
	)

	task.spawn(function()
		task.wait()

		local startCFrame = CFrame.new(Eixo.Position) * CFrame.Angles(0, math.rad(180), 0)
		local goalCFrame = startCFrame * CFrame.Angles(0, 0, math.rad(90))

		Eixo.CFrame = startCFrame

		local tweenA = TweenService:Create(Eixo, tweenInfo, {CFrame = goalCFrame})
		local tweenB = TweenService:Create(Eixo, tweenInfo, {CFrame = startCFrame})

		while part.Parent do
			tweenA:Play()
			tweenA.Completed:Wait()

			tweenB:Play()
			tweenB.Completed:Wait()
		end
	end)
end

--[[
    Automates a snow cannon turret that fires physics-driven snowball parts at a constant rate.
]]
function ConfigPartsTag.CanhaoNeve(part: BasePart, tagName: string)
	if not part:IsDescendantOf(game.Workspace) then
		return
	end

	if not configuredObjects[part] then
		configuredObjects[part] = {}
	end

	if configuredObjects[part][tagName] then
		return
	end

	configuredObjects[part][tagName] = true

	local SPAWN_RATE = 3
	local SNOWBALL_SPEED = 100
	local SNOWBALL_LIFETIME = 5

	local spawner = part

	local function shootSnowball()
		local snowball = Instance.new("Part")

		snowball.Name = "Snowball"
		snowball.Size = Vector3.new(10, 10, 10)
		snowball.Shape = Enum.PartType.Ball
		snowball.Material = Enum.Material.Snow
		snowball.BrickColor = BrickColor.new("White")
		snowball.CanCollide = true

		-- Connect automatically to the Seat logic via Tag replication
		CollectionService:AddTag(snowball, "Seat")

		snowball.CFrame = spawner.CFrame
		snowball.Parent = game.Workspace

		local direction = spawner.CFrame.LookVector
		snowball.AssemblyLinearVelocity = direction * SNOWBALL_SPEED

		Debris:AddItem(snowball, SNOWBALL_LIFETIME)
	end

	task.spawn(function()
		while part.Parent do
			shootSnowball()
			task.wait(SPAWN_RATE)
		end
	end)
end

--[[
    Temporarily increases a player's WalkSpeed while standing on ice terrain blocks.
]]
function ConfigPartsTag.WalkIce(part: BasePart)
	local icePart = part

	icePart.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then return end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 24
		end
	end)

	icePart.TouchEnded:Connect(function(hit)
		local character = hit.Parent
		if not character then return end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 16
		end
	end)
end

--[[
    Determines type safety compliance before passing an instance into a custom behavior handler.
]]
local function handleInstance(instance, func, tagName)
	if instance:IsA("BasePart") or instance:IsA("Model") then
		func(instance, tagName)
	end
end

-- Collection Service Tag Mapping Configuration
local TAG_MAP = {
	["KillPart"] = ConfigPartsTag.DamagePart,
	["FanPart"] = ConfigPartsTag.FanPart,
	["KnockbackPart"] = ConfigPartsTag.KnockbackPart,
	["Platform"] = ConfigPartsTag.Platform,
	["Seat"] = ConfigPartsTag.Seat,
	["RotateServer"] = ConfigPartsTag.Rotate,
	["Rotate90"] = ConfigPartsTag.Rotate90,
	["CanhaoNeve"] = ConfigPartsTag.CanhaoNeve,
	["RotateRope"] = ConfigPartsTag.RotateRope
}

--[[
    Initializes the system by loading setup data and anchoring connections.
]]
local function Init()
	ConfigPartsTag.SetupCollisionGroups()

	for tagName, func in pairs(TAG_MAP) do
		for _, instance in ipairs(CollectionService:GetTagged(tagName)) do
			handleInstance(instance, func, tagName)
		end

		CollectionService:GetInstanceAddedSignal(tagName):Connect(function(instance)
			handleInstance(instance, func, tagName)
		end)
	end
end

Init()

return ConfigPartsTag