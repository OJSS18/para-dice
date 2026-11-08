-- transition.lua
-- SLIDING between the table and the shop, with a soft SWOOSH.
--
-- How it works: every frame, the game screen is drawn into a "canvas" (an
-- invisible picture) instead of straight onto the window. When the screen
-- changes (table -> shop, or shop -> table), the canvas holding the last
-- frame of the OLD screen is kept, and for a moment both pictures are
-- drawn side by side, sliding across - the old one out, the new one in.
--
--   to the shop:   the table slides off to the LEFT, the shop comes in from the right
--   back to play:  the shop slides off to the RIGHT, the table comes back from the left
--
-- The swoosh sounds are MADE in code (no sound files): a burst of random
-- noise, filtered so it goes from a low "whoo" to a higher "sh" (or the
-- other way), fading in and out - like air rushing past.
-- Drawing and sound only - nothing in here changes game data.

local util = require("util")

local transition = {}

transition.TIME = 0.6   -- seconds a slide takes

local canvases = {}     -- two canvases; one holds this frame, the other the last
local current = 1       -- which one this frame is drawn into
local builtW, builtH = 0, 0

local active = nil      -- { t = seconds so far, dir = 1 (to shop) or -1 (back) }
local sounds = {}       -- sounds.toShop, sounds.toTable


---------------------------------------------------------------------------
-- THE SWOOSH SOUNDS
---------------------------------------------------------------------------

-- Make a swoosh: 'rising' = true sweeps from low to high, false the other way.
local function makeSwoosh(rising)
    local rate, length = 44100, 0.75
    local samples = math.floor(rate * length)
    local data = love.sound.newSoundData(samples, rate, 16, 1)
    local low, low2 = 0, 0          -- two simple filters, smoothing the noise
    local wave, peak = {}, 0
    for n = 0, samples - 1 do
        local p = n / samples       -- 0 -> 1 through the sound
        -- How "bright" it is right now: the filter opens up (or closes).
        local sweep = rising and p or (1 - p)
        local cutoff = 0.06 + 0.3 * sweep ^ 1.4     -- about 450 Hz up to 2800 Hz
        -- Random noise, smoothed twice: that turns harsh hiss into soft air.
        local noise = love.math.random() * 2 - 1
        low = low + cutoff * (noise - low)
        low2 = low2 + cutoff * (low - low2)
        -- Fade in quickly, swell, then fade out softly.
        local envelope = math.sin(math.pi * p ^ 0.7) ^ 2
        wave[n] = low2 * envelope
        peak = math.max(peak, math.abs(wave[n]))
    end
    -- Scale it so the loudest moment is a gentle 60% - soft, never harsh.
    for n = 0, samples - 1 do
        data:setSample(n, util.clamp(wave[n] / peak * 0.6, -1, 1))
    end
    return love.audio.newSource(data, "static")
end

-- Call once from love.load.
function transition.load()
    sounds.toShop = makeSwoosh(true)
    sounds.toTable = makeSwoosh(false)
end

-- The swooshes get louder or quieter with the music volume.
local volume = 0.5
function transition.setVolume(v)
    volume = v
end


---------------------------------------------------------------------------
-- RUNNING A SLIDE
---------------------------------------------------------------------------

-- Start sliding. 'toShop' = true going into the shop, false coming back.
function transition.start(toShop)
    active = { t = 0, dir = toShop and 1 or -1 }
    local s = toShop and sounds.toShop or sounds.toTable
    if s then
        s:stop()
        s:setVolume(0.55 * volume + 0.15 * (volume > 0 and 1 or 0))
        s:play()
    end
    -- The canvas with the last frame of the old screen is kept as it is;
    -- the new screen is drawn into the other one from now on.
    current = 3 - current
end

function transition.isActive()
    return active ~= nil
end

function transition.update(dt)
    if active then
        active.t = active.t + dt
        if active.t >= transition.TIME then active = nil end
    end
end

local function buildCanvases()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    if W == builtW and H == builtH and canvases[1] then return end
    builtW, builtH = W, H
    canvases[1] = love.graphics.newCanvas(W, H)
    canvases[2] = love.graphics.newCanvas(W, H)
end

-- Slow start, fast middle, gentle stop.
local function ease(p)
    if p < 0.5 then return 4 * p * p * p end
    return 1 - (-2 * p + 2) ^ 3 / 2
end

-- Draw the game screen: 'drawScene' draws this frame's screen as normal.
-- It goes into a canvas, then onto the window - sliding if a slide is on.
function transition.draw(drawScene)
    buildCanvases()
    local canvas = canvases[current]
    love.graphics.setCanvas({ canvas, stencil = true })
    love.graphics.clear(love.graphics.getBackgroundColor())
    drawScene()
    love.graphics.setCanvas()

    -- Canvases hold "premultiplied" colours, so they're drawn that way.
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("alpha", "premultiplied")
    if not active then
        love.graphics.draw(canvas, 0, 0)
    else
        local W, H = love.graphics.getWidth(), love.graphics.getHeight()
        local e = ease(math.min(1, active.t / transition.TIME))
        local old = canvases[3 - current]
        local shift = -active.dir * W * e            -- how far the old screen has moved
        love.graphics.draw(old, shift, 0)
        love.graphics.draw(canvas, shift + active.dir * W, 0)
        -- A soft shadow where the two screens meet, so it reads as one
        -- panel sliding over the other.
        love.graphics.setBlendMode("alpha")
        local edge = active.dir == 1 and (shift + W) or shift
        for i = 0, 23 do
            love.graphics.setColor(0, 0, 0, 0.30 * (1 - i / 24))
            local x = active.dir == 1 and (edge - 1 - i) or (edge + i)
            love.graphics.rectangle("fill", x, 0, 1, H)
        end
    end
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
end

return transition
