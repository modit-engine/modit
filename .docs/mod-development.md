# Mod Development Guide

Modit is built from the ground up as a "mod-first" game engine. Any game with modding enabled allows you to create custom modifications by following this guide.

---

## 1. Structure & Core Rules

Mods require very minimal configuration to get started:

* **`manifest.lua`**: Every mod must include a `manifest.lua` file in its root directory.
* **Requirements**: Defining `sdk_version` and including at least one script file are mandatory; everything else is optional based on what your mod needs.
* **Sandbox Security**: All mod files pass through the engine's safe sandbox, which strips out common "dangerous" functionalities.
* **Relative Imports**: The `require` function within mods is strictly relative to the mod's own folders. A mod cannot access or require engine or game files directly.
* **Global Access**: The `modit` API is served globally to mods. You can use any function marked with `[mod]` in the API Cheatsheet.
* **Game Restrictions**: Game developers have full control to restrict certain APIs (for example, environment lighting) to preserve a specific game's atmosphere or design intentions.

---

## 2. The `manifest.lua` File

The manifest defines your mod's metadata, dependencies, provided APIs, assets, and entry-point scripts.

```lua
--- @file manifest.lua
--- @description Manifest defining a mod's metadata, dependencies, provided APIs, assets, and scripts.

--- Modit SDK API version this mod targets.
sdk_version "1.0"

--- Descriptive metadata for this mod.
--- The engine assigns the mod's internal ID automatically.
metadata {
    name = "test_mod",
    version = "0.1.0",
    description = "Just a dev test mod.",
    author = "Case",
    license = "MIT"
}

--- Mods or services this mod requires to function.
--- Dependencies must be available before this mod loads.
depends {}

--- API namespaces this mod provides.
--- Allows this mod to act as an alternative provider for an existing API.
provides {}

--- Non-script assets used by this mod, such as models, textures, and audio.
assets {}

--- Client-side scripts, executed on each connected client.
client {
    "client/main.lua"
}

--- Shared scripts, loaded in both client and server realms.
shared {}

--- Server-side scripts, executed by the server.
server {}

```

---

## 3. Directory Structure

A standard mod folder structure should look like this:

```text
my_mod/
├── manifest.lua
└── client/
    └── main.lua

```

---

## 4. Writing Your First Script (`client/main.lua`)

Inside your mod scripts, you can interact globally via the `modit` API. Mods are designed to listen to game hook, but they can also register custom handling or communicate using exports.

```lua
--- @module client_main
--- @file client/main.lua

-- Example: Using global modit APIs marked with [mod]
modit.log.info("My custom mod has loaded successfully!")

-- Interacting with game hook or setting up periodic logic
modit.runtime.every(2.0, function()
    modit.log.debug("Mod periodic tick running...")
end)

```

---

## 5. Inter-Mod Communication & Hooks

### Hooks

Hooks serve as powerful extension points. Games and modders alike can declare, listen to, and fire hook to build extensible mod architectures:

* `modit.hook.register(name, description)` - Declares a brand-new hook name with an optional description, allowing mods to define custom extension points for other mods.
* `modit.hook.listen(name, callback, owner)` - Adds a listener to a hook with an optional owner tag.
* `modit.hook.fire(name, ...)` - Calls every listener of a hook in order.
* `modit.hook.unlisten(name, callback)` - Removes a specific listener function.
* `modit.hook.list()` - Lists all declared hook names.

### Exports

Similar to FiveM ecosystem patterns, you can expose custom functions from your mod for other mods to consume, or call functions exposed by other providers:

* `exports(name, fn)` - Registers an export function for the current mod.
* `exports.provider.name(...)` - Calls an export function exposed by another mod.

Additionally, each mod instance receives helper properties on load:

* `mod.name` - The name of the current mod.
* `mod.realm` - The current realm (`"client"` or `"server"`).
* `mod.dir` - The absolute directory path of the mod.
* `mod.persist` - Persistent state table shared across reloads.
* `mod.on_stop(callback)` - Registers a cleanup handler called when the mod stops.