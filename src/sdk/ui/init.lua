--- @module ui
--- @file src/sdk/ui/init.lua
--- @description Lazy-loaded client UI SDK entry point.

--- @default_access mod

--- @section Imports

local _lazy = require("src.engine.core.internal.lazy")

--- @section Constants

local UI = "src.sdk.ui"

--- @section SDK Export

return _lazy.new({
    -- Core Modules & Themes (must be string paths, not evaluated require() tables)
    theme = UI .. ".theme",
    input = UI .. ".input",
    icons = UI .. ".icons",

    -- Atomic Components & Layouts
    button = UI .. ".components.button",
    item = UI .. ".components.item",
    label = UI .. ".components.label",
    panel = UI .. ".components.panel",
    splitter = UI .. ".components.splitter",
    textfield = UI .. ".components.textfield",
    toggle = UI .. ".components.toggle",

    -- Deferred function wrappers using closures
    scroll_begin = function(...) return require(UI .. ".components.scroll").begin(...) end,
    scroll_finish = function(...) return require(UI .. ".components.scroll").finish(...) end,

    build_dropdown = function(...) return require(UI .. ".overlays.dropdown").build(...) end,
    close_dropdown = function(...) return require(UI .. ".overlays.dropdown").close_all(...) end,

    open_modal = function(...) return require(UI .. ".overlays.modal").open(...) end,
    close_modal = function(...) return require(UI .. ".overlays.modal").close(...) end,
    is_modal_open = function(...) return require(UI .. ".overlays.modal").is_open(...) end,
    draw_modal = function(...) return require(UI .. ".overlays.modal").draw(...) end,
})