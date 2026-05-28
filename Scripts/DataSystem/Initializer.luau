-- Services
local Players = game:GetService("Players")

-- Modules
local ProfileService = require(script.Parent.ProfileService)

--[[
    Handles data loading when a player joins the server.
    @param player Player: The player who joined.
]]
local function onPlayerAdded(player: Player)
    task.wait(5)

    -- Load and retrieve the player's profile
    ProfileService.LoadProfile(player)
    local profile = ProfileService.getProfile(player)

    -- If the profile fails to load, abort execution
    if not profile then return end
end

--[[
    Handles data saving and cleanup when a player leaves the server.
    @param player Player: The player who is leaving.
]]
local function onPlayerRemoving(player: Player)
    local profile = ProfileService.getProfile(player)

    -- Save the profile if it exists before the player disconnects
    if profile then
        ProfileService.saveProfile(player)
    end
end

-- Event Listeners
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle players who joined before the script finished executing (Edge case fix)
for _, player in Players:GetPlayers() do
    task.spawn(onPlayerAdded, player)
end