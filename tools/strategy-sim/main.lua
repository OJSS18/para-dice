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
