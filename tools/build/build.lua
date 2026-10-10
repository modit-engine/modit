
--- @script build
--- @file tools/build/build.lua
--- @description Packages a project into a standalone game folder.

--- @section Constants

local IS_WINDOWS = package.config:sub(1, 1) == "\\"
local MAGIC = "MODITPK1"
local STUB_NAME = "modit_stub.exe"
local RUNTIME_DLLS = { "lua51.dll", "raylib.dll" }

local USAGE = [[
usage: luajit tools/build/build.lua <project> [options]

  --target <target>  build target: client or server (default: client)
  --name <name>      executable name (default: project folder name)
  --out <folder>     output folder (default: <project>/build/<name>)
  --console          show a console window
  --no-console       hide the console window
  --bytecode         embed LuaJIT bytecode instead of source
  --no-mods          do not copy the project's mods folder
  --rebuild-stub     recompile the launcher stub (needs Visual Studio C++ tools)
  --stub <path>      use this launcher stub instead of src/bin/modit_stub.exe
  --log <file>       also write build output to a file
]]

--- @section Paths

local script_dir = (arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
local ROOT = script_dir .. "/../.."

--- @section Options

local opts = { mods = true, target = "client" }

do
    local index = 1

    local function value_of(flag)
        index = index + 1
        local value = arg[index]
        if not value then
            print("missing value for " .. flag)
            os.exit(1)
        end
        return value
    end

    while index <= #arg do
        local flag = arg[index]

        if flag == "--target" then opts.target = value_of(flag)
        elseif flag == "--name" then opts.name = value_of(flag)
        elseif flag == "--out" then opts.out = value_of(flag)
        elseif flag == "--console" then opts.console = true
        elseif flag == "--no-console" then opts.console = false
        elseif flag == "--bytecode" then opts.bytecode = true
        elseif flag == "--no-mods" then opts.mods = false
        elseif flag == "--rebuild-stub" then opts.rebuild_stub = true
        elseif flag == "--stub" then opts.stub = value_of(flag)
        elseif flag == "--log" then opts.log = value_of(flag)
        elseif flag:sub(1, 2) == "--" then
            print("unknown option: " .. flag)
            print(USAGE)
            os.exit(1)
        elseif not opts.project then
            opts.project = flag
        end

        index = index + 1
    end
end

if not opts.project then
    print(USAGE)
    os.exit(1)
end

if opts.target ~= "client" and opts.target ~= "server" then
    print("invalid target '" .. tostring(opts.target) .. "' (expected client or server)")
    print(USAGE)
    os.exit(1)
end

local project = opts.project:gsub("[/\\]+$", "")

--- @section Logging

local log_file = opts.log and io.open(opts.log, "w")
if log_file then log_file:setvbuf("line") end

--- Prints a build message, and mirrors it to the editor log file when --log is set
--- @param level string "info", "success", "warn" or "error"
--- @param text string Message
local function emit(level, text)
    print("[BUILD] " .. text)

    if log_file then
        for line in (text .. "\n"):gmatch("(.-)\n") do
            log_file:write(level, "\t", os.date("%H:%M:%S"), "\t", line, "\n")
        end
        log_file:flush()
    end
end

--- Logs an error and exits
local function fail(text)
    emit("error", text)
    if log_file then log_file:close() end
    os.exit(1)
end

--- @section File Helpers

local function read_file(path)
    local handle = io.open(path, "rb")
    if not handle then return nil end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function write_file(path, content)
    local handle = io.open(path, "wb")
    if not handle then return false end
    handle:write(content)
    handle:close()
    return true
end

local function native(path)
    if IS_WINDOWS then return (path:gsub("/", "\\")) end
    return path
end

--- Runs a command through the shell and returns its exit code
local function run(command)
    local code = os.execute('"' .. command .. '"')
    if code == true then return 0 end
    if type(code) == "number" then return code end
    return 1
end

local made_dirs = {}

local function make_dir(path)
    if made_dirs[path] then return end
    made_dirs[path] = true

    if IS_WINDOWS then
        os.execute('mkdir "' .. native(path) .. '" 2>nul')
    else
        os.execute('mkdir -p "' .. path .. '"')
    end
end

local function copy_file(from, to)
    local content = read_file(from)
    if not content then return false end

    local parent = to:match("^(.*)[/\\][^/\\]*$")
    if parent then make_dir(parent) end

    return write_file(to, content)
end

--- Lists the files or folders directly inside a folder, sorted
local function list_dir(path, folders)
    local command
    if IS_WINDOWS then
        command = ("dir %s /b \"%s\" 2>nul"):format(folders and "/a:d" or "/a:-d", native(path))
    else
        command = ("find \"%s\" -mindepth 1 -maxdepth 1 -type %s -printf '%%f\\n' 2>/dev/null")
            :format(path, folders and "d" or "f")
    end

    local names = {}
    local pipe = io.popen(command)
    if not pipe then return names end

    for line in pipe:lines() do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" then names[#names + 1] = line end
    end
    pipe:close()

    table.sort(names)
    return names
end

--- Collects every .lua file under a folder as key -> disk path
local function scan_lua(dir, prefix, into)
    for _, file in ipairs(list_dir(dir, false)) do
        if file:match("%.lua$") then
            into[prefix .. file] = dir .. "/" .. file
        end
    end

    for _, folder in ipairs(list_dir(dir, true)) do
        if folder:sub(1, 1) ~= "." then
            scan_lua(dir .. "/" .. folder, prefix .. folder .. "/", into)
        end
    end
end

--- Copies a folder tree. skip(relative, is_folder) returns true to leave something out
local function copy_tree(from, to, relative, skip, counter)
    for _, file in ipairs(list_dir(from, false)) do
        local rel = relative .. file
        if file:sub(1, 1) ~= "." and not skip(rel, false) then
            if copy_file(from .. "/" .. file, to .. "/" .. file) then
                counter.files = counter.files + 1
            else
                emit("warn", "could not copy " .. rel)
            end
        end
    end

    for _, folder in ipairs(list_dir(from, true)) do
        local rel = relative .. folder .. "/"
        if folder:sub(1, 1) ~= "." and not skip(rel, true) then
            copy_tree(from .. "/" .. folder, to .. "/" .. folder, rel, skip, counter)
        end
    end
end

--- @section Launcher Stub

--- Finds vcvars64.bat, which sets up the Visual Studio compiler environment
local function find_vcvars()
    local override = os.getenv("VCVARS")
    if override then return override end

    local program_files = os.getenv("ProgramFiles(x86)") or "C:\\Program Files (x86)"
    local vswhere = program_files .. "\\Microsoft Visual Studio\\Installer\\vswhere.exe"

    local pipe = io.popen('""' .. vswhere .. '" -latest -products * '
        .. '-requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 '
        .. '-property installationPath 2>nul"')
    if not pipe then return nil end

    local install = pipe:read("*l")
    pipe:close()
    if not install or install == "" then return nil end

    local vcvars = install:gsub("%s+$", "") .. "\\VC\\Auxiliary\\Build\\vcvars64.bat"
    if read_file(vcvars) then return vcvars end
end

--- Compiles the stub (tools/build/stub_source.lua) once and caches it in src/bin
local function build_stub(cache_path)
    if not IS_WINDOWS then
        fail("the launcher stub can only be compiled on Windows. Pass --stub <path> instead.")
    end

    emit("info", "Compiling the launcher stub (one time only)...")

    local include = os.getenv("LUA_INCLUDE") or "C:\\luajit\\src"
    local library = os.getenv("LUA_LIB") or "C:\\luajit\\src\\lua51.lib"
    -- Installed LuaJIT distributions usually keep headers and libraries beside bin.
    local executable = (arg[-1] or ""):gsub("\\", "/")
    local install_root = executable:match("^(.*)/bin/[^/]+$")
    if install_root then
        if not os.getenv("LUA_INCLUDE") and not read_file(include .. "/lua.h") then
            include = install_root .. "/include"
        end
        if not os.getenv("LUA_LIB") and not read_file(library) then
            library = install_root .. "/lib/lua51.lib"
        end
    end
    if not read_file(include .. "/lua.h") or not read_file(library) then
        fail("LuaJIT development files were not found. Set LUA_INCLUDE to the folder containing lua.h "
            .. "and LUA_LIB to lua51.lib. Checked: " .. include .. " and " .. library)
    end

    local temp = (os.getenv("TEMP") or ".") .. "\\modit_build"
    make_dir(temp)

    local setup = ""
    if not os.getenv("VSCMD_VER") then
        local vcvars = find_vcvars()
        if not vcvars then
            fail("could not find Visual Studio with the C++ tools.\n"
                .. "Install 'Desktop development with C++', or set VCVARS to your vcvars64.bat path.")
        end
        setup = ('call "%s" >nul 2>&1\r\nif errorlevel 1 exit /b 1\r\n'):format(vcvars)
    end

    local stub_source = loadfile(ROOT .. "/tools/build/stub_source.lua")
    if not stub_source then fail("tools/build/stub_source.lua not found") end

    local source = temp .. "\\stub.c"
    write_file(source, stub_source())

    local script = "@echo off\r\n" .. setup
        .. ('cl /nologo /O2 /MT /I"%s" "%s" /Fo"%s\\stub.obj" /Fe"%s\\stub.exe" /link "%s" user32.lib\r\n')
            :format(include, source, temp, temp, library)
        .. "exit /b %errorlevel%\r\n"

    local bat = temp .. "\\build_stub.bat"
    local log = temp .. "\\build_stub.log"
    write_file(bat, script)

    local code = run('"' .. bat .. '" > "' .. log .. '" 2>&1')
    local output = read_file(log) or ""

    if code ~= 0 then
        fail("compiling the stub failed:\n" .. output)
    end

    local built = read_file(temp .. "\\stub.exe")
    if not built then fail("the compiler did not produce a stub") end

    make_dir(ROOT .. "/src/bin")
    if not write_file(cache_path, built) then fail("could not cache launcher: " .. cache_path) end
    emit("success", "Launcher stub ready: " .. cache_path)
    return built
end

--- Returns the launcher stub bytes, compiling it first if needed
local function get_stub()
    if opts.stub then
        local custom = read_file(opts.stub)
        if not custom then fail("could not read stub: " .. opts.stub) end
        return custom
    end

    local cache_path = ROOT .. "/src/bin/" .. STUB_NAME
    if not opts.rebuild_stub then
        local cached = read_file(cache_path)
        if cached then return cached end
    end

    return build_stub(cache_path)
end

--- Switches a Windows exe between console and windowed (GUI) subsystem
local function set_subsystem(exe, console)
    if exe:sub(1, 2) ~= "MZ" then return exe, false end

    local b1, b2, b3, b4 = exe:byte(0x3C + 1, 0x3C + 4)
    local pe = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
    if exe:sub(pe + 1, pe + 4) ~= "PE\0\0" then return exe, false end

    -- Optional header starts 24 bytes after the signature, Subsystem is 68 bytes into it
    local at = pe + 24 + 68 + 1
    return exe:sub(1, at - 1) .. string.char(console and 3 or 2, 0) .. exe:sub(at + 2), true
end

--- @section Packing

local function u32(value)
    return string.char(
        value % 256,
        math.floor(value / 256) % 256,
        math.floor(value / 65536) % 256,
        math.floor(value / 16777216) % 256
    )
end

--- Builds the data appended to the stub from a key -> content table
local function pack(entries)
    local keys = {}
    for key in pairs(entries) do
        keys[#keys + 1] = key
    end
    table.sort(keys)

    local parts = {}
    for _, key in ipairs(keys) do
        local data = entries[key]
        parts[#parts + 1] = u32(#key) .. key .. u32(#data) .. data
    end

    local body = table.concat(parts)
    return body .. u32(#keys) .. u32(#body) .. MAGIC
end

--- Reads a Lua file, checks its syntax, and returns what should be embedded
local function embed(key, path)
    local source = read_file(path)
    if not source then fail("could not read " .. path) end

    local chunk, err = loadstring(source, "@" .. key)
    if not chunk then
        fail(("syntax error in %s:\n%s"):format(key, tostring(err)))
    end

    if opts.bytecode then return string.dump(chunk) end
    return source
end

--- Reads game/config.lua to find the window.console default
local function read_config()
    local chunk = loadfile(project .. "/game/config.lua")
    if not chunk then return {} end

    local ok, conf = pcall(chunk)
    if ok and type(conf) == "table" then return conf end
    return {}
end

--- @section Build

local required_file = opts.target == "server"
    and "/game/server/init.lua"
    or "/game/main.lua"

if not read_file(project .. required_file) then
    if opts.target == "server" then
        fail("not a server-enabled game project (no game/server/init.lua): " .. project)
    else
        fail("not a game project (no game/main.lua): " .. project)
    end
end

local project_name = project:match("([^/\\]+)$") or "game"
local name = opts.name
if not name then
    name = opts.target == "server" and (project_name .. "_server") or project_name
end
name = name:gsub("[^%w_%-]", "_")

local conf = read_config()
local console = opts.console
if opts.target == "server" then
    console = true
elseif console == nil then
    console = conf.window and conf.window.console or false
end

local out = (opts.out or (project .. "/build/" .. name)):gsub("[/\\]+$", "")

emit("info", ("Building '%s' target (%s mode)"):format(
    opts.target, console and "console" or "windowed"
))

--- Embedded files

emit("info", "Collecting Lua files...")

local files = {}
scan_lua(ROOT .. "/src/engine", "src/engine/", files)
if read_file(ROOT .. "/src/version.lua") then
    files["src/version.lua"] = ROOT .. "/src/version.lua"
end
scan_lua(project .. "/game", "game/", files)

-- Save files are data, not code, and are never shipped
for key in pairs(files) do
    if key:match("^game/save/") then files[key] = nil end
end

if not files["src/engine/runner.lua"] then
    fail("src/engine/runner.lua not found, is the script inside the engine folder?")
end

local entries = {}
local count = 0
for key, path in pairs(files) do
    entries[key] = embed(key, path)
    count = count + 1
end

local prelude = read_file(ROOT .. "/tools/build/prelude.lua")
if not prelude then fail("tools/build/prelude.lua not found") end
entries["@prelude"] = prelude
entries["@meta"] = ("return { name = %q, target = %q }"):format(name, opts.target)

emit("info", ("Embedding %d Lua files%s"):format(
    count, opts.bytecode and " as bytecode" or ""
))

--- Executable

local exe = get_stub()
local patched
exe, patched = set_subsystem(exe, console)
if not patched then
    emit("warn", "stub is not a Windows executable, console mode was not applied")
end

make_dir(out)
local exe_path = out .. "/" .. name .. ".exe"
local packed = exe .. pack(entries)
if not write_file(exe_path, packed) then
    fail("could not write " .. exe_path .. " (is the game still running?)")
end

--- @section Runtime files

local runtime_dlls = opts.target == "server"
    and { "lua51.dll", "raylib.dll" }
    or RUNTIME_DLLS

for _, dll in ipairs(runtime_dlls) do
    local folder = dll == "lua51.dll" and "luajit/lib/" or "raylib/lib/"
    local found = ROOT .. "/vendor/" .. folder .. dll

    if not copy_file(found, out .. "/" .. dll) then
        fail("missing " .. dll .. " at " .. found)
    end

    emit("info", "Copied runtime DLL: " .. dll)
end

local assets = { files = 0 }
copy_tree(ROOT .. "/src/assets", out .. "/src/assets", "", function()
    return false
end, assets)

--- Project files: everything except game Lua (embedded), builds, saves and logs

local extras = { files = 0 }
copy_tree(project, out, "", function(relative, is_folder)
    if is_folder then
        return relative == "build/"
            or relative == "game/save/"
            or relative == "saves/"
            or (not opts.mods and relative == "mods/")
    end

    return relative == "factory-save.json"
        or relative:match("%.log$") ~= nil
        or relative:match("^game/.*%.lua$") ~= nil
end, extras)

emit("info", ("Copied %d engine asset files and %d project files"):format(
    assets.files, extras.files
))

emit("success", ("Built %s (%.1f KB)"):format(exe_path, #packed / 1024))

if log_file then log_file:close() end