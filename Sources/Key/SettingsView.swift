import SwiftUI

/// Settings panel for adjusting the global shortcut, font size, and window dimensions.
///
/// Changes apply immediately via `SettingsStore` bindings. The panel uses
/// a dark theme matching the main popup appearance.
///
/// @example
/// ```swift
/// let panel = NSPanel(contentViewController: NSHostingController(rootView: SettingsView()))
/// panel.makeKeyAndOrderFront(nil)
/// ```
struct SettingsView: View {
    @Bindable private var store = SettingsStore.shared
    @State private var shortcutStatusMessage: String?
    @State private var shortcutStatusIsError = false

    private let onGlobalShortcutChange: () -> Bool

    /// Creates a settings panel view.
    ///
    /// - Parameter onGlobalShortcutChange: Called after the global shortcut is saved.
    ///   Return `true` when the saved shortcut was registered successfully.
    /// @example
    /// ```swift
    /// SettingsView {
    ///     true
    /// }
    /// ```
    init(onGlobalShortcutChange: @escaping () -> Bool = { true }) {
        self.onGlobalShortcutChange = onGlobalShortcutChange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Settings")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white)

            shortcutRow()

            Divider()
                .background(Color(white: 0.3))

            settingsRow(label: "Font Size", value: $store.fontSize, range: 10...24, step: 1, unit: "pt")
            settingsRow(label: "Window Width", value: $store.windowWidth, range: 600...1400, step: 20, unit: "pt")
            settingsRow(label: "Window Height", value: $store.windowHeight, range: 400...1100, step: 50, unit: "pt")

            Divider()
                .background(Color(white: 0.3))

            HStack {
                Button("Reset Display") {
                    store.resetDisplayDefaults()
                }
                .buttonStyle(.bordered)
                .foregroundStyle(Color.white)

                Spacer()

                Button("Reset Shortcut") {
                    store.resetGlobalShortcut()
                }
                .buttonStyle(.bordered)
                .foregroundStyle(Color.white)
            }
        }
        .padding(20)
        .frame(width: 340)
        .background(Color(nsColor: NSColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)))
        .onChange(of: store.globalShortcut) { _, newShortcut in
            store.save()
            let didRegister = onGlobalShortcutChange()
            shortcutStatusMessage = didRegister ? "Saved \(newShortcut)" : "Saved, but shortcut unavailable"
            shortcutStatusIsError = !didRegister
        }
        .onChange(of: store.fontSize) { _, _ in store.save() }
        .onChange(of: store.windowWidth) { _, _ in store.save() }
        .onChange(of: store.windowHeight) { _, _ in store.save() }
    }

    /// A row that records and persists the app-wide popup shortcut.
    ///
    /// - Returns: A labeled shortcut recorder row with status feedback.
    @ViewBuilder
    private func shortcutRow() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Global Shortcut")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color(white: 0.75))
                    .frame(width: 120, alignment: .leading)

                Spacer()

                ShortcutRecorderField(
                    shortcut: $store.globalShortcut,
                    onShortcutCaptured: { shortcut in
                        shortcutStatusMessage = "Saved \(shortcut)"
                        shortcutStatusIsError = false
                    },
                    onInvalidShortcut: { message in
                        shortcutStatusMessage = message
                        shortcutStatusIsError = true
                    }
                )
                .frame(width: 160, height: 30)
            }

            // The compact status line confirms saves and explains rejected keypresses.
            if let shortcutStatusMessage {
                Text(shortcutStatusMessage)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(
                        shortcutStatusIsError
                            ? Color(red: 1.0, green: 0.45, blue: 0.45)
                            : Color(white: 0.65)
                    )
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    /// A labeled row with a stepper control and numeric display.
    ///
    /// - Parameters:
    ///   - label: Text shown on the left side of the row.
    ///   - value: Binding updated by the stepper.
    ///   - range: Minimum and maximum values accepted by the stepper.
    ///   - step: Amount to add or subtract per stepper click.
    ///   - unit: Suffix shown next to the numeric value.
    /// - Returns: A compact settings row.
    private func settingsRow(
        label: String,
        value: Binding<CGFloat>,
        range: ClosedRange<CGFloat>,
        step: CGFloat,
        unit: String
    ) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color(white: 0.75))
                .frame(width: 110, alignment: .leading)

            Spacer()

            Text("\(Int(value.wrappedValue))\(unit)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.white)
                .frame(width: 60, alignment: .trailing)

            Stepper("", value: value, in: range, step: step)
                .labelsHidden()
        }
    }
}
