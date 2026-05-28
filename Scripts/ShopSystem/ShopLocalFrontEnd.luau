local ShopModule = {}

-- Services
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local ItensModule = require(ReplicatedStorage.Modules.ItensModule)
local GuiSoundModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GuiSoundsModule"))
local TweensModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("TweensModule"))

-- Player References
local player = game.Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- State Variables
local debounce = false
ShopModule.Profile = nil -- Dynamically updated when the server replicates player data

-- Configuration mapping for each sub-shop category
local SubShopConfigs = {
	ShopCoinsFrame = {
		Frame = PlayerGui:WaitForChild("MainGUI"):WaitForChild("ShopCoinsFrame"),
		Template = ReplicatedStorage:WaitForChild("Templates"):WaitForChild("TemplateCoinsFrame"),
		RemoteEvent = ReplicatedStorage.Events:WaitForChild("BuyCoinItem"),
		ItemType = "Coins"
	},
	ShopTitlesFrame = {
		Frame = PlayerGui:WaitForChild("MainGUI"):WaitForChild("ShopTitlesFrame"),
		Template = ReplicatedStorage:WaitForChild("Templates"):WaitForChild("TemplateTitleFrame"),
		RemoteEvent = ReplicatedStorage.Events:WaitForChild("BuyTitleItem"),
		ItemType = "Title"
	},
	ShopEffectsFrame = {
		Frame = PlayerGui:WaitForChild("MainGUI"):WaitForChild("ShopEffectsFrame"),
		Template = ReplicatedStorage:WaitForChild("Templates"):WaitForChild("TemplateEffectsFrame"),
		RemoteEvent = ReplicatedStorage.Events:WaitForChild("BuyEffectsItem"),
		ItemType = "Effects"
	},
}

-- Shop categorizations tied to specific NPCs or interactive systems
ShopModule.Frames = {
	VendedorGeral = {
		Tabs = {"ShopCoinsFrame", "ShopTitlesFrame", "ShopEffectsFrame"},
		ModelsFolder = ReplicatedStorage:WaitForChild("ModelsForShop"),
	},
}

--[[
    Dynamically refreshes the UI buttons across all store frames.
    Switches state between "Buy", "Equip", or "Equipped" depending on player inventory and current selections.
]]
function ShopModule.updateButtonStates()
	if not ShopModule.Profile then return end

	for _, config in pairs(SubShopConfigs) do
		local scrolling = config.Frame and config.Frame:FindFirstChildWhichIsA("ScrollingFrame")
		if not scrolling then continue end

			for _, cloneTemplate in ipairs(scrolling:GetChildren()) do
			if not cloneTemplate:IsA("Frame") then continue end
			local itemName = cloneTemplate.Name
			local buyButton = cloneTemplate:FindFirstChild("BuyButton")

			if buyButton then
				-- Handle layout updates for Overhead Titles
				if config.ItemType == "Title" and ShopModule.Profile.ItensTitles then
					-- Hybrid check supporting both dictionary or array-like storage structures
					local ownsItem = ShopModule.Profile.ItensTitles[itemName] or table.find(ShopModule.Profile.ItensTitles, itemName)

					if ownsItem then
						if ShopModule.Profile.EquippedTitle == itemName then
							buyButton.Text = "Equipped"
							buyButton.BackgroundColor3 = Color3.fromRGB(0, 188, 0)
							buyButton.UIStrokeBorda.Color = Color3.fromRGB(0, 136, 0)
						else
							buyButton.Text = "Equip"
							buyButton.BackgroundColor3 = Color3.fromRGB(0, 170, 255) 
							buyButton.UIStrokeBorda.Color = Color3.fromRGB(0, 127, 190)
						end
					else
						buyButton.Text = "Buy"
						buyButton.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
						buyButton.UIStrokeBorda.Color = Color3.fromRGB(0, 207, 0)
					end
				
				-- Handle layout updates for Visual Effects (Trails/Particles)
				elseif config.ItemType == "Effects" and ShopModule.Profile.ItensEffects then
					local ownsItem = ShopModule.Profile.ItensEffects[itemName] or table.find(ShopModule.Profile.ItensEffects, itemName)

					if ownsItem then
						if ShopModule.Profile.EquippedEffect == itemName then
							buyButton.Text = "Equipped"
							buyButton.BackgroundColor3 = Color3.fromRGB(0, 188, 0)
							buyButton.UIStrokeBorda.Color = Color3.fromRGB(0, 136, 0)
						else
							buyButton.Text = "Equip"
							buyButton.BackgroundColor3 = Color3.fromRGB(0, 170, 255) 
							buyButton.UIStrokeBorda.Color = Color3.fromRGB(0, 127, 190)
						end
					else
						buyButton.Text = "Buy"
						buyButton.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
						buyButton.UIStrokeBorda.Color = Color3.fromRGB(0, 207, 0)
					end
				end
			end
		end
	end
end

-- Server-to-Client listener to fetch up-to-date player profiles
ReplicatedStorage.Events.GetProfileFromLocal.OnClientEvent:Connect(function(profile)
	ShopModule.Profile = profile
	ShopModule.updateButtonStates()
end)

--[[
    Clears out old UI templates from a scrolling frame to prepare for a fresh render.
    @param scrollingFrame ScrollingFrame: The container being cleared.
]]
local function clearShop(scrollingFrame)
	for _, child in scrollingFrame:GetChildren() do
		if child:IsA("Frame") or child:IsA("ImageLabel") then
			child:Destroy()
		end
	end
end

--[[
    Populates, styles, and renders item elements inside a designated shop layout category.
    @param shopType string: The identifier key mapping to ShopModule.Frames.
    @param targetItemType string|nil: An optional filter to display only a specific type of item.
]]
function ShopModule.createTemplate(shopType, targetItemType)
	local currentShop = ShopModule.Frames[shopType]
	if not currentShop or not currentShop.Tabs then return end

	for _, tabName in ipairs(currentShop.Tabs) do
		local config = SubShopConfigs[tabName]
		if not config then continue end

		local shopFrame = config.Frame
		if not shopFrame then continue end

		-- Hide frames that don't match the requested type criteria filter
		if targetItemType and config.ItemType ~= targetItemType then
			shopFrame.Visible = false
			continue
		end

		local template = config.Template
		if not template then continue end

		local scrolling = shopFrame:FindFirstChildWhichIsA("ScrollingFrame")
		if not scrolling then continue end

		clearShop(scrolling)

		-- Populate elements from the game's shared item catalog configuration
		for itemName, info in pairs(ItensModule.Shops) do
			local itemTypeInModule = info.ShopType or "Coins"
			local isValidItem = false

			-- Consolidate subcategories under generalized classification tags
			if config.ItemType == "Effects" then
				if itemTypeInModule == "Trail" or itemTypeInModule == "Particle" then
					isValidItem = true
				end
			else
				if itemTypeInModule == config.ItemType then
					isValidItem = true
				end
			end

			if not isValidItem then continue end

			local cloneTemplate = template:Clone()
			cloneTemplate.Name = itemName
			cloneTemplate.LayoutOrder = info.Price -- Leverage UI sorting natively via prices

			local frameContainer = cloneTemplate:FindFirstChild("Frame")
			local viewPort = frameContainer and frameContainer:FindFirstChild("ViewportFrame")

			local nameLabel = cloneTemplate:FindFirstChild("Name")
			local priceLabel = cloneTemplate:FindFirstChild("Price")
			local IsPermanent = cloneTemplate:FindFirstChild("IsPermanent")

			-- Styling Logic: In-game Coin adjustments
			if itemTypeInModule == "Coins" then
				if IsPermanent then
					IsPermanent.Visible = true
					if info.Permanent == "Yes" then
						IsPermanent.Text = "Permanent: Yes"
						IsPermanent.TextColor3 = Color3.fromRGB(0, 255, 0)
					else
						IsPermanent.Text = "Permanent: Not" -- Consider changing to "No"
						IsPermanent.TextColor3 = Color3.fromRGB(255, 0, 0)
					end
				end

			-- Styling Logic: Overhead Text Titles
			elseif itemTypeInModule == "Title" then
				if IsPermanent then IsPermanent.Visible = false end

				if ShopModule.Profile and ShopModule.Profile.ItensTitles then
					local ownsItem = ShopModule.Profile.ItensTitles[itemName] or table.find(ShopModule.Profile.ItensTitles, itemName)
					if ownsItem then
						if ShopModule.Profile.EquippedTitle == itemName then
							cloneTemplate.BuyButton.Text = "Equipped"
							cloneTemplate.BuyButton.BackgroundColor3 = Color3.fromRGB(0, 188, 0)
							cloneTemplate.BuyButton.UIStrokeBorda.Color = Color3.fromRGB(0, 136, 0)
						else
							cloneTemplate.BuyButton.Text = "Equip"
							cloneTemplate.BuyButton.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
							cloneTemplate.BuyButton.UIStrokeBorda.Color = Color3.fromRGB(0, 127, 190)
						end
					end
				end

				if nameLabel then
					nameLabel.Text = itemName
					if info.ColorText then
						nameLabel.TextColor3 = info.ColorText
					end

					local uiStroke = nameLabel:FindFirstChildOfClass("UIStroke")
					if uiStroke and info.StrokeColor then
						uiStroke.Color = info.StrokeColor
					end
				end

			-- Styling Logic: Trails and Particle Visual Effects
			elseif itemTypeInModule == "Trail" or itemTypeInModule == "Particle" then
				if IsPermanent then IsPermanent.Visible = false end

				if ShopModule.Profile and ShopModule.Profile.ItensEffects then
					local ownsItem = ShopModule.Profile.ItensEffects[itemName] or table.find(ShopModule.Profile.ItensEffects, itemName)
					if ownsItem then
						if ShopModule.Profile.EquippedEffect == itemName then
							cloneTemplate.BuyButton.Text = "Equipped"
							cloneTemplate.BuyButton.BackgroundColor3 = Color3.fromRGB(0, 188, 0)
							cloneTemplate.BuyButton.UIStrokeBorda.Color = Color3.fromRGB(0, 136, 0)
						else
							cloneTemplate.BuyButton.Text = "Equip"
							cloneTemplate.BuyButton.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
							cloneTemplate.BuyButton.UIStrokeBorda.Color = Color3.fromRGB(0, 127, 190)
						end
					end
				end

				if nameLabel then
					nameLabel.Text = itemName
					if info.Color then
						if typeof(info.Color) == "Color3" then
							nameLabel.TextColor3 = info.Color
						elseif nameLabel.Text == "Trail Rainbow" then
							TweensModule.RainbowText(nameLabel, 3)
						end
					else
						nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
					end

					local uiStroke = nameLabel:FindFirstChildOfClass("UIStroke")
					if uiStroke then
						uiStroke.Color = Color3.fromRGB(0, 0, 0)
					end
				end
			end

			-- General string info assignments
			if nameLabel then nameLabel.Text = itemName end
			if priceLabel then priceLabel.Text = info.Price end

			-- If a 3D preview asset exists for the item, render it inside the template viewport
			if viewPort then
				local model = currentShop.ModelsFolder:FindFirstChild(itemName)
				if model then
					local modelClone = model:Clone()
					modelClone.Parent = viewPort
				end
			end

			-- Connect standard hover audio triggers to buttons
			GuiSoundModule.HoverSoundButton(player, cloneTemplate.BuyButton)
			
			-- Handle network requests when interactions are activated (Buy vs Equip)
			cloneTemplate.BuyButton.Activated:Connect(function()
				if debounce then return end
				debounce = true
				GuiSoundModule.Select()

				if cloneTemplate.BuyButton.Text == "Equip" or cloneTemplate.BuyButton.Text == "Equipped" then
					if itemTypeInModule == "Title" then
						ReplicatedStorage.Events.EquipTitle:FireServer(itemName)
					elseif itemTypeInModule == "Trail" or itemTypeInModule == "Particle" then
						ReplicatedStorage.Events.EquipEffect:FireServer(itemName) 
					end
				else
					config.RemoteEvent:FireServer(itemName)
				end

				task.wait(0.25)
				debounce = false
			end)

			cloneTemplate.Parent = scrolling
		end

		-- Play layout opening animations and reveal frame assets
		GuiSoundModule.OpenGui(player)
		TweensModule.OpenFrame(shopFrame, 0.25)
		shopFrame.Visible = true

		-- Connect custom frame close buttons safely without stacking events
		if shopFrame:FindFirstChild("Collum") and shopFrame.Collum:FindFirstChild("TextButton") then
			local closeButton = shopFrame.Collum.TextButton
			if not closeButton:GetAttribute("Connected") then
				closeButton:SetAttribute("Connected", true)
				GuiSoundModule.HoverSoundButton(player, closeButton)
				closeButton.Activated:Connect(function()
					GuiSoundModule.Select(player)
					shopFrame.Visible = false
				end)
			end
		end
	end
end

-- Event connection triggered via server proxies or zone interactions
ReplicatedStorage.Events.EnabledGui.Event:Connect(function(lojaTipoEspecifica, targetItemType)
	if lojaTipoEspecifica then
		ShopModule.createTemplate(lojaTipoEspecifica, targetItemType)
	else
		for _, vendedor in CollectionService:GetTagged("Vendedor") do
			local lojaTipo = vendedor:GetAttribute("LojaTipo")
			ShopModule.createTemplate(lojaTipo, targetItemType)
		end
	end
end)

return ShopModule