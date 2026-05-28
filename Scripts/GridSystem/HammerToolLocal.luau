local tool = script.Parent
local player = game.Players.LocalPlayer
local PlayerGUI = player:WaitForChild("PlayerGui")
local HammerFrame = PlayerGUI:WaitForChild("MainGUI"):WaitForChild("HammerFrame")
local ScrollingFrame = HammerFrame:WaitForChild("ScrollingFrame")

-- Services and Module Dependencies
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiSoundModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GuiSoundsModule"))
local TweensModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("TweensModule"))

-- Core Mechanics Assets Gateways
local UnitsRigs = ReplicatedStorage:WaitForChild("UnitsRigs")
local PlacementEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("PlacementEvent")
local mouse = player:GetMouse()

-- Safe Environment Workspace References Lookup
local placesFolder = workspace:WaitForChild("Places")
local playerFolder = placesFolder:WaitForChild(player.Name)
local templateBase = playerFolder:WaitForChild("TemplateBase")
local BasePart = templateBase:WaitForChild("Terra")

-- Static Logic Properties
local ChosenUnitName = nil
local previewModel = nil
local currentFrame = nil
local gridSize = 4
local isPlacing = false

--[[
    Snaps raw 3D vectors smoothly onto a grid matrix based on configured padding sizes.
    @param position Vector3: The raw point coordinates captured by the mouse raycast.
    @return Vector3: The aligned and grid-snapped coordinates.
]]
local function snapToGrid(position)
	return Vector3.new(
		math.floor(position.X / gridSize + 0.5) * gridSize,
		BasePart.Position.Y + (BasePart.Size.Y / 2),
		math.floor(position.Z / gridSize + 0.5) * gridSize
	)
end

--[[
    Completely eliminates the current preview instance and clears memory slots safely.
]]
local function clearPreview()
	if previewModel then
		previewModel:Destroy()
		previewModel = nil
	end
end

--[[
    Iterates through model descendants to modify transparency and physical interaction boundaries.
    @param model Model: The construction asset model target.
]]
local function applyModelProperties(model)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			-- Optimization: Prevent double-assignment checking current values
			if part.Transparency ~= 0.5 then part.Transparency = 0.5 end
			if part.CanCollide then part.CanCollide = false end
			if part.CanQuery then part.CanQuery = false end
		end
	end
end

--[[
    Initializes button active states and binds audio hover visual feedback pipelines.
    @param item GuiObject: The container element representing the build item layout frame.
]]
local function setupPlaceButton(item)
	local button = item:FindFirstChild("PlaceButton")
	
	if button then
		-- Refactored signature matching your updated client-optimized module
		GuiSoundModule.HoverSoundButton(button)
		
		button.Activated:Connect(function()
			GuiSoundModule.Select(button)
			ChosenUnitName = item.Name
			currentFrame = item
			clearPreview()

			local original = UnitsRigs:FindFirstChild(ChosenUnitName)
			if original then
				previewModel = original:Clone()
				previewModel.Parent = workspace
				applyModelProperties(previewModel)
			end
		end)
	end
end

-- Initialize persistent visual frames loaded by default structures
for _, child in ipairs(ScrollingFrame:GetChildren()) do
	setupPlaceButton(child)
end

-- Dynamic dynamic frame tracking catching inventory additions on the fly
ScrollingFrame.ChildAdded:Connect(function(child)
	setupPlaceButton(child)
end)

--[[
    Main Render Loop Step: Syncs preview position targets with grid points instantly every frame.
]]
RunService.RenderStepped:Connect(function()
	if previewModel then 
		if mouse.Target == BasePart then
			local pos = snapToGrid(mouse.Hit.Position)
			previewModel:PivotTo(previewModel:GetPivot():Lerp(CFrame.new(pos), 0.1))
		else
			-- Conceal model dimensions off-canvas safely if aiming outside legal baseplate terrain
			previewModel:PivotTo(CFrame.new(0, -50, 0))
		end
	end
end)

--[[
    Main Placement Trigger Activation Pipeline
]]
tool.Activated:Connect(function()
	if isPlacing or not ChosenUnitName or not currentFrame or mouse.Target ~= BasePart then 
		return 
	end

	local quantidadeLabel = currentFrame:FindFirstChild("Quantidade")
	if not quantidadeLabel then return end

	-- Isolate structural integers inside inventory strings via regex string parsing
	local textoLimpo = quantidadeLabel.Text:gsub("%D", "")
	local qtd = tonumber(textoLimpo) or 0
	if qtd <= 0 then return end

	isPlacing = true

	local pos = snapToGrid(mouse.Hit.Position)

	-- Setup bounding box parameters excluding the active ghost preview model itself
	local overlapParams = OverlapParams.new()
	if previewModel then
		overlapParams.FilterDescendantsInstances = {previewModel}
		overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	end

	local parts = workspace:GetPartBoundsInBox(CFrame.new(pos + Vector3.new(0, 2, 0)), Vector3.new(3.5, 3.5, 3.5), overlapParams)

	-- If the grid slot is physically unblocked, fire updates towards the server
	if #parts <= 0 then
		PlacementEvent:FireServer(ChosenUnitName, pos)
		GuiSoundModule.DeployUnit(currentFrame)

		qtd = qtd - 1
		if qtd <= 0 then
			currentFrame:Destroy()
			clearPreview()
			ChosenUnitName = nil
			currentFrame = nil
		else
			quantidadeLabel.Text = qtd .. "x" 
		end
	end

	task.wait(0.2)
	isPlacing = false
end)

-- Structural setup triggered when drawing out the building tool asset
tool.Equipped:Connect(function() 
	TweensModule.OpenFrame(HammerFrame, 0.25)
	GuiSoundModule.OpenGui(HammerFrame)
	HammerFrame.Visible = true 
end)

-- Structural teardown triggered when holstering the item layout frame
tool.Unequipped:Connect(function() 
	HammerFrame.Visible = false 
	clearPreview()
	ChosenUnitName = nil
	currentFrame = nil
end)