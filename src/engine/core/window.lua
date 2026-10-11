--- @module window
--- @file src/engine/core/window.lua
--- @description High-level window lifecycle, display configuration, and frame timing facade.

--- @section Imports

local _backend = require("src.engine.backend").window

--- @section Initialisation

local m = {
    title = "Modit",
    size = { width = 1280, height = 720 },
    fps = { draw = false, target = false },
    audio = false,
    icon = nil,
    flags = {},
    background = { 10, 10, 20, 255 },
}

--- Initializes display window and backend rendering context
--- @param opts table|nil Configuration table containing window, fps, and module options
function m.init(opts)
    opts = opts or {}
    local w = opts.window or {}

    m.title = w.title or m.title
    m.size = w.size or m.size
    m.flags = w.flags or m.flags
    m.icon = w.icon or m.icon
    m.fps = opts.fps or m.fps
    m.audio = opts.modules and opts.modules.audio or m.audio

    _backend.init(m.title, m.size.width, m.size.height, m.flags, m.icon, m.audio, m.fps.target)
end

--- @section Render Pass & Lifecycle

--- Begins frame render pass and clears background color
function m.begin_draw()
    local c = m.background
    _backend.begin_draw(c[1], c[2], c[3], c[4])
end

--- Finalizes frame render pass and swaps display buffers
function m.end_draw()
    _backend.end_draw()
end

--- Checks whether user requested window close event
--- @return boolean is_closing True if window close event was signaled
function m.should_close()
    return _backend.should_close()
end

--- @section Flags & Display Modes

--- Toggles or sets backend window configuration flag
--- @param name string Flag key identifier
--- @param enabled boolean True to enable flag, false to disable
function m.toggle_flag(name, enabled)
    if _backend.set_flag(name, enabled) then
        m.flags[name] = enabled and true or false
    else
        print("Warning: Unknown flag '" .. name .. "'")
    end
end

--- Toggles windowed and fullscreen display modes
function m.toggle_fullscreen()
    _backend.toggle_fullscreen()
    m.flags.fullscreen_mode = not m.flags.fullscreen_mode
end

--- Sets whether window runs in borderless windowed mode
--- @param enabled boolean True for borderless, false for decorated
function m.set_borderless(enabled)
    m.toggle_flag("borderless_windowed_mode", enabled)
end

--- Sets whether window stays on top of other windows
--- @param enabled boolean True to pin window on top
function m.set_topmost(enabled)
    m.toggle_flag("topmost", enabled)
end

--- Enables or disables window resizing by user
--- @param enabled boolean True to allow user resize
function m.set_resizable(enabled)
    m.toggle_flag("resizable", enabled)
end

--- Toggles window frame decorations (title bar and borders)
--- @param enabled boolean True to enable borders, false for undecorated
function m.set_decorated(enabled)
    m.toggle_flag("undecorated", not enabled)
end

--- Queries whether a specific window flag is currently active
--- @param name string Flag key identifier
--- @return boolean is_enabled True if flag active
function m.is_flag_enabled(name)
    return m.flags[name] or false
end

--- @section Metrics & Position

--- Retrieves current window dimensions in pixels
--- @return number width Width in pixels
--- @return number height Height in pixels
function m.get_size()
    return _backend.get_size()
end

--- Retrieves elapsed time between current and previous frame
--- @return number dt Delta time in seconds
function m.get_dt()
    return _backend.get_dt()
end

--- Retrieves current rendering frame rate
--- @return number fps Frames per second
function m.get_fps()
    return _backend.get_fps()
end

--- Renders FPS counter overlay at specified screen position
--- @param x number Screen X position
--- @param y number Screen Y position
function m.draw_fps(x, y)
    _backend.draw_fps(x, y)
end

--- Retrieves current desktop position of window
--- @return number x Screen X position
--- @return number y Screen Y position
function m.get_position()
    return _backend.get_position()
end

--- Repositions window on desktop screen
--- @param x number Target screen X position
--- @param y number Target screen Y position
function m.set_position(x, y)
    _backend.set_position(x, y)
end

--- Minimizes window to OS taskbar
function m.minimize()
    _backend.minimize()
end

--- Closes display window and destroys graphics context
function m.close()
    -- Drop public handles while their graphics context is still alive.
    local water = package.loaded["src.engine.modules.render.water"]
    if water then water.reset() end
    local model = package.loaded["src.engine.modules.render.model"]
    if model then model.cleanup() end
    _backend.close()
end

return m
