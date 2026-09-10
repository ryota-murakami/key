import AppKit
import SwiftUI

/// Edge and corner hit targets so the overlay border can be dragged to resize.
///
/// Only the chrome strips receive hits — the center stays click-through so
/// {@link ProfileChromeBar} tabs and the pin button keep working. Writes clamped
/// sizes into {@link SettingsStore} and asks {@link PopupPanelController} to
/// keep the opposite edge anchored.
///
/// @example
/// ```swift
/// ZStack {
///     content
///     ResizeBorderOverlay()
/// }
/// ```
struct ResizeBorderOverlay: View {
    @Bindable private var settings = SettingsStore.shared

    private let edgeThickness: CGFloat = 6
    private let cornerSize: CGFloat = 12

    @State private var dragStart = CGSize.zero
    @State private var activeEdge: ResizeEdge?

    var body: some View {
        // Spacer in the center is click-through so table tabs and the pin stay usable.
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                edgeStrip(edge: .top, cursor: .resizeUpDown)
                    .frame(height: edgeThickness)
                // Keep the pin button (top-trailing chrome) free of resize hits.
                Color.clear
                    .frame(width: 40, height: edgeThickness)
                    .allowsHitTesting(false)
            }

            HStack(spacing: 0) {
                edgeStrip(edge: .leading, cursor: .resizeLeftRight)
                    .frame(width: edgeThickness)
                Spacer(minLength: 0)
                    .allowsHitTesting(false)
                VStack(spacing: 0) {
                    Color.clear
                        .frame(width: edgeThickness, height: 36)
                        .allowsHitTesting(false)
                    edgeStrip(edge: .trailing, cursor: .resizeLeftRight)
                        .frame(width: edgeThickness)
                }
            }

            edgeStrip(edge: .bottom, cursor: .resizeUpDown)
                .frame(height: edgeThickness)
        }
        .overlay(alignment: .topLeading) { cornerHandle(.topLeading) }
        .overlay(alignment: .bottomLeading) { cornerHandle(.bottomLeading) }
        .overlay(alignment: .bottomTrailing) { cornerHandle(.bottomTrailing) }
    }

    /// Full-width or full-height edge strip that starts a {@link ResizeEdge} drag.
    ///
    /// - Parameters:
    ///   - edge: Top / bottom / leading / trailing edge being grabbed.
    ///   - cursor: Resize cursor shown while the pointer is over the strip.
    private func edgeStrip(edge: ResizeEdge, cursor: NSCursor) -> some View {
        ResizeHandleView(cursor: cursor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .gesture(dragGesture(edge: edge))
    }

    /// Square corner handle placed with alignment overlays so it wins over edge strips.
    ///
    /// - Parameter edge: Corner {@link ResizeEdge} to drive.
    private func cornerHandle(_ edge: ResizeEdge) -> some View {
        ResizeHandleView(cursor: .crosshair)
            .frame(width: cornerSize, height: cornerSize)
            .gesture(dragGesture(edge: edge))
    }

    /// Shared drag gesture that records the start size once, then resizes live.
    ///
    /// - Parameter edge: Edge or corner this gesture belongs to.
    private func dragGesture(edge: ResizeEdge) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                // Capture the starting size once so each translation is absolute.
                if activeEdge != edge {
                    activeEdge = edge
                    dragStart = CGSize(width: settings.windowWidth, height: settings.windowHeight)
                }
                applyDrag(translation: value.translation, edge: edge)
            }
            .onEnded { _ in
                settings.save()
                activeEdge = nil
            }
    }

    /// Maps a SwiftUI drag translation into clamped width / height and panel resize.
    ///
    /// - Parameters:
    ///   - translation: Gesture delta (x right, y down).
    ///   - edge: Border currently being dragged.
    private func applyDrag(translation: CGSize, edge: ResizeEdge) {
        var width = dragStart.width
        var height = dragStart.height

        switch edge {
        case .trailing, .topTrailing, .bottomTrailing:
            width += translation.width
        case .leading, .topLeading, .bottomLeading:
            width -= translation.width
        case .top, .bottom:
            break
        }

        switch edge {
        case .bottom, .bottomLeading, .bottomTrailing:
            height += translation.height
        case .top, .topLeading, .topTrailing:
            height -= translation.height
        case .leading, .trailing:
            break
        }

        settings.windowWidth = settings.clampWidth(width)
        settings.windowHeight = settings.clampHeight(height)
        PopupPanelController.shared.resize(
            to: NSSize(width: settings.windowWidth, height: settings.windowHeight),
            edge: edge
        )
    }
}

/// Clear AppKit-backed handle that pushes a resize cursor on hover.
///
/// SwiftUI `onHover` alone can miss cursor changes on a non-activating panel,
/// so this view uses {@link NSTrackingArea} via {@link CursorTrackingView}.
///
/// @example
/// ```swift
/// ResizeHandleView(cursor: .resizeLeftRight)
/// ```
private struct ResizeHandleView: NSViewRepresentable {
    let cursor: NSCursor

    func makeNSView(context: Context) -> CursorTrackingView {
        CursorTrackingView(cursor: cursor)
    }

    func updateNSView(_ nsView: CursorTrackingView, context: Context) {
        nsView.resizeCursor = cursor
    }
}

/// Tracking view that shows `resizeCursor` while the pointer is inside the handle.
///
/// Installed as the backing view of {@link ResizeHandleView}.
final class CursorTrackingView: NSView {
    var resizeCursor: NSCursor

    private var tracking: NSTrackingArea?

    /// Creates a clear tracking view for one resize handle.
    ///
    /// - Parameter cursor: Cursor pushed while the pointer stays inside.
    init(cursor: NSCursor) {
        self.resizeCursor = cursor
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking {
            removeTrackingArea(tracking)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        resizeCursor.push()
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.pop()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: resizeCursor)
    }
}
