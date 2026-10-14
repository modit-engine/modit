--- @module model
--- @file src/engine/sdk/client/model.lua

--- Public model API. Implementation is split by responsibility.

local core = require("src.engine.sdk.client.model.core")

require("src.engine.sdk.client.model.lifecycle")
require("src.engine.sdk.client.model.rendering")
require("src.engine.sdk.client.model.animation")
require("src.engine.sdk.client.model.materials")
require("src.engine.sdk.client.model.picking")
require("src.engine.sdk.client.model.asset_descriptions")

return core.m
