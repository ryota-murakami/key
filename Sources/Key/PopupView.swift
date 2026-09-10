import SwiftUI

/// Dark-themed overlay that shows the active {@link KeybindProfile} in a multi-column layout.
///
/// Hosted by {@link PopupPanelController}. The chrome row switches tables and pins the
/// overlay; {@link ResizeBorderOverlay} lets the user drag the border to resize.
///
/// @example
/// Categories are distributed across columns to balance vertical space.
/// Each category shows a bold header followed by action–shortcut rows.
struct PopupView: View {
    private let store = KeybindStore.shared
    private let settings = SettingsStore.shared

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ProfileChromeBar()

                // Category columns — scroll only when the table is taller than the card.
                ScrollView {
                    HStack(alignment: .top, spacing: 20) {
                        ForEach(Array(store.columns.enumerated()), id: \.offset) { _, column in
                            VStack(alignment: .leading, spacing: 14) {
                                ForEach(column, id: \.category) { category in
                                    CategoryBlock(category: category, fontSize: settings.fontSize)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                    .id(settings.selectedProfile)
                }
                .scrollContentBackground(.hidden)
                .scrollIndicators(.never)

                Spacer(minLength: 0)

                LegendBar(fontSize: settings.legendFontSize, opacity: settings.backgroundOpacity)
            }

            ResizeBorderOverlay()
        }
        .frame(width: settings.windowWidth, height: settings.windowHeight)
        .background(overlayBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    /// Card fill uses {@link SettingsStore.backgroundOpacity} so only the background fades.
    private var overlayBackground: Color {
        Color(nsColor: NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: settings.backgroundOpacity))
    }
}

/// Top chrome: profile tabs plus the always-on-top pin used by {@link PopupView}.
///
/// Switching a tab calls {@link KeybindStore.select}; the pin writes {@link SettingsStore.alwaysOnTop}.
///
/// @example
/// ```swift
/// ProfileChromeBar()
/// ```
private struct ProfileChromeBar: View {
    private let keybinds = KeybindStore.shared
    @Bindable private var settings = SettingsStore.shared

    var body: some View {
        HStack(spacing: 6) {
            ForEach(KeybindProfile.allCases) { profile in
                profileTab(profile)
            }

            Spacer(minLength: 8)

            Color.clear
                .frame(minWidth: 24, minHeight: 22)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { value in
                            PopupPanelController.shared.beginMove()
                            PopupPanelController.shared.moveToDrag(
                                translation: CGSize(
                                    width: value.translation.width,
                                    height: -value.translation.height
                                )
                            )
                        }
                        .onEnded { _ in
                            PopupPanelController.shared.endMove()
                        }
                )
                .help("Drag to move overlay")

            Button {
                settings.alwaysOnTop.toggle()
                settings.save()
                PopupPanelController.shared.applyAppearance()
            } label: {
                Image(systemName: settings.alwaysOnTop ? "pin.fill" : "pin")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(settings.alwaysOnTop ? Color.accentColor : Color(white: 0.55))
                    .frame(width: 32, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(settings.alwaysOnTop ? Color.white.opacity(0.10) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.white.opacity(settings.alwaysOnTop ? 0.28 : 0.12), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help(settings.alwaysOnTop ? "Unpin overlay" : "Keep overlay in front of other windows")
            .accessibilityLabel(settings.alwaysOnTop ? "Unpin overlay" : "Pin overlay on top")
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    /// One selectable table tab for `profile`.
    ///
    /// - Parameter profile: Cursor / Emacs / Vim / GitHub table to activate.
    private func profileTab(_ profile: KeybindProfile) -> some View {
        let selected = settings.selectedProfile == profile
        return Button {
            keybinds.select(profile)
        } label: {
            Text(profile.displayName)
                .font(.system(size: 11, weight: selected ? .semibold : .regular, design: .monospaced))
                .foregroundStyle(selected ? Color.white : Color(white: 0.62))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selected ? Color.white.opacity(0.12) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.white.opacity(selected ? 0.32 : 0.10), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityLabel("\(profile.displayName) keybind table")
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
/// Background alpha follows {@link SettingsStore.backgroundOpacity} so the legend matches the card.
///
/// @example
/// ⌘=command  ⌃=control  ⌥=option  ⇧=shift  ⏎=return
private struct LegendBar: View {
    let fontSize: CGFloat
    let opacity: Double

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
        .background(Color(nsColor: NSColor(red: 0.10, green: 0.10, blue: 0.10, alpha: opacity)))
    }
}
