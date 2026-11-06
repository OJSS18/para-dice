-- markers.lua
-- MARKERS: white chips the player places on the table at the start of
-- each level. A marker sits on ONE tile:
--   * a POINTS tile (a sum, like 17)       -> rolling that sum pays x1.5 points
--   * a MONEY MAKER tile (a hand, like Full House) -> that hand pays x1.5 coins
-- The marker stays put for the whole level, then comes off the table so
-- a new one can be placed at the start of the next level.
--
-- Right now the player gets one marker. Later, upgrades could give more
-- (that's why it's kept in its own file).
--
-- Pure LOGIC/data - nothing in here draws.

local markers = {}

-- How much a marked tile multiplies its payout by.
markers.MULTIPLIER = 1.5

-- The marker on the table, or nil if there isn't one. Looks like:
--   { kind = "points", sum = 17 }        or
--   { kind = "coins",  hand = "fullHouse" }
markers.placed = nil

-- An AUTOMATIC marker that a luck item puts down (Addict flips one
-- between 17 and 18 each round). Just a sum, or nil. It works exactly
-- like the player's marker.
markers.autoSum = nil


-- Put the marker on a POINTS tile (moves it if it was somewhere else).
function markers.placeOnSum(sum)
    markers.placed = { kind = "points", sum = sum }
end

-- Put the marker on a MONEY MAKER tile.
function markers.placeOnHand(handId)
    markers.placed = { kind = "coins", hand = handId }
end

-- Take the player's marker off the table.
function markers.clear()
    markers.placed = nil
end

-- Is the player's marker on this POINTS tile?
function markers.isPlayerOnSum(sum)
    return markers.placed ~= nil and markers.placed.kind == "points" and markers.placed.sum == sum
end

-- Is ANY marker (the player's or the automatic one) on this POINTS tile?
function markers.isOnSum(sum)
    return markers.isPlayerOnSum(sum) or markers.autoSum == sum
end

-- Is the marker on this MONEY MAKER tile?
function markers.isOnHand(handId)
    return markers.placed ~= nil and markers.placed.kind == "coins" and markers.placed.hand == handId
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
