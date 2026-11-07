-- menu.lua
-- The MAIN MENU (the first thing you see) and the PLAY menu (pick a game
-- type). Both sit on a blue felt table under the big Para-DICE logo,
-- which has chasing marquee bulbs all round it.
--
-- This file holds their LAYOUT (where the buttons are, so drawing and
-- clicking agree) and their DRAWING. main.lua decides what a click does.

local fonts    = require("fonts")
local ui       = require("ui")
local util     = require("util")
local profiles = require("profiles")

local menu = {}

local rect = util.rect

local BUTTON_W, BUTTON_H, BUTTON_GAP = 340, 58, 14

-- The colours of the menu buttons.
local COLORS = {
    play        = { 0.10, 0.65, 0.25 },
    replay      = { 0.95, 0.62, 0.10 },
    settings    = { 0.45, 0.45, 0.52 },
    login       = { 0.12, 0.38, 0.95 },
    leaderboard = { 0.85, 0.10, 0.12 },
}


---------------------------------------------------------------------------
-- THE BLUE FELT TABLE
---------------------------------------------------------------------------

local feltTile, feltQuad, builtW, builtH

-- A square of blue felt with tiny random specks, tiled across the screen.
local function buildFelt()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    if feltTile and builtW == W and builtH == H then return end
    builtW, builtH = W, H
    if not feltTile then
        local data = love.image.newImageData(256, 256)
        data:mapPixel(function()
            local speck = 0.90 + love.math.random() * 0.14
            return 0.05 * speck, 0.20 * speck, 0.46 * speck, 1
        end)
        feltTile = love.graphics.newImage(data)
        feltTile:setWrap("repeat", "repeat")
    end
    feltQuad = love.graphics.newQuad(0, 0, W, H, 256, 256)
end

-- The background every menu screen uses: blue felt, darker at the edges,
-- inside a wooden rail.
function menu.drawBackground()
    buildFelt()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(feltTile, feltQuad, 0, 0)
    -- A soft dark edge, made of see-through frames getting darker outwards.
    for i = 0, 40 do
        love.graphics.setColor(0, 0, 0.05, 0.02 + 0.012 * (40 - i) / 40 * 2)
        love.graphics.setLineWidth(6)
        love.graphics.rectangle("line", i * 5, i * 5, W - i * 10, H - i * 10)
    end
    love.graphics.setLineWidth(1)
    -- The wooden rail round the table.
    love.graphics.setColor(0.33, 0.18, 0.08)
    love.graphics.setLineWidth(18)
    love.graphics.rectangle("line", 9, 9, W - 18, H - 18, 18, 18)
    love.graphics.setColor(0.55, 0.32, 0.14)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", 4, 4, W - 8, H - 8, 22, 22)
    love.graphics.rectangle("line", 17, 17, W - 34, H - 34, 12, 12)
    love.graphics.setLineWidth(1)
end


---------------------------------------------------------------------------
-- THE LOGO
---------------------------------------------------------------------------

function menu.logoRect()
    local W = love.graphics.getWidth()
    return rect((W - 780) / 2, 34, 780, 200)
end

-- The big logo on a dark sign board, ringed with chasing bulbs.
function menu.drawLogo(subtitle)
    local r = menu.logoRect()
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", r.x + 6, r.y + 8, r.w, r.h, 22, 22)
    love.graphics.setColor(0.10, 0.02, 0.05, 0.95)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 22, 22)
    love.graphics.setColor(1, 0.82, 0.3)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", r.x + 12, r.y + 12, r.w - 24, r.h - 24, 14, 14)
    love.graphics.setLineWidth(1)
    ui.bulbBorder(r, 30, 7, 6)

    -- "Para-DICE" in big Vegas letters, red with a gold glow.
    local text = "Para-DICE"
    local font = fonts.logoBig
    local scale = math.min(1, (r.w - 80) / font:getWidth(text))
    local w, h = font:getWidth(text) * scale, font:getHeight() * scale
    local x, y = r.x + (r.w - w) / 2, r.y + (r.h - h) / 2 - 10
    love.graphics.setFont(font)
    love.graphics.setColor(1, 0.75, 0.2, 0.25)
    for _, o in ipairs({ { -4, 0 }, { 4, 0 }, { 0, -4 }, { 0, 4 } }) do
        love.graphics.print(text, x + o[1], y + o[2], 0, scale, scale)
    end
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.print(text, x + 4, y + 6, 0, scale, scale)
    love.graphics.setColor(0.92, 0.12, 0.16)
    love.graphics.print(text, x, y, 0, scale, scale)
    if subtitle then
        ui.text(subtitle, fonts.heading, r.x, r.y + r.h - 46, r.w, "center", { 1, 0.85, 0.3 }, true)
    end
end


---------------------------------------------------------------------------
-- THE MAIN MENU
---------------------------------------------------------------------------

-- The buttons, top to bottom: { id, label }. LOGIN becomes STATS once
-- you're logged in.
function menu.mainButtons()
    return {
        { id = "play",        label = "PLAY" },
        { id = "replay",      label = "REPLAY" },
        { id = "settings",    label = "SETTINGS" },
        { id = "login",       label = profiles.current and "STATS" or "LOGIN" },
        { id = "leaderboard", label = "LEADERBOARD" },
    }
end

function menu.mainButtonRect(n)
    local W = love.graphics.getWidth()
    local top = menu.logoRect().y + menu.logoRect().h + 46
    return rect((W - BUTTON_W) / 2, top + (n - 1) * (BUTTON_H + BUTTON_GAP), BUTTON_W, BUTTON_H)
end

-- Which main menu button is at (x, y)? Its id, or nil.
function menu.mainButtonAt(x, y)
    for n, b in ipairs(menu.mainButtons()) do
        if util.isInside(x, y, menu.mainButtonRect(n)) then return b.id end
    end
    return nil
end

function menu.drawMain()
    menu.drawBackground()
    menu.drawLogo("A  DICE  ROGUELITE")
    for n, b in ipairs(menu.mainButtons()) do
        ui.glossyButton(menu.mainButtonRect(n), b.label, COLORS[b.id], true)
    end
    local H = love.graphics.getHeight()
    local who = profiles.current and ("Logged in as " .. profiles.current) or "Not logged in - LOGIN to keep your stats"
    ui.text(who, fonts.small, 0, H - 64, love.graphics.getWidth(), "center", { 1, 1, 1, 0.75 })
    if not ui.touchMode then
        ui.text("ENTER = PLAY     R = REPLAY     S = SETTINGS     L = LEADERBOARD", fonts.hint,
            0, H - 40, love.graphics.getWidth(), "center", { 1, 0.9, 0.3, 0.8 })
    end
end


---------------------------------------------------------------------------
-- THE PLAY MENU (choose a game type)
---------------------------------------------------------------------------

menu.GAME_TYPES = {
    { id = "tutorial", title = "TUTORIAL", color = { 0.12, 0.38, 0.95 },
      lines = { "Learn the game in", "a guided first level.", "Goals x1.25 a level,", "x1.35 from level 6" } },
    { id = "normal", title = "NORMAL", color = { 0.10, 0.65, 0.25 },
      lines = { "10 levels to beat", "the house.", "Goals x1.25 a level,", "x1.35 from level 6" } },
    { id = "hard", title = "HARD", color = { 0.85, 0.10, 0.12 },
      lines = { "For high rollers:", "goals climb fast.", "Goals x1.5 a level,", "x1.62 from level 6" } },
}

function menu.typeCardRect(n)
    local W = love.graphics.getWidth()
    local w, h, gap = 260, 300, 30
    local total = 3 * w + 2 * gap
    return rect((W - total) / 2 + (n - 1) * (w + gap), menu.logoRect().y + menu.logoRect().h + 40, w, h)
end

-- The PLAY button on card n.
function menu.typeButtonRect(n)
    local c = menu.typeCardRect(n)
    return rect(c.x + 24, c.y + c.h - 76, c.w - 48, 56)
end

function menu.backRect()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    return rect((W - 220) / 2, H - 100, 220, 52)
end

-- Which game type card is at (x, y)? Its id, or nil.
function menu.typeAt(x, y)
    for n, t in ipairs(menu.GAME_TYPES) do
        if util.isInside(x, y, menu.typeCardRect(n)) then return t.id end
    end
    return nil
end

function menu.drawPlay()
    menu.drawBackground()
    menu.drawLogo("CHOOSE YOUR GAME")
    for n, t in ipairs(menu.GAME_TYPES) do
        local c = menu.typeCardRect(n)
        ui.vegasWindow(c, nil)
        if ui.isHovered(c) then
            love.graphics.setColor(1, 1, 1, 0.06)
            love.graphics.rectangle("fill", c.x, c.y, c.w, c.h, 14, 14)
        end
        ui.text(t.title, fonts.title, c.x, c.y + 18, c.w, "center", t.color, true)
        for k, line in ipairs(t.lines) do
            ui.text(line, fonts.small, c.x + 10, c.y + 86 + (k - 1) * 24, c.w - 20, "center",
                k == #t.lines and { 1, 0.85, 0.3 } or { 1, 0.95, 0.88 })
        end
        ui.glossyButton(menu.typeButtonRect(n), "PLAY " .. n, t.color, true)
    end
    ui.text("Every run can go ENDLESS after level 10: goals x2 each level, and a 4th luck slot.",
        fonts.small, 0, menu.typeCardRect(1).y + 318, love.graphics.getWidth(), "center", { 1, 1, 1, 0.8 })
    ui.glossyButton(menu.backRect(), "BACK", { 0.45, 0.45, 0.52 }, true)
end

return menu
