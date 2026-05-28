local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local soundFolder = ReplicatedStorage:WaitForChild("EffectSound")

local GuiSoundsModule = {}

--[[
    Plays a specified sound asset locally and handles its automated lifecycle cleanup.
    @param soundName string: The exact instance name of the sound inside the asset folder.
    @param targetParent Instance: The object container where the sound clone will temporarily reside.
]]
local function playSoundBase(soundName, targetParent)
	if not targetParent then return end
	
	local soundTemplate = soundFolder:FindFirstChild(soundName)
	if soundTemplate then
		local soundClone = soundTemplate:Clone()
		soundClone.Parent = targetParent
		soundClone:Play()
		-- Automatically queue the clone for destruction once its playback finishes
		Debris:AddItem(soundClone, soundClone.TimeLength)
	end
end

--[[
    Binds a UI mouse hover connection to an interface button.
    NOTE: This must be executed purely inside a LocalScript.
    @param button GuiButton: The interactive UI button receiving the connection.
]]
function GuiSoundsModule.HoverSoundButton(button)
	if not button or not button:IsA("GuiButton") then return end
	
	button.MouseEnter:Connect(function()
		playSoundBase("HoverSound", button)
	end)
end

--[[
    Plays the transactional item purchase success sound effect.
]]
function GuiSoundsModule.purchaseSound(targetInstance)
	playSoundBase("Purchase", targetInstance)
end

--[[
    Plays the open-window canvas interface sound effect.
]]
function GuiSoundsModule.OpenGui(targetInstance)
	playSoundBase("OpenGui", targetInstance)
end

--[[
    Plays a standard list/grid option item selection sound effect.
]]
function GuiSoundsModule.Select(targetInstance)
	playSoundBase("Select", targetInstance)
end

--[[
    Plays the sound effect associated with deploying a battlefield tactical unit.
]]
function GuiSoundsModule.DeployUnit(targetInstance)
	playSoundBase("DeployUnit", targetInstance)
end

--[[
    Plays a generic mouse click transactional interface sound effect.
]]
function GuiSoundsModule.Click(targetInstance)
	playSoundBase("Click", targetInstance)
end

return GuiSoundsModule