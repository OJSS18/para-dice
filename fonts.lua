-- fonts.lua
-- Every font in the game, made once and shared by all the drawing files.
-- Call fonts.load() once from love.load, then use e.g. fonts.text.
--
--   Bungee     - bold signage: buttons, headings, the big score
--   Righteous  - lively retro: all the everyday text
--   Limelight  - art-deco Vegas: the Para-DICE logo, LEVEL CLEAR / GAME OVER
--   Ultra      - heavy slab-serif: the big craps numbers on the felt

local config = require("config")

local fonts = {}

function fonts.load()
    local display = config.DISPLAY_FONT
    local text    = config.TEXT_FONT

    -- Bungee
    fonts.title    = love.graphics.newFont(display, 48)
    fonts.scoreBig = love.graphics.newFont(display, 44)
    fonts.button   = love.graphics.newFont(display, 24)
    fonts.heading  = love.graphics.newFont(display, 18)
    fonts.hint     = love.graphics.newFont(display, 13)

    -- Righteous
    fonts.text  = love.graphics.newFont(text, 22)
    fonts.small = love.graphics.newFont(text, 17)
    fonts.tiny  = love.graphics.newFont(text, 13)   -- the small white payout text on the felt

    -- Limelight, the Vegas marquee font
    fonts.logo    = love.graphics.newFont(config.VEGAS_FONT, config.LOGO_FONT_SIZE)
    fonts.logoBig = love.graphics.newFont(config.VEGAS_FONT, 150)   -- the main menu

    -- Ultra, the heavy craps-table numbers
    fonts.number    = love.graphics.newFont(config.NUMBER_FONT, 34)
    fonts.propTitle = love.graphics.newFont(config.NUMBER_FONT, 20)
end

return fonts
