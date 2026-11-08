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

local pipsscore = {}

-- The starting POINTS and MULT before any Perky (what the side panel
-- shows while you decide). Gives back points, mult, the set, and the
-- plain pip total.
function pipsscore.base(run, values)
    local counts = pipshands.countFaces(values)
    local hand, mult = pipshands.best(counts, run.slots, run.setAug)
    local pipTotal = util.sum(values)
    local points = 0
    for _, v in ipairs(values) do
        points = points + augments.facePoints(v, run.diceAug[v])
    end
    return points, mult, hand, pipTotal, counts
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
        contained = pipshands.contained(counts, run.slots),
        hand = hand.id,
        numDice = #values,
        pipTotal = pipTotal,
        setsLeft = run.setsLeft - 1,          -- sets left AFTER this one
        rerollsThisSet = run.rerollsThisSet,
        coins = run.coins,
        perkyCount = #run.perkys,
    }

    local xmult = 1
    for _, held in ipairs(run.perkys) do
        local p = perkys.get(held.id)
        if p.effect then
            -- A preview works on a copy, so a growing Perky doesn't really grow.
            local target = held
            if preview then target = { id = held.id, gained = held.gained } end
            local out = p.effect(ctx, target)
            if out then
                local words = {}
                if out.points then points = points + out.points; table.insert(words, "+" .. out.points .. " POINTS") end
                if out.mult then mult = mult + out.mult; table.insert(words, "+" .. out.mult .. " MULT") end
                if out.xmult then xmult = xmult * out.xmult; table.insert(words, "x" .. out.xmult .. " MULT") end
                if out.coins then result.coins = result.coins + out.coins; table.insert(words, "+" .. out.coins .. " COINS") end
                if #words > 0 then
                    table.insert(result.parts, { name = p.name, text = table.concat(words, "  ") })
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
