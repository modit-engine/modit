--- @file src/main.lua
--- @description Entry point. Initializes the engine and launches the editor.

--- @section Package Path

package.path = "./?.lua;./?/init.lua;" .. package.path

--- @section Imports

local modit = require("src.engine")
local editor = require("src.editor")
local ver = require("src.version")
local ui_input = require("src.sdk.ui.input")

--- @section Run

modit.run({
    version = ver.engine,
    check_updates = true,

    window = {
        title = "Modit Engine - " .. ver.display,
        icon = "src/engine/assets/branding/modit_icon_32x32.png",
        console = false,
        size = { width = 1600, height = 900 },
        fps = { draw = false, target = false },
        flags = { maximized = true, resizable = true }
    },

    modules = {
        audio = true
    },

    load = function()
        editor.init()
        if arg[1] then
            editor.open_project(arg[1])
        end
    end,

    update = function(dt)
        editor.update(dt)
    end,

    draw = function()
        if ui_input and ui_input.begin_frame then ui_input.begin_frame() end

        editor.draw()
        modit.draw2d.reset_clip()

        if ui_input and ui_input.end_frame then ui_input.end_frame() end
    end,

    quit = function()
        editor.close()
    end,
})