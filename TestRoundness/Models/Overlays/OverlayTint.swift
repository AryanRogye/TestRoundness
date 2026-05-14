import SwiftUI

enum PresetTint: String, CaseIterable, Identifiable, Codable {
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
    
    static func defaultTint(for number: Int) -> PresetTint {
        let index = max(0, number - 1) % allCases.count
        return allCases[index]
    }
}

struct RGBAColor: Codable, Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double = 1
    
    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
    
    var hexString: String {
        "\(red)-\(green)-\(blue)-\(alpha)"
    }
}

enum OverlayTint: Identifiable, Codable, Hashable {
    case preset(PresetTint)
    case custom(RGBAColor)
    
    var id: String {
        switch self {
        case .preset(let preset):
            return "preset-\(preset.rawValue)"
        case .custom(let color):
            return "custom-\(color.hexString)"
        }
    }
    
    var color: Color {
        switch self {
        case .preset(let preset):
            return preset.color
        case .custom(let rgba):
            return rgba.color
        }
    }
}
