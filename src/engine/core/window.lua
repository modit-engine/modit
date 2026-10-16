--- @module window
--- @file src/engine/core/window.lua
--- @description High-level window lifecycle, display configuration, and frame timing facade.

--- @section Imports

local _backend = require("src.engine.backend").window

--- @section Constants

local FPS_X, FPS_Y = 10, 10

--- @section Initialisation

local close_requested = false

local m = {
    title = "Modit",
    size = { width = 1280, height = 720 },
    fps = { draw = false, target = false },
    icon = nil,
    flags = {},
    exit_key = false,
    background = { 10, 10, 20, 255 },
}

--- @section Helpers

--- Gets a loaded module without requiring it, so the window has no hard dependency on it
--- @param name string Module path
--- @return table|nil module Loaded module or nil
local function loaded(name)
    return package.loaded[name]
end

--- @section Lifecycle

--- Initializes display window and backend rendering context
--- @param opts table|nil { title, icon, size = { width, height }, fps = { draw, target }, flags = {}, exit_key = false }
--- @param modules table|nil Module toggles from the game config, e.g. { audio = true }
function m.init(opts, modules)
    close_requested = false
    opts = opts or {}

    m.title = opts.title or m.title
    m.size = opts.size or m.size
    m.fps = opts.fps or m.fps
    m.flags = opts.flags or m.flags
    m.icon = opts.icon or m.icon
    m.exit_key = opts.exit_key == true

    local audio = modules and modules.audio or false

    _backend.init(m.title, m.size.width, m.size.height, m.flags, m.icon, audio, m.fps.target, m.exit_key)
end

--- Begins frame render pass and clears background color
function m.begin_draw()
    local c = m.background
    _backend.begin_draw(c[1], c[2], c[3], c[4])
end

--- Finalizes frame render pass and swaps display buffers
function m.end_draw()
    -- never swap buffers while a post-processing scene is still open
    local post = loaded("src.engine.modules.render.post")
    if post then post.close_scene() end

    if m.fps.draw then _backend.draw_fps(FPS_X, FPS_Y) end

    _backend.end_draw()
end

--- Checks whether user requested window close event
--- @return boolean is_closing True if window close event was signaled
function m.should_close()
    return close_requested or _backend.should_close()
end

--- Requests a clean exit after the current frame
--- @access game
function m.request_close()
    close_requested = true
end

--- Closes display window and destroys graphics context
function m.close()
    -- Drop public handles while their graphics context is still alive.
    local water = loaded("src.engine.modules.render.water")
    if water then water.reset() end

    local model = loaded("src.sdk.client.model")
    if model then model.cleanup() end

    local audio = loaded("src.sdk.client.audio")
    if audio then audio.cleanup() end
    
    _backend.close()
end

--- @section Flags & Display Modes

--- Toggles or sets backend window configuration flag
--- @access game
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
--- @access game
function m.toggle_fullscreen()
    _backend.toggle_fullscreen()
    m.flags.fullscreen_mode = not m.flags.fullscreen_mode
end

--- Sets whether window runs in borderless windowed mode
--- @access game
--- @param enabled boolean True for borderless, false for decorated
function m.set_borderless(enabled)
    m.toggle_flag("borderless_windowed_mode", enabled)
end

--- Sets whether window stays on top of other windows
--- @access game
--- @param enabled boolean True to pin window on top
function m.set_topmost(enabled)
    m.toggle_flag("topmost", enabled)
end

--- Enables or disables window resizing by user
--- @access game
--- @param enabled boolean True to allow user resize
function m.set_resizable(enabled)
    m.toggle_flag("resizable", enabled)
end

--- Toggles window frame decorations (title bar and borders)
--- @access game
--- @param enabled boolean True to enable borders, false for undecorated
function m.set_decorated(enabled)
    m.toggle_flag("undecorated", not enabled)
end

--- Queries whether a specific window flag is currently active
--- @access game
--- @param name string Flag key identifier
--- @return boolean is_enabled True if flag active
function m.is_flag_enabled(name)
    return m.flags[name] or false
end

--- @section Metrics & Position

--- Retrieves current window dimensions in pixels
--- @access mod
--- @return number width Width in pixels
--- @return number height Height in pixels
function m.get_size()
    return _backend.get_size()
end

--- Retrieves elapsed time between current and previous frame
--- @access mod
--- @return number dt Delta time in seconds
function m.get_dt()
    return _backend.get_dt()
end

--- Retrieves current rendering frame rate
--- @access mod
--- @return number fps Frames per second
function m.get_fps()
    return _backend.get_fps()
end

--- Retrieves current desktop position of window
--- @access mod
--- @return number x Screen X position
--- @return number y Screen Y position
function m.get_position()
    return _backend.get_position()
end

--- Repositions window on desktop screen
--- @access game
--- @param x number Target screen X position
--- @param y number Target screen Y position
function m.set_position(x, y)
    _backend.set_position(x, y)
end

--- Minimizes window to OS taskbar
--- @access game
function m.minimize()
    _backend.minimize()
end

return m