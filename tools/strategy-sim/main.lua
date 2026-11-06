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
