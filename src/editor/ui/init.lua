--- @module ui
--- @file src/editor/ui/init.lua

local components = require("src.engine.ui.components")
components.modal = require("src.editor.ui.components.modal")

return {
    panels = require("src.editor.ui.panels"),
    themes = require("src.editor.ui.style.themes"),
    style = {
        layout = require("src.editor.ui.style.layout"),
    },
}