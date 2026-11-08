-- pipsdraw.lua
-- PIPS MODE: all the DRAWING - the play screen, the pop-ups, the shop and
-- its packs. Drawing only: nothing here changes the run's data.
-- (Where things go is in pipslayout.lua.)
--
-- THE DICE are drawn by code, not from pictures, so a die and its pips
-- can be any of the 10 colours in pipsdice.COLORS, and faces 7-10 (for
-- dungeon dice) work too.

local config     = require("config")
local fonts      = require("fonts")
local ui         = require("ui")
local util       = require("util")
local pipsgame   = require("pipsgame")
local pipsdice   = require("pipsdice")
local pipshands  = require("pipshands")
local pipsshop   = require("pipsshop")
local augments   = require("augments")
local perkys     = require("perkys")
local pipsview   = require("pipsview")
local pipslayout = require("pipslayout")
local bosses     = require("bosses")
local bossart    = require("bossart")

local pipsdraw = {}

local P = config.PIPS
local GOLD   = { 1, 0.82, 0.3 }
local WHITE  = { 1, 1, 1 }
local CREAM  = { 1, 0.95, 0.88 }
local DIM    = { 1, 1, 1, 0.6 }
local RED    = { 0.92, 0.18, 0.18 }
local BLUE   = { 0.20, 0.50, 1.00 }
local GREEN  = { 0.30, 0.95, 0.40 }

-- Blend two colours (t = 0 gives a, 1 gives b).
local function mix(a, b, t)
    return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end

-- Wrapped text (several lines) in a box 'w' wide.
local function wrapped(text, font, x, y, w, color, align)
    love.graphics.setFont(font)
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.printf(text, x + 1, y + 2, w, align or "center")
    love.graphics.setColor(color)
    love.graphics.printf(text, x, y, w, align or "center")
end


---------------------------------------------------------------------------
-- BACKGROUNDS
---------------------------------------------------------------------------

local feltTile = nil

-- A dark green felt with tiny specks, inside a wooden rail.
local function drawFelt()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    if not feltTile then
        local data = love.image.newImageData(256, 256)
        data:mapPixel(function()
            local speck = 0.90 + love.math.random() * 0.14
            return 0.04 * speck, 0.30 * speck, 0.16 * speck, 1
        end)
        feltTile = love.graphics.newImage(data)
        feltTile:setWrap("repeat", "repeat")
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(feltTile, love.graphics.newQuad(0, 0, W, H, 256, 256), 0, 0)
    for i = 0, 30 do
        love.graphics.setColor(0, 0.02, 0, 0.03 + 0.03 * (30 - i) / 30)
        love.graphics.setLineWidth(6)
        love.graphics.rectangle("line", i * 5, i * 5, W - i * 10, H - i * 10)
    end
    love.graphics.setColor(0.33, 0.18, 0.08)
    love.graphics.setLineWidth(14)
    love.graphics.rectangle("line", 7, 7, W - 14, H - 14, 16, 16)
    love.graphics.setColor(0.55, 0.32, 0.14)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 2, 2, W - 4, H - 4, 20, 20)
    love.graphics.setLineWidth(1)
end

-- Deep red casino carpet with a faint gold diamond pattern (the shop).
local function drawCarpet()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    for i = 0, H, 4 do
        local t = i / H
        love.graphics.setColor(0.24 - 0.14 * t, 0.03, 0.06 - 0.02 * t)
        love.graphics.rectangle("fill", 0, i, W, 4)
    end
    love.graphics.setColor(1, 0.8, 0.3, 0.05)
    love.graphics.setLineWidth(2)
    for x = -H, W, 60 do
        love.graphics.line(x, 0, x + H, H)
        love.graphics.line(x + H, 0, x, H)
    end
    love.graphics.setLineWidth(1)
end


---------------------------------------------------------------------------
-- DICE
---------------------------------------------------------------------------

-- Where the pips go for each face, on a 0-1 square (0.5, 0.5 = middle).
local L, M, R = 0.25, 0.5, 0.75
local PIPS = {
    [1]  = { { M, M } },
    [2]  = { { L, L }, { R, R } },
    [3]  = { { L, L }, { M, M }, { R, R } },
    [4]  = { { L, L }, { R, L }, { L, R }, { R, R } },
    [5]  = { { L, L }, { R, L }, { M, M }, { L, R }, { R, R } },
    [6]  = { { L, L }, { R, L }, { L, M }, { R, M }, { L, R }, { R, R } },
    [7]  = { { L, L }, { R, L }, { L, M }, { M, M }, { R, M }, { L, R }, { R, R } },
    [8]  = { { L, L }, { M, L }, { R, L }, { L, M }, { R, M }, { L, R }, { M, R }, { R, R } },
    [9]  = { { L, L }, { M, L }, { R, L }, { L, M }, { M, M }, { R, M }, { L, R }, { M, R }, { R, R } },
    [10] = { { L, 0.2 }, { L, 0.4 }, { L, 0.6 }, { L, 0.8 }, { M, 0.33 }, { M, 0.67 },
             { R, 0.2 }, { R, 0.4 }, { R, 0.6 }, { R, 0.8 } },
}

-- Draw die 'die' showing 'face' in the square (x, y, size).
--   lit - 0 to 1: how bright its electronic glow is (while rolling / held)
function pipsdraw.die(die, face, x, y, s, lit)
    lit = lit or 0
    local body = pipsdice.COLORS[die.body].rgb
    local pip = pipsdice.COLORS[die.pip].rgb
    local radius = s * 0.18
    -- Glow behind it.
    if lit > 0 then
        love.graphics.setColor(pip[1], pip[2], pip[3], 0.35 * lit)
        love.graphics.rectangle("fill", x - 6, y - 6, s + 12, s + 12, radius + 6, radius + 6)
    end
    -- Shadow, then the body: a lighter top half and a darker rim, so it looks rounded.
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", x + 3, y + 5, s, s, radius, radius)
    love.graphics.setColor(mix(body, { 0, 0, 0 }, 0.35))
    love.graphics.rectangle("fill", x, y, s, s, radius, radius)
    love.graphics.setColor(body)
    love.graphics.rectangle("fill", x + s * 0.04, y + s * 0.03, s * 0.92, s * 0.9, radius * 0.9, radius * 0.9)
    love.graphics.setColor(1, 1, 1, 0.18)
    love.graphics.rectangle("fill", x + s * 0.1, y + s * 0.06, s * 0.8, s * 0.3, radius * 0.6, radius * 0.6)
    -- Dungeon dice get a gold rim and their name in the corner.
    local info = pipsdice.info(die)
    if info.dungeon then
        love.graphics.setColor(GOLD)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x + 2, y + 2, s - 4, s - 4, radius, radius)
        love.graphics.setLineWidth(1)
    end
    -- The pips. Faces with lots of pips use smaller ones.
    local pr = s * (face <= 6 and 0.085 or 0.07)
    for _, p in ipairs(PIPS[face] or PIPS[1]) do
        local px, py = x + p[1] * s, y + p[2] * s
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.circle("fill", px, py + 1, pr)
        love.graphics.setColor(mix(pip, { 1, 1, 1 }, 0.25 * lit))
        love.graphics.circle("fill", px, py, pr)
    end
    if info.dungeon and s >= 60 then
        love.graphics.setFont(fonts.tiny)
        love.graphics.setColor(GOLD)
        love.graphics.print(info.name, x + s - fonts.tiny:getWidth(info.name) - 5, y + s - 16)
    end
end


---------------------------------------------------------------------------
-- PERKY AND ITEM CARDS
---------------------------------------------------------------------------

-- The text a held Perky shows: what it does, plus how much it has grown.
local function perkyAbout(p, held)
    local text = p.about
    if held and p.grows then text = text .. "  (Now +" .. held.gained .. " MULT)" end
    return text
end

-- A card's frame: dark, with a coloured border.
local function cardBox(r, color, dimmed)
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", r.x + 3, r.y + 5, r.w, r.h, 10, 10)
    love.graphics.setColor(0.08, 0.05, 0.09, dimmed and 0.6 or 0.95)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 10, 10)
    love.graphics.setColor(color[1], color[2], color[3], dimmed and 0.35 or 1)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 10, 10)
    love.graphics.setLineWidth(1)
    if not dimmed and ui.isHovered(r) then
        love.graphics.setColor(color[1], color[2], color[3], 0.12)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 10, 10)
    end
end

-- A Perky card. 'held' is the held Perky's table (for growth), or nil.
function pipsdraw.perkyCard(r, id, held, dimmed)
    local p = perkys.get(id)
    local color = perkys.RARITIES[p.rarity].color
    cardBox(r, color, dimmed)
    ui.text(perkys.RARITIES[p.rarity].label, fonts.hint, r.x, r.y + 8, r.w, "center", color)
    ui.text(p.name, fonts.small, r.x + 6, r.y + 26, r.w - 12, "center", WHITE)
    wrapped(perkyAbout(p, held), fonts.tiny, r.x + 8, r.y + 52, r.w - 16, CREAM)
end

-- Any shop thing: a Perky, an augment, a die or a craps bet.
--   price - drawn at the bottom if given;  sold - greyed out with SOLD;  faded - just greyed out
local function itemCard(r, item, price, sold, faded)
    local dim = sold or faded
    if item.type == "perky" then
        pipsdraw.perkyCard(r, item.id, nil, dim)
    elseif item.type == "die" then
        local info = pipsdice.info(item.die)
        cardBox(r, info.dungeon and GOLD or { 0.9, 0.9, 0.9 }, dim)
        ui.text(info.dungeon and "DUNGEON DIE" or "DIE", fonts.hint, r.x, r.y + 8, r.w, "center", GOLD)
        ui.text(info.name, fonts.small, r.x + 6, r.y + 26, r.w - 12, "center", WHITE)
        local s = math.min(70, r.w - 40)
        pipsdraw.die(item.die, pipsdice.maxFace(item.die), r.x + (r.w - s) / 2, r.y + 56, s, 0)
        wrapped(info.about, fonts.tiny, r.x + 8, r.y + 64 + s, r.w - 16, CREAM)
        wrapped("Faces: " .. table.concat(item.die.faces, " "), fonts.tiny, r.x + 8, r.y + 104 + s, r.w - 16, DIM)
    elseif item.type == "bet" then
        cardBox(r, { 1, 0.55, 0.15 }, dim)
        ui.text("CRAPS BET", fonts.hint, r.x, r.y + 8, r.w, "center", { 1, 0.55, 0.15 })
        local box = util.rect(r.x + (r.w - 90) / 2, r.y + 40, 90, 70)
        love.graphics.setColor(0.04, 0.32, 0.16)
        love.graphics.rectangle("fill", box.x, box.y, box.w, box.h, 8, 8)
        love.graphics.setColor(WHITE)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", box.x, box.y, box.w, box.h, 8, 8)
        love.graphics.setLineWidth(1)
        ui.text(tostring(item.number), fonts.number, box.x, box.y + 14, box.w, "center", WHITE)
        wrapped("If your pips add up to exactly " .. item.number .. ": x" .. P.CRAPS_XMULT .. " MULT.",
            fonts.tiny, r.x + 8, r.y + 126, r.w - 16, CREAM)
    else
        -- An augment.
        local isDice = item.type == "diceAug"
        local color = isDice and { 0.3, 0.85, 1 } or { 1, 0.45, 0.85 }
        cardBox(r, color, dim)
        ui.text(isDice and "DICE AUGMENT" or "SET AUGMENT", fonts.hint, r.x, r.y + 8, r.w, "center", color)
        if isDice then
            ui.text(item.name, fonts.small, r.x + 6, r.y + 26, r.w - 12, "center", WHITE)
            local s = 56
            pipsdraw.die({ kind = "classic", body = 1, pip = 2, faces = {} }, item.face,
                r.x + (r.w - s) / 2, r.y + 56, s, 0)
        else
            ui.text(item.name, fonts.small, r.x + 6, r.y + 26, r.w - 12, "center", WHITE)
            ui.text("MULT+", fonts.number, r.x, r.y + 60, r.w, "center", color)
        end
        wrapped(pipsshop.itemAbout(item, pipsgame.run), fonts.tiny, r.x + 8, r.y + 124, r.w - 16, CREAM)
    end
    if sold then
        ui.text("SOLD", fonts.title, r.x, r.y + r.h / 2 - 26, r.w, "center", { 1, 0.3, 0.3 }, true)
    elseif price then
        local tag = util.rect(r.x + (r.w - 90) / 2, r.y + r.h - 40, 90, 30)
        local canPay = pipsgame.run.coins >= price
        love.graphics.setColor(canPay and { 0.75, 0.55, 0.10 } or { 0.35, 0.3, 0.3 })
        love.graphics.rectangle("fill", tag.x, tag.y, tag.w, tag.h, 8, 8)
        ui.text(price .. " COINS", fonts.hint, tag.x, tag.y + 8, tag.w, "center", canPay and WHITE or DIM)
    end
end


---------------------------------------------------------------------------
-- THE PLAY SCREEN
---------------------------------------------------------------------------

-- A label and a value in a small box (SETS 3, REROLLS 2...).
local function statBox(r, label, value, color)
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 8, 8)
    ui.text(label, fonts.hint, r.x, r.y + 6, r.w, "center", DIM)
    ui.text(tostring(value), fonts.button, r.x, r.y + 24, r.w, "center", color)
end

-- The blue POINTS box and red MULT box, like Balatro's chips x mult.
local function pointsTimesMult(p, y, points, multText)
    local w = (p.w - 70) / 2
    local a = util.rect(p.x + 18, y, w, 64)
    local b = util.rect(p.x + p.w - 18 - w, y, w, 64)
    love.graphics.setColor(0.10, 0.30, 0.75)
    love.graphics.rectangle("fill", a.x, a.y, a.w, a.h, 10, 10)
    love.graphics.setColor(0.75, 0.12, 0.12)
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 10, 10)
    ui.text("POINTS", fonts.hint, a.x, a.y + 5, a.w, "center", { 0.8, 0.9, 1 })
    ui.text("MULT", fonts.hint, b.x, b.y + 5, b.w, "center", { 1, 0.85, 0.85 })
    ui.text(tostring(points), fonts.button, a.x + 4, a.y + 24, a.w - 8, "center", WHITE)
    ui.text(multText, fonts.button, b.x + 4, b.y + 24, b.w - 8, "center", WHITE)
    ui.text("X", fonts.button, a.x + a.w, a.y + 18, b.x - a.x - a.w, "center", GOLD)
end

-- Show a number nicely: 2.5 stays 2.5, 3.0 becomes 3.
local function num(x)
    if x == math.floor(x) then return tostring(math.floor(x)) end
    return string.format("%.2f", x):gsub("0+$", "")
end

local function drawScoreboard(run)
    local p = pipslayout.panel()
    ui.vegasWindow(p, nil)
    local roundName = "ROUND " .. run.round .. "/" .. P.ROUNDS
    if run.boss then roundName = "BOSS ROUND" end
    ui.text("LEVEL " .. run.level .. "   " .. roundName, fonts.heading,
        p.x, p.y + 16, p.w, "center", run.boss and RED or GOLD, true)
    if run.josh then
        -- The duel: your total against Josh's.
        ui.text("BEAT PIT BOSS JOSH", fonts.hint, p.x, p.y + 46, p.w, "center", DIM)
        local half = (p.w - 36) / 2
        ui.text("YOU", fonts.hint, p.x + 18, p.y + 66, half, "center", GREEN)
        ui.text("JOSH", fonts.hint, p.x + 18 + half, p.y + 66, half, "center", RED)
        ui.text(tostring(run.roundScore), fonts.button, p.x + 18, p.y + 84, half, "center", WHITE, true)
        ui.text(tostring(run.josh.total), fonts.button, p.x + 18 + half, p.y + 84, half, "center", WHITE, true)
        ui.text("Josh has " .. run.josh.setsLeft .. " sets and " .. run.josh.rerollsLeft .. " rerolls left",
            fonts.tiny, p.x, p.y + 122, p.w, "center", CREAM)
        local off = "The house wins ties."
        for _, held in ipairs(run.josh.perkys) do
            if held.disabled then off = "Josh's " .. perkys.get(held.id).name .. " is switched off. House wins ties." end
        end
        ui.text(off, fonts.tiny, p.x + 10, p.y + 142, p.w - 20, "center", DIM)
    else
        ui.text("GOAL", fonts.hint, p.x, p.y + 46, p.w, "center", DIM)
        ui.text(tostring(run.goal), fonts.scoreBig, p.x, p.y + 60, p.w, "center", WHITE, true)

        -- Round score with a bar filling up to the goal.
        ui.text("ROUND SCORE  " .. run.roundScore, fonts.small, p.x, p.y + 116, p.w, "center", CREAM)
        local bar = util.rect(p.x + 24, p.y + 142, p.w - 48, 14)
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", bar.x, bar.y, bar.w, bar.h, 7, 7)
        local fill = math.min(1, run.roundScore / run.goal)
        if fill > 0 then
            love.graphics.setColor(fill >= 1 and GREEN or GOLD)
            love.graphics.rectangle("fill", bar.x, bar.y, bar.w * fill, bar.h, 7, 7)
        end
    end

    local w = (p.w - 56) / 3
    statBox(util.rect(p.x + 18, p.y + 168, w, 58), "SETS", run.setsLeft, BLUE)
    statBox(util.rect(p.x + 28 + w, p.y + 168, w, 58), "REROLLS", run.rerollsLeft, RED)
    statBox(util.rect(p.x + 38 + 2 * w, p.y + 168, w, 58), "COINS", run.coins, GOLD)

    -- The set and POINTS x MULT: before scoring, the starting (base) numbers;
    -- after scoring, the final numbers with every Perky added in.
    local result = run.lastResult
    if run.state == "scored" and result then
        ui.text(result.hand.name, fonts.heading, p.x, p.y + 240, p.w, "center", GOLD, true)
        local multText = num(result.mult)
        if result.xmult ~= 1 then multText = multText .. " x" .. num(result.xmult) end
        pointsTimesMult(p, p.y + 266, result.points, multText)
        ui.text("= " .. result.total, fonts.title, p.x, p.y + 334, p.w, "center", GREEN, true)
        ui.text("BASE  " .. result.basePoints .. " x " .. result.baseMult, fonts.hint,
            p.x, p.y + 390, p.w, "center", DIM)
        local y = p.y + 410
        for k, part in ipairs(result.parts) do
            if k > 8 then break end
            ui.text(part.name, fonts.tiny, p.x + 22, y, p.w * 0.5 - 22, "left", CREAM)
            ui.text(part.text, fonts.tiny, p.x + p.w * 0.5, y, p.w * 0.5 - 22, "right", GOLD)
            y = y + 19
        end
    elseif not pipsview.isRolling() then
        local points, mult, hand = pipsgame.preview()
        ui.text(hand.name, fonts.heading, p.x, p.y + 240, p.w, "center", GOLD, true)
        pointsTimesMult(p, p.y + 266, points, tostring(mult))
        ui.text("BASE POINTS x BASE MULT", fonts.hint, p.x, p.y + 340, p.w, "center", DIM)
        ui.text("Perkys add theirs when you SCORE.", fonts.tiny, p.x, p.y + 358, p.w, "center", DIM)
    else
        ui.text("ROLLING...", fonts.heading, p.x, p.y + 240, p.w, "center", GOLD, true)
        pointsTimesMult(p, p.y + 266, "?", "?")
    end

    -- The buttons.
    local busy = pipsview.isRolling()
    if run.state == "scored" then
        ui.glossyButton(pipslayout.nextButton(), run.josh and "JOSH'S TURN" or "NEXT", { 0.10, 0.65, 0.25 }, true)
    elseif run.state == "joshTurn" then
        ui.glossyButton(pipslayout.nextButton(), "NEXT", { 0.10, 0.65, 0.25 }, pipsview.joshDone())
    else
        local anyFree = false
        for i = 1, #run.dice do if not run.held[i] then anyFree = true end end
        ui.glossyButton(pipslayout.rerollButton(), "REROLL", { 0.85, 0.10, 0.12 },
            run.state == "choose" and not busy and run.rerollsLeft > 0 and anyFree)
        ui.glossyButton(pipslayout.scoreButton(), "SCORE", { 0.12, 0.38, 0.95 }, run.state == "choose" and not busy)
    end
    ui.glossyButton(pipslayout.menuButton(), "MENU", { 0.45, 0.45, 0.52 }, true)
end

-- The SETS list on the right: every unlocked set and its mult.
local function drawSetsList(run, current)
    local s = pipslayout.setsPanel()
    ui.vegasWindow(s, nil)
    ui.text("SETS", fonts.heading, s.x, s.y + 14, s.w, "center", GOLD, true)
    ui.text("MULT", fonts.hint, s.x, s.y + 38, s.w - 14, "right", DIM)
    local unlocked = {}
    for _, h in ipairs(pipshands.LIST) do
        if pipshands.isUnlocked(h, run.slots) then table.insert(unlocked, h) end
    end
    local rowH = math.min(24, (s.h - 110) / #unlocked)
    local y = s.y + 58
    for _, h in ipairs(unlocked) do
        local level = run.setAug[h.id] or 0
        local mult = h.mult + level * pipshands.augmentMult(h)
        local isCurrent = current and current.id == h.id
        if isCurrent then
            love.graphics.setColor(1, 0.82, 0.3, 0.25)
            love.graphics.rectangle("fill", s.x + 8, y - 2, s.w - 16, rowH, 6, 6)
        end
        local name = h.name .. (level > 0 and ("  +" .. level) or "")
        ui.text(name, fonts.tiny, s.x + 14, y, s.w * 0.6, "left", isCurrent and GOLD or CREAM)
        ui.text("x" .. mult, fonts.tiny, s.x + s.w * 0.6, y, s.w * 0.4 - 14, "right",
            isCurrent and GOLD or WHITE)
        y = y + rowH
    end
    -- When does the next dice slot open?
    for _, l in ipairs(P.SLOT_LEVELS) do
        if l > run.level then
            wrapped("Next dice slot (and new sets) at level " .. l, fonts.tiny, s.x + 10, s.y + s.h - 44, s.w - 20, DIM)
            break
        end
    end
end

local function drawPerkyRack(run)
    local m = pipslayout.middle()
    ui.text("PERKYS  " .. #run.perkys .. "/" .. P.MAX_PERKYS, fonts.heading, m.x, m.y + 8, m.w, "center", GOLD, true)
    for k = 1, P.MAX_PERKYS do
        local r = pipslayout.perkyCard(k)
        local held = run.perkys[k]
        if held then
            -- A Perky that did something in the set just scored lights up.
            local p = perkys.get(held.id)
            local fired = false
            if run.state == "scored" and run.lastResult then
                for _, part in ipairs(run.lastResult.parts) do
                    if part.name == p.name then fired = true end
                end
            end
            if fired then
                love.graphics.setColor(1, 0.85, 0.3, 0.5)
                love.graphics.rectangle("fill", r.x - 6, r.y - 6, r.w + 12, r.h + 12, 14, 14)
            end
            pipsdraw.perkyCard(r, held.id, held, held.disabled)
            if held.disabled then
                -- Pit Boss Josh switched this one off for the duel.
                love.graphics.setColor(0.9, 0.1, 0.1, 0.85)
                love.graphics.setLineWidth(5)
                love.graphics.line(r.x + 10, r.y + 10, r.x + r.w - 10, r.y + r.h - 10)
                love.graphics.line(r.x + r.w - 10, r.y + 10, r.x + 10, r.y + r.h - 10)
                love.graphics.setLineWidth(1)
                ui.text("SWITCHED OFF", fonts.hint, r.x, r.y + r.h - 24, r.w, "center", RED, true)
            end
        else
            love.graphics.setColor(1, 1, 1, 0.12)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 10, 10)
            love.graphics.setLineWidth(1)
            ui.text("EMPTY", fonts.hint, r.x, r.y + r.h / 2 - 8, r.w, "center", { 1, 1, 1, 0.25 })
        end
    end
end

local function drawDiceRow(run)
    local m = pipslayout.middle()
    for i = 1, run.slots do
        local r = pipslayout.dieRect(i, run.slots)
        local die = run.dice[i]
        if die then
            local held = run.held[i] and run.state == "choose"
            local y = r.y - (held and 20 or 0)
            local lit = 0
            if pipsview.isFlickering(i) then
                lit = 0.6 + 0.4 * math.sin(pipsview.time * 40)
            elseif held then
                lit = 0.8
            end
            -- A small "pop" just after a die stops.
            local ago = pipsview.landedAgo(i)
            local grow = 0
            if ago and ago >= 0 and ago < 0.15 then grow = (1 - ago / 0.15) * 6 end
            pipsdraw.die(die, pipsview.faceShown(i), r.x - grow, y - grow, r.w + 2 * grow, lit)
            if held then
                ui.text("HELD", fonts.hint, r.x - 10, y + r.h + 6, r.w + 20, "center", GOLD, true)
            elseif not ui.touchMode and i <= 10 and run.state == "choose" then
                ui.text(tostring(i % 10), fonts.hint, r.x, r.y + r.h + 6, r.w, "center", { 1, 1, 1, 0.3 })
            end
        else
            -- An open slot with no die in it yet.
            love.graphics.setColor(1, 1, 1, 0.18)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", r.x, r.y, r.w, r.h, r.w * 0.18, r.w * 0.18)
            love.graphics.setLineWidth(1)
            local stolen = run.boss and run.boss.stolen and i == #run.dice + 1
            ui.text(stolen and "STOLEN!" or "EMPTY", fonts.hint, r.x - 6, r.y + r.h / 2 - 7, r.w + 12, "center",
                stolen and RED or { 1, 1, 1, 0.3 })
        end
    end
    local hint
    if run.state == "choose" then
        hint = ui.touchMode and "TAP DICE TO HOLD THEM, THEN REROLL THE REST - OR SCORE"
            or "CLICK DICE (OR 1-9, 0) TO HOLD,  R = REROLL,  ENTER = SCORE"
    elseif run.state == "scored" or (run.state == "joshTurn" and pipsview.joshDone()) then
        hint = ui.touchMode and "TAP NEXT" or "ENTER = NEXT"
    end
    if hint then
        local r = pipslayout.dieRect(1, run.slots)
        ui.text(hint, fonts.hint, m.x, r.y + r.h + 40, m.w, "center", { 1, 0.9, 0.3, 0.8 })
    end
end

local function drawBets(run)
    local s = pipslayout.betsStrip()
    local total = util.sum(run.values)
    ui.text("PIP TOTAL  " .. (pipsview.isRolling() and "?" or total), fonts.heading, s.x, s.y - 8, s.w, "center", WHITE)
    if #run.bets == 0 then
        ui.text("No craps bets yet - win them from the slot machine's CRAPS PACK.", fonts.tiny,
            s.x, s.y + 50, s.w, "center", DIM)
        return
    end
    ui.text("CRAPS BETS: roll a total on the board for x" .. P.CRAPS_XMULT .. " MULT", fonts.tiny,
        s.x, s.y + 20, s.w, "center", DIM)
    for k, n in ipairs(run.bets) do
        local r = pipslayout.betBox(k, #run.bets)
        local hit = (n == total) and not pipsview.isRolling()
        if hit then
            love.graphics.setColor(1, 0.85, 0.3, 0.45)
            love.graphics.rectangle("fill", r.x - 5, r.y - 5, r.w + 10, r.h + 10, 10, 10)
        end
        love.graphics.setColor(0.03, 0.22, 0.11)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 8, 8)
        love.graphics.setColor(hit and GOLD or WHITE)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 8, 8)
        love.graphics.setLineWidth(1)
        ui.text(tostring(n), fonts.number, r.x, r.y + 8, r.w, "center", hit and GOLD or WHITE)
    end
end

-- During a boss round: the boss's picture and trick between the Perkys and
-- your dice. During the Josh duel: Josh and HIS dice, playing his turn.
local function drawBossStrip(run)
    local s = pipslayout.bossStrip()
    local b = bosses.get(run.boss.id)
    love.graphics.setColor(0.25, 0.02, 0.04, 0.75)
    love.graphics.rectangle("fill", s.x, s.y, s.w, s.h, 10, 10)
    love.graphics.setColor(RED)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", s.x, s.y, s.w, s.h, 10, 10)
    love.graphics.setLineWidth(1)
    bossart.draw(b, s.x + 12, s.y + 8, 3, 1)
    if not run.josh then
        ui.text(b.name, fonts.heading, s.x + 70, s.y + 14, s.w - 80, "left", RED, true)
        local trick = bosses.TRICK_BY_ID[run.boss.trick]
        ui.text(trick.about, fonts.small, s.x + 70, s.y + 44, s.w - 80, "left", CREAM)
        return
    end
    local josh = run.josh
    for i, die in ipairs(josh.dice) do
        local r = pipslayout.joshDieRect(i, #josh.dice)
        local face, flicker, held = pipsview.joshFace(i)
        if face then
            local lit = flicker and (0.6 + 0.4 * math.sin(pipsview.time * 40)) or (held and 0.8 or 0)
            pipsdraw.die(die, face, r.x, r.y, r.w, lit)
        else
            love.graphics.setColor(1, 1, 1, 0.15)
            love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 8, 8)
        end
    end
    local text
    if josh.lastResult and pipsview.joshDone() then
        text = "JOSH SCORED " .. josh.lastResult.total .. "  (" .. josh.lastResult.hand.name .. ")"
    elseif josh.steps then
        text = "JOSH IS ROLLING..."
    else
        text = "PIT BOSS JOSH - waiting for your first set"
    end
    ui.text(text, fonts.hint, s.x + 70, s.y + s.h - 20, s.w - 80, "center", GOLD, true)
end

-- "OH NO.... A STRANGE FIGURE APPEARS..." - the boss's entrance.
local function drawBossIntro(run)
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local t = pipsview.introClock
    love.graphics.setColor(0.04, 0.0, 0.02)
    love.graphics.rectangle("fill", 0, 0, W, H)
    -- A slow red pulse round the edges.
    local pulse = 0.5 + 0.5 * math.sin(t * 3)
    for i = 0, 30 do
        love.graphics.setColor(0.6, 0.0, 0.05, (0.02 + 0.02 * pulse) * (30 - i) / 30 * 3)
        love.graphics.setLineWidth(8)
        love.graphics.rectangle("line", i * 8, i * 8, W - i * 16, H - i * 16)
    end
    love.graphics.setLineWidth(1)

    -- The words appear one letter at a time.
    local words = "OH NO.... A STRANGE FIGURE APPEARS..."
    local shown = words:sub(1, math.min(#words, math.floor(t * 18)))
    ui.text(shown, fonts.title, 40, 50, W - 80, "center", RED, true)

    local b = bosses.get(run.boss.id)
    if t < 2.2 then return end
    local scale = math.max(6, math.floor(math.min(W, H) / 70))
    local bw, bh = bossart.size(b, scale)
    local alpha = math.min(1, (t - 2.2) / 0.6)
    local bx, by = W / 2 - bw - 60, 150
    bossart.draw(b, bx, by, scale, alpha)

    if t < 2.8 then return end
    local x, w = W / 2 - 20, math.min(560, W / 2 - 40)
    ui.text(b.name, fonts.title, x, 170, w, "left", run.boss.josh and GOLD or RED, true)
    -- A speech bubble with what they say.
    local bubble = util.rect(x, 240, w, 150)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.rectangle("fill", bubble.x, bubble.y, bubble.w, bubble.h, 16, 16)
    love.graphics.polygon("fill", bubble.x, bubble.y + 50, bubble.x - 26, bubble.y + 70, bubble.x, bubble.y + 80)
    love.graphics.setFont(fonts.text)
    love.graphics.setColor(0.1, 0.05, 0.05)
    love.graphics.printf('"' .. run.boss.line .. '"', bubble.x + 20, bubble.y + 22, bubble.w - 40, "left")
    -- What the boss does.
    local about = run.boss.josh and bosses.JOSH_ABOUT or bosses.TRICK_BY_ID[run.boss.trick].about
    wrapped(about, fonts.small, x, 410, w, GOLD, "left")
    if run.boss.josh then
        wrapped("Beat him and you beat the game - then ENDLESS awaits.", fonts.small, x, 470, w, CREAM, "left")
    end

    if t < 3.2 then return end
    ui.glossyButton(pipslayout.fightButton(), "FIGHT!", { 0.85, 0.10, 0.12 }, true)
    if not ui.touchMode then
        ui.text("ENTER = FIGHT", fonts.hint, 0, H - 44, W, "center", { 1, 0.9, 0.3, 0.8 })
    end
end

-- The ROUND WON / GAME OVER / VICTORY window.
local function drawPopup(run)
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, W, H)
    local p = pipslayout.popup()
    ui.vegasWindow(p, nil)
    ui.bulbBorder({ x = p.x - 10, y = p.y - 10, w = p.w + 20, h = p.h + 20 }, 26, 5, 6)
    if run.state == "victory" then
        ui.text("YOU BEAT", fonts.title, p.x, p.y + 20, p.w, "center", GREEN, true)
        ui.text("PIT BOSS JOSH!", fonts.title, p.x, p.y + 72, p.w, "center", GOLD, true)
        ui.text("You " .. run.roundScore .. "  vs  Josh " .. run.josh.total, fonts.text, p.x, p.y + 146, p.w,
            "center", CREAM)
        wrapped("You beat the game! Keep going in ENDLESS: the goals climb x3 a level, "
            .. "and faster every level after.", fonts.small, p.x + 40, p.y + 196, p.w - 80, CREAM)
        ui.glossyButton(pipslayout.popupButton(1, 3), "ENDLESS", { 0.85, 0.10, 0.12 }, true)
        ui.glossyButton(pipslayout.popupButton(2, 3), "AGAIN", { 0.10, 0.65, 0.25 }, true)
        ui.glossyButton(pipslayout.popupButton(3, 3), "MENU", { 0.45, 0.45, 0.52 }, true)
    elseif run.state == "roundWon" then
        local title = run.boss and "BOSS BEATEN!" or "ROUND WON!"
        ui.text(title, fonts.title, p.x, p.y + 24, p.w, "center", GREEN, true)
        ui.text("Scored " .. run.roundScore .. " of " .. run.goal, fonts.text, p.x, p.y + 90, p.w, "center", CREAM)
        local pay = run.payout
        local rows = {
            { "Round won", pay.win },
            { "Rerolls left (+" .. P.COIN_PER_REROLL .. " each)", pay.rerolls },
            { "Sets left (+" .. P.COIN_PER_SET .. " each)", pay.sets },
        }
        if pay.perkys > 0 then table.insert(rows, { "Perkys", pay.perkys }) end
        local y = p.y + 140
        for _, row in ipairs(rows) do
            ui.text(row[1], fonts.small, p.x + 60, y, p.w - 200, "left", CREAM)
            ui.text("+" .. row[2], fonts.small, p.x + p.w - 160, y, 100, "right", GOLD)
            y = y + 30
        end
        ui.text("COINS  +" .. pay.total, fonts.heading, p.x, y + 10, p.w, "center", GOLD, true)
        ui.glossyButton(pipslayout.popupButton(1, 1), "TO THE SHOP", { 0.10, 0.65, 0.25 }, true)
    else
        ui.text("GAME OVER", fonts.title, p.x, p.y + 24, p.w, "center", RED, true)
        if run.josh then
            ui.text("PIT BOSS JOSH WINS: you " .. run.roundScore .. " vs Josh " .. run.josh.total, fonts.text,
                p.x + 10, p.y + 100, p.w - 20, "center", CREAM)
        elseif run.boss then
            ui.text(bosses.get(run.boss.id).name .. " beat you: " .. run.roundScore .. " of " .. run.goal,
                fonts.text, p.x + 10, p.y + 100, p.w - 20, "center", CREAM)
        else
            ui.text("Out of sets: " .. run.roundScore .. " of " .. run.goal, fonts.text, p.x, p.y + 100, p.w, "center", CREAM)
        end
        ui.text("Reached level " .. run.level .. ", round " .. run.round, fonts.text, p.x, p.y + 140, p.w, "center", CREAM)
        ui.text("Best set: " .. run.best, fonts.text, p.x, p.y + 180, p.w, "center", GOLD)
        ui.glossyButton(pipslayout.popupButton(1, 2), "AGAIN", { 0.10, 0.65, 0.25 }, true)
        ui.glossyButton(pipslayout.popupButton(2, 2), "MENU", { 0.45, 0.45, 0.52 }, true)
    end
end

local function drawPlay(run)
    if run.state == "bossIntro" then
        drawBossIntro(run)
        return
    end
    drawFelt()
    local hand = nil
    if run.state == "scored" and run.lastResult then
        hand = run.lastResult.hand
    elseif not pipsview.isRolling() then
        local _, _, h = pipsgame.preview()
        hand = h
    end
    drawScoreboard(run)
    drawSetsList(run, hand)
    drawPerkyRack(run)
    if run.boss then drawBossStrip(run) end
    drawDiceRow(run)
    drawBets(run)
    if run.state == "roundWon" or run.state == "gameOver" or run.state == "victory" then
        drawPopup(run)
    end
end


---------------------------------------------------------------------------
-- THE SHOP
---------------------------------------------------------------------------

-- Each pack's colour and short label on the reels.
local PACK_LOOK = {
    dice      = { color = { 0.95, 0.95, 0.95 }, label = "DICE" },
    perky     = { color = { 0.55, 0.75, 1.00 }, label = "PERKY" },
    bigPerky  = { color = { 0.35, 0.95, 0.45 }, label = "BIG PERKY" },
    rarePerky = { color = { 1.00, 0.35, 0.35 }, label = "RARE PERKY" },
    diceAug   = { color = { 0.30, 0.85, 1.00 }, label = "DICE AUG" },
    setAug    = { color = { 1.00, 0.45, 0.85 }, label = "SET AUG" },
    craps     = { color = { 1.00, 0.55, 0.15 }, label = "CRAPS" },
    dungeon   = { color = { 1.00, 0.82, 0.30 }, label = "DUNGEON" },
}

-- One pack symbol, centred at (cx, cy).
local function packSymbol(id, cx, cy, w, h)
    local look = PACK_LOOK[id]
    local c = look.color
    love.graphics.setColor(mix(c, { 0.05, 0.02, 0.05 }, 0.7))
    love.graphics.rectangle("fill", cx - w / 2, cy - h / 2, w, h, 10, 10)
    love.graphics.setColor(c)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", cx - w / 2, cy - h / 2, w, h, 10, 10)
    love.graphics.setLineWidth(1)
    ui.text(look.label, fonts.heading, cx - w / 2 + 6, cy - 22, w - 12, "center", c, true)
    ui.text("PACK", fonts.hint, cx - w / 2 + 4, cy + 4, w - 8, "center", WHITE)
end

local function drawMachine(run)
    local m = pipslayout.machine()
    local spinning = pipsview.isSpinning()
    ui.bulbBorder({ x = m.x - 10, y = m.y - 10, w = m.w + 20, h = m.h + 20 }, 24, 6, spinning and 18 or 5)
    for i = 0, m.h, 3 do
        love.graphics.setColor(0.78 - 0.35 * i / m.h, 0.08, 0.10)
        love.graphics.rectangle("fill", m.x, m.y + i, m.w, 3)
    end
    love.graphics.setColor(GOLD)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", m.x, m.y, m.w, m.h, 8, 8)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.08, 0.02, 0.04)
    love.graphics.rectangle("fill", m.x + 14, m.y + 10, m.w - 28, 46, 8, 8)
    ui.text("PACK MACHINE", fonts.heading, m.x, m.y + 13, m.w, "center", GOLD, true)
    ui.text(pipsshop.hasUntakenReels(run) and not spinning and "CLICK A REEL TO OPEN ITS PACK"
        or "SPIN, THEN OPEN ONE OF THE 3 PACKS", fonts.hint, m.x, m.y + 36, m.w, "center", WHITE)

    local reels = run.shop.reels
    for k = 1, 3 do
        local r = pipslayout.reel(k)
        love.graphics.setColor(0.95, 0.93, 0.88)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 8, 8)
        love.graphics.stencil(function() love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 8, 8) end, "replace", 1)
        love.graphics.setStencilTest("greater", 0)
        local cx, cy = r.x + r.w / 2, r.y + r.h / 2
        if reels and not pipsview.reelStopped(k) then
            -- Spinning: pack symbols sliding past (just for show).
            local offset = (pipsview.spinClock * 900) % 110
            for n = -1, 2 do
                local id = pipsshop.PACKS[(n + math.floor(pipsview.spinClock * 9) + k) % #pipsshop.PACKS + 1].id
                packSymbol(id, cx, r.y + n * 110 + offset - 20, r.w - 20, 90)
            end
        elseif reels then
            packSymbol(reels[k], cx, cy, r.w - 20, 100)
        else
            ui.text("?", fonts.title, r.x, cy - 28, r.w, "center", { 0.5, 0.45, 0.4 })
        end
        love.graphics.setStencilTest()
        local rim = GOLD
        if reels and pipsview.reelStopped(k) then rim = PACK_LOOK[reels[k]].color end
        love.graphics.setColor(rim)
        love.graphics.setLineWidth(4)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 8, 8)
        love.graphics.setLineWidth(1)
        if reels and not spinning then
            if reels.taken == k then
                ui.text("OPENED", fonts.heading, r.x, r.y + r.h - 26, r.w, "center", GOLD, true)
            elseif reels.taken then
                love.graphics.setColor(0, 0, 0, 0.6)
                love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 8, 8)
            elseif ui.isHovered(r) then
                love.graphics.setColor(1, 1, 1, 0.2)
                love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 8, 8)
            end
            if not reels.taken or reels.taken == k then
                wrapped(pipsshop.PACK_BY_ID[reels[k]].about, fonts.tiny, r.x - 6, r.y + r.h + 8, r.w + 12, CREAM)
            end
        end
    end
    if not reels then
        ui.text("Each reel lands on a pack. Rare Perky packs: 1% a reel.", fonts.tiny,
            m.x, m.y + 248, m.w, "center", DIM)
    end
    local price = pipsshop.spinPrice(run)
    local canSpin = not spinning and not pipsshop.hasUntakenReels(run) and run.coins >= price and not run.shop.pack
    ui.glossyButton(pipslayout.spinButton(), "SPIN  " .. price, { 0.95, 0.70, 0.10 }, canSpin)
end

local function drawForSale(run)
    local f = pipslayout.forSale()
    ui.vegasWindow(f, "FOR SALE")
    for k, item in ipairs(run.shop.items) do
        itemCard(pipslayout.itemCard(k), item, item.price, item.sold)
    end
    ui.glossyButton(pipslayout.shopRerollButton(), "REROLL  " .. run.shop.rerollCost, { 0.85, 0.10, 0.12 },
        run.coins >= run.shop.rerollCost and not run.shop.pack)
end

local function drawYourPerkys(run)
    local w = pipslayout.perkyWindow()
    ui.vegasWindow(w, "YOUR PERKYS " .. #run.perkys .. "/" .. P.MAX_PERKYS)
    for k = 1, P.MAX_PERKYS do
        local r = pipslayout.perkyRow(k)
        local held = run.perkys[k]
        love.graphics.setColor(0, 0, 0, 0.35)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 8, 8)
        if held then
            local p = perkys.get(held.id)
            local color = perkys.RARITIES[p.rarity].color
            love.graphics.setColor(color)
            love.graphics.rectangle("fill", r.x, r.y, 6, r.h, 3, 3)
            ui.text(p.name, fonts.small, r.x + 14, r.y + 4, r.w - 110, "left", color)
            love.graphics.setScissor(r.x, r.y, r.w - 80, r.h)
            wrapped(perkyAbout(p, held), fonts.tiny, r.x + 14, r.y + 26, r.w - 100, CREAM, "left")
            love.graphics.setScissor()
            ui.glossyButton(pipslayout.sellButton(k), "+" .. perkys.sellPrice(p), { 0.85, 0.40, 0.10 }, true)
            ui.text("SELL", fonts.hint, pipslayout.sellButton(k).x, pipslayout.sellButton(k).y - 14,
                pipslayout.sellButton(k).w, "center", DIM)
        else
            ui.text("empty slot", fonts.tiny, r.x, r.y + r.h / 2 - 8, r.w, "center", { 1, 1, 1, 0.3 })
        end
    end
end

local function drawYourDice(run)
    local w = pipslayout.diceWindow()
    ui.vegasWindow(w, "YOUR DICE " .. #run.dice .. "/" .. run.slots)
    local pack = run.shop.pack
    local swapping = pack and pack.replacing
    for i = 1, run.slots do
        local r = pipslayout.shopDie(i, run.slots)
        local die = run.dice[i]
        if die then
            local lit = (swapping and ui.isHovered(r)) and 1 or 0
            pipsdraw.die(die, pipsdice.maxFace(die), r.x, r.y, r.w, lit)
        else
            love.graphics.setColor(1, 1, 1, 0.2)
            love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 8, 8)
        end
    end
    local text = "Empty slots fill from DICE packs."
    if swapping then text = "Click the die to swap out (or SKIP)." end
    ui.text(text, fonts.tiny, w.x + 16, w.y + 112, w.w - 32, "left", swapping and GOLD or DIM)
    for _, l in ipairs(P.SLOT_LEVELS) do
        if l > run.level then
            ui.text("Next slot opens at level " .. l, fonts.tiny, w.x + 16, w.y + 132, w.w - 32, "left", DIM)
            break
        end
    end
end

local function drawAugments(run)
    local w = pipslayout.augWindow()
    ui.vegasWindow(w, "AUGMENTS")
    local parts = {}
    for f = 1, pipshands.MAX_FACE do
        if (run.diceAug[f] or 0) > 0 then
            table.insert(parts, "Each " .. f .. " scores " .. augments.facePoints(f, run.diceAug[f])
                .. " (level " .. run.diceAug[f] .. ")")
        end
    end
    for _, h in ipairs(pipshands.LIST) do
        if (run.setAug[h.id] or 0) > 0 then
            table.insert(parts, h.name .. " +" .. run.setAug[h.id] * pipshands.augmentMult(h) .. " mult")
        end
    end
    if #run.bets > 0 then table.insert(parts, "Craps bets: " .. table.concat(run.bets, ", ")) end
    if #parts == 0 then parts = { "None yet." } end
    love.graphics.setScissor(w.x, w.y, w.w, w.h - 8)
    wrapped(table.concat(parts, "\n"), fonts.tiny, w.x + 16, w.y + 30, w.w - 32, CREAM, "left")
    love.graphics.setScissor()
end

local function drawPack(run)
    local pack = run.shop.pack
    local r = pipslayout.packWindow()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", r.x - 10, r.y - 20, r.w + 20, r.h + 30, 14, 14)
    ui.vegasWindow(r, pipsshop.PACK_BY_ID[pack.id].name .. " - PICK ONE")
    for k, option in ipairs(pack.options) do
        local box = pipslayout.packOption(k, #pack.options)
        if pack.replacing == k then
            love.graphics.setColor(1, 0.85, 0.3, 0.5)
            love.graphics.rectangle("fill", box.x - 6, box.y - 6, box.w + 12, box.h + 12, 14, 14)
        end
        itemCard(box, option, nil, false, pack.replacing ~= nil and pack.replacing ~= k)
    end
    if #pack.options == 0 then
        ui.text("Nothing left to find in this pack!", fonts.text, r.x, r.y + 120, r.w, "center", CREAM)
    end
    ui.glossyButton(pipslayout.skipButton(), "SKIP", { 0.45, 0.45, 0.52 }, true)
end

local function drawShop(run)
    drawCarpet()
    local sign = pipslayout.shopSign()
    love.graphics.setColor(0.55, 0.05, 0.08)
    love.graphics.rectangle("fill", sign.x, sign.y, sign.w, sign.h, 14, 14)
    ui.bulbBorder(sign, 26, 5, 6)
    ui.text("PERKY SHOP", fonts.title, sign.x, sign.y + 2, sign.w, "center", GOLD, true)
    ui.text("COINS  " .. run.coins, fonts.button, 30, 30, 300, "left", GOLD, true)
    local nextText = "NEXT: LEVEL " .. (run.round == P.ROUNDS and run.level + 1 or run.level) .. "  ROUND "
        .. (run.round % P.ROUNDS + 1)
    if run.pendingBoss then nextText = "NEXT: A BOSS!" end
    ui.text(nextText, fonts.hint, 30, 66, 360, "left", run.pendingBoss and RED or CREAM)

    drawForSale(run)
    drawMachine(run)
    drawYourPerkys(run)
    drawYourDice(run)
    drawAugments(run)
    if run.shop.pack then drawPack(run) end

    ui.glossyButton(pipslayout.continueButton(), run.pendingBoss and "FACE THE BOSS" or "NEXT ROUND",
        run.pendingBoss and { 0.85, 0.10, 0.12 } or { 0.10, 0.65, 0.25 }, not run.shop.pack)
    local sign2 = pipslayout.shopSign()
    ui.text(run.shop.message or "", fonts.small, 0, sign2.y + sign2.h + 6, love.graphics.getWidth(), "center", CREAM)
end


-- "Turn on god mode?" - shown after the first ` press.
local function drawGodPrompt()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0, 0, 0, 0.65)
    love.graphics.rectangle("fill", 0, 0, W, H)
    local p = pipslayout.popup()
    ui.vegasWindow(p, nil)
    ui.text("GOD MODE?", fonts.title, p.x, p.y + 24, p.w, "center", RED, true)
    wrapped("This is a testing cheat. Turning it on marks this run as GOD MODE: it can never "
        .. "go on the leaderboard or count toward your stats.\n\n"
        .. "Once it's on, every ` jumps you to the next shop (winning the round) and fills "
        .. "every empty dice slot with a white die.\n\n"
        .. "Press ` again to turn it on, or Esc to cancel.",
        fonts.small, p.x + 34, p.y + 96, p.w - 68, CREAM)
    ui.glossyButton(pipslayout.popupButton(1, 2), "TURN ON", { 0.85, 0.10, 0.12 }, true)
    ui.glossyButton(pipslayout.popupButton(2, 2), "CANCEL", { 0.45, 0.45, 0.52 }, true)
end

-- Draw whichever PIPS screen the run is on.
function pipsdraw.screen()
    local run = pipsgame.run
    if not run then return end
    if run.state == "shop" then drawShop(run) else drawPlay(run) end
    if pipsgame.unranked then
        ui.text("GOD MODE - NOT RANKED", fonts.hint, 30, love.graphics.getHeight() - 20, 300, "left",
            { 1, 0.35, 0.3, 0.8 })
    end
    if pipsview.godPrompt then drawGodPrompt() end
end

return pipsdraw
