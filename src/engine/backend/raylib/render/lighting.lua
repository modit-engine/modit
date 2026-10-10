--- @module lighting
--- @file src/engine/backend/raylib/render/lighting.lua
--- @description Raylib lit and fogged shader, bound once for a whole 3D pass. Flat normals come from screen-space derivatives.

--- @section Imports

local _raylib = require("src.engine.backend.raylib.ffi")
local _ffi, _lib = _raylib.ffi, _raylib.lib

--- @section Constants

local UNIFORM_VEC2 = 1
local UNIFORM_VEC3 = 2

local VERTEX = [[
#version 330
in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec4 vertexColor;
uniform mat4 mvp;
uniform mat4 matView;
out vec2 fragTexCoord;
out vec4 fragColor;
out vec3 viewPos;
void main() {
    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor;
    viewPos = (matView * vec4(vertexPosition, 1.0)).xyz;
    gl_Position = mvp * vec4(vertexPosition, 1.0);
}
]]

local FRAGMENT = [[
#version 330
in vec2 fragTexCoord;
in vec4 fragColor;
in vec3 viewPos;
uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform vec3 sunDir;
uniform vec3 sunColour;
uniform vec3 ambient;
uniform vec3 fogColour;
uniform vec2 fogRange;
out vec4 finalColor;
void main() {
    vec4 base = texture(texture0, fragTexCoord) * colDiffuse * fragColor;
    vec3 c = cross(dFdx(viewPos), dFdy(viewPos));
    float len = length(c);
    float ndl = len > 1e-10 ? max(dot(c / len, -sunDir), 0.0) : 1.0;
    vec3 lit = base.rgb * min(ambient + sunColour * ndl, vec3(1.5));
    float fog = clamp((-viewPos.z - fogRange.x) / (fogRange.y - fogRange.x), 0.0, 1.0);
    finalColor = vec4(mix(lit, fogColour, fog), base.a);
}
]]

--- @section State

local buf2 = _ffi.new("float[2]")
local buf3 = _ffi.new("float[3]")

local shader = nil
local locs = nil
local failed = false
local active = false

--- @section Helpers

local function set_vec3(loc, x, y, z)
    buf3[0], buf3[1], buf3[2] = x, y, z
    _lib.SetShaderValue(shader, loc, buf3, UNIFORM_VEC3)
end

local function set_vec2(loc, x, y)
    buf2[0], buf2[1] = x, y
    _lib.SetShaderValue(shader, loc, buf2, UNIFORM_VEC2)
end

--- Compiles the shader on first use (needs a live GL context)
--- @return boolean ready True if the shader is usable
local function ensure_loaded()
    if shader then return true end
    if failed then return false end

    local loaded = _lib.LoadShaderFromMemory(VERTEX, FRAGMENT)
    local sun_dir = _lib.GetShaderLocation(loaded, "sunDir")
    if sun_dir < 0 then
        failed = true
        return false
    end

    shader = loaded
    locs = {
        sun_dir = sun_dir,
        sun_colour = _lib.GetShaderLocation(shader, "sunColour"),
        ambient = _lib.GetShaderLocation(shader, "ambient"),
        fog_colour = _lib.GetShaderLocation(shader, "fogColour"),
        fog_range = _lib.GetShaderLocation(shader, "fogRange"),
    }
    return true
end

--- @section Functions

--- Uploads lighting parameters and binds the shader. Call right after begin_3d
--- @param sdx number Sun direction X (view space, direction the light travels)
--- @param sdy number Sun direction Y
--- @param sdz number Sun direction Z
--- @param sr number Sun red (0-1)
--- @param sg number Sun green (0-1)
--- @param sb number Sun blue (0-1)
--- @param ar number Ambient red (0-1)
--- @param ag number Ambient green (0-1)
--- @param ab number Ambient blue (0-1)
--- @param fog_near number Fog start distance
--- @param fog_far number Fog full distance
--- @param fr number Fog red (0-1)
--- @param fg number Fog green (0-1)
--- @param fb number Fog blue (0-1)
--- @return boolean bound True if the shader was bound
local function m_begin(sdx, sdy, sdz, sr, sg, sb, ar, ag, ab, fog_near, fog_far, fr, fg, fb)
    if not ensure_loaded() then return false end

    set_vec3(locs.sun_dir, sdx, sdy, sdz)
    set_vec3(locs.sun_colour, sr, sg, sb)
    set_vec3(locs.ambient, ar, ag, ab)
    set_vec3(locs.fog_colour, fr, fg, fb)
    set_vec2(locs.fog_range, fog_near, fog_far)

    _lib.BeginShaderMode(shader)
    active = true
    return true
end

--- Unbinds the shader. Call right before end_3d
local function finish()
    if not active then return end
    _lib.EndShaderMode()
    active = false
end

--- Releases the shader from VRAM
local function free()
    if not shader then return end
    _lib.UnloadShader(shader)
    shader, locs, active = nil, nil, false
end

return {
    begin = m_begin,
    finish = finish,
    free = free,
}