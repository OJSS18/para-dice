-- controlsguide.lua
-- The list of every control, shown when the player presses C.
-- The game itself never prints key hints anywhere else - just
-- "PRESS C FOR A LIST OF CONTROLS" - so this is the one place to look.
--
-- If you add or change a control in main.lua, update the list below too.

local config = require("config")
local fonts  = require("fonts")
local ui     = require("ui")

local controlsguide = {}

-- Each section has a title and a list of {keys, what it does}.
local SECTIONS = {
    { title = "ANY TIME  (on a phone or tablet, tap = click)", items = {
        { "C  /  CONTROLS tab", "Show / hide this list (tap anywhere to close it)" },
        { "S  /  SETTINGS tab", "Settings: music volume (Left / Right arrows or drag the slider)" },
        { "Esc",     "Close this list - or quit the game" },
    } },
    { title = "START", items = {
        { "Enter  /  START",   "Start a new game" },
    } },
    { title = "PLACING YOUR MARKERS (start of each level)", items = {
        { "Click a tile",        "Put a white chip there (x1.5 if it hits); click again to pick it up" },
        { "CLEAR CHIPS",         "Take all your chips back off the table" },
        { "Enter  /  ROLL",      "Start rolling (chips are optional)" },
    } },
    { title = "ROLLING", items = {
        { "Click a die  /  1-5", "Mark that die to keep (again to un-mark)" },
        { "Enter  /  REROLL",    "Reroll every die you didn't keep" },
        { "K  /  KEEP",          "Keep all 5 dice (x1.1 points if you haven't rerolled)" },
    } },
    { title = "BETWEEN ROUNDS", items = {
        { "Space  /  NEXT ROUND",     "Roll the next round" },
        { "Space  /  VISIT THE SHOP", "After LEVEL CLEAR: go to the shop" },
    } },
    { title = "SHOP", items = {
        { "Click a card",               "Buy it (dice, luck item or upgrade)" },
        { "MARKERS  +1",                "Buy another white chip to place each level" },
        { "SPIN  /  click the reel",    "Mystery Machine: 30 coins for a random luck item" },
        { "Click inventory die, then one of your dice", "Swap it in" },
        { "Enter  /  CONTINUE",         "Start the next level" },
    } },
    { title = "GAME OVER / YOU WIN", items = {
        { "Enter  /  PLAY AGAIN",   "Play again" },
    } },
}

-- Only listed while god mode is switched on in config.lua.
local GOD_MODE = { title = "TESTING (GOD MODE)", items = {
    { "`  (the ~ key)", "In a level: win it and go to the shop.  In the shop: +coins" },
} }


-- The CONTROLS tab, hanging from the top edge just left of SETTINGS.
-- (On a phone there's no C key, so this is how you open the list.)
function controlsguide.tabRect()
    return { x = love.graphics.getWidth() - 334, y = 0, w = 150, h = 38 }
end

function controlsguide.isOnTab(x, y)
    local r = controlsguide.tabRect()
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function controlsguide.drawTab()
    local r = controlsguide.tabRect()
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
    -- A gold "?" coin
    love.graphics.setColor(1, 0.85, 0.35)
    love.graphics.circle("fill", r.x + 22, r.y + r.h / 2, 10)
    ui.text("?", fonts.hint, r.x + 12, r.y + r.h / 2 - 8, 20, "center", { 0.45, 0.04, 0.07 })
    ui.text("CONTROLS", fonts.hint, r.x + 36, r.y + 12, r.w - 44, "center", { 1, 0.95, 0.85 })
end

-- Draw the guide over whatever is on screen.
function controlsguide.draw()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()

    -- Dim everything behind.
    love.graphics.setColor(0, 0, 0, 0.78)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- The card the list sits on.
    local cardW = math.min(860, W - 80)
    local cardH = math.min(700, H - 30)
    local x, y = (W - cardW) / 2, (H - cardH) / 2
    love.graphics.setColor(0.10, 0.04, 0.07, 0.97)
    love.graphics.rectangle("fill", x, y, cardW, cardH, 16, 16)
    love.graphics.setColor(1, 0.8, 0.25)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", x, y, cardW, cardH, 16, 16)
    love.graphics.setLineWidth(1)

    ui.text("CONTROLS", fonts.title, x, y + 18, cardW, "center", { 1, 0.85, 0.25 }, true)

    local sections = {}
    for _, s in ipairs(SECTIONS) do table.insert(sections, s) end
    if config.GOD_MODE_ENABLED then table.insert(sections, GOD_MODE) end

    -- Keys in the left column, what they do in the right column.
    local keyW = cardW * 0.40
    local left = x + 36
    local rowY = y + 84
    local lineH = 20
    for _, s in ipairs(sections) do
        ui.text(s.title, fonts.heading, left, rowY, cardW - 72, "left", { 1, 0.45, 0.35 })
        rowY = rowY + 23
        for _, item in ipairs(s.items) do
            ui.text(item[1], fonts.small, left + 12, rowY, keyW - 20, "left", { 1, 0.9, 0.3 })
            ui.text(item[2], fonts.small, left + keyW, rowY, cardW - keyW - 72, "left", { 1, 0.95, 0.88 })
            rowY = rowY + lineH
        end
        rowY = rowY + 5
    end
end

return controlsguide
