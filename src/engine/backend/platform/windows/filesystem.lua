--- @module filesystem
--- @file src/engine/backend/platform/windows/filesystem.lua
--- @description Windows platform Win32 API filesystem operations.

--- @section Imports

local _ffi = require("ffi")
local _bit = require("bit")

--- @section FFI Definitions

_ffi.cdef[[
    typedef struct {
        uint32_t dwFileAttributes;
        uint32_t ftCreationTime[2];
        uint32_t ftLastAccessTime[2];
        uint32_t ftLastWriteTime[2];
        uint32_t nFileSizeHigh;
        uint32_t nFileSizeLow;
        uint32_t dwReserved0;
        uint32_t dwReserved1;
        char cFileName[260];
        char cAlternateFileName[14];
    } WIN32_FIND_DATAA;

    void *FindFirstFileA(const char *pattern, WIN32_FIND_DATAA *data);
    int FindNextFileA(void *handle, WIN32_FIND_DATAA *data);
    int FindClose(void *handle);

    int CreateDirectoryA(const char *path, void *security);
    int RemoveDirectoryA(const char *path);
    int DeleteFileA(const char *path);
    int MoveFileExA(const char *from, const char *to, uint32_t flags);
    uint32_t GetFileAttributesA(const char *path);
    int SetFileAttributesA(const char *path, uint32_t attrs);
]]

--- @section Constants & State

local ATTR_DIRECTORY = 0x10
local ATTR_NORMAL = 0x80
local ATTR_REPARSE = 0x400
local INVALID_ATTRS = 0xFFFFFFFF
local MOVE_REPLACE_EXISTING = 0x1

local find_data_buffer = _ffi.new("WIN32_FIND_DATAA")

--- @section Helpers

--- Validates that path string is safe and does not escape context or wipe drives
--- @param path string Path string to validate
--- @return boolean is_safe True if path is safe for filesystem operations
local function is_safe_path(path)
    if type(path) ~= "string" or path == "" or path == "." then return false end
    if path:match("^[/\\]+(") or path:match("^%a:[/\\]*)") then return false end
    for part in path:gmatch("[^/\\]+") do
        if part == ".." then return false end
    end
    return true
end

--- Retrieves Win32 file attribute bitmask for a given path
--- @param path string Target path string
--- @return number|nil attributes Attribute flags or nil if path does not exist
local function get_file_attributes(path)
    local attrs = _ffi.C.GetFileAttributesA(path)
    if attrs == INVALID_ATTRS then return nil end
    return attrs
end

--- Resets file attributes to normal to allow deletion of read-only entities
--- @param path string Target file or directory path
local function clear_readonly_attribute(path)
    _ffi.C.SetFileAttributesA(path, ATTR_NORMAL)
end

--- @section Module

local m = {}

--- @section Directory Listing

--- Lists directory entries sorted by folders first, then files
--- @param path string Directory path to inspect
--- @return table entries List of entry tables containing name and dir flag
function m.list(path)
    local directories, files = {}, {}

    local handle = _ffi.C.FindFirstFileA(path .. "/*", find_data_buffer)
    if handle == nil or tonumber(_ffi.cast("intptr_t", handle)) == -1 then
        return directories
    end

    repeat
        local entry_name = _ffi.string(find_data_buffer.cFileName)
        if entry_name ~= "." and entry_name ~= ".." then
            if _bit.band(find_data_buffer.dwFileAttributes, ATTR_DIRECTORY) ~= 0 then
                directories[#directories + 1] = { name = entry_name, dir = true }
            else
                files[#files + 1] = { name = entry_name, dir = false }
            end
        end
    until _ffi.C.FindNextFileA(handle, find_data_buffer) == 0

    _ffi.C.FindClose(handle)

    local function by_name_case_insensitive(a, b)
        return a.name:lower() < b.name:lower()
    end
    table.sort(directories, by_name_case_insensitive)
    table.sort(files, by_name_case_insensitive)

    for i = 1, #files do
        directories[#directories + 1] = files[i]
    end

    return directories
end

--- Lists names of subdirectories in target directory path
--- @param path string Directory path to inspect
--- @return table dir_names List of subdirectory name strings
function m.list_dirs(path)
    local subdirectories = {}
    for _, entry in ipairs(m.list(path)) do
        if entry.dir then
            subdirectories[#subdirectories + 1] = entry.name
        end
    end
    return subdirectories
end

--- @section Path Queries

--- Checks whether a file or directory exists
--- @param path string Path to check
--- @return boolean exists True if entity exists
function m.exists(path)
    return get_file_attributes(path) ~= nil
end

--- Checks whether path points to a directory
--- @param path string Path to check
--- @return boolean is_directory True if entity exists and is a directory
function m.is_dir(path)
    local attrs = get_file_attributes(path)
    return attrs ~= nil and _bit.band(attrs, ATTR_DIRECTORY) ~= 0
end

--- Checks whether path points to a file
--- @param path string Path to check
--- @return boolean is_file True if entity exists and is a regular file
function m.is_file(path)
    local attrs = get_file_attributes(path)
    return attrs ~= nil and _bit.band(attrs, ATTR_DIRECTORY) == 0
end

--- @section Directory Operations

--- Creates a single directory (parent must exist)
--- @param path string Directory path to create
--- @return boolean ok True if directory creation succeeded
function m.create_dir(path)
    return _ffi.C.CreateDirectoryA(path, nil) ~= 0
end

--- Recursively ensures directory path exists, creating missing parent folders
--- @param path string Directory path to ensure
--- @return boolean ok True if directory exists after operation
function m.ensure_dir(path)
    local accumulated_path = path:match("^[/\\]") and "/" or ""
    for segment in path:gmatch("[^/\\]+") do
        accumulated_path = (accumulated_path == "" or accumulated_path == "/") and (accumulated_path .. segment) or (accumulated_path .. "/" .. segment)
        if not segment:match("^%a:$") then
            _ffi.C.CreateDirectoryA(accumulated_path, nil)
        end
    end
    return m.is_dir(path)
end

--- Recursively deletes a directory and all contained files and subfolders
--- @param path string Target directory path to remove
--- @return boolean ok True if removal succeeded
--- @return string|nil err Error message string on failure
function m.remove_dir(path)
    if not is_safe_path(path) then
        return false, "Refusing to delete: " .. tostring(path)
    end

    local attrs = get_file_attributes(path)
    if not attrs then
        return false, "Not found: " .. path
    end
    if _bit.band(attrs, ATTR_DIRECTORY) == 0 then
        return false, "Not a folder: " .. path
    end

    if _bit.band(attrs, ATTR_REPARSE) == 0 then
        for _, entry in ipairs(m.list(path)) do
            local child_path = path .. "/" .. entry.name
            local ok, err
            if entry.dir then
                ok, err = m.remove_dir(child_path)
            else
                ok, err = m.remove_file(child_path)
            end
            if not ok then
                return false, err
            end
        end
    end

    clear_readonly_attribute(path)
    if _ffi.C.RemoveDirectoryA(path) == 0 then
        return false, "Could not delete folder: " .. path
    end
    return true
end

--- @section File Operations

--- Reads entire file contents as a binary string
--- @param path string File path to read
--- @return string|nil contents File content string or nil on failure
--- @return string|nil err Error message string on failure
function m.read_file(path)
    local file_handle, err = io.open(path, "rb")
    if not file_handle then return nil, err end
    local content = file_handle:read("*a")
    file_handle:close()
    return content
end

--- Writes string contents to a file atomically via a temporary file
--- @param path string Target file path
--- @param text string Content string to write
--- @return boolean ok True if write succeeded
--- @return string|nil err Error message string on failure
function m.write_file(path, text)
    local temp_path = path .. ".tmp"

    local file_handle, err = io.open(temp_path, "wb")
    if not file_handle then return false, err end

    local ok, write_err = file_handle:write(text)
    file_handle:close()
    if not ok then
        m.remove_file(temp_path)
        return false, write_err
    end

    if _ffi.C.MoveFileExA(temp_path, path, MOVE_REPLACE_EXISTING) == 0 then
        m.remove_file(temp_path)
        return false, "Could not write file: " .. path
    end
    return true
end

--- Creates a new empty file
--- @param path string Target file path
--- @return boolean ok True if creation succeeded
--- @return string|nil err Error message string on failure
function m.create_file(path)
    if m.exists(path) then
        return false, "Already exists: " .. path
    end
    return m.write_file(path, "")
end

--- Removes a single file
--- @param path string Target file path
--- @return boolean ok True if removal succeeded
--- @return string|nil err Error message string on failure
function m.remove_file(path)
    if not is_safe_path(path) then
        return false, "Refusing to delete: " .. tostring(path)
    end
    clear_readonly_attribute(path)
    if _ffi.C.DeleteFileA(path) == 0 then
        return false, "Could not delete file: " .. path
    end
    return true
end

--- Renames or moves a file or folder
--- @param from string Original path
--- @param to string Target path
--- @return boolean ok True if operation succeeded
--- @return string|nil err Error message string on failure
function m.rename(from, to)
    if not is_safe_path(from) or not is_safe_path(to) then
        return false, "Invalid path"
    end
    if m.exists(to) then
        return false, "Already exists: " .. to
    end
    if _ffi.C.MoveFileExA(from, to, 0) == 0 then
        return false, "Could not rename: " .. from
    end
    return true
end

return m