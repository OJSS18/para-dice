-- godmode.lua
-- A TESTING CHEAT. Press the ` key (the ~ key, top-left under Escape):
--   * during a level -> the level is won right away and you go to the shop
--   * in the shop     -> you get more coins, to test buying
-- Each use gives config.GOD_MODE_COINS coins.
--
-- Turn it off by setting config.GOD_MODE_ENABLED = false in config.lua.
--
-- This file only changes the DATA (score and coins). main.lua decides
-- which screen to show afterwards, because main.lua owns 'state'.

local config = require("config")
local score  = require("score")
local player = require("player")

local godmode = {}

-- Is this key the god mode key (and is god mode switched on)?
-- LÖVE calls the ` / ~ key "`" (pressing Shift for ~ is still the same key).
function godmode.isTrigger(key)
    return config.GOD_MODE_ENABLED and key == "`"
end

-- Force a win for the current level:
-- all rounds count as played and the level score is topped up to the target.
function godmode.winLevel()
    score.round = score.ROUNDS_PER_LEVEL
    if score.levelTotal < score.getTarget() then
        score.levelTotal = score.getTarget()
    end
    player.addCoins(config.GOD_MODE_COINS)
end

-- Just hand over coins (used while already in the shop).
function godmode.giveCoins()
    player.addCoins(config.GOD_MODE_COINS)
end

return godmode
