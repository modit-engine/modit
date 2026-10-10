--- Current-file literal search and undoable replacement. No patterns or regex.
local input = require("src.engine.ui.modules.input")
local ui = require("src.engine.ui.components")
local draw = require("src.engine.modules.draw")
local keys = require("src.engine.modules.input.keyboard")
local state = require("src.editor.ui.panels.code.modules.state")
local buffer = require("src.editor.ui.panels.code.modules.buffer")
local cursor = require("src.editor.ui.panels.code.modules.cursor")
local history = require("src.editor.ui.panels.code.modules.history")

local m = { visible = false, expanded = false, query = {text="", pos=0}, replacement = {text="", pos=0}, matches = {}, index = 0 }
local cached_text, cached_query, cached_case, cached_buffer, cached_whole

function m.refresh(b)
    local text = table.concat(b.lines, "\n")
    if cached_text == text and cached_query == m.query.text and cached_case == m.case and cached_buffer == b and cached_whole == m.whole then return false end
    cached_text, cached_query, cached_case, cached_buffer, cached_whole = text, m.query.text, m.case, b, m.whole
    m.matches, m.index = {}, 0
    local needle = m.case and m.query.text or m.query.text:lower()
    if needle == "" then return true end
    for y, line in ipairs(b.lines) do
        local source, start = m.case and line or line:lower(), 1
        while true do
            local first, last = source:find(needle, start, true)
            if not first then break end
            local before, after = source:sub(first-1,first-1), source:sub(last+1,last+1)
            if not m.whole or (not before:match("[%w_]") and not after:match("[%w_]")) then
                m.matches[#m.matches + 1] = {y=y, first=first, last=last}
            end
            start = last + 1
        end
    end
    return true
end

function m.select(b, index)
    if #m.matches == 0 then m.index = 0; return end
    m.index = (index - 1) % #m.matches + 1
    local hit = m.matches[m.index]
    cursor.move_to(b, hit.y, hit.last, false)
    b.ay, b.ax = hit.y, hit.first - 1
end

local function nearest(b)
    for i, hit in ipairs(m.matches) do
        if hit.y > b.cy or (hit.y == b.cy and hit.first - 1 >= b.cx) then return i end
    end
    return 1
end

function m.replace(b, all)
    m.refresh(b)
    if #m.matches == 0 then return end
    local index = m.index > 0 and m.index or nearest(b)
    local hit = m.matches[index]
    b.last_kind = nil -- Each Replace/Replace All is a separate undo action.
    history.begin_edit(b, "replace")
    for i = all and #m.matches or index, all and 1 or index, -1 do
        local match = m.matches[i]
        local line = b.lines[match.y]
        b.lines[match.y] = line:sub(1, match.first - 1) .. m.replacement.text .. line:sub(match.last + 1)
    end
    b.hl, b.auto_end = {}, nil
    cursor.move_to(b, hit.y, hit.first - 1 + #m.replacement.text, false)
    b.cx = math.min(b.cx, #b.lines[b.cy])
    m.refresh(b)
    if not all then m.select(b, nearest(b)) end
end

function m.close()
    m.visible = false
    input.set_focus(state.focus_token)
end

local function ctrl()
    return (keys.down("leftctrl") or keys.down("rightctrl")) and not (keys.down("leftalt") or keys.down("rightalt"))
end

-- A small single-line field with a caret, clipboard and select-all support.
local function field(f, x, y, w, label, theme)
    if input.in_rect(x,y,w,26) then
        input.set_cursor("text")
        if input.pressed() then input.set_focus(f); f.pos = #f.text end
    end
    if input.has_focus(f) then
        local function insert(text)
            text = text:gsub("[\r\n]", " ")
            if f.selected then f.text, f.pos, f.selected = "", 0, false end
            f.text = f.text:sub(1,f.pos) .. text .. f.text:sub(f.pos+1)
            f.pos = f.pos + #text
        end
        if ctrl() then
            if keys.pressed("a") then f.selected = true end
            if f.selected and (keys.pressed("c") or keys.pressed("x")) then
                keys.set_clipboard(f.text)
                if keys.pressed("x") then insert("") end
            end
            if keys.pressed("v") then insert(keys.get_clipboard() or "") end
        else
            local chars,n = input.typed()
            for i=1,n do if chars[i]>=32 and chars[i]<127 then insert(string.char(chars[i])) end end
            for _,key in ipairs({"backspace","delete","arrowleft","arrowright","home","end"}) do
                if keys.pressed(key) or keys.pressed_repeat(key) then
                    if key=="backspace" or key=="delete" then
                        if f.selected then insert("")
                        elseif key=="backspace" and f.pos>0 then
                            f.text=f.text:sub(1,f.pos-1)..f.text:sub(f.pos+1); f.pos=f.pos-1
                        elseif key=="delete" then f.text=f.text:sub(1,f.pos)..f.text:sub(f.pos+2) end
                    else
                        f.selected=false
                        if key=="home" then f.pos=0 elseif key=="end" then f.pos=#f.text
                        else f.pos=math.max(0,math.min(#f.text,f.pos+(key=="arrowleft" and -1 or 1))) end
                    end
                end
            end
        end
    end
    draw.set_colour(theme.bg_input); draw.rect(x,y,w,26)
    draw.push_clip(x+6,y,w-12,26)
    local offset=math.max(0,input.measure(f.text:sub(1,f.pos),16)-w+18)
    if f.selected and input.has_focus(f) then
        draw.set_colour(theme.bg_hover);draw.rect(x+6-offset,y,input.measure(f.text,16),26)
    end
    ui.label(f.text=="" and label or f.text,x+6-offset,y+5,16,f.text=="" and theme.text_tertiary or theme.text_primary)
    if input.has_focus(f) then
        draw.set_colour(theme.accent);draw.rect(x+6-offset+input.measure(f.text:sub(1,f.pos),16),y+4,1,18)
    end
    draw.pop_clip()
end

function m.draw(b, x, y, w, theme)
    if ui.modal.is_open() then return m.visible and (m.expanded and 70 or 36) or 0 end
    if ctrl() and (keys.pressed("f") or keys.pressed("h")) then
        m.visible = true
        if keys.pressed("h") then m.expanded = true end
        local selected = buffer.selected_text(b)
        if selected and selected~="" and not selected:find("\n",1,true) then m.query.text=selected end
        m.query.pos, m.query.selected = #m.query.text, true
        input.set_focus(m.query)
    end
    if not m.visible then return 0 end
    if keys.pressed("escape") then m.close(); return 0 end
    local height = m.expanded and 70 or 36
    draw.set_colour(theme.bg_panel);draw.rect(x,y,w,height)
    draw.push_clip(x,y,w,height)
    local fw=math.max(60,w-382)
    field(m.query,x+8,y+5,fw,"Find",theme)
    local refreshed=m.refresh(b)
    if refreshed then m.select(b,nearest(b)) end
    local bx=x+fw+14
    local count = #m.matches==0 and "No results" or (m.index>0 and (m.index.." / "..#m.matches) or (#m.matches.." matches"))
    ui.label(count,bx,y+10,14,theme.text_secondary)
    bx=bx+90
    if ui.button("<",bx,y+5,28,26) then m.select(b,m.index-1) end
    if ui.button(">",bx+30,y+5,28,26) then m.select(b,m.index+1) end
    if ui.button("Aa",bx+62,y+5,32,26,16,m.case and theme.accent or theme.text_secondary) then
        m.case=not m.case;m.refresh(b);m.select(b,nearest(b))
    end
    if ui.button("|ab|",bx+98,y+5,40,26,14,m.whole and theme.accent or theme.text_secondary) then
        m.whole=not m.whole;m.refresh(b);m.select(b,nearest(b))
    end
    if ui.button(m.expanded and "Hide" or "Replace",bx+142,y+5,72,26) then
        m.expanded=not m.expanded
        if not m.expanded and input.has_focus(m.replacement) then input.set_focus(m.query) end
    end
    if ui.button("x",bx+220,y+5,26,26) then m.close() end
    if m.expanded then
        field(m.replacement,x+8,y+39,fw,"Replace with",theme)
        if ui.button("Replace",x+fw+14,y+39,90,26) then m.replace(b,false) end
        if ui.button("Replace All",x+fw+110,y+39,120,26) then m.replace(b,true) end
    end
    if input.has_focus(m.query) or input.has_focus(m.replacement) then
        if keys.pressed("enter") then
            if input.has_focus(m.replacement) then m.replace(b,false)
            else m.select(b,m.index+((keys.down("leftshift") or keys.down("rightshift")) and -1 or 1)) end
        end
        if keys.pressed("tab") and m.expanded then input.set_focus(input.has_focus(m.query) and m.replacement or m.query) end
    end
    draw.pop_clip()
    return height
end

function m.highlight(b, x, y, first, last, cell_w, line_h, theme)
    if not m.visible then return end
    m.refresh(b)
    draw.set_colour(theme.accent[1],theme.accent[2],theme.accent[3],45)
    for _,hit in ipairs(m.matches) do
        if hit.y>last then break end
        if hit.y>=first then draw.rect(x+(hit.first-1)*cell_w,y+(hit.y-1)*line_h,(hit.last-hit.first+1)*cell_w,line_h) end
    end
end
return m
