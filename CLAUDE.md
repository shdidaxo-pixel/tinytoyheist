# Tiny Toy Heist

Roblox "steal" game. Code is synced into Studio with Rojo (`default.project.json`); the map is built by
`tools/build-bedroom.luau`; the UI is built by `src/StarterPlayer/StarterPlayerScripts/TinyToyHeistUI/`.
Notes, decisions and the devlog live in the Obsidian vault (Games/Tiny Toy Heist).

## Always
- **Commit every change.** After each change (code, assets, design files, places), run StyLua and Selene, then
  commit with a short plain message. Don't batch unrelated changes. Videos (*.mp4) stay out of git.
- **Save the place every time Studio changes.** Tools can't save a place file, so after changing anything in
  Studio, ask Dylan to save with File > Save to File As into `places/TinyToyHeist-Latest.rbxl`, check the file's
  timestamp, then commit it.
