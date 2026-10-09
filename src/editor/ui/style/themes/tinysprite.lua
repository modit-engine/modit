--- @module tinysprite
--- @description TinySprite's red identity, with neutral surfaces and readable code colours.
--- Missing fields inherit the default theme. Colours are { red, green, blue, alpha }.

return {
    name = "TinySprite",

    -- Brand palette: #FF1A1A, #A60000, #0A0A0A, #1C1C1C, #FFFFFF.
    bg_main = {10, 10, 10, 255},
    bg_panel = {28, 28, 28, 255},
    bg_input = {16, 16, 16, 255},
    bg_hover = {54, 30, 32, 255},
    bg_overlay = {0, 0, 0, 180},

    text_primary = {255, 255, 255, 255},
    text_secondary = {199, 191, 191, 255},
    text_tertiary = {151, 141, 141, 255},

    accent = {255, 26, 26, 255},
    accent2 = {166, 0, 0, 255},
    accent3 = {255, 112, 112, 255},
    accent4 = {151, 141, 141, 255},

    border_dark = { color = {0, 0, 0, 180}, thickness = 1 },
    border_light = { color = {255, 255, 255, 24}, thickness = 1 },
    border_accent = { color = {255, 26, 26, 255}, thickness = 1 },
    border_dashed = { color = {112, 94, 94, 255}, thickness = 1 },
    scrollbar_track = {255, 255, 255, 24},
    scrollbar_thumb = {255, 26, 26, 210},

    -- Keep severity colours distinct from the red UI accent.
    console_logs = {
        print = {199, 191, 191},
        debug = {192, 160, 224},
        info = {112, 205, 225},
        success = {158, 205, 143},
        warn = {242, 194, 112},
        error = {255, 112, 112},
        fatal = {255, 70, 70},
    },

    -- Softer reds in code keep longer sessions comfortable to read.
    syntax = {
        text = {225, 216, 216, 255},
        variable = {238, 231, 231, 255},
        keyword = {255, 132, 132, 255},
        control = {255, 132, 132, 255},
        constant = {219, 171, 232, 255},
        self = {255, 171, 157, 255},
        func = {240, 205, 151, 255},
        member = {132, 205, 212, 255},
        string = {178, 207, 153, 255},
        number = {237, 173, 126, 255},
        comment = {148, 142, 142, 255},
        doctag = {204, 163, 163, 255},
        docname = {240, 205, 151, 255},
        doctype = {132, 205, 212, 255},
        bracket1 = {240, 205, 151, 255},
        bracket2 = {219, 171, 232, 255},
        bracket3 = {132, 205, 212, 255},
        gutter = {135, 123, 123, 255},
        gutter_active = {255, 175, 175, 255},
    },
}
