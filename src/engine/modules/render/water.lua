--- @module water
--- @file src/engine/modules/render/water.lua
--- @description Faceted, animated, translucent water surface. Draw it last inside camera begin_3d/end_3d.

--- @section Imports

local _backend = require("src.engine.backend").water

--- @section Constants

local MAX_CELLS = 200
local WAVE_FORWARD = 1.31 -- keep in sync with the water shader
local WAVE_BACKWARD = 0.8

local DEFAULTS = {
    x = 0, y = 0, z = 0,
    size = 80,
    cell = 2,
    colour = { 30, 95, 150 },
    opacity = 0.6,
    amplitude = 0.12,
    frequency = 0.6,
    speed = 1.2,
}

--- @section State

local state = {}
local enabled = false
local handle = nil
local built_size, built_cells = nil, nil

--- @section Initialisation

local m = {}

--- @section Helpers

local function number(value, fallback, low, high)
    value = tonumber(value) or fallback
    return math.max(low, math.min(high, value))
end

local function channel(source, index, name, fallback)
    local value = source[name] or source[index]
    return math.max(0, math.min(255, tonumber(value) or fallback))
end

local function release()
    if handle then
        _backend.free(handle)
        handle, built_size, built_cells = nil, nil, nil
    end
end

local function cell_count()
    return math.max(1, math.min(MAX_CELLS, math.floor(state.size / state.cell + 0.5)))
end

--- Flat triangle grid on y = 0, counter-clockwise seen from above
local function build_vertices(size, cells)
    local vertices, count = {}, 0
    local step, half = size / cells, size / 2

    local function push(x, z)
        vertices[count + 1], vertices[count + 2], vertices[count + 3] = x, 0, z
        count = count + 3
    end

    for i = 0, cells - 1 do
        local x0, x1 = -half + i * step, -half + (i + 1) * step
        for j = 0, cells - 1 do
            local z0, z1 = -half + j * step, -half + (j + 1) * step
            push(x0, z0); push(x0, z1); push(x1, z1)
            push(x0, z0); push(x1, z1); push(x1, z0)
        end
    end

    return vertices
end

local function ensure_mesh()
    local cells = cell_count()
    if handle and built_size == state.size and built_cells == cells then return end

    release()
    handle = _backend.build(build_vertices(state.size, cells))
    built_size, built_cells = state.size, cells
end

--- @section Functions

--- Sets up the water and turns it on
--- @param opts table `{ x?, y?, z?, size?, cell?, colour?, opacity?, amplitude?, frequency?, speed? }` centre, level, square size and grid cell size, colour as `{ r, g, b }` (0-255), opacity 0-1, wave height, wave frequency and wave speed
function m.set(opts)
    opts = opts or {}

    state.x = number(opts.x, state.x, -1e6, 1e6)
    state.y = number(opts.y, state.y, -1e6, 1e6)
    state.z = number(opts.z, state.z, -1e6, 1e6)
    state.size = number(opts.size, state.size, 4, 2000)
    state.cell = number(opts.cell, state.cell, 0.25, 100)
    state.cell = math.max(state.cell, state.size / MAX_CELLS)
    state.opacity = number(opts.opacity, state.opacity, 0, 1)
    state.amplitude = number(opts.amplitude, state.amplitude, 0, 10)
    state.frequency = number(opts.frequency, state.frequency, 0.01, 10)
    state.speed = number(opts.speed, state.speed, 0, 20)

    if type(opts.colour) == "table" then
        local c, old = opts.colour, state.colour
        state.colour = { channel(c, 1, "r", old[1]), channel(c, 2, "g", old[2]), channel(c, 3, "b", old[3]) }
    end

    enabled = true
end

--- Turns the water on or off without losing its settings
--- @param flag boolean True to show the water
function m.set_enabled(flag)
    enabled = flag and true or false
end

--- Draws the water. Call last inside camera begin_3d/end_3d, after the opaque scene
function m.draw()
    if not enabled then return end

    ensure_mesh()
    local colour = state.colour
    _backend.draw(handle, state.x, state.y, state.z, os.clock(),
        state.amplitude, state.frequency, state.speed,
        colour[1] / 255, colour[2] / 255, colour[3] / 255, state.opacity)
end

--- Gets the water surface height at a point, matching what is drawn (for boats and floating objects)
--- @param x number World X
--- @param z number World Z
--- @return number|nil height Surface Y, or nil when the water is off or the point is outside it
function m.height_at(x, z)
    if not enabled then return nil end

    local half = state.size / 2
    if x < state.x - half or x > state.x + half or z < state.z - half or z > state.z + half then
        return nil
    end

    local t = os.clock() * state.speed
    local f = state.frequency
    local wave = math.sin(x * f + t) + math.sin(z * f * WAVE_FORWARD - t * WAVE_BACKWARD)
    return state.y + wave * 0.5 * state.amplitude
end

--- Turns the water off, frees its mesh and restores the defaults
function m.reset()
    enabled = false
    release()
    for key, value in pairs(DEFAULTS) do
        state[key] = type(value) == "table" and { value[1], value[2], value[3] } or value
    end
end

m.reset()

return m