-- pipsshop.lua
-- PIPS MODE: the SHOP you visit after every round. Pure LOGIC - no
-- drawing (pipsdraw.lua) and no clicks (pipsinput.lua).
--
-- What's in it:
--   * THE MAIN ITEMS - 2 things for sale. Each one is a Perky (80%), a
--     DICE AUGMENT (10%: "each 4 scores +4 more points per level") or a
--     SET AUGMENT (10%: "Pair +1 mult"). See augments.lua. REROLL swaps
--     both for new ones.
--   * THE SLOT MACHINE - 3 reels. Each reel lands on a PACK; you open ONE:
--       Dice pack        - pick 1 of 4 dice
--       Perky pack       - pick 1 of 3 Perkys
--       Big Perky pack   - pick 1 of 5 Perkys
--       Rare Perky pack  - pick 1 of 3 RARE Perkys (1% a reel)
--       Dice Augment pack- pick 1 of 3 dice augments
--       Set Augment pack - pick 1 of 3 set augments
--       Craps pack       - pick 1 of 4 numbers; it goes on the board as a
--                          craps bet (roll that total for x2 MULT)
--       Dungeon dice pack- pick 1 of 4 dungeon dice (D7 up to D20)
--   * SELL - sell a Perky for half its price.
--
-- Every function takes 'run' (the run's data, see pipsgame.lua).

local config    = require("config")
local rng       = require("rng")
local util      = require("util")
local perkys    = require("perkys")
local pipshands = require("pipshands")
local pipsdice  = require("pipsdice")
local augments  = require("augments")

local pipsshop = {}

local P = config.PIPS

-- The packs, in a fixed order (the reels pick from these).
pipsshop.PACKS = {
    { id = "dice",      name = "DICE PACK",       about = "Pick 1 of 4 dice" },
    { id = "perky",     name = "PERKY PACK",      about = "Pick 1 of 3 Perkys" },
    { id = "bigPerky",  name = "BIG PERKY PACK",  about = "Pick 1 of 5 Perkys" },
    { id = "rarePerky", name = "RARE PERKY PACK", about = "Pick 1 of 3 RARE Perkys" },
    { id = "diceAug",   name = "DICE AUGMENT PACK", about = "Pick 1 of 3 dice augments" },
    { id = "setAug",    name = "SET AUGMENT PACK",  about = "Pick 1 of 3 set augments" },
    { id = "craps",     name = "CRAPS PACK",      about = "Pick a number for the board" },
    { id = "dungeon",   name = "DUNGEON DICE",    about = "Pick 1 of 4 dungeon dice" },
}
pipsshop.PACK_BY_ID = {}
for _, p in ipairs(pipsshop.PACKS) do pipsshop.PACK_BY_ID[p.id] = p end


---------------------------------------------------------------------------
-- PICKING RANDOM THINGS
---------------------------------------------------------------------------

-- Is Perky 'id' already held, or already on offer somewhere in the shop?
local function isTaken(run, id, extra)
    for _, h in ipairs(run.perkys) do if h.id == id then return true end end
    for _, item in ipairs(run.shop.items) do
        if item.type == "perky" and item.id == id and not item.sold then return true end
    end
    for _, id2 in ipairs(extra or {}) do if id2 == id then return true end end
    return false
end

-- A random Perky the player could get now. 'rarity' forces a rarity (nil =
-- pick one by RARITY_ODDS). 'extra' = ids to leave out (others in a pack).
-- Gives back nil if there's nothing left.
function pipsshop.randomPerky(run, rarity, extra)
    if not rarity then
        rarity = util.pickWeighted(perkys.RARITY_ORDER, function(r) return P.RARITY_ODDS[r] end)
    end
    local function poolOf(wanted)
        local pool = {}
        for _, p in ipairs(perkys.LIST) do
            if (wanted == nil or p.rarity == wanted) and perkys.isAvailable(p, run.slots)
                and not isTaken(run, p.id, extra) then
                table.insert(pool, p.id)
            end
        end
        return pool
    end
    local pool = poolOf(rarity)
    if #pool == 0 then pool = poolOf(nil) end   -- that rarity has run out: any will do
    if #pool == 0 then return nil end
    return pool[rng.random(#pool)]
end

-- The faces a DICE AUGMENT can be for: 1-6, plus 7-10 if you own a die
-- that can show them.
local function augmentFaces(run)
    local top = 6
    for _, d in ipairs(run.dice) do top = math.max(top, pipsdice.maxFace(d)) end
    return top
end

-- The augments of one kind ("diceAug" or "setAug") the player could get now:
-- dice augments for faces your dice can show, set augments for unlocked sets.
local function augmentPool(run, kind)
    local pool = {}
    if kind == "diceAug" then
        local top = augmentFaces(run)
        for _, a in ipairs(augments.DICE) do
            if a.face <= top then table.insert(pool, a) end
        end
    else
        for _, a in ipairs(augments.SETS) do
            if pipshands.isUnlocked(pipshands.get(a.hand), run.slots) then table.insert(pool, a) end
        end
    end
    return pool
end

-- A random augment of a kind ("diceAug" or "setAug"). 'leaveOut' = ids
-- already picked for the same pack, so a pack has no repeats.
function pipsshop.randomAugment(run, kind, leaveOut)
    local pool = {}
    for _, a in ipairs(augmentPool(run, kind)) do
        local used = false
        for _, id in ipairs(leaveOut or {}) do
            if id == a.id then used = true end
        end
        if not used then table.insert(pool, a) end
    end
    if #pool == 0 then pool = augmentPool(run, kind) end
    return augments.offer(pool[rng.random(#pool)])
end

-- One main item: a Perky, dice augment or set augment (by MAIN_ODDS).
local function randomItem(run)
    local kind = util.pickWeighted({ "perky", "diceAug", "setAug" }, function(k) return P.MAIN_ODDS[k] end)
    if kind == "perky" then
        local id = pipsshop.randomPerky(run)
        if id then return { type = "perky", id = id, price = perkys.get(id).price } end
        kind = "setAug"   -- no Perkys left to offer
    end
    return pipsshop.randomAugment(run, kind)
end

local function fillItems(run)
    run.shop.items = {}
    for k = 1, P.MAIN_ITEMS do
        run.shop.items[k] = randomItem(run)
    end
end


---------------------------------------------------------------------------
-- OPENING AND THE MAIN ITEMS
---------------------------------------------------------------------------

-- A fresh shop: new items, the machine and reroll prices start low again.
function pipsshop.open(run)
    run.shop = { items = {}, rerollCost = P.SHOP_REROLL, spins = 0, reels = nil, pack = nil,
                 message = "Welcome! Buy Perkys, augments - or spin for a pack." }
    fillItems(run)
end

-- What an item does, in words (shared by the shop cards and packs).
function pipsshop.itemName(item)
    if item.type == "perky" then return perkys.get(item.id).name end
    return item.name
end
function pipsshop.itemAbout(item, run)
    if item.type == "perky" then return perkys.get(item.id).about end
    return augments.about(item, run)
end

-- Is there room for another Perky?
function pipsshop.perkyRoom(run)
    return #run.perkys < P.MAX_PERKYS
end

-- Give the player an item they bought or picked. Gives back false (and
-- sets a message) if it can't be taken.
local function giveItem(run, item)
    if item.type == "perky" then
        if not pipsshop.perkyRoom(run) then
            run.shop.message = "Your Perky slots are full - SELL one first."
            return false
        end
        table.insert(run.perkys, { id = item.id, gained = 0 })
    elseif item.type == "diceAug" then
        run.diceAug[item.face] = (run.diceAug[item.face] or 0) + 1
    else
        run.setAug[item.hand] = (run.setAug[item.hand] or 0) + 1
    end
    return true
end

-- Buy main item k.
function pipsshop.buy(run, k)
    local item = run.shop.items[k]
    if not item or item.sold or run.shop.pack then return false end
    if run.coins < item.price then
        run.shop.message = "Not enough coins."
        return false
    end
    if not giveItem(run, item) then return false end
    run.coins = run.coins - item.price
    item.sold = true
    run.shop.message = "Bought " .. pipsshop.itemName(item) .. "!"
    return true
end

-- REROLL: swap the main items for new ones.
function pipsshop.reroll(run)
    if run.shop.pack or run.coins < run.shop.rerollCost then return false end
    run.coins = run.coins - run.shop.rerollCost
    run.shop.rerollCost = run.shop.rerollCost + 1
    fillItems(run)
    run.shop.message = "Fresh stock!"
    return true
end

-- SELL Perky k for half its price.
function pipsshop.sell(run, k)
    local held = run.perkys[k]
    if not held then return false end
    local p = perkys.get(held.id)
    run.coins = run.coins + perkys.sellPrice(p)
    table.remove(run.perkys, k)
    run.shop.message = "Sold " .. p.name .. " for " .. perkys.sellPrice(p) .. "."
    return true
end


---------------------------------------------------------------------------
-- THE SLOT MACHINE AND PACKS
---------------------------------------------------------------------------

function pipsshop.spinPrice(run)
    return P.SPIN_PRICE + run.shop.spins * P.SPIN_STEP
end

-- Have the reels landed on packs that nobody has opened yet?
function pipsshop.hasUntakenReels(run)
    return run.shop.reels ~= nil and run.shop.reels.taken == nil
end

-- Pull the lever: each of the 3 reels lands on a random pack.
function pipsshop.spin(run)
    local price = pipsshop.spinPrice(run)
    if run.shop.pack or pipsshop.hasUntakenReels(run) then return false end
    if run.coins < price then
        run.shop.message = "Not enough coins to spin."
        return false
    end
    run.coins = run.coins - price
    run.shop.spins = run.shop.spins + 1
    local reels = { taken = nil }
    for k = 1, 3 do
        reels[k] = util.pickWeighted(pipsshop.PACKS, function(p) return P.REEL_ODDS[p.id] end).id
    end
    run.shop.reels = reels
    run.shop.message = "Pick ONE pack to open!"
    return true
end

-- The options inside a pack of type 'packId'.
local function packOptions(run, packId)
    local options = {}
    if packId == "dice" or packId == "dungeon" then
        local list = packId == "dice" and pipsdice.PACK_KINDS or pipsdice.DUNGEON_KINDS
        for _, kind in ipairs(pipsdice.randomKinds(list, 4)) do
            table.insert(options, { type = "die", die = pipsdice.make(kind) })
        end
    elseif packId == "perky" or packId == "bigPerky" or packId == "rarePerky" then
        local count = packId == "bigPerky" and 5 or 3
        local rarity = packId == "rarePerky" and "rare" or nil
        local ids = {}
        for _ = 1, count do
            local id = pipsshop.randomPerky(run, rarity, ids)
            if id then
                table.insert(ids, id)
                table.insert(options, { type = "perky", id = id })
            end
        end
    elseif packId == "diceAug" or packId == "setAug" then
        local ids = {}
        for _ = 1, 3 do
            local a = pipsshop.randomAugment(run, packId, ids)
            table.insert(ids, a.id)
            table.insert(options, a)
        end
    elseif packId == "craps" then
        -- 4 different totals your dice could roll (from all 1s up to all
        -- max faces), not already on the board.
        local low, high = #run.dice, 0
        for _, d in ipairs(run.dice) do high = high + pipsdice.maxFace(d) end
        local choices = {}
        for n = low, high do
            local used = false
            for _, b in ipairs(run.bets) do if b == n then used = true end end
            if not used then table.insert(choices, n) end
        end
        for _ = 1, 4 do
            if #choices == 0 then break end
            table.insert(options, { type = "bet", number = table.remove(choices, rng.random(#choices)) })
        end
        table.sort(options, function(a, b) return a.number < b.number end)
    end
    return options
end

-- Open the pack on reel k.
function pipsshop.pickReel(run, k)
    if not pipsshop.hasUntakenReels(run) or not run.shop.reels[k] then return false end
    local packId = run.shop.reels[k]
    run.shop.reels.taken = k
    run.shop.pack = { id = packId, options = packOptions(run, packId), replacing = nil }
    run.shop.message = "Opened a " .. pipsshop.PACK_BY_ID[packId].name .. ". Pick one (or SKIP)."
    return true
end

-- Take option k from the open pack.
function pipsshop.pickOption(run, k)
    local pack = run.shop.pack
    if not pack or not pack.options[k] then return false end
    local option = pack.options[k]
    if option.type == "die" then
        if #run.dice < run.slots then
            table.insert(run.dice, option.die)
            run.shop.message = "New die added!"
        else
            -- No empty slot: the player picks which die it replaces.
            pack.replacing = k
            run.shop.message = "No empty slot. Click one of YOUR DICE to swap it out."
            return true
        end
    elseif option.type == "bet" then
        table.insert(run.bets, option.number)
        table.sort(run.bets)
        run.shop.message = "Craps bet on " .. option.number .. " is on the board!"
    else
        if not giveItem(run, option) then return false end
        run.shop.message = "Got " .. pipsshop.itemName(option) .. "!"
    end
    run.shop.pack = nil
    return true
end

-- Swap your die k for the die picked from a dice pack.
function pipsshop.replaceDie(run, k)
    local pack = run.shop.pack
    if not pack or not pack.replacing or not run.dice[k] then return false end
    run.dice[k] = pack.options[pack.replacing].die
    run.shop.pack = nil
    run.shop.message = "Die swapped!"
    return true
end

-- Close the pack without taking anything.
function pipsshop.skipPack(run)
    if not run.shop.pack then return false end
    run.shop.pack = nil
    run.shop.message = "Skipped."
    return true
end

return pipsshop
