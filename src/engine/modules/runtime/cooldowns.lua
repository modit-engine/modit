--- @module runtime.cooldowns
--- @description Cooldown tracker driven by an accumulated clock. Works for keys, users, or global.

local m = {}

--- @section Tables

local _registry = {} -- id -> kind -> { expires }
local now = 0        -- seconds, advanced by m.update(dt)

--- @section API

--- Advances the cooldown clock. Call once per frame (client) or per tick (server)
--- @param dt number Delta time in seconds
function m.update(dt)
    now = now + dt
end

--- Add a cooldown for a given id + kind
--- @param id string|number Unique actor/user/entity
--- @param kind string Action key
--- @param duration number Duration in seconds
function m.add_cooldown(id, kind, duration)
    assert(id ~= nil, "add_cooldown: id is required")
    assert(kind ~= nil, "add_cooldown: kind is required")
    assert(type(duration) == "number" and duration > 0, "add_cooldown: duration must be > 0")

    _registry[id] = _registry[id] or {}
    _registry[id][kind] = { expires = now + duration }
end

--- Check if a cooldown is still active
--- @param id string|number Unique actor/user/entity
--- @param kind string Action key
--- @return boolean active
function m.check_cooldown(id, kind)
    local data = _registry[id] and _registry[id][kind]
    return data ~= nil and now < data.expires
end

--- Get remaining time on cooldown (0 if none)
--- @param id string|number Unique actor/user/entity
--- @param kind string Action key
--- @return number seconds
function m.cooldown_time_remaining(id, kind)
    local data = _registry[id] and _registry[id][kind]
    if not data then return 0 end
    return math.max(0, data.expires - now)
end

--- Clear a specific cooldown
--- @param id string|number Unique actor/user/entity
--- @param kind string Action key
function m.clear_cooldown(id, kind)
    if _registry[id] then
        _registry[id][kind] = nil
        if not next(_registry[id]) then _registry[id] = nil end
    end
end

--- Remove all cooldowns for a given id
--- @param id string|number Unique actor/user/entity
function m.clear_all_cooldowns(id)
    _registry[id] = nil
end

--- Clear all expired cooldowns
function m.clear_expired_cooldowns()
    for id, kinds in pairs(_registry) do
        for kind, data in pairs(kinds) do
            if now >= data.expires then
                kinds[kind] = nil
            end
        end
        if not next(kinds) then
            _registry[id] = nil
        end
    end
end

return m