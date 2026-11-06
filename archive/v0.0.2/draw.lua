-- draw.lua
-- Puts the PLAY SCREENS together, layer by layer:
--   1. the craps table (crapstable.lua)   - rails, felt, logo, dice tray
--   2. the betting boxes (scoreboard.lua) - POINTS / COINS, lit or unlit
--   3. the dice                           - in the tray, or flying/resting on the felt
--   4. the info banner (banner.lua)       - left side: score, coins, buttons
-- Things drawn later appear ON TOP of things drawn earlier.
--
-- It also loads the dice pictures. Drawing only - it never changes game data.
-- (The shop is drawn by shopdraw.lua.)

local config     = require("config")
local layout     = require("layout")
local fonts      = require("fonts")
local dice       = require("dice")
local score      = require("score")
local confetti   = require("confetti")
local animation  = require("animation")
local dicetypes  = require("dicetypes")
local player     = require("player")
local luckart    = require("luckart")
local luckrack   = require("luckrack")
local crapstable = require("crapstable")
local scoreboard = require("scoreboard")
local banner     = require("banner")
local ui         = require("ui")

local draw = {}

-- Flat die pictures, loaded once. Looked up as images[typeId][face]:
--   images.purple[4]  is  assets/dice/die_purple_4.png
-- These are only used in the SHOP. The play screen uses 'frames'.
local images = {}

-- Rolling/landed die pictures, loaded once. Looked up as frames[color][frameId]:
--   frames.red[5]   is  assets/dice/tumble/tumble_red_05.png
--   frames.red[21]  is  assets/dice/tumble/land_red_5.png  (landed on 5)
-- (See animation.lua for what each frame ID means.)
-- Every picture is loaded in draw.load(), so nothing is ever loaded mid-roll.
local frames = {}


---------------------------------------------------------------------------
-- SETUP
---------------------------------------------------------------------------

-- Call once from love.load. Fonts and images can only be made after
-- LÖVE has started.
function draw.load()
    fonts.load()

    -- All 6 flat faces of every die type (for the shop).
    for _, id in ipairs(dicetypes.ORDER) do
        images[id] = {}
        for face = 1, 6 do
            images[id][face] = love.graphics.newImage("assets/dice/die_" .. id .. "_" .. face .. ".png")
        end
    end

    -- Luck item pictures (swap the PNGs in assets/luck for new art any
    -- time; keep the same file names).
    luckart.load()

    -- Every tumble/settle/landed frame that any roll pattern uses,
    -- for every colour. (About 70 pictures per colour.)
    local frameIds = animation.allFrameIds()
    for _, color in ipairs(dicetypes.ORDER) do
        frames[color] = {}
        for _, frameId in ipairs(frameIds) do
            local path = "assets/dice/tumble/" .. animation.frameFile(color, frameId)
            frames[color][frameId] = love.graphics.newImage(path)
        end
    end
end


---------------------------------------------------------------------------
-- DICE
---------------------------------------------------------------------------

-- Draw a flat die picture (the shop uses this): type 'typeId' showing
-- 'face', top-left at (x, y), 'size' pixels wide and tall.
function draw.dieImage(typeId, face, x, y, size)
    local image = images[typeId][face]
    local scale = size / image:getWidth()
    love.graphics.setColor(1, 1, 1)   -- white = draw the image's own colours
    love.graphics.draw(image, x, y, 0, scale, scale)
end

-- Draw one tumble/landed frame CENTRED on (cx, cy), with the die's body
-- 'size' pixels across, turned by 'angle' (radians).
local function drawFrame(color, frameId, cx, cy, size, angle)
    -- A die at REST (frames 17-22) is drawn with the flat picture of its
    -- face, seen straight from above: just the one face, no sides showing.
    if frameId >= 17 and frameId <= 22 then
        local flat = images[color][frameId - 16]
        local s = size / flat:getWidth()
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(flat, cx, cy, angle, s, s, flat:getWidth() / 2, flat:getHeight() / 2)
        return
    end

    local image = frames[color][frameId]
    -- Scale so the die BODY (not the whole see-through picture) is 'size' wide.
    local scale = size / config.TUMBLE_BODY_SIZE
    -- The last two numbers (half, half) are the "origin": the point in the
    -- picture placed at (cx, cy): the middle of the 216x216 picture.
    local half = config.TUMBLE_FRAME_SIZE / 2
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(image, cx, cy, angle, scale, scale, half, half)
end

-- The dice sitting in the tray (the ones that aren't out on the felt or
-- in your hand). Dice picked to throw glow gold; dice not thrown yet this
-- round are shown dimmed (they still show last round's face). HELD dice
-- glow gold and say HELD.
local function drawTrayDice(state)
    for i = 1, config.NUM_DICE do
        local slot = layout.traySlot(i)

        if animation.getDraw(i) == nil then
            local picked = dice.held[i]

            -- Held dice: a soft gold glow behind the die...
            if picked then
                love.graphics.setColor(1, 0.8, 0.2, 0.25)
                love.graphics.rectangle("fill", slot.x - 8, slot.y - 8, slot.w + 16, slot.h + 16, 14, 14)
            end

            local cx, cy = slot.x + slot.w / 2, slot.y + slot.h / 2
            drawFrame(player.loadout[i], animation.landedFrameId(dice.values[i]),
                cx, cy, config.TRAY_DIE_SIZE, 0)

            -- Not thrown yet: darken it, so the old face doesn't look like a result.
            if not dice.thrown[i] then
                love.graphics.setColor(0.05, 0.12, 0.07, 0.6)
                love.graphics.rectangle("fill", slot.x + 4, slot.y + 4, slot.w - 8, slot.h - 8, 10, 10)
            end

            -- ...then a gold outline.
            if picked then
                love.graphics.setColor(1, 0.85, 0.1)
                love.graphics.setLineWidth(4)
                love.graphics.rectangle("line", slot.x - 4, slot.y - 4, slot.w + 8, slot.h + 8, 10, 10)
                love.graphics.setLineWidth(1)
                ui.text("HELD", fonts.hint, slot.x, slot.y + slot.h + 4, slot.w, "center", { 1, 0.85, 0.1 })
            end
        end
    end

    -- A "REROLL 3" tag above the tray, saying how many dice the reroll sends.
    -- Only for REROLLS while playing: the first throw always sends all 5,
    -- so it needs no tag.
    local rerolling = state == "play" and dice.allThrown() and dice.canReroll()
    if rerolling and dice.countToThrow() > 0 and not animation.isRolling() and not animation.isHolding() then
        local t = layout.tray()
        ui.text("REROLL " .. dice.countToThrow(), fonts.heading, t.x, t.y - 32, t.w, "center",
            { 1, 0.85, 0.1 }, true)
    end
end

-- The dice that are in your hand, out on the felt, or flying back to the
-- tray. Drawn after the tray so they pass OVER it.
local function drawMovingDice()
    for i = 1, config.NUM_DICE do
        local a = animation.getDraw(i)
        if a then
            -- A soft shadow on the felt under the die. The higher the die
            -- is, the smaller and fainter its shadow.
            local high = math.min(1, a.z / 250)
            love.graphics.setColor(0, 0, 0, 0.3 - 0.18 * high)
            love.graphics.ellipse("fill", a.x + 3, a.y + a.size * 0.3,
                a.size * (0.5 - 0.15 * high), a.size * (0.22 - 0.07 * high))
            -- The die itself: lifted up the screen by its height (we look at
            -- the table from a tilt), and a bit bigger when it's nearer to us.
            local lift = a.z * math.cos(layout.tiltRadians())
            drawFrame(a.color, a.frameId, a.x, a.y - lift, a.size * (1 + a.z / 600), a.angle)
        end
    end
end


---------------------------------------------------------------------------
-- SCREENS (main.lua calls these)
---------------------------------------------------------------------------

-- The start screen: the empty table, with the title on the felt.
function draw.startScreen()
    crapstable.draw()
    scoreboard.draw(false)   -- all the betting boxes, lights off
    banner.drawFrameOnly()

    local _, cy = layout.logoCenter()
    local f = layout.felt()
    ui.text(ui.controlsHint(), fonts.heading, f.x, cy + 90, f.w, "center",
        { 1, 0.9, 0.2 }, true)
    if not ui.touchMode then
        ui.text("ENTER = START      T = START WITH TUTORIAL", fonts.heading, f.x, cy + 122, f.w, "center",
            { 1, 0.95, 0.85 }, true)
    end
end

-- The play screen. main.lua passes in 'state' ("play", "roundOver", ...).
-- Reading state is fine here - we just never CHANGE it in draw.lua.
function draw.playScreen(state)
    crapstable.draw()
    -- The boxes stay dark until all 5 dice have been thrown and landed (and
    -- before the first roll, while the marker is being placed).
    local placing = (state == "placeMarker")
    local lightsOn = not placing and dice.allThrown() and not animation.isTumbling()
    scoreboard.draw(lightsOn, placing)

    -- This roll's score, spelled out under the POINTS block.
    if state == "play" and lightsOn then
        -- What KEEP would score right now (the keep bonus only if nothing's been rerolled).
        local keepNow = not dice.hasRerolled()
        scoreboard.drawScoreLine(score.calculate(dice.values, keepNow, dice.hasRerolled(), dice.firstSum), keepNow)
    elseif state ~= "play" and not placing and score.lastRound then
        scoreboard.drawScoreLine(score.lastRound, score.lastRound.noReroll)
    end
    luckrack.draw()          -- your luck items, right of the tray
    drawTrayDice(state)
    drawMovingDice()
    banner.draw(state)
    luckrack.drawTooltip()   -- what the hovered luck item does, on top
end

-- Darken everything already drawn, so a big message on top stands out.
local function drawDimOverlay()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
end

-- Draw every confetti piece from confetti.lua.
local function drawConfetti()
    for _, p in ipairs(confetti.pieces) do
        -- To draw a ROTATED rectangle we move and turn the whole
        -- "drawing paper", draw the rectangle, then put the paper back:
        --   push      = remember how the paper is now
        --   translate = move the paper so (0, 0) is at the piece
        --   rotate    = turn the paper by the piece's angle
        --   pop       = put the paper back the way push remembered it
        love.graphics.push()
        love.graphics.translate(p.x, p.y)
        love.graphics.rotate(p.rotation)
        love.graphics.setColor(p.color)
        love.graphics.rectangle("fill", -p.width / 2, -p.height / 2, p.width, p.height)
        love.graphics.pop()
    end
end

-- A big glowing title, a line under it, a glossy button to carry on
-- (so it can be tapped on a phone), and the controls hint below.
local function drawMessage(title, titleColor, line, buttonLabel)
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    ui.text(title, fonts.logo, 0, H / 2 - 150, W, "center", titleColor, true)
    ui.text(line, fonts.text, 0, H / 2 - 10, W, "center", { 1, 0.97, 0.9 })
    ui.glossyButton(layout.overlayButton(), buttonLabel, { 0.10, 0.65, 0.25 }, true)
    ui.text(ui.controlsHint(), fonts.heading, 0, H / 2 + 130, W, "center", { 1, 0.9, 0.2 })
end

-- LEVEL CLEAR: the finished level, dimmed, with confetti and a message.
function draw.levelClearScreen(state)
    draw.playScreen(state)
    drawDimOverlay()
    drawConfetti()
    drawMessage("LEVEL CLEAR!", { 1, 0.85, 0.1 },
        "Level " .. score.level .. ":  " .. score.levelTotal .. "/" .. score.getTarget()
            .. "     +" .. score.levelCoins .. " coins this level", "VISIT THE SHOP")
end

-- VICTORY: the last level is cleared - the whole game is won.
function draw.victoryScreen(state)
    draw.playScreen(state)
    drawDimOverlay()
    drawConfetti()
    drawMessage("YOU BEAT THE HOUSE!", { 1, 0.85, 0.1 },
        "All " .. score.MAX_LEVEL .. " levels cleared  -  final total: " .. score.total .. " points",
        "PLAY AGAIN")
end

-- GAME OVER: the finished level, dimmed, with a message.
function draw.gameOverScreen(state)
    draw.playScreen(state)
    drawDimOverlay()
    drawMessage("GAME OVER", { 1, 0.3, 0.3 },
        "You scored " .. score.levelTotal .. " - you needed " .. score.getTarget(), "PLAY AGAIN")
end

return draw
