import SwiftUI

struct RoundnessToolView: View {
    let projects: [ProjectSummary]
    @Binding var selectedProjectID: UUID?
    let importedImage: ImportedImage?
    @Binding var overlays: [OverlayRectangle]
    @Binding var selectedOverlayID: UUID?
    let selectedOverlay: Binding<OverlayRectangle>?
    @Binding var swiftUIScale: Double
    let canUndo: Bool
    let canRedo: Bool
    let onSelectProject: (UUID) -> Void
    let onDeleteSelectedProject: () -> Void
    let onImportImage: () -> Void
    let onPasteImage: () -> Void
    let onAddOverlay: () -> Void
    let onDeleteSelectedOverlay: () -> Void
    let onResetSelectedOverlay: () -> Void
    let onToggleOverlayVisibility: (UUID) -> Void
    let onShowAllOverlays: () -> Void
    let onBeginOverlayEdit: () -> Void
    let onEndOverlayEdit: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void

    var body: some View {
        GeometryReader { proxy in
            if usesCompactLayout(for: proxy.size) {
                compactLayout(inspectorHeight: inspectorHeight(for: proxy.size))
            } else {
                regularLayout
            }
        }
    }

    private var regularLayout: some View {
        HStack(spacing: 0) {
            canvas

            Divider()

            inspector
            .frame(width: 300)
        }
    }

    private func compactLayout(inspectorHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            canvas
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)

            Divider()

            inspector
                .frame(height: inspectorHeight)
                .background(.background)
        }
    }

    private var canvas: some View {
        OverlayCanvas(
            importedImage: importedImage,
            overlays: $overlays,
            selectedOverlayID: $selectedOverlayID,
            swiftUIScale: swiftUIScale,
            onImportImage: onImportImage,
            onPasteImage: onPasteImage,
            onBeginOverlayEdit: onBeginOverlayEdit,
            onEndOverlayEdit: onEndOverlayEdit
        )
    }

    private var inspector: some View {
        OverlayInspector(
            projects: projects,
            selectedProjectID: $selectedProjectID,
            importedImage: importedImage,
            overlays: $overlays,
            selectedOverlayID: $selectedOverlayID,
            selectedOverlay: selectedOverlay,
            swiftUIScale: $swiftUIScale,
            canUndo: canUndo,
            canRedo: canRedo,
            onSelectProject: onSelectProject,
            onDeleteSelectedProject: onDeleteSelectedProject,
            onImportImage: onImportImage,
            onPasteImage: onPasteImage,
            onAddOverlay: onAddOverlay,
            onDeleteSelectedOverlay: onDeleteSelectedOverlay,
            onResetSelectedOverlay: onResetSelectedOverlay,
            onToggleOverlayVisibility: onToggleOverlayVisibility,
            onShowAllOverlays: onShowAllOverlays,
            onUndo: onUndo,
            onRedo: onRedo
        )
    }

    private func usesCompactLayout(for size: CGSize) -> Bool {
        #if os(iOS)
        size.width < 700
        #else
        false
        #endif
    }

    private func inspectorHeight(for size: CGSize) -> CGFloat {
        min(max(size.height * 0.42, 280), 390)
    }
}
