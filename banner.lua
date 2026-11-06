-- banner.lua
-- DRAWS the info banner down the left side of the screen (like Balatro's
-- side panel):
--   * the level score in the top-left, as  SCORE/TARGET  (e.g. 116/500)
--   * level and round
--   * coins, dice sum and luck item
--   * the last round's result
--   * a glossy red REROLL button and a glossy blue KEEP button
--   * "PRESS C FOR A LIST OF CONTROLS" in yellow at the bottom
--
-- It's styled like an old Vegas sign: a gold border with light bulbs.
-- Drawing only - this never changes any game data.

local config    = require("config")
local layout    = require("layout")
local fonts     = require("fonts")
local ui        = require("ui")
local score     = require("score")
local dice      = require("dice")
local player    = require("player")
local luck      = require("luck")
local animation = require("animation")
local markers   = require("markers")

local banner = {}

local GOLD   = { 1.00, 0.80, 0.25 }
local CREAM  = { 1.00, 0.95, 0.85 }
local DIM    = { 1.00, 0.95, 0.85, 0.6 }
local GREEN  = { 0.45, 1.00, 0.45 }
local YELLOW = { 1.00, 0.90, 0.20 }
local WHITE  = { 1, 1, 1 }

local RED_BUTTON  = { 0.85, 0.10, 0.12 }
local BLUE_BUTTON = { 0.12, 0.38, 0.95 }


---------------------------------------------------------------------------
-- PIECES
---------------------------------------------------------------------------

-- The panel: dark background, gold border and a row of glowing bulbs.
local function drawFrame()
    local b = layout.banner()

    -- A dark background that's a touch lighter at the top.
    for i = 0, b.h, 4 do
        local t = i / b.h
        love.graphics.setColor(0.14 - 0.07 * t, 0.05 - 0.02 * t, 0.09 - 0.04 * t)
        love.graphics.rectangle("fill", b.x, b.y + i, b.w, 4)
    end

    -- Gold border, inset from the edges.
    local inset = 12
    local bx, by, bw, bh = b.x + inset, b.y + inset, b.w - 2 * inset, b.h - 2 * inset
    love.graphics.setColor(0.55, 0.38, 0.12)
    love.graphics.setLineWidth(8)
    love.graphics.rectangle("line", bx, by, bw, bh, 14, 14)
    love.graphics.setColor(GOLD)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", bx, by, bw, bh, 14, 14)
    love.graphics.setLineWidth(1)

    -- Bulbs along the border. They chase, like a real marquee.
    local spacing = 34
    local step = math.floor(love.timer.getTime() * 6)
    local n = 0
    local function bulb(x, y)
        n = n + 1
        local bright = ((n + step) % 3 == 0) and 1 or 0.65
        love.graphics.setColor(1, 0.8, 0.4, 0.22 * bright)
        love.graphics.circle("fill", x, y, 10)
        love.graphics.setColor(1, 0.75 + 0.2 * bright, 0.45 + 0.3 * bright)
        love.graphics.circle("fill", x, y, 4)
    end
    for x = bx + 20, bx + bw - 20, spacing do bulb(x, by) end
    for y = by + 20, by + bh - 20, spacing do bulb(bx + bw, y) end
    for x = bx + bw - 20, bx + 20, -spacing do bulb(x, by + bh) end
    for y = by + bh - 20, by + 20, -spacing do bulb(bx, y) end
end

-- A label on the left and a value on the right, on one line.
local function row(label, value, y, valueColor)
    local c = layout.bannerContent()
    ui.text(label, fonts.small, c.x, y + 4, c.w * 0.5, "left", DIM)
    ui.text(value, fonts.text, c.x + c.w * 0.35, y, c.w * 0.65, "right", valueColor or CREAM)
end

-- What the markers are sitting on, as text: "17, Full House", or "none".
local function markerName()
    local names = {}
    for _, m in ipairs(markers.placed) do
        if m.kind == "points" then
            table.insert(names, tostring(m.sum))
        else
            for _, hand in ipairs(score.COIN_HANDS) do
                if hand.id == m.hand then
                    table.insert(names, hand.name)
                end
            end
        end
    end
    if markers.autoSum then
        table.insert(names, markers.autoSum .. " (auto)")   -- Addict's automatic marker
    end
    if #names == 0 then
        return "none"
    end
    -- table.concat joins a list with ", " between each item.
    return table.concat(names, ", ")
end

-- A thin gold divider line across the banner.
local function divider(y)
    local c = layout.bannerContent()
    love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.35)
    love.graphics.rectangle("fill", c.x, y, c.w, 1)
end

-- "PRESS C FOR A LIST OF CONTROLS" in yellow, inside rectangle r.
-- Public so the other screens can show the same hint.
function banner.drawControlsHint(r)
    love.graphics.setFont(fonts.hint)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.printf(ui.controlsHint(), r.x + 1, r.y + 2, r.w, "center")
    love.graphics.setColor(YELLOW)
    love.graphics.printf(ui.controlsHint(), r.x, r.y, r.w, "center")
end


---------------------------------------------------------------------------
-- THE BANNER (draw.lua calls this)
---------------------------------------------------------------------------

-- 'state' is the screen from main.lua ("play", "roundOver", ...).
function banner.draw(state)
    local c = layout.bannerContent()
    local choosing = (state == "play")
    local placing = (state == "placeMarker")
    local busy = animation.isRolling()

    drawFrame()

    -- LEVEL SCORE, top-left, as SCORE/TARGET. Green once the target is reached.
    ui.text("LEVEL SCORE", fonts.heading, c.x, c.y, c.w, "left", DIM)
    local scoreColor = score.hasPassedLevel() and GREEN or GOLD
    ui.text(score.levelTotal .. "/" .. score.getTarget(), fonts.scoreBig,
        c.x, c.y + 24, c.w, "left", scoreColor, true)

    -- LEVEL and ROUND
    -- While choosing (or placing), the round being played hasn't been counted yet.
    local roundNumber = score.round
    if choosing or placing then
        roundNumber = score.round + 1
    end
    ui.text("LEVEL " .. score.level .. "/" .. score.MAX_LEVEL
        .. "   ROUND " .. roundNumber .. "/" .. score.ROUNDS_PER_LEVEL,
        fonts.heading, c.x, c.y + 84, c.w, "left", CREAM)
    divider(c.y + 116)

    -- Info rows
    local y = c.y + 128
    row("Coins", tostring(player.coins), y, GOLD)
    y = y + 32
    row("Dice sum", busy and "..." or tostring(dice.total), y)   -- hidden until the dice stop
    y = y + 32
    if luck.current then
        local item = luck.get(luck.current)
        row("Luck", item.name .. " (" .. luck.timeLeftText() .. ")", y, luck.rarityColor(item))
    else
        row("Luck", "none", y, DIM)
    end
    y = y + 32
    local anyMarker = markers.count() > 0 or markers.autoSum ~= nil
    row("Markers", markerName(), y, anyMarker and WHITE or DIM)
    if player.unlockTokens > 0 then
        y = y + 32
        row("Unlock Tokens", tostring(player.unlockTokens), y, { 1, 0.62, 0.15 })
    end
    y = y + 40
    divider(y - 6)

    if placing then
        -- PLACE YOUR MARKERS: explain what the chips do.
        ui.text("PLACE YOUR MARKERS", fonts.heading, c.x, y + 4, c.w, "left", GOLD, true)
        local chipsLeft = markers.owned - markers.count()
        local lines = {
            "Put your white chips on any",
            "POINTS or MONEY MAKER tiles.",
            "Each marked tile pays x" .. markers.MULTIPLIER .. "!",
            chipsLeft .. " of " .. markers.owned .. " chips left to place.",
        }
        for n, line in ipairs(lines) do
            ui.text(line, fonts.small, c.x, y + 8 + n * 24, c.w, "left", CREAM)
        end
    end

    -- Last round's result (once the round is over)
    local r = score.lastRound
    if r and not choosing and not placing then
        ui.text("ROUND " .. r.round, fonts.heading, c.x, y + 4, c.w, "left", GOLD)
        local lines = { "Sum " .. r.sum .. " = " .. r.base .. " pts" }
        local boosted = false   -- did anything change the base points?
        if r.flat > 0 then
            table.insert(lines, "+" .. r.flat .. " point bonus")
            boosted = true
        end
        if r.boostMult ~= 1 then
            -- string.format("%.2f", 1.65) gives "1.65": 2 decimal places.
            table.insert(lines, "x" .. string.format("%.2f", r.boostMult) .. " point boost")
            boosted = true
        end
        if r.upgradeMult ~= 1 then
            table.insert(lines, "x" .. string.format("%.2f", r.upgradeMult) .. " upgrades")
            boosted = true
        end
        if r.luckMult ~= 1 then
            table.insert(lines, "x" .. r.luckMult .. " " .. (r.sum % 2 == 0 and "Even Steven" or "That's Odd"))
            boosted = true
        end
        if r.markerPoints then
            table.insert(lines, "x" .. markers.MULTIPLIER .. " marker!")
            boosted = true
        end
        if r.noReroll then
            table.insert(lines, "x" .. score.keepMultiplier() .. " keep bonus")
            boosted = true
        end
        if boosted then
            table.insert(lines, "= " .. r.points .. " pts")
        end
        if r.hand then
            local text = r.hand .. ": +" .. (r.coins - r.payMe) .. " coins"
            if r.markerCoins then
                text = text .. " (x" .. markers.MULTIPLIER .. ")"
            end
            table.insert(lines, text)
        else
            table.insert(lines, "No Money Maker")
        end
        if r.payMe > 0 then
            table.insert(lines, "Pay Me: +" .. r.payMe .. " coins")
        end
        for n, line in ipairs(lines) do
            ui.text(line, fonts.small, c.x, y + 8 + n * 24, c.w, "left", CREAM)
        end
    end

    -- Buttons.
    if placing then
        -- Before the first roll: ROLL starts the level (chip or no chip),
        -- and the blue button takes the chip back off the table.
        ui.glossyButton(layout.rerollButton(), "ROLL", RED_BUTTON, true)
        ui.glossyButton(layout.keepButton(), "CLEAR CHIPS", BLUE_BUTTON, markers.count() > 0)
    else
        -- Neither works while dice are moving.
        local ready = choosing and not busy
        local canReroll = ready and dice.canReroll() and dice.countToReroll() > 0
        local canKeep   = ready and dice.canKeep()

        if state == "roundOver" then
            -- Between rounds the red button starts the next round
            -- (so it can be tapped on a phone - no Space bar there).
            ui.glossyButton(layout.rerollButton(), "NEXT ROUND", RED_BUTTON, true)
        else
            ui.glossyButton(layout.rerollButton(), "REROLL", RED_BUTTON, canReroll)
        end

        -- Show the bonus on KEEP while it can still be earned.
        local keepLabel = "KEEP"
        if canKeep and not dice.hasRerolled() then
            keepLabel = "KEEP  x" .. score.keepMultiplier()
        end
        ui.glossyButton(layout.keepButton(), keepLabel, BLUE_BUTTON, canKeep)
    end

    banner.drawControlsHint(layout.controlsHint())
end

-- Just the decorated banner with the controls hint (start screen).
function banner.drawFrameOnly()
    drawFrame()
    -- A big START button (Enter works too).
    ui.glossyButton(layout.rerollButton(), "START", RED_BUTTON, true)
    banner.drawControlsHint(layout.controlsHint())
end

return banner
