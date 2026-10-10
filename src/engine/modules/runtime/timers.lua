--- @module runtime.timers
--- @description Generic timer manager with optional owner cleanup.

--- @section Imports

local _log = require("src.engine.core.log")

--- @section Initialisation

local m = {}

local _next_id = 0
local _active = {} -- id -> { id, time, interval, remaining, fn, owner }

--- @section Helpers

local function add(delay, interval, count, fn, owner)
    assert(type(fn) == "function", "timer callback must be a function")
    _next_id = _next_id + 1
    _active[_next_id] = {
        id = _next_id,
        time = delay,
        interval = interval,
        remaining = count, -- fires left, -1 = infinite
        fn = fn,
        owner = owner,
    }
    return _next_id
end

--- @section API

--- Run a function once after a delay
--- @param delay number Seconds to wait
--- @param fn function Callback to call
--- @param owner string|nil Owner name, for remove_owner cleanup
--- @return number id Timer ID
function m.set_timer(delay, fn, owner)
    assert(type(delay) == "number" and delay >= 0, "delay must be >= 0")
    return add(delay, 0, 1, fn, owner)
end

--- Run a function repeatedly (like setInterval)
--- @param interval number Interval in seconds
--- @param fn function Callback to call
--- @param count number|nil Number of times to fire (default -1 = infinite)
--- @param owner string|nil Owner name, for remove_owner cleanup
--- @return number id Timer ID
function m.repeat_timer(interval, fn, count, owner)
    assert(type(interval) == "number" and interval > 0, "interval must be > 0")
    count = count or -1
    assert(count == -1 or count > 0, "count must be -1 or > 0")
    return add(interval, interval, count, fn, owner)
end

--- Cancel a timer by ID
--- @param id number Timer ID
function m.cancel_timer(id)
    _active[id] = nil
end

--- Cancel every timer registered by an owner
--- @param owner string Owner name
function m.remove_owner(owner)
    for id, timer in pairs(_active) do
        if timer.owner == owner then _active[id] = nil end
    end
end

--- Clear all active timers
function m.clear_all_timers()
    _active = {}
end

--- Advances timers. Call once per frame (client) or per tick (server)
--- @param dt number Delta time in seconds
function m.update(dt)
    -- Snapshot ids so callbacks can safely add or cancel timers
    local ids = {}
    for id in pairs(_active) do ids[#ids + 1] = id end
    table.sort(ids)

    for _, id in ipairs(ids) do
        local timer = _active[id] -- may have been cancelled by an earlier callback
        if timer then
            timer.time = timer.time - dt
            if timer.time <= 0 then
                if timer.remaining > 0 then timer.remaining = timer.remaining - 1 end

                if timer.remaining == 0 then
                    _active[id] = nil
                else
                    -- carry the overshoot so repeats don't drift
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

m.update_timer = m.update -- old name

return m