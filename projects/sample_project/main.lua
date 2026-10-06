local game = {}

local font = require("src.engine.modules.font")

local FONT_PATH = "src/assets/fonts/JetBrainsMono-Regular.ttf"
local FONT_SIZE = 32

local game_font

local function get_font()
    if game_font == nil then
        game_font = font.load(FONT_PATH, FONT_SIZE)
        if not game_font then
            game_font = false
        end
    end

    return game_font
end

function game.load()
    game_font = get_font()

    engine.log.info("sample_project loaded")
end

function game.update(dt)
end

function game.draw()
    engine.draw.set_colour(255, 255, 255)

    local f = get_font()

    if f then
        font.draw(f, "sample_project", 40, 40)
    else
        engine.draw.text("sample_project", 40, 40, FONT_SIZE)
    end
end

return game
