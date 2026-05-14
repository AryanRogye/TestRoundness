import Foundation

struct StoredProject {
    var id: UUID
    var name: String
    var importedImage: ImportedImage
    var documentState: RoundnessDocumentState
    var swiftUIScale: Double
}
