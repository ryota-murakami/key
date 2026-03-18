# Key

A macOS menubar-resident keyboard shortcut viewer. Displays your keybinds at a glance in a dark-themed popup — triggered by the ⌘ menubar icon or a global hotkey (default: ⌘⇧K).

## Features

- **Menubar-resident** — lives in the menubar, no Dock icon
- **Global hotkey** — toggle with ⌘⇧K (configurable)
- **4-column layout** — 98 keybinds across 13 categories, all visible without scrolling
- **User-editable** — keybinds stored as JSON at `~/.config/key/keybinds.json`
- **Configurable display** — adjust font size and window dimensions via Settings panel
- **Right-click menu** — Edit Keybinds, Reload, Settings, Quit

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
| `~/.config/key/keybinds.json` | Keybind data (auto-created on first launch from bundled defaults) |
| `~/.config/key/settings.json` | Global shortcut and display settings |

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
  "globalShortcut": "⌘⇧K",
  "fontSize": 16,
  "windowWidth": 860,
  "windowHeight": 850
}
```

## Tech Stack

- **Language**: Swift 5.9+
- **UI**: SwiftUI (`MenuBarExtra`, `.window` style)
- **Platform**: macOS 14+
- **Package Manager**: Swift Package Manager
- **Global Hotkey**: Carbon Event API (`RegisterEventHotKey`)
- **Bundle ID**: `io.laststance.key`

## Project Structure

```
Sources/Key/
  KeyApp.swift                 # App entry + AppDelegate
  Keybind.swift                # Data models (Codable)
  KeybindLoader.swift          # JSON loading with user-config-first priority
  KeybindStore.swift           # Observable store + column distribution
  ShortcutConfig.swift         # Settings persistence + shortcut parsing
  SettingsStore.swift           # Display settings (font size, window size)
  SettingsView.swift           # Settings panel UI
  GlobalShortcutManager.swift  # Carbon Event API hotkey registration
  PopupView.swift              # Main popup UI (columns, categories, rows)
  Resources/
    default-keybinds.json      # Bundled defaults (98 keybinds, 13 categories)
assets/
  AppIcon.icns                 # App icon
scripts/
  bundle.sh                    # Release build + .app bundle installer
```

## License

MIT
