--- @module state
--- @file projects/test_project/game/client/core/state.lua
--- @description Holds which client screen is active and its context data.

--- @section Initialisation

local m = {
    current = "menu", -- "menu" or "game"
    data = nil,
}

--- @section Functions

function m.set(screen_name, context)
    m.current = screen_name
    m.data = context
end

return m