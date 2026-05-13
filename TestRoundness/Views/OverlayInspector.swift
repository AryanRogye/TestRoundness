import SwiftUI

struct OverlayInspector: View {
    let importedImage: ImportedImage?
    let overlays: [OverlayRectangle]
    @Binding var selectedOverlayID: UUID?
    let selectedOverlay: Binding<OverlayRectangle>?
    let canUndo: Bool
    let canRedo: Bool
    let onImportImage: () -> Void
    let onPasteImage: () -> Void
    let onAddOverlay: () -> Void
    let onDeleteSelectedOverlay: () -> Void
    let onResetSelectedOverlay: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void

    var body: some View {
        Form {
            Section("Image") {
                if let importedImage {
                    LabeledContent("File", value: importedImage.displayName)
                    LabeledContent("Size", value: importedImage.pixelSizeText)
                } else {
                    Text("No image imported")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button {
                        onImportImage()
                    } label: {
                        Label("Import", systemImage: "photo.badge.plus")
                    }

                    Button {
                        onPasteImage()
                    } label: {
                        Label("Paste", systemImage: "doc.on.clipboard")
                    }
                }
            }

            Section("Rectangles") {
                if overlays.isEmpty {
                    Text("No rectangles")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Selected", selection: selectedOverlaySelection) {
                        ForEach(overlays) { overlay in
                            Text(overlay.name).tag(Optional(overlay.id))
                        }
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

    private var selectedOverlaySelection: Binding<UUID?> {
        Binding(
            get: { selectedOverlayID },
            set: { selectedOverlayID = $0 }
        )
    }

    private func selectedOverlayControls(_ overlay: Binding<OverlayRectangle>) -> some View {
        Group {
            Section("Shape") {
                TextField("Name", text: overlay.name)

                Picker("Corner style", selection: overlay.settings.cornerStyle) {
                    ForEach(OverlayCornerStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                valueSlider(
                    title: "Radius",
                    value: overlay.settings.cornerRadius,
                    range: 0...240,
                    suffix: "pt"
                )

                valueSlider(
                    title: "Opacity",
                    value: Binding(
                        get: { CGFloat(overlay.wrappedValue.settings.fillOpacity) },
                        set: { overlay.wrappedValue.settings.fillOpacity = Double($0) }
                    ),
                    range: 0.05...0.9,
                    suffix: ""
                )
            }

            Section("Stroke") {
                Toggle("Show stroke", isOn: overlay.settings.showsStroke)

                valueSlider(
                    title: "Width",
                    value: overlay.settings.strokeWidth,
                    range: 1...12,
                    suffix: "pt"
                )
                .disabled(!overlay.wrappedValue.settings.showsStroke)
            }

            Section("Overlay") {
                LabeledContent("X", value: percentText(overlay.wrappedValue.settings.normalizedRect.minX))
                LabeledContent("Y", value: percentText(overlay.wrappedValue.settings.normalizedRect.minY))
                LabeledContent("Width", value: percentText(overlay.wrappedValue.settings.normalizedRect.width))
                LabeledContent("Height", value: percentText(overlay.wrappedValue.settings.normalizedRect.height))

                Button("Reset Position", action: onResetSelectedOverlay)
            }
        }
    }

    private func valueSlider(
        title: String,
        value: Binding<CGFloat>,
        range: ClosedRange<CGFloat>,
        suffix: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(valueText(value.wrappedValue, suffix: suffix))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Slider(value: value, in: range)
        }
    }

    private func valueText(_ value: CGFloat, suffix: String) -> String {
        if suffix.isEmpty {
            return String(format: "%.0f%%", value * 100)
        }

        return String(format: "%.0f %@", value, suffix)
    }

    private func percentText(_ value: CGFloat) -> String {
        String(format: "%.1f%%", value * 100)
    }
}
