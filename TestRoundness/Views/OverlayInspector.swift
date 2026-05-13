import SwiftUI

struct OverlayInspector: View {
    let importedImage: ImportedImage?
    @Binding var overlays: [OverlayRectangle]
    @Binding var selectedOverlayID: UUID?
    let selectedOverlay: Binding<OverlayRectangle>?
    @Binding var swiftUIScale: Double
    let canUndo: Bool
    let canRedo: Bool
    let onImportImage: () -> Void
    let onPasteImage: () -> Void
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
                } else {
                    Text("No image imported")
                        .foregroundStyle(.secondary)
                }

                Picker("Scale", selection: $swiftUIScale) {
                    Text("1x").tag(1.0)
                    Text("2x").tag(2.0)
                    Text("3x").tag(3.0)
                }
                .pickerStyle(.segmented)

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
                .disabled(!overlays.contains { !$0.isVisible })

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

    private func overlayRow(_ overlay: OverlayRectangle) -> some View {
        HStack(spacing: 8) {
            Button {
                onToggleOverlayVisibility(overlay.id)
            } label: {
                Image(systemName: overlay.isVisible ? "eye" : "eye.slash")
                    .foregroundStyle(overlay.isVisible ? .secondary : .tertiary)
                    .frame(width: 18)
            }
            .buttonStyle(.plain)
            .help(overlay.isVisible ? "Hide rectangle" : "Show rectangle")

            Circle()
                .fill(overlay.tint.color)
                .frame(width: 10, height: 10)

            Text(overlay.name)
                .lineLimit(1)
                .foregroundStyle(overlay.isVisible ? .primary : .secondary)

            Spacer()

            if overlay.id == selectedOverlayID {
                Image(systemName: "checkmark")
                    .font(.caption)
                    .foregroundStyle(.tint)
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedOverlayID = overlay.id
        }
    }

    private func selectedOverlayControls(_ overlay: Binding<OverlayRectangle>) -> some View {
        Group {
            Section("Shape") {
                TextField("Name", text: overlay.name)

                Picker("Color", selection: overlay.tint) {
                    ForEach(OverlayTint.allCases) { tint in
                        Label(tint.rawValue, systemImage: "circle.fill")
                            .foregroundStyle(tint.color)
                            .tag(tint)
                    }
                }

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
                if let importedImage {
                    pointValueField(
                        title: "X",
                        value: pointMetricBinding(.x, overlay: overlay, importedImage: importedImage)
                    )

                    pointValueField(
                        title: "Y",
                        value: pointMetricBinding(.y, overlay: overlay, importedImage: importedImage)
                    )

                    pointValueField(
                        title: "Width",
                        value: pointMetricBinding(.width, overlay: overlay, importedImage: importedImage)
                    )

                    pointValueField(
                        title: "Height",
                        value: pointMetricBinding(.height, overlay: overlay, importedImage: importedImage)
                    )
                } else {
                    LabeledContent("X", value: percentText(overlay.wrappedValue.settings.normalizedRect.minX))
                    LabeledContent("Y", value: percentText(overlay.wrappedValue.settings.normalizedRect.minY))
                    LabeledContent("Width", value: percentText(overlay.wrappedValue.settings.normalizedRect.width))
                    LabeledContent("Height", value: percentText(overlay.wrappedValue.settings.normalizedRect.height))
                }

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

    private func pointValueField(title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(
                title,
                value: value,
                format: .number.precision(.fractionLength(0...1))
            )
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .frame(width: 84)

            Text("pt")
                .foregroundStyle(.secondary)
        }
    }

    private func pointMetricBinding(
        _ metric: OverlayPointMetric,
        overlay: Binding<OverlayRectangle>,
        importedImage: ImportedImage
    ) -> Binding<Double> {
        Binding(
            get: {
                let rect = overlay.wrappedValue.settings.normalizedRect
                return pointValue(for: metric, rect: rect, pixelSize: importedImage.pixelSize)
            },
            set: { newValue in
                var rect = overlay.wrappedValue.settings.normalizedRect
                let pixelSize = importedImage.pixelSize

                switch metric {
                case .x:
                    rect.origin.x = normalizedOrigin(
                        pointValue: newValue,
                        normalizedLength: rect.width,
                        pixelLength: pixelSize.width
                    )
                case .y:
                    rect.origin.y = normalizedOrigin(
                        pointValue: newValue,
                        normalizedLength: rect.height,
                        pixelLength: pixelSize.height
                    )
                case .width:
                    rect.size.width = normalizedLength(
                        pointValue: newValue,
                        origin: rect.minX,
                        pixelLength: pixelSize.width
                    )
                case .height:
                    rect.size.height = normalizedLength(
                        pointValue: newValue,
                        origin: rect.minY,
                        pixelLength: pixelSize.height
                    )
                }

                overlay.wrappedValue.settings.normalizedRect = rect
            }
        )
    }

    private func pointValue(
        for metric: OverlayPointMetric,
        rect: CGRect,
        pixelSize: CGSize
    ) -> Double {
        let scale = CGFloat(max(swiftUIScale, 1))

        switch metric {
        case .x:
            return Double(rect.minX * pixelSize.width / scale)
        case .y:
            return Double(rect.minY * pixelSize.height / scale)
        case .width:
            return Double(rect.width * pixelSize.width / scale)
        case .height:
            return Double(rect.height * pixelSize.height / scale)
        }
    }

    private func normalizedOrigin(
        pointValue: Double,
        normalizedLength: CGFloat,
        pixelLength: CGFloat
    ) -> CGFloat {
        let safePixelLength = max(pixelLength, 1)
        let normalizedValue = CGFloat(pointValue * max(swiftUIScale, 1)) / safePixelLength
        return min(max(0, normalizedValue), max(0, 1 - normalizedLength))
    }

    private func normalizedLength(
        pointValue: Double,
        origin: CGFloat,
        pixelLength: CGFloat
    ) -> CGFloat {
        let safePixelLength = max(pixelLength, 1)
        let normalizedValue = CGFloat(pointValue * max(swiftUIScale, 1)) / safePixelLength
        return min(max(0.001, normalizedValue), max(0.001, 1 - origin))
    }

    private func percentText(_ value: CGFloat) -> String {
        String(format: "%.1f%%", value * 100)
    }
}

private enum OverlayPointMetric {
    case x
    case y
    case width
    case height
}
