-- tools/pips-sim/bot.lua
-- A strategy bot for PIPS mode. It only ever plays through pipsgame.act,
-- just like a real player. It tries to play well:
--   * ROLLING: it tries several ways to hold dice (keep the biggest group,
--     keep every pair, keep a straight, keep high dice...), imagines each
--     reroll 40 times, and picks the hold with the best average score.
--     It only rerolls when that beats scoring now by enough.
--   * SHOP: it values the run by the average score of 80 imagined rolls,
--     and buys / picks whatever raises that the most for its price.
-- The bot's imagined rolls use their OWN random numbers, so they never
-- change the game's dice.

local config    = require("config")
local pipsgame  = require("pipsgame")
local pipsscore = require("pipsscore")
local pipshands = require("pipshands")
local pipsshop  = require("pipsshop")
local perkys    = require("perkys")

local bot = {}
local P = config.PIPS
local gen = love.math.newRandomGenerator(12345)

local function rollFace(die)
    return die.faces[gen:random(#die.faces)]
end

local function scoreOf(run, values)
    return pipsscore.score(run, values, true).total
end

---------------------------------------------------------------------------
-- ROLLING
---------------------------------------------------------------------------

-- Candidate holds: lists of true/false per die.
local function candidates(run)
    local vals = run.values
    local counts = pipshands.countFaces(vals)
    local list = {}
    local function add(fn)
        local h = {}
        for i, v in ipairs(vals) do h[i] = fn(i, v) and true or false end
        table.insert(list, h)
    end
    add(function() return false end)                                 -- hold nothing
    add(function(_, v) return counts[v] >= 2 end)                    -- every pair or better
    -- each face's group on its own
    for f = 1, pipshands.MAX_FACE do
        if counts[f] >= 1 then add(function(_, v) return v == f end) end
    end
    -- two biggest groups together
    add(function(_, v) return counts[v] >= 2 or v >= 5 end)          -- pairs + high dice
    add(function(_, v) return v >= 5 end)                            -- high dice only
    -- longest straight run (one die for each value)
    local bestStart, bestLen, run0, len = 1, 0, nil, 0
    for f = 1, pipshands.MAX_FACE do
        if counts[f] > 0 then
            if len == 0 then run0 = f end
            len = len + 1
            if len > bestLen then bestLen, bestStart = len, run0 end
        else
            len = 0
        end
    end
    if bestLen >= 2 then
        local used = {}
        add(function(_, v)
            if v >= bestStart and v < bestStart + bestLen and not used[v] then used[v] = true; return true end
            return false
        end)
    end
    return list
end

-- Average score after rerolling everything not in 'hold'.
local function expected(run, hold, samples)
    local total = 0
    local vals = {}
    for _ = 1, samples do
        for i, die in ipairs(run.dice) do
            vals[i] = hold[i] and run.values[i] or rollFace(die)
        end
        total = total + scoreOf(run, vals)
    end
    return total / samples
end

local function playSet(run)
    while run.state == "choose" do
        local now = scoreOf(run, run.values)
        -- Already enough to win the round? Score it and keep the rerolls (coins).
        if (run.goal and run.roundScore + now >= run.goal) or run.rerollsLeft == 0 then break end
        local bestHold, bestValue = nil, -1
        for _, hold in ipairs(candidates(run)) do
            local all = true
            for i = 1, #run.dice do if not hold[i] then all = false end end
            if not all then
                local e = expected(run, hold, 40)
                if e > bestValue then bestHold, bestValue = hold, e end
            end
        end
        -- Spend more freely when there are plenty of rerolls for the sets left.
        local margin = run.rerollsLeft >= run.setsLeft and 1.0 or 1.15
        if run.setsLeft == 1 then margin = 1.0 end
        if not bestHold or bestValue <= now * margin then break end
        for i = 1, #run.dice do
            if (run.held[i] or false) ~= bestHold[i] then pipsgame.act("hold", i) end
        end
        pipsgame.act("reroll")
    end
    pipsgame.act("score")
end

---------------------------------------------------------------------------
-- THE SHOP
---------------------------------------------------------------------------

-- How good is the run right now? The average score of imagined rolls
-- (the same imagined rolls every time, so comparisons are fair).
local sampleSeeds = {}
for s = 1, 80 do sampleSeeds[s] = s * 7919 end
local function value(run)
    local saved = gen:getState()   -- put the bot's own random numbers back afterwards
    local total = 0
    for s = 1, #sampleSeeds do
        gen:setSeed(sampleSeeds[s])
        local vals = {}
        for i, die in ipairs(run.dice) do vals[i] = rollFace(die) end
        total = total + scoreOf(run, vals)
    end
    gen:setState(saved)
    return total / #sampleSeeds
end

-- The value of the run with 'item' added (and nothing really changed).
local function valueWith(run, item)
    if item.type == "perky" then
        local p = perkys.get(item.id)
        local held = { id = item.id, gained = p.grows and 4 or 0 }  -- growers: guess some growth
        table.insert(run.perkys, held)
        local v = value(run)
        table.remove(run.perkys)
        if p.extraSets then v = v * 1.25 end
        if p.extraRerolls then v = v * 1.08 end
        if p.roundEnd then v = v * 1.03 end
        return v
    elseif item.type == "diceAug" then
        run.diceAug[item.face] = (run.diceAug[item.face] or 0) + 1
        local v = value(run)
        run.diceAug[item.face] = run.diceAug[item.face] - 1
        return v
    elseif item.type == "setAug" then
        run.setAug[item.hand] = (run.setAug[item.hand] or 0) + 1
        local v = value(run)
        run.setAug[item.hand] = run.setAug[item.hand] - 1
        return v
    elseif item.type == "die" then
        table.insert(run.dice, item.die)
        local v = value(run)
        table.remove(run.dice)
        return v
    end
    return 0
end

-- The value without held Perky k.
local function valueWithout(run, k)
    local held = table.remove(run.perkys, k)
    local v = value(run)
    table.insert(run.perkys, k, held)
    return v
end

-- If the Perky slots are full, sell the weakest Perky when 'item' beats it.
-- Gives back true if there's room now.
local function makeRoom(run, item, base)
    if item.type ~= "perky" or pipsshop.perkyRoom(run) then return true end
    local worstK, worstV = nil, -1
    for k = 1, #run.perkys do
        local v = valueWithout(run, k)
        if v > worstV then worstK, worstV = k, v end
    end
    -- worstV = the value after selling the weakest. Is the new one better than it?
    local gain = valueWith(run, item) - base
    local loss = base - worstV
    if gain > loss * 1.2 then
        pipsgame.act("sell", worstK)
        return true
    end
    return false
end

local PACK_ORDER = { rarePerky = 1, bigPerky = 2, dice = 3, perky = 4, diceAug = 5, setAug = 5, dungeon = 6, craps = 7 }

local function openPack(run)
    local pack = run.shop.pack
    local base = value(run)
    local bestK, bestGain = nil, 0
    for k, opt in ipairs(pack.options) do
        local gain = 0
        if opt.type == "bet" then
            -- Closest to the average total is most likely to hit.
            local mean = 0
            for _, d in ipairs(run.dice) do
                local s = 0
                for _, f in ipairs(d.faces) do s = s + f end
                mean = mean + s / #d.faces
            end
            gain = 1 / (1 + math.abs(opt.number - mean))
        elseif opt.type == "die" and #run.dice >= run.slots then
            gain = -1   -- handled below (swap)
        else
            gain = valueWith(run, opt) - base
        end
        if gain > bestGain then bestK, bestGain = k, gain end
    end
    if bestK then
        local opt = pack.options[bestK]
        if makeRoom(run, opt, base) then
            pipsgame.act("pickPack", bestK)
            if run.shop.pack then pipsgame.act("skipPack") end
            return
        end
    end
    -- Full of dice: swap the weakest die for the best pack die, if it helps.
    if pack.options[1] and pack.options[1].type == "die" then
        local bestOpt, bestSlot, bestV = nil, nil, base
        for k, opt in ipairs(pack.options) do
            for slot = 1, #run.dice do
                local old = run.dice[slot]
                run.dice[slot] = opt.die
                local v = value(run)
                run.dice[slot] = old
                if v > bestV * 1.03 then bestOpt, bestSlot, bestV = k, slot, v end
            end
        end
        if bestOpt then
            pipsgame.act("pickPack", bestOpt)
            pipsgame.act("replaceDie", bestSlot)
            return
        end
    end
    pipsgame.act("skipPack")
end

local function shopVisit(run)
    for _ = 1, 30 do   -- (a safety limit)
        local base = value(run)
        -- 1. The best main item for its price.
        local bestK, bestScore = nil, 0
        for k, item in ipairs(run.shop.items) do
            if not item.sold and item.price <= run.coins then
                local gain = (valueWith(run, item) - base) / math.max(1, base)
                local score = gain / item.price
                if gain > 0.04 and score > bestScore then bestK, bestScore = k, score end
            end
        end
        if bestK and makeRoom(run, run.shop.items[bestK], base) then
            pipsgame.act("buy", bestK)
        elseif run.coins >= pipsshop.spinPrice(run)
            and (#run.dice < run.slots or run.coins >= pipsshop.spinPrice(run) + 2) then
            -- 2. Spin for a pack.
            pipsgame.act("spin")
            local bestReel, bestRank = 1, 99
            for k = 1, 3 do
                local id = run.shop.reels[k]
                local rank = PACK_ORDER[id]
                if (id == "dice" or id == "dungeon") and #run.dice < run.slots then rank = 0 end
                if rank < bestRank then bestReel, bestRank = k, rank end
            end
            pipsgame.act("pickReel", bestReel)
            openPack(run)
        elseif run.coins >= run.shop.rerollCost + 6 then
            pipsgame.act("shopReroll")
        else
            break
        end
    end
    pipsgame.act("continue")
end

-- Play one whole run. Gives back the run.
function bot.play(seed)
    local run = pipsgame.new(seed)
    gen:setSeed(seed * 31 + 7)
    while true do
        local s = run.state
        if s == "choose" then playSet(run)
        elseif s == "scored" then pipsgame.act("next")
        elseif s == "roundWon" then pipsgame.act("toShop")
        elseif s == "bossIntro" then pipsgame.act("fight")
        elseif s == "joshTurn" then pipsgame.act("next")
        elseif s == "shop" then shopVisit(run)
        else break end
    end
    return run
end

return bot
