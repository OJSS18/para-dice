-- Renders every tumble / settle / land frame for every colour from the flat faces.
local d3 = require("dice3d")
local FRAME = tonumber(os.getenv("FRAME") or "216")
local BODY = 130
local COLORS = { "white", "red", "blue", "green", "purple", "amber" }
local rad = math.rad

-- The spin loop: two turns at once (forwards tumble + a slower twist), both
-- completing exactly once over 16 frames, so frame 17 would equal frame 1.
local BASE = d3.mul(d3.fromAxisAngle(1, 0, 0, rad(-28)), d3.fromAxisAngle(0, 1, 0, rad(32)))
local function spin(k)
    local t = (k - 1) / 16 * 2 * math.pi
    return d3.mul(d3.fromAxisAngle(1, 0.15, 0, t), d3.mul(d3.fromAxisAngle(0.2, 0.3, 1, t), BASE))
end

-- Settling onto face R: the last tip of the roll, then a small rock back.
-- f tips forwards (top coming towards you), r tips the other way.
local SETTLE = { 52, 24, 7, -3 }   -- degrees from flat, steps 1-4
local function settle(face, dir, k)
    local axis = dir == "f" and { 1, 0.3, 0 } or { -1, 0.3, 0 }
    return d3.mul(d3.fromAxisAngle(axis[1], axis[2], axis[3], rad(SETTLE[k])), d3.faceUp(face, nil, true))
end

local canvas
local function render(color, q, name)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setBlendMode("alpha")
    d3.draw(color, q, FRAME / 2, FRAME / 2, BODY, 0)
    love.graphics.setCanvas()
    canvas:newImageData():encode("png", name)
end

function love.load()
    d3.load(COLORS)
    canvas = love.graphics.newCanvas(FRAME, FRAME)
    love.filesystem.createDirectory("tumble")
    for _, c in ipairs(COLORS) do
        for k = 1, 16 do render(c, spin(k), string.format("tumble/tumble_%s_%02d.png", c, k)) end
        for f = 1, 6 do
            render(c, d3.faceUp(f, nil, true), string.format("tumble/land_%s_%d.png", c, f))
            for _, dir in ipairs({ "f", "r" }) do
                for k = 1, 4 do render(c, settle(f, dir, k), string.format("tumble/settle_%s_%s%d_%d.png", c, dir, f, k)) end
            end
        end
    end
    love.event.quit()
end
