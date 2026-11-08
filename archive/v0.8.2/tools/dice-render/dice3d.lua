-- dice3d.lua
-- Draws a die as a little 3D CUBE, made from the 6 flat face pictures
-- (assets/dice/die_<color>_<face>.png). No pre-drawn rolling pictures are
-- needed: the cube is turned in code, so any colour, any angle, any face.
--
-- HOW IT WORKS
--   * A die's ORIENTATION (how it's turned in 3D) is a "quaternion": four
--     numbers {w, x, y, z} that describe a turn. They're easy to combine
--     and to blend smoothly from one turn to another (slerp).
--   * Directions: x = right across the screen, y = down the screen,
--     z = straight up out of the felt, towards you.
--   * Each face of the cube has a number. 1 points towards you when the die
--     isn't turned at all, and opposite faces add up to 7, like a real die.
--   * To draw, each corner of the cube is turned, then flattened onto the
--     screen (just drop the z). Faces pointing towards you are drawn as
--     textured 4-corner shapes ("meshes"), darker the more they lean away.
--
-- This file only DRAWS. It never changes any game data.

local dice3d = {}

---------------------------------------------------------------------------
-- QUATERNIONS (turns in 3D)
---------------------------------------------------------------------------

-- No turn at all.
function dice3d.identity()
    return { 1, 0, 0, 0 }
end

-- A turn of 'angle' radians around the direction (ax, ay, az).
function dice3d.fromAxisAngle(ax, ay, az, angle)
    local len = math.sqrt(ax * ax + ay * ay + az * az)
    if len < 1e-9 then
        return dice3d.identity()
    end
    local s = math.sin(angle / 2) / len
    return { math.cos(angle / 2), ax * s, ay * s, az * s }
end

-- Do turn b, THEN turn a  (written a * b).
function dice3d.mul(a, b)
    local aw, ax, ay, az = a[1], a[2], a[3], a[4]
    local bw, bx, by, bz = b[1], b[2], b[3], b[4]
    return {
        aw * bw - ax * bx - ay * by - az * bz,
        aw * bx + ax * bw + ay * bz - az * by,
        aw * by - ax * bz + ay * bw + az * bx,
        aw * bz + ax * by - ay * bx + az * bw,
    }
end

-- Keep the four numbers at length 1 (tiny rounding errors add up otherwise).
function dice3d.normalize(q)
    local len = math.sqrt(q[1] ^ 2 + q[2] ^ 2 + q[3] ^ 2 + q[4] ^ 2)
    return { q[1] / len, q[2] / len, q[3] / len, q[4] / len }
end

-- How close two turns are: 1 = the same, 0 = as different as can be.
local function closeness(a, b)
    return math.abs(a[1] * b[1] + a[2] * b[2] + a[3] * b[3] + a[4] * b[4])
end

-- Blend smoothly from turn a (t = 0) to turn b (t = 1), always the short
-- way round. t a little over 1 overshoots a little past b (for a rock).
function dice3d.slerp(a, b, t)
    local dot = a[1] * b[1] + a[2] * b[2] + a[3] * b[3] + a[4] * b[4]
    local bw, bx, by, bz = b[1], b[2], b[3], b[4]
    if dot < 0 then
        dot, bw, bx, by, bz = -dot, -bw, -bx, -by, -bz
    end
    if dot > 0.9995 then
        -- Almost the same: a straight blend is fine.
        return dice3d.normalize({
            a[1] + (bw - a[1]) * t, a[2] + (bx - a[2]) * t,
            a[3] + (by - a[3]) * t, a[4] + (bz - a[4]) * t })
    end
    local theta = math.acos(dot)
    local s = math.sin(theta)
    local wa = math.sin((1 - t) * theta) / s
    local wb = math.sin(t * theta) / s
    return { a[1] * wa + bw * wb, a[2] * wa + bx * wb, a[3] * wa + by * wb, a[4] * wa + bz * wb }
end

-- The angle (radians) between two turns.
function dice3d.angleBetween(a, b)
    return 2 * math.acos(math.min(1, closeness(a, b)))
end

-- Turn the point (x, y, z) by q.
local function rotate(q, x, y, z)
    local w, qx, qy, qz = q[1], q[2], q[3], q[4]
    -- t = 2 * (q.xyz cross v)
    local tx = 2 * (qy * z - qz * y)
    local ty = 2 * (qz * x - qx * z)
    local tz = 2 * (qx * y - qy * x)
    return x + w * tx + (qy * tz - qz * ty),
           y + w * ty + (qz * tx - qx * tz),
           z + w * tz + (qx * ty - qy * tx)
end


---------------------------------------------------------------------------
-- THE CUBE
---------------------------------------------------------------------------

-- Each face: which way it points (n), and the two directions its picture
-- runs along (u = left->right of the picture, v = top->bottom).
-- Face 1 looks straight at you with its picture the right way up.
local FACES = {
    [1] = { n = { 0, 0, 1 },  u = { 1, 0, 0 },  v = { 0, 1, 0 } },
    [6] = { n = { 0, 0, -1 }, u = { -1, 0, 0 }, v = { 0, 1, 0 } },
    [2] = { n = { 0, 1, 0 },  u = { 1, 0, 0 },  v = { 0, 0, -1 } },
    [5] = { n = { 0, -1, 0 }, u = { 1, 0, 0 },  v = { 0, 0, 1 } },
    [3] = { n = { 1, 0, 0 },  u = { 0, 0, -1 }, v = { 0, 1, 0 } },
    [4] = { n = { -1, 0, 0 }, u = { 0, 0, 1 },  v = { 0, 1, 0 } },
}

-- (The sides are numbered like the faces of a plain die: side N shows
-- face N unless the pictures have been swapped round - see draw.)

-- The turn that brings side 'face' round to look straight at you (picture the
-- right way up, as if it were face 1).
local FACE_UP = {}
do
    local h = math.pi / 2
    FACE_UP[1] = dice3d.identity()
    FACE_UP[6] = dice3d.fromAxisAngle(0, 1, 0, math.pi)
    FACE_UP[2] = dice3d.fromAxisAngle(1, 0, 0, h)    -- +y face swings up to +z
    FACE_UP[5] = dice3d.fromAxisAngle(1, 0, 0, -h)
    FACE_UP[3] = dice3d.fromAxisAngle(0, 1, 0, -h)   -- +x face swings round to +z
    FACE_UP[4] = dice3d.fromAxisAngle(0, 1, 0, h)
end

-- The resting turn with 'face' looking at you, squared to the screen.
-- Of the 4 ways it could sit (turned 0, 90, 180 or 270 degrees flat on the
-- felt), pick the one nearest to 'near', so the die rolls the least.
-- Only 0 degrees shows the picture exactly upright, so 'upright' = true
-- forces that one.
function dice3d.faceUp(face, near, upright)
    local base = FACE_UP[face]
    if upright or near == nil then
        return base
    end
    local best, bestClose = base, -1
    for k = 0, 3 do
        local q = dice3d.mul(dice3d.fromAxisAngle(0, 0, 1, k * math.pi / 2), base)
        local c = closeness(q, near)
        if c > bestClose then
            best, bestClose = q, c
        end
    end
    return best
end

-- Pictures and colours, filled in by dice3d.load().
local images = {}     -- images[color][face]
local bodyColor = {}  -- bodyColor[color] = { r, g, b }, the die's plastic, darker
local mesh = nil      -- one 4-corner mesh, refilled for each face drawn

-- Call once from love.load, with the list of colour ids.
function dice3d.load(colors)
    for _, color in ipairs(colors) do
        images[color] = {}
        for face = 1, 6 do
            images[color][face] = love.graphics.newImage("assets/dice/die_" .. color .. "_" .. face .. ".png")
        end
        -- The plastic's colour: a spot on face 1 between the edge and the pip.
        local data = love.image.newImageData("assets/dice/die_" .. color .. "_1.png")
        local r, g, b = data:getPixel(math.floor(data:getWidth() * 0.23), math.floor(data:getHeight() / 2))
        bodyColor[color] = { r * 0.72, g * 0.72, b * 0.72 }
        data:release()
    end
    mesh = love.graphics.newMesh(4, "fan", "stream")
end

-- The flat picture for one face (the shop uses this).
function dice3d.faceImage(color, face)
    return images[color][face]
end

-- How much cube side 'slot' faces you when turned by q: 1 = straight at
-- you, 0 = edge on, below 0 = facing away (hidden).
function dice3d.facing(q, slot)
    local n = FACES[slot].n
    local _, _, z = rotate(q, n[1], n[2], n[3])
    return z
end

-- Which cube side faces you most when turned by q.
function dice3d.topSlot(q)
    local best, bestZ = 1, -2
    for slot = 1, 6 do
        local z = dice3d.facing(q, slot)
        if z > bestZ then
            best, bestZ = slot, z
        end
    end
    return best
end

-- The 8 corners of a cube 2 wide, centred on (0, 0, 0).
local CORNERS = {}
for _, sx in ipairs({ -1, 1 }) do
    for _, sy in ipairs({ -1, 1 }) do
        for _, sz in ipairs({ -1, 1 }) do
            table.insert(CORNERS, { sx, sy, sz })
        end
    end
end

-- The outline round a set of points (a "convex hull"), going round in order.
local function hull(points)
    table.sort(points, function(a, b)
        return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2])
    end)
    local function cross(o, a, b)
        return (a[1] - o[1]) * (b[2] - o[2]) - (a[2] - o[2]) * (b[1] - o[1])
    end
    local lower, upper = {}, {}
    for _, p in ipairs(points) do
        while #lower >= 2 and cross(lower[#lower - 1], lower[#lower], p) <= 0 do
            table.remove(lower)
        end
        table.insert(lower, p)
    end
    for n = #points, 1, -1 do
        local p = points[n]
        while #upper >= 2 and cross(upper[#upper - 1], upper[#upper], p) <= 0 do
            table.remove(upper)
        end
        table.insert(upper, p)
    end
    table.remove(lower)
    table.remove(upper)
    local out = {}
    for _, p in ipairs(lower) do table.insert(out, p) end
    for _, p in ipairs(upper) do table.insert(out, p) end
    return out
end

-- Draw a die of 'color' turned by q, centred on (cx, cy), 'size' pixels
-- across (one face seen straight on is exactly 'size' wide), then turned
-- flat on the screen by 'angle' radians.
-- With q = dice3d.faceUp(face, nil, true) and angle 0 it looks exactly
-- like the flat picture of that face.
-- 'labels' (optional) says which picture is on each cube side:
-- labels[side] = face number. Without it, side N shows face N.
-- (animation.lua swaps the pictures of HIDDEN sides mid-roll, so the die
-- can roll naturally onto its real result.)
function dice3d.draw(color, q, cx, cy, size, angle, labels)
    local half = size / 2
    local ca, sa = math.cos(angle or 0), math.sin(angle or 0)
    -- Turn by q, then flat by 'angle', then onto the screen.
    local function project(x, y, z)
        local rx, ry, rz = rotate(q, x, y, z)
        return cx + (rx * ca - ry * sa) * half, cy + (rx * sa + ry * ca) * half, rz
    end

    -- The solid body behind the faces (the pictures have rounded,
    -- see-through corners). Shrunk a little so it never pokes out past them.
    local points = {}
    for n, c in ipairs(CORNERS) do
        local px, py = project(c[1], c[2], c[3])
        points[n] = { px, py }
    end
    local outline = hull(points)
    if #outline >= 3 then
        local flat = {}
        for _, p in ipairs(outline) do
            table.insert(flat, cx + (p[1] - cx) * 0.8)
            table.insert(flat, cy + (p[2] - cy) * 0.8)
        end
        local b = bodyColor[color]
        love.graphics.setColor(b[1], b[2], b[3])
        love.graphics.polygon("fill", flat)
    end

    -- Each side pointing towards you.
    for slot = 1, 6 do
        local f = FACES[slot]
        local _, _, nz = rotate(q, f.n[1], f.n[2], f.n[3])
        if nz > 0.001 then
            -- Lean away = darker. Square on to you = full brightness.
            local shade = 0.45 + 0.55 * nz
            local n, u, v = f.n, f.u, f.v
            local function corner(su, sv, tu, tv)
                local x = n[1] + u[1] * su + v[1] * sv
                local y = n[2] + u[2] * su + v[2] * sv
                local z = n[3] + u[3] * su + v[3] * sv
                local px, py = project(x, y, z)
                return { px, py, tu, tv, shade, shade, shade, 1 }
            end
            mesh:setVertices({
                corner(-1, -1, 0, 0),
                corner(1, -1, 1, 0),
                corner(1, 1, 1, 1),
                corner(-1, 1, 0, 1),
            })
            mesh:setTexture(images[color][labels and labels[slot] or slot])
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(mesh)
        end
    end
end

return dice3d
