import SwiftUI

/// Settings panel for adjusting font size and window dimensions.
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white)

            settingsRow(label: "Font Size", value: $store.fontSize, range: 10...24, step: 1, unit: "pt")
            settingsRow(label: "Window Width", value: $store.windowWidth, range: 600...1400, step: 20, unit: "pt")
            settingsRow(label: "Window Height", value: $store.windowHeight, range: 400...1100, step: 50, unit: "pt")

            Divider()
                .background(Color(white: 0.3))

            Button("Reset to Defaults") {
                store.resetDisplayDefaults()
            }
            .buttonStyle(.bordered)
            .foregroundStyle(Color.white)
        }
        .padding(20)
        .frame(width: 300)
        .background(Color(nsColor: NSColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)))
        .onChange(of: store.fontSize) { _, _ in store.save() }
        .onChange(of: store.windowWidth) { _, _ in store.save() }
        .onChange(of: store.windowHeight) { _, _ in store.save() }
    }

    /// A labeled row with a stepper control and numeric display.
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
