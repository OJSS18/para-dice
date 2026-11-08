-- luckrack.lua
-- The LUCK RACK on the play screen: your 3 luck item slots, sitting on the
-- felt to the right of the dice tray. Hover over one to see what it does;
-- click its SELL button to sell it for coins - any time the dice aren't
-- rolling.
--
-- This file has its own layout (where the slots are), drawing, and click
-- handling, so main.lua and draw.lua only need one line each.

local layout  = require("layout")
local luck    = require("luck")
local luckart = require("luckart")
local player  = require("player")
local fonts   = require("fonts")
local ui      = require("ui")
local util    = require("util")

local luckrack = {}

local SLOT   = 60   -- each item picture
local GAP    = 14
local SELL_H = 22

-- The message under the rack ("Sold Sky High for +12 coins"), and how
-- long it has left on screen.
local note, noteTime = "", 0

-- REARRANGING luck items (main.lua fills these in; the rack and the shop
-- both draw them):
--   luckrack.selected - the slot picked with a click or the L key (the
--                       arrow keys then move it), or nil
--   luckrack.drag     - { from = slot, x, y, moved } while one is being dragged
luckrack.selected = nil
luckrack.drag = nil

-- Which slot's picture is at (px, py) on the rack? (Held items only.)
function luckrack.slotAt(px, py)
    for k = 1, #luck.held do
        if layout.isInside(px, py, luckrack.slotRect(k)) then return k end
    end
    return nil
end

-- Where a dragged item would land if let go at (px, py): the nearest slot.
function luckrack.dropSlotAt(px)
    local best, bestD = nil, math.huge
    for k = 1, #luck.held do
        local s = luckrack.slotRect(k)
        local d = math.abs(px - (s.x + s.w / 2))
        if d < bestD then best, bestD = k, d end
    end
    return best
end

-- The dragged item, following the mouse (drawn last, on top).
function luckrack.drawDragged()
    local d = luckrack.drag
    if d and d.moved and luck.held[d.from] then
        love.graphics.setColor(0, 0, 0, 0.4)
        love.graphics.rectangle("fill", d.x - 30, d.y - 26, 64, 64, 8, 8)
        luckart.picture(luck.held[d.from], d.x - 32, d.y - 32, 64)
    end
end

-- A gold glow round a selected slot, and a faint hint how to move it.
local function drawSelected(s)
    local pulse = 0.6 + 0.4 * math.sin(love.timer.getTime() * 5)
    love.graphics.setColor(1, 0.85, 0.2, pulse)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", s.x - 5, s.y - 5, s.w + 10, s.h + 10, 10, 10)
    love.graphics.setLineWidth(1)
end
luckrack.drawSelected = drawSelected


---------------------------------------------------------------------------
-- LAYOUT
---------------------------------------------------------------------------

local rect = util.rect

-- The whole rack: just right of the tray, the same height as it.
function luckrack.rect()
    local t = layout.tray()
    local w = luck.MAX_HELD * SLOT + (luck.MAX_HELD + 1) * GAP
    return rect(t.x + t.w + 24, t.y, w, t.h)
end

-- Slot k's picture.
function luckrack.slotRect(k)
    local r = luckrack.rect()
    return rect(r.x + GAP + (k - 1) * (SLOT + GAP), r.y + 20, SLOT, SLOT)
end

-- Slot k's SELL button, under its picture.
function luckrack.sellRect(k)
    local s = luckrack.slotRect(k)
    return rect(s.x - 4, s.y + s.h + 3, s.w + 8, SELL_H)
end


---------------------------------------------------------------------------
-- DRAWING
---------------------------------------------------------------------------

-- The rack and the items on it (drawn under the dice, so they roll over it).
function luckrack.draw()
    local r = luckrack.rect()
    -- A dark wooden plaque.
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", r.x + 3, r.y + 5, r.w, r.h, 10, 10)
    love.graphics.setColor(0.24, 0.13, 0.06, 0.95)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 10, 10)
    love.graphics.setColor(1, 0.82, 0.3, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 10, 10)
    love.graphics.setLineWidth(1)
    ui.text("LUCK  " .. #luck.held .. "/" .. luck.MAX_HELD, fonts.hint, r.x, r.y + 2, r.w, "center",
        { 1, 0.85, 0.3 })

    for k = 1, luck.MAX_HELD do
        local s = luckrack.slotRect(k)
        local id = luck.held[k]
        if id then
            local item = luck.get(id)
            local color = luck.rarityColor(item)
            local lifted = luckrack.drag and luckrack.drag.moved and luckrack.drag.from == k
            if not lifted then luckart.picture(id, s.x, s.y, s.w) end
            if luckrack.selected == k then drawSelected(s) end
            love.graphics.setColor(color)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", s.x - 2, s.y - 2, s.w + 4, s.h + 4, 8, 8)
            love.graphics.setLineWidth(1)
            luckart.sellButton(luckrack.sellRect(k), luck.sellPrice(item))
        else
            -- An empty slot: a dashed-looking dim box.
            love.graphics.setColor(1, 1, 1, 0.15)
            love.graphics.rectangle("line", s.x, s.y, s.w, s.h, 8, 8)
            ui.text("EMPTY", fonts.hint, s.x, s.y + s.h / 2 - 7, s.w, "center", { 1, 1, 1, 0.3 })
        end
    end

    if noteTime > 0 then
        ui.text(note, fonts.hint, r.x - 40, r.y - 20, r.w + 80, "center", { 1, 0.85, 0.3 }, true)
    elseif luckrack.selected and luck.held[luckrack.selected] then
        ui.text("LEFT / RIGHT to move it", fonts.hint, r.x - 40, r.y - 20, r.w + 80, "center",
            { 1, 0.85, 0.3 }, true)
    end
end

-- The tooltip for whichever item the mouse is over (drawn on top of everything).
function luckrack.drawTooltip()
    if luckrack.drag and luckrack.drag.moved then return end   -- not while dragging
    for k = 1, luck.MAX_HELD do
        local s = luckrack.slotRect(k)
        if luck.held[k] and ui.isHovered(s) then
            luckart.tooltip(luck.held[k], s.x - 40, s.y - 10)
        end
    end
end

-- Count down the note's time on screen.
function luckrack.update(dt)
    noteTime = math.max(0, noteTime - dt)
end


---------------------------------------------------------------------------
-- CLICKS
---------------------------------------------------------------------------

-- What a click at (px, py) is on: the number of the SELL button it hit,
-- true for anywhere else on the rack (so main.lua doesn't also treat it as
-- a click on the felt), or nil if it missed the rack.
function luckrack.click(px, py)
    for k = 1, luck.MAX_HELD do
        if luck.held[k] and layout.isInside(px, py, luckrack.sellRect(k)) then
            return k
        end
    end
    return layout.isInside(px, py, luckrack.rect()) or nil
end

-- Sell the item in slot k (game.lua calls this). Returns true if it sold.
function luckrack.sell(k)
    if luck.held[k] == nil then return false end
    local name = luck.get(luck.held[k]).name
    local coins = luck.sell(k)
    player.addCoins(coins)
    note, noteTime = "Sold " .. name .. "  +" .. coins .. " coins", 3
    return true
end

return luckrack
