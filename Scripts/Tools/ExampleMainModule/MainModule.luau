local ToolServerModule = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- Folder References
local SoundsFolder = ReplicatedStorage.Sounds.SoundsTool
local Events = ReplicatedStorage:WaitForChild("Events")
local Sounds = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("SoundsTool")
local Models = ReplicatedStorage:WaitForChild("ModelsForShop")

-- Modules
local ProfileService = require(ServerScriptService.Services.ProfileInitializer.ProfileService)

--[[
    Removes a single-use tool from the player's persistent database profile save slot.
    @param toolName string: The internal key of the tool to clear.
    @param player Player: The owner of the targeted save data profile.
]]
function removeToolInProfile(toolName, player)
	local profile = ProfileService.getProfile(player)
	if not profile then return end

	profile.ItensCoins[toolName] = nil
end

--[[
    Spawns, plays, and schedules automated garbage collection for 3D positional audio.
    @param soundName string: Instance name inside the global asset bank folder.
    @param parent Instance: The physical container object hosting the sound clone.
]]
function playSound(soundName, parent)
	local sound = SoundsFolder:FindFirstChild(soundName)
	if sound then
		local clone = sound:Clone()
		clone.Parent = parent
		clone:Play()
		Debris:AddItem(clone, clone.TimeLength)
	end
end

-- Micro-configuration maps containing tuning matrices for every interactive mechanics pipeline
local Config = {
	Grapple = {
		ToolName = "GrappleHook",
		Speed = 65,
		MaxForce = 300000,
		Cooldown = 5,
		MaxDistance = 115,
		ArrivalDist = 6,
		RopeDuration = 7,
	},

	EnderPearl = {
		ToolName = "EnderPearl",
		ThrowForce = 200,
		Lifetime = 10,
		LandOffset = Vector3.new(0, 3, 0),
	},

	Snowball = {
		ToolName = "Snowball", 
		MaxAmmo = 3,
		Speed = 100,
		KnockTime = 2,
		Cooldown = 0.5,
		Lifetime = 5,
	},

	Smoke = {
		ToolName = "Smoke",
		Duration = 120,
		Transition = 3,
		FogEnd = 120,
		FogColor = Color3.fromRGB(150, 150, 150),
	},

	SpeedCoil = {
		ToolName = "SpeedCoil",
		BOOST = 16
	},

	JumpPotion = {
		ToolName = "JumpPotion",
		duration = 90,
		NewJump = 70,
		BaseJump = 50
	},

	MeleeTool = {
		ToolName = "Slap Glove",
		FriendlyFire = false,
		HitWindup = 0.15,
		HitWindow = 0.75,
		SwingRestTime = 1,
	},

	Boombox = {
		ToolName = "Boombox"
	},
	
	Jetpack = {
		ToolName = "Jetpack",
		MaxFuel = 100,
		BurnRate = 40,
		RegenRate = 2,
		FlySpeed = 42,
	},
}

-- ============================================================================
-- GRAPPLE HOOK MECHANIC (Linear Vector Force Displacement Execution)
-- ============================================================================
do
	local cfg = Config.Grapple
	local remote = Events:WaitForChild("GrappleEvent")
	local cooldowns = {}

	-- Handles internal kinematic loops driving the player's root assembly forward
	local function pullCharacter(character, targetPos, ropeObjects)
		local hrp = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChild("Humanoid")

		if not hrp or not humanoid then return end

		playSound("GrappleHook", hrp)

		local attachment = Instance.new("Attachment")
		attachment.Parent = hrp

		local alignPos = Instance.new("AlignPosition")
		alignPos.Mode = Enum.PositionAlignmentMode.OneAttachment
		alignPos.Attachment0 = attachment
		alignPos.Position = targetPos
		alignPos.MaxForce = cfg.MaxForce
		alignPos.MaxVelocity = cfg.Speed
		alignPos.Responsiveness = 50
		alignPos.Parent = hrp

		local alignOrient = Instance.new("AlignOrientation")
		alignOrient.Mode = Enum.OrientationAlignmentMode.OneAttachment
		alignOrient.Attachment0 = attachment
		alignOrient.MaxTorque = 400000
		alignOrient.Responsiveness = 25
		alignOrient.Parent = hrp

		-- Maintain force execution loop until distance convergence or health failure registers
		while character.Parent and humanoid.Health > 0 do
			if not hrp.Parent then break end
			if (hrp.Position - targetPos).Magnitude <= cfg.ArrivalDist then break end

			alignOrient.CFrame = CFrame.new(
				hrp.Position,
				Vector3.new(targetPos.X, hrp.Position.Y, targetPos.Z)
			)
			task.wait()
		end

		if hrp and hrp.Parent then
			hrp.AssemblyLinearVelocity = Vector3.zero
		end

		alignPos:Destroy()
		alignOrient:Destroy()
		attachment:Destroy()

		for _, obj in ipairs(ropeObjects) do
			if obj and obj.Parent then obj:Destroy() end
		end
	end

	remote.OnServerEvent:Connect(function(player, hitPosition, hitPart)
		local now = os.clock()
		if now - (cooldowns[player] or 0) < cfg.Cooldown then return end

		local character = player.Character
		if not character or not hitPart or not hitPart.Parent then return end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then return end

		local tool = character:FindFirstChild(cfg.ToolName)
		if not tool then return end

		local origin = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm") or character:FindFirstChild("HumanoidRootPart")
		if not origin then return end

		-- Distance validation preventing infinite range exploits via network alterations
		if (origin.Position - hitPosition).Magnitude > cfg.MaxDistance then return end

		cooldowns[player] = now

		local a1 = Instance.new("Attachment")
		a1.Parent = origin

		local tip = tool:FindFirstChild("Handle") and tool.Handle:FindFirstChild("Ponta")
		if tip then a1.WorldPosition = tip.Position end

		local a2 = Instance.new("Attachment")
		a2.Parent = hitPart
		a2.WorldPosition = hitPosition

		local rope = Instance.new("RopeConstraint")
		rope.Attachment0 = a1
		rope.Attachment1 = a2
		rope.Visible = true
		rope.Thickness = 0.08
		rope.Color = BrickColor.new("Burnt Sienna")
		rope.Length = (a1.WorldPosition - hitPosition).Magnitude
		rope.Parent = character

		local ropeObjects = { rope, a1, a2 }
		for _, obj in ipairs(ropeObjects) do Debris:AddItem(obj, cfg.RopeDuration) end

		task.spawn(pullCharacter, character, hitPosition, ropeObjects)
	end)

	if Players.PlayerRemoving then
		Players.PlayerRemoving:Connect(function(player) cooldowns[player] = nil end)
	end
end

-- ============================================================================
-- ENDER PEARL MECHANIC (Projectile Physics & Safe Collision Teleportation)
-- ============================================================================
do
	local cfg = Config.EnderPearl
	local remote = Events:WaitForChild("ThrowEnderEvent")
	local pearlTemplate = Models:WaitForChild("EnderPearl")

	remote.OnServerEvent:Connect(function(player, direction)
		local character = player.Character
		if not character then return end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then return end

		local tool = character:FindFirstChild(cfg.ToolName) or player.Backpack:FindFirstChild(cfg.ToolName)
		if not tool then return end

		local handle = tool:FindFirstChild("Handle")
		if not handle then return end

		playSound("ThrowEnderPearl", rootPart)
		removeToolInProfile(tool.Name, player)
		tool:Destroy()

		local pearl = pearlTemplate:Clone()
		local pearlPart = pearl:FindFirstChild("Handle") or pearl:FindFirstChildOfClass("BasePart")

		if not pearlPart then
			pearl:Destroy()
			return
		end

		playSound("FinaleEnderPearl", pearlPart)
		pearl.Parent = workspace
		pearl:PivotTo(handle.CFrame)

		pearlPart.Anchored = false
		pearlPart.CanCollide = true
		pearlPart.Massless = false
		pearlPart:SetNetworkOwner(nil) -- Relinquish network ownership directly to server physics engine

		pearlPart.AssemblyLinearVelocity = Vector3.zero
		pearlPart.AssemblyAngularVelocity = Vector3.zero

		local impulse = direction.Unit * cfg.ThrowForce * pearlPart.AssemblyMass
		pearlPart:ApplyImpulse(impulse)
		pearlPart:ApplyAngularImpulse(Vector3.new(math.random(-5, 5), math.random(-5, 5), math.random(-5, 5)) * pearlPart.AssemblyMass)

		local hit = false
		pearlPart.Touched:Connect(function(other)
			if hit or other:IsDescendantOf(character) or not other.CanCollide then return end
			hit = true

			-- Teleport root assembly cleanly using structured directional safety offsets
			rootPart.CFrame = CFrame.new(pearlPart.Position + cfg.LandOffset)
			playSound("FinaleEnderPearl", rootPart)
			pearl:Destroy()
		end)

		Debris:AddItem(pearl, cfg.Lifetime)
	end)
end

-- ============================================================================
-- SNOWBALL MECHANIC (Linear Velocity Projectiles & Ammunition States)
-- ============================================================================
do
	local cfg = Config.Snowball
	local remote = Events:WaitForChild("ThrowEvent")

	local sndThrow = Sounds:WaitForChild("Throw"):Clone()
	local sndHit = Sounds:WaitForChild("BoomHeadshot"):Clone()
	local debounces = {}

	local function setupTool(tool)
		if tool:IsA("Tool") and tool.Name == cfg.ToolName then
			tool:SetAttribute("Municao", cfg.MaxAmmo)
		end
	end

	-- Global state listeners configuring internal item metadata tags automatically
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			player.Backpack.ChildAdded:Connect(setupTool)
			character.ChildAdded:Connect(setupTool)
		end)
	end)

	remote.OnServerEvent:Connect(function(player, mousePos)
		local character = player.Character
		if not character or debounces[player] then return end

		local tool = character:FindFirstChild(cfg.ToolName)
		if not tool then return end

		local handle = tool:FindFirstChild("Handle")
		if not handle then return end

		local ammo = tool:GetAttribute("Municao") or cfg.MaxAmmo
		if ammo <= 0 then return end

		debounces[player] = true
		tool:SetAttribute("Municao", ammo - 1)

		sndThrow:Play()
		playSound("Throw", handle)

		local ball = Instance.new("Part")
		ball.Size = Vector3.new(0.8, 0.8, 0.8)
		ball.Shape = Enum.PartType.Ball
		ball.Color = Color3.new(1, 1, 1)
		ball.Material = Enum.Material.Snow
		ball.CFrame = handle.CFrame
		ball.CanCollide = true
		ball.Parent = workspace

		local attachment = Instance.new("Attachment", ball)
		local velocity = Instance.new("LinearVelocity")
		velocity.MaxForce = math.huge
		velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		velocity.Attachment0 = attachment
		velocity.VectorVelocity = (mousePos - handle.Position).Unit * cfg.Speed
		velocity.Parent = ball

		Debris:AddItem(ball, cfg.Lifetime)

		local hit = false
		ball.Touched:Connect(function(other)
			if hit then return end

			local targetChar = other.Parent
			local humanoid = targetChar:FindFirstChildOfClass("Humanoid")

			if not humanoid or targetChar == character or humanoid.Health <= 0 then return end

			playSound("BoomHeadShot", targetChar)
			hit = true
			local impact = velocity.VectorVelocity
			ball:Destroy()
			sndHit:Play()

			-- Force ragdoll/knockdown behaviors via the native PlatformStand property
			humanoid.PlatformStand = true
			local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
			if targetRoot then targetRoot.AssemblyLinearVelocity = impact * 0.5 end

			task.wait(cfg.KnockTime)
			if humanoid then humanoid.PlatformStand = false end
		end)

		-- Destructive consumption processing when ammo pool zeroes out
		if tool:GetAttribute("Municao") <= 0 then
			task.wait(0.5)
			if tool then
				tool:Destroy()
				removeToolInProfile(tool.Name, player)
			end
		else
			task.wait(cfg.Cooldown)
		end

		debounces[player] = nil
	end)

	if Players.PlayerRemoving then
		Players.PlayerRemoving:Connect(function(player) debounces[player] = nil end)
	end
end

-- ============================================================================
-- SMOKE GRENADE MECHANIC (Global Atmospheric Fog Control Tweens)
-- ============================================================================
do
	local cfg = Config.Smoke
	local remote = Events:WaitForChild("SmokeEffectActivated")

	-- Instantiate persistent tracking tags on workspace environments safely
	if Lighting:GetAttribute("SmokeActive") == nil then
		Lighting:SetAttribute("SmokeActive", false)
		Lighting:SetAttribute("FogOriginalEnd", Lighting.FogEnd)
		Lighting:SetAttribute("FogOriginalStart", Lighting.FogStart)
		Lighting:SetAttribute("FogOriginalColor", Lighting.FogColor)
	end

	local tweenInfo = TweenInfo.new(cfg.Transition, Enum.EasingStyle.Linear)
	local function tween(props) TweenService:Create(Lighting, tweenInfo, props):Play() end

	remote.OnServerEvent:Connect(function(player)
		if Lighting:GetAttribute("SmokeActive") then return end

		local character = player.Character
		local tool = (character and character:FindFirstChild(cfg.ToolName)) or player.Backpack:FindFirstChild(cfg.ToolName)
		if not tool then return end

		local starterGear = player:FindFirstChild("StarterGear")
		if starterGear then
			local copy = starterGear:FindFirstChild(cfg.ToolName)
			if copy then copy:Destroy() end
		end

		playSound("Smoke", workspace)
		Lighting:SetAttribute("SmokeActive", true)

		tool:Destroy()
		removeToolInProfile(tool.Name, player)

		-- Shift global lighting engines smoothly to obscure visibility
		tween({ FogEnd = cfg.FogEnd, FogStart = 0, FogColor = cfg.FogColor })
		remote:FireAllClients(cfg.Duration)
		task.wait(cfg.Duration)

		-- Revert environmental parameters cleanly back to pristine original states
		local fogOut = TweenService:Create(Lighting, tweenInfo, {
			FogEnd = Lighting:GetAttribute("FogOriginalEnd"),
			FogStart = Lighting:GetAttribute("FogOriginalStart"),
			FogColor = Lighting:GetAttribute("FogOriginalColor"),
		})
		fogOut:Play()
		fogOut.Completed:Connect(function() Lighting:SetAttribute("SmokeActive", false) end)
	end)
end

-- ============================================================================
-- SPEED COIL MECHANIC (Stateful Movement Speed Modifications)
-- ============================================================================
do
	local cfg = Config.SpeedCoil
	local playerOldSpeeds = {}
	local playerHumanoids = {}

	function ToolServerModule.onEquip(player, tool)
		if not player or not tool or tool.Name ~= cfg.ToolName then return end

		local character = tool.Parent
		local humanoid = character:FindFirstChildOfClass("Humanoid")

		playSound("SpeedCoil", tool.Handle)
		if humanoid then
			playerHumanoids[player] = humanoid
			playerOldSpeeds[player] = humanoid.WalkSpeed
			humanoid.WalkSpeed = humanoid.WalkSpeed + cfg.BOOST
		end
	end

	function ToolServerModule.onUnequip(player)
		if not player then return end
		local humanoid = playerHumanoids[player]
		local oldSpeed = playerOldSpeeds[player]

		if humanoid and oldSpeed then humanoid.WalkSpeed = oldSpeed end
		playerHumanoids[player] = nil
		playerOldSpeeds[player] = nil
	end
end

-- ============================================================================
-- JUMP POTION MECHANIC (Temporary Humanoid Stat Augmentation Cycles)
-- ============================================================================
do
	local cfg = Config.JumpPotion
	local activePotions = {}

	function ToolServerModule.onActivatePotion(player, tool)
		if not player or not tool or tool.Name ~= cfg.ToolName then return end
		if activePotions[player] then return end

		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if not humanoid or humanoid.Health <= 0 then return end
		playSound("JumpPotion", character.HumanoidRootPart)

		activePotions[player] = true
		local toolName = tool.Name 

		humanoid.UseJumpPower = true	
		humanoid.JumpPower = cfg.NewJump
		tool.Parent = nil -- Drop safely out of tracking contexts to start consumption phase

		local efeitoEncerrado = false
		local diedConnection

		local function finalizarEfeito()
			if efeitoEncerrado then return end
			efeitoEncerrado = true

			if diedConnection then diedConnection:Disconnect() end
			if player.Character == character and humanoid and humanoid.Parent and humanoid.Health > 0 then
				humanoid.JumpPower = cfg.BaseJump
			end
			if tool and tool.Parent == nil then tool:Destroy() end

			pcall(function()
				if removeToolInProfile then removeToolInProfile(toolName, player) end
			end)
			activePotions[player] = nil
		end

		diedConnection = humanoid.Died:Connect(function() finalizarEfeito() end)
		task.delay(cfg.duration, finalizarEfeito) -- Fixed structural runtime leak via automated termination timeout
	end
end

-- ============================================================================
-- MELEE SLAP GLOVE MECHANIC (Weak-keyed Garbage Cleaned Combat System)
-- ============================================================================
do
	local cfg = Config.MeleeTool
	local remote = Events:WaitForChild("WeaponEvent")
	-- Weak keys (__mode = "k") allow garbage collector to unload removed weapons instantly
	local weaponStates = setmetatable({}, {__mode = "k"})

	local function getWeaponState(tool)
		if not weaponStates[tool] then
			weaponStates[tool] = { SwingAble = true, HitAble = false, HitVictims = {}, ArmMesh = nil }
		end
		return weaponStates[tool]
	end

	local function getPlayerFromTool(tool)
		local char = tool.Parent
		return Players:GetPlayerFromCharacter(char)
	end

	local function contains(t, v)
		for _, val in pairs(t) do if val == v then return true end end
		return false
	end

	-- Classic kill credit tracking tag injectors
	local function tagHuman(player, human)
		if not player then return end
		local tag = Instance.new("ObjectValue")
		tag.Value = player
		tag.Name = "creator"
		tag.Parent = human
		Debris:AddItem(tag, 2)
	end

	local function sameTeam(player, otherHuman)
		local otherPlayer = Players:GetPlayerFromCharacter(otherHuman.Parent)
		if player and otherPlayer then
			if player == otherPlayer then return true end
			if otherPlayer.Neutral then return false end
			return player.TeamColor == otherPlayer.TeamColor
		end
		return false
	end

	local function checkTeams(player, otherHuman)
		return not (sameTeam(player, otherHuman) and not cfg.FriendlyFire)
	end

	local function onTouched(tool, part)
		if part:IsDescendantOf(tool.Parent) then return end

		local state = getWeaponState(tool)
		if not state.HitAble then return end

		if part.Parent and part.Parent:FindFirstChildOfClass("Humanoid") then
			local human = part.Parent:FindFirstChildOfClass("Humanoid")
			if contains(state.HitVictims, human) then return end

			local root = part.Parent:FindFirstChild("HumanoidRootPart")
			local myRoot = tool.Parent:FindFirstChild("HumanoidRootPart")
			local player = getPlayerFromTool(tool)

			if root and not root.Anchored and myRoot and checkTeams(player, human) then
				local delta = root.Position - myRoot.Position
				tagHuman(player, human)
				table.insert(state.HitVictims, human)

				-- Exert dramatic instant impulse forces using high-order BodyVelocity overrides
				local bv = Instance.new("BodyVelocity")
				bv.maxForce = Vector3.new(1e9, 1e9, 1e9)
				bv.velocity = delta.Unit * 40
				bv.Parent = root
				Debris:AddItem(bv, 0.05)

				local handle = tool:FindFirstChild("Handle")
				if handle then
					local SoundsRand = math.random(3)
					if SoundsRand == 1 and handle:FindFirstChild("Smack") then handle.Smack:Play()
					elseif SoundsRand == 2 and handle:FindFirstChild("GET OUT! 🗣️ meme voice clip") then handle["GET OUT! 🗣️ meme voice clip"]:Play()
					elseif handle:FindFirstChild("Spinning cat") then handle["Spinning cat"]:Play() end
				end
			end
		end
	end

	local function vincularEventosDaArma(tool)
		if not tool:IsA("Tool") or tool.Name ~= cfg.ToolName then return end
		local handle = tool:WaitForChild("Handle", 5)
		if not handle then return end

		tool.Equipped:Connect(function()
			local char = tool.Parent
			local armMeshObj = tool:FindFirstChild("ArmMesh")
			local state = getWeaponState(tool)

			if char and armMeshObj and char:FindFirstChild("Right Arm") then
				local arm = armMeshObj:Clone()
				arm.Parent = char:FindFirstChild("Right Arm")
				state.ArmMesh = arm
			end
		end)

		tool.Unequipped:Connect(function()
			local state = getWeaponState(tool)
			if state.ArmMesh then state.ArmMesh:Destroy() state.ArmMesh = nil end
		end)

		handle.Touched:Connect(function(part) onTouched(tool, part) end)
	end

	local function monitorarJogador(player)
		player.CharacterAdded:Connect(function(char)
			char.ChildAdded:Connect(vincularEventosDaArma)
			for _, item in ipairs(char:GetChildren()) do vincularEventosDaArma(item) end
		end)
		player.ChildAdded:Connect(function(child)
			if child:IsA("Backpack") then child.ChildAdded:Connect(vincularEventosDaArma) end
		end)
		local backpack = player:WaitForChild("Backpack", 5)
		if backpack then
			backpack.ChildAdded:Connect(vincularEventosDaArma)
			for _, item in ipairs(backpack:GetChildren()) do vincularEventosDaArma(item) end
		end
	end

	Players.PlayerAdded:Connect(monitorarJogador)
	for _, p in ipairs(Players:GetPlayers()) do monitorarJogador(p) end

	remote.OnServerEvent:Connect(function(player, action)
		local character = player.Character
		if not character then return end

		local tool = character:FindFirstChild(cfg.ToolName)
		if not tool then return end

		local state = getWeaponState(tool)
		local handle = tool:FindFirstChild("Handle")

		if action == "LeftDown" then
			if not state.SwingAble then return end
			state.SwingAble = false
			task.delay(cfg.SwingRestTime, function() state.SwingAble = true end)
			task.delay(cfg.HitWindup, function()
				state.HitAble = true
				task.delay(cfg.HitWindow, function() state.HitAble = false end)
			end)

			state.HitVictims = {}
			remote:FireClient(player, "PlayAnimation", "Swing")

			task.wait(0.25)
			if handle and handle:FindFirstChild("Boom") then
				handle.Boom.Pitch = math.random(80, 100) / 100
				handle.Boom:Play()
			end
		end
	end)
end

-- ============================================================================
-- BOOMBOX MECHANIC (Networked Custom Audio Replication Engine)
-- ============================================================================
do
	local cfg = Config.Boombox
	local remote = Events:WaitForChild("BoomboxEvent")

	local function garantirSom(tool)
		local handle = tool:WaitForChild("Handle", 5)
		if not handle then return nil end

		local sound = handle:FindFirstChild("BoomboxSound")
		if not sound then
			sound = Instance.new("Sound")
			sound.Name = "BoomboxSound"
			sound.Volume = 0.5
			sound.Looped = true
			sound.Parent = handle
		end
		return sound
	end

	local function vincularBoombox(tool)
		if not tool:IsA("Tool") or tool.Name ~= cfg.ToolName then return end
		local sound = garantirSom(tool)
		if not sound then return end

		tool.Unequipped:Connect(function() sound:Stop() end)
	end

	local function monitorarJogadorBoombox(player)
		player.CharacterAdded:Connect(function(char)
			char.ChildAdded:Connect(vincularBoombox)
			for _, item in ipairs(char:GetChildren()) do vincularBoombox(item) end
		end)
		player.ChildAdded:Connect(function(child)
			if child:IsA("Backpack") then child.ChildAdded:Connect(vincularBoombox) end
		end)
		local backpack = player:WaitForChild("Backpack", 5)
		if backpack then
			backpack.ChildAdded:Connect(vincularBoombox)
			for _, item in ipairs(backpack:GetChildren()) do vincularBoombox(item) end
		end
	end

	Players.PlayerAdded:Connect(monitorarJogadorBoombox)
	for _, p in ipairs(Players:GetPlayers()) do monitorarJogadorBoombox(p) end

	remote.OnServerEvent:Connect(function(player, action, id)
		local character = player.Character
		if not character then return end

		local tool = character:FindFirstChild(cfg.ToolName)
		if not tool then return end

		local sound = garantirSom(tool)
		if not sound then return end

		if action == "PlaySong" then
			if id and id ~= "" then
				sound.SoundId = "rbxassetid://" .. tostring(id)
				sound:Play()
			else
				sound:Stop()
				sound.SoundId = ""
			end
		end
	end)
end

-- ============================================================================
-- JETPACK MECHANIC (Dynamic Vector Velocity Thruster Flight Engine)
-- ============================================================================
do
	local cfg = Config.Jetpack
	local remote = Events:WaitForChild("JetpackEvent")
	local RunService = game:GetService("RunService")
	local states = {}

	local function getState(player)
		if not states[player] then
			states[player] = { fuel = cfg.MaxFuel, flying = false, recharging = false }
		end
		return states[player]
	end

	local function setEffects(tool, state)
		if not tool then return end
		for _, item in ipairs(tool:GetDescendants()) do
			if item:IsA("ParticleEmitter") and (item.Name == "Particula1" or item.Name == "Particula2" or item.Name == "Particula3") then
				item.Enabled = state
			elseif item:IsA("Sound") and item.Name == "SomTurbina" then
				if state then if not item.IsPlaying then item:Play() end else item:Stop() end
			end
		end
	end

	local function clearPhysics(player)
		local state = states[player]
		if not state then return end
		if state.velocity then state.velocity:Destroy() state.velocity = nil end
		if state.attachment then state.attachment:Destroy() state.attachment = nil end
		state.flying = false
	end

	-- Frame-by-frame simulation update stepping to process fuel burn/regeneration metrics
	RunService.Heartbeat:Connect(function(dt)
		for player, state in pairs(states) do
			local character = player.Character
			local tool = character and character:FindFirstChild(cfg.ToolName)
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")

			if not character or not humanoid or humanoid.Health <= 0 then
				if state.flying then
					clearPhysics(player)
				end
				state.fuel = cfg.MaxFuel
				state.recharging = false
			else
				if state.flying and tool then
					state.fuel = math.max(0, state.fuel - (cfg.BurnRate * dt))
					if state.fuel <= 0 then
						state.flying = false
						state.recharging = true
						clearPhysics(player)
						setEffects(tool, false)
						remote:FireClient(player, "ForceStop") 
					end
				else
					if state.fuel < cfg.MaxFuel then
						state.fuel = math.min(cfg.MaxFuel, state.fuel + (cfg.RegenRate * dt))
					end

					if state.fuel >= cfg.MaxFuel then 
						state.recharging = false 
					end
				end
			end
		end
	end)

	remote.OnServerEvent:Connect(function(player, action)
		local character = player.Character
		if not character then return end

		local tool = character:FindFirstChild(cfg.ToolName)
		if not tool then return end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart or character.Humanoid.Health <= 0 then return end

		local state = getState(player)

		if action == "StartFlying" then
			if state.fuel > 0 and not state.recharging and not state.flying then
				state.flying = true

				clearPhysics(player)

				local existingForce = rootPart:FindFirstChild("JetpackForce")
				if existingForce then existingForce:Destroy() end
				local existingAtt = rootPart:FindFirstChild("JetpackAttachment")
				if existingAtt then existingAtt:Destroy() end

				local att = Instance.new("Attachment")
				att.Name = "JetpackAttachment"
				att.Parent = rootPart
				state.attachment = att

				local lv = Instance.new("LinearVelocity")
				lv.Name = "JetpackForce"
				lv.Attachment0 = att
				lv.MaxForce = 999999
				lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
				lv.VectorVelocity = Vector3.new(0, cfg.FlySpeed, 0)
				lv.Enabled = true
				lv.Parent = rootPart
				state.velocity = lv

				setEffects(tool, true)
			end
		elseif action == "StopFlying" then
			state.flying = false
			clearPhysics(player)
			setEffects(tool, false)

			local existingForce = rootPart:FindFirstChild("JetpackForce")
			if existingForce then existingForce:Destroy() end
			local existingAtt = rootPart:FindFirstChild("JetpackAttachment")
			if existingAtt then existingAtt:Destroy() end
		end
	end)

	if Players.PlayerRemoving then
		Players.PlayerRemoving:Connect(function(player) states[player] = nil end)
	end
end

return ToolServerModule