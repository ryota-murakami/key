import AppKit
import SwiftUI

/// Invisible hit targets on every edge and corner so the overlay border can be dragged to resize.
///
/// Writes clamped sizes into {@link SettingsStore} and asks {@link PopupPanelController}
/// to keep the opposite edge anchored. Hover switches to the matching resize cursor.
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
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                handle(edge: .top, cursor: .resizeUpDown, frame: CGRect(x: cornerSize, y: 0, width: w - cornerSize * 2, height: edgeThickness))
                handle(edge: .bottom, cursor: .resizeUpDown, frame: CGRect(x: cornerSize, y: h - edgeThickness, width: w - cornerSize * 2, height: edgeThickness))
                handle(edge: .leading, cursor: .resizeLeftRight, frame: CGRect(x: 0, y: cornerSize, width: edgeThickness, height: h - cornerSize * 2))
                handle(edge: .trailing, cursor: .resizeLeftRight, frame: CGRect(x: w - edgeThickness, y: cornerSize, width: edgeThickness, height: h - cornerSize * 2))

                handle(edge: .topLeading, cursor: .crosshair, frame: CGRect(x: 0, y: 0, width: cornerSize, height: cornerSize))
                handle(edge: .topTrailing, cursor: .crosshair, frame: CGRect(x: w - cornerSize, y: 0, width: cornerSize, height: cornerSize))
                handle(edge: .bottomLeading, cursor: .crosshair, frame: CGRect(x: 0, y: h - cornerSize, width: cornerSize, height: cornerSize))
                handle(edge: .bottomTrailing, cursor: .crosshair, frame: CGRect(x: w - cornerSize, y: h - cornerSize, width: cornerSize, height: cornerSize))
            }
        }
        .allowsHitTesting(true)
    }

    /// A single edge or corner drag target with hover cursor feedback.
    ///
    /// - Parameters:
    ///   - edge: Which {@link ResizeEdge} this handle drives.
    ///   - cursor: AppKit cursor shown while the pointer is over the handle.
    ///   - frame: Handle rectangle in the overlay's local coordinates.
    private func handle(edge: ResizeEdge, cursor: NSCursor, frame: CGRect) -> some View {
        ResizeHandleView(cursor: cursor)
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named("overlay"))
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
            )
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
