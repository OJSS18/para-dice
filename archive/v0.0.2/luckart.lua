-- luckart.lua
-- Drawing bits for LUCK ITEMS that the shop and the play screen share:
--   * every item's picture (assets/luck/<image>.png), loaded once
--   * a small SELL button
--   * a tooltip box with an item's name, rarity and what it does
-- Drawing only - this never changes any game data.

local luck  = require("luck")
local fonts = require("fonts")
local ui    = require("ui")

local luckart = {}

local images = {}   -- images[itemId] = the picture


-- Call once from love.load (after the fonts exist).
function luckart.load()
    for _, id in ipairs(luck.ORDER) do
        local item = luck.get(id)
        local path = item.image and ("assets/luck/" .. item.image .. ".png")
        if path and love.filesystem.getInfo(path) then
            images[id] = love.graphics.newImage(path)
        end
    end
end

-- An item's picture, top-left at (x, y), 'size' pixels square.
-- Items without a picture get a plain coin with an L on it.
function luckart.picture(itemId, x, y, size)
    local image = images[itemId]
    if image then
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(image, x, y, 0, size / image:getWidth(), size / image:getHeight())
        return
    end
    local color = luck.rarityColor(luck.get(itemId))
    love.graphics.setColor(color)
    love.graphics.circle("fill", x + size / 2, y + size / 2, size * 0.45)
    ui.text("L", fonts.text, x, y + size / 2 - 12, size, "center", { 0, 0, 0 })
end

-- A small red "SELL 12" button inside rectangle r.
function luckart.sellButton(r, price)
    local hover = ui.isHovered(r)
    love.graphics.setColor(hover and { 0.95, 0.25, 0.25 } or { 0.75, 0.12, 0.14 })
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 6, 6)
    love.graphics.setColor(1, 0.85, 0.4, 0.9)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 6, 6)
    ui.text("SELL " .. price, fonts.hint, r.x, r.y + (r.h - fonts.hint:getHeight()) / 2 + 1,
        r.w, "center", { 1, 1, 1 })
end

-- A tooltip for an item, with its bottom-left corner near (x, y). It's
-- kept on screen.
function luckart.tooltip(itemId, x, y)
    local item = luck.get(itemId)
    local color = luck.rarityColor(item)
    local w = 280
    local _, lines = fonts.tiny:getWrap(item.about, w - 20)
    local h = 54 + #lines * fonts.tiny:getHeight() + 10

    local W = love.graphics.getWidth()
    x = math.max(8, math.min(W - w - 8, x))
    y = math.max(8, y - h)

    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", x + 3, y + 4, w, h, 10, 10)
    love.graphics.setColor(0.08, 0.04, 0.07, 0.96)
    love.graphics.rectangle("fill", x, y, w, h, 10, 10)
    love.graphics.setColor(color)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h, 10, 10)
    love.graphics.setLineWidth(1)

    ui.text(luck.RARITIES[item.rarity].label, fonts.hint, x + 10, y + 8, w - 20, "left", color)
    ui.text(item.name, fonts.small, x + 10, y + 24, w - 20, "left", { 1, 1, 1 })
    love.graphics.setFont(fonts.tiny)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.printf(item.about, x + 10, y + 50, w - 20, "left")
end

return luckart
