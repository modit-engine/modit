--- File locations in Lua errors and traceback lines. No filesystem work until clicked.
local m = {}

-- Lua truncates long filenames from the left. Match the remaining suffix only
-- when it identifies one file in the project or engine/editor source tree.
local function resolve_shortened(path, project)
    local fs = require("src.engine.backend.platform." .. require("ffi").os:lower() .. ".filesystem")
    local suffix = path:sub(4):lower()
    local matches, visited = {}, {}
    local function scan(directory, depth)
        if depth > 32 then return end
        local key = directory:lower()
        if visited[key] then return end
        visited[key] = true
        for _, entry in ipairs(fs.list(directory)) do
            if entry.name:sub(1, 1) ~= "." then
                local candidate = directory .. "/" .. entry.name
                if entry.dir then
                    scan(candidate, depth + 1)
                elseif candidate:lower():sub(-#suffix) == suffix then
                    matches[#matches + 1] = candidate
                end
            end
        end
    end
    if project then scan(project:gsub("\\", "/"):gsub("/+$", ""), 0) end
    scan("src", 0)
    if #matches == 1 then return matches[1] end
    if #matches > 1 then return nil, "Multiple source files match: " .. path end
end

function m.parse(text)
    local path, line = text:match('%[string "(@?.-)"%]:(%d+)')
    if not path then
        path, line = text:match('(.-%.lua):(%d+)')
    end
    if not path or not path:match('%.lua$') then return end
    path = path:gsub('\\', '/'):gsub('^%s+', ''):gsub('^@', '')
    -- Strip a message prefix, while retaining drive letters and spaces in paths.
    path = path:match('(%a:/.*)') or path:match('^.*:%s+(.+)$') or path
    path = path:gsub('^["\']', '')
    line = tonumber(line)
    if path == '' or line < 1 then return end
    return { path = path, line = line }
end

function m.resolve(location, project)
    local path = location.path
    if path:sub(1, 3) == '...' then return resolve_shortened(path, project) end
    local candidates = {}
    local absolute = path:match('^%a:/') or path:sub(1, 1) == '/'
    if absolute then
        candidates = { path }
    else
        if path:match('^src/') or path:match('^projects/') then
            candidates[#candidates + 1] = path
        end
        if project then
            candidates[#candidates + 1] = project .. '/' .. path
            candidates[#candidates + 1] = project .. '/game/' .. path
        end
        candidates[#candidates + 1] = path
    end
    for _, candidate in ipairs(candidates) do
        candidate = candidate:gsub('/%./', '/'):gsub('^%./', '')
        local file = io.open(candidate, 'rb')
        if file then
            file:close()
            return candidate
        end
    end
end

return m
