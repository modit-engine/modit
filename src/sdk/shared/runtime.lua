--- @module runtime
--- @file src/sdk/shared/runtime.lua
--- @description Flat runtime API: timers, cooldowns and deterministic RNG (xorshift32).

--- @default_access game

--- @section Imports

local bit = require("bit")
local _log = require("src.engine.core.log")

local bxor, lshift, rshift, tobit = bit.bxor, bit.lshift, bit.rshift, bit.tobit

--- @section Initialisation

local m = {}

local TWO_32 = 4294967296

-- timers
local _next_id = 0
local _active = {}

-- cooldowns
local _cooldowns = {}
local _now = 0

-- rng
local _seed = os.time()
local _state

local timer_meta = {
    __index = {
        cancel = function(self)
            _active[self.id] = nil
        end
    }
}

--- @section Helpers

local function add_timer(delay, interval, count, fn, owner)
    assert(type(fn) == "function", "timer callback must be a function")
    _next_id = _next_id + 1

    local timer_obj = setmetatable({
        id = _next_id,
        time = delay,
        interval = interval,
        remaining = count, -- fires left, -1 = infinite
        fn = fn,
        owner = owner,
    }, timer_meta)

    _active[_next_id] = timer_obj
    return timer_obj
end

local function normalise_seed(s)
    s = tobit(math.floor(s))
    if s == 0 then s = 1 end
    return s
end

_state = normalise_seed(_seed)

local function update_timers(dt)
    local ids = {}
    for id in pairs(_active) do ids[#ids + 1] = id end
    table.sort(ids)

    for _, id in ipairs(ids) do
        local timer = _active[id]
        if timer then
            timer.time = timer.time - dt
            if timer.time <= 0 then
                if timer.remaining > 0 then timer.remaining = timer.remaining - 1 end

                if timer.remaining == 0 then
                    _active[id] = nil
                else
                    timer.time = math.max(0, timer.time + timer.interval)
                end

                local ok, err = pcall(timer.fn)
                if not ok then
                    _log.error(("timer %d failed: %s"):format(id, tostring(err)))
                end
            end
        end
    end
end

--- @section Update

--- Advances timers and the cooldown clock. Call once per frame (client) or per tick (server)
--- @param dt number Delta time in seconds
function m.update(dt)
    _now = _now + dt
    update_timers(dt)
end

--- @section Timers

--- Run a function once after a delay
--- @param delay number Seconds to wait
--- @param fn function Callback to call
--- @param owner string|nil Owner name, for clear_owner_timers cleanup
--- @return table handle Timer handle with :cancel() method
function m.after(delay, fn, owner)
    assert(type(delay) == "number" and delay >= 0, "delay must be >= 0")
    return add_timer(delay, 0, 1, fn, owner)
end

--- Run a function repeatedly at a given interval
--- @param interval number Interval in seconds
--- @param fn function Callback to call
--- @param count number|nil Number of times to fire (default -1 = infinite)
--- @param owner string|nil Owner name, for clear_owner_timers cleanup
--- @return table handle Timer handle with :cancel() method
function m.every(interval, fn, count, owner)
    assert(type(interval) == "number" and interval > 0, "interval must be > 0")
    count = count or -1
    assert(count == -1 or count > 0, "count must be -1 or > 0")
    return add_timer(interval, interval, count, fn, owner)
end

--- Cancel every timer registered by an owner
--- @param owner string Owner name
function m.clear_owner_timers(owner)
    for id, timer in pairs(_active) do
        if timer.owner == owner then _active[id] = nil end
    end
end

--- Clear all active timers
function m.clear_timers()
    _active = {}
end

--- @section Cooldowns

--- Start a cooldown for a given id + kind
--- @param id string|number Unique actor/user/entity
--- @param kind string Action key
--- @param duration number Duration in seconds
function m.add_cooldown(id, kind, duration)
    assert(id ~= nil, "add_cooldown: id is required")
    assert(kind ~= nil, "add_cooldown: kind is required")
    assert(type(duration) == "number" and duration > 0, "add_cooldown: duration must be > 0")

    _cooldowns[id] = _cooldowns[id] or {}
    _cooldowns[id][kind] = { expires = _now + duration }
end

--- Check if a cooldown is still active
--- @param id string|number Unique actor/user/entity
--- @param kind string Action key
--- @return boolean active
function m.has_cooldown(id, kind)
    local data = _cooldowns[id] and _cooldowns[id][kind]
    return data ~= nil and _now < data.expires
end

--- Get remaining time on cooldown (0 if none)
--- @param id string|number Unique actor/user/entity
--- @param kind string Action key
--- @return number seconds
function m.get_cooldown(id, kind)
    local data = _cooldowns[id] and _cooldowns[id][kind]
    if not data then return 0 end
    return math.max(0, data.expires - _now)
end

--- Clear a specific cooldown
--- @param id string|number Unique actor/user/entity
--- @param kind string Action key
function m.clear_cooldown(id, kind)
    if _cooldowns[id] then
        _cooldowns[id][kind] = nil
        if not next(_cooldowns[id]) then _cooldowns[id] = nil end
    end
end

--- Remove all cooldowns for a given id
--- @param id string|number Unique actor/user/entity
function m.clear_cooldowns(id)
    _cooldowns[id] = nil
end

--- @section Random

--- Sets the seed for the RNG
--- @param s number|nil Seed to use
function m.set_seed(s)
    _seed = s or os.time()
    _state = normalise_seed(_seed)
end

--- Gets the last set seed value
--- @return number seed
function m.get_seed()
    return _seed
end

--- Returns a raw float in [0, 1)
--- @return number
function m.random_float()
    local x = _state
    x = bxor(x, lshift(x, 13))
    x = bxor(x, rshift(x, 17))
    x = bxor(x, lshift(x, 5))
    _state = x
    return (x % TWO_32) / TWO_32
end

--- Returns an integer in [min, max] inclusive
--- @param min number Lower bound
--- @param max number Upper bound
--- @return number
function m.random_int(min, max)
    return min + math.floor(m.random_float() * (max - min + 1))
end

--- Gets the internal RNG state for snapshot/rewind
--- @return number state
function m.get_rng_state()
    return _state
end

--- Restores a previously saved RNG state
--- @param s number State value to restore
function m.set_rng_state(s)
    _state = normalise_seed(s)
end

return m