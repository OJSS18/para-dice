-- pipshands.lua
-- PIPS MODE: the SETS (hands) a roll can make, like poker hands.
-- The set you roll decides your starting MULT. Pure LOGIC - no drawing.
--
-- Each set has:
--   id    - its name inside the code
--   name  - what the player sees
--   needs - how many dice SLOTS you must have before it unlocks
--   mult  - its starting mult
--   check - a function that says if a roll CONTAINS this set
--
-- "Contains" works like poker: a roll of 4 4 4 2 2 contains a Full House,
-- but it also contains a Pair and a Three of a Kind. The set that SCORES
-- is the one with the biggest mult. Perkys like "if the roll contains a
-- Pair" look at everything the roll contains.

local pipshands = {}

-- Faces go up to 10 (dungeon dice), so we count all 10.
pipshands.MAX_FACE = 10

-- How many of each face: {6, 2, 6} -> counts[6] = 2, counts[2] = 1.
function pipshands.countFaces(values)
    local counts = {}
    for f = 1, pipshands.MAX_FACE do counts[f] = 0 end
    for _, v in ipairs(values) do counts[v] = counts[v] + 1 end
    return counts
end

-- How many DIFFERENT faces show up at least 'atLeast' times.
local function groupsOf(counts, atLeast)
    local n = 0
    for f = 1, pipshands.MAX_FACE do
        if counts[f] >= atLeast then n = n + 1 end
    end
    return n
end

-- The longest run of faces in a row (like 3-4-5-6) where each face shows
-- up at least 'atLeast' times.
local function longestRun(counts, atLeast)
    local best, run = 0, 0
    for f = 1, pipshands.MAX_FACE do
        if counts[f] >= atLeast then
            run = run + 1
            best = math.max(best, run)
        else
            run = 0
        end
    end
    return best
end

-- The check functions, made by small "makers" so we don't write the same
-- thing 30 times. Each maker gives back a function(counts).
local function ofAKind(n)
    return function(counts) return groupsOf(counts, n) >= 1 end
end
local function groups(size, howMany)
    return function(counts) return groupsOf(counts, size) >= howMany end
end
local function straight(length)
    return function(counts) return longestRun(counts, 1) >= length end
end
local function fullHouse(counts)
    -- A three of a kind, plus a pair of a DIFFERENT face.
    for a = 1, pipshands.MAX_FACE do
        if counts[a] >= 3 then
            for b = 1, pipshands.MAX_FACE do
                if b ~= a and counts[b] >= 2 then return true end
            end
        end
    end
    return false
end
local function tripleLadder(counts)
    return longestRun(counts, 3) >= 3   -- e.g. 222 333 444
end
local function nothing() return true end   -- every roll "contains" nothing special

-- Every set, from the start of the game to 11 dice.
pipshands.LIST = {
    { id = "none",       name = "High Roll",         needs = 0,  mult =  1,  check = nothing },
    { id = "pair",       name = "Pair",              needs = 3,  mult =  2,  check = ofAKind(2) },
    { id = "straight3",  name = "Small Straight",    needs = 3,  mult =  3,  check = straight(3) },
    { id = "three",      name = "Three of a Kind",   needs = 3,  mult =  4,  check = ofAKind(3) },
    { id = "twoPair",    name = "Two Pair",          needs = 4,  mult =  3,  check = groups(2, 2) },
    { id = "straight4",  name = "Straight of 4",     needs = 4,  mult =  5,  check = straight(4) },
    { id = "four",       name = "Four of a Kind",    needs = 4,  mult =  7,  check = ofAKind(4) },
    { id = "fullHouse",  name = "Full House",        needs = 5,  mult =  6,  check = fullHouse },
    { id = "straight5",  name = "Straight of 5",     needs = 5,  mult =  7,  check = straight(5) },
    { id = "five",       name = "Five of a Kind",    needs = 5,  mult = 10, check = ofAKind(5) },
    { id = "threePair",  name = "Three Pair",        needs = 6,  mult =  6,  check = groups(2, 3) },
    { id = "twoThree",   name = "Two Triples",       needs = 6,  mult =  9,  check = groups(3, 2) },
    { id = "straight6",  name = "Straight of 6",     needs = 6,  mult =  9,  check = straight(6) },
    { id = "six",        name = "Six of a Kind",     needs = 6,  mult = 13, check = ofAKind(6) },
    { id = "straight7",  name = "Straight of 7",     needs = 7,  mult = 11, check = straight(7) },
    { id = "seven",      name = "Seven of a Kind",   needs = 7,  mult = 16, check = ofAKind(7) },
    { id = "fourPair",   name = "Four Pair",         needs = 8,  mult =  8,  check = groups(2, 4) },
    { id = "twoFour",    name = "Two Fours",         needs = 8,  mult = 14, check = groups(4, 2) },
    { id = "straight8",  name = "Straight of 8",     needs = 8,  mult = 13, check = straight(8) },
    { id = "eight",      name = "Eight of a Kind",   needs = 8,  mult = 19, check = ofAKind(8) },
    { id = "threeThree", name = "Three Triples",     needs = 9,  mult = 15, check = groups(3, 3) },
    { id = "ladder",     name = "Triple Ladder",     needs = 9,  mult = 22, check = tripleLadder },
    { id = "straight9",  name = "Straight of 9",     needs = 9,  mult = 15, check = straight(9) },
    { id = "nine",       name = "Nine of a Kind",    needs = 9,  mult = 22, check = ofAKind(9) },
    { id = "fivePair",   name = "Five Pair",         needs = 10, mult = 10, check = groups(2, 5) },
    { id = "twoFive",    name = "Two Fives",         needs = 10, mult = 18, check = groups(5, 2) },
    { id = "straight10", name = "Straight of 10",    needs = 10, mult = 17, check = straight(10) },
    { id = "ten",        name = "Ten of a Kind",     needs = 10, mult = 25, check = ofAKind(10) },
    { id = "eleven",     name = "Eleven of a Kind",  needs = 11, mult = 28, check = ofAKind(11) },
}

-- Look a set up by its id: pipshands.BY_ID.pair
pipshands.BY_ID = {}
for _, h in ipairs(pipshands.LIST) do pipshands.BY_ID[h.id] = h end

function pipshands.get(id)
    return pipshands.BY_ID[id]
end

-- Is set h unlocked when you have 'slots' dice slots?
function pipshands.isUnlocked(h, slots)
    return slots >= h.needs
end

-- How much MULT one SET AUGMENT level adds to set h (bigger sets get more).
function pipshands.augmentMult(h)
    return math.max(1, math.ceil(h.mult / 3))
end

-- Every unlocked set this roll contains, as { [id] = true }.
function pipshands.contained(counts, slots)
    local found = {}
    for _, h in ipairs(pipshands.LIST) do
        if pipshands.isUnlocked(h, slots) and h.check(counts) then found[h.id] = true end
    end
    return found
end

-- The set that SCORES: the unlocked set this roll contains with the
-- biggest mult (counting set augments). 'augments' is { [id] = levels }.
-- Gives back the set and its mult. (Sets only give MULT - POINTS come
-- from the pips and dice augments.)
function pipshands.best(counts, slots, augments)
    local bestHand, bestMult = pipshands.BY_ID.none, 0
    for _, h in ipairs(pipshands.LIST) do
        if pipshands.isUnlocked(h, slots) and h.check(counts) then
            local m = h.mult + (augments[h.id] or 0) * pipshands.augmentMult(h)
            if m > bestMult then bestHand, bestMult = h, m end
        end
    end
    return bestHand, bestMult
end

return pipshands
