-- pipsview.lua
-- PIPS MODE: the LOOKS-ONLY moving parts - the electronic dice roll and
-- the slot machine's spinning reels. It never changes the run's data: the
-- dice values are already decided (in pipsgame.lua) before they "roll".
--
-- THE ELECTRONIC ROLL: instead of dice tumbling across the table, each
-- die that rolled flickers through random faces (like an electronic
-- dice game), and stops on its real value one after the other, left to
-- right. The flicker uses love.math.random (animations only), never the
-- game's rng, so it can't change what happens in the run.

local pipsgame = require("pipsgame")

local pipsview = {}

pipsview.ROLL_TIME   = 0.45   -- seconds the first die flickers...
pipsview.ROLL_STEP   = 0.07   -- ...and each next die stops this much later
pipsview.FLICK_TIME  = 0.05   -- a new random face this often
pipsview.SPIN_TIME   = 1.4    -- seconds the first reel spins...
pipsview.REEL_STEP   = 0.4    -- ...and each next reel stops this much later

local seenRoll = nil      -- the run's rollId we last saw
local rollClock = 99      -- seconds since the last roll started
local rolledDice = {}     -- which dice are flickering
local flickFaces = {}     -- the random face each flickering die shows now
local flickClock = 0
local seenSpins, seenRun = nil, nil
pipsview.spinClock = 99   -- seconds since the reels started spinning
pipsview.time = 0         -- seconds since the run started (for glows and pulses)

function pipsview.reset()
    seenRoll, seenSpins, seenRun = nil, nil, nil
    rollClock, pipsview.spinClock = 99, 99
end

-- When does die i stop flickering? (Counted only among dice that rolled.)
local function stopTime(i)
    local order = 0
    for k = 1, i do
        if rolledDice[k] then order = order + 1 end
    end
    return pipsview.ROLL_TIME + (order - 1) * pipsview.ROLL_STEP
end

function pipsview.update(dt)
    local run = pipsgame.run
    if not run then return end
    pipsview.time = pipsview.time + dt
    -- A new run: forget the old one's animations.
    if run ~= seenRun then
        seenRun = run
        seenRoll = nil
        seenSpins = nil
    end
    -- A new roll happened: start flickering the dice that rolled.
    if run.rollId ~= seenRoll then
        seenRoll = run.rollId
        rollClock = 0
        rolledDice = {}
        for i in pairs(run.rolled) do rolledDice[i] = true end
    end
    rollClock = rollClock + dt
    flickClock = flickClock + dt
    if flickClock >= pipsview.FLICK_TIME then
        flickClock = 0
        for i, die in ipairs(run.dice) do
            flickFaces[i] = die.faces[love.math.random(#die.faces)]
        end
    end
    -- A new spin: start the reels.
    local spins = run.shop and run.shop.spins or 0
    if run.state == "shop" and seenSpins ~= nil and spins > seenSpins then
        pipsview.spinClock = 0
    end
    seenSpins = spins
    pipsview.spinClock = pipsview.spinClock + dt
end

-- Is die i still flickering?
function pipsview.isFlickering(i)
    return rolledDice[i] == true and rollClock < stopTime(i)
end

-- The face die i shows right now (a random one while it flickers).
function pipsview.faceShown(i)
    local run = pipsgame.run
    if pipsview.isFlickering(i) then return flickFaces[i] or run.values[i] end
    return run.values[i]
end

-- How long ago die i stopped (for a little "pop" as it lands). nil if it didn't roll.
function pipsview.landedAgo(i)
    if not rolledDice[i] then return nil end
    return rollClock - stopTime(i)
end

-- Are any dice still flickering?
function pipsview.isRolling()
    local run = pipsgame.run
    if not run then return false end
    for i = 1, #run.dice do
        if pipsview.isFlickering(i) then return true end
    end
    return false
end

-- Has reel k stopped spinning?
function pipsview.reelStopped(k)
    return pipsview.spinClock >= pipsview.SPIN_TIME + (k - 1) * pipsview.REEL_STEP
end

function pipsview.isSpinning()
    return not pipsview.reelStopped(3)
end

-- Is anything moving that the player should wait for?
function pipsview.isBusy()
    return pipsview.isRolling() or pipsview.isSpinning()
end

return pipsview
