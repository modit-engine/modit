--- Windows JPEG decoder for raylib builds without JPEG support.
--- GDI+ LockBits: https://learn.microsoft.com/en-us/windows/win32/api/gdiplusheaders/nf-gdiplusheaders-bitmap-lockbits
local ffi = require("ffi")
local ray = require("src.engine.backend.raylib.ffi").lib
ffi.cdef[[
typedef struct { unsigned int version; void *callback; int no_thread; int no_codecs; } EditorGdiStartup;
typedef struct { int x,y,width,height; } EditorGdiRect;
typedef struct { unsigned int width,height; int stride,format; void *pixels; uintptr_t reserved; } EditorGdiPixels;
int __stdcall GdiplusStartup(uintptr_t *, const EditorGdiStartup *, void *);
void __stdcall GdiplusShutdown(uintptr_t);
int __stdcall GdipCreateBitmapFromFile(const wchar_t *, void **);
int __stdcall GdipGetImageWidth(void *, unsigned int *);
int __stdcall GdipGetImageHeight(void *, unsigned int *);
int __stdcall GdipBitmapLockBits(void *, const EditorGdiRect *, unsigned int, int, EditorGdiPixels *);
int __stdcall GdipBitmapUnlockBits(void *, EditorGdiPixels *);
int __stdcall GdipDisposeImage(void *);
int MultiByteToWideChar(unsigned int, unsigned int, const char *, int, wchar_t *, int);
]]
local gdi = ffi.load("gdiplus")
local m = {}

function m.load(path)
    local empty = ffi.new("Image")
    local n = ffi.C.MultiByteToWideChar(65001,0,path,-1,nil,0)
    if n == 0 then return empty end
    local wide = ffi.new("wchar_t[?]",n)
    ffi.C.MultiByteToWideChar(65001,0,path,-1,wide,n)
    local token = ffi.new("uintptr_t[1]")
    if gdi.GdiplusStartup(token,ffi.new("EditorGdiStartup",{1,nil,0,0}),nil) ~= 0 then return empty end
    local bitmap = ffi.new("void *[1]")
    local result = empty
    if gdi.GdipCreateBitmapFromFile(wide,bitmap) == 0 then
        local w,h = ffi.new("unsigned int[1]"),ffi.new("unsigned int[1]")
        gdi.GdipGetImageWidth(bitmap[0],w);gdi.GdipGetImageHeight(bitmap[0],h)
        local width,height = tonumber(w[0]),tonumber(h[0])
        local pixels = ffi.new("EditorGdiPixels")
        local rect = ffi.new("EditorGdiRect",{0,0,width,height})
        if width>0 and height>0 and gdi.GdipBitmapLockBits(bitmap[0],rect,1,0x26200A,pixels)==0 then
            result = ray.GenImageColor(width,height,{0,0,0,0})
            if result.data ~= nil then
                local dest = ffi.cast("uint8_t *",result.data)
                local source = ffi.cast("uint8_t *",pixels.pixels)
                for y=0,height-1 do
                    for x=0,width-1 do
                        local src, dst = y*pixels.stride+x*4, (y*width+x)*4
                        dest[dst],dest[dst+1],dest[dst+2],dest[dst+3] = source[src+2],source[src+1],source[src],source[src+3]
                    end
                end
            end
            gdi.GdipBitmapUnlockBits(bitmap[0],pixels)
        end
        gdi.GdipDisposeImage(bitmap[0])
    end
    gdi.GdiplusShutdown(token[0])
    return result
end
return m
