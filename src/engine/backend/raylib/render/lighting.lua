--- @module lighting
--- @file src/engine/backend/raylib/render/lighting.lua
--- @description Lit and fogged shaders for primitives and meshes, projected and shadow-map shadows, and blob shadow discs.

--- @section Imports

local _raylib = require("src.engine.backend.raylib.ffi")
local _ffi, _lib, _Color = _raylib.ffi, _raylib.lib, _raylib.Color

--- @section Constants

local UNIFORM_VEC2 = 1
local UNIFORM_VEC3 = 2
local UNIFORM_VEC4 = 3

local BLOB_SLICES = 12
local BLOB_HEIGHT = 0.001
local MAP_BRDF_LOC = 25
local FILTER_POINT = 0
local WRAP_CLAMP = 1

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
out vec3 worldPos;
void main() {
    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor;
    worldPos = vertexPosition;
    viewPos = (matView * vec4(vertexPosition, 1.0)).xyz;
    gl_Position = mvp * vec4(vertexPosition, 1.0);
}
]]

local MESH_VERTEX = [[
#version 330
in vec3 vertexPosition;
in vec3 vertexNormal;
in vec2 vertexTexCoord;
in vec4 vertexColor;
uniform mat4 mvp;
uniform mat4 matView;
uniform mat4 matModel;
uniform mat4 matNormal;
uniform mat4 lightVP;
out vec2 fragTexCoord;
out vec4 fragColor;
out vec3 viewPos;
out vec3 worldPos;
out vec3 viewNormal;
out vec4 lightPos;
void main() {
    viewNormal = mat3(matView) * mat3(matNormal) * vertexNormal;
    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor;
    worldPos = (matModel * vec4(vertexPosition, 1.0)).xyz;
    viewPos = (matView * matModel * vec4(vertexPosition, 1.0)).xyz;
    lightPos = lightVP * (matModel * vec4(vertexPosition, 1.0));
    gl_Position = mvp * vec4(vertexPosition, 1.0);
}
]]

local LOCAL_LIGHTS = [[
in vec3 worldPos;
uniform vec4 localPositions[8];
uniform vec4 localColours[8];
uniform vec4 blockerMin[32];
uniform vec4 blockerMax[32];
uniform vec2 localCounts;
// Analytic soft box shadows: conservative building bounds, not voxel silhouettes.
float local_visibility(vec3 surface, vec3 source) {
    vec3 ray = source - surface;
    vec3 safeRay = mix(vec3(0.00001), ray, greaterThan(abs(ray), vec3(0.00001)));
    float visibility = 1.0;
    for (int index = 0; index < int(localCounts.y); index++) {
        vec3 first = (blockerMin[index].xyz - surface) / safeRay;
        vec3 last = (blockerMax[index].xyz - surface) / safeRay;
        vec3 entry = min(first, last), exitPoint = max(first, last);
        float nearPoint = max(max(entry.x, entry.y), entry.z);
        float farPoint = min(min(exitPoint.x, exitPoint.y), exitPoint.z);
        if (farPoint <= 0.002 || nearPoint >= 0.998) continue;
        float softness = 0.075;
        visibility *= smoothstep(-softness, softness, max(nearPoint, 0.002) - min(farPoint, 0.998));
        if (visibility < 0.01) break;
    }
    return visibility;
}
vec3 local_illumination() {
    vec3 normal = cross(dFdx(worldPos), dFdy(worldPos));
    normal = length(normal) > 0.00001 ? normalize(normal) : vec3(0.0, 1.0, 0.0);
    vec3 result = vec3(0.0);
    for (int index = 0; index < int(localCounts.x); index++) {
        vec3 delta = localPositions[index].xyz - worldPos;
        float radius = localPositions[index].w;
        float distanceToLight = length(delta);
        if (distanceToLight >= radius || delta.y < -0.1) continue;
        float falloff = 1.0 - smoothstep(0.0, radius, distanceToLight);
        float diffuse = max(dot(normal, delta / max(distanceToLight, 0.001)), 0.0);
        float visibility = local_visibility(worldPos + normal * 0.035, localPositions[index].xyz);
        result += localColours[index].rgb * localColours[index].a * falloff * diffuse * visibility;
    }
    return result;
}
]]

local MESH_FRAGMENT = "#version 330\n" .. LOCAL_LIGHTS .. [[
in vec2 fragTexCoord;
in vec4 fragColor;
in vec3 viewPos;
in vec3 viewNormal;
in vec4 lightPos;
uniform sampler2D texture0;
uniform sampler2D texture5;
uniform vec4 emission;
uniform vec4 materialParams;
uniform sampler2D shadowMap;
uniform vec4 colDiffuse;
uniform vec3 sunDir;
uniform vec3 sunColour;
uniform vec3 ambient;
uniform vec3 fogColour;
uniform vec2 fogRange;
uniform vec4 shadowParams;
out vec4 finalColor;
float unpack_depth(vec3 c) {
    return dot(c, vec3(1.0, 1.0 / 255.0, 1.0 / 65025.0));
}
void main() {
    vec4 base = texture(texture0, fragTexCoord) * colDiffuse * fragColor;
    if (materialParams.y > 0.5 && materialParams.y < 1.5 && base.a < materialParams.z) discard;
    if (materialParams.y < 1.5) base.a = 1.0;
    vec3 c = cross(dFdx(viewPos), dFdy(viewPos));
    if (materialParams.x > 0.5 && dot(viewNormal, viewNormal) > 1e-10) {
        c = gl_FrontFacing ? viewNormal : -viewNormal;
    }
    float len = length(c);
    float ndl = len > 1e-10 ? max(dot(c / len, -sunDir), 0.0) : 1.0;
    float sun_vis = 1.0;
    if (shadowParams.w > 0.5) {
        vec3 proj = lightPos.xyz / lightPos.w * 0.5 + 0.5;
        if (proj.x > 0.0 && proj.x < 1.0 && proj.y > 0.0 && proj.y < 1.0 && proj.z < 1.0) {
            float bias = (0.05 + 0.3 * (1.0 - ndl)) / shadowParams.y;
            float vis = 0.0;
            for (int x = -1; x <= 1; x++) {
                for (int y = -1; y <= 1; y++) {
                    vec2 uv = proj.xy + vec2(float(x), float(y)) * shadowParams.x;
                    float d = unpack_depth(textureLod(shadowMap, uv, 0.0).rgb);
                    vis += (proj.z - bias <= d) ? 1.0 : 0.0;
                }
            }
            sun_vis = mix(1.0 - shadowParams.z, 1.0, vis / 9.0);
        }
    }
    vec3 lit = base.rgb * min(ambient + sunColour * ndl * sun_vis + local_illumination(), vec3(1.5));
    lit += emission.rgb * (emission.a > 0.5 ? texture(texture5, fragTexCoord).rgb : vec3(1.0));
    float fog = clamp((-viewPos.z - fogRange.x) / (fogRange.y - fogRange.x), 0.0, 1.0);
    finalColor = vec4(mix(lit, fogColour, fog), base.a);
}
]]

local FRAGMENT = "#version 330\n" .. LOCAL_LIGHTS .. [[
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
    vec3 lit = base.rgb * min(ambient + sunColour * ndl + local_illumination(), vec3(1.5));
    float fog = clamp((-viewPos.z - fogRange.x) / (fogRange.y - fogRange.x), 0.0, 1.0);
    finalColor = vec4(mix(lit, fogColour, fog), base.a);
}
]]

local SHADOW_VERTEX = [[
#version 330
in vec3 vertexPosition;
uniform mat4 mvp;
uniform mat4 matView;
uniform vec3 sunWorld;
uniform vec4 shadow;
out vec3 viewPos;
void main() {
    vec3 p = vertexPosition;
    p += sunWorld * ((shadow.x - p.y) / sunWorld.y);
    viewPos = (matView * vec4(p, 1.0)).xyz;
    gl_Position = mvp * vec4(p, 1.0);
}
]]

local SHADOW_MESH_VERTEX = [[
#version 330
in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec4 vertexColor;
out vec2 fragTexCoord;
out float vertexAlpha;
uniform mat4 matProjection;
uniform mat4 matView;
uniform mat4 matModel;
uniform vec3 sunWorld;
uniform vec4 shadow;
out vec3 viewPos;
void main() {
    fragTexCoord = vertexTexCoord;
    vertexAlpha = vertexColor.a;
    vec3 p = (matModel * vec4(vertexPosition, 1.0)).xyz;
    p += sunWorld * ((shadow.x - p.y) / sunWorld.y);
    viewPos = (matView * vec4(p, 1.0)).xyz;
    gl_Position = matProjection * matView * vec4(p, 1.0);
}
]]

local SHADOW_FRAGMENT = [[
#version 330
in vec3 viewPos;
uniform vec4 shadow;
out vec4 finalColor;
void main() {
    float fog = clamp((-viewPos.z - shadow.z) / (shadow.w - shadow.z), 0.0, 1.0);
    finalColor = vec4(0.0, 0.0, 0.0, shadow.y * (1.0 - fog));
}
]]

local WATER_VERTEX = [[
#version 330
in vec3 vertexPosition;
uniform mat4 matProjection;
uniform mat4 matView;
uniform mat4 matModel;
uniform vec4 wave;
out vec3 viewPos;
void main() {
    vec4 p = matModel * vec4(vertexPosition, 1.0);
    p.y += (sin(p.x * wave.y + wave.w * wave.z) + sin(p.z * wave.y * 1.31 - wave.w * wave.z * 0.8)) * 0.5 * wave.x;
    viewPos = (matView * p).xyz;
    gl_Position = matProjection * matView * p;
}
]]

local WATER_FRAGMENT = [[
#version 330
in vec3 viewPos;
uniform vec3 sunDir;
uniform vec3 sunColour;
uniform vec3 ambient;
uniform vec3 fogColour;
uniform vec2 fogRange;
uniform vec4 waterColour;
out vec4 finalColor;
void main() {
    vec3 c = cross(dFdx(viewPos), dFdy(viewPos));
    float len = length(c);
    vec3 n = len > 1e-10 ? c / len : vec3(0.0, 0.0, 1.0);
    vec3 v = normalize(-viewPos);
    float ndl = max(dot(n, -sunDir), 0.0);
    float fresnel = pow(1.0 - max(dot(n, v), 0.0), 3.0);
    vec3 col = waterColour.rgb * (ambient + sunColour * ndl);
    col = mix(col, fogColour, fresnel * 0.5);
    vec3 h = normalize(v - sunDir);
    col += sunColour * pow(max(dot(n, h), 0.0), 48.0) * 0.6;
    float fog = clamp((-viewPos.z - fogRange.x) / (fogRange.y - fogRange.x), 0.0, 1.0);
    finalColor = vec4(mix(col, fogColour, fog), clamp(waterColour.a + fresnel * 0.3, 0.0, 1.0));
}
]]

local DEPTH_VERTEX = [[
#version 330
in vec3 vertexPosition;
uniform mat4 lightVP;
void main() {
    gl_Position = lightVP * vec4(vertexPosition, 1.0);
}
]]

local DEPTH_MESH_VERTEX = [[
#version 330
in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec4 vertexColor;
out vec2 fragTexCoord;
out float vertexAlpha;
uniform mat4 matModel;
uniform mat4 lightVP;
void main() {
    fragTexCoord = vertexTexCoord;
    vertexAlpha = vertexColor.a;
    gl_Position = lightVP * (matModel * vec4(vertexPosition, 1.0));
}
]]

local DEPTH_FRAGMENT = [[
#version 330
out vec4 finalColor;
vec3 pack_depth(float d) {
    vec3 enc = fract(d * vec3(1.0, 255.0, 65025.0));
    enc -= enc.yzz * vec3(1.0 / 255.0, 1.0 / 255.0, 0.0);
    return enc;
}
void main() {
    finalColor = vec4(pack_depth(clamp(gl_FragCoord.z, 0.0, 0.99999)), 1.0);
}
]]

local MESH_ALPHA = [[
in vec2 fragTexCoord;
in float vertexAlpha;
uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform vec4 materialParams;
]]

local function mesh_shadow_fragment(source)
    source = source:gsub("#version 330", "#version 330\n" .. MESH_ALPHA)
    return (source:gsub("void main%(%) {", [[void main() {
    float alpha = texture(texture0, fragTexCoord).a * colDiffuse.a * vertexAlpha;
    if (materialParams.y > 0.5 && alpha < materialParams.z) discard;]]))
end

local LIT_UNIFORMS = {
    sun_dir = "sunDir",
    sun_colour = "sunColour",
    ambient = "ambient",
    fog_colour = "fogColour",
    fog_range = "fogRange",
}

local MESH_UNIFORMS = {
    sun_dir = "sunDir",
    sun_colour = "sunColour",
    ambient = "ambient",
    fog_colour = "fogColour",
    fog_range = "fogRange",
    light_vp = "lightVP",
    shadow_params = "shadowParams",
    material = "materialParams",
    emission = "emission",
}

local DEPTH_UNIFORMS = {
    material = "materialParams",
    light_vp = "lightVP",
}

local WATER_UNIFORMS = {
    sun_dir = "sunDir",
    sun_colour = "sunColour",
    ambient = "ambient",
    fog_colour = "fogColour",
    fog_range = "fogRange",
    wave = "wave",
    water_colour = "waterColour",
}

local SHADOW_UNIFORMS = {
    material = "materialParams",
    sun_world = "sunWorld",
    shadow = "shadow",
}

--- @section State

local buf2 = _ffi.new("float[2]")
local buf3 = _ffi.new("float[3]")
local buf4 = _ffi.new("float[4]")

local Vector3 = _ffi.typeof("Vector3")
local blob_pos = Vector3()
local blob_colour = _Color(0, 0, 0, 255)

local _Camera3D = _ffi.typeof("Camera3D")
local map_camera = _Camera3D()
map_camera.up.y = 1
map_camera.position.z = 1
map_camera.fovy = 45
local map_clear = _Color(255, 255, 255, 255)
local matrix = _ffi.new("Matrix")
local matrix_floats = _ffi.cast("float*", matrix)

local map_target = nil
local map_size = 0

local local_sources, local_blockers = {}, {}
local active = false
local in_shadow = false
local in_map = false
local receiving = false
local warned_unlit = false

local lit = { vertex = VERTEX, fragment = FRAGMENT, uniforms = LIT_UNIFORMS, probe = "sun_dir" }
local lit_mesh = { vertex = MESH_VERTEX, fragment = MESH_FRAGMENT, uniforms = MESH_UNIFORMS, probe = "sun_dir", map_uniform = "shadowMap" }
-- Raylib supplies one model matrix per instance; mvp remains the view/projection matrix.
local instanced_vertex = MESH_VERTEX:gsub("uniform mat4 matModel;", "in mat4 instanceTransform;")
    :gsub("mat3%(matNormal%)", "transpose(inverse(mat3(instanceTransform)))")
    :gsub("matModel", "instanceTransform")
    :gsub("gl_Position = mvp %* vec4%(vertexPosition, 1.0%);", "gl_Position = mvp * instanceTransform * vec4(vertexPosition, 1.0);")
local lit_instanced = { vertex = instanced_vertex, fragment = FRAGMENT, uniforms = MESH_UNIFORMS,
    probe = "sun_dir", map_uniform = "shadowMap" }
local shadow = { vertex = SHADOW_VERTEX, fragment = SHADOW_FRAGMENT, uniforms = SHADOW_UNIFORMS, probe = "sun_world" }
local shadow_mesh = { vertex = SHADOW_MESH_VERTEX, fragment = mesh_shadow_fragment(SHADOW_FRAGMENT), uniforms = SHADOW_UNIFORMS, probe = "sun_world" }

local depth = { vertex = DEPTH_VERTEX, fragment = DEPTH_FRAGMENT, uniforms = DEPTH_UNIFORMS, probe = "light_vp" }
local depth_mesh = { vertex = DEPTH_MESH_VERTEX, fragment = mesh_shadow_fragment(DEPTH_FRAGMENT), uniforms = DEPTH_UNIFORMS, probe = "light_vp" }

local water = { vertex = WATER_VERTEX, fragment = WATER_FRAGMENT, uniforms = WATER_UNIFORMS, probe = "sun_dir" }

local PROGRAMS = { lit, lit_mesh, lit_instanced, shadow, shadow_mesh, depth, depth_mesh, water }

--- @section Helpers

local function set_vec3(program, loc, x, y, z)
    buf3[0], buf3[1], buf3[2] = x, y, z
    _lib.SetShaderValue(program.shader, loc, buf3, UNIFORM_VEC3)
end

local function set_vec2(program, loc, x, y)
    buf2[0], buf2[1] = x, y
    _lib.SetShaderValue(program.shader, loc, buf2, UNIFORM_VEC2)
end

local function set_vec4(program, loc, x, y, z, w)
    buf4[0], buf4[1], buf4[2], buf4[3] = x, y, z, w
    _lib.SetShaderValue(program.shader, loc, buf4, UNIFORM_VEC4)
end

--- Compiles a program on first use
--- @param program table Program entry
--- @return boolean ready True if the program is usable
local function ensure(program)
    if program.shader then return true end
    if program.failed then return false end

    local loaded = _lib.LoadShaderFromMemory(program.vertex, program.fragment)
    if _lib.GetShaderLocation(loaded, program.uniforms[program.probe]) < 0 then
        _lib.UnloadShader(loaded)
        program.failed = true
        return false
    end

    program.shader = loaded
    program.locs = {}
    for key, name in pairs(program.uniforms) do
        program.locs[key] = _lib.GetShaderLocation(loaded, name)
    end
    if program == lit or program == lit_mesh or program == lit_instanced then
        program.local_positions, program.local_colours = {}, {}
        program.blocker_min, program.blocker_max = {}, {}
        program.local_counts = _lib.GetShaderLocation(loaded, "localCounts")
        for index = 1, 8 do
            program.local_positions[index] = _lib.GetShaderLocation(loaded, "localPositions[" .. (index - 1) .. "]")
            program.local_colours[index] = _lib.GetShaderLocation(loaded, "localColours[" .. (index - 1) .. "]")
        end
        for index = 1, 32 do
            program.blocker_min[index] = _lib.GetShaderLocation(loaded, "blockerMin[" .. (index - 1) .. "]")
            program.blocker_max[index] = _lib.GetShaderLocation(loaded, "blockerMax[" .. (index - 1) .. "]")
        end
    end
    if program == lit_mesh or program == lit_instanced then
        loaded.locs[20] = _lib.GetShaderLocation(loaded, "texture5") -- SHADER_LOC_MAP_EMISSION
        loaded.locs[1] = _lib.GetShaderLocation(loaded, "colDiffuse") -- SHADER_LOC_COLOR_DIFFUSE (CRITICAL)
    end
    if program == lit_instanced then 
        local attrib_loc = _lib.GetShaderLocationAttrib(loaded, "instanceTransform")
        loaded.locs[9] = attrib_loc
    end
    if program.map_uniform then
        loaded.locs[MAP_BRDF_LOC] = _lib.GetShaderLocation(loaded, program.map_uniform)
    end
    return true
end

--- Uploads a 4x4 matrix given as 16 numbers in row-major order (row * 4 + column)
local function upload_matrix(program, loc, rows)
    for index = 0, 15 do matrix_floats[index] = rows[index + 1] end
    _lib.SetShaderValueMatrix(program.shader, loc, matrix)
end

local function upload_lit(program, sdx, sdy, sdz, sr, sg, sb, ar, ag, ab, fog_near, fog_far, fr, fg, fb)
    local locs = program.locs
    set_vec3(program, locs.sun_dir, sdx, sdy, sdz)
    set_vec3(program, locs.sun_colour, sr, sg, sb)
    set_vec3(program, locs.ambient, ar, ag, ab)
    set_vec3(program, locs.fog_colour, fr, fg, fb)
    set_vec2(program, locs.fog_range, fog_near, fog_far)
end

local function upload_shadow(program, sx, sy, sz, plane_y, strength, fog_near, fog_far)
    set_vec3(program, program.locs.sun_world, sx, sy, sz)
    set_vec4(program, program.locs.shadow, plane_y, strength, fog_near, fog_far)
end

--- @section Functions

--- Uploads world-space local lights and soft box shadow casters for the current frame.
local function upload_local_lights()
    local lights, blockers = local_sources, local_blockers
    for _, program in ipairs({ lit, lit_mesh, lit_instanced }) do
        if ensure(program) then
            set_vec2(program, program.local_counts, math.min(#lights, 8), math.min(#blockers, 32))
            for index = 1, math.min(#lights, 8) do
                local light = lights[index]
                set_vec4(program, program.local_positions[index], light.x, light.y, light.z, light.radius)
                set_vec4(program, program.local_colours[index], light.r / 255, light.g / 255, light.b / 255, light.strength)
            end
            for index = 1, math.min(#blockers, 32) do
                local box = blockers[index]
                set_vec4(program, program.blocker_min[index], box.min_x, box.min_y, box.min_z, 0)
                set_vec4(program, program.blocker_max[index], box.max_x, box.max_y, box.max_z, 0)
            end
        end
    end
end

--- Uploads lighting parameters and binds the lit shader. Call right after begin_3d
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
local function begin(sdx, sdy, sdz, sr, sg, sb, ar, ag, ab, fog_near, fog_far, fr, fg, fb)
    if not ensure(lit) then return false end

    upload_lit(lit, sdx, sdy, sdz, sr, sg, sb, ar, ag, ab, fog_near, fog_far, fr, fg, fb)
    if ensure(lit_mesh) then
        upload_lit(lit_mesh, sdx, sdy, sdz, sr, sg, sb, ar, ag, ab, fog_near, fog_far, fr, fg, fb)
    end
    if ensure(lit_instanced) then
        upload_lit(lit_instanced, sdx, sdy, sdz, sr, sg, sb, ar, ag, ab, fog_near, fog_far, fr, fg, fb)
    end
    if ensure(water) then
        upload_lit(water, sdx, sdy, sdz, sr, sg, sb, ar, ag, ab, fog_near, fog_far, fr, fg, fb)
    end

    upload_local_lights()
    _lib.BeginShaderMode(lit.shader)
    active = true
    return true
end

--- Unbinds the shader. Call right before end_3d
local function finish()
    if not active then return end
    _lib.EndShaderMode()
    active = false
    receiving = false
end

--- Switches to the projected-shadow shader. Must be inside begin/finish.
--- Swapping shaders flushes the pending batch, so earlier geometry keeps its own uniforms.
--- @param sx number Sun direction X (world space, direction the light travels)
--- @param sy number Sun direction Y (must be negative)
--- @param sz number Sun direction Z
--- @param plane_y number World Y of the plane the shadows land on
--- @param strength number Shadow opacity (0-1)
--- @param fog_near number Fog start distance
--- @param fog_far number Fog full distance
--- @return boolean started True if the shadow shader is now bound
local function shadow_begin(sx, sy, sz, plane_y, strength, fog_near, fog_far)
    if not active or not ensure(shadow) then return false end

    upload_shadow(shadow, sx, sy, sz, plane_y, strength, fog_near, fog_far)
    if ensure(shadow_mesh) then
        upload_shadow(shadow_mesh, sx, sy, sz, plane_y, strength, fog_near, fog_far)
    end

    _lib.EndShaderMode()
    _lib.BeginShaderMode(shadow.shader)
    in_shadow = true
    return true
end

--- Returns from the projected-shadow shader to the lit shader
local function shadow_end()
    in_shadow = false
    _lib.EndShaderMode()
    _lib.BeginShaderMode(lit.shader)
end

--- Gets the shader meshes must use right now
--- @return cdata|false|nil shader Mesh shader, nil for raylibs default, or false to skip drawing (shadow pass without a mesh shadow shader)
local function mesh_shader()
    if in_map then return depth_mesh.shader or false end
    if in_shadow then return shadow_mesh.shader or false end
    if active and lit_mesh.shader then return lit_mesh.shader end
    return nil
end

--- Starts the shadow-map depth pass. Must be called outside any 3D pass, texture mode or shader mode.
--- @param size number Shadow map width and height in pixels
--- @param light_vp table 16 numbers, row-major: light projection * light view
--- @return boolean started True if the depth pass is now bound
local function map_begin(size, light_vp)
    if active or in_shadow or in_map then return false end
    if not (ensure(depth) and ensure(depth_mesh)) then return false end

    if not map_target or map_size ~= size then
        if map_target then _lib.UnloadRenderTexture(map_target) end
        map_target = _lib.LoadRenderTexture(size, size)
        _lib.SetTextureFilter(map_target.texture, FILTER_POINT)
        _lib.SetTextureWrap(map_target.texture, WRAP_CLAMP)
        map_size = size
    end

    upload_matrix(depth, depth.locs.light_vp, light_vp)
    upload_matrix(depth_mesh, depth_mesh.locs.light_vp, light_vp)

    _lib.BeginTextureMode(map_target)
    _lib.ClearBackground(map_clear)
    _lib.BeginMode3D(map_camera)
    _lib.BeginShaderMode(depth.shader)
    in_map = true
    return true
end

--- Ends the shadow-map depth pass
local function map_end()
    in_map = false
    _lib.EndShaderMode()
    _lib.EndMode3D()
    _lib.EndTextureMode()
end

--- Hands the finished shadow map to meshes for this 3D pass. Call after begin, or with nil to disable
--- @param light_vp table|nil 16 numbers, row-major: light projection * light view
--- @param texel number Size of one shadow-map texel in UV units
--- @param depth_range number Depth covered by the light, in world units
--- @param strength number Shadow opacity (0-1)
local function map_receive(light_vp, texel, depth_range, strength)
    if not ensure(lit_mesh) then return end

    local enabled = light_vp ~= nil and map_target ~= nil
    if enabled then
        upload_matrix(lit_mesh, lit_mesh.locs.light_vp, light_vp)
    end
    set_vec4(lit_mesh, lit_mesh.locs.shadow_params, texel or 0, depth_range or 1, strength or 0, enabled and 1 or 0)
    receiving = enabled
end

--- Gets the shadow map texture meshes must bind right now
--- @return cdata|nil texture Shadow map texture, or nil when meshes receive no map shadows
local function shadow_texture()
    if receiving and map_target then return map_target.texture end
    return nil
end

--- Uploads per-mesh material values for the current lighting or shadow pass
--- @param smooth boolean Use the mesh normals rather than faceted derivatives
--- @param mode number 0 = opaque, 1 = mask, 2 = blend
--- @param cutoff number Alpha cutoff (0-1)
--- @param colour cdata Emission colour
--- @param strength number Emission multiplier
--- @param textured boolean True if an emission texture is bound
local function set_model_material(smooth, mode, cutoff, colour, strength, textured, instanced)
    local program = in_map and depth_mesh or (in_shadow and shadow_mesh or (active and lit_mesh))
    if instanced then program = lit_instanced end
    if not program or not program.shader then return end
    set_vec4(program, program.locs.material, smooth and 1 or 0, mode, cutoff, 0)
    if program == lit_mesh or program == lit_instanced then
        set_vec4(program, program.locs.emission,
            colour.r / 255 * strength, colour.g / 255 * strength, colour.b / 255 * strength, textured and 1 or 0)
    end
end

--- True while models are being rendered as shadow casters
local function is_shadow_pass()
    return in_shadow or in_map
end

--- Gets the water shader, only inside a normal lit 3D pass
--- @return cdata|nil shader Water shader, or nil when water cant draw right now
local function water_shader()
    if not active or in_shadow or in_map then return nil end
    if not ensure(water) then return nil end
    return water.shader
end

--- Uploads the water surface settings. Call right before drawing the water mesh
--- @param time number Animation time in seconds
--- @param amplitude number Wave height
--- @param frequency number Wave frequency
--- @param speed number Wave speed
--- @param r number Water red (0-1)
--- @param g number Water green (0-1)
--- @param b number Water blue (0-1)
--- @param opacity number Base opacity (0-1)
local function set_water(time, amplitude, frequency, speed, r, g, b, opacity)
    set_vec4(water, water.locs.wave, amplitude, frequency, speed, time)
    set_vec4(water, water.locs.water_colour, r, g, b, opacity)
end

--- Draws one soft layer of a blob shadow: a flat black disc
--- @param x number Centre X
--- @param y number Ground Y
--- @param z number Centre Z
--- @param radius number Disc radius
--- @param alpha number Disc opacity (0-1)
local function blob_disc(x, y, z, radius, alpha)
    blob_pos.x, blob_pos.y, blob_pos.z = x, y, z
    blob_colour.a = math.floor(math.max(0, math.min(1, alpha)) * 255)
    _lib.DrawCylinder(blob_pos, radius, radius, BLOB_HEIGHT, BLOB_SLICES, blob_colour)
end

--- Releases every shader from VRAM
local function free()
    for _, program in ipairs(PROGRAMS) do
        if program.shader then _lib.UnloadShader(program.shader) end
        program.shader, program.locs, program.failed = nil, nil, nil
    end
    if map_target then
        _lib.UnloadRenderTexture(map_target)
        map_target, map_size = nil, 0
    end
    active, in_shadow, in_map, receiving = false, false, false, false
    local_sources, local_blockers = {}, {}
end

return {
    begin = begin,
    finish = finish,
    shadow_begin = shadow_begin,
    shadow_end = shadow_end,
    mesh_shader = mesh_shader,
    instance_shader = function()
        if not (ensure(lit_instanced) and lit_instanced.shader) then
            return lit_mesh.shader
        end
        if not active then
            if not warned_unlit then
                warned_unlit = true
                print("[lighting] instanced draw outside a lit 3D pass: using neutral lighting and no fog")
            end
            upload_lit(lit_instanced, 0.3, -0.8, -0.5, 0.8, 0.8, 0.8, 0.45, 0.45, 0.45, 1e5, 1e6, 0.5, 0.5, 0.5)
        end
        return lit_instanced.shader
    end,
    set_local_lights = function(lights, blockers)
        local_sources, local_blockers = lights, blockers
    end,
    set_model_material = set_model_material,
    is_shadow_pass = is_shadow_pass,
    water_shader = water_shader,
    set_water = set_water,
    map_begin = map_begin,
    map_end = map_end,
    map_receive = map_receive,
    shadow_texture = shadow_texture,
    blob_disc = blob_disc,
    free = free,
}
