local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DATASTORE_NAME = "data-key_V1"
local DataStore = DataStoreService:GetDataStore(DATASTORE_NAME)
local ProfileTemplate = require(script.Parent.ProfileTemplate)

local profilesInCache = {}
local ProfileService = {}

--[[
    Creates a deep copy of a given table to ensure unique memory references.
    @param original any: The value or table to be copied.
    @return any: A deep copy of the original table, or the value itself if it's not a table.
]]
local function deepCopy(original)
	local copy = {}
	for key, value in pairs(original) do
		if typeof(value) == "table" then
			copy[key] = deepCopy(value)
		else
			copy[key] = value
		end
	end
	return copy
end

--[[
    Loads a player's profile data from the DataStore or initializes it from the template.
    Handles data reconciliation for new fields added to the template over time.
    @param player Player: The target player loading into the game.
    @return table|nil: The loaded or newly generated profile data table, or nil if an error occurs.
]]
function ProfileService.LoadProfile(player: Player)
	local userId = player.UserId

	task.wait(3) 
	if not player:IsDescendantOf(Players) then 
		return nil
	end

	local success, data = pcall(function()
		return DataStore:GetAsync(userId)
	end)

	if not success then
		player:Kick("Erro ao carregar dados. Por favor, tente novamente.")
		return nil
	end

	local profile = data and deepCopy(data) or deepCopy(ProfileTemplate)
	
	for key, value in pairs(ProfileTemplate) do
		if profile[key] == nil then
			profile[key] = typeof(value) == "table" and deepCopy(value) or value
		end
	end

	profilesInCache[userId] = profile
	ProfileService.updateProfile(player, profile)
	return profile
end

--[[
    Saves the specified player's cached profile back to the DataStore using an asynchronous update.
    @param player Player: The player whose profile needs to be saved.
]]
function ProfileService.saveProfile(player: Player)
	local userId = player.UserId
	local profile = profilesInCache[userId]

	if profile then
		local success, err = pcall(function()
			DataStore:UpdateAsync(userId, function(oldData)
				return profile
			end)
		end)

		if not success then
			warn("Erro ao salvar dados de " .. player.Name .. ": " .. tostring(err))
		else
			print("Dados de " .. player.Name .. " salvos com sucesso.")
		end
	end
end

--[[
    Removes a player's profile from the local session cache.
    @param player Player: The player whose cache should be cleared.
]]
function ProfileService.ClearCache(player: Player)
	profilesInCache[player.UserId] = nil
end

--[[
    Updates the cached profile data for a player and synchronizes it with the client.
    @param player Player: The target player.
    @param profile table: The updated profile data table.
]]
function ProfileService.updateProfile(player: Player, profile)
	if not profile then return end
	profilesInCache[player.UserId] = profile
	ReplicatedStorage.Remotes.GetProfileFromLocal:FireClient(player, profile)
end

--[[
    Retrieves the cached profile of a specific player.
    @param player Player: The target player.
    @return table|nil: The cached data table or nil if it doesn't exist.
]]
function ProfileService.getProfile(player: Player)
	return profilesInCache[player.UserId]
end

-- Background loop that auto-saves all cached player profiles every 5 minutes (300 seconds)
task.spawn(function()
	while true do
		task.wait(300)
		for _, player in ipairs(Players:GetPlayers()) do
			if profilesInCache[player.UserId] then
				task.spawn(ProfileService.saveProfile, player)
			end
		end
	end
end)

-- Game shutdown listener ensures data is safely saved when the server closes
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		ProfileService.saveProfile(player)
	end
end)

return ProfileService