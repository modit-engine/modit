--- @module init
--- @file src/editor/ui/components/init.lua
--- @description Handles component initialisation

--- @section Imports

local _scroll = require("src.editor.ui.components.scroll")
local _menu = require("src.editor.ui.components.menu")

--- @section Module

return {
    button = require("src.editor.ui.components.button"),
    icon_button = require("src.editor.ui.components.icon_button"),
    dropdown = _menu.dropdown,
    modal = require("src.editor.ui.components.modal"),
    panel = require("src.editor.ui.components.panel"),
    label = require("src.editor.ui.components.label"),
    item = require("src.editor.ui.components.item"),
    textfield = require("src.editor.ui.components.textfield"),
    splitter = require("src.editor.ui.components.splitter"),
    scroll_begin = _scroll.begin,
    scroll_end = _scroll.finish,
}