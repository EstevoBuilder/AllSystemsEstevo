local Tool = script.Parent
local Player = game.Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Mechanics Configuration Matrices
local MAX_FUEL = 100
local BURN_RATE = 40
local REGEN_RATE = 2
local JETPACK_GUI_NAME = "JetpackFrame"

-- Stateful Core Properties
local currentFuel = MAX_FUEL
local isEquipped = false
local isFlying = false
local isRecharging = false 

-- Interface References
local targetGui = nil
local fuelBar = nil

-- Network Remote Gateways
local remote = ReplicatedStorage:WaitForChild("Events"):WaitForChild("JetpackEvent")

--[[
    Monitors character instantiation life-cycles.
    Ensures screens clean up and hide structural jetpack UI components on character collapse/death.
    @param newCharacter Model: The newly spawned character assembly workspace structure.
]]
local function onCharacterAdded(newCharacter)
	local humanoid = newCharacter:WaitForChild("Humanoid", 5)
	if humanoid then
		humanoid.Died:Connect(function()
			local pGui = Player:FindFirstChild("PlayerGui")
			if pGui then
				local mainGui = pGui:FindFirstChild("MainGUI")
				if mainGui then
					local jetpackFrame = mainGui:FindFirstChild(JETPACK_GUI_NAME)
					if jetpackFrame then
						jetpackFrame.Visible = false
					end
				end
			end
		end)
	end
end

-- Initialize persistent structural event listeners tracking player reincarnation updates
Player.CharacterAdded:Connect(onCharacterAdded)
if Player.Character then
	onCharacterAdded(Player.Character)
end

--[[
    Renders vector dimensions and structural color modulations over screen canvas layouts.
    Fires responsively inside framerate rendering steps.
]]
local function updateUI()
	if fuelBar and targetGui and targetGui.Visible then
		local percentage = math.clamp(currentFuel / MAX_FUEL, 0, 1)
		fuelBar.Size = UDim2.fromScale(percentage, 1)

		-- Apply visual state feedback based on current fuel availability conditions
		if isRecharging then
			fuelBar.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
			fuelBar.BackgroundTransparency = 0.3
		else
			fuelBar.BackgroundColor3 = Color3.fromRGB(247, 82, 0)
			fuelBar.BackgroundTransparency = 0
		end
	end
end

--[[
    Evaluates and shifts the client flight state machine cleanly.
    Dispatches secure validation signals to server physical cluster environments.
    @param flying boolean: The targeted active state intended for the flight mechanics engine.
]]
local function toggleFlying(flying)
	if not isEquipped then return end
	if flying and currentFuel > 0 and not isRecharging then
		if not isFlying then
			isFlying = true
			remote:FireServer("StartFlying")
		end
	else
		if isFlying then
			isFlying = false
			remote:FireServer("StopFlying")
		end
	end
end

-- Hook into system input hardware events to process mechanical button actions cleanly
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end 
	if input.KeyCode == Enum.KeyCode.Space and isEquipped then
		toggleFlying(true)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Space then
		toggleFlying(false)
	end
end)

--[[
    Client Render Loop Step: Updates local fuel estimations per frame.
    Guarantees responsive UI modifications without adding lag cycles.
]]
RunService.RenderStepped:Connect(function(deltaTime)
	if isFlying and isEquipped then
		currentFuel = math.max(0, currentFuel - (BURN_RATE * deltaTime))
		if currentFuel <= 0 then
			isFlying = false
			isRecharging = true
			remote:FireServer("StopFlying")
		end
	else
		if currentFuel < MAX_FUEL then
			currentFuel = math.min(MAX_FUEL, currentFuel + (REGEN_RATE * deltaTime))
		end

		if currentFuel >= MAX_FUEL then
			isRecharging = false
		end
	end

	updateUI()
end)

-- Structural network signal listener capturing authoritative server override events
remote.OnClientEvent:Connect(function(action)
	if action == "ForceStop" then
		isFlying = false
		isRecharging = true
		currentFuel = 0
	end
end)

-- Structural setup triggered when pulling out the utility asset tool
Tool.Equipped:Connect(function()
	isEquipped = true
	local pGui = Player:WaitForChild("PlayerGui")
	targetGui = pGui:WaitForChild("MainGUI"):WaitForChild(JETPACK_GUI_NAME)
	fuelBar = targetGui:FindFirstChild("BarraCombustivel", true)
	if targetGui then 
		targetGui.Visible = true 
		updateUI()
	end
end)

-- Structural disassembly routine triggered when putting away or dropping the asset item
Tool.Unequipped:Connect(function()
	if isFlying then
		remote:FireServer("StopFlying")
	end
	isEquipped = false
	isFlying = false
	if targetGui then targetGui.Visible = false end
end)