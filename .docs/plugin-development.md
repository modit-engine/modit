# Plugin Development

Plugins let you extend the Modit editor with your own tools and custom logic.
They have full access to the global `modit` API, just like games and mods.

---

## 1. The Config File (`plugin.modit`)

To make a config file, just create a plain text file, put the settings inside using `key=value` format, and name it `plugin.modit`:

```ini
engine=modit
name=test_plugin
label=Test Plugin
version=1.0.0
author=Modit
entry=init.lua

```

---

## 2. The Script (`init.lua`)

Your script needs `load` and `unload` functions. Since the global `modit` namespace is available right away, you can use logs, toasts, and UI functions directly:

```lua
--- @module test_plugin
--- @file plugins/test_plugin/init.lua
--- @description Sample editor test plugin demonstrating lifecycle loading, logging, and toast notifications.

local plugin = {}

--- Called when the plugin is loaded by the editor.
function plugin.load()
    modit.log.info("[test_plugin] Initialized.")
    modit.ui.push_toast("Test Plugin loaded", "success")
end

--- Called when the plugin is unloaded or reloaded.
function plugin.unload()
    modit.log.info("[test_plugin] Unloading.")
    modit.ui.push_toast("Test Plugin unloaded", "info")
end

return plugin

```

---

## 3. Managing Plugins in the Editor

* **Adding:** Click **Add Plugin...** in the editor's Plugins panel to choose an external folder. It copies it into your local workspace automatically.
* **Toggling:** Use the toggle switch in the panel to turn a plugin on or off.
* **Removing:** Clicking **Remove** physically deletes the plugin folder from disk.