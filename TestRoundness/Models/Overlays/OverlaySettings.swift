import CoreGraphics

struct OverlaySettings: Codable, Equatable {
    var normalizedRect = CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
    var cornerRadius: CGFloat = 28
    var cornerStyle: OverlayCornerStyle = .continuous
    var fillOpacity: Double = 0.32
    var showsRectInfo = false
    var showsStroke = true
    var strokeWidth: CGFloat = 2
    
    static let defaultNormalizedRect = CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
    static let defaultCornerRadius = 28
    static let defaultCornerStyle: OverlayCornerStyle = .continuous
    static let defaultFillOpacity: Double = 0.32
    static let defaultShowsRectInfo = false
    
    enum CodingKeys: String, CodingKey {
        case normalizedRect
        case cornerRadius
        case cornerStyle
        case fillOpacity
        case showsRectInfo
        case showsStroke
        case strokeWidth
    }
    
    public init() {}
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        normalizedRect = try container.decodeIfPresent(CGRect.self, forKey: .normalizedRect) ?? CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
        cornerRadius = try container.decodeIfPresent(CGFloat.self, forKey: .cornerRadius) ?? 28
        cornerStyle = try container.decodeIfPresent(OverlayCornerStyle.self, forKey: .cornerStyle) ?? .continuous
        fillOpacity = try container.decodeIfPresent(Double.self, forKey: .fillOpacity) ?? 0.32
        showsRectInfo = try container.decodeIfPresent(Bool.self, forKey: .showsRectInfo) ?? false
        showsStroke = try container.decodeIfPresent(Bool.self, forKey: .showsStroke) ?? true
        strokeWidth = try container.decodeIfPresent(CGFloat.self, forKey: .strokeWidth) ?? 2
    }
}
