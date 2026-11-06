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
--   luck.lua      - luck items: one held at a time; rarities, effects, how long they last
--   boosts.lua    - lasting boosts stuck onto POINTS tiles by luck items
--   upgrades.lua  - shop upgrades: EVEN / ODD / LOWER 13 / UPPER 13 / HOT FOUR
--   markers.lua   - the white chip placed on a tile each level (x1.5)
--   dice.lua      - dice LOGIC: rolling, keeping, rerolling, the sum
--   score.lua     - SCORING: points table, Money Maker coin hands, level targets
--   shop.lua      - the SHOP: stock, buying, swapping dice, and its layout
--   godmode.lua   - testing cheat: ` wins the level / gives coins
--   animation.lua - the tumbling roll that settles onto each die's real face
--   confetti.lua  - the falling confetti on the LEVEL CLEAR screen
--   layout.lua    - WHERE things are on the play screen (banner, rails, felt, tray...)
--   fonts.lua     - every font, loaded once
--   draw.lua      - puts the play screens together (and loads the dice images)
--   crapstable.lua- DRAWING of the table: wood rails, felt, Para-DICE logo, dice tray
--   scoreboard.lua- DRAWING of the lit-up POINTS / COINS betting boxes on the felt
--   banner.lua    - DRAWING of the info banner and buttons on the left
--   ui.lua        - shared drawing helpers: glossy buttons, shadowed text
--   controlsguide.lua - the list of controls shown when you press C
--   music.lua     - the looping background music
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
local ui            = require("ui")
local settings      = require("settings")
local settingsmenu  = require("settingsmenu")
local music         = require("music")

-- true while the controls list (press C) is showing on top of the screen.
local showControls = false

-- true while the settings panel (S, or the SETTINGS tab) is open.
local showSettings = false

-- 'state' tells us which screen we're on. It's just a string:
--   "start"       - the title screen
--   "placeMarker" - start of a level: put your white chip on a tile (or not), then ROLL
--   "play"        - dice are rolled; the player keeps some and rerolls, or KEEPs all
--   "roundOver"   - the round has been scored; Space starts the next one
--   "levelClear"  - all rounds played and the target was reached; confetti!
--   "victory"     - the LAST level was cleared: you beat the game!
--   "gameOver"    - all rounds played and the target was missed
--   "shop"        - between levels: buy dice and luck, swap dice in
local state = "start"

-- Set to true when the round is over but the dice are still animating.
-- love.update waits for the animation to finish, THEN scores the round,
-- so the result never appears before the dice have stopped.
local roundEndPending = false


---------------------------------------------------------------------------
-- GAME FLOW
---------------------------------------------------------------------------
-- These small functions connect the modules together and move between
-- states. They're the "rules of the game".

-- Begin a new round: fresh roll, back to choosing.
-- The real values are rolled first; the animation then tumbles each die
-- and settles it onto that real value.
local function startRound()
    luck.useRoll()          -- a fresh roll counts toward the luck item wearing off
    -- Addict's automatic marker flips between 17 and 18 each round.
    markers.autoSum = luck.autoMarkerSum(score.round + 1)
    dice.rollAll()
    animation.startAll(dice.values, player.loadout)
    state = "play"
end

-- Begin a level:
--   * luck items that only last until a certain level wear off,
--   * "this level only" point boosts come off,
--   * the marker from last level comes off the table,
--   * and the player places a new one before the first roll - unless
--     their luck item doesn't allow it (Addict), then we roll straight away.
local function beginLevel()
    luck.onLevelStart(score.level)
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

-- Start a brand new game from zero.
local function startGame()
    confetti.stop()
    score.reset()
    player.reset()          -- 0 coins, 5 white dice, empty inventory
    boosts.reset()          -- no point boosts
    upgrades.reset()        -- no shop upgrades
    markers.reset()         -- back to one marker
    luck.give(luck.STARTER) -- everyone starts holding "Run it Back"
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
    local result = score.recordRound(dice.values, noReroll)
    player.addCoins(result.coins)   -- coins from a Money Maker hand (0 if none)

    -- The held luck item may stick a lasting boost onto the point just scored.
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

-- Try to reroll every die that isn't kept. Only the rerolled dice animate.
-- If that used up the last reroll, the round ends - but not until the
-- animation has finished (see love.update).
local function tryReroll()
    if not dice.canReroll() or dice.countToReroll() == 0 then
        return
    end
    luck.useRoll()          -- rerolls count toward the luck item too
    local rerolled, which = dice.rerollUnkept()
    if rerolled then
        animation.start(which, dice.values, player.loadout)
        if not dice.canReroll() then
            roundEndPending = true
        end
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

    -- The SETTINGS tab is on every screen; the panels go on top of everything.
    settingsmenu.drawTab()
    controlsguide.drawTab()
    if showSettings then
        settingsmenu.draw()
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

    -- C opens and closes the controls list, from any screen.
    if key == "c" then
        showControls = not showControls
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
        end

    elseif state == "placeMarker" then
        -- Every chip has to be on the table before the level can start.
        if isEnter and markers.allPlaced() then
            startRound()
        end

    elseif state == "play" then
        -- Ignore every key while the dice are rolling.
        if animation.isRolling() then
            return
        end

        if isEnter then
            tryReroll()
        elseif key == "k" then
            tryNoReroll()       -- K = the KEEP button
        else
            -- tonumber turns the text "3" into the number 3.
            -- For keys that aren't numbers (like "a") it gives nil.
            local n = tonumber(key)
            if n and n >= 1 and n <= config.NUM_DICE then
                dice.toggleKeep(n)
            end
        end

    elseif state == "roundOver" then
        if key == "space" then
            startRound()
        end

    elseif state == "levelClear" then
        if key == "space" then
            openShop()
        end

    elseif state == "shop" then
        if isEnter and not shop.machine.spinning then
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

    -- Clicking anywhere closes the controls list (and does nothing else).
    if showControls then
        showControls = false
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

    -- Screens that used to need a key now have a button too, so the whole
    -- game can be played by tapping on a phone.
    if state == "start" then
        if layout.isOnRerollButton(x, y) then
            startGame()                  -- the START button
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

    -- Below here: the play screen. Not while rolling.
    if state ~= "play" or animation.isRolling() then
        return
    end

    -- layout tells us WHAT was clicked; main/dice decide what that DOES.
    local i = layout.getDieAt(x, y)
    if i then
        dice.toggleKeep(i)
    elseif layout.isOnRerollButton(x, y) then
        tryReroll()
    elseif layout.isOnKeepButton(x, y) then
        tryNoReroll()
    end
end

-- The mouse moved (LÖVE calls this every time it does).
-- Used to drag the volume knob in the settings panel.
function love.mousemoved(x, y)
    if showSettings then
        settingsmenu.mousemoved(x)
    end
end

-- A mouse button was let go: stop dragging the volume knob.
function love.mousereleased(x, y, button)
    settingsmenu.mousereleased()
end
