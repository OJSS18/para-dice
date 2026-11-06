-- tools/strategy-sim/strategies.lua
-- The bot strategies (see sim.lua for what each field means).

-- Luck items that help any points strategy, best first.
local POINTS_LUCK = {
    "evenSteven", "thatsOdd", "secondChance",
    "rabbitsLeg", "rabbitsFoot", "theySeeMeRollin", "crowdFavourite",
    "showMeTheMoney", "luckySeven", "pureBreed",
}
-- Extra ones that suit LOW dice (lots of 1s and 2s).
local LOW_LUCK = {
    "evenSteven", "thatsOdd", "secondChance",
    "lowballDeluxe", "rabbitsLeg", "rabbitsFoot", "tripleThreat1", "showMeTheMoneyRare",
    "theySeeMeRollin", "doubleTrouble1", "crowdFavourite", "lowball", "snakeEyes", "showMeTheMoney",
}
local AVOID = { "addict" }

return {
    { name = "1 Always Keep",      reroll = "never", coinWeight = 0 },
    { name = "2 Reroll Everything", reroll = "all",  coinWeight = 0 },
    { name = "3 Smart Rerolls",     reroll = "ev",   coinWeight = 0 },
    { name = "4 Smart + Markers & Keep Bonus", reroll = "ev", coinWeight = 0,
      upgrades = { "keep" }, markers = true },
    { name = "5 High Roller (red dice, UPPER 13)", reroll = "ev", coinWeight = 0,
      dice = { "red" }, upgrades = { "upper", "keep" }, markers = true },
    { name = "6 Low Roller (blue + amber, LOWER 13)", reroll = "ev", coinWeight = 0,
      dice = { "amber", "blue" }, upgrades = { "lower", "keep" }, markers = true },
    { name = "7 Extremist (purple dice)", reroll = "ev", coinWeight = 0,
      dice = { "purple" }, upgrades = { "lower", "upper" }, markers = true },
    { name = "8 Mystery Machine Gambler", reroll = "ev", coinWeight = 0,
      spin = true, luckPrefs = POINTS_LUCK, luckAvoid = AVOID },
    { name = "9 Money Maker (chase hands)", reroll = "ev", coinWeight = 2,
      dice = { "amber", "blue" }, upgrades = { "lower" }, markers = true,
      spin = true, luckPrefs = LOW_LUCK, luckAvoid = AVOID },
    { name = "10 Low Roller + Luck", reroll = "ev", coinWeight = 0.5,
      dice = { "amber", "blue" }, upgrades = { "lower", "keep" }, markers = true, maxMarkers = 3,
      spin = true, luckPrefs = LOW_LUCK, luckAvoid = AVOID },
    { name = "11 Spin First, Coin-Aware", reroll = "ev", coinWeight = 1,
      shopOrder = { "spin", "dice", "upgrades" }, dice = { "amber", "blue" }, upgrades = { "lower" },
      spin = true, luckPrefs = POINTS_LUCK, luckAvoid = AVOID },
    { name = "12 Odd + Even Hunter", reroll = "ev", coinWeight = 1,
      shopOrder = { "spin", "dice", "upgrades" }, dice = { "amber", "blue" }, upgrades = { "lower" },
      spin = true, luckAvoid = AVOID, luckPrefs = {
          "evenSteven", "thatsOdd", "secondChance",
          "rabbitsLeg", "rabbitsFoot", "theySeeMeRollin", "lowballDeluxe",
          "crowdFavourite", "showMeTheMoney" } },
    { name = "13 Spin First, no Even+Odd combo", reroll = "ev", coinWeight = 1,
      shopOrder = { "spin", "dice", "upgrades" }, dice = { "amber", "blue" }, upgrades = { "lower" },
      spin = true, luckPrefs = POINTS_LUCK, luckAvoid = { "addict", "evenSteven", "thatsOdd" } },
}
