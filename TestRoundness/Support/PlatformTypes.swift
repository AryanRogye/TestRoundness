import SwiftUI

#if os(macOS)
import AppKit

typealias PlatformImage = NSImage
typealias PlatformBackgroundColor = NSColor
#elseif canImport(UIKit)
import UIKit

typealias PlatformImage = UIImage
typealias PlatformBackgroundColor = UIColor

extension UIColor {
    static var windowBackgroundColor: UIColor {
        .systemBackground
    }
}
#endif

extension Color {
    init(nsColorOrUIColor color: PlatformBackgroundColor) {
        #if os(macOS)
        self.init(nsColor: color)
        #else
        self.init(uiColor: color)
        #endif
    }
}
