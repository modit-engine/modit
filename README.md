# Modit Engine

### A small-footprint, modding-first game engine built with LuaJIT and Raylib.

![Status](https://img.shields.io/badge/Status-Alpha-e4ad29?style=flat-square\&labelColor=0E0E0E)
![Platforms](https://img.shields.io/badge/Platforms-Windows-green?style=flat-square\&labelColor=0E0E0E)
![Language](https://img.shields.io/badge/Language-LuaJIT-blue?style=flat-square\&labelColor=0E0E0E)
![License](https://img.shields.io/badge/License-Apache--2.0-555?style=flat-square\&labelColor=0E0E0E)

<h4>Built by Case (CaseIRL)</h4>

<a href="https://caseirl.dev" style="text-decoration: none;"><img src="https://img.shields.io/badge/🌐_Website-caseirl.dev-4dcbc2?style=for-the-badge&logoColor=white" alt="Website" /></a><a href="https://discord.gg/KJeEEUtyeq" style="text-decoration: none;"><img src="https://img.shields.io/badge/_Discord-/KJeEEUtyeq-4dcbc2?style=for-the-badge&logo=discord&logoColor=white" alt="Discord" /></a><a href="https://ko-fi.com/case" style="text-decoration: none;"><img src="https://img.shields.io/badge/_Ko--fi-Support-4dcbc2?style=for-the-badge&logo=kofi&logoColor=white" alt="Ko-fi" /></a>

## About

I've tried pretty much every Lua game engine and framework I've come across, and always ended up preferring the code-first ones. Coming from the FiveM modding scene, that workflow is more natural to me.

The problem is that once you start looking for native Lua engines with proper 3D support, the options get pretty slim.

So I'm building the minimal, code-first Lua 3D engine I wish existed.

Modit is also being built with a much bigger game project in mind. I want the engine to be something I can actually use myself, which is why modding is part of the foundation rather than something I'm planning to bolt on later.

## Getting Started

### Prerequisites

* **Windows OS** (WinSock & WinHTTP FFI backend)
* **LuaJIT** installed and added to your system `PATH`
    * [LuaJIT Installation Guide](https://gist.github.com/Egor-Skriptunoff/cb952f7eaf39b7b1bf739b818ece87cd)

### Installation & Launch

```bash
# Clone the repository
git clone https://github.com/CaseIRL/modit.git
cd modit

# Launch the Editor
luajit src/main.lua
```

## Contributions

Modit is open-source, but I'm not looking for contributions just yet.

I'm still establishing the core around what I personally need for the game I want to build. Once that's in place, I'll be more open to outside contributions.

Issues and experimentation are welcome.

## Support

Something crash? 
Sandbox sinking? 
Window decided to become a black hole?

If I'm around, give me a shout. 
If not? Figure it out or sacrifice a chicken and wait?

Support Hours: *Whenever I'm awake and not dealing with real life.*

## License & Credits

Modit is open-source software licensed under the [Apache 2.0 License](LICENSE).

### Third-Party Software

- **[raylib](https://www.raylib.com)** (zlib License) - Copyright (c) 2013-2026 Ramon Santamaria (@raysan5)
- **[LuaJIT](https://luajit.org)** (MIT License) - Copyright (c) 2005-2026 Mike Pall

