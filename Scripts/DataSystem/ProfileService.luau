-- Services
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

-- Constants & Configurations
local DATASTORE_NAME = "data-key"
local DataStore = DataStoreService:GetDataStore(DATASTORE_NAME)
local ProfileTemplate = require(script.Parent.ProfileTemplate)

-- Session Cache (Stores active player data in memory)
local profilesInCache = {}

local ProfileService = {}

--[[
    Deep copies a table to prevent nested tables from referencing the original template.
    @param original table: The source table to copy.
    @return table: A brand new detached copy of the table.
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
    Loads a player's profile from the DataStore. Kicks the player if a critical error occurs.
    @param player Player: The target player.
]]
function ProfileService.LoadProfile(player: Player)
	local userId = player.UserId
	local success, data = pcall(function()
		return DataStore:GetAsync(userId)
	end)

	if not success then
		player:Kick("Error loading data. Please try again.")
		return
	end

	local profile
	if data then
		profile = data
		-- NOTE: Data reconciliation should happen here to inject new template fields into old player data.
	else
		profile = deepCopy(ProfileTemplate)
	end

	profilesInCache[userId] = profile
	ProfileService.updateProfile(player, profile)
end

--[[
    Saves the player's current cached profile back to the DataStore and updates leaderboards.
    @param player Player: The player whose data is being saved.
]]
function ProfileService.saveProfile(player: Player)
	local userId = player.UserId
	local profile = profilesInCache[userId]

	if profile then
		-- Save main profile data
		local success, err = pcall(function()
			DataStore:UpdateAsync(userId, function(oldData)
				return profile
			end)
		end)

		if not success then
			warn("Error saving " .. player.Name .. ": " .. tostring(err))
		end

		-- Clear session cache to prevent memory leaks
		profilesInCache[userId] = nil
	end
end

--[[
    Forces an update or manually sets a profile inside the session cache.
    @param player Player: The target player.
    @param profile table: The profile data to write.
]]
function ProfileService.updateProfile(player: Player, profile)
	if not profile then return end
	profilesInCache[player.UserId] = profile
end

--[[
    Retrieves the cached profile of a specific player.
    @param player Player: The target player.
    @return table|nil: The cached data table or nil if it doesn't exist.
]]
function ProfileService.getProfile(player: Player)
	return profilesInCache[player.UserId]
end

-- Auto-save data for all remaining players when the server shuts down
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		ProfileService.saveProfile(player)
	end
end)

return ProfileService