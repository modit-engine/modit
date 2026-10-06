--- @module hooks
--- @file src/engine/core/hooks.lua
--- @description Event hook system. Listeners can be tagged with an owner so a whole resource can be unhooked at once.

--- @section Imports

local _log = require("src.engine.core.log")

--- @section Initialisation

local m = {}

local registered = {}
local available = {}
local firing = 0
local needs_compact = false

--- @section Helpers

--- Removes dead entries from one listener list, keeping order
local function compact_list(list)
    local write = 0
    for read = 1, #list do
        local entry = list[read]
        if not entry.dead then
            write = write + 1
            list[write] = entry
        end
    end
    for index = #list, write + 1, -1 do
        list[index] = nil
    end
end

--- Removes dead entries from every list
local function compact_all()
    for _, list in pairs(registered) do
        compact_list(list)
    end
    needs_compact = false
end

--- @section Functions

--- Declares a hook name with an optional description
--- @param name string Hook name
--- @param description string|nil What the hook is for
function m.register(name, description)
    available[name] = description or ""
    registered[name] = registered[name] or {}
    _log.print("debug", "[hooks] registered: " .. name)
end

--- Adds a listener to a hook
--- @param name string Hook name
--- @param callback function Called with the arguments given to fire
--- @param owner string|nil Owner tag, used by remove_owner
--- @return function callback The same function, for use with unlisten
function m.listen(name, callback, owner)
    if type(name) ~= "string" then error("hook name must be a string", 2) end
    if type(callback) ~= "function" then error("hook callback must be a function", 2) end

    local list = registered[name]
    if not list then
        list = {}
        registered[name] = list
    end
    list[#list + 1] = { fn = callback, owner = owner }
    _log.print("debug", ("[hooks] listener added: %s%s"):format(name, owner and (" (" .. owner .. ")") or ""))
    return callback
end

--- Calls every listener of a hook in the order they were added
--- @param name string Hook name
--- @param ... any Arguments passed to each listener
function m.fire(name, ...)
    local list = registered[name]
    if not list then return end

    firing = firing + 1
    for index = 1, #list do
        local entry = list[index]
        if not entry.dead then
            local ok, err = pcall(entry.fn, ...)
            if not ok then
                -- Remove the broken listener so it can't spam the log every frame.
                -- Delete these two lines to keep calling it instead
                entry.dead = true
                needs_compact = true
                _log.print("error", ("[hooks] '%s' listener%s removed after error: %s"):format(
                    name, entry.owner and (" from " .. entry.owner) or "", tostring(err)))
            end
        end
    end
    firing = firing - 1

    if firing == 0 and needs_compact then
        compact_all()
    end
end

--- Removes one listener
--- @param name string Hook name
--- @param callback function The function passed to listen
function m.unlisten(name, callback)
    local list = registered[name]
    if not list then return end

    for _, entry in ipairs(list) do
        if entry.fn == callback and not entry.dead then
            entry.dead = true
            if firing == 0 then compact_list(list) else needs_compact = true end
            _log.print("debug", "[hooks] listener removed: " .. name)
            return
        end
    end
end

--- Removes every listener tagged with an owner
--- @param owner string Owner tag, for example a resource name
function m.remove_owner(owner)
    for _, list in pairs(registered) do
        for _, entry in ipairs(list) do
            if entry.owner == owner then entry.dead = true end
        end
    end
    if firing == 0 then compact_all() else needs_compact = true end
end

--- Removes every listener of one hook
--- @param name string Hook name
function m.clear(name)
    local list = registered[name]
    if not list then return end
    for _, entry in ipairs(list) do entry.dead = true end
    if firing == 0 then compact_list(list) else needs_compact = true end
end

--- Removes every listener of every hook
function m.clear_all()
    for _, list in pairs(registered) do
        for _, entry in ipairs(list) do entry.dead = true end
    end
    if firing == 0 then compact_all() else needs_compact = true end
end

--- Lists declared hook names
--- @return table names Sorted array of names
function m.list()
    local names = {}
    for name in pairs(available) do names[#names + 1] = name end
    table.sort(names)
    return names
end

return m