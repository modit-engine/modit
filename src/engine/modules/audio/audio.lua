--- @module audio
--- @file src/engine/modules/audio.lua
--- @description Engine audio interface for sound effects and music playback.

--- @section Imports

local _backend = require("src.engine.backend").audio

--- @section Initialisation

local m = {}

--- @section Sound Effects

--- Load a sound effect from file.
--- @param key string Unique identifier for this sound
--- @param path string Path to sound file
--- @return boolean success Whether the sound loaded successfully
function m.load_sound(key, path)
    return _backend.load_sound(key, path)
end

--- Play a sound effect.
--- @param key string Sound identifier
function m.play_sound(key)
    _backend.play_sound(key)
end

--- Set volume for a sound effect.
--- @param key string Sound identifier
--- @param volume number Volume from 0.0 to 1.0
function m.set_sound_volume(key, volume)
    _backend.set_sound_volume(key, volume)
end

--- Set pitch for a sound effect.
--- @param key string Sound identifier
--- @param pitch number Playback pitch
function m.set_sound_pitch(key, pitch)
    _backend.set_sound_pitch(key, pitch)
end

--- Unload a sound effect.
--- @param key string Sound identifier
function m.unload_sound(key)
    _backend.unload_sound(key)
end

--- @section Music

--- Load a music track from file.
--- @param key string Unique identifier for this music
--- @param path string Path to audio file
--- @return boolean success Whether the music loaded successfully
function m.load_music(key, path)
    return _backend.load_music(key, path)
end

--- Play music, stopping the current track if necessary.
--- @param key string Music identifier
--- @param loop? boolean Whether to loop
function m.play_music(key, loop)
    _backend.play_music(key, loop)
end

--- Stop current music.
function m.stop_music()
    _backend.stop_music()
end

--- Pause current music.
function m.pause_music()
    _backend.pause_music()
end

--- Resume current music.
function m.resume_music()
    _backend.resume_music()
end

--- Set music volume.
--- @param key string Music identifier
--- @param volume number Volume from 0.0 to 1.0
function m.set_music_volume(key, volume)
    _backend.set_music_volume(key, volume)
end

--- Set music pitch.
--- @param key string Music identifier
--- @param pitch number Playback pitch
function m.set_music_pitch(key, pitch)
    _backend.set_music_pitch(key, pitch)
end

--- Check if music is currently playing.
--- @return boolean playing Whether music is playing
function m.is_music_playing()
    return _backend.is_music_playing()
end

--- Unload a music track.
--- @param key string Music identifier
function m.unload_music(key)
    _backend.unload_music(key)
end

--- Clean up all audio resources.
function m.cleanup()
    _backend.cleanup()
end

return m