--- Categorised editor preferences, sharing the editor modal layer.
local ui = require("src.engine.ui.components")
local draw = require("src.engine.modules.render.draw")
local theme = require("src.engine.ui.modules.theme")
local settings = require("src.editor.core.settings")
local themes = require("src.editor.ui.style.themes")
local images = require("src.editor.ui.panels.image")
local SIDEBAR_WIDTH = 112
local category = "General"
local scroll = { y = 0 }
local m = {}

local function save()
    settings.set_theme(theme.name())
    settings.save()
end
local function toggle(key,label,description,x,y,w,t)
    ui.label(label,x,y+4,16,t.text_primary)
    if ui.button(settings[key] and "On" or "Off",x+w-50,y,50,24,16,
        settings[key] and t.accent or t.text_secondary) then
        settings[key] = not settings[key]
        if key=="show_file_previews" and not settings[key] then images.clear_thumbnails() end
        save()
    end
    ui.label(description,x,y+27,14,t.text_secondary)
end
local function render(r,t)
    local sidebar = SIDEBAR_WIDTH
    draw.set_colour(t.bg_input);draw.rect(r.x,r.y,sidebar,r.h)
    for i,name in ipairs({"General","View"}) do
        if ui.button(name,r.x+6,r.y+6+(i-1)*28,sidebar-12,26,16,
            category==name and t.accent or t.text_secondary) then category=name;scroll.y=0 end
    end
    local content_h = category=="General" and (#themes.keys*30+52) or 136
    ui.scroll_begin(scroll,r.x+sidebar,r.y,r.w-sidebar,r.h,content_h)
    local x,y,w = r.x+sidebar+14,r.y+12-scroll.y,r.w-sidebar-40
    if category=="View" then
        toggle("show_file_previews","Show file previews","Small image thumbnails in the Files panel.",x,y,w,t)
        toggle("minimap","Show minimap","Show the overview beside your code.",x,y+58,w,t)
    else
        ui.label("Editor theme",x,y,16,t.text_primary)
        for i,key in ipairs(themes.keys) do
            if ui.button(themes.labels[i],x,y+26+(i-1)*30,math.min(w,220),26,16,
                theme.name()==key and t.accent or t.text_secondary) then
                theme.set(key);save()
            end
        end
    end
    ui.scroll_end()
end
function m.open()
    ui.modal.open({title="Editor Settings",width=560,height=560,sidebar_width=SIDEBAR_WIDTH,render=render})
end
return m
