-- leaderboard.lua
-- The LEADERBOARD: the best runs, ranked by the highest level reached,
-- then by points. Every finished run (by a logged-in player, not the
-- tutorial, no god mode) goes on it, with its replay code so anyone can
-- WATCH it.
--
-- Two boards:
--   * THIS DEVICE - saved in the save folder; always works.
--   * ONLINE      - shared by everyone, on a Supabase database (a free web
--                   service). It switches on once config.ONLINE_URL and
--                   config.ONLINE_KEY are filled in (see README.md).
-- Nothing in here draws.

local config = require("config")
local json   = require("json")
local net    = require("net")

local leaderboard = {}

local FILE = "leaderboard.txt"
local KEEP = 100   -- how many runs the device board keeps

leaderboard.device = {}             -- the runs saved on this device, best first
leaderboard.online = {}             -- the last list downloaded, best first
leaderboard.onlineStatus = "idle"   -- "idle", "loading", "ok", "error", "off"

function leaderboard.isOnline()
    return config.ONLINE_URL ~= "" and config.ONLINE_KEY ~= ""
end

-- Is run a better than run b?
local function better(a, b)
    if a.level ~= b.level then return a.level > b.level end
    return a.points > b.points
end

local function sortRuns(list)
    table.sort(list, better)
end


---------------------------------------------------------------------------
-- THIS DEVICE
---------------------------------------------------------------------------

function leaderboard.load()
    if not love.filesystem.getInfo(FILE) then return end
    local data = json.decode(love.filesystem.read(FILE) or "")
    if type(data) == "table" then
        leaderboard.device = data
        sortRuns(leaderboard.device)
    end
end

local function saveDevice()
    love.filesystem.write(FILE, json.encode(leaderboard.device))
end


---------------------------------------------------------------------------
-- ONLINE
---------------------------------------------------------------------------

local function headers()
    return {
        ["apikey"] = config.ONLINE_KEY,
        ["Authorization"] = "Bearer " .. config.ONLINE_KEY,
        ["Content-Type"] = "application/json",
        ["Prefer"] = "return=minimal",
    }
end

-- Download the top runs for a game type ("normal" or "hard").
function leaderboard.fetchOnline(mode)
    if not leaderboard.isOnline() then
        leaderboard.onlineStatus = "off"
        return
    end
    leaderboard.onlineStatus = "loading"
    local url = config.ONLINE_URL .. "/rest/v1/runs?select=username,mode,level,points,code,created_at"
        .. "&mode=eq." .. mode .. "&order=level.desc,points.desc&limit=50"
    net.request("GET", url, headers(), nil, function(status, text)
        local list = (status == 200) and json.decode(text)
        if type(list) ~= "table" then
            leaderboard.onlineStatus = "error"
            return
        end
        leaderboard.online = {}
        for _, row in ipairs(list) do
            table.insert(leaderboard.online, { name = row.username, mode = row.mode,
                level = tonumber(row.level) or 0, points = tonumber(row.points) or 0, code = row.code })
        end
        leaderboard.onlineStatus = "ok"
    end)
end


---------------------------------------------------------------------------
-- ADDING A RUN
---------------------------------------------------------------------------

-- run = { name, mode, level, points, code }
function leaderboard.submit(run)
    run.date = os.date("%Y-%m-%d")
    table.insert(leaderboard.device, run)
    sortRuns(leaderboard.device)
    while #leaderboard.device > KEEP do table.remove(leaderboard.device) end
    saveDevice()

    if leaderboard.isOnline() then
        local body = json.encode({ username = run.name, mode = run.mode, level = run.level,
            points = run.points, code = run.code, version = config.VERSION })
        net.request("POST", config.ONLINE_URL .. "/rest/v1/runs", headers(), body, function() end)
    end
end

-- The runs to show for a board ("online" or "device") and a game type.
function leaderboard.list(board, mode)
    local source = board == "online" and leaderboard.online or leaderboard.device
    local out = {}
    for _, run in ipairs(source) do
        if run.mode == mode then table.insert(out, run) end
    end
    return out
end

return leaderboard
