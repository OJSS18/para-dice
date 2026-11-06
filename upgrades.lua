-- upgrades.lua
-- UPGRADES: permanent boosts bought in the shop, for a whole GROUP of sums.
-- Each upgrade has levels. Every level adds +0.25x to its group:
--   EVEN LVL1 -> even sums score x1.25
--   EVEN LVL2 -> even sums score x1.50   ...and so on.
-- If a sum is in several upgraded groups, the multipliers multiply
-- together (e.g. 18 is EVEN and in the MOST COMMON 4).
-- Upgrades last the whole run and are wiped when a new game starts.
--
-- Pure LOGIC/data - nothing in here draws.

local upgrades = {}

upgrades.STEP = 0.25        -- each level adds this much to the multiplier
-- Each upgrade has its own PRICE for LVL1; LVL2 costs twice that, LVL3
-- three times... (Prices from the strategy simulator: the upgrades that help
-- most cost most.)

-- Each upgrade: a name, what it does, and a test that says whether a sum
-- belongs to its group. ('function(sum) return ... end' is a small function
-- stored in the table - we call it like def.covers(18).)
upgrades.DEFS = {
    even = {
        name = "EVEN", about = "Every EVEN sum scores +0.25x", price = 55,
        covers = function(sum) return sum % 2 == 0 end,
    },
    odd = {
        name = "ODD", about = "Every ODD sum scores +0.25x", price = 40,
        covers = function(sum) return sum % 2 == 1 end,
    },
    lower = {
        name = "LOWER 13", about = "Sums 5 to 17 score +0.25x", price = 60,
        covers = function(sum) return sum <= 17 end,
    },
    upper = {
        name = "UPPER 13", about = "Sums 18 to 30 score +0.25x", price = 60,
        covers = function(sum) return sum >= 18 end,
    },
    common = {
        -- 17 and 18 are the most likely sums with 5 dice, then 16 and 19.
        name = "HOT FOUR", about = "The 4 most likely sums (16, 17, 18, 19) score +0.25x", price = 20,
        covers = function(sum) return sum >= 16 and sum <= 19 end,
    },
}

-- The ids in a fixed order (for picking shop stock). These ROTATE: the shop
-- offers 2 of them at random each visit.
upgrades.ORDER = { "even", "odd", "lower", "upper", "common" }

-- KEEP BONUS: this one does NOT rotate - it's in the shop every visit.
-- Each level raises the KEEP (no reroll) multiplier by 0.1:
--   x1.1 normally, x1.2 at LVL1, x1.3 at LVL2 ...
upgrades.DEFS.keep = {
    name = "KEEP BONUS", about = "KEEP with no reroll pays +0.1x more", price = 20,
    covers = function(sum) return false end,   -- not a sum group
}
upgrades.KEEP_STEP = 0.1

-- How many levels of each upgrade the player owns. upgrades.levels.even = 2
upgrades.levels = {}


-- Back to nothing (new game).
function upgrades.reset()
    upgrades.levels = {}
    for _, id in ipairs(upgrades.ORDER) do
        upgrades.levels[id] = 0
    end
    upgrades.levels.keep = 0
end

-- The KEEP bonus multiplier with this upgrade, given the normal one (1.1).
function upgrades.keepMultiplier(normal)
    return normal + upgrades.KEEP_STEP * upgrades.level("keep")
end

-- Current level of an upgrade (0 = not bought).
function upgrades.level(id)
    return upgrades.levels[id] or 0
end

-- The label for the NEXT level you could buy, e.g. "EVEN LVL1".
function upgrades.nextLabel(id)
    return upgrades.DEFS[id].name .. " LVL" .. (upgrades.level(id) + 1)
end

-- What the next level costs.
function upgrades.nextPrice(id)
    return upgrades.DEFS[id].price * (upgrades.level(id) + 1)
end

-- Buy one more level.
function upgrades.levelUp(id)
    upgrades.levels[id] = upgrades.level(id) + 1
end

-- Total multiplier for a sum from every upgrade that covers it (1 if none).
function upgrades.multiplierFor(sum)
    local mult = 1
    for _, id in ipairs(upgrades.ORDER) do
        local lvl = upgrades.level(id)
        if lvl > 0 and upgrades.DEFS[id].covers(sum) then
            mult = mult * (1 + upgrades.STEP * lvl)
        end
    end
    return mult
end

upgrades.reset()

return upgrades
