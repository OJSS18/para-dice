-- dice.lua
-- The dice LOGIC: their values, which ones the player is keeping, the
-- total and rerolls.
-- Nothing in this file draws anything. It only changes data.
--
-- How a turn works:
--   * A round starts with all 5 dice in the tray. The first throw always
--     sends all 5.
--   * After that, the player marks dice to HOLD. A REROLL throws every die
--     that ISN'T held. Held dice stay held for the next reroll too.
--   * No Reroll (KEEP) keeps all 5 as they are (and earns the points bonus).

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

-- dice.held[i] is true if the player is HOLDING die i (a reroll won't touch it).
-- Keeping it as a separate list means dice.values[i] is always just a number.
dice.held = {}

-- dice.thrown[i] is true once die i has been thrown this round.
-- (Before that, dice.values[i] is just last round's face, shown dimmed.)
dice.thrown = {}

-- The sum of the thrown dice's pips. Recalculated every time the dice change,
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

-- Add up every thrown die's value and return the sum.
local function sumValues()
    local sum = 0
    for i = 1, config.NUM_DICE do
        if dice.thrown[i] then
            sum = sum + dice.values[i]
        end
    end
    return sum
end

-- Let go of every held die.
local function clearHeld()
    for i = 1, config.NUM_DICE do
        dice.held[i] = false
    end
end


---------------------------------------------------------------------------
-- PUBLIC FUNCTIONS (other files can call these)
---------------------------------------------------------------------------

-- Will die i be thrown by the next throw?
--   First throw of the round: every die.
--   A reroll: every die that isn't held.
function dice.willThrow(i)
    if not dice.allThrown() then
        return true
    end
    return not dice.held[i]
end

-- How many dice will the next throw send?
function dice.countToThrow()
    local count = 0
    for i = 1, config.NUM_DICE do
        if dice.willThrow(i) then
            count = count + 1
        end
    end
    return count
end

-- Have all 5 dice been thrown this round?
function dice.allThrown()
    for i = 1, config.NUM_DICE do
        if not dice.thrown[i] then
            return false
        end
    end
    return true
end

-- Can the player reroll right now? Only once every die is out, with
-- rerolls left, and before pressing KEEP.
function dice.canReroll()
    return dice.allThrown() and dice.rerollsLeft > 0 and not dice.decided
end

-- Can dice be held right now? Only after the first throw, while there's
-- a reroll left (holding is about choosing what NOT to reroll).
function dice.canHold()
    return dice.canReroll()
end

-- Can the dice be thrown right now? The first throw always can; a reroll
-- needs a reroll left and at least one die that isn't held.
function dice.canThrow()
    if dice.decided then
        return false
    end
    if not dice.allThrown() then
        return true
    end
    return dice.canReroll() and dice.countToThrow() > 0
end

-- Can the player press KEEP right now? Once all 5 are out and before the
-- round is decided (even with zero rerolls - e.g. when holding Addict).
function dice.canKeep()
    return dice.allThrown() and not dice.decided
end

-- Has the player rerolled any dice this round?
-- If you've used fewer rerolls than you started with, the answer is no.
-- The KEEP bonus is only for players who never rerolled.
function dice.hasRerolled()
    return dice.rerollsLeft < dice.rerollsGiven
end

-- Give every die a value (used once at startup, so they're never empty).
function dice.rollAll()
    for i = 1, config.NUM_DICE do
        dice.values[i] = rollDie(i)
        dice.thrown[i] = true
    end
    clearHeld()
    dice.total = sumValues()
end

-- Start a new round: all 5 dice back in the tray, none thrown or held.
function dice.newRound()
    for i = 1, config.NUM_DICE do
        dice.thrown[i] = false
        dice.held[i] = false
    end
    dice.total = 0
    -- Rerolls for this round: normally MAX_REROLLS, but a luck item can
    -- add one (They See Me Rollin') or take them all away (Addict).
    dice.rerollsGiven = luck.rerollsPerRound(config.MAX_REROLLS)
    dice.rerollsLeft  = dice.rerollsGiven
    dice.decided = false
end

-- Hold or let go of die number i. "not" flips true <-> false.
function dice.toggleHold(i)
    if dice.canHold() then
        dice.held[i] = not dice.held[i]
    end
end

-- Hold every die (the A key). If they're ALL held already, let them all go.
function dice.holdAll()
    if not dice.canHold() then
        return
    end
    local allHeld = true
    for i = 1, config.NUM_DICE do
        if not dice.held[i] then
            allHeld = false
        end
    end
    for i = 1, config.NUM_DICE do
        dice.held[i] = not allHeld
    end
end

-- Throw: the first throw sends all 5 dice, a reroll sends every die that
-- isn't held. Their real results are decided HERE.
-- Returns TWO values (Lua functions can do that):
--   1. true if a throw happened, false if it didn't
--   2. a list of which dice were thrown, e.g. {2, 5}
--      (so main.lua can send just those dice across the table)
-- Call it like:   local thrown, which = dice.throw()
function dice.throw()
    if not dice.canThrow() then
        return false, {}
    end
    local isReroll = dice.allThrown()
    if isReroll then
        dice.rerollsLeft = dice.rerollsLeft - 1   -- use up one reroll
    end

    local which = {}
    for i = 1, config.NUM_DICE do
        if dice.willThrow(i) then
            dice.values[i] = rollDie(i)
            dice.thrown[i] = true
            table.insert(which, i)   -- remember that die i was thrown
        end
    end

    -- Held dice stay held for the next reroll - unless there isn't one.
    if dice.rerollsLeft <= 0 then
        clearHeld()
    end

    dice.total = sumValues()
    return true, which
end

-- Is the next throw a reroll? (Asked BEFORE throwing, by main.lua.)
function dice.nextThrowIsReroll()
    return dice.allThrown()
end

-- No Reroll: keep every die as it is and give up any rerolls left.
-- Returns true if that was allowed, false if not.
function dice.noReroll()
    if not dice.canKeep() then
        return false
    end
    clearHeld()
    dice.rerollsLeft = 0    -- uses up the rest of your rerolls
    dice.decided = true
    return true
end

return dice
