-- tools/pips-sim/main.lua
-- Plays N PIPS-mode runs with the bot and prints how far they got.
-- Arguments: N games, first seed.

function love.load(args)
    local N = tonumber(args[1]) or 20
    local seed = tonumber(args[2]) or 1
    local config = require("config")
    if os.getenv("GROWTH") then config.PIPS.GOAL_GROWTH = tonumber(os.getenv("GROWTH")) end
    -- SET="SETS=5 REROLLS=3" changes any number in config.PIPS for this test.
    for k, v in (os.getenv("SET") or ""):gmatch("(%w+)=([%d%.]+)") do config.PIPS[k] = tonumber(v) end
    local bot = require("bot")
    local perkys = require("perkys")
    local wins, levels, reached = 0, 0, {}
    local start = os.clock()
    for g = 1, N do
        local run = bot.play(seed + g - 1)
        local won = run.state == "victory"
        if won then wins = wins + 1 end
        levels = levels + run.level
        reached[run.level] = (reached[run.level] or 0) + 1
        if os.getenv("TRACE") then
            local names = {}
            for _, h in ipairs(run.perkys) do table.insert(names, perkys.get(h.id).name) end
            local dice = {}
            for _, d in ipairs(run.dice) do table.insert(dice, d.kind) end
            print(string.format("game %2d: %s level %d round %d  best set %d  coins %d  dice[%s]  perkys[%s]",
                g, won and "WON " or "lost", run.level, run.round, run.best, run.coins,
                table.concat(dice, ","), table.concat(names, ", ")))
        end
    end
    print(string.format("PIPS: %d games, growth x%.2f: won %d (%.0f%%), average level %.1f  (%.1fs)",
        N, config.PIPS.GOAL_GROWTH, wins, 100 * wins / N, levels / N, os.clock() - start))
    local parts = {}
    for l = 1, config.PIPS.MAX_LEVEL do
        if reached[l] then table.insert(parts, "L" .. l .. ":" .. reached[l]) end
    end
    print("ended on level: " .. table.concat(parts, "  "))
    love.event.quit()
end
