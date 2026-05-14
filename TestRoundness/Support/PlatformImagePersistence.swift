import Foundation

#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

extension PlatformImage {
    static func load(contentsOf url: URL) -> PlatformImage? {
        #if os(macOS)
        PlatformImage(contentsOf: url)
        #else
        PlatformImage(contentsOfFile: url.path)
        #endif
    }

    var pngRepresentation: Data? {
        #if os(macOS)
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        bitmap.size = size
        return bitmap.representation(using: .png, properties: [:])
        #else
        return pngData()
        #endif
    }
}
