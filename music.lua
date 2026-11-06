-- music.lua
-- The background music: one song, looping forever.
--
-- The file is big (about 30 MB), so it's loaded as a "stream" source:
-- LÖVE reads a little of it at a time while it plays, instead of loading
-- the whole thing into memory first.

local music = {}

local SONG = "assets/music/bonne_soiree.mp3"

local source = nil   -- the playing song (a LÖVE "Source")


-- Start the music (call once from love.load). 'volume' is 0 to 1.
function music.start(volume)
    source = love.audio.newSource(SONG, "stream")
    source:setLooping(true)
    source:setVolume(volume)
    source:play()
end

-- Change how loud the music is: 0 = silent, 1 = full volume.
function music.setVolume(volume)
    if source then
        source:setVolume(volume)
    end
end

-- Is the music playing right now? (handy for testing)
function music.isPlaying()
    return source ~= nil and source:isPlaying()
end

return music
