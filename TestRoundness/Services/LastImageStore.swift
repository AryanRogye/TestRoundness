import AppKit
import Foundation

struct LastImageStore {
    private let imageFileName = "LastImage.png"
    private let metadataFileName = "LastImageMetadata.json"

    func save(image: NSImage, sourceName: String, documentState: RoundnessDocumentState) throws {
        let directoryURL = try storageDirectoryURL()
        let imageURL = directoryURL.appendingPathComponent(imageFileName)

        guard let imageData = image.pngData else {
            throw CocoaError(.fileWriteUnknown)
        }

        try imageData.write(to: imageURL, options: .atomic)
        try saveMetadata(sourceName: sourceName, documentState: documentState)
    }

    func saveDocumentState(_ documentState: RoundnessDocumentState, sourceName: String) throws {
        try saveMetadata(sourceName: sourceName, documentState: documentState)
    }

    func load() throws -> LastStoredImage? {
        let directoryURL = try storageDirectoryURL(createIfNeeded: false)
        let imageURL = directoryURL.appendingPathComponent(imageFileName)
        let metadataURL = directoryURL.appendingPathComponent(metadataFileName)

        guard
            let image = NSImage(contentsOf: imageURL),
            FileManager.default.fileExists(atPath: imageURL.path)
        else {
            return nil
        }

        let metadata = loadMetadata(from: metadataURL)
        let importedImage = ImportedImage(sourceName: metadata.sourceName, image: image)

        return LastStoredImage(
            importedImage: importedImage,
            documentState: metadata.documentState
        )
    }

    private func saveMetadata(sourceName: String, documentState: RoundnessDocumentState) throws {
        let directoryURL = try storageDirectoryURL()
        let metadataURL = directoryURL.appendingPathComponent(metadataFileName)
        let metadata = StoredImageMetadata(sourceName: sourceName, documentState: documentState)
        let metadataData = try JSONEncoder().encode(metadata)
        try metadataData.write(to: metadataURL, options: .atomic)
    }

    private func loadMetadata(from url: URL) -> StoredImageMetadata {
        guard let metadataData = try? Data(contentsOf: url) else {
            return StoredImageMetadata(sourceName: "Restored Image", documentState: .fresh)
        }

        if let metadata = try? JSONDecoder().decode(StoredImageMetadata.self, from: metadataData) {
            return metadata
        }

        if let legacy = try? JSONDecoder().decode(LegacyStoredImageMetadata.self, from: metadataData) {
            return StoredImageMetadata(sourceName: legacy.sourceName, documentState: .fresh)
        }

        return StoredImageMetadata(sourceName: "Restored Image", documentState: .fresh)
    }

    private func storageDirectoryURL(createIfNeeded: Bool = true) throws -> URL {
        let baseURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = baseURL.appendingPathComponent("TestRoundness", isDirectory: true)

        if createIfNeeded {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
        }

        return directoryURL
    }
}

private struct StoredImageMetadata: Codable {
    var sourceName: String
    var documentState: RoundnessDocumentState
}

private struct LegacyStoredImageMetadata: Codable {
    var sourceName: String
}

private extension NSImage {
    var pngData: Data? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        bitmap.size = size
        return bitmap.representation(using: .png, properties: [:])
    }
}
