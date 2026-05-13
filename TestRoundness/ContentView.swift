import AppKit
import SwiftUI
import UniformTypeIdentifiers

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

    private let imageStore = LastImageStore()

    var body: some View {
        RoundnessToolView(
            importedImage: importedImage,
            overlays: $overlays,
            selectedOverlayID: $selectedOverlayID,
            selectedOverlay: selectedOverlayBinding,
            canUndo: !undoStack.isEmpty,
            canRedo: !redoStack.isEmpty,
            onImportImage: { isImporterPresented = true },
            onPasteImage: pasteImageFromClipboard,
            onAddOverlay: addOverlay,
            onDeleteSelectedOverlay: deleteSelectedOverlay,
            onResetSelectedOverlay: resetSelectedOverlay,
            onBeginOverlayEdit: beginOverlayEdit,
            onEndOverlayEdit: endOverlayEdit,
            onUndo: undo,
            onRedo: redo
        )
        .frame(minWidth: 940, minHeight: 620)
        .toolbar {
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
                    isImporterPresented = true
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
        .onAppear(perform: restoreLastImage)
    }

    private var importErrorBinding: Binding<Bool> {
        Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
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
            guard let nsImage = NSImage(data: data) else {
                importError = "The selected file could not be decoded as an image."
                return
            }

            setImportedImage(nsImage, sourceName: url.lastPathComponent)
        } catch {
            importError = error.localizedDescription
        }
    }

    private func pasteImageFromClipboard() {
        let pasteboard = NSPasteboard.general

        if let image = pasteboard
            .readObjects(forClasses: [NSImage.self], options: nil)?
            .compactMap({ $0 as? NSImage })
            .first {
            setImportedImage(image, sourceName: "Pasted Image")
            return
        }

        for type in [NSPasteboard.PasteboardType.tiff, .png] {
            if let data = pasteboard.data(forType: type), let image = NSImage(data: data) {
                setImportedImage(image, sourceName: "Pasted Image")
                return
            }
        }

        importError = "The clipboard does not currently contain an image. Copy a photo or screenshot, then paste again."
    }

    private func setImportedImage(_ image: NSImage, sourceName: String) {
        let freshState = RoundnessDocumentState.fresh
        importedImage = ImportedImage(sourceName: sourceName, image: image)
        applyDocumentState(freshState)
        undoStack.removeAll()
        redoStack.removeAll()
        pendingEditSnapshot = nil

        do {
            try imageStore.save(image: image, sourceName: sourceName, documentState: freshState)
        } catch {
            importError = "The image was loaded, but could not be saved for next launch: \(error.localizedDescription)"
        }
    }

    private func restoreLastImage() {
        guard importedImage == nil else { return }
        guard let storedImage = try? imageStore.load() else { return }

        importedImage = storedImage.importedImage
        applyDocumentState(normalizedDocumentState(storedImage.documentState))
        undoStack.removeAll()
        redoStack.removeAll()
        pendingEditSnapshot = nil
    }

    private func addOverlay() {
        commitDocumentMutation {
            var overlay = OverlayRectangle.makeDefault(number: overlays.count + 1)

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
        guard let importedImage else { return }

        do {
            try imageStore.saveDocumentState(currentDocumentState, sourceName: importedImage.sourceName)
        } catch {
            importError = "The overlay state could not be saved: \(error.localizedDescription)"
        }
    }

    private func shiftedRect(_ rect: CGRect) -> CGRect {
        let offset: CGFloat = 0.04
        var shifted = rect.offsetBy(dx: offset, dy: offset)

        if shifted.maxX > 1 {
            shifted.origin.x = max(0, 1 - shifted.width)
        }

        if shifted.maxY > 1 {
            shifted.origin.y = max(0, 1 - shifted.height)
        }

        return shifted
    }
}
