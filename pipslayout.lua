-- pipslayout.lua
-- PIPS MODE: WHERE everything sits on screen. Drawing (pipsdraw.lua) and
-- clicking (pipsinput.lua) both ask this file, so they always agree.
-- Every function gives back a rectangle { x, y, w, h } (see util.rect).
--
-- THE PLAY SCREEN
--   +-----------+-------------------------------+----------+
--   | SCOREBOARD|  PERKYS (5 cards)             |  SETS    |
--   | goal,     |                               |  list    |
--   | score,    |  DICE (3 to 11)               |          |
--   | POINTS x  |                               |          |
--   | MULT      |  CRAPS BETS                   |          |
--   | buttons   |                               |          |
--   +-----------+-------------------------------+----------+
--
-- THE SHOP: FOR SALE on the left half; the pack machine, your dice, NEXT
-- ROUND and your Perkys on the right half (picture further down).

local util     = require("util")
local config   = require("config")
local pipsgame = require("pipsgame")

local pipslayout = {}

local rect = util.rect
local MARGIN = 24
local GAP = 20

local function size()
    return love.graphics.getWidth(), love.graphics.getHeight()
end


---------------------------------------------------------------------------
-- THE PLAY SCREEN
---------------------------------------------------------------------------

pipslayout.PANEL_W = 330
pipslayout.SETS_W  = 250

function pipslayout.panel()
    local _, H = size()
    return rect(MARGIN, MARGIN, pipslayout.PANEL_W, H - 2 * MARGIN)
end

function pipslayout.setsPanel()
    local W, H = size()
    return rect(W - MARGIN - pipslayout.SETS_W, MARGIN, pipslayout.SETS_W, H - 2 * MARGIN)
end

-- The middle part, between the two panels.
function pipslayout.middle()
    local p, s = pipslayout.panel(), pipslayout.setsPanel()
    local x = p.x + p.w + GAP
    return rect(x, p.y, s.x - GAP - x, p.h)
end

-- Perky card k of n (5, or 6 with the mythic VIP upgrade) along the top of the middle.
function pipslayout.perkyCard(k, n)
    local m = pipslayout.middle()
    n = n or config.PIPS.MAX_PERKYS
    local gap = 10
    local w = math.min(170, (m.w - 20 - (n - 1) * gap) / n)
    local total = n * w + (n - 1) * gap
    return rect(m.x + (m.w - total) / 2 + (k - 1) * (w + gap), m.y + 40, w, 160)
end

-- The dice slots: 'slots' of them in a row across the middle.
function pipslayout.dieSize(slots)
    local m = pipslayout.middle()
    return math.min(92, math.floor((m.w - 40) / slots - 12))
end

function pipslayout.dieRect(i, slots)
    local m = pipslayout.middle()
    local s = pipslayout.dieSize(slots)
    local gap = math.min(24, s * 0.3)
    local total = slots * s + (slots - 1) * gap
    local y = m.y + m.h * 0.5 - s / 2 + 10
    return rect(m.x + (m.w - total) / 2 + (i - 1) * (s + gap), y, s, s)
end

-- Which die is at (x, y)? Its number, or nil.
function pipslayout.dieAt(x, y)
    local run = pipsgame.run
    for i = 1, #run.dice do
        local r = pipslayout.dieRect(i, run.slots)
        -- (a held die is drawn raised, so allow a bit above it too)
        if util.isInside(x, y, rect(r.x, r.y - 24, r.w, r.h + 24)) then return i end
    end
    return nil
end

-- The craps bets strip near the bottom of the middle.
function pipslayout.betsStrip()
    local m = pipslayout.middle()
    return rect(m.x + 20, m.y + m.h - 120, m.w - 40, 100)
end

function pipslayout.betBox(k, count)
    local s = pipslayout.betsStrip()
    local w = math.min(80, (s.w - 20) / math.max(1, count) - 8)
    local total = count * w + (count - 1) * 8
    return rect(s.x + (s.w - total) / 2 + (k - 1) * (w + 8), s.y + 36, w, 54)
end

-- The buttons at the bottom of the scoreboard panel.
function pipslayout.rerollButton()
    local p = pipslayout.panel()
    return rect(p.x + 18, p.y + p.h - 140, (p.w - 46) / 2, 58)
end
function pipslayout.scoreButton()
    local p = pipslayout.panel()
    local r = pipslayout.rerollButton()
    return rect(r.x + r.w + 10, r.y, r.w, r.h)
end
-- NEXT (after a set is scored) takes the place of both.
function pipslayout.nextButton()
    local r = pipslayout.rerollButton()
    local s = pipslayout.scoreButton()
    return rect(r.x, r.y, s.x + s.w - r.x, r.h)
end
-- The little MENU button at the very bottom of the panel.
function pipslayout.menuButton()
    local p = pipslayout.panel()
    return rect(p.x + 18, p.y + p.h - 66, p.w - 36, 44)
end

-- The strip between the Perkys and your dice: the boss (or Pit Boss Josh
-- and his dice) during a boss round.
function pipslayout.bossStrip()
    local m = pipslayout.middle()
    return rect(m.x + 10, m.y + 214, m.w - 20, 84)
end

-- Josh's dice, in a row in the boss strip (right of his picture).
function pipslayout.joshDieRect(i, count)
    local s = pipslayout.bossStrip()
    local left = s.x + 70
    local size = math.min(54, math.floor((s.w - 80) / count - 8))
    local gap = 8
    local total = count * size + (count - 1) * gap
    return rect(left + (s.w - 70 - total) / 2 + (i - 1) * (size + gap), s.y + 4, size, size)
end

-- FIGHT on the boss screen.
function pipslayout.fightButton()
    local W, H = size()
    return rect((W - 300) / 2, H - 120, 300, 66)
end

-- The window in the middle for ROUND WON / GAME OVER / VICTORY.
function pipslayout.popup()
    local W, H = size()
    return rect((W - 520) / 2, (H - 440) / 2, 520, 440)
end
function pipslayout.popupButton(n, count)
    local p = pipslayout.popup()
    local w = (p.w - 60 - (count - 1) * 16) / count
    return rect(p.x + 30 + (n - 1) * (w + 16), p.y + p.h - 84, w, 58)
end


---------------------------------------------------------------------------
-- THE SHOP
--   +-----------------------+----------------------+
--   | FOR SALE              |  PACK MACHINE        |
--   |  [item] [item] (item) |                      |
--   |      REROLL           +-----------+----------+
--   |  VIP UPGRADE          | YOUR DICE |  NEXT    |
--   |  [card]  words        +-----------+----------+
--   |                       | YOUR PERKYS (2 x 3)  |
--   +-----------------------+----------------------+
---------------------------------------------------------------------------

pipslayout.CARD_W = 170
pipslayout.CARD_H = 236
pipslayout.SHOP_DIE = 44      -- your dice in the shop (7 fit in the YOUR DICE window)

function pipslayout.shopSign()
    local W = size()
    return rect((W - 420) / 2, 8, 420, 56)
end

-- FOR SALE takes the left half of the shop.
function pipslayout.forSale()
    local W, H = size()
    return rect(MARGIN, 108, W / 2 - MARGIN - GAP / 2, H - 108 - MARGIN)
end

-- Main item k of 'count', in a row along the top of FOR SALE.
function pipslayout.itemCard(k, count)
    local f = pipslayout.forSale()
    local w = math.min(pipslayout.CARD_W, (f.w - 32 - (count - 1) * 12) / count)
    local total = count * w + (count - 1) * 12
    return rect(f.x + (f.w - total) / 2 + (k - 1) * (w + 12), f.y + 30, w, pipslayout.CARD_H)
end

function pipslayout.shopRerollButton()
    local f = pipslayout.forSale()
    return rect(f.x + (f.w - 260) / 2, f.y + 30 + pipslayout.CARD_H + 14, 260, 50)
end

-- This level's VIP upgrade card (bottom-left of FOR SALE), with its words to the right.
function pipslayout.vipCard()
    local f = pipslayout.forSale()
    local y = pipslayout.shopRerollButton().y + 50 + 40
    return rect(f.x + 24, y, pipslayout.CARD_W, f.y + f.h - 16 - y)
end

-- The right half: the pack machine on top.
local function rightSide()
    local W = size()
    local x = W / 2 + GAP / 2
    return x, W - MARGIN - x
end

function pipslayout.machine()
    local x, w = rightSide()
    return rect(x, 108, w, 300)
end

function pipslayout.reel(k)
    local m = pipslayout.machine()
    local w, gap = 132, 14
    local total = 3 * w + 2 * gap
    return rect(m.x + (m.w - total) / 2 + (k - 1) * (w + gap), m.y + 70, w, 130)
end

function pipslayout.spinButton()
    local m = pipslayout.machine()
    return rect(m.x + (m.w - 280) / 2, m.y + m.h - 60, 280, 48)
end

-- YOUR DICE: just wide enough for 7 dice (the most you can have).
function pipslayout.diceWindow()
    local x = rightSide()
    local m = pipslayout.machine()
    return rect(x, m.y + m.h + 26, pipsgame.slotsFor(99) * (pipslayout.SHOP_DIE + 6) + 30, 110)
end

function pipslayout.shopDie(i, slots)
    local w = pipslayout.diceWindow()
    local s = math.min(pipslayout.SHOP_DIE, (w.w - 30) / slots - 6)
    return rect(w.x + 15 + (i - 1) * (s + 6), w.y + 36, s, s)
end

-- NEXT ROUND, to the right of YOUR DICE.
function pipslayout.continueButton()
    local x, rw = rightSide()
    local d = pipslayout.diceWindow()
    return rect(d.x + d.w + 12, d.y, x + rw - (d.x + d.w + 12), d.h)
end

-- YOUR PERKYS: a small window at the bottom right, 2 columns of slots.
function pipslayout.perkyWindow()
    local _, H = size()
    local x, w = rightSide()
    local d = pipslayout.diceWindow()
    local y = d.y + d.h + 26
    return rect(x, y, w, H - MARGIN - y)
end

function pipslayout.perkyRow(k)
    local p = pipslayout.perkyWindow()
    local cw = (p.w - 24 - 8) / 2
    local ch = (p.h - 34) / 3 - 4
    local col = (k - 1) % 2
    local row = math.floor((k - 1) / 2)
    return rect(p.x + 12 + col * (cw + 8), p.y + 26 + row * (ch + 4), cw, ch)
end

function pipslayout.sellButton(k)
    local r = pipslayout.perkyRow(k)
    return rect(r.x + r.w - 58, r.y + (r.h - 30) / 2, 52, 30)
end

-- A pack you opened covers FOR SALE.
function pipslayout.packWindow()
    return pipslayout.forSale()
end

function pipslayout.packOption(k, count)
    local p = pipslayout.packWindow()
    local w = math.min(pipslayout.CARD_W, (p.w - 40 - (count - 1) * 12) / count)
    local total = count * w + (count - 1) * 12
    return rect(p.x + (p.w - total) / 2 + (k - 1) * (w + 12), p.y + 40, w, pipslayout.CARD_H)
end

function pipslayout.skipButton()
    local p = pipslayout.packWindow()
    return rect(p.x + (p.w - 200) / 2, p.y + 40 + pipslayout.CARD_H + 24, 200, 52)
end

return pipslayout
