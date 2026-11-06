-- player.lua
-- What the PLAYER owns: coins, which die is in each of the 5 slots
-- (their "loadout"), and spare dice waiting in their inventory.
--
-- Pure LOGIC/data - nothing in here draws.

local config    = require("config")
local dicetypes = require("dicetypes")

local player = {}

---------------------------------------------------------------------------
-- DATA
---------------------------------------------------------------------------

player.coins = 0

-- Special Unlock Tokens (from the Unlock Token luck item). They don't do
-- anything yet - they're saved up for a future unlock system.
player.unlockTokens = 0

-- player.loadout[i] is the die TYPE id used for die i, e.g. "white" or "red".
-- These are the 5 dice that actually get rolled.
player.loadout = {}

-- Dice the player has bought but isn't using yet. A list of type ids,
-- e.g. { "red", "purple" }.
player.inventory = {}


---------------------------------------------------------------------------
-- FUNCTIONS
---------------------------------------------------------------------------

-- Back to the start of a new game: no coins, 5 starter dice, empty inventory.
function player.reset()
    player.coins        = 0
    player.unlockTokens = 0
    player.inventory    = {}
    for i = 1, config.NUM_DICE do
        player.loadout[i] = dicetypes.STARTER
    end
end

-- Give the player coins (from a Money Maker hand, or from god mode).
function player.addCoins(amount)
    player.coins = player.coins + amount
end

-- Try to spend coins. Returns true if they had enough (and pays),
-- false if they didn't (and nothing changes).
function player.spend(amount)
    if player.coins < amount then
        return false
    end
    player.coins = player.coins - amount
    return true
end

-- Put a newly bought die in the inventory.
function player.addToInventory(typeId)
    table.insert(player.inventory, typeId)
end

-- Swap inventory die number 'invIndex' into loadout slot 'slot'.
-- The die that was in the slot goes back to the inventory - unless it's
-- a plain starter die, which is just thrown away so the inventory doesn't
-- fill up with white dice.
function player.equip(slot, invIndex)
    local incoming = player.inventory[invIndex]
    if incoming == nil then
        return
    end

    local outgoing = player.loadout[slot]
    player.loadout[slot] = incoming

    if outgoing == dicetypes.STARTER then
        -- table.remove takes an item out of a list and closes the gap.
        table.remove(player.inventory, invIndex)
    else
        player.inventory[invIndex] = outgoing   -- straight swap
    end
end

-- Start with a fresh player as soon as this file is loaded, so loadout is
-- never empty (dice.lua reads it the first time it rolls).
player.reset()

return player
