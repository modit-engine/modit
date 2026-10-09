--- Copies dropped files/folders into a project. Existing items are never overwritten.
local ffi = require("ffi")
local bit = require("bit")
local m = {}
if ffi.os ~= "Windows" then
    function m.copy() return nil, "File import is currently supported on Windows." end
    return m
end

ffi.cdef[[
typedef struct {
    uint32_t attributes; uint32_t times[6]; uint32_t size_high, size_low;
    uint32_t reserved[2]; wchar_t name[260]; wchar_t alternate[14];
} EditorImportFindData;
int MultiByteToWideChar(unsigned int, unsigned int, const char *, int, wchar_t *, int);
int WideCharToMultiByte(unsigned int, unsigned long, const wchar_t *, int, char *, int, const char *, int *);
uint32_t GetFullPathNameW(const wchar_t *, uint32_t, wchar_t *, wchar_t **);
uint32_t GetFileAttributesW(const wchar_t *);
void *FindFirstFileW(const wchar_t *, EditorImportFindData *);
int FindNextFileW(void *, EditorImportFindData *);
int FindClose(void *);
int CreateDirectoryW(const wchar_t *, void *);
int CopyFileW(const wchar_t *, const wchar_t *, int);
]]

local function wide(text)
    local n = ffi.C.MultiByteToWideChar(65001,0,text,-1,nil,0)
    local out = ffi.new("wchar_t[?]",math.max(1,n))
    ffi.C.MultiByteToWideChar(65001,0,text,-1,out,n)
    return out
end
local function utf8(text)
    local n = ffi.C.WideCharToMultiByte(65001,0,text,-1,nil,0,nil,nil)
    local out = ffi.new("char[?]",math.max(1,n))
    ffi.C.WideCharToMultiByte(65001,0,text,-1,out,n,nil,nil)
    return ffi.string(out)
end
local function absolute(path)
    local out = ffi.new("wchar_t[32768]")
    local n = ffi.C.GetFullPathNameW(wide(path),32768,out,nil)
    if n == 0 or n >= 32768 then return end
    return utf8(out):gsub("\\", "/"):gsub("/+$", "")
end
local function attributes(path)
    local a = ffi.C.GetFileAttributesW(wide(path))
    if a ~= 0xFFFFFFFF then return a end
end
local function inside(path, parent)
    path, parent = path:lower(), parent:lower()
    return path == parent or path:sub(1,#parent+1) == parent .. "/"
end

local function collect(source, relative, plan)
    local a = attributes(source)
    assert(a, "Cannot read: " .. source)
    assert(bit.band(a,0x400)==0, "Cannot import links or junctions: " .. source)
    local directory = bit.band(a,0x10)~=0
    plan[#plan+1] = {source=source, relative=relative, directory=directory}
    if not directory then return end
    local data = ffi.new("EditorImportFindData[1]")
    local handle = ffi.C.FindFirstFileW(wide(source .. "/*"),data)
    assert(ffi.cast("intptr_t",handle)~=-1, "Cannot read folder: " .. source)
    -- Gather entries before recursing so all native handles are closed on errors.
    local names = {}
    repeat
        local name = utf8(data[0].name)
        if name~="." and name~=".." then names[#names+1]=name end
    until ffi.C.FindNextFileW(handle,data)==0
    ffi.C.FindClose(handle)
    for _,name in ipairs(names) do collect(source.."/"..name,relative.."/"..name,plan) end
end

function m.copy(paths, destination, project)
    local copied = 0
    local ok, err = pcall(function()
        destination, project = absolute(destination), absolute(project)
        assert(destination and project and inside(destination,project), "Choose a folder inside the project.")
        -- Reject destination junctions that could lead outside the project.
        local check = destination
        while inside(check,project) do
            local a = attributes(check)
            assert(a and bit.band(a,0x10)~=0 and bit.band(a,0x400)==0, "Destination is not a regular folder: " .. check)
            if check==project then break end
            check=check:match("^(.*)/[^/]+$")
        end
        for _,path in ipairs(paths) do
            local source = assert(absolute(path), "Invalid source path")
            local a = assert(attributes(source), "Source no longer exists: " .. source)
            local directory = bit.band(a,0x10)~=0
            assert(not directory or not inside(destination,source), "Cannot import a folder into itself: " .. source)
            local name = assert(source:match("([^/]+)$"), "Cannot import a drive root")
            local stem, extension = name, ""
            if not directory then stem,extension=name:match("^(.*)(%.[^%.]+)$");stem,extension=stem or name,extension or "" end
            local target, number = destination.."/"..name, 2
            while attributes(target) do
                target=destination.."/"..stem.." ("..number..")"..extension;number=number+1
            end
            local plan = {}
            collect(source,"",plan)
            for _,entry in ipairs(plan) do
                local dest=target..entry.relative
                if entry.directory then
                    assert(ffi.C.CreateDirectoryW(wide(dest),nil)~=0, "Could not create: " .. dest)
                else
                    assert(ffi.C.CopyFileW(wide(entry.source),wide(dest),1)~=0, "Could not copy: " .. entry.source)
                end
            end
            copied=copied+1
        end
    end)
    if not ok then return nil, tostring(err), copied end
    return copied
end
return m
