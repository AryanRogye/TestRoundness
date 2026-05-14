import Foundation

struct RoundnessDocumentState: Codable, Equatable {
    var overlays: [OverlayRectangle]
    var selectedOverlayID: UUID?

    static var fresh: RoundnessDocumentState {
        let overlay = OverlayRectangle.makeDefault(number: 1)
        return RoundnessDocumentState(overlays: [overlay], selectedOverlayID: overlay.id)
    }
}
