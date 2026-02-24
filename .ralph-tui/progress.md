# Ralph Progress Log

This file tracks progress across iterations. Agents update this file
after each iteration and it's included in prompts for context.

## Codebase Patterns (Study These First)

- **SPM macOS GUI App**: Use `Package.swift` with `platforms: [.macOS(.v14)]` and `@main` SwiftUI `App` struct. `swift build` produces a working executable.
- **No-Dock Menubar App (SPM)**: Without Info.plist, use `NSApp.setActivationPolicy(.accessory)` via `@NSApplicationDelegateAdaptor` instead of `LSUIElement`.
- **MenuBarExtra custom label**: Use `MenuBarExtra { content } label: { Text("⌘") }` for text-based menubar icons.
- **Outside-click dismissal**: `.menuBarExtraStyle(.window)` provides this behavior for free — no custom event handling needed.
- **SPM Resource Bundling**: Add `resources: [.process("Resources")]` to target in `Package.swift`. Access at runtime via `Bundle.module.url(forResource:withExtension:)`.
- **User Config Path Pattern**: Use `~/.config/key/` for user customization files, with bundled defaults as fallback.
- **Dark Theme Colors**: Background `NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)` ≈ `#1E1E1E`. Use `Color(nsColor:)` for precise control.
- **Multi-column category layout**: Use greedy bin-packing by row count (`1 + keybinds.count` per category) with ~15% overflow tolerance to balance columns evenly.
- **Global hotkey with MenuBarExtra**: Use Carbon `RegisterEventHotKey` for system-wide hotkey, then `NSStatusBarButton.performClick(nil)` (found via `NSApp.windows` hierarchy search) to toggle the MenuBarExtra popup programmatically.
- **Configurable shortcut from JSON**: `~/.config/key/settings.json` with `{ "globalShortcut": "⌘⇧K" }` format — uses same Unicode modifier symbols (⌘⇧⌃⌥) as the keybind cheat sheet data.
- **Right-click menu on MenuBarExtra**: Use `NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown)` + check `event.window == button.window` + `NSMenu.popUp(positioning:at:in:)`. Return `nil` to consume the event.
- **@Observable singleton for reactive state**: `@Observable final class Store { static let shared = Store() }` — SwiftUI views auto-track property access in `body` without wrappers.

---

## 2026-02-20 - US-001
- Implemented macOS menubar app foundation with SwiftUI MenuBarExtra
- Files changed:
  - `Package.swift` — SPM config targeting macOS 14
  - `Sources/Key/KeyApp.swift` — Main app entry with MenuBarExtra scene + AppDelegate for `.accessory` activation policy
  - `Sources/Key/PopupView.swift` — Placeholder popup view with Quit button
- **Learnings:**
  - `MenuBarExtra` with `.menuBarExtraStyle(.window)` handles popup display and outside-click dismissal natively
  - `@NSApplicationDelegateAdaptor` is the correct way to hook into AppDelegate lifecycle in a SwiftUI App
  - `swiftlint` is not installed on this machine — quality gate partially unavailable
  - SPM `swift build` compiles SwiftUI macOS apps correctly without Xcode project wrapper
---

## 2026-02-20 - US-002
- Implemented JSON keybind data loading with user-config-first priority and bundled default fallback
- Files changed:
  - `Sources/Key/Keybind.swift` — Codable data models: `KeybindData > KeybindCategory > Keybind`
  - `Sources/Key/Resources/default-keybinds.json` — Bundled default keybinds (General, Window, Navigation categories)
  - `Sources/Key/KeybindLoader.swift` — Loader enum with `~/.config/key/keybinds.json` priority, parse-error fallback
  - `Package.swift` — Added `resources: [.process("Resources")]` to executable target
- **Learnings:**
  - SPM auto-generates `resource_bundle_accessor.swift` when `resources` is declared, providing `Bundle.module`
  - `Bundle.module` is the correct way to access SPM target resources (not `Bundle.main`)
  - `enum` with static methods is idiomatic Swift for utility types with no instances (like `KeybindLoader`)
  - `FileManager.default.homeDirectoryForCurrentUser` gives the correct `~` expansion at runtime
---

## 2026-02-20 - US-003
- Added 11 Editor section keybinding categories (88 items total) to `default-keybinds.json`
- Files changed:
  - `Sources/Key/Resources/default-keybinds.json` — Added Move Cursor (10), Selection (12), Scroll (5), Code Edit (14), Find (4), Split Editor Window (5), Code Jump (10), IntelliSense (1), File Explorer (8), IDE Feature (16), AI (3)
- **Learnings:**
  - Chord keybindings (e.g. `⌘K ⌘S`) are represented as a single string with space separator — no special data model needed
  - Context-dependent shortcuts (e.g. `⌘X` for Cut vs Cut Line) can appear in multiple categories — this is intentional for cheat sheet UX
  - Existing `KeybindData > KeybindCategory > Keybind` model handled 14 categories / 88+ items without any schema changes
  - JSON backslash for Split Editor (`⌘\`) requires `\\` escape in JSON source
---

## 2026-02-20 - US-004
- Added Git (1 item) and Multiple Cursor (6 items) keybinding categories to `default-keybinds.json`
- Files changed:
  - `Sources/Key/Resources/default-keybinds.json` — Added Git: Git Blame (`⌃G ⌃B`); Multiple Cursor: Add Cursor Above, Add Cursor Below, Rectangular Selection, Add Cursors to Line Ends, Add Next Occurrence, Undo Last Cursor
- **Learnings:**
  - Git Blame uses chord keybinding `⌃G ⌃B` — same space-separated format as `⌘K ⌘S`
  - Multiple Cursor items intentionally overlap with Selection category (e.g. `⌘D`, `⌥⌘↑/↓`) — cheat sheet UX benefits from grouping by conceptual context
  - Total categories now at 16 with 95+ keybinds, no schema changes needed
---

## 2026-02-20 - US-005
- Implemented dark-themed popup window UI with multi-column keybind layout
- Files changed:
  - `Sources/Key/PopupView.swift` — Complete rewrite: replaced placeholder with `PopupView` (820×520pt fixed), `CategoryBlock`, `KeybindRow`, `LegendBar`
- **Learnings:**
  - `MenuBarExtra` popup size is driven entirely by the content view's `.frame()` — no separate window configuration needed
  - Greedy bin-packing with 1.15× overflow tolerance distributes 16 categories evenly across 4 columns
  - `.font(.system(size:design:.monospaced))` gives SF Mono on macOS 14+; no need to specify font family explicitly
  - `private struct` for sub-views (`CategoryBlock`, `KeybindRow`, `LegendBar`) keeps the file self-contained and prevents namespace pollution
  - `ForEach(Array(x.enumerated()), id: \.offset)` is needed when model types don't conform to `Identifiable`
---

## 2026-02-20 - US-006
- Already implemented as part of US-005 — multi-column layout was delivered together with the popup UI
- Files changed: None (all criteria already met in `Sources/Key/PopupView.swift`)
- Verification: `swift build` passes, all 5 acceptance criteria confirmed in existing code:
  - 4-column distribution via `distributeColumns(_:columnCount:)` with greedy bin-packing
  - Balanced heights via `targetPerColumn * 1.15` overflow tolerance
  - Category spacing: 14pt vertical, 20pt horizontal
  - Visual distinction: bold white headers vs gray action/shortcut rows
  - Fixed 820×520pt frame fits all data without scrolling
- **Learnings:**
  - When a prerequisite story (US-005) delivers more than its own scope, downstream stories may already be complete — always verify before reimplementing
---

## 2026-02-20 - US-007
- Implemented global keyboard shortcut (⌘⇧K) to toggle popup visibility from any app
- Files changed:
  - `Sources/Key/GlobalShortcutManager.swift` — Carbon Hot Key API wrapper: registers system-wide hotkey, C-compatible callback with `Unmanaged` pointer context
  - `Sources/Key/ShortcutConfig.swift` — JSON-configurable shortcut settings from `~/.config/key/settings.json`, `ShortcutParser` converts Unicode symbols (⌘⇧⌃⌥) + key character to Carbon key codes/modifiers
  - `Sources/Key/KeyApp.swift` — Extended `AppDelegate` with shortcut setup, `NSStatusBarButton` discovery via `NSApp.windows`, and `performClick(nil)` toggle
- **Learnings:**
  - Carbon `RegisterEventHotKey` is still the only reliable way to register system-wide hotkeys on macOS — no Swift/AppKit replacement exists
  - The C callback for `InstallEventHandler` requires a free function (not a closure); use `Unmanaged.passUnretained(self).toOpaque()` as userData to pass Swift context
  - `MenuBarExtra(.window)` creates an `NSStatusBarButton` findable via recursive `NSApp.windows` search — `performClick(nil)` triggers the built-in show/hide toggle
  - `DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)` is needed after launch to ensure MenuBarExtra has created its status bar window
  - `EventHotKeyID.signature` should be `let` not `var` — `RegisterEventHotKey` takes it by value, not by reference
  - Carbon modifier constants (`cmdKey`, `shiftKey`, `controlKey`, `optionKey`) are available in Swift via `import Carbon`
---

## 2026-02-20 - US-008
- Implemented settings menu and app management features
- Files changed:
  - `Sources/Key/KeybindLoader.swift` — Added `ensureUserConfigExists()` for first-launch bootstrap (creates `~/.config/key/` dir + copies bundled default JSON)
  - `Sources/Key/KeybindStore.swift` — **New file**: `@Observable` singleton holding keybind data/columns with `reload()`, moved `distributeColumns` from PopupView
  - `Sources/Key/PopupView.swift` — Refactored to use `KeybindStore.shared` instead of inline data loading; removed `distributeColumns` (moved to store)
  - `Sources/Key/KeyApp.swift` — Added right-click context menu (Edit Keybinds / Reload / Quit), calls `ensureUserConfigExists()` at launch
- **Learnings:**
  - `NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown)` is the cleanest way to add right-click behavior to an `NSStatusBarButton` owned by `MenuBarExtra(.window)` — avoids subclassing or swizzling
  - `NSMenu.popUp(positioning:at:in:)` can show a menu at an arbitrary position relative to any view — used to position context menu just above the status bar button
  - `@Observable` singleton pattern (`static let shared`) works seamlessly with SwiftUI views — accessing properties in `body` auto-tracks without `@ObservedObject` or `@EnvironmentObject`
  - `NSWorkspace.shared.open(URL(fileURLWithPath:))` opens a file in the user's default editor — simplest way to implement "Edit config file"
  - `ensureUserConfigExists()` must be called before `KeybindStore.shared` is first accessed to guarantee the user config file exists; placing it early in `applicationDidFinishLaunching` ensures correct ordering
---

