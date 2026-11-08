-- bossart.lua
-- PIPS MODE: DRAWING the bosses as chunky 16-bit style pixel pictures.
-- Drawing only - nothing here changes game data.
--
-- Each picture is a grid of letters, one letter per "pixel". Each letter
-- stands for a colour:
--   .  see-through          h  hair             b  eyebrows (dark hair)
--   s  skin                 e  white of the eye o  pupil / dice pip (black)
--   m  mouth                r  red lips         x  white (the die on their chest)
--   c  shirt                p  trousers         k  shoes
--   d  dress                j  suit jacket      w  white shirt      t  tie
-- The colours for h, c, p, d, j and t come from each boss (bosses.lua),
-- so the same picture can be four different people.

local bossart = {}

local PICTURES = {
    man = {
        "................",
        ".....hhhhhh.....",
        "....hhhhhhhh....",
        "....hhhhhhhh....",
        "....hssssssh....",
        "....sbbssbbs....",
        "....seossoes....",
        "....ssssssss....",
        "....ssmmmmss....",
        ".....ssssss.....",
        "......ssss......",
        "...cccccccccc...",
        "..cccccxxxcccc..",
        "..cccccxoxcccc..",
        "..cccccxxxcccc..",
        ".ss.cccccccc.ss.",
        ".ss.cccccccc.ss.",
        "....pppppppp....",
        "....ppp..ppp....",
        "....ppp..ppp....",
        "....ppp..ppp....",
        "...kkkk..kkkk...",
    },
    woman = {
        "................",
        "....hhhhhhhh....",
        "...hhhhhhhhhh...",
        "...hhhhhhhhhh...",
        "...hssssssssh...",
        "...hsbbssbbsh...",
        "...hseossoesh...",
        "...hssssssssh...",
        "...hssrrrrssh...",
        "..hhh.ssss.hhh..",
        "..hhhddddddhhh..",
        "..hddddxxxdddh..",
        "..hddddxoxdddh..",
        ".ssddddxxxdddss.",
        ".ss.dddddddd.ss.",
        "...dddddddddd...",
        "..dddddddddddd..",
        "....ss....ss....",
        "....ss....ss....",
        "....ss....ss....",
        "....ss....ss....",
        "...kkk....kkk...",
    },
    suit = {
        "................",
        ".....hhhhhh.....",
        "....hhhhhhhh....",
        "....hhhhhhhh....",
        "....hssssssh....",
        "....sbbssbbs....",
        "....seossoes....",
        "....ssssssss....",
        "....sssmmsss....",
        ".....ssssss.....",
        "......ssss......",
        "...jjjwttwjjj...",
        "..jjjjwttwjjjj..",
        "..jjjjwttwjjjj..",
        "..jjjjjttjjjjj..",
        ".ssjjjjttjjjjss.",
        ".ss.jjjjjjjj.ss.",
        "....jjjjjjjj....",
        "....jjj..jjj....",
        "....jjj..jjj....",
        "....jjj..jjj....",
        "...kkkk..kkkk...",
    },
}

-- Darker version of a colour (for eyebrows).
local function darker(c)
    return { c[1] * 0.6, c[2] * 0.6, c[3] * 0.6 }
end

-- The colour for each letter, for boss 'b'.
local function paletteFor(b)
    local c = b.colors
    return {
        h = c.hair, b = darker(c.hair),
        s = { 0.96, 0.78, 0.62 }, e = { 1, 1, 1 }, o = { 0.05, 0.05, 0.05 },
        m = { 0.55, 0.12, 0.12 }, r = { 0.90, 0.10, 0.20 }, x = { 1, 1, 1 },
        c = c.shirt or { 0.5, 0.5, 0.5 }, p = c.pants or { 0.2, 0.2, 0.3 },
        k = { 0.10, 0.07, 0.05 }, d = c.dress or { 0.5, 0.2, 0.6 },
        j = c.suit or { 0.15, 0.15, 0.18 }, w = { 0.97, 0.97, 0.97 }, t = c.tie or { 0.8, 0.1, 0.1 },
    }
end

-- The size of a picture at 'scale' (each pixel is scale x scale).
function bossart.size(b, scale)
    local pic = PICTURES[b.art]
    return #pic[1] * scale, #pic * scale
end

-- Draw boss 'b' with its top-left at (x, y). 'alpha' fades it in (0-1).
function bossart.draw(b, x, y, scale, alpha)
    alpha = alpha or 1
    local pic = PICTURES[b.art]
    local palette = paletteFor(b)
    -- A dark outline first: every pixel drawn a little bigger in black.
    love.graphics.setColor(0, 0, 0, 0.8 * alpha)
    for row, line in ipairs(pic) do
        for col = 1, #line do
            if line:sub(col, col) ~= "." then
                love.graphics.rectangle("fill", x + (col - 1) * scale - scale * 0.25,
                    y + (row - 1) * scale - scale * 0.25, scale * 1.5, scale * 1.5)
            end
        end
    end
    -- Then the pixels themselves.
    for row, line in ipairs(pic) do
        for col = 1, #line do
            local color = palette[line:sub(col, col)]
            if color then
                love.graphics.setColor(color[1], color[2], color[3], alpha)
                love.graphics.rectangle("fill", x + (col - 1) * scale, y + (row - 1) * scale, scale, scale)
            end
        end
    end
end

return bossart
