-- markers.lua
-- MARKERS: white chips the player places on the table at the start of
-- each level. Each marker sits on ONE tile (one marker per tile):
--   * a POINTS tile (a sum, like 17)       -> rolling that sum pays x1.5 points
--   * a MONEY MAKER tile (a hand, like Full House) -> that hand pays x1.5 coins
-- Markers stay put for the whole level, then come off the table so they
-- can be placed again at the start of the next level.
--
-- The player starts with ONE marker and can buy more in the shop.
--
-- Pure LOGIC/data - nothing in here draws.

local markers = {}

-- How much a marked tile multiplies its payout by.
markers.MULTIPLIER = 1.5

-- How many markers the player owns, and the most they can own.
markers.owned = 1
markers.MAX_OWNED = 5

-- What the next extra marker costs in the shop: 20, then 30, 40, 50.
-- (Each extra chip helps about +0.2 levels in the simulator.)
function markers.nextPrice()
    return 10 + 10 * markers.owned
end

-- The markers on the table: a list, oldest first. Each one looks like
--   { kind = "points", sum = 17 }        or
--   { kind = "coins",  hand = "fullHouse" }
markers.placed = {}

-- An AUTOMATIC marker that a luck item puts down (Addict flips one
-- between 17 and 18 each round). Just a sum, or nil. It works exactly
-- like the player's markers.
markers.autoSum = nil


-- Back to one marker and an empty table (new game).
function markers.reset()
    markers.owned = 1
    markers.placed = {}
    markers.autoSum = nil
end

-- Take every player marker off the table.
function markers.clear()
    markers.placed = {}
end

-- How many markers are on the table right now.
function markers.count()
    return #markers.placed
end

-- Are ALL the player's markers on the table? The level can't start until
-- they are (unless a luck item like Addict skips placing altogether).
function markers.allPlaced()
    return #markers.placed >= markers.owned
end

-- Where in the 'placed' list a tile's marker is (or nil if it has none).
local function findTile(kind, key)
    for i, m in ipairs(markers.placed) do
        if m.kind == kind and (m.sum == key or m.hand == key) then
            return i
        end
    end
    return nil
end

-- Click a tile while placing:
--   * if it already has a marker, pick that marker back up;
--   * otherwise put a marker on it. If all your markers are already out,
--     the OLDEST one moves here (so clicking around never gets stuck).
-- 'key' is the sum (for "points") or the hand id (for "coins").
function markers.toggle(kind, key)
    local i = findTile(kind, key)
    if i then
        table.remove(markers.placed, i)
        return
    end
    if #markers.placed >= markers.owned then
        table.remove(markers.placed, 1)
    end
    if kind == "points" then
        table.insert(markers.placed, { kind = "points", sum = key })
    else
        table.insert(markers.placed, { kind = "coins", hand = key })
    end
end

-- Is a player marker on this POINTS tile?
function markers.isPlayerOnSum(sum)
    return findTile("points", sum) ~= nil
end

-- Is ANY marker (the player's or the automatic one) on this POINTS tile?
function markers.isOnSum(sum)
    return markers.isPlayerOnSum(sum) or markers.autoSum == sum
end

-- Is a marker on this MONEY MAKER tile?
function markers.isOnHand(handId)
    return findTile("coins", handId) ~= nil
end

-- What to multiply a sum's points by: 1.5 if it's marked, otherwise 1.
function markers.pointsMultiplier(sum)
    if markers.isOnSum(sum) then
        return markers.MULTIPLIER
    end
    return 1
end

-- What to multiply a hand's coins by: 1.5 if it's marked, otherwise 1.
function markers.coinsMultiplier(handId)
    if markers.isOnHand(handId) then
        return markers.MULTIPLIER
    end
    return 1
end

return markers
