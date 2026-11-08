-- boosts.lua
-- POINT BOOSTS: lasting upgrades stuck onto individual POINTS tiles.
-- Luck items create them (see luck.lua). For example, Rabbit's Leg gives
-- every point you roll an extra x1.5 for the rest of the run, so after
-- rolling a 19, the 19 tile is worth 1.5 times as much from then on.
--
-- There are two kinds:
--   RUN boosts   - last for the whole game (multiplier and/or flat bonus)
--   LEVEL boosts - wiped at the start of every level (multiplier only)
--
-- score.lua reads these when working out points; the tiles on the table
-- show the boosted value. Pure LOGIC/data - nothing in here draws.

local boosts = {}

-- boosts.run[sum]   = { mult = 1.65, flat = 100 }
-- boosts.level[sum] = 1.75
boosts.run   = {}
boosts.level = {}


-- Give a point a run boost. Multipliers multiply together, flat bonuses add.
function boosts.addRun(sum, mult, flat)
    local b = boosts.run[sum]
    if b == nil then
        b = { mult = 1, flat = 0 }
        boosts.run[sum] = b
    end
    b.mult = b.mult * (mult or 1)
    b.flat = b.flat + (flat or 0)
end

-- Give a point a boost for this level only.
function boosts.addLevel(sum, mult)
    boosts.level[sum] = (boosts.level[sum] or 1) * mult
end

-- Total multiplier on a point from all its boosts (1 if none).
function boosts.multiplierFor(sum)
    local mult = boosts.level[sum] or 1
    if boosts.run[sum] then
        mult = mult * boosts.run[sum].mult
    end
    return mult
end

-- Flat bonus points added to a point (0 if none).
function boosts.flatFor(sum)
    if boosts.run[sum] then
        return boosts.run[sum].flat
    end
    return 0
end

-- Is this point boosted at all?
function boosts.isBoosted(sum)
    return boosts.multiplierFor(sum) ~= 1 or boosts.flatFor(sum) ~= 0
end

-- Start of a level: level boosts come off.
function boosts.clearLevel()
    boosts.level = {}
end

-- New game: everything comes off.
function boosts.reset()
    boosts.run = {}
    boosts.level = {}
end

return boosts
