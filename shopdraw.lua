-- shopdraw.lua
-- DRAWS the shop screen: a casino-carpet background, a marquee sign,
-- Vegas-style windows for DICE / LUCK / UPGRADES / YOUR DICE, the
-- MYSTERY MACHINE slot machine wrapped in chasing bulbs, and what you're
-- holding. Reads shop.lua (stock and positions), player.lua, luck.lua and
-- upgrades.lua - but never changes any of them.

local config    = require("config")
local shop      = require("shop")
local player    = require("player")
local luck      = require("luck")
local upgrades  = require("upgrades")
local markers   = require("markers")
local dicetypes = require("dicetypes")
local score     = require("score")
local draw      = require("draw")    -- for draw.dieImage and draw.luckImage
local fonts     = require("fonts")
local ui        = require("ui")

local shopdraw = {}

-- Colours used more than once. {red, green, blue}
local GOLD   = { 1, 0.85, 0.2 }
local WHITE  = { 1, 1, 1 }
local DIM    = { 1, 1, 1, 0.6 }
local YELLOW = { 1, 0.9, 0.2 }


---------------------------------------------------------------------------
-- BACKGROUND AND SIGN
---------------------------------------------------------------------------

-- Deep red casino carpet: a dark gradient with a faint gold diamond pattern.
local function drawBackground()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    for i = 0, H, 4 do
        local t = i / H
        love.graphics.setColor(0.24 - 0.14 * t, 0.03, 0.06 - 0.02 * t)
        love.graphics.rectangle("fill", 0, i, W, 4)
    end
    -- Diamond lattice: two sets of diagonal lines.
    love.graphics.setColor(1, 0.8, 0.3, 0.05)
    love.graphics.setLineWidth(2)
    local step = 60
    for x = -H, W, step do
        love.graphics.line(x, 0, x + H, H)
        love.graphics.line(x + H, 0, x, H)
    end
    love.graphics.setLineWidth(1)
end

-- The SHOP marquee sign: a red board with chasing bulbs all round.
local function drawSign()
    local r = shop.signRect()
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", r.x + 4, r.y + 6, r.w, r.h, 16, 16)
    love.graphics.setColor(0.55, 0.05, 0.08)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 16, 16)
    love.graphics.setColor(1, 0.82, 0.3)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", r.x + 8, r.y + 8, r.w - 16, r.h - 16, 10, 10)
    love.graphics.setLineWidth(1)
    ui.bulbBorder(r, 26, 5, 6)
    ui.text("THE SHOP", fonts.title, r.x, r.y + 2, r.w, "center", GOLD, true)
end


---------------------------------------------------------------------------
-- CARDS
---------------------------------------------------------------------------

-- The background box every card sits on. Darker when sold.
local function drawCardBox(r, sold, borderColor)
    love.graphics.setColor(0.03, 0.02, 0.03, sold and 0.85 or 0.6)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 10, 10)
    if borderColor and not sold then
        love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], 0.9)
        love.graphics.setLineWidth(2)
    else
        love.graphics.setColor(1, 1, 1, 0.2)
    end
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 10, 10)
    love.graphics.setLineWidth(1)

    -- A soft highlight when the mouse is over an unsold card.
    if not sold and ui.isHovered(r) then
        love.graphics.setColor(1, 1, 1, 0.07)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 10, 10)
    end
end

-- The price strip along the bottom of a card: "BUY  40" or "SOLD".
-- Gold if they can afford it, dull if they can't.
local function drawPrice(r, price, sold)
    local strip = { x = r.x + 10, y = r.y + r.h - 38, w = r.w - 20, h = 28 }
    if sold then
        love.graphics.setColor(0.22, 0.22, 0.22)
    elseif player.coins >= price then
        love.graphics.setColor(0.92, 0.72, 0.12)
    else
        love.graphics.setColor(0.35, 0.3, 0.2)
    end
    love.graphics.rectangle("fill", strip.x, strip.y, strip.w, strip.h, 7, 7)
    local label = sold and "SOLD" or ("BUY  " .. price)
    love.graphics.setFont(fonts.hint)
    love.graphics.setColor(sold and DIM or { 0.15, 0.07, 0 })
    love.graphics.printf(label, strip.x, strip.y + 7, strip.w, "center")
end

-- A dice card: picture, name, description and the chance of each face.
local function drawDiceCard(r, typeId, sold)
    local dieType = dicetypes.get(typeId)
    drawCardBox(r, sold)

    local imageSize = 64
    draw.dieImage(typeId, 6, r.x + (r.w - imageSize) / 2, r.y + 10, imageSize)
    ui.text(dieType.name, fonts.small, r.x + 6, r.y + 82, r.w - 12, "center", WHITE)

    love.graphics.setFont(fonts.tiny)
    love.graphics.setColor(DIM)
    love.graphics.printf(dieType.about, r.x + 8, r.y + 108, r.w - 16, "center")

    -- Chance of each face, in two rows of three: "1: 10%  2: 10%  3: 15%"
    love.graphics.setColor(WHITE)
    for row = 0, 1 do
        local parts = {}
        for col = 1, 3 do
            local face = row * 3 + col
            table.insert(parts, face .. ": " .. dicetypes.percent(dieType.weights, face) .. "%")
        end
        love.graphics.printf(table.concat(parts, "  "), r.x, r.y + 160 + row * 18, r.w, "center")
    end

    drawPrice(r, dieType.price, sold)
end

-- A luck item's picture, or a plain coin with an L if it has none.
local function drawLuckPicture(itemId, x, y, size)
    if not draw.luckImage(itemId, x, y, size) then
        local color = luck.rarityColor(luck.get(itemId))
        love.graphics.setColor(color)
        love.graphics.circle("fill", x + size / 2, y + size / 2, size * 0.45)
        ui.text("L", fonts.text, x, y + size / 2 - 12, size, "center", { 0, 0, 0 })
    end
end

-- A luck card: picture, rarity, name, what it does and how long it lasts.
local function drawLuckCard(r, itemId, sold)
    local item = luck.get(itemId)
    local rarityColor = luck.rarityColor(item)
    drawCardBox(r, sold, rarityColor)

    drawLuckPicture(itemId, r.x + (r.w - 64) / 2, r.y + 8, 64)
    ui.text(luck.RARITIES[item.rarity].label, fonts.hint, r.x, r.y + 76, r.w, "center", rarityColor)
    ui.text(item.name, fonts.small, r.x + 6, r.y + 92, r.w - 12, "center", WHITE)

    love.graphics.setFont(fonts.tiny)
    love.graphics.setColor(DIM)
    love.graphics.printf(item.about, r.x + 8, r.y + 116, r.w - 16, "center")
    love.graphics.setColor(rarityColor)
    love.graphics.printf(luck.durationText(item), r.x, r.y + r.h - 58, r.w, "center")

    drawPrice(r, luck.price(item), sold)
end

-- An upgrade card: a big "x1.25" badge, its name and level, what it does.
local function drawUpgradeCard(r, offer, sold)
    local def = upgrades.DEFS[offer.id]
    local isKeep = (offer.id == "keep")
    -- KEEP BONUS is the always-there card, so it gets gold instead of blue.
    local accent = isKeep and { 1, 0.80, 0.25 } or { 0.35, 0.85, 1 }
    drawCardBox(r, sold, accent)

    -- Round badge showing what the multiplier becomes.
    local nextLevel = upgrades.level(offer.id) + (sold and 0 or 1)
    local nextMult = 1 + upgrades.STEP * nextLevel
    if isKeep then
        nextMult = score.NO_REROLL_MULTIPLIER + upgrades.KEEP_STEP * nextLevel
    end
    local cx, cy = r.x + r.w / 2, r.y + 46
    love.graphics.setColor(0.05, 0.25, 0.4)
    love.graphics.circle("fill", cx, cy, 36)
    love.graphics.setColor(accent)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", cx, cy, 36)
    love.graphics.setLineWidth(1)
    ui.text("x" .. string.format("%.2f", nextMult), fonts.heading, cx - 36, cy - 10, 72, "center", WHITE)

    ui.text(offer.label, fonts.heading, r.x + 6, r.y + 92, r.w - 12, "center", accent, true)

    love.graphics.setFont(fonts.tiny)
    love.graphics.setColor(DIM)
    love.graphics.printf(def.about .. " - for the rest of the run.", r.x + 10, r.y + 124, r.w - 20, "center")
    love.graphics.setColor(accent)
    love.graphics.printf("Owned: LVL" .. upgrades.level(offer.id), r.x, r.y + r.h - 58, r.w, "center")

    drawPrice(r, offer.price, sold)
end


---------------------------------------------------------------------------
-- THE MYSTERY MACHINE
---------------------------------------------------------------------------

local function drawMachine()
    local m = shop.machineRect()
    local machine = shop.machine

    -- Bulbs first, all round the cabinet - they chase faster while it spins.
    local speed = machine.spinning and 18 or 5
    ui.bulbBorder({ x = m.x - 10, y = m.y - 10, w = m.w + 20, h = m.h + 20 }, 24, 6, speed)

    -- The cabinet: shiny red, darker at the bottom, with a gold trim.
    for i = 0, m.h, 3 do
        local t = i / m.h
        love.graphics.setColor(0.78 - 0.35 * t, 0.08, 0.10)
        love.graphics.rectangle("fill", m.x, m.y + i, m.w, 3)
    end
    love.graphics.setColor(1, 0.82, 0.3)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", m.x, m.y, m.w, m.h, 8, 8)
    love.graphics.setLineWidth(1)

    -- Title plate
    love.graphics.setColor(0.08, 0.02, 0.04)
    love.graphics.rectangle("fill", m.x + 14, m.y + 12, m.w - 28, 42, 8, 8)
    ui.text("MYSTERY", fonts.heading, m.x, m.y + 14, m.w, "center", YELLOW, true)
    ui.text("MACHINE", fonts.hint, m.x, m.y + 36, m.w, "center", WHITE)

    -- The reel window. A STENCIL cuts out its shape so the item pictures
    -- scrolling past only show up inside the glass.
    local reel = shop.reelRect()
    love.graphics.setColor(0.95, 0.93, 0.88)
    love.graphics.rectangle("fill", reel.x, reel.y, reel.w, reel.h, 8, 8)

    love.graphics.stencil(function()
        love.graphics.rectangle("fill", reel.x, reel.y, reel.w, reel.h, 8, 8)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)

    -- The strip of items: item k sits (k - 1 - position) cells below the centre.
    local cell = 84
    local position = shop.reelPosition()
    local centreY = reel.y + reel.h / 2
    for k, id in ipairs(machine.strip) do
        local cy = centreY + (k - 1 - position) * cell
        if cy > reel.y - cell and cy < reel.y + reel.h + cell then
            drawLuckPicture(id, reel.x + (reel.w - 70) / 2, cy - 35, 70)
        end
    end
    -- Shading at the top and bottom of the glass, like a curved drum.
    for i = 0, 30 do
        local a = 0.55 * (1 - i / 30)
        love.graphics.setColor(0, 0, 0, a)
        love.graphics.rectangle("fill", reel.x, reel.y + i, reel.w, 1)
        love.graphics.rectangle("fill", reel.x, reel.y + reel.h - 1 - i, reel.w, 1)
    end
    love.graphics.setStencilTest()

    -- Payline arrows and the glass rim.
    love.graphics.setColor(1, 0.2, 0.2)
    love.graphics.polygon("fill", reel.x - 14, centreY - 9, reel.x - 2, centreY, reel.x - 14, centreY + 9)
    love.graphics.polygon("fill", reel.x + reel.w + 14, centreY - 9, reel.x + reel.w + 2, centreY,
        reel.x + reel.w + 14, centreY + 9)

    -- When it has stopped on a prize, the rim glows in the prize's rarity colour.
    local rimColor = { 1, 0.82, 0.3 }
    if not machine.spinning and machine.prize then
        rimColor = luck.rarityColor(luck.get(machine.prize))
        love.graphics.setColor(rimColor[1], rimColor[2], rimColor[3], 0.35)
        love.graphics.rectangle("fill", reel.x - 6, reel.y - 6, reel.w + 12, reel.h + 12, 12, 12)
    end
    love.graphics.setColor(rimColor)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", reel.x, reel.y, reel.w, reel.h, 8, 8)
    love.graphics.setLineWidth(1)

    -- Under the reel: what you won (or the odds before the first spin).
    local labelY = reel.y + reel.h + 8
    if not machine.spinning and machine.prize then
        local item = luck.get(machine.prize)
        ui.text(luck.RARITIES[item.rarity].label, fonts.hint, m.x, labelY, m.w, "center", rimColor, true)
        ui.text(item.name, fonts.tiny, m.x + 8, labelY + 17, m.w - 16, "center", WHITE)
    elseif not machine.spinning then
        ui.text("A RANDOM LUCK ITEM!", fonts.hint, m.x, labelY + 6, m.w, "center", WHITE)
    end

    -- The lever on the right side. It's pulled down while the reel spins.
    local lx = m.x + m.w + 2
    local pulled = machine.spinning and math.max(0, 1 - machine.time * 2) or 0
    local knobY = m.y + 90 + pulled * 90
    love.graphics.setColor(0.55, 0.55, 0.6)
    love.graphics.rectangle("fill", lx, m.y + 150, 10, 30, 3, 3)          -- the mount
    love.graphics.setLineWidth(6)
    love.graphics.line(lx + 10, m.y + 165, lx + 22, knobY)                 -- the arm
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.9, 0.1, 0.12)
    love.graphics.circle("fill", lx + 22, knobY, 11)                       -- the red ball
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.circle("fill", lx + 18, knobY - 4, 3.5)

    -- SPIN button
    local canSpin = not machine.spinning and player.coins >= shop.MYSTERY_PRICE
    ui.glossyButton(shop.spinButtonRect(), "SPIN  " .. shop.MYSTERY_PRICE, { 0.95, 0.70, 0.10 }, canSpin)
end


---------------------------------------------------------------------------
-- YOUR DICE, HOLDING, CONTINUE
---------------------------------------------------------------------------

-- Your 5 equipped dice and your inventory, in one window.
local function drawYourDice()
    local win = shop.diceWindowRect()
    ui.vegasWindow(win, "YOUR DICE")

    for i = 1, config.NUM_DICE do
        local s = shop.slotRect(i)
        draw.dieImage(player.loadout[i], i, s.x, s.y, s.w)
        -- When an inventory die is picked, outline the slots to show that
        -- clicking one will swap.
        if shop.selectedInv then
            love.graphics.setColor(1, 1, 1, 0.6)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", s.x - 4, s.y - 4, s.w + 8, s.h + 8, 10, 10)
            love.graphics.setLineWidth(1)
        end
    end

    local labelY = shop.slotRect(1).y + shop.SLOT_SIZE + 10
    ui.text("INVENTORY", fonts.hint, win.x, labelY, win.w, "center", DIM)
    if #player.inventory == 0 then
        ui.text("(dice you buy go here)", fonts.tiny, win.x, labelY + 36, win.w, "center", DIM)
    end
    for j, typeId in ipairs(player.inventory) do
        local s = shop.inventoryRect(j)
        draw.dieImage(typeId, 6, s.x, s.y, s.w)
        if shop.selectedInv == j then
            love.graphics.setColor(GOLD)
            love.graphics.setLineWidth(4)
            love.graphics.rectangle("line", s.x - 5, s.y - 5, s.w + 10, s.h + 10, 10, 10)
            love.graphics.setLineWidth(1)
        end
    end
end

-- The luck item you're holding right now.
local function drawHolding()
    local r = shop.holdingRect()
    ui.vegasWindow(r, "HOLDING")
    if luck.current == nil then
        ui.text("No luck item", fonts.small, r.x, r.y + 60, r.w, "center", DIM)
        return
    end
    local item = luck.get(luck.current)
    local color = luck.rarityColor(item)
    drawLuckPicture(item.id, r.x + 16, r.y + 34, 58)
    local tx, tw = r.x + 86, r.w - 100
    ui.text(luck.RARITIES[item.rarity].label, fonts.hint, tx, r.y + 26, tw, "left", color)
    ui.text(item.name, fonts.small, tx, r.y + 42, tw, "left", WHITE)
    ui.text(luck.timeLeftText(), fonts.tiny, tx, r.y + 64, tw, "left", color)
    love.graphics.setFont(fonts.tiny)
    love.graphics.setColor(DIM)
    love.graphics.printf(item.about, tx, r.y + 80, tw, "left")
end

-- A white casino chip seen face-on (for the MARKERS window).
local function drawChipIcon(cx, cy, r)
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.circle("fill", cx + 2, cy + 3, r)
    love.graphics.setColor(0.97, 0.97, 0.99)
    love.graphics.circle("fill", cx, cy, r)
    love.graphics.setColor(0.15, 0.32, 0.85)
    for n = 0, 5 do
        local a = n * math.pi / 3
        love.graphics.circle("fill", cx + math.cos(a) * r * 0.78, cy + math.sin(a) * r * 0.78, r * 0.16)
    end
    love.graphics.setColor(0.55, 0.58, 0.68)
    love.graphics.circle("line", cx, cy, r * 0.58)
    ui.text("x" .. markers.MULTIPLIER, fonts.tiny, cx - r, cy - 8, r * 2, "center", { 0.10, 0.18, 0.55 })
end

-- MARKERS: buy another white chip to place at the start of each level.
local function drawMarkers()
    local r = shop.markersRect()
    ui.vegasWindow(r, "MARKERS")
    drawChipIcon(r.x + 40, r.y + 58, 22)
    ui.text("OWNED", fonts.hint, r.x + 72, r.y + 34, r.w - 84, "left", DIM)
    ui.text(markers.owned .. " / " .. markers.MAX_OWNED, fonts.heading, r.x + 72, r.y + 50, r.w - 84, "left", WHITE, true)
    ui.text("+1 chip each level", fonts.tiny, r.x + 72, r.y + 74, r.w - 84, "left", DIM)

    local b = shop.markerButtonRect()
    if markers.owned >= markers.MAX_OWNED then
        ui.glossyButton(b, "MAX", { 0.5, 0.5, 0.55 }, false)
    else
        local price = markers.nextPrice()
        ui.glossyButton(b, "+1  BUY " .. price, { 0.12, 0.38, 0.95 }, player.coins >= price)
    end
end


---------------------------------------------------------------------------
-- THE SCREEN (main.lua calls this)
---------------------------------------------------------------------------

function shopdraw.screen()
    local W = love.graphics.getWidth()

    drawBackground()
    drawSign()

    -- Coins and next level, top-left; the controls hint, top-right.
    ui.text("COINS  " .. player.coins, fonts.heading, 20, 20, 400, "left", GOLD, true)
    ui.text("NEXT UP: LEVEL " .. shop.nextLevel, fonts.heading, 20, 48, 400, "left", WHITE)
    ui.text(ui.controlsHint(), fonts.heading, W - 600, 48, 580, "right", YELLOW)

    -- The three windows of cards
    ui.vegasWindow(shop.windowRect(1), "DICE")
    ui.vegasWindow(shop.windowRect(2), "LUCK")
    ui.vegasWindow(shop.windowRect(3), "UPGRADES")
    for n = 1, 2 do
        drawDiceCard(shop.cardRect("dice", n), shop.stock.dice[n], shop.sold.dice[n])
        drawLuckCard(shop.cardRect("luck", n), shop.stock.luck[n], shop.sold.luck[n])
    end
    for n = 1, 3 do
        drawUpgradeCard(shop.cardRect("upgrades", n), shop.stock.upgrades[n], shop.sold.upgrades[n])
    end

    drawYourDice()
    drawMachine()
    drawHolding()
    drawMarkers()

    -- A glossy green CONTINUE button, then the latest message under it.
    ui.glossyButton(shop.continueRect(), "CONTINUE", { 0.10, 0.65, 0.25 }, not shop.machine.spinning)
    local msg = shop.messageRect()
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.printf(shop.message, msg.x + 1, msg.y + 2, msg.w, "center")
    love.graphics.setColor(GOLD)
    love.graphics.printf(shop.message, msg.x, msg.y, msg.w, "center")
end

return shopdraw
