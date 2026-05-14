import SwiftUI

struct ImportedImage: Identifiable {
    let id = UUID()
    let sourceName: String
    let image: PlatformImage

    var displayName: String {
        sourceName
    }

    var pixelSize: CGSize {
        #if os(macOS)
        guard let representation = image.representations.first else {
            return image.size
        }

        return CGSize(width: representation.pixelsWide, height: representation.pixelsHigh)
        #else
        return CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        #endif
    }

    var swiftUIImage: Image {
        #if os(macOS)
        Image(nsImage: image)
        #else
        Image(uiImage: image)
        #endif
    }

    var pixelSizeText: String {
        "\(Int(pixelSize.width)) x \(Int(pixelSize.height)) px"
    }

    var detectedSwiftUIScale: Double {
        SwiftUIScaleDetector.detectedScale(for: pixelSize)
    }

    func swiftUIPointSizeText(scale: Double) -> String {
        let safeScale = CGFloat(max(scale, 1))
        return String(
            format: "%.0f x %.0f pt @%.0fx",
            Double(pixelSize.width / safeScale),
            Double(pixelSize.height / safeScale),
            Double(safeScale)
        )
    }
}
