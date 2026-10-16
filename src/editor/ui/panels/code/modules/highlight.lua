--- @module highlight
--- @file src/editor/ui/panels/code/modules/highlight.lua
--- @description Pure Lua syntax highlighter and lexical tokenizer with LDoc tag and bracket nesting support.

--- @section Constants

local KEYWORDS = {}
for word in ("local and or not"):gmatch("%a+") do 
    KEYWORDS[word] = true 
end

local CONTROL = {}
for word in ("function if then else elseif end for while do repeat until return break goto in"):gmatch("%a+") do
    CONTROL[word] = true
end

local CONSTANTS = { 
    ["true"] = true, 
    ["false"] = true, 
    ["nil"] = true 
}

--- @section Initialisation

local m = {}

--- @section Helpers

--- Highlights parts of a doc comment line (`--- @tag name type description`)
--- @param line_text string Full line string
--- @param pos number Current position index in string
--- @param line_length number Total line length
--- @param emit_func function Token emitter callback
local function doc_comment(line_text, pos, line_length, emit_func)
    local _, tag_e, tag = line_text:find("^%-%-%-%s*(@%a+)", pos)
    if not tag then
        emit_func(pos, line_length, "comment")
        return
    end

    local tag_s = tag_e - #tag + 1
    emit_func(pos, tag_s - 1, "comment")
    emit_func(tag_s, tag_e, "doctag")

    local current_pos = tag_e + 1
    local function word(kind)
        local _, ws_e = line_text:find("^%s+", current_pos)
        local start_pos = ws_e and ws_e + 1 or current_pos
        local match_s, match_e = line_text:find("^%S+", start_pos)
        if not match_s then return false end
        emit_func(match_s, match_e, kind)
        current_pos = match_e + 1
        return true
    end

    local tag_name = tag:sub(2)
    if tag_name == "param" or tag_name == "field" then
        if word("docname") then word("doctype") end
    elseif tag_name == "class" or tag_name == "return" or tag_name == "type" or tag_name == "alias" then
        word("doctype")
    end

    if current_pos <= line_length then 
        emit_func(current_pos, line_length, "comment") 
    end
end

--- Tokenizes a single line into token structures { s, e, kind }
--- @param line_text string Text of the line to tokenize
--- @param parse_state string|boolean Multiline string/comment state from previous line
--- @param bracket_depth number Opening bracket depth count from previous line
--- @return table tokens Array of token tables
--- @return string|boolean state_out Multiline parse state at line end
--- @return number depth_out Bracket depth at line end
local function tokenise(line_text, parse_state, bracket_depth)
    local tokens, token_count = {}, 0
    local line_length, pos = #line_text, 1

    local function emit(start_char, end_char, kind)
        local last_token = tokens[token_count]
        if last_token and last_token.kind == kind and last_token.e == start_char - 1 then
            last_token.e = end_char
        else
            token_count = token_count + 1
            tokens[token_count] = { s = start_char, e = end_char, kind = kind }
        end
    end

    if parse_state then
        local kind = parse_state:sub(1, 1) == "c" and "comment" or "string"
        local level = tonumber(parse_state:sub(2))
        local _, end_match = line_text:find("]" .. string.rep("=", level) .. "]", 1, true)
        if not end_match then
            if line_length > 0 then emit(1, line_length, kind) end
            return tokens, parse_state, bracket_depth
        end
        emit(1, end_match, kind)
        pos = end_match + 1
        parse_state = false
    end

    while pos <= line_length do
        local _, whitespace_end = line_text:find("^%s+", pos)
        if whitespace_end then
            pos = whitespace_end + 1
        else
            local char = line_text:sub(pos, pos)

            if char == "-" and line_text:sub(pos + 1, pos + 1) == "-" then
                local equals_pat = line_text:match("^%-%-%[(=*)%[", pos)
                if equals_pat then
                    local _, comment_end = line_text:find("]" .. equals_pat .. "]", pos + #equals_pat + 4, true)
                    if comment_end then
                        emit(pos, comment_end, "comment")
                        pos = comment_end + 1
                    else
                        emit(pos, line_length, "comment")
                        return tokens, "c" .. #equals_pat, bracket_depth
                    end
                else
                    doc_comment(line_text, pos, line_length, emit)
                    pos = line_length + 1
                end

            elseif char == "[" and line_text:match("^%[=*%[", pos) then
                local equals_pat = line_text:match("^%[(=*)%[", pos)
                local _, string_end = line_text:find("]" .. equals_pat .. "]", pos + #equals_pat + 2, true)
                if string_end then
                    emit(pos, string_end, "string")
                    pos = string_end + 1
                else
                    emit(pos, line_length, "string")
                    return tokens, "s" .. #equals_pat, bracket_depth
                end

            elseif char == '"' or char == "'" then
                local index = pos + 1
                while index <= line_length do
                    local current_char = line_text:sub(index, index)
                    if current_char == "\\" then 
                        index = index + 2
                    elseif current_char == char then 
                        break
                    else 
                        index = index + 1 
                    end
                end
                local end_pos = math.min(index, line_length)
                emit(pos, end_pos, "string")
                pos = end_pos + 1

            elseif char:match("%d") or (char == "." and line_text:sub(pos + 1, pos + 1):match("%d")) then
                local _, num_end = line_text:find("^0[xX]%x+", pos)
                if not num_end then _, num_end = line_text:find("^%d+%.?%d*[eE][+-]?%d+", pos) end
                if not num_end then _, num_end = line_text:find("^%d*%.?%d+", pos) end
                num_end = num_end or pos
                emit(pos, num_end, "number")
                pos = num_end + 1

            elseif char:match("[%a_]") then
                local _, word_end = line_text:find("^[%a_][%w_]*", pos)
                local identifier = line_text:sub(pos, word_end)
                local kind = "variable"
                if KEYWORDS[identifier] then 
                    kind = "keyword"
                elseif CONTROL[identifier] then 
                    kind = "control"
                elseif CONSTANTS[identifier] then 
                    kind = "constant"
                elseif identifier == "self" then 
                    kind = "self"
                elseif line_text:find("^%s*[%(\"'{]", word_end + 1) then 
                    kind = "func"
                elseif pos > 1 and line_text:sub(pos - 1, pos - 1) == "."
                    and line_text:sub(pos - 2, pos - 2) ~= "."
                    and line_text:find("^%.[%w_%.:]*%s*[%(\"'{]", word_end + 1) then
                    kind = "member"
                end
                emit(pos, word_end, kind)
                pos = word_end + 1

            else
                local kind = "text"
                if char == "(" or char == "{" or char == "[" then
                    bracket_depth = bracket_depth + 1
                    kind = "bracket" .. ((bracket_depth - 1) % 3 + 1)
                elseif (char == ")" or char == "}" or char == "]") and bracket_depth > 0 then
                    kind = "bracket" .. ((bracket_depth - 1) % 3 + 1)
                    bracket_depth = bracket_depth - 1
                end
                emit(pos, pos, kind)
                pos = pos + 1
            end
        end
    end

    return tokens, false, bracket_depth
end

--- @section Functions

--- Updates highlighting tokens cache for buffer lines up to specified line index
--- @param target_buffer table Target text buffer instance
--- @param last_line number Last line index to update (1-based)
function m.update(target_buffer, last_line)
    local highlight_cache = target_buffer.hl
    local parse_state = false
    local bracket_depth = 0

    for line_index = 1, last_line do
        local line_text = target_buffer.lines[line_index]
        local cache_entry = highlight_cache[line_index]

        if not (cache_entry 
            and cache_entry.text == line_text 
            and cache_entry.state_in == parse_state 
            and cache_entry.depth_in == bracket_depth) then
            
            local tokens, state_out, depth_out = tokenise(line_text, parse_state, bracket_depth)
            cache_entry = {
                text = line_text, 
                toks = tokens,
                state_in = parse_state, 
                depth_in = bracket_depth,
                state_out = state_out, 
                depth_out = depth_out,
            }
            highlight_cache[line_index] = cache_entry
        end

        parse_state = cache_entry.state_out
        bracket_depth = cache_entry.depth_out
    end
end

return m