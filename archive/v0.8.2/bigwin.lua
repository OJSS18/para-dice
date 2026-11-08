-- bigwin.lua
-- The BIG WIN / MEGA WIN celebration, like a slot machine jackpot.
--
-- After a round is scored, main.lua asks bigwin.check(points, target):
--   points >= 75% of the level goal  ->  MEGA WIN, +25 coins
--   points >= 40% of the level goal  ->  BIG WIN,  +10 coins
-- If it's a win, the jackpot sound plays and huge yellow block letters
-- sweep across the screen for a few seconds. It never blocks the game:
-- you can carry on clicking while it shows.

local bigwin = {}

bigwin.BIG_SHARE   = 0.40   -- share of the level goal for a BIG WIN
bigwin.MEGA_SHARE  = 0.75   -- ... and for a MEGA WIN
bigwin.BIG_COINS   = 10
bigwin.MEGA_COINS  = 25

local SOUND = "assets/sounds/jackpot.mp3"
local SHOW_TIME = 3.5       -- seconds the letters stay up (longer if the sound is)

local sound = nil           -- the jackpot sound, loaded once
local current = nil         -- { title, coins, mega, t, duration } while showing
local bigFont, coinFont = nil, nil


-- Call once from love.load.
function bigwin.load(displayFont)
    sound = love.audio.newSource(SOUND, "static")
    bigFont  = love.graphics.newFont(displayFont, 150)
    coinFont = love.graphics.newFont(displayFont, 54)
end

-- Was this round a BIG or MEGA win? If so, start the show and give back
-- how many bonus coins it pays (0 if it wasn't).
-- 'shares' (optional) = { big, mega } to use instead of the usual 40% / 75%
-- (the Jackpot Magnet luck item lowers them).
function bigwin.check(points, target, shares)
    if target <= 0 then return 0 end
    local share = points / target
    local bigShare  = shares and shares[1] or bigwin.BIG_SHARE
    local megaShare = shares and shares[2] or bigwin.MEGA_SHARE
    local title, coins
    if share >= megaShare then
        title, coins = "MEGA WIN!", bigwin.MEGA_COINS
    elseif share >= bigShare then
        title, coins = "BIG WIN!", bigwin.BIG_COINS
    else
        return 0
    end

    local duration = SHOW_TIME
    if sound then
        duration = math.min(6, math.max(SHOW_TIME, sound:getDuration()))
        sound:stop()     -- start again from the top if it was still playing
        sound:play()
    end
    current = { title = title, coins = coins, mega = (coins == bigwin.MEGA_COINS),
                t = 0, duration = duration }
    return coins
end

function bigwin.update(dt)
    if current then
        current.t = current.t + dt
        if current.t >= current.duration then
            current = nil
        end
    end
end

-- Stop it straight away (e.g. a new game starts).
function bigwin.stop()
    current = nil
    if sound then sound:stop() end
end


---------------------------------------------------------------------------
-- DRAWING
---------------------------------------------------------------------------

-- Chunky "block letter" text: many dark copies stacked down-right make it
-- look solid and 3D, then a black outline, then the bright face on top.
local function blockText(text, font, cx, cy, scale, face, side)
    love.graphics.setFont(font)
    local w, h = font:getWidth(text), font:getHeight()
    local ox, oy = w / 2, h / 2

    -- The solid side of the letters.
    for d = 12, 1, -1 do
        love.graphics.setColor(side[1], side[2], side[3], face[4] or 1)
        love.graphics.print(text, cx + d, cy + d, 0, scale, scale, ox, oy)
    end
    -- Black outline all round.
    love.graphics.setColor(0, 0, 0, face[4] or 1)
    for _, o in ipairs({ {-4, 0}, {4, 0}, {0, -4}, {0, 4}, {-3, -3}, {3, -3}, {-3, 3}, {3, 3} }) do
        love.graphics.print(text, cx + o[1], cy + o[2], 0, scale, scale, ox, oy)
    end
    -- The bright face.
    love.graphics.setColor(face)
    love.graphics.print(text, cx, cy, 0, scale, scale, ox, oy)
    -- A shine across the top half.
    love.graphics.setScissor(0, 0, love.graphics.getWidth(), math.floor(cy))
    love.graphics.setColor(1, 1, 1, 0.35 * (face[4] or 1))
    love.graphics.print(text, cx, cy, 0, scale, scale, ox, oy)
    love.graphics.setScissor()
end

function bigwin.draw()
    if not current then return end
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local t = current.t

    -- Fade in fast, fade out over the last half second.
    local alpha = math.min(1, t / 0.15, (current.duration - t) / 0.5)

    -- Darken the table a little behind the letters.
    love.graphics.setColor(0, 0, 0, 0.45 * alpha)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Slam in: start huge and settle with a little bounce, then pulse.
    local pop
    if t < 0.35 then
        local p = t / 0.35
        pop = 2.2 - 1.3 * p + 0.15 * math.sin(p * math.pi)
    else
        pop = 1 + 0.04 * math.sin((t - 0.35) * 10)
    end

    -- Fit the word across the screen.
    local textW = bigFont:getWidth(current.title)
    local scale = pop * math.min(1.0, (W * 0.9) / textW)

    -- MEGA WIN shakes and flashes gold/white.
    local cx, cy = W / 2, H / 2 - 40
    local face = { 1, 0.86, 0.1, alpha }
    if current.mega then
        cx = cx + math.sin(t * 47) * 6
        cy = cy + math.cos(t * 39) * 5
        local flash = 0.5 + 0.5 * math.sin(t * 14)
        face = { 1, 0.80 + 0.2 * flash, 0.1 + 0.6 * flash, alpha }
    end

    -- Rays of light behind the letters.
    love.graphics.push()
    love.graphics.translate(W / 2, H / 2 - 40)
    love.graphics.rotate(t * 0.6)
    love.graphics.setColor(1, 0.85, 0.2, 0.12 * alpha)
    for i = 0, 11 do
        local a = i * math.pi / 6
        love.graphics.polygon("fill", 0, 0,
            math.cos(a - 0.12) * W, math.sin(a - 0.12) * W,
            math.cos(a + 0.12) * W, math.sin(a + 0.12) * W)
    end
    love.graphics.pop()

    blockText(current.title, bigFont, cx, cy, scale, face, { 0.65, 0.32, 0.02 })

    -- The coins it paid, underneath.
    if t > 0.25 then
        local s = 1 + 0.06 * math.sin(t * 8)
        blockText("+" .. current.coins .. " COINS", coinFont, W / 2, H / 2 + 110, s,
            { 1, 1, 1, alpha }, { 0.55, 0.42, 0.05 })
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return bigwin
