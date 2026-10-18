--- @module default_theme
--- @file src/sdk/ui/default_theme.lua
--- @description Defines default UI theme palette, borders, shadows, console log colors, and syntax highlighting styles.

--- @section Theme

return {
    -- Font
    font = "src/engine/assets/fonts/JetBrainsMono-Regular.ttf",

    -- Backgrounds
    bg_main = {22, 22, 22, 255}, -- #161616 | Main canvas background
    bg_panel = {31, 30, 30, 255}, -- #1f1e1e | Dock panel background
    bg_hover = {50, 48, 48, 255}, -- #323030 | Hover highlight fill
    bg_overlay = {0, 0, 0, 127}, -- #000000 | 50% Dimmed overlay
    bg_input = {17, 17, 17, 255}, -- #111111 | Text input background fill

    -- Text
    text_primary = {255, 255, 255, 255}, -- #ffffff | Headings and primary text
    text_secondary = {180, 180, 180, 255}, -- #b4b4b4 | Subtitles and secondary labels
    text_tertiary = {102, 102, 102, 255}, -- #666666 | Disabled text and hints

    -- Accents
    accent = {77, 203, 194, 255}, -- #4dcbc2 | Active primary accent teal
    accent2 = {49, 145, 138, 255}, -- #31918a | Muted pressed state teal
    accent3 = {181, 50, 50, 255}, -- #b53232 | Crimson red warnings and errors
    accent4 = {102, 102, 102, 255}, -- #666666 | Slate grey inactive accent

    -- Borders
    border_dark = {
        color = {0, 0, 0, 127}, -- #000000 | 50% Semi-transparent dark border
        thickness = 2
    },
    border_light = {
        color = {255, 255, 255, 25}, -- #ffffff | Faint white divider line
        thickness = 2
    },
    border_accent = {
        color = {77, 203, 194, 255}, -- #4dcbc2 | Teal focus outline
        thickness = 2
    },
    border_dashed = {
        color = {102, 102, 102, 255}, -- #666666 | Slate grey guide line
        thickness = 1
    },
    border_transparent = {
        color = {0, 0, 0, 0}, -- #000000 | Clear invisible border
        thickness = 2
    },

    -- Shadows (X-offset, Y-offset, Blur, Color)
    shadow_soft = {0, 1, 2, {0, 0, 0, 127}}, -- #000000 | 50% Soft drop shadow
    shadow_medium = {0, 2, 4, {0, 0, 0, 153}}, -- #000000 | 60% Medium drop shadow
    shadow_large = {0, 4, 8, {0, 0, 0, 191}}, -- #000000 | 75% Deep drop shadow

    -- Text shadow (Offset coordinates + Color)
    text_shadow_hard = {
        {-1, -1, {0, 0, 0, 255}}, -- #000000 | Outline top-left
        {1, -1, {0, 0, 0, 255}}, -- #000000 | Outline top-right
        {-1, 1, {0, 0, 0, 255}}, -- #000000 | Outline bottom-left
        {1, 1, {0, 0, 0, 255}}, -- #000000 | Outline bottom-right
    },

    -- Scrollbars
    scrollbar_track = {255, 255, 255, 64}, -- #ffffff | 25% Transparent white trough
    scrollbar_thumb = {77, 203, 194, 204}, -- #4dcbc2 | 80% Opaque teal draggable handle
    
    -- Console Output Log Colors
    console_logs = {
        print = {150, 150, 150}, -- #969696 | Standard print log message
        debug = {180, 120, 200}, -- #b478c8 | Debug log message text
        info = {110, 200, 220}, -- #6ec8dc | Informational log message text
        success = {110, 200, 120}, -- #6ec878 | Operation success log message
        warn = {228, 173, 41}, -- #e4ad29 | Warning alert log message
        error = {225, 90, 90}, -- #e15a5a | Runtime error log message
        fatal = {255, 60, 60}, -- #ff3c3c | Critical fatal crash log message
    },
    
    -- Syntax Highlighting
    syntax = {
        text = {212, 212, 212, 255}, -- #d4d4d4 | Operators and punctuation
        variable = {156, 220, 254, 255}, -- #9cdcfe | Variables and table fields
        keyword = {86, 156, 214, 255}, -- #569cd6 | Keywords (local, function, and, or, not)
        control = {197, 134, 192, 255}, -- #c586c0 | Control flow (if, then, else, end, for, while, do, return)
        constant = {86, 156, 214, 255}, -- #569cd6 | Boolean and nil constants (true, false, nil)
        self = {86, 156, 214, 255}, -- #569cd6 | Self reference keyword
        func = {220, 220, 170, 255}, -- #dcdcaa | Function identifiers
        member = {78, 201, 176, 255}, -- #4ec9b0 | Module members and field calls
        string = {206, 145, 120, 255}, -- #ce9178 | String literals
        number = {181, 206, 168, 255}, -- #b5cea8 | Numeric literals
        comment = {106, 153, 85, 255}, -- #6a9955 | Code comments
        doctag = {106, 153, 85, 255}, -- #6a9955 | Docstring tags (@param, @return)
        docname = {156, 220, 254, 255}, -- #9cdcfe | Parameter names in doc comments
        doctype = {78, 201, 176, 255}, -- #4ec9b0 | Parameter types in doc comments
        bracket1 = {255, 215, 0, 255}, -- #ffd700 | Primary bracket pair
        bracket2 = {218, 112, 214, 255}, -- #da70d6 | Secondary bracket pair
        bracket3 = {23, 159, 255, 255}, -- #179fff | Tertiary bracket pair
        gutter = {133, 133, 133, 255}, -- #858585 | Inactive line numbers
        gutter_active = {198, 198, 198, 255}, -- #c6c6c6 | Current active line number
    },
}