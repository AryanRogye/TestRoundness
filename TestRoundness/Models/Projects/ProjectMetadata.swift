import Foundation

struct ProjectMetadata: Codable {
    var id: UUID
    var name: String
    var sourceName: String
    var documentState: RoundnessDocumentState
    var swiftUIScale: Double
    var createdAt: Date
    var modifiedAt: Date
}
