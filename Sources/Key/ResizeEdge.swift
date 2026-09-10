import Foundation

/// Which chrome edge or corner the user is dragging to resize {@link PopupPanelController}.
///
/// Used by {@link ResizeBorderOverlay} to compute the new size and by the panel to
/// keep the opposite edge anchored under the cursor.
///
/// @example
/// ```swift
/// ResizeEdge.bottom.anchorsTop // true — growing downward keeps the top fixed
/// ```
enum ResizeEdge {
    case top, bottom, leading, trailing
    case topLeading, topTrailing, bottomLeading, bottomTrailing

    /// `true` when width changes should keep the left edge fixed.
    var anchorsLeading: Bool {
        switch self {
        case .trailing, .topTrailing, .bottomTrailing: return true
        default: return false
        }
    }

    /// `true` when width changes should keep the right edge fixed.
    var anchorsTrailing: Bool {
        switch self {
        case .leading, .topLeading, .bottomLeading: return true
        default: return false
        }
    }

    /// `true` when height changes should keep the top edge fixed (AppKit y-up).
    var anchorsTop: Bool {
        switch self {
        case .bottom, .bottomLeading, .bottomTrailing: return true
        default: return false
        }
    }

    /// `true` when height changes should keep the bottom edge fixed.
    var anchorsBottom: Bool {
        switch self {
        case .top, .topLeading, .topTrailing: return true
        default: return false
        }
    }
}
