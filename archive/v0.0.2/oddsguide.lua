-- oddsguide.lua
-- The DICE ODDS panel: press O (or tap the ODDS tab) to see, for each of
-- your 5 dice, how likely every face is to come up.
--
-- The numbers come straight from dicetypes.lua (each die type's weights),
-- so they're always the real odds the game uses.
-- Drawing only - nothing in here changes game data.

local config    = require("config")
local dicetypes = require("dicetypes")
local player    = require("player")
local fonts     = require("fonts")
local ui        = require("ui")
local draw      = require("draw")   -- for draw.dieImage

local oddsguide = {}

local GOLD  = { 1, 0.85, 0.25 }
local CREAM = { 1, 0.95, 0.88 }
local DIM   = { 1, 0.95, 0.88, 0.55 }


---------------------------------------------------------------------------
-- THE ODDS TAB (top edge, left of CONTROLS) - for phones with no O key
---------------------------------------------------------------------------

function oddsguide.tabRect()
    return { x = love.graphics.getWidth() - 466, y = 0, w = 124, h = 38 }
end

function oddsguide.isOnTab(x, y)
    local r = oddsguide.tabRect()
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function oddsguide.drawTab()
    local r = oddsguide.tabRect()
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", r.x + 3, r.y + 4, r.w, r.h)
    if ui.isHovered(r) then
        love.graphics.setColor(0.75, 0.08, 0.12)
    else
        love.graphics.setColor(0.55, 0.05, 0.08)
    end
    love.graphics.rectangle("fill", r.x, r.y - 10, r.w, r.h + 10, 10, 10)
    love.graphics.setColor(1, 0.82, 0.3)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", r.x, r.y - 10, r.w, r.h + 10, 10, 10)
    love.graphics.setLineWidth(1)
    -- A tiny die icon
    love.graphics.setColor(1, 0.85, 0.35)
    love.graphics.rectangle("fill", r.x + 12, r.y + 9, 20, 20, 4, 4)
    love.graphics.setColor(0.45, 0.04, 0.07)
    love.graphics.circle("fill", r.x + 17, r.y + 14, 2.2)
    love.graphics.circle("fill", r.x + 22, r.y + 19, 2.2)
    love.graphics.circle("fill", r.x + 27, r.y + 24, 2.2)
    ui.text("ODDS", fonts.hint, r.x + 36, r.y + 12, r.w - 44, "center", { 1, 0.95, 0.85 })
end


---------------------------------------------------------------------------
-- THE PANEL
---------------------------------------------------------------------------

-- One row: die picture and name on the left, then a bar for each face.
local function drawDieRow(i, x, y, w, h)
    local typeId = player.loadout[i]
    local dieType = dicetypes.get(typeId)

    -- Faint stripe behind every other row, to make rows easy to follow.
    if i % 2 == 0 then
        love.graphics.setColor(1, 1, 1, 0.04)
        love.graphics.rectangle("fill", x, y, w, h, 8, 8)
    end

    -- Picture and name
    local size = h - 24
    draw.dieImage(typeId, i, x + 10, y + 12, size)
    ui.text("DIE " .. i, fonts.hint, x + size + 22, y + 14, 150, "left", DIM)
    ui.text(dieType.name, fonts.small, x + size + 22, y + 32, 160, "left", CREAM)

    -- Six bars, one per face. The tallest possible bar means 50%.
    local barsX = x + size + 200
    local barsW = w - (barsX - x) - 14
    local slotW = barsW / 6
    local barMaxH = h - 44
    local baseY = y + h - 22
    local fair = 100 / 6
    for face = 1, 6 do
        local pct = dicetypes.percent(dieType.weights, face)
        local bx = barsX + (face - 1) * slotW + slotW * 0.2
        local bw = slotW * 0.6
        local bh = math.max(2, barMaxH * math.min(1, pct / 50))

        -- Gold if this face comes up more than a fair die's 1-in-6,
        -- blue if less, grey if about the same.
        if pct > fair + 1 then
            love.graphics.setColor(1, 0.78, 0.2)
        elseif pct < fair - 1 then
            love.graphics.setColor(0.35, 0.6, 1)
        else
            love.graphics.setColor(0.75, 0.75, 0.78)
        end
        love.graphics.rectangle("fill", bx, baseY - bh, bw, bh, 3, 3)

        ui.text(pct .. "%", fonts.tiny, bx - 10, baseY - bh - 17, bw + 20, "center", CREAM)
        ui.text(tostring(face), fonts.hint, bx - 10, baseY + 4, bw + 20, "center", DIM)
    end
end

-- Draw the whole panel over whatever is on screen.
function oddsguide.draw()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0, 0, 0, 0.78)
    love.graphics.rectangle("fill", 0, 0, W, H)

    local cardW = math.min(860, W - 80)
    local cardH = math.min(640, H - 40)
    local x, y = (W - cardW) / 2, (H - cardH) / 2
    ui.vegasWindow({ x = x, y = y, w = cardW, h = cardH }, "DICE ODDS")

    ui.text("How likely each face is on each of your dice", fonts.small, x, y + 26, cardW, "center", DIM)

    local top = y + 60
    local rowH = (cardH - 110) / config.NUM_DICE
    for i = 1, config.NUM_DICE do
        drawDieRow(i, x + 20, top + (i - 1) * rowH, cardW - 40, rowH)
    end

    -- A small key at the bottom
    local keyY = y + cardH - 40
    love.graphics.setColor(1, 0.78, 0.2)
    love.graphics.rectangle("fill", x + 40, keyY + 4, 14, 14, 3, 3)
    ui.text("more likely than a fair die", fonts.tiny, x + 60, keyY + 2, 220, "left", CREAM)
    love.graphics.setColor(0.35, 0.6, 1)
    love.graphics.rectangle("fill", x + 300, keyY + 4, 14, 14, 3, 3)
    ui.text("less likely", fonts.tiny, x + 320, keyY + 2, 120, "left", CREAM)
    love.graphics.setColor(0.75, 0.75, 0.78)
    love.graphics.rectangle("fill", x + 440, keyY + 4, 14, 14, 3, 3)
    ui.text("fair (1 in 6)", fonts.tiny, x + 460, keyY + 2, 140, "left", CREAM)
end

return oddsguide
