-- pipsscore.lua
-- PIPS MODE: how a roll SCORES. Pure LOGIC - no drawing.
--
--   1. POINTS = the pips on all your dice added up. DICE AUGMENTS make a
--      face worth more: with the Fours Augment at level 2, each 4 scores
--      4 + 2 x 4 = 12 (see augments.lua). Sets give NO points, only mult.
--   2. MULT   = the starting mult of the best SET the roll makes (Pair 2,
--      Three of a Kind 4...), plus any SET AUGMENT levels for that set.
--   3. Each Perky adds its +POINTS and +MULT.
--   4. Then every xMULT (from Perkys, and craps bets that hit) multiplies
--      the mult, right at the very end.
--   SCORE = POINTS x MULT.

local config    = require("config")
local pipshands = require("pipshands")
local perkys    = require("perkys")
local util      = require("util")
local augments  = require("augments")
local rng       = require("rng")

local pipsscore = {}

-- The set a boss has banned this round (or nil).
function pipsscore.banned(run)
    return run.boss and run.boss.banned or nil
end

-- The starting POINTS and MULT before any Perky (what the side panel
-- shows while you decide). Gives back points, mult, the set, and the
-- plain pip total.
function pipsscore.base(run, values)
    local counts = pipshands.countFaces(values)
    local hand, mult = pipshands.best(counts, run.slots, run.setAug, pipsscore.banned(run))
    local pipTotal = util.sum(values)
    local points = 0
    for _, v in ipairs(values) do
        points = points + augments.facePoints(v, run.diceAug[v])
    end
    return points, mult, hand, pipTotal, counts
end

-- Which held Perky does copy Perky k copy? Gives back that Perky's table, or nil.
--   "left"   - the one in the slot to its left
--   "random" - a random other one, picked fresh every scored roll. (While
--              only trying out a roll - 'preview' - it takes the first one,
--              so trying things out never uses up the game's random numbers.)
local function copyTarget(run, k, mode, preview)
    if mode == "left" then
        local left = run.perkys[k - 1]
        if left and perkys.isCopyable(left) then return left end
        return nil
    end
    local choices = {}
    for j, held in ipairs(run.perkys) do
        if j ~= k and perkys.isCopyable(held) then table.insert(choices, held) end
    end
    if #choices == 0 then return nil end
    if preview then return choices[1] end
    return choices[rng.random(#choices)]
end

-- Score a roll. Gives back a result table:
--   hand, basePoints, baseMult  - before Perkys
--   points, mult, xmult         - after Perkys (xmult = everything multiplied together)
--   total                       - the score: points x mult x xmult
--   coins                       - coins the Perkys pay out
--   parts                       - a list of { name, text } saying what each Perky did
-- When 'preview' is true nothing changes (growing Perkys don't grow) - the
-- strategy bot uses that to try out choices.
function pipsscore.score(run, values, preview)
    local points, mult, hand, pipTotal, counts = pipsscore.base(run, values)
    local result = { hand = hand, basePoints = points, baseMult = mult, values = values,
                     pipTotal = pipTotal, coins = 0, parts = {} }

    -- Facts about the roll, for the Perkys to look at.
    local ctx = {
        values = values,
        counts = counts,
        contained = pipshands.contained(counts, run.slots, pipsscore.banned(run)),
        hand = hand.id,
        numDice = #values,
        pipTotal = pipTotal,
        setsLeft = run.setsLeft - 1,          -- sets left AFTER this one
        rerollsThisSet = run.rerollsThisSet,
        coins = run.coins,
        perkyCount = #run.perkys,
    }

    local xmult = 1
    for k, held in ipairs(run.perkys) do
        local p = perkys.get(held.id)
        local name = p.name
        local out = nil
        if held.disabled then
            -- Pit Boss Josh switched this one off: it does nothing.
        elseif p.copy then
            -- A copy Perky does what its target does. (A growing Perky is
            -- copied at its current size - the copy doesn't make it grow.)
            local target = copyTarget(run, k, p.copy, preview)
            if target then
                local tp = perkys.get(target.id)
                name = p.name .. " (as " .. tp.name .. ")"
                if tp.grows then
                    if target.gained > 0 then out = { mult = target.gained } end
                else
                    out = tp.effect(ctx, { id = target.id, gained = target.gained })
                end
            end
        elseif p.effect then
            -- A preview works on a copy, so a growing Perky doesn't really grow.
            local target = held
            if preview then target = { id = held.id, gained = held.gained } end
            out = p.effect(ctx, target)
        end
        -- Add up what it gave.
        do
            if out then
                local words = {}
                if out.points then points = points + out.points; table.insert(words, "+" .. out.points .. " POINTS") end
                if out.mult then mult = mult + out.mult; table.insert(words, "+" .. out.mult .. " MULT") end
                if out.xmult then xmult = xmult * out.xmult; table.insert(words, "x" .. out.xmult .. " MULT") end
                if out.coins then result.coins = result.coins + out.coins; table.insert(words, "+" .. out.coins .. " COINS") end
                if #words > 0 then
                    table.insert(result.parts, { name = name, text = table.concat(words, "  "), slot = k })
                end
            end
        end
    end

    -- Craps bets on the board: if the pips add up to a bet's number, xMULT.
    for _, n in ipairs(run.bets) do
        if pipTotal == n then
            xmult = xmult * config.PIPS.CRAPS_XMULT
            table.insert(result.parts, { name = "Craps bet " .. n, text = "x" .. config.PIPS.CRAPS_XMULT .. " MULT" })
        end
    end

    result.points, result.mult, result.xmult = points, mult, xmult
    result.total = math.floor(points * mult * xmult)
    return result
end

return pipsscore
