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
leaderboard.online = {}             -- leaderboard.online[mode] = the last list downloaded, best first
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
    local h = {
        ["apikey"] = config.ONLINE_KEY,
        ["Content-Type"] = "application/json",
        ["Prefer"] = "return=minimal",
    }
    -- Older "anon" keys (they start with eyJ) also go in Authorization;
    -- the newer "sb_publishable_" keys must not.
    if config.ONLINE_KEY:sub(1, 3) == "eyJ" then
        h["Authorization"] = "Bearer " .. config.ONLINE_KEY
    end
    return h
end

-- Download the top runs for a game type ("normal" or "hard").
-- Only runs from THIS version of the game are fetched: a replay code only
-- replays on the version it was made with, and every run must replay to be
-- shown (see verify.lua). So each new version starts a fresh "season".
-- 'quietly' = true keeps showing the old list while the new one loads.
function leaderboard.fetchOnline(mode, quietly)
    if not leaderboard.isOnline() then
        leaderboard.onlineStatus = "off"
        return
    end
    leaderboard.lastMode = mode
    if not (quietly and leaderboard.onlineStatus == "ok") then
        leaderboard.onlineStatus = "loading"
    end
    local url = config.ONLINE_URL .. "/rest/v1/runs?select=username,mode,level,points,code,created_at"
        .. "&mode=eq." .. mode .. "&version=eq." .. config.RULES_VERSION
        .. "&order=level.desc,points.desc,created_at.asc&limit=200"
    net.request("GET", url, headers(), nil, function(status, text)
        local list = (status == 200) and json.decode(text)
        if type(list) ~= "table" then
            if leaderboard.onlineStatus ~= "ok" then leaderboard.onlineStatus = "error" end
            return
        end
        -- Keep what we already checked (so a refresh doesn't check again),
        -- and only the FIRST post of each code (someone re-posting another
        -- player's code under their own name doesn't count).
        local checked = {}
        for _, old in ipairs(leaderboard.online[mode] or {}) do
            checked[old.code] = old.verified
        end
        local runs, seen = {}, {}
        for _, row in ipairs(list) do
            if row.code and not seen[row.code] then
                seen[row.code] = true
                table.insert(runs, { name = row.username, mode = row.mode, code = row.code,
                    level = tonumber(row.level) or 0, points = tonumber(row.points) or 0,
                    verified = checked[row.code] })
            end
        end
        leaderboard.online[mode] = runs
        leaderboard.onlineStatus = "ok"
    end)
end


---------------------------------------------------------------------------
-- ADDING A RUN
---------------------------------------------------------------------------

-- run = { name, mode, level, points, code, god (true if god mode was used) }
function leaderboard.submit(run)
    run.date = os.date("%Y-%m-%d")
    table.insert(leaderboard.device, run)
    sortRuns(leaderboard.device)
    while #leaderboard.device > KEEP do table.remove(leaderboard.device) end
    saveDevice()

    -- Online too (not god mode runs), then download the board again so the
    -- new run shows up there straight away.
    if leaderboard.isOnline() and not run.god and run.code then
        local body = json.encode({ username = run.name, mode = run.mode, level = run.level,
            points = run.points, code = run.code, version = config.RULES_VERSION })
        net.request("POST", config.ONLINE_URL .. "/rest/v1/runs", headers(), body, function()
            leaderboard.fetchOnline(run.mode, true)
        end)
    end
end

-- Check a few downloaded runs each frame (replaying a run takes a moment,
-- so they're spread out to keep the game smooth). Call every frame while
-- the leaderboard is open.
function leaderboard.update()
    local verify = require("verify")
    local budget = 3
    for _, runs in pairs(leaderboard.online) do
        for _, run in ipairs(runs) do
            if budget == 0 then return end
            if run.verified == nil then
                run.verified = verify.check(run)
                budget = budget - 1
            end
        end
    end
end

-- How many downloaded runs are still waiting to be checked.
function leaderboard.unchecked(mode)
    local n = 0
    for _, run in ipairs(leaderboard.online[mode] or {}) do
        if run.verified == nil then n = n + 1 end
    end
    return n
end

-- The runs to show for a board ("online" or "device") and a game type.
-- Online, only runs whose replay checked out are shown.
function leaderboard.list(board, mode)
    local source = board == "online" and (leaderboard.online[mode] or {}) or leaderboard.device
    local out = {}
    for _, run in ipairs(source) do
        if run.mode == mode and (board ~= "online" or run.verified == true) then
            table.insert(out, run)
        end
    end
    return out
end

return leaderboard
