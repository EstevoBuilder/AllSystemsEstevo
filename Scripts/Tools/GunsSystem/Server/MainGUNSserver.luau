local MainGUNSserver = {}

-- Services
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GUNS_MODULE = require(ReplicatedStorage.Modules.GunsInfo)

--[[
    Evaluates hits, updates limb target routing (including R15 adaptations), 
    calculates linear/custom damage distance falloff, and updates humanoid health.
]]
local function processHit(hitPart, infoTool, multiplierHit, originPos)
	local character = hitPart:FindFirstAncestorOfClass("Model")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	-- Validate that the targeted humanoid is live and operational
	if not (humanoid and humanoid.Health > 0) then return end

	local partName = hitPart.Name
	
	-- Handle Accessory Hitbox Routing (R15 Accessory fallback pipeline)
	if hitPart.Parent:IsA("Accessory") then
		local attachment = hitPart:FindFirstChildWhichIsA("Attachment")
		if attachment then
			local name = attachment.Name
			if name:find("Face") or name:find("Hat") or name:find("Hair") or name:find("Neck") then
				partName = "Head"
			elseif name:find("Body") or name:find("Chest") or name:find("Back") then
				partName = "UpperTorso"
			elseif name:find("Waist") then
				partName = "LowerTorso"
			else
				partName = "UpperTorso" 
			end
		else
			partName = "UpperTorso"
		end
	end

	-- R15 to R6 Compatibility Normalization Layer
	if partName == "UpperTorso" or partName == "LowerTorso" then
		partName = "Torso"
	end

	local distance = (originPos - hitPart.Position).Magnitude
	local mult = multiplierHit[partName] or 1
	local maxRange = infoTool.Range or 150
	local falloff = 1

	-- Distance Falloff Interpolation Framework
	if infoTool.Shot == "shard" then
		-- Shard/Shotgun linear dispersion falloff calculation
		falloff = math.clamp(1 - (distance / maxRange), 0.1, 1)
	else
		-- Standard firearm three-tier linear interpolation falloff calculation
		local falloffStart = infoTool.FalloffStart or (maxRange * 0.3)
		local minDamagePercent = infoTool.MinDamagePercent or 0.5 

		if distance <= falloffStart then
			falloff = 1
		elseif distance >= maxRange then
			falloff = minDamagePercent
		else
			local rangeAlpha = (distance - falloffStart) / (maxRange - falloffStart)
			falloff = 1 - (rangeAlpha * (1 - minDamagePercent))
		end
	end

	-- Apply damage scaling matrices variables
	local finalDamage = (infoTool.Damage * mult) * falloff
	finalDamage = math.max(finalDamage, 0)

	-- Instantiate visual impact feedback FX safely
	local bloodTemplate = ReplicatedStorage:FindFirstChild("Blood1")
	local targetHRP = character:FindFirstChild("HumanoidRootPart")
	
	if bloodTemplate and targetHRP then
		local CloneBloodVfx = bloodTemplate:Clone()
		CloneBloodVfx.Parent = targetHRP
		CloneBloodVfx:Emit(1)
		Debris:AddItem(CloneBloodVfx, 0.5)
	end

	humanoid:TakeDamage(finalDamage)
end

--[[
    Handles instance duplication, attachment management, and sound playback parameters.
]]
local function playSound(Sound, destin, Speed)
	if not Sound or not destin then return end
	local CloneSound = Sound:Clone()
	CloneSound.Parent = destin
	CloneSound.PlaybackSpeed = Speed
	CloneSound:Play()
	Debris:AddItem(CloneSound, CloneSound.TimeLength)
end

--[[
    Generates a transient 3D client tracer beam using dual environmental attachments.
]]
local function createBeam(origin, target)
	if not origin or not target then return end
	local att0 = Instance.new("Attachment", origin)
	local att1 = Instance.new("Attachment", workspace.Terrain)
	att1.WorldPosition = target

	local beam = Instance.new("Beam", origin)
	beam.Attachment0, beam.Attachment1 = att0, att1
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	beam.Width0, beam.Width1 = 0.05, 0.05

	Debris:AddItem(beam, 0.05)
	Debris:AddItem(att0, 0.05)
	Debris:AddItem(att1, 0.05)
end

--[[
    Network Fire Gateway: Core listener routing firearm combat parameters securely.
]]
ReplicatedStorage.Events.FireEvent.OnServerEvent:Connect(function(player, Tool, hitData, endPos)
	local InfoTool = GUNS_MODULE.GeneralInfo[Tool.Name]
	local MultiplierHit = GUNS_MODULE.MultiplierHit
	if not InfoTool or not MultiplierHit then return end
	
	-- Strict Inventory Context Check: Mitigates exploiters firing tools they do not possess
	if not player.Character or not Tool:IsDescendantOf(player.Character) then return end

	local handle = Tool:FindFirstChild("Handle")
	local firePart = handle and handle:FindFirstChild("FirePart")
	if not firePart then return end
	local origin = firePart.Position

	local currentAmmo = Tool:GetAttribute("Ammo") or InfoTool.Magazine
	if currentAmmo <= 0 then return end

	Tool:SetAttribute("Ammo", currentAmmo - 1)
	
	local hrp = player.Character:FindFirstChild("HumanoidRootPart")
	if hrp then playSound(InfoTool.Sounds.Fire, hrp, 1) end
	
	local emitter = firePart:FindFirstChildWhichIsA("ParticleEmitter")
	if emitter then emitter:Emit(1) end

	-- Execution Fork based on shot archetype profiles
	if InfoTool.Shot == "Normal" then
		if InfoTool.Beam and endPos then createBeam(firePart, endPos) end
		
		if hitData and hitData:IsA("BasePart") then
			processHit(hitData, InfoTool, MultiplierHit, origin)
		end

	elseif InfoTool.Shot == "shard" then
		if type(hitData) == "table" and type(endPos) == "table" then
			for i, hitPart in pairs(hitData) do
				if InfoTool.Beam and endPos[i] then
					createBeam(firePart, endPos[i])
				end
				
				-- Note: Swapped nil check to false compatibility fallback matching client array structures
				if hitPart and hitPart:IsA("BasePart") then
					processHit(hitPart, InfoTool, MultiplierHit, origin)
				end
			end
		end
	end
end)

--[[
    Network Reload Gateway: Updates current tool magazine inventory allocations.
]]
ReplicatedStorage.Events.ReloadEvent.OnServerEvent:Connect(function(player, Tool)
	if not player.Character or not Tool:IsDescendantOf(player.Character) then return end
	
	local InfoTool = GUNS_MODULE.GeneralInfo[Tool.Name]
	if not InfoTool then return end
	
	Tool:SetAttribute("Ammo", InfoTool.Magazine)
end)

return MainGUNSserver