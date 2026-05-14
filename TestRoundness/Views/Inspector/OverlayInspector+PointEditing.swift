import SwiftUI

extension OverlayInspector {
    func pointValueField(title: String, value: Binding<Double>) -> some View {
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

    func pointMetricBinding(
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

    func pointValue(
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

    func normalizedOrigin(
        pointValue: Double,
        normalizedLength: CGFloat,
        pixelLength: CGFloat
    ) -> CGFloat {
        let safePixelLength = max(pixelLength, 1)
        let normalizedValue = CGFloat(pointValue * max(swiftUIScale, 1)) / safePixelLength
        return min(max(0, normalizedValue), max(0, 1 - normalizedLength))
    }

    func normalizedLength(
        pointValue: Double,
        origin: CGFloat,
        pixelLength: CGFloat
    ) -> CGFloat {
        let safePixelLength = max(pixelLength, 1)
        let normalizedValue = CGFloat(pointValue * max(swiftUIScale, 1)) / safePixelLength
        let minimumLength = 1 / safePixelLength
        let maximumLength = max(minimumLength, 1 - origin)
        return min(max(minimumLength, normalizedValue), maximumLength)
    }
}
