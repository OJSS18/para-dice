-- settings.lua
-- The player's SETTINGS, and saving them so they're remembered next time.
--
-- Right now there's one setting: music volume. Add more fields to
-- settings.values (and to save/load below) as the game grows.
--
-- WHERE IS IT SAVED? love.filesystem.write saves into LÖVE's "save
-- directory" for this game (on Windows, inside %APPDATA%\LOVE\...). A game
-- can only write files there, never into its own folder.
--
-- Pure LOGIC/data - nothing in here draws. (settingsmenu.lua draws the panel.)

local music = require("music")
local util  = require("util")

local settings = {}

local FILE = "settings.txt"

-- The current settings, with their starting values.
settings.values = {
    musicVolume = 0.5,   -- 0 = silent, 1 = full volume
}


-- Keep a number between 0 and 1.
local function clamp01(v)
    return util.clamp(v, 0, 1)
end

-- Change the music volume (0 to 1), apply it right away, and save it.
function settings.setMusicVolume(v)
    -- Round to whole percent, so 0.5000001 is just 0.5.
    settings.values.musicVolume = math.floor(clamp01(v) * 100 + 0.5) / 100
    music.setVolume(settings.values.musicVolume)
    settings.save()
end

-- Nudge the volume up or down by 'amount' (e.g. 0.05 = 5%).
function settings.changeMusicVolume(amount)
    settings.setMusicVolume(settings.values.musicVolume + amount)
end

-- Save to the settings file, one "name=value" per line.
function settings.save()
    local text = "musicVolume=" .. settings.values.musicVolume .. "\n"
    love.filesystem.write(FILE, text)
end

-- Load from the settings file (if there is one).
function settings.load()
    if not love.filesystem.getInfo(FILE) then
        return   -- first time playing: keep the starting values
    end
    -- love.filesystem.lines reads a file one line at a time.
    for line in love.filesystem.lines(FILE) do
        -- line:match pulls out the two parts of "name=value".
        local name, value = line:match("^(%w+)=(.+)$")
        if name == "musicVolume" and tonumber(value) then
            settings.values.musicVolume = clamp01(tonumber(value))
        end
    end
end

return settings
