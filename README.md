# Modit Engine

### A small-footprint, code-first 2D/3D game engine built with LuaJIT & Raylib.

![Status](https://img.shields.io/badge/Status-Alpha-e4ad29?style=flat-square&labelColor=0E0E0E)
![Platforms](https://img.shields.io/badge/Platforms-Windows-green?style=flat-square&labelColor=0E0E0E)
![Language](https://img.shields.io/badge/Language-LuaJIT-blue?style=flat-square&labelColor=0E0E0E)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square&labelColor=0E0E0E)

<a href="https://modit.dev"><img src="https://img.shields.io/badge/🌐_Website-modit.dev-4dcbc2?style=for-the-badge&logoColor=white" alt="Website" /></a>
<a href="https://discord.gg/QQ7yarSE5U"><img src="https://img.shields.io/badge/_Discord-Join-4dcbc2?style=for-the-badge&logo=discord&logoColor=white" alt="Discord" /></a>
<a href="https://ko-fi.com/case"><img src="https://img.shields.io/badge/_Ko--fi-Support-4dcbc2?style=for-the-badge&logo=kofi&logoColor=white" alt="Ko-fi" /></a>

---

## ⚡ About

I've tried pretty much every Lua game engine and framework I've come across, and always ended up preferring the code-first workflow. Coming from the FiveM modding scene, writing scripts directly against lightweight APIs is second nature.

The problem? Once you start looking for native, high-performance Lua engines with real 3D capabilities, options get pretty slim.

So I'm building **Modit** - the minimal, code-first 2D/3D Lua engine I wish existed.

Modit is engineered with extreme performance and modularity in mind. Instead of bolting modding or multiplayer on as an afterthought, sandboxed mod support and client/server architecture are baked directly into the engine's DNA.

---

## 🛠️ Feature Overview

- [x] **Code-First Workflow:** Pure LuaJIT execution with low-overhead C-FFI bindings. No bulky editor overhead unless you want it.
- [x] **2D & 3D Rendering Pipeline:** Built on top of Raylib - supporting 3D models, custom GLSL shaders, camera systems, lighting, and 2D sprite rendering.
- [x] **Box3D Physics & Voxels:** Integrated 3D bounding boxes, collision detection, raycasting, dynamic physics, and voxel terrain support.
- [x] **Sandboxed Modding Core:** Isolated environment execution allowing players and creators to load dynamic mods safely at runtime.
- [x] **Client/Server & Headless Mode:** Built-in networking architecture with headless server support for dedicated game servers.
- [x] **Audio & Input Management:** Direct input mapping for gamepads/keyboard/mouse and positional 3D spatial audio.

---

## 🚀 Getting Started

### Prerequisites

* **Windows OS** (WinSock & WinHTTP FFI backend)
* **LuaJIT** installed and added to your system `PATH`
    * [LuaJIT Installation Guide](https://gist.github.com/Egor-Skriptunoff/cb952f7eaf39b7b1bf739b818ece87cd)

### Installation & Launch

```bash
# Clone the repository
git clone https://github.com/modit-engine/modit.git
cd modit-engine

# Launch the Engine / Sandbox
luajit src/main.lua

```

---

## 🤝 Contributions

Modit is open-source, but I'm not actively taking major pull requests just yet.

I'm currently solidifying the core architectural foundations around the commercial title I'm building with it. Once the baseline API stabilizes, outside contributions and extensions will be warmly welcomed!

In the meantime, feel free to open issues, report bugs, or experiment with the code.

---

## 💬 Support

Something crash?

Sandbox sinking?

Window decided to turn into a black hole?

If I'm around, give me a shout on [Discord](https://discord.gg/QQ7yarSE5U).

If not? Figure it out or offer up a sacrifice to the Lua compiler.

**Support Hours:** *Whenever I'm awake and not dealing with real life.*

---

## 📄 License & Credits

Modit Engine is open-source software licensed under the [MIT License](https://www.google.com/search?q=LICENSE).

### Third-Party Libraries & Tech

* **[raylib](https://raylib.com)** (zlib License) - Copyright (c) 2013-2026 Ramon Santamaria (@raysan5)
* **[LuaJIT](https://luajit.org)** (MIT License) - Copyright (c) 2005-2026 Mike Pall
* **[Box3D](https://box2d.org)** (MIT License) - Copyright (c) 2026 Erin Catto
