-- game.lua
-- One RUN of the game: the screens it moves through, and every ACTION the
-- player can take (place a marker, hold a die, throw, keep, buy, spin...).
--
-- Every action goes through game.act(name, arg). That one doorway is what
-- makes replays work: each action is written down in game.log, and a
-- replay just feeds the same actions back in, in the same order, starting
-- from the same random seed (see rng.lua and replay.lua).
--
-- main.lua turns clicks and keys into actions; replay.lua turns a replay
-- code back into actions. Nothing in here draws.
--
-- game.state is which screen the run is on:
--   "placeMarker" - start of a level: put your white chips on tiles, then ROLL
--   "play"        - throw the dice, hold some, reroll, or KEEP
--   "roundOver"   - the round has been scored; NEXT ROUND starts the next one
--   "levelClear"  - the level's goal was reached; confetti, then the shop
--   "victory"     - level 10 was cleared: keep going (ENDLESS) or finish
--   "gameOver"    - a level's goal was missed: the run is over
--   "finished"    - the player chose to finish after level 10: the run is over
--   "shop"        - between levels: dice, upgrades, Mystery Machine, markers

local config    = require("config")
local rng       = require("rng")
local dice      = require("dice")
local score     = require("score")
local player    = require("player")
local luck      = require("luck")
local luckrack  = require("luckrack")
local tutorial  = require("tutorial")
local markers   = require("markers")
local boosts    = require("boosts")
local upgrades  = require("upgrades")
local shop      = require("shop")
local godmode   = require("godmode")
local confetti  = require("confetti")
local animation = require("animation")
local bigwin    = require("bigwin")

local game = {}

-- The game types on the PLAY menu. 'growth' is how much bigger each
-- level's goal is than the one before (up to level 10; endless is x2).
-- 'late' is the growth from level 6 to 10 (steeper, so the late game stays tense).
game.MODES = {
    tutorial = { name = "TUTORIAL", growth = 1.25, late = 1.35 },
    normal   = { name = "NORMAL",   growth = 1.25, late = 1.35 },
    hard     = { name = "HARD",     growth = 1.35, late = 1.40 },
}

game.state    = "placeMarker"
game.mode     = "normal"
game.seed     = 0
game.log      = {}      -- every action so far: { {name, arg}, ... }
game.recording = true   -- false while a replay is playing (it has its own log)
game.instant  = false   -- true while a replay jumps ahead: no animations
game.endless  = false   -- true once the player keeps going after level 10
game.unranked = false   -- true if god mode was used (no leaderboard entry)
game.active   = false   -- is a run going at all?

-- Things other files want to hear about (main.lua plugs the stats in here).
-- game.events.round(result), .spin(), .runEnd()
game.events = {}

local roundEndPending = false   -- the last reroll is still rolling; score it when it stops

local function emit(name, ...)
    if game.events[name] then game.events[name](...) end
end


---------------------------------------------------------------------------
-- GAME FLOW
---------------------------------------------------------------------------

-- Begin a new round: all 5 dice back in the tray, waiting to be thrown.
local function startRound()
    -- Addict's automatic marker flips between 17 and 18 each round.
    markers.autoSum = luck.autoMarkerSum(score.round + 1)
    dice.newRound()
    game.state = "play"
end

-- Begin a level: "this level only" boosts come off, last level's markers
-- come off the table, and the player places new ones - unless their luck
-- item doesn't allow it (Addict), then we roll straight away.
local function beginLevel()
    boosts.clearLevel()
    markers.clear()
    markers.autoSum = nil
    -- From level 11 (endless) you may hold a 4th luck item.
    luck.MAX_HELD = (score.level > score.MAX_LEVEL) and 4 or 3
    if luck.blocksMarker() then
        startRound()
    else
        game.state = "placeMarker"
    end
end

local function openShop()
    confetti.stop()
    shop.open(score.level + 1)   -- fresh stock every visit, for the level coming up
    game.state = "shop"
end

-- The run is over (game over, or finished after level 10).
local function endRun(state)
    game.state = state
    if game.active then
        game.active = false
        emit("runEnd")
    end
end

-- The dice are final: score them, pay any coins, then decide what's next.
-- 'noReroll' is true if the player chose KEEP without rerolling.
local function finishRound(noReroll)
    local result = score.recordRound(dice.values, noReroll, dice.hasRerolled(), dice.firstSum)
    player.addCoins(result.coins)   -- coins from a Money Maker hand and luck items (0 if none)

    -- A huge round (40% / 75% of the level goal in one go) is a BIG / MEGA
    -- WIN, which pays bonus coins on top. (Jackpot Magnet lowers those.)
    result.winBonus = bigwin.check(result.points, score.getTarget(), luck.bigWinShares())
    if result.winBonus > 0 then
        player.addCoins(result.winBonus)
        score.levelCoins = score.levelCoins + result.winBonus
    end
    emit("round", result)

    -- The held luck items may stick a lasting boost onto the point just
    -- scored. (AFTER scoring, so the boost counts from the next time.)
    luck.onPointScored(result.sum)

    -- Clearing a level: Unlock Tokens, and Compound Interest on your coins.
    if score.isLevelOver() and score.hasPassedLevel() then
        if luck.givesUnlockTokens() then
            player.unlockTokens = player.unlockTokens + 1
        end
        local interest = luck.levelEndCoins(player.coins)
        player.addCoins(interest)
        score.levelCoins = score.levelCoins + interest
    end

    if not score.isLevelOver() then
        game.state = "roundOver"
    elseif score.hasPassedLevel() and score.level == score.MAX_LEVEL and not game.endless then
        game.state = "victory"          -- all 10 levels beaten!
        confetti.start()
    elseif score.hasPassedLevel() then
        game.state = "levelClear"
        confetti.start()
    else
        endRun("gameOver")
    end
end

-- The list of dice the next throw will send (all 5 on the first throw,
-- then every die that isn't held).
function game.diceToThrow()
    local list = {}
    for i = 1, config.NUM_DICE do
        if dice.willThrow(i) then table.insert(list, i) end
    end
    return list
end

-- Throw the dice. 'how' is "hand" (letting go of the handful held under
-- the mouse) or "auto" (THROW / REROLL, Enter, or a replay).
-- The results are decided first (in dice.lua); the physics then sends the
-- dice across the table and each settles onto its result. If that used
-- the last reroll, the round ends once the dice have stopped.
local function throwDice(how)
    if not dice.canThrow() then
        animation.cancelHold()
        return false
    end
    local isReroll = dice.nextThrowIsReroll()
    local thrown, which = dice.throw()
    if not thrown then
        animation.cancelHold()
        return false
    end
    if game.instant then
        animation.cancelHold()
    elseif how == "hand" then
        animation.release(dice.values)
    else
        animation.autoThrow(which, dice.values, player.loadout)
    end
    if isReroll and not dice.canReroll() then
        roundEndPending = true
        if game.instant then
            roundEndPending = false
            finishRound(false)
        end
    end
    return true
end

-- KEEP: keep all the dice as they are and end the round. The bonus only
-- counts if nothing has been rerolled. (Checked BEFORE dice.noReroll(),
-- which uses up the rerolls.)
local function keep()
    local earnedBonus = not dice.hasRerolled()
    if dice.noReroll() then
        finishRound(earnedBonus)
        return true
    end
    return false
end

-- Start a brand new run.
--   mode - "normal", "hard" or "tutorial"
--   seed - the random seed (a new one if nil)
function game.new(mode, seed)
    game.mode = mode
    game.seed = seed or rng.newSeed()
    rng.setSeed(game.seed)
    game.log = {}
    game.endless = false
    game.unranked = false
    game.active = true
    roundEndPending = false

    if mode == "tutorial" then tutorial.start() else tutorial.stop() end
    animation.stop()
    confetti.stop()
    bigwin.stop()
    score.reset()
    score.growth = game.MODES[mode].growth
    score.lateGrowth = game.MODES[mode].late
    score.endless = false
    player.reset()          -- 0 coins, 5 white dice, empty inventory
    boosts.reset()          -- no point boosts
    upgrades.reset()        -- no shop upgrades
    markers.reset()         -- back to one marker
    luck.reset()            -- no luck items...
    luck.give(luck.STARTER) -- ...except "Just Getting Started", which everyone starts with
    dice.rollAll()          -- fill the dice so they're never empty
    beginLevel()
end

-- Can replays and the leaderboard trust this run? (Tutorial throws are
-- set up by the tutorial, so they can't be replayed.)
function game.isReplayable()
    return game.mode ~= "tutorial"
end


---------------------------------------------------------------------------
-- ACTIONS (the only way the player changes the game)
---------------------------------------------------------------------------

-- What each action does. Each returns true if something happened.
-- 'arg' is a small whole number (which tile, which die, which card...).
local ACTIONS = {}

-- Marker tiles are numbered 1-26 for POINTS (sums 5-30) and 27-32 for
-- the six MONEY MAKERS.
function ACTIONS.marker(arg)
    if game.state ~= "placeMarker" then return false end
    if arg <= 26 then
        markers.toggle("points", score.sumBoxes()[arg].sum)
    else
        markers.toggle("coins", score.COIN_HANDS[arg - 26].id)
    end
    return true
end
function ACTIONS.clearMarkers()
    if game.state ~= "placeMarker" then return false end
    markers.clear()
    return true
end
-- ROLL on the marker screen (arg 1 = throw all 5 straight away, like Enter).
function ACTIONS.roll(arg)
    if game.state ~= "placeMarker" or not markers.allPlaced() then return false end
    startRound()
    if arg == 1 then throwDice("auto") end
    return true
end
function ACTIONS.throw(arg)
    if game.state ~= "play" then return false end
    return throwDice(arg == 1 and "hand" or "auto")
end
function ACTIONS.hold(arg)
    if game.state ~= "play" or not dice.canHold() then return false end
    dice.toggleHold(arg)
    return true
end
function ACTIONS.holdAll()
    if game.state ~= "play" or not dice.canHold() then return false end
    dice.holdAll()
    return true
end
function ACTIONS.keep()
    if game.state ~= "play" then return false end
    return keep()
end
-- NEXT ROUND (arg 1 = throw all 5 straight away).
function ACTIONS.nextRound(arg)
    if game.state ~= "roundOver" then return false end
    startRound()
    if arg == 1 then throwDice("auto") end
    return true
end
function ACTIONS.openShop()
    if game.state ~= "levelClear" then return false end
    openShop()
    return true
end
-- After level 10: keep going in ENDLESS mode (goals x2 each level).
function ACTIONS.endless()
    if game.state ~= "victory" then return false end
    game.endless = true
    score.endless = true
    openShop()
    return true
end
function ACTIONS.finish()
    if game.state ~= "victory" then return false end
    confetti.stop()
    endRun("finished")
    return true
end
-- Rearrange the luck items: arg = from x 10 + to (e.g. 13 = slot 1 to slot 3).
-- The order matters for Copycat, so it's an action (and in replays).
function ACTIONS.moveLuck(arg)
    if not (game.onTable() or game.state == "shop") then return false end
    return luck.move(math.floor(arg / 10), arg % 10)
end

-- Sell luck item k from the rack on the play screen.
function ACTIONS.sellRack(arg)
    if not (game.state == "placeMarker" or game.state == "play" or game.state == "roundOver") then return false end
    return luckrack.sell(arg)
end
-- Shop actions: shop.lua does the work.
local SHOP = {
    buyDice = shop.buyDice, buyUpgrade = shop.buyUpgrade, buyMarker = shop.buyMarker,
    sellShop = shop.sellLuck, take = shop.takePrize, selectInv = shop.selectInventory,
    equip = shop.equipTo,
}
for name, fn in pairs(SHOP) do
    ACTIONS[name] = function(arg)
        if game.state ~= "shop" then return false end
        fn(arg)
        return true
    end
end
function ACTIONS.spin()
    if game.state ~= "shop" then return false end
    local coinsBefore = player.coins
    shop.pullMystery()
    if game.instant then shop.update(100) end   -- a replay jumping ahead: stop the reels now
    if player.coins < coinsBefore then emit("spin") end
    return true
end
function ACTIONS.continue()
    if game.state ~= "shop" then return false end
    if shop.tryContinue() ~= "continue" then return true end   -- (a warning still counts)
    score.startNextLevel()
    beginLevel()
    return true
end
-- GOD MODE (testing): win the level, or more coins in the shop.
function ACTIONS.god()
    if not config.GOD_MODE_ENABLED then return false end
    game.unranked = true
    local s = game.state
    if s == "placeMarker" or s == "play" or s == "roundOver" then
        animation.stop()
        roundEndPending = false
        godmode.winLevel()
        if score.level == score.MAX_LEVEL and not game.endless then
            game.state = "victory"
            confetti.start()
        else
            openShop()
        end
    elseif s == "levelClear" then
        openShop()
    elseif s == "shop" then
        godmode.giveCoins()
        shop.message = "God mode: +" .. config.GOD_MODE_COINS .. " coins."
    else
        return false
    end
    return true
end

-- The action names in a fixed order: a replay code stores each action as
-- its position in this list, so NEVER reorder it - only add to the end.
game.ACTION_NAMES = {
    "marker", "clearMarkers", "roll", "throw", "hold", "holdAll", "keep", "nextRound",
    "openShop", "endless", "finish", "sellRack", "buyDice", "buyUpgrade", "buyMarker",
    "sellShop", "take", "selectInv", "equip", "spin", "continue", "god", "moveLuck",
}

-- Do an action. Returns true if it did something (and, while recording,
-- writes it into game.log).
function game.act(name, arg)
    local fn = ACTIONS[name]
    if fn == nil then return false end
    -- Write it down FIRST: the action might end the run, and the replay
    -- code is made the moment the run ends, so it must already be in the
    -- log. (The throw style - hand or auto - only changes the animation,
    -- so a replay doesn't need it.)
    local entry = { name, name == "throw" and 0 or (arg or 0) }
    if game.recording then table.insert(game.log, entry) end
    local done = fn(arg or 0)
    if not done and game.recording and game.log[#game.log] == entry then
        table.remove(game.log)       -- it didn't do anything: forget it
    end
    return done
end

-- Call every frame (after animation.update).
function game.update(dt)
    if game.state == "shop" then
        shop.update(dt)     -- the Mystery Machine's reels
    end
    -- The round ended while dice were rolling. Once they've all stopped,
    -- score it. (Cleared first so this only happens once.)
    if roundEndPending and not animation.isRolling() then
        roundEndPending = false
        finishRound(false)   -- false = no KEEP bonus (they rerolled)
    end
end

-- Is the game busy (dice moving, reels spinning, a round waiting to be
-- scored)? Replays wait for this before the next action.
function game.isBusy()
    return roundEndPending or animation.isRolling() or animation.isHolding()
        or (game.state == "shop" and shop.machine.spinning)
end

-- Is the run on a screen that shows the table with its dice?
function game.onTable()
    local s = game.state
    return s == "placeMarker" or s == "play" or s == "roundOver"
end

return game
