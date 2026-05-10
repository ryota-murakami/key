import Foundation
import AppKit
import Carbon

/// Configurable global shortcut settings, loaded from `~/.config/key/settings.json`.
///
/// Uses the same modifier symbol notation as the keybind cheat sheet:
/// ⌘=command, ⇧=shift, ⌃=control, ⌥=option.
///
/// @example
/// ```json
/// { "globalShortcut": "⌘⇧K" }
/// ```
struct ShortcutConfig: Codable {
    var globalShortcut: String
    var fontSize: CGFloat?
    var windowWidth: CGFloat?
    var windowHeight: CGFloat?

    static let defaultShortcut = "⌘⇧K"

    /// Loads shortcut configuration from `~/.config/key/settings.json` or returns defaults.
    ///
    /// @example
    /// ```swift
    /// let config = ShortcutConfig.load()
    /// print(config.globalShortcut) // "⌘⇧K"
    /// ```
    static func load() -> ShortcutConfig {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = "\(home)/.config/key/settings.json"

        if FileManager.default.fileExists(atPath: path),
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let config = try? JSONDecoder().decode(ShortcutConfig.self, from: data) {
            return config
        }
        return ShortcutConfig(globalShortcut: defaultShortcut)
    }

    /// Saves the current configuration to `~/.config/key/settings.json`.
    ///
    /// @example
    /// ```swift
    /// var config = ShortcutConfig.load()
    /// config.fontSize = 18
    /// config.save()
    /// ```
    func save() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let dir = "\(home)/.config/key"
        let path = "\(dir)/settings.json"

        let fm = FileManager.default
        if !fm.fileExists(atPath: dir) {
            try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(self) {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }

    /// Parses the shortcut string into Carbon key code and modifier mask.
    ///
    /// @example
    /// ```swift
    /// let config = ShortcutConfig(globalShortcut: "⌘⇧K")
    /// let (keyCode, modifiers) = config.carbonValues()!
    /// // keyCode == kVK_ANSI_K, modifiers == cmdKey | shiftKey
    /// ```
    func carbonValues() -> (keyCode: UInt32, modifiers: UInt32)? {
        ShortcutParser.parse(globalShortcut)
    }
}

/// Parses macOS shortcut notation (e.g., "⌘⇧K") into Carbon virtual key codes and modifiers.
///
/// @example
/// ```swift
/// let result = ShortcutParser.parse("⌘⇧K")
/// // result == (keyCode: 0x28, modifiers: 0x0300)
/// ```
enum ShortcutParser {
    /// Parses a shortcut string containing modifier symbols and a key token.
    ///
    /// - Parameter shortcut: Saved shortcut notation, such as `⌥⇧.` or `⌘Space`.
    /// - Returns: Carbon key code and modifier mask, or `nil` when the token is invalid.
    static func parse(_ shortcut: String) -> (keyCode: UInt32, modifiers: UInt32)? {
        var modifiers: UInt32 = 0
        var keyToken = ""

        for char in shortcut {
            switch char {
            case "⌘": modifiers |= UInt32(cmdKey)
            case "⇧": modifiers |= UInt32(shiftKey)
            case "⌃": modifiers |= UInt32(controlKey)
            case "⌥": modifiers |= UInt32(optionKey)
            default: keyToken.append(char)
            }
        }

        guard let keyCode = ShortcutKeyCatalog.carbonKeyCode(for: keyToken) else {
            return nil
        }
        return (keyCode, modifiers)
    }
}

/// Shared key-code catalog for parsing and displaying global shortcuts.
///
/// The recorder saves friendly tokens (`.`, `Space`, `F12`, `←`) while Carbon
/// still receives the physical virtual key code it needs for registration.
///
/// @example
/// ```swift
/// ShortcutKeyCatalog.carbonKeyCode(for: ".") == UInt32(kVK_ANSI_Period)
/// ShortcutKeyCatalog.displaySymbol(for: UInt16(kVK_ANSI_Period)) == "."
/// ```
enum ShortcutKeyCatalog {
    /// Converts a saved key token into a Carbon virtual key code.
    ///
    /// - Parameter token: Key token after modifier symbols are removed.
    /// - Returns: Carbon virtual key code, including fallback `KeyCode123` tokens.
    static func carbonKeyCode(for token: String) -> UInt32? {
        let normalized = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        if let directMatch = carbonKeyCodes[normalized] {
            return directMatch
        }

        // Manual JSON edits are easier when common aliases also parse.
        if let alias = keyAliases[normalized], let aliasMatch = carbonKeyCodes[alias] {
            return aliasMatch
        }

        let uppercased = normalized.uppercased()
        if let uppercasedMatch = carbonKeyCodes[uppercased] {
            return uppercasedMatch
        }
        if let alias = keyAliases[uppercased], let aliasMatch = carbonKeyCodes[alias] {
            return aliasMatch
        }

        return fallbackKeyCode(for: normalized)
    }

    /// Converts a physical key code into the display token saved in settings.
    ///
    /// - Parameter keyCode: Physical key code reported by `NSEvent`.
    /// - Returns: Friendly token, or a stable fallback token for unknown keys.
    static func displaySymbol(for keyCode: UInt16) -> String {
        displaySymbols[keyCode] ?? "\(fallbackPrefix)\(keyCode)"
    }

    /// Parses fallback tokens for key codes not covered by the named catalog.
    ///
    /// - Parameter token: Saved token in the `KeyCode123` format.
    /// - Returns: Raw Carbon key code, or `nil` when the token is not a fallback.
    private static func fallbackKeyCode(for token: String) -> UInt32? {
        guard token.hasPrefix(fallbackPrefix) else { return nil }

        let suffix = token.dropFirst(fallbackPrefix.count)
        guard let keyCode = UInt32(suffix), keyCode <= UInt32(UInt16.max) else {
            return nil
        }
        return keyCode
    }

    private static let fallbackPrefix = "KeyCode"

    private static let displaySymbols: [UInt16: String] = Dictionary(
        uniqueKeysWithValues: keyDefinitions.map { ($0.keyCode, $0.symbol) }
    )

    private static let carbonKeyCodes: [String: UInt32] = Dictionary(
        uniqueKeysWithValues: keyDefinitions.map { ($0.symbol, UInt32($0.keyCode)) }
    )

    private static let keyAliases: [String: String] = [
        "RETURN": "↩",
        "ENTER": "↩",
        "TAB": "⇥",
        "SPACE": "Space",
        "DELETE": "⌫",
        "BACKSPACE": "⌫",
        "FORWARDDELETE": "⌦",
        "ESCAPE": "Esc",
        "LEFT": "←",
        "RIGHT": "→",
        "DOWN": "↓",
        "UP": "↑",
        "PAGEUP": "PageUp",
        "PAGEDOWN": "PageDown",
    ]

    private static let keyDefinitions: [(symbol: String, keyCode: UInt16)] = [
        ("A", UInt16(kVK_ANSI_A)), ("B", UInt16(kVK_ANSI_B)),
        ("C", UInt16(kVK_ANSI_C)), ("D", UInt16(kVK_ANSI_D)),
        ("E", UInt16(kVK_ANSI_E)), ("F", UInt16(kVK_ANSI_F)),
        ("G", UInt16(kVK_ANSI_G)), ("H", UInt16(kVK_ANSI_H)),
        ("I", UInt16(kVK_ANSI_I)), ("J", UInt16(kVK_ANSI_J)),
        ("K", UInt16(kVK_ANSI_K)), ("L", UInt16(kVK_ANSI_L)),
        ("M", UInt16(kVK_ANSI_M)), ("N", UInt16(kVK_ANSI_N)),
        ("O", UInt16(kVK_ANSI_O)), ("P", UInt16(kVK_ANSI_P)),
        ("Q", UInt16(kVK_ANSI_Q)), ("R", UInt16(kVK_ANSI_R)),
        ("S", UInt16(kVK_ANSI_S)), ("T", UInt16(kVK_ANSI_T)),
        ("U", UInt16(kVK_ANSI_U)), ("V", UInt16(kVK_ANSI_V)),
        ("W", UInt16(kVK_ANSI_W)), ("X", UInt16(kVK_ANSI_X)),
        ("Y", UInt16(kVK_ANSI_Y)), ("Z", UInt16(kVK_ANSI_Z)),
        ("0", UInt16(kVK_ANSI_0)), ("1", UInt16(kVK_ANSI_1)),
        ("2", UInt16(kVK_ANSI_2)), ("3", UInt16(kVK_ANSI_3)),
        ("4", UInt16(kVK_ANSI_4)), ("5", UInt16(kVK_ANSI_5)),
        ("6", UInt16(kVK_ANSI_6)), ("7", UInt16(kVK_ANSI_7)),
        ("8", UInt16(kVK_ANSI_8)), ("9", UInt16(kVK_ANSI_9)),
        ("=", UInt16(kVK_ANSI_Equal)), ("-", UInt16(kVK_ANSI_Minus)),
        ("]", UInt16(kVK_ANSI_RightBracket)), ("[", UInt16(kVK_ANSI_LeftBracket)),
        ("'", UInt16(kVK_ANSI_Quote)), (";", UInt16(kVK_ANSI_Semicolon)),
        ("\\", UInt16(kVK_ANSI_Backslash)), (",", UInt16(kVK_ANSI_Comma)),
        ("/", UInt16(kVK_ANSI_Slash)), (".", UInt16(kVK_ANSI_Period)),
        ("`", UInt16(kVK_ANSI_Grave)),
        ("↩", UInt16(kVK_Return)), ("⇥", UInt16(kVK_Tab)),
        ("Space", UInt16(kVK_Space)), ("⌫", UInt16(kVK_Delete)),
        ("Esc", UInt16(kVK_Escape)), ("⌦", UInt16(kVK_ForwardDelete)),
        ("←", UInt16(kVK_LeftArrow)), ("→", UInt16(kVK_RightArrow)),
        ("↓", UInt16(kVK_DownArrow)), ("↑", UInt16(kVK_UpArrow)),
        ("Home", UInt16(kVK_Home)), ("End", UInt16(kVK_End)),
        ("PageUp", UInt16(kVK_PageUp)), ("PageDown", UInt16(kVK_PageDown)),
        ("Help", UInt16(kVK_Help)),
        ("Clear", UInt16(kVK_ANSI_KeypadClear)),
        ("Num.", UInt16(kVK_ANSI_KeypadDecimal)),
        ("Num*", UInt16(kVK_ANSI_KeypadMultiply)),
        ("Num+", UInt16(kVK_ANSI_KeypadPlus)),
        ("Num/", UInt16(kVK_ANSI_KeypadDivide)),
        ("Num↩", UInt16(kVK_ANSI_KeypadEnter)),
        ("Num-", UInt16(kVK_ANSI_KeypadMinus)),
        ("Num=", UInt16(kVK_ANSI_KeypadEquals)),
        ("Num0", UInt16(kVK_ANSI_Keypad0)),
        ("Num1", UInt16(kVK_ANSI_Keypad1)),
        ("Num2", UInt16(kVK_ANSI_Keypad2)),
        ("Num3", UInt16(kVK_ANSI_Keypad3)),
        ("Num4", UInt16(kVK_ANSI_Keypad4)),
        ("Num5", UInt16(kVK_ANSI_Keypad5)),
        ("Num6", UInt16(kVK_ANSI_Keypad6)),
        ("Num7", UInt16(kVK_ANSI_Keypad7)),
        ("Num8", UInt16(kVK_ANSI_Keypad8)),
        ("Num9", UInt16(kVK_ANSI_Keypad9)),
        ("F1", UInt16(kVK_F1)), ("F2", UInt16(kVK_F2)),
        ("F3", UInt16(kVK_F3)), ("F4", UInt16(kVK_F4)),
        ("F5", UInt16(kVK_F5)), ("F6", UInt16(kVK_F6)),
        ("F7", UInt16(kVK_F7)), ("F8", UInt16(kVK_F8)),
        ("F9", UInt16(kVK_F9)), ("F10", UInt16(kVK_F10)),
        ("F11", UInt16(kVK_F11)), ("F12", UInt16(kVK_F12)),
        ("F13", UInt16(kVK_F13)), ("F14", UInt16(kVK_F14)),
        ("F15", UInt16(kVK_F15)), ("F16", UInt16(kVK_F16)),
        ("F17", UInt16(kVK_F17)), ("F18", UInt16(kVK_F18)),
        ("F19", UInt16(kVK_F19)), ("F20", UInt16(kVK_F20)),
        ("§", UInt16(kVK_ISO_Section)),
        ("¥", UInt16(kVK_JIS_Yen)),
        ("_", UInt16(kVK_JIS_Underscore)),
        ("Num,", UInt16(kVK_JIS_KeypadComma)),
        ("英数", UInt16(kVK_JIS_Eisu)),
        ("かな", UInt16(kVK_JIS_Kana)),
    ]
}

/// Formats AppKit key events into the shortcut string stored in settings JSON.
///
/// This keeps the Settings UI and Carbon registration path using the same
/// human-readable notation (`⌘⇧K`) so the saved file remains easy to edit.
///
/// @example
/// ```swift
/// let shortcut = ShortcutFormatter.format(
///     keyCode: UInt16(kVK_ANSI_K),
///     modifierFlags: [.command, .shift]
/// )
/// print(shortcut!) // "⌘⇧K"
/// ```
enum ShortcutFormatter {
    /// Creates a shortcut string from an AppKit key code and modifier flags.
    ///
    /// - Parameters:
    ///   - keyCode: The physical key code reported by `NSEvent`.
    ///   - modifierFlags: The modifier flags held while the key was pressed.
    /// - Returns: A shortcut like `⌘⇧K`, or `nil` for unsupported/no-trigger input.
    static func format(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) -> String? {
        let modifiers = modifierSymbols(from: modifierFlags)

        // Require a trigger modifier so normal typing and Shift-only typing stay untouched.
        guard hasTriggerModifier(in: modifierFlags), !modifiers.isEmpty else {
            return nil
        }

        let key = ShortcutKeyCatalog.displaySymbol(for: keyCode)
        return "\(modifiers)\(key)"
    }

    /// Checks whether modifiers include a safe trigger modifier for a global shortcut.
    ///
    /// - Parameter flags: The modifier flags currently held by the user.
    /// - Returns: `true` for Command, Control, or Option based shortcuts.
    static func hasTriggerModifier(in flags: NSEvent.ModifierFlags) -> Bool {
        let supportedFlags = flags.intersection(.deviceIndependentFlagsMask)
        return supportedFlags.contains(.command)
            || supportedFlags.contains(.control)
            || supportedFlags.contains(.option)
    }

    /// Returns only the modifier symbols for in-progress recording feedback.
    ///
    /// - Parameter flags: The modifier flags currently held by the user.
    /// - Returns: Symbols like `⌘⇧`, or an empty string when no supported modifier is held.
    /// @example
    /// ```swift
    /// ShortcutFormatter.modifierSymbols(from: [.command, .shift]) // "⌘⇧"
    /// ```
    static func modifierSymbols(from flags: NSEvent.ModifierFlags) -> String {
        let supportedFlags = flags.intersection(.deviceIndependentFlagsMask)
        var symbols = ""

        // Keep command first to match the existing default string: "⌘⇧K".
        if supportedFlags.contains(.command) { symbols += "⌘" }
        if supportedFlags.contains(.control) { symbols += "⌃" }
        if supportedFlags.contains(.option) { symbols += "⌥" }
        if supportedFlags.contains(.shift) { symbols += "⇧" }

        return symbols
    }
}
