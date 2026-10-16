--- Read-only image tabs and small, bounded explorer thumbnail cache.
local ffi = require("ffi")
local ray = require("src.engine.backend.raylib.ffi").lib
local draw = require("src.sdk.client.draw2d")
local _engine = require("src.engine")
local _ui = _engine.ui

local m = {}
local extensions = {png=true, jpg=true, jpeg=true, bmp=true, tga=true, gif=true, qoi=true}
local thumbnails, count, serial = {}, 0, 0

function m.supports(path)
    return extensions[path:lower():match("%.([^%.]+)$")] == true
end

function m.release(asset)
    if asset.texture then ray.UnloadTexture(asset.texture); asset.texture = nil end
end

function m.clear_thumbnails()
    for _, asset in pairs(thumbnails) do m.release(asset) end
    thumbnails, count = {}, 0
end

-- Only check timestamps once a second. Decode again only when the file changes.
local function load(asset, path, limit)
    local now = os.clock()
    if asset.path == path and asset.checked and now - asset.checked < 1 then return end
    asset.checked = now
    local modified = tonumber(ray.GetFileModTime(path))
    if asset.path == path and asset.modified == modified then return end
    m.release(asset)
    asset.path, asset.modified = path, modified
    asset.width, asset.height = nil, nil
    local jpeg = path:lower():match("%.jpe?g$")
    local decoded
    if jpeg and ffi.os == "Windows" then
        decoded = require("src.editor.core.windows_image").load(path)
    else
        decoded = ray.LoadImage(path)
    end
    local image = ffi.new("Image[1]", decoded)
    if image[0].data == nil or image[0].width <= 0 or image[0].height <= 0 then
        if image[0].data ~= nil then ray.UnloadImage(image[0]) end
        return
    end
    asset.width, asset.height = image[0].width, image[0].height
    local scale = math.min(1, limit / math.max(asset.width, asset.height))
    if scale < 1 then
        ray.ImageResize(image, math.max(1, math.floor(asset.width * scale)), math.max(1, math.floor(asset.height * scale)))
    end
    local texture = ray.LoadTextureFromImage(image[0])
    ray.UnloadImage(image[0])
    if texture.id ~= 0 then asset.texture = texture end
end

local function fit(asset, x, y, w, h, enlarge)
    local scale = math.min(w / asset.width, h / asset.height, enlarge and math.huge or 1)
    local iw, ih = math.max(1,asset.width*scale), math.max(1,asset.height*scale)
    local ix, iy = math.floor(x+(w-iw)/2), math.floor(y+(h-ih)/2)
    ray.DrawTexturePro(asset.texture, {0,0,asset.texture.width,asset.texture.height},
        {ix,iy,iw,ih}, {0,0}, 0, {255,255,255,255})
    return scale
end

function m.thumbnail(path, x, y, size, theme)
    local asset = thumbnails[path]
    if not asset then
        if count >= 128 then
            local oldest, age
            for key, entry in pairs(thumbnails) do
                if not age or entry.used < age then oldest, age = key, entry.used end
            end
            m.release(thumbnails[oldest]); thumbnails[oldest] = nil; count = count - 1
        end
        asset = {}; thumbnails[path] = asset; count = count + 1
    end
    serial = serial + 1; asset.used = serial
    load(asset, path, 32)
    draw.set_colour(theme.bg_input); draw.rect(x,y,size,size)
    if asset.texture then fit(asset,x,y,size,size,true)
    else _ui.label("?",x+3,y,14,theme.text_tertiary) end
end

function m.draw(tab, viewport, theme)
    tab.asset = tab.asset or {}
    local asset = tab.asset
    load(asset, tab.path, 4096)
    local x,y,w,h = viewport.x,viewport.y,viewport.w,viewport.h
    if w <= 0 or h <= 24 then return end
    draw.set_colour(theme.bg_main);draw.rect(x,y,w,h)
    draw.push_clip(x,y,w,h-24)
    local scale
    if asset.texture then
        local available_w,available_h = math.max(1,w-32), math.max(1,h-56)
        scale = math.min(1,available_w/asset.width,available_h/asset.height)
        local iw,ih = asset.width*scale,asset.height*scale
        local ix,iy = math.floor(x+(w-iw)/2),math.floor(y+(h-24-ih)/2)
        -- Checkerboard makes transparent pixels visible without tinting the image.
        for cy=0,math.ceil(ih/12)-1 do
            for cx=0,math.ceil(iw/12)-1 do
                draw.set_colour((cx+cy)%2==0 and theme.bg_panel or theme.bg_hover)
                draw.rect(ix+cx*12,iy+cy*12,math.min(12,iw-cx*12),math.min(12,ih-cy*12))
            end
        end
        fit(asset,x+16,y+16,available_w,available_h,false)
    else
        _ui.label("Could not preview image (missing, damaged or unsupported).",x+16,y+20,16,theme.text_secondary)
    end
    draw.pop_clip()
    draw.set_colour(theme.bg_panel);draw.rect(x,y+h-24,w,24)
    draw.push_clip(x,y+h-24,w,24)
    local details = asset.texture and ("%d x %d   |   %.0f%%   |   "):format(asset.width,asset.height,scale*100) or ""
    _ui.label(details .. tab.path,x+10,y+h-20,16,theme.text_secondary)
    draw.pop_clip()
end

return m