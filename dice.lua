-- dice.lua
-- The dice LOGIC: their values, which ones the player is keeping, the
-- total and rerolls.
-- Nothing in this file draws anything. It only changes data.
--
-- How a turn works:
--   * A round starts with all 5 dice in the tray, not thrown yet.
--   * The player picks which dice to throw (1-5 at a time, A = all) and
--     throws them. Until all 5 have been thrown, throwing is free.
--   * Once all 5 are out, throwing again is a REROLL of the picked dice.
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

-- dice.selected[i] is true if die i is picked to be THROWN next.
-- Keeping it as a separate list means dice.values[i] is always just a number.
dice.selected = {}

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

-- Un-pick every die.
local function clearSelected()
    for i = 1, config.NUM_DICE do
        dice.selected[i] = false
    end
end


---------------------------------------------------------------------------
-- PUBLIC FUNCTIONS (other files can call these)
---------------------------------------------------------------------------

-- How many dice are picked to be thrown?
function dice.countSelected()
    local count = 0
    for i = 1, config.NUM_DICE do
        if dice.selected[i] then
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

-- Can die i be picked to throw right now?
--   Before all 5 are out: only the dice still in the tray.
--   After that: any die, as long as there's a reroll left.
function dice.canSelect(i)
    if dice.decided then
        return false
    end
    if not dice.allThrown() then
        return not dice.thrown[i]
    end
    return dice.canReroll()
end

-- Can the picked dice be thrown right now?
function dice.canThrow()
    return dice.countSelected() > 0 and (not dice.allThrown() or dice.canReroll())
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
    clearSelected()
    dice.total = sumValues()
end

-- Start a new round: all 5 dice back in the tray, none thrown yet, and
-- all of them picked (so one throw sends all 5 - or un-pick some first).
function dice.newRound()
    for i = 1, config.NUM_DICE do
        dice.thrown[i] = false
        dice.selected[i] = true
    end
    dice.total = 0
    -- Rerolls for this round: normally MAX_REROLLS, but a luck item can
    -- add one (They See Me Rollin') or take them all away (Addict).
    dice.rerollsGiven = luck.rerollsPerRound(config.MAX_REROLLS)
    dice.rerollsLeft  = dice.rerollsGiven
    dice.decided = false
end

-- Pick or un-pick die number i. "not" flips true <-> false.
function dice.toggleSelect(i)
    if dice.canSelect(i) then
        dice.selected[i] = not dice.selected[i]
    end
end

-- Pick every die that can be picked (the A key).
-- If they're ALL picked already, un-pick them all instead.
function dice.selectAll()
    local allOn = true
    for i = 1, config.NUM_DICE do
        if dice.canSelect(i) and not dice.selected[i] then
            allOn = false
        end
    end
    for i = 1, config.NUM_DICE do
        dice.selected[i] = dice.canSelect(i) and not allOn
    end
end

-- Throw the picked dice: their real results are decided HERE.
-- Returns TWO values (Lua functions can do that):
--   1. true if a throw happened, false if it didn't
--   2. a list of which dice were thrown, e.g. {2, 5}
--      (so main.lua can send just those dice across the table)
-- Call it like:   local thrown, which = dice.throwSelected()
function dice.throwSelected()
    if not dice.canThrow() then
        return false, {}
    end
    local isReroll = dice.allThrown()
    if isReroll then
        dice.rerollsLeft = dice.rerollsLeft - 1   -- use up one reroll
    end

    local which = {}
    for i = 1, config.NUM_DICE do
        if dice.selected[i] then
            dice.values[i] = rollDie(i)
            dice.thrown[i] = true
            table.insert(which, i)   -- remember that die i was thrown
        end
    end
    clearSelected()

    -- Still some dice in the tray? Pick them, ready for the next throw.
    if not dice.allThrown() then
        for i = 1, config.NUM_DICE do
            dice.selected[i] = not dice.thrown[i]
        end
    end

    dice.total = sumValues()
    return true, which
end

-- Was that last throw a reroll? (Asked BEFORE throwing, by main.lua.)
function dice.nextThrowIsReroll()
    return dice.allThrown()
end

-- No Reroll: keep every die as it is and give up any rerolls left.
-- Returns true if that was allowed, false if not.
function dice.noReroll()
    if not dice.canKeep() then
        return false
    end
    clearSelected()
    dice.rerollsLeft = 0    -- uses up the rest of your rerolls
    dice.decided = true
    return true
end

return dice
