-- main.lua
-- The entry point. LÖVE always starts by running this file.
-- (conf.lua runs even earlier, just to set up the window.)
--
-- How a LÖVE game runs:
--   1. love.load()          runs ONCE when the game starts. Set things up here.
--   2. love.update(dt)      runs every frame. Change the game's data here (logic).
--   3. love.draw()          runs every frame after update. Draw things here (drawing).
--   4. love.keypressed()    runs whenever a key is pressed.
--   5. love.mousepressed()  runs whenever a mouse button is clicked.
--
-- The project is split into files (called "modules"):
--   conf.lua      - window settings (full screen)
--   config.lua    - numbers you can tweak (sizes, rerolls, prices of things...)
--   util.lua      - small shared helpers (rectangles, rounding, weighted random...)
--   rng.lua       - the GAME's seeded random numbers (so runs can be replayed)
--   game.lua      - one RUN: its screens and every action the player can take
--   dicetypes.lua - every kind of die (White, Red, ...) and its odds
--   player.lua    - coins, your 5 dice, your inventory
--   luck.lua      - luck items (perks): up to 3 (4 in endless), rarities and effects
--   luckart.lua   - luck item pictures, SELL buttons and tooltips
--   luckrack.lua  - your luck slots on the play screen (sell from there)
--   tutorial.lua  - the TUTORIAL: spotlights, arrows and steps over a real game
--   boosts.lua    - lasting boosts stuck onto POINTS tiles by luck items
--   upgrades.lua  - shop upgrades: EVEN / ODD / LOWER 13 / UPPER 13 / HOT FOUR
--   markers.lua   - the white chips placed on tiles each level (x1.5)
--   dice.lua      - dice LOGIC: picking dice to throw, rolling, rerolling, the sum
--   score.lua     - SCORING: points table, Money Maker coin hands, level goals
--   shop.lua      - the SHOP: stock, buying, swapping dice, and its layout
--   godmode.lua   - testing cheat: ` wins the level / gives coins
--   animation.lua - THROWING: real physics, dice bounce off walls and each other
--   confetti.lua  - the falling confetti on the LEVEL CLEAR screen
--   layout.lua    - WHERE things are on the play screen (banner, rails, felt, tray...)
--   fonts.lua     - every font, loaded once
--   draw.lua      - puts the play screens together (and loads the dice images)
--   crapstable.lua- DRAWING of the table: wood rails, felt, Para-DICE logo, dice tray
--   scoreboard.lua- DRAWING of the lit-up POINTS / COINS betting boxes on the felt
--   banner.lua    - DRAWING of the info banner and buttons on the left
--   ui.lua        - shared drawing helpers: glossy buttons, shadowed text, bulbs
--   menu.lua      - the MAIN MENU and the PLAY menu (pick a game type)
--   screens.lua   - the text entry, STATS and LEADERBOARD screens
--   profiles.lua  - LOGIN (a username) and each player's stats, saved to disk
--   leaderboard.lua - the best runs, on this device and online
--   replaycode.lua  - turning a run into a shareable REPLAY CODE and back
--   replay.lua    - WATCHING a replay: a bot plays the code's actions back
--   verify.lua    - checks an online leaderboard run is real by replaying its code
--   transition.lua- the sliding SWOOSH between the table and the shop
--   net.lua       - web requests (online leaderboard) and the clipboard
--   json.lua      - reading and writing JSON, the web's text format
--   controlsguide.lua - the list of controls shown when you press C
--   oddsguide.lua - the dice odds panel shown when you press O
--   music.lua     - the looping background music
--   bigwin.lua    - BIG WIN / MEGA WIN: jackpot sound, huge letters, bonus coins
--   settings.lua  - the player's settings (music volume), saved to disk
--   settingsmenu.lua - the SETTINGS tab and panel
--   shopdraw.lua  - DRAWING for the shop
--
-- PIPS MODE (the second game type: pips x mult, Perkys, packs) has its own files:
--   pipsgame.lua  - one PIPS run: rounds, sets, rerolls, and every action
--   pipsdice.lua  - its dice: kinds, dungeon dice (D7-D20) and the 10 colours
--   pipshands.lua - the SETS a roll can make (Pair, Straight...) and their mult
--   pipsscore.lua - scoring: POINTS x MULT, with Perkys and craps bets
--   perkys.lua    - PERKYS, the cards you buy that change scoring
--   augments.lua  - DICE AUGMENTS (a face scores more points) and SET AUGMENTS (a set gets more mult)
--   pipsshop.lua  - its shop: 2 items, the pack slot machine, packs, selling
--   pipsview.lua  - looks only: the electronic dice roll and spinning reels
--   pipslayout.lua- WHERE everything is on its screens
--   pipsdraw.lua  - DRAWING of its play screen, pop-ups and shop
--   pipsinput.lua - its clicks and keys, turned into actions
--   main.lua      - this file: which screen we're on, and turning input
--                   (keys and clicks) into menu steps and game actions
--
-- Logic files never draw, and drawing files never change data.

-- require loads another file and gives back the table it returned.
local config        = require("config")
local game          = require("game")
local dice          = require("dice")
local score         = require("score")
local player        = require("player")
local luckrack      = require("luckrack")
local tutorial      = require("tutorial")
local shop          = require("shop")
local confetti      = require("confetti")
local animation     = require("animation")
local layout        = require("layout")
local draw          = require("draw")
local shopdraw      = require("shopdraw")
local controlsguide = require("controlsguide")
local oddsguide     = require("oddsguide")
local ui            = require("ui")
local fonts         = require("fonts")
local settings      = require("settings")
local settingsmenu  = require("settingsmenu")
local music         = require("music")
local bigwin        = require("bigwin")
local menu          = require("menu")
local screens       = require("screens")
local profiles      = require("profiles")
local leaderboard   = require("leaderboard")
local replaycode    = require("replaycode")
local replay        = require("replay")
local net           = require("net")
local godmode       = require("godmode")
local transition    = require("transition")
local pipsgame      = require("pipsgame")
local pipsview      = require("pipsview")
local pipsdraw      = require("pipsdraw")
local pipsinput     = require("pipsinput")

-- Which screen is showing:
--   "menu"        - the main menu
--   "playMenu"    - pick a game type (tutorial / normal / hard)
--   "game"        - a run is being played (game.state says which part)
--   "pips"        - a PIPS mode run is being played (pipsgame.run.state says which part)
--   "replay"      - watching a replay (game.state again, played by the bot)
--   "entry"       - typing a username or pasting a replay code
--   "stats"       - the logged-in player's stats
--   "leaderboard" - the best runs
local screen = "menu"

-- The panels that can open on top of any screen.
local showControls, showSettings, showOdds = false, false, false

-- The run that just ended: its replay code, and whether COPY was pressed.
local lastRun = { code = nil, copied = false }

-- Where EXIT on a replay goes back to ("menu" or "leaderboard").
local replayReturn = "menu"

-- Escape during a run asks first: pressing it again before this time leaves.
local leaveUntil = 0

-- The mouse went down on a tray die. If it's let go without moving, that
-- holds / lets go of the die; if it's dragged, it picks up the dice to throw.
local pendingPress = nil
local DRAG_DISTANCE = 12   -- pixels the mouse must move before it counts as a drag


-- REARRANGING luck items: press on one and drag it to another slot, or
-- click it (or press L) to pick it and move it with the arrow keys.
local function moveLuck(from, to)
    if to and to ~= from and game.act("moveLuck", from * 10 + to) then
        luckrack.selected = to
        return true
    end
    return false
end

---------------------------------------------------------------------------
-- MOVING BETWEEN SCREENS
---------------------------------------------------------------------------

-- Start a new run of a game type ("tutorial", "normal", "hard" or "pips").
local function startRun(mode)
    leaveUntil = 0
    if mode == "pips" then
        pipsgame.new()
        pipsview.reset()
        screen = "pips"
        return
    end
    game.new(mode)
    luckrack.selected, luckrack.drag = nil, nil
    lastRun = { code = nil, copied = false }
    pendingPress = nil
    leaveUntil = 0
    screen = "game"
end

-- Back to the main menu (a run in progress is left behind).
local function toMenu()
    if replay.active then replay.stop() end
    game.active = false
    pipsgame.active = false
    tutorial.stop()
    animation.stop()
    confetti.stop()
    bigwin.stop()
    screen = "menu"
end

-- Open the text entry screen for a username ("name") or a replay code ("code").
local function openEntry(kind)
    screens.entry = { kind = kind, text = "", message = "" }
    love.keyboard.setTextInput(true)
    screen = "entry"
end

local function openLeaderboard()
    screen = "leaderboard"
    if screens.board.which == "online" then
        leaderboard.fetchOnline(screens.board.mode, true)   -- keeps showing what we have while it loads
    end
end

-- Leave a replay: back to where it was started from.
local function exitReplay()
    toMenu()
    if replayReturn == "leaderboard" then openLeaderboard() end
end

-- Watch a replay from its code. Returns false and a reason if the code is bad.
local function watch(code, returnTo)
    local run, why = replaycode.decode(code)
    if not run then return false, why end
    replayReturn = returnTo or "menu"
    replay.start(run)
    screen = "replay"
    return true
end

-- OK on the text entry screen.
local function submitEntry()
    local e = screens.entry
    local text = e.text:gsub("^%s+", ""):gsub("%s+$", "")
    if e.kind == "name" then
        if not profiles.isValidName(text) then
            e.message = "Use 3 to 16 letters, numbers or _ (no spaces)."
            return
        end
        profiles.login(text)
        love.keyboard.setTextInput(false)
        screen = "menu"
    else
        local ok, why = watch(text, "menu")
        if ok then
            love.keyboard.setTextInput(false)
        else
            e.message = why
        end
    end
end

local function pasteIntoEntry()
    local prompt = screens.entry.kind == "name" and "Type a username:" or "Paste the replay code:"
    net.paste(prompt, function(text)
        if screen == "entry" then
            screens.entry.text = screens.entry.text .. text:gsub("[\r\n]", "")
        end
    end)
end


---------------------------------------------------------------------------
-- STATS AND THE LEADERBOARD (game.lua tells us what happened)
---------------------------------------------------------------------------

-- Does this run count for stats? Not replays, the tutorial or god mode.
local function counts()
    return screen == "game" and not replay.active and game.mode ~= "tutorial" and not game.unranked
end

game.events.round = function(result)
    if counts() then profiles.recordRound(result) end
end

game.events.spin = function()
    if counts() then profiles.recordSpin() end
end

game.events.runEnd = function()
    if replay.active or game.verifying then return end
    lastRun.code = game.isReplayable()
        and replaycode.encode(game.mode, game.seed, game.log, score.level, score.total) or nil
    if screen ~= "game" or game.mode == "tutorial" then return end
    -- Every finished run goes on the leaderboard straight away: under your
    -- username, or as "Guest" if you're not logged in. God mode runs are
    -- marked, and only kept on this device (not the online board).
    leaderboard.submit({ name = profiles.current or "Guest", mode = game.mode, level = score.level,
        points = score.total, code = lastRun.code, god = game.unranked or nil })
    if counts() then
        local won = score.level > score.MAX_LEVEL or game.state == "finished"
        profiles.recordRun({ points = score.total, level = score.level, won = won, mode = game.mode })
    end
end


---------------------------------------------------------------------------
-- LÖVE CALLBACKS (LÖVE calls these for us automatically)
---------------------------------------------------------------------------

function love.load()
    love.graphics.setBackgroundColor(0.05, 0.3, 0.15)
    draw.load()                        -- the fonts and the dice pictures
    bigwin.load(config.DISPLAY_FONT)   -- the jackpot sound and its big letters
    dice.rollAll()                     -- fill the dice so they're never empty
    settings.load()                    -- remembered settings (if any)
    profiles.load()                    -- who's logged in, and everyone's stats
    leaderboard.load()                 -- the runs saved on this device
    transition.load()                  -- make the swoosh sounds
    music.start(settings.values.musicVolume)
end

local function inRun()
    return screen == "game" or screen == "replay"
end

-- While the leaderboard is open, check the online board for new runs
-- every so often, so other players' runs pop up by themselves.
local refreshTimer = 0
local REFRESH_EVERY = 20   -- seconds

function love.update(dt)
    net.update()
    transition.update(dt)
    transition.setVolume(settings.values.musicVolume)
    if screen == "leaderboard" then
        leaderboard.update()   -- check downloaded runs are real (see verify.lua)
    end
    if screen == "leaderboard" and screens.board.which == "online" then
        refreshTimer = refreshTimer + dt
        if refreshTimer >= REFRESH_EVERY and leaderboard.onlineStatus ~= "loading" then
            refreshTimer = 0
            leaderboard.fetchOnline(screens.board.mode, true)
        end
    end
    -- A replay can run faster or slower; the animations follow its speed.
    local speed = replay.active and replay.speed() or 1
    if replay.active and replay.paused then speed = 0 end
    animation.update(dt * speed)
    confetti.update(dt)
    bigwin.update(dt * speed)
    luckrack.update(dt)
    tutorial.update(screen == "game" and game.state or "start")
    if inRun() then
        game.update(dt * speed)
    end
    replay.update(dt)
    if screen == "pips" then pipsview.update(dt) end
end

-- Do what pipsinput.lua says the player asked for in a PIPS run.
local function pipsDo(action, arg)
    if action == "again" then
        startRun("pips")
    elseif action == "menu" then
        toMenu()
    elseif action == "leave" then
        -- MENU during a run: press it twice (the first press warns).
        if love.timer.getTime() < leaveUntil then toMenu() else leaveUntil = love.timer.getTime() + 2.5 end
    elseif action then
        pipsgame.act(action, arg)
    end
end

-- Was the shop showing last frame? (A change starts a slide.)
local wasInShop = nil

-- The screen itself (everything that slides during a transition).
local function drawScene()
    if screen == "menu" then
        menu.drawMain()
    elseif screen == "playMenu" then
        menu.drawPlay()
    elseif screen == "entry" then
        screens.drawEntry()
    elseif screen == "stats" then
        screens.drawStats()
    elseif screen == "leaderboard" then
        screens.drawBoard()
    elseif screen == "pips" then
        pipsdraw.screen()
        if love.timer.getTime() < leaveUntil then
            ui.text("Press again to leave this run (it won't be saved)", fonts.heading,
                0, love.graphics.getHeight() - 40, love.graphics.getWidth(), "center", { 1, 0.4, 0.35 }, true)
        end
    else
        local s = game.state
        if game.onTable() then
            draw.playScreen(s)
        elseif s == "shop" then
            shopdraw.screen()
        else
            draw.endScreen(s, { code = lastRun.code, copied = lastRun.copied, buttons = screen == "game" })
        end
        luckrack.drawDragged()   -- a luck item being dragged, under the mouse
        bigwin.draw()       -- BIG WIN / MEGA WIN letters, over whatever is showing
        tutorial.draw()     -- the tutorial's spotlight, arrow and words (if running)
        replay.draw()       -- the replay controls (if watching one)
        if love.timer.getTime() < leaveUntil then
            ui.text("Press Esc again to leave this run (it won't be saved)", fonts.heading,
                0, 90, love.graphics.getWidth(), "center", { 1, 0.4, 0.35 }, true)
        end
    end
end

function love.draw()
    -- Going into the shop, or coming back out to the table: slide + swoosh.
    -- (Only within a run - not when a new run starts or you leave to the menu.)
    local inShop = inRun() and game.state == "shop"
    if not inRun() then
        wasInShop = nil
    elseif wasInShop ~= nil and inShop ~= wasInShop then
        transition.start(inShop)
    end
    if inRun() then wasInShop = inShop end
    transition.draw(drawScene)

    -- The version number, small, in the bottom-right corner.
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    ui.text("v" .. config.VERSION, fonts.hint, W - 110, H - 20, 100, "right", { 1, 1, 1, 0.35 })

    -- The tabs are on the game screens; the panels go on top of everything.
    if inRun() then
        settingsmenu.drawTab()
        controlsguide.drawTab()
        oddsguide.drawTab()
    end
    if showSettings then settingsmenu.draw() end
    if showOdds then oddsguide.draw() end
    if showControls then controlsguide.draw() end
end

-- Typed letters (only used on the text entry screen).
function love.textinput(t)
    if screen ~= "entry" then return end
    local e = screens.entry
    local allowed = e.kind == "name" and "[%w_]" or "[%w%-_%.]"
    local limit = e.kind == "name" and 16 or 8000
    for c in t:gmatch(allowed) do
        if #e.text < limit then e.text = e.text .. c end
    end
end

-- The keys for each part of a run (game.state). Each turns into an action.
local function runKey(key)
    local isEnter = (key == "return" or key == "kpenter")
    local s = game.state
    if s == "placeMarker" then
        -- Enter skips the throwing part: it starts the round AND throws.
        if isEnter then game.act("roll", 1) end
    elseif s == "play" then
        if animation.isRolling() or animation.isHolding() then return end
        if isEnter then
            game.act("throw")            -- the THROW / REROLL button
        elseif key == "k" then
            game.act("keep")             -- K = the KEEP button
        elseif key == "a" then
            game.act("holdAll")          -- A = hold all (again = let them all go)
        else
            local n = tonumber(key)      -- 1-5 = hold / let go of that die
            if n and n >= 1 and n <= config.NUM_DICE then game.act("hold", n) end
        end
    elseif s == "roundOver" then
        if key == "space" then
            game.act("nextRound", 0)     -- dice back in the tray, ready to fling
        elseif isEnter then
            game.act("nextRound", 1)     -- skip the fling: throw all 5 straight away
        end
    elseif s == "levelClear" then
        if key == "space" or isEnter then game.act("openShop") end
    elseif s == "shop" then
        if isEnter then game.act("continue") end
    elseif s == "victory" then
        if isEnter then game.act("endless") elseif key == "f" then game.act("finish") end
    elseif s == "gameOver" or s == "finished" then
        if isEnter then startRun(game.mode) elseif key == "m" then toMenu() end
    end
end

function love.keypressed(key)
    ui.touchMode = false   -- a key was pressed, so hints talk about keys again

    -- While SETTINGS is open: left/right change the volume, S or Escape closes it.
    if showSettings then
        if key == "left" then
            settings.changeMusicVolume(-0.05)
        elseif key == "right" then
            settings.changeMusicVolume(0.05)
        elseif key == "s" or key == "escape" then
            showSettings = false
        end
        return
    end

    -- Typing a name or code: every key goes to the text box.
    if screen == "entry" then
        local e = screens.entry
        if key == "backspace" then
            e.text = e.text:sub(1, -2)
        elseif key == "return" or key == "kpenter" then
            submitEntry()
        elseif key == "escape" then
            love.keyboard.setTextInput(false)
            screen = "menu"
        elseif key == "v" and love.keyboard.isDown("lctrl", "rctrl", "lgui", "rgui") then
            pasteIntoEntry()
        end
        return
    end

    -- Escape during a run: press it twice to leave (the first press warns).
    if screen == "game" and key == "escape" and not (showOdds or showControls) then
        if not game.active or love.timer.getTime() < leaveUntil then
            toMenu()
        else
            leaveUntil = love.timer.getTime() + 2.5
        end
        return
    end

    -- Escape during a PIPS run: the same, press it twice to leave.
    if screen == "pips" and key == "escape" and pipsview.godPrompt then
        pipsview.godPrompt = false   -- Escape answers "no" to the god mode question
        return
    end
    if screen == "pips" and key == "escape" and not (showOdds or showControls) then
        if not pipsgame.active then toMenu() else pipsDo("leave") end
        return
    end

    -- While the tutorial is showing a "read this" step, it takes the keys.
    if screen == "game" and tutorial.keypressed(key) then return end

    -- C and O open and close the controls list and the dice odds.
    if key == "c" then
        showControls, showOdds = not showControls, false
        return
    end
    if key == "o" and inRun() then
        showOdds, showControls = not showOdds, false
        return
    end
    if showOdds or showControls then
        if key == "escape" then showOdds, showControls = false, false end
        return
    end
    if key == "s" then
        showSettings = true
        return
    end

    if screen == "menu" then
        if key == "return" or key == "kpenter" or key == "p" then
            screen = "playMenu"
        elseif key == "r" then
            openEntry("code")
        elseif key == "l" then
            openLeaderboard()
        elseif key == "escape" and love.system.getOS() ~= "Web" then
            love.event.quit()   -- (in a browser, "quitting" would just freeze the page)
        end
    elseif screen == "playMenu" then
        local n = tonumber(key)
        if n and menu.GAME_TYPES[n] then
            startRun(menu.GAME_TYPES[n].id)
        elseif key == "escape" then
            screen = "menu"
        end
    elseif screen == "stats" or screen == "leaderboard" then
        if key == "escape" then screen = "menu" end
    elseif screen == "pips" then
        pipsDo(pipsinput.key(key))
    elseif screen == "replay" then
        if key == "space" then replay.togglePause()
        elseif key == "left" then replay.rewind()
        elseif key == "right" then replay.forward()
        elseif key == "up" then replay.faster()
        elseif key == "down" then replay.slower()
        elseif key == "escape" then exitReplay() end
    elseif screen == "game" then
        -- L picks the next luck item; the arrows move the picked one.
        if (game.onTable() or game.state == "shop") and require("luck").held[1] then
            local luck = require("luck")
            if key == "l" then
                local k = (luckrack.selected or 0) + 1
                luckrack.selected = (k <= #luck.held) and k or nil
                return
            end
            local sel = luckrack.selected
            if sel and luck.held[sel] then
                if key == "left" or key == "up" then moveLuck(sel, sel - 1); return end
                if key == "right" or key == "down" then moveLuck(sel, sel + 1); return end
            end
        end
        if godmode.isTrigger(key) then
            game.act("god")
            return
        end
        runKey(key)
    end
end

-- Pick up every die that's about to be thrown, into a handful under the mouse.
local function grabDice(x, y)
    if dice.canThrow() then
        animation.grab(game.diceToThrow(), player.loadout, x, y)
    end
end

-- A click during a run (screen "game").
local function runClick(x, y)
    local s = game.state

    -- The luck rack (right of the tray): SELL a luck item, or press on one
    -- to drag it, any time the dice aren't flying.
    if game.onTable() and not animation.isRolling() and not animation.isHolding() then
        local hit = luckrack.click(x, y)
        if type(hit) == "number" then
            game.act("sellRack", hit)
            luckrack.selected = nil
            return
        end
        local k = luckrack.slotAt(x, y)
        if k then
            luckrack.drag = { from = k, startX = x, startY = y, x = x, y = y, moved = false }
            return
        end
        if hit then return end
    end

    -- The tutorial's NEXT / SKIP buttons (and, on a "read this" step, it
    -- swallows every other click).
    if tutorial.mousepressed(x, y) then return end

    -- The end-of-level and end-of-run screens.
    if s == "levelClear" or s == "victory" or s == "gameOver" or s == "finished" then
        local id = layout.endButtonAt(s, x, y)
        if id == "shop" then game.act("openShop")
        elseif id == "endless" then game.act("endless")
        elseif id == "finish" then game.act("finish")
        elseif id == "copy" and lastRun.code then
            net.copy(lastRun.code)
            lastRun.copied = true
        elseif id == "again" then startRun(game.mode)
        elseif id == "menu" then toMenu() end
        return
    end

    if s == "shop" then
        -- A luck item's row (not its SELL button): start dragging it.
        local k = shop.luckRowAt(x, y)
        if k then
            luckrack.drag = { from = k, startX = x, startY = y, x = x, y = y, moved = false }
            return
        end
        -- shop.lua says WHAT was clicked; game.act does it (and records it).
        local action, arg = shop.click(x, y)
        if action then game.act(action, arg) end
        if action == "sellShop" then luckrack.selected = nil end
        return
    end

    if s == "roundOver" then
        if layout.isOnRerollButton(x, y) then game.act("nextRound", 0) end   -- NEXT ROUND
        return
    end

    -- Placing markers: click a tile to put a chip there (or pick it up);
    -- ROLL starts the level once every chip is placed; CLEAR CHIPS takes
    -- them all back off. (Coin tiles are numbered after the 26 points tiles.)
    if s == "placeMarker" then
        local kind, k = layout.getTileAt(x, y)
        if kind then
            game.act("marker", kind == "points" and k or 26 + k)
        elseif layout.isOnRerollButton(x, y) then
            game.act("roll", 0)
        elseif layout.isOnKeepButton(x, y) then
            game.act("clearMarkers")
        end
        return
    end

    -- The play screen. Not while dice are out on the felt.
    if s ~= "play" or animation.isRolling() or animation.isHolding() then return end
    local i = layout.getDieAt(x, y)
    if i then
        -- Wait and see: a click holds it, a drag picks up the dice (love.mousemoved).
        pendingPress = { i = i, x = x, y = y }
    elseif layout.isOnRerollButton(x, y) then
        game.act("throw")
    elseif layout.isOnKeepButton(x, y) then
        game.act("keep")
    elseif layout.isInside(x, y, layout.felt()) then
        grabDice(x, y)   -- pressing on the felt picks up the dice into your hand
    end
end

-- x, y = where the mouse was clicked; button 1 = left. 'istouch' is true
-- when the "click" was really a finger (LÖVE turns taps into clicks).
function love.mousepressed(x, y, button, istouch)
    if button ~= 1 then return end
    if transition.isActive() then return end   -- wait for the slide to finish
    ui.touchMode = istouch == true

    -- Clicking anywhere closes the controls list or the odds panel.
    if showControls or showOdds then
        showControls, showOdds = false, false
        return
    end
    -- The settings panel handles its own clicks while it's open.
    if showSettings then
        if settingsmenu.mousepressed(x, y) == "close" then showSettings = false end
        return
    end
    -- The tabs along the top, on the game screens.
    if inRun() then
        if settingsmenu.isOnTab(x, y) then showSettings = true; return end
        if controlsguide.isOnTab(x, y) then showControls = true; return end
        if oddsguide.isOnTab(x, y) then showOdds = true; return end
    end

    if screen == "menu" then
        local id = menu.mainButtonAt(x, y)
        if id == "play" then
            screen = "playMenu"
        elseif id == "replay" then
            openEntry("code")
        elseif id == "settings" then
            showSettings = true
        elseif id == "login" then
            if profiles.current then screen = "stats" else openEntry("name") end
        elseif id == "leaderboard" then
            openLeaderboard()
        end
    elseif screen == "playMenu" then
        local id = menu.typeAt(x, y)
        if id then
            startRun(id)
        elseif layout.isInside(x, y, menu.backRect()) then
            screen = "menu"
        end
    elseif screen == "entry" then
        local id = screens.entryButtonAt(x, y)
        if id == "ok" then
            submitEntry()
        elseif id == "paste" then
            pasteIntoEntry()
        elseif id == "cancel" then
            love.keyboard.setTextInput(false)
            screen = "menu"
        end
    elseif screen == "stats" then
        local id = screens.statsButtonAt(x, y)
        if id == "logout" then profiles.logout() end
        if id then screen = "menu" end
    elseif screen == "leaderboard" then
        local what, value = screens.boardClick(x, y)
        if what == "tab" then
            if value == "online" or value == "device" then
                screens.board.which = value
            else
                screens.board.mode = value
            end
            openLeaderboard()
        elseif what == "watch" then
            watch(value.code, "leaderboard")
        elseif what == "back" then
            screen = "menu"
        end
    elseif screen == "replay" then
        local id = replay.buttonAt(x, y)
        if id == "restart" then replay.restart()
        elseif id == "rewind" then replay.rewind()
        elseif id == "pause" then replay.togglePause()
        elseif id == "forward" then replay.forward()
        elseif id == "speed" then replay.cycleSpeed()
        elseif id == "exit" then exitReplay() end
    elseif screen == "game" then
        runClick(x, y)
    elseif screen == "pips" then
        pipsDo(pipsinput.click(x, y))
    end
end

-- The mouse moved: drag the volume knob, or carry the dice in your hand.
function love.mousemoved(x, y)
    if showSettings then
        settingsmenu.mousemoved(x)
        return
    end
    -- Dragging a luck item: it follows the mouse once it's moved a little.
    local d = luckrack.drag
    if d then
        d.x, d.y = x, y
        if (x - d.startX) ^ 2 + (y - d.startY) ^ 2 > 8 * 8 then d.moved = true end
        return
    end
    -- Dragging off a tray die picks up the whole handful about to be thrown.
    if pendingPress then
        local dx, dy = x - pendingPress.x, y - pendingPress.y
        if dx * dx + dy * dy > DRAG_DISTANCE * DRAG_DISTANCE then
            pendingPress = nil
            grabDice(x, y)
        end
    end
    animation.moveHold(x, y)   -- does nothing if no dice are held
end

-- A mouse button was let go: stop dragging the volume knob, let go of the
-- dice (THROW!), or finish a click on a tray die (HOLD it).
function love.mousereleased(x, y, button)
    settingsmenu.mousereleased()
    if button ~= 1 then return end
    -- Letting go of a luck item: drop it on the nearest slot - or, if it
    -- never moved, that was a click: pick it (again = un-pick).
    local d = luckrack.drag
    if d then
        luckrack.drag = nil
        if screen ~= "game" then return end
        if d.moved then
            local to = game.state == "shop" and shop.luckDropRowAt(y) or luckrack.dropSlotAt(x)
            if not moveLuck(d.from, to) then luckrack.selected = nil end
        else
            luckrack.selected = (luckrack.selected ~= d.from) and d.from or nil
        end
        return
    end
    if pendingPress then
        if screen == "game" and game.state == "play" then
            game.act("hold", pendingPress.i)
        end
        pendingPress = nil
    end
    if animation.isHolding() then
        if screen == "game" and game.state == "play" then
            game.act("throw", 1)
        else
            animation.cancelHold()
        end
    end
end
