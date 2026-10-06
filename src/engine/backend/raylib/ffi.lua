--- @module ffi
--- @file src/engine/backend/raylib/ffi.lua
--- @description C FFI declarations and dynamic library binding wrapper for Raylib engine backend.

--- @section Imports

local _ffi = require("ffi")

--- @section Data Structure Types

_ffi.cdef[[
    typedef struct { unsigned char r, g, b, a; } Color;
    typedef struct { float x; float y; } Vector2;
    typedef struct { float x, y, width, height; } Rectangle;

    typedef struct {
        void *data;
        int width;
        int height;
        int mipmaps;
        int format;
    } Image;

    typedef struct { unsigned int id; int width; int height; int mipmaps; int format; } Texture;
    typedef Texture Texture2D;
    typedef struct { unsigned int id; Texture texture; Texture depth; } RenderTexture;
    typedef RenderTexture RenderTexture2D;

    typedef struct { int value; int offsetX; int offsetY; int advanceX; Image image; } GlyphInfo;
    typedef struct {
        int baseSize;
        int glyphCount;
        int glyphPadding;
        Texture2D texture;
        Rectangle *recs;
        GlyphInfo *glyphs;
    } Font;
]]

--- @section Window Management

_ffi.cdef[[
    typedef enum {
        FLAG_VSYNC_HINT = 0x00000040,
        FLAG_FULLSCREEN_MODE = 0x00000002,
        FLAG_WINDOW_RESIZABLE = 0x00000004,
        FLAG_WINDOW_UNDECORATED = 0x00000008,
        FLAG_WINDOW_HIDDEN = 0x00000080,
        FLAG_WINDOW_MINIMIZED = 0x00000200,
        FLAG_WINDOW_MAXIMIZED = 0x00000400,
        FLAG_WINDOW_UNFOCUSED = 0x00000800,
        FLAG_WINDOW_TOPMOST = 0x00001000,
        FLAG_WINDOW_ALWAYS_RUN = 0x00000100,
        FLAG_WINDOW_TRANSPARENT = 0x00000010,
        FLAG_WINDOW_HIGHDPI = 0x00002000,
        FLAG_WINDOW_MOUSE_PASSTHROUGH = 0x00004000,
        FLAG_BORDERLESS_WINDOWED_MODE = 0x00008000,
        FLAG_MSAA_4X_HINT = 0x00000020,
        FLAG_INTERLACED_HINT = 0x00010000
    } ConfigFlags;

    void SetConfigFlags(unsigned int flags);
    void SetWindowState(unsigned int flags);
    void ClearWindowState(unsigned int flags);

    void InitWindow(int width, int height, const char *title);
    void CloseWindow(void);
    int WindowShouldClose(void);
    void ToggleFullscreen(void);
    void MinimizeWindow(void);
    int GetWindowPositionX(void);
    int GetWindowPositionY(void);
    int GetScreenWidth(void);
    int GetScreenHeight(void);
    void SetWindowPosition(int x, int y);
    void SetWindowIcon(Image image);
]]

--- @section Timing & Framerate

_ffi.cdef[[
    void SetTargetFPS(int fps);
    float GetFrameTime(void);
    int GetFPS(void);
    void DrawFPS(int posX, int posY);
]]

--- @section Rendering Pipeline

_ffi.cdef[[
    void BeginDrawing(void);
    void EndDrawing(void);
    void ClearBackground(Color color);
]]

--- @section Shape Primitives

_ffi.cdef[[
    void DrawLine(int startPosX, int startPosY, int endPosX, int endPosY, Color color);
    void DrawRectangle(int posX, int posY, int width, int height, Color color);
    void DrawRectangleRec(Rectangle rec, Color color);
    void DrawRectangleLines(int posX, int posY, int width, int height, Color color);
    void DrawRectangleLinesEx(Rectangle rec, float lineThick, Color color);
    void DrawRectangleRounded(Rectangle rec, float roundness, int segments, Color color);
    void DrawRectangleRoundedLinesEx(Rectangle rec, float roundness, int segments, float lineThick, Color color);
    void DrawCircle(int centerX, int centerY, float radius, Color color);
    void DrawCircleLines(int centerX, int centerY, float radius, Color color);
    void DrawTriangle(Vector2 v1, Vector2 v2, Vector2 v3, Color color);
    void DrawTriangleLines(Vector2 v1, Vector2 v2, Vector2 v3, Color color);
    void DrawEllipse(int centerX, int centerY, float radiusH, float radiusV, Color color);
    void DrawPoly(Vector2 center, int sides, float radius, float rotation, Color color);
]]

--- @section Basic Text Rendering

_ffi.cdef[[
    void DrawText(const char *text, int posX, int posY, int fontSize, Color color);
    int MeasureText(const char *text, int fontSize);
]]

--- @section Custom Font Operations

_ffi.cdef[[
    Font LoadFontEx(const char *fileName, int fontSize, int *codepoints, int codepointCount);
    void UnloadFont(Font font);
    void DrawTextEx(Font font, const char *text, Vector2 position, float fontSize, float spacing, Color tint);
    Vector2 MeasureTextEx(Font font, const char *text, float fontSize, float spacing);
]]

--- @section Scissor Clipping

_ffi.cdef[[
    void BeginScissorMode(int x, int y, int width, int height);
    void EndScissorMode(void);
]]

--- @section Render Texture Canvas

_ffi.cdef[[
    RenderTexture2D LoadRenderTexture(int width, int height);
    void UnloadRenderTexture(RenderTexture2D target);
    void BeginTextureMode(RenderTexture2D target);
    void EndTextureMode(void);
    void SetTextureFilter(Texture2D texture, int filter);
    void DrawTexturePro(Texture2D texture, Rectangle source, Rectangle dest, Vector2 origin, float rotation, Color tint);
]]

--- @section Mouse Input

_ffi.cdef[[
    int GetMouseX(void);
    int GetMouseY(void);
    Vector2 GetMouseDelta(void);
    void SetMousePosition(int x, int y);
    bool IsMouseButtonPressed(int button);
    bool IsMouseButtonDown(int button);
    bool IsMouseButtonReleased(int button);
    float GetMouseWheelMove(void);
    void SetMouseCursor(int cursor);
    void ShowCursor(void);
    void HideCursor(void);
    void EnableCursor(void);
    void DisableCursor(void);
]]

--- @section Keyboard Input

_ffi.cdef[[
    bool IsKeyDown(int key);
    bool IsKeyPressed(int key);
    bool IsKeyReleased(int key);
    bool IsKeyPressedRepeat(int key);
    int GetCharPressed(void);
]]

--- @section System Clipboard

_ffi.cdef[[
    const char *GetClipboardText(void);
    void SetClipboardText(const char *text);
]]

--- @section Image Management

_ffi.cdef[[
    Image LoadImage(const char *fileName);
    void UnloadImage(Image image);
]]

--- @section Audio Subsystem

_ffi.cdef[[
    void InitAudioDevice(void);
    void CloseAudioDevice(void);
]]

--- @section 3D & Camera

_ffi.cdef[[
    typedef struct { float x, y, z; } Vector3;
    typedef struct { Vector3 position; Vector3 target; Vector3 up; float fovy; int projection; } Camera3D;
    typedef struct { Vector2 offset; Vector2 target; float rotation; float zoom; } Camera2D;

    void BeginMode3D(Camera3D camera);
    void EndMode3D(void);
    void BeginMode2D(Camera2D camera);
    void EndMode2D(void);

    void DrawLine3D(Vector3 startPos, Vector3 endPos, Color color);
    void DrawCube(Vector3 position, float width, float height, float length, Color color);
    void DrawCubeWires(Vector3 position, float width, float height, float length, Color color);
    void DrawPlane(Vector3 centerPos, Vector2 size, Color color);
    void DrawSphere(Vector3 centerPos, float radius, Color color);
    void DrawSphereWires(Vector3 centerPos, float radius, int rings, int slices, Color color);
    void DrawGrid(int slices, float spacing);
]]

--- @section Library Binding Loading

local ok, raylib_lib = pcall(_ffi.load, "vendor/raylib/lib/raylib")
if not ok then
    raylib_lib = _ffi.load("raylib")
end

return {
    ffi = _ffi,
    lib = raylib_lib,
    Color = _ffi.typeof("Color"),
}