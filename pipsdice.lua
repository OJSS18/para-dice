-- pipsdice.lua
-- PIPS MODE: every kind of die, and the 10 colours a die (and its pips)
-- can be. Pure LOGIC/data - nothing here draws (pipsdraw.lua does that).
--
-- A die in PIPS mode is a small table:
--   { kind = "classic", faces = {1,2,3,4,5,6}, body = 1, pip = 2 }
--   faces - the number on each side. Rolling picks one side at random, so
--           a face that's written twice comes up twice as often.
--   body  - which colour (1-10 in pipsdice.COLORS) the die is
--   pip   - which colour its dots are

local rng = require("rng")

local pipsdice = {}

-- The 10 colours. Any die and any pip can be any of these.
pipsdice.COLORS = {
    { name = "Ivory",    rgb = { 0.96, 0.94, 0.88 } },
    { name = "Onyx",     rgb = { 0.10, 0.10, 0.12 } },
    { name = "Ruby",     rgb = { 0.85, 0.10, 0.14 } },
    { name = "Amber",    rgb = { 0.98, 0.55, 0.10 } },
    { name = "Gold",     rgb = { 1.00, 0.84, 0.20 } },
    { name = "Jade",     rgb = { 0.10, 0.65, 0.32 } },
    { name = "Sapphire", rgb = { 0.12, 0.35, 0.90 } },
    { name = "Violet",   rgb = { 0.55, 0.22, 0.80 } },
    { name = "Rose",     rgb = { 1.00, 0.45, 0.70 } },
    { name = "Aqua",     rgb = { 0.15, 0.80, 0.85 } },
}

-- Is colour number c a light one? (Dark pips go on light dice and the
-- other way round, so you can always read them.)
local LIGHT = { [1] = true, [4] = true, [5] = true, [9] = true, [10] = true }
function pipsdice.isLight(c)
    return LIGHT[c] == true
end

-- The kinds of die. 'faces' are the 6 (or more) sides. 'body' is the
-- colour the die always has, so you can tell the kinds apart at a glance.
-- Dungeon dice (d7 and up) only come from the DUNGEON DICE pack.
pipsdice.KINDS = {
    classic  = { name = "Classic Die",  about = "A normal die: 1 to 6.",          faces = { 1, 2, 3, 4, 5, 6 }, body = 1 },
    high     = { name = "High Roller",  about = "Only 4s, 5s and 6s.",            faces = { 4, 4, 5, 5, 6, 6 }, body = 3 },
    low      = { name = "Low Rider",    about = "Only 1s, 2s and 3s.",            faces = { 1, 1, 2, 2, 3, 3 }, body = 7 },
    odd      = { name = "Odd Ball",     about = "Only 1s, 3s and 5s.",            faces = { 1, 1, 3, 3, 5, 5 }, body = 8 },
    even     = { name = "Even Keel",    about = "Only 2s, 4s and 6s.",            faces = { 2, 2, 4, 4, 6, 6 }, body = 6 },
    twins    = { name = "Twin Die",     about = "Mostly 3s and 4s - good for sets.", faces = { 3, 3, 4, 4, 5, 6 }, body = 10 },
    loaded   = { name = "Loaded Six",   about = "Two 6s, and no 5.",              faces = { 1, 2, 3, 4, 6, 6 }, body = 5 },
    middle   = { name = "Middle Man",   about = "Two 3s and two 4s, no 1 or 6.",  faces = { 2, 3, 3, 4, 4, 5 }, body = 9 },
    -- Dungeon dice. A die can't show more than 10, so the big ones repeat
    -- their high faces (they roll high more often).
    d7  = { name = "D7",  about = "Rolls 1 to 7.",  faces = { 1, 2, 3, 4, 5, 6, 7 }, body = 2, dungeon = true },
    d8  = { name = "D8",  about = "Rolls 1 to 8.",  faces = { 1, 2, 3, 4, 5, 6, 7, 8 }, body = 2, dungeon = true },
    d9  = { name = "D9",  about = "Rolls 1 to 9.",  faces = { 1, 2, 3, 4, 5, 6, 7, 8, 9 }, body = 2, dungeon = true },
    d10 = { name = "D10", about = "Rolls 1 to 10.", faces = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }, body = 2, dungeon = true },
    d12 = { name = "D12", about = "1 to 10, with an extra 9 and 10.",
            faces = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 9, 10 }, body = 2, dungeon = true },
    d15 = { name = "D15", about = "1 to 10, with 6-10 twice.",
            faces = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 6, 7, 8, 9, 10 }, body = 2, dungeon = true },
    d20 = { name = "D20", about = "1 to 10, with 6-10 three times.",
            faces = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 6, 7, 8, 9, 10, 6, 7, 8, 9, 10 }, body = 2, dungeon = true },
}

-- The kinds in a fixed order (pairs() on a table has no fixed order, and
-- the game's random picks must come out the same every time for a seed).
pipsdice.PACK_KINDS    = { "classic", "high", "low", "odd", "even", "twins", "loaded", "middle" }
pipsdice.DUNGEON_KINDS = { "d7", "d8", "d9", "d10", "d12", "d15", "d20" }

-- A random pip colour that shows up well on body colour 'body'.
local function pipColorFor(body)
    local choices = {}
    for c = 1, #pipsdice.COLORS do
        if c ~= body and pipsdice.isLight(c) ~= pipsdice.isLight(body) then
            table.insert(choices, c)
        end
    end
    return choices[rng.random(#choices)]
end

-- Make a new die of a kind. 'pip' is optional (a random one if nil).
function pipsdice.make(kindId, pip)
    local kind = pipsdice.KINDS[kindId]
    return { kind = kindId, faces = kind.faces, body = kind.body, pip = pip or pipColorFor(kind.body) }
end

-- The die everyone starts with: an ivory classic die with onyx pips.
function pipsdice.starter()
    return pipsdice.make("classic", 2)
end

-- Roll one die: pick one of its sides at random.
function pipsdice.roll(die)
    return die.faces[rng.random(#die.faces)]
end

-- The biggest number die can show.
function pipsdice.maxFace(die)
    local best = 1
    for _, f in ipairs(die.faces) do best = math.max(best, f) end
    return best
end

function pipsdice.info(die)
    return pipsdice.KINDS[die.kind]
end

-- 'count' different random kinds from 'list' (for a pack).
function pipsdice.randomKinds(list, count)
    local pool = {}
    for _, id in ipairs(list) do table.insert(pool, id) end
    local picked = {}
    while #picked < count and #pool > 0 do
        table.insert(picked, table.remove(pool, rng.random(#pool)))
    end
    return picked
end

return pipsdice
