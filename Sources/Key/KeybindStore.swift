import SwiftUI

/// Shared observable store for the active {@link KeybindProfile} table and column layout.
///
/// Uses the Observation framework (`@Observable`) for automatic SwiftUI view updates.
/// Access via {@link KeybindStore.shared}. Call {@link KeybindStore.select} to switch tables.
///
/// @example
/// ```swift
/// KeybindStore.shared.select(.vim)
/// KeybindStore.shared.reload()
/// ```
@Observable
final class KeybindStore {
    static let shared = KeybindStore()

    var keybindData: KeybindData
    var columns: [[KeybindCategory]]

    private init() {
        let data = KeybindLoader.load()
        self.keybindData = data
        self.columns = Self.distributeColumns(data.categories, columnCount: 4)
    }

    /// Reloads the currently selected profile from disk and recomputes columns.
    ///
    /// Triggered by the Reload menu item and after {@link KeybindStore.select}.
    ///
    /// @example
    /// ```swift
    /// KeybindStore.shared.reload()
    /// ```
    func reload() {
        let data = KeybindLoader.load(profile: SettingsStore.shared.selectedProfile)
        self.keybindData = data
        self.columns = Self.distributeColumns(data.categories, columnCount: 4)
        // Force the long-lived hosting controller to paint the new table.
        PopupPanelController.shared.refreshContent()
    }

    /// Persists `profile`, reloads its JSON, and refreshes the overlay columns.
    ///
    /// - Parameter profile: Table to show (Cursor / Emacs / Vim / GitHub).
    ///
    /// @example
    /// ```swift
    /// KeybindStore.shared.select(.github)
    /// ```
    func select(_ profile: KeybindProfile) {
        SettingsStore.shared.selectedProfile = profile
        SettingsStore.shared.save()
        reload()
    }

    /// Distributes categories across N columns, balancing by total row count.
    ///
    /// Uses greedy bin-packing with ~15% overflow tolerance per column.
    ///
    /// @example
    /// Given 16 categories with varying keybind counts, this produces
    /// 4 columns with roughly equal total heights.
    static func distributeColumns(_ categories: [KeybindCategory], columnCount: Int) -> [[KeybindCategory]] {
        let totalRows = categories.reduce(0) { $0 + 1 + $1.keybinds.count }
        let targetPerColumn = Double(totalRows) / Double(columnCount)

        var result: [[KeybindCategory]] = []
        var current: [KeybindCategory] = []
        var currentRows = 0

        for category in categories {
            let categoryRows = 1 + category.keybinds.count
            // Start a new column when this category would overflow the target and a later column remains.
            if currentRows > 0
                && Double(currentRows + categoryRows) > targetPerColumn * 1.15
                && result.count < columnCount - 1 {
                result.append(current)
                current = []
                currentRows = 0
            }
            current.append(category)
            currentRows += categoryRows
        }
        if !current.isEmpty {
            result.append(current)
        }

        return result
    }
}
