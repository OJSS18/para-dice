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

local luckrack = {}

local SLOT   = 60   -- each item picture
local GAP    = 14
local SELL_H = 22

-- The message under the rack ("Sold Sky High for +12 coins"), and how
-- long it has left on screen.
local note, noteTime = "", 0


---------------------------------------------------------------------------
-- LAYOUT
---------------------------------------------------------------------------

local function rect(x, y, w, h)
    return { x = x, y = y, w = w, h = h }
end

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
            luckart.picture(id, s.x, s.y, s.w)
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
    end
end

-- The tooltip for whichever item the mouse is over (drawn on top of everything).
function luckrack.drawTooltip()
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

-- Handle a click at (px, py). Returns true if it was on the rack (so
-- main.lua doesn't also treat it as a click on the felt).
function luckrack.click(px, py)
    for k = 1, luck.MAX_HELD do
        if luck.held[k] and layout.isInside(px, py, luckrack.sellRect(k)) then
            local name = luck.get(luck.held[k]).name
            local coins = luck.sell(k)
            player.addCoins(coins)
            note, noteTime = "Sold " .. name .. "  +" .. coins .. " coins", 3
            return true
        end
    end
    return layout.isInside(px, py, luckrack.rect())
end

return luckrack
