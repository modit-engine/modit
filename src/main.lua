--- @file src/main.lua
--- @description Entry point. Opens the window and runs the draw test.

--- @section Package Path

package.path = "./?.lua;./?/init.lua;" .. package.path

--- @section Imports

local modit = require("src.engine")

--- @section Constants

local VERSION = "0.08.0-alpha"

--- @section Run

-- local lighting_test = require("src.engine.tests.lighting")(modit)

modit.run({
    version = VERSION,
    check_updates = true,

    window = {
        title = "Modit Engine - V" .. VERSION,
        icon = "src/engine/assets/branding/modit_icon_32x32.png",
        console = false,
        size = { width = 1600, height = 900 },
        fps = { draw = false, target = false },
        flags = { maximized = true, resizable = true }
    },

    --update = test_suite.update,
    draw = require("src.engine.tests.maths")(modit)
})

--- @section Test files
--- @todo remove

-- draw = require("src.engine.tests.draw2d")(modit) -- draw & camera: 2d drawing + cam + font + images
-- draw = require("src.engine.tests.draw3d")(modit) -- draw & camera:3d drawing + cam
-- draw = require("src.engine.tests.commands_hooks")(modit) -- commands & hooks: commands + hooks
-- draw = require("src.engine.tests.canvas")(modit) -- canvas: minimap + fixed res + mouse mapping
-- draw = require("src.engine.tests.postfx")(modit) -- postfx: options, scene size, shaders
-- draw = require("src.engine.tests.lighting")(modit) -- lighting & sky: sun, ambient, fog, shadow modes, sky backdrop
-- draw = require("src.engine.tests.maths")(modit) -- maths, geometry, vector, mat4