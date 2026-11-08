-- json.lua
-- A tiny JSON reader and writer, for talking to the online leaderboard.
-- (JSON is the text format web services use: {"name": "Ann", "level": 7}.)

local json = {}

local escapes = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }

-- Lua value -> JSON text. Tables with [1], [2]... become lists.
function json.encode(v)
    local t = type(v)
    if t == "nil" then return "null" end
    if t == "boolean" then return tostring(v) end
    if t == "number" then
        if v == math.floor(v) and math.abs(v) < 2 ^ 53 then return string.format("%d", v) end
        return string.format("%.14g", v)
    end
    if t == "string" then
        return '"' .. v:gsub('[%c"\\]', function(c)
            return escapes[c] or string.format("\\u%04x", c:byte())
        end) .. '"'
    end
    local parts = {}
    if #v > 0 or next(v) == nil then
        for _, x in ipairs(v) do table.insert(parts, json.encode(x)) end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    for k, x in pairs(v) do
        table.insert(parts, json.encode(tostring(k)) .. ":" .. json.encode(x))
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

-- JSON text -> Lua value. Returns nil if the text isn't valid JSON.
function json.decode(text)
    local pos = 1
    local function skip() pos = text:find("[^ \t\r\n]", pos) or #text + 1 end
    local value
    local function str()
        local out = {}
        pos = pos + 1
        while true do
            local c = text:sub(pos, pos)
            if c == "" then error("unfinished string") end
            if c == '"' then pos = pos + 1; break end
            if c == "\\" then
                local e = text:sub(pos + 1, pos + 1)
                if e == "u" then
                    local code = tonumber(text:sub(pos + 2, pos + 5), 16)
                    table.insert(out, code < 128 and string.char(code) or "?")
                    pos = pos + 6
                else
                    table.insert(out, ({ n = "\n", r = "\r", t = "\t", b = "\b", f = "\f" })[e] or e)
                    pos = pos + 2
                end
            else
                table.insert(out, c)
                pos = pos + 1
            end
        end
        return table.concat(out)
    end
    function value()
        skip()
        local c = text:sub(pos, pos)
        if c == "{" then
            local obj = {}
            pos = pos + 1; skip()
            if text:sub(pos, pos) == "}" then pos = pos + 1; return obj end
            while true do
                skip()
                local k = str(); skip()
                pos = pos + 1          -- the ':'
                obj[k] = value(); skip()
                local sep = text:sub(pos, pos); pos = pos + 1
                if sep == "}" then return obj end
            end
        elseif c == "[" then
            local list = {}
            pos = pos + 1; skip()
            if text:sub(pos, pos) == "]" then pos = pos + 1; return list end
            while true do
                table.insert(list, value()); skip()
                local sep = text:sub(pos, pos); pos = pos + 1
                if sep == "]" then return list end
            end
        elseif c == '"' then
            return str()
        elseif text:sub(pos, pos + 3) == "true" then pos = pos + 4; return true
        elseif text:sub(pos, pos + 4) == "false" then pos = pos + 5; return false
        elseif text:sub(pos, pos + 3) == "null" then pos = pos + 4; return nil
        end
        local num = text:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
        if not num or num == "" then error("bad JSON at " .. pos) end
        pos = pos + #num
        return tonumber(num)
    end
    local ok, result = pcall(value)
    if ok then return result end
    return nil
end

return json
