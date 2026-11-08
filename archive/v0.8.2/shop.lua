-- shop.lua
-- The SHOP between levels: what's for sale, buying, the Mystery Machine,
-- selling luck items, swapping dice into your 5 slots, and WHERE
-- everything sits on screen.
--
-- What's on offer each visit (each in its own Vegas-style window):
--   * DICE      - 2 random coloured dice. Bought dice go to your inventory;
--                 then you swap one into any of your 5 slots.
--   * UPGRADES  - ALL 6 upgrades, every visit. Buy as many levels as you can
--                 afford; each level costs more than the last.
--   * YOUR LUCK - the luck items you hold (up to 3). SELL any of them.
--   * THE MYSTERY MACHINE - a THREE-reel slot machine: 35 coins for the first
--                 spin each visit, then 10 more for each spin after that.
--                 Each reel lands on a random luck item and you pick ONE.
--                 Odds by rarity 35/35/25/4/1 %. Luck items can't be got
--                 any other way. If your 3 slots are full, sell one first.
--
-- This file is LOGIC + LAYOUT. The drawing lives in shopdraw.lua.

local config    = require("config")
local dicetypes = require("dicetypes")
local luck      = require("luck")
local player    = require("player")
local upgrades  = require("upgrades")
local markers   = require("markers")
local util      = require("util")
local rng       = require("rng")

local shop = {}


---------------------------------------------------------------------------
-- SIZES (tweak these to resize the shop)
---------------------------------------------------------------------------

shop.CARD_W      = 160   -- each item card
shop.CARD_H      = 270
shop.CARD_GAP    = 12    -- gap between the cards in a window
shop.WINDOW_PAD  = 14    -- space between a window's frame and its cards
shop.WINDOW_HEAD = 34    -- room at the top of a window for its title plate
shop.WINDOW_GAP  = 18    -- gap between the top windows

shop.SLOT_SIZE   = 76    -- your 5 equipped dice
shop.SLOT_GAP    = 12
shop.INV_SIZE    = 58    -- dice in your inventory
shop.INV_GAP     = 10

shop.LUCK_W      = 360   -- the YOUR LUCK window (top right)

shop.MACHINE_W   = 520   -- the Mystery Machine cabinet
shop.MACHINE_H   = 320
shop.REELS       = 3
shop.REEL_W      = 148
shop.REEL_GAP    = 14
-- A spin costs MYSTERY_PRICE, plus MYSTERY_STEP more for every spin already
-- made at this visit (35, 45, 55...). It goes back to 35 at the next shop.
shop.MYSTERY_PRICE = 35
shop.MYSTERY_STEP  = 10
shop.spins = 0           -- spins made at this visit
shop.SPIN_TIME   = 2.2   -- seconds the FIRST reel spins for...
shop.REEL_DELAY  = 0.45  -- ...and each next reel stops this much later

shop.CONTINUE_H  = 56

-- The whole shop is this tall; it's centred top-to-bottom on screen.
local SHOP_HEIGHT = 748


---------------------------------------------------------------------------
-- DATA (what's in the shop right now)
---------------------------------------------------------------------------

-- What's for sale:
--   dice     = { "red", "amber" }
--   upgrades = { {id = "even"}, {id = "odd"}, ... }  (all 6; label and price are live)
shop.stock = { dice = {}, upgrades = {} }

-- sold.dice[1] = true once the first dice card has been bought, etc.
shop.sold = { dice = {}, upgrades = {} }

-- Which inventory die is picked, waiting to be swapped into a slot (or nil).
shop.selectedInv = nil

-- A line of feedback ("Bought Dice of Red!", ...).
shop.message = ""

-- The level the player is about to play.
shop.nextLevel = 1

-- THE MYSTERY MACHINE
--   reels[k]  - { strip = {...}, prize = id }: the item ids painted on
--               reel k, top to bottom; the LAST one is where it stops (the
--               prize). Before the first spin, prize is nil.
--   spinning  - true while any reel is turning
--   time      - seconds since this spin started
--   taken     - which reel's prize the player picked (nil = not yet)
--   warned    - true once we've warned that an untaken prize will be lost
shop.machine = { reels = {}, spinning = false, time = 0, taken = nil, warned = false }


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
        table.insert(picked, table.remove(pool, rng.random(1, #pool)))
    end
    return picked
end

-- Fast at first, slowing to a stop - for the reels.
local function easeOut(p)
    return 1 - (1 - p) ^ 3
end

-- Some random items to paint on a reel (just for show).
local function randomStrip(count)
    local strip = {}
    for i = 1, count do
        strip[i] = luck.randomItem()
    end
    return strip
end

-- Three idle reels showing random items, with no prizes on them.
local function idleReels()
    local reels = {}
    for k = 1, shop.REELS do
        reels[k] = { strip = randomStrip(3), prize = nil }
    end
    return reels
end


---------------------------------------------------------------------------
-- LOGIC
---------------------------------------------------------------------------

-- Fill the shop with fresh stock. 'nextLevel' is the level about to be played.
function shop.open(nextLevel)
    shop.nextLevel = nextLevel

    shop.stock.dice = pickDifferent(dicetypes.shopTypes(), 2)

    -- Every upgrade, every visit (they can be levelled up again and again).
    shop.stock.upgrades = {}
    for _, id in ipairs(shop.UPGRADES) do
        table.insert(shop.stock.upgrades, { id = id })
    end

    shop.sold = { dice = {}, upgrades = {} }
    shop.selectedInv = nil
    shop.spins = 0      -- the Mystery Machine's price starts low again
    shop.message = "Welcome to the shop!"

    -- Idle reels showing a few random items.
    shop.machine = { reels = idleReels(), spinning = false, time = 0, taken = nil, warned = false }
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

-- Sell the luck item in slot k of YOUR LUCK.
function shop.sellLuck(k)
    local id = luck.held[k]
    if id == nil then return end
    local name = luck.get(id).name
    local coins = luck.sell(k)
    player.addCoins(coins)
    shop.message = "Sold " .. name .. " for " .. coins .. " coins."
end

-- Buy upgrade card k (1 to 6): one more level of that upgrade. It can be
-- bought again straight away - the next level just costs more.
function shop.buyUpgrade(k)
    local offer = shop.stock.upgrades[k]
    if offer == nil then return end
    local label, price = upgrades.nextLabel(offer.id), upgrades.nextPrice(offer.id)
    if not player.spend(price) then
        shop.message = "Not enough coins for " .. label .. " (" .. price .. ")."
        return
    end
    upgrades.levelUp(offer.id)
    shop.message = label .. " bought!  " .. upgrades.DEFS[offer.id].about .. "."
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


---------------------------------------------------------------------------
-- THE MYSTERY MACHINE
---------------------------------------------------------------------------

-- Have the reels landed on prizes that nobody has taken yet?
function shop.hasUntakenPrizes()
    local m = shop.machine
    return not m.spinning and m.reels[1] ~= nil and m.reels[1].prize ~= nil and m.taken == nil
end

-- What the next spin costs.
function shop.spinPrice()
    return shop.MYSTERY_PRICE + shop.MYSTERY_STEP * shop.spins
end

-- Pull the Mystery Machine's lever.
function shop.pullMystery()
    local m = shop.machine
    if m.spinning then return end
    -- Spinning again throws away prizes you haven't picked - warn once.
    if shop.hasUntakenPrizes() and not m.warned then
        m.warned = true
        shop.message = "You haven't picked a prize! SPIN again to give them up."
        return
    end
    local price = shop.spinPrice()
    if not player.spend(price) then
        shop.message = "The next spin costs " .. price .. " coins."
        return
    end
    shop.spins = shop.spins + 1

    -- Decide the 3 prizes NOW (all different, and none you already hold),
    -- then build each reel so it ends on its prize. The spin is just for
    -- show - like the dice, the result is picked first.
    local exclude = {}
    for _, id in ipairs(luck.held) do
        table.insert(exclude, id)
    end
    for k = 1, shop.REELS do
        local old = m.reels[k]
        local prize = luck.randomItem(exclude)
        table.insert(exclude, prize)
        -- Later reels spin longer, so they get longer strips.
        local strip = randomStrip(20 + 6 * k)
        -- Start the new strip on whatever was showing, so it doesn't jump.
        strip[1] = old.strip[#old.strip] or strip[1]
        table.insert(strip, prize)
        m.reels[k] = { strip = strip, prize = prize }
    end
    m.time = 0
    m.spinning = true
    m.taken = nil
    m.warned = false
    shop.message = "Round and round they go..."
end

-- How long reel k spins for (each one stops a little after the one before).
function shop.reelSpinTime(k)
    return shop.SPIN_TIME + (k - 1) * shop.REEL_DELAY
end

-- Has reel k stopped?
function shop.reelStopped(k)
    local m = shop.machine
    return not m.spinning or m.time >= shop.reelSpinTime(k)
end

-- Move the reels along. Called every frame from love.update while in the shop.
function shop.update(dt)
    local m = shop.machine
    if not m.spinning then return end
    m.time = m.time + dt
    if m.time >= shop.reelSpinTime(shop.REELS) then
        m.spinning = false
        if luck.isFull() then
            shop.message = "Your luck slots are full - SELL one in YOUR LUCK, then pick a prize!"
        else
            shop.message = "Pick ONE prize - click its reel!"
        end
    end
end

-- How far reel k has turned, in "items": 0 shows strip[1], 1 shows strip[2]...
-- It eases out, so the reel slows down before it stops on the prize.
function shop.reelPosition(k)
    local m = shop.machine
    local last = #m.reels[k].strip - 1
    if shop.reelStopped(k) then
        return last
    end
    return last * easeOut(m.time / shop.reelSpinTime(k))
end

-- Take the prize on reel k.
function shop.takePrize(k)
    local m = shop.machine
    if m.spinning then return end
    local prize = m.reels[k].prize
    if prize == nil then return end
    if m.taken then
        shop.message = "You've already picked this spin's prize."
        return
    end
    if luck.isFull() then
        shop.message = "Your " .. luck.MAX_HELD .. " luck slots are full - SELL one in YOUR LUCK first."
        return
    end
    luck.give(prize)
    m.taken = k
    shop.message = "MYSTERY MACHINE: you got " .. luck.get(prize).name .. "!"
end


---------------------------------------------------------------------------
-- YOUR DICE
---------------------------------------------------------------------------

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
--   +-- DICE --+ +---- UPGRADES ----+ +-- YOUR LUCK --+
--   | [ ] [ ]  | | [ ] [ ] [KEEP]   | | item    SELL  |
--   |          | |                  | | item    SELL  |
--   +----------+ +------------------+ +---------------+
--   +- YOUR DICE -+  +--- MYSTERY MACHINE ---+  +MARKERS+
--   | o o o o o   |  | [reel] [reel] [reel]  |  | +1    |
--   | inventory   |  |        [SPIN]         |  message
--   +-------------+  +-----------------------+  [CONTINUE]

local rect, isInside = util.rect, util.isInside

-- The y of the top of the shop, so the whole thing is centred vertically.
function shop.getTop()
    return math.max(8, (love.graphics.getHeight() - SHOP_HEIGHT) / 2)
end

-- How many cards each card window holds (window 1 = dice, 2 = upgrades).
local CARDS_IN = { 2, 3 }

-- Width of a window holding 'n' cards.
local function windowW(n)
    return n * shop.CARD_W + (n - 1) * shop.CARD_GAP + 2 * shop.WINDOW_PAD
end

local WINDOW_H = shop.WINDOW_HEAD + shop.CARD_H + shop.WINDOW_PAD

-- The left edge of everything (the top row is centred), and the total
-- width it takes up.
local function shopLeft()
    local total = shop.LUCK_W + 2 * shop.WINDOW_GAP
    for _, n in ipairs(CARDS_IN) do
        total = total + windowW(n)
    end
    return (love.graphics.getWidth() - total) / 2, total
end

-- The marquee sign at the top.
function shop.signRect()
    return rect((love.graphics.getWidth() - 460) / 2, shop.getTop() + 2, 460, 60)
end

-- Card window w (1 = dice, 2 = upgrades).
function shop.windowRect(w)
    local x = shopLeft()
    for previous = 1, w - 1 do
        x = x + windowW(CARDS_IN[previous]) + shop.WINDOW_GAP
    end
    return rect(x, shop.getTop() + 94, windowW(CARDS_IN[w]), WINDOW_H)
end

-- Which window each kind of card lives in.
local WINDOW_FOR = { dice = 1, upgrades = 2 }

-- Every upgrade the shop sells, in the order its cards are laid out.
shop.UPGRADES = { "lower", "upper", "even", "odd", "common", "keep" }

-- Card n of a kind. "dice" has 2 full-size cards; "upgrades" has 6 small
-- ones in 3 columns x 2 rows.
function shop.cardRect(kind, n)
    local win = shop.windowRect(WINDOW_FOR[kind])
    if kind == "upgrades" then
        local col, row = (n - 1) % 3, math.floor((n - 1) / 3)
        local h = (shop.CARD_H - shop.CARD_GAP) / 2
        return rect(win.x + shop.WINDOW_PAD + col * (shop.CARD_W + shop.CARD_GAP),
            win.y + shop.WINDOW_HEAD + row * (h + shop.CARD_GAP), shop.CARD_W, h)
    end
    return rect(win.x + shop.WINDOW_PAD + (n - 1) * (shop.CARD_W + shop.CARD_GAP),
        win.y + shop.WINDOW_HEAD, shop.CARD_W, shop.CARD_H)
end

-- YOUR LUCK: top right, one row per luck slot.
function shop.luckRect()
    local left, total = shopLeft()
    return rect(left + total - shop.LUCK_W, shop.getTop() + 94, shop.LUCK_W, WINDOW_H)
end

-- Row k of YOUR LUCK.
function shop.luckRowRect(k)
    local r = shop.luckRect()
    local rowH = (r.h - shop.WINDOW_HEAD - shop.WINDOW_PAD) / luck.MAX_HELD
    return rect(r.x + 12, r.y + shop.WINDOW_HEAD + (k - 1) * rowH, r.w - 24, rowH)
end

-- Which YOUR LUCK row holds an item at (px, py)? (Not counting its SELL button.)
function shop.luckRowAt(px, py)
    for k = 1, #luck.held do
        if isInside(px, py, shop.luckRowRect(k)) and not isInside(px, py, shop.luckSellRect(k)) then
            return k
        end
    end
    return nil
end

-- Where a dragged item would land if let go at height py: the nearest row.
function shop.luckDropRowAt(py)
    local best, bestD = nil, math.huge
    for k = 1, #luck.held do
        local r = shop.luckRowRect(k)
        local d = math.abs(py - (r.y + r.h / 2))
        if d < bestD then best, bestD = k, d end
    end
    return best
end

-- How big the item pictures are: smaller when there are 4 rows (endless).
function shop.luckPictureSize()
    return luck.MAX_HELD > 3 and 40 or 56
end

-- Row k's SELL button, under its picture.
function shop.luckSellRect(k)
    local row = shop.luckRowRect(k)
    return rect(row.x, row.y + shop.luckPictureSize() + 6, 64, 22)
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

-- Reel k's window (the glass the pictures scroll past).
function shop.reelRect(k)
    local m = shop.machineRect()
    local rowW = shop.REELS * shop.REEL_W + (shop.REELS - 1) * shop.REEL_GAP
    local x = m.x + (m.w - rowW) / 2 + (k - 1) * (shop.REEL_W + shop.REEL_GAP)
    return rect(x, m.y + 62, shop.REEL_W, 92)
end

function shop.spinButtonRect()
    local m = shop.machineRect()
    return rect(m.x + (m.w - 240) / 2, m.y + m.h - 52, 240, 42)
end

-- Reel k plus the prize's name and words under it - click anywhere in
-- here to take that prize.
function shop.reelColumnRect(k)
    local reel = shop.reelRect(k)
    return rect(reel.x - 4, reel.y - 4, reel.w + 8, shop.spinButtonRect().y - reel.y - 2)
end

-- The column on the right of the machine: MARKERS, then CONTINUE.
local function rightColumn()
    local m = shop.machineRect()
    local left, total = shopLeft()
    local x = m.x + m.w + 44   -- room for the lever
    return rect(x, bottomY(), left + total - x, shop.MACHINE_H)
end

function shop.markersRect()
    local c = rightColumn()
    return rect(c.x, c.y, c.w, 150)
end

function shop.markerButtonRect()
    local r = shop.markersRect()
    return rect(r.x + 16, r.y + r.h - 50, r.w - 32, 38)
end

function shop.continueRect()
    local c = rightColumn()
    return rect(c.x, c.y + c.h - shop.CONTINUE_H, c.w, shop.CONTINUE_H)
end

-- The feedback message, between MARKERS and CONTINUE.
function shop.messageRect()
    local c = rightColumn()
    local top = shop.markersRect().y + shop.markersRect().h + 10
    return rect(c.x, top, c.w, shop.continueRect().y - 8 - top)
end


---------------------------------------------------------------------------
-- CLICKS
---------------------------------------------------------------------------

-- CONTINUE (button or Enter). Returns "continue" if it's OK to leave.
-- Leaving with a prize still on the reels warns once first.
function shop.tryContinue()
    local m = shop.machine
    if m.spinning then
        shop.message = "Wait for the Mystery Machine to stop!"
        return nil
    end
    if shop.hasUntakenPrizes() and not m.warned then
        m.warned = true
        shop.message = "You haven't picked a Mystery Machine prize! CONTINUE again to leave it."
        return nil
    end
    return "continue"
end

-- What a left-click at (px, py) means, as a game ACTION and its number,
-- e.g. "buyDice", 2. (main.lua passes it to game.act, so it gets recorded
-- for replays.) Returns nil if the click wasn't on anything.
function shop.click(px, py)
    for n = 1, 2 do
        if isInside(px, py, shop.cardRect("dice", n)) then return "buyDice", n end
    end
    for n = 1, #shop.UPGRADES do
        if isInside(px, py, shop.cardRect("upgrades", n)) then return "buyUpgrade", n end
    end
    for k = 1, luck.MAX_HELD do
        if luck.held[k] and isInside(px, py, shop.luckSellRect(k)) then return "sellShop", k end
    end
    if isInside(px, py, shop.markersRect()) then return "buyMarker" end
    if isInside(px, py, shop.spinButtonRect()) then return "spin" end
    for k = 1, shop.REELS do
        if isInside(px, py, shop.reelColumnRect(k)) then
            -- Once the reels have landed, clicking one takes its prize.
            if shop.hasUntakenPrizes() then return "take", k end
            return nil
        end
    end
    for i = 1, config.NUM_DICE do
        if isInside(px, py, shop.slotRect(i)) then return "equip", i end
    end
    for j = 1, #player.inventory do
        if isInside(px, py, shop.inventoryRect(j)) then return "selectInv", j end
    end
    if isInside(px, py, shop.continueRect()) then return "continue" end
    return nil
end

return shop
