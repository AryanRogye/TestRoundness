import SwiftUI

struct PlatformWindowFrame: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
        content.frame(minWidth: 940, minHeight: 620)
        #else
        content
        #endif
    }
}
