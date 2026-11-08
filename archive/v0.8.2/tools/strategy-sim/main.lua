-- tools/strategy-sim/main.lua
-- Plays N games with every strategy and prints how far each one gets.
-- Arguments (after the folder): N games per strategy, first seed, and
-- optionally which strategy numbers to run (e.g. 6,10).

function love.load(args)
    local N = tonumber(args[1]) or 200
    local seed = tonumber(args[2]) or 1
    local only = nil
    if args[3] then
        only = {}
        for n in args[3]:gmatch("%d+") do only[tonumber(n)] = true end
    end

    local sim = require("sim")
    local strategies = require("strategies")
    -- HARD SWEEP: try pairs of growth rates, e.g. HARDSWEEP="1.4:1.5 1.35:1.45"
    -- (levels 2-5 : levels 6-10) against the 3 strongest strategies.
    if os.getenv("HARDSWEEP") then
        local early, strategies, score = require("early"), require("strategies"), require("score")
        local function branchOf(parentN, tag)
            for _, b in ipairs(early.branches(early.base[parentN])) do
                if b.name:find(tag, 1, true) then return b end
            end
        end
        local list = { strategies[9], branchOf(14, "Double Down"), branchOf(11, "Show Me The Money") }
        for pair in os.getenv("HARDSWEEP"):gmatch("%S+") do
            local g1, g2 = pair:match("([%d%.]+):([%d%.]+)")
            g1, g2 = tonumber(g1), tonumber(g2)
            local parts = {}
            for _, s in ipairs(list) do
                local wins, reach5 = 0, 0
                for g = 1, N do
                    require("rng").setSeed(seed + g)
                    score.growth, score.lateGrowth = g1, g2
                    local l = sim.playGame(s)
                    if l == 10 then wins = wins + 1 end
                    if l >= 4 then reach5 = reach5 + 1 end
                end
                table.insert(parts, string.format("%s %.1f%% (L5 %.0f%%)", s.name:sub(1, 14), 100 * wins / N, 100 * reach5 / N))
            end
            print("HS	" .. g1 .. " / " .. g2 .. "	" .. table.concat(parts, " | "))
            io.stdout:flush()
        end
        love.event.quit()
        return
    end

    -- HARD TEST: the strongest strategies on HARD's goals.
    if os.getenv("HARDTEST") then
        local early, strategies, score = require("early"), require("strategies"), require("score")
        local function branchOf(parentN, tag)
            for _, b in ipairs(early.branches(early.base[parentN])) do
                if b.name:find(tag, 1, true) then return b end
            end
        end
        local list = { strategies[9], strategies[11], branchOf(11, "Show Me The Money"), branchOf(11, "Double Down"),
            branchOf(14, "Double Down"), branchOf(14, "Even Steven"), branchOf(17, "Show Me The Money"), early.base[13] }
        local levelsHist = {}
        for _, s in ipairs(list) do
            local wins, reach5, total, best = 0, 0, 0, 0
            for g = 1, N do
                require("rng").setSeed(seed + g)
                score.growth, score.lateGrowth = 1.5, 1.62
                local l = sim.playGame(s)
                score.growth, score.lateGrowth = 1.5, 1.62
                total = total + l
                best = math.max(best, l)
                if l == 10 then wins = wins + 1 end
                if l >= 4 then reach5 = reach5 + 1 end
            end
            print(string.format("HARD	%s	win %.1f%%	reach L5 %.0f%%	avg %.2f	best %d", s.name, 100 * wins / N, 100 * reach5 / N, total / N, best))
            io.stdout:flush()
        end
        love.event.quit()
        return
    end

    -- LATE TEST: how hard levels 6-10 should get. For each late growth
    -- value, the strongest strategies play N games; prints their win rates.
    if os.getenv("LATETEST") then
        local early, strategies, score = require("early"), require("strategies"), require("score")
        local list = { strategies[9] }
        local branchOf = function(parentN, tag)
            for _, b in ipairs(early.branches(early.base[parentN])) do
                if b.name:find(tag, 1, true) then return b end
            end
        end
        table.insert(list, branchOf(11, "Show Me The Money"))
        table.insert(list, branchOf(14, "Even Steven"))
        table.insert(list, branchOf(14, "Double Down"))
        for value in os.getenv("LATETEST"):gmatch("[%d%.]+") do
            score.lateGrowth = tonumber(value)
            local parts = {}
            for _, s in ipairs(list) do
                local wins, reach6 = 0, 0
                for g = 1, N do
                    require("rng").setSeed(seed + g)
                    score.lateGrowth = tonumber(value)
                    local l = sim.playGame(s)
                    if l == 10 then wins = wins + 1 end
                    if l >= 5 then reach6 = reach6 + 1 end
                end
                table.insert(parts, string.format("%s=%.0f%%(L6 %.0f%%)", s.name:sub(1, 18), 100 * wins / N, 100 * reach6 / N))
            end
            print("LATE\t" .. value .. "\t" .. table.concat(parts, "  "))
            io.stdout:flush()
        end
        love.event.quit()
        return
    end

    -- EARLY TEST: 20 early-game strategies, then 5 synergy branches for each
    -- one that reaches level 5 at least half the time (see early.lua).
    if os.getenv("EARLYTEST") then
        local early = require("early")
        local function run(s)
            local reach, levels, wins = 0, 0, 0
            for g = 1, N do
                require("rng").setSeed(seed + g)
                local l = sim.playGame(s)
                levels = levels + l
                if l >= 4 then reach = reach + 1 end     -- cleared 1-4: reached level 5
                if l == 10 then wins = wins + 1 end
            end
            return 100 * reach / N, levels / N, 100 * wins / N
        end
        local winners = {}
        -- EARLYPARENTS=11,13 skips the base runs and branches those strategies.
        local parents = os.getenv("EARLYPARENTS")
        if parents then
            for n in parents:gmatch("%d+") do table.insert(winners, early.base[tonumber(n)]) end
        end
        print("BASE STRATEGIES")
        for n, s in ipairs(parents and {} or early.base) do
            local reach, avg, win = run(s)
            print(string.format("BASE\t%d\t%s\t%.0f\t%.2f\t%.0f", n, s.name, reach, avg, win))
            io.stdout:flush()
            if reach >= 50 then table.insert(winners, s) end
        end
        print("SYNERGY BRANCHES (from " .. #winners .. " strategies at 50%+)")
        for _, parent in ipairs(winners) do
            for _, s in ipairs(early.branches(parent)) do
                local reach, avg, win = run(s)
                print(string.format("BRANCH\t%s\t%s\t%.0f\t%.2f\t%.0f", parent.name, s.name, reach, avg, win))
                io.stdout:flush()
            end
        end
        love.event.quit()
        return
    end

    -- PRICE TEST: what each shop purchase is worth, bought before level 1.
    if os.getenv("PRICETEST") then
        local variants = { { "none", {} } }
        for _, t in ipairs({ "red", "blue", "green", "purple", "amber" }) do
            for _, n in ipairs({ 1, 3, 5 }) do
                local list = {}
                for i = 1, n do list[i] = t end
                table.insert(variants, { t .. " x" .. n, { startDice = list } })
            end
        end
        for _, u in ipairs({ "even", "odd", "lower", "upper", "common", "keep" }) do
            table.insert(variants, { u .. " LVL1", { startUpgrades = { [u] = 1 } } })
        end
        table.insert(variants, { "lower LVL2", { startUpgrades = { lower = 2 } } })
        table.insert(variants, { "2 markers", { startMarkers = 2 } })
        table.insert(variants, { "3 markers", { startMarkers = 3 } })
        for _, v in ipairs(variants) do
            local s = { name = v[1], reroll = "ev", coinWeight = 0 }
            for k, x in pairs(v[2]) do s[k] = x end
            local levels, coins, played = 0, 0, 0
            for g = 1, N do
                require("rng").setSeed(seed + g)
                levels = levels + sim.playGame(s)
                coins, played = coins + sim.coinsEarned, played + sim.levelsPlayed
            end
            print(string.format("PRICE	%s	%.3f	%.1f", v[1], levels / N, coins / played))
            io.stdout:flush()
        end
        love.event.quit()
        return
    end

    -- PERK TEST: every luck item held from the start, one at a time.
    if os.getenv("PERKTEST") then
        local luck = require("luck")
        local ids = { "none" }
        for _, id in ipairs(luck.ORDER) do if id ~= luck.STARTER then table.insert(ids, id) end end
        local from = tonumber(os.getenv("PERKFROM") or "1")
        for n, id in ipairs(ids) do
          if n >= from then
            local s = { name = id, reroll = "ev", coinWeight = 0, startLuck = id ~= "none" and { id } or nil }
            local levels, wins = 0, 0
            for g = 1, N do
                require("rng").setSeed(seed + g)
                local l = sim.playGame(s)
                levels = levels + l
                if l == 10 then wins = wins + 1 end
            end
            print(string.format("PERK	%s	%.3f	%.1f", id, levels / N, 100 * wins / N))
            io.stdout:flush()
          end
        end
        love.event.quit()
        return
    end
    print(string.format("%-40s %7s %8s %9s %s", "STRATEGY", "WINS", "AVG LVL", "MEDIAN", "levels cleared: 0 1 2 ... 10"))
    for n, s in ipairs(strategies) do
        if only == nil or only[n] then
            local cleared, total = {}, 0
            for l = 0, 10 do cleared[l] = 0 end
            local list = {}
            for g = 1, N do
                require("rng").setSeed(seed + g)
                local levels = sim.playGame(s)
                if os.getenv("TRACE") then
                    local luck, score = require("luck"), require("score")
                    print(levels, table.concat(luck.held, ","), "total=" .. score.total)
                end
                cleared[levels] = cleared[levels] + 1
                total = total + levels
                list[g] = levels
            end
            table.sort(list)
            local hist = {}
            for l = 0, 10 do hist[#hist + 1] = cleared[l] end
            print(string.format("%-40s %6.1f%% %8.2f %9d   %s", s.name, 100 * cleared[10] / N,
                total / N, list[math.ceil(N / 2)], table.concat(hist, " ")))
            io.stdout:flush()
        end
    end
    love.event.quit()
end
