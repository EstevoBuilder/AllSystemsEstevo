local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GunsInfo = {}

-- Comprehensive combat parameters matrix matching active weapon identities
GunsInfo.GeneralInfo = {
	["Ak-47"] = {
		Damage = 17,
		Cadence = 0.1,
		Magazine = 30,
		Recoil = 20,
		Range = 500,
		TimerSoundReload = 1.8,
		TypeState = "Automatic",
		Shot = "Normal",
		Beam = true,
		
		-- Distance Falloff Damage Matrices
		FalloffStart = 60,       -- Maximum range in studs maintaining peak default damage (100%)
		MinDamagePercent = 0.6,   -- Baseline scale multiplier applied when hit approaches maximum range boundaries
		
		Animations = {
			Hold = ReplicatedStorage.Animations["Ak-47"].Hold,
			Aim = ReplicatedStorage.Animations["Ak-47"].Aim,
			Fire = ReplicatedStorage.Animations["Ak-47"].Fire,
			Reload = ReplicatedStorage.Animations["Ak-47"].Reload
		},
		Sounds = {
			Fire = ReplicatedStorage.Sounds["Ak-47"]:WaitForChild("Fire"),
			Reload = ReplicatedStorage.Sounds["Ak-47"]:WaitForChild("Reload"),
			Equip = ReplicatedStorage.Sounds["Ak-47"]:WaitForChild("Equip"),
		}
	},
	["Pump"] = {
		Damage = 20,
		Cadence = 1,
		Magazine = 6,
		Recoil = 200,
		Range = 100,
		TimerSoundReload = 1,
		TypeState = "Semi-automatic",
		Shot = "shard",
		
		-- Multi-Projectile Cluster Configurations
		Pellets = 8, 
		Spread = 0.1,
		Beam = true,
		
		-- Distance Falloff Damage Matrices
		FalloffStart = 10, 
		MinDamagePercent = 0.1,  
		
		Animations = {
			Hold = ReplicatedStorage.Animations["Pump"].Hold,
			Aim = ReplicatedStorage.Animations["Pump"].Aim,
			Fire = ReplicatedStorage.Animations["Pump"].Fire,
			Reload = ReplicatedStorage.Animations["Pump"].Reload
		},
		Sounds = {
			Fire = ReplicatedStorage.Sounds["Pump"]:WaitForChild("Fire"),
			Reload = ReplicatedStorage.Sounds["Pump"]:WaitForChild("Reload"),
			Equip = ReplicatedStorage.Sounds["Pump"]:WaitForChild("Equip"),
		}
	},
	["Colt"] = {
		Damage = 17,
		Cadence = 0.2,
		Magazine = 7,
		Recoil = 20,
		Range = 500,
		TimerSoundReload = 1,
		TypeState = "Semi-automatic",
		Shot = "Normal",
		Beam = true,
		
		-- Distance Falloff Damage Matrices
		FalloffStart = 60, 
		MinDamagePercent = 0.5,
		
		Animations = {
			Hold = ReplicatedStorage.Animations["Colt"].Hold,
			Aim = ReplicatedStorage.Animations["Colt"].Aim,
			Fire = ReplicatedStorage.Animations["Colt"].Fire,
			Reload = ReplicatedStorage.Animations["Colt"].Reload
		},
		Sounds = {
			Fire = ReplicatedStorage.Sounds["Colt"]:WaitForChild("Fire"),
			Reload = ReplicatedStorage.Sounds["Colt"]:WaitForChild("Reload"),
			Equip = ReplicatedStorage.Sounds["Colt"]:WaitForChild("Equip"),
		}
	},
}

-- Damage scale multipliers mapped by character anatomy limb targets
GunsInfo.MultiplierHit = {
	["Head"] = 2,
	["Torso"] = 1,
	["Left Leg"] = 0.4,
	["Right Leg"] = 0.4,
	["Right Arm"] = 0.6,
	["Left Arm"] = 0.6
}

return GunsInfo