local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

-- Core Network Remote Events
local PlacementEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("PlacementEvent")
local BuyUnitEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("BuyUnit")

-- Modules and Asset Directory References
local UnitsRigs = ReplicatedStorage:WaitForChild("UnitsRigs")
local ProfileService = require(ServerScriptService.Services.ProfileInitializer.ProfileService)
local UnitInfoModule = require(ReplicatedStorage.Modules.UnitsInfo)

-- Thread Debounce Context Matrix
local db = {}

-- Constant Simulation Variables
local TICK_RATE = 1

--[[
    Main Placement Listener: Manages client placement networking requests, verifies profile balances,
    calculates spatial orientations facing base targets, and establishes local instance click listeners.
]]
PlacementEvent.OnServerEvent:Connect(function(player, unitName, position)
	-- Debounce validation guard clause
	if db[player.UserId] then return end
	db[player.UserId] = true 

	local profile = ProfileService.getProfile(player)
	if not profile then 
		db[player.UserId] = nil
		return 
	end

	-- Structural Verification: Prevents unauthorized placement exploits via data validation
	if not profile.Units[unitName] or profile.Units[unitName] <= 0 then
		warn(player.Name .. " attempted unauthorized placement of: " .. tostring(unitName))
		db[player.UserId] = nil
		return 
	end

	local unitOriginal = UnitsRigs:FindFirstChild(unitName)
	if not unitOriginal then 
		db[player.UserId] = nil 
		return 
	end

	-- Deduct from profile ledger BEFORE instantiating physics objects to block processing race-conditions
	profile.Units[unitName] -= 1 

	local placesFolder = workspace.Places:FindFirstChild(player.Name)
	if not placesFolder then 
		profile.Units[unitName] += 1 -- Refund deducted asset immediately if space container validation collapses
		db[player.UserId] = nil
		return 
	end

	local templateBase = placesFolder:FindFirstChild("TemplateBase")
	local noob = templateBase and templateBase:FindFirstChild("Noob")
	local UnitsFolderPlayer = placesFolder:FindFirstChild("Units")

	if not noob or not UnitsFolderPlayer then
		profile.Units[unitName] += 1 -- Refund validation fallback safety
		db[player.UserId] = nil
		return
	end

	local unitClone = unitOriginal:Clone()
	unitClone.Name = unitName -- Enforce naming conformity matching table profiles keys
	unitClone:SetAttribute("OwnerID", player.UserId)
	
	-- Calculate orientation matrices tracking horizontal vector tracking targets
	local lookAt = CFrame.lookAt(position, noob.PrimaryPart.Position)
	local _, y, _ = lookAt:ToOrientation() 
	local cframeFinal = CFrame.new(position) * CFrame.Angles(0, y, 0)

	unitClone:PivotTo(cframeFinal)

	-- Establish interactive click handling infrastructure targeting tool pick-ups
	local ClickDetectorNew = Instance.new("ClickDetector")
	ClickDetectorNew.CursorIcon = "rbxassetid://125273340081232"
	ClickDetectorNew.MaxActivationDistance = 32
	ClickDetectorNew.Parent = unitClone

	local clickConnection = nil
	clickConnection = ClickDetectorNew.MouseClick:Connect(function(clickedPlayer)
		if clickedPlayer.UserId ~= unitClone:GetAttribute("OwnerID") then return end
		
		-- Disconnect event handling context immediately to prevent multi-click thread execution duplicates
		if clickConnection then
			clickConnection:Disconnect()
			clickConnection = nil
		end
		
		unitClone:Destroy()
		profile.Units[unitName] += 1
		BuyUnitEvent:FireClient(clickedPlayer, unitName, profile)
	end)

	unitClone.Parent = UnitsFolderPlayer
	
	if unitClone.PrimaryPart then
		unitClone.PrimaryPart.Anchored = true
	end

	print(player.Name .. " placed unit: " .. unitName .. ". Remainder balance: " .. profile.Units[unitName])

	task.wait(0.2)
	db[player.UserId] = nil
end)

--[[
    Global Factory Generation Thread: Periodically scans active physical unit folders,
    accumulates data power values, and maps continuous transactional changes across datastores.
]]
task.spawn(function()
	while true do
		task.wait(TICK_RATE)

		local UnitsInfo = UnitInfoModule.UnitsInfo
		if not UnitsInfo then continue end

		for _, folder in ipairs(workspace.Places:GetChildren()) do
			local unitsFolder = folder:FindFirstChild("Units")
			if not unitsFolder then continue end

			local activePlayer = Players:FindFirstChild(folder.Name)
			if not activePlayer then continue end

			local totalPower = 0

			for _, unit in ipairs(unitsFolder:GetChildren()) do
				local targetShopData = UnitsInfo.Shops and UnitsInfo.Shops[unit.Name]
				if targetShopData and targetShopData.power then
					totalPower += targetShopData.power
				end
			end

			if totalPower > 0 then
				ProfileService.ClickerAdd(activePlayer, totalPower)
			end
		end
	end
end)

return MainGUNSserver