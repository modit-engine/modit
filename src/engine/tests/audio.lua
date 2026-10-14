--- @file src/engine/tests/audio.lua
--- @description Audio test: sound and music handles, volume, pitch, music controls, unload safety. Needs modules.audio = true.

return function(modit)

    --- @section Config (point these at real files)

    local SOUND_PATH = "src/engine/assets/audio/test_sound.ogg"
    local MUSIC_PATH = "src/engine/assets/audio/test_music.ogg"

    --- @section State

    local sound, music = nil, nil
    local volume, pitch = 1.0, 1.0
    local music_volume = 1.0
    local paused = false
    local status = "press a key"

    local function set_status(text)
        status = text
        modit.log.info("[test] audio: " .. text)
    end

    local function clamp(value, low, high)
        return math.max(low, math.min(high, value))
    end

    --- @section Draw Test

    local function draw_test()
        local draw = modit.draw
        local key = modit.keyboard

        -- sound
        if key.pressed("1") then
            sound = modit.audio.load_sound(SOUND_PATH)
            set_status(sound and "sound loaded" or "sound failed to load (check SOUND_PATH)")
        end

        if key.pressed("2") then
            if sound then sound:play() set_status("sound played") else set_status("load the sound first (1)") end
        end

        if key.pressed("arrowup") and sound then
            volume = clamp(volume + 0.1, 0, 1)
            sound:set_volume(volume)
            set_status(("sound volume %.1f"):format(volume))
        end

        if key.pressed("arrowdown") and sound then
            volume = clamp(volume - 0.1, 0, 1)
            sound:set_volume(volume)
            set_status(("sound volume %.1f"):format(volume))
        end

        if key.pressed("arrowright") and sound then
            pitch = clamp(pitch + 0.1, 0.5, 2)
            sound:set_pitch(pitch)
            set_status(("sound pitch %.1f"):format(pitch))
        end

        if key.pressed("arrowleft") and sound then
            pitch = clamp(pitch - 0.1, 0.5, 2)
            sound:set_pitch(pitch)
            set_status(("sound pitch %.1f"):format(pitch))
        end

        if key.pressed("u") and sound then
            sound:unload()
            set_status("sound unloaded (press 2: must do nothing and not crash)")
        end

        -- music
        if key.pressed("3") then
            music = modit.audio.load_music(MUSIC_PATH)
            set_status(music and "music loaded" or "music failed to load (check MUSIC_PATH)")
        end

        if key.pressed("4") then
            if music then music:play(true) paused = false set_status("music playing (loop)") else set_status("load the music first (3)") end
        end

        if key.pressed("5") then
            modit.audio.stop_music()
            paused = false
            set_status("music stopped")
        end

        if key.pressed("space") then
            if paused then modit.audio.resume_music() else modit.audio.pause_music() end
            paused = not paused
            set_status(paused and "music paused" or "music resumed")
        end

        if key.pressed("w") and music then
            music_volume = clamp(music_volume + 0.1, 0, 1)
            music:set_volume(music_volume)
            set_status(("music volume %.1f"):format(music_volume))
        end

        if key.pressed("s") and music then
            music_volume = clamp(music_volume - 0.1, 0, 1)
            music:set_volume(music_volume)
            set_status(("music volume %.1f"):format(music_volume))
        end

        if key.pressed("d") and music then
            music:set_pitch(1.25)
            set_status("music pitch 1.25")
        end

        if key.pressed("a") and music then
            music:set_pitch(1.0)
            set_status("music pitch 1.0")
        end

        if key.pressed("m") and music then
            music:unload()
            set_status("music unloaded (press 4: must do nothing and not crash)")
        end

        if key.pressed("c") then
            modit.audio.cleanup()
            set_status("cleanup called (both handles are now dead)")
        end

        -- screen
        draw.clear(22, 22, 22, 255)
        draw.set_colour(255, 255, 255, 255)
        draw.text("audio test", 20, 20, 24)

        draw.set_colour(255, 220, 80, 255)
        draw.text(status, 20, 60, 18)

        draw.set_colour(160, 160, 180, 255)
        draw.text("sound: " .. (sound and sound.key and "loaded" or "not loaded"), 20, 100, 16)
        draw.text("music: " .. (music and music.key and "loaded" or "not loaded"), 20, 122, 16)
        draw.text("is_music_playing: " .. tostring(modit.audio.is_music_playing()), 20, 144, 16)
        draw.text(("sound volume %.1f  pitch %.1f  |  music volume %.1f"):format(volume, pitch, music_volume), 20, 166, 16)

        local lines = {
            "[1] load sound   [2] play sound   [U] unload sound",
            "[UP/DOWN] sound volume   [LEFT/RIGHT] sound pitch",
            "[3] load music   [4] play music (loop)   [5] stop music   [SPACE] pause / resume",
            "[W/S] music volume   [A/D] music pitch 1.0 / 1.25   [M] unload music",
            "[C] cleanup (kills every handle)",
        }
        draw.set_colour(130, 130, 150, 255)
        for i, line in ipairs(lines) do
            draw.text(line, 20, 210 + (i - 1) * 22, 16)
        end
    end

    return draw_test
end