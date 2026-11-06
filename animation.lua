-- animation.lua
-- The dice ROLL ANIMATION: a die tumbles through a set of frames and
-- settles onto the face it really rolled.
--
-- IMPORTANT: by the time an animation starts, dice.lua has ALREADY picked
-- the real result. This file only decides which PICTURE to show while the
-- die tumbles, and every pattern ends on the picture of that real result.
-- Nothing in here changes dice.values, so the animation can't change a score.
--
-- FRAME IDs (each one is a picture in assets/dice/tumble/):
--   1-16   spinning frames (one full loop)       tumble_<color>_01.png ... _16.png
--   17-22  landed, showing face 1-6              land_<color>_1.png ... _6.png
--   1RK    forward settle onto face R, step K    settle_<color>_f<R>_<K>.png   (e.g. 134)
--   2RK    reverse settle onto face R, step K    settle_<color>_r<R>_<K>.png   (e.g. 251)
--
-- PATTERNS: 3 different tumbles (A, B, C), each with a version that lands
-- on every face. Each is 25 frames long; frame 25 is always the landed face.
-- Dice 1-5 use A, B, C, A, B so neighbouring dice don't spin in sync.
--
-- MOVEMENT: each rolled die goes through 3 phases:
--   "tumble" - thrown from its tray slot, it flies onto the felt while the
--              tumble frames play, slowing down and landing on its spot.
--   "rest"   - it sits on the felt showing its landed face for a moment.
--   "return" - it slides back into its tray slot, where the player can
--              click it. Then it's done and drawn in the tray as normal.

local config = require("config")
local layout = require("layout")

local animation = {}


---------------------------------------------------------------------------
-- PATTERNS: PATTERNS[sequence][result] = list of 25 frame IDs
---------------------------------------------------------------------------

animation.PATTERNS = {
    A = {
        [1] = {1, 3, 5, 7, 9, 11, 13, 15, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 111, 112, 113, 114, 17},
        [2] = {1, 3, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 1, 2, 3, 4, 5, 6, 7, 121, 122, 123, 124, 18},
        [3] = {1, 3, 5, 7, 9, 11, 12, 13, 14, 15, 16, 1, 2, 3, 4, 5, 6, 7, 8, 9, 131, 132, 133, 134, 19},
        [4] = {1, 4, 7, 9, 11, 13, 15, 1, 3, 5, 7, 9, 11, 12, 13, 14, 15, 16, 1, 2, 141, 142, 143, 144, 20},
        [5] = {1, 3, 5, 7, 9, 11, 13, 15, 1, 3, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 151, 152, 153, 154, 21},
        [6] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 1, 2, 3, 4, 161, 162, 163, 164, 22},
    },
    B = {
        [1] = {5, 7, 9, 11, 13, 14, 15, 16, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 111, 112, 113, 114, 17},
        [2] = {5, 8, 11, 14, 16, 2, 4, 6, 8, 10, 12, 14, 16, 1, 2, 3, 4, 5, 6, 7, 121, 122, 123, 124, 18},
        [3] = {5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 1, 2, 3, 4, 5, 6, 7, 8, 9, 131, 132, 133, 134, 19},
        [4] = {5, 7, 9, 11, 13, 15, 1, 3, 5, 7, 9, 10, 11, 12, 13, 14, 15, 16, 1, 2, 141, 142, 143, 144, 20},
        [5] = {5, 7, 9, 11, 13, 15, 1, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 151, 152, 153, 154, 21},
        [6] = {5, 7, 9, 11, 13, 15, 1, 3, 5, 7, 9, 11, 13, 14, 15, 16, 1, 2, 3, 4, 161, 162, 163, 164, 22},
    },
    C = {
        [1] = {10, 8, 6, 4, 2, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 211, 212, 213, 214, 17},
        [2] = {10, 8, 6, 4, 2, 16, 14, 12, 10, 8, 6, 4, 3, 2, 1, 16, 15, 14, 13, 12, 221, 222, 223, 224, 18},
        [3] = {10, 8, 6, 4, 2, 16, 14, 12, 10, 8, 7, 6, 5, 4, 3, 2, 1, 16, 15, 14, 231, 232, 233, 234, 19},
        [4] = {10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 241, 242, 243, 244, 20},
        [5] = {10, 8, 6, 4, 3, 2, 1, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 251, 252, 253, 254, 21},
        [6] = {10, 7, 4, 2, 16, 14, 12, 10, 8, 6, 4, 2, 16, 15, 14, 13, 12, 11, 10, 9, 261, 262, 263, 264, 22},
    },
}

-- Which pattern each die uses: die 1 -> A, die 2 -> B, die 3 -> C, die 4 -> A, die 5 -> B.
local SEQUENCE_FOR_DIE = { "A", "B", "C", "A", "B" }

local FRAMES_PER_ROLL = 25   -- every pattern is this long
local SPIN_FRAMES     = 20   -- frames 1-20 spin, 21-24 settle, 25 is landed

-- Frame ID of the landed picture for a face: 17 for a 1 ... 22 for a 6.
function animation.landedFrameId(face)
    return 16 + face
end


---------------------------------------------------------------------------
-- FILE NAMES (used by draw.lua to preload every picture)
---------------------------------------------------------------------------

-- Turn a colour and frame ID into its file name.
-- string.format fills in the %s / %d gaps:  %02d means "at least 2 digits,
-- padded with a 0", so 5 becomes "05".
function animation.frameFile(color, id)
    if id <= 16 then
        return string.format("tumble_%s_%02d.png", color, id)
    end
    if id <= 22 then
        return string.format("land_%s_%d.png", color, id - 16)
    end
    -- 1RK or 2RK: the hundreds digit is the direction, then R, then K.
    local dir = (id < 200) and "f" or "r"
    local r = math.floor(id % 100 / 10)   -- e.g. 134 -> 34 -> 3
    local k = id % 10                     -- e.g. 134 -> 4
    return string.format("settle_%s_%s%d_%d.png", color, dir, r, k)
end

-- Every frame ID used by any pattern, each listed once.
-- A table used as a "set": seen[id] = true means we already have that id.
function animation.allFrameIds()
    local seen, list = {}, {}
    for _, byResult in pairs(animation.PATTERNS) do
        for _, pattern in pairs(byResult) do
            for _, id in ipairs(pattern) do
                if not seen[id] then
                    seen[id] = true
                    table.insert(list, id)
                end
            end
        end
    end
    return list
end


---------------------------------------------------------------------------
-- TIMING: each frame stays up a little longer than the one before
---------------------------------------------------------------------------

-- How long frame number k (1-25) stays on screen, in seconds.
--   Frames 1-20 ease from ROLL_FIRST_FRAME_TIME up to ROLL_LAST_SPIN_FRAME_TIME,
--   like a die slowing down.
--   Frames 21-24 (the settle) each last ROLL_SETTLE_FRAME_TIME.
--   Frame 25 is the landed face; it never ends by itself.
local function frameDuration(k)
    if k <= SPIN_FRAMES then
        -- t goes from 0 (first frame) to 1 (frame 20). Squaring it (t * t)
        -- keeps the start fast and makes the slow-down build up at the end.
        local t = (k - 1) / (SPIN_FRAMES - 1)
        return config.ROLL_FIRST_FRAME_TIME
            + (config.ROLL_LAST_SPIN_FRAME_TIME - config.ROLL_FIRST_FRAME_TIME) * t * t
    end
    return config.ROLL_SETTLE_FRAME_TIME
end


-- How long the spinning part (frames 1-20) takes in total. The die's flight
-- across the felt lasts exactly this long, so it lands as it stops spinning.
local function spinTime()
    local total = 0
    for k = 1, SPIN_FRAMES do
        total = total + frameDuration(k)
    end
    return total
end


---------------------------------------------------------------------------
-- EASING: turn a straight 0-to-1 progress into a natural-looking motion
---------------------------------------------------------------------------

-- Fast at first, slowing to a stop (like a thrown die sliding to rest).
local function easeOut(p)
    return 1 - (1 - p) ^ 3
end

-- Slow start, fast middle, slow end (a smooth slide).
local function easeInOut(p)
    if p < 0.5 then
        return 2 * p * p
    end
    return 1 - (-2 * p + 2) ^ 2 / 2
end

-- Blend from a to b. p = 0 gives a, p = 1 gives b, 0.5 is halfway.
local function lerp(a, b, p)
    return a + (b - a) * p
end


---------------------------------------------------------------------------
-- DATA: one small table per die that's moving
---------------------------------------------------------------------------
-- dieState[i] describes die i while it's moving, and is nil once it's back
-- in the tray. Each entry holds:
--   color      - which colour's pictures to use ("white", "red", ...)
--   sequence   - "A", "B" or "C"
--   result     - the face it lands on (1-6), already decided by dice.lua
--   frameIndex - which of the 25 frames is showing (1-25)
--   timer      - seconds the current frame has been showing
--   rolling    - true until frame 25 is reached
-- plus what's needed to MOVE it around the table:
--   phase      - "tumble", "rest" or "return"
--   elapsed    - seconds since this phase started
--   fromX, fromY - its tray slot (centre), where it's thrown from
--   toX, toY   - where it lands on the felt (centre)
--   angle      - how much it's turned when it lands (radians), for a natural scatter
local dieState = {}


---------------------------------------------------------------------------
-- CONTROLS
---------------------------------------------------------------------------

-- Start rolling the dice listed in 'indices', e.g. {1, 3, 4}.
-- 'values' are the real results (dice.values) and 'colors' are the die
-- colours per slot (player.loadout).
function animation.start(indices, values, colors)
    local spots = layout.randomLandingSpots(#indices)
    for n, i in ipairs(indices) do
        local fromX, fromY = layout.traySlotCenter(i)
        dieState[i] = {
            color      = colors[i],
            sequence   = SEQUENCE_FOR_DIE[i],
            result     = values[i],
            frameIndex = 1,
            timer      = 0,
            rolling    = true,
            phase      = "tumble",
            elapsed    = 0,
            fromX = fromX,       fromY = fromY,
            toX   = spots[n].x,  toY   = spots[n].y,
            angle = (love.math.random() - 0.5) * 0.7,   -- about -20 to +20 degrees
        }
    end
end

-- Start rolling all the dice.
function animation.startAll(values, colors)
    local all = {}
    for i = 1, config.NUM_DICE do
        all[i] = i
    end
    animation.start(all, values, colors)
end

-- Stop everything right now (the dice just show their landed faces).
function animation.stop()
    dieState = {}
end

-- Move every moving die forward. Called every frame from love.update.
function animation.update(dt)
    for i, d in pairs(dieState) do
        d.elapsed = d.elapsed + dt

        if d.phase == "tumble" then
            d.timer = d.timer + dt

            -- Time for the next frame? ('while' so a slow frame can skip
            -- ahead more than one picture and the timing stays correct.)
            while d.rolling and d.timer >= frameDuration(d.frameIndex) do
                d.timer = d.timer - frameDuration(d.frameIndex)
                d.frameIndex = d.frameIndex + 1

                if d.frameIndex >= FRAMES_PER_ROLL then
                    d.frameIndex = FRAMES_PER_ROLL   -- landed
                    d.rolling = false
                    d.timer = 0
                    d.phase = "rest"                 -- sit on the felt for a moment
                    d.elapsed = 0
                end
            end

        elseif d.phase == "rest" then
            if d.elapsed >= config.ROLL_REST_TIME then
                d.phase = "return"                   -- slide back to the tray
                d.elapsed = 0
            end

        elseif d.phase == "return" then
            if d.elapsed >= config.ROLL_RETURN_TIME then
                dieState[i] = nil                    -- back in the tray: done
            end
        end
    end
end


---------------------------------------------------------------------------
-- QUESTIONS (draw.lua and main.lua ask these)
---------------------------------------------------------------------------

-- Is die i still moving (tumbling, resting on the felt, or sliding back)?
-- Without an i: is ANY die still moving? Input and scoring wait for this.
function animation.isRolling(i)
    if i then
        return dieState[i] ~= nil
    end
    return next(dieState) ~= nil   -- next() is nil when the table is empty
end

-- Is any die still TUMBLING (not landed yet)?
-- The betting boxes stay dark until every die has landed.
function animation.isTumbling()
    for _, d in pairs(dieState) do
        if d.phase == "tumble" then
            return true
        end
    end
    return false
end

-- Everything needed to draw die i while it's moving, or nil if it's
-- sitting in the tray (then draw.lua draws it there as normal).
-- Returns a table: { color, frameId, x, y (centre), size, angle }.
function animation.getDraw(i)
    local d = dieState[i]
    if d == nil then
        return nil
    end
    local pattern = animation.PATTERNS[d.sequence][d.result]
    local trayS, tableS = config.TRAY_DIE_SIZE, config.TABLE_DIE_SIZE

    if d.phase == "tumble" then
        -- p goes 0 -> 1 over the spinning frames; the die flies with easeOut,
        -- grows from tray size to table size, and hops a little as it goes.
        local p = math.min(1, d.elapsed / spinTime())
        local e = easeOut(p)
        local hop = math.abs(math.sin(p * math.pi * 3)) * (1 - p) * 40
        return {
            color   = d.color,
            frameId = pattern[d.frameIndex],
            x       = lerp(d.fromX, d.toX, e),
            y       = lerp(d.fromY, d.toY, e) - hop,
            size    = lerp(trayS, tableS, math.min(1, p * 3)),
            angle   = d.angle * e,
        }

    elseif d.phase == "rest" then
        return {
            color = d.color, frameId = pattern[FRAMES_PER_ROLL],
            x = d.toX, y = d.toY, size = tableS, angle = d.angle,
        }

    else -- "return"
        local q = easeInOut(math.min(1, d.elapsed / config.ROLL_RETURN_TIME))
        return {
            color   = d.color,
            frameId = pattern[FRAMES_PER_ROLL],
            x       = lerp(d.toX, d.fromX, q),
            y       = lerp(d.toY, d.fromY, q),
            size    = lerp(tableS, trayS, q),
            angle   = lerp(d.angle, 0, q),
        }
    end
end

return animation
