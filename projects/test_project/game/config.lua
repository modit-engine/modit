--- @module config
--- @file src/planetlua/client/config.lua
--- @description Planet Lua client window configuration.

return {

    window = {
        title = "Modit Client", -- Window title bar text
        icon = "src/assets/branding/modit_icon_32x32.png", -- Window and taskbar icon path
        size = {
            width = 1280, -- Default width in pixels
            height = 720 -- Default height in pixels
        },
        flags = {
            vsync_hint = true, -- Sync frames with monitor refresh rate
            fullscreen_mode = false, -- Launch directly in full screen
            resizable = true, -- Allow manual window resizing
            undecorated = false, -- Hide title bar and borders
            transparent = false, -- Enable transparent window background
            hidden = false, -- Start window hidden
            minimized = false, -- Start window minimized
            maximized = false, -- Start window maximized
            unfocused = false, -- Avoid stealing focus on launch
            topmost = false, -- Pin window above all other OS windows
            always_run = false, -- Keep updating when alt-tabbed or minimized
            highdpi = false, -- High-DPI scaling support
            mouse_passthrough = false, -- Mouse clicks pass through window
            borderless_windowed_mode = false, -- Borderless windowed mode
            msaa_4x_hint = true, -- 4x anti-aliasing hint
            interlaced_hint = false -- Interlaced render mode
        },
        console = true -- Attach debug terminal on launch (set false for releases)
    },

    fps = {
        draw = false, -- Render FPS counter on screen
        target = 144 -- Target FPS cap (or false for uncapped)
    },

    modules = {
        audio = false -- Init Raylib audio on boot
    },
    
    server = {
        enabled = true, -- Game has server code (game/server). Runs beside the client while developing
        port = 7777,
        tick_rate = 30, -- Server updates per second
    },
}