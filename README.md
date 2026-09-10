# Key

A macOS menubar-resident keyboard shortcut viewer. Displays your keybinds at a glance in a dark-themed overlay — triggered by the ⌘ menubar icon or a global hotkey (default: ⌘⇧K).

## Features

- **Menubar-resident** — lives in the menubar, no Dock icon
- **Global hotkey** — toggle with ⌘⇧K (configurable)
- **Switchable tables** — Cursor, Emacs, Vim, and GitHub shortcut boards
- **Background opacity** — fade the overlay card without fading the text
- **Always on top** — pin the overlay in front of other windows
- **Border resize** — drag any edge or corner to change the overlay size
- **4-column layout** — categories laid out so a full table is visible without scrolling
- **User-editable** — each table is a JSON file under `~/.config/key/`
- **Configurable display** — font size, window size, opacity, pin, and table via Settings
- **Right-click menu** — Edit Keybinds, table switcher, Always on Top, Reload, Settings, Quit

## Install

### From source

```bash
git clone https://github.com/laststance/key.git
cd key
./scripts/bundle.sh    # builds and installs to /Applications/Key.app
```

### Development

```bash
swift build    # compile
swift run      # launch from terminal
```

Requires macOS 14+ and Swift 5.9+.

## Configuration

| File | Purpose |
|------|---------|
| `~/.config/key/keybinds.json` | Cursor table (auto-created from bundled defaults) |
| `~/.config/key/emacs-keybinds.json` | Emacs table |
| `~/.config/key/vim-keybinds.json` | Vim table |
| `~/.config/key/github-keybinds.json` | GitHub table |
| `~/.config/key/settings.json` | Global shortcut, display, opacity, pin, and selected table |

### Keybind JSON format

```json
{
  "categories": [
    {
      "category": "Category Name",
      "keybinds": [
        { "action": "Action Name", "shortcut": "⌘K" }
      ]
    }
  ]
}
```

### Settings JSON format

```json
{
  "alwaysOnTop": false,
  "backgroundOpacity": 1,
  "fontSize": 16,
  "globalShortcut": "⌘⇧K",
  "selectedProfile": "cursor",
  "windowHeight": 850,
  "windowWidth": 860
}
```

`selectedProfile` is one of `cursor`, `emacs`, `vim`, or `github`. `backgroundOpacity` is `0.1`–`1.0` and affects only the card background.

## Overlay controls

- **Tabs** at the top of the overlay switch tables immediately
- **Pin** button (or Settings / right-click → Always on Top) keeps the overlay in front
- **Drag the border** (edges and corners) to resize; size is saved to `settings.json`
- Unpinned overlays hide when the app deactivates or when you press Escape

## Tech Stack

- **Language**: Swift 5.9+
- **UI**: SwiftUI + AppKit (`NSPanel` overlay, `MenuBarExtra` status item)
- **Platform**: macOS 14+
- **Package Manager**: Swift Package Manager
- **Global Hotkey**: Carbon Event API (`RegisterEventHotKey`)
- **Bundle ID**: `io.laststance.key`

## Project Structure

```
Sources/Key/
  KeyApp.swift                 # App entry + AppDelegate
  Keybind.swift                # Data models (Codable)
  KeybindProfile.swift         # Cursor / Emacs / Vim / GitHub tables
  KeybindLoader.swift          # Per-profile JSON loading
  KeybindStore.swift           # Observable store + column distribution
  ShortcutConfig.swift         # Settings persistence + shortcut parsing
  SettingsStore.swift          # Display, opacity, pin, selected table
  SettingsView.swift           # Settings panel UI
  GlobalShortcutManager.swift  # Carbon Event API hotkey registration
  PopupPanelController.swift   # Floating overlay window
  PopupView.swift              # Overlay UI (tabs, columns, pin)
  ResizeBorderOverlay.swift    # Border-drag resize handles
  ResizeEdge.swift             # Resize-anchor math
  Resources/
    default-keybinds.json      # Cursor table
    emacs-keybinds.json        # Emacs table
    vim-keybinds.json          # Vim table
    github-keybinds.json       # GitHub table
Tests/KeyTests/
  KeybindTableJSONTests.swift  # Bundled table decode specs
assets/
  AppIcon.icns                 # App icon
scripts/
  bundle.sh                    # Release build + .app bundle installer
```

## License

MIT
