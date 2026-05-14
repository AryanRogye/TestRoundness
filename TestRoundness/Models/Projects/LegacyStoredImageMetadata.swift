import Foundation

struct LegacyStoredImageMetadata: Codable {
    var sourceName: String
    var documentState: RoundnessDocumentState
}

struct OlderLegacyStoredImageMetadata: Codable {
    var sourceName: String
}
