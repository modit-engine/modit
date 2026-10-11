--- @module config
--- @file src/editor/config.lua
--- @description Editor configuration file
--- This is not the engine or game configuration, can be mostly left untouched.

return {

    window = {
        title = "Modit Engine - V0.8.0", -- Window title bar text
        icon = "src/assets/branding/modit_icon_32x32.png", -- Window and taskbar icon path
        size = {
            width = 1600, -- Default width in pixels
            height = 900 -- Default height in pixels
        }, 
        flags = {
            vsync_hint = false, -- Sync frames with monitor refresh rate
            fullscreen_mode = false, -- Launch directly in full screen
            resizable = true, -- Allow manual window resizing
            undecorated = false, -- Hide title bar and borders
            transparent = false, -- Enable transparent window background
            hidden = false, -- Start window hidden
            minimized = false, -- Start window minimized
            maximized = true, -- Start window maximized
            unfocused = false, -- Avoid stealing focus on launch
            topmost = false, -- Pin window above all other OS windows
            always_run = false, -- Keep updating when alt-tabbed or minimized
            highdpi = false, -- High-DPI scaling support
            mouse_passthrough = false, -- Mouse clicks pass through window
            borderless_windowed_mode = false, -- Borderless windowed mode
            msaa_4x_hint = false, -- 4x anti-aliasing hint
            interlaced_hint = false -- Interlaced render mode
        },
        console = false -- Attach debug terminal on launch
    },

    fps = { 
        draw = true, -- Render FPS counter on screen
        target = 500 -- Target FPS cap (or false for uncapped)
    }
}