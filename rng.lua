-- rng.lua
-- The GAME's random numbers: dice rolls, shop stock, Mystery Machine prizes.
--
-- They come from their own seeded generator, kept apart from the random
-- numbers the animations use (how the dice bounce, confetti...). So a run
-- is decided ONLY by its seed and what the player does - which is what
-- makes replay codes possible: same seed + same actions = the same game.

local rng = {}

local generator = love.math.newRandomGenerator(os.time())
rng.seed = 0

-- Start a fresh sequence of random numbers from 'seed' (a whole number).
function rng.setSeed(seed)
    rng.seed = seed
    generator = love.math.newRandomGenerator(seed)
end

-- A new random seed for a new run.
function rng.newSeed()
    return love.math.random(1, 2147483646)
end

-- Works like love.math.random: random() gives 0-1, random(n) gives 1..n,
-- random(a, b) gives a..b.
function rng.random(a, b)
    if a == nil then return generator:random() end
    if b == nil then return generator:random(a) end
    return generator:random(a, b)
end

return rng
