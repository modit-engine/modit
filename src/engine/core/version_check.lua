--- @module version_check
--- @file src/engine/core/version_check.lua
--- @description GitHub release version checking.

--- @section Imports

local _http = require("src.engine.modules.http")
local _log = require("src.engine.core.log")
local _json = require("src.engine.core.json")

--- @section Module

local m = {}

--- @section Configuration

local RELEASES_URL = "https://api.github.com/repos/CaseIRL/modit/releases/latest"

--- @section Functions

--- Checks the latest GitHub release against the current engine version.
--- @param current_version string Current local engine version
--- @return table|nil release Latest release information, or nil on failure
function m.check(current_version)
    local body, status, err = _http.get(RELEASES_URL, {
        ["Accept"] = "application/vnd.github+json",
        ["User-Agent"] = "Modit"
    })

    if not body or status ~= 200 then
        _log.error("Failed to check for updates", {
            status = status,
            error = err
        })
        return nil
    end

    local ok, release = pcall(_json.decode, body)
    if not ok or type(release) ~= "table" or not release.tag_name then
        _log.error("Failed to parse GitHub release response", {
            error = ok and "missing tag_name" or release
        })
        return nil
    end

    local remote_version = tostring(release.tag_name):gsub("^v", "")
    local local_version = tostring(current_version or "0.0.0")

    local result = {
        current = local_version,
        latest = remote_version,
        update_available = remote_version ~= local_version,
        url = release.html_url,
        changelog = release.body
    }

    if result.update_available then
        _log.warn("Modit update available", {
            current = local_version,
            latest = remote_version
        })
    else
        _log.success("Modit is up to date", {
            version = local_version
        })
    end

    return result
end

return m