-- verify.lua
-- CHECKING A LEADERBOARD RUN IS REAL.
--
-- Anyone who knows the online leaderboard's address could post a made-up
-- score. But every run on it comes with its REPLAY CODE, and a replay code
-- reproduces a run exactly (same seed + same actions = same game). So
-- before a run is shown, the game quietly replays its code - instantly, no
-- animations - and checks it really reaches the level and points it
-- claims. A fake score has no code that can back it up, so it's hidden.
--
-- Only call this when no run is being played (e.g. on the leaderboard
-- screen): it borrows the game to do the replay.

local game       = require("game")
local score      = require("score")
local replaycode = require("replaycode")
local animation  = require("animation")
local confetti   = require("confetti")
local bigwin     = require("bigwin")

local verify = {}

-- Does 'run' ({ mode, level, points, code }) hold up? true or false.
function verify.check(run)
    local decoded = replaycode.decode(run.code)
    if not decoded or decoded.mode ~= run.mode then return false end
    if decoded.finalLevel ~= run.level or decoded.finalPoints ~= run.points then return false end
    -- God mode (the testing cheat) can't be on the leaderboard.
    for _, action in ipairs(decoded.actions) do
        if action[1] == "god" then return false end
    end

    game.recording, game.instant, game.verifying = false, true, true
    local ok = pcall(function()
        game.new(decoded.mode, decoded.seed)
        for _, action in ipairs(decoded.actions) do
            game.act(action[1], action[2])
        end
    end)
    -- The run must really have ENDED there, on that level, with those points.
    local over = game.state == "gameOver" or game.state == "finished"
    local real = ok and over and score.level == run.level and score.total == run.points
    game.recording, game.instant, game.verifying = true, false, false
    game.active = false
    animation.stop()
    confetti.stop()
    bigwin.stop()
    return real
end

return verify
