import Foundation

struct ProjectSummary: Identifiable {
    var id: UUID
    var name: String
    var sourceName: String
    var modifiedAt: Date
    var thumbnailImage: PlatformImage?
}
