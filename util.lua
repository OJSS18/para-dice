-- util.lua
-- Small helpers that lots of files need. Pure maths - nothing here draws
-- or changes game data.

local rng = require("rng")

local util = {}

-- A rectangle as a table: { x = left, y = top, w = width, h = height }.
function util.rect(x, y, w, h)
    return { x = x, y = y, w = w, h = h }
end

-- Is the point (px, py) inside rectangle r?
function util.isInside(px, py, r)
    return px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

-- Keep v between lo and hi.
function util.clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

-- Blend from a to b. p = 0 gives a, p = 1 gives b, 0.5 is halfway.
function util.lerp(a, b, p)
    return a + (b - a) * p
end

-- Round to the nearest whole number. Lua has no built-in round(), so we
-- add 0.5 and chop off the decimals with math.floor: 60.5 -> 61, 55.0 -> 55.
function util.round(n)
    return math.floor(n + 0.5)
end

-- A random decimal number between lo and hi.
-- (love.math.random() with no arguments gives a decimal from 0 to 1.)
function util.randomBetween(lo, hi)
    return lo + (hi - lo) * love.math.random()
end

-- Add up a list of numbers.
function util.sum(list)
    local total = 0
    for _, v in ipairs(list) do
        total = total + v
    end
    return total
end

-- Count how many of each face there are in a list of dice values.
-- {6, 2, 6, 6, 2} -> counts[6] = 3, counts[2] = 2, everything else 0.
function util.countFaces(values)
    local counts = { 0, 0, 0, 0, 0, 0 }
    for _, v in ipairs(values) do
        counts[v] = counts[v] + 1
    end
    return counts
end

-- Pick one thing from 'list' at random, where weightOf(thing) says how
-- likely each one is. Bigger weight = more likely.
--
-- HOW WEIGHTED RANDOM WORKS: imagine the weights laid end to end on a
-- ruler. With weights {10, 10, 15, 15, 20, 30} the first covers 0-10, the
-- second 10-20, the third 20-35 ... the last 70-100. Pick a random spot on
-- the ruler and see whose stretch it lands in.
function util.pickWeighted(list, weightOf)
    local total = 0
    for _, x in ipairs(list) do total = total + weightOf(x) end
    local spot = rng.random() * total   -- the GAME's random numbers (see rng.lua)
    for _, x in ipairs(list) do
        spot = spot - weightOf(x)
        if spot < 0 then return x end
    end
    return list[#list]   -- safety net for rounding; normally never reached
end

return util
