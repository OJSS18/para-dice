-- settingsmenu.lua
-- The SETTINGS tab (top-right of every screen) and the settings panel it opens.
-- Right now the panel has one control: a MUSIC VOLUME slider.
--
-- Like shop.lua, this file holds the LAYOUT (where things are), the
-- DRAWING, and the CLICKS for the panel. The settings themselves (and
-- saving them) live in settings.lua.

local settings = require("settings")
local fonts    = require("fonts")
local ui       = require("ui")

local settingsmenu = {}

-- true while the player is dragging the volume knob with the mouse.
local dragging = false

local function rect(x, y, w, h)
    return { x = x, y = y, w = w, h = h }
end

local function isInside(px, py, r)
    return px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end


---------------------------------------------------------------------------
-- LAYOUT
---------------------------------------------------------------------------

-- The little tab hanging from the top-right corner of the screen.
function settingsmenu.tabRect()
    return rect(love.graphics.getWidth() - 172, 0, 158, 38)
end

-- The panel in the middle of the screen.
local function panelRect()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    return rect((W - 560) / 2, (H - 320) / 2, 560, 320)
end

-- The slider's track (the line the knob slides along).
local function trackRect()
    local p = panelRect()
    return rect(p.x + 110, p.y + 150, p.w - 220, 14)
end

local function minusRect()
    local t = trackRect()
    return rect(t.x - 74, t.y - 18, 50, 50)
end

local function plusRect()
    local t = trackRect()
    return rect(t.x + t.w + 24, t.y - 18, 50, 50)
end

local function doneRect()
    local p = panelRect()
    return rect(p.x + (p.w - 220) / 2, p.y + p.h - 84, 220, 56)
end


---------------------------------------------------------------------------
-- DRAWING
---------------------------------------------------------------------------

-- A simple gear icon: a circle with 8 teeth and a hole in the middle.
local function drawGear(cx, cy, r, color)
    love.graphics.setColor(color)
    for n = 0, 7 do
        local a = n * math.pi / 4
        love.graphics.push()
        love.graphics.translate(cx, cy)
        love.graphics.rotate(a)
        love.graphics.rectangle("fill", -r * 0.22, -r * 1.15, r * 0.44, r * 0.5)
        love.graphics.pop()
    end
    love.graphics.circle("fill", cx, cy, r * 0.8)
    love.graphics.setColor(0.45, 0.04, 0.07)
    love.graphics.circle("fill", cx, cy, r * 0.32)
end

-- The SETTINGS tab. Drawn on every screen.
function settingsmenu.drawTab()
    local r = settingsmenu.tabRect()
    local hover = ui.isHovered(r)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", r.x + 3, r.y + 4, r.w, r.h, 0, 0)
    if hover then
        love.graphics.setColor(0.75, 0.08, 0.12)
    else
        love.graphics.setColor(0.55, 0.05, 0.08)
    end
    love.graphics.rectangle("fill", r.x, r.y - 10, r.w, r.h + 10, 10, 10)
    love.graphics.setColor(1, 0.82, 0.3)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", r.x, r.y - 10, r.w, r.h + 10, 10, 10)
    love.graphics.setLineWidth(1)
    drawGear(r.x + 22, r.y + r.h / 2, 9, { 1, 0.85, 0.35 })
    ui.text("SETTINGS", fonts.hint, r.x + 36, r.y + 12, r.w - 44, "center", { 1, 0.95, 0.85 })
end

-- The settings panel, over a dimmed screen.
function settingsmenu.draw()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, W, H)

    local p = panelRect()
    ui.vegasWindow(p, "SETTINGS")
    ui.bulbBorder({ x = p.x - 14, y = p.y - 14, w = p.w + 28, h = p.h + 28 }, 28, 5, 6)

    -- MUSIC VOLUME label and the percentage
    local volume = settings.values.musicVolume
    ui.text("MUSIC VOLUME", fonts.heading, p.x, p.y + 52, p.w, "center", { 1, 0.85, 0.2 })
    ui.text(math.floor(volume * 100 + 0.5) .. "%", fonts.scoreBig, p.x, p.y + 76, p.w, "center",
        { 1, 1, 1 }, true)

    -- The slider: a dark track, a gold "filled" part up to the knob, then the knob.
    local t = trackRect()
    love.graphics.setColor(0.15, 0.08, 0.1)
    love.graphics.rectangle("fill", t.x, t.y, t.w, t.h, 7, 7)
    love.graphics.setColor(1, 0.75, 0.15)
    love.graphics.rectangle("fill", t.x, t.y, t.w * volume, t.h, 7, 7)
    love.graphics.setColor(1, 0.85, 0.35)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", t.x, t.y, t.w, t.h, 7, 7)
    love.graphics.setLineWidth(1)

    local kx, ky = t.x + t.w * volume, t.y + t.h / 2
    ui.bulb(kx, ky, 13, 1)   -- the knob is a big glowing bulb

    -- - and + buttons, and DONE
    ui.glossyButton(minusRect(), "-", { 0.12, 0.38, 0.95 }, volume > 0)
    ui.glossyButton(plusRect(), "+", { 0.85, 0.10, 0.12 }, volume < 1)
    ui.glossyButton(doneRect(), "DONE", { 0.10, 0.65, 0.25 }, true)
end


---------------------------------------------------------------------------
-- MOUSE
---------------------------------------------------------------------------

-- Is (x, y) on the SETTINGS tab?
function settingsmenu.isOnTab(x, y)
    return isInside(x, y, settingsmenu.tabRect())
end

-- Set the volume from where the mouse is along the slider.
local function setFromMouse(x)
    local t = trackRect()
    settings.setMusicVolume((x - t.x) / t.w)
end

-- A click while the panel is open. Returns "close" when the panel should close.
function settingsmenu.mousepressed(x, y)
    local t = trackRect()
    -- The slider's clickable area is a bit taller than the thin track.
    if isInside(x, y, rect(t.x - 14, t.y - 16, t.w + 28, t.h + 32)) then
        dragging = true
        setFromMouse(x)
    elseif isInside(x, y, minusRect()) then
        settings.changeMusicVolume(-0.05)
    elseif isInside(x, y, plusRect()) then
        settings.changeMusicVolume(0.05)
    elseif isInside(x, y, doneRect()) or not isInside(x, y, panelRect()) then
        return "close"   -- DONE, or a click outside the panel
    end
    return nil
end

-- The mouse moved: if the knob is being dragged, follow it.
function settingsmenu.mousemoved(x)
    if dragging then
        setFromMouse(x)
    end
end

-- The mouse button was let go: stop dragging.
function settingsmenu.mousereleased()
    dragging = false
end

return settingsmenu
