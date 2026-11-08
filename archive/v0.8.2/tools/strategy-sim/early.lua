-- tools/strategy-sim/early.lua
-- EARLY-GAME strategies: 20 ways to play aimed at getting through the
-- first levels strongly (scored by how often a run REACHES level 5), and
-- for every one that does it at least half the time, 5 "synergy" branches
-- built around 2-3 luck items that work together.
-- Run: EARLYTEST=1 bash tools/strategy-sim/run.sh 100 <seed>

local early = {}

-- Every strategy here thinks about its luck items when holding dice.
local function S(t)
    t.reroll = t.reroll or "ev"
    t.coinWeight = t.coinWeight or 0
    t.perkAware = true
    t.luckAvoid = t.luckAvoid or { "addict", "loadedDie", "unlockToken" }
    return t
end

local ROUND_PERKS = { "doubleDown", "hatTrick", "hotDice", "firstImpression", "underdog", "pairUp",
    "comebackKid", "skyHigh", "lowballDeluxe", "evenSteven", "thatsOdd" }
local COIN_PERKS = { "fyPayMe", "cashIsKing", "collector", "interest", "tipJar", "piggyBank", "pocketChange", "steadyHand" }
local LOW_PERKS = { "lowballDeluxe", "lowball", "snakeEyes", "doubleTrouble1", "tripleThreat1", "piggyBank", "doubleDown" }
local HIGH_PERKS = { "hotDice", "skyHigh", "highroller", "doubleTrouble6", "tripleThreat6", "midasDice", "hatTrick" }
local REROLL_PERKS = { "secondChance", "theySeeMeRollin", "doubleDown", "comebackKid", "copycat" }

early.base = {
    S{ name = "E1 Amber Rush", dice = { "amber" }, upgrades = { "lower" }, markers = true, maxMarkers = 2 },
    S{ name = "E2 Amber + Spins", dice = { "amber" }, upgrades = { "lower" }, spin = true, luckPrefs = ROUND_PERKS },
    S{ name = "E3 Blue Budget", dice = { "blue" }, upgrades = { "lower" } },
    S{ name = "E4 Red + Upper 13", dice = { "red" }, upgrades = { "upper" } },
    S{ name = "E5 Purple Split", dice = { "purple" }, upgrades = { "lower", "upper" } },
    S{ name = "E6 Lower 13 Stack", upgrades = { "lower" } },
    S{ name = "E7 Upgrades, then Amber", shopOrder = { "upgrades", "dice" }, dice = { "amber", "blue" }, upgrades = { "lower", "even" } },
    S{ name = "E8 Marker Max", markers = true, upgrades = { "lower" }, dice = { "amber" } },
    S{ name = "E9 Coin Engine", coinWeight = 2, spin = true, shopOrder = { "spin", "dice" }, dice = { "amber" }, luckPrefs = COIN_PERKS },
    S{ name = "E10 Round-Perk Spinner", spin = true, shopOrder = { "spin", "dice", "upgrades" }, dice = { "amber" }, upgrades = { "lower" }, luckPrefs = ROUND_PERKS },
    S{ name = "E11 Reroll Lover", spin = true, dice = { "amber", "blue" }, luckPrefs = REROLL_PERKS },
    S{ name = "E12 Keeper", upgrades = { "keep", "lower" }, spin = true, luckPrefs = { "firstImpression", "steadyHand", "pairUp", "underdog" } },
    S{ name = "E13 Even + Odd", upgrades = { "even", "odd" }, spin = true, luckPrefs = { "evenSteven", "thatsOdd", "copycat" } },
    S{ name = "E14 Low Luck", dice = { "amber", "blue" }, upgrades = { "lower" }, spin = true, luckPrefs = LOW_PERKS },
    S{ name = "E15 High Luck", dice = { "red" }, upgrades = { "upper" }, spin = true, luckPrefs = HIGH_PERKS },
    S{ name = "E16 Saver (interest)", reserve = 60, coinWeight = 1, spin = true, dice = { "amber" }, luckPrefs = { "interest", "collector", "cashIsKing", "tipJar" } },
    S{ name = "E17 Balanced", coinWeight = 0.5, dice = { "amber" }, upgrades = { "lower" }, markers = true, maxMarkers = 2, spin = true, luckPrefs = ROUND_PERKS },
    S{ name = "E18 One Spin a Shop", maxSpins = 1, dice = { "amber" }, upgrades = { "lower" }, spin = true, luckPrefs = ROUND_PERKS },
    S{ name = "E19 Dice First", dice = { "amber", "blue", "purple" }, spin = true, luckPrefs = ROUND_PERKS },
    S{ name = "E20 Middle Road (Green)", dice = { "green" }, upgrades = { "common" }, spin = true, luckPrefs = { "middleRoad", "underdog", "pairUp" } },
}

-- 5 synergy branches for a successful strategy: its dice, upgrades and
-- shop habits stay; its Mystery Machine wish list now starts with 2-3
-- items that work together.
local SYNERGIES = {
    { tag = "Double Down + Copycat + Second Chance", luck = { "doubleDown", "copycat", "secondChance", "theySeeMeRollin" } },
    { tag = "Collector + Tip Jar + Piggy Bank", luck = { "collector", "tipJar", "piggyBank", "cashIsKing" }, coinWeight = 1.5 },
    { tag = "LOWFACE", low = { "lowballDeluxe", "snakeEyes", "piggyBank" }, high = { "hotDice", "hatTrick", "skyHigh" } },
    { tag = "Even Steven + That's Odd + Copycat", luck = { "evenSteven", "thatsOdd", "copycat" } },
    { tag = "Show Me The Money + Rabbit's Leg + Copycat", luck = { "showMeTheMoney", "rabbitsLeg", "copycat", "rabbitsFoot" } },
}

local function isHigh(parent)
    for _, d in ipairs(parent.dice or {}) do
        if d == "red" then return true end
    end
    return false
end

function early.branches(parent)
    local out = {}
    for _, syn in ipairs(SYNERGIES) do
        local s = {}
        for k, v in pairs(parent) do s[k] = v end
        local luckList, tag = syn.luck, syn.tag
        if syn.low then
            luckList = isHigh(parent) and syn.high or syn.low
            tag = isHigh(parent) and "Hot Dice + Hat Trick + Sky High" or "Lowball Deluxe + Snake Eyes + Piggy Bank"
        end
        s.luckPrefs = {}
        for _, id in ipairs(luckList) do table.insert(s.luckPrefs, id) end
        for _, id in ipairs(parent.luckPrefs or ROUND_PERKS) do table.insert(s.luckPrefs, id) end
        s.spin = true
        if syn.coinWeight then s.coinWeight = math.max(s.coinWeight, syn.coinWeight) end
        s.name = parent.name:match("^(E%d+)") .. " > " .. tag
        table.insert(out, s)
    end
    return out
end

return early
