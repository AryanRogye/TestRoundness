import Foundation

extension ContentView {
    func createProject(_ image: PlatformImage, sourceName: String) {
        let freshState = RoundnessDocumentState.fresh
        let importedImage = ImportedImage(sourceName: sourceName, image: image)
        swiftUIScale = importedImage.detectedSwiftUIScale

        do {
            let project = try imageStore.createProject(
                image: image,
                sourceName: sourceName,
                documentState: freshState,
                swiftUIScale: swiftUIScale
            )
            applyProject(project)
            showsProjectHome = false
            refreshProjects()
        } catch {
            importError = "The image was loaded, but could not be saved as a project: \(error.localizedDescription)"
        }
    }

    func restoreProjects() {
        guard importedImage == nil else { return }

        refreshProjects()

        guard let projectID = projects.first?.id,
              let project = try? imageStore.loadProject(id: projectID)
        else {
            return
        }

        applyProject(project)
    }

    func selectProject(_ projectID: UUID) {
        guard projectID != selectedProjectID else { return }
        guard let project = try? imageStore.loadProject(id: projectID) else {
            refreshProjects()
            return
        }

        applyProject(project)
    }

    func openProject(_ projectID: UUID) {
        if projectID != selectedProjectID {
            selectProject(projectID)
        }

        if importedImage != nil {
            showsProjectHome = false
        }
    }

    func requestSelectedProjectDeletion() {
        guard let selectedProjectID else { return }
        guard let project = projects.first(where: { $0.id == selectedProjectID }) else { return }
        requestProjectDeletion(project)
    }

    func requestProjectDeletion(_ project: ProjectSummary) {
        projectPendingDeletion = project
    }

    func deleteProject(_ project: ProjectSummary) {
        do {
            try imageStore.deleteProject(id: project.id)
            projectPendingDeletion = nil
            refreshProjects()

            if selectedProjectID == project.id,
               let nextProjectID = projects.first?.id,
               let nextProject = try imageStore.loadProject(id: nextProjectID) {
                applyProject(nextProject)
            } else if selectedProjectID == project.id {
                clearProject()
            }

            if projects.isEmpty {
                showsProjectHome = true
            }
        } catch {
            importError = "The project could not be deleted: \(error.localizedDescription)"
        }
    }

    func refreshProjects() {
        projects = (try? imageStore.loadProjectSummaries()) ?? []
    }

    func applyProject(_ project: StoredProject) {
        selectedProjectID = project.id
        importedImage = project.importedImage
        swiftUIScale = project.swiftUIScale
        applyDocumentState(normalizedDocumentState(project.documentState))
        undoStack.removeAll()
        redoStack.removeAll()
        pendingEditSnapshot = nil
    }

    func clearProject() {
        selectedProjectID = nil
        importedImage = nil
        applyDocumentState(.fresh)
        undoStack.removeAll()
        redoStack.removeAll()
        pendingEditSnapshot = nil
    }
}
