-- tools/strategy-sim/sim.lua
-- A headless BOT that plays Para-DICE with the game's real logic modules
-- (dice, score, luck, shop, markers, upgrades, boosts...). No graphics, no
-- god mode: it plays exactly what a player could do, as fast as it can.
--
-- Run it with tools/strategy-sim/run.sh (see there). Each STRATEGY below
-- is a table of choices:
--   reroll   - "never" (always KEEP the first throw), "all" (reroll all 5
--              once), or "ev" (try every way of holding dice and pick the one
--              that scores most on average)
--   coinWeight - how many points one coin is worth when deciding (0 = ignore coins)
--   dice     - die colours to buy, best first (e.g. { "amber", "blue" })
--   upgrades - upgrade ids to buy, best first (e.g. { "lower", "keep" })
--   markers  - buy extra marker chips (true / false)
--   spin     - use the Mystery Machine; luckPrefs lists the luck items it
--              wants most (anything else is ranked by rarity)
--   reserve  - coins to keep back after shopping

local dice      = require("dice")
local score     = require("score")
local player    = require("player")
local luck      = require("luck")
local markers   = require("markers")
local boosts    = require("boosts")
local upgrades  = require("upgrades")
local shop      = require("shop")
local dicetypes = require("dicetypes")
local bigwin    = require("bigwin")
local config    = require("config")

local sim = {}

---------------------------------------------------------------------------
-- WHAT A DICE RESULT IS WORTH (to the bot)
---------------------------------------------------------------------------

local strat            -- the strategy being played
local ptsBySum = {}    -- ptsBySum[s] = tile value x marker, this round
local handCache = {}   -- coins for each multiset of faces, this round

local function refreshValues()
    for s = 5, 30 do
        ptsBySum[s] = score.tileValue(s) * markers.pointsMultiplier(s)
    end
    handCache = {}
end

local function handCoins(v)
    if strat.coinWeight == 0 then return 0 end
    local a, b, c, d, e = v[1], v[2], v[3], v[4], v[5]
    local key = 0
    local counts = { 0, 0, 0, 0, 0, 0 }
    counts[a] = counts[a] + 1; counts[b] = counts[b] + 1; counts[c] = counts[c] + 1
    counts[d] = counts[d] + 1; counts[e] = counts[e] + 1
    for f = 1, 6 do key = key * 6 + counts[f] end
    local coins = handCache[key]
    if coins == nil then
        local _, best = score.bestHand({ a, b, c, d, e })
        coins = best
        handCache[key] = coins
    end
    return coins
end

local function value(v, keepBonus)
    local sum = v[1] + v[2] + v[3] + v[4] + v[5]
    local p = ptsBySum[sum]
    if keepBonus then p = p * score.keepMultiplier() end
    return p + strat.coinWeight * handCoins(v)
end

-- The chance of each face for each die (luck items included).
local function faceOdds()
    local odds = {}
    for i = 1, 5 do
        local w = luck.applyTo(dicetypes.get(player.loadout[i]).weights, i)
        local total = 0
        for f = 1, 6 do total = total + w[f] end
        odds[i] = {}
        for f = 1, 6 do odds[i][f] = w[f] / total end
    end
    return odds
end

-- Expected value of rerolling every die NOT in 'hold' (a list of true/false).
local function rerollEV(hold, odds)
    local v = { dice.values[1], dice.values[2], dice.values[3], dice.values[4], dice.values[5] }
    local total = 0
    local function walk(i, prob)
        if i > 5 then
            total = total + prob * value(v, false)
            return
        end
        if hold[i] then
            walk(i + 1, prob)
        else
            local o = odds[i]
            for f = 1, 6 do
                v[i] = f
                walk(i + 1, prob * o[f])
            end
            v[i] = dice.values[i]
        end
    end
    walk(1, 1)
    return total
end

-- Decide: returns nil to KEEP, or a hold list to reroll the rest.
local function decide()
    if not dice.canReroll() then return nil end
    if strat.reroll == "never" then return nil end
    if strat.reroll == "all" then
        if dice.hasRerolled() then return nil end
        return { false, false, false, false, false }
    end
    local keepValue = value(dice.values, not dice.hasRerolled())
    local odds = faceOdds()
    local best, bestEV = nil, keepValue
    for mask = 0, 30 do   -- 31 = hold everything = keep
        local hold = {}
        for i = 1, 5 do hold[i] = (math.floor(mask / 2 ^ (i - 1)) % 2) == 1 end
        local ev = rerollEV(hold, odds)
        if ev > bestEV + 1e-9 then best, bestEV = hold, ev end
    end
    return best
end


---------------------------------------------------------------------------
-- PLACING MARKERS: put each chip where it adds the most on average
---------------------------------------------------------------------------

local function placeMarkers()
    if luck.blocksMarker() then return end
    -- The chance of every sum and every best hand on ONE throw of the
    -- current dice (all 7776 outcomes). Good enough to rank the tiles.
    local odds = faceOdds()
    local pSum, pHand = {}, {}
    for s = 5, 30 do pSum[s] = 0 end
    local v = {}
    local function walk(i, prob)
        if i > 5 then
            local s = v[1] + v[2] + v[3] + v[4] + v[5]
            pSum[s] = pSum[s] + prob
            local hand = score.bestHand(v)
            if hand then pHand[hand.id] = (pHand[hand.id] or 0) + prob end
            return
        end
        for f = 1, 6 do v[i] = f; walk(i + 1, prob * odds[i][f]) end
    end
    walk(1, 1)
    -- Rerolling pushes results toward the valuable extremes, so value a
    -- tile by chance x points squared-ish: favour rarer, bigger tiles.
    local options = {}
    for s = 5, 30 do
        table.insert(options, { kind = "points", key = s,
            gain = pSum[s] ^ (strat.markerSkew or 1) * score.tileValue(s) })
    end
    for _, hand in ipairs(score.COIN_HANDS) do
        local coins = hand.coins == "sum" and 20 or hand.coins
        table.insert(options, { kind = "coins", key = hand.id,
            gain = (pHand[hand.id] or 0) * coins * math.max(strat.coinWeight, 0.3) })
    end
    table.sort(options, function(a, b) return a.gain > b.gain end)
    for n = 1, markers.owned do
        markers.toggle(options[n].kind, options[n].key)
    end
end


---------------------------------------------------------------------------
-- THE SHOP
---------------------------------------------------------------------------

local function rankOf(list, id)
    for n, x in ipairs(list or {}) do if x == id then return n end end
    return nil
end

-- How much the bot wants a luck item (higher = better).
local function luckScore(id)
    if rankOf(strat.luckAvoid, id) then return -1 end
    local r = rankOf(strat.luckPrefs, id)
    if r then return 1000 - r end
    return luck.RARITIES[luck.get(id).rarity].value
end

local function shopDice()
    for k = 1, 2 do
        local id = shop.stock.dice[k]
        local want = rankOf(strat.dice, id)
        if want and not shop.sold.dice[k] then
            -- Which slot would it replace? A white die first, else a die we
            -- want less than this one.
            local slot, worst = nil, want
            for i = 1, 5 do
                local r = rankOf(strat.dice, player.loadout[i]) or 99
                if r > worst then slot, worst = i, r end
            end
            if slot and player.coins - dicetypes.get(id).price >= (strat.reserve or 0) then
                shop.buyDice(k)
                if shop.sold.dice[k] then
                    shop.selectInventory(#player.inventory)
                    shop.equipTo(slot)
                end
            end
        end
    end
end

local function shopUpgrades()
    for _, want in ipairs(strat.upgrades or {}) do
        for k = 1, 3 do
            local offer = shop.stock.upgrades[k]
            if offer.id == want and not shop.sold.upgrades[k]
                and player.coins - offer.price >= (strat.reserve or 0) then
                shop.buyUpgrade(k)
            end
        end
    end
end

local function shopMarkers()
    while strat.markers and markers.owned < (strat.maxMarkers or markers.MAX_OWNED)
        and player.coins - markers.nextPrice() >= (strat.reserve or 0) do
        shop.buyMarker()
    end
end

local function shopSpin()
    while strat.spin and player.coins - shop.spinPrice() >= (strat.reserve or 0) do
        shop.pullMystery()
        shop.update(100)          -- let the reels stop
        local bestK, bestScore = nil, -math.huge
        for k = 1, shop.REELS do
            local s = luckScore(shop.machine.reels[k].prize)
            if s > bestScore then bestK, bestScore = k, s end
        end
        if luck.isFull() then
            local worstK, worstScore = nil, math.huge
            for k, id in ipairs(luck.held) do
                local s = luckScore(id)
                if s < worstScore then worstK, worstScore = k, s end
            end
            if bestScore > worstScore then shop.sellLuck(worstK) end
        end
        if not luck.isFull() and bestScore > 0 then shop.takePrize(bestK) end
        shop.machine.warned = true    -- happy to leave untaken prizes
    end
end

local function visitShop()
    shop.open(score.level + 1)
    local order = strat.shopOrder or { "dice", "upgrades", "markers", "spin" }
    for _, step in ipairs(order) do
        if step == "dice" then shopDice()
        elseif step == "upgrades" then shopUpgrades()
        elseif step == "markers" then shopMarkers()
        elseif step == "spin" then shopSpin() end
    end
end


---------------------------------------------------------------------------
-- ONE WHOLE GAME (the same flow as main.lua)
---------------------------------------------------------------------------

local function finishRound(noReroll)
    local result = score.recordRound(dice.values, noReroll, dice.hasRerolled(), dice.firstSum)
    player.addCoins(result.coins)
    result.winBonus = bigwin.check(result.points, score.getTarget(), luck.bigWinShares())
    if result.winBonus > 0 then
        player.addCoins(result.winBonus)
        score.levelCoins = score.levelCoins + result.winBonus
    end
    luck.onPointScored(result.sum)
    if score.isLevelOver() and score.hasPassedLevel() then
        if luck.givesUnlockTokens() then player.unlockTokens = player.unlockTokens + 1 end
        local interest = luck.levelEndCoins(player.coins)
        player.addCoins(interest)
        score.levelCoins = score.levelCoins + interest
    end
end

local function playRound()
    markers.autoSum = luck.autoMarkerSum(score.round + 1)
    dice.newRound()
    refreshValues()
    dice.throw()                       -- the first throw: all 5
    while true do
        local hold = decide()
        if hold == nil then
            local earned = not dice.hasRerolled()
            dice.noReroll()
            finishRound(earned)
            return
        end
        for i = 1, 5 do dice.held[i] = hold[i] end
        dice.throw()
        if not dice.canReroll() then
            finishRound(false)         -- that used the last reroll
            return
        end
    end
end

-- Play one game with strategy 's'. Returns how many levels were cleared
-- (10 = the game was won) and some stats.
function sim.playGame(s)
    strat = s
    score.reset(); player.reset(); boosts.reset(); upgrades.reset()
    markers.reset(); luck.reset(); luck.give(luck.STARTER)
    for _, id in ipairs(s.startLuck or {}) do luck.give(id) end   -- perks held from the start
    for i, id in ipairs(s.startDice or {}) do player.loadout[i] = id end   -- dice swapped in from the start
    for id, lvl in pairs(s.startUpgrades or {}) do upgrades.levels[id] = lvl end
    markers.owned = s.startMarkers or markers.owned
    sim.coinsEarned, sim.levelsPlayed = 0, 0
    while true do
        boosts.clearLevel(); markers.clear(); markers.autoSum = nil
        placeMarkers()
        for _ = 1, score.ROUNDS_PER_LEVEL do playRound() end
        sim.coinsEarned = sim.coinsEarned + score.levelCoins
        sim.levelsPlayed = sim.levelsPlayed + 1
        if not score.hasPassedLevel() then
            return score.level - 1, score.levelTotal / score.getTarget()
        end
        if score.level >= score.MAX_LEVEL then
            return score.MAX_LEVEL, score.levelTotal / score.getTarget()
        end
        visitShop()
        score.startNextLevel()
    end
end

return sim
