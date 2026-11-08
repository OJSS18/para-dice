-- pipsgame.lua
-- PIPS MODE: one RUN of the second game type, and every ACTION the player
-- can take in it. Nothing in here draws (pipsdraw.lua) or reads clicks
-- (pipsinput.lua).
--
-- THE RULES IN SHORT
--   * You start with 3 dice. More dice SLOTS open at levels 2, 3, 5, 6, 8,
--     9, 10 and 11 - but you have to get the dice for them from the shop.
--   * Each level has 3 ROUNDS with a goal each (level 1: 100, 200, 300).
--   * A round gives you 5 SETS (scored rolls) and 4 REROLLS to share
--     between them. Roll, hold the dice you like, reroll the rest as often
--     as your rerolls last, then SCORE.
--   * Score = POINTS (pips) x MULT (from the set you rolled) - see pipsscore.lua.
--   * Reach the goal and you win the round: coins for winning, +1 per
--     reroll left and +2 per set left. Then the SHOP. Run out of sets
--     first and the run is over.
--
-- Like the main game, every player action goes through pipsgame.act(name, arg),
-- and all randomness uses rng.random (seeded per run), so a run could be
-- replayed later from its seed and pipsgame.log.
--
-- pipsgame.run.state is which part of the run we're in:
--   "choose"   - the dice are rolled: hold some, REROLL, or SCORE
--   "scored"   - a set was just scored; NEXT carries on
--   "roundWon" - the goal was reached; coins counted; on to the shop
--   "shop"     - between rounds
--   "gameOver" - out of sets before the goal
--   "victory"  - the last level was beaten!

local config    = require("config")
local rng       = require("rng")
local pipsdice  = require("pipsdice")
local pipsscore = require("pipsscore")
local pipsshop  = require("pipsshop")
local perkys    = require("perkys")

local pipsgame = {}

local P = config.PIPS

pipsgame.run = nil       -- the run's data (see pipsgame.new)
pipsgame.active = false  -- is a PIPS run going?
pipsgame.log = {}        -- every action so far: { {name, arg}, ... }


---------------------------------------------------------------------------
-- SMALL HELPERS
---------------------------------------------------------------------------

-- How many dice slots are open on level 'level'.
function pipsgame.slotsFor(level)
    local slots = P.START_DICE
    for _, l in ipairs(P.SLOT_LEVELS) do
        if level >= l then slots = slots + 1 end
    end
    return slots
end

-- The goal for round 'round' of level 'level': 100, 200, 300 on level 1,
-- then GOAL_GROWTH times bigger each level.
function pipsgame.goalFor(level, round)
    local base = P.FIRST_GOAL * P.GOAL_GROWTH ^ (level - 1)
    -- Round to a tidy number (nearest 10).
    return math.floor(base * round / 10 + 0.5) * 10
end

-- Add up a passive Perky bonus ('extraSets' or 'extraRerolls').
local function perkyBonus(run, field)
    local total = 0
    for _, held in ipairs(run.perkys) do
        total = total + (perkys.get(held.id)[field] or 0)
    end
    return total
end

-- Roll every die that isn't held. Remembers which ones rolled (so the
-- screen can flash them) and counts up rollId (so it knows a roll happened).
local function rollDice(run)
    run.rolled = {}
    for i, die in ipairs(run.dice) do
        if not run.held[i] then
            run.values[i] = pipsdice.roll(die)
            run.rolled[i] = true
        end
    end
    run.rollId = run.rollId + 1
end


---------------------------------------------------------------------------
-- GAME FLOW
---------------------------------------------------------------------------

-- A new set: nothing held, all the dice rolled.
local function startSet(run)
    run.held = {}
    run.values = {}
    run.rerollsThisSet = 0
    run.lastResult = nil
    rollDice(run)
    run.state = "choose"
end

-- A new round: fresh sets and rerolls, score back to 0.
local function startRound(run)
    run.goal = pipsgame.goalFor(run.level, run.round)
    run.roundScore = 0
    run.setsLeft = P.SETS + perkyBonus(run, "extraSets")
    run.rerollsLeft = P.REROLLS + perkyBonus(run, "extraRerolls")
    startSet(run)
end

-- The goal is reached: count up the coins.
local function winRound(run)
    local pay = { win = P.WIN_COINS, rerolls = run.rerollsLeft * P.COIN_PER_REROLL,
                  sets = run.setsLeft * P.COIN_PER_SET, perkys = 0 }
    for _, held in ipairs(run.perkys) do
        local p = perkys.get(held.id)
        if p.roundEnd then pay.perkys = pay.perkys + p.roundEnd({ coins = run.coins }) end
    end
    pay.total = pay.win + pay.rerolls + pay.sets + pay.perkys
    run.coins = run.coins + pay.total
    run.payout = pay
    if run.level == P.MAX_LEVEL and run.round == P.ROUNDS then
        run.state = "victory"
        pipsgame.active = false
    else
        run.state = "roundWon"
    end
end

-- Start a brand new PIPS run. 'seed' is optional (a new one if nil).
function pipsgame.new(seed)
    local run = {
        seed = seed or rng.newSeed(),
        level = 1, round = 1,
        coins = P.START_COINS,
        dice = {},
        perkys = {},              -- held Perkys: { {id, gained}, ... }
        diceAug = {},             -- dice augment levels: { [face] = levels }
        setAug = {},              -- set augment levels: { [set id] = levels }
        bets = {},                -- craps bet numbers on the board
        held = {}, values = {}, rolled = {}, rollId = 0,
        best = 0,                 -- the biggest single set scored this run
        sets = 0,                 -- how many sets have been scored this run
    }
    rng.setSeed(run.seed)
    run.slots = pipsgame.slotsFor(1)
    for _ = 1, P.START_DICE do table.insert(run.dice, pipsdice.starter()) end
    run.shop = { items = {} }
    pipsgame.run = run
    pipsgame.log = {}
    pipsgame.active = true
    pipsgame.unranked = false
    startRound(run)
    return run
end

-- The set scored and pipsgame.run.lastResult: what's next?
local function afterScore(run)
    if run.roundScore >= run.goal then
        winRound(run)
    elseif run.setsLeft <= 0 then
        run.state = "gameOver"
        pipsgame.active = false
    else
        startSet(run)
    end
end


---------------------------------------------------------------------------
-- ACTIONS (the only way the player changes the run)
---------------------------------------------------------------------------

local ACTIONS = {}

-- Hold / let go of die 'arg'.
function ACTIONS.hold(run, arg)
    if run.state ~= "choose" or not run.dice[arg] then return false end
    run.held[arg] = not run.held[arg]
    return true
end

-- Reroll every die that isn't held (uses one reroll).
function ACTIONS.reroll(run)
    if run.state ~= "choose" or run.rerollsLeft <= 0 then return false end
    local any = false
    for i = 1, #run.dice do
        if not run.held[i] then any = true end
    end
    if not any then return false end   -- everything is held: nothing to roll
    run.rerollsLeft = run.rerollsLeft - 1
    run.rerollsThisSet = run.rerollsThisSet + 1
    rollDice(run)
    return true
end

-- Score the dice as they are.
function ACTIONS.score(run)
    if run.state ~= "choose" then return false end
    local result = pipsscore.score(run, run.values, false)
    run.setsLeft = run.setsLeft - 1
    run.roundScore = run.roundScore + result.total
    run.coins = run.coins + result.coins
    run.best = math.max(run.best, result.total)
    run.sets = run.sets + 1
    run.lastResult = result
    run.state = "scored"
    return true
end

-- NEXT after a set is scored: the next set, or the end of the round.
function ACTIONS.next(run)
    if run.state ~= "scored" then return false end
    afterScore(run)
    return true
end

-- On to the shop after winning a round.
function ACTIONS.toShop(run)
    if run.state ~= "roundWon" then return false end
    pipsshop.open(run)
    run.state = "shop"
    return true
end

-- Shop actions: pipsshop.lua does the work.
local SHOP = {
    buy = pipsshop.buy, shopReroll = pipsshop.reroll, spin = pipsshop.spin,
    pickReel = pipsshop.pickReel, pickPack = pipsshop.pickOption, replaceDie = pipsshop.replaceDie,
    skipPack = pipsshop.skipPack, sell = pipsshop.sell,
}
for name, fn in pairs(SHOP) do
    ACTIONS[name] = function(run, arg)
        if run.state ~= "shop" then return false end
        return fn(run, arg)
    end
end

-- Leave the shop: the next round (or the next level, with maybe a new slot).
function ACTIONS.continue(run)
    if run.state ~= "shop" or run.shop.pack then return false end
    run.round = run.round + 1
    if run.round > P.ROUNDS then
        run.round = 1
        run.level = run.level + 1
        run.slots = pipsgame.slotsFor(run.level)
    end
    startRound(run)
    return true
end

-- GOD MODE (testing): win the round, or +20 coins in the shop.
function ACTIONS.god(run)
    if not config.GOD_MODE_ENABLED then return false end
    pipsgame.unranked = true
    if run.state == "choose" or run.state == "scored" then
        run.roundScore = math.max(run.roundScore, run.goal)
        winRound(run)
    elseif run.state == "shop" then
        run.coins = run.coins + 20
        run.shop.message = "God mode: +20 coins."
    else
        return false
    end
    return true
end

-- The action names in a fixed order (for replay codes later): NEVER
-- reorder - only add to the end.
pipsgame.ACTION_NAMES = {
    "hold", "reroll", "score", "next", "toShop", "buy", "shopReroll", "spin",
    "pickReel", "pickPack", "replaceDie", "skipPack", "sell", "continue", "god",
}

-- Do an action. Returns true if it did something (and writes it in the log).
function pipsgame.act(name, arg)
    local run = pipsgame.run
    local fn = ACTIONS[name]
    if run == nil or fn == nil then return false end
    local done = fn(run, arg or 0)
    if done then table.insert(pipsgame.log, { name, arg or 0 }) end
    return done
end

-- The POINTS x MULT the dice show right now, before Perkys (for the side panel).
function pipsgame.preview()
    local run = pipsgame.run
    return pipsscore.base(run, run.values)
end

return pipsgame
