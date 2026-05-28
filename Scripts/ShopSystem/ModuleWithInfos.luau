local ItemsModule = {}

--[[
    Central Game Catalog Configuration.
    Stores all purchasable assets, cosmetics, and traits mapped out by category.
    
    Fields:
    - Price (number): Cost in the specified currency.
    - Permanent (string): "Yes" or "Not" flag denoting inventory retention upon death/reset.
    - ShopType (string): Defines categorization ("Coins", "Title", "Trail", "Particle", "Robux").
    - ColorText / StrokeColor (Color3): Specific rendering configurations for UI text titles.
    - Color (Color3/ColorSequence): Graphical asset coloring tint parameters.
    - Target (string): Character skeletal assembly point to bind visual effects to.
]]
ItemsModule.Shops = {
	-- ==========================================
	-- COIN ITEMS (In-game Tools & Consumables)
	-- ==========================================
	["JumpPotion"] = {Price = 100, Permanent = "Not", ShopType = "Coins"},
	["Snowball"] = {Price = 200, Permanent = "Not", ShopType = "Coins"},
	["EnderPearl"] = {Price = 250, Permanent = "Not", ShopType = "Coins"},
	["Smoke"] = {Price = 1750, Permanent = "Not", ShopType = "Coins"},
	["SpeedCoil"] = {Price = 5000, Permanent = "Yes", ShopType = "Coins"},
	["GrappleHook"] = {Price = 12000, Permanent = "Yes", ShopType = "Coins"},

	-- ==========================================
	-- OVERHEAD TITLES (Chat/Billboard Cosmetics)
	-- ==========================================
	["Noob"] = {
		Price = 50, 
		ShopType = "Title",
		ColorText = Color3.fromRGB(255, 255, 255),
		StrokeColor = Color3.fromRGB(0, 0, 0),
	},
	["Poor"] = {
		Price = 100, 
		ShopType = "Title",
		ColorText = Color3.fromRGB(170, 85, 0),
		StrokeColor = Color3.fromRGB(103, 52, 0),
	},
	["Monotonous"] = {
		Price = 250, 
		ShopType = "Title",
		ColorText = Color3.fromRGB(170, 170, 170),
		StrokeColor = Color3.fromRGB(85, 85, 85),
	},
	["Casual"] = {
		Price = 500, 
		ShopType = "Title",
		ColorText = Color3.fromRGB(170, 170, 255),
		StrokeColor = Color3.fromRGB(85, 85, 170),
	},
	["Fighter"] = {
		Price = 800, 
		ShopType = "Title",
		ColorText = Color3.fromRGB(255, 0, 0),
		StrokeColor = Color3.fromRGB(170, 0, 0),
	},
	["Artist"] = {
		Price = 1200, 
		ShopType = "Title",
		ColorText = Color3.fromRGB(255, 255, 0),
		StrokeColor = Color3.fromRGB(170, 170, 0),
	},
	["Thinker"] = {
		Price = 1600, 
		ShopType = "Title",
		ColorText = Color3.fromRGB(0, 0, 255),
		StrokeColor = Color3.fromRGB(0, 0, 170),
	},
	["Scout"] = {
		Price = 2200, 
		ShopType = "Title",
		ColorText = Color3.fromRGB(0, 255, 255),
		StrokeColor = Color3.fromRGB(0, 170, 170),
	},
	["Friendly"] = {
		Price = 3000, 
		ShopType = "Title",
		ColorText = Color3.fromRGB(0, 255, 0),
		StrokeColor = Color3.fromRGB(0, 170, 0),
	},
	["Faithful"] = {
		Price = 3800, 
		ShopType = "Title",
		ColorText = Color3.fromRGB(255, 255, 255),
		StrokeColor = Color3.fromRGB(170, 170, 170),
	},
	["Cool"] = {
		Price = 4600, 
		ShopType = "Title",
		ColorText = Color3.fromRGB(0, 170, 255),
		StrokeColor = Color3.fromRGB(0, 0, 255),
	},
	["Intelligent"] = {
		Price = 5500, 
		ShopType = "Title",
		ColorText = Color3.fromRGB(255, 85, 255),
		StrokeColor = Color3.fromRGB(170, 55, 170),
	},
	["Innovative"] = {
		Price = 7000, 
		ShopType = "Title",
		ColorText = Color3.fromRGB(255, 170, 0),
		StrokeColor = Color3.fromRGB(170, 85, 0),
	},
	["Lucky"] = {
		Price = 8500, 
		ShopType = "Title",
		ColorText = Color3.fromRGB(255, 255, 0),
		StrokeColor = Color3.fromRGB(170, 170, 0),
	},
	["Brave"] = {
		Price = 10000, 
		ShopType = "Title",
		ColorText = Color3.fromRGB(255, 0, 0),
		StrokeColor = Color3.fromRGB(170, 0, 0),
	},
	["Nemesis"] = {
		Price = 13000, 
		ShopType = "Title",
		ColorText = Color3.fromRGB(120, 0, 180),
		StrokeColor = Color3.fromRGB(0, 0, 0),
	},
	["Alien"] = {
		Price = 17000, 
		ShopType = "Title",
		ColorText = Color3.fromRGB(0, 255, 0),
		StrokeColor = Color3.fromRGB(0, 170, 0),
	},
	["Typical"] = {
		Price = 22000, 
		ShopType = "Title",
		ColorText = Color3.fromRGB(0, 0, 0),
		StrokeColor = Color3.fromRGB(168, 0, 168),
	},
	["Worthy"] = {
		Price = 28000, 
		ShopType = "Title",
		ColorText = Color3.fromRGB(255, 85, 0),
		StrokeColor = Color3.fromRGB(255, 255, 255),
	},
	[")-:"] = {
		Price = 100000, 
		ShopType = "Title",
		ColorText = Color3.fromRGB(85, 255, 255),
		StrokeColor = Color3.fromRGB(0, 85, 255),
	},
	[":-)"] = {
		Price = 100000, 
		ShopType = "Title",
		ColorText = Color3.fromRGB(255, 255, 0),
		StrokeColor = Color3.fromRGB(200, 200, 0),
	},
	
	-- Premium Robux Titles
	["Rich"] = {
		Price = 0, -- CRITICAL FIX: Explicit assignment to prevent UI runtime index crashes
		ShopType = "Robux",
		ColorText = Color3.fromRGB(255, 255, 0),
		StrokeColor = Color3.fromRGB(117, 117, 0),
	},

	-- ==========================================
	-- VISUAL TRAILS (Movement Cosmetics)
	-- ==========================================
	["Trail White"] = {
		Price = 50,
		ShopType = "Trail",
		Color = Color3.fromRGB(255, 255, 255),
	},
	["Trail Black"] = {
		Price = 150,
		ShopType = "Trail",
		Color = Color3.fromRGB(0, 0, 0),
	},
	["Trail Green"] = {
		Price = 300,
		ShopType = "Trail",
		Color = Color3.fromRGB(0, 255, 0),
	},
	["Trail Yellow"] = {
		Price = 500,
		ShopType = "Trail",
		Color = Color3.fromRGB(255, 255, 0),
	},
	["Trail Orange"] = {
		Price = 700,
		ShopType = "Trail",
		Color = Color3.fromRGB(255, 170, 0),
	},
	["Trail Blue"] = {
		Price = 1000,
		ShopType = "Trail",
		Color = Color3.fromRGB(0, 0, 255),
	},
	["Trail Purple"] = {
		Price = 1400,
		ShopType = "Trail",
		Color = Color3.fromRGB(170, 0, 255),
	},
	["Trail Pink"] = {
		Price = 1800,
		ShopType = "Trail",
		Color = Color3.fromRGB(255, 0, 255),
	},
	["Trail Red"] = {
		Price = 2300,
		ShopType = "Trail",
		Color = Color3.fromRGB(255, 0, 0),
	},
	["Trail Rainbow"] = {
		Price = 5000,
		ShopType = "Trail",
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
			ColorSequenceKeypoint.new(0.166, Color3.fromRGB(255, 127, 0)),
			ColorSequenceKeypoint.new(0.333, Color3.fromRGB(255, 255, 0)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 0)),
			ColorSequenceKeypoint.new(0.666, Color3.fromRGB(0, 170, 255)),
			ColorSequenceKeypoint.new(0.833, Color3.fromRGB(170, 0, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 127))
		}),
	},

	-- ==========================================
	-- VISUAL AURAS (Particle Emitter Cosmetics)
	-- ==========================================
	["Aura Eight Paths"] = {
		Price = 45000, 
		ShopType = "Particle",
		Target = "HumanoidRootPart",
		Color = Color3.fromRGB(170, 0, 127),
	},
	["Aura Incognito"] = {
		Price = 65000, 
		ShopType = "Particle",
		Target = "Head",
		Color = Color3.fromRGB(185, 0, 0),
	},
	["Aura Celeste"] = {
		Price = 85000, 
		ShopType = "Particle",
		Target = "HumanoidRootPart",
		Color = Color3.fromRGB(255, 255, 0),
	},
	["Aura Wings"] = {
		Price = 110000, 
		ShopType = "Particle",
		Target = "HumanoidRootPart",
		Color = Color3.fromRGB(255, 255, 255),
	},
	["Aura Cape"] = {
		Price = 150000, 
		ShopType = "Particle",
		Target = "HumanoidRootPart",
		Color = Color3.fromRGB(170, 0, 0),
	},
	
	-- Premium Robux Auras
	["Aura Crown"] = {
		Price = 0,
		ShopType = "Robux",
		Target = "Head",
	}
}

return ItemsModule