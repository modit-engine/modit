--- @module runtime.callbacks
--- @description Lightweight named callback registry

local m = {}

--- @section Tables

local _registry = {} -- name -> function

--- @section Module Functions

--- Register a callback
--- @param name string Unique key
--- @param fn function The function to store
--- @param overwrite boolean|nil Set true to replace an existing entry (default false)
function m.register_callback(name, fn, overwrite)
    assert(type(name) == "string", "name must be string")
    assert(type(fn) == "function", "fn must be function")
    if _registry[name] and not overwrite then
        error(("callback '%s' exists"):format(name), 2)
    end
    _registry[name] = fn
end

--- Trigger a callback
--- @param name string Key to look up
--- @return any ... Whatever the callback returns, or nil + error message if it doesn't exist
function m.trigger_callback(name, ...)
    local cb = _registry[name]
    if not cb then
        return nil, ("callback '%s' not found"):format(name)
    end
    return cb(...)
end

--- Remove a callback
--- @param name string Key to remove
function m.unregister_callback(name)
    _registry[name] = nil
end

--- Check whether a callback exists
--- @param name string Key to check
--- @return boolean
function m.callback_exists(name)
    return _registry[name] ~= nil
end

--- Iterate over all callbacks
--- @return function iterator
--- @return table state
function m.get_each_callback()
    return next, _registry
end

return m