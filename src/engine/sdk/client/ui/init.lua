--- @module ui
--- @file src/engine/sdk/client/ui/init.lua
--- @description Lazy-loaded client UI SDK entry point.

--- @section Imports

local _lazy = require("src.engine.core.internal.lazy")

--- @section Constants

local UI = "src.engine.sdk.client.ui"

--- @section SDK Export

return _lazy.new({
    -- Core Modules & Themes
    theme = require(UI .. ".modules.theme"),
    input = require(UI .. ".modules.input"),
    icons = require(UI .. ".modules.icons"),

    -- Atomic Components & Layouts
    button = require(UI .. ".components.button"),
    item = require(UI .. ".components.item"),
    label = require(UI .. ".components.label"),
    panel = require(UI .. ".components.panel"),
    splitter = require(UI .. ".components.splitter"),
    textfield = require(UI .. ".components.textfield"),
    scroll_begin = require(UI .. ".components.scroll").begin,
    scroll_finish = require(UI .. ".components.scroll").finish,

    -- Dropdown Menu Overlays
    build_dropdown = require(UI .. ".overlays.dropdown").build,
    close_dropdown = require(UI .. ".overlays.dropdown").close_all,

    -- Modal Dialog Overlays
    open_modal = require(UI .. ".overlays.modal").open,
    close_modal = require(UI .. ".overlays.modal").close,
    is_modal_open = require(UI .. ".overlays.modal").is_open,
    draw_modal = require(UI .. ".overlays.modal").draw,
})