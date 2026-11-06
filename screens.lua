-- screens.lua
-- The smaller menu screens, all on the blue felt:
--   * TEXT ENTRY  - type a username, or paste a replay code
--   * STATS       - the logged-in player's stats (and LOG OUT)
--   * LEADERBOARD - the best runs, online or on this device, with WATCH
--
-- Like menu.lua, this file has the LAYOUT and DRAWING; main.lua decides
-- what clicks do.

local fonts       = require("fonts")
local ui          = require("ui")
local util        = require("util")
local menu        = require("menu")
local profiles    = require("profiles")
local leaderboard = require("leaderboard")

local screens = {}

local rect = util.rect
local GOLD, CREAM, DIM = { 1, 0.85, 0.3 }, { 1, 0.95, 0.88 }, { 1, 0.95, 0.88, 0.55 }

-- A big panel in the middle of the screen, under the logo.
local function panelRect(h)
    local W = love.graphics.getWidth()
    return rect((W - 820) / 2, menu.logoRect().y + menu.logoRect().h + 30, 820, h)
end

-- A row of buttons along the bottom of a panel: rect for button n of count.
function screens.buttonRect(panel, n, count)
    local w, gap = 200, 20
    local total = count * w + (count - 1) * gap
    return rect(panel.x + (panel.w - total) / 2 + (n - 1) * (w + gap), panel.y + panel.h - 74, w, 52)
end


---------------------------------------------------------------------------
-- TEXT ENTRY
---------------------------------------------------------------------------

-- What's being typed: { kind = "name" or "code", text, message }.
screens.entry = { kind = "name", text = "", message = "" }

function screens.entryPanel()
    return panelRect(300)
end

-- The buttons: OK, PASTE, CANCEL.
screens.ENTRY_BUTTONS = { "ok", "paste", "cancel" }

function screens.drawEntry()
    menu.drawBackground()
    local e = screens.entry
    menu.drawLogo(e.kind == "name" and "LOG IN" or "WATCH A REPLAY")
    local p = screens.entryPanel()
    ui.vegasWindow(p, e.kind == "name" and "PICK A USERNAME" or "PASTE A REPLAY CODE")
    ui.text(e.kind == "name" and "3 to 16 letters, numbers or _ . Your stats are kept under this name."
        or "Paste the code a player shared after their run, then press OK to watch it.",
        fonts.small, p.x + 20, p.y + 30, p.w - 40, "center", DIM)

    -- The box being typed in, with a blinking cursor.
    local box = rect(p.x + 40, p.y + 80, p.w - 80, 56)
    love.graphics.setColor(0.03, 0.02, 0.04)
    love.graphics.rectangle("fill", box.x, box.y, box.w, box.h, 10, 10)
    love.graphics.setColor(GOLD)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", box.x, box.y, box.w, box.h, 10, 10)
    love.graphics.setLineWidth(1)
    local shown = e.text
    local font = e.kind == "name" and fonts.text or fonts.tiny
    -- A long code only shows its end, so the cursor stays in view.
    while font:getWidth(shown .. "|") > box.w - 30 do shown = shown:sub(2) end
    local cursor = (math.floor(love.timer.getTime() * 2) % 2 == 0) and "|" or ""
    love.graphics.setFont(font)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(shown .. cursor, box.x + 15, box.y + (box.h - font:getHeight()) / 2)

    if e.message ~= "" then
        ui.text(e.message, fonts.small, p.x + 20, box.y + box.h + 14, p.w - 40, "center", { 1, 0.45, 0.4 })
    end
    local labels = { ok = "OK", paste = "PASTE", cancel = "CANCEL" }
    local colors = { ok = { 0.10, 0.65, 0.25 }, paste = { 0.95, 0.62, 0.10 }, cancel = { 0.45, 0.45, 0.52 } }
    for n, id in ipairs(screens.ENTRY_BUTTONS) do
        ui.glossyButton(screens.buttonRect(p, n, 3), labels[id], colors[id], true)
    end
end

-- Which entry button is at (x, y)?
function screens.entryButtonAt(x, y)
    for n, id in ipairs(screens.ENTRY_BUTTONS) do
        if util.isInside(x, y, screens.buttonRect(screens.entryPanel(), n, 3)) then return id end
    end
    return nil
end


---------------------------------------------------------------------------
-- STATS
---------------------------------------------------------------------------

function screens.statsPanel()
    return panelRect(love.graphics.getHeight() - panelRect(0).y - 30)
end

screens.STATS_BUTTONS = { "logout", "back" }

function screens.drawStats()
    menu.drawBackground()
    menu.drawLogo("PLAYER STATS")
    local p = screens.statsPanel()
    ui.vegasWindow(p, string.upper(profiles.current or ""))
    local s = profiles.stats() or {}
    local list = profiles.STATS
    local half = math.ceil(#list / 2)
    local rowH = math.min(34, (p.h - 120) / half)
    for n, stat in ipairs(list) do
        local col = (n <= half) and 0 or 1
        local row = (n - 1) % half
        local x = p.x + 30 + col * (p.w / 2)
        local y = p.y + 30 + row * rowH
        local value = s[stat[1]]
        local text = value == nil and "-" or tostring(value)
        if type(value) == "number" and value >= 1000 then
            text = tostring(math.floor(value)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
        end
        ui.text(stat[2], fonts.small, x, y, p.w / 2 - 170, "left", CREAM)
        ui.text(text, fonts.heading, x + p.w / 2 - 190, y, 130, "right", GOLD, true)
    end
    ui.glossyButton(screens.buttonRect(p, 1, 2), "LOG OUT", { 0.85, 0.10, 0.12 }, true)
    ui.glossyButton(screens.buttonRect(p, 2, 2), "BACK", { 0.45, 0.45, 0.52 }, true)
end

function screens.statsButtonAt(x, y)
    for n, id in ipairs(screens.STATS_BUTTONS) do
        if util.isInside(x, y, screens.buttonRect(screens.statsPanel(), n, 2)) then return id end
    end
    return nil
end


---------------------------------------------------------------------------
-- LEADERBOARD
---------------------------------------------------------------------------

-- Which board and game type are showing.
screens.board = { which = "online", mode = "normal" }

local ROWS = 10

function screens.boardPanel()
    return panelRect(love.graphics.getHeight() - panelRect(0).y - 30)
end

-- The four toggle tabs across the top of the panel.
screens.BOARD_TABS = {
    { id = "online", label = "ONLINE" }, { id = "device", label = "THIS DEVICE" },
    { id = "normal", label = "NORMAL" }, { id = "hard", label = "HARD" },
}

function screens.boardTabRect(n)
    local p = screens.boardPanel()
    local w = 150
    local x = p.x + 24 + (n - 1) * (w + 10) + (n > 2 and 30 or 0)
    return rect(x, p.y + 22, w, 36)
end

-- The WATCH button on row n.
function screens.watchRect(n)
    local p = screens.boardPanel()
    local rowH = (p.h - 170) / ROWS
    return rect(p.x + p.w - 130, p.y + 96 + (n - 1) * rowH, 96, rowH - 6)
end

function screens.boardRows()
    return leaderboard.list(screens.board.which, screens.board.mode)
end

function screens.drawBoard()
    menu.drawBackground()
    menu.drawLogo("LEADERBOARD")
    local p = screens.boardPanel()
    ui.vegasWindow(p, nil)
    local b = screens.board
    for n, tab in ipairs(screens.BOARD_TABS) do
        local on = (tab.id == b.which) or (tab.id == b.mode)
        ui.glossyButton(screens.boardTabRect(n), tab.label,
            on and { 0.95, 0.62, 0.10 } or { 0.30, 0.30, 0.36 }, true)
    end

    local rowH = (p.h - 170) / ROWS
    local cols = { p.x + 30, p.x + 90, p.x + 380, p.x + 500 }
    local y0 = p.y + 70
    ui.text("#", fonts.hint, cols[1], y0, 50, "left", DIM)
    ui.text("PLAYER", fonts.hint, cols[2], y0, 280, "left", DIM)
    ui.text("LEVEL", fonts.hint, cols[3], y0, 110, "left", DIM)
    ui.text("POINTS", fonts.hint, cols[4], y0, 180, "left", DIM)

    local status = nil
    if b.which == "online" then
        if leaderboard.onlineStatus == "off" then
            status = "The online leaderboard isn't set up yet - see THIS DEVICE."
        elseif leaderboard.onlineStatus == "loading" then
            status = "Loading..."
        elseif leaderboard.onlineStatus == "error" then
            status = "Couldn't reach the online leaderboard. Check your internet connection."
        end
    end
    local rows = screens.boardRows()
    if status then
        ui.text(status, fonts.small, p.x, p.y + p.h / 2 - 20, p.w, "center", CREAM)
    elseif #rows == 0 then
        ui.text("No runs yet - log in and play one!", fonts.small, p.x, p.y + p.h / 2 - 20, p.w, "center", CREAM)
    else
        for n = 1, math.min(ROWS, #rows) do
            local run = rows[n]
            local y = p.y + 96 + (n - 1) * rowH
            if n % 2 == 1 then
                love.graphics.setColor(1, 1, 1, 0.04)
                love.graphics.rectangle("fill", p.x + 20, y - 2, p.w - 40, rowH - 2, 6, 6)
            end
            local mine = run.name == profiles.current
            local color = mine and GOLD or CREAM
            local ty = y + (rowH - 6 - fonts.small:getHeight()) / 2
            ui.text(tostring(n), fonts.heading, cols[1], ty, 50, "left", n <= 3 and GOLD or CREAM)
            ui.text(run.name or "?", fonts.small, cols[2], ty, 280, "left", color)
            ui.text(tostring(run.level), fonts.small, cols[3], ty, 110, "left", color)
            ui.text(tostring(run.points), fonts.small, cols[4], ty, 220, "left", color)
            if run.code then
                ui.glossyButton(screens.watchRect(n), "WATCH", { 0.12, 0.38, 0.95 }, true)
            end
        end
    end
    ui.glossyButton(screens.buttonRect(p, 1, 1), "BACK", { 0.45, 0.45, 0.52 }, true)
end

-- What's at (x, y) on the leaderboard: "tab", id / "watch", run / "back".
function screens.boardClick(x, y)
    for n, tab in ipairs(screens.BOARD_TABS) do
        if util.isInside(x, y, screens.boardTabRect(n)) then return "tab", tab.id end
    end
    local rows = screens.boardRows()
    for n = 1, math.min(ROWS, #rows) do
        if rows[n].code and util.isInside(x, y, screens.watchRect(n)) then return "watch", rows[n] end
    end
    if util.isInside(x, y, screens.buttonRect(screens.boardPanel(), 1, 1)) then return "back" end
    return nil
end

return screens
