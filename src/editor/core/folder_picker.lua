--- @module folder_picker
--- @description Editor-only Explorer-style Windows folder selection.

local ffi = require("ffi")
local bit = require("bit")
local m = {}

if ffi.os ~= "Windows" then
    function m.choose() return nil, "Folder selection is only available on Windows." end
    return m
end

-- IFileOpenDialog with FOS_PICKFOLDERS uses the modern Common Item Dialog.
-- https://learn.microsoft.com/windows/win32/shell/common-file-dialog
ffi.cdef[[
    typedef struct { uint32_t a; uint16_t b, c; uint8_t d[8]; } MODIT_EDITOR_GUID;
    long __stdcall CLSIDFromString(const uint16_t *text, MODIT_EDITOR_GUID *id);
    long __stdcall CoCreateInstance(const MODIT_EDITOR_GUID *clsid, void *outer,
        unsigned long context, const MODIT_EDITOR_GUID *iid, void **object);
    long __stdcall OleInitialize(void *reserved);
    void __stdcall OleUninitialize(void);
    void __stdcall CoTaskMemFree(void *memory);
    void * __stdcall GetActiveWindow(void);
    int __stdcall WideCharToMultiByte(unsigned int page, unsigned long flags,
        const uint16_t *wide, int length, char *text, int capacity,
        const char *fallback, int *used_fallback);
]]

local ole = ffi.load("ole32")
local user = ffi.load("user32")
local kernel = ffi.load("kernel32")
local CANCELLED = bit.tobit(0x800704c7)

-- All strings supplied to the dialog here are ASCII constants.
local function wide(text)
    local result = ffi.new("uint16_t[?]", #text + 1)
    for i = 1, #text do result[i - 1] = text:byte(i) end
    return result
end

local function guid(text)
    local result = ffi.new("MODIT_EDITOR_GUID[1]")
    assert(ole.CLSIDFromString(wide(text), result) >= 0)
    return result
end

local CLSID = guid("{DC1C5A9C-E88A-4DDE-A5A1-60F82A20AEF7}")
local IID = guid("{D57C7288-D4AD-4768-BE02-9D969532D960}")

-- COM vtable slots include inherited IUnknown and IModalWindow methods.
local function method(object, slot, signature)
    return ffi.cast(signature, ffi.cast("void ***", object)[0][slot])
end

local function release(object)
    if object ~= nil then
        method(object, 2, "unsigned long (__stdcall *)(void *)")(object)
    end
end

local function check(result, message)
    if result < 0 then error(message, 0) end
end

--- Returns the parent folder, nil on cancellation, or nil and an error.
function m.choose()
    if ole.OleInitialize(nil) < 0 then
        return nil, "Could not initialise the Windows folder picker."
    end
    local dialog = ffi.new("void *[1]")
    local item = ffi.new("void *[1]")
    local path = ffi.new("uint16_t *[1]")
    local ok, result = pcall(function()
        check(ole.CoCreateInstance(CLSID, nil, 1, IID, dialog), "Could not open the Windows folder picker.")
        local d = dialog[0]
        local options = ffi.new("unsigned long[1]")
        check(method(d, 10, "long (__stdcall *)(void *, unsigned long *)")(d, options), "Could not read folder picker options.")
        -- Pick folders, require filesystem paths, preserve the engine working directory.
        check(method(d, 9, "long (__stdcall *)(void *, unsigned long)")(d, bit.bor(options[0], 0x20, 0x40, 0x8)), "Could not configure the folder picker.")
        check(method(d, 17, "long (__stdcall *)(void *, const uint16_t *)")(d, wide("Choose where to create your project")), "Could not set the folder picker title.")
        check(method(d, 18, "long (__stdcall *)(void *, const uint16_t *)")(d, wide("Select Folder")), "Could not set the folder picker button.")
        local shown = method(d, 3, "long (__stdcall *)(void *, void *)")(d, user.GetActiveWindow())
        if shown == CANCELLED then return nil end
        check(shown, "The folder picker could not be shown.")
        check(method(d, 20, "long (__stdcall *)(void *, void **)")(d, item), "Could not read the selected folder.")
        -- IShellItem::GetDisplayName(SIGDN_FILESYSPATH).
        check(method(item[0], 5, "long (__stdcall *)(void *, unsigned int, uint16_t **)")(item[0], 0x80058000, path), "Choose a filesystem folder.")
        -- Match the existing engine's ANSI filesystem API; reject lossy paths.
        local used_fallback = ffi.new("int[1]")
        local size = kernel.WideCharToMultiByte(0, 0, path[0], -1, nil, 0, nil, used_fallback)
        if size == 0 then error("Could not read the folder path.", 0) end
        local text = ffi.new("char[?]", size)
        if kernel.WideCharToMultiByte(0, 0, path[0], -1, text, size, nil, used_fallback) == 0 or used_fallback[0] ~= 0 then
            error("This folder path contains characters the engine cannot currently use.", 0)
        end
        return (ffi.string(text):gsub("\\", "/"))
    end)
    if path[0] ~= nil then ole.CoTaskMemFree(path[0]) end
    release(item[0])
    release(dialog[0])
    ole.OleUninitialize()
    if not ok then return nil, tostring(result) end
    return result
end

return m
