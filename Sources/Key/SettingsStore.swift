import SwiftUI

/// Reactive singleton that holds app settings (global shortcut, font size, window dimensions).
///
/// Reads from and writes to `~/.config/key/settings.json`, preserving other fields
/// when saving partial changes. SwiftUI views observe this store for live updates.
///
/// @example
/// ```swift
/// let store = SettingsStore.shared
/// store.fontSize = 18  // UI updates immediately
/// store.save()         // Persists to disk
/// ```
@Observable
final class SettingsStore {
    static let shared = SettingsStore()

    var globalShortcut: String = Defaults.globalShortcut
    var fontSize: CGFloat = Defaults.fontSize
    var windowWidth: CGFloat = Defaults.windowWidth
    var windowHeight: CGFloat = Defaults.windowHeight

    /// Legend font maintains a 4pt offset from main font (matching the 16/12 default ratio).
    var legendFontSize: CGFloat { max(fontSize - 4, 8) }

    /// Default values for display settings.
    enum Defaults {
        static let globalShortcut = ShortcutConfig.defaultShortcut
        static let fontSize: CGFloat = 16
        static let windowWidth: CGFloat = 860
        static let windowHeight: CGFloat = 850
    }

    private init() {
        load()
    }

    /// Loads app settings from `~/.config/key/settings.json`.
    /// Missing fields fall back to defaults.
    func load() {
        let config = ShortcutConfig.load()
        globalShortcut = config.globalShortcut
        fontSize = config.fontSize ?? Defaults.fontSize
        windowWidth = config.windowWidth ?? Defaults.windowWidth
        windowHeight = config.windowHeight ?? Defaults.windowHeight
    }

    /// Saves current app settings to `~/.config/key/settings.json`.
    ///
    /// @example
    /// ```swift
    /// SettingsStore.shared.globalShortcut = "⌘⌥K"
    /// SettingsStore.shared.save()
    /// ```
    func save() {
        var config = ShortcutConfig.load()
        config.globalShortcut = globalShortcut
        config.fontSize = fontSize
        config.windowWidth = windowWidth
        config.windowHeight = windowHeight
        config.save()
    }

    /// Resets font size and window dimensions to defaults and saves.
    ///
    /// @example
    /// ```swift
    /// SettingsStore.shared.resetDisplayDefaults()
    /// ```
    func resetDisplayDefaults() {
        fontSize = Defaults.fontSize
        windowWidth = Defaults.windowWidth
        windowHeight = Defaults.windowHeight
        save()
    }

    /// Resets the global shortcut to the built-in default and saves.
    ///
    /// @example
    /// ```swift
    /// SettingsStore.shared.resetGlobalShortcut()
    /// ```
    func resetGlobalShortcut() {
        globalShortcut = Defaults.globalShortcut
        save()
    }
}
