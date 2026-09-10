import SwiftUI

/// Reactive singleton that holds app settings (shortcut, display, overlay chrome).
///
/// Reads from and writes to `~/.config/key/settings.json`, preserving other fields
/// when saving partial changes. SwiftUI views observe this store for live updates.
///
/// @example
/// ```swift
/// let store = SettingsStore.shared
/// store.backgroundOpacity = 0.7
/// store.alwaysOnTop = true
/// store.save()
/// ```
@Observable
final class SettingsStore {
    static let shared = SettingsStore()

    var globalShortcut: String = Defaults.globalShortcut
    var fontSize: CGFloat = Defaults.fontSize
    var windowWidth: CGFloat = Defaults.windowWidth
    var windowHeight: CGFloat = Defaults.windowHeight
    var backgroundOpacity: Double = Defaults.backgroundOpacity
    var alwaysOnTop: Bool = Defaults.alwaysOnTop
    var selectedProfile: KeybindProfile = Defaults.selectedProfile

    /// Legend font maintains a 4pt offset from main font (matching the 16/12 default ratio).
    var legendFontSize: CGFloat { max(fontSize - 4, 8) }

    /// Integer percent binding used by the Settings stepper (10...100).
    var backgroundOpacityPercent: CGFloat {
        get { CGFloat((backgroundOpacity * 100).rounded()) }
        set { backgroundOpacity = Self.clampOpacity(Double(newValue) / 100) }
    }

    /// Default values for display and overlay settings.
    enum Defaults {
        static let globalShortcut = ShortcutConfig.defaultShortcut
        static let fontSize: CGFloat = 16
        static let windowWidth: CGFloat = 860
        static let windowHeight: CGFloat = 850
        static let backgroundOpacity: Double = 1.0
        static let alwaysOnTop = false
        static let selectedProfile: KeybindProfile = .cursor
        static let windowWidthRange: ClosedRange<CGFloat> = 600...1600
        static let windowHeightRange: ClosedRange<CGFloat> = 400...1200
        static let opacityRange: ClosedRange<Double> = 0.10...1.0
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
        windowWidth = clampWidth(config.windowWidth ?? Defaults.windowWidth)
        windowHeight = clampHeight(config.windowHeight ?? Defaults.windowHeight)
        backgroundOpacity = Self.clampOpacity(config.backgroundOpacity ?? Defaults.backgroundOpacity)
        alwaysOnTop = config.alwaysOnTop ?? Defaults.alwaysOnTop
        selectedProfile = config.selectedProfile ?? Defaults.selectedProfile
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
        config.backgroundOpacity = backgroundOpacity
        config.alwaysOnTop = alwaysOnTop
        config.selectedProfile = selectedProfile
        config.save()
    }

    /// Resets font size, window size, and background opacity to defaults and saves.
    ///
    /// Leaves {@link SettingsStore.alwaysOnTop} and {@link SettingsStore.selectedProfile} unchanged.
    ///
    /// @example
    /// ```swift
    /// SettingsStore.shared.resetDisplayDefaults()
    /// ```
    func resetDisplayDefaults() {
        fontSize = Defaults.fontSize
        windowWidth = Defaults.windowWidth
        windowHeight = Defaults.windowHeight
        backgroundOpacity = Defaults.backgroundOpacity
        save()
        PopupPanelController.shared.syncContentSize()
    }

    /// Clamps a proposed overlay width to {@link SettingsStore.Defaults.windowWidthRange}.
    func clampWidth(_ width: CGFloat) -> CGFloat {
        min(max(width.rounded(), Defaults.windowWidthRange.lowerBound), Defaults.windowWidthRange.upperBound)
    }

    /// Clamps a proposed overlay height to {@link SettingsStore.Defaults.windowHeightRange}.
    func clampHeight(_ height: CGFloat) -> CGFloat {
        min(max(height.rounded(), Defaults.windowHeightRange.lowerBound), Defaults.windowHeightRange.upperBound)
    }

    /// Clamps background opacity so the overlay never becomes fully invisible.
    static func clampOpacity(_ opacity: Double) -> Double {
        min(max(opacity, Defaults.opacityRange.lowerBound), Defaults.opacityRange.upperBound)
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
