--- @file runner
--- @description Just a stub, allows for `luajit runner.lua <path>` instead of having to use `luajit src/engine/core/internal/runner.lua`

package.path = "./?.lua;./?/init.lua;" .. package.path
require("src.editor.builder.build")