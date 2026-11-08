-- pipsinput.lua
-- PIPS MODE: turns clicks and keys into ACTIONS. It never changes the
-- run itself: it only says WHAT the player asked for, as
--   action, arg     e.g. "hold", 3    or "buy", 1
-- and main.lua does it with pipsgame.act(action, arg). (A few answers are
-- for main.lua itself: "again" = new run, "menu" = back to the menu,
-- "leave" = the MENU button during a run.)

local util       = require("util")
local pipsgame   = require("pipsgame")
local pipsshop   = require("pipsshop")
local pipsview   = require("pipsview")
local pipslayout = require("pipslayout")
local config     = require("config")

local pipsinput = {}

local inside = util.isInside

local function clickPlay(run, x, y)
    local s = run.state
    if s == "roundWon" then
        if inside(x, y, pipslayout.popupButton(1, 1)) then return "toShop" end
        return nil
    end
    if s == "victory" then
        if inside(x, y, pipslayout.popupButton(1, 3)) then return "endless" end
        if inside(x, y, pipslayout.popupButton(2, 3)) then return "again" end
        if inside(x, y, pipslayout.popupButton(3, 3)) then return "menu" end
        return nil
    end
    if s == "gameOver" then
        if inside(x, y, pipslayout.popupButton(1, 2)) then return "again" end
        if inside(x, y, pipslayout.popupButton(2, 2)) then return "menu" end
        return nil
    end
    if s == "bossIntro" then
        if inside(x, y, pipslayout.fightButton()) then return "fight" end
        return nil
    end
    if inside(x, y, pipslayout.menuButton()) then return "leave" end
    if pipsview.isRolling() then return nil end   -- wait for the dice to stop
    if s == "scored" or (s == "joshTurn" and pipsview.joshDone()) then
        if inside(x, y, pipslayout.nextButton()) then return "next" end
        return nil
    end
    if s == "choose" then
        local i = pipslayout.dieAt(x, y)
        if i then return "hold", i end
        if inside(x, y, pipslayout.rerollButton()) then return "reroll" end
        if inside(x, y, pipslayout.scoreButton()) then return "score" end
    end
    return nil
end

local function clickShop(run, x, y)
    if pipsview.isSpinning() then return nil end   -- wait for the reels to stop
    -- Selling works any time (even with a pack open, to make room).
    for k = 1, #run.perkys do
        if inside(x, y, pipslayout.sellButton(k)) then return "sell", k end
    end
    local pack = run.shop.pack
    if pack then
        -- Swapping a die out: click one of your dice.
        if pack.replacing then
            for i = 1, #run.dice do
                if inside(x, y, pipslayout.shopDie(i, run.slots)) then return "replaceDie", i end
            end
        end
        for k = 1, #pack.options do
            if inside(x, y, pipslayout.packOption(k, #pack.options)) then return "pickPack", k end
        end
        if inside(x, y, pipslayout.skipButton()) then return "skipPack" end
        return nil
    end
    for k = 1, #run.shop.items do
        if inside(x, y, pipslayout.itemCard(k)) then return "buy", k end
    end
    if inside(x, y, pipslayout.shopRerollButton()) then return "shopReroll" end
    if inside(x, y, pipslayout.spinButton()) then return "spin" end
    if pipsshop.hasUntakenReels(run) then
        for k = 1, 3 do
            if inside(x, y, pipslayout.reel(k)) then return "pickReel", k end
        end
    end
    if inside(x, y, pipslayout.continueButton()) then return "continue" end
    return nil
end

-- A click at (x, y). Gives back an action and its arg (or nil).
function pipsinput.click(x, y)
    local run = pipsgame.run
    if not run then return nil end
    -- The god mode question: YES turns it on (and jumps ahead), NO closes it.
    if pipsview.godPrompt then
        if inside(x, y, pipslayout.popupButton(1, 2)) then
            pipsview.godPrompt = false
            return "god"
        end
        if inside(x, y, pipslayout.popupButton(2, 2)) then pipsview.godPrompt = false end
        return nil
    end
    if run.state == "shop" then return clickShop(run, x, y) end
    return clickPlay(run, x, y)
end

-- A key press. Gives back an action and its arg (or nil).
function pipsinput.key(key)
    local run = pipsgame.run
    if not run then return nil end
    local enter = key == "return" or key == "kpenter"
    -- GOD MODE: the first ` asks "are you sure?"; pressing ` again says
    -- yes. Once it's on, every ` jumps straight to the next shop.
    if key == "`" and config.GOD_MODE_ENABLED then
        if pipsgame.unranked or pipsview.godPrompt then
            pipsview.godPrompt = false
            return "god"
        end
        pipsview.godPrompt = true
        return nil
    end
    if pipsview.godPrompt then
        pipsview.godPrompt = false   -- any other key means no
        return nil
    end
    local s = run.state
    if s == "roundWon" then
        if enter or key == "space" then return "toShop" end
    elseif s == "gameOver" then
        if enter then return "again" elseif key == "m" then return "menu" end
    elseif s == "victory" then
        if enter then return "endless" elseif key == "m" then return "menu" end
    elseif s == "bossIntro" then
        if enter or key == "space" then return "fight" end
    elseif s == "joshTurn" then
        if (enter or key == "space") and pipsview.joshDone() then return "next" end
    elseif s == "shop" then
        if pipsview.isSpinning() then return nil end
        if enter and not run.shop.pack then return "continue" end
    elseif not pipsview.isRolling() then
        if s == "scored" and (enter or key == "space") then return "next" end
        if s == "choose" then
            if enter then return "score" end
            if key == "r" then return "reroll" end
            -- 1-9 hold dice 1-9, and 0 holds die 10.
            local n = tonumber(key)
            if n then
                if n == 0 then n = 10 end
                if run.dice[n] then return "hold", n end
            end
        end
    end
    return nil
end

return pipsinput
