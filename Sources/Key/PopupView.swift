import SwiftUI

/// Dark-themed popup window displaying keybind categories in a multi-column layout.
///
/// @example
/// Categories are distributed across columns to balance vertical space.
/// Each category shows a bold header followed by action–shortcut rows.
/// A modifier-key legend bar sits at the bottom.
struct PopupView: View {
    private let store = KeybindStore.shared
    private let settings = SettingsStore.shared

    var body: some View {
        VStack(spacing: 0) {
            // Category columns
            HStack(alignment: .top, spacing: 20) {
                ForEach(Array(store.columns.enumerated()), id: \.offset) { _, column in
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(column.enumerated()), id: \.offset) { _, category in
                            CategoryBlock(category: category, fontSize: settings.fontSize)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Spacer(minLength: 0)

            // Modifier key legend
            LegendBar(fontSize: settings.legendFontSize)
        }
        .frame(width: settings.windowWidth, height: settings.windowHeight)
        .background(Color(nsColor: NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)))
    }
}

/// A single category block: bold header + list of action–shortcut rows.
///
/// @example
/// ```
/// General
/// Copy                ⌘C
/// Paste               ⌘V
/// ```
private struct CategoryBlock: View {
    let category: KeybindCategory
    let fontSize: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(category.category)
                .font(.system(size: fontSize, design: .monospaced).bold())
                .foregroundStyle(Color.white)
                .padding(.bottom, 4)

            ForEach(Array(category.keybinds.enumerated()), id: \.offset) { _, keybind in
                KeybindRow(keybind: keybind, fontSize: fontSize)
            }
        }
    }
}

/// A single row showing action name (left) and shortcut (right).
///
/// @example
/// ```
/// Copy                ⌘C
/// ```
private struct KeybindRow: View {
    let keybind: Keybind
    let fontSize: CGFloat

    var body: some View {
        HStack(spacing: 6) {
            Text(keybind.action)
                .foregroundStyle(Color(white: 0.75))
            Spacer(minLength: 4)
            Text(keybind.shortcut)
                .foregroundStyle(Color(white: 0.55))
        }
        .font(.system(size: fontSize, design: .monospaced))
        .lineLimit(1)
    }
}

/// Bottom legend bar showing modifier key symbols and their names.
///
/// @example
/// ⌘=command  ⌃=control  ⌥=option  ⇧=shift  ⏎=return
private struct LegendBar: View {
    let fontSize: CGFloat

    private let legends = [
        ("⌘", "command"),
        ("⌃", "control"),
        ("⌥", "option"),
        ("⇧", "shift"),
        ("⏎", "return"),
    ]

    var body: some View {
        HStack(spacing: 16) {
            ForEach(legends, id: \.0) { symbol, name in
                Text("\(symbol)=\(name)")
            }
        }
        .font(.system(size: fontSize, design: .monospaced))
        .foregroundStyle(Color(white: 0.45))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(nsColor: NSColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1.0)))
    }
}
