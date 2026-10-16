--- @module config
--- @file src/editor/ui/panels/code/config.lua
--- @description Configuration constants and layout dimensions for the code editor panel.

--- @section Configuration

return {
    FONT_PATH = "src/engine/assets/fonts/JetBrainsMono-Regular.ttf",
    FONT_SIZE = 20,
    LINE_GAP = 4,
    TAB_H = 30,
    STATUS_H = 24,
    GUTTER_PAD = 12,
    TEXT_PAD = 8,
    INDENT = 4,
    MAX_BYTES = 2 * 1024 * 1024,
    UNDO_MAX = 200,
    EDGE = 4,
}