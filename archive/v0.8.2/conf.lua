-- conf.lua
-- LÖVE reads this special file BEFORE main.lua, to set up the window.
-- It has to be called exactly "conf.lua" and define love.conf.

function love.conf(t)
    t.window.title = "Para-DICE"

    -- The name of this game's save folder (where settings.txt is kept).
    t.identity = "ParaDice"

    -- In a web browser (the GitHub Pages version), love._os is "Web".
    -- There the game runs in a fixed-size box on the page instead of full
    -- screen. 1366 x 768 is the smallest size the layout was built for.
    if love._os == "Web" then
        t.window.width  = 1366
        t.window.height = 768
        return
    end

    -- On a computer: open as a full screen window.
    -- "desktop" fullscreen uses your monitor's normal resolution
    -- (a borderless window that covers the whole screen), so nothing
    -- gets stretched. Press Escape in-game to quit.
    t.window.fullscreen     = true
    t.window.fullscreentype = "desktop"
end
