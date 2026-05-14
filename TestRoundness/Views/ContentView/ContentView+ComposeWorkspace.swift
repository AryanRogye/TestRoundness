import SwiftUI
import UniformTypeIdentifiers

extension ContentView {
    var content: some View {
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
                editorToolbar
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

    var editor: some View {
        RoundnessToolView(
            importedImage: importedImage,
            overlays: $overlays,
            selectedOverlayID: $selectedOverlayID,
            isShowingAllSizingInfo: $isShowingAllSizingInfo,
            allowHoverSizingInfo: $allowHoverSizingInfo,
            selectedOverlay: selectedOverlayBinding,
            swiftUIScale: $swiftUIScale,
            canUndo: !undoStack.isEmpty,
            canRedo: !redoStack.isEmpty,
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

    @ToolbarContentBuilder
    var editorToolbar: some ToolbarContent {
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
                toggleSizingInfo()
            } label: {
                Label("Show Sizing", systemImage: "info")
            }
            
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
