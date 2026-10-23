--- @module boilerplate_config
--- @file src/editor/boilerplates/config.lua
--- @description Default project configuration template.

return [[
return {

    -- Window & Display Settings
    window = {
        title = {{label_literal}},
        -- icon = "path/to/icon.png",
        size = {
            width = 1280,
            height = 720,
        },
        console = true, -- Attach debug terminal on launch
        flags = {
            vsync_hint = true,
            fullscreen_mode = false,
            resizable = true,
            undecorated = false,
            transparent = false,
            hidden = false,
            minimized = false,
            maximized = false,
            unfocused = false,
            topmost = false,
            always_run = false,
            highdpi = false,
            mouse_passthrough = false,
            borderless_windowed_mode = false,
            msaa_4x_hint = true,
            interlaced_hint = false,
        },
        fps = {
            draw = false,
            target = 144, -- Target FPS cap (false for uncapped)
        }
    },

    -- Engine Modules (Opt-out)
    modules = {
        -- Client Subsystems
        audio = true,
        camera = true,
        canvas = true,
        draw2d = true,
        draw3d = true,
        environment = true,
        font = true,
        image = true,
        input = true,
        model = true,

        -- Shared Utilities
        command = true,
        filesystem = true,
        hook = true,
        mat4 = true,
        math = true,
        mods = true,
        network = true,
        physics = true,
        runtime = true,
        string = true,
        table = true,
        timestamp = true,
        vector = true,
        server_console = true,

        -- UI Framework
        ui = true
    },

    -- Modding Support
    modding = {
        enabled = true,
        blacklisted_modules = {}, -- e.g. { "environment" }
    },

    -- Headless Server Support
    server = {
        enabled = false,
        tick_rate = 30,
        port = 7777
    },

    -- Build / Packaging Settings
    build = {
        icons = {
            windows = {
                client_exe = nil,
                server_exe = nil,
            }
        },
        
        engine_assets = {
            fonts = true
        },
        
        external_saves = {
            enabled = false,
            directory = "saves",
            files = {},
        },
    }
}
]]