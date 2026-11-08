-- pipsgame.lua
-- PIPS MODE: one RUN of the second game type, and every ACTION the player
-- can take in it. Nothing in here draws (pipsdraw.lua) or reads clicks
-- (pipsinput.lua).
--
-- THE RULES IN SHORT
--   * You start with 3 dice. More dice SLOTS open at levels 2, 4, 6 and 8
--     (7 dice at most) - but you have to get the dice for them from the shop.
--   * Each level has 3 ROUNDS with a goal each (level 1: 60, 120, 180).
--     Each level's goals grow by a bit more than the level before's.
--   * A round gives you 4 SETS (scored rolls) and 4 REROLLS to share
--     between them. Roll, hold the dice you like, reroll the rest as often
--     as your rerolls last, then SCORE.
--   * Score = POINTS (pips) x MULT (from the set you rolled) - see pipsscore.lua.
--   * Reach the goal and you win the round: coins for winning, +1 per
--     reroll left and +1 per set left. Then the SHOP. Run out of sets
--     first and the run is over.
--   * BOSSES (bosses.lua): after one random level of 2-3, of 5-7 and of
--     8-10, a boss round follows the shop. After level 12 comes PIT BOSS
--     JOSH, a 1-on-1 duel. Beat him to win - then ENDLESS, if you dare.
--
-- Like the main game, every player action goes through pipsgame.act(name, arg),
-- and all randomness uses rng.random (seeded per run), so a run could be
-- replayed later from its seed and pipsgame.log.
--
-- pipsgame.run.state is which part of the run we're in:
--   "choose"    - the dice are rolled: hold some, REROLL, or SCORE
--   "scored"    - a set was just scored; NEXT carries on
--   "joshTurn"  - (Josh duel) Josh just played his set; NEXT carries on
--   "roundWon"  - the goal was reached; coins counted; on to the shop
--   "shop"      - between rounds
--   "bossIntro" - "OH NO... A STRANGE FIGURE APPEARS..."; FIGHT starts the boss round
--   "gameOver"  - out of sets before the goal (or Josh won)
--   "victory"   - Pit Boss Josh is beaten! ENDLESS or finish

local config    = require("config")
local rng       = require("rng")
local pipsdice  = require("pipsdice")
local pipsscore = require("pipsscore")
local pipsshop  = require("pipsshop")
local perkys    = require("perkys")
local bosses    = require("bosses")
local pitboss   = require("pitboss")

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

-- How many times bigger level 'level''s goals are than the level before's.
-- It grows a little every level (x GOAL_GROWTH for level 2, then + GOAL_STEP
-- each level after), and much faster in ENDLESS (after level 12).
function pipsgame.growthFor(level)
    if level <= P.MAX_LEVEL then
        return P.GOAL_GROWTH + P.GOAL_STEP * (level - 2)
    end
    return P.ENDLESS_GROWTH + P.ENDLESS_STEP * (level - P.MAX_LEVEL - 1)
end

-- Round a goal to a tidy number: nearest 10 (nearest 1000 once it's huge).
local function tidy(n)
    local step = n >= 1000000 and 1000 or 10
    return math.floor(n / step + 0.5) * step
end

-- The goal for round 'round' of level 'level': 60, 120, 180 on level 1.
function pipsgame.goalFor(level, round)
    local base = P.FIRST_GOAL
    for l = 2, level do
        base = base * pipsgame.growthFor(l)
    end
    return tidy(base * round)
end

-- Does a boss round follow level 'level' in this run?
function pipsgame.isBossLevel(run, level)
    if level == P.MAX_LEVEL and not run.endless then return true end   -- Pit Boss Josh
    for _, l in ipairs(run.bossLevels) do
        if l == level then return true end
    end
    return false
end

-- Add up a passive Perky bonus ('extraSets' or 'extraRerolls').
-- (A Perky switched off by Josh doesn't count.)
local function perkyBonus(run, field)
    local total = 0
    for _, held in ipairs(run.perkys) do
        if not held.disabled then total = total + (perkys.get(held.id)[field] or 0) end
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

-- A copy of a list (the things in it aren't copied).
local function copyList(list)
    local out = {}
    for i, v in ipairs(list) do out[i] = v end
    return out
end
local function copyTable(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end


---------------------------------------------------------------------------
-- GAME FLOW
---------------------------------------------------------------------------

-- Give back a die a boss stole (at the end of the boss round).
local function returnStolenDie(run)
    if run.boss and run.boss.stolen then
        table.insert(run.dice, run.boss.stolenAt, run.boss.stolen)
        run.boss.stolen = nil
    end
end

-- A new set: nothing held, all the dice rolled.
local function startSet(run)
    -- The "steal a die" boss strikes once half the round's sets are gone.
    local b = run.boss
    if b and b.trick == "stealDie" and not b.stolen and not b.didSteal
        and run.setsTotal - run.setsLeft >= math.ceil(run.setsTotal / 2) and #run.dice > 1 then
        b.stolenAt = rng.random(#run.dice)
        b.stolen = table.remove(run.dice, b.stolenAt)
        b.didSteal = true
    end
    run.held = {}
    run.values = {}
    run.rerollsThisSet = 0
    run.lastResult = nil
    rollDice(run)
    run.state = "choose"
end

-- Fresh sets and rerolls for a round ('minusSets' / 'minusRerolls' are
-- what a boss steals), score back to 0, then the first set.
local function freshRound(run, minusSets, minusRerolls)
    run.roundScore = 0
    run.setsLeft = P.SETS + run.bonusSets + perkyBonus(run, "extraSets") - (minusSets or 0)
    run.rerollsLeft = P.REROLLS + run.bonusRerolls + perkyBonus(run, "extraRerolls") - (minusRerolls or 0)
    run.setsTotal = run.setsLeft
    startSet(run)
end

-- A normal round.
local function startRound(run)
    run.goal = pipsgame.goalFor(run.level, run.round)
    freshRound(run, 0, 0)
end

-- The goal is reached: count up the coins. 'savedByLife' is true when the
-- round was really lost but an EXTRA LIFE saved the run (no coins then).
local function winRound(run, savedByLife)
    returnStolenDie(run)
    local pay = { win = P.WIN_COINS, rerolls = run.rerollsLeft * P.COIN_PER_REROLL,
                  sets = run.setsLeft * P.COIN_PER_SET, perkys = 0 }
    for _, held in ipairs(run.perkys) do
        local p = perkys.get(held.id)
        if p.roundEnd then pay.perkys = pay.perkys + p.roundEnd({ coins = run.coins }) end
    end
    if savedByLife then pay = { win = 0, rerolls = 0, sets = 0, perkys = 0 } end
    run.savedByLife = savedByLife or false
    pay.total = pay.win + pay.rerolls + pay.sets + pay.perkys
    run.coins = run.coins + pay.total
    run.payout = pay
    if run.boss then
        run.boss.beaten = true
    elseif run.round == P.ROUNDS and pipsgame.isBossLevel(run, run.level) then
        run.pendingBoss = true   -- the shop comes first, then the boss
    end
    run.state = "roundWon"
end

-- Out of sets (or Josh won): the run is over.
local function loseRun(run)
    returnStolenDie(run)
    run.state = "gameOver"
    pipsgame.active = false
end

-- After the shop: a boss steps up. Who, and which dirty trick?
local function meetBoss(run)
    run.pendingBoss = false
    if run.level == P.MAX_LEVEL and not run.endless then
        run.boss = { id = "josh", josh = true, line = bosses.JOSH.lines[rng.random(#bosses.JOSH.lines)] }
    else
        local b = bosses.LIST[rng.random(#bosses.LIST)]
        local t = bosses.TRICKS[rng.random(#bosses.TRICKS)]
        run.boss = { id = b.id, trick = t.id, line = b.lines[rng.random(#b.lines)] }
    end
    run.state = "bossIntro"
end

-- FIGHT: a boss round. The goal is the level's last goal (x1.5 for the
-- "big goal" trick), and the boss steals a set or a reroll if that's its trick.
local function startBossRound(run)
    local trick = run.boss.trick
    run.goal = pipsgame.goalFor(run.level, P.ROUNDS)
    if trick == "bigGoal" then run.goal = tidy(run.goal * 1.5) end
    freshRound(run, trick == "stealSet" and 1 or 0, trick == "stealReroll" and 1 or 0)
end

-- FIGHT against Pit Boss Josh: he copies your run, one Perky on each side
-- is switched off, and you take turns: your set, then his.
local function startDuel(run)
    local josh = {
        slots = run.slots, dice = copyList(run.dice), coins = run.coins,
        diceAug = copyTable(run.diceAug), setAug = copyTable(run.setAug), bets = copyList(run.bets),
        perkys = {}, total = 0, turns = 0, rerollsThisSet = 0,
    }
    for i, held in ipairs(run.perkys) do
        josh.perkys[i] = { id = held.id, gained = held.gained }
    end
    -- Switch off one random Perky for you, and one (maybe a different one) for Josh.
    if #run.perkys > 0 then
        run.perkys[rng.random(#run.perkys)].disabled = true
        josh.perkys[rng.random(#josh.perkys)].disabled = true
    end
    josh.setsLeft = P.SETS + run.bonusSets + perkyBonus(josh, "extraSets")
    josh.rerollsLeft = P.REROLLS + run.bonusRerolls + perkyBonus(josh, "extraRerolls")
    run.josh = josh
    -- Josh's dice and thinking use their own random numbers, made from the seed.
    run.joshGen = love.math.newRandomGenerator(run.seed % 1000000007 + 4242)
    run.goal = nil   -- no goal: just beat Josh's total
    freshRound(run, 0, 0)
end

-- Josh plays one set (or all his sets left, once you're out of sets).
local function joshPlays(run)
    local josh = run.josh
    josh.steps, josh.lastResult = nil, nil
    repeat
        if josh.setsLeft <= 0 then break end
        local steps, result = pitboss.playSet(josh, run.joshGen)
        josh.total = josh.total + result.total
        josh.turns = josh.turns + 1
        josh.steps, josh.lastResult = steps, result
    until run.setsLeft > 0
    josh.turnId = (josh.turnId or 0) + 1
end

-- The duel is over: did you beat Josh?
local function endDuel(run)
    for _, held in ipairs(run.perkys) do held.disabled = nil end   -- your Perky works again
    if run.roundScore > run.josh.total then
        run.boss.beaten = true
        run.state = "victory"
        pipsgame.active = false
    else
        loseRun(run)
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
        boss = nil,               -- the boss of this boss round (nil = a normal round)
        pendingBoss = false,      -- a boss is waiting after this shop
        endless = false,
        -- VIP upgrades (vips.lua)
        vipOwned = {}, bonusSets = 0, bonusRerolls = 0, shopSlots = 0, perkySlots = 0,
        extraLife = false, vipOffer = nil, vipLevel = nil,
    }
    rng.setSeed(run.seed)
    -- Which levels end with a boss: one of 2-3, one of 5-7, one of 8-10.
    run.bossLevels = { rng.random(2, 3), rng.random(5, 7), rng.random(8, 10) }
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

-- A set was just scored (pipsgame.run.lastResult): what's next?
local function afterScore(run)
    if run.josh then
        joshPlays(run)
        run.state = "joshTurn"
    elseif run.roundScore >= run.goal then
        winRound(run)
    elseif run.setsLeft <= 0 then
        if run.extraLife and not run.boss then
            run.extraLife = false        -- the EXTRA LIFE saves the run (and is used up)
            winRound(run, true)
        else
            loseRun(run)
        end
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

-- NEXT: after a set is scored, or after Josh's turn.
function ACTIONS.next(run)
    if run.state == "scored" then
        afterScore(run)
    elseif run.state == "joshTurn" then
        if run.setsLeft <= 0 then endDuel(run) else startSet(run) end
    else
        return false
    end
    return true
end

-- On to the shop after winning a round.
function ACTIONS.toShop(run)
    if run.state ~= "roundWon" then return false end
    pipsshop.open(run)
    run.state = "shop"
    return true
end

-- FIGHT on the boss screen.
function ACTIONS.fight(run)
    if run.state ~= "bossIntro" then return false end
    if run.boss.josh then startDuel(run) else startBossRound(run) end
    return true
end

-- After beating Josh: keep going in ENDLESS (goals climb fast).
function ACTIONS.endless(run)
    if run.state ~= "victory" then return false end
    run.endless = true
    run.josh = nil
    pipsgame.active = true
    pipsshop.open(run)
    run.state = "shop"
    return true
end

-- Shop actions: pipsshop.lua does the work.
local SHOP = {
    buy = pipsshop.buy, shopReroll = pipsshop.reroll, spin = pipsshop.spin,
    pickReel = pipsshop.pickReel, pickPack = pipsshop.pickOption, replaceDie = pipsshop.replaceDie,
    skipPack = pipsshop.skipPack, sell = pipsshop.sell, buyVip = pipsshop.buyVip,
}
for name, fn in pairs(SHOP) do
    ACTIONS[name] = function(run, arg)
        if run.state ~= "shop" then return false end
        return fn(run, arg)
    end
end

-- Leave the shop: a boss if one is waiting, otherwise the next round (or
-- the next level, maybe with a new dice slot).
function ACTIONS.continue(run)
    if run.state ~= "shop" or run.shop.pack then return false end
    if run.pendingBoss then
        meetBoss(run)
        return true
    end
    run.boss = nil
    run.round = run.round + 1
    if run.round > P.ROUNDS then
        run.round = 1
        run.level = run.level + 1
        run.slots = pipsgame.slotsFor(run.level)
    end
    startRound(run)
    return true
end

-- GOD MODE (testing). Each use jumps to the NEXT shop:
--   * during a round  - win it (with its normal coins) and open the shop
--   * on ROUND WON     - open the shop
--   * in the shop      - play past the next round (winning it) to the shop after
--   * a boss / Josh    - beaten (beating Josh wins the run)
-- and fills every empty dice slot with a white die. The run is marked as
-- god mode (pipsgame.unranked), so it can't go on the leaderboard.
-- (pipsinput.lua asks "are you sure?" before the first use.)
function ACTIONS.god(run)
    if not config.GOD_MODE_ENABLED then return false end
    local s = run.state
    if s == "gameOver" or s == "victory" then return false end
    if s == "shop" then
        run.shop.pack = nil          -- close any open pack...
        ACTIONS.continue(run)        -- ...and start the next round (or meet the boss)
        s = run.state
    end
    if s == "bossIntro" then
        ACTIONS.fight(run)
        s = run.state
    end
    if run.josh and (s == "choose" or s == "scored" or s == "joshTurn") then
        run.setsLeft = 0
        run.roundScore = math.max(run.roundScore, run.josh.total + 1)
        endDuel(run)
        s = run.state
    elseif s == "choose" or s == "scored" then
        run.roundScore = math.max(run.roundScore, run.goal)
        winRound(run)
        s = run.state
    end
    if s == "roundWon" then
        pipsshop.open(run)
        run.state = "shop"
    end
    pipsgame.unranked = true
    -- Fill the empty slots with white dice.
    while #run.dice < run.slots do
        table.insert(run.dice, pipsdice.starter())
    end
    if run.state == "shop" then run.shop.message = "God mode: on to the shop, dice slots filled." end
    return true
end

-- The action names in a fixed order (for replay codes later): NEVER
-- reorder - only add to the end.
pipsgame.ACTION_NAMES = {
    "hold", "reroll", "score", "next", "toShop", "buy", "shopReroll", "spin",
    "pickReel", "pickPack", "replaceDie", "skipPack", "sell", "continue", "god",
    "fight", "endless", "buyVip",
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
