--- @module state
--- @file src/editor/ui/panels/code/modules/state.lua
--- @description Shared editor state container and font management without circular module dependencies.

--- @section Imports

--- Engine
local _font = require("src.sdk.client.font")

--- Editor
local _config = require("src.editor.ui.panels.code.modules.config")

--- @section Initialisation

local m = {
    font = nil,
    line_h = nil,
    font_err = nil,
    buffers = {},
    active = nil,
    focus_token = {},
    notice = nil,
    notice_until = nil,
    blink_from = 0,
    selecting = false,
    tab_clicked = false,
}

--- @section Functions

--- Displays a transient status notification message for a default duration
--- @param text string Notification text to display
function m.notify(text)
    m.notice, m.notice_until = text, os.clock() + 4
end

--- Resets the cursor caret blink animation cycle start time
function m.blink()
    m.blink_from = os.clock()
end

--- Ensures the editor font asset is loaded and computes line spacing metrics
--- @return boolean ok True if font loading succeeded or was previously loaded
function m.ensure_font()
    if m.font then 
        return true 
    end
    m.font, m.font_err = _font.load(_config.FONT_PATH, _config.FONT_SIZE)
    if not m.font then 
        return false 
    end
    m.line_h = _config.FONT_SIZE + _config.LINE_GAP
    return true
end

return m