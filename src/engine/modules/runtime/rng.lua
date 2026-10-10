--- @module runtime.rng
--- @description Deterministic RNG using xorshift32 (exact in LuaJIT, no float overflow).

local bit = require("bit")
local bxor, lshift, rshift, tobit = bit.bxor, bit.lshift, bit.rshift, bit.tobit

local m = {}

--- @section State

local TWO_32 = 4294967296

local seed = os.time()
local state

local function normalise(s)
    s = tobit(math.floor(s))
    if s == 0 then s = 1 end -- xorshift must never hold zero
    return s
end

state = normalise(seed)

--- @section API

--- Sets the seed for the RNG
--- @param s number|nil Seed to use (default: current time)
function m.set_rng_seed(s)
    seed = s or os.time()
    state = normalise(seed)
end

--- Gets the last set seed value
--- @return number seed
function m.get_rng_seed()
    return seed
end

--- Returns a raw float in [0, 1)
--- @return number
function m.random_rng()
    local x = state
    x = bxor(x, lshift(x, 13))
    x = bxor(x, rshift(x, 17))
    x = bxor(x, lshift(x, 5))
    state = x
    return (x % TWO_32) / TWO_32
end

--- Returns an integer in [min, max] inclusive
--- @param min number Lower bound
--- @param max number Upper bound
--- @return number
function m.random_int(min, max)
    return min + math.floor(m.random_rng() * (max - min + 1))
end

--- Gets the internal state for snapshot/rewind
--- @return number state
function m.get_rng_state()
    return state
end

--- Restores a previously saved state
--- @param s number State value to restore
function m.set_rng_state(s)
    state = normalise(s)
end

return m