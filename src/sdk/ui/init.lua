--- @module ui
--- @file src/sdk/ui/init.lua
--- @description Client UI SDK entry point. Each entry loads its module on first use.

--- @default_access mod

--- @section Constants

local UI = "src.sdk.ui"

--- @section Helpers

local function component(path)
    local loaded
    return function(...)
        loaded = loaded or require(path)
        return loaded(...)
    end
end

local function namespace(path)
    return setmetatable({}, {
        __index = function(_, key)
            return require(path)[key]
        end,
    })
end

--- @section SDK Export

return {
    -- Core Modules & Themes
    theme = namespace(UI .. ".theme"),
    input = namespace(UI .. ".input"),
    icons = namespace(UI .. ".icons"),

    -- Atomic Components & Layouts
    button = component(UI .. ".components.button"),
    item = component(UI .. ".components.item"),
    label = component(UI .. ".components.label"),
    panel = component(UI .. ".components.panel"),
    splitter = component(UI .. ".components.splitter"),
    textfield = component(UI .. ".components.textfield"),
    toggle = component(UI .. ".components.toggle"),

    -- Deferred function wrappers using closures
    scroll_begin = function(...) return require(UI .. ".components.scroll").begin(...) end,
    scroll_finish = function(...) return require(UI .. ".components.scroll").finish(...) end,

    build_dropdown = function(...) return require(UI .. ".overlays.dropdown").build(...) end,
    close_dropdown = function(...) return require(UI .. ".overlays.dropdown").close_all(...) end,

    open_modal = function(...) return require(UI .. ".overlays.modal").open(...) end,
    close_modal = function(...) return require(UI .. ".overlays.modal").close(...) end,
    is_modal_open = function(...) return require(UI .. ".overlays.modal").is_open(...) end,
    draw_modal = function(...) return require(UI .. ".overlays.modal").draw(...) end,

    -- Toast Notifications
    push_toast = function(...) return require(UI .. ".overlays.toast").push(...) end,
    clear_toasts = function(...) return require(UI .. ".overlays.toast").clear(...) end,
    update_toasts = function(...) return require(UI .. ".overlays.toast").update(...) end,
    draw_toasts = function(...) return require(UI .. ".overlays.toast").draw(...) end,
}