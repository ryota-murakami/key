import ServiceManagement
import SwiftUI

/// macOS menubar app that displays keybind information in a floating overlay.
///
/// @example
/// The app runs as a menubar-only utility with a "⌘" icon.
/// Clicking the icon toggles {@link PopupPanelController}; clicking outside dismisses
/// an unpinned overlay. Right-clicking the icon shows the settings menu.
/// Press ⌘⇧K (configurable) to toggle the overlay from any app.
@main
struct KeyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // MenuBarExtra only creates the ⌘ status item; the button action is hijacked
        // in {@link AppDelegate} so the overlay is {@link PopupPanelController}, not this window.
        MenuBarExtra {
            Color.clear
                .frame(width: 1, height: 1)
        } label: {
            Text("⌘")
        }
        .menuBarExtraStyle(.window)
    }
}

/// Configures the app as a menubar-only accessory, registers the global keyboard shortcut,
/// and routes menubar clicks to {@link PopupPanelController}.
///
/// @example
/// `NSApp.setActivationPolicy(.accessory)` hides the Dock icon.
/// The global shortcut (default ⌘⇧K) toggles the overlay via {@link PopupPanelController.toggle}.
/// Right-click on the menubar icon shows Edit Keybinds / table switcher / Quit.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var shortcutManager: GlobalShortcutManager?
    private var settingsWindow: NSPanel?
    private var statusItemMonitor: Any?
    private var extraWindowObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        _ = SettingsStore.shared
        KeybindLoader.ensureUserConfigExists()

        PopupPanelController.shared.statusButtonProvider = { [weak self] in
            self?.findMenuBarButton()
        }

        // Delay to ensure MenuBarExtra has created its status bar button
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.setupGlobalShortcut()
            self.installStatusItemMonitor(attempt: 0)
        }
        hideMenuBarExtraContentWindow()
    }

    // MARK: - Global Shortcut

    /// Loads shortcut config and registers the global hotkey.
    ///
    /// This method is also called after Settings changes so the newly recorded
    /// shortcut starts working immediately.
    ///
    /// - Returns: `true` when the configured shortcut was registered successfully.
    @discardableResult
    private func setupGlobalShortcut() -> Bool {
        shortcutManager = nil

        let config = ShortcutConfig.load()
        guard let (keyCode, modifiers) = config.carbonValues() else {
            print("[Key] Invalid shortcut config: \(config.globalShortcut)")
            return false
        }

        let manager = GlobalShortcutManager()
        let didRegister = manager.register(keyCode: keyCode, modifiers: modifiers) {
            PopupPanelController.shared.toggle()
        }
        guard didRegister else {
            return false
        }

        shortcutManager = manager
        return true
    }

    // MARK: - Status Item Clicks

    /// Consumes clicks on the ⌘ status button so MenuBarExtra never opens its 1×1 window.
    ///
    /// Left-click toggles {@link PopupPanelController}; right-click shows the context menu.
    /// Retries because the status button is created asynchronously.
    ///
    /// - Parameter attempt: Zero-based retry count used when the button is not ready yet.
    private func installStatusItemMonitor(attempt: Int) {
        if findMenuBarButton() == nil, attempt < 10 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.installStatusItemMonitor(attempt: attempt + 1)
            }
            return
        }

        statusItemMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let button = self.findMenuBarButton(), event.window == button.window else {
                return event
            }

            let location = button.convert(event.locationInWindow, from: nil)
            guard button.bounds.contains(location) else {
                return event
            }

            if event.type == .rightMouseDown {
                self.showContextMenu()
            } else {
                PopupPanelController.shared.toggle()
            }
            return nil
        }
    }

    /// Hides the unused MenuBarExtra content window if SwiftUI still materializes it.
    private func hideMenuBarExtraContentWindow() {
        extraWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow else { return }
            if window.identifier?.rawValue == "key.popup-panel" { return }
            if window === self?.settingsWindow { return }
            // The leftover extra is a tiny empty window next to the status item.
            if window.frame.width <= 8, window.frame.height <= 8 {
                window.orderOut(nil)
            }
        }
    }

    /// Builds and presents the menubar context menu under the ⌘ button.
    private func showContextMenu() {
        guard let button = findMenuBarButton() else { return }
        let menu = buildContextMenu()
        PopupPanelController.shared.withMenusAbove {
            menu.popUp(
                positioning: menu.items.first,
                at: NSPoint(x: 0, y: button.bounds.height),
                in: button
            )
        }
    }

    // MARK: - Right-Click Context Menu

    /// Builds the context menu for the menubar icon's right-click action.
    ///
    /// @example
    /// Right-clicking the ⌘ icon shows:
    /// - Edit Keybinds... → opens the current profile JSON
    /// - Keybind Table → Cursor / Emacs / Vim / GitHub
    /// - Always on Top → pins {@link PopupPanelController}
    /// - Reload → re-reads JSON
    /// - Launch at Login → toggles SMAppService login item
    /// - Settings... → opens display settings panel
    /// - Quit → terminates the app
    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu()

        let editItem = NSMenuItem(
            title: "Edit Keybinds...",
            action: #selector(editKeybinds),
            keyEquivalent: ""
        )
        editItem.target = self
        menu.addItem(editItem)

        let tableMenu = NSMenu()
        for profile in KeybindProfile.allCases {
            let item = NSMenuItem(
                title: profile.displayName,
                action: #selector(selectProfileFromMenu(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = profile.rawValue
            item.state = SettingsStore.shared.selectedProfile == profile ? .on : .off
            tableMenu.addItem(item)
        }
        let tableItem = NSMenuItem(title: "Keybind Table", action: nil, keyEquivalent: "")
        tableItem.submenu = tableMenu
        menu.addItem(tableItem)

        let pinItem = NSMenuItem(
            title: "Always on Top",
            action: #selector(toggleAlwaysOnTop),
            keyEquivalent: ""
        )
        pinItem.target = self
        pinItem.state = SettingsStore.shared.alwaysOnTop ? .on : .off
        menu.addItem(pinItem)

        let reloadItem = NSMenuItem(
            title: "Reload",
            action: #selector(reloadKeybinds),
            keyEquivalent: ""
        )
        reloadItem.target = self
        menu.addItem(reloadItem)

        let launchAtLoginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginItem.target = self
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(launchAtLoginItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ""
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quitApp),
            keyEquivalent: ""
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    /// Opens the current {@link KeybindProfile} JSON in the user's default editor.
    @objc private func editKeybinds() {
        KeybindLoader.ensureUserConfigExists()
        let url = URL(fileURLWithPath: KeybindLoader.userConfigPath)
        NSWorkspace.shared.open(url)
    }

    /// Reloads keybind data from disk and refreshes the overlay.
    @objc private func reloadKeybinds() {
        KeybindStore.shared.reload()
    }

    /// Switches tables from the context-menu submenu.
    ///
    /// - Parameter sender: Menu item whose `representedObject` is a {@link KeybindProfile} raw value.
    @objc private func selectProfileFromMenu(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let profile = KeybindProfile(rawValue: raw) else { return }
        KeybindStore.shared.select(profile)
    }

    /// Toggles {@link SettingsStore.alwaysOnTop} from the context menu.
    @objc private func toggleAlwaysOnTop() {
        SettingsStore.shared.alwaysOnTop.toggle()
        SettingsStore.shared.save()
        PopupPanelController.shared.applyAppearance()
    }

    /// Opens the settings panel for display options and global shortcut capture.
    @objc private func openSettings() {
        if let existing = settingsWindow, existing.isVisible {
            existing.level = .modalPanel
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(
            rootView: SettingsView { [weak self] in
                self?.setupGlobalShortcut() ?? false
            }
        )
        hosting.sizingOptions = [.preferredContentSize]

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 420),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Settings"
        panel.isFloatingPanel = true
        panel.level = .modalPanel
        panel.becomesKeyOnlyIfNeeded = false
        panel.contentViewController = hosting
        let fitting = hosting.preferredContentSize
        // Preferred size can be zero before the first layout pass.
        if fitting.width > 0, fitting.height > 0 {
            panel.setContentSize(fitting)
        } else {
            panel.setContentSize(NSSize(width: 420, height: 480))
        }
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = panel
    }

    /// Toggles whether the app launches at login via SMAppService.
    ///
    /// @example
    /// ```swift
    /// // If currently enabled, unregisters the login item.
    /// // If currently disabled, registers it.
    /// toggleLaunchAtLogin()
    /// ```
    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        if service.status == .enabled {
            service.unregister { error in
                if let error = error {
                    print("[Key] Failed to unregister login item: \(error)")
                }
            }
        } else {
            do {
                try service.register()
            } catch {
                print("[Key] Failed to register login item: \(error)")
            }
        }
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
