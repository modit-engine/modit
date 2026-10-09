--- @file mods/default_world/mod.lua
--- @description Mod manifest for default_world.

return {

    -- Identity
    name = "default_world",
    version = "0.1.0",
    description = "Default game world for Modit",
    author = "Case",
    license = "Apache 2.0",

    -- Modit API version target
    api_version = 1,

    -- Dependencies (mods that must load before this one)
    depends = {},

    -- Scripts loaded sequentially per realm
    shared = {
        "shared/world.lua",
        "shared/movement.lua",
    },

    client = {
        "client/main.lua",
    },

    server = {
        "server/main.lua",
    },

    -- Non-script assets to stream/load (models, textures, audio)
    assets = {},
}