import SwiftUI

/// Shared observable store for keybind data, supporting live reload.
///
/// Uses the Observation framework (`@Observable`) for automatic SwiftUI view updates.
/// Access via `KeybindStore.shared` singleton. Call `reload()` to re-read JSON from disk.
///
/// @example
/// ```swift
/// let store = KeybindStore.shared
/// store.reload() // re-reads ~/.config/key/keybinds.json
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

    /// Reloads keybind data from disk and recomputes column layout.
    ///
    /// @example
    /// ```swift
    /// KeybindStore.shared.reload()
    /// ```
    func reload() {
        let data = KeybindLoader.load()
        self.keybindData = data
        self.columns = Self.distributeColumns(data.categories, columnCount: 4)
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
