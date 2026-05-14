import SwiftUI

struct ResizeHandleView: View {
    let handle: ResizeHandle
    let zoomScale: CGFloat

    var body: some View {
        Circle()
            .fill(.background)
            .strokeBorder(Color.accentColor, lineWidth: 2 / zoomScale)
            .frame(
                width: handleSize / zoomScale,
                height: handleSize / zoomScale
            )
            .shadow(color: .black.opacity(0.2), radius: 2 / zoomScale, y: 1 / zoomScale)
    }

    private var handleSize: CGFloat {
        #if os(iOS)
        handle.isCorner ? 24 : 22
        #else
        handle.isCorner ? 12 : 10
        #endif
    }
}
