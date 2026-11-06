-- crapstable.lua
-- DRAWS the craps table itself: the wooden rails along the top and left,
-- the rubber "pyramid" walls inside them, the green felt, the faded
-- Para-DICE logo, and the wooden dice tray.
--
-- The camera is tilted 15 degrees (see config.VIEW_TILT_DEGREES and
-- layout.lua): we look down from a little south of the table, so we can
-- see the inside face of the far (north) wall, a sliver of the west wall,
-- and the front face of the dice tray.
--
-- The wood and felt textures are made by code (no picture files):
-- we fill an ImageData pixel by pixel, then turn it into an Image once.
-- They're rebuilt only if the window size changes.
--
-- Drawing only - this never changes any game data.

local config = require("config")
local layout = require("layout")
local fonts  = require("fonts")

local crapstable = {}

-- The textures, and the window size they were made for.
local topRailImage, leftRailImage, feltTile, feltQuad, vignette
local builtForW, builtForH = 0, 0


---------------------------------------------------------------------------
-- MAKING THE TEXTURES
---------------------------------------------------------------------------

-- Keep a number between 0 and 1.
local function clamp01(v)
    return math.max(0, math.min(1, v))
end

-- A polished wooden rail, w x h pixels.
-- 'vertical' = true for the left rail (grain runs up and down).
--
-- How the wood is made, for every pixel:
--   along  = how far along the rail we are; across = how far across it.
--   love.math.noise gives smooth random "wobble", which bends straight
--   stripes into wavy wood grain. A sine curve across the rail makes the
--   middle brighter than the edges, so it looks rounded like a real rail.
local function makeWood(w, h, vertical)
    local data = love.image.newImageData(w, h)
    local thickness = vertical and w or h

    data:mapPixel(function(x, y)
        local along  = vertical and y or x
        local across = vertical and x or y
        local t = across / (thickness - 1)   -- 0 at the outer edge, 1 at the inner edge

        local wobble = love.math.noise(along * 0.003, across * 0.08)
        local grain  = (math.sin((across + wobble * 25) * 0.55) + 1) / 2
        local fine   = love.math.noise(along * 0.05, across * 0.5) * 0.15

        -- Rounded: dark at both edges, bright in the middle, plus a shine line.
        local shade = 0.55 + 0.6 * math.sin(math.pi * t)
        local shine = 0.10 * math.exp(-((t - 0.35) / 0.07) ^ 2)

        local light = (0.75 + 0.25 * grain + fine) * shade + shine
        return clamp01(0.42 * light), clamp01(0.23 * light), clamp01(0.11 * light), 1
    end)
    return love.graphics.newImage(data)
end

-- A small square of felt: green with tiny random specks, repeated
-- (tiled) across the whole table.
local function makeFeltTile()
    local size = 256
    local data = love.image.newImageData(size, size)
    data:mapPixel(function()
        local speck = 0.90 + love.math.random() * 0.14
        return 0.05 * speck, 0.36 * speck, 0.17 * speck, 1
    end)
    local image = love.graphics.newImage(data)
    image:setWrap("repeat", "repeat")   -- so it can tile
    return image
end

-- A soft dark edge for the felt: clear in the middle, darker near the edges.
-- It's tiny (64x64) and gets stretched, which makes it nice and smooth.
local function makeVignette()
    local size = 64
    local data = love.image.newImageData(size, size)
    data:mapPixel(function(x, y)
        local dx = (x / (size - 1)) * 2 - 1     -- -1 .. 1
        local dy = (y / (size - 1)) * 2 - 1
        local dist = math.sqrt(dx * dx + dy * dy) / math.sqrt(2)
        local alpha = clamp01((dist - 0.35) / 0.65) ^ 1.6 * 0.6
        return 0, 0, 0, alpha
    end)
    return love.graphics.newImage(data)
end

-- Build (or rebuild) everything for the current window size.
local function buildTextures()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    if W == builtForW and H == builtForH then
        return   -- already made for this size
    end
    builtForW, builtForH = W, H

    local top, left = layout.topRail(), layout.leftRail()
    topRailImage  = makeWood(top.w, top.h, false)
    leftRailImage = makeWood(left.w, left.h, true)

    feltTile = feltTile or makeFeltTile()
    local f = layout.felt()
    -- A Quad picks which part of an image to draw. Making it as big as the
    -- felt, with the tile set to "repeat", tiles the felt across the table.
    feltQuad = love.graphics.newQuad(0, 0, f.w, f.h, feltTile:getWidth(), feltTile:getHeight())

    vignette = vignette or makeVignette()
end


---------------------------------------------------------------------------
-- PIECES
---------------------------------------------------------------------------

local function drawFelt()
    local f = layout.felt()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(feltTile, feltQuad, f.x, f.y)

    -- Stretch the vignette over the felt.
    love.graphics.draw(vignette, f.x, f.y, 0, f.w / vignette:getWidth(), f.h / vignette:getHeight())

    -- The tall north wall casts a shadow onto the felt in front of it
    -- (a dark band that fades out, a little deeper than before because the
    -- wall now has height).
    for i = 0, 17 do
        love.graphics.setColor(0, 0, 0, 0.40 * (1 - i / 18))
        love.graphics.rectangle("fill", f.x, f.y + i, f.w, 1)
    end
end

-- One rubber pyramid on a wall, w wide and h tall: a box split into 4
-- triangles meeting at the tip. Each triangle gets its own shade, as if
-- lit from above, which makes the tip look like it sticks out.
local function drawPyramid(x, y, w, h)
    local cx, cy = x + w / 2, y + h / 2
    love.graphics.setColor(0.34, 0.33, 0.32)      -- upper face (most light)
    love.graphics.polygon("fill", x, y, x + w, y, cx, cy)
    love.graphics.setColor(0.21, 0.20, 0.20)      -- left face
    love.graphics.polygon("fill", x, y, cx, cy, x, y + h)
    love.graphics.setColor(0.14, 0.13, 0.13)      -- right face
    love.graphics.polygon("fill", x + w, y, x + w, y + h, cx, cy)
    love.graphics.setColor(0.07, 0.07, 0.07)      -- lower face (in shadow)
    love.graphics.polygon("fill", x, y + h, cx, cy, x + w, y + h)
end

-- The NORTH wall's inside face, seen almost head-on because of the camera
-- tilt: a band of rubber pyramids under the rail, like the back wall of a
-- real craps table that the dice bounce off.
local function drawNorthWall()
    local face = layout.northWallFace()
    local s = face.h   -- square pyramids, as tall as the visible face

    love.graphics.setColor(0.05, 0.05, 0.05)
    love.graphics.rectangle("fill", face.x, face.y, face.w, face.h)
    for x = face.x, face.x + face.w, s do
        drawPyramid(x, face.y, s, s)
    end

    -- A dark line where the wall meets the felt.
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", face.x, face.y + face.h - 1, face.w, 2)
end

-- The WEST wall's inside face, seen from the side: just a thin sliver that
-- gets wider toward the bottom of the screen (nearer to the viewer).
local function drawWestWall()
    local x, top, bottom, farW, nearW = layout.westWallFace()

    -- Width of the sliver at height y: blend from farW (top) to nearW (bottom).
    local function widthAt(y)
        local t = (y - top) / (bottom - top)
        return farW + (nearW - farW) * t
    end

    -- Dark rubber backing, as one long trapezoid.
    love.graphics.setColor(0.05, 0.05, 0.05)
    love.graphics.polygon("fill", x, top, x + farW, top, x + nearW, bottom, x, bottom)

    -- Pyramids down the sliver, squashed sideways to match its width.
    local step = 18
    for y = top, bottom, step do
        drawPyramid(x, y, widthAt(y), step)
    end

    -- The sliver casts a soft shadow onto the felt to its right.
    for i = 0, 9 do
        love.graphics.setColor(0, 0, 0, 0.28 * (1 - i / 10))
        love.graphics.line(x + farW + i, top, x + nearW + i, bottom)
    end
end

local function drawRails()
    local top, left = layout.topRail(), layout.leftRail()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(leftRailImage, left.x, left.y)
    love.graphics.draw(topRailImage, top.x, top.y)

    -- A thin dark line where the two rails meet, so the corner reads as a joint.
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.line(left.x, top.h, left.x + left.w, top.h)

    -- The front edge of the top rail's cap, rounding over toward us:
    -- a darker strip with a thin highlight just above it.
    love.graphics.setColor(0.18, 0.09, 0.04)
    love.graphics.rectangle("fill", left.x + left.w, top.h - 5, top.w - left.w, 5)
    love.graphics.setColor(1, 0.85, 0.6, 0.25)
    love.graphics.rectangle("fill", left.x + left.w, top.h - 7, top.w - left.w, 1)

    -- A dark edge between the banner and the left rail.
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", left.x, 0, 3, left.h)
end

-- "Para-DICE" printed on the felt in faded maroon, like worn table ink.
local function drawLogo()
    local cx, cy = layout.logoCenter()
    local text = "Para-DICE"
    -- Shrink the logo if it's wider than the space it sits in.
    local scale = math.min(1, layout.landingZone().w * 0.95 / fonts.logo:getWidth(text))
    local w = fonts.logo:getWidth(text) * scale
    local h = fonts.logo:getHeight() * scale

    love.graphics.setFont(fonts.logo)
    -- A faint, slightly offset copy first: ink that bled into the felt.
    love.graphics.setColor(0.40, 0.03, 0.10, 0.22)
    love.graphics.print(text, cx - w / 2 + 3, cy - h / 2 + 3, 0, scale, scale)
    -- The main letters, a little see-through so the felt shows through (faded).
    love.graphics.setColor(0.48, 0.05, 0.13, 0.72)
    love.graphics.print(text, cx - w / 2, cy - h / 2, 0, scale, scale)

    -- Two thin printed lines under the logo, like a table marking.
    love.graphics.setColor(0.55, 0.10, 0.14, 0.4)
    love.graphics.setLineWidth(2)
    love.graphics.line(cx - w / 2, cy + h / 2 + 4, cx + w / 2, cy + h / 2 + 4)
    love.graphics.line(cx - w / 2 + 30, cy + h / 2 + 10, cx + w / 2 - 30, cy + h / 2 + 10)
    love.graphics.setLineWidth(1)
end

-- The wooden tray in the bottom-left where the dice sit after a roll.
-- With the camera tilt we also see its FRONT face (the side facing us)
-- below it, and the inside of its BACK wall at the top of the hollow.
local function drawTray()
    local t = layout.tray()
    local front = 10   -- how tall the front face looks

    -- Shadow the tray casts on the felt.
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("fill", t.x - 4, t.y - 2, t.w + 16, t.h + 16 + front, 12, 12)

    -- Front face of the frame (darker wood, it's the side facing us).
    love.graphics.setColor(0.20, 0.11, 0.05)
    love.graphics.rectangle("fill", t.x - 8, t.y + t.h, t.w + 16, 8 + front, 0, 0)
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", t.x - 8, t.y + t.h + 8 + front - 2, t.w + 16, 2)

    -- Top of the wooden frame
    love.graphics.setColor(0.33, 0.19, 0.09)
    love.graphics.rectangle("fill", t.x - 8, t.y - 8, t.w + 16, t.h + 16, 10, 10)
    love.graphics.setColor(0.48, 0.28, 0.13)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", t.x - 7, t.y - 7, t.w + 14, t.h + 14, 9, 9)
    love.graphics.setLineWidth(1)

    -- The sunken felt inside.
    love.graphics.setColor(0.02, 0.16, 0.08)
    love.graphics.rectangle("fill", t.x, t.y, t.w, t.h, 6, 6)

    -- The inside of the tray's back wall, facing us: a wood band at the top.
    love.graphics.setColor(0.24, 0.13, 0.06)
    love.graphics.rectangle("fill", t.x, t.y, t.w, front, 6, 6)
    for i = 0, 7 do
        love.graphics.setColor(0, 0, 0, 0.35 * (1 - i / 8))   -- its shadow on the felt
        love.graphics.rectangle("fill", t.x + 2, t.y + front + i, t.w - 4, 1)
    end
end


---------------------------------------------------------------------------
-- THE TABLE (draw.lua calls this first - everything else goes on top)
---------------------------------------------------------------------------

function crapstable.draw()
    buildTextures()
    drawFelt()
    drawLogo()
    drawNorthWall()
    drawWestWall()
    drawRails()
    drawTray()
end

return crapstable
