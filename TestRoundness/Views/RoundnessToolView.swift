import SwiftUI

struct RoundnessToolView: View {
    let importedImage: ImportedImage?
    @Binding var overlays: [OverlayRectangle]
    @Binding var selectedOverlayID: UUID?
    let selectedOverlay: Binding<OverlayRectangle>?
    let canUndo: Bool
    let canRedo: Bool
    let onImportImage: () -> Void
    let onPasteImage: () -> Void
    let onAddOverlay: () -> Void
    let onDeleteSelectedOverlay: () -> Void
    let onResetSelectedOverlay: () -> Void
    let onBeginOverlayEdit: () -> Void
    let onEndOverlayEdit: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            OverlayCanvas(
                importedImage: importedImage,
                overlays: $overlays,
                selectedOverlayID: $selectedOverlayID,
                onImportImage: onImportImage,
                onPasteImage: onPasteImage,
                onBeginOverlayEdit: onBeginOverlayEdit,
                onEndOverlayEdit: onEndOverlayEdit
            )

            Divider()

            OverlayInspector(
                importedImage: importedImage,
                overlays: overlays,
                selectedOverlayID: $selectedOverlayID,
                selectedOverlay: selectedOverlay,
                canUndo: canUndo,
                canRedo: canRedo,
                onImportImage: onImportImage,
                onPasteImage: onPasteImage,
                onAddOverlay: onAddOverlay,
                onDeleteSelectedOverlay: onDeleteSelectedOverlay,
                onResetSelectedOverlay: onResetSelectedOverlay,
                onUndo: onUndo,
                onRedo: onRedo
            )
            .frame(width: 300)
        }
    }
}
