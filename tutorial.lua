-- tutorial.lua
-- The TUTORIAL ("START WITH TUTORIAL" on the title screen). It plays over
-- a real game: the first two rounds of level 1, then a quick tour of the
-- shop the first time you get there.
--
-- Each STEP shines a spotlight on part of the screen (everything else is
-- dimmed), points a bouncing gold arrow at it, and explains it in a box.
-- There are two kinds of step:
--   "next"   - just reading: press NEXT (or Enter / Space) to carry on.
--              The game underneath ignores your clicks and keys.
--   "action" - you have to DO something (place a chip, throw, hold dice...).
--              The game works as normal, and the step finishes by itself
--              once its 'done' check is true.
--
-- So the lesson always shows the same things, the tutorial sets what some
-- throws land on (dice.rig) - like a dealer setting up a demo table.
--
-- main.lua calls tutorial.update / draw / keypressed / mousepressed.

local layout   = require("layout")
local dice     = require("dice")
local score    = require("score")
local markers  = require("markers")
local luck     = require("luck")
local luckrack = require("luckrack")
local shop     = require("shop")
local animation = require("animation")
local fonts    = require("fonts")
local ui       = require("ui")
local util     = require("util")

local tutorial = {}

tutorial.active = false   -- is a tutorial running?
local k = 1               -- which step we're on
local started = {}        -- started[n] = true once step n's 'start' has run
local state = "start"     -- main.lua's screen, kept up to date by tutorial.update

local GOLD  = { 1, 0.85, 0.25 }
local CREAM = { 1, 0.96, 0.88 }

local BOX_W = 440
local PAD = 8             -- spotlight padding around a target


---------------------------------------------------------------------------
-- TARGETS (the parts of the screen a step can shine its spotlight on)
---------------------------------------------------------------------------

local rect = util.rect

local T = {}

function T.levelScore()
    local c = layout.bannerContent()
    return rect(c.x - 6, c.y - 4, c.w + 12, 112)
end

function T.points()
    return layout.placeGrid()
end

function T.moneyMakers()
    local p = layout.propPanel()
    return rect(p.x, p.y - 24, p.w, p.h + 24)   -- include the MONEY MAKERS title
end

function T.markerArea()
    local g, p = layout.placeGrid(), T.moneyMakers()
    return { g, p }
end

function T.rollButton()
    return layout.rerollButton()
end

function T.keepButton()
    return layout.keepButton()
end

function T.bothButtons()
    local r, kb = layout.rerollButton(), layout.keepButton()
    return rect(r.x, r.y, r.w, kb.y + kb.h - r.y)
end

function T.throwArea()
    local z, t = layout.landingZone(), layout.tray()
    return rect(t.x, z.y, z.x + z.w - t.x, t.y + t.h - z.y)
end

function T.tray()
    local t = layout.tray()
    return rect(t.x, t.y - 34, t.w, t.h + 34)   -- include the REROLL tag above it
end

function T.scoreLine()
    return layout.scoreLine()
end

-- The round result in the banner (under the info rows).
function T.roundResult()
    local c = layout.bannerContent()
    return rect(c.x - 6, c.y + 290, c.w + 12, math.min(230, layout.rerollButton().y - (c.y + 290) - 10))
end

function T.luckRack()
    return luckrack.rect()
end

-- The POINTS tile the first round landed on (it now has Run it Back's boost).
function T.boostedTile()
    local first = score.history[1]
    local sum = first and first.sum or 17
    return layout.placeBox(sum - 4)
end

function T.shopCards()
    local a, b = shop.windowRect(1), shop.windowRect(2)
    return rect(a.x, a.y - 16, b.x + b.w - a.x, a.h + 16)
end

function T.machine()
    local m = shop.machineRect()
    return rect(m.x - 12, m.y - 12, m.w + 40, m.h + 24)
end

function T.yourLuck()
    local r = shop.luckRect()
    return rect(r.x, r.y - 16, r.w, r.h + 16)
end

function T.markersAndContinue()
    local a, b = shop.markersRect(), shop.continueRect()
    return rect(a.x, a.y - 16, a.w, b.y + b.h - a.y + 16)
end


---------------------------------------------------------------------------
-- THE STEPS
---------------------------------------------------------------------------
-- Each step:
--   title, text  - what the box says ('text' can be a function, for words
--                  that depend on what just happened)
--   target       - a function from T giving the rect(s) to spotlight (nil = none)
--   kind         - "next" or "action"
--   done         - for "action": a function that's true once it's been done
--   start        - optional: runs once, when the step begins (rigs dice)
--   screen       - the step only shows on this screen (main.lua's state)

local function landed()
    return state == "play" and dice.allThrown() and not animation.isRolling()
end

local function heldCount()
    local n = 0
    for i = 1, 5 do
        if dice.held[i] then n = n + 1 end
    end
    return n
end

local STEPS = {
    -- LEVEL 1, before the first roll
    { screen = "placeMarker", kind = "next", target = T.levelScore,
      title = "WELCOME TO PARA-DICE!",
      text = "Each level is 5 ROUNDS. Score enough POINTS to reach the target (SCORE/TARGET up here) "
          .. "and you clear the level. 10 levels beat the house." },
    { screen = "placeMarker", kind = "next", target = T.points,
      title = "POINTS",
      text = "Every round you throw 5 dice and ADD THEM UP. The sum (5 to 30) lands on one of these tiles. "
          .. "Rare sums - very low or very high - pay the most." },
    { screen = "placeMarker", kind = "next", target = T.moneyMakers,
      title = "MONEY MAKERS",
      text = "Some rolls also make a HAND - like a Full House or a Straight. Hands pay COINS, "
          .. "and coins are what you spend in the shop between levels." },
    { screen = "placeMarker", kind = "action", target = T.markerArea,
      title = "PLACE YOUR MARKER",
      text = "Before each level you put a white chip on any tile. If your roll hits it, it pays x1.5. "
          .. "Click any POINTS or MONEY MAKER tile now.",
      done = function() return markers.allPlaced() end },
    { screen = "placeMarker", kind = "action", target = T.rollButton,
      title = "LET'S ROLL",
      text = "Press ROLL to start the level. (On a keyboard, Enter starts AND throws in one go.)",
      start = function() dice.rig = { 3, 3, 3, 5, 5 } end,
      done = function() return state == "play" end },

    -- ROUND 1
    { screen = "play", kind = "action", target = T.throwArea,
      title = "THROW THE DICE",
      text = "Hold the mouse down on the felt, fling, and let go - the dice fly across the table. "
          .. "Or just press THROW / Enter.",
      start = function()
          if not dice.allThrown() then dice.rig = { 3, 3, 3, 5, 5 } end
      end,
      done = landed },
    { screen = "play", kind = "next", target = T.scoreLine,
      title = "HOW IT SCORES",
      text = function()
          return "3 + 3 + 3 + 5 + 5 = " .. dice.total .. ", so you landed on the " .. dice.total
              .. " tile. This line spells out the maths: the tile's points x every bonus that applies."
      end },
    { screen = "play", kind = "next", target = T.moneyMakers,
      title = "A FULL HOUSE!",
      text = "Three 3s and two 5s is a FULL HOUSE - its box lights up and it'll pay 25 coins. "
          .. "If a roll makes more than one hand, you're paid for the best one." },
    { screen = "play", kind = "next", target = T.bothButtons,
      title = "REROLL OR KEEP?",
      text = "Every round you get ONE reroll: hold the dice you like and throw the rest again. "
          .. "Or press KEEP to stop - keeping WITHOUT rerolling pays x1.1." },
    { screen = "play", kind = "action", target = T.keepButton,
      title = "KEEP IT",
      text = "That's a great roll - don't push your luck. Press KEEP (or K).",
      done = function() return state == "roundOver" end },
    { screen = "roundOver", kind = "next", target = T.roundResult,
      title = "ROUND 1 DONE",
      text = function()
          local r = score.lastRound
          if r == nil then return "Here's how the round scored." end
          return "Here's the breakdown: " .. r.points .. " points and " .. r.coins
              .. " coins. Everything that boosted your score is listed here."
      end },
    { screen = "roundOver", kind = "action", target = T.rollButton,
      title = "NEXT ROUND",
      text = "Press NEXT ROUND (Space). Or press Enter to skip the fling and throw straight away.",
      start = function() dice.rig = { 6, 2, 6, 1, 6 } end,
      done = function() return state == "play" end },

    -- ROUND 2
    { screen = "play", kind = "action", target = T.throwArea,
      title = "THROW AGAIN",
      text = "Fling the dice (or press THROW / Enter).",
      start = function()
          if not dice.allThrown() then dice.rig = { 6, 2, 6, 1, 6 } end
      end,
      done = landed },
    { screen = "play", kind = "action", target = T.tray,
      title = "HOLD THE GOOD ONES",
      text = "Three 6s! Click the three 6s in the tray to HOLD them (or press 1, 3 and 5). "
          .. "Held dice stay put when you reroll.",
      start = function() dice.rig = { 6, 4, 6, 5, 6 } end,
      done = function() return heldCount() >= 1 end },
    { screen = "play", kind = "action", target = T.throwArea,
      title = "NOW REROLL",
      text = "Hold as many as you like, then fling the rest - or press REROLL / Enter. "
          .. "Only the dice that AREN'T held get thrown.",
      done = function() return state == "roundOver" end },
    { screen = "roundOver", kind = "next", target = T.roundResult,
      title = "NICE REROLL!",
      text = function()
          local r = score.lastRound
          local hand = r and r.hand and (" Your " .. r.hand .. " paid coins too.") or ""
          local big = (r and (r.winBonus or 0) > 0)
              and " A huge round like that is a BIG WIN - bonus coins!"
              or " A round worth 40% of the target is a BIG WIN, which pays bonus coins."
          return "That reroll landed on " .. (r and r.sum or "?") .. " for " .. (r and r.points or "?")
              .. " points." .. hand .. big
      end },
    { screen = "roundOver", kind = "next", target = T.luckRack,
      title = "LUCK ITEMS",
      text = "These are your LUCK ITEMS - permanent perks. You start with Run it Back. Hover one to see "
          .. "what it does. You can hold 3, and SELL them for coins any time." },
    { screen = "roundOver", kind = "next", target = T.boostedTile,
      title = "BOOSTS STICK",
      text = "Run it Back gives every point you hit another x1.1 for the rest of the run - so the tile "
          .. "you landed on in round 1 is now worth more (its number glows gold)." },
    { screen = "roundOver", kind = "next", target = nil,
      title = "YOU'VE GOT IT!",
      text = "Play out the last 3 rounds of the level yourself. Reach the target and you're off to the "
          .. "SHOP - the tutorial will show you around when you get there. Good luck!" },

    -- THE SHOP (the first time you get there)
    { screen = "shop", kind = "next", target = T.shopCards,
      title = "THE SHOP",
      text = "Between levels you spend coins here. DICE have different odds (click one to buy, then "
          .. "swap it into YOUR DICE). UPGRADES boost groups of points for the whole run." },
    { screen = "shop", kind = "next", target = T.machine,
      title = "THE MYSTERY MACHINE",
      text = "This is the ONLY way to get new luck items. A spin costs 30 coins and lands 3 random items "
          .. "- click a reel to keep ONE of them. Rarer items are stronger." },
    { screen = "shop", kind = "next", target = T.yourLuck,
      title = "YOUR LUCK",
      text = "Your luck items live here - up to 3. They never wear off. If you're full and want a new one, "
          .. "SELL one first (it pays half its value)." },
    { screen = "shop", kind = "next", target = T.markersAndContinue,
      title = "READY?",
      text = "MARKERS buys extra chips to place each level. When you're done, press CONTINUE for the next "
          .. "level. That's the tutorial - have fun!" },
}


---------------------------------------------------------------------------
-- RUNNING IT
---------------------------------------------------------------------------

function tutorial.start()
    tutorial.active = true
    k = 1
    started = {}
end

function tutorial.stop()
    tutorial.active = false
    dice.rig = nil
end

-- The step showing right now, or nil (none running, or it's waiting for
-- another screen - like the shop steps while you play out the level).
local function current()
    if not tutorial.active then return nil end
    local step = STEPS[k]
    if step == nil or step.screen ~= state then return nil end
    return step
end

local function advance()
    k = k + 1
    if STEPS[k] == nil then
        tutorial.stop()
    end
end

-- Call every frame with main.lua's current screen.
function tutorial.update(screen)
    state = screen
    if not tutorial.active then return end
    -- The game ended (or a new one started) before the tutorial finished.
    if screen == "gameOver" or screen == "victory" or screen == "start" then
        tutorial.stop()
        return
    end
    local step = STEPS[k]
    if step == nil then return end
    if step.screen == state and not started[k] then
        started[k] = true
        if step.start then step.start() end
    end
    -- An action step counts as done even if doing it moved the game on to
    -- another screen (pressing ROLL leaves the marker screen, for example).
    if step.kind == "action" and started[k] and step.done() then
        advance()
    end
end


---------------------------------------------------------------------------
-- LAYOUT OF THE BOX
---------------------------------------------------------------------------

-- The step's targets as a list of rects.
local function targetsOf(step)
    if step.target == nil then return {} end
    local t = step.target()
    if t.x then return { t } end
    return t
end

-- One rect around all of a step's targets.
local function bounds(list)
    local x1, y1, x2, y2 = math.huge, math.huge, -math.huge, -math.huge
    for _, r in ipairs(list) do
        x1, y1 = math.min(x1, r.x), math.min(y1, r.y)
        x2, y2 = math.max(x2, r.x + r.w), math.max(y2, r.y + r.h)
    end
    return rect(x1, y1, x2 - x1, y2 - y1)
end

local function textOf(step)
    if type(step.text) == "function" then return step.text() end
    return step.text
end

-- Where the explanation box goes: beside the target, on whichever side has
-- the most room (or in the middle of the screen if there's no target).
local function boxRect(step)
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local _, lines = fonts.small:getWrap(textOf(step), BOX_W - 32)
    local h = 50 + #lines * fonts.small:getHeight() + (step.kind == "next" and 64 or 46)

    local list = targetsOf(step)
    if #list == 0 then
        return rect((W - BOX_W) / 2, (H - h) / 2, BOX_W, h)
    end
    local t = bounds(list)
    local gap = 85     -- room between the target and the box, for the arrow
    local spaces = {
        below = H - (t.y + t.h), above = t.y,
        right = W - (t.x + t.w), left = t.x,
    }
    local x, y
    if spaces.below >= h + gap or spaces.above >= h + gap then
        if spaces.below >= spaces.above then
            y = t.y + t.h + gap
        else
            y = t.y - gap - h
        end
        x = t.x + t.w / 2 - BOX_W / 2
    elseif spaces.right >= spaces.left then
        x, y = t.x + t.w + gap, t.y + t.h / 2 - h / 2
    else
        x, y = t.x - gap - BOX_W, t.y + t.h / 2 - h / 2
    end
    x = util.clamp(x, 12, W - BOX_W - 12)
    y = util.clamp(y, 46, H - h - 12)
    return rect(x, y, BOX_W, h)
end

local function nextButtonRect(box)
    return rect(box.x + box.w - 170, box.y + box.h - 52, 154, 40)
end

-- SKIP TUTORIAL, at the top of the screen (just right of the banner).
local function skipRect()
    return rect(layout.banner().w + 30, 6, 190, 30)
end

local function drawSkipButton()
    local s = skipRect()
    ui.glossyButton(s, "", { 0.35, 0.35, 0.4 }, true)
    ui.text("SKIP TUTORIAL", fonts.hint, s.x, s.y + 8, s.w, "center", CREAM)
end


---------------------------------------------------------------------------
-- DRAWING
---------------------------------------------------------------------------

-- A gold arrow from (x1, y1) to (x2, y2), bobbing towards its tip.
local function drawArrow(x1, y1, x2, y2)
    local angle = math.atan2(y2 - y1, x2 - x1)
    local bob = math.sin(love.timer.getTime() * 6) * 6
    x2, y2 = x2 - math.cos(angle) * (10 + bob), y2 - math.sin(angle) * (10 + bob)
    local head = 22
    local bx, by = x2 - math.cos(angle) * head, y2 - math.sin(angle) * head
    local px, py = math.cos(angle + math.pi / 2) * 13, math.sin(angle + math.pi / 2) * 13

    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.setLineWidth(11)
    love.graphics.line(x1, y1, bx, by)
    love.graphics.polygon("fill", x2 + 2, y2 + 2, bx + px * 1.25, by + py * 1.25, bx - px * 1.25, by - py * 1.25)
    love.graphics.setColor(GOLD)
    love.graphics.setLineWidth(7)
    love.graphics.line(x1, y1, bx, by)
    love.graphics.polygon("fill", x2, y2, bx + px, by + py, bx - px, by - py)
    love.graphics.setLineWidth(1)
end

-- The point on rect r's edge closest to (px, py).
local function edgePoint(r, px, py)
    local cx, cy = r.x + r.w / 2, r.y + r.h / 2
    local dx, dy = px - cx, py - cy
    if dx == 0 and dy == 0 then return cx, cy end
    local sx = (r.w / 2) / math.max(1e-6, math.abs(dx))
    local sy = (r.h / 2) / math.max(1e-6, math.abs(dy))
    local s = math.min(sx, sy)
    return cx + dx * s, cy + dy * s
end

function tutorial.draw()
    local step = current()
    if step == nil then
        -- Still running, just waiting for another screen: keep SKIP up.
        if tutorial.active and state ~= "start" then
            drawSkipButton()
        end
        return
    end
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local list = targetsOf(step)

    -- 1. Dim everything EXCEPT the targets. A stencil marks the targets,
    --    then the dark layer is only drawn where the stencil is empty.
    love.graphics.stencil(function()
        for _, r in ipairs(list) do
            love.graphics.rectangle("fill", r.x - PAD, r.y - PAD, r.w + 2 * PAD, r.h + 2 * PAD, 12, 12)
        end
    end, "replace", 1)
    love.graphics.setStencilTest("equal", 0)
    love.graphics.setColor(0, 0, 0, 0.72)
    love.graphics.rectangle("fill", 0, 0, W, H)
    love.graphics.setStencilTest()

    -- 2. A glowing gold outline round each target.
    local pulse = 0.6 + 0.4 * math.sin(love.timer.getTime() * 4)
    for _, r in ipairs(list) do
        love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.35 * pulse)
        love.graphics.setLineWidth(10)
        love.graphics.rectangle("line", r.x - PAD, r.y - PAD, r.w + 2 * PAD, r.h + 2 * PAD, 12, 12)
        love.graphics.setColor(GOLD)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", r.x - PAD, r.y - PAD, r.w + 2 * PAD, r.h + 2 * PAD, 12, 12)
    end
    love.graphics.setLineWidth(1)

    -- 3. The explanation box, and an arrow from it to the (first) target.
    local box = boxRect(step)
    if #list > 0 then
        local t = list[1]
        local tr = rect(t.x - PAD, t.y - PAD, t.w + 2 * PAD, t.h + 2 * PAD)
        local tx, ty = edgePoint(tr, box.x + box.w / 2, box.y + box.h / 2)
        local bx, by = edgePoint(box, tx, ty)
        local dx, dy = tx - bx, ty - by
        if dx * dx + dy * dy > 30 * 30 then
            drawArrow(bx, by, tx, ty)
        end
    end

    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", box.x + 4, box.y + 6, box.w, box.h, 14, 14)
    love.graphics.setColor(0.12, 0.04, 0.08, 0.98)
    love.graphics.rectangle("fill", box.x, box.y, box.w, box.h, 14, 14)
    love.graphics.setColor(GOLD)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", box.x, box.y, box.w, box.h, 14, 14)
    love.graphics.setLineWidth(1)

    ui.text(step.title, fonts.heading, box.x + 16, box.y + 14, box.w - 32, "left", GOLD, true)
    local count = "TUTORIAL " .. k .. "/" .. #STEPS
    ui.text(count, fonts.hint, box.x + 16, box.y + 16, box.w - 32, "right", { 1, 1, 1, 0.45 })
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(CREAM)
    love.graphics.printf(textOf(step), box.x + 16, box.y + 44, box.w - 32, "left")

    if step.kind == "next" then
        ui.glossyButton(nextButtonRect(box), "NEXT", { 0.10, 0.65, 0.25 }, true)
        ui.text(ui.touchMode and "" or "(Enter)", fonts.hint, box.x + 16, box.y + box.h - 38, 200, "left",
            { 1, 1, 1, 0.45 })
    else
        ui.text("YOUR TURN!", fonts.hint, box.x + 16, box.y + box.h - 30, box.w - 32, "left", { 0.45, 1, 0.45 })
    end

    drawSkipButton()
end


---------------------------------------------------------------------------
-- INPUT (main.lua passes clicks and keys here first)
---------------------------------------------------------------------------

-- A click. Returns true if the tutorial used it (so the game shouldn't).
function tutorial.mousepressed(x, y)
    if not tutorial.active or state == "start" then return false end
    if util.isInside(x, y, skipRect()) then
        tutorial.stop()
        return true
    end
    local step = current()
    if step and step.kind == "next" then
        if util.isInside(x, y, nextButtonRect(boxRect(step))) then
            advance()
        end
        return true   -- reading steps swallow every other click
    end
    return false
end

-- A key. Returns true if the tutorial used it.
function tutorial.keypressed(key)
    local step = current()
    if step == nil or step.kind ~= "next" then return false end
    if key == "return" or key == "kpenter" or key == "space" then
        advance()
    end
    return true       -- reading steps swallow every other key
end

return tutorial
