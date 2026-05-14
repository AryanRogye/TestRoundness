import CoreGraphics
import Foundation

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
        tint: OverlayTint = .preset(.cyan),
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
            tint: OverlayTint.preset(PresetTint.defaultTint(for: number))
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
        ?? OverlayTint.preset(PresetTint.defaultTint(for: OverlayRectangle.number(from: decodedName) ?? 1))
        settings = try container.decodeIfPresent(OverlaySettings.self, forKey: .settings) ?? OverlaySettings()
    }

    private static func number(from name: String) -> Int? {
        name
            .split(separator: " ")
            .last
            .flatMap { Int($0) }
    }
}
