-- net.lua
-- Talking to the internet (the online leaderboard), and the clipboard.
--
-- LÖVE 11 can't fetch web pages by itself, so:
--   * ON A COMPUTER: a background thread runs Windows' (or Mac/Linux's)
--     built-in "curl" program, so the game never freezes while it waits.
--     On Windows it's started directly with "no window" (through LuaJIT's
--     FFI, which can call Windows itself), so no console window flashes up.
--     curl writes the answer and its headers into files, which we read.
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
local THREAD_CODE = [==[
local requests, replies = ...

-- On Windows: start a program with NO window, and wait for it to finish.
local runHidden
if jit and jit.os == "Windows" then
    local ffi = require("ffi")
    ffi.cdef[[
        typedef struct {
            uint32_t cb; void* lpReserved; void* lpDesktop; void* lpTitle;
            uint32_t dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
            uint16_t wShowWindow, cbReserved2; void* lpReserved2;
            void* hStdInput; void* hStdOutput; void* hStdError;
        } PD_STARTUPINFOA;
        typedef struct { void* hProcess; void* hThread; uint32_t dwProcessId, dwThreadId; } PD_PROCESS_INFORMATION;
        int CreateProcessA(const char* app, char* cmd, void* pa, void* ta, int inherit, uint32_t flags,
            void* env, const char* dir, PD_STARTUPINFOA* si, PD_PROCESS_INFORMATION* pi);
        uint32_t WaitForSingleObject(void* handle, uint32_t ms);
        int CloseHandle(void* handle);
    ]]
    local CREATE_NO_WINDOW, STARTF_USESHOWWINDOW, SW_HIDE = 0x08000000, 1, 0
    runHidden = function(command)
        local si = ffi.new("PD_STARTUPINFOA")
        si.cb = ffi.sizeof(si)
        si.dwFlags = STARTF_USESHOWWINDOW
        si.wShowWindow = SW_HIDE
        local pi = ffi.new("PD_PROCESS_INFORMATION")
        local line = ffi.new("char[?]", #command + 1, command)
        if ffi.C.CreateProcessA(nil, line, nil, nil, 0, CREATE_NO_WINDOW, nil, nil, si, pi) == 0 then
            return false
        end
        ffi.C.WaitForSingleObject(pi.hProcess, 30000)
        ffi.C.CloseHandle(pi.hProcess)
        ffi.C.CloseHandle(pi.hThread)
        return true
    end
end

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return "" end
    local text = f:read("*a")
    f:close()
    os.remove(path)
    return text
end

while true do
    local job = requests:demand()
    if runHidden then
        runHidden(job.command)
    else
        local f = io.popen(job.command)
        if f then f:read("*a"); f:close() end
    end
    -- The status is on the headers' "HTTP/1.1 200 OK" line (the last one,
    -- in case there was a "100 Continue" first).
    local status = 0
    for code in readFile(job.headFile):gmatch("HTTP/[%d%.]+ (%d%d%d)") do status = tonumber(code) end
    replies:push({ id = job.id, status = status, out = readFile(job.bodyFile) })
end
]==]
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
        love.filesystem.write("net_ready.txt", "")   -- makes sure the save folder exists
        print("@@PD@@" .. json.encode({
            kind = "http", id = id, method = method, url = url, headers = headers, body = body,
            reply = love.filesystem.getSaveDirectory() .. "/net_" .. id .. ".txt",
        }))
        return
    end
    -- A computer: what we send, and curl's answer and headers, all go
    -- through files in the save folder (so nothing needs tricky quoting).
    startThread()
    local dir = love.filesystem.getSaveDirectory()
    love.filesystem.write("net_ready.txt", "")   -- makes sure the save folder exists
    local bodyFile, headFile = dir .. "/net_out_" .. id .. ".txt", dir .. "/net_head_" .. id .. ".txt"
    local parts = { "curl -s -m 15 -o " .. quote(bodyFile) .. " -D " .. quote(headFile) .. " -X " .. method }
    for k, v in pairs(headers or {}) do
        table.insert(parts, "-H " .. quote(k .. ": " .. v))
    end
    if body then
        local file = "net_body_" .. id .. ".json"
        love.filesystem.write(file, body)
        table.insert(parts, "--data-binary @" .. quote(love.filesystem.getSaveDirectory() .. "/" .. file))
    end
    table.insert(parts, quote(url))
    requests:push({ id = id, command = table.concat(parts, " "), bodyFile = bodyFile, headFile = headFile })
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
        love.filesystem.write("net_ready.txt", "")   -- makes sure the save folder exists
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
        if done then done(reply.status or 0, reply.out or "") end
    end
end

return net
