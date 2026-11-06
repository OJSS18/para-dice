-- animation.lua
-- THROWING the dice like a real craps roll: you hold the picked dice under
-- the mouse, fling them, and they fly through the AIR, bounce on the felt,
-- slam into the walls (the back wall's rubber pyramids kick them off at odd
-- angles), knock into each other, then roll out, stop and show their face.
--
-- IMPORTANT: by the time a throw starts, dice.lua has ALREADY picked the
-- real result. This file only moves the dice around and decides which
-- PICTURE to show; every die always settles onto its real result.
-- Nothing in here changes dice.values, so the physics can't change a score.
--
-- HOW THE PHYSICS WORKS
--   * Across the table (left/right, up/down the screen) LÖVE's built-in
--     physics engine (love.physics, which is Box2D) moves the dice and
--     bounces them off the walls, the tray and each other.
--   * HEIGHT off the felt ('z') is worked out here: gravity pulls a flying
--     die down, it bounces on the felt (a bit lower each time), and once
--     it's down it ROLLS, and the felt slows it to a stop.
--   * A die high in the air is drawn higher up the screen and a little
--     bigger, with its shadow left behind on the felt.
--
-- FRAME IDs (each one is a picture in assets/dice/tumble/):
--   1-16   spinning frames (one full loop)       tumble_<color>_01.png ... _16.png
--   17-22  landed, showing face 1-6              land_<color>_1.png ... _6.png
--   1RK    forward settle onto face R, step K    settle_<color>_f<R>_<K>.png   (e.g. 134)
--   2RK    reverse settle onto face R, step K    settle_<color>_r<R>_<K>.png   (e.g. 251)
--
-- Each thrown die goes through these phases:
--   "fly"    - in the air or rolling across the felt, tumbling all the way.
--   "settle" - it's stopped: the 4 settle pictures roll it onto its result.
--   "landed" - showing its face. Once EVERY thrown die has landed, they all
--              sit for a moment, then...
--   "return" - slide back into their tray slots, where they can be picked again.

local config = require("config")
local layout = require("layout")

local animation = {}

local SPIN_FRAMES   = 16   -- frames 1-16 are one full spin
local SETTLE_STEPS  = 4    -- 4 settle pictures, then the landed face
local STOP_SPEED    = 25   -- rolling slower than this (pixels per second) counts as stopped
local STOP_SPIN     = 1.5  -- turning slower than this (radians per second) counts as stopped
local MAX_FLY_TIME  = 7    -- a die still moving after this many seconds settles anyway
local PHYSICS_STEP  = 1 / 120   -- the physics moves in small fixed steps (steadier bounces)
local BODY_FRACTION = 0.82 -- the solid square is this much of the picture's die size
local AIR_SPIN_RATE = 34   -- spin pictures per second while a die is in the air
local SMALL_HOP     = 90   -- a bounce slower than this just stops bouncing (it rolls instead)

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

-- Every frame ID there is: 1-22, then every settle step for every face,
-- both directions.
function animation.allFrameIds()
    local list = {}
    for id = 1, 22 do
        table.insert(list, id)
    end
    for dir = 1, 2 do
        for face = 1, 6 do
            for k = 1, SETTLE_STEPS do
                table.insert(list, dir * 100 + face * 10 + k)
            end
        end
    end
    return list
end


---------------------------------------------------------------------------
-- SMALL HELPERS
---------------------------------------------------------------------------

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

-- A random number between lo and hi.
local function randomBetween(lo, hi)
    return lo + (hi - lo) * love.math.random()
end

-- Either 1 or -1, at random.
local function randomSign()
    return (love.math.random() < 0.5) and -1 or 1
end

-- Turn any angle into the same angle between -pi and pi, so a die that
-- spun round 5 times doesn't spin 5 times back when it returns.
local function wrapAngle(a)
    return (a + math.pi) % (2 * math.pi) - math.pi
end

-- The spin picture (1-16) for a die that has spun 'spin' frames so far.
-- dir = 1 spins forwards (1, 2, 3...), dir = -1 backwards (16, 15, 14...).
local function spinFrame(spin, dir)
    local n = math.floor(spin) % SPIN_FRAMES
    if dir == 1 then
        return n + 1
    end
    return SPIN_FRAMES - n
end

-- Where each die sits in a held handful, as offsets from the mouse.
-- The dice are packed in a little ring so they don't overlap.
local function clusterOffsets(count)
    local s = config.TABLE_DIE_SIZE
    if count == 1 then
        return { { x = 0, y = 0 } }
    end
    local radius = ({ [2] = 0.5, [3] = 0.6, [4] = 0.7, [5] = 0.85 })[count] or 0.9
    local list = {}
    for n = 1, count do
        local a = (n - 1) / count * 2 * math.pi - math.pi / 2
        list[n] = { x = math.cos(a) * radius * s, y = math.sin(a) * radius * s }
    end
    return list
end

-- How far the outside of a handful of 'count' dice reaches from its middle.
local function clusterReach(count)
    local far = 0
    for _, o in ipairs(clusterOffsets(count)) do
        far = math.max(far, math.sqrt(o.x * o.x + o.y * o.y))
    end
    return far + config.TABLE_DIE_SIZE * 0.6
end

-- Move a hold point so the whole handful is on the felt and off the tray.
local function clampHoldPoint(x, y, count)
    local f = layout.felt()
    local reach = clusterReach(count)
    x = math.max(f.x + 10 + reach, math.min(love.graphics.getWidth() - reach, x))
    y = math.max(f.y + reach, math.min(love.graphics.getHeight() - reach, y))

    -- Over the tray? Lift it up above the tray instead.
    local t = layout.tray()
    if x > t.x - reach and x < t.x + t.w + reach and y > t.y - reach then
        y = t.y - reach
    end
    return x, y
end


---------------------------------------------------------------------------
-- DATA
---------------------------------------------------------------------------

-- The physics world (nil when no dice are out on the felt).
local world = nil
local stepLeftover = 0   -- time not yet used up by a physics step

-- Things the dice bumped into during the last physics step. The physics
-- engine tells us about them while it's busy, when we mustn't change any
-- speeds, so we write them down and deal with them straight after.
-- Each is { i = which die, what = "backwall", "wall" or "die" }.
local bumps = {}

-- dieState[i] describes die i while it's out on the felt, and is nil once
-- it's back in the tray. Each entry holds:
--   color, result - which pictures to use, and the face it lands on
--   body          - its physics body (while it's on the felt)
--   phase         - "fly", "settle", "landed" or "return"
--   elapsed       - seconds since this phase started (or since thrown, in "fly")
--   z, vz         - height above the felt, and how fast that's changing (up = +)
--   spin, dir     - how far the spin pictures have turned, and which way
--   step          - which settle picture is showing (1-4)
--   x, y, angle   - where it is and how it's turned (copied from the body)
--   fromX, fromY, fromAngle - where it starts its slide back to the tray
local dieState = {}

-- How long every thrown die has sat landed (they go back to the tray together).
local restTimer = 0

-- The handful of dice under the mouse while the button is held, or nil.
--   indices - which dice, e.g. {1, 3, 4}
--   colors  - their die colours
--   x, y    - the hold point (already kept inside the table)
--   samples - recent mouse positions with times, to measure the throw
local held = nil


---------------------------------------------------------------------------
-- THE TABLE: walls and the tray, for the dice to bounce off
---------------------------------------------------------------------------

-- The physics engine calls this when two things start touching.
-- Each fixture carries a label (its "user data"): a die's number, or a
-- word for a wall. We just note what hit what.
local function beginContact(a, b)
    local la, lb = a:getUserData(), b:getUserData()
    if type(la) == "number" and type(lb) == "number" then
        table.insert(bumps, { i = la, what = "die" })
        table.insert(bumps, { i = lb, what = "die" })
    elseif type(la) == "number" then
        table.insert(bumps, { i = la, what = lb })
    elseif type(lb) == "number" then
        table.insert(bumps, { i = lb, what = la })
    end
end

-- A wall from (x1, y1) to (x2, y2), labelled 'label'.
local function addWall(body, label, x1, y1, x2, y2)
    local fixture = love.physics.newFixture(body, love.physics.newEdgeShape(x1, y1, x2, y2))
    fixture:setRestitution(config.DIE_WALL_BOUNCE)
    fixture:setFriction(0.4)
    fixture:setUserData(label)
end

local function buildWorld()
    love.physics.setMeter(64)                 -- 64 pixels = 1 metre for the physics
    world = love.physics.newWorld(0, 0, true) -- no sideways gravity: we look DOWN at the table
    world:setCallbacks(beginContact)
    stepLeftover = 0
    bumps = {}

    -- The walls: the far (north) wall with its rubber pyramids, the west
    -- wall, and the screen's right and bottom edges.
    local f = layout.felt()
    local left, top = f.x + 8, f.y
    local right, bottom = love.graphics.getWidth(), love.graphics.getHeight()
    local walls = love.physics.newBody(world, 0, 0, "static")
    addWall(walls, "backwall", left, top, right, top)
    addWall(walls, "wall", right, top, right, bottom)
    addWall(walls, "wall", right, bottom, left, bottom)
    addWall(walls, "wall", left, bottom, left, top)

    -- The dice tray sticks up off the felt, so dice bounce off it too.
    local t = layout.tray()
    local trayH = t.h + 10   -- including its front face
    local tray = love.physics.newBody(world, t.x + t.w / 2, t.y + trayH / 2, "static")
    local trayFixture = love.physics.newFixture(tray, love.physics.newRectangleShape(t.w, trayH))
    trayFixture:setRestitution(config.DIE_WALL_BOUNCE)
    trayFixture:setUserData("wall")
end

-- Make a physics die for die number i at (x, y), moving at (vx, vy) and
-- turning at 'turn'.
local function newDieBody(i, x, y, angle, vx, vy, turn)
    local size = config.TABLE_DIE_SIZE * BODY_FRACTION
    local body = love.physics.newBody(world, x, y, "dynamic")
    local fixture = love.physics.newFixture(body, love.physics.newRectangleShape(size, size), 1)
    fixture:setRestitution(0.5)
    fixture:setFriction(0.3)
    fixture:setUserData(i)
    body:setAngle(angle)
    body:setLinearVelocity(vx, vy)
    body:setAngularVelocity(turn)
    body:setLinearDamping(0)
    body:setAngularDamping(0.3)
    body:setBullet(true)   -- checked extra carefully so fast dice can't skip through a wall
    return body
end


---------------------------------------------------------------------------
-- CONTROLS
---------------------------------------------------------------------------

-- Pick up the dice listed in 'indices' into a handful under the mouse.
-- 'colors' are the die colours per slot (player.loadout).
function animation.grab(indices, colors, x, y)
    if #indices == 0 then
        return
    end
    local hx, hy = clampHoldPoint(x, y, #indices)
    local list = {}
    for n, i in ipairs(indices) do
        list[n] = i
    end
    held = {
        indices = list,
        colors  = colors,
        x = hx, y = hy,
        samples = { { t = love.timer.getTime(), x = x, y = y } },
    }
end

-- The mouse moved while holding: the handful follows it.
function animation.moveHold(x, y)
    if held == nil then
        return
    end
    held.x, held.y = clampHoldPoint(x, y, #held.indices)
    table.insert(held.samples, { t = love.timer.getTime(), x = x, y = y })
    -- Only the last moment matters; don't let the list grow forever.
    if #held.samples > 60 then
        table.remove(held.samples, 1)
    end
end

-- How fast the mouse has been moving just before letting go, for the
-- handful 'h'. A flick gives a big speed; holding still gives 0.
local function heldVelocity(h)
    local now = love.timer.getTime()
    local samples = h.samples
    local last = samples[#samples]
    -- The mouse hasn't moved for a while: no speed at all.
    if now - last.t > 0.12 then
        return 0, 0
    end
    local first = last
    for n = #samples, 1, -1 do
        if now - samples[n].t > 0.12 then
            break
        end
        first = samples[n]
    end
    local time = math.max(1 / 60, last.t - first.t)
    return (last.x - first.x) / time, (last.y - first.y) / time
end

-- Is a handful being held? Which dice are in it?
function animation.isHolding()
    return held ~= nil
end

function animation.heldIndices()
    return held and held.indices or {}
end

-- Drop the handful without throwing (e.g. the throw wasn't allowed).
function animation.cancelHold()
    held = nil
end

-- Send the dice listed in 'indices' flying from (x, y) in direction
-- (dirX, dirY) at 'speed'. 'values' are their real results.
local function launch(indices, values, colors, x, y, dirX, dirY, speed)
    if world == nil then
        buildWorld()
    end
    restTimer = 0

    local offsets = clusterOffsets(#indices)
    local baseAngle = math.atan2(dirY, dirX)
    for n, i in ipairs(indices) do
        -- Every die goes a little off the line of the throw, a little
        -- faster or slower, and spins its own way - like a real handful.
        local spread = math.rad(config.THROW_SPREAD_DEGREES)
        local a = baseAngle + randomBetween(-spread, spread)
        local s = speed * randomBetween(1 - config.THROW_SPEED_SPREAD, 1 + config.THROW_SPEED_SPREAD)
        local turn = randomBetween(4, 12) * randomSign()
        local startAngle = randomBetween(-0.4, 0.4)
        local body = newDieBody(i, x + offsets[n].x, y + offsets[n].y, startAngle,
            math.cos(a) * s, math.sin(a) * s, turn)

        dieState[i] = {
            color   = colors[i],
            result  = values[i],
            body    = body,
            phase   = "fly",
            elapsed = 0,
            z       = config.THROW_RELEASE_HEIGHT,
            vz      = config.THROW_RELEASE_LIFT * randomBetween(0.8, 1.2),
            spin    = love.math.random() * SPIN_FRAMES,
            dir     = randomSign(),
            step    = 1,
            x = body:getX(), y = body:getY(), angle = startAngle,
        }
    end
end

-- Let go of the handful: throw it the way the mouse was moving.
-- 'values' are the real results (dice.values), already decided.
-- If the mouse wasn't moving, they're tossed at the far wall, like a
-- craps shooter is supposed to.
function animation.release(values)
    if held == nil then
        return
    end
    local h = held
    held = nil

    local vx, vy = heldVelocity(h)
    local speed = math.sqrt(vx * vx + vy * vy) * config.THROW_FLICK_BOOST
    if speed < 400 then
        -- Barely moving: toss them at the back wall.
        local cx = layout.logoCenter()
        vx, vy = (cx - h.x) * 0.3, -(h.y - layout.felt().y)
        speed = config.THROW_AUTO_SPEED
    end
    speed = math.max(config.THROW_MIN_SPEED, math.min(config.THROW_MAX_SPEED, speed))
    launch(h.indices, values, h.colors, h.x, h.y, vx, vy, speed)
end

-- Throw the dice in 'indices' without dragging (THROW / REROLL button, or
-- Enter): from just above the tray, hard at the back wall.
function animation.autoThrow(indices, values, colors)
    if #indices == 0 then
        return
    end
    local t = layout.tray()
    local x, y = clampHoldPoint(t.x + t.w + 60, t.y, #indices)
    local f = layout.felt()
    local tx = x + randomBetween(0.05, 0.35) * f.w   -- somewhere along the back wall
    launch(indices, values, colors, x, y, tx - x, f.y - y,
        config.THROW_AUTO_SPEED * randomBetween(0.9, 1.1))
end

-- Stop everything right now (the dice just show their faces in the tray).
function animation.stop()
    dieState = {}
    held = nil
    bumps = {}
    if world then
        world:destroy()
        world = nil
    end
end


---------------------------------------------------------------------------
-- EVERY FRAME
---------------------------------------------------------------------------

-- A die bumped into something: real dice don't just slide off - they kick
-- up, tumble the other way, and (off the back wall's rubber pyramids)
-- fly off at an odd angle.
local function react(d, what)
    if d.phase ~= "fly" then
        return
    end
    local body = d.body
    if what == "backwall" then
        -- The pyramids: knock it up into the air and off at a random angle.
        local vx, vy = body:getLinearVelocity()
        local turnBy = randomBetween(-0.45, 0.45)
        local c, s = math.cos(turnBy), math.sin(turnBy)
        body:setLinearVelocity(vx * c - vy * s, vx * s + vy * c)
        if d.z < 40 then
            d.vz = math.max(d.vz, randomBetween(350, 650))
        end
        body:setAngularVelocity(randomBetween(6, 14) * randomSign())
        d.dir = randomSign()
    elseif what == "wall" then
        if d.z < 20 then
            d.vz = math.max(d.vz, randomBetween(120, 300))
        end
        body:setAngularVelocity(body:getAngularVelocity() + randomBetween(-6, 6))
    elseif what == "die" then
        if d.z < 20 then
            d.vz = math.max(d.vz, randomBetween(80, 220))
        end
        body:setAngularVelocity(body:getAngularVelocity() + randomBetween(-5, 5))
        d.dir = randomSign()
    end
end

-- One small physics step for one flying die: its height, and the felt
-- slowing it down while it rolls.
local function stepHeight(d, dt)
    local body = d.body
    if d.z > 0 or d.vz > 0 then
        -- In the air: gravity pulls it down.
        d.vz = d.vz - config.DIE_GRAVITY * dt
        d.z = d.z + d.vz * dt
        if d.z <= 0 then
            -- It hit the felt: bounce (lower each time), and the felt grabs
            -- at it, slowing it and changing its spin.
            d.z = 0
            local bounce = -d.vz * config.DIE_FELT_BOUNCE
            if bounce > SMALL_HOP then
                d.vz = bounce
            else
                d.vz = 0          -- too small to bounce: it rolls from here
            end
            local vx, vy = body:getLinearVelocity()
            local keep = config.DIE_BOUNCE_SLOWDOWN
            body:setLinearVelocity(vx * keep, vy * keep)
            body:setAngularVelocity(body:getAngularVelocity() * 0.7 + randomBetween(-3, 3))
        end
    else
        -- Rolling on the felt: the felt slows it down to a stop.
        local vx, vy = body:getLinearVelocity()
        local speed = math.sqrt(vx * vx + vy * vy)
        if speed > 0 then
            local loss = (config.DIE_ROLL_FRICTION + config.DIE_ROLL_DRAG * speed) * dt
            local slower = math.max(0, speed - loss) / speed
            body:setLinearVelocity(vx * slower, vy * slower)
        end
        local turn = body:getAngularVelocity()
        body:setAngularVelocity(turn * math.max(0, 1 - 4 * dt))
    end
end

-- Bring a flying die to a stop and start its settle pictures.
-- While it settles it also turns square to the screen, so the face it
-- lands on looks straight at you.
local function startSettle(d)
    d.z, d.vz = 0, 0
    d.settleFromAngle = wrapAngle(d.body:getAngle())
    d.body:setLinearVelocity(0, 0)
    d.body:setAngularVelocity(0)
    d.body:setAngle(0)
    d.body:setType("static")   -- it stays put; other dice bounce off it
    d.phase = "settle"
    d.elapsed = 0
    d.step = 1
end

-- Move every die forward. Called every frame from love.update.
function animation.update(dt)
    -- The physics, in small fixed steps. (Capped, so a hiccup in the frame
    -- rate can't fire the dice through a wall.)
    if world then
        stepLeftover = stepLeftover + math.min(dt, 0.1)
        while stepLeftover >= PHYSICS_STEP do
            for _, d in pairs(dieState) do
                if d.phase == "fly" then
                    stepHeight(d, PHYSICS_STEP)
                end
            end
            world:update(PHYSICS_STEP)
            -- Now the engine's done with this step, react to the bumps.
            for _, bump in ipairs(bumps) do
                local d = dieState[bump.i]
                if d then
                    react(d, bump.what)
                end
            end
            bumps = {}
            stepLeftover = stepLeftover - PHYSICS_STEP
        end
    end

    local allLanded = next(dieState) ~= nil
    for i, d in pairs(dieState) do
        d.elapsed = d.elapsed + dt

        if d.body and not d.body:isDestroyed() then
            d.x, d.y = d.body:getX(), d.body:getY()
            d.angle = d.body:getAngle()
        end

        if d.phase == "fly" then
            local vx, vy = d.body:getLinearVelocity()
            local speed = math.sqrt(vx * vx + vy * vy)
            if d.z > 0 then
                -- Tumbling through the air.
                d.spin = d.spin + AIR_SPIN_RATE * dt
            else
                -- Rolling: it turns over once (4 pictures) for every die
                -- length it rolls, so it looks like it's really rolling.
                d.spin = d.spin + speed * dt / (config.TABLE_DIE_SIZE / 4)
            end
            local turning = math.abs(d.body:getAngularVelocity())
            local stopped = d.z <= 0 and d.vz <= 0 and speed < STOP_SPEED and turning < STOP_SPIN
            if stopped or d.elapsed > MAX_FLY_TIME then
                startSettle(d)
            end

        elseif d.phase == "settle" then
            if d.elapsed >= config.ROLL_SETTLE_FRAME_TIME then
                d.elapsed = d.elapsed - config.ROLL_SETTLE_FRAME_TIME
                d.step = d.step + 1
                if d.step > SETTLE_STEPS then
                    d.phase = "landed"
                    d.elapsed = 0
                end
            end

        elseif d.phase == "return" then
            if d.elapsed >= config.ROLL_RETURN_TIME then
                dieState[i] = nil                    -- back in the tray: done
            end
        end

        if d.phase ~= "landed" then
            allLanded = false
        end
    end

    -- Every thrown die has landed: let them sit a moment, then send them
    -- all back to the tray and put the physics away.
    if allLanded then
        restTimer = restTimer + dt
        if restTimer >= config.ROLL_REST_TIME then
            for _, d in pairs(dieState) do
                d.phase = "return"
                d.elapsed = 0
                d.fromX, d.fromY = d.x, d.y
                d.fromAngle = wrapAngle(d.angle)
                d.body = nil
            end
            if world then
                world:destroy()
                world = nil
            end
        end
    end
end


---------------------------------------------------------------------------
-- QUESTIONS (draw.lua and main.lua ask these)
---------------------------------------------------------------------------

-- Is die i out on the felt (flying, landed, or sliding back)?
-- Without an i: is ANY die out? Input and scoring wait for this.
function animation.isRolling(i)
    if i then
        return dieState[i] ~= nil
    end
    return next(dieState) ~= nil   -- next() is nil when the table is empty
end

-- Is any die still moving or settling (not landed yet)?
-- The betting boxes stay dark until every die has landed.
function animation.isTumbling()
    for _, d in pairs(dieState) do
        if d.phase == "fly" or d.phase == "settle" then
            return true
        end
    end
    return false
end

-- Everything needed to draw die i while it's held or out on the felt, or
-- nil if it's sitting in the tray (then draw.lua draws it there as normal).
-- Returns a table: { color, frameId, x, y, z, size, angle }.
-- (x, y) is the spot on the felt under the die (where its shadow goes);
-- z is how high above that spot it is.
function animation.getDraw(i)
    local tableS, trayS = config.TABLE_DIE_SIZE, config.TRAY_DIE_SIZE

    -- In the handful under the mouse: jiggling, rattling through the spin
    -- pictures like dice shaken in a hand.
    if held then
        for n, j in ipairs(held.indices) do
            if j == i then
                local o = clusterOffsets(#held.indices)[n]
                local t = love.timer.getTime()
                return {
                    color   = held.colors[i],
                    frameId = spinFrame(t * 14 + n * 3, (n % 2 == 0) and 1 or -1),
                    x       = held.x + o.x + math.sin(t * 31 + n * 2) * 2,
                    y       = held.y + o.y + math.cos(t * 27 + n) * 2,
                    z       = config.THROW_RELEASE_HEIGHT,
                    size    = tableS,
                    angle   = math.sin(t * 9 + n) * 0.12,
                }
            end
        end
    end

    local d = dieState[i]
    if d == nil then
        return nil
    end

    if d.phase == "fly" then
        return { color = d.color, frameId = spinFrame(d.spin, d.dir),
            x = d.x, y = d.y, z = d.z, size = tableS, angle = d.angle }

    elseif d.phase == "settle" then
        local frameId = (d.dir == 1 and 100 or 200) + d.result * 10 + d.step
        -- p goes 0 -> 1 across the 4 settle pictures; the die turns square as it goes.
        local p = math.min(1, ((d.step - 1) + d.elapsed / config.ROLL_SETTLE_FRAME_TIME) / SETTLE_STEPS)
        return { color = d.color, frameId = frameId,
            x = d.x, y = d.y, z = 0, size = tableS,
            angle = lerp(d.settleFromAngle, 0, easeInOut(p)) }

    elseif d.phase == "landed" then
        -- Square to the screen: the face looks straight at you.
        return { color = d.color, frameId = animation.landedFrameId(d.result),
            x = d.x, y = d.y, z = 0, size = tableS, angle = 0 }

    else -- "return"
        local q = easeInOut(math.min(1, d.elapsed / config.ROLL_RETURN_TIME))
        local toX, toY = layout.traySlotCenter(i)
        return {
            color   = d.color,
            frameId = animation.landedFrameId(d.result),
            x       = lerp(d.fromX, toX, q),
            y       = lerp(d.fromY, toY, q),
            z       = 0,
            size    = lerp(tableS, trayS, q),
            angle   = lerp(d.fromAngle, 0, q),
        }
    end
end

return animation
