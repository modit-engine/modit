--- @module test_plugin
local plugin = {}

function plugin.load()
    modit.log.info("[test_plugin] Initialized.")
    modit.ui.push_toast("Test Plugin loaded", "success")
end

function plugin.unload()
    modit.log.info("[test_plugin] Unloading.")
    modit.ui.push_toast("Test Plugin unloaded", "info")
end

return plugin