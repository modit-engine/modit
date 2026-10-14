--- @module process
--- @file src/engine/backend/platform/windows/process.lua
--- @description Windows platform process execution and management.

--- @section Imports

local _ffi = require("ffi")

--- @section FFI

_ffi.cdef[[
    typedef struct {
        uint32_t cb;
        char *lpReserved;
        char *lpDesktop;
        char *lpTitle;
        uint32_t dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
        uint16_t wShowWindow, cbReserved2;
        uint8_t *lpReserved2;
        void *hStdInput, *hStdOutput, *hStdError;
    } STARTUPINFOA;

    typedef struct {
        void *hProcess;
        void *hThread;
        uint32_t dwProcessId;
        uint32_t dwThreadId;
    } PROCESS_INFORMATION;

    int CreateProcessA(const char *app, char *cmdline, void *pattr, void *tattr, int inherit,
                       uint32_t flags, void *env, const char *cwd, STARTUPINFOA *si, PROCESS_INFORMATION *pi);
    int GetExitCodeProcess(void *process, uint32_t *code);
    int TerminateProcess(void *process, uint32_t code);
    int CloseHandle(void *handle);
    uint32_t GetLastError(void);
]]

--- @section Constants & State

local STILL_ACTIVE = 259
local exit_code_buffer = _ffi.new("uint32_t[1]")

--- @section Module

local m = {}

--- @section Process Management

--- Starts a new child process given a command line string
--- @param cmdline string Command line string to execute
--- @return cdata|nil handle Process handle or nil on failure
--- @return string|nil err Error message string on failure
function m.start(cmdline)
    local startup_info = _ffi.new("STARTUPINFOA")
    startup_info.cb = _ffi.sizeof(startup_info)
    local process_info = _ffi.new("PROCESS_INFORMATION")
    local cmd_buffer = _ffi.new("char[?]", #cmdline + 1, cmdline)

    if _ffi.C.CreateProcessA(nil, cmd_buffer, nil, nil, 0, 0, nil, nil, startup_info, process_info) == 0 then
        return nil, "CreateProcess failed (error " .. _ffi.C.GetLastError() .. ")"
    end

    _ffi.C.CloseHandle(process_info.hThread)
    return process_info.hProcess
end

--- Checks if target process handle is actively running
--- @param handle cdata Native process handle
--- @return boolean is_running True if process is currently running
function m.running(handle)
    if _ffi.C.GetExitCodeProcess(handle, exit_code_buffer) == 0 then
        return false
    end
    return exit_code_buffer[0] == STILL_ACTIVE
end

--- Terminates process if active and releases native process handle
--- @param handle cdata Native process handle
function m.kill(handle)
    _ffi.C.TerminateProcess(handle, 1)
    _ffi.C.CloseHandle(handle)
end

return m