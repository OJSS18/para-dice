-- vips.lua
-- PIPS MODE: VIP UPGRADES - big, expensive buys that change the whole run.
-- Pure LOGIC/data - no drawing.
--
-- Each level, the shop offers ONE random VIP upgrade (it stays on offer in
-- every shop of that level until you buy it). They cost a lot, but they
-- last for the rest of the run:
--   Extra Set        - +1 set every round
--   Extra Reroll     - +1 reroll every round
--   Bigger Shop      - +1 item in FOR SALE
--   Extra Life       - lose one round without losing the run (not a boss
--                      round); used up when it saves you, then can be bought again
--   Extra Set II / Extra Reroll II - another one, from level 7 (needs the first)
--   MYTHIC: Sixth Seat - a 6th Perky slot (rare to be offered, and pricier)
--
-- The run keeps what you've bought in run.vipOwned = { [id] = true } and
-- the effects in run.bonusSets, run.bonusRerolls, run.shopSlots,
-- run.perkySlots and run.extraLife (see pipsgame.new).

local config = require("config")
local util   = require("util")

local vips = {}

local PRICE = config.PIPS.VIP_PRICE
local MYTHIC_PRICE = config.PIPS.VIP_MYTHIC_PRICE

-- weight - how likely it is to be the level's offer (bigger = more likely)
vips.LIST = {
    { id = "set1", name = "Extra Set", about = "+1 SET every round, for the rest of the run.",
      price = PRICE, weight = 10, apply = function(run) run.bonusSets = run.bonusSets + 1 end },
    { id = "reroll1", name = "Extra Reroll", about = "+1 REROLL every round, for the rest of the run.",
      price = PRICE, weight = 10, apply = function(run) run.bonusRerolls = run.bonusRerolls + 1 end },
    { id = "shopSlot", name = "Bigger Shop", about = "+1 item in FOR SALE at every shop.",
      price = PRICE, weight = 10, apply = function(run) run.shopSlots = run.shopSlots + 1 end },
    { id = "life", name = "Extra Life", repeatable = true,
      about = "Run out of sets and you DON'T lose - once. (Not in a boss round.) Used up when it saves you.",
      price = PRICE, weight = 10, apply = function(run) run.extraLife = true end },
    { id = "set2", name = "Extra Set II", requires = "set1", minLevel = 7,
      about = "Another +1 SET every round (2 extra in all).",
      price = PRICE, weight = 10, apply = function(run) run.bonusSets = run.bonusSets + 1 end },
    { id = "reroll2", name = "Extra Reroll II", requires = "reroll1", minLevel = 7,
      about = "Another +1 REROLL every round (2 extra in all).",
      price = PRICE, weight = 10, apply = function(run) run.bonusRerolls = run.bonusRerolls + 1 end },
    { id = "perkySlot", name = "Sixth Seat", mythic = true,
      about = "MYTHIC: a 6th Perky slot.",
      price = MYTHIC_PRICE, weight = 2, apply = function(run) run.perkySlots = run.perkySlots + 1 end },
}

vips.BY_ID = {}
for _, v in ipairs(vips.LIST) do vips.BY_ID[v.id] = v end

function vips.get(id)
    return vips.BY_ID[id]
end

-- Can VIP upgrade v be offered to this run now?
function vips.isAvailable(v, run)
    if v.repeatable then
        if run.extraLife then return false end          -- already holding one
    elseif run.vipOwned[v.id] then
        return false                                     -- already bought
    end
    if v.requires and not run.vipOwned[v.requires] then return false end
    if v.minLevel and run.level < v.minLevel then return false end
    return true
end

-- A random VIP upgrade for this level (its id), or nil if none are left.
function vips.pick(run)
    local pool = {}
    for _, v in ipairs(vips.LIST) do
        if vips.isAvailable(v, run) then table.insert(pool, v) end
    end
    if #pool == 0 then return nil end
    return util.pickWeighted(pool, function(v) return v.weight end).id
end

return vips
