-- profiles.lua
-- LOG IN with a username, and keep that player's STATS (best run, best
-- round, highest level, Mystery Machine spins...). Everything is saved in
-- the game's save folder, so it's remembered next time.
--
-- There are no passwords: a username is just a name to keep stats under.
-- Pure LOGIC/data - nothing in here draws.

local profiles = {}

local FILE = "profiles.txt"

profiles.current = nil   -- the logged-in username, or nil
profiles.all = {}        -- profiles.all[name] = that player's stats

-- Every stat, in the order the STATS screen shows them.
--   key, label, and how it's shown ("number" or "level")
profiles.STATS = {
    { "bestRunPoints",   "Most points in a run" },
    { "bestRoundPoints", "Most points in one round" },
    { "highestLevel",    "Highest level reached" },
    { "highestHard",     "Highest level on HARD" },
    { "wins",            "Runs that beat all 10 levels" },
    { "runs",            "Runs played" },
    { "rounds",          "Rounds played" },
    { "totalPoints",     "Points scored (all time)" },
    { "coinsEarned",     "Coins earned (all time)" },
    { "spins",           "Mystery Machine spins" },
    { "fiveKinds",       "5 of a Kinds rolled" },
    { "bigWins",         "BIG WINs" },
    { "megaWins",        "MEGA WINs" },
    { "luckiestSum",     "Most-scored sum" },
}

-- A blank set of stats for a new player.
local function blankStats()
    local s = { sums = {} }
    for _, stat in ipairs(profiles.STATS) do s[stat[1]] = 0 end
    s.luckiestSum = nil
    return s
end

-- Is this a name we accept? 3-16 letters, numbers or _ .
function profiles.isValidName(name)
    return #name >= 3 and #name <= 16 and name:match("^[%w_]+$") ~= nil
end


---------------------------------------------------------------------------
-- SAVING AND LOADING
---------------------------------------------------------------------------

-- Turn a table into Lua text, so it can be saved and read back.
local function serialize(v, indent)
    if type(v) == "table" then
        local parts = {}
        for k, x in pairs(v) do
            local key = type(k) == "number" and ("[" .. k .. "]") or string.format("[%q]", k)
            table.insert(parts, indent .. "  " .. key .. " = " .. serialize(x, indent .. "  "))
        end
        return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
    elseif type(v) == "string" then
        return string.format("%q", v)
    end
    return tostring(v)
end

function profiles.save()
    love.filesystem.write(FILE, "return " .. serialize({ current = profiles.current, all = profiles.all }, ""))
end

function profiles.load()
    if not love.filesystem.getInfo(FILE) then return end
    local chunk = love.filesystem.load(FILE)
    -- setfenv gives the file an empty world, so it can only build a table.
    local ok, data = pcall(setfenv(chunk, {}))
    if ok and type(data) == "table" then
        profiles.all = data.all or {}
        profiles.current = data.current
        for _, s in pairs(profiles.all) do
            for _, stat in ipairs(profiles.STATS) do
                if s[stat[1]] == nil and stat[1] ~= "luckiestSum" then s[stat[1]] = 0 end
            end
            s.sums = s.sums or {}
        end
    end
end

-- Log in (a new name gets a fresh set of stats).
function profiles.login(name)
    profiles.current = name
    profiles.all[name] = profiles.all[name] or blankStats()
    profiles.save()
end

function profiles.logout()
    profiles.current = nil
    profiles.save()
end

-- The logged-in player's stats, or nil.
function profiles.stats()
    return profiles.current and profiles.all[profiles.current]
end


---------------------------------------------------------------------------
-- RECORDING (game.lua's events call these)
---------------------------------------------------------------------------

-- A round was scored. 'result' is the entry from score.recordRound.
function profiles.recordRound(result, values)
    local s = profiles.stats()
    if not s then return end
    s.rounds = s.rounds + 1
    s.totalPoints = s.totalPoints + result.points
    s.coinsEarned = s.coinsEarned + result.coins + (result.winBonus or 0)
    s.bestRoundPoints = math.max(s.bestRoundPoints, result.points)
    if result.hand == "5 of a Kind" then s.fiveKinds = s.fiveKinds + 1 end
    if (result.winBonus or 0) >= 25 then
        s.megaWins = s.megaWins + 1
    elseif (result.winBonus or 0) > 0 then
        s.bigWins = s.bigWins + 1
    end
    s.sums[result.sum] = (s.sums[result.sum] or 0) + 1
    local best, bestCount = nil, 0
    for sum, count in pairs(s.sums) do
        if count > bestCount then best, bestCount = sum, count end
    end
    s.luckiestSum = best
end

function profiles.recordSpin()
    local s = profiles.stats()
    if s then s.spins = s.spins + 1 end
end

-- A run ended. 'run' = { points, level (highest level reached), won, mode }.
function profiles.recordRun(run)
    local s = profiles.stats()
    if not s then return end
    s.runs = s.runs + 1
    s.bestRunPoints = math.max(s.bestRunPoints, run.points)
    s.highestLevel = math.max(s.highestLevel, run.level)
    if run.mode == "hard" then s.highestHard = math.max(s.highestHard, run.level) end
    if run.won then s.wins = s.wins + 1 end
    profiles.save()
end

return profiles
