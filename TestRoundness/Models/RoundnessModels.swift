import SwiftUI

#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#elseif canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#endif

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

private enum SwiftUIScaleDetector {
    private static let knownPointSizes: [(width: CGFloat, height: CGFloat)] = [
        (320, 568),
        (375, 667),
        (414, 736),
        (375, 812),
        (390, 844),
        (393, 852),
        (402, 874),
        (414, 896),
        (428, 926),
        (430, 932),
        (440, 956),
        (744, 1133),
        (768, 1024),
        (810, 1080),
        (820, 1180),
        (834, 1112),
        (834, 1194),
        (1024, 1366)
    ]

    static func detectedScale(for pixelSize: CGSize) -> Double {
        [3.0, 2.0, 1.0]
            .map { scale in
                (scale: scale, score: score(scale: CGFloat(scale), pixelSize: pixelSize))
            }
            .max { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.scale < rhs.scale
                }

                return lhs.score < rhs.score
            }?
            .scale ?? 1
    }

    private static func score(scale: CGFloat, pixelSize: CGSize) -> CGFloat {
        let pointSize = normalizedSize(
            CGSize(
                width: pixelSize.width / scale,
                height: pixelSize.height / scale
            )
        )
        let integerDistance = fractionalDistance(pointSize.width) + fractionalDistance(pointSize.height)
        let isPixelAligned = integerDistance < 0.02
        var score: CGFloat = isPixelAligned ? 40 : max(0, 16 - integerDistance * 24)

        if knownPointSizes.contains(where: { knownSize in
            abs(pointSize.width - knownSize.width) <= 2
                && abs(pointSize.height - knownSize.height) <= 2
        }) {
            score += 200
        }

        if isPixelAligned && isLikelyPhonePointSize(pointSize) {
            score += scale == 3 ? 72 : 48
        }

        if isPixelAligned && isLikelyTabletPointSize(pointSize) {
            score += scale == 2 ? 72 : 36
        }

        if scale == 1 && max(pixelSize.width, pixelSize.height) <= 1400 {
            score += 20
        }

        return score
    }

    private static func normalizedSize(_ size: CGSize) -> CGSize {
        CGSize(
            width: min(size.width, size.height),
            height: max(size.width, size.height)
        )
    }

    private static func fractionalDistance(_ value: CGFloat) -> CGFloat {
        abs(value.rounded() - value)
    }

    private static func isLikelyPhonePointSize(_ size: CGSize) -> Bool {
        (320...460).contains(size.width) && (560...980).contains(size.height)
    }

    private static func isLikelyTabletPointSize(_ size: CGSize) -> Bool {
        (700...1100).contains(size.width) && (1000...1400).contains(size.height)
    }
}

struct OverlayRectangle: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var isVisible: Bool
    var tint: OverlayTint
    var settings = OverlaySettings()

    init(
        id: UUID = UUID(),
        name: String,
        isVisible: Bool = true,
        tint: OverlayTint = .cyan,
        settings: OverlaySettings = OverlaySettings()
    ) {
        self.id = id
        self.name = name
        self.isVisible = isVisible
        self.tint = tint
        self.settings = settings
    }

    static func makeDefault(number: Int) -> OverlayRectangle {
        OverlayRectangle(
            name: "Rectangle \(number)",
            tint: OverlayTint.defaultTint(for: number)
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case isVisible
        case tint
        case settings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedName = try container.decode(String.self, forKey: .name)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = decodedName
        isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
        tint = try container.decodeIfPresent(OverlayTint.self, forKey: .tint)
            ?? OverlayTint.defaultTint(for: OverlayRectangle.number(from: decodedName) ?? 1)
        settings = try container.decodeIfPresent(OverlaySettings.self, forKey: .settings) ?? OverlaySettings()
    }

    private static func number(from name: String) -> Int? {
        name
            .split(separator: " ")
            .last
            .flatMap { Int($0) }
    }
}

struct OverlaySettings: Codable, Equatable {
    var normalizedRect = CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
    var cornerRadius: CGFloat = 28
    var cornerStyle: OverlayCornerStyle = .continuous
    var fillOpacity: Double = 0.32
    var showsStroke = true
    var strokeWidth: CGFloat = 2
}

struct RoundnessDocumentState: Codable, Equatable {
    var overlays: [OverlayRectangle]
    var selectedOverlayID: UUID?

    static var fresh: RoundnessDocumentState {
        let overlay = OverlayRectangle.makeDefault(number: 1)
        return RoundnessDocumentState(overlays: [overlay], selectedOverlayID: overlay.id)
    }
}

struct LastStoredImage {
    var importedImage: ImportedImage
    var documentState: RoundnessDocumentState
}

enum OverlayCornerStyle: String, CaseIterable, Identifiable, Codable {
    case continuous = "Continuous"
    case circular = "Circular"

    var id: String { rawValue }

    var swiftUIStyle: RoundedCornerStyle {
        switch self {
        case .continuous:
            return .continuous
        case .circular:
            return .circular
        }
    }
}

enum OverlayTint: String, CaseIterable, Identifiable, Codable {
    case cyan = "Cyan"
    case blue = "Blue"
    case green = "Green"
    case orange = "Orange"
    case pink = "Pink"
    case purple = "Purple"
    case yellow = "Yellow"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .cyan:
            return .cyan
        case .blue:
            return .blue
        case .green:
            return .green
        case .orange:
            return .orange
        case .pink:
            return .pink
        case .purple:
            return .purple
        case .yellow:
            return .yellow
        }
    }

    static func defaultTint(for number: Int) -> OverlayTint {
        let index = max(0, number - 1) % allCases.count
        return allCases[index]
    }
}
