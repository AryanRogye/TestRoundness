import Foundation

extension ContentView {
    var currentDocumentState: RoundnessDocumentState {
        RoundnessDocumentState(overlays: overlays, selectedOverlayID: selectedOverlayID)
    }

    func beginOverlayEdit() {
        if pendingEditSnapshot == nil {
            pendingEditSnapshot = currentDocumentState
        }
    }

    func endOverlayEdit() {
        guard let pendingEditSnapshot else { return }
        self.pendingEditSnapshot = nil

        guard pendingEditSnapshot != currentDocumentState else { return }
        undoStack.append(pendingEditSnapshot)
        redoStack.removeAll()
        saveCurrentDocumentState()
    }

    func undo() {
        guard let previousState = undoStack.popLast() else { return }
        redoStack.append(currentDocumentState)
        applyDocumentState(previousState)
        pendingEditSnapshot = nil
        saveCurrentDocumentState()
    }

    func redo() {
        guard let nextState = redoStack.popLast() else { return }
        undoStack.append(currentDocumentState)
        applyDocumentState(nextState)
        pendingEditSnapshot = nil
        saveCurrentDocumentState()
    }

    func commitDocumentMutation(_ mutation: () -> Void) {
        let before = currentDocumentState
        mutation()
        applyDocumentState(normalizedDocumentState(currentDocumentState))

        guard before != currentDocumentState else { return }
        undoStack.append(before)
        redoStack.removeAll()
        saveCurrentDocumentState()
    }

    func applyDocumentState(_ state: RoundnessDocumentState) {
        overlays = state.overlays
        selectedOverlayID = state.selectedOverlayID
    }

    func normalizedDocumentState(_ state: RoundnessDocumentState) -> RoundnessDocumentState {
        guard !state.overlays.isEmpty else {
            return RoundnessDocumentState(overlays: [], selectedOverlayID: nil)
        }

        let selectedID = state.selectedOverlayID.flatMap { selectedID in
            state.overlays.contains(where: { $0.id == selectedID }) ? selectedID : nil
        } ?? state.overlays.first?.id

        return RoundnessDocumentState(overlays: state.overlays, selectedOverlayID: selectedID)
    }

    func saveCurrentDocumentState() {
        guard let selectedProjectID, let importedImage else { return }
        let projectName = projects.first { $0.id == selectedProjectID }?.name ?? importedImage.displayName

        do {
            try imageStore.saveProject(
                id: selectedProjectID,
                name: projectName,
                image: importedImage.image,
                sourceName: importedImage.sourceName,
                documentState: currentDocumentState,
                swiftUIScale: swiftUIScale
            )
            refreshProjects()
        } catch {
            importError = "The overlay state could not be saved: \(error.localizedDescription)"
        }
    }
}
