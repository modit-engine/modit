--- @module audio
--- @file src/sdk/client/audio.lua
--- @description Sound effect and music handles, plus global music controls. Needs modules.audio = true in the run config.

--- @section Imports

local _backend = require("src.engine.backend").audio
local _log = require("src.engine.core.log")

--- @section Class Definition

--- @class Sound
--- @field key string|nil Backend key, nil once unloaded
--- @field path string File path
local Sound = {}
Sound.__index = Sound

--- @class Music
--- @field key string|nil Backend key, nil once unloaded
--- @field path string File path
local Music = {}
Music.__index = Music

--- @section State

local live = {}
local next_id = 0

--- @section Initialisation

local m = {}

--- @section Helpers

local function resolve_audio_path(path)
    local file = io.open(path, "rb")
    if file then
        file:close()
        return path, nil
    end

    local game_dir = (rawget(_G, "modit") and rawget(_G, "modit").game_dir) or "game"
    local clean_path = path:gsub("^game/", ""):gsub("^assets/", "")
    
    local candidate_paths = {
        game_dir .. "/" .. path,
        game_dir .. "/assets/" .. clean_path,
        "game/" .. path,
        "game/assets/" .. clean_path
    }

    for _, candidate in ipairs(candidate_paths) do
        file = io.open(candidate, "rb")
        if file then
            file:close()
            return candidate, nil
        end
    end

    return nil, "Audio not found: " .. path
end

local function new_key(kind)
    next_id = next_id + 1
    return kind .. ":" .. next_id
end

local function release(handle, unload)
    if not handle.key then return end
    unload(handle.key)
    live[handle] = nil
    handle.key = nil
end

--- @section Loading

--- Loads a sound effect
--- @access mod
--- @param path string Path to the sound file
--- @return Sound|nil sound Sound handle, or nil on failure
function m.load_sound(path)
    local resolved_path, err = resolve_audio_path(path)
    if not resolved_path then
        _log.warn("audio: " .. tostring(err))
        return nil
    end

    local key = new_key("sound")
    if not _backend.load_sound(key, resolved_path) then
        _log.warn("audio: failed to load sound: " .. tostring(path))
        return nil
    end

    local sound = setmetatable({ key = key, path = path }, Sound)
    live[sound] = true
    return sound
end

--- Loads a music track
--- @access mod
--- @param path string Path to the audio file
--- @return Music|nil music Music handle, or nil on failure
function m.load_music(path)
    local resolved_path, err = resolve_audio_path(path)
    if not resolved_path then
        _log.warn("audio: " .. tostring(err))
        return nil
    end

    local key = new_key("music")
    if not _backend.load_music(key, resolved_path) then
        _log.warn("audio: failed to load music: " .. tostring(path))
        return nil
    end

    local music = setmetatable({ key = key, path = path }, Music)
    live[music] = true
    return music
end

--- @section Sound Methods

--- Plays the sound effect
function Sound:play()
    if not self.key then return end
    _backend.play_sound(self.key)
end

--- Sets the sound volume
--- @param volume number Volume from 0.0 to 1.0
function Sound:set_volume(volume)
    if not self.key then return end
    _backend.set_sound_volume(self.key, volume)
end

--- Sets the sound pitch
--- @param pitch number Playback pitch (1.0 is normal)
function Sound:set_pitch(pitch)
    if not self.key then return end
    _backend.set_sound_pitch(self.key, pitch)
end

--- Unloads the sound
function Sound:unload()
    release(self, _backend.unload_sound)
end

--- @section Music Methods

--- Plays this track, stopping any current music
--- @param loop boolean|nil True to loop
function Music:play(loop)
    if not self.key then return end
    _backend.play_music(self.key, loop)
end

--- Sets the music volume
--- @param volume number Volume from 0.0 to 1.0
function Music:set_volume(volume)
    if not self.key then return end
    _backend.set_music_volume(self.key, volume)
end

--- Sets the music pitch
--- @param pitch number Playback pitch (1.0 is normal)
function Music:set_pitch(pitch)
    if not self.key then return end
    _backend.set_music_pitch(self.key, pitch)
end

--- Unloads the track
function Music:unload()
    release(self, _backend.unload_music)
end

--- @section Music Controls

--- Stops the current music
--- @access mod
function m.stop_music()
    _backend.stop_music()
end

--- Pauses the current music
--- @access mod
function m.pause_music()
    _backend.pause_music()
end

--- Resumes the current music
--- @access mod
function m.resume_music()
    _backend.resume_music()
end

--- Checks if music is playing
--- @access mod
--- @return boolean playing True if music is playing
function m.is_music_playing()
    return _backend.is_music_playing()
end

--- @section Engine Internal

--- Unloads every sound and track. Called by the window on close
function m.cleanup()
    for handle in pairs(live) do handle.key = nil end
    live = {}
    _backend.cleanup()
end

return m