# v0.2.0



# v0.1.0

Initial public build.

A lot was done before the first GitHub upload, with previous development taking place in a private repository within an organisation. This is the first public Modit repository, so this changelog is effectively documenting the state of the project at its first public release.

Modit is mostly a rebuild of my old [lua_game_engine](https://github.com/CaseIRL/lua_game_engine) project, but with a small editor attached and a much better direction.

The goal is to build a small-footprint game engine around a development experience similar to FiveM, with modding and resource support being a core part of the engine rather than something added afterwards.

Some of the API concepts are intentionally familiar:

* `exports()`
* `json.encode()`
* `json.decode()`
* Resource manifests
* Resource dependencies
* Resource lifecycle management
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
* Project/resource tooling

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
* Resource loading and lifecycle management
* Fixed-rate server ticking
* Headless server foundations
* Logging and log history
* Developer console

The project is still very much in development and the architecture, APIs and project structure will continue to change significantly before the first stable release.
