import SwiftUI

/// macOS menubar app that displays keybind information in a popup window.
///
/// @example
/// The app runs as a menubar-only utility with a "⌘" icon.
/// Clicking the icon shows a popup; clicking outside dismisses it.
/// Right-clicking the icon shows a settings menu (Edit Keybinds, Reload, Quit).
/// Press ⌘⇧K (configurable) to toggle the popup from any app.
@main
struct KeyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            PopupView()
        } label: {
            Text("⌘")
        }
        .menuBarExtraStyle(.window)
    }
}

/// Configures the app as a menubar-only accessory, registers the global keyboard shortcut,
/// and sets up the right-click context menu on the status bar icon.
///
/// @example
/// `NSApp.setActivationPolicy(.accessory)` hides the Dock icon.
/// The global shortcut (default ⌘⇧K) toggles the popup via `NSStatusBarButton.performClick`.
/// Right-click on the menubar icon shows Edit Keybinds / Reload / Quit.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var shortcutManager: GlobalShortcutManager?
    private var rightClickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        KeybindLoader.ensureUserConfigExists()

        // Delay to ensure MenuBarExtra has created its status bar button
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.setupGlobalShortcut()
            self.setupRightClickMenu()
        }
    }

    // MARK: - Global Shortcut

    /// Loads shortcut config and registers the global hotkey.
    private func setupGlobalShortcut() {
        let config = ShortcutConfig.load()
        guard let (keyCode, modifiers) = config.carbonValues() else {
            print("[Key] Invalid shortcut config: \(config.globalShortcut)")
            return
        }

        shortcutManager = GlobalShortcutManager()
        shortcutManager?.register(keyCode: keyCode, modifiers: modifiers) { [weak self] in
            self?.toggleMenuBarPopup()
        }
    }

    /// Toggles the MenuBarExtra popup by simulating a click on its status bar button.
    private func toggleMenuBarPopup() {
        guard let button = findMenuBarButton() else {
            print("[Key] Could not find menu bar button")
            return
        }
        button.performClick(nil)
    }

    // MARK: - Right-Click Context Menu

    /// Monitors right-click events on the status bar button to show the settings menu.
    private func setupRightClickMenu() {
        rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
            guard let self = self,
                  let button = self.findMenuBarButton(),
                  event.window == button.window else {
                return event
            }

            let menu = self.buildContextMenu()
            menu.popUp(
                positioning: nil,
                at: NSPoint(x: 0, y: button.bounds.height + 5),
                in: button
            )
            return nil // consume the event
        }
    }

    /// Builds the context menu with Edit Keybinds, Reload, and Quit items.
    ///
    /// @example
    /// Right-clicking the ⌘ icon shows:
    /// - Edit Keybinds... (opens ~/.config/key/keybinds.json in default editor)
    /// - Reload (re-reads JSON and refreshes UI)
    /// - ─────── (separator)
    /// - Quit (terminates the app)
    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu()

        let editItem = NSMenuItem(
            title: "Edit Keybinds...",
            action: #selector(editKeybinds),
            keyEquivalent: ""
        )
        editItem.target = self
        menu.addItem(editItem)

        let reloadItem = NSMenuItem(
            title: "Reload",
            action: #selector(reloadKeybinds),
            keyEquivalent: ""
        )
        reloadItem.target = self
        menu.addItem(reloadItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quitApp),
            keyEquivalent: ""
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    /// Opens `~/.config/key/keybinds.json` in the user's default editor.
    @objc private func editKeybinds() {
        let url = URL(fileURLWithPath: KeybindLoader.userConfigPath)
        NSWorkspace.shared.open(url)
    }

    /// Reloads keybind data from disk and refreshes the popup UI.
    @objc private func reloadKeybinds() {
        KeybindStore.shared.reload()
    }

    /// Terminates the application.
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Status Bar Button Discovery

    /// Finds the NSStatusBarButton created by MenuBarExtra in the app's window hierarchy.
    private func findMenuBarButton() -> NSStatusBarButton? {
        for window in NSApp.windows {
            if let button = findButton(in: window.contentView) {
                return button
            }
        }
        return nil
    }

    /// Recursively searches a view hierarchy for an NSStatusBarButton.
    private func findButton(in view: NSView?) -> NSStatusBarButton? {
        guard let view = view else { return nil }
        if let button = view as? NSStatusBarButton { return button }
        for subview in view.subviews {
            if let button = findButton(in: subview) { return button }
        }
        return nil
    }
}
