import AppKit
import Carbon
import SwiftUI

/// SwiftUI bridge for a macOS shortcut recorder field.
///
/// The field looks like a read-only input, but it becomes first responder when
/// clicked and records the next modifier-plus-key combination the user presses.
///
/// @example
/// ```swift
/// ShortcutRecorderField(
///     shortcut: $store.globalShortcut,
///     onShortcutCaptured: { print("Saved \($0)") },
///     onInvalidShortcut: { print($0) }
/// )
/// ```
struct ShortcutRecorderField: NSViewRepresentable {
    @Binding var shortcut: String
    var onShortcutCaptured: (String) -> Void
    var onInvalidShortcut: (String) -> Void

    /// Creates the coordinator that writes AppKit callbacks back into SwiftUI.
    ///
    /// - Returns: A coordinator that owns the current binding and callbacks.
    func makeCoordinator() -> Coordinator {
        Coordinator(
            shortcut: $shortcut,
            onShortcutCaptured: onShortcutCaptured,
            onInvalidShortcut: onInvalidShortcut
        )
    }

    /// Creates the AppKit recorder view used by SwiftUI.
    ///
    /// - Parameter context: SwiftUI context containing the coordinator.
    /// - Returns: A configured shortcut recorder view.
    func makeNSView(context: Context) -> ShortcutRecorderFieldView {
        let view = ShortcutRecorderFieldView(shortcut: shortcut)
        view.onShortcutCaptured = context.coordinator.captureShortcut
        view.onInvalidShortcut = context.coordinator.rejectShortcut
        return view
    }

    /// Keeps the AppKit view synchronized with the latest SwiftUI state.
    ///
    /// - Parameters:
    ///   - nsView: The underlying AppKit shortcut recorder view.
    ///   - context: SwiftUI context containing the coordinator.
    func updateNSView(_ nsView: ShortcutRecorderFieldView, context: Context) {
        context.coordinator.shortcut = $shortcut
        context.coordinator.onShortcutCaptured = onShortcutCaptured
        context.coordinator.onInvalidShortcut = onInvalidShortcut

        // External changes, such as reset buttons, should update the visible field.
        nsView.shortcut = shortcut
    }

    /// Passes AppKit events back into the SwiftUI binding and status callbacks.
    final class Coordinator {
        var shortcut: Binding<String>
        var onShortcutCaptured: (String) -> Void
        var onInvalidShortcut: (String) -> Void

        /// Stores the binding and callback hooks for recorder events.
        ///
        /// - Parameters:
        ///   - shortcut: Binding to the saved shortcut string.
        ///   - onShortcutCaptured: Called after a valid shortcut is recorded.
        ///   - onInvalidShortcut: Called when the event cannot become a shortcut.
        init(
            shortcut: Binding<String>,
            onShortcutCaptured: @escaping (String) -> Void,
            onInvalidShortcut: @escaping (String) -> Void
        ) {
            self.shortcut = shortcut
            self.onShortcutCaptured = onShortcutCaptured
            self.onInvalidShortcut = onInvalidShortcut
        }

        /// Saves a valid shortcut into SwiftUI and notifies the parent view.
        ///
        /// - Parameter newShortcut: The formatted shortcut string, such as `⌘⇧K`.
        func captureShortcut(_ newShortcut: String) {
            shortcut.wrappedValue = newShortcut
            onShortcutCaptured(newShortcut)
        }

        /// Shows validation feedback from the AppKit view.
        ///
        /// - Parameter message: Human-readable reason the shortcut was rejected.
        func rejectShortcut(_ message: String) {
            onInvalidShortcut(message)
        }
    }
}

/// AppKit control that captures the next shortcut typed by the user.
///
/// This view avoids text editing entirely: it only records complete shortcuts,
/// then hands the formatted result back to SwiftUI.
///
/// @example
/// ```swift
/// let field = ShortcutRecorderFieldView(shortcut: "⌘⇧K")
/// field.onShortcutCaptured = { print($0) }
/// ```
final class ShortcutRecorderFieldView: NSView {
    var shortcut: String {
        didSet { updateLabel() }
    }

    var onShortcutCaptured: ((String) -> Void)?
    var onInvalidShortcut: ((String) -> Void)?

    private let label = NSTextField(labelWithString: "")
    private var isRecording = false {
        didSet {
            updateLabel()
            updateAppearance()
        }
    }

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 150, height: 30) }

    /// Initializes a recorder field with the current saved shortcut.
    ///
    /// - Parameter shortcut: The shortcut string currently stored in settings.
    init(shortcut: String) {
        self.shortcut = shortcut
        super.init(frame: .zero)
        configureView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    /// Places the label inside the custom field bounds.
    override func layout() {
        super.layout()
        label.frame = bounds.insetBy(dx: 10, dy: 5)
    }

    /// Starts recording when the user clicks the field.
    ///
    /// - Parameter event: Mouse event that selected the recorder field.
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    /// Updates visual state after the field receives keyboard focus.
    ///
    /// - Returns: `true` when the field became first responder.
    override func becomeFirstResponder() -> Bool {
        let didBecomeFirstResponder = super.becomeFirstResponder()

        // The highlighted field indicates that the next keypress will be captured.
        if didBecomeFirstResponder {
            isRecording = true
        }

        return didBecomeFirstResponder
    }

    /// Leaves recording mode when focus moves away.
    ///
    /// - Returns: `true` when the field resigned first responder.
    override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }

    /// Records the next supported modifier-plus-key shortcut.
    ///
    /// - Parameter event: Key event produced while the field is focused.
    override func keyDown(with event: NSEvent) {
        let hasTriggerModifier = ShortcutFormatter.hasTriggerModifier(in: event.modifierFlags)

        // Plain Escape cancels; modified Escape can be recorded as a shortcut.
        if event.keyCode == UInt16(kVK_Escape), !hasTriggerModifier {
            window?.makeFirstResponder(nil)
            return
        }

        // Plain Tab keeps keyboard navigation; modified Tab can be recorded.
        if event.keyCode == UInt16(kVK_Tab), !hasTriggerModifier {
            window?.selectNextKeyView(nil)
            return
        }

        guard let newShortcut = ShortcutFormatter.format(
            keyCode: event.keyCode,
            modifierFlags: event.modifierFlags
        ) else {
            onInvalidShortcut?("Use ⌘, ⌃, or ⌥ plus any key")
            NSSound.beep()
            return
        }

        shortcut = newShortcut
        onShortcutCaptured?(newShortcut)
        window?.makeFirstResponder(nil)
    }

    /// Shows held modifier keys while the user is building a shortcut.
    ///
    /// - Parameter event: Modifier-key state change from AppKit.
    override func flagsChanged(with event: NSEvent) {
        guard isRecording else {
            super.flagsChanged(with: event)
            return
        }

        let modifiers = ShortcutFormatter.modifierSymbols(from: event.modifierFlags)

        // Partial modifier feedback makes it clear the field is listening.
        label.stringValue = modifiers.isEmpty ? "Press shortcut" : "\(modifiers)..."
    }

    /// Configures the field's appearance and child label.
    private func configureView() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1

        label.alignment = .center
        label.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        label.lineBreakMode = .byTruncatingTail
        label.textColor = .white

        addSubview(label)
        updateLabel()
        updateAppearance()
    }

    /// Refreshes the text shown inside the recorder field.
    private func updateLabel() {
        label.stringValue = isRecording ? "Press shortcut" : shortcut
    }

    /// Refreshes border and background colors for focused/unfocused states.
    private func updateAppearance() {
        let backgroundColor = isRecording
            ? NSColor(red: 0.16, green: 0.18, blue: 0.20, alpha: 1.0)
            : NSColor(red: 0.10, green: 0.10, blue: 0.11, alpha: 1.0)
        let borderColor = isRecording
            ? NSColor.controlAccentColor
            : NSColor(red: 0.32, green: 0.32, blue: 0.34, alpha: 1.0)

        layer?.backgroundColor = backgroundColor.cgColor
        layer?.borderColor = borderColor.cgColor
    }
}
