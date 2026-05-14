import SwiftUI

struct OverlayInspector: View {
    
    @Environment(\.self) var enviornment
    
    let importedImage: ImportedImage?
    @Binding var overlays: [OverlayRectangle]
    @Binding var selectedOverlayID: UUID?
    let selectedOverlay: Binding<OverlayRectangle>?
    @Binding var swiftUIScale: Double
    @State internal var customColor: Color = .blue
    let canUndo: Bool
    let canRedo: Bool
    let onAddOverlay: () -> Void
    let onDeleteSelectedOverlay: () -> Void
    let onResetSelectedOverlay: () -> Void
    let onToggleOverlayVisibility: (UUID) -> Void
    let onShowAllOverlays: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void

    var body: some View {
        Form {
            Section("Image") {
                if let importedImage {
                    LabeledContent("File", value: importedImage.displayName)
                    LabeledContent("Pixels", value: importedImage.pixelSizeText)
                    LabeledContent("SwiftUI Size", value: importedImage.swiftUIPointSizeText(scale: swiftUIScale))
                    LabeledContent("Detection", value: scaleStatusText(for: importedImage))
                } else {
                    Text("No image imported")
                        .foregroundStyle(.secondary)
                }

                if let importedImage {
                    Picker("Point Scale", selection: scaleSelection(for: importedImage)) {
                        Text("Auto (\(scaleText(importedImage.detectedSwiftUIScale)))").tag("auto")
                        Text("1x Override").tag("1")
                        Text("2x Override").tag("2")
                        Text("3x Override").tag("3")
                    }
                    .pickerStyle(.menu)
                } else {
                    Picker("Point Scale", selection: $swiftUIScale) {
                        Text("1x").tag(1.0)
                        Text("2x").tag(2.0)
                        Text("3x").tag(3.0)
                    }
                    .pickerStyle(.segmented)
                }

                Text("Import or paste creates a new project.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Rectangles") {
                if overlays.isEmpty {
                    Text("No rectangles")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(overlays) { overlay in
                        overlayRow(overlay)
                    }
                }

                HStack {
                    Button {
                        onAddOverlay()
                    } label: {
                        Label("Add", systemImage: "plus")
                    }

                    Button(role: .destructive) {
                        onDeleteSelectedOverlay()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(selectedOverlayID == nil)
                }

                Button {
                    onShowAllOverlays()
                } label: {
                    Label("Show All", systemImage: "eye")
                }
                .disabled(overlays.isEmpty)

                HStack {
                    Button {
                        onUndo()
                    } label: {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(!canUndo)

                    Button {
                        onRedo()
                    } label: {
                        Label("Redo", systemImage: "arrow.uturn.forward")
                    }
                    .disabled(!canRedo)
                }
            }

            if let selectedOverlay {
                selectedOverlayControls(selectedOverlay)
            } else {
                Section("Shape") {
                    Text("Select or add a rectangle.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
    }
}
