-- augments.lua
-- PIPS MODE: AUGMENTS - lasting upgrades you buy in the shop or find in
-- augment packs. Pure LOGIC/data - no drawing.
--
-- There are two separate kinds:
--
--   DICE AUGMENTS (one for each face, 1 to 10) - make one face worth more
--   POINTS. Each level adds the face's own value again:
--       level 0:  a 4 scores 4 points
--       level 1:  a 4 scores 4 + 1 x 4 = 8
--       level 2:  a 4 scores 4 + 2 x 4 = 12
--   So a face scores  face x (1 + level).  This is where extra POINTS
--   come from - the sets themselves only give MULT.
--
--   SET AUGMENTS (one for each set except High Roll) - give one set more
--   MULT. Each level adds pipshands.augmentMult(set): +1 for small sets,
--   more for big ones.
--
-- An augment on offer is a small table:
--   { type = "diceAug", id = "dice4", face = 4 }   or
--   { type = "setAug",  id = "setPair", hand = "pair" }

local config    = require("config")
local pipshands = require("pipshands")

local augments = {}

local FACE_WORDS = { "Ones", "Twos", "Threes", "Fours", "Fives", "Sixes",
                     "Sevens", "Eights", "Nines", "Tens" }

-- Every dice augment, faces 1 to 10.
augments.DICE = {}
for f = 1, 10 do
    table.insert(augments.DICE, { type = "diceAug", id = "dice" .. f, face = f,
                                  name = FACE_WORDS[f] .. " Augment" })
end

-- Every set augment (High Roll can't be augmented).
augments.SETS = {}
for _, h in ipairs(pipshands.LIST) do
    if h.id ~= "none" then
        table.insert(augments.SETS, { type = "setAug", id = "set_" .. h.id, hand = h.id,
                                      name = h.name .. " Augment" })
    end
end

-- A copy of augment 'a' to put in the shop or a pack (with its price).
function augments.offer(a)
    return { type = a.type, id = a.id, face = a.face, hand = a.hand, name = a.name,
             price = config.PIPS.AUG_PRICE }
end

-- How many points one die showing 'face' scores, with 'level' dice augment levels.
function augments.facePoints(face, level)
    return face * (1 + (level or 0))
end

-- What augment 'a' does, in words. 'run' says what level you already have,
-- so the words can show what the NEXT level gives.
function augments.about(a, run)
    if a.type == "diceAug" then
        local level = run.diceAug[a.face] or 0
        return "Each " .. a.face .. " you score is worth +" .. a.face .. " more POINTS (level "
            .. level .. " -> " .. (level + 1) .. ": a " .. a.face .. " scores "
            .. augments.facePoints(a.face, level + 1) .. ")."
    end
    local h = pipshands.get(a.hand)
    local level = run.setAug[a.hand] or 0
    return h.name .. " gets +" .. pipshands.augmentMult(h) .. " MULT (level " .. level .. " -> "
        .. (level + 1) .. ": x" .. (h.mult + (level + 1) * pipshands.augmentMult(h)) .. ")."
end

return augments
