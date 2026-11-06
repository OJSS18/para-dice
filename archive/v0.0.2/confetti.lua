-- confetti.lua
-- Falling confetti for the LEVEL CLEAR screen.
--
-- This is a tiny "particle system": a list of little pieces, each with its
-- own position, speed, spin and colour. Every frame, confetti.update(dt)
-- moves each piece a little. draw.lua then draws whatever is in the list.
-- Like the other logic files, nothing in here draws.

local confetti = {}

-- How many pieces are on screen at once.
local COUNT = 150

-- Colours to pick from: {red, green, blue}, each 0 to 1.
local COLORS = {
    {1.00, 0.30, 0.30},   -- red
    {1.00, 0.85, 0.10},   -- yellow
    {0.30, 0.80, 1.00},   -- blue
    {0.40, 1.00, 0.40},   -- green
    {1.00, 0.50, 1.00},   -- pink
    {1.00, 1.00, 1.00},   -- white
}

-- The list of pieces. Empty means "no confetti".
confetti.pieces = {}


-- A random decimal number between low and high.
-- (love.math.random() with no arguments gives a decimal from 0 to 1.)
local function randomBetween(low, high)
    return low + love.math.random() * (high - low)
end

-- Make one new confetti piece.
-- If 'anywhereAbove' is true it starts somewhere in a tall band above the
-- screen, so the first wave doesn't all arrive at the same moment.
-- Otherwise it starts just above the top edge.
local function newPiece(anywhereAbove)
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    local startY = -20
    if anywhereAbove then
        startY = -randomBetween(20, screenH)
    end

    local baseX = randomBetween(0, screenW)

    -- A table can hold lots of named values. This one describes one piece.
    return {
        baseX     = baseX,                     -- centre of its side-to-side sway
        x         = baseX,                     -- where it actually is right now
        y         = startY,
        fallSpeed = randomBetween(80, 200),    -- pixels per second downwards
        sway      = randomBetween(15, 50),     -- how far it drifts left/right
        swaySpeed = randomBetween(1, 3),       -- how fast it drifts
        swayTime  = randomBetween(0, 6.28),    -- start at a random point in the drift
        rotation  = randomBetween(0, 6.28),    -- angle in radians (6.28 = full turn)
        spin      = randomBetween(-6, 6),      -- radians per second
        width     = randomBetween(6, 10),
        height    = randomBetween(10, 16),
        -- COLORS[love.math.random(1, #COLORS)] picks a random colour.
        -- '#COLORS' means "how many items are in COLORS".
        color     = COLORS[love.math.random(1, #COLORS)],
    }
end

-- Start the confetti: fill the list with fresh pieces.
function confetti.start()
    confetti.pieces = {}
    for i = 1, COUNT do
        confetti.pieces[i] = newPiece(true)
    end
end

-- Stop the confetti: empty the list.
function confetti.stop()
    confetti.pieces = {}
end

-- Move every piece. Called every frame from love.update.
-- Multiplying by dt (seconds since last frame) keeps the speed the same
-- no matter how fast or slow the computer runs.
function confetti.update(dt)
    local screenH = love.graphics.getHeight()

    for i, p in ipairs(confetti.pieces) do
        p.y        = p.y + p.fallSpeed * dt
        p.swayTime = p.swayTime + p.swaySpeed * dt
        -- math.sin swings smoothly between -1 and 1, giving a gentle drift.
        p.x        = p.baseX + math.sin(p.swayTime) * p.sway
        p.rotation = p.rotation + p.spin * dt

        -- Fell off the bottom? Replace it with a new piece at the top,
        -- so the confetti keeps coming until confetti.stop() is called.
        if p.y > screenH + 20 then
            confetti.pieces[i] = newPiece(false)
        end
    end
end

return confetti
