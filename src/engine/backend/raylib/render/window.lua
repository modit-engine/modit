--- @module window
--- @file src/engine/backend/raylib/window.lua
--- @description Window management, graphics context lifecycle, frame timing, audio context initialization, and window state flags.

--- @section Imports

local _raylib = require("src.engine.backend.raylib.ffi")
local _bit = require("bit")
local _log = require("src.engine.core.log")

local _ffi, _lib, _Color = _raylib.ffi, _raylib.lib, _raylib.Color

--- @section Constants & Flags

local KEY_NULL = 0
local KEY_ESCAPE = 256

local WINDOW_FLAGS = {
    vsync_hint = _ffi.C.FLAG_VSYNC_HINT,
    fullscreen_mode = _ffi.C.FLAG_FULLSCREEN_MODE,
    resizable = _ffi.C.FLAG_WINDOW_RESIZABLE,
    undecorated = _ffi.C.FLAG_WINDOW_UNDECORATED,
    transparent = _ffi.C.FLAG_WINDOW_TRANSPARENT,
    hidden = _ffi.C.FLAG_WINDOW_HIDDEN,
    minimized = _ffi.C.FLAG_WINDOW_MINIMIZED,
    maximized = _ffi.C.FLAG_WINDOW_MAXIMIZED,
    unfocused = _ffi.C.FLAG_WINDOW_UNFOCUSED,
    topmost = _ffi.C.FLAG_WINDOW_TOPMOST,
    always_run = _ffi.C.FLAG_WINDOW_ALWAYS_RUN,
    highdpi = _ffi.C.FLAG_WINDOW_HIGHDPI,
    mouse_passthrough = _ffi.C.FLAG_WINDOW_MOUSE_PASSTHROUGH,
    borderless_windowed_mode = _ffi.C.FLAG_BORDERLESS_WINDOWED_MODE,
    msaa_4x_hint = _ffi.C.FLAG_MSAA_4X_HINT,
    interlaced_hint = _ffi.C.FLAG_INTERLACED_HINT,
}

--- @section State

local audio_device_active = false
local clear_color_buffer = _Color(0, 0, 0, 255)

--- @section Initialisation

local m = {}

--- @section Lifecycle

--- Initializes application window, optionally loading icon and audio device
--- @param title string Window title string
--- @param width number Window width in pixels
--- @param height number Window height in pixels
--- @param flags table|nil Map of flag name strings to boolean states
--- @param icon_path string|nil Path to window icon image file
--- @param enable_audio boolean|nil Whether to initialize audio subsystem
--- @param target_fps number|nil Target frame rate limit
--- @param exit_on_escape boolean|nil Whether the ESC key closes the window (default false)
function m.init(title, width, height, flags, icon_path, enable_audio, target_fps, exit_on_escape)
    local want_maximized = flags and flags.maximized

    local flag_mask = 0
    for flag_name, is_enabled in pairs(flags or {}) do
        local name = flag_name:lower()
        local flag_bit = WINDOW_FLAGS[name]
        if flag_bit and is_enabled and name ~= "maximized" then
            flag_mask = _bit.bor(flag_mask, flag_bit)
        end
    end

    _lib.SetConfigFlags(flag_mask)
    _lib.InitWindow(width, height, title)
    _lib.SetExitKey(exit_on_escape and KEY_ESCAPE or KEY_NULL)

    if want_maximized then
        _lib.MaximizeWindow()
    end

    if icon_path then
        local resolved_path = nil

        local function file_exists(path)
            local f = io.open(path, "rb")
            if f then f:close(); return true end
            return false
        end

        if file_exists(icon_path) then
            resolved_path = icon_path
        else
            local engine = rawget(_G, "modit")
            local game_dir = engine and engine.game_dir
            local project_dir = engine and engine.project_dir
            local clean_path = icon_path:gsub("\\", "/"):gsub("^%./", "")
            local candidates = { game_dir and (game_dir .. "/" .. clean_path), project_dir and (project_dir .. "/" .. clean_path) }

            for _, path in ipairs(candidates) do
                if path and file_exists(path) then resolved_path = path; break end
            end
        end

        local icon_img = nil

        if resolved_path then
            icon_img = _lib.LoadImage(resolved_path)
        elseif MODIT_BUNDLE then
            local data = MODIT_BUNDLE.get(icon_path)

            if data then
                local tmp = os.tmpname() .. ".png"
                local f = io.open(tmp, "wb")

                if f then
                    f:write(data)
                    f:close()
                    icon_img = _lib.LoadImage(tmp)
                    os.remove(tmp)
                end
            end
        end

        if icon_img and icon_img.data ~= nil then
            _lib.SetWindowIcon(icon_img)
            _lib.UnloadImage(icon_img)
        end
    end

    audio_device_active = enable_audio and true or false
    if audio_device_active then
        _lib.InitAudioDevice()
    end

    if target_fps then
        _lib.SetTargetFPS(target_fps)
    end
end

--- Closes audio device (if active) and shuts down window context
function m.close()
    if not _lib.IsWindowReady() then return end
    local model = package.loaded["src.engine.backend.raylib.render.model"]
    if model then model.cleanup() end
    local lighting = package.loaded["src.engine.backend.raylib.render.lighting"]
    if lighting then lighting.free() end
    if audio_device_active then
        _lib.CloseAudioDevice()
        audio_device_active = false
    end
    _lib.CloseWindow()
end

--- @section Frame & Rendering Lifecycle

--- Begins frame drawing and clears canvas with RGBA color
--- @param r number Red component (0-255)
--- @param g number Green component (0-255)
--- @param b number Blue component (0-255)
--- @param a number Alpha component (0-255)
function m.begin_draw(r, g, b, a)
    _lib.BeginDrawing()
    clear_color_buffer.r, clear_color_buffer.g, clear_color_buffer.b, clear_color_buffer.a = r, g, b, a
    _lib.ClearBackground(clear_color_buffer)
end

--- Ends frame drawing and swaps render buffers
function m.end_draw()
    _lib.EndDrawing()
end

--- Checks if user or system requested window closure
--- @return boolean should_close True if window should close
function m.should_close()
    return _lib.WindowShouldClose()
end

--- @section Window State Flags & Properties

--- Configures specific window state flag
--- @param name string Flag name key
--- @param enabled boolean True to set flag, false to clear
--- @return boolean success True if flag was recognized and applied
function m.set_flag(name, enabled)
    local flag_bit = WINDOW_FLAGS[name:lower()]
    if not flag_bit then
        return false
    end

    if enabled then
        _lib.SetWindowState(flag_bit)
    else
        _lib.ClearWindowState(flag_bit)
    end
    return true
end

--- Toggles window fullscreen mode
function m.toggle_fullscreen()
    _lib.ToggleFullscreen()
end

--- Minimizes application window
function m.minimize()
    _lib.MinimizeWindow()
end

--- Gets current window screen dimensions
--- @return number width Screen width in pixels
--- @return number height Screen height in pixels
function m.get_size()
    return _lib.GetScreenWidth(), _lib.GetScreenHeight()
end

--- Gets top-left window coordinates on screen
--- @return number x Screen X position
--- @return number y Screen Y position
function m.get_position()
    return _lib.GetWindowPositionX(), _lib.GetWindowPositionY()
end

--- Sets top-left window coordinates on screen
--- @param pos_x number Target X position
--- @param pos_y number Target Y position
function m.set_position(pos_x, pos_y)
    _lib.SetWindowPosition(pos_x, pos_y)
end

--- @section Timing & Metrics

--- Returns frame delta time in seconds
--- @return number delta_time Delta time in seconds
function m.get_dt()
    return _lib.GetFrameTime()
end

--- Returns current frames per second (FPS) count
--- @return number fps Current FPS
function m.get_fps()
    return _lib.GetFPS()
end

--- Renders debug FPS counter overlay at specified position
--- @param pos_x number Overlay X position
--- @param pos_y number Overlay Y position
function m.draw_fps(pos_x, pos_y)
    _lib.DrawFPS(pos_x, pos_y)
end

--- Gets top-left window coordinates on screen
--- @return number x Screen X position
--- @return number y Screen Y position
function m.get_position()
    local p = _lib.GetWindowPosition()
    return p.x, p.y
end

return m