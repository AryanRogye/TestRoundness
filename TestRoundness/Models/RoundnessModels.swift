import AppKit
import SwiftUI

struct ImportedImage: Identifiable {
    let id = UUID()
    let sourceName: String
    let image: NSImage

    var displayName: String {
        sourceName
    }

    var pixelSizeText: String {
        guard let representation = image.representations.first else {
            return "\(Int(image.size.width)) x \(Int(image.size.height)) pt"
        }

        return "\(representation.pixelsWide) x \(representation.pixelsHigh) px"
    }
}

struct OverlayRectangle: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var settings = OverlaySettings()

    static func makeDefault(number: Int) -> OverlayRectangle {
        OverlayRectangle(name: "Rectangle \(number)")
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
