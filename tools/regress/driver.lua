-- Regression driver: plays a fixed, fully deterministic script through the
-- game and saves a screenshot + state dump at every checkpoint.
-- The game's main.lua is copied in as main_game.lua.

-- Fake clock and mouse, so animations depend only on the frame number.
local fakeTime, mx, my = 1000, 683, 384
love.timer.getTime = function() return fakeTime end
love.mouse.getPosition = function() return mx, my end
local function stubSource()
    local s = {}
    function s:getDuration() return 2.5 end
    setmetatable(s, { __index = function() return function() end end })
    return s
end
love.audio.newSource = function() return stubSource() end

love.filesystem.load("main_game.lua")()
local G = { load = love.load, update = love.update, draw = love.draw, kp = love.keypressed,
            mp = love.mousepressed, mm = love.mousemoved, mr = love.mousereleased }
-- Ignore the real mouse / keyboard completely.
love.keypressed, love.mousepressed, love.mousemoved, love.mousereleased = nil, nil, nil, nil
love.keyreleased, love.textinput, love.focus, love.resize = nil, nil, nil, nil

local layout, animation, dice, score, player, luck, shop, markers =
    require("layout"), require("animation"), require("dice"), require("score"),
    require("player"), require("luck"), require("shop"), require("markers")

local shotQueue, shotN, log = {}, 0, {}
local function center(r) return r.x + r.w / 2, r.y + r.h / 2 end

local function dump()
    local held = {}
    for i = 1, 5 do held[i] = dice.held[i] and "H" or "-" end
    return string.format("lvl=%d rnd=%d tot=%d lvlTot=%d coins=%d vals=%s held=%s rr=%d luck=%s mk=%d/%d shopmsg=%s",
        score.level, score.round, score.total, score.levelTotal, player.coins,
        table.concat(dice.values, ","), table.concat(held), dice.rerollsLeft,
        table.concat(luck.held, ","), #markers.placed, markers.owned, tostring(shop.message))
end

-- Script helpers (run inside a coroutine; each yield = one frame).
local function frame() coroutine.yield() end
local function wait(n) for _ = 1, n do frame() end end
local function shot(name)
    shotN = shotN + 1
    table.insert(shotQueue, string.format("%03d_%s", shotN, name))
    frame()
end
local function key(k) G.kp(k); frame() end
local function move(x, y) mx, my = x, y; G.mm(x, y, 0, 0, false); frame() end
local function click(x, y)
    mx, my = x, y; G.mm(x, y, 0, 0, false)
    G.mp(x, y, 1, false); frame()
    G.mr(x, y, 1, false); frame()
end
local function clickR(r) click(center(r)) end
local function settle(prefix, every)
    local n = 0
    while animation.isRolling() and n < 900 do
        if every and n % every == 0 then shot(prefix .. "_f" .. n) else frame() end
        n = n + 1
    end
    wait(2)
end

local script = coroutine.wrap(function()
    wait(3); shot("start")
    key("c"); shot("controls"); key("c")
    key("s"); shot("settings"); key("right"); key("left"); key("left"); shot("settings_vol"); key("escape")
    move(center(require("settingsmenu").tabRect())); shot("hover_settings_tab")
    move(center(require("controlsguide").tabRect())); shot("hover_controls_tab")
    move(center(require("menu").mainButtonRect(1))); shot("hover_play")

    -- TUTORIAL
    key("return"); shot("play_menu"); key("1"); shot("tut_welcome")
    key("return"); shot("tut_points")
    key("return"); shot("tut_money")
    key("return"); shot("tut_marker")
    move(center(layout.placeBox(13))); shot("tut_hover_tile")
    clickR(layout.placeBox(13)); shot("tut_marker_placed")
    clickR(layout.rerollButton()); shot("tut_throw_step")
    key("return")
    settle("tut_roll1", 8)
    shot("tut_scoring")
    for n = 1, 3 do key("return"); shot("tut_next" .. n) end
    key("k"); shot("tut_round1_done")
    key("return"); shot("tut_next_round")
    key("space"); shot("tut_r2_tray")
    key("return"); settle("tut_roll2", 10); shot("tut_hold_step")
    key("1"); key("3"); key("5"); shot("tut_held")
    key("return"); settle("tut_reroll", 10); shot("tut_nice_reroll")
    for n = 1, 3 do key("return"); shot("tut_end" .. n) end
    key("return"); shot("tut_free_play")

    -- Rounds 3-5: Enter (start+throw) then KEEP.
    for r = 3, 5 do
        key("return"); settle("r" .. r, 20); shot("r" .. r .. "_landed")
        key("k"); wait(30); shot("r" .. r .. "_over")
    end
    wait(60); shot("level_end")
    if score.hasPassedLevel() then key("space") else key("return"); wait(2); key("`") end
    wait(2); shot("shop_arrive")
    for n = 1, 4 do key("return"); shot("shop_tut" .. n) end

    -- SHOP
    key("`"); key("`"); key("`"); shot("shop_coins")
    move(center(shop.cardRect("dice", 1))); shot("shop_hover_card")
    clickR(shop.cardRect("dice", 1)); shot("shop_bought_die")
    clickR(shop.cardRect("upgrades", 1)); clickR(shop.cardRect("upgrades", 3)); shot("shop_upgrades")
    clickR(shop.markersRect()); shot("shop_marker")
    clickR(shop.spinButtonRect()); wait(8); shot("shop_spin_early")
    wait(40); shot("shop_spin_mid")
    while shop.machine.spinning do frame() end
    wait(2); shot("shop_spin_done")
    move(center(shop.reelColumnRect(2))); shot("shop_reel_hover")
    clickR(shop.reelColumnRect(2)); shot("shop_prize_taken")
    clickR(shop.luckSellRect(1)); shot("shop_sold")
    clickR(shop.spinButtonRect()); while shop.machine.spinning do frame() end
    shot("shop_spin2")
    clickR(shop.continueRect()); shot("shop_continue_warn")
    clickR(shop.reelColumnRect(1)); shot("shop_take1")
    if #player.inventory > 0 then
        clickR(shop.inventoryRect(1)); shot("shop_inv_selected")
        clickR(shop.slotRect(2)); shot("shop_equipped")
    end
    clickR(shop.slotRect(3)); shot("shop_no_inv_msg")
    key("return"); shot("level2_place")

    -- LEVEL 2: markers, then a hand fling.
    clickR(layout.propCell(4)); clickR(layout.placeBox(1)); shot("l2_markers")
    clickR(layout.keepButton()); shot("l2_cleared")
    clickR(layout.propCell(2)); clickR(layout.placeBox(20)); shot("l2_markers2")
    clickR(layout.rerollButton()); shot("l2_play")
    local f = layout.felt()
    local x, y = f.x + f.w * 0.55, f.y + f.h * 0.75
    mx, my = x, y; G.mm(x, y, 0, 0, false); G.mp(x, y, 1, false); frame()
    for n = 1, 12 do move(x + n * 3, y - n * 2) end
    shot("l2_holding")
    for n = 1, 4 do move(x + 36 + n * 25, y - 24 - n * 30) end
    G.mr(mx, my, 1, false); frame()
    settle("l2_fling", 6); shot("l2_landed")
    move(center(require("luckrack").slotRect(1))); shot("l2_tooltip")
    clickR(layout.traySlot(2)); clickR(layout.traySlot(4)); shot("l2_tray_held")
    -- Drag off a tray die to pick up the rest and throw them.
    local sx, sy = center(layout.traySlot(1))
    mx, my = sx, sy; G.mm(sx, sy, 0, 0, false); G.mp(sx, sy, 1, false); frame()
    for n = 1, 10 do move(sx + n * 8, sy - n * 25) end
    for n = 1, 4 do move(sx + 80 + n * 30, sy - 250 - n * 40) end
    G.mr(mx, my, 1, false); frame()
    settle("l2_reroll", 12); shot("l2_reroll_done")
    clickR(require("luckrack").sellRect(1)); shot("l2_rack_sold")

    -- A rigged MEGA WIN with several luck items held.
    luck.reset(); luck.give("skyHigh"); luck.give("midasDice"); luck.give("pairUp")
    clickR(layout.rerollButton()); wait(2)      -- NEXT ROUND
    dice.rig = { 6, 6, 6, 6, 6 }
    key("return"); settle("mega", 30)
    key("k"); for n = 1, 6 do shot("mega_show" .. n); wait(9) end
    wait(240); shot("mega_after")
    luck.reset(); luck.give("addict"); luck.give("hotStreak"); luck.give("crowdFavourite")
    key("space"); shot("addict_round")
    key("return"); settle("addict", 40); shot("addict_landed")
    key("k"); wait(20); shot("addict_over")

    -- God mode through to the last level and the win.
    for n = 1, 40 do
        if score.level >= score.MAX_LEVEL then break end
        key("`"); wait(2); key("return"); wait(2)
            end
    shot("level10")
    key("`"); wait(30); shot("victory")
    wait(60); shot("victory_later")
    clickR(layout.endButtons("victory")[2].rect); shot("finished")
    clickR(layout.endButtons("finished")[3].rect); shot("back_to_menu")    -- MAIN MENU
    key("return"); key("2"); shot("new_game_place")                          -- PLAY > NORMAL

    -- A plain game played with Enter + KEEP until it ends.
    clickR(layout.placeBox(14)); key("return"); settle("plain1"); key("k"); wait(5)
    for _ = 2, 5 do key("return"); settle("plain"); key("k"); wait(5) end
    wait(30); shot("plain_end")
    -- A rigged losing level: GAME OVER.
    clickR(layout.endButtons("levelClear")[1].rect); wait(2); key("return"); wait(2)
    clickR(layout.placeBox(1)); clickR(layout.rerollButton()); wait(2)
    for r = 1, 5 do
        dice.rig = { 3, 3, 4, 4, 3 }
        key("return"); settle("lose"); key("k"); wait(5)
        if r < 5 then key("space"); wait(2) end
    end
    wait(30); shot("game_over")
    key("return"); shot("after_game_over")
    print("DONE " .. shotN)
    love.event.quit()
end)

function love.load()
    love.math.setRandomSeed(12345)
    require("rng").setSeed(12345)
    math.randomseed(12345)
    G.load()
end

function love.update()
    fakeTime = fakeTime + 1 / 60
    G.update(1 / 60)
    script()
end

function love.draw()
    G.draw()
    if #shotQueue > 0 then
        local name = table.remove(shotQueue, 1)
        table.insert(log, name .. " | " .. dump())
        love.graphics.captureScreenshot(function(img) img:encode("png", "shots/" .. name .. ".png") end)
        love.filesystem.write("log.txt", table.concat(log, "\n") .. "\n")
    end
end
