--- @file src/engine/core/version_check.lua
--- @description GitHub release version checking, including pre-releases.

--- @section Imports

local _backend = require("src.engine.backend")
local _log = require("src.engine.core.log")
local _json = require("src.engine.core.json")

--- @section Constants

local RELEASES_URL = "https://api.github.com/repos/modit-engine/modit/releases?per_page=10"

--- @section Initialisation

local m = {}

--- @section Helpers

local function parse(version)
    local text = (tostring(version):gsub("^v", ""))
    local core, pre = text:match("^([%d%.]+)%-?(.*)$")

    local numbers = {}
    for part in (core or "0"):gmatch("%d+") do
        numbers[#numbers + 1] = tonumber(part)
    end

    return numbers, pre or ""
end

local function compare(a, b)
    local a_nums, a_pre = parse(a)
    local b_nums, b_pre = parse(b)

    for i = 1, math.max(#a_nums, #b_nums) do
        local x, y = a_nums[i] or 0, b_nums[i] or 0
        if x ~= y then return x > y and 1 or -1 end
    end

    if a_pre == b_pre then return 0 end
    if a_pre == "" then return 1 end
    if b_pre == "" then return -1 end
    return a_pre > b_pre and 1 or -1
end

-- Export compare so external modules can use it
m.compare = compare

local function newest(releases)
    local best
    for _, release in ipairs(releases) do
        if not release.draft and release.tag_name then
            if not best or compare(release.tag_name, best.tag_name) > 0 then
                best = release
            end
        end
    end
    return best
end

--- @section Functions

function m.check(current_version)
    local body, status, err = _backend.http.request(RELEASES_URL, {
        ["Accept"] = "application/vnd.github+json",
        ["User-Agent"] = "Modit"
    })

    if not body or status ~= 200 then
        _log.error("Failed to check for updates", { status = status, error = err })
        return nil
    end

    local ok, releases = pcall(_json.decode, body)
    if not ok or type(releases) ~= "table" then
        _log.error("Failed to parse GitHub release response", { error = ok and "not a list" or releases })
        return nil
    end

    local release = newest(releases)
    if not release then
        _log.warn("No published releases found")
        return nil
    end

    local local_version = (tostring(current_version or "0.0.0"):gsub("^v", ""))
    local remote_version = (tostring(release.tag_name):gsub("^v", ""))

    local result = {
        current = local_version,
        latest = remote_version,
        update_available = compare(remote_version, local_version) > 0,
        prerelease = release.prerelease and true or false,
        url = release.html_url,
        changelog = release.body
    }

    if result.update_available then
        _log.warn("Modit update available", { current = local_version, latest = remote_version, url = result.url })
    else
        _log.success("Modit is up to date", { version = local_version })
    end

    return result
end

return m