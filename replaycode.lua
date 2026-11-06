-- replaycode.lua
-- Turns a finished run into a REPLAY CODE (a line of letters and numbers a
-- player can share), and back again.
--
-- A run is fully decided by three things (see game.lua and rng.lua):
--   * the game type (normal / hard)
--   * the random seed it started from
--   * every action the player took, in order
-- So that's all the code holds - plus the final level and points, so a
-- replay can check it really reproduced the same run.
--
-- The code is those numbers packed into bytes, then written with 64
-- "safe" characters (A-Z a-z 0-9 - _) so it can be copied and pasted
-- anywhere. Each action is usually just ONE byte: its number in
-- game.ACTION_NAMES (x8), plus its small number (0-6). Bigger numbers
-- (like marker tile 21) take a second byte.

local game = require("game")

local replaycode = {}

replaycode.PREFIX = "PD1."   -- "Para-DICE code, version 1"
local MODES = { "normal", "hard" }
local CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

local function indexOf(list, x)
    for n, v in ipairs(list) do if v == x then return n end end
    return nil
end

-- Bytes -> text, 3 bytes become 4 characters.
local function toText(bytes)
    local out = {}
    for n = 1, #bytes, 3 do
        local a, b, c = bytes[n], bytes[n + 1] or 0, bytes[n + 2] or 0
        local v = a * 65536 + b * 256 + c
        local count = math.min(4, math.floor((#bytes - n + 1) * 4 / 3 + 0.999))
        for k = 1, count do
            local six = math.floor(v / 2 ^ (18 - 6 * (k - 1))) % 64
            table.insert(out, CHARS:sub(six + 1, six + 1))
        end
    end
    return table.concat(out)
end

-- Text -> bytes (nil if a character isn't one of ours).
local function toBytes(text)
    local bytes, bits, value = {}, 0, 0
    for n = 1, #text do
        local six = CHARS:find(text:sub(n, n), 1, true)
        if not six then return nil end
        value = value * 64 + (six - 1)
        bits = bits + 6
        if bits >= 8 then
            bits = bits - 8
            table.insert(bytes, math.floor(value / 2 ^ bits) % 256)
            value = value % 2 ^ bits
        end
    end
    return bytes
end

local function pushNumber(bytes, n, size)
    for k = size - 1, 0, -1 do table.insert(bytes, math.floor(n / 256 ^ k) % 256) end
end

local function readNumber(bytes, pos, size)
    local n = 0
    for k = 0, size - 1 do n = n * 256 + (bytes[pos + k] or 0) end
    return n, pos + size
end

-- The code for the run that just ended.
function replaycode.encode(mode, seed, log, finalLevel, finalPoints)
    local bytes = {}
    table.insert(bytes, indexOf(MODES, mode) or 1)
    pushNumber(bytes, seed, 4)
    pushNumber(bytes, finalLevel, 2)
    pushNumber(bytes, math.min(finalPoints, 2 ^ 48 - 1), 6)
    for _, action in ipairs(log) do
        local op = indexOf(game.ACTION_NAMES, action[1])
        local arg = action[2] or 0
        if arg <= 6 then
            table.insert(bytes, op * 8 + arg)
        else
            table.insert(bytes, op * 8 + 7)
            table.insert(bytes, arg)
        end
    end
    return replaycode.PREFIX .. toText(bytes)
end

-- Read a code. Returns a table { mode, seed, finalLevel, finalPoints,
-- actions = { {name, arg}, ... } }, or nil and a reason if it's not valid.
function replaycode.decode(code)
    code = (code or ""):gsub("%s", "")
    if code:sub(1, #replaycode.PREFIX) ~= replaycode.PREFIX then
        return nil, "That isn't a Para-DICE replay code."
    end
    local bytes = toBytes(code:sub(#replaycode.PREFIX + 1))
    if not bytes or #bytes < 13 then return nil, "That code looks broken or cut short." end
    local run = { mode = MODES[bytes[1]], actions = {} }
    if not run.mode then return nil, "That code is from a different version of the game." end
    local pos = 2
    run.seed, pos = readNumber(bytes, pos, 4)
    run.finalLevel, pos = readNumber(bytes, pos, 2)
    run.finalPoints, pos = readNumber(bytes, pos, 6)
    while pos <= #bytes do
        local b = bytes[pos]
        local name = game.ACTION_NAMES[math.floor(b / 8)]
        local arg = b % 8
        pos = pos + 1
        if arg == 7 then
            arg = bytes[pos]
            pos = pos + 1
        end
        if not name or not arg then return nil, "That code looks broken or cut short." end
        table.insert(run.actions, { name, arg })
    end
    return run
end

return replaycode
