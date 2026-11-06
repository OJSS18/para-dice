-- layout.lua
-- WHERE everything sits on the play screen. Nothing here draws.
--
--   +---------+------------------------------------------+
--   |         | wood rail (top)                          |
--   |         |  | north wall's inside face (rubber)     |
--   | BANNER  +--+---------------------------------------+
--   | (info,  |  |  5 | 6 | 7 | ...  POINTS  ... | 17    | <- bulbs around
--   | buttons)|w | 18 |19 |20 | ...              | 30    |    every box
--   |         |o |                                       |
--   |         |o |   Para-DICE logo           MONEY      |
--   |         |d |   (dice land here)         MAKERS     |
--   |         |  |                            [][]       |
--   |         |  |  [dice tray]               [][] [][]  |
--   +---------+--+---------------------------------------+
--
-- The rail runs along the top and down the left side all the way to the
-- bottom of the screen. There is no rail along the bottom or right.
--
-- Drawing files (crapstable, scoreboard, banner, draw) AND clicking
-- (main.lua) all ask this file for positions, so they always agree.
-- Everything is worked out from the window size, so it fits any screen.

local config = require("config")
local util   = require("util")

local layout = {}

local rect = util.rect
layout.isInside = util.isInside   -- is the point (px, py) inside rectangle r?


---------------------------------------------------------------------------
-- THE BIG PIECES
---------------------------------------------------------------------------

-- The info banner down the left side.
function layout.banner()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local w = W * config.BANNER_FRACTION
    w = util.clamp(w, config.BANNER_MIN_W, config.BANNER_MAX_W)
    return rect(0, 0, math.floor(w), H)
end

-- THE CAMERA TILT
-- The viewer stands south of the table, looking down and tilted
-- config.VIEW_TILT_DEGREES (30) toward the north. Two things change because of that:
--   * Flat things that run north-south look a bit shorter: x cos(tilt).
--   * Tall things lean "up" the screen. A wall of height h shows its
--     inside face as a band h x sin(tilt) tall. For the NORTH wall that
--     face points right at us, so we see it. The west wall's face points
--     sideways, so we only see a thin sliver of it, wider nearer to us.
local function tilt()
    return math.rad(config.VIEW_TILT_DEGREES)   -- degrees -> radians
end
layout.tiltRadians = tilt   -- other files (the bulbs) need it too

-- How tall the north wall's inside face looks on screen.
function layout.wallFaceHeight()
    return math.floor(config.WALL_HEIGHT * math.sin(tilt()) + 0.5)
end

-- How thick the top rail's cap looks (slightly squashed by the tilt).
local function topRailHeight()
    return math.floor(config.RAIL_SIZE * math.cos(tilt()) + 0.5)
end

-- The wooden rails. The left one runs the full height of the screen.
function layout.leftRail()
    local b = layout.banner()
    return rect(b.w, 0, config.RAIL_SIZE, love.graphics.getHeight())
end

function layout.topRail()
    local b = layout.banner()
    return rect(b.w, 0, love.graphics.getWidth() - b.w, topRailHeight())
end

-- The inside face of the north wall: the band we can see because of the tilt.
function layout.northWallFace()
    local b = layout.banner()
    local x = b.w + config.RAIL_SIZE
    return rect(x, topRailHeight(), love.graphics.getWidth() - x, layout.wallFaceHeight())
end

-- The thin sliver of the west wall's inside face. It's a trapezoid: thin at
-- the far (top) end and wider at the near (bottom) end, because nearer
-- things look bigger. Returns the left x, the top and bottom y, and the
-- sliver's width at the top and at the bottom.
function layout.westWallFace()
    local b = layout.banner()
    local x = b.w + config.RAIL_SIZE
    local top = topRailHeight() + layout.wallFaceHeight()
    local nearW = math.floor(layout.wallFaceHeight() * 0.6)
    return x, top, love.graphics.getHeight(), 3, nearW
end

-- The felt: everything inside the walls, out to the right and bottom edges.
-- (The west sliver is drawn over its left edge.)
function layout.felt()
    local b = layout.banner()
    local x = b.w + config.RAIL_SIZE
    local y = topRailHeight() + layout.wallFaceHeight()
    return rect(x, y, love.graphics.getWidth() - x, love.graphics.getHeight() - y)
end


---------------------------------------------------------------------------
-- BETTING BOXES
---------------------------------------------------------------------------

-- Every box has a "lane" around it where its light bulbs sit. Lanes are
-- shared: the lane between 5 and 6 holds the bulbs for both boxes'
-- touching sides. So a block of boxes looks like this, with bulbs on
-- every line:
--
--      o---o---o---o
--      | 5 | 6 | 7 |
--      o---o---o---o
--      |18 |19 |20 |
--      o---o---o---o
--
-- layout.bulbFrame(box) gives the rectangle running down the middle of the
-- lanes around one box - the line its bulbs sit on.
function layout.bulbFrame(box)
    local half = config.BULB_LANE / 2
    return rect(box.x - half, box.y - half, box.w + 2 * half, box.h + 2 * half)
end

-- How many POINTS boxes there are: one per possible sum, 5 to 30.
layout.POINTS_COUNT = 26

-- POINTS: like the "place bet" numbers on a craps table, in two rows of
-- 13: sums 5-17 on top and 18-30 underneath, with a bulb lane around
-- every box. The whole block is centred across the top of the felt.
-- Returns the block's rectangle, plus each box's width and height.
function layout.placeGrid()
    local f = layout.felt()
    local lane = config.BULB_LANE
    local perRow = config.PLACE_PER_ROW
    local available = f.w - 2 * config.TABLE_MARGIN - 20 - (perRow + 1) * lane
    local boxW = math.min(config.PLACE_BOX_MAX_W, math.floor(available / perRow))
    local boxH = config.PLACE_NUMBER_H + config.PLACE_STRIP_H
    local w = perRow * boxW + (perRow + 1) * lane
    local h = 2 * boxH + 3 * lane
    return rect(f.x + 10 + (f.w - 10 - w) / 2, f.y + config.TABLE_MARGIN, w, h), boxW, boxH
end

-- The strip just under the POINTS block where this roll's score is spelled
-- out: "SCORING 60 x 1.65 (marker x1.5, keep x1.1) = 99".
layout.SCORE_LINE_H = 30

function layout.scoreLine()
    local grid = layout.placeGrid()
    return rect(grid.x, grid.y + grid.h + 8, grid.w, layout.SCORE_LINE_H)
end

-- POINTS box number k (1-26), in order: box 1 is sum 5, box 26 is sum 30.
function layout.placeBox(k)
    local grid, boxW, boxH = layout.placeGrid()
    local lane = config.BULB_LANE
    local row = math.floor((k - 1) / config.PLACE_PER_ROW)   -- 0 or 1
    local col = (k - 1) % config.PLACE_PER_ROW               -- 0 .. 12
    return rect(grid.x + lane + col * (boxW + lane), grid.y + lane + row * (boxH + lane), boxW, boxH)
end

-- COINS: the Money Makers, in a panel on the right like a craps table's
-- proposition (horn / C&E) bets: a red title, then 2 columns x 3 rows of
-- cells, each with its own bulb lane.
function layout.propPanel()
    local f = layout.felt()
    local lane = config.BULB_LANE
    local w = config.PROP_PANEL_W
    local h = config.PROP_HEADER_H + 3 * config.PROP_CELL_H + 4 * lane

    -- Centre it top-to-bottom in the space under the POINTS block.
    local grid = layout.placeGrid()
    local top = grid.y + grid.h + layout.SCORE_LINE_H + 24
    local bottom = love.graphics.getHeight() - config.TABLE_MARGIN
    local y = math.max(top, top + (bottom - top - h) / 2)
    local x = f.x + f.w - config.TABLE_MARGIN - w
    return rect(x, y, w, h)
end

-- Cell k (1-6) inside the panel.
function layout.propCell(k)
    local p = layout.propPanel()
    local lane = config.BULB_LANE
    local cellW = (p.w - 3 * lane) / 2
    local col = (k - 1) % 2
    local row = math.floor((k - 1) / 2)
    return rect(p.x + lane + col * (cellW + lane),
        p.y + config.PROP_HEADER_H + lane + row * (config.PROP_CELL_H + lane),
        cellW, config.PROP_CELL_H)
end


---------------------------------------------------------------------------
-- THE DICE TRAY (bottom-left of the felt)
---------------------------------------------------------------------------

local TRAY_NUMBER_SPACE = 22   -- room under the dice for the HELD labels

function layout.tray()
    local f = layout.felt()
    local n = config.NUM_DICE
    local w = 2 * config.TRAY_PADDING + n * config.TRAY_DIE_SIZE + (n - 1) * config.TRAY_GAP
    local h = 2 * config.TRAY_PADDING + config.TRAY_DIE_SIZE + TRAY_NUMBER_SPACE
    local x = f.x + config.TABLE_MARGIN + 10   -- a little extra to clear the west wall sliver
    local y = f.y + f.h - config.TABLE_MARGIN - 10 - h   -- extra room for the tray's front face
    return rect(x, y, w, h)
end

-- Where die i sits in the tray (a square TRAY_DIE_SIZE across).
function layout.traySlot(i)
    local t = layout.tray()
    local x = t.x + config.TRAY_PADDING + (i - 1) * (config.TRAY_DIE_SIZE + config.TRAY_GAP)
    local y = t.y + config.TRAY_PADDING
    return rect(x, y, config.TRAY_DIE_SIZE, config.TRAY_DIE_SIZE)
end

-- The centre point of tray slot i (the animation needs centres).
function layout.traySlotCenter(i)
    local s = layout.traySlot(i)
    return s.x + s.w / 2, s.y + s.h / 2
end

-- Which tray die (1-5) is at (px, py)? nil if none.
function layout.getDieAt(px, py)
    for i = 1, config.NUM_DICE do
        if layout.isInside(px, py, layout.traySlot(i)) then
            return i
        end
    end
    return nil
end


---------------------------------------------------------------------------
-- WHERE DICE LAND, AND THE LOGO
---------------------------------------------------------------------------

-- Which scoring tile is at (px, py)? Used when placing a marker.
-- Returns "points", k  (k = 1-26, box k is sum k + 4)
--      or "coins",  k  (k = 1-6, the k-th Money Maker)
--      or nil if the point isn't on a tile.
function layout.getTileAt(px, py)
    for k = 1, layout.POINTS_COUNT do
        if layout.isInside(px, py, layout.placeBox(k)) then
            return "points", k
        end
    end
    for k = 1, 6 do
        if layout.isInside(px, py, layout.propCell(k)) then
            return "coins", k
        end
    end
    return nil
end

-- The open felt below the POINTS block, left of the Money Makers panel and
-- above the tray. Dice land in here, and the Para-DICE logo is printed in it.
function layout.landingZone()
    local f = layout.felt()
    local points = layout.placeGrid()
    local left = f.x + 16 + config.TABLE_MARGIN          -- clear of the west wall sliver
    local right = layout.propPanel().x - 20
    local top = points.y + points.h + layout.SCORE_LINE_H + 24
    local bottom = layout.tray().y - 40
    return rect(left, top, right - left, bottom - top)
end

-- Centre of the logo.
function layout.logoCenter()
    local z = layout.landingZone()
    return z.x + z.w / 2, z.y + z.h / 2
end

---------------------------------------------------------------------------
-- BANNER BUTTONS (bottom of the banner)
---------------------------------------------------------------------------

local BANNER_PAD = 26
local HINT_SPACE = 44   -- room at the very bottom for "PRESS C FOR A LIST OF CONTROLS"

-- The blue KEEP button (keep all 5 dice), at the bottom of the banner.
function layout.keepButton()
    local b = layout.banner()
    return rect(b.x + BANNER_PAD, b.h - BANNER_PAD - HINT_SPACE - config.BUTTON_H,
        b.w - 2 * BANNER_PAD, config.BUTTON_H)
end

-- The red REROLL button, just above KEEP.
function layout.rerollButton()
    local kb = layout.keepButton()
    return rect(kb.x, kb.y - 16 - config.BUTTON_H, kb.w, config.BUTTON_H)
end

-- The buttons on the LEVEL CLEAR / YOU WIN / GAME OVER screens, in a row:
-- a list of { id, label, color, rect }.
local END_BUTTONS = {
    levelClear = { { "shop", "VISIT THE SHOP", { 0.10, 0.65, 0.25 } } },
    victory    = { { "endless", "KEEP GOING (ENDLESS)", { 0.10, 0.65, 0.25 } },
                   { "finish", "FINISH RUN", { 0.85, 0.10, 0.12 } } },
    gameOver   = { { "copy", "COPY CODE", { 0.95, 0.62, 0.10 } },
                   { "again", "PLAY AGAIN", { 0.10, 0.65, 0.25 } },
                   { "menu", "MAIN MENU", { 0.12, 0.38, 0.95 } } },
}
END_BUTTONS.finished = END_BUTTONS.gameOver

function layout.endButtons(state)
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local list = END_BUTTONS[state] or {}
    local w, gap = 320, 20
    local total = #list * w + (#list - 1) * gap
    local out = {}
    for n, b in ipairs(list) do
        table.insert(out, { id = b[1], label = b[2], color = b[3],
            rect = rect((W - total) / 2 + (n - 1) * (w + gap), H / 2 + 30, w, 64) })
    end
    return out
end

-- Which end-screen button is at (px, py)? Its id, or nil.
function layout.endButtonAt(state, px, py)
    for _, b in ipairs(layout.endButtons(state)) do
        if layout.isInside(px, py, b.rect) then return b.id end
    end
    return nil
end

-- Where the yellow controls hint goes (under the buttons).
function layout.controlsHint()
    local b = layout.banner()
    return rect(b.x + BANNER_PAD, b.h - BANNER_PAD - HINT_SPACE + 8, b.w - 2 * BANNER_PAD, HINT_SPACE)
end

function layout.isOnRerollButton(px, py)
    return layout.isInside(px, py, layout.rerollButton())
end

function layout.isOnKeepButton(px, py)
    return layout.isInside(px, py, layout.keepButton())
end

-- The area inside the banner's border where text goes.
function layout.bannerContent()
    local b = layout.banner()
    return rect(b.x + BANNER_PAD + 6, BANNER_PAD + 10, b.w - 2 * (BANNER_PAD + 6), b.h)
end

return layout
