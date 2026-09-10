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
    /// After the user drags the pinned overlay, keep that origin for the session.
    private var hasCustomPosition = false

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
        // Unpinned overlay becomes key so Escape can dismiss it.
        if !SettingsStore.shared.alwaysOnTop {
            panel.makeKeyAndOrderFront(nil)
        }
    }

    /// Hides the overlay without tearing down the panel (next show is cheaper).
    func hide() {
        panel?.orderOut(nil)
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
        panel.isMovableByWindowBackground = true

        if settings.alwaysOnTop {
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)) + 1)
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        } else {
            panel.level = .statusBar
            panel.hidesOnDeactivate = true
            panel.collectionBehavior = [.transient, .fullScreenAuxiliary]
            hasCustomPosition = false
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

        panel.setFrame(frame, display: true, animate: false)
        hasCustomPosition = true
    }

    /// Recreates hosting content after a profile switch so Observation updates paint immediately.
    func refreshContent() {
        hostingController?.rootView = PopupView()
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
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.identifier = NSUserInterfaceItemIdentifier("key.popup-panel")
        panel.animationBehavior = .utilityWindow

        let hosting = NSHostingController(rootView: PopupView())
        hosting.view.wantsLayer = true
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
