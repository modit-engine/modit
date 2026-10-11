# v0.9.0

Physics & Box3D Integration.

- Integrated the **Box3D** physics engine backend under `engine/backend/box3d/`, featuring comprehensive modular wrappers (`body.lua`, `events.lua`, `query.lua`, `shape.lua`, `world.lua`) alongside generated FFI bindings.
- Added the core engine physics module (`modules/physics.lua`) to expose physics capabilities.
- Added build configuration support for Box3D, enabling automatic runtime detection of single-precision (`float`) versus double-precision (`BOX3D_DOUBLE_PRECISION`) builds via `b3IsDoublePrecision()` and conditionally mapping `b3Pos` and `b3WorldTransform` types.

Notes:
- Be careful not to spam or overload physics tick/update loops with unhandled errors. Rapid failures in `update` listeners can trigger table overflows and disconnects:
error     20:41:04    network connection failed: connection refused
error     20:41:37    [hooks] 'update' listener from default_world removed after error: table overflow

This will be fully addressed and fixed before `v0.10.0`.

# v0.8.0

Shadows & Water

- Added support for shadows; blob/projected/mapped pretty basic implementation but its there.
- Added water module same as above basic but exists, using a sinewave vertex shader.

Notes:
- Project will go public as soon as possible potentially after physics? 

# v0.7.0

Lighting & Sky.

- Moved render modules inside engine into `/modules/render`
- Added basic `modules/render/lighting` & `/sky` modules nothing amazing mostly a copy of raylib examples
- Client build fixes pushed by sayer

Notes:
- Project will go public as soon as possible, once the API is a little more feature filled and documented. 

# v0.6.0

Maths modules, editor improvements, and client/server support.

- Added an editor **Load Project** menu option.
- Moved keyboard and mouse input into the new `modules/input/` directory.
- Added an input actions module for defining and handling higher-level input actions.
- Replaced the old maths file with a new `modules/maths/` directory containing:
  - Vector operations (`vec2`, `vec3`, `vec4`).
  - 4×4 matrix operations.
  - 2D and 3D geometry utilities.
  - Easing functions.
  - Probability utilities.
  - Statistics and core maths helpers.
- Added a maths `init.lua` entry point to expose maths modules through a single import.
- Added a new `modules/runtime/` directory containing callbacks, cooldowns, RNG utilities, state management, and timers.
- Reviewed and corrected mathematical edge cases, input validation, degenerate geometry, and matrix operations.
- Kept maths modules independent of Raylib for use in game logic and headless server code.
- Added support for building both client and server executables using the build tool's target option.
- Verified the client and server can run together, connect successfully, and support in-game movement.

**Notes:**

- The maths API remains subject to review as the engine develops.
- Matrix conventions and rendering integration should continue to be verified against Modit's Raylib backend and camera implementation.
- Additional modules and API documentation will be reviewed as development continues.

# v0.5.0

More modules + Editor improvments

* Added support for audio and images back in from old build.
* Editor has had a lot of improvements courtesy of Sayer
* Game/Mod pathing handling fixed not correctly handles all files relative to current directory
* Project are now created and loaded externally with an included `project.modit` file on creation
* Game engine api is now gated behind `modules = {}` section in game configs, this still has more work to go
* Test projects removed from repo, will put up a seperate repo to pull download from on template picker.
* Raylib font functions moved out of `draw` into its own `font` module.
* Mod sandbox updated to cover the new modules, still has more work to go. 

Notes:

* API is still not fully finalised, have a few more modules to move over, then will give everything a once over and build a api cheatsheet prior to public switch over.

# v0.4.0

Add in test game and port modules into engine.

Changes:

* Too many to really name? will cover important ones
* Headless server support built into core
* Built in commands for headless server moved
* Editor updated to support project templates *(templates are not complete support is there)*
* Editor can now run server or client and only offers server options if enabled in game config
* Changes to runner to support the server side correctly
* General clean up

Notes:

* Still alot of changes to go in porting in the sample game code from a build before deciding to make the engine.
* API should be passed and used correctly within game files instead of requires *(left over from old)*

# v0.3.0

Raylib 6.0 and generated bindings.

Changes:

* Updated the bundled raylib DLL to 6.0
* `engine/backend/raylib/ffi.lua` is now generated from the raylib API definition (`tools/raylib_api/gen_api.lua`) instead of being hand-written
* The generated file covers the full API (structs, aliases, enums, callbacks and functions) with raylib's descriptions as comments, and includes the library loading
* Added the raylib version to the FFI module's exports (`ffi.version`)
* Fixed the window launching maximized but keeping a stale 1600x900 render size on raylib 6.0. Maximize is now applied after the window is created with `MaximizeWindow()`, rather than as a creation flag
* Fixed `window.should_close()` for the `bool` return type, since `WindowShouldClose` returns a `bool` in the real raylib signature

Notes:

* Struct layouts and signatures now come straight from the raylib API file, so upgrading raylib means re-running the generator against the matching API file
* `ffi.lua` is generated and shouldn't be edited by hand. Changes to the library loading go in the generator's template

# v0.2.0

Engine UI split out of the editor.

The reusable UI layer that previously lived inside the editor now belongs to the engine, so in-game UI (for example the in-game client console) no longer depends on any editor code. The editor sits on top of the engine UI rather than owning it.

Changes:

* Moved UI components from `editor/ui/components/` into `engine/ui/components/`
* Moved the theme manager into the engine (`engine/ui/style/theme.lua`)
* Moved the default theme into the engine (`engine/ui/style/themes/default.lua`), so engine UI always has a theme with no editor code required
* Added theme registration with `theme.register()`, plus `theme.set()`, `theme.get()`, `theme.name()`, `theme.list()` and `theme.on_change()`
* Registered themes fall back to the default theme for any missing top-level keys
* Editor-only themes (such as `tokyo_night`) now register themselves with the engine theme manager
* The editor now saves the active theme on close and restores it on startup
* Editor UI reduced to the editor-specific pieces: `panels` and `style/layout`
* Editor now draws through `engine.ui` for components, input and theme
* Removed the duplicate default theme from the editor

Notes:

* The engine no longer requires anything from `src.editor`
* Games get the default theme automatically and don't need a theme picker
* Editor theme picker is not built yet

# v0.1.0

Initial public build.

A lot was done before the first GitHub upload, with previous development taking place in a private repository within an organisation. This is the first public Modit repository, so this changelog is effectively documenting the state of the project at its first public release.

Modit is mostly a rebuild of my old [lua_game_engine](https://github.com/CaseIRL/lua_game_engine) project, but with a small editor attached and a much better direction.

The goal is to build a small-footprint game engine around a development experience similar to FiveM, with modding and mod support being a core part of the engine rather than something added afterwards.

Some of the API concepts are intentionally familiar:

* `exports()`
* `json.encode()`
* `json.decode()`
* Mod manifests
* Mod dependencies
* Mod lifecycle management
* Client/server/shared execution
* Hooks and events

Current engine modules:

* `engine/core/`
* `engine/modules/`
* `engine/backend/`
* `engine/backend/raylib/`
* `engine/backend/platform/`
* `engine/ui/`

Current editor:

* Project management
* Code editor
* Console
* Reusable UI components
* Editor panels
* 3D viewport foundations
* Themes and styling
* Project/mod tooling

Current backend/runtime foundations:

* Raylib windowing and rendering
* 2D and 3D drawing
* Canvas support
* Mouse and keyboard input
* Camera support
* Windows filesystem backend
* Windows process backend
* Windows networking backend
* Windows HTTP/HTTPS backend
* Client/server runtime foundations
* Mod loading and lifecycle management
* Fixed-rate server ticking
* Headless server foundations
* Logging and log history
* Developer console

The project is still very much in development and the architecture, APIs and project structure will continue to change significantly before the first stable release.
