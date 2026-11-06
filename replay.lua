-- replay.lua
-- WATCHING A REPLAY. A replay code (see replaycode.lua) holds the seed and
-- every action of a run. Here a "bot" feeds those actions back into the
-- real game (game.act), one at a time at a comfortable pace, so you see
-- the exact same run play out: same dice, same shop, same everything.
--
-- The controls bar along the top: RESTART, << ROUND (rewind), PAUSE/PLAY,
-- ROUND >> (skip ahead), SPEED, and EXIT.
-- Rewinding works by quietly replaying from the start up to the right
-- action with no animations (it only takes a moment).

local game      = require("game")
local animation = require("animation")
local confetti  = require("confetti")
local score     = require("score")
local fonts     = require("fonts")
local ui        = require("ui")
local util      = require("util")
local layout    = require("layout")
local bigwin    = require("bigwin")

local replay = {}

replay.active = false
replay.paused = false
replay.SPEEDS = { 0.5, 1, 2, 4 }
replay.speedIndex = 2           -- start at 1x

local run = nil                 -- the decoded code
local nextAction = 1            -- the action that happens next
local timer = 0                 -- seconds waited before the next action
local roundStarts = {}          -- action numbers where a round begins

-- How long to pause BEFORE each kind of action (at 1x speed), so a human
-- can follow what's happening.
local DELAY = {
    marker = 0.6, clearMarkers = 0.6, roll = 0.8, throw = 0.6, hold = 0.45, holdAll = 0.5,
    keep = 1.1, nextRound = 1.6, openShop = 2.2, endless = 2.5, finish = 2.5, sellRack = 0.8,
    buyDice = 0.9, buyUpgrade = 0.9, buyMarker = 0.9, sellShop = 0.9, take = 1.4, selectInv = 0.7,
    equip = 0.7, spin = 0.9, continue = 1.4, god = 1,
}

function replay.speed()
    return replay.SPEEDS[replay.speedIndex]
end

-- Rebuild the run quietly (no animations) so that 'count' actions have
-- happened. The next action shown is then count + 1.
local function jumpTo(count)
    count = util.clamp(count, 0, #run.actions)
    game.instant = true
    game.new(run.mode, run.seed)
    for n = 1, count do
        game.act(run.actions[n][1], run.actions[n][2])
    end
    game.instant = false
    animation.stop()
    bigwin.stop()
    nextAction = count + 1
    timer = 0
end

-- Start watching. 'decoded' comes from replaycode.decode.
function replay.start(decoded)
    run = decoded
    replay.active = true
    replay.paused = false
    game.recording = false
    roundStarts = {}
    for n, action in ipairs(run.actions) do
        if action[1] == "roll" or action[1] == "nextRound" then table.insert(roundStarts, n) end
    end
    jumpTo(0)
end

function replay.stop()
    replay.active = false
    game.recording = true
    game.active = false
    animation.stop()
    confetti.stop()
end

function replay.isFinished()
    return run ~= nil and nextAction > #run.actions
end

-- Does the end of the replay match the original run's result?
function replay.matches()
    return run and score.total == run.finalPoints
end

-- Move along. Call every frame with the REAL time passed (speed is
-- applied in here and by main.lua for the animations).
function replay.update(dt)
    if not replay.active or replay.paused or replay.isFinished() then return end
    if game.isBusy() then return end            -- wait for the dice / reels to stop
    timer = timer + dt * replay.speed()
    local action = run.actions[nextAction]
    if timer >= (DELAY[action[1]] or 0.7) then
        timer = 0
        nextAction = nextAction + 1
        game.act(action[1], action[2])
    end
end

-- Back to the start of this round (or the one before, if this one has
-- only just begun).
function replay.rewind()
    if not run then return end
    local current = 0
    for _, n in ipairs(roundStarts) do
        if n < nextAction - 1 then current = n end
    end
    local previous = 0
    for _, n in ipairs(roundStarts) do
        if n < current then previous = n end
    end
    local target = (nextAction - current <= 3) and previous or current
    jumpTo(math.max(0, target - 1))
end

-- Skip ahead to the start of the next round.
function replay.forward()
    if not run then return end
    for _, n in ipairs(roundStarts) do
        if n > nextAction then
            jumpTo(n - 1)
            return
        end
    end
    jumpTo(#run.actions)
end

function replay.restart() if run then jumpTo(0) end end
function replay.togglePause() replay.paused = not replay.paused end
function replay.faster() replay.speedIndex = math.min(#replay.SPEEDS, replay.speedIndex + 1) end
function replay.slower() replay.speedIndex = math.max(1, replay.speedIndex - 1) end
function replay.cycleSpeed()
    replay.speedIndex = replay.speedIndex % #replay.SPEEDS + 1
end


---------------------------------------------------------------------------
-- THE CONTROLS BAR
---------------------------------------------------------------------------

replay.BUTTONS = { "restart", "rewind", "pause", "forward", "speed", "exit" }

function replay.barRect()
    local left = layout.banner().w + 20
    return util.rect(left, 4, love.graphics.getWidth() - 480 - left, 68)
end

function replay.buttonRect(n)
    local bar = replay.barRect()
    local w = (bar.w - 20 - 5 * 6) / 6
    return util.rect(bar.x + 10 + (n - 1) * (w + 6), bar.y + 6, w, 34)
end

function replay.buttonAt(x, y)
    for n, id in ipairs(replay.BUTTONS) do
        if util.isInside(x, y, replay.buttonRect(n)) then return id end
    end
    return nil
end

function replay.draw()
    if not replay.active then return end
    local bar = replay.barRect()
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", bar.x, bar.y, bar.w, bar.h, 10, 10)
    love.graphics.setColor(1, 0.82, 0.3)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", bar.x, bar.y, bar.w, bar.h, 10, 10)
    love.graphics.setLineWidth(1)

    local labels = {
        restart = "RESTART", rewind = "<< ROUND", pause = replay.paused and "PLAY" or "PAUSE",
        forward = "ROUND >>", speed = "SPEED " .. replay.speed() .. "x", exit = "EXIT",
    }
    for n, id in ipairs(replay.BUTTONS) do
        local color = id == "exit" and { 0.85, 0.10, 0.12 } or { 0.12, 0.38, 0.95 }
        if id == "pause" then color = { 0.10, 0.65, 0.25 } end
        ui.glossyButton(replay.buttonRect(n), labels[id], color, true)
    end

    -- Progress: a thin bar and a line of text.
    local done = math.min(#run.actions, nextAction - 1)
    local track = util.rect(bar.x + 10, bar.y + 48, bar.w * 0.45, 8)
    love.graphics.setColor(1, 1, 1, 0.15)
    love.graphics.rectangle("fill", track.x, track.y, track.w, track.h, 4, 4)
    love.graphics.setColor(1, 0.82, 0.3)
    love.graphics.rectangle("fill", track.x, track.y, track.w * done / math.max(1, #run.actions), track.h, 4, 4)
    local text = "REPLAY  " .. string.upper(run.mode) .. "   action " .. done .. "/" .. #run.actions
    if replay.isFinished() then
        text = replay.matches() and "REPLAY FINISHED - matches the original run" or
            "REPLAY FINISHED - but it didn't match (different game version?)"
    end
    ui.text(text, fonts.hint, track.x + track.w + 12, bar.y + 45, bar.w - track.w - 32, "left",
        { 1, 0.95, 0.85 })
end

return replay
