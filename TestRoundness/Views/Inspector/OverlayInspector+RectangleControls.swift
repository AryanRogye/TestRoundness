import SwiftUI

extension OverlayInspector {
    func overlayRow(_ overlay: OverlayRectangle) -> some View {
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
    

    func selectedOverlayControls(_ overlay: Binding<OverlayRectangle>) -> some View {
        Group {
            Section("Shape") {
                TextField("Name", text: overlay.name)
                
                Picker("Color", selection: overlay.tint) {
                    ForEach(PresetTint.allCases) { tint in
                        Label(tint.rawValue, systemImage: "circle.fill")
                            .foregroundStyle(tint.color)
                            .tag(OverlayTint.preset(tint))
                    }
                }
                
                ColorPicker("Custom Color", selection: $customColor)
                    .onChange(of: customColor) { _, newValue in
                        let resolved = newValue.resolve(in: enviornment)
                        let red: Double = Double(resolved.red)
                        let green: Double = Double(resolved.green)
                        let blue: Double = Double(resolved.blue)
                        overlay.wrappedValue.tint = .custom(
                            .init(
                                red: red,
                                green: green,
                                blue: blue
                            )
                        )
                    }

                Picker("Corner style", selection: overlay.settings.cornerStyle) {
                    ForEach(OverlayCornerStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                radiusSlider(value: overlay.settings.cornerRadius)

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
}
