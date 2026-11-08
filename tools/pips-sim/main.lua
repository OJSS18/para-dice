-- tools/pips-sim/main.lua
-- Plays N PIPS-mode runs with the bot and prints how far they got.
-- Arguments: N games, first seed.

function love.load(args)
    local N = tonumber(args[1]) or 20
    local seed = tonumber(args[2]) or 1
    local config = require("config")
    if os.getenv("GROWTH") then config.PIPS.GOAL_GROWTH = tonumber(os.getenv("GROWTH")) end
    -- SET="SETS=5 REROLLS=3" changes any number in config.PIPS for this test.
    for k, v in (os.getenv("SET") or ""):gmatch("([%w_]+)=([%d%.]+)") do config.PIPS[k] = tonumber(v) end
    -- SHOPCHECK=1: open thousands of shops and packs at every level and make
    -- sure nothing for a LOCKED set (one that needs more dice slots than the
    -- run has) is ever offered - no Perkys, no set augments.
    if os.getenv("SHOPCHECK") then
        local pipsgame, pipsshop, perkys, pipshands = require("pipsgame"), require("pipsshop"),
            require("perkys"), require("pipshands")
        local checked, bad = 0, 0
        local function check(item, run, where)
            local hand = nil
            if item.type == "perky" then hand = perkys.get(item.id).hand end
            if item.type == "setAug" then hand = item.hand end
            checked = checked + 1
            if hand and not pipshands.isUnlocked(pipshands.get(hand), run.slots) then
                bad = bad + 1
                print("LOCKED SET OFFERED: " .. where .. " level " .. run.level .. " slots " .. run.slots .. ": " .. (item.id or item.hand))
            end
        end
        for game = 1, 300 do
            local run = pipsgame.new(seed + game)
            for level = 1, config.PIPS.MAX_LEVEL do
                run.level, run.slots = level, pipsgame.slotsFor(level)
                for _ = 1, 3 do
                    pipsshop.open(run)
                    for _, item in ipairs(run.shop.items) do check(item, run, "shop") end
                    for _, packId in ipairs({ "perky", "bigPerky", "rarePerky", "setAug" }) do
                        run.shop.reels = { packId, packId, packId }
                        pipsshop.pickReel(run, 1)
                        for _, opt in ipairs(run.shop.pack.options) do check(opt, run, packId) end
                        run.shop.pack = nil
                    end
                end
            end
        end
        print(string.format("SHOPCHECK: %d offers checked, %d for locked sets", checked, bad))
        love.event.quit()
        return
    end
    local bot = require("bot")
    local perkys = require("perkys")
    local wins, levels, reached, bossDeaths = 0, 0, {}, {}
    local shops, fullShops, everFull, endFull, firstFull = 0, 0, 0, 0, {}
    local trickMet, trickLost = {}, {}
    local start = os.clock()
    for g = 1, N do
        local run = bot.play(seed + g - 1)
        local won = run.state == "victory"
        local st = run.stats or { shops = 0, fullShops = 0 }
        shops, fullShops = shops + st.shops, fullShops + st.fullShops
        if st.firstFull then
            everFull = everFull + 1
            firstFull[st.firstFull] = (firstFull[st.firstFull] or 0) + 1
        end
        if #run.perkys >= require("pipsshop").maxPerkys(run) then endFull = endFull + 1 end
        for _, t in ipairs(st.tricks or {}) do trickMet[t] = (trickMet[t] or 0) + 1 end
        if run.boss and not won and run.state == "gameOver" then
            local t = run.boss.trick or "josh"
            trickLost[t] = (trickLost[t] or 0) + 1
        end
        if run.boss and not won then
            local key = run.boss.josh and "josh" or "boss"
            bossDeaths[key] = (bossDeaths[key] or 0) + 1
        end
        if won then wins = wins + 1 end
        levels = levels + run.level
        reached[run.level] = (reached[run.level] or 0) + 1
        if os.getenv("TRACE") then
            local names = {}
            for _, h in ipairs(run.perkys) do table.insert(names, perkys.get(h.id).name) end
            local dice = {}
            for _, d in ipairs(run.dice) do table.insert(dice, d.kind) end
            local where = run.boss and (" BOSS " .. run.boss.id .. (run.boss.trick and ("/" .. run.boss.trick) or "")) or ""
            local duel = run.josh and string.format(" you %d vs josh %d", run.roundScore, run.josh.total) or ""
            print(string.format("game %2d: %s level %d round %d%s%s  best set %d  coins %d  dice[%s]  perkys[%s]",
                g, won and "WON " or "lost", run.level, run.round, where, duel, run.best, run.coins,
                table.concat(dice, ","), table.concat(names, ", ")))
        end
    end
    print(string.format("PIPS: %d games, growth x%.2f +%.2f/level, first goal %d: won %d (%.0f%%), average level %.1f  (%.1fs)",
        N, config.PIPS.GOAL_GROWTH, config.PIPS.GOAL_STEP, config.PIPS.FIRST_GOAL, wins, 100 * wins / N, levels / N, os.clock() - start))
    local parts = {}
    for l = 1, config.PIPS.MAX_LEVEL + 1 do
        if reached[l] then table.insert(parts, "L" .. l .. ":" .. reached[l]) end
    end
    print("ended on level: " .. table.concat(parts, "  "))
    print(string.format("PERKYS FULL: after %.0f%% of all shop visits; %d of %d runs ever filled every slot; "
        .. "%d runs ended with every slot full", 100 * fullShops / math.max(1, shops), everFull, N, endFull))
    local fl = {}
    for l = 1, 13 do if firstFull[l] then table.insert(fl, "L" .. l .. ":" .. firstFull[l]) end end
    print("first level with every slot full: " .. table.concat(fl, "  "))
    print(string.format("lost to a boss: %d   lost to Pit Boss Josh: %d", bossDeaths.boss or 0, bossDeaths.josh or 0))
    local tp = {}
    for _, t in ipairs({ "stealReroll", "stealSet", "stealDie", "bigGoal", "oneReroll", "banSet", "hugeGoal", "josh" }) do
        if trickMet[t] then
            table.insert(tp, string.format("%s %d/%d lost (%.0f%%)", t, trickLost[t] or 0, trickMet[t],
                100 * (trickLost[t] or 0) / trickMet[t]))
        end
    end
    print("BOSS TRICKS (runs lost / times met): " .. table.concat(tp, ",  "))
    love.event.quit()
end
