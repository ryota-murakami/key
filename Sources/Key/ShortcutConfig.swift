import Foundation
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
    let globalShortcut: String

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
    /// Parses a shortcut string containing modifier symbols and a key character.
    static func parse(_ shortcut: String) -> (keyCode: UInt32, modifiers: UInt32)? {
        var modifiers: UInt32 = 0
        var keyCharacter: Character?

        for char in shortcut {
            switch char {
            case "⌘": modifiers |= UInt32(cmdKey)
            case "⇧": modifiers |= UInt32(shiftKey)
            case "⌃": modifiers |= UInt32(controlKey)
            case "⌥": modifiers |= UInt32(optionKey)
            default: keyCharacter = char
            }
        }

        guard let key = keyCharacter,
              let keyCode = carbonKeyCode(for: key) else {
            return nil
        }
        return (keyCode, modifiers)
    }

    /// Maps a character to its Carbon virtual key code (kVK_ANSI_*).
    private static func carbonKeyCode(for character: Character) -> UInt32? {
        let upper = Character(String(character).uppercased())
        return keyCodeMap[upper]
    }

    // swiftlint:disable comma
    private static let keyCodeMap: [Character: UInt32] = [
        "A": UInt32(kVK_ANSI_A), "B": UInt32(kVK_ANSI_B),
        "C": UInt32(kVK_ANSI_C), "D": UInt32(kVK_ANSI_D),
        "E": UInt32(kVK_ANSI_E), "F": UInt32(kVK_ANSI_F),
        "G": UInt32(kVK_ANSI_G), "H": UInt32(kVK_ANSI_H),
        "I": UInt32(kVK_ANSI_I), "J": UInt32(kVK_ANSI_J),
        "K": UInt32(kVK_ANSI_K), "L": UInt32(kVK_ANSI_L),
        "M": UInt32(kVK_ANSI_M), "N": UInt32(kVK_ANSI_N),
        "O": UInt32(kVK_ANSI_O), "P": UInt32(kVK_ANSI_P),
        "Q": UInt32(kVK_ANSI_Q), "R": UInt32(kVK_ANSI_R),
        "S": UInt32(kVK_ANSI_S), "T": UInt32(kVK_ANSI_T),
        "U": UInt32(kVK_ANSI_U), "V": UInt32(kVK_ANSI_V),
        "W": UInt32(kVK_ANSI_W), "X": UInt32(kVK_ANSI_X),
        "Y": UInt32(kVK_ANSI_Y), "Z": UInt32(kVK_ANSI_Z),
        "0": UInt32(kVK_ANSI_0), "1": UInt32(kVK_ANSI_1),
        "2": UInt32(kVK_ANSI_2), "3": UInt32(kVK_ANSI_3),
        "4": UInt32(kVK_ANSI_4), "5": UInt32(kVK_ANSI_5),
        "6": UInt32(kVK_ANSI_6), "7": UInt32(kVK_ANSI_7),
        "8": UInt32(kVK_ANSI_8), "9": UInt32(kVK_ANSI_9),
    ]
    // swiftlint:enable comma
}
