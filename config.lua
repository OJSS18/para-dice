-- config.lua
-- All the numbers you might want to tweak, in one place.
--
-- HOW MODULES WORK IN LUA:
-- A module is just a file that builds a table and 'return's it at the end.
-- Another file loads it with:   local config = require("config")
-- (no ".lua" on the end). After that, config.NUM_DICE is 5, and so on.
-- Lua only runs each file once, however many times it's required, so
-- every file that requires "config" gets the very same table.

local config = {}

-- Dice
config.NUM_DICE       = 5    -- how many dice we roll
config.TRAY_DIE_SIZE  = 80   -- dice sitting in the tray (bottom-left), in pixels
config.TABLE_DIE_SIZE = 95   -- dice rolling / resting out on the felt
config.TRAY_GAP       = 14   -- space between dice in the tray
config.TRAY_PADDING   = 14   -- wood-to-die space inside the tray

-- Rules
config.MAX_REROLLS = 1   -- how many rerolls you get after each fresh roll

-- Roll animation (visual only - it never changes the real dice values).
-- Each frame stays up a little longer than the last, like a die slowing down.
config.ROLL_FIRST_FRAME_TIME     = 0.025  -- seconds for frame 1
config.ROLL_LAST_SPIN_FRAME_TIME = 0.07   -- seconds for frame 20 (last spin frame)
config.ROLL_SETTLE_FRAME_TIME    = 0.06   -- seconds for each of the 4 settle frames
config.ROLL_REST_TIME            = 0.6    -- seconds dice sit on the felt after landing
config.ROLL_RETURN_TIME          = 0.35   -- seconds to slide back into the tray

-- The tumble pictures are 192x192, with the die body about 130 pixels wide
-- in the middle. They're scaled so that body is the die size we want.
config.TUMBLE_FRAME_SIZE = 192
config.TUMBLE_BODY_SIZE  = 130

-- The craps table
config.BANNER_FRACTION = 0.22  -- the info banner on the left is this share of the screen width...
config.BANNER_MIN_W    = 300   -- ...but never narrower than this
config.BANNER_MAX_W    = 420   -- ...or wider than this
config.RAIL_SIZE       = 46    -- width of the wooden rail's top (cap)
config.TABLE_MARGIN    = 24    -- space between the felt's edges and things on it

-- The camera. 0 would be looking straight down. Tilting it (the viewer
-- stands a bit to the south, looking north) lets you see the inside face
-- of the far (north) wall - its height, lined with rubber pyramids.
config.VIEW_TILT_DEGREES = 30
config.WALL_HEIGHT       = 80  -- how tall the table wall really is, in pixels
                               -- (you only see part of it: height x sin(tilt))

-- Fonts (all free - see assets/fonts)
-- Bungee: bold Vegas-signage letters for buttons, headings and the big score (SIL OFL).
config.DISPLAY_FONT    = "assets/fonts/Bungee-Regular.ttf"
-- Righteous: lively retro font for all the everyday text (SIL OFL).
config.TEXT_FONT       = "assets/fonts/Righteous-Regular.ttf"
-- Limelight: art-deco Vegas marquee style (SIL Open Font License).
config.VEGAS_FONT      = "assets/fonts/Limelight-Regular.ttf"
config.LOGO_FONT_SIZE  = 110
-- Ultra: heavy slab-serif for the big craps-style numbers (Apache licence).
config.NUMBER_FONT     = "assets/fonts/Ultra-Regular.ttf"

-- POINTS: craps "place bet" style boxes, two rows of 13 (sums 5-17, then 18-30)
config.PLACE_PER_ROW   = 13
config.PLACE_BOX_MAX_W = 110   -- each box is at most this wide (narrower on small screens)
config.PLACE_NUMBER_H  = 50    -- the part with the big number
config.PLACE_STRIP_H   = 20    -- the thin strip underneath with the points ("500 PTS")

-- COINS: the "Money Makers" hands, in a panel like a craps table's proposition bets
config.PROP_PANEL_W    = 300
config.PROP_HEADER_H   = 34    -- the red "MONEY MAKERS" title above the cells
config.PROP_CELL_H     = 78    -- 6 hands in 2 columns x 3 rows

-- Vegas bulbs around EVERY box (points and coins)
config.BULB_LANE       = 14    -- width of the strip between boxes where the bulbs sit
config.BULB_SPACING    = 22    -- distance between bulbs
config.BULB_RADIUS     = 5     -- size of each glass bulb
config.BULB_HEIGHT     = 12    -- how far a bulb sticks up off the felt (seen thanks to the tilt)

-- Banner buttons (glossy red REROLL, glossy blue KEEP)
config.BUTTON_H = 56

-- Luck items
config.LUCK_DURATION = 20     -- how many rolls (fresh rolls AND rerolls) a luck item lasts

-- God mode (testing only - see godmode.lua)
config.GOD_MODE_ENABLED = true  -- set to false before you share the game
config.GOD_MODE_COINS   = 100   -- coins given each time god mode is used

return config
