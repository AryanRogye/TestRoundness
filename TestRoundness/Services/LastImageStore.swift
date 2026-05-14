import Foundation

struct LastImageStore {
    private let imageFileName = "Image.png"
    private let metadataFileName = "Metadata.json"
    private let projectsDirectoryName = "Projects"
    private let legacyImageFileName = "LastImage.png"
    private let legacyMetadataFileName = "LastImageMetadata.json"

    func loadProjectSummaries() throws -> [ProjectSummary] {
        try migrateLegacyProjectIfNeeded()

        let fileManager = FileManager.default
        let projectsURL = try projectsDirectoryURL(createIfNeeded: false)
        guard let projectURLs = try? fileManager.contentsOfDirectory(
            at: projectsURL,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        return projectURLs.compactMap { projectURL in
            guard let metadata = loadProjectMetadata(from: projectURL) else { return nil }
            return ProjectSummary(
                id: metadata.id,
                name: metadata.name,
                sourceName: metadata.sourceName,
                modifiedAt: metadata.modifiedAt,
                thumbnailImage: loadThumbnail(from: projectURL)
            )
        }
        .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    func createProject(
        image: PlatformImage,
        sourceName: String,
        documentState: RoundnessDocumentState,
        swiftUIScale: Double
    ) throws -> StoredProject {
        let id = UUID()
        let now = Date()
        let projectName = defaultProjectName(sourceName: sourceName, date: now)
        let projectURL = try projectDirectoryURL(for: id)

        try saveProjectFiles(
            id: id,
            name: projectName,
            image: image,
            sourceName: sourceName,
            documentState: documentState,
            swiftUIScale: swiftUIScale,
            createdAt: now,
            modifiedAt: now,
            projectURL: projectURL
        )

        return StoredProject(
            id: id,
            name: projectName,
            importedImage: ImportedImage(sourceName: sourceName, image: image),
            documentState: documentState,
            swiftUIScale: swiftUIScale
        )
    }

    func loadProject(id: UUID) throws -> StoredProject? {
        try migrateLegacyProjectIfNeeded()

        let projectURL = try projectDirectoryURL(for: id, createIfNeeded: false)
        guard let metadata = loadProjectMetadata(from: projectURL) else { return nil }

        let imageURL = projectURL.appendingPathComponent(imageFileName)
        guard let image = PlatformImage.load(contentsOf: imageURL) else { return nil }

        return StoredProject(
            id: metadata.id,
            name: metadata.name,
            importedImage: ImportedImage(sourceName: metadata.sourceName, image: image),
            documentState: metadata.documentState,
            swiftUIScale: metadata.swiftUIScale
        )
    }

    func saveProject(
        id: UUID,
        name: String,
        image: PlatformImage,
        sourceName: String,
        documentState: RoundnessDocumentState,
        swiftUIScale: Double
    ) throws {
        let projectURL = try projectDirectoryURL(for: id)
        let createdAt = loadProjectMetadata(from: projectURL)?.createdAt ?? Date()

        try saveProjectFiles(
            id: id,
            name: name,
            image: image,
            sourceName: sourceName,
            documentState: documentState,
            swiftUIScale: swiftUIScale,
            createdAt: createdAt,
            modifiedAt: Date(),
            projectURL: projectURL
        )
    }

    func deleteProject(id: UUID) throws {
        let projectURL = try projectDirectoryURL(for: id, createIfNeeded: false)
        if FileManager.default.fileExists(atPath: projectURL.path) {
            try FileManager.default.removeItem(at: projectURL)
        }
    }

    private func saveProjectFiles(
        id: UUID,
        name: String,
        image: PlatformImage,
        sourceName: String,
        documentState: RoundnessDocumentState,
        swiftUIScale: Double,
        createdAt: Date,
        modifiedAt: Date,
        projectURL: URL
    ) throws {
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)

        guard let imageData = image.pngRepresentation else {
            throw CocoaError(.fileWriteUnknown)
        }

        let imageURL = projectURL.appendingPathComponent(imageFileName)
        let metadataURL = projectURL.appendingPathComponent(metadataFileName)
        let metadata = ProjectMetadata(
            id: id,
            name: name,
            sourceName: sourceName,
            documentState: documentState,
            swiftUIScale: swiftUIScale,
            createdAt: createdAt,
            modifiedAt: modifiedAt
        )

        try imageData.write(to: imageURL, options: .atomic)
        try JSONEncoder().encode(metadata).write(to: metadataURL, options: .atomic)
    }

    private func loadProjectMetadata(from projectURL: URL) -> ProjectMetadata? {
        let metadataURL = projectURL.appendingPathComponent(metadataFileName)
        guard let data = try? Data(contentsOf: metadataURL) else { return nil }
        return try? JSONDecoder().decode(ProjectMetadata.self, from: data)
    }

    private func migrateLegacyProjectIfNeeded() throws {
        let summaries = try? projectSummariesWithoutMigration()
        guard summaries?.isEmpty != false else { return }

        let legacyDirectoryURL = try storageDirectoryURL(createIfNeeded: false)
        let legacyImageURL = legacyDirectoryURL.appendingPathComponent(legacyImageFileName)
        let legacyMetadataURL = legacyDirectoryURL.appendingPathComponent(legacyMetadataFileName)

        guard let image = PlatformImage.load(contentsOf: legacyImageURL) else { return }

        let legacyMetadata = loadLegacyMetadata(from: legacyMetadataURL)
        _ = try createProject(
            image: image,
            sourceName: legacyMetadata.sourceName,
            documentState: legacyMetadata.documentState,
            swiftUIScale: 3.0
        )
    }

    private func projectSummariesWithoutMigration() throws -> [ProjectSummary] {
        let fileManager = FileManager.default
        let projectsURL = try projectsDirectoryURL(createIfNeeded: false)
        guard let projectURLs = try? fileManager.contentsOfDirectory(at: projectsURL, includingPropertiesForKeys: nil) else {
            return []
        }

        return projectURLs.compactMap { projectURL in
            guard let metadata = loadProjectMetadata(from: projectURL) else { return nil }
            return ProjectSummary(
                id: metadata.id,
                name: metadata.name,
                sourceName: metadata.sourceName,
                modifiedAt: metadata.modifiedAt,
                thumbnailImage: loadThumbnail(from: projectURL)
            )
        }
    }

    private func loadThumbnail(from projectURL: URL) -> PlatformImage? {
        PlatformImage.load(contentsOf: projectURL.appendingPathComponent(imageFileName))
    }

    private func loadLegacyMetadata(from url: URL) -> LegacyStoredImageMetadata {
        guard let metadataData = try? Data(contentsOf: url) else {
            return LegacyStoredImageMetadata(sourceName: "Restored Image", documentState: .fresh)
        }

        if let metadata = try? JSONDecoder().decode(LegacyStoredImageMetadata.self, from: metadataData) {
            return metadata
        }

        if let olderMetadata = try? JSONDecoder().decode(OlderLegacyStoredImageMetadata.self, from: metadataData) {
            return LegacyStoredImageMetadata(sourceName: olderMetadata.sourceName, documentState: .fresh)
        }

        return LegacyStoredImageMetadata(sourceName: "Restored Image", documentState: .fresh)
    }

    private func defaultProjectName(sourceName: String, date: Date) -> String {
        let trimmedSourceName = sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSourceName.isEmpty && trimmedSourceName != "Pasted Image" && trimmedSourceName != "Photo Library Image" {
            return trimmedSourceName
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Project \(formatter.string(from: date))"
    }

    private func projectDirectoryURL(for id: UUID, createIfNeeded: Bool = true) throws -> URL {
        let projectsURL = try projectsDirectoryURL()
        let projectURL = projectsURL.appendingPathComponent(id.uuidString, isDirectory: true)

        if createIfNeeded {
            try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        }

        return projectURL
    }

    private func projectsDirectoryURL(createIfNeeded: Bool = true) throws -> URL {
        let directoryURL = try storageDirectoryURL().appendingPathComponent(projectsDirectoryName, isDirectory: true)

        if createIfNeeded {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        return directoryURL
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
