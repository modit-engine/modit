--- Read-only streamed audio previews. The editor owns its preview audio device.
local raylib = require("src.engine.backend.raylib.ffi").lib
local draw = require("src.sdk.client.draw2d")
local _engine = require("src.engine")
local _ui = _engine.ui
local _ui_input = _ui.input

local audio = {}
local extensions = { wav = true, ogg = true, mp3 = true, flac = true }
local active_asset
local owns_device = false
local volume = 0.5

function audio.supports(path)
    return extensions[path:lower():match("%.([^%.]+)$")] == true
end

function audio.stop(asset)
    if asset and asset.music then
        raylib.StopMusicStream(asset.music)
        asset.status = "Stopped"
    end
end

function audio.release(asset)
    audio.stop(asset)
    if asset.music then
        raylib.UnloadMusicStream(asset.music)
        asset.music = nil
    end
    if active_asset == asset then
        active_asset = nil
    end
end

function audio.activate(asset)
    if active_asset ~= asset then
        audio.stop(active_asset)
        active_asset = asset
    end
end

function audio.load(asset, path)
    if asset.path == path then return end
    audio.release(asset)
    asset.path, asset.error = path, nil

    if not raylib.IsAudioDeviceReady() then
        raylib.InitAudioDevice()
        owns_device = raylib.IsAudioDeviceReady()
    end
    if not raylib.IsAudioDeviceReady() then
        asset.error = "Audio device unavailable."
        return
    end
    if not raylib.FileExists(path) then
        asset.error = "Audio file not found."
        return
    end

    local music = raylib.LoadMusicStream(path)
    if not raylib.IsMusicValid(music) then
        asset.error = "Could not preview audio (damaged or unsupported format)."
        return
    end
    music.looping = false
    asset.music = music
    asset.duration = tonumber(raylib.GetMusicTimeLength(music))
    asset.status = "Stopped"
    raylib.SetMusicVolume(music, volume)
end

function audio.toggle(asset)
    if not asset.music then return end
    audio.activate(asset)
    if asset.status == "Playing" then
        raylib.PauseMusicStream(asset.music)
        asset.status = "Paused"
    else
        if asset.status == "Paused" then
            raylib.ResumeMusicStream(asset.music)
        else
            raylib.PlayMusicStream(asset.music)
        end
        raylib.SetMusicVolume(asset.music, volume)
        asset.status = "Playing"
    end
end

function audio.set_volume(value)
    volume = math.max(0, math.min(1, value))
    if active_asset and active_asset.music then
        raylib.SetMusicVolume(active_asset.music, volume)
    end
end

function audio.update(tab)
    audio.activate(tab and tab.audio and tab.asset or nil)
    if active_asset and active_asset.music and active_asset.status == "Playing" then
        raylib.UpdateMusicStream(active_asset.music)
        if not raylib.IsMusicStreamPlaying(active_asset.music) then
            active_asset.status = "Stopped"
        end
    end
end

function audio.shutdown()
    audio.activate(nil)
    if owns_device then
        raylib.CloseAudioDevice()
        owns_device = false
    end
end

local function time_label(seconds)
    seconds = math.max(0, math.floor(seconds))
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

local function volume_slider(x, y, width, theme)
    local slider_id = _ui_input.new_id()
    local hovered = _ui_input.in_rect(x - 5, y, width + 10, 24)
    if hovered then
        _ui_input.set_hot(slider_id)
        _ui_input.set_cursor("hand")
        if _ui_input.pressed() then _ui_input.set_active(slider_id) end
    end
    local dragging = _ui_input.is_active(slider_id) and _ui_input.down()
    if dragging then
        local mouse_x = _ui_input.mouse()
        audio.set_volume((mouse_x - x) / width)
    end
    draw.set_colour(theme.bg_hover)
    draw.rect(x, y + 10, width, 4)
    draw.set_colour(theme.accent)
    draw.rect(x, y + 10, width * volume, 4)
    draw.set_colour((hovered or dragging) and theme.text_primary or theme.accent)
    draw.rect(x + width * volume - 4, y + 5, 8, 14)
end

function audio.draw(tab, viewport, theme)
    tab.asset = tab.asset or {}
    local asset = tab.asset
    audio.load(asset, tab.path)
    audio.activate(asset)
    local x, y, width, height = viewport.x, viewport.y, viewport.w, viewport.h
    if width <= 0 or height <= 24 then return end

    draw.set_colour(theme.bg_main)
    draw.rect(x, y, width, height)
    draw.push_clip(x, y, width, height - 24)
    local panel_width = math.max(1, math.min(400, width - 40))
    local panel_x = x + (width - panel_width) / 2
    local panel_y = y + math.max(12, (height - 24 - 176) / 2)
    local centre_x = x + width / 2
    local function centred_label(text, offset, size, colour)
        _ui.label(text, centre_x - _ui_input.measure(text, size) / 2,
            panel_y + offset, size, colour)
    end

    centred_label(tab.name, 0, 18, theme.text_primary)
    if asset.error then
        centred_label(asset.error, 34, 14, theme.text_secondary)
        if _ui.button("Retry", centre_x - 40, panel_y + 76, 80, 28, { size = 14 }) then
            asset.path = nil
        end
    else
        local elapsed = tonumber(raylib.GetMusicTimePlayed(asset.music))
        centred_label(time_label(elapsed) .. " / " .. time_label(asset.duration)
            .. "   " .. asset.status, 32, 14, theme.text_secondary)
        draw.set_colour(theme.bg_panel)
        draw.rect(panel_x, panel_y + 58, panel_width, 3)
        draw.set_colour(theme.accent)
        draw.rect(panel_x, panel_y + 58, panel_width * math.min(1,
            elapsed / math.max(0.001, asset.duration)), 3)
        if _ui.button(asset.status == "Playing" and "Pause" or "Play",
            centre_x - 84, panel_y + 76, 80, 28, { size = 14 }) then
            audio.toggle(asset)
        end
        if _ui.button("Stop", centre_x + 4, panel_y + 76, 80, 28, { size = 14 }) then
            audio.stop(asset)
        end
        local slider_width = math.max(1, math.min(300, panel_width - 16))
        volume_slider(centre_x - slider_width / 2, panel_y + 152, slider_width, theme)
        centred_label(("Volume  %.0f%%"):format(volume * 100), 120, 14, theme.text_secondary)
    end
    draw.pop_clip()
    draw.set_colour(theme.bg_panel)
    draw.rect(x, y + height - 24, width, 24)
    draw.push_clip(x, y + height - 24, width, 24)
    _ui.label(tab.path, x + 10, y + height - 20, 16, theme.text_secondary)
    draw.pop_clip()
end

return audio