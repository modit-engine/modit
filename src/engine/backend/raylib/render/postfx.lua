--- @module post
--- @file src/engine/backend/raylib/render/post.lua
--- @description Raylib post-processing: renders the scene into a canvas and draws it fullscreen through custom or default shaders.

--- @section Imports

local _raylib = require("src.engine.backend.raylib.ffi")
local _ffi, _lib, _Color = _raylib.ffi, _raylib.lib, _raylib.Color
local _canvas = require("src.engine.backend.raylib.render.canvas")

--- @section Constants

local UNIFORM_VEC2 = 1
local UNIFORM_VEC4 = 3

local DEFAULT_VERTEX = [[
#version 330
in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec4 vertexColor;
uniform mat4 mvp;
out vec2 fragTexCoord;
out vec4 fragColor;
void main() {
    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor;
    gl_Position = mvp * vec4(vertexPosition, 1.0);
}
]]

local DEFAULT_FRAGMENT = [[
#version 330
in vec2 fragTexCoord;
in vec4 fragColor;
uniform sampler2D texture0;
uniform vec2 resolution;
uniform vec4 grade;
uniform vec2 quant;
out vec4 finalColor;
const float BAYER[16] = float[16](
    0.0, 8.0, 2.0, 10.0,
    12.0, 4.0, 14.0, 6.0,
    3.0, 11.0, 1.0, 9.0,
    15.0, 7.0, 13.0, 5.0);
float bayer(vec2 pixel) {
    int x = int(mod(pixel.x, 4.0));
    int y = int(mod(pixel.y, 4.0));
    return (BAYER[y * 4 + x] + 0.5) / 16.0;
}
void main() {
    vec3 col = texture(texture0, fragTexCoord).rgb;

    float luma = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(vec3(luma), col, grade.x);
    col = (col - 0.5) * grade.y + 0.5 + grade.z;

    vec2 uv = fragTexCoord * 2.0 - 1.0;
    col *= 1.0 - grade.w * smoothstep(0.4, 1.4, length(uv));

    if (quant.x > 1.0) {
        float steps = quant.x - 1.0;
        float noise = (bayer(floor(fragTexCoord * resolution)) - 0.5) * quant.y / steps;
        col = floor((col + noise) * steps + 0.5) / steps;
    }

    finalColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
]]

--- @section State

local buf2 = _ffi.new("float[2]")
local buf4 = _ffi.new("float[4]")
local clear_colour = _Color(0, 0, 0, 255)

local target = nil
local target_width, target_height = 0, 0

local shader = nil
local locs = nil
local current_vs = nil
local current_fs = nil

--- @section Helpers

--- Compiles or updates the post shader if sources change
--- @param vertex_code string|nil Vertex shader source code
--- @param fragment_code string|nil Fragment shader source code
--- @return boolean success True if shader is ready
local function ensure_shader(vertex_code, fragment_code)
    vertex_code = vertex_code or DEFAULT_VERTEX
    fragment_code = fragment_code or DEFAULT_FRAGMENT

    -- If shader is already compiled with these exact sources, keep it
    if shader and current_vs == vertex_code and current_fs == fragment_code then
        return true
    end

    -- Unload old shader if it exists
    if shader then
        _lib.UnloadShader(shader)
        shader = nil
        locs = nil
    end

    local loaded = _lib.LoadShaderFromMemory(vertex_code, fragment_code)
    if loaded.id == 0 then
        return false
    end

    shader = loaded
    current_vs = vertex_code
    current_fs = fragment_code

    -- Cache uniform locations safely (handles custom shaders gracefully)
    locs = {
        grade = _lib.GetShaderLocation(shader, "grade"),
        quant = _lib.GetShaderLocation(shader, "quant"),
        resolution = _lib.GetShaderLocation(shader, "resolution"),
    }

    return true
end

--- @section Initialisation

local m = {}

--- @section Functions

--- Starts drawing the scene into the low-resolution canvas
--- @param width number Scene width in pixels
--- @param height number Scene height in pixels
--- @param r number Clear red (0-255)
--- @param g number Clear green (0-255)
--- @param b number Clear blue (0-255)
--- @param vertex_code string|nil Optional custom vertex shader code
--- @param fragment_code string|nil Optional custom fragment shader code
--- @return boolean started False if post-processing can't run, draw normally instead
function m.begin_scene(width, height, r, g, b, vertex_code, fragment_code)
    if not ensure_shader(vertex_code, fragment_code) then return false end

    if not target or target_width ~= width or target_height ~= height then
        if target then _canvas.free(target) end
        target = _canvas.new(width, height, true)
        target_width, target_height = width, height
    end

    _canvas.begin_target(target)
    clear_colour.r, clear_colour.g, clear_colour.b = r, g, b
    _lib.ClearBackground(clear_colour)
    return true
end

--- Finishes the scene and draws it fullscreen through the active shader
--- @param width number Window width in pixels
--- @param height number Window height in pixels
--- @param saturation number Colour saturation (1 = unchanged)
--- @param contrast number Contrast (1 = unchanged)
--- @param brightness number Brightness offset (0 = unchanged)
--- @param vignette number Corner darkening (0 = none)
--- @param levels number Colour levels per channel (0 = off, 32 = PS1)
--- @param dither number Dither strength when quantising (0-1)
function m.end_scene(width, height, saturation, contrast, brightness, vignette, levels, dither)
    _canvas.end_target()

    -- Only update uniforms if the active shader actually exposes them
    if locs.grade >= 0 then
        buf4[0], buf4[1], buf4[2], buf4[3] = saturation, contrast, brightness, vignette
        _lib.SetShaderValue(shader, locs.grade, buf4, UNIFORM_VEC4)
    end

    if locs.quant >= 0 then
        buf2[0], buf2[1] = levels, dither
        _lib.SetShaderValue(shader, locs.quant, buf2, UNIFORM_VEC2)
    end

    if locs.resolution >= 0 then
        buf2[0], buf2[1] = target_width, target_height
        _lib.SetShaderValue(shader, locs.resolution, buf2, UNIFORM_VEC2)
    end

    _lib.BeginShaderMode(shader)
    _canvas.draw(target, 0, 0, width, height)
    _lib.EndShaderMode()
end

--- Releases the canvas and shader from VRAM
function m.free()
    if target then
        _canvas.free(target)
        target, target_width, target_height = nil, 0, 0
    end
    if shader then
        _lib.UnloadShader(shader)
        shader, locs, current_vs, current_fs = nil, nil, nil, nil
    end
end

return m