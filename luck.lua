-- luck.lua
-- LUCK ITEMS: the player can hold ONE at a time. Buying a new one in the
-- shop replaces the old one. Every game starts with "Run it Back".
--
-- Each item is a table of DATA describing what it does. The functions at
-- the bottom read those fields, so adding a new item usually means adding
-- one table here - no new code. The fields an item can have:
--
--   id, name, rarity, about, image   - the basics (the price comes from the rarity)
--   duration       - how long it lasts (one of):
--                      { rolls = 20 }      20 rolls (a fresh roll or a reroll = 1)
--                      { levels = 1 }      the next level only
--                      { untilLevel = 3 }  gone at the start of level 3
--   pointRunMult   - each point you roll gets x this for the rest of the RUN
--   pointRunFlat   - each point you roll gets + this many points for the rest of the RUN
--   pointLevelMult - each point you roll gets x this for the rest of the LEVEL
--   extraRerolls   - extra rerolls every round
--   noRerolls      - true = no rerolls at all
--   noMarker       - true = you can't place your own marker
--   autoMarker     - a marker that flips between these sums each round, e.g. {17, 18}
--   targetMult     - multiplies the level's score goal (0.75 = 25% lower)
--   coinsMult      - multiplies every coin you earn
--   evenMult       - multiplies the points of EVEN sums
--   oddMult        - multiplies the points of ODD sums
--   payMe          - true = also earn coins equal to the point's value
--   unlockTokens   - true = earn an Unlock Token for each level you beat
--
-- Each item boosts a given point only ONCE (the first time you roll it
-- while holding the item). Boosts from different items stack.
--
-- Pure LOGIC/data - nothing in here draws.

local config = require("config")
local boosts = require("boosts")

local luck = {}

-- Everything about each rarity, in one place:
--   shop    - % chance a shop luck card is this rarity
--   mystery - % chance the MYSTERY MACHINE gives this rarity
--   price   - what an item of this rarity costs in the shop
--   color   - the colour its name and border are shown in
--   minShopLevel - the shop won't sell this rarity before this level
--                  (the Mystery Machine still can)
luck.RARITIES = {
    starter   = { shop = 0,  mystery = 0,    color = { 0.75, 0.75, 0.78 }, label = "STARTER" },
    common    = { shop = 40, mystery = 20, price = 10,  color = { 0.68, 0.68, 0.72 }, label = "COMMON" },
    uncommon  = { shop = 30, mystery = 35, price = 25,  color = { 0.30, 0.88, 0.35 }, label = "UNCOMMON" },
    rare      = { shop = 20, mystery = 25, price = 50,  color = { 0.30, 0.58, 1.00 }, label = "RARE",
                  minShopLevel = 4 },
    epic      = { shop = 9,  mystery = 15, price = 75,  color = { 0.72, 0.35, 1.00 }, label = "EPIC",
                  minShopLevel = 4 },
    legendary = { shop = 1,  mystery = 5,  price = 100, color = { 1.00, 0.82, 0.20 }, label = "LEGENDARY" },
}

-- What an item costs (set by its rarity).
function luck.price(item)
    return luck.RARITIES[item.rarity].price
end

local ROLLS = { rolls = config.LUCK_DURATION }   -- the usual 20 rolls

-- Every luck item, keyed by id.
luck.ITEMS = {
    -- STARTER (everyone begins with this; never sold)
    runItBack = {
        name = "Run it Back", rarity = "starter", image = nil,
        about = "Every point you score gets x1.1 for the rest of the run. Gone at the start of Level 3.",
        duration = { untilLevel = 3 }, pointRunMult = 1.1,
    },

    -- COMMON
    addict = {
        name = "Addict", rarity = "common", image = "addict",
        about = "No rerolls and no marker of your own - a marker flips between 17 and 18. This level's goal is 25% lower.",
        duration = { levels = 1 },
        noRerolls = true, noMarker = true, autoMarker = { 17, 18 }, targetMult = 0.75,
    },
    rabbitsFoot = {
        name = "Rabbit's Foot", rarity = "common", image = "rabbitsFoot",
        about = "Every point you roll pays x1.75 for the rest of the level.",
        duration = ROLLS, pointLevelMult = 1.75,
    },

    -- UNCOMMON
    rabbitsLeg = {
        name = "Rabbit's Leg", rarity = "uncommon", image = "rabbitsLeg",
        about = "Every point you roll gets x1.5 for the rest of the run.",
        duration = ROLLS, pointRunMult = 1.5,
    },
    showMeTheMoney = {
        name = "Show Me The Money", rarity = "uncommon", image = "showMeTheMoney",
        about = "Every point you roll gets +100 points for the rest of the run.",
        duration = ROLLS, pointRunFlat = 100,
    },

    -- RARE
    showMeTheMoneyRare = {
        name = "Show Me The Money", rarity = "rare", image = "showMeTheMoneyRare",
        about = "Every point you roll gets +200 points for the rest of the run.",
        duration = ROLLS, pointRunFlat = 200,
    },
    theySeeMeRollin = {
        name = "They See Me Rollin'", rarity = "rare", image = "theySeeMeRollin",
        about = "Get an extra reroll every round.",
        duration = ROLLS, extraRerolls = 1,
    },
    cashIsKing = {
        name = "Cash is King", rarity = "rare", image = "cashIsKing",
        about = "Any time you earn coins, DOUBLE IT!",
        duration = ROLLS, coinsMult = 2,
    },

    -- EPIC
    showMeTheMoneyEpic = {
        name = "Show Me The Money", rarity = "epic", image = "showMeTheMoneyEpic",
        about = "Every point you roll gets +300 points and x1.25 for the rest of the run.",
        duration = ROLLS, pointRunFlat = 300, pointRunMult = 1.25,
    },
    evenSteven = {
        name = "Even Steven", rarity = "epic", image = "evenSteven",
        about = "Every EVEN sum you score is doubled (on top of any other multiplier).",
        duration = ROLLS, evenMult = 2,
    },
    thatsOdd = {
        name = "Hmm... That's Odd", rarity = "epic", image = "thatsOdd",
        about = "Every ODD sum you score is doubled (on top of any other multiplier).",
        duration = ROLLS, oddMult = 2,
    },

    -- LEGENDARY
    showMeTheMoneyLegendary = {
        name = "Show Me The Money", rarity = "legendary", image = "showMeTheMoneyLegendary",
        about = "Every point you roll gets +500 points and x1.75 for the rest of the run.",
        duration = ROLLS, pointRunFlat = 500, pointRunMult = 1.75,
    },
    fyPayMe = {
        name = "F*** You Pay Me", rarity = "legendary", image = "fyPayMe",
        about = "Earn coins equal to the value of every point you score.",
        duration = ROLLS, payMe = true,
    },
    unlockToken = {
        name = "Unlock Token", rarity = "legendary", image = "unlockToken",
        about = "Earn a special Unlock Token for every level you beat while holding this.",
        duration = ROLLS, unlockTokens = true,
    },
}

-- Fill in each item's id from its key, so items don't have to repeat it.
for id, item in pairs(luck.ITEMS) do
    item.id = id
end

-- The ids as an ordered list (tables keyed by name have no order).
luck.ORDER = {
    "runItBack", "addict", "rabbitsFoot", "rabbitsLeg", "showMeTheMoney",
    "showMeTheMoneyRare", "theySeeMeRollin", "cashIsKing",
    "showMeTheMoneyEpic", "evenSteven", "thatsOdd",
    "showMeTheMoneyLegendary", "fyPayMe", "unlockToken",
}

luck.STARTER = "runItBack"


---------------------------------------------------------------------------
-- DATA: what the player is holding right now
---------------------------------------------------------------------------

luck.current     = nil   -- id of the held item, or nil for none
luck.rollsLeft   = nil   -- for { rolls = N } items
luck.levelsSeen  = 0     -- for { levels = N } items: level starts since it was given
luck.boostedSums = {}    -- points this item has already boosted (each only once)


---------------------------------------------------------------------------
-- BASICS
---------------------------------------------------------------------------

function luck.get(id)
    return luck.ITEMS[id]
end

-- The held item's table, or nil.
local function held()
    return luck.current and luck.ITEMS[luck.current]
end

-- The colour for an item's rarity.
function luck.rarityColor(item)
    return luck.RARITIES[item.rarity].color
end

-- Give the player an item. Any item they already had is REPLACED.
function luck.give(id)
    local item = luck.ITEMS[id]
    luck.current     = id
    luck.rollsLeft   = item.duration.rolls
    luck.levelsSeen  = 0
    luck.boostedSums = {}
end

function luck.clear()
    luck.current     = nil
    luck.rollsLeft   = nil
    luck.levelsSeen  = 0
    luck.boostedSums = {}
end

-- Short text for how long the held item has left, e.g. "14 rolls".
function luck.timeLeftText()
    local item = held()
    if item == nil then return "" end
    local d = item.duration
    if d.rolls then
        return luck.rollsLeft .. " rolls"
    elseif d.levels then
        return "this level"
    else
        return "until L" .. d.untilLevel
    end
end

-- How long an item lasts, as words (for the shop card).
function luck.durationText(item)
    local d = item.duration
    if d.rolls then
        return "Lasts " .. d.rolls .. " rolls"
    elseif d.levels then
        return "Lasts " .. d.levels .. " level"
    else
        return "Gone at Level " .. d.untilLevel
    end
end


---------------------------------------------------------------------------
-- WEARING OFF
---------------------------------------------------------------------------

-- Call just BEFORE every roll (fresh roll or reroll). Only "rolls" items
-- count down. An item with 0 rolls left is used up, so it disappears
-- before this roll - that way an item's last roll still gets scored with it.
function luck.useRoll()
    if luck.rollsLeft == nil then return end
    if luck.rollsLeft <= 0 then
        luck.clear()
    else
        luck.rollsLeft = luck.rollsLeft - 1
    end
end

-- Call at the start of every level (before anything else happens).
function luck.onLevelStart(level)
    local item = held()
    if item == nil then return end
    local d = item.duration
    if d.untilLevel and level >= d.untilLevel then
        luck.clear()
    elseif d.levels then
        if luck.levelsSeen >= d.levels then
            luck.clear()                -- its levels are used up
        else
            luck.levelsSeen = luck.levelsSeen + 1
        end
    end
end


---------------------------------------------------------------------------
-- EFFECTS (other files ask these questions)
---------------------------------------------------------------------------

-- How many rerolls the player gets each round.
function luck.rerollsPerRound(normal)
    local item = held()
    if item == nil then return normal end
    if item.noRerolls then return 0 end
    return normal + (item.extraRerolls or 0)
end

-- Can the player place their own marker?
function luck.blocksMarker()
    local item = held()
    return item ~= nil and item.noMarker == true
end

-- The automatic marker's sum for this round (round = 1, 2, 3...), or nil.
function luck.autoMarkerSum(round)
    local item = held()
    if item == nil or item.autoMarker == nil then return nil end
    local list = item.autoMarker
    return list[((round - 1) % #list) + 1]   -- round 1 -> 17, round 2 -> 18, round 3 -> 17...
end

-- What the level's score goal is multiplied by.
function luck.targetMultiplier()
    local item = held()
    return (item and item.targetMult) or 1
end

-- What every coin earned is multiplied by.
function luck.coinsMultiplier()
    local item = held()
    return (item and item.coinsMult) or 1
end

-- Extra multiplier on a sum's points from Even Steven / That's Odd.
function luck.sumMultiplier(sum)
    local item = held()
    if item == nil then return 1 end
    if sum % 2 == 0 then
        return item.evenMult or 1      -- % is "remainder": an even number % 2 is 0
    end
    return item.oddMult or 1
end

-- Extra coins for scoring a point worth 'points' (F*** You Pay Me).
function luck.payMeCoins(points)
    local item = held()
    if item and item.payMe then
        return points
    end
    return 0
end

-- Does the held item hand out Unlock Tokens?
function luck.givesUnlockTokens()
    local item = held()
    return item ~= nil and item.unlockTokens == true
end

-- A point was just scored: stick this item's boosts onto it (once per point).
function luck.onPointScored(sum)
    local item = held()
    if item == nil or luck.boostedSums[sum] then return end

    if item.pointRunMult or item.pointRunFlat then
        boosts.addRun(sum, item.pointRunMult, item.pointRunFlat)
        luck.boostedSums[sum] = true
    end
    if item.pointLevelMult and not boosts.hasLevel(sum) then
        boosts.addLevel(sum, item.pointLevelMult)
        luck.boostedSums[sum] = true
    end
end


---------------------------------------------------------------------------
-- THE SHOP
---------------------------------------------------------------------------

-- Pick a random item id. It's done in two steps:
--   1. pick a RARITY using a set of % chances - 'oddsKey' says which:
--        "shop"    = 40 / 30 / 20 / 9 / 1   (common ... legendary)
--        "mystery" = 20 / 35 / 25 / 15 / 5  (the Mystery Machine)
--   2. pick one item of that rarity, all equally likely.
-- 'exclude' is a list of ids that mustn't be picked (so the shop doesn't
-- show the same item twice).
-- 'level' (optional) - if given, rarities with a minShopLevel above it are
-- left out (no rare or epic in the shop before level 4).
function luck.randomItem(oddsKey, exclude, level)
    local skip = {}
    for _, id in ipairs(exclude or {}) do skip[id] = true end

    -- Sort the items that can be picked into lists, one per rarity.
    local byRarity = {}
    for _, id in ipairs(luck.ORDER) do
        local rarity = luck.ITEMS[id].rarity
        local info = luck.RARITIES[rarity]
        local tooEarly = level and info.minShopLevel and level < info.minShopLevel
        if not skip[id] and info[oddsKey] > 0 and not tooEarly then
            byRarity[rarity] = byRarity[rarity] or {}
            table.insert(byRarity[rarity], id)
        end
    end

    -- Step 1: same "ruler" idea as dicetypes.pickFace - lay the rarities'
    -- chances end to end, pick a random spot, see whose stretch it's in.
    -- (If some rarities were left out, the rest share the ruler between them.)
    local total = 0
    for rarity, _ in pairs(byRarity) do
        total = total + luck.RARITIES[rarity][oddsKey]
    end
    local spot = love.math.random() * total
    for rarity, list in pairs(byRarity) do
        spot = spot - luck.RARITIES[rarity][oddsKey]
        if spot < 0 then
            -- Step 2: any item of that rarity.
            return list[love.math.random(1, #list)]
        end
    end
    return "rabbitsFoot"   -- safety net; normally never reached
end

-- The old luck items changed dice odds. None of the current ones do, but
-- dice.lua still asks, so this just hands the weights straight back.
function luck.applyTo(weights)
    return weights
end

return luck
