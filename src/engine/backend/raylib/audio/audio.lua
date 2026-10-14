--- @module audio
--- @file src/engine/backend/raylib/modules/audio.lua
--- @description Raylib audio resource loading, playback, control, and cleanup.

--- @section Imports

local _raylib = require("src.engine.backend.raylib.ffi")
local _lib = _raylib.lib

--- @section Initialisation

local m = {
    sounds = {},
    music = {},
    current_music = nil,
    music_loop = {}
}

--- @section Sound Lifecycle

--- Load a sound effect from file.
--- @param key string Unique identifier for this sound
--- @param path string Path to sound file
--- @return boolean success Whether the sound loaded successfully
function m.load_sound(key, path)
    if m.sounds[key] then
        return true
    end

    local sound = _lib.LoadSound(path)

    if not _lib.IsSoundValid(sound) then
        return false
    end

    m.sounds[key] = sound
    return true
end

--- Unload a sound effect.
--- @param key string Sound identifier
function m.unload_sound(key)
    local sound = m.sounds[key]
    if not sound then
        return
    end

    _lib.UnloadSound(sound)
    m.sounds[key] = nil
end

--- Play a sound effect.
--- @param key string Sound identifier
function m.play_sound(key)
    local sound = m.sounds[key]
    if sound then
        _lib.PlaySound(sound)
    end
end

--- Set sound volume.
--- @param key string Sound identifier
--- @param volume number Volume from 0.0 to 1.0
function m.set_sound_volume(key, volume)
    local sound = m.sounds[key]
    if sound then
        _lib.SetSoundVolume(sound, math.max(0, math.min(1, volume)))
    end
end

--- Set sound pitch.
--- @param key string Sound identifier
--- @param pitch number Playback pitch
function m.set_sound_pitch(key, pitch)
    local sound = m.sounds[key]
    if sound then
        _lib.SetSoundPitch(sound, pitch)
    end
end

--- @section Music Lifecycle

--- Load a music track from file.
--- @param key string Unique identifier for this music
--- @param path string Path to audio file
--- @return boolean success Whether the music loaded successfully
function m.load_music(key, path)
    if m.music[key] then
        return true
    end

    local wave = _lib.LoadWave(path)
    if not _lib.IsWaveValid(wave) then
        print("Failed to load wave: " .. path)
        return false
    end

    local sound = _lib.LoadSoundFromWave(wave)
    _lib.UnloadWave(wave)

    if not _lib.IsSoundValid(sound) then
        print("Failed to convert wave to sound: " .. path)
        return false
    end

    m.music[key] = sound
    m.music_loop[key] = false
    return true
end

--- Unload a music track.
--- @param key string Music identifier
function m.unload_music(key)
    local sound = m.music[key]
    if not sound then
        return
    end

    if m.current_music == key then
        _lib.StopSound(sound)
        m.current_music = nil
    end

    _lib.UnloadSound(sound)
    m.music[key] = nil
    m.music_loop[key] = nil
end

--- Play music, stopping the previous track if necessary.
--- @param key string Music identifier
--- @param loop? boolean Whether to loop
function m.play_music(key, loop)
    local sound = m.music[key]
    if not sound then
        return
    end

    if m.current_music and m.current_music ~= key then
        local current = m.music[m.current_music]
        if current then
            _lib.StopSound(current)
        end
    end

    m.current_music = key
    m.music_loop[key] = loop or false
    _lib.PlaySound(sound)
end

--- Stop current music.
function m.stop_music()
    local key = m.current_music
    if key and m.music[key] then
        _lib.StopSound(m.music[key])
        m.current_music = nil
    end
end

--- Pause current music.
function m.pause_music()
    local key = m.current_music
    if key and m.music[key] then
        _lib.PauseSound(m.music[key])
    end
end

--- Resume current music.
function m.resume_music()
    local key = m.current_music
    if key and m.music[key] then
        _lib.ResumeSound(m.music[key])
    end
end

--- Set music volume.
--- @param key string Music identifier
--- @param volume number Volume from 0.0 to 1.0
function m.set_music_volume(key, volume)
    local sound = m.music[key]
    if sound then
        _lib.SetSoundVolume(sound, math.max(0, math.min(1, volume)))
    end
end

--- Set music pitch.
--- @param key string Music identifier
--- @param pitch number Playback pitch
function m.set_music_pitch(key, pitch)
    local sound = m.music[key]
    if sound then
        _lib.SetSoundPitch(sound, pitch)
    end
end

--- Check if current music is playing.
--- @return boolean playing Whether music is playing
function m.is_music_playing()
    local key = m.current_music
    if key and m.music[key] then
        return _lib.IsSoundPlaying(m.music[key])
    end

    return false
end

--- @section Cleanup

--- Clean up all audio resources.
function m.cleanup()
    m.stop_music()

    for key in pairs(m.sounds) do
        m.unload_sound(key)
    end

    for key in pairs(m.music) do
        m.unload_music(key)
    end
end

return m