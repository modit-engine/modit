--- @module json
--- @file src/engine/core/json.lua
--- @description Lightweight dependency-free JSON encoder and decoder.

--- @section Module

local m = {}

--- @section Encoder

local function encode_string(value)
    return '"' .. value:gsub('[%z\1-\31\\"]', function(char)
        local escapes = {
            ['"'] = '\\"',
            ['\\'] = '\\\\',
            ['\b'] = '\\b',
            ['\f'] = '\\f',
            ['\n'] = '\\n',
            ['\r'] = '\\r',
            ['\t'] = '\\t'
        }

        return escapes[char] or ("\\u%04x"):format(char:byte())
    end) .. '"'
end

local function encode_value(value, seen)
    local value_type = type(value)

    if value == nil then return "null" end
    if value_type == "boolean" then return value and "true" or "false" end
    if value_type == "number" then
        if value ~= value or value == math.huge or value == -math.huge then error("json.encode: invalid number") end
        return tostring(value)
    end
    if value_type == "string" then return encode_string(value) end
    if value_type ~= "table" then error("json.encode: unsupported type '" .. value_type .. "'") end

    seen = seen or {}
    if seen[value] then error("json.encode: circular reference") end
    seen[value] = true

    local is_array = true
    local length = #value

    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 or key > length then
            is_array = false
            break
        end
    end

    local result = {}

    if is_array then
        for i = 1, length do
            result[#result + 1] = encode_value(value[i], seen)
        end
        seen[value] = nil
        return "[" .. table.concat(result, ",") .. "]"
    end

    for key, item in pairs(value) do
        if type(key) ~= "string" then
            seen[value] = nil
            error("json.encode: object keys must be strings")
        end
        result[#result + 1] = encode_string(key) .. ":" .. encode_value(item, seen)
    end

    seen[value] = nil
    return "{" .. table.concat(result, ",") .. "}"
end

--- Encodes a Lua value as JSON.
--- @param value any Value to encode.
--- @return string json Encoded JSON string.
function m.encode(value)
    return encode_value(value)
end

--- @section Decoder

local function decode_error(input, index, message)
    error(("json.decode: %s at position %d"):format(message, index))
end

local function decode_value(input, index)
    local length = #input

    while index <= length and input:sub(index, index):match("%s") do
        index = index + 1
    end

    if index > length then decode_error(input, index, "unexpected end of input") end

    local char = input:sub(index, index)

    if char == '"' then
        local result = {}
        index = index + 1

        while index <= length do
            char = input:sub(index, index)

            if char == '"' then
                return table.concat(result), index + 1
            end

            if char == "\\" then
                index = index + 1
                if index > length then decode_error(input, index, "unterminated string") end

                local escape = input:sub(index, index)
                local escapes = {
                    ['"'] = '"',
                    ['\\'] = '\\',
                    ['/'] = '/',
                    ['b'] = '\b',
                    ['f'] = '\f',
                    ['n'] = '\n',
                    ['r'] = '\r',
                    ['t'] = '\t'
                }

                if escapes[escape] then
                    result[#result + 1] = escapes[escape]
                    index = index + 1
                elseif escape == "u" then
                    local hex = input:sub(index + 1, index + 4)
                    if not hex:match("^%x%x%x%x$") then decode_error(input, index, "invalid unicode escape") end
                    result[#result + 1] = utf8.char(tonumber(hex, 16))
                    index = index + 5
                else
                    decode_error(input, index, "invalid escape sequence")
                end
            else
                if char:byte() < 32 then decode_error(input, index, "invalid control character") end
                result[#result + 1] = char
                index = index + 1
            end
        end

        decode_error(input, index, "unterminated string")
    end

    local literals = {
        ["true"] = true,
        ["false"] = false,
        ["null"] = nil
    }

    for literal, value in pairs(literals) do
        if input:sub(index, index + #literal - 1) == literal then
            return value, index + #literal
        end
    end

    if char == "[" then
        local result = {}
        index = index + 1

        while true do
            while index <= length and input:sub(index, index):match("%s") do index = index + 1 end
            if input:sub(index, index) == "]" then return result, index + 1 end

            local value
            value, index = decode_value(input, index)
            result[#result + 1] = value

            while index <= length and input:sub(index, index):match("%s") do index = index + 1 end

            char = input:sub(index, index)
            if char == "]" then return result, index + 1 end
            if char ~= "," then decode_error(input, index, "expected ',' or ']'") end
            index = index + 1
        end
    end

    if char == "{" then
        local result = {}
        index = index + 1

        while true do
            while index <= length and input:sub(index, index):match("%s") do index = index + 1 end
            if input:sub(index, index) == "}" then return result, index + 1 end

            local key
            key, index = decode_value(input, index)
            if type(key) ~= "string" then decode_error(input, index, "object key must be a string") end

            while index <= length and input:sub(index, index):match("%s") do index = index + 1 end
            if input:sub(index, index) ~= ":" then decode_error(input, index, "expected ':'") end
            index = index + 1

            local value
            value, index = decode_value(input, index)
            result[key] = value

            while index <= length and input:sub(index, index):match("%s") do index = index + 1 end

            char = input:sub(index, index)
            if char == "}" then return result, index + 1 end
            if char ~= "," then decode_error(input, index, "expected ',' or '}'") end
            index = index + 1
        end
    end

    local number = input:match("^(-?%d+%.?%d*[eE]?[+-]?%d*)", index)
    if number then
        local value = tonumber(number)
        if not value then decode_error(input, index, "invalid number") end
        return value, index + #number
    end

    decode_error(input, index, "unexpected character '" .. char .. "'")
end

--- Decodes a JSON string into a Lua value.
--- @param input string JSON string to decode.
--- @return any value Decoded Lua value.
function m.decode(input)
    if type(input) ~= "string" then error("json.decode: input must be a string") end

    local value, index = decode_value(input, 1)

    while index <= #input and input:sub(index, index):match("%s") do
        index = index + 1
    end

    if index <= #input then decode_error(input, index, "unexpected trailing data") end

    return value
end

return m