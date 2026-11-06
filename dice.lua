-- dice.lua
-- The dice LOGIC: their values, which ones the player is keeping, the
-- total and rerolls.
-- Nothing in this file draws anything. It only changes data.
--
-- How a turn works:
--   * After a roll, the player marks dice to KEEP.
--   * Reroll rerolls every die that ISN'T kept.
--   * No Reroll keeps all 5 as they are (and earns the points bonus).

local config    = require("config")
local dicetypes = require("dicetypes")
local player    = require("player")
local luck      = require("luck")

local dice = {}

---------------------------------------------------------------------------
-- DATA
---------------------------------------------------------------------------

-- dice.values[i] is the number (1-6) showing on die i.
-- (Lua lists start counting at 1, not 0!)
dice.values = {}

-- dice.kept[i] is true if the player is KEEPING die i (it won't be rerolled).
-- Keeping it as a separate list means dice.values[i] is always just a number.
dice.kept = {}

-- The sum of all the dice's pips. Recalculated every time the dice change,
-- so the drawing code can just read it.
dice.total = 0

-- How many rerolls this round started with (usually config.MAX_REROLLS,
-- but luck items can change it), and how many are left.
dice.rerollsGiven = config.MAX_REROLLS
dice.rerollsLeft  = config.MAX_REROLLS

-- true once the player has pressed KEEP this round (the round is decided).
dice.decided = false


---------------------------------------------------------------------------
-- HELPERS (only used inside this file, so they're 'local', not 'dice.')
---------------------------------------------------------------------------

-- Roll die number i and return its new value (1-6).
-- Each slot can hold a different TYPE of die (white, red, ...), and each
-- type has its own odds. A held luck item can tilt the odds further.
local function rollDie(i)
    local dieType = dicetypes.get(player.loadout[i])
    local weights = luck.applyTo(dieType.weights)
    return dicetypes.pickFace(weights)
end

-- Add up every die's value and return the sum.
local function sumValues()
    local sum = 0
    for i = 1, config.NUM_DICE do
        sum = sum + dice.values[i]
    end
    return sum
end

-- Un-keep every die.
local function clearKept()
    for i = 1, config.NUM_DICE do
        dice.kept[i] = false
    end
end


---------------------------------------------------------------------------
-- PUBLIC FUNCTIONS (other files can call these)
---------------------------------------------------------------------------

-- How many dice is the player keeping?
function dice.countKept()
    local count = 0
    for i = 1, config.NUM_DICE do
        if dice.kept[i] then
            count = count + 1
        end
    end
    return count
end

-- How many dice WOULD a reroll change right now? (all the un-kept ones)
function dice.countToReroll()
    return config.NUM_DICE - dice.countKept()
end

-- Can the player reroll right now? Only if they have rerolls left and
-- haven't already pressed KEEP.
function dice.canReroll()
    return dice.rerollsLeft > 0 and not dice.decided
end

-- Can the player press KEEP right now? Any time before the round is decided
-- (even with zero rerolls - e.g. when holding Addict).
function dice.canKeep()
    return not dice.decided
end

-- Has the player rerolled any dice this round?
-- If you've used fewer rerolls than you started with, the answer is no.
-- The KEEP bonus is only for players who never rerolled.
function dice.hasRerolled()
    return dice.rerollsLeft < dice.rerollsGiven
end

-- Roll every die fresh. Each die keeps its slot ("in place");
-- only its value changes. This also starts a new turn.
function dice.rollAll()
    for i = 1, config.NUM_DICE do
        dice.values[i] = rollDie(i)
    end
    clearKept()                            -- nothing kept to start with
    dice.total = sumValues()               -- update the total
    -- Rerolls for this round: normally MAX_REROLLS, but a luck item can
    -- add one (They See Me Rollin') or take them all away (Addict).
    dice.rerollsGiven = luck.rerollsPerRound(config.MAX_REROLLS)
    dice.rerollsLeft  = dice.rerollsGiven
    dice.decided = false
end

-- Keep or un-keep die number i. "not" flips true <-> false.
function dice.toggleKeep(i)
    -- No rerolls left means there's nothing to keep dice FROM, so ignore it.
    if not dice.canReroll() then
        return
    end
    dice.kept[i] = not dice.kept[i]
end

-- Reroll every die that ISN'T kept. Kept dice stay as they are.
-- Returns TWO values (Lua functions can do that):
--   1. true if a reroll happened, false if it didn't
--   2. a list of which dice were rerolled, e.g. {2, 5}
--      (so main.lua can animate just those dice)
-- Call it like:   local rerolled, which = dice.rerollUnkept()
function dice.rerollUnkept()
    -- Leave early if the reroll is used up, or every die is kept
    -- (keeping all 5 is what No Reroll is for).
    if not dice.canReroll() or dice.countToReroll() == 0 then
        return false, {}
    end
    dice.rerollsLeft = dice.rerollsLeft - 1   -- use up one reroll

    local which = {}
    for i = 1, config.NUM_DICE do
        if not dice.kept[i] then
            dice.values[i] = rollDie(i)
            table.insert(which, i)   -- remember that die i was rerolled
        end
    end
    clearKept()
    dice.total = sumValues()
    return true, which
end

-- No Reroll: keep every die as it is and give up any rerolls left.
-- Returns true if that was allowed, false if not.
function dice.noReroll()
    if not dice.canKeep() then
        return false
    end
    clearKept()
    dice.rerollsLeft = 0    -- uses up the rest of your rerolls
    dice.decided = true
    return true
end

return dice
