--- @module tokyo_night
--- @file src/engine/ui/themes/tokyo_night.lua
--- @description Defines Tokyo Night engine UI theme palette, borders, shadows, console log colors, and syntax highlighting styles.

--- @section Theme

return {
    -- Font
    font = "src/engine/assets/fonts/JetBrainsMono-Regular.ttf",

    -- Backgrounds
    bg_main = {26, 27, 38, 255}, -- #1a1b26 | Main canvas background
    bg_panel = {36, 40, 59, 255}, -- #24283b | Dock panel background
    bg_hover = {41, 46, 66, 255}, -- #292e42 | Hover highlight fill
    bg_overlay = {0, 0, 0, 127}, -- #000000 | 50% Dimmed overlay
    bg_input = {22, 22, 30, 255}, -- #16161e | Text input background fill

    -- Text
    text_primary = {192, 202, 245, 255}, -- #c0caf5 | Headings and primary text
    text_secondary = {169, 177, 214, 255}, -- #a9b1d6 | Subtitles and secondary labels
    text_tertiary = {86, 95, 137, 255}, -- #565f89 | Disabled text and hints

    -- Accents
    accent = {122, 162, 247, 255}, -- #7aa2f7 | Active primary soft blue
    accent2 = {187, 154, 247, 255}, -- #bb9af7 | Pastel purple pressed state
    accent3 = {247, 118, 142, 255}, -- #f7768e | Coral red warnings and errors
    accent4 = {86, 95, 137, 255}, -- #565f89 | Dark slate inactive accent

    -- Borders
    border_dark = {
        color = {0, 0, 0, 127}, -- #000000 | 50% Semi-transparent dark border
        thickness = 2
    },
    border_light = {
        color = {255, 255, 255, 20}, -- #ffffff | Faint white divider line
        thickness = 2
    },
    border_accent = {
        color = {122, 162, 247, 255}, -- #7aa2f7 | Soft blue focus outline
        thickness = 2
    },
    border_dashed = {
        color = {86, 95, 137, 255}, -- #565f89 | Muted slate guide line
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
    scrollbar_track = {255, 255, 255, 30}, -- #ffffff | Transparent white trough
    scrollbar_thumb = {122, 162, 247, 204}, -- #7aa2f7 | 80% Opaque soft blue handle

    -- Console Output Log Colors
    console_logs = {
        print = {169, 177, 214}, -- #a9b1d6 | Standard print log message
        debug = {187, 154, 247}, -- #bb9af7 | Debug log message text
        info = {125, 207, 255}, -- #7dcfff | Informational log message text
        success = {158, 206, 106}, -- #9ece6a | Operation success log message
        warn = {224, 175, 104}, -- #e0af68 | Warning alert log message
        error = {247, 118, 142}, -- #f7768e | Runtime error log message
        fatal = {255, 117, 127}, -- #ff757f | Critical fatal crash log message
    },
    
    -- Syntax Highlighting
    syntax = {
        text = {169, 177, 214, 255}, -- #a9b1d6 | Operators and punctuation
        variable = {192, 202, 245, 255}, -- #c0caf5 | Variables and table fields
        keyword = {187, 154, 247, 255}, -- #bb9af7 | Keywords (local, function, and, or, not)
        control = {187, 154, 247, 255}, -- #bb9af7 | Control flow (if, then, else, end, for, while, do, return)
        constant = {255, 158, 100, 255}, -- #ff9e64 | Boolean and nil constants (true, false, nil)
        self = {247, 118, 142, 255}, -- #f7768e | Self reference keyword
        func = {122, 162, 247, 255}, -- #7aa2f7 | Function identifiers
        member = {42, 195, 222, 255}, -- #2ac3de | Module members and field calls
        string = {158, 206, 106, 255}, -- #9ece6a | String literals
        number = {255, 158, 100, 255}, -- #ff9e64 | Numeric literals
        comment = {86, 95, 137, 255}, -- #565f89 | Code comments
        doctag = {86, 95, 137, 255}, -- #565f89 | Docstring tags (@param, @return)
        docname = {224, 175, 104, 255}, -- #e0af68 | Parameter names in doc comments
        doctype = {42, 195, 222, 255}, -- #2ac3de | Parameter types in doc comments
        bracket1 = {224, 175, 104, 255}, -- #e0af68 | Primary bracket pair
        bracket2 = {187, 154, 247, 255}, -- #bb9af7 | Secondary bracket pair
        bracket3 = {122, 162, 247, 255}, -- #7aa2f7 | Tertiary bracket pair
        gutter = {86, 95, 137, 255}, -- #565f89 | Inactive line numbers
        gutter_active = {169, 177, 214, 255}, -- #a9b1d6 | Current active line number
    },
}