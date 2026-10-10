--- @module runtime.state
--- @description Named state manager with a metatable proxy for easy key access and optional scope access.

local m = {}

local _states = {}
local _current = "__default"

local _proxy = {}

-- __pairs and __len on tables only work when LuaJIT is built with LUAJIT_ENABLE_LUA52COMPAT.
-- Otherwise use m.dump_state() to iterate.
setmetatable(_proxy, {
    __index = function(_, key)
        local s = _states[_current]
        return s and s[key]
    end,
    __newindex = function(_, key, value)
        _states[_current] = _states[_current] or {}
        _states[_current][key] = value
    end,
    __pairs = function()
        return pairs(_states[_current] or {})
    end,
    __len = function()
        return #(_states[_current] or {})
    end,
})

--- Switch to a named state (creates it if missing)
--- @param name string|nil Name of the state to use (default "__default")
function m.use_state(name)
    _current = name or "__default"
    _states[_current] = _states[_current] or {}
end

--- Get the current state name
--- @return string
function m.current_state()
    return _current
end

--- Set a value in a state (default: current)
--- @param key any Key to set
--- @param value any Value to store
--- @param scope string|nil State name to write to
function m.set_state(key, value, scope)
    local target = scope or _current
    _states[target] = _states[target] or {}
    _states[target][key] = value
end

--- Get a value from a state (default: current)
--- @param key any Key to read
--- @param fallback any Returned when the key is nil (false is a valid stored value)
--- @param scope string|nil State name to read from
--- @return any
function m.get_state(key, fallback, scope)
    local s = _states[scope or _current]
    local value = s and s[key]
    if value == nil then return fallback end
    return value
end

--- Clear a single key from a state (default: current)
--- @param key any Key to clear
--- @param scope string|nil State name to clear from
function m.clear_state(key, scope)
    local target = scope or _current
    if _states[target] then
        _states[target][key] = nil
    end
end

--- Clear all keys from a state (default: current)
--- @param scope string|nil State name to clear
function m.clear_all(scope)
    _states[scope or _current] = {}
end

--- Return the key-value table of a state (default: current)
--- @param scope string|nil State name
--- @return table
function m.dump_state(scope)
    return _states[scope or _current] or {}
end

--- Delete a named state completely
--- @param name string State name
function m.delete_state(name)
    _states[name] = nil
    if _current == name then
        m.use_state("__default")
    end
end

--- List all state names, sorted
--- @return string[]
function m.list_states()
    local list = {}
    for name in pairs(_states) do
        list[#list + 1] = name
    end
    table.sort(list)
    return list
end

--- Temporarily run code in another state scope
--- @param scope string State name to use temporarily
--- @param fn function Function to execute while scoped
function m.with_state(scope, fn)
    local previous = _current
    m.use_state(scope)
    local ok, err = pcall(fn)
    m.use_state(previous)
    if not ok then error(err, 0) end
end

--- Proxy for direct state access (state.data.key = value)
m.data = _proxy

return m