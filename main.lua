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
--   dicetypes.lua - every kind of die (White, Red, ...) and its odds
--   player.lua    - coins, your 5 dice, your inventory
--   luck.lua      - luck items (perks): up to 3, permanent until sold; rarities and effects
--   luckart.lua   - luck item pictures, SELL buttons and tooltips
--   luckrack.lua  - your 3 luck slots on the play screen (sell from there)
--   tutorial.lua  - START WITH TUTORIAL: spotlights, arrows and steps over a real game
--   boosts.lua    - lasting boosts stuck onto POINTS tiles by luck items
--   upgrades.lua  - shop upgrades: EVEN / ODD / LOWER 13 / UPPER 13 / HOT FOUR
--   markers.lua   - the white chip placed on a tile each level (x1.5)
--   dice.lua      - dice LOGIC: picking dice to throw, rolling, rerolling, the sum
--   score.lua     - SCORING: points table, Money Maker coin hands, level targets
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
--   ui.lua        - shared drawing helpers: glossy buttons, shadowed text
--   controlsguide.lua - the list of controls shown when you press C
--   oddsguide.lua - the dice odds panel shown when you press O
--   music.lua     - the looping background music
--   bigwin.lua    - BIG WIN / MEGA WIN: jackpot sound, huge letters, bonus coins
--   settings.lua  - the player's settings (music volume), saved to disk
--   settingsmenu.lua - the SETTINGS tab and panel
--   shopdraw.lua  - DRAWING for the shop
--   main.lua      - this file: which screen we're on, and turning input
--                   (keys and clicks) into calls to the other modules
--
-- Logic files never draw, and drawing files never change data.

-- require loads another file and gives back the table it returned.
local config    = require("config")
local dice      = require("dice")
local score     = require("score")
local player    = require("player")
local luck      = require("luck")
local luckrack  = require("luckrack")
local tutorial  = require("tutorial")
local markers   = require("markers")
local boosts    = require("boosts")
local upgrades  = require("upgrades")
local shop      = require("shop")
local godmode   = require("godmode")
local confetti  = require("confetti")
local animation = require("animation")
local layout    = require("layout")
local draw      = require("draw")
local shopdraw  = require("shopdraw")
local controlsguide = require("controlsguide")
local oddsguide     = require("oddsguide")
local ui            = require("ui")
local fonts         = require("fonts")
local settings      = require("settings")
local settingsmenu  = require("settingsmenu")
local music         = require("music")
local bigwin        = require("bigwin")

-- true while the controls list (press C) is showing on top of the screen.
local showControls = false

-- true while the settings panel (S, or the SETTINGS tab) is open.
local showSettings = false

-- true while the dice odds panel (O, or the ODDS tab) is open.
local showOdds = false

-- 'state' tells us which screen we're on. It's just a string:
--   "start"       - the title screen
--   "placeMarker" - start of a level: put your white chip on a tile (or not), then ROLL
--   "play"        - the player throws the dice (1-5 at a time), then can
--                   reroll some of them, or KEEP all 5
--   "roundOver"   - the round has been scored; Space starts the next one
--   "levelClear"  - all rounds played and the target was reached; confetti!
--   "victory"     - the LAST level was cleared: you beat the game!
--   "gameOver"    - all rounds played and the target was missed
--   "shop"        - between levels: buy dice and upgrades, spin for luck, swap dice in
local state = "start"

-- Set to true when the round is over but the dice are still animating.
-- love.update waits for the animation to finish, THEN scores the round,
-- so the result never appears before the dice have stopped.
local roundEndPending = false

-- The mouse went down on a tray die. If it's let go without moving, that
-- holds / lets go of the die; if it's dragged, it picks up the dice to throw.
-- { i = which die, x, y = where the press started }, or nil.
local pendingPress = nil
local DRAG_DISTANCE = 12   -- pixels the mouse must move before it counts as a drag


---------------------------------------------------------------------------
-- GAME FLOW
---------------------------------------------------------------------------
-- These small functions connect the modules together and move between
-- states. They're the "rules of the game".

-- Begin a new round: all 5 dice back in the tray, waiting to be thrown.
local function startRound()
    -- Addict's automatic marker flips between 17 and 18 each round.
    markers.autoSum = luck.autoMarkerSum(score.round + 1)
    dice.newRound()
    pendingPress = nil
    state = "play"
end

-- Begin a level:
--   * "this level only" point boosts come off,
--   * the marker from last level comes off the table,
--   * and the player places a new one before the first roll - unless
--     their luck item doesn't allow it (Addict), then we roll straight away.
local function beginLevel()
    boosts.clearLevel()
    markers.clear()
    markers.autoSum = nil
    if luck.blocksMarker() then
        startRound()
    else
        state = "placeMarker"
    end
end

-- Click a tile while placing markers: put a marker there, or pick it back up.
local function placeMarkerAt(kind, k)
    if kind == "points" then
        markers.toggle("points", score.sumBoxes()[k].sum)
    else
        markers.toggle("coins", score.COIN_HANDS[k].id)
    end
end

-- Start a brand new game from zero. 'withTutorial' = true runs the tutorial
-- over it (START WITH TUTORIAL on the title screen).
local function startGame(withTutorial)
    if withTutorial then
        tutorial.start()
    else
        tutorial.stop()
    end
    confetti.stop()
    bigwin.stop()
    score.reset()
    player.reset()          -- 0 coins, 5 white dice, empty inventory
    boosts.reset()          -- no point boosts
    upgrades.reset()        -- no shop upgrades
    markers.reset()         -- back to one marker
    luck.reset()            -- no luck items...
    luck.give(luck.STARTER) -- ...except "Run it Back", which everyone starts with
    beginLevel()
end

-- Go to the shop (after clearing a level).
local function openShop()
    confetti.stop()
    shop.open(score.level + 1)   -- fresh stock every visit, for the level coming up
    state = "shop"
end

-- Leave the shop and start the next level.
-- The level score resets to 0; the game total, coins and dice are kept.
local function startNextLevel()
    score.startNextLevel()
    beginLevel()
end

-- The dice are final: score them, pay any coins, then decide what's next.
-- 'noReroll' is true if the player chose No Reroll (earns the points bonus).
local function finishRound(noReroll)
    local result = score.recordRound(dice.values, noReroll, dice.hasRerolled(), dice.firstSum)
    player.addCoins(result.coins)   -- coins from a Money Maker hand and luck items (0 if none)

    -- A huge round (40% / 75% of the level goal in one go) is a BIG / MEGA WIN,
    -- which pays bonus coins on top.
    -- (Jackpot Magnet lowers those thresholds.)
    result.winBonus = bigwin.check(result.points, score.getTarget(), luck.bigWinShares())
    if result.winBonus > 0 then
        player.addCoins(result.winBonus)
        score.levelCoins = score.levelCoins + result.winBonus
    end

    -- The held luck items may stick a lasting boost onto the point just scored.
    -- (This happens AFTER scoring, so the boost counts from the next time.)
    luck.onPointScored(result.sum)

    -- Unlock Token: one token for each level beaten while holding it.
    if score.isLevelOver() and score.hasPassedLevel() and luck.givesUnlockTokens() then
        player.unlockTokens = player.unlockTokens + 1
    end

    if not score.isLevelOver() then
        -- More rounds to go in this level.
        state = "roundOver"
    elseif score.hasPassedLevel() and score.isFinalLevel() then
        -- The last level is cleared: the whole game is won!
        state = "victory"
        confetti.start()
    elseif score.hasPassedLevel() then
        -- Last round done, and the target was reached: celebrate.
        state = "levelClear"
        confetti.start()
    else
        -- Last round done, and the target was missed.
        state = "gameOver"
    end
end

-- The list of dice the next throw will send, e.g. {1, 3, 4}
-- (all 5 on the first throw, then every die that isn't held).
local function diceToThrow()
    local list = {}
    for i = 1, config.NUM_DICE do
        if dice.willThrow(i) then
            table.insert(list, i)
        end
    end
    return list
end

-- Throw the dice (all 5, or the ones not held). 'how' is "hand" (letting go of the handful held
-- under the mouse) or "auto" (THROW / REROLL button, or Enter).
-- The real results are decided first (in dice.lua); the physics then
-- sends the dice across the table and each settles onto its result.
-- Once all 5 are out, a throw is a REROLL. If that used up the last
-- reroll, the round ends - but not until the dice have stopped (see love.update).
local function throwDice(how)
    if not dice.canThrow() then
        animation.cancelHold()
        return
    end
    local isReroll = dice.nextThrowIsReroll()
    local thrown, which = dice.throw()
    if not thrown then
        animation.cancelHold()
        return
    end
    if how == "hand" then
        animation.release(dice.values)
    else
        animation.autoThrow(which, dice.values, player.loadout)
    end
    if isReroll and not dice.canReroll() then
        roundEndPending = true
    end
end

-- Start a round and throw all 5 dice at once, skipping the (just for
-- fun) part where you fling them yourself. Enter does this, so keyboard
-- players can hotkey straight through a round.
local function startRoundAndThrow()
    startRound()
    throwDice("auto")
end

-- Pick up every die that's about to be thrown into a handful under the mouse at (x, y).
local function grabDice(x, y)
    if dice.canThrow() then
        animation.grab(diceToThrow(), player.loadout, x, y)
    end
end

-- KEEP (all): keep all the dice as they are and end the round.
-- (In the code this is still called "no reroll", because that's what it is.)
-- The points bonus only counts if the player hasn't rerolled anything.
local function tryNoReroll()
    -- Check BEFORE calling dice.noReroll(), because it sets rerollsLeft
    -- to 0, which would make it look like the player had rerolled.
    local earnedBonus = not dice.hasRerolled()

    if dice.noReroll() then
        finishRound(earnedBonus)
    end
end

-- GOD MODE (testing): what the ` key does depends on the screen.
local function useGodMode()
    if state == "placeMarker" or state == "play" or state == "roundOver" then
        -- Stop anything half-finished and force the win.
        animation.stop()
        roundEndPending = false
        godmode.winLevel()
        if score.isFinalLevel() then
            state = "victory"           -- that was the last level
            confetti.start()
        else
            openShop()
        end
    elseif state == "levelClear" then
        openShop()              -- already won; just skip ahead
    elseif state == "shop" then
        godmode.giveCoins()     -- more money to test buying
        shop.message = "God mode: +" .. config.GOD_MODE_COINS .. " coins."
    end
end


---------------------------------------------------------------------------
-- LÖVE CALLBACKS (LÖVE calls these for us automatically)
---------------------------------------------------------------------------

function love.load()
    -- A dark green background, like a casino table.
    love.graphics.setBackgroundColor(0.05, 0.3, 0.15)

    draw.load()      -- make the fonts and load the dice images
    bigwin.load(config.DISPLAY_FONT)   -- the jackpot sound and its big letters
    dice.rollAll()   -- fill the dice so they're never empty

    settings.load()                            -- remembered settings (if any)
    music.start(settings.values.musicVolume)   -- start the looping music
end

function love.update(dt)
    -- 'dt' (delta time) is how many seconds passed since the last frame.
    -- Anything that moves over time is updated here.
    -- (If nothing is animating, these do nothing.)
    animation.update(dt)
    confetti.update(dt)
    bigwin.update(dt)
    luckrack.update(dt)
    tutorial.update(state)  -- moves the tutorial on once you've done what it asked
    if state == "shop" then
        shop.update(dt)     -- the Mystery Machine's reel
    end

    -- The round ended while dice were rolling. Once they've all stopped,
    -- score it. The flag is cleared first so this only happens once.
    if roundEndPending and not animation.isRolling() then
        roundEndPending = false
        finishRound(false)   -- false = no No Reroll bonus (they rerolled)
    end
end

function love.draw()
    -- Look at the state and draw the matching screen.
    if state == "start" then
        draw.startScreen()
    elseif state == "placeMarker" or state == "play" or state == "roundOver" then
        draw.playScreen(state)
    elseif state == "levelClear" then
        draw.levelClearScreen(state)
    elseif state == "victory" then
        draw.victoryScreen(state)
    elseif state == "gameOver" then
        draw.gameOverScreen(state)
    elseif state == "shop" then
        shopdraw.screen()
    end

    -- BIG WIN / MEGA WIN letters, over whatever screen is showing.
    bigwin.draw()

    -- The tutorial's spotlight, arrow and words (only while it's running).
    tutorial.draw()

    -- The version number, small, in the bottom-right corner.
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    ui.text("v" .. config.VERSION, fonts.hint, W - 110, H - 20, 100, "right", { 1, 1, 1, 0.35 })

    -- The SETTINGS tab is on every screen; the panels go on top of everything.
    settingsmenu.drawTab()
    controlsguide.drawTab()
    oddsguide.drawTab()
    if showSettings then
        settingsmenu.draw()
    end
    if showOdds then
        oddsguide.draw()
    end
    if showControls then
        controlsguide.draw()
    end
end

function love.keypressed(key)
    ui.touchMode = false   -- a key was pressed, so hints talk about keys again

    -- While SETTINGS is open: left/right change the volume, S or Escape
    -- closes it, and every other key is ignored.
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

    -- While the tutorial is showing a "read this" step, it takes the keys
    -- (Enter / Space = NEXT) and the game underneath ignores them.
    if tutorial.keypressed(key) then
        return
    end

    -- C opens and closes the controls list, from any screen.
    if key == "c" then
        showControls = not showControls
        showOdds = false
        return
    end

    -- O opens and closes the dice odds panel, from any screen.
    if key == "o" then
        showOdds = not showOdds
        showControls = false
        return
    end

    -- While the odds panel is open, Escape closes it and other keys are ignored.
    if showOdds then
        if key == "escape" then
            showOdds = false
        end
        return
    end

    -- S opens the settings (unless the controls list is open).
    if key == "s" and not showControls then
        showSettings = true
        return
    end

    -- While the list is open, Escape closes it and every other key is ignored.
    if showControls then
        if key == "escape" then
            showControls = false
        end
        return
    end

    -- Escape quits from any screen - except in a web browser, where
    -- "quitting" would just freeze the page.
    if key == "escape" then
        if love.system.getOS() ~= "Web" then
            love.event.quit()
        end
        return
    end

    -- God mode works from any screen it makes sense on.
    if godmode.isTrigger(key) then
        useGodMode()
        return
    end

    -- "return" is the main Enter key; "kpenter" is the number-pad Enter.
    local isEnter = (key == "return" or key == "kpenter")

    -- What a key does depends on which screen we're on.
    if state == "start" then
        if isEnter then
            startGame()
        elseif key == "t" then
            startGame(true)     -- T = START WITH TUTORIAL
        end

    elseif state == "placeMarker" then
        -- Every chip has to be on the table before the level can start.
        -- Enter skips the throwing part: it starts the round AND throws.
        if isEnter and markers.allPlaced() then
            startRoundAndThrow()
        end

    elseif state == "play" then
        -- Ignore every key while the dice are rolling.
        if animation.isRolling() or animation.isHolding() then
            return
        end

        if isEnter then
            throwDice("auto")   -- the THROW / REROLL button
        elseif key == "k" then
            tryNoReroll()       -- K = the KEEP button
        elseif key == "a" then
            dice.holdAll()      -- A = hold all (again = let them all go)
        else
            -- tonumber turns the text "3" into the number 3.
            -- For keys that aren't numbers (like "a") it gives nil.
            local n = tonumber(key)
            if n and n >= 1 and n <= config.NUM_DICE then
                dice.toggleHold(n)  -- 1-5 = hold / let go of that die
            end
        end

    elseif state == "roundOver" then
        if key == "space" then
            startRound()            -- dice back in the tray, ready to fling
        elseif isEnter then
            startRoundAndThrow()    -- skip the fling: throw all 5 straight away
        end

    elseif state == "levelClear" then
        if key == "space" then
            openShop()
        end

    elseif state == "shop" then
        if isEnter and shop.tryContinue() == "continue" then
            startNextLevel()
        end

    elseif state == "gameOver" or state == "victory" then
        if isEnter then
            startGame()   -- start over from level 1
        end
    end
end

-- x, y   = where the mouse was clicked
-- button = which mouse button (1 = left, 2 = right, 3 = middle)
-- 'istouch' is true when the "click" was really a finger on a touch screen
-- (LÖVE turns taps into mouse clicks for us, so tapping just works).
function love.mousepressed(x, y, button, istouch)
    if button ~= 1 then
        return   -- only the left button does anything
    end

    -- Remember whether the player is using touch, so hints can say "tap".
    ui.touchMode = istouch == true

    -- Clicking anywhere closes the controls list or the odds panel
    -- (and does nothing else).
    if showControls or showOdds then
        showControls = false
        showOdds = false
        return
    end

    -- The settings panel handles its own clicks while it's open.
    if showSettings then
        if settingsmenu.mousepressed(x, y) == "close" then
            showSettings = false
        end
        return
    end

    -- The SETTINGS and CONTROLS tabs, on every screen.
    if settingsmenu.isOnTab(x, y) then
        showSettings = true
        return
    end
    if controlsguide.isOnTab(x, y) then
        showControls = true
        return
    end
    if oddsguide.isOnTab(x, y) then
        showOdds = true
        return
    end

    -- The luck rack (right of the tray): SELL a luck item any time the
    -- dice aren't flying.
    if (state == "placeMarker" or state == "play" or state == "roundOver")
        and not animation.isRolling() and not animation.isHolding()
        and luckrack.click(x, y) then
        return
    end

    -- Screens that used to need a key now have a button too, so the whole
    -- game can be played by tapping on a phone.
    -- The tutorial's NEXT / SKIP buttons (and, on a "read this" step, it
    -- swallows every other click).
    if tutorial.mousepressed(x, y) then
        return
    end

    if state == "start" then
        if layout.isOnRerollButton(x, y) then
            startGame()                  -- the START button
        elseif layout.isOnKeepButton(x, y) then
            startGame(true)              -- START WITH TUTORIAL
        end
        return
    elseif state == "roundOver" then
        if layout.isOnRerollButton(x, y) then
            startRound()                 -- the NEXT ROUND button
        end
        return
    elseif state == "levelClear" then
        if layout.isInside(x, y, layout.overlayButton()) then
            openShop()                   -- VISIT THE SHOP
        end
        return
    elseif state == "gameOver" or state == "victory" then
        if layout.isInside(x, y, layout.overlayButton()) then
            startGame()                  -- PLAY AGAIN
        end
        return
    end

    if state == "shop" then
        -- shop.lua handles buying and swapping itself; it only tells us
        -- when Continue was clicked, because changing screens is main's job.
        if shop.click(x, y) == "continue" then
            startNextLevel()
        end
        return
    end

    -- Placing markers: click a tile to put a chip there (or pick it up);
    -- ROLL starts the level once every chip is placed; the blue button
    -- takes all the chips back off.
    if state == "placeMarker" then
        local kind, k = layout.getTileAt(x, y)
        if kind then
            placeMarkerAt(kind, k)
        elseif layout.isOnRerollButton(x, y) and markers.allPlaced() then
            startRound()        -- ROLL only works once every chip is placed
        elseif layout.isOnKeepButton(x, y) then
            markers.clear()
        end
        return
    end

    -- Below here: the play screen. Not while dice are out on the felt.
    if state ~= "play" or animation.isRolling() or animation.isHolding() then
        return
    end

    -- layout tells us WHAT was clicked; main/dice decide what that DOES.
    local i = layout.getDieAt(x, y)
    if i then
        -- Wait and see: a click picks it, a drag picks it up (love.mousemoved).
        pendingPress = { i = i, x = x, y = y }
    elseif layout.isOnRerollButton(x, y) then
        throwDice("auto")
    elseif layout.isOnKeepButton(x, y) then
        tryNoReroll()
    elseif layout.isInside(x, y, layout.felt()) then
        -- Pressing on the felt picks up the picked dice into your hand.
        grabDice(x, y)
    end
end

-- The mouse moved (LÖVE calls this every time it does).
-- Used to drag the volume knob in the settings panel, and to carry the
-- dice in your hand.
function love.mousemoved(x, y)
    if showSettings then
        settingsmenu.mousemoved(x)
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

-- A mouse button was let go: stop dragging the volume knob, or let go of
-- the dice (THROW!), or finish a click on a tray die.
function love.mousereleased(x, y, button)
    settingsmenu.mousereleased()
    if button ~= 1 then
        return
    end

    if pendingPress then
        if state == "play" then
            dice.toggleHold(pendingPress.i)   -- a click holds / lets go of the die
        end
        pendingPress = nil
    end

    if animation.isHolding() then
        if state == "play" then
            throwDice("hand")
        else
            animation.cancelHold()
        end
    end
end
