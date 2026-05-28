local ProcessPurchaseModule = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Modules
local ItensModule = require(ReplicatedStorage.Modules.ItensModule)
-- ProfileService wrappers handle player data loading and saving safely
local ProfileService = require(ServerScriptService.Services.ProfileInitializer.ProfileService)

--[[
    Triggers a network signal to play the transactional purchase sound on the client.
    @param player Player: The target client recipient.
]]
local function playSoundBuy(player)
	ReplicatedStorage.Events.WarnSoundBuy:FireClient(player, "Purchase")
end

--[[
    Server Listener: Handles standard Coin-based Item purchases (Tools / Potions).
]]
ReplicatedStorage.Events.BuyCoinItem.OnServerEvent:Connect(function(player, ItemName)
	local profile = ProfileService.getProfile(player)
	if not profile then return end

	local itemInfo = ItensModule.Shops[ItemName]
	if not itemInfo then return end

	-- Backend protection check: Stop execution if the user already owns the inventory asset
	if profile.ItensCoins[ItemName] then 
		ReplicatedStorage.Events.WarnEventServer:FireClient(player, "You already have this item")
		return
	end

	-- Transaction safety checks validating player financial sufficiency
	if profile.Coins >= itemInfo.Price then
		local Tool = ReplicatedStorage.Tools:FindFirstChild(ItemName):Clone()

		playSoundBuy(player)
		profile.ItensCoins[ItemName] = true
		profile.Coins -= itemInfo.Price
		
		-- Persist modifications inside the server session cluster state
		ProfileService.updateProfile(player, profile)
		ReplicatedStorage.Events.UpdateCoins:FireClient(player, profile)

		Tool.Parent = player.Backpack
	end
end)

--[[
    Server Listener: Handles standard Coin-based Billboard Title text purchases.
]]
ReplicatedStorage.Events.BuyTitleItem.OnServerEvent:Connect(function(player, ItemName)
	local profile = ProfileService.getProfile(player)
	if not profile then return end

	local itemInfo = ItensModule.Shops[ItemName]
	if not itemInfo then return end

	if profile.ItensTitles[ItemName] then 
		ReplicatedStorage.Events.WarnEventServer:FireClient(player, "You already have this item")
		return 
	end

	if profile.Coins >= itemInfo.Price then
		profile.Coins -= itemInfo.Price
		playSoundBuy(player)
		profile.ItensTitles[ItemName] = true
		
		ProfileService.updateProfile(player, profile)
		ReplicatedStorage.Events.GetProfileFromLocal:FireClient(player, profile)
		ReplicatedStorage.Events.UpdateCoins:FireClient(player, profile)
	end
end)

--[[
    Server Listener: Handles standard Coin-based Visual Effect (Trail/Particle) purchases.
]]
ReplicatedStorage.Events.BuyEffectsItem.OnServerEvent:Connect(function(player, ItemName)
	local profile = ProfileService.getProfile(player)
	if not profile then return end

	local itemInfo = ItensModule.Shops[ItemName]
	if not itemInfo then return end

	if profile.ItensEffects[ItemName] then 
		ReplicatedStorage.Events.WarnEventServer:FireClient(player, "You already have this item")
		return 
	end

	if profile.Coins >= itemInfo.Price then
		profile.Coins -= itemInfo.Price
		playSoundBuy(player)
		profile.ItensEffects[ItemName] = true
		
		ProfileService.updateProfile(player, profile)
		ReplicatedStorage.Events.GetProfileFromLocal:FireClient(player, profile)
		ReplicatedStorage.Events.UpdateCoins:FireClient(player, profile)
	end
end)

return ProcessPurchaseModule