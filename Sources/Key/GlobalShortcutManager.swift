import Carbon
import AppKit

/// Manages a system-wide global keyboard shortcut using Carbon Hot Key APIs.
///
/// Carbon's `RegisterEventHotKey` is the standard macOS approach for global hotkeys
/// that work even when other applications have focus.
///
/// @example
/// ```swift
/// let manager = GlobalShortcutManager()
/// manager.register(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(cmdKey | shiftKey)) {
///     print("Global shortcut triggered!")
/// }
/// ```
final class GlobalShortcutManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private(set) var callback: (() -> Void)?

    /// Registers a global hotkey with the given Carbon key code and modifier mask.
    ///
    /// @example
    /// ```swift
    /// // Register ⌘⇧K
    /// manager.register(
    ///     keyCode: UInt32(kVK_ANSI_K),
    ///     modifiers: UInt32(cmdKey | shiftKey)
    /// ) { togglePopup() }
    /// ```
    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        self.callback = handler
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        var eventType = EventTypeSpec(
            eventClass: UInt32(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            globalShortcutEventHandler,
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )

        guard installStatus == noErr else {
            print("[Key] Failed to install event handler: \(installStatus)")
            return
        }

        let hotKeyID = EventHotKeyID(signature: 0x4B455959, id: 1) // 'KEYY'
        let regStatus = RegisterEventHotKey(
            keyCode, modifiers, hotKeyID,
            GetApplicationEventTarget(), 0, &hotKeyRef
        )

        if regStatus != noErr {
            print("[Key] Failed to register hotkey: \(regStatus)")
        }
    }

    /// Called from the C callback when the registered hotkey is pressed.
    func handleHotKey() {
        callback?()
    }

    deinit {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        if let ref = eventHandlerRef { RemoveEventHandler(ref) }
    }
}

/// C-compatible callback for the Carbon event handler.
/// Uses `Unmanaged` pointer to recover the Swift `GlobalShortcutManager` instance.
private func globalShortcutEventHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData = userData else { return OSStatus(eventNotHandledErr) }
    let manager = Unmanaged<GlobalShortcutManager>.fromOpaque(userData).takeUnretainedValue()
    DispatchQueue.main.async { manager.handleHotKey() }
    return noErr
}
