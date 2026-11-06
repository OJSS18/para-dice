-- score.lua
-- Turns a round's final dice into POINTS and COINS, and keeps the
-- running score.
--
-- A ROUND goes like this:
--   1. The 5 dice are rolled.
--   2. The player picks dice to KEEP and rerolls the rest - or chooses
--      NO REROLL and keeps all 5 as they are.
--   3. The 5 final dice are scored twice:
--        POINTS - their sum (5 to 30) is looked up in POINT_VALUES.
--                 No Reroll multiplies the points by 1.1.
--        COINS  - if they make a "Money Maker" hand (Full House, Straight...)
--                 the best one pays coins, using Yahtzee's own scores.
--   4. Points go to the level score; coins go to the player.
--
-- A LEVEL is ROUNDS_PER_LEVEL rounds. After the last one, if the level
-- score reached the level's target the level is cleared; if not, game over.
--
-- Like dice.lua, this file is pure LOGIC: it never draws anything.
-- It's the place to come back to when you add new scoring rules.
-- (The lit-up boxes on the table read their numbers from HERE, so if you
-- change a value below, the boxes change too.)

local markers = require("markers")
local boosts   = require("boosts")
local luck     = require("luck")
local upgrades = require("upgrades")

local score = {}


---------------------------------------------------------------------------
-- RULES: POINTS
---------------------------------------------------------------------------

-- Points for each possible 5-dice sum. Rarer sums score more.
-- Sums that are equally likely (like 5 and 30, or 17 and 18) score the same.
--
--   Sum     | Ways (of 7776) | Chance  | Points
--   5 / 30  |   1            | 0.01%   | 500
--   6 / 29  |   5            | 0.06%   | 390
--   7 / 28  |  15            | 0.19%   | 315
--   8 / 27  |  35            | 0.45%   | 260
--   9 / 26  |  70            | 0.90%   | 215
--   10 / 25 | 126            | 1.62%   | 175
--   11 / 24 | 205            | 2.64%   | 140
--   12 / 23 | 305            | 3.92%   | 115
--   13 / 22 | 420            | 5.40%   |  90
--   14 / 21 | 540            | 6.94%   |  75
--   15 / 20 | 651            | 8.37%   |  60
--   16 / 19 | 735            | 9.45%   |  55
--   17 / 18 | 780            | 10.03%  |  50
--
-- In Lua, [5]=500 means "the key 5 holds the value 500", so
-- score.POINT_VALUES[23] gives 115.
score.POINT_VALUES = {
    [5]=500, [6]=390, [7]=315, [8]=260, [9]=215, [10]=175, [11]=140,
    [12]=115, [13]=90, [14]=75, [15]=60, [16]=55, [17]=50,
    [18]=50, [19]=55, [20]=60, [21]=75, [22]=90, [23]=115, [24]=140,
    [25]=175, [26]=215, [27]=260, [28]=315, [29]=390, [30]=500,
}

-- Choosing No Reroll (keeping all 5 dice) multiplies the round's points by this.
score.NO_REROLL_MULTIPLIER = 1.1

-- The KEEP bonus right now: 1.1, plus 0.1 per level of the KEEP BONUS upgrade.
function score.keepMultiplier()
    -- Rounded to 2 decimals: computers store 1.1 + 0.1 as 1.2000000000000002,
    -- which would look silly on screen.
    return math.floor(upgrades.keepMultiplier(score.NO_REROLL_MULTIPLIER) * 100 + 0.5) / 100
end


---------------------------------------------------------------------------
-- RULES: COINS (the "Money Makers")
---------------------------------------------------------------------------
-- Coins use the same values as the classic Yahtzee scorecard:
--   5 of a Kind (all 5 the same)   50
--   Large Straight (5 in a row)    40
--   Small Straight (4 in a row)    30
--   Full House (3 of one + 2 of another)  25
--   4 of a Kind                    sum of all 5 dice
--   3 of a Kind                    sum of all 5 dice
-- A roll can match more than one (four 6s is also three 6s); only the
-- one that pays the MOST is paid.
--
-- coins = "sum" means "pays the total of all 5 dice".
-- This list is in order from best to worst, which is also the order the
-- boxes are drawn on the table.
score.COIN_HANDS = {
    { id = "fiveKind",      name = "5 of a Kind",    coins = 50 },
    { id = "largeStraight", name = "Large Straight", coins = 40 },
    { id = "smallStraight", name = "Small Straight", coins = 30 },
    { id = "fullHouse",     name = "Full House",     coins = 25 },
    { id = "fourKind",      name = "4 of a Kind",    coins = "sum" },
    { id = "threeKind",     name = "3 of a Kind",    coins = "sum" },
}


---------------------------------------------------------------------------
-- RULES: LEVELS
---------------------------------------------------------------------------

-- How many rounds make up one level.
score.ROUNDS_PER_LEVEL = 5

-- How many levels there are. Clear the last one and you win the game.
score.MAX_LEVEL = 10

-- Points needed to clear level 1, and how much bigger each level's
-- target is than the one before (1.25 = 25% more each level):
--   L1 500   L2 625   L3 781   L4 977   L5 1221 ...   L10 3725
score.FIRST_TARGET  = 500
score.TARGET_GROWTH = 1.25


---------------------------------------------------------------------------
-- DATA (the running score)
---------------------------------------------------------------------------

score.level      = 1  -- which level we're on
score.round      = 0  -- how many rounds have been finished in this level
score.levelTotal = 0  -- points scored in THIS level (resets each level)
score.levelCoins = 0  -- coins earned in THIS level (resets each level)
score.total      = 0  -- points across the whole game (never resets mid-game)

-- A list of every finished round, oldest first. Each entry is a table like:
--   { level = 1, round = 3, sum = 23, noReroll = true, base = 115,
--     points = 127, hand = "Full House", coins = 25 }
score.history = {}

-- The most recent entry from score.history (nil before the first round).
score.lastRound = nil


---------------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------------

-- Round a number to the nearest whole number. Lua has no built-in round(),
-- so we add 0.5 and chop off the decimals with math.floor.
-- e.g. 60.5 -> 61,   126.5 -> 127,   55.0 -> 55
local function roundToWhole(n)
    return math.floor(n + 0.5)
end

-- Add up a list of dice values.
local function sumOf(values)
    local sum = 0
    for _, v in ipairs(values) do
        sum = sum + v
    end
    return sum
end

-- Count how many of each face there are.
-- {6, 2, 6, 6, 2} -> counts[6] = 3, counts[2] = 2, everything else 0.
local function countFaces(values)
    local counts = { 0, 0, 0, 0, 0, 0 }
    for _, v in ipairs(values) do
        counts[v] = counts[v] + 1
    end
    return counts
end

-- Are ALL of these faces present at least once?
-- hasAll(counts, {2, 3, 4, 5}) checks for a 2, a 3, a 4 and a 5.
local function hasAll(counts, faces)
    for _, face in ipairs(faces) do
        if counts[face] == 0 then
            return false
        end
    end
    return true
end


---------------------------------------------------------------------------
-- PUBLIC FUNCTIONS: POINTS
---------------------------------------------------------------------------

-- Base points for a sum, before any multiplier.
-- 'or 0' means: if the sum isn't in the table, give 0 instead of crashing.
function score.pointsForSum(sum)
    return score.POINT_VALUES[sum] or 0
end

-- What a POINTS tile is worth right now, with its lasting boosts from
-- luck items (but not this round's extras like the marker or KEEP).
-- This is the number printed on the tile.
function score.tileValue(sum)
    return roundToWhole((score.pointsForSum(sum) + boosts.flatFor(sum))
        * boosts.multiplierFor(sum) * upgrades.multiplierFor(sum))
end

-- Work out a round's points WITHOUT saving anything.
--   1. Start from the tile's value, plus any flat bonus (Show Me The Money).
--   2. Multiply by everything that applies - they all stack:
--        point boosts (Run it Back, Rabbit's Foot/Leg...)
--        shop upgrades (EVEN, ODD, LOWER 13, UPPER 13, HOT FOUR)
--        x1.5 if a marker is on this sum
--        x2 for Even Steven / That's Odd
--        x1.1 for KEEP with no reroll
--   3. Round once, at the very end.
-- Returns a table describing the result, e.g.
--   { base = 55, flat = 100, boostMult = 1.1, marker = true, luckMult = 1, points = 285 }
function score.calculate(sum, noReroll)
    local r = {
        base        = score.pointsForSum(sum),
        flat        = boosts.flatFor(sum),
        boostMult   = boosts.multiplierFor(sum),
        upgradeMult = upgrades.multiplierFor(sum),
        marker      = markers.isOnSum(sum),
        luckMult    = luck.sumMultiplier(sum),
    }
    local multiplier = r.boostMult * r.upgradeMult * markers.pointsMultiplier(sum) * r.luckMult
    if noReroll then
        multiplier = multiplier * score.keepMultiplier()
    end
    r.points = roundToWhole((r.base + r.flat) * multiplier)
    return r
end

-- Every possible sum in order, with its points - one entry per box on the table:
--   { {sum = 5, points = 500, boosted = false}, ... {sum = 30, points = 500, boosted = false} }
-- Built FROM POINT_VALUES (plus any boosts), so the table always matches
-- the real scoring.
function score.sumBoxes()
    local list = {}
    for sum = 5, 30 do
        table.insert(list, { sum = sum, points = score.tileValue(sum),
            boosted = boosts.isBoosted(sum) or upgrades.multiplierFor(sum) ~= 1 })
    end
    return list
end


---------------------------------------------------------------------------
-- PUBLIC FUNCTIONS: COINS
---------------------------------------------------------------------------

-- Does this list of 5 dice values make the hand with this id?
function score.matchesHand(id, values)
    local counts = countFaces(values)

    -- The biggest pile of matching faces, and whether there's a pair.
    local most, hasPair, hasThree = 0, false, false
    for face = 1, 6 do
        most = math.max(most, counts[face])
        if counts[face] == 2 then hasPair = true end
        if counts[face] == 3 then hasThree = true end
    end

    if id == "fiveKind" then
        return most == 5
    elseif id == "largeStraight" then
        return hasAll(counts, {1, 2, 3, 4, 5}) or hasAll(counts, {2, 3, 4, 5, 6})
    elseif id == "smallStraight" then
        return hasAll(counts, {1, 2, 3, 4}) or hasAll(counts, {2, 3, 4, 5})
            or hasAll(counts, {3, 4, 5, 6})
    elseif id == "fullHouse" then
        return hasThree and hasPair
    elseif id == "fourKind" then
        return most >= 4
    elseif id == "threeKind" then
        return most >= 3
    end
    return false
end

-- How many coins a hand pays for these dice ("sum" hands pay the dice total).
function score.handCoins(hand, values)
    if hand.coins == "sum" then
        return sumOf(values)
    end
    return hand.coins
end

-- The best-paying hand these dice make, counting a marker's x1.5
-- (so a marked Full House at 38 beats an unmarked Small Straight at 30).
-- Returns two values: the hand (a table from COIN_HANDS) and its coins,
-- or nil and 0 if the dice don't make any hand.
function score.bestHand(values)
    local bestHand, bestCoins = nil, 0
    for _, hand in ipairs(score.COIN_HANDS) do
        if score.matchesHand(hand.id, values) then
            local coins = roundToWhole(score.handCoins(hand, values)
                * markers.coinsMultiplier(hand.id) * luck.coinsMultiplier())
            if coins > bestCoins then
                bestHand, bestCoins = hand, coins
            end
        end
    end
    return bestHand, bestCoins
end


---------------------------------------------------------------------------
-- PUBLIC FUNCTIONS: ROUNDS AND LEVELS
---------------------------------------------------------------------------

-- Score a finished round from its 5 final dice values.
-- Adds the points to the totals, works out the coins, and saves the round.
-- Returns the saved entry (main.lua uses entry.coins to pay the player).
function score.recordRound(values, noReroll)
    local sum = sumOf(values)
    local calc = score.calculate(sum, noReroll)
    local hand, coins = score.bestHand(values)

    -- F*** You Pay Me: coins equal to the point's tile value (doubled by Cash
    -- is King too, though you can only hold one item at a time anyway).
    local payMe = roundToWhole(luck.payMeCoins(score.tileValue(sum)) * luck.coinsMultiplier())

    score.round      = score.round + 1
    score.levelTotal = score.levelTotal + calc.points
    score.levelCoins = score.levelCoins + coins + payMe
    score.total      = score.total + calc.points

    local entry = {
        level    = score.level,
        round    = score.round,
        sum      = sum,
        noReroll = noReroll,
        base     = calc.base,
        points   = calc.points,
        -- 'hand and hand.name' = the hand's name, or nil if there's no hand.
        hand     = hand and hand.name,
        coins    = coins + payMe,
        payMe    = payMe,
        -- What boosted this round (for the round result text)
        flat         = calc.flat,
        boostMult    = calc.boostMult,
        upgradeMult  = calc.upgradeMult,
        luckMult     = calc.luckMult,
        markerPoints = calc.marker,
        markerCoins  = hand ~= nil and markers.isOnHand(hand.id),
    }
    table.insert(score.history, entry)
    score.lastRound = entry
    return entry
end

-- Points needed to clear a level:
--   FIRST_TARGET x TARGET_GROWTH ^ (level - 1), rounded to a whole number.
-- '^' means "to the power of": 1.25 ^ 2 = 1.25 x 1.25 = 1.5625.
-- A luck item (Addict) can lower the CURRENT level's goal.
function score.getTarget(level)
    level = level or score.level   -- no level given? use the current one
    local target = score.FIRST_TARGET * score.TARGET_GROWTH ^ (level - 1)
    if level == score.level then
        target = target * luck.targetMultiplier()
    end
    return roundToWhole(target)
end

-- Is this the last level? Clearing it wins the game.
function score.isFinalLevel()
    return score.level >= score.MAX_LEVEL
end

-- Have all the rounds in this level been played?
function score.isLevelOver()
    return score.round >= score.ROUNDS_PER_LEVEL
end

-- Did the player score enough this level to clear it?
function score.hasPassedLevel()
    return score.levelTotal >= score.getTarget()
end

-- Move on to the next level. The level score, coins counter and round
-- count go back to zero; the whole-game total and the history are kept.
function score.startNextLevel()
    score.level      = score.level + 1
    score.round      = 0
    score.levelTotal = 0
    score.levelCoins = 0
    score.lastRound  = nil
end

-- Wipe everything back to zero for a new game.
function score.reset()
    score.level      = 1
    score.round      = 0
    score.levelTotal = 0
    score.levelCoins = 0
    score.total      = 0
    score.history    = {}
    score.lastRound  = nil
end

return score
