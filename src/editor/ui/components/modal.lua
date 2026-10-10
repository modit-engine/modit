--- Editor modal adapter: existing confirmation dialogs plus custom settings content.
local base = require("src.engine.ui.components.modal")
local ui = require("src.engine.ui.components")
local input = require("src.engine.ui.modules.input")
local draw = require("src.engine.modules.draw")
local theme = require("src.engine.ui.modules.theme")
local keyboard = require("src.engine.modules.input.keyboard")
local current
local m = {}

function m.open(options)
    input.blur()
    if options.render then
        base.close()
        current = options
    else
        current = nil
        base.open(options)
    end
end
function m.close()
    current = nil
    base.close()
    input.blur()
end
function m.is_open() return current ~= nil or base.is_open() end
function m.draw(w,h)
    if not current then return base.draw(w,h) end
    local t, dialog = theme.get(), current
    local width,height = math.min(dialog.width or 560,w-24),math.min(dialog.height or 216,h-24)
    local x,y = math.floor((w-width)/2),math.floor((h-height)/2)
    draw.set_colour(t.bg_overlay);draw.rect(0,0,w,h)
    draw.set_colour(t.bg_panel);draw.rect(x,y,width,height)
    ui.label(dialog.title,x+12,y+10,16,t.text_primary)
    draw.set_colour(t.border_light.color);draw.line(x,y+35,x+width,y+35)
    draw.push_clip(x,y+36,width,height-72)
    dialog.render({x=x,y=y+36,w=width,h=height-72},t)
    draw.pop_clip()
    local sidebar = dialog.sidebar_width or 0
    if sidebar > 0 then
        draw.set_colour(t.bg_input)
        draw.rect(x+1,y+height-36,sidebar-1,35)
    end
    ui.label("Changes are saved automatically",x+sidebar+14,y+height-24,14,t.text_tertiary)
    if ui.button("Close",x+width-76,y+height-30,64,24) or keyboard.pressed("escape") then m.close() end
    -- Keep the outline above sidebar and content backgrounds.
    draw.set_colour(t.border_light.color);draw.rect_lines(x,y,width,height,1)
end
return m
