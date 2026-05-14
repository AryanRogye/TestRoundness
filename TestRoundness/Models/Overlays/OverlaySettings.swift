import CoreGraphics

struct OverlaySettings: Codable, Equatable {
    var normalizedRect = CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
    var cornerRadius: CGFloat = 28
    var cornerStyle: OverlayCornerStyle = .continuous
    var fillOpacity: Double = 0.32
    var showsStroke = true
    var strokeWidth: CGFloat = 2
}
