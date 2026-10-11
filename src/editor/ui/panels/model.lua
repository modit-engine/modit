--- @module model_preview
--- @file src/editor/ui/panels/model.lua
--- @description Read-only model tabs with orbit controls and named assembly parts.

--- @section Imports

local _raylib = require("src.engine.backend.raylib.ffi").lib
local _model = require("src.engine.modules.render.model")
local _camera = require("src.engine.modules.camera.cam")
local _draw = require("src.engine.modules.render.draw")
local _input = require("src.engine.ui.modules.input")
local _components = require("src.engine.ui.components")

--- @section Initialisation

local m = {}
local serial = 0
local extensions = { obj = true, gltf = true, glb = true, iqm = true, vox = true, m3d = true }

--- @section Asset Lifecycle

function m.supports(path)
    return extensions[path:lower():match("%.([^%.]+)$")] == true
end

function m.release(asset)
    if asset.target then _raylib.UnloadRenderTexture(asset.target) end
    if asset.key then _model.unload(asset.key) end
    asset.target, asset.key, asset.instance, asset.path = nil, nil, nil, nil
    asset.rows, asset.selected, asset.dragging = nil, nil, nil
end

local function collect_parts(asset, instance, name, depth)
    -- VOX colour batches and unnamed transform wrappers are implementation details.
    local internal = asset.voxel and (name:match("^node_%d") or name:match("^palette_%d"))
    if not internal then
        asset.rows[#asset.rows + 1] = { instance = instance, name = name, depth = depth }
        depth = depth + 1
    end
    local names = {}
    for part_name in pairs(instance.parts) do names[#names + 1] = part_name end
    table.sort(names)
    for _, part_name in ipairs(names) do
        collect_parts(asset, instance.parts[part_name], part_name, depth)
    end
end

function m.load(asset, path)
    if asset.path == path then return end
    m.release(asset)
    serial = serial + 1
    asset.path, asset.key, asset.error = path, "editor_preview:" .. serial, nil
    asset.voxel = path:lower():match("%.vox$") ~= nil
    local loader = asset.voxel and _model.load_asset or _model.load
    local ok, reason = loader({ key = asset.key, path = path })
    if not ok then asset.error = reason; return end
    asset.instance, reason = _model.create_instance({ key = asset.key })
    if not asset.instance then asset.error = reason; return end

    -- Normalize only this preview instance, keeping large VOX scenes inside the camera range.
    local bounds
    bounds, reason = _model.get_bounds(asset.instance)
    if not bounds then asset.error = reason; return end
    local extent = math.max(.001, bounds.max.x - bounds.min.x,
        bounds.max.y - bounds.min.y, bounds.max.z - bounds.min.z)
    for _, axis in ipairs({ "x", "y", "z" }) do
        asset.instance.scale[axis] = asset.instance.scale[axis] * 4 / extent
    end
    bounds, reason = _model.get_bounds(asset.instance)
    if not bounds then asset.error = reason; return end
    for _, axis in ipairs({ "x", "y", "z" }) do
        asset.instance[axis] = asset.instance[axis] - (bounds.min[axis] + bounds.max[axis]) / 2
    end
    asset.camera = _camera.new()
    asset.yaw, asset.pitch, asset.distance = .7, .35, 10
    asset.rows, asset.scroll = {}, { y = 0 }
    collect_parts(asset, asset.instance, "Model", 0)
end

local function select_part(asset, instance)
    if asset.selected then asset.selected.tint = asset.previous_tint end
    asset.selected = instance
    if instance then
        asset.previous_tint = instance.tint
        instance.tint = { 255, 190, 100, 255 }
    end
end

--- @section Rendering

local function render_model(asset, width, height)
    if not asset.target or asset.target.texture.width ~= width or asset.target.texture.height ~= height then
        if asset.target then _raylib.UnloadRenderTexture(asset.target) end
        asset.target = nil
        local target = _raylib.LoadRenderTexture(width, height)
        if target.id == 0 then return false, "Could not create model preview surface." end
        asset.target = target
    end

    local camera = asset.camera
    local horizontal = math.cos(asset.pitch) * asset.distance
    camera:set_position(math.sin(asset.yaw) * horizontal, math.sin(asset.pitch) * asset.distance,
        math.cos(asset.yaw) * horizontal)

    -- The editor's screen scissor must not clip the offscreen framebuffer.
    local clip_x, clip_y, clip_width, clip_height = _draw.get_clip()
    _raylib.EndScissorMode()
    _raylib.BeginTextureMode(asset.target)
    _raylib.ClearBackground({ 0, 0, 0, 0 })
    camera:begin_3d()
    local protected, ok, reason = pcall(_model.draw_many, { asset.instance }, camera)
    camera:end_3d()
    _raylib.EndTextureMode()
    if clip_x then _raylib.BeginScissorMode(clip_x, clip_y, clip_width, clip_height) end
    if not protected then return false, tostring(ok) end
    return ok, reason
end

function m.draw(tab, viewport, theme)
    tab.asset = tab.asset or {}
    local asset = tab.asset
    m.load(asset, tab.path)
    local x, y, width, height = viewport.x, viewport.y, viewport.w, viewport.h
    if width < 80 or height < 80 then return end
    _draw.set_colour(theme.bg_main)
    _draw.rect(x, y, width, height)
    if asset.error then
        _draw.push_clip(x, y, width, height)
        _components.label("Could not preview model: " .. asset.error, x + 12, y + 16, 14, theme.text_secondary)
        if _components.button("Retry", x + 12, y + 44, 70, 24, 14) then m.release(asset) end
        _draw.pop_clip()
        return
    end

    local sidebar_width = width >= 380 and 180 or 0
    local view_width, view_height = math.floor(width - sidebar_width), math.floor(height - 56)
    local view_y = y + 32
    if _components.button("Reset view", x + 8, y + 4, 96, 24, 14) then
        asset.yaw, asset.pitch, asset.distance = .7, .35, 10
        select_part(asset, nil)
    end
    if _components.button("Reload", x + 112, y + 4, 68, 24, 14) then
        m.release(asset)
        return
    end

    local mouse_x, mouse_y = _input.mouse()
    local hovered = _input.in_rect(x, view_y, view_width, view_height)
    if hovered and _input.pressed() then
        asset.dragging, asset.mouse_x, asset.mouse_y = true, mouse_x, mouse_y
    end
    if not _input.down() or not hovered then asset.dragging = false end
    if asset.dragging and asset.mouse_x then
        asset.yaw = asset.yaw - (mouse_x - asset.mouse_x) * .01
        asset.pitch = math.max(-1.45, math.min(1.45, asset.pitch + (mouse_y - asset.mouse_y) * .01))
    end
    asset.mouse_x, asset.mouse_y = mouse_x, mouse_y
    if hovered then
        asset.distance = math.max(3.5, math.min(40, asset.distance * math.exp(-_input.wheel() * .12)))
    end

    local ok, reason = render_model(asset, view_width, view_height)
    if not ok then asset.error = reason; return end
    _raylib.DrawTexturePro(asset.target.texture, { 0, 0, view_width, -view_height },
        { x, view_y, view_width, view_height }, { 0, 0 }, 0, { 255, 255, 255, 255 })

    if sidebar_width > 0 then
        local sidebar_x = x + view_width
        _draw.set_colour(theme.bg_panel)
        _draw.rect(sidebar_x, y, sidebar_width, height - 24)
        _components.label("Parts", sidebar_x + 10, y + 9, 14, theme.text_primary)
        _components.scroll_begin(asset.scroll, sidebar_x, y + 32, sidebar_width,
            view_height, #asset.rows * 26)
        for index, row in ipairs(asset.rows) do
            local row_y = y + 32 + (index - 1) * 26 - asset.scroll.y
            local row_x = sidebar_x + 6 + math.min(row.depth, 6) * 10
            local row_width = sidebar_x + sidebar_width - row_x - 12
            local over, clicked = _input.interact(row_x, row_y, row_width, 24)
            if over or row.instance == asset.selected then
                _draw.set_colour(theme.bg_hover)
                _draw.rect(row_x, row_y, row_width, 24)
            end
            _draw.push_clip(row_x, row_y, row_width, 24)
            _components.label(row.name, row_x + 4, row_y + 5, 14,
                row.instance == asset.selected and theme.accent or theme.text_secondary)
            _draw.pop_clip()
            if clicked then
                if row.instance == asset.selected then select_part(asset, nil)
                else select_part(asset, row.instance) end
            end
        end
        _components.scroll_end()
    end
    _draw.set_colour(theme.bg_panel)
    _draw.rect(x, y + height - 24, width, 24)
    _draw.push_clip(x, y + height - 24, width, 24)
    _components.label("Drag to rotate  |  Scroll to zoom", x + 10, y + height - 19, 14, theme.text_secondary)
    _draw.pop_clip()
end

return m
