-- dicetypes.lua
-- Every KIND of die in the game, and how likely each face is to come up.
--
-- Each type has a colour id that matches the image files in assets/dice:
--   id "purple"  ->  assets/dice/die_purple_1.png ... die_purple_6.png
-- When a purple die lands on 4, the game shows die_purple_4.png.
--
-- WEIGHTS: each type has 6 numbers, one per face, that say how likely
-- that face is. Only their sizes COMPARED TO EACH OTHER matter:
--   White {10,10,10,10,10,10}  all equal = a normal, fair die (1 in 6 each).
--   Red   {10,10,15,15,20,30}  lands on 6 three times as often as on 1.
-- The coloured dice add up to 100, so you can read them as percentages.
-- Bigger weight = more likely. Change these to rebalance the dice.
--
-- This file is pure LOGIC/data. It never draws (draw.lua loads the images).

local dicetypes = {}

-- The types, keyed by id. dicetypes.TYPES.red gives the red die's info.
dicetypes.TYPES = {
    white = {
        id      = "white",
        name    = "Dice of White",
        about   = "A normal, fair die.",
        weights = { 10, 10, 10, 10, 10, 10 },
        price   = 0,      -- the starter die; never sold in the shop
    },
    red = {
        id      = "red",
        name    = "Dice of Red",
        about   = "Leans toward high numbers.",
        weights = { 10, 10, 15, 15, 20, 30 },
        price   = 40,
    },
    blue = {
        id      = "blue",
        name    = "Dice of Blue",
        about   = "Leans toward low numbers.",
        weights = { 30, 20, 15, 15, 10, 10 },
        price   = 40,
    },
    green = {
        id      = "green",
        name    = "Dice of Green",
        about   = "Hugs the middle. Safe sums.",
        weights = { 5, 20, 25, 25, 20, 5 },
        price   = 30,
    },
    purple = {
        id      = "purple",
        name    = "Dice of Purple",
        about   = "Loves the extremes: 1s and 6s.",
        weights = { 30, 10, 10, 10, 10, 30 },
        price   = 55,
    },
    amber = {
        id      = "amber",
        name    = "Dice of Amber",
        about   = "Lands on 1 almost half the time.",
        weights = { 45, 11, 11, 11, 11, 11 },
        price   = 50,
    },
}

-- The same ids as a LIST, in a fixed order. Tables keyed by name (like
-- TYPES above) don't keep any order, so whenever we need "every type,
-- one after another" (loading images, picking random shop stock) we use this.
dicetypes.ORDER = { "white", "red", "blue", "green", "purple", "amber" }

-- The starter die every slot begins with.
dicetypes.STARTER = "white"


-- Look up a type by its id. Returns the table, e.g. dicetypes.get("red").name
function dicetypes.get(id)
    return dicetypes.TYPES[id]
end

-- Every type the shop is allowed to sell (everything except the starter).
function dicetypes.shopTypes()
    local list = {}
    for _, id in ipairs(dicetypes.ORDER) do
        if id ~= dicetypes.STARTER then
            table.insert(list, id)
        end
    end
    return list
end

-- What percent chance does face 'face' have with these weights?
-- (weight / total of all weights * 100, rounded to a whole number)
function dicetypes.percent(weights, face)
    local total = 0
    for f = 1, 6 do
        total = total + weights[f]
    end
    return math.floor(weights[face] / total * 100 + 0.5)
end

-- Pick a face (1-6) at random, using weights.
--
-- HOW WEIGHTED RANDOM WORKS: imagine the weights laid end to end on a
-- ruler. With {10,10,15,15,20,30} face 1 covers 0-10, face 2 covers 10-20,
-- face 3 covers 20-35 ... face 6 covers 70-100. Pick a random spot on the
-- ruler and see whose stretch it lands in. Bigger weight = bigger stretch
-- = more likely to be hit.
function dicetypes.pickFace(weights)
    local total = 0
    for f = 1, 6 do
        total = total + weights[f]
    end

    -- A random spot along the ruler, from 0 up to total.
    local spot = love.math.random() * total

    -- Walk along the ruler until we pass that spot.
    local runningTotal = 0
    for f = 1, 6 do
        runningTotal = runningTotal + weights[f]
        if spot < runningTotal then
            return f
        end
    end
    return 6   -- safety net for rounding; normally never reached
end

return dicetypes
