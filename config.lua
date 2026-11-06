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
config.TRAY_DIE_SIZE  = 60   -- dice sitting in the tray (bottom-left), in pixels
config.TABLE_DIE_SIZE = 50   -- dice rolling / resting out on the felt
config.TRAY_GAP       = 12   -- space between dice in the tray
config.TRAY_PADDING   = 12   -- wood-to-die space inside the tray

-- Rules
config.MAX_REROLLS = 1   -- how many rerolls you get after each fresh roll

-- Roll animation (visual only - it never changes the real dice values).
config.ROLL_SETTLE_FRAME_TIME    = 0.06   -- seconds for each of the 4 settle frames
config.ROLL_REST_TIME            = 0.9    -- seconds dice sit on the felt after landing
config.ROLL_RETURN_TIME          = 0.35   -- seconds to slide back into the tray

-- Throwing, like a real craps roll: the dice fly through the air, bounce
-- on the felt, slam into the walls (the back wall's rubber pyramids kick
-- them off at odd angles), then roll out and stop.
-- Speeds are in pixels per second.
config.THROW_MIN_SPEED      = 1700  -- even a gentle throw goes at least this fast...
config.THROW_MAX_SPEED      = 4200  -- ...and the hardest throw is capped here
config.THROW_FLICK_BOOST    = 1.6   -- your flick speed is multiplied by this
config.THROW_AUTO_SPEED     = 2900  -- speed of a THROW / REROLL button throw (no dragging)
config.THROW_SPREAD_DEGREES = 10    -- each die flies up to this many degrees off your throw
config.THROW_SPEED_SPREAD   = 0.12  -- and up to 12% faster or slower
config.THROW_RELEASE_HEIGHT = 70    -- how high off the felt your hand lets go
config.THROW_RELEASE_LIFT   = 420   -- how fast the dice rise as you let go (an arc, not a slide)
config.DIE_GRAVITY          = 2600  -- pulls airborne dice down to the felt
config.DIE_FELT_BOUNCE      = 0.42  -- how much of its fall speed a die keeps when it bounces on the felt
config.DIE_BOUNCE_SLOWDOWN  = 0.84  -- each bounce on the felt keeps this much of its forward speed
config.DIE_WALL_BOUNCE      = 0.6   -- 0 = dead stop on a wall, 1 = perfect bounce
config.DIE_ROLL_FRICTION    = 1150  -- how hard the felt slows a rolling die (per second)
config.DIE_ROLL_DRAG        = 0.9   -- extra slowing that's stronger the faster it rolls

-- The tumble pictures are 216x216, with the die body 130 pixels wide
-- in the middle. They're scaled so that body is the die size we want.
config.TUMBLE_FRAME_SIZE = 216
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

-- The game's version, shown small in the bottom-right corner. Bump it
-- (and add a line to CHANGELOG.md) whenever you put out a new version.
config.VERSION = "0.0.2"

-- The ONLINE leaderboard (a free Supabase project - see README.md).
-- Leave these empty and the leaderboard only shows runs from this device.
-- The key is the project's PUBLIC "anon" key, which is safe to share.
config.ONLINE_URL = ""
config.ONLINE_KEY = ""

-- God mode (testing only - see godmode.lua)
config.GOD_MODE_ENABLED = true  -- set to false before you share the game
config.GOD_MODE_COINS   = 100   -- coins given each time god mode is used

return config
