import Foundation

/// Named keybind table the overlay can switch between (Cursor defaults plus bundled Emacs / Vim / GitHub).
///
/// Persisted in {@link ShortcutConfig.selectedProfile} and applied by {@link KeybindStore.select}.
///
/// @example
/// ```swift
/// KeybindProfile.emacs.displayName // "Emacs"
/// KeybindProfile.github.userFileName // "github-keybinds.json"
/// ```
enum KeybindProfile: String, CaseIterable, Codable, Identifiable {
    case cursor
    case emacs
    case vim
    case github

    var id: String { rawValue }

    /// Tab and menu label shown in the overlay and context menu.
    var displayName: String {
        switch self {
        case .cursor: return "Cursor"
        case .emacs: return "Emacs"
        case .vim: return "Vim"
        case .github: return "GitHub"
        }
    }

    /// Bundled resource name (without `.json`) loaded when no user override exists.
    var bundledResourceName: String {
        switch self {
        case .cursor: return "default-keybinds"
        case .emacs: return "emacs-keybinds"
        case .vim: return "vim-keybinds"
        case .github: return "github-keybinds"
        }
    }

    /// Filename under `~/.config/key/` — Cursor keeps the original `keybinds.json` path.
    var userFileName: String {
        switch self {
        case .cursor: return "keybinds.json"
        case .emacs: return "emacs-keybinds.json"
        case .vim: return "vim-keybinds.json"
        case .github: return "github-keybinds.json"
        }
    }
}
