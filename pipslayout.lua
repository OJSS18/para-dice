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
-- THE SHOP
--   +-----------+-----------------+--------------+
--   | FOR SALE  |  SLOT MACHINE   |  YOUR PERKYS |
--   +-----------+-----------------+              |
--   | YOUR DICE  |  AUGMENTS      |  NEXT ROUND  |
--   +-----------+-----------------+--------------+

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

-- Perky card k (1-5) along the top of the middle.
function pipslayout.perkyCard(k)
    local m = pipslayout.middle()
    local n = config.PIPS.MAX_PERKYS
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
---------------------------------------------------------------------------

pipslayout.CARD_W = 170
pipslayout.CARD_H = 236

function pipslayout.shopSign()
    local W = size()
    return rect((W - 420) / 2, 8, 420, 56)
end

function pipslayout.forSale()
    return rect(MARGIN, 108, 2 * pipslayout.CARD_W + 12 + 32, 360)
end

function pipslayout.itemCard(k)
    local f = pipslayout.forSale()
    return rect(f.x + 16 + (k - 1) * (pipslayout.CARD_W + 12), f.y + 26, pipslayout.CARD_W, pipslayout.CARD_H)
end

function pipslayout.shopRerollButton()
    local f = pipslayout.forSale()
    return rect(f.x + 16, f.y + f.h - 72, f.w - 32, 54)
end

function pipslayout.machine()
    local f = pipslayout.forSale()
    return rect(f.x + f.w + GAP, f.y, 470, f.h)
end

function pipslayout.reel(k)
    local m = pipslayout.machine()
    local w, gap = 132, 14
    local total = 3 * w + 2 * gap
    return rect(m.x + (m.w - total) / 2 + (k - 1) * (w + gap), m.y + 70, w, 160)
end

function pipslayout.spinButton()
    local m = pipslayout.machine()
    return rect(m.x + 90, m.y + m.h - 72, m.w - 180, 54)
end

function pipslayout.perkyWindow()
    local W, H = size()
    local m = pipslayout.machine()
    local x = m.x + m.w + GAP
    return rect(x, 108, W - MARGIN - x, H - 108 - 110)
end

function pipslayout.perkyRow(k)
    local p = pipslayout.perkyWindow()
    local h = math.min(86, (p.h - 40) / config.PIPS.MAX_PERKYS - 6)
    return rect(p.x + 12, p.y + 26 + (k - 1) * (h + 6), p.w - 24, h)
end

function pipslayout.sellButton(k)
    local r = pipslayout.perkyRow(k)
    return rect(r.x + r.w - 74, r.y + (r.h - 34) / 2, 66, 34)
end

function pipslayout.continueButton()
    local W, H = size()
    local p = pipslayout.perkyWindow()
    return rect(p.x, H - MARGIN - 66, p.w, 66)
end

function pipslayout.diceWindow()
    local _, H = size()
    local f = pipslayout.forSale()
    local m = pipslayout.machine()
    local y = f.y + f.h + 26
    return rect(f.x, y, (m.x + m.w - f.x) * 0.58, H - MARGIN - y)
end

function pipslayout.shopDie(i, slots)
    local w = pipslayout.diceWindow()
    local s = math.min(64, (w.w - 30) / slots - 8)
    return rect(w.x + 16 + (i - 1) * (s + 8), w.y + 34, s, s)
end

function pipslayout.augWindow()
    local d = pipslayout.diceWindow()
    local m = pipslayout.machine()
    local x = d.x + d.w + GAP
    return rect(x, d.y, m.x + m.w - x, d.h)
end

-- The pack you opened covers FOR SALE and the slot machine.
function pipslayout.packWindow()
    local f = pipslayout.forSale()
    local m = pipslayout.machine()
    return rect(f.x, f.y, m.x + m.w - f.x, f.h)
end

function pipslayout.packOption(k, count)
    local p = pipslayout.packWindow()
    local w = math.min(pipslayout.CARD_W, (p.w - 40 - (count - 1) * 12) / count)
    local total = count * w + (count - 1) * 12
    return rect(p.x + (p.w - total) / 2 + (k - 1) * (w + 12), p.y + 40, w, pipslayout.CARD_H)
end

function pipslayout.skipButton()
    local p = pipslayout.packWindow()
    return rect(p.x + (p.w - 200) / 2, p.y + p.h - 68, 200, 52)
end

return pipslayout
