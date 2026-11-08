-- scoreboard.lua
-- DRAWS the scoring areas printed on the felt, styled like a craps table:
--
--   POINTS - like the "place bet" numbers: two rows of boxes, 5 to 17 on
--            top and 18 to 30 underneath, each with a big number and a
--            thin strip below it saying what it pays ("500 PTS").
--   COINS  - like the proposition bets (the horn / C&E area): a panel with
--            a red "MONEY MAKERS" title and a cell for each hand, showing
--            little example dice, the hand's name and what it pays.
--
-- EVERY box is outlined with Vegas light bulbs. Neighbouring boxes share
-- the row of bulbs between them. Because the camera is tilted (see
-- layout.lua) you can see the bulbs stand up off the felt.
--
-- Everything starts "unlit", like a sign with its lights off. When the
-- dice match a box, that box lights up, and so do the bulbs around it.
--
-- All numbers come from score.lua (POINT_VALUES and COIN_HANDS), so if you
-- change the scoring there, these change to match.
-- Positions come from layout.lua. Drawing only - nothing here changes data.

local config = require("config")
local layout = require("layout")
local fonts  = require("fonts")
local score  = require("score")
local dice    = require("dice")
local markers = require("markers")
local ui      = require("ui")

local scoreboard = {}

-- Colours. {red, green, blue, see-through-ness}
local LINE        = { 1, 1, 1, 0.55 }            -- the white printed lines
local NUMBER_OFF  = { 0.36, 0.34, 0.16 }         -- yellow paint with the light off
local NUMBER_ON   = { 1.00, 0.88, 0.20 }         -- lit yellow
local WHITE_OFF   = { 1, 1, 1, 0.70 }            -- small white text, still readable
local WHITE_ON    = { 1, 1, 1, 1 }
local RED_TITLE   = { 0.85, 0.13, 0.12 }
local GLOW        = { 1.00, 0.85, 0.35 }

-- Example dice drawn in each Money Maker cell, like the dice pictures on a
-- craps table's hardway bets.
local EXAMPLE_DICE = {
    fiveKind      = { 6, 6, 6, 6, 6 },
    largeStraight = { 1, 2, 3, 4, 5 },
    smallStraight = { 1, 2, 3, 4 },
    fullHouse     = { 3, 3, 3, 5, 5 },
    fourKind      = { 4, 4, 4, 4 },
    threeKind     = { 2, 2, 2 },
}

-- Where the pips go on a mini die, as fractions of its size.
local PIPS = {
    [1] = { {0.5, 0.5} },
    [2] = { {0.25, 0.25}, {0.75, 0.75} },
    [3] = { {0.25, 0.25}, {0.5, 0.5}, {0.75, 0.75} },
    [4] = { {0.25, 0.25}, {0.75, 0.25}, {0.25, 0.75}, {0.75, 0.75} },
    [5] = { {0.25, 0.25}, {0.75, 0.25}, {0.5, 0.5}, {0.25, 0.75}, {0.75, 0.75} },
    [6] = { {0.25, 0.25}, {0.75, 0.25}, {0.25, 0.5}, {0.75, 0.5}, {0.25, 0.75}, {0.75, 0.75} },
}


---------------------------------------------------------------------------
-- PIECES
---------------------------------------------------------------------------

-- Print text centred in a box, shrinking it if it's too wide to fit.
local function printCentered(text, font, x, y, w)
    love.graphics.setFont(font)
    local textW = font:getWidth(text)
    local scale = math.min(1, (w - 8) / textW)
    love.graphics.print(text, x + (w - textW * scale) / 2, y, 0, scale, scale)
end

-- A soft glow behind a lit box.
local function drawGlow(r)
    love.graphics.setColor(GLOW[1], GLOW[2], GLOW[3], 0.16)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h)
    love.graphics.setLineWidth(2)
    for spread = 3, 1, -1 do
        love.graphics.setColor(GLOW[1], GLOW[2], GLOW[3], 0.12 * (4 - spread))
        love.graphics.rectangle("line", r.x - spread * 2, r.y - spread * 2, r.w + spread * 4, r.h + spread * 4)
    end
    love.graphics.setLineWidth(1)
end

-- One POINTS box: big number on top, thin "PTS" strip underneath.
-- 'boosted' = a luck item has upgraded this point; its value shows in gold.
local function drawPlaceBox(r, sum, points, lit, boosted)
    if lit then drawGlow(r) end

    -- White printed outline, and the line between the number and the strip.
    love.graphics.setLineWidth(2)
    love.graphics.setColor(lit and GLOW or LINE)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h)
    local stripY = r.y + config.PLACE_NUMBER_H
    love.graphics.line(r.x, stripY, r.x + r.w, stripY)
    love.graphics.setLineWidth(1)

    -- The big number.
    love.graphics.setColor(lit and NUMBER_ON or NUMBER_OFF)
    local numberY = r.y + (config.PLACE_NUMBER_H - fonts.number:getHeight()) / 2 + 2
    printCentered(tostring(sum), fonts.number, r.x, numberY, r.w)

    -- What it pays, small and white.
    if boosted then
        love.graphics.setColor(1, 0.78, 0.2)          -- gold: this point has been upgraded
    else
        love.graphics.setColor(lit and WHITE_ON or WHITE_OFF)
    end
    local textY = stripY + (config.PLACE_STRIP_H - fonts.tiny:getHeight()) / 2
    printCentered(points .. " PTS", fonts.tiny, r.x, textY, r.w)
end

-- A small red die with white pips (like the dice pictured on a craps table).
local function drawMiniDie(x, y, size, face, lit)
    if lit then
        love.graphics.setColor(0.88, 0.12, 0.12)
    else
        love.graphics.setColor(0.42, 0.08, 0.08)
    end
    love.graphics.rectangle("fill", x, y, size, size, 3, 3)

    love.graphics.setColor(1, 1, 1, lit and 1 or 0.6)
    local pipR = size * 0.09
    for _, p in ipairs(PIPS[face]) do
        love.graphics.circle("fill", x + p[1] * size, y + p[2] * size, pipR)
    end
end

-- One Money Maker cell: example dice, the hand's name, and what it pays.
local function drawPropCell(r, hand, coinsText, lit)
    if lit then drawGlow(r) end

    love.graphics.setLineWidth(2)
    love.graphics.setColor(lit and GLOW or LINE)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h)
    love.graphics.setLineWidth(1)

    -- The example dice, in a centred row.
    local example = EXAMPLE_DICE[hand.id]
    local size, gap = 20, 4
    local rowW = #example * size + (#example - 1) * gap
    local dx = r.x + (r.w - rowW) / 2
    for n, face in ipairs(example) do
        drawMiniDie(dx + (n - 1) * (size + gap), r.y + 10, size, face, lit)
    end

    -- Name and payout, small and white.
    love.graphics.setColor(lit and WHITE_ON or WHITE_OFF)
    printCentered(string.upper(hand.name), fonts.tiny, r.x, r.y + 38, r.w)
    love.graphics.setColor(lit and NUMBER_ON or WHITE_OFF)
    printCentered(coinsText, fonts.tiny, r.x, r.y + 55, r.w)
end


---------------------------------------------------------------------------
-- VEGAS BULBS
---------------------------------------------------------------------------

-- One light bulb standing on the felt at (x, y), seen from the tilted camera.
--   * The metal socket sits ON the felt, so it's a flattened circle
--     (an ellipse squashed by cos(tilt)).
--   * The glass bulb sticks UP, so it's drawn higher up the screen by
--     BULB_HEIGHT x sin(tilt). That's what lets you see its shape.
-- 'brightness' is 0 for off, up to 1 for fully on.
local function drawBulb(x, y, brightness)
    local t = layout.tiltRadians()
    local r = config.BULB_RADIUS
    local lift = config.BULB_HEIGHT * math.sin(t)
    local gx, gy = x, y - lift   -- where the glass is drawn

    -- Shadow on the felt, then the socket.
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.ellipse("fill", x + 1, y + 1, r + 1, (r + 1) * math.cos(t))
    love.graphics.setColor(0.55, 0.42, 0.18)
    love.graphics.ellipse("fill", x, y, r * 0.8, r * 0.8 * math.cos(t))
    -- The neck joining socket and glass.
    love.graphics.rectangle("fill", x - r * 0.45, gy, r * 0.9, lift)

    if brightness > 0 then
        -- Light spilling out around a lit bulb.
        love.graphics.setColor(1, 0.8, 0.4, 0.22 * brightness)
        love.graphics.circle("fill", gx, gy, r * 2.6)
        love.graphics.setColor(1, 0.85, 0.5, 0.35 * brightness)
        love.graphics.circle("fill", gx, gy, r * 1.6)
        -- The glass, glowing warm.
        love.graphics.setColor(1, 0.75 + 0.2 * brightness, 0.45 + 0.35 * brightness)
    else
        love.graphics.setColor(0.30, 0.30, 0.28)   -- dark glass: light off
    end
    love.graphics.circle("fill", gx, gy, r)

    -- A tiny shine on the glass.
    love.graphics.setColor(1, 1, 1, brightness > 0 and 0.9 or 0.35)
    love.graphics.circle("fill", gx - r * 0.35, gy - r * 0.35, r * 0.3)
end

-- BULB GRIDS
-- A "bulb grid" collects the bulbs around a group of boxes. Neighbouring
-- boxes share a side, so the same bulb would be added twice - once for
-- each box. To avoid drawing it twice we file every bulb under a "key"
-- made from its position (like "512,140"), and only keep one per key.
-- If EITHER box next to a bulb is lit, that bulb is lit.

local function newBulbGrid()
    return { byKey = {}, list = {}, frames = {} }
end

-- Add the bulbs around one box. 'lit' = is this box lit up?
local function addBoxBulbs(grid, box, lit)
    local frame = layout.bulbFrame(box)
    table.insert(grid.frames, frame)

    local chaseIndex = 0   -- counts bulbs around THIS box, for the chase effect
    local function side(x1, y1, x2, y2)
        local length = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
        local count = math.max(1, math.floor(length / config.BULB_SPACING + 0.5))
        -- Both ends included (n = 0 .. count), so two boxes sharing a side
        -- produce exactly the same bulb positions.
        for n = 0, count do
            local p = n / count
            local x, y = x1 + (x2 - x1) * p, y1 + (y2 - y1) * p
            local key = math.floor(x + 0.5) .. "," .. math.floor(y + 0.5)
            local bulb = grid.byKey[key]
            if bulb == nil then
                bulb = { x = x, y = y, lit = false, chase = 0 }
                grid.byKey[key] = bulb
                table.insert(grid.list, bulb)
            end
            if lit and not bulb.lit then
                bulb.lit = true
                bulb.chase = chaseIndex
            end
            chaseIndex = chaseIndex + 1
        end
    end
    -- Walk round the box: top, right, bottom, left.
    local r = frame
    side(r.x, r.y, r.x + r.w, r.y)
    side(r.x + r.w, r.y, r.x + r.w, r.y + r.h)
    side(r.x + r.w, r.y + r.h, r.x, r.y + r.h)
    side(r.x, r.y + r.h, r.x, r.y)
end

-- Draw a bulb grid: gold lines along the lanes, then every bulb.
-- Lit bulbs "chase": every third one is brighter, and which ones move
-- round the box over time - the classic Vegas marquee effect.
local function drawBulbGrid(grid)
    love.graphics.setColor(0.55, 0.40, 0.14, 0.85)
    love.graphics.setLineWidth(3)
    for _, f in ipairs(grid.frames) do
        love.graphics.rectangle("line", f.x, f.y, f.w, f.h)
    end
    love.graphics.setLineWidth(1)

    -- love.timer.getTime() is the seconds since the game started.
    -- Reading it is fine in drawing code; it doesn't change any game data.
    local step = math.floor(love.timer.getTime() * 8)
    for _, b in ipairs(grid.list) do
        local brightness = 0
        if b.lit then
            if (b.chase + step) % 3 == 0 then
                brightness = 1
            else
                brightness = 0.6
            end
        end
        drawBulb(b.x, b.y, brightness)
    end
end


---------------------------------------------------------------------------
-- THE MARKER CHIP
---------------------------------------------------------------------------

-- A white casino chip lying on the felt, centred on (cx, cy).
-- Like the bulbs, it's drawn for the tilted camera:
--   * flat circles become ellipses, squashed by cos(tilt)
--   * the chip has thickness, so its top face is raised up the screen by
--     thickness x sin(tilt), and we see a band of its edge underneath.
local function drawChip(cx, cy, radius)
    local t = layout.tiltRadians()
    local squash = math.cos(t)
    local lift = 7 * math.sin(t)      -- the chip is 7 pixels thick
    local top = cy - lift             -- centre of the top face

    -- Shadow on the felt
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.ellipse("fill", cx + 2, cy + 3, radius + 2, (radius + 2) * squash)

    -- The edge (the bottom of the chip), then a band joining it to the top
    love.graphics.setColor(0.70, 0.70, 0.74)
    love.graphics.ellipse("fill", cx, cy, radius, radius * squash)
    love.graphics.rectangle("fill", cx - radius, top, radius * 2, lift)

    -- The white top face
    love.graphics.setColor(0.97, 0.97, 0.99)
    love.graphics.ellipse("fill", cx, top, radius, radius * squash)

    -- Blue "edge spots" round the rim, like a real casino chip
    love.graphics.setColor(0.15, 0.32, 0.85)
    for n = 0, 5 do
        local a = n * math.pi / 3              -- 6 spots, 60 degrees apart
        local sx = cx + math.cos(a) * radius * 0.80
        local sy = top + math.sin(a) * radius * 0.80 * squash
        love.graphics.ellipse("fill", sx, sy, radius * 0.17, radius * 0.17 * squash)
    end

    -- Inner ring and the "x1.5" printed in the middle (squashed to lie flat)
    love.graphics.setColor(0.55, 0.58, 0.68)
    love.graphics.setLineWidth(1)
    love.graphics.ellipse("line", cx, top, radius * 0.6, radius * 0.6 * squash)
    local label = "x" .. markers.MULTIPLIER
    love.graphics.setFont(fonts.tiny)
    love.graphics.setColor(0.10, 0.18, 0.55)
    local w, h = fonts.tiny:getWidth(label), fonts.tiny:getHeight()
    local s = math.min(1, radius * 1.1 / w)
    love.graphics.print(label, cx - w * s / 2, top - h * s * squash / 2, 0, s, s * squash)
end

-- Where the chip sits on a tile: tucked into the top-right corner, so the
-- big number stays readable.
local function chipSpot(r)
    return r.x + r.w - 10, r.y + 12
end

-- A soft white highlight on the tile under the mouse (while placing).
local function drawHover(r)
    love.graphics.setColor(1, 1, 1, 0.16)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", r.x - 2, r.y - 2, r.w + 4, r.h + 4)
    love.graphics.setLineWidth(1)
end


---------------------------------------------------------------------------
-- THE SCORING AREAS (draw.lua calls this right after drawing the table)
---------------------------------------------------------------------------

-- 'lightsOn' is false while dice are still tumbling, so nothing lights up
-- until every die has landed.
-- 'placing' is true while the player is choosing where the marker goes:
-- the tile under the mouse gets highlighted.
function scoreboard.draw(lightsOn, placing)
    local mx, my = love.mouse.getPosition()
    local chips = {}     -- where to draw marker chips: a list of {x, y}, one per marked tile

    -- POINTS: 26 boxes, 5 to 30 in order, each with bulbs all round it.
    local pointBulbs = newBulbGrid()
    for k, box in ipairs(score.sumBoxes()) do
        local lit = lightsOn and dice.total == box.sum
        local r = layout.placeBox(k)
        drawPlaceBox(r, box.sum, box.points, lit, box.boosted)
        if placing and layout.isInside(mx, my, r) then
            drawHover(r)
        end
        if markers.isOnSum(box.sum) then
            table.insert(chips, { chipSpot(r) })
        end
        addBoxBulbs(pointBulbs, r, lit)
    end
    drawBulbGrid(pointBulbs)

    -- COINS: the Money Makers panel. Only the best hand lights up - it's the one that pays.
    local bestHand, bestCoins = nil, 0
    if lightsOn then
        bestHand, bestCoins = score.bestHand(dice.values)
    end

    -- Red title above the cells, like "SEVEN" on a real table.
    local panel = layout.propPanel()
    love.graphics.setColor(RED_TITLE)
    local titleY = panel.y + (config.PROP_HEADER_H - fonts.propTitle:getHeight()) / 2
    printCentered("MONEY MAKERS", fonts.propTitle, panel.x, titleY, panel.w)

    local coinBulbs = newBulbGrid()
    for k, hand in ipairs(score.COIN_HANDS) do
        local lit = (bestHand == hand)
        local coinsText
        if lit then
            coinsText = bestCoins .. " COINS"       -- the real amount (marker included)
        elseif hand.coins == "sum" then
            coinsText = "DICE SUM IN COINS"
        else
            coinsText = hand.coins .. " COINS"
        end
        local r = layout.propCell(k)
        drawPropCell(r, hand, coinsText, lit)
        if placing and layout.isInside(mx, my, r) then
            drawHover(r)
        end
        if markers.isOnHand(hand.id) then
            table.insert(chips, { chipSpot(r) })
        end
        addBoxBulbs(coinBulbs, r, lit)
    end
    drawBulbGrid(coinBulbs)

    -- The marker chips go on last, so they sit on top of everything.
    -- ({ chipSpot(r) } packs chipSpot's two answers, x and y, into a table.)
    for _, c in ipairs(chips) do
        drawChip(c[1], c[2], 15)
    end
end


-- The line under the POINTS block that spells out this roll's score:
--   SCORING  60  x 1.88  (marker x1.5, keep x1.25)  =  113 PTS
-- 'r' is from score.calculate() or a saved round; 'noReroll' = KEEP bonus counts.
function scoreboard.drawScoreLine(r, noReroll)
    local line = layout.scoreLine()
    local baseText, mult, sources = score.breakdown(r, noReroll)
    local text = "SCORING  " .. baseText .. "  x " .. score.formatMult(mult)
    if #sources > 0 then
        text = text .. "  (" .. table.concat(sources, ", ") .. ")"
    else
        text = text .. "  (no bonuses)"
    end
    text = text .. "  =  " .. r.points .. " PTS"

    -- A dark strip behind it so it reads on the felt.
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", line.x, line.y, line.w, line.h, 8, 8)
    ui.text(text, fonts.heading, line.x + 10, line.y + (line.h - fonts.heading:getHeight()) / 2,
        line.w - 20, "center", NUMBER_ON)
end

return scoreboard
