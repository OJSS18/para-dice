-- luck.lua
-- LUCK ITEMS (perks). They are PERMANENT: once you have one, it stays
-- until you SELL it. You can hold up to luck.MAX_HELD (3) at once, and
-- sell any of them at any time for half its value.
--
-- The only way to get new ones is the MYSTERY MACHINE in the shop: each
-- spin shows 3 items and you pick ONE. Every game starts with "Run it Back".
--
-- Each item is a table of DATA describing what it does. The functions at
-- the bottom read those fields, so adding a new item usually means adding
-- one table here. The fields an item can have:
--
--   id, name, rarity, about, image   - the basics
--   weight         - how likely it is picked within its rarity (default 1).
--                    The six "Double Trouble" cards share one item's worth.
--
--   LASTING BOOSTS (stuck onto the POINTS tile you land on - they STACK)
--   pointRunMult   - each point you roll gets x this for the rest of the RUN
--   pointRunFlat   - each point you roll gets + this many points for the rest of the RUN
--   pointLevelMult - each point you roll gets x this for the rest of the LEVEL
--
--   ROUND BONUSES (checked against the 5 final dice every round)
--   check          - function(d) that returns true when the bonus pays.
--                    'd' describes the dice - see luck.diceFacts below.
--   mult, flat     - what it pays when 'check' is true: x mult points, + flat points
--   coins          - ... and + this many coins
--   bonus          - function(d) returning mult, flat, coins - for bonuses
--                    that grow (Midas Dice: +0.2x for every 6)
--
--   RULE CHANGES
--   extraRerolls   - extra rerolls every round
--   noRerolls      - true = no rerolls at all
--   noMarker       - true = you can't place your own marker
--   autoMarker     - a marker that flips between these sums each round, e.g. {17, 18}
--   targetMult     - multiplies the level's score goal (0.75 = 25% lower)
--   coinsMult      - multiplies every coin you earn
--   handCoinsMult  - multiplies one Money Maker's coins, e.g. { fullHouse = 2 }
--   payMe          - true = also earn coins equal to the point's value
--   unlockTokens   - true = earn an Unlock Token for each level you beat
--   loadedDie      - true = your FIRST die never lands on 1 or 2
--   bigWinShares   - { big, mega } - lower BIG WIN / MEGA WIN thresholds
--   allHandsMult   - multiplies the coins of EVERY Money Maker hand
--   interest, interestCap - clearing a level pays this share of your coins (up to the cap)
--   copyLeft       - true = acts as a copy of the item in the slot to its LEFT
--
-- Items hold their slot order: you can drag them (or press L and the
-- arrow keys) to rearrange them - which matters for Copycat.
--
-- Pure LOGIC/data - nothing in here draws.

local boosts = require("boosts")
local util   = require("util")

local luck = {}

luck.MAX_HELD = 3

-- Everything about each rarity, in one place:
--   mystery - % chance the MYSTERY MACHINE gives this rarity
--   value   - what an item of this rarity is worth (you SELL for half)
--   color   - the colour its name and border are shown in
luck.RARITIES = {
    starter   = { mystery = 0,  value = 10,  color = { 0.75, 0.75, 0.78 }, label = "STARTER" },
    common    = { mystery = 30, value = 10,  color = { 0.68, 0.68, 0.72 }, label = "COMMON" },
    uncommon  = { mystery = 30, value = 25,  color = { 0.30, 0.88, 0.35 }, label = "UNCOMMON" },
    rare      = { mystery = 22, value = 50,  color = { 0.30, 0.58, 1.00 }, label = "RARE" },
    epic      = { mystery = 13, value = 75,  color = { 0.72, 0.35, 1.00 }, label = "EPIC" },
    legendary = { mystery = 5,  value = 100, color = { 1.00, 0.82, 0.20 }, label = "LEGENDARY" },
}

-- What selling an item pays: half its rarity's value, rounded down.
function luck.sellPrice(item)
    return math.floor(luck.RARITIES[item.rarity].value / 2)
end


---------------------------------------------------------------------------
-- THE ITEMS
---------------------------------------------------------------------------

-- Small helpers the 'check' functions use. 'd' is from luck.diceFacts.
local function allOf(d, test)
    for _, v in ipairs(d.values) do
        if not test(v) then return false end
    end
    return true
end
local function isEven(v) return v % 2 == 0 end
local function isOdd(v)  return v % 2 == 1 end

luck.ITEMS = {
    -- STARTER (everyone begins with this)
    runItBack = {
        name = "Run it Back", rarity = "starter", image = "runItBack",
        about = "Each time a point hits, it gets another x1.1 for the rest of the run.",
        pointRunMult = 1.1,
    },

    -- COMMON
    addict = {
        name = "Addict", rarity = "common", image = "addict",
        about = "No rerolls, no marker of your own (an auto marker flips 17/18). Level goals 25% lower.",
        noRerolls = true, noMarker = true, autoMarker = { 17, 18 }, targetMult = 0.75,
    },
    rabbitsFoot = {
        name = "Rabbit's Foot", rarity = "common", image = "rabbitsFoot",
        about = "Each time a point hits, it gets another x1.75 for the rest of the level.",
        pointLevelMult = 1.75,
    },
    snakeEyes = {
        name = "Snake Eyes", rarity = "common", image = "snakeEyes",
        about = "Two or more 1s: +15 points.",
        check = function(d) return d.counts[1] >= 2 end, flat = 15,
    },
    pairUp = {
        name = "Pair Up", rarity = "common", image = "pairUp",
        about = "Any pair (two of the same number): +10 points.",
        check = function(d) return d.most >= 2 end, flat = 10,
    },
    lowball = {
        name = "Lowball", rarity = "common", image = "lowball",
        about = "All 5 dice under 4 (1, 2 or 3): +50 points.",
        check = function(d) return allOf(d, function(v) return v < 4 end) end, flat = 50,
    },
    highroller = {
        name = "Highroller", rarity = "common", image = "highroller",
        about = "All 5 dice over 3 (4, 5 or 6): +50 points.",
        check = function(d) return allOf(d, function(v) return v > 3 end) end, flat = 50,
    },
    pocketChange = {
        name = "Pocket Change", rarity = "common", image = "pocketChange",
        about = "+1 coin for every 6 you roll.",
        bonus = function(d) return 1, 0, d.counts[6] end,
    },
    middleRoad = {
        name = "Middle of the Road", rarity = "common", image = "middleRoad",
        about = "The dice add up to 15-20 (the usual sums): +20 points.",
        check = function(d) return d.sum >= 15 and d.sum <= 20 end, flat = 20,
    },

    -- UNCOMMON
    rabbitsLeg = {
        name = "Rabbit's Leg", rarity = "uncommon", image = "rabbitsLeg",
        about = "Each time a point hits, it gets another x1.25 for the rest of the run.",
        pointRunMult = 1.25,
    },
    hotDice = {
        name = "Hot Dice", rarity = "uncommon", image = "hotDice",
        about = "+8 points for every 5 or 6 you roll.",
        bonus = function(d) return 1, 8 * (d.counts[5] + d.counts[6]), 0 end,
    },
    underdog = {
        name = "Underdog", rarity = "uncommon", image = "underdog",
        about = "Land on a tile worth 60 points or less: x1.6 points.",
        check = function(d) return d.points <= 60 end, mult = 1.6,
    },
    tipJar = {
        name = "Tip Jar", rarity = "uncommon", image = "tipJar",
        about = "+3 coins every round.",
        check = function() return true end, coins = 3,
    },
    piggyBank = {
        name = "Piggy Bank", rarity = "uncommon", image = "piggyBank",
        about = "+2 coins for every 1 you roll.",
        bonus = function(d) return 1, 0, 2 * d.counts[1] end,
    },
    -- (the six Double Trouble cards are added further down)
    lowballDeluxe = {
        name = "Lowball Deluxe", rarity = "uncommon", image = "lowballDeluxe",
        about = "All 5 dice under 4 (1, 2 or 3): x1.5 points.",
        check = function(d) return allOf(d, function(v) return v < 4 end) end, mult = 1.5,
    },
    skyHigh = {
        name = "Sky High", rarity = "uncommon", image = "skyHigh",
        about = "All 5 dice over 3 (4, 5 or 6): x1.5 points.",
        check = function(d) return allOf(d, function(v) return v > 3 end) end, mult = 1.5,
    },
    noRepeats = {
        name = "No Repeats", rarity = "uncommon", image = "noRepeats",
        about = "All 5 dice different: +40 points.",
        check = function(d) return d.most == 1 end, flat = 40,
    },
    comebackKid = {
        name = "Comeback Kid", rarity = "uncommon", image = "comebackKid",
        about = "Reroll onto a better point than your first throw: +30 points.",
        check = function(d) return d.rerolled and d.firstPoints and d.points > d.firstPoints end,
        flat = 30,
    },
    steadyHand = {
        name = "Steady Hand", rarity = "uncommon", image = "steadyHand",
        about = "KEEP without rerolling: +5 coins.",
        check = function(d) return d.noReroll end, coins = 5,
    },

    -- RARE
    doubleDown = {
        name = "Double Down", rarity = "rare", image = "doubleDown",
        about = "If you rerolled this round: x1.5 points.",
        check = function(d) return d.rerolled end, mult = 1.5,
    },
    firstImpression = {
        name = "First Impression", rarity = "rare", image = "firstImpression",
        about = "KEEP your first throw (no reroll): x1.4 points.",
        check = function(d) return d.noReroll end, mult = 1.4,
    },
    collector = {
        name = "Collector", rarity = "rare", image = "collector",
        about = "Every Money Maker hand pays x1.5 coins.",
        allHandsMult = 1.5,
    },
    interest = {
        name = "Compound Interest", rarity = "rare", image = "interest",
        about = "Clear a level: +10% of your coins (up to 30).",
        interest = 0.10, interestCap = 30,
    },
    theySeeMeRollin = {
        name = "They See Me Rollin'", rarity = "rare", image = "theySeeMeRollin",
        about = "Get an extra reroll every round.",
        extraRerolls = 1,
    },
    cashIsKing = {
        name = "Cash is King", rarity = "rare", image = "cashIsKing",
        about = "Any time you earn coins, DOUBLE IT!",
        coinsMult = 2,
    },
    allSquare = {
        name = "All Square", rarity = "rare", image = "allSquare",
        about = "All 5 dice EVEN (2, 4, 6): x1.5 points.",
        check = function(d) return allOf(d, isEven) end, mult = 1.5,
    },
    oddSquad = {
        name = "Odd Squad", rarity = "rare", image = "oddSquad",
        about = "All 5 dice ODD (1, 3, 5): x1.5 points.",
        check = function(d) return allOf(d, isOdd) end, mult = 1.5,
    },
    -- (the six Triple Threat cards are added further down)
    luckySeven = {
        name = "Lucky Seven", rarity = "rare", image = "luckySeven",
        about = "The dice add up to 7, 17 or 27: x1.77 points.",
        check = function(d) return d.sum == 7 or d.sum == 17 or d.sum == 27 end, mult = 1.77,
    },
    houseRules = {
        name = "House Rules", rarity = "rare", image = "houseRules",
        about = "A Full House pays DOUBLE coins.",
        handCoinsMult = { fullHouse = 2 },
    },
    middleChild = {
        name = "Middle Child", rarity = "rare", image = "middleChild",
        about = "No 1s and no 6s at all: +75 points.",
        check = function(d) return d.counts[1] == 0 and d.counts[6] == 0 end, flat = 75,
    },

    -- EPIC
    copycat = {
        name = "Copycat", rarity = "epic", image = "copycat",
        about = "Copies the luck item in the slot to its LEFT. (Drag items to rearrange them.)",
        copyLeft = true,
    },
    hatTrick = {
        name = "Hat Trick", rarity = "epic", image = "hatTrick",
        about = "Three of a kind or better: x1.8 points.",
        check = function(d) return d.most >= 3 end, mult = 1.8,
    },
    evenSteven = {
        name = "Even Steven", rarity = "epic", image = "evenSteven",
        about = "Every EVEN sum you score is doubled.",
        check = function(d) return d.sum % 2 == 0 end, mult = 2,
    },
    thatsOdd = {
        name = "Hmm... That's Odd", rarity = "epic", image = "thatsOdd",
        about = "Every ODD sum you score is doubled.",
        check = function(d) return d.sum % 2 == 1 end, mult = 2,
    },
    pureBreed = {
        name = "Pure Breed", rarity = "epic", image = "pureBreed",
        about = "All 5 dice even OR all 5 odd: x2 points and +50 points.",
        check = function(d) return allOf(d, isEven) or allOf(d, isOdd) end, mult = 2, flat = 50,
    },
    stairway = {
        name = "Stairway", rarity = "epic", image = "stairway",
        about = "Any straight (4 or 5 in a row): x1.75 points.",
        check = function(d) return d.straight end, mult = 1.75,
    },
    crowdFavourite = {
        name = "Crowd Favourite", rarity = "epic", image = "crowdFavourite",
        about = "Every round you play holding this adds +0.03x to ALL points.",
        bonus = function(d) return 1 + 0.03 * luck.crowdRounds, 0, 0 end,
    },
    loadedDie = {
        name = "Loaded Die", rarity = "epic", image = "loadedDie",
        about = "Your first die never lands on a 1 or a 2.",
        loadedDie = true,
    },
    hotStreak = {
        name = "Hot Streak", rarity = "epic", image = "hotStreak",
        about = "Beat the round before: +0.25x per round in a row. A miss resets it.",
        -- Worked out in score.lua, because it needs the last round's points.
    },

    -- LEGENDARY
    showMeTheMoney = {
        name = "Show Me The Money", rarity = "legendary", image = "showMeTheMoneyLegendary",
        about = "Each time a point hits, it gets another +100 points for the rest of the run.",
        pointRunFlat = 100,
    },
    fyPayMe = {
        name = "F*** You Pay Me", rarity = "legendary", image = "fyPayMe",
        about = "Earn coins equal to the value of every point you score.",
        payMe = true,
    },
    unlockToken = {
        name = "Unlock Token", rarity = "legendary", image = "unlockToken",
        about = "Earn a special Unlock Token for every level you beat while holding this.",
        unlockTokens = true,
    },
    yahtzeeGods = {
        name = "Yahtzee Gods", rarity = "legendary", image = "yahtzeeGods",
        about = "5 of a Kind: x5 points and +100 coins.",
        check = function(d) return d.most == 5 end, mult = 5, coins = 100,
    },
    midasDice = {
        name = "Midas Dice", rarity = "legendary", image = "midasDice",
        about = "+0.2x points for every 6 you roll (five 6s = x2).",
        bonus = function(d) return 1 + 0.2 * d.counts[6], 0, 0 end,
    },
    mirrorMirror = {
        name = "Mirror Mirror", rarity = "legendary", image = "mirrorMirror",
        about = "Dice 1-5 read the same both ways (like 3-5-1-5-3): x3 points.",
        check = function(d)
            local v = d.values
            return v[1] == v[5] and v[2] == v[4]
        end, mult = 3,
    },
    secondChance = {
        name = "Second Chance", rarity = "legendary", image = "secondChance",
        about = "Get TWO extra rerolls every round.",
        extraRerolls = 2,
    },
    jackpotMagnet = {
        name = "Jackpot Magnet", rarity = "legendary", image = "jackpotMagnet",
        about = "BIG WIN needs only 30% of the goal, MEGA WIN only 60%.",
        bigWinShares = { 0.30, 0.60 },
    },
}

-- The ids in order (tables keyed by name have no order). The face cards
-- are slotted in below.
luck.ORDER = {
    "runItBack",
    "addict", "rabbitsFoot", "snakeEyes", "pairUp", "lowball", "highroller", "pocketChange", "middleRoad",
    "rabbitsLeg", "lowballDeluxe", "skyHigh", "noRepeats", "comebackKid", "steadyHand",
    "hotDice", "underdog", "tipJar", "piggyBank",
    "theySeeMeRollin", "cashIsKing", "allSquare", "oddSquad",
    "luckySeven", "houseRules", "middleChild", "doubleDown", "firstImpression", "collector", "interest",
    "evenSteven", "thatsOdd", "pureBreed", "stairway",
    "crowdFavourite", "loadedDie", "hotStreak", "copycat", "hatTrick",
    "showMeTheMoney", "fyPayMe", "unlockToken", "yahtzeeGods", "midasDice",
    "mirrorMirror", "secondChance", "jackpotMagnet",
}

-- DOUBLE TROUBLE (uncommon) and TRIPLE THREAT (rare): one card per face.
-- Built in a loop so the 12 cards don't have to be typed out. Each has a
-- weight of 1/6, so all six together are as likely as one normal item.
local WORDS = { "1s", "2s", "3s", "4s", "5s", "6s" }
for face = 1, 6 do
    luck.ITEMS["doubleTrouble" .. face] = {
        name = "Double Trouble: " .. WORDS[face], rarity = "uncommon", image = "doubleTrouble" .. face,
        about = "Two or more " .. WORDS[face] .. ": x1.5 points.",
        check = function(d) return d.counts[face] >= 2 end, mult = 1.5, weight = 1 / 6,
    }
    luck.ITEMS["tripleThreat" .. face] = {
        name = "Triple Threat: " .. WORDS[face], rarity = "rare", image = "tripleThreat" .. face,
        about = "Three or more " .. WORDS[face] .. ": x2 points.",
        check = function(d) return d.counts[face] >= 3 end, mult = 2, weight = 1 / 6,
    }
    table.insert(luck.ORDER, "doubleTrouble" .. face)
    table.insert(luck.ORDER, "tripleThreat" .. face)
end

-- Fill in each item's id from its key, so items don't have to repeat it.
for id, item in pairs(luck.ITEMS) do
    item.id = id
end

luck.STARTER = "runItBack"


---------------------------------------------------------------------------
-- DATA: what the player is holding right now
---------------------------------------------------------------------------

luck.held = {}          -- the ids held, in slot order, e.g. { "runItBack", "skyHigh" }
luck.crowdRounds = 0    -- rounds played while holding Crowd Favourite
luck.streak = 0         -- Hot Streak: rounds in a row that beat the one before


---------------------------------------------------------------------------
-- BASICS
---------------------------------------------------------------------------

function luck.get(id)
    return luck.ITEMS[id]
end

-- The colour for an item's rarity.
function luck.rarityColor(item)
    return luck.RARITIES[item.rarity].color
end

-- Is this item held?
function luck.has(id)
    for _, held in ipairs(luck.held) do
        if held == id then return true end
    end
    return false
end

-- Are all the slots full?
function luck.isFull()
    return #luck.held >= luck.MAX_HELD
end

-- Give the player an item. Returns false if their slots are full.
function luck.give(id)
    if luck.isFull() or luck.has(id) then
        return false
    end
    table.insert(luck.held, id)
    return true
end

-- Sell the item in slot k: it's gone, and the coins it's worth are
-- handed back (the caller gives them to the player).
function luck.sell(k)
    local id = luck.held[k]
    if id == nil then return 0 end
    table.remove(luck.held, k)
    if id == "crowdFavourite" then luck.crowdRounds = 0 end
    if id == "hotStreak" then luck.streak = 0 end
    return luck.sellPrice(luck.ITEMS[id])
end

-- A new game: nothing held, counters back to zero.
function luck.reset()
    luck.held = {}
    luck.crowdRounds = 0
    luck.streak = 0
end

-- What a Copycat with nothing to copy acts like: nothing at all.
local COPYING_NOTHING = { name = "Copycat" }

-- Loop over the held items: for item in each() do ... end
-- A Copycat comes out as a copy of the item to its left (a table that
-- looks up everything in that item, with its own name).
local function each()
    local k = 0
    return function()
        k = k + 1
        local id = luck.held[k]
        if id == nil then return nil end
        local item = luck.ITEMS[id]
        if item.copyLeft then
            local left = luck.held[k - 1] and luck.ITEMS[luck.held[k - 1]]
            if left == nil or left.copyLeft then return COPYING_NOTHING end
            return setmetatable({ name = "Copycat (" .. left.name .. ")" }, { __index = left })
        end
        return item
    end
end

-- Move the item in slot 'from' to slot 'to' (the others shuffle along).
-- Returns true if it moved.
function luck.move(from, to)
    if luck.held[from] == nil or to < 1 or to > #luck.held or from == to then return false end
    local id = table.remove(luck.held, from)
    table.insert(luck.held, to, id)
    return true
end

-- Does any held item have this field set?
local function anyHeld(field)
    for item in each() do
        if item[field] then return true end
    end
    return false
end


---------------------------------------------------------------------------
-- EFFECTS (other files ask these questions)
---------------------------------------------------------------------------

-- How many rerolls the player gets each round.
function luck.rerollsPerRound(normal)
    local total = normal
    for item in each() do
        if item.noRerolls then return 0 end
        total = total + (item.extraRerolls or 0)
    end
    return total
end

-- Can the player place their own marker?
function luck.blocksMarker()
    return anyHeld("noMarker")
end

-- The automatic marker's sum for this round (round = 1, 2, 3...), or nil.
function luck.autoMarkerSum(round)
    for item in each() do
        if item.autoMarker then
            local list = item.autoMarker
            return list[((round - 1) % #list) + 1]   -- round 1 -> 17, round 2 -> 18, ...
        end
    end
    return nil
end

-- Multiply together one field from every held item (1 if none have it).
local function product(field)
    local m = 1
    for item in each() do
        m = m * (item[field] or 1)
    end
    return m
end

-- What the level's score goal is multiplied by.
function luck.targetMultiplier()
    return product("targetMult")
end

-- What every coin earned is multiplied by.
function luck.coinsMultiplier()
    return product("coinsMult")
end

-- What one Money Maker hand's coins are multiplied by (House Rules).
function luck.handCoinsMultiplier(handId)
    local m = 1
    for item in each() do
        if item.handCoinsMult and item.handCoinsMult[handId] then
            m = m * item.handCoinsMult[handId]
        end
        m = m * (item.allHandsMult or 1)   -- Collector: every hand
    end
    return m
end

-- Extra coins for scoring a point worth 'points' (F*** You Pay Me).
function luck.payMeCoins(points)
    return anyHeld("payMe") and points or 0
end

-- Coins for clearing a level while holding Compound Interest, given the
-- coins you have.
function luck.levelEndCoins(coins)
    local total = 0
    for item in each() do
        if item.interest then
            total = total + math.min(item.interestCap, math.floor(coins * item.interest))
        end
    end
    return total
end

-- Does a held item hand out Unlock Tokens?
function luck.givesUnlockTokens()
    return anyHeld("unlockTokens")
end

-- BIG WIN / MEGA WIN thresholds: the lowest any held item gives, or nil.
function luck.bigWinShares()
    local best = nil
    for item in each() do
        if item.bigWinShares and (best == nil or item.bigWinShares[1] < best[1]) then
            best = item.bigWinShares
        end
    end
    return best
end

-- The odds a die rolls with. Loaded Die stops die 1 from rolling 1 or 2.
-- 'slot' is which of the 5 dice is being rolled.
function luck.applyTo(weights, slot)
    if slot ~= 1 then return weights end
    for item in each() do
        if item.loadedDie then
            local loaded = {}
            for f = 1, 6 do loaded[f] = weights[f] end
            loaded[1], loaded[2] = 0, 0
            return loaded
        end
    end
    return weights
end


---------------------------------------------------------------------------
-- ROUND BONUSES
---------------------------------------------------------------------------

-- Everything the 'check' functions might want to know about the 5 dice:
--   values      - the 5 faces in slot order, e.g. {3, 5, 1, 5, 3}
--   sum         - their total
--   counts      - how many of each face: counts[5] = 2
--   most        - the biggest pile of one face (5 = five of a kind)
--   straight    - 4 or more in a row?
--   noReroll    - KEEP was pressed without rerolling
--   rerolled    - the player rerolled at least once
--   points      - base points of the final sum
--   firstPoints - base points of the first throw's sum (nil if unknown)
function luck.diceFacts(values, extra)
    local d = {
        values = values, sum = util.sum(values), counts = util.countFaces(values), most = 0,
        noReroll = extra.noReroll, rerolled = extra.rerolled,
        points = extra.points, firstPoints = extra.firstPoints,
    }
    for f = 1, 6 do
        d.most = math.max(d.most, d.counts[f])
    end
    local c = d.counts
    d.straight = (c[1] > 0 and c[2] > 0 and c[3] > 0 and c[4] > 0)
        or (c[2] > 0 and c[3] > 0 and c[4] > 0 and c[5] > 0)
        or (c[3] > 0 and c[4] > 0 and c[5] > 0 and c[6] > 0)
    return d
end

-- Which held items pay out for these dice. Returns a list like
--   { { name = "Sky High", mult = 1.5, flat = 0, coins = 0 }, ... }
function luck.roundBonuses(d)
    local list = {}
    for item in each() do
        local mult, flat, coins
        if item.bonus then
            mult, flat, coins = item.bonus(d)
        elseif item.check and item.check(d) then
            mult, flat, coins = item.mult or 1, item.flat or 0, item.coins or 0
        end
        if mult and (mult ~= 1 or flat ~= 0 or coins ~= 0) then
            table.insert(list, { name = item.name, mult = mult, flat = flat, coins = coins })
        end
    end
    return list
end

-- A round was just scored on 'sum': stick the held items' lasting boosts
-- onto that point. They STACK: every time the same point hits, it gets
-- boosted again. (Roll 19 three times with Run it Back and 19 is worth
-- x1.1 x1.1 x1.1.)
function luck.onPointScored(sum)
    for item in each() do
        if item.pointRunMult or item.pointRunFlat then
            boosts.addRun(sum, item.pointRunMult, item.pointRunFlat)
        end
        if item.pointLevelMult then
            boosts.addLevel(sum, item.pointLevelMult)
        end
    end
    if luck.has("crowdFavourite") then
        luck.crowdRounds = luck.crowdRounds + 1
    end
end


---------------------------------------------------------------------------
-- THE MYSTERY MACHINE
---------------------------------------------------------------------------

-- Pick a random item id. It's done in two steps:
--   1. pick a RARITY using the "mystery" % chances (30/30/22/13/5)
--   2. pick one item of that rarity, using each item's weight.
-- 'exclude' is a list of ids that mustn't be picked (ones you already
-- hold, or that are already on another reel).
function luck.randomItem(exclude)
    local skip = {}
    for _, id in ipairs(exclude or {}) do skip[id] = true end

    -- Sort the items that can be picked into lists, one per rarity.
    local byRarity, rarities = {}, {}
    for _, id in ipairs(luck.ORDER) do
        local rarity = luck.ITEMS[id].rarity
        if not skip[id] and luck.RARITIES[rarity].mystery > 0 then
            if byRarity[rarity] == nil then
                byRarity[rarity] = {}
                table.insert(rarities, rarity)
            end
            table.insert(byRarity[rarity], id)
        end
    end

    if #rarities == 0 then return nil end
    local rarity = util.pickWeighted(rarities, function(r) return luck.RARITIES[r].mystery end)
    return util.pickWeighted(byRarity[rarity], function(id) return luck.ITEMS[id].weight or 1 end)
end

return luck
