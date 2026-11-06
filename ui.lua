-- ui.lua
-- Little drawing helpers that make things POP, shared by the banner, the
-- shop and the overlays:
--   ui.text(...)         - text with a drop shadow (and optional glow)
--   ui.glossyButton(...) - a shiny, candy-like button
--   ui.tab(...)          - a tab hanging from the top edge (SETTINGS, CONTROLS, ODDS)
--   ui.bulb / ui.bulbBorder / ui.vegasWindow - Vegas light bulbs and windows
-- Drawing only - nothing here changes game data.

local fonts = require("fonts")
local util  = require("util")

local ui = {}

-- true once the player has touched the screen (phone / tablet). Hints then
-- talk about tapping instead of keys. main.lua sets this.
ui.touchMode = false

-- The "how to see the controls" hint, worded for keyboard or touch.
function ui.controlsHint()
    if ui.touchMode then
        return "TAP CONTROLS (TOP RIGHT) FOR HELP"
    end
    return "PRESS C FOR A LIST OF CONTROLS"
end

-- Blend between two colours. t = 0 gives a, t = 1 gives b.
local function mix(a, b, t)
    return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end

-- Is the mouse over rectangle r? (Reading the mouse is fine in drawing code.)
local function hovered(r)
    local mx, my = love.mouse.getPosition()
    return util.isInside(mx, my, r)
end
ui.isHovered = hovered


-- Text with a dark drop shadow underneath, so it stands out on anything.
--   text, font  - what to write and in which font
--   x, y, w     - where; w is the width to align within
--   align       - "left", "center" or "right"
--   color       - {r, g, b} or {r, g, b, a}
--   glow        - optional: true adds a soft halo in the text's colour
-- If the text is wider than w it's shrunk to fit (on one line).
function ui.text(text, font, x, y, w, align, color, glow)
    love.graphics.setFont(font)
    local textW = font:getWidth(text)
    local scale = math.min(1, w / math.max(1, textW))
    local drawW = textW * scale

    local tx = x
    if align == "center" then
        tx = x + (w - drawW) / 2
    elseif align == "right" then
        tx = x + w - drawW
    end

    if glow then
        love.graphics.setColor(color[1], color[2], color[3], 0.18)
        for _, o in ipairs({ {-2, 0}, {2, 0}, {0, -2}, {0, 2} }) do
            love.graphics.print(text, tx + o[1], y + o[2], 0, scale, scale)
        end
    end

    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.print(text, tx + 2, y + 3, 0, scale, scale)
    love.graphics.setColor(color)
    love.graphics.print(text, tx, y, 0, scale, scale)
end


-- A glossy button, like a shiny candy:
--   * a shadow underneath so it seems to float,
--   * a top-to-bottom gradient (light at the top, deep at the bottom),
--   * a white "gloss" shine across the top half,
--   * a bright rim, and bold white text with a shadow.
-- r is the rectangle, label the text, base the main colour {r, g, b}.
-- When 'enabled' is false it's drawn dull and grey-ish.
function ui.glossyButton(r, label, base, enabled)
    local radius = 12
    local hover = enabled and hovered(r)

    -- Disabled buttons lose most of their colour; hovered ones brighten.
    local color = base
    if not enabled then
        color = mix(base, { 0.25, 0.25, 0.27 }, 0.75)
    elseif hover then
        color = mix(base, { 1, 1, 1 }, 0.15)
    end
    local top    = mix(color, { 1, 1, 1 }, 0.35)
    local bottom = mix(color, { 0, 0, 0 }, 0.45)

    -- Glow behind a hovered button.
    if hover then
        love.graphics.setColor(color[1], color[2], color[3], 0.35)
        love.graphics.rectangle("fill", r.x - 5, r.y - 5, r.w + 10, r.h + 10, radius + 4, radius + 4)
    end

    -- Shadow underneath.
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", r.x + 2, r.y + 5, r.w, r.h, radius, radius)

    -- A STENCIL is a cut-out: we draw the button's rounded shape into it,
    -- then everything drawn while the stencil test is on only shows up
    -- inside that shape. That keeps the gradient stripes inside the
    -- rounded corners.
    love.graphics.stencil(function()
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, radius, radius)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)

    -- Gradient: one thin stripe per row of pixels, from 'top' to 'bottom'.
    for i = 0, r.h - 1, 2 do
        love.graphics.setColor(mix(top, bottom, i / r.h))
        love.graphics.rectangle("fill", r.x, r.y + i, r.w, 2)
    end

    -- Gloss: a white shine over the top half, fading out downwards.
    local shineH = r.h * 0.48
    for i = 0, shineH, 2 do
        love.graphics.setColor(1, 1, 1, 0.38 * (1 - i / shineH))
        love.graphics.rectangle("fill", r.x + 4, r.y + 3 + i, r.w - 8, 2)
    end

    love.graphics.setStencilTest()   -- stencil off again

    -- Rim: a dark edge, then a thin bright line just inside the top.
    love.graphics.setLineWidth(2)
    love.graphics.setColor(mix(color, { 0, 0, 0 }, 0.6))
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, radius, radius)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, enabled and 0.5 or 0.15)
    love.graphics.line(r.x + radius, r.y + 2, r.x + r.w - radius, r.y + 2)

    -- Label
    local textColor = enabled and { 1, 1, 1 } or { 0.65, 0.65, 0.68 }
    local textY = r.y + (r.h - fonts.button:getHeight()) / 2 + 2
    ui.text(label, fonts.button, r.x + 10, textY, r.w - 20, "center", textColor)
end

-- A red tab hanging from the top edge of the screen, with a gold rim and
-- its label. The file that owns the tab draws its little icon on the left.
function ui.tab(r, label)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", r.x + 3, r.y + 4, r.w, r.h)
    if hovered(r) then
        love.graphics.setColor(0.75, 0.08, 0.12)
    else
        love.graphics.setColor(0.55, 0.05, 0.08)
    end
    love.graphics.rectangle("fill", r.x, r.y - 10, r.w, r.h + 10, 10, 10)
    love.graphics.setColor(1, 0.82, 0.3)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", r.x, r.y - 10, r.w, r.h + 10, 10, 10)
    love.graphics.setLineWidth(1)
    ui.text(label, fonts.hint, r.x + 36, r.y + 12, r.w - 44, "center", { 1, 0.95, 0.85 })
end

-- One marquee light bulb facing us, centred on (x, y).
-- 'brightness' 0 = off (dark glass), up to 1 = fully on.
function ui.bulb(x, y, radius, brightness)
    -- Metal socket ring
    love.graphics.setColor(0.45, 0.33, 0.12)
    love.graphics.circle("fill", x, y, radius + 2)
    if brightness > 0 then
        -- Light spilling out around it
        love.graphics.setColor(1, 0.8, 0.4, 0.20 * brightness)
        love.graphics.circle("fill", x, y, radius * 3)
        love.graphics.setColor(1, 0.85, 0.5, 0.35 * brightness)
        love.graphics.circle("fill", x, y, radius * 1.8)
        love.graphics.setColor(1, 0.78 + 0.18 * brightness, 0.45 + 0.4 * brightness)
    else
        love.graphics.setColor(0.32, 0.30, 0.28)
    end
    love.graphics.circle("fill", x, y, radius)
    -- Shine
    love.graphics.setColor(1, 1, 1, brightness > 0 and 0.9 or 0.3)
    love.graphics.circle("fill", x - radius * 0.35, y - radius * 0.35, radius * 0.32)
end

-- A row of bulbs all the way round rectangle r, chasing like a marquee.
--   spacing - distance between bulbs
--   speed   - how fast the bright ones move round (steps per second)
function ui.bulbBorder(r, spacing, radius, speed)
    -- Work out positions by walking round the four sides.
    local positions = {}
    local function side(x1, y1, x2, y2)
        local length = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
        local count = math.max(1, math.floor(length / spacing + 0.5))
        for n = 0, count - 1 do
            local p = n / count
            table.insert(positions, { x1 + (x2 - x1) * p, y1 + (y2 - y1) * p })
        end
    end
    side(r.x, r.y, r.x + r.w, r.y)
    side(r.x + r.w, r.y, r.x + r.w, r.y + r.h)
    side(r.x + r.w, r.y + r.h, r.x, r.y + r.h)
    side(r.x, r.y + r.h, r.x, r.y)

    local step = math.floor(love.timer.getTime() * speed)
    for n, p in ipairs(positions) do
        local brightness = ((n + step) % 3 == 0) and 1 or 0.55
        ui.bulb(p[1], p[2], radius, brightness)
    end
end

-- A Vegas-style window: dark glass panel, a double gold frame with
-- diamond studs at the corners, and a red title plate across the top.
function ui.vegasWindow(r, title)
    -- Shadow and dark glass
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", r.x + 4, r.y + 6, r.w, r.h, 14, 14)
    love.graphics.setColor(0.07, 0.03, 0.06, 0.88)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 14, 14)

    -- Double gold frame
    love.graphics.setLineWidth(5)
    love.graphics.setColor(0.55, 0.38, 0.10)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 14, 14)
    love.graphics.setLineWidth(2)
    love.graphics.setColor(1, 0.82, 0.30)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 14, 14)
    love.graphics.setColor(1, 0.82, 0.30, 0.45)
    love.graphics.rectangle("line", r.x + 6, r.y + 6, r.w - 12, r.h - 12, 10, 10)
    love.graphics.setLineWidth(1)

    -- Diamond studs in the corners
    for _, c in ipairs({ { r.x, r.y }, { r.x + r.w, r.y }, { r.x, r.y + r.h }, { r.x + r.w, r.y + r.h } }) do
        local cx, cy, s = c[1], c[2], 7
        love.graphics.setColor(1, 0.85, 0.35)
        love.graphics.polygon("fill", cx, cy - s, cx + s, cy, cx, cy + s, cx - s, cy)
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.polygon("fill", cx, cy - s, cx + s * 0.4, cy - s * 0.2, cx, cy)
    end

    -- Red title plate, centred on the top edge
    if title then
        local plateW = fonts.heading:getWidth(title) + 40
        local px, py = r.x + (r.w - plateW) / 2, r.y - 14
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", px + 2, py + 3, plateW, 30, 8, 8)
        love.graphics.setColor(0.70, 0.08, 0.10)
        love.graphics.rectangle("fill", px, py, plateW, 30, 8, 8)
        love.graphics.setColor(1, 0.82, 0.30)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", px, py, plateW, 30, 8, 8)
        love.graphics.setLineWidth(1)
        ui.text(title, fonts.heading, px, py + 6, plateW, "center", { 1, 0.95, 0.8 })
    end
end

return ui
