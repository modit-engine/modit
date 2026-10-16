--- @module panels
--- @file src/editor/ui/panels/init.lua

local _lazy = require("src.engine.core.internal.lazy")

return _lazy.new({
    code = "src.editor.ui.panels.code",
    centre = "src.editor.ui.panels.centre",
    console = "src.editor.ui.panels.console",
    explorer = "src.editor.ui.panels.explorer",
    toolbar = "src.editor.ui.panels.toolbar",
    new_project = "src.editor.ui.panels.new_project",
})