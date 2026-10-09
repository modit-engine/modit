--- @module terminal
--- @file src/planetlua/server/core/terminal.lua
--- @description Non-blocking console line input for the headless server (Windows).

local _ffi = require("ffi")

pcall(_ffi.cdef, "int _kbhit(void); int _getch(void);")
local _crt = _ffi.load("msvcrt")

local PROMPT = "> "

local m = {}

local buffer = ""

--- Prepares the console
function m.init()
    io.stdout:setvbuf("no")
    io.write(PROMPT)
end

--- Reads pending keystrokes and calls on_line for each completed line
--- @param on_line function Receives the typed line
function m.poll(on_line)
    while _crt._kbhit() ~= 0 do
        local key = _crt._getch()
        if key == 0 or key == 224 then
            _crt._getch() -- swallow the second byte of arrow and function keys
        elseif key == 13 then
            io.write("\n")
            local line = buffer
            buffer = ""
            if line:find("%S") then on_line(line) end
            io.write(PROMPT)
        elseif key == 8 then
            if #buffer > 0 then
                buffer = buffer:sub(1, -2)
                io.write("\b \b")
            end
        elseif key >= 32 and key < 127 then
            local character = string.char(key)
            buffer = buffer .. character
            io.write(character)
        end
    end
end

return m