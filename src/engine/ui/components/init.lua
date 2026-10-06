--- @module init
--- @file src/editor/ui/components/init.lua
--- @description Handles component initialisation

--- @section Imports

local _scroll = require("src.engine.ui.components.scroll")
local _menu = require("src.engine.ui.components.menu")

--- @section Module

return {
    button = require("src.engine.ui.components.button"),
    icon_button = require("src.engine.ui.components.icon_button"),
    dropdown = _menu.dropdown,
    modal = require("src.engine.ui.components.modal"),
    panel = require("src.engine.ui.components.panel"),
    label = require("src.engine.ui.components.label"),
    item = require("src.engine.ui.components.item"),
    textfield = require("src.engine.ui.components.textfield"),
    splitter = require("src.engine.ui.components.splitter"),
    scroll_begin = _scroll.begin,
    scroll_end = _scroll.finish,
}