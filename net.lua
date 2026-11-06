-- net.lua
-- Talking to the internet (the online leaderboard), and the clipboard.
--
-- LÖVE 11 can't fetch web pages by itself, so:
--   * ON A COMPUTER: a background thread runs Windows' (or Mac/Linux's)
--     built-in "curl" program, so the game never freezes while it waits.
--   * IN A WEB BROWSER: the game prints a special line ("@@PD@@{...}").
--     The web page (docs/index.html) spots it, does the request with the
--     browser's own fetch(), and writes the answer into the game's save
--     folder, where we pick it up.
-- Either way, net.request() returns straight away and calls 'done' later.
-- Call net.update() every frame.

local json = require("json")

local net = {}

local onWeb = love.system.getOS() == "Web"
local nextId = 0
local waiting = {}   -- waiting[id] = done callback

-- The background thread used on a computer.
local THREAD_CODE = [[
local requests, replies = ...
while true do
    local job = requests:demand()
    local f = io.popen(job.command)
    local out = f and f:read("*a") or ""
    if f then f:close() end
    replies:push({ id = job.id, out = out })
end
]]
local thread, requests, replies

local function startThread()
    if thread then return end
    requests = love.thread.newChannel()
    replies = love.thread.newChannel()
    thread = love.thread.newThread(THREAD_CODE)
    thread:start(requests, replies)
end

-- Wrap text in quotes for the command line.
local function quote(s)
    if love.system.getOS() == "Windows" then
        return '"' .. s:gsub('"', '\\"') .. '"'
    end
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- Send a web request.
--   method  - "GET" or "POST"
--   url     - the full address
--   headers - { ["apikey"] = "...", ... }
--   body    - text to send (or nil)
--   done    - function(status, text) - status 0 means it didn't get through
function net.request(method, url, headers, body, done)
    nextId = nextId + 1
    local id = nextId
    waiting[id] = done
    if onWeb then
        print("@@PD@@" .. json.encode({
            kind = "http", id = id, method = method, url = url, headers = headers, body = body,
            reply = love.filesystem.getSaveDirectory() .. "/net_" .. id .. ".txt",
        }))
        return
    end
    -- A computer: the body goes in a file, so it needs no quoting.
    startThread()
    local parts = { "curl -s -m 15 -w " .. quote("\n%{http_code}") .. " -X " .. method }
    for k, v in pairs(headers or {}) do
        table.insert(parts, "-H " .. quote(k .. ": " .. v))
    end
    if body then
        local file = "net_body_" .. id .. ".json"
        love.filesystem.write(file, body)
        table.insert(parts, "--data-binary @" .. quote(love.filesystem.getSaveDirectory() .. "/" .. file))
    end
    table.insert(parts, quote(url))
    local command = table.concat(parts, " ")
    -- Windows runs it through cmd.exe, which needs the whole line in one more pair of quotes.
    if love.system.getOS() == "Windows" then command = '"' .. command .. '"' end
    requests:push({ id = id, command = command })
end

-- Copy text to the clipboard.
function net.copy(text)
    if onWeb then
        print("@@PD@@" .. json.encode({ kind = "copy", text = text }))
    else
        love.system.setClipboardText(text)
    end
end

-- Ask for text from the clipboard. On the web the page pops up a box to
-- paste into (browsers won't let a game read the clipboard by itself).
-- done(text) is called with what was pasted ("" if nothing).
function net.paste(prompt, done)
    if onWeb then
        nextId = nextId + 1
        waiting[nextId] = function(_, text) done(text or "") end
        print("@@PD@@" .. json.encode({
            kind = "paste", id = nextId, prompt = prompt,
            reply = love.filesystem.getSaveDirectory() .. "/net_" .. nextId .. ".txt",
        }))
    else
        done(love.system.getClipboardText() or "")
    end
end

-- Check for answers. Call every frame.
function net.update()
    if onWeb then
        for id, done in pairs(waiting) do
            local file = "net_" .. id .. ".txt"
            if love.filesystem.getInfo(file) then
                local text = love.filesystem.read(file) or ""
                love.filesystem.remove(file)
                waiting[id] = nil
                -- First line is the status number, the rest is the answer.
                local status, rest = text:match("^(%d+)\n(.*)$")
                done(tonumber(status) or 0, rest or "")
            end
        end
        return
    end
    if not replies then return end
    while true do
        local reply = replies:pop()
        if not reply then break end
        local done = waiting[reply.id]
        waiting[reply.id] = nil
        love.filesystem.remove("net_body_" .. reply.id .. ".json")
        -- curl adds the status code on the last line (the -w option).
        local text, status = reply.out:match("^(.*)\n(%d+)$")
        if done then done(tonumber(status) or 0, text or "") end
    end
end

return net
