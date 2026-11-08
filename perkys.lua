-- perkys.lua
-- PIPS MODE: PERKYS, the cards you buy in the shop that change how your
-- rolls score (like jokers in a card game). You can hold up to 5.
-- Pure LOGIC - no drawing (pipsdraw.lua draws the cards).
--
-- HOW A PERKY WORKS
-- Every Perky has an 'effect' function. When you score a set, the game
-- calls effect(ctx, held) for each Perky you hold:
--   ctx  - facts about the roll (see pipsgame.scoreRoll): the dice values,
--          how many of each face, which sets it contains, and so on.
--   held - this Perky's own little table, e.g. { id = "onesCollector",
--          gained = 3 }. Perkys that GROW keep their growth in 'gained'.
-- It gives back what it adds, e.g. { mult = 3 } or { points = 20 } or
-- { xmult = 2 } or { coins = 1 } (or nil for nothing).
--
-- Some Perkys are PASSIVE instead: they have 'extraRerolls' or 'extraSets'
-- (more each round), or 'roundEnd' (run when you win a round).
--
-- THE FAMILIES (each made by a loop, so there's one of each for every face
-- or every set):
--   For each face 1-6:   "Ones Up" (+1 mult per 1), "Ones Collector" (grows
--                        +1 mult whenever a 1 scores), "Ones Banker" (+1 coin per 1)
--   For each set:        "Pair Power" (+mult), "Pair Points" (+points),
--                        "Pair Grower" (grows +mult), "Pair Crown" (x mult).
--                        These only show up once that set is unlocked.
--   Plus some one-offs ("solo" Perkys) at the bottom.

local config    = require("config")
local pipshands = require("pipshands")

local perkys = {}

perkys.RARITIES = {
    common   = { label = "COMMON",   color = { 0.55, 0.75, 1.00 } },
    uncommon = { label = "UNCOMMON", color = { 0.35, 0.95, 0.45 } },
    rare     = { label = "RARE",     color = { 1.00, 0.35, 0.35 } },
}
perkys.RARITY_ORDER = { "common", "uncommon", "rare" }

perkys.LIST = {}   -- every Perky, in a fixed order
perkys.BY_ID = {}

local function add(p)
    p.price = config.PIPS.PERKY_PRICES[p.rarity]
    table.insert(perkys.LIST, p)
    perkys.BY_ID[p.id] = p
end

function perkys.get(id)
    return perkys.BY_ID[id]
end


---------------------------------------------------------------------------
-- FACE PERKYS (one of each for the faces 1 to 6)
---------------------------------------------------------------------------

local FACE_WORDS = { "Ones", "Twos", "Threes", "Fours", "Fives", "Sixes" }

for f = 1, 6 do
    local word = FACE_WORDS[f]
    add({
        id = "up" .. f, name = word .. " Up", rarity = "common", family = "face", face = f,
        about = "+1 MULT for every " .. f .. " in the scored roll.",
        effect = function(ctx)
            if ctx.counts[f] > 0 then return { mult = ctx.counts[f] } end
        end,
    })
    add({
        id = "collector" .. f, name = word .. " Collector", rarity = "uncommon", family = "face", face = f,
        about = "Whenever a scored roll has a " .. f .. ", this Perky gains +1 MULT (for good).",
        grows = true,
        effect = function(ctx, held)
            if ctx.counts[f] > 0 then held.gained = held.gained + 1 end
            if held.gained > 0 then return { mult = held.gained } end
        end,
    })
    add({
        id = "banker" .. f, name = word .. " Banker", rarity = "common", family = "face", face = f,
        about = "+1 coin for every " .. f .. " in the scored roll.",
        effect = function(ctx)
            if ctx.counts[f] > 0 then return { coins = ctx.counts[f] } end
        end,
    })
end


---------------------------------------------------------------------------
-- SET PERKYS (four for every set except High Roll)
---------------------------------------------------------------------------

-- Round to the nearest quarter: 1.6 -> 1.5, 1.9 -> 2.0.
local function quarter(x)
    return math.floor(x * 4 + 0.5) / 4
end

for _, h in ipairs(pipshands.LIST) do
    if h.id ~= "none" then
        -- Bigger sets are rarer to roll, so their Perkys give more.
        local plusMult   = math.ceil(h.mult * 1.5)          -- Pair: +3 mult
        local plusPoints = h.mult * 10                      -- Pair: +20 points
        local grow       = math.max(1, math.floor(h.mult / 2))   -- Pair: +1 a time
        local times      = math.min(4, quarter(1 + h.mult / 4))  -- Pair: x1.5
        local name = h.name
        add({
            id = h.id .. "Power", name = name .. " Power", rarity = "common", family = "set", hand = h.id,
            about = "If the scored roll contains a " .. name .. ": +" .. plusMult .. " MULT.",
            effect = function(ctx)
                if ctx.contained[h.id] then return { mult = plusMult } end
            end,
        })
        add({
            id = h.id .. "Points", name = name .. " Points", rarity = "common", family = "set", hand = h.id,
            about = "If the scored roll contains a " .. name .. ": +" .. plusPoints .. " POINTS.",
            effect = function(ctx)
                if ctx.contained[h.id] then return { points = plusPoints } end
            end,
        })
        add({
            id = h.id .. "Grower", name = name .. " Grower", rarity = "uncommon", family = "set", hand = h.id,
            about = "If the scored roll contains a " .. name .. ", this Perky gains +" .. grow .. " MULT (for good).",
            grows = true,
            effect = function(ctx, held)
                if ctx.contained[h.id] then held.gained = held.gained + grow end
                if held.gained > 0 then return { mult = held.gained } end
            end,
        })
        add({
            id = h.id .. "Crown", name = name .. " Crown", rarity = "rare", family = "set", hand = h.id,
            about = "If the scored roll contains a " .. name .. ": x" .. times .. " MULT.",
            effect = function(ctx)
                if ctx.contained[h.id] then return { xmult = times } end
            end,
        })
    end
end


---------------------------------------------------------------------------
-- SOLO PERKYS (one-offs)
---------------------------------------------------------------------------

-- Do all the dice show different faces?
local function allDifferent(ctx)
    for f = 1, pipshands.MAX_FACE do
        if ctx.counts[f] > 1 then return false end
    end
    return true
end
-- Is every die odd (or every die even)?
local function allMatch(ctx, wantOdd)
    for _, v in ipairs(ctx.values) do
        if (v % 2 == 1) ~= wantOdd then return false end
    end
    return true
end

add({ id = "rainbow", name = "Rainbow", rarity = "common", family = "solo",
      about = "If every die in the scored roll is different: +20 POINTS.",
      effect = function(ctx) if allDifferent(ctx) then return { points = 20 } end end })
add({ id = "oddJob", name = "Odd Job", rarity = "uncommon", family = "solo",
      about = "If every die in the scored roll is odd: +8 MULT.",
      effect = function(ctx) if allMatch(ctx, true) then return { mult = 8 } end end })
add({ id = "evenMoney", name = "Even Money", rarity = "uncommon", family = "solo",
      about = "If every die in the scored roll is even: +8 MULT.",
      effect = function(ctx) if allMatch(ctx, false) then return { mult = 8 } end end })
add({ id = "piggyBank", name = "Piggy Bank", rarity = "common", family = "solo",
      about = "+2 POINTS for every coin you have.",
      effect = function(ctx) if ctx.coins > 0 then return { points = 2 * ctx.coins } end end })
add({ id = "lastCall", name = "Last Call", rarity = "uncommon", family = "solo",
      about = "On the LAST set of a round: x2 MULT.",
      effect = function(ctx) if ctx.setsLeft == 0 then return { xmult = 2 } end end })
add({ id = "steadyHand", name = "Steady Hand", rarity = "uncommon", family = "solo",
      about = "If you didn't reroll this set: x1.5 MULT.",
      effect = function(ctx) if ctx.rerollsThisSet == 0 then return { xmult = 1.5 } end end })
add({ id = "crowd", name = "Crowd Pleaser", rarity = "common", family = "solo",
      about = "+2 MULT for every Perky you hold (this one too).",
      effect = function(ctx) return { mult = 2 * ctx.perkyCount } end })
add({ id = "hoarder", name = "Dice Hoarder", rarity = "common", family = "solo",
      about = "+1 MULT for every die you own.",
      effect = function(ctx) return { mult = ctx.numDice } end })
add({ id = "hotStreak", name = "Hot Streak", rarity = "uncommon", family = "solo",
      about = "If the dice average 4.5 or more: +8 MULT.",
      effect = function(ctx) if ctx.pipTotal >= 4.5 * ctx.numDice then return { mult = 8 } end end })
add({ id = "lowBall", name = "Low Ball", rarity = "uncommon", family = "solo",
      about = "If the dice average 2.5 or less: x2 MULT.",
      effect = function(ctx) if ctx.pipTotal <= 2.5 * ctx.numDice then return { xmult = 2 } end end })
add({ id = "extraRoll", name = "Second Wind", rarity = "uncommon", family = "solo",
      about = "+1 reroll every round.", extraRerolls = 1 })
add({ id = "extraSet", name = "Encore", rarity = "rare", family = "solo",
      about = "+1 set every round.", extraSets = 1 })
-- COPY PERKYS: they do what another Perky does when you score (pipsscore.lua
-- works out which one). They can't copy each other, or passive Perkys.
add({ id = "copycat", name = "Copycat", rarity = "rare", family = "solo", copy = "left",
      about = "Copies the Perky to its LEFT (whatever it does when you score)." })
add({ id = "mimic", name = "Mimic", rarity = "uncommon", family = "solo", copy = "random",
      about = "Copies a RANDOM other Perky - a new pick for every scored roll." })
add({ id = "interest", name = "Interest", rarity = "uncommon", family = "solo",
      about = "When you win a round: +1 coin for every 5 coins you have (up to +5).",
      roundEnd = function(ctx) return math.min(5, math.floor(ctx.coins / 5)) end })


---------------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------------

-- Can Perky p turn up in the shop yet? (A set's Perkys need the set unlocked.)
function perkys.isAvailable(p, slots)
    if p.family ~= "set" then return true end
    return pipshands.isUnlocked(pipshands.get(p.hand), slots)
end

-- Can held Perky 'held' be copied by a copy Perky? (Not if it's a copy
-- Perky itself, switched off, or has nothing to do when you score.)
function perkys.isCopyable(held)
    local p = perkys.get(held.id)
    return p.effect ~= nil and not p.copy and not held.disabled
end

-- What a Perky sells for: half its price, rounded down (at least 1).
function perkys.sellPrice(p)
    return math.max(1, math.floor(p.price / 2))
end

return perkys
