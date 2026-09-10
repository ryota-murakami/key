import AppKit
import SwiftUI

/// Borderless floating {@link KeybindPanel} that hosts {@link PopupView}.
///
/// Exists so background opacity, always-on-top, and border-drag resize can be
/// applied to a real window instead of the transient MenuBarExtra popover.
/// {@link AppDelegate} toggles this panel from the menubar icon and global hotkey.
///
/// @example
/// ```swift
/// PopupPanelController.shared.toggle()
/// PopupPanelController.shared.applyAppearance()
/// ```
final class PopupPanelController {
    static let shared = PopupPanelController()

    /// Supplies the menubar button so the first show can sit under the ⌘ icon.
    var statusButtonProvider: (() -> NSStatusBarButton?)?

    private var panel: KeybindPanel?
    private var hostingController: NSHostingController<PopupView>?
    private var moveObserver: NSObjectProtocol?
    private var outsideClickMonitor: Any?
    private var localOutsideClickMonitor: Any?
    /// After the user drags the pinned overlay, keep that origin for the session.
    private var hasCustomPosition = false
    /// Ignore outside clicks briefly after show so the opening click cannot dismiss.
    private var ignoreOutsideClicksUntil: Date?
    private var moveStartOrigin: NSPoint?

    var isVisible: Bool { panel?.isVisible == true }

    private init() {}

    /// Shows the overlay when hidden, hides it when visible.
    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    /// Builds the panel if needed, applies settings, and orders it front.
    func show() {
        let panel = ensurePanel()
        applyAppearance()
        syncContentSize()
        positionIfNeeded()
        panel.orderFrontRegardless()
        ignoreOutsideClicksUntil = Date().addingTimeInterval(0.35)
        // Unpinned overlay becomes key so Escape can dismiss it.
        if !SettingsStore.shared.alwaysOnTop {
            panel.makeKeyAndOrderFront(nil)
        }
    }

    /// Hides the overlay without tearing down the panel (next show is cheaper).
    func hide() {
        panel?.orderOut(nil)
        removeOutsideClickMonitor()
    }

    /// Applies opacity-friendly chrome and the always-on-top window level.
    ///
    /// Called from Settings / the pin button whenever {@link SettingsStore.alwaysOnTop} changes.
    func applyAppearance() {
        guard let panel else { return }
        let settings = SettingsStore.shared
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        // Background dragging stole edge hits; the chrome bar moves the panel instead.
        panel.isMovableByWindowBackground = false

        // Never use hidesOnDeactivate: a menubar click would hide then toggle-show the overlay.
        panel.hidesOnDeactivate = false

        // Stay at `.floating` so Settings and NSMenu stay above the overlay.
        panel.level = .floating
        if settings.alwaysOnTop {
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            removeOutsideClickMonitor()
        } else {
            panel.collectionBehavior = [.transient, .fullScreenAuxiliary]
            installOutsideClickMonitor()
        }

        // Re-front after a live pin so the overlay actually rises above the focused app.
        if panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    /// Resizes the panel to match {@link SettingsStore} width / height without moving it.
    func syncContentSize() {
        guard let panel else { return }
        let settings = SettingsStore.shared
        let size = NSSize(width: settings.windowWidth, height: settings.windowHeight)
        var frame = panel.frame
        // Keep the top edge fixed when Settings steppers change the size.
        frame.origin.y += frame.height - size.height
        frame.size = size
        panel.setFrame(frame, display: true, animate: false)
    }

    /// Resizes the panel while anchoring the opposite edge of the dragged {@link ResizeEdge}.
    ///
    /// - Parameters:
    ///   - size: Proposed content size (already clamped by {@link SettingsStore}).
    ///   - edge: Border or corner the user is dragging.
    func resize(to size: NSSize, edge: ResizeEdge) {
        guard let panel else { return }
        var frame = panel.frame
        let old = frame
        frame.size = size

        // AppKit origin is bottom-left; keep the un-grabbed edges under the cursor.
        if edge.anchorsTrailing {
            frame.origin.x = old.maxX - size.width
        }
        if edge.anchorsTop {
            frame.origin.y = old.maxY - size.height
        }

        if let screen = panel.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            frame.origin.x = min(max(frame.origin.x, visible.minX), visible.maxX - frame.width)
            frame.origin.y = min(max(frame.origin.y, visible.minY), visible.maxY - frame.height)
        }

        panel.setFrame(frame, display: true, animate: false)
        hasCustomPosition = true
    }

    /// Recreates hosting content after a profile switch so Observation updates paint immediately.
    func refreshContent() {
        hostingController?.rootView = PopupView()
    }

    /// Starts a chrome-bar drag so later {@link PopupPanelController.moveToDrag} translations are absolute.
    func beginMove() {
        if moveStartOrigin == nil {
            moveStartOrigin = panel?.frame.origin
        }
    }

    /// Moves the overlay by a SwiftUI drag translation (x right, y already converted to AppKit-up).
    ///
    /// - Parameter translation: Distance from the drag start, in points.
    func moveToDrag(translation: CGSize) {
        guard let panel else { return }
        let start = moveStartOrigin ?? panel.frame.origin
        var frame = panel.frame
        frame.origin = NSPoint(x: start.x + translation.width, y: start.y + translation.height)
        if let screen = panel.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            frame.origin.x = min(max(frame.origin.x, visible.minX), visible.maxX - frame.width)
            frame.origin.y = min(max(frame.origin.y, visible.minY), visible.maxY - frame.height)
        }
        panel.setFrameOrigin(frame.origin)
        hasCustomPosition = true
    }

    /// Ends a chrome-bar drag.
    func endMove() {
        moveStartOrigin = nil
    }

    /// Drops the overlay under pop-up menus for the duration of `work` so submenu clicks hit the menu.
    ///
    /// - Parameter work: Synchronous block that presents an `NSMenu` (e.g. `popUp`).
    func withMenusAbove(_ work: () -> Void) {
        panel?.level = .normal
        work()
        applyAppearance()
    }

    /// Creates the borderless panel and installs {@link PopupView} once.
    private func ensurePanel() -> KeybindPanel {
        if let panel {
            return panel
        }

        let settings = SettingsStore.shared
        let panel = KeybindPanel(
            contentRect: NSRect(x: 0, y: 0, width: settings.windowWidth, height: settings.windowHeight),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.title = "Keybinds"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.identifier = NSUserInterfaceItemIdentifier("key.popup-panel")
        panel.animationBehavior = .utilityWindow

        let hosting = NSHostingController(rootView: PopupView())
        hosting.view.wantsLayer = true
        hosting.view.layer?.isOpaque = false
        hosting.view.layer?.cornerRadius = 10
        hosting.view.layer?.masksToBounds = true
        hosting.view.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentViewController = hosting

        self.panel = panel
        self.hostingController = hosting
        observeMoves(panel)
        applyAppearance()
        return panel
    }

    /// Places the overlay under the menubar icon unless the user already dragged it.
    private func positionIfNeeded() {
        guard !hasCustomPosition, let panel else { return }

        if let button = statusButtonProvider?(), let buttonWindow = button.window {
            let buttonInWindow = button.convert(button.bounds, to: nil)
            let buttonOnScreen = buttonWindow.convertToScreen(buttonInWindow)
            let screenFrame = (buttonWindow.screen ?? NSScreen.main)?.visibleFrame ?? panel.frame

            var origin = NSPoint(
                x: buttonOnScreen.midX - panel.frame.width / 2,
                y: buttonOnScreen.minY - panel.frame.height - 6
            )
            // Clamp so a wide overlay does not slide off the current display.
            origin.x = min(max(origin.x, screenFrame.minX + 8), screenFrame.maxX - panel.frame.width - 8)
            if origin.y < screenFrame.minY + 8 {
                origin.y = screenFrame.minY + 8
            }
            panel.setFrameOrigin(origin)
            return
        }

        panel.center()
    }

    /// Dismisses an unpinned overlay when the user clicks outside it (but not the ⌘ item).
    ///
    /// Status-item clicks are ignored so {@link AppDelegate} can toggle without a hide/show race.
    /// Global + local monitors are both required: other apps only show up globally.
    private func installOutsideClickMonitor() {
        if outsideClickMonitor == nil {
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.hideIfClickIsOutside()
            }
        }
        if localOutsideClickMonitor == nil {
            localOutsideClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                self?.hideIfClickIsOutside()
                return event
            }
        }
    }

    /// Removes the click-outside monitors used for unpinned overlays.
    private func removeOutsideClickMonitor() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
        if let localOutsideClickMonitor {
            NSEvent.removeMonitor(localOutsideClickMonitor)
            self.localOutsideClickMonitor = nil
        }
    }

    /// Hides when the pointer is not over the overlay and not over the menubar button.
    private func hideIfClickIsOutside() {
        if let until = ignoreOutsideClicksUntil, Date() < until {
            return
        }
        guard !SettingsStore.shared.alwaysOnTop, isVisible, let panel else { return }

        let location = NSEvent.mouseLocation
        if panel.frame.contains(location) {
            return
        }

        if let button = statusButtonProvider?(), let buttonWindow = button.window {
            let buttonInWindow = button.convert(button.bounds, to: nil)
            let buttonOnScreen = buttonWindow.convertToScreen(buttonInWindow)
            if buttonOnScreen.contains(location) {
                return
            }
        }

        hide()
    }

    /// Marks the session position as user-owned after a background drag.
    private func observeMoves(_ panel: KeybindPanel) {
        if let moveObserver {
            NotificationCenter.default.removeObserver(moveObserver)
        }
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.hasCustomPosition = true
        }
    }
}

/// Non-activating panel that can still become key for Escape-to-dismiss.
///
/// Hosted exclusively by {@link PopupPanelController}; not used for Settings.
///
/// @example
/// ```swift
/// let panel = KeybindPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
/// panel.canBecomeKey // true
/// ```
final class KeybindPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Escape hides an unpinned overlay; pinned overlays stay until the hotkey / icon toggle.
    override func cancelOperation(_ sender: Any?) {
        if SettingsStore.shared.alwaysOnTop {
            return
        }
        PopupPanelController.shared.hide()
    }
}
