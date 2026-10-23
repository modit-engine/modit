--- @module version
--- @file src/version.lua
--- @description Centralized version module with automatic GitHub update checking.

--- @section Imports

local version_check = require("src.engine.core.internal.version_check")

--- @section Constants

local LOCAL_VERSION = "0.14.0-alpha"
local SDK_VERSION = "0.1.0"

local REMOTE_INFO = version_check.check(LOCAL_VERSION)
local LATEST_RELEASE = REMOTE_INFO and REMOTE_INFO.latest or LOCAL_VERSION
local HAS_UPDATE = REMOTE_INFO and REMOTE_INFO.update_available or false
local DISPLAY_STRING = "Version: " .. LOCAL_VERSION

--- @section Module

if REMOTE_INFO then
    local cmp = version_check.compare(LOCAL_VERSION, LATEST_RELEASE)
    if cmp > 0 then
        DISPLAY_STRING = DISPLAY_STRING .. " | Local (Ahead of " .. LATEST_RELEASE .. ")"
    elseif HAS_UPDATE then
        DISPLAY_STRING = DISPLAY_STRING .. " | Latest: " .. LATEST_RELEASE
    end
end

return {
    engine = LOCAL_VERSION,
    sdk = SDK_VERSION,
    latest = LATEST_RELEASE,
    update_available = HAS_UPDATE,
    display = DISPLAY_STRING,
}