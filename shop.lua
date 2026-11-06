-- shop.lua
-- The SHOP between levels: what's for sale, buying, the Mystery Machine,
-- swapping dice into your 5 slots, and WHERE everything sits on screen.
--
-- What's on offer each visit (each in its own Vegas-style window):
--   * DICE     - 2 random coloured dice. Bought dice go to your inventory;
--                then you swap one into any of your 5 slots.
--   * LUCK     - 2 random luck items (you hold one at a time; buying
--                replaces it). Odds by rarity: 40/30/20/9/1 %.
--                No rare or epic items before level 4.
--   * UPGRADES - 2 random upgrades, e.g. "EVEN LVL1" (+0.25x on even sums).
--   * THE MYSTERY MACHINE - a one-reel slot machine: 30 coins a spin for a
--                random luck item. Odds 20/35/25/15/5 %, any rarity, any level.
--
-- This file is LOGIC + LAYOUT. The drawing lives in shopdraw.lua.

local config    = require("config")
local dicetypes = require("dicetypes")
local luck      = require("luck")
local player    = require("player")
local upgrades  = require("upgrades")
local markers   = require("markers")

local shop = {}


---------------------------------------------------------------------------
-- SIZES (tweak these to resize the shop)
---------------------------------------------------------------------------

shop.CARD_W      = 160   -- each item card
shop.CARD_H      = 270
shop.CARD_GAP    = 12    -- gap between the two cards in a window
shop.WINDOW_PAD  = 14    -- space between a window's frame and its cards
shop.WINDOW_HEAD = 34    -- room at the top of a window for its title plate
shop.WINDOW_GAP  = 18    -- gap between the three windows

shop.SLOT_SIZE   = 76    -- your 5 equipped dice
shop.SLOT_GAP    = 12
shop.INV_SIZE    = 58    -- dice in your inventory
shop.INV_GAP     = 10

shop.MACHINE_W   = 230   -- the Mystery Machine cabinet
shop.MACHINE_H   = 320
shop.MYSTERY_PRICE = 30
shop.SPIN_TIME   = 2.6   -- seconds the reel spins for

shop.CONTINUE_W  = 260
shop.CONTINUE_H  = 56

-- The whole shop is this tall; it's centred top-to-bottom on screen.
local SHOP_HEIGHT = 748


---------------------------------------------------------------------------
-- DATA (what's in the shop right now)
---------------------------------------------------------------------------

-- What's for sale:
--   dice     = { "red", "amber" }
--   luck     = { "addict", "rabbitsLeg" }
--   upgrades = { {id = "even", label = "EVEN LVL1", price = 25}, ... }
shop.stock = { dice = {}, luck = {}, upgrades = {} }

-- sold.dice[1] = true once the first dice card has been bought, etc.
shop.sold = { dice = {}, luck = {}, upgrades = {} }

-- Which inventory die is picked, waiting to be swapped into a slot (or nil).
shop.selectedInv = nil

-- A line of feedback ("Bought Dice of Red!", ...).
shop.message = ""

-- The level the player is about to play (decides whether rare/epic can show).
shop.nextLevel = 1

-- THE MYSTERY MACHINE
--   strip     - the list of item ids painted on the reel, top to bottom;
--               the LAST one is where it stops (the prize)
--   spinning  - true while the reel is turning
--   time      - seconds since this spin started
--   prize     - the item id it's going to land on (or landed on)
shop.machine = { strip = {}, spinning = false, time = 0, prize = nil }


---------------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------------

-- Pick 'count' DIFFERENT random items from 'list'.
-- We copy the list, then repeatedly pull a random item out of the copy,
-- so the same item can't be picked twice.
local function pickDifferent(list, count)
    local pool = {}
    for i, item in ipairs(list) do
        pool[i] = item
    end
    local picked = {}
    for _ = 1, math.min(count, #pool) do
        table.insert(picked, table.remove(pool, love.math.random(1, #pool)))
    end
    return picked
end

-- Fast at first, slowing to a stop - for the reel.
local function easeOut(p)
    return 1 - (1 - p) ^ 3
end

-- Some random items to paint on the reel (just for show).
local function randomStrip(count)
    local strip = {}
    for i = 1, count do
        strip[i] = luck.randomItem("mystery")
    end
    return strip
end


---------------------------------------------------------------------------
-- LOGIC
---------------------------------------------------------------------------

-- Fill the shop with fresh stock. 'nextLevel' is the level about to be played.
function shop.open(nextLevel)
    shop.nextLevel = nextLevel

    shop.stock.dice = pickDifferent(dicetypes.shopTypes(), 2)

    -- Two different luck items, picked by the shop's rarity odds. Passing
    -- the level keeps rare and epic out until level 4.
    local first = luck.randomItem("shop", {}, nextLevel)
    shop.stock.luck = { first, luck.randomItem("shop", { first }, nextLevel) }

    -- Two different random upgrades, then KEEP BONUS (always there),
    -- each priced for its NEXT level.
    shop.stock.upgrades = {}
    local offered = pickDifferent(upgrades.ORDER, 2)
    table.insert(offered, "keep")
    for _, id in ipairs(offered) do
        table.insert(shop.stock.upgrades,
            { id = id, label = upgrades.nextLabel(id), price = upgrades.nextPrice(id) })
    end

    shop.sold = { dice = {}, luck = {}, upgrades = {} }
    shop.selectedInv = nil
    shop.message = "Welcome to the shop!"

    -- An idle reel showing a few random items.
    shop.machine = { strip = randomStrip(3), spinning = false, time = 0, prize = nil }
end

-- Buy dice card k (1 or 2).
function shop.buyDice(k)
    if shop.sold.dice[k] then return end
    local dieType = dicetypes.get(shop.stock.dice[k])
    if not player.spend(dieType.price) then
        shop.message = "Not enough coins for " .. dieType.name .. "."
        return
    end
    player.addToInventory(dieType.id)
    shop.sold.dice[k] = true
    shop.message = "Bought " .. dieType.name .. "! It's in your inventory."
end

-- Give the player a luck item and say what happened.
local function takeLuckItem(id, prefix)
    local item = luck.get(id)
    local old = luck.current
    luck.give(id)
    if old and old ~= id then
        shop.message = prefix .. item.name .. "! (replaced " .. luck.get(old).name .. ")"
    else
        shop.message = prefix .. item.name .. "!  " .. luck.durationText(item) .. "."
    end
end

-- Buy luck card k (1 or 2).
function shop.buyLuck(k)
    if shop.sold.luck[k] then return end
    local item = luck.get(shop.stock.luck[k])
    if not player.spend(luck.price(item)) then
        shop.message = "Not enough coins for " .. item.name .. "."
        return
    end
    shop.sold.luck[k] = true
    takeLuckItem(item.id, "Bought ")
end

-- Buy upgrade card k (1 or 2): one more level of that upgrade.
function shop.buyUpgrade(k)
    if shop.sold.upgrades[k] then return end
    local offer = shop.stock.upgrades[k]
    if not player.spend(offer.price) then
        shop.message = "Not enough coins for " .. offer.label .. "."
        return
    end
    upgrades.levelUp(offer.id)
    shop.sold.upgrades[k] = true
    shop.message = offer.label .. " bought!  " .. upgrades.DEFS[offer.id].about .. "."
end

-- Buy one more marker (white chip) to place at the start of each level.
function shop.buyMarker()
    if markers.owned >= markers.MAX_OWNED then
        shop.message = "You already have the most markers (" .. markers.MAX_OWNED .. ")."
        return
    end
    local price = markers.nextPrice()
    if not player.spend(price) then
        shop.message = "Another marker costs " .. price .. " coins."
        return
    end
    markers.owned = markers.owned + 1
    shop.message = "+1 MARKER!  You now have " .. markers.owned .. " chips to place each level."
end

-- Pull the Mystery Machine's lever.
function shop.pullMystery()
    local m = shop.machine
    if m.spinning then return end
    if not player.spend(shop.MYSTERY_PRICE) then
        shop.message = "The Mystery Machine costs " .. shop.MYSTERY_PRICE .. " coins."
        return
    end

    -- Decide the prize NOW, then build a reel that ends on it. The spin is
    -- just for show - like the dice, the result is picked first.
    m.prize = luck.randomItem("mystery")
    m.strip = randomStrip(26)
    -- Start the new reel on whatever was showing, so it doesn't jump.
    m.strip[1] = shop.machine.strip[#shop.machine.strip] or m.strip[1]
    table.insert(m.strip, m.prize)
    m.time = 0
    m.spinning = true
    shop.message = "Round and round it goes..."
end

-- Move the reel along. Called every frame from love.update while in the shop.
function shop.update(dt)
    local m = shop.machine
    if not m.spinning then return end
    m.time = m.time + dt
    if m.time >= shop.SPIN_TIME then
        m.spinning = false
        takeLuckItem(m.prize, "MYSTERY MACHINE: ")
    end
end

-- How far the reel has turned, in "items": 0 shows strip[1], 1 shows strip[2]...
-- It eases out, so the reel slows down before it stops on the prize.
function shop.reelPosition()
    local m = shop.machine
    local last = #m.strip - 1
    if not m.spinning then
        return last
    end
    return last * easeOut(math.min(1, m.time / shop.SPIN_TIME))
end

-- Click an inventory die to pick it (click it again to un-pick).
function shop.selectInventory(j)
    if shop.selectedInv == j then
        shop.selectedInv = nil
        shop.message = ""
    else
        shop.selectedInv = j
        shop.message = dicetypes.get(player.inventory[j]).name .. " picked - choose which of your dice it replaces."
    end
end

-- Click one of the 5 slots: swap the picked inventory die into it.
function shop.equipTo(slot)
    if shop.selectedInv == nil then
        shop.message = "Pick a die from your inventory first."
        return
    end
    local incomingName = dicetypes.get(player.inventory[shop.selectedInv]).name
    player.equip(slot, shop.selectedInv)
    shop.selectedInv = nil
    shop.message = incomingName .. " is now die " .. slot .. "."
end


---------------------------------------------------------------------------
-- LAYOUT (where things are) - used by shopdraw.lua AND by clicking
---------------------------------------------------------------------------
--
--                 [  SHOP  marquee sign  ]
--   +-- DICE --+ +-- LUCK --+ +--- UPGRADES ----+
--   | [ ] [ ]  | | [ ] [ ]  | | [ ] [ ] [KEEP]  |
--   +----------+ +----------+ +-----------------+
--   +- YOUR DICE -+  +--MYSTERY--+  +- HOLDING -+ +MARKERS+
--   | o o o o o   |  |  [reel]   |  |  item     | | +1    |
--   | inventory   |  |  [SPIN]   |       [CONTINUE]
--   +-------------+  +-----------+        message

local function rect(x, y, w, h)
    return { x = x, y = y, w = w, h = h }
end

local function isInside(px, py, r)
    return px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

-- The y of the top of the shop, so the whole thing is centred vertically.
function shop.getTop()
    return math.max(8, (love.graphics.getHeight() - SHOP_HEIGHT) / 2)
end

-- How many cards each top window holds (1 = dice, 2 = luck, 3 = upgrades).
local CARDS_IN = { 2, 2, 3 }

-- Width of a window holding 'n' cards.
local function windowW(n)
    return n * shop.CARD_W + (n - 1) * shop.CARD_GAP + 2 * shop.WINDOW_PAD
end

-- The left edge of everything (the three windows are centred), and the
-- total width they take up.
local function shopLeft()
    local total = 2 * shop.WINDOW_GAP
    for _, n in ipairs(CARDS_IN) do
        total = total + windowW(n)
    end
    return (love.graphics.getWidth() - total) / 2, total
end

-- The marquee sign at the top.
function shop.signRect()
    return rect((love.graphics.getWidth() - 460) / 2, shop.getTop() + 2, 460, 60)
end

-- Window w (1 = dice, 2 = luck, 3 = upgrades).
function shop.windowRect(w)
    local x = shopLeft()
    for previous = 1, w - 1 do
        x = x + windowW(CARDS_IN[previous]) + shop.WINDOW_GAP
    end
    return rect(x, shop.getTop() + 94, windowW(CARDS_IN[w]), shop.WINDOW_HEAD + shop.CARD_H + shop.WINDOW_PAD)
end

-- Which window each kind of card lives in.
local WINDOW_FOR = { dice = 1, luck = 2, upgrades = 3 }

-- Card n of a kind ("dice" and "luck" have 2 cards, "upgrades" has 3).
function shop.cardRect(kind, n)
    local win = shop.windowRect(WINDOW_FOR[kind])
    return rect(win.x + shop.WINDOW_PAD + (n - 1) * (shop.CARD_W + shop.CARD_GAP),
        win.y + shop.WINDOW_HEAD, shop.CARD_W, shop.CARD_H)
end

-- The bottom row starts here.
local function bottomY()
    return shop.getTop() + 428
end

-- "YOUR DICE" window (with the inventory inside it).
function shop.diceWindowRect()
    local left = shopLeft()
    return rect(left, bottomY(), 470, 240)
end

-- Loadout slot i (your 5 dice).
function shop.slotRect(i)
    local win = shop.diceWindowRect()
    local rowW = config.NUM_DICE * shop.SLOT_SIZE + (config.NUM_DICE - 1) * shop.SLOT_GAP
    local x = win.x + (win.w - rowW) / 2 + (i - 1) * (shop.SLOT_SIZE + shop.SLOT_GAP)
    return rect(x, win.y + shop.WINDOW_HEAD + 10, shop.SLOT_SIZE, shop.SLOT_SIZE)
end

-- Inventory die j.
function shop.inventoryRect(j)
    local win = shop.diceWindowRect()
    local count = #player.inventory
    local rowW = count * shop.INV_SIZE + (count - 1) * shop.INV_GAP
    local x = win.x + (win.w - rowW) / 2 + (j - 1) * (shop.INV_SIZE + shop.INV_GAP)
    return rect(x, win.y + shop.WINDOW_HEAD + shop.SLOT_SIZE + 46, shop.INV_SIZE, shop.INV_SIZE)
end

-- The Mystery Machine cabinet, and its parts.
function shop.machineRect()
    local d = shop.diceWindowRect()
    return rect(d.x + d.w + 30, bottomY(), shop.MACHINE_W, shop.MACHINE_H)
end

function shop.reelRect()
    local m = shop.machineRect()
    return rect(m.x + 30, m.y + 66, m.w - 60, 150)
end

function shop.spinButtonRect()
    local m = shop.machineRect()
    return rect(m.x + 20, m.y + m.h - 62, m.w - 40, 48)
end

-- The column on the right of the machine: HOLDING and MARKERS side by
-- side, then Continue and the message underneath.
local MARKERS_W = 190

local function rightColumn()
    local m = shop.machineRect()
    local left, total = shopLeft()
    local x = m.x + m.w + 40
    return rect(x, bottomY(), left + total - x, 150)
end

function shop.holdingRect()
    local c = rightColumn()
    return rect(c.x, c.y, c.w - MARKERS_W - 18, c.h)
end

function shop.markersRect()
    local c = rightColumn()
    return rect(c.x + c.w - MARKERS_W, c.y, MARKERS_W, c.h)
end

function shop.markerButtonRect()
    local r = shop.markersRect()
    return rect(r.x + 16, r.y + r.h - 50, r.w - 32, 38)
end

function shop.continueRect()
    local c = rightColumn()
    return rect(c.x + (c.w - shop.CONTINUE_W) / 2, c.y + c.h + 20, shop.CONTINUE_W, shop.CONTINUE_H)
end

function shop.messageRect()
    local c = rightColumn()
    local b = shop.continueRect()
    return rect(c.x, b.y + b.h + 14, c.w, 80)
end


---------------------------------------------------------------------------
-- CLICKS
---------------------------------------------------------------------------

-- Handle a left-click at (px, py).
-- Returns "continue" if the Continue button was clicked, so main.lua can
-- start the next level. Everything else is handled right here.
function shop.click(px, py)
    for n = 1, 2 do
        if isInside(px, py, shop.cardRect("dice", n)) then shop.buyDice(n); return nil end
        if isInside(px, py, shop.cardRect("luck", n)) then shop.buyLuck(n); return nil end
    end
    for n = 1, 3 do
        if isInside(px, py, shop.cardRect("upgrades", n)) then shop.buyUpgrade(n); return nil end
    end

    if isInside(px, py, shop.markersRect()) then
        shop.buyMarker()
        return nil
    end

    if isInside(px, py, shop.spinButtonRect()) or isInside(px, py, shop.reelRect()) then
        shop.pullMystery()
        return nil
    end

    for i = 1, config.NUM_DICE do
        if isInside(px, py, shop.slotRect(i)) then shop.equipTo(i); return nil end
    end

    for j = 1, #player.inventory do
        if isInside(px, py, shop.inventoryRect(j)) then shop.selectInventory(j); return nil end
    end

    if isInside(px, py, shop.continueRect()) then
        if shop.machine.spinning then
            shop.message = "Wait for the Mystery Machine to stop!"
            return nil
        end
        return "continue"
    end
    return nil
end

return shop
