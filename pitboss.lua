-- pitboss.lua
-- PIPS MODE: the BRAIN of PIT BOSS JOSH, the final boss. Pure LOGIC.
--
-- Josh plays with a copy of YOUR run (same dice, Perkys, augments and
-- craps bets - see pipsgame.lua), so the best way for him to play is
-- whatever your build is good at. Each set he:
--   1. rolls all his dice,
--   2. tries several ways to hold them (keep the biggest group, keep every
--      pair, keep a straight, keep the high dice...), imagines each reroll
--      30 times, and picks the hold with the best average score,
--   3. rerolls if that beats scoring now by enough (and he has rerolls),
--   4. scores.
-- The strategy test bot (tools/pips-sim) uses the same brain.
--
-- All of Josh's dice and imagined rolls use his OWN random generator (made
-- from the run's seed), so a run still plays out the same every time.

local pipshands = require("pipshands")
local pipsscore = require("pipsscore")

local pitboss = {}

-- Roll one die with generator 'gen'.
local function rollFace(die, gen)
    return die.faces[gen:random(#die.faces)]
end

local function copyList(list)
    local out = {}
    for i, v in ipairs(list) do out[i] = v end
    return out
end

-- Ways to hold dice worth trying, for the dice showing 'values'.
-- Each is a list of true/false, one per die.
function pitboss.candidates(values)
    local counts = pipshands.countFaces(values)
    local list = {}
    local function add(keep)
        local h = {}
        for i, v in ipairs(values) do h[i] = keep(i, v) and true or false end
        table.insert(list, h)
    end
    add(function() return false end)                         -- hold nothing
    add(function(_, v) return counts[v] >= 2 end)            -- every pair or better
    for f = 1, pipshands.MAX_FACE do                         -- each face's group on its own
        if counts[f] >= 1 then add(function(_, v) return v == f end) end
    end
    add(function(_, v) return counts[v] >= 2 or v >= 5 end)  -- pairs and high dice
    add(function(_, v) return v >= 5 end)                    -- high dice only
    -- The longest run of faces in a row (one die for each face).
    local bestStart, bestLen, start, len = 1, 0, 1, 0
    for f = 1, pipshands.MAX_FACE do
        if counts[f] > 0 then
            if len == 0 then start = f end
            len = len + 1
            if len > bestLen then bestLen, bestStart = len, start end
        else
            len = 0
        end
    end
    if bestLen >= 2 then
        local used = {}
        add(function(_, v)
            if v >= bestStart and v < bestStart + bestLen and not used[v] then
                used[v] = true
                return true
            end
            return false
        end)
    end
    return list
end

-- The average score after rerolling every die not in 'hold'.
local function expected(run, values, hold, gen, samples)
    local total = 0
    local trial = {}
    for _ = 1, samples do
        for i, die in ipairs(run.dice) do
            trial[i] = hold[i] and values[i] or rollFace(die, gen)
        end
        total = total + pipsscore.score(run, trial, true).total
    end
    return total / samples
end

-- Should 'run' reroll the dice showing 'values'? Gives back the hold to
-- reroll with, or nil to score now.
--   samples - how many imagined rolls per hold (more = smarter, slower)
--   goalLeft- points still needed to win (nil = no goal, score as high as possible)
function pitboss.chooseHold(run, values, gen, samples, goalLeft)
    if run.rerollsLeft <= 0 then return nil end
    local now = pipsscore.score(run, values, true).total
    if goalLeft and now >= goalLeft then return nil end   -- already enough: keep the rerolls
    local bestHold, bestValue = nil, -1
    for _, hold in ipairs(pitboss.candidates(values)) do
        local holdsAll = true
        for i = 1, #run.dice do
            if not hold[i] then holdsAll = false end
        end
        if not holdsAll then
            local e = expected(run, values, hold, gen, samples)
            if e > bestValue then bestHold, bestValue = hold, e end
        end
    end
    -- Spend rerolls freely when there are enough for the sets left.
    local margin = 1.15
    if run.rerollsLeft >= run.setsLeft or run.setsLeft <= 1 then margin = 1.0 end
    if bestHold and bestValue > now * margin then return bestHold end
    return nil
end

-- Josh plays ONE set with his copy of the run ('josh', see pipsgame.lua).
-- Gives back:
--   steps  - every roll he made: { {values = {...}, held = {...}}, ... }
--            (the screen plays these back one by one)
--   result - his score for the set (from pipsscore.score)
function pitboss.playSet(josh, gen)
    josh.rerollsThisSet = 0
    local values = {}
    for i, die in ipairs(josh.dice) do values[i] = rollFace(die, gen) end
    local steps = { { values = copyList(values), held = {} } }
    while true do
        local hold = pitboss.chooseHold(josh, values, gen, 30, nil)
        if not hold then break end
        for i, die in ipairs(josh.dice) do
            if not hold[i] then values[i] = rollFace(die, gen) end
        end
        josh.rerollsLeft = josh.rerollsLeft - 1
        josh.rerollsThisSet = josh.rerollsThisSet + 1
        table.insert(steps, { values = copyList(values), held = hold })
    end
    local result = pipsscore.score(josh, values, false)   -- (his growing Perkys really grow)
    josh.setsLeft = josh.setsLeft - 1
    return steps, result
end

return pitboss
