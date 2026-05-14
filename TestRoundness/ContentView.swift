import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#elseif os(iOS)
import PhotosUI
import UIKit
#endif

struct ContentView: View {
    private static let initialDocumentState = RoundnessDocumentState.fresh

    @State private var importedImage: ImportedImage?
    @State private var overlays = initialDocumentState.overlays
    @State private var selectedOverlayID = initialDocumentState.selectedOverlayID
    @State private var undoStack: [RoundnessDocumentState] = []
    @State private var redoStack: [RoundnessDocumentState] = []
    @State private var pendingEditSnapshot: RoundnessDocumentState?
    @State private var isImporterPresented = false
    @State private var importError: String?
    @State private var projects: [ProjectSummary] = []
    @State private var selectedProjectID: UUID?
    @State private var showsProjectHome = true
    @State private var projectPendingDeletion: ProjectSummary?
    @AppStorage("swiftUIScale") private var swiftUIScale = 3.0
    @Environment(\.displayScale) private var displayScale
    #if os(iOS)
    @State private var isPhotoPickerPresented = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    #endif

    private let imageStore = LastImageStore()

    var body: some View {
        #if os(iOS)
        content
            .photosPicker(
                isPresented: $isPhotoPickerPresented,
                selection: $selectedPhotoItem,
                matching: .images
            )
            .onChange(of: selectedPhotoItem) {
                importSelectedPhoto()
            }
        #else
        content
        #endif
    }

    private var content: some View {
        ZStack {
            if showsProjectHome {
                ProjectHomeView(
                    projects: projects,
                    selectedProjectID: selectedProjectID,
                    onOpenProject: openProject,
                    onNewProject: presentImageImporter,
                    onPasteProject: pasteImageFromClipboard,
                    onDeleteProject: requestProjectDeletion
                )
            } else {
                editor
            }
        }
        .modifier(PlatformWindowFrame())
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showsProjectHome = true
                } label: {
                    Label("Home", systemImage: "house")
                }
            }

            if !showsProjectHome {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        undo()
                    } label: {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(undoStack.isEmpty)
                    .keyboardShortcut("z", modifiers: .command)

                    Button {
                        redo()
                    } label: {
                        Label("Redo", systemImage: "arrow.uturn.forward")
                    }
                    .disabled(redoStack.isEmpty)
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        addOverlay()
                    } label: {
                        Label("Add Rectangle", systemImage: "plus.rectangle.on.rectangle")
                    }

                    Button {
                        deleteSelectedOverlay()
                    } label: {
                        Label("Delete Rectangle", systemImage: "trash")
                    }
                    .disabled(selectedOverlayID == nil)
                    .keyboardShortcut(.delete, modifiers: [])
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        presentImageImporter()
                    } label: {
                        Label("Import Image", systemImage: "photo.badge.plus")
                    }
                    .keyboardShortcut("o", modifiers: .command)

                    Button {
                        pasteImageFromClipboard()
                    } label: {
                        Label("Paste Image", systemImage: "doc.on.clipboard")
                    }
                    .keyboardShortcut("v", modifiers: .command)
                }
            }
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false,
            onCompletion: importImage
        )
        .alert("Image Import Failed", isPresented: importErrorBinding) {
            Button("OK", role: .cancel) {
                importError = nil
            }
        } message: {
            Text(importError ?? "")
        }
        .alert("Delete Project?", isPresented: projectDeletionBinding) {
            Button("Cancel", role: .cancel) {
                projectPendingDeletion = nil
            }

            Button("Delete", role: .destructive) {
                guard let projectPendingDeletion else { return }
                deleteProject(projectPendingDeletion)
            }
        } message: {
            Text("This removes the project, its image, and all rectangles. This cannot be undone.")
        }
        .onChange(of: swiftUIScale) {
            saveCurrentDocumentState()
        }
        .onAppear(perform: restoreProjects)
    }

    private var editor: some View {
        RoundnessToolView(
            projects: projects,
            selectedProjectID: $selectedProjectID,
            importedImage: importedImage,
            overlays: $overlays,
            selectedOverlayID: $selectedOverlayID,
            selectedOverlay: selectedOverlayBinding,
            swiftUIScale: $swiftUIScale,
            canUndo: !undoStack.isEmpty,
            canRedo: !redoStack.isEmpty,
            onSelectProject: selectProject,
            onDeleteSelectedProject: requestSelectedProjectDeletion,
            onImportImage: presentImageImporter,
            onPasteImage: pasteImageFromClipboard,
            onAddOverlay: addOverlay,
            onDeleteSelectedOverlay: deleteSelectedOverlay,
            onResetSelectedOverlay: resetSelectedOverlay,
            onToggleOverlayVisibility: toggleOverlayVisibility,
            onShowAllOverlays: showAllOverlays,
            onBeginOverlayEdit: beginOverlayEdit,
            onEndOverlayEdit: endOverlayEdit,
            onUndo: undo,
            onRedo: redo
        )
    }

    private func presentImageImporter() {
        #if os(iOS)
        isPhotoPickerPresented = true
        #else
        isImporterPresented = true
        #endif
    }

    private var importErrorBinding: Binding<Bool> {
        Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )
    }

    private var projectDeletionBinding: Binding<Bool> {
        Binding(
            get: { projectPendingDeletion != nil },
            set: { if !$0 { projectPendingDeletion = nil } }
        )
    }

    private var selectedOverlayBinding: Binding<OverlayRectangle>? {
        guard let selectedOverlayID else { return nil }

        return Binding(
            get: {
                overlays.first { $0.id == selectedOverlayID } ?? OverlayRectangle.makeDefault(number: 1)
            },
            set: { updatedOverlay in
                updateSelectedOverlay(updatedOverlay)
            }
        )
    }

    private var currentDocumentState: RoundnessDocumentState {
        RoundnessDocumentState(overlays: overlays, selectedOverlayID: selectedOverlayID)
    }

    private func importImage(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let isSecurityScoped = url.startAccessingSecurityScopedResource()
            defer {
                if isSecurityScoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            guard let image = PlatformImage(data: data) else {
                importError = "The selected file could not be decoded as an image."
                return
            }

            importNewImage(image, sourceName: url.lastPathComponent)
        } catch {
            importError = error.localizedDescription
        }
    }

    private func pasteImageFromClipboard() {
        #if os(macOS)
        let pasteboard = NSPasteboard.general

        if let image = pasteboard
            .readObjects(forClasses: [NSImage.self], options: nil)?
            .compactMap({ $0 as? NSImage })
            .first {
            importNewImage(image, sourceName: "Pasted Image")
            return
        }

        for type in [NSPasteboard.PasteboardType.tiff, .png] {
            if let data = pasteboard.data(forType: type), let image = NSImage(data: data) {
                importNewImage(image, sourceName: "Pasted Image")
                return
            }
        }

        importError = "The clipboard does not currently contain an image. Copy a photo or screenshot, then paste again."
        #else
        guard let image = UIPasteboard.general.image else {
            importError = "The clipboard does not currently contain an image. Copy a photo or screenshot, then paste again."
            return
        }

        importNewImage(image, sourceName: "Pasted Image")
        #endif
    }

    #if os(iOS)
    private func importSelectedPhoto() {
        guard let selectedPhotoItem else { return }
        self.selectedPhotoItem = nil

        Task {
            do {
                guard
                    let data = try await selectedPhotoItem.loadTransferable(type: Data.self),
                    let image = PlatformImage(data: data)
                else {
                    importError = "The selected photo could not be decoded as an image."
                    return
                }

                importNewImage(image, sourceName: "Photo Library Image")
            } catch {
                importError = error.localizedDescription
            }
        }
    }
    #endif

    private func importNewImage(_ image: PlatformImage, sourceName: String) {
        createProject(image, sourceName: sourceName)
    }

    private func createProject(_ image: PlatformImage, sourceName: String) {
        let freshState = RoundnessDocumentState.fresh
        applyImportedImageScaleDefault()

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

    private func restoreProjects() {
        guard importedImage == nil else { return }

        refreshProjects()

        guard let projectID = projects.first?.id,
              let project = try? imageStore.loadProject(id: projectID)
        else {
            return
        }

        applyProject(project)
    }

    private func selectProject(_ projectID: UUID) {
        guard projectID != selectedProjectID else { return }
        guard let project = try? imageStore.loadProject(id: projectID) else {
            refreshProjects()
            return
        }

        applyProject(project)
    }

    private func openProject(_ projectID: UUID) {
        if projectID != selectedProjectID {
            selectProject(projectID)
        }

        if importedImage != nil {
            showsProjectHome = false
        }
    }

    private func requestSelectedProjectDeletion() {
        guard let selectedProjectID else { return }
        guard let project = projects.first(where: { $0.id == selectedProjectID }) else { return }
        requestProjectDeletion(project)
    }

    private func requestProjectDeletion(_ project: ProjectSummary) {
        projectPendingDeletion = project
    }

    private func deleteProject(_ project: ProjectSummary) {
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

    private func refreshProjects() {
        projects = (try? imageStore.loadProjectSummaries()) ?? []
    }

    private func applyProject(_ project: StoredProject) {
        selectedProjectID = project.id
        importedImage = project.importedImage
        swiftUIScale = project.swiftUIScale
        applyDocumentState(normalizedDocumentState(project.documentState))
        undoStack.removeAll()
        redoStack.removeAll()
        pendingEditSnapshot = nil
    }

    private func clearProject() {
        selectedProjectID = nil
        importedImage = nil
        applyDocumentState(.fresh)
        undoStack.removeAll()
        redoStack.removeAll()
        pendingEditSnapshot = nil
    }

    private func applyImportedImageScaleDefault() {
        #if os(iOS)
        swiftUIScale = Double(displayScale)
        #endif
    }

    private func addOverlay() {
        commitDocumentMutation {
            var overlay = OverlayRectangle.makeDefault(number: nextOverlayNumber)

            if let selectedOverlay = overlays.first(where: { $0.id == selectedOverlayID }) {
                overlay.settings = selectedOverlay.settings
                overlay.settings.normalizedRect = shiftedRect(selectedOverlay.settings.normalizedRect)
            }

            overlays.append(overlay)
            selectedOverlayID = overlay.id
        }
    }

    private func deleteSelectedOverlay() {
        guard let selectedOverlayID,
              let selectedIndex = overlays.firstIndex(where: { $0.id == selectedOverlayID })
        else {
            return
        }

        commitDocumentMutation {
            overlays.remove(at: selectedIndex)

            if overlays.isEmpty {
                self.selectedOverlayID = nil
            } else {
                self.selectedOverlayID = overlays[min(selectedIndex, overlays.count - 1)].id
            }
        }
    }

    private func resetSelectedOverlay() {
        guard let selectedOverlayID,
              let selectedIndex = overlays.firstIndex(where: { $0.id == selectedOverlayID })
        else {
            return
        }

        commitDocumentMutation {
            overlays[selectedIndex].settings.normalizedRect = CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
        }
    }

    private func toggleOverlayVisibility(_ overlayID: UUID) {
        guard let overlayIndex = overlays.firstIndex(where: { $0.id == overlayID }) else { return }

        commitDocumentMutation {
            overlays[overlayIndex].isVisible.toggle()
            selectedOverlayID = overlayID
        }
    }

    private func showAllOverlays() {
        guard overlays.contains(where: { !$0.isVisible }) else { return }

        commitDocumentMutation {
            for index in overlays.indices {
                overlays[index].isVisible = true
            }
        }
    }

    private func updateSelectedOverlay(_ updatedOverlay: OverlayRectangle) {
        guard let index = overlays.firstIndex(where: { $0.id == updatedOverlay.id }),
              overlays[index] != updatedOverlay
        else {
            return
        }

        commitDocumentMutation {
            overlays[index] = updatedOverlay
            selectedOverlayID = updatedOverlay.id
        }
    }

    private func beginOverlayEdit() {
        if pendingEditSnapshot == nil {
            pendingEditSnapshot = currentDocumentState
        }
    }

    private func endOverlayEdit() {
        guard let pendingEditSnapshot else { return }
        self.pendingEditSnapshot = nil

        guard pendingEditSnapshot != currentDocumentState else { return }
        undoStack.append(pendingEditSnapshot)
        redoStack.removeAll()
        saveCurrentDocumentState()
    }

    private func undo() {
        guard let previousState = undoStack.popLast() else { return }
        redoStack.append(currentDocumentState)
        applyDocumentState(previousState)
        pendingEditSnapshot = nil
        saveCurrentDocumentState()
    }

    private func redo() {
        guard let nextState = redoStack.popLast() else { return }
        undoStack.append(currentDocumentState)
        applyDocumentState(nextState)
        pendingEditSnapshot = nil
        saveCurrentDocumentState()
    }

    private func commitDocumentMutation(_ mutation: () -> Void) {
        let before = currentDocumentState
        mutation()
        applyDocumentState(normalizedDocumentState(currentDocumentState))

        guard before != currentDocumentState else { return }
        undoStack.append(before)
        redoStack.removeAll()
        saveCurrentDocumentState()
    }

    private func applyDocumentState(_ state: RoundnessDocumentState) {
        overlays = state.overlays
        selectedOverlayID = state.selectedOverlayID
    }

    private func normalizedDocumentState(_ state: RoundnessDocumentState) -> RoundnessDocumentState {
        guard !state.overlays.isEmpty else {
            return RoundnessDocumentState(overlays: [], selectedOverlayID: nil)
        }

        let selectedID = state.selectedOverlayID.flatMap { selectedID in
            state.overlays.contains(where: { $0.id == selectedID }) ? selectedID : nil
        } ?? state.overlays.first?.id

        return RoundnessDocumentState(overlays: state.overlays, selectedOverlayID: selectedID)
    }

    private func saveCurrentDocumentState() {
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

    private var nextOverlayNumber: Int {
        let usedNumbers = overlays.compactMap { overlay in
            overlay.name
                .split(separator: " ")
                .last
                .flatMap { Int($0) }
        }

        return (usedNumbers.max() ?? overlays.count) + 1
    }

    private func shiftedRect(_ rect: CGRect) -> CGRect {
        let offset = CGFloat((overlays.count % 5) + 1) * 0.035
        let candidates = [
            rect.offsetBy(dx: offset, dy: offset),
            rect.offsetBy(dx: -offset, dy: offset),
            rect.offsetBy(dx: offset, dy: -offset),
            rect.offsetBy(dx: -offset, dy: -offset)
        ]

        return candidates
            .map(clampedRect)
            .first { candidate in
                candidate.origin != rect.origin
            } ?? clampedRect(rect.offsetBy(dx: offset, dy: offset))
    }

    private func clampedRect(_ rect: CGRect) -> CGRect {
        var clamped = rect
        clamped.origin.x = min(max(0, clamped.minX), max(0, 1 - clamped.width))
        clamped.origin.y = min(max(0, clamped.minY), max(0, 1 - clamped.height))
        return clamped
    }
}

private struct PlatformWindowFrame: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
        content.frame(minWidth: 940, minHeight: 620)
        #else
        content
        #endif
    }
}
