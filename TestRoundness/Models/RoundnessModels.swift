import AppKit
import SwiftUI

struct ImportedImage: Identifiable {
    let id = UUID()
    let sourceName: String
    let image: NSImage

    var displayName: String {
        sourceName
    }

    var pixelSize: CGSize {
        guard let representation = image.representations.first else {
            return image.size
        }

        return CGSize(width: representation.pixelsWide, height: representation.pixelsHigh)
    }

    var pixelSizeText: String {
        "\(Int(pixelSize.width)) x \(Int(pixelSize.height)) px"
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
