import SwiftUI

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
