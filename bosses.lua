-- bosses.lua
-- PIPS MODE: the BOSSES - who they are, what they say, what they look like
-- (as 16-bit pixel pictures) and the dirty tricks they pull. Pure
-- LOGIC/data - bossart.lua draws the pictures.
--
-- WHEN BOSSES APPEAR (chosen at random when a run starts):
--   * after beating one random level out of 2-3,
--   * after one out of 5-7,
--   * after one out of 8-10,
--   * and after level 12.
-- A boss round comes after that level's shop. Its goal is BOSS_GOAL (in
-- config.lua) times the level's last goal, and the boss pulls one random
-- TRICK (below).
-- Then, as "level 13", PIT BOSS JOSH, the final boss.
--
-- PIT BOSS JOSH is different: he copies your whole run (dice, Perkys,
-- augments, craps bets), switches off one random Perky on each side, and
-- plays his own sets against yours, 1 on 1. Highest total wins.

local bosses = {}

-- The bosses you can meet at levels 2-10 (one picked at random each time).
--   art    - which picture: "man", "woman" or "suit" (see bossart.lua)
--   colors - the colours used in the picture
--   lines  - what they might say before the fight (one picked at random)
bosses.LIST = {
    {
        id = "caleb", name = "DICEMAN CALEB", art = "man",
        colors = { hair = { 0.45, 0.26, 0.12 }, shirt = { 0.80, 0.12, 0.15 }, pants = { 0.15, 0.20, 0.45 } },
        lines = {
            "Your luck just ran out, pal. I'm rolling with the big boys now!",
            "I've got snake eyes... and they're watching YOU.",
            "Prepare to be... DICED!",
        },
    },
    {
        id = "chandler", name = "DICEMAN CHANDLER", art = "man",
        colors = { hair = { 0.95, 0.80, 0.35 }, shirt = { 0.12, 0.60, 0.25 }, pants = { 0.25, 0.22, 0.20 } },
        lines = {
            "I eat dice like you for breakfast. With extra syrup.",
            "Roll over, rookie. Literally.",
            "You call that a roll? My grandma rolls harder than that!",
        },
    },
    {
        id = "morgan", name = "DICEWOMAN MORGAN", art = "woman",
        colors = { hair = { 0.75, 0.18, 0.10 }, dress = { 0.55, 0.20, 0.75 } },
        lines = {
            "Honey, the house always wins. And I AM the house.",
            "Pick up your dice, sweetie. I want to watch you cry.",
            "Six sides. Zero chances.",
        },
    },
    {
        id = "evan", name = "DICEMAN EVAN", art = "man",
        colors = { hair = { 0.10, 0.08, 0.08 }, shirt = { 0.15, 0.40, 0.90 }, pants = { 0.12, 0.12, 0.14 } },
        lines = {
            "I'm not a gambler. I'm a SURE THING.",
            "You rolled into the wrong alley, friend.",
            "I loaded these dice with pure, concentrated EVIL.",
        },
    },
}

-- The final boss.
bosses.JOSH = {
    id = "josh", name = "PIT BOSS JOSH", art = "suit",
    colors = { hair = { 0.12, 0.10, 0.09 }, suit = { 0.14, 0.14, 0.18 }, tie = { 0.85, 0.10, 0.12 } },
    lines = {
        "Nice little run you built. Mind if I... borrow it?",
        "Welcome to my floor. Nobody leaves with MY money.",
        "Anything you can roll, I can roll better. In a nicer suit.",
    },
}

-- The tricks a boss can pull (one picked at random for each boss round).
bosses.TRICKS = {
    { id = "stealReroll", about = "STEALS ONE OF YOUR REROLLS this round." },
    { id = "stealSet",    about = "STEALS ONE OF YOUR SETS this round." },
    { id = "stealDie",    about = "STEALS ONE OF YOUR DICE once half your sets are gone." },
    { id = "bigGoal",     about = "THE GOAL IS 3x THE LAST ROUND'S - and steals a set AND a reroll." },
    { id = "oneReroll",   about = "ONLY ONE REROLL PER SET this round." },
    { id = "banSet",      about = "BANS YOUR MOST-SCORED SET: it can't be used this round." },
    { id = "hugeGoal",    about = "THE GOAL IS 5x THE LAST ROUND'S GOAL." },
}
bosses.TRICK_BY_ID = {}
for _, t in ipairs(bosses.TRICKS) do bosses.TRICK_BY_ID[t.id] = t end

bosses.JOSH_ABOUT = "Copies your whole run, switches off one Perky on each side, "
    .. "and rolls against you, 1 on 1. Highest total wins - the house wins ties."

-- What boss trick 'boss' does, in words (the ban trick names the banned set).
function bosses.trickText(boss)
    local text = bosses.TRICK_BY_ID[boss.trick].about
    if boss.trick == "banSet" and boss.banned then
        text = "BANS YOUR MOST-SCORED SET (" .. require("pipshands").get(boss.banned).name:upper()
            .. "): it can't be used this round."
    end
    return text
end

-- Look up a boss by id (any of the four, or "josh").
function bosses.get(id)
    if id == "josh" then return bosses.JOSH end
    for _, b in ipairs(bosses.LIST) do
        if b.id == id then return b end
    end
    return nil
end

return bosses
