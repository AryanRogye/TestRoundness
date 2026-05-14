import SwiftUI

extension OverlayInspector {
    func valueText(_ value: CGFloat, suffix: String) -> String {
        if suffix.isEmpty {
            return String(format: "%.0f%%", value * 100)
        }

        return String(format: "%.0f %@", value, suffix)
    }

    func scaleSelection(for importedImage: ImportedImage) -> Binding<String> {
        Binding(
            get: {
                let detectedScale = importedImage.detectedSwiftUIScale
                if abs(swiftUIScale - detectedScale) < 0.01 {
                    return "auto"
                }

                return String(Int(swiftUIScale.rounded()))
            },
            set: { selection in
                if selection == "auto" {
                    swiftUIScale = importedImage.detectedSwiftUIScale
                } else if let scale = Double(selection) {
                    swiftUIScale = scale
                }
            }
        )
    }

    func scaleStatusText(for importedImage: ImportedImage) -> String {
        let detectedScale = importedImage.detectedSwiftUIScale

        if abs(swiftUIScale - detectedScale) < 0.01 {
            return "Auto \(scaleText(detectedScale))"
        }

        return "Manual \(scaleText(swiftUIScale)), auto \(scaleText(detectedScale))"
    }

    func scaleText(_ scale: Double) -> String {
        String(format: "%.0fx", scale)
    }

    func radiusText(_ value: CGFloat) -> String {
        let scale = CGFloat(max(swiftUIScale, 1))
        let pixelRadius = value * scale

        if value.rounded() == value {
            return String(format: "%.0f pt / %.0f px @%.0fx", value, pixelRadius, scale)
        }

        return String(format: "%.1f pt / %.0f px @%.0fx", value, pixelRadius, scale)
    }

    func percentText(_ value: CGFloat) -> String {
        String(format: "%.1f%%", value * 100)
    }
}
