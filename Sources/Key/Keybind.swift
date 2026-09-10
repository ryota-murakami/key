import Foundation

/// A single keybind mapping an action name to a keyboard shortcut.
///
/// @example
/// ```json
/// { "action": "Copy", "shortcut": "⌘C" }
/// ```
struct Keybind: Codable, Equatable, Hashable {
    let action: String
    let shortcut: String
}

/// A named category containing a list of keybinds.
///
/// @example
/// ```json
/// { "category": "Editing", "keybinds": [{ "action": "Copy", "shortcut": "⌘C" }] }
/// ```
struct KeybindCategory: Codable, Equatable, Hashable, Identifiable {
    let category: String
    let keybinds: [Keybind]

    var id: String { category }
}

/// Top-level container for the keybinds JSON file.
///
/// @example
/// ```json
/// { "categories": [{ "category": "Editing", "keybinds": [...] }] }
/// ```
struct KeybindData: Codable, Equatable {
    let categories: [KeybindCategory]
}
