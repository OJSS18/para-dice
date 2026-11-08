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
-- PRICES come from the strategy simulator (tools/strategy-sim, PRICETEST):
-- about 80 coins for each extra level a die helps a player clear.
-- Amber is the strongest (low sums pay big); Green is cheap because
-- hugging the middle lands on the LOW-value tiles.
--
-- This file is pure LOGIC/data. It never draws (draw.lua loads the images).

local util = require("util")

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
        price   = 25,
    },
    green = {
        id      = "green",
        name    = "Dice of Green",
        about   = "Hugs the middle. Safe sums.",
        weights = { 5, 20, 25, 25, 20, 5 },
        price   = 10,
    },
    purple = {
        id      = "purple",
        name    = "Dice of Purple",
        about   = "Loves the extremes: 1s and 6s.",
        weights = { 30, 10, 10, 10, 10, 30 },
        price   = 30,
    },
    amber = {
        id      = "amber",
        name    = "Dice of Amber",
        about   = "Lands on 1 almost half the time.",
        weights = { 45, 11, 11, 11, 11, 11 },
        price   = 60,
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
    return util.round(weights[face] / util.sum(weights) * 100)
end

-- Pick a face (1-6) at random, using weights (see util.pickWeighted).
local FACES = { 1, 2, 3, 4, 5, 6 }
function dicetypes.pickFace(weights)
    return util.pickWeighted(FACES, function(face) return weights[face] end)
end

return dicetypes
