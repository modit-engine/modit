--- @module http
--- @file src/engine/backend/platform/windows/http.lua
--- @description Windows WinHTTP backend for HTTP/HTTPS requests.

--- @section Imports

local _ffi = require("ffi")

--- @section Platform

if _ffi.os ~= "Windows" then error("http backend: Windows only") end

--- @section FFI

_ffi.cdef[[
    typedef void *HINTERNET;
    typedef unsigned short WCHAR;
    typedef unsigned long DWORD;
    typedef int BOOL;

    HINTERNET WinHttpOpen(const WCHAR *user_agent, DWORD access_type, const WCHAR *proxy_name, const WCHAR *proxy_bypass, DWORD flags);
    HINTERNET WinHttpConnect(HINTERNET session, const WCHAR *server_name, unsigned short server_port, DWORD reserved);
    HINTERNET WinHttpOpenRequest(HINTERNET connect, const WCHAR *verb, const WCHAR *object_name, const WCHAR *version, const WCHAR *referrer, const WCHAR **accept_types, DWORD flags);
    BOOL WinHttpSendRequest(HINTERNET request, const WCHAR *headers, DWORD headers_length, void *optional, DWORD optional_length, DWORD total_length, unsigned long long context);
    BOOL WinHttpReceiveResponse(HINTERNET request, void *reserved);
    BOOL WinHttpQueryHeaders(HINTERNET request, DWORD info_level, const WCHAR *name, void *buffer, DWORD *buffer_length, DWORD *index);
    BOOL WinHttpQueryDataAvailable(HINTERNET request, DWORD *bytes_available);
    BOOL WinHttpReadData(HINTERNET request, void *buffer, DWORD bytes_to_read, DWORD *bytes_read);
    BOOL WinHttpCloseHandle(HINTERNET handle);
    DWORD GetLastError(void);
]]

--- @section Constants

local _winhttp = _ffi.load("winhttp")

local WINHTTP_ACCESS_TYPE_NO_PROXY = 1
local WINHTTP_FLAG_SECURE = 0x00800000
local WINHTTP_QUERY_STATUS_CODE = 19
local WINHTTP_QUERY_FLAG_NUMBER = 0x20000000
local DEFAULT_HTTPS_PORT = 443
local DEFAULT_HTTP_PORT = 80
local BUFFER_SIZE = 8192

--- @section Helpers

local function wide(value)
    local buffer = _ffi.new("WCHAR[?]", #value + 1)

    for index = 1, #value do
        local byte = value:byte(index)
        if byte > 127 then return nil, "value contains unsupported non-ASCII characters" end
        buffer[index - 1] = byte
    end

    buffer[#value] = 0
    return buffer
end

local function parse_url(url)
    local scheme, host, port, path = url:match("^([%a][%w+.-]*)://([^/:]+):?(%d*)(/.*)$")

    if not scheme then
        scheme, host = url:match("^([%a][%w+.-]*)://([^/]+)$")
        if not scheme then return nil, "invalid URL" end
        path = "/"
    end

    scheme = scheme:lower()
    if scheme ~= "http" and scheme ~= "https" then return nil, "unsupported URL scheme '" .. scheme .. "'" end

    if port == "" then
        port = scheme == "https" and DEFAULT_HTTPS_PORT or DEFAULT_HTTP_PORT
    else
        port = tonumber(port)
        if not port or port < 1 or port > 65535 then return nil, "invalid URL port" end
    end

    return { scheme = scheme, host = host, port = port, path = path or "/" }
end

local function close(handle)
    if handle then _winhttp.WinHttpCloseHandle(handle) end
end

local function get_status(request)
    local status = _ffi.new("DWORD[1]")
    local length = _ffi.new("DWORD[1]", _ffi.sizeof(status))
    local index = _ffi.new("DWORD[1]", 0)

    if _winhttp.WinHttpQueryHeaders(request, WINHTTP_QUERY_STATUS_CODE + WINHTTP_QUERY_FLAG_NUMBER, nil, status, length, index) == 0 then
        return nil, _winhttp.GetLastError()
    end

    return tonumber(status[0])
end

local function read_body(request)
    local chunks = {}

    while true do
        local available = _ffi.new("DWORD[1]", 0)
        if _winhttp.WinHttpQueryDataAvailable(request, available) == 0 then return nil, _winhttp.GetLastError() end

        local count = tonumber(available[0])
        if count == 0 then break end

        while count > 0 do
            local size = math.min(count, BUFFER_SIZE)
            local buffer = _ffi.new("char[?]", size)
            local read = _ffi.new("DWORD[1]", 0)

            if _winhttp.WinHttpReadData(request, buffer, size, read) == 0 then return nil, _winhttp.GetLastError() end

            local bytes = tonumber(read[0])
            if bytes == 0 then break end

            chunks[#chunks + 1] = _ffi.string(buffer, bytes)
            count = count - bytes
        end
    end

    return table.concat(chunks)
end

--- @section Module

local m = {}

--- @section Functions

--- @param url string
--- @param headers table|nil
--- @return string|nil body
--- @return number|nil status
--- @return string|nil error
function m.get(url, headers)
    if type(url) ~= "string" then return nil, nil, "URL must be a string" end

    local parsed, parse_error = parse_url(url)
    if not parsed then return nil, nil, parse_error end

    local user_agent = wide("Modit")
    local host = wide(parsed.host)
    local path = wide(parsed.path)
    local verb = wide("GET")

    if not user_agent or not host or not path or not verb then return nil, nil, "failed to create request strings" end

    local session = _winhttp.WinHttpOpen(user_agent, WINHTTP_ACCESS_TYPE_NO_PROXY, nil, nil, 0)
    if not session then return nil, nil, "WinHttpOpen failed: " .. _winhttp.GetLastError() end

    local connection = _winhttp.WinHttpConnect(session, host, parsed.port, 0)
    if not connection then
        local error_code = _winhttp.GetLastError()
        close(session)
        return nil, nil, "WinHttpConnect failed: " .. error_code
    end

    local flags = parsed.scheme == "https" and WINHTTP_FLAG_SECURE or 0
    local request = _winhttp.WinHttpOpenRequest(connection, verb, path, nil, nil, nil, flags)

    if not request then
        local error_code = _winhttp.GetLastError()
        close(connection)
        close(session)
        return nil, nil, "WinHttpOpenRequest failed: " .. error_code
    end

    local header_buffer

    if headers then
        local values = {}
        for name, value in pairs(headers) do values[#values + 1] = tostring(name) .. ": " .. tostring(value) end
        if #values > 0 then header_buffer = wide(table.concat(values, "\r\n")) end
    end

    if _winhttp.WinHttpSendRequest(request, header_buffer, header_buffer and -1 or 0, nil, 0, 0, 0) == 0 then
        local error_code = _winhttp.GetLastError()
        close(request)
        close(connection)
        close(session)
        return nil, nil, "WinHttpSendRequest failed: " .. error_code
    end

    if _winhttp.WinHttpReceiveResponse(request, nil) == 0 then
        local error_code = _winhttp.GetLastError()
        close(request)
        close(connection)
        close(session)
        return nil, nil, "WinHttpReceiveResponse failed: " .. error_code
    end

    local status, status_error = get_status(request)

    if not status then
        close(request)
        close(connection)
        close(session)
        return nil, nil, "failed to read HTTP status: " .. status_error
    end

    local body, body_error = read_body(request)

    close(request)
    close(connection)
    close(session)

    if not body then return nil, status, "failed to read response: " .. body_error end

    return body, status
end

return m