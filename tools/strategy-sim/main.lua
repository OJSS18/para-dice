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
    print(string.format("%-40s %7s %8s %9s %s", "STRATEGY", "WINS", "AVG LVL", "MEDIAN", "levels cleared: 0 1 2 ... 10"))
    for n, s in ipairs(strategies) do
        if only == nil or only[n] then
            local cleared, total = {}, 0
            for l = 0, 10 do cleared[l] = 0 end
            local list = {}
            for g = 1, N do
                love.math.setRandomSeed(seed + g)
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
