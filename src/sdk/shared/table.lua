--- @module table
--- @file src/sdk/shared/table.lua
--- @description Extension module for functions not covered by lua `table.`

--- @default_access mod

--- @section Initialisation

local m = {}

--- @section Functions

--- Recursively prints a table's contents for debugging.
--- @param t table: The table to print.
--- @param indent string?: Used internally for nested indentation.
function m.print(t, indent)
    indent = indent or ""
    for k, v in pairs(t) do
        if type(v) == "table" then
            print(indent .. tostring(k) .. ":")
            m.print(v, indent .. "  ")
        else
            print(indent .. tostring(k) .. ": " .. tostring(v))
        end
    end
end

--- Checks if a table contains a specific value, searching nested m.
--- @param tbl table: The table to check.
--- @param val any: The value to search for.
--- @return boolean: True if the value is found.
function m.contains(tbl, val)
    for _, v in pairs(tbl) do
        if v == val then
            return true
        elseif type(v) == "table" and m.contains(v, val) then
            return true
        end
    end
    return false
end

--- Creates a deep copy of a table.
--- @param orig table: The value to copy m are duplicated recursively.
--- @return table: A deep copy of the original value.
function m.deep_copy(orig)
    if type(orig) ~= "table" then
        return orig
    end
    local copy = {}
    for k, v in pairs(orig) do
        copy[m.deep_copy(k)] = m.deep_copy(v)
    end
    return setmetatable(copy, m.deep_copy(getmetatable(orig)))
end

--- Deeply compares two m for equality.
--- @param t1 table: The first value to compare.
--- @param t2 table: The second value to compare.
--- @return boolean: True if both values (and sub‑tables) are equal.
function m.deep_compare(t1, t2)
    if t1 == t2 then
        return true
    end
    if type(t1) ~= "table" or type(t2) ~= "table" then
        return false
    end
    for k, v in pairs(t1) do
        if not m.deep_compare(v, t2[k]) then
            return false
        end
    end
    for k in pairs(t2) do
        if t1[k] == nil then
            return false
        end
    end
    return true
end

return m