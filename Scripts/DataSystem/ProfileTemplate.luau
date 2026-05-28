--[[
    Default player data template.
    This table defines the initial stats and inventories assigned to new players when they first join.
]]
return {
    Coins = 0, -- The player's current currency balance
    Wins = 0,  -- The total number of victories accumulated by the player

    -- Inventories (Tables storing unique identifiers of unlocked items)
    ItemsCoins = {},   -- Stores purchased coin-related cosmetics or multipliers
    ItemsTitles = {},  -- Stores unlocked overhead or chat titles
    ItemsEffects = {}, -- Stores unlocked visual particle effects
}