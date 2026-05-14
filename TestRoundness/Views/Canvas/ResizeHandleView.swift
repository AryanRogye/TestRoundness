import SwiftUI

struct ResizeHandleView: View {
    let handle: ResizeHandle
    let zoomScale: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(.background)
                .strokeBorder(Color.accentColor, lineWidth: 2 / zoomScale)
                .frame(
                    width: visibleHandleSize / zoomScale,
                    height: visibleHandleSize / zoomScale
                )
                .shadow(color: .black.opacity(0.2), radius: 2 / zoomScale, y: 1 / zoomScale)
        }
        .frame(
            width: hitHandleSize / zoomScale,
            height: hitHandleSize / zoomScale
        )
        .contentShape(Circle())
    }

    private var visibleHandleSize: CGFloat {
        #if os(iOS)
        handle.isCorner ? 18 : 16
        #else
        handle.isCorner ? 12 : 10
        #endif
    }

    private var hitHandleSize: CGFloat {
        #if os(iOS)
        28
        #else
        visibleHandleSize
        #endif
    }
}
