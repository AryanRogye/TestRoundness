import CoreGraphics
import SwiftUI

enum OverlayPointMetric {
    case x
    case y
    case width
    case height
}

enum OverlayPointEditing {
    /// Creates a point-based binding for one normalized rectangle metric.
    ///
    /// Example: editing `.width` with a 2x image scale stores the matching normalized width
    /// while the visible field continues to show SwiftUI points.
    static func pointMetricBinding(
        _ metric: OverlayPointMetric,
        overlay: Binding<OverlayRectangle>,
        importedImage: ImportedImage,
        swiftUIScale: Double
    ) -> Binding<Double> {
        Binding(
            get: {
                let rect = overlay.wrappedValue.settings.normalizedRect
                return pointValue(
                    for: metric,
                    rect: rect,
                    pixelSize: importedImage.pixelSize,
                    swiftUIScale: swiftUIScale
                )
            },
            set: { newValue in
                var rect = overlay.wrappedValue.settings.normalizedRect
                let pixelSize = importedImage.pixelSize

                switch metric {
                case .x:
                    rect.origin.x = normalizedOrigin(
                        pointValue: newValue,
                        normalizedLength: rect.width,
                        pixelLength: pixelSize.width,
                        swiftUIScale: swiftUIScale
                    )
                case .y:
                    rect.origin.y = normalizedOrigin(
                        pointValue: newValue,
                        normalizedLength: rect.height,
                        pixelLength: pixelSize.height,
                        swiftUIScale: swiftUIScale
                    )
                case .width:
                    rect.size.width = normalizedLength(
                        pointValue: newValue,
                        origin: rect.minX,
                        pixelLength: pixelSize.width,
                        swiftUIScale: swiftUIScale
                    )
                case .height:
                    rect.size.height = normalizedLength(
                        pointValue: newValue,
                        origin: rect.minY,
                        pixelLength: pixelSize.height,
                        swiftUIScale: swiftUIScale
                    )
                }

                overlay.wrappedValue.settings.normalizedRect = rect
            }
        )
    }

    /// Returns a single overlay metric in SwiftUI points for read-only labels.
    ///
    /// Example: use this for canvas badges while `pointMetricBinding` remains for editable fields.
    static func pointValue(
        for metric: OverlayPointMetric,
        overlay: OverlayRectangle,
        importedImage: ImportedImage,
        swiftUIScale: Double
    ) -> Double {
        pointValue(
            for: metric,
            rect: overlay.settings.normalizedRect,
            pixelSize: importedImage.pixelSize,
            swiftUIScale: swiftUIScale
        )
    }

    static func pointText(
        for metric: OverlayPointMetric,
        overlay: OverlayRectangle,
        importedImage: ImportedImage,
        swiftUIScale: Double
    ) -> String {
        let value = pointValue(
            for: metric,
            overlay: overlay,
            importedImage: importedImage,
            swiftUIScale: swiftUIScale
        )

        if value.rounded() == value {
            return String(format: "%.0f", value)
        }

        return String(format: "%.1f", value)
    }

    static func pointValue(
        for metric: OverlayPointMetric,
        rect: CGRect,
        pixelSize: CGSize,
        swiftUIScale: Double
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

    static func normalizedOrigin(
        pointValue: Double,
        normalizedLength: CGFloat,
        pixelLength: CGFloat,
        swiftUIScale: Double
    ) -> CGFloat {
        let safePixelLength = max(pixelLength, 1)
        let normalizedValue = CGFloat(pointValue * max(swiftUIScale, 1)) / safePixelLength
        return min(max(0, normalizedValue), max(0, 1 - normalizedLength))
    }

    static func normalizedLength(
        pointValue: Double,
        origin: CGFloat,
        pixelLength: CGFloat,
        swiftUIScale: Double
    ) -> CGFloat {
        let safePixelLength = max(pixelLength, 1)
        let normalizedValue = CGFloat(pointValue * max(swiftUIScale, 1)) / safePixelLength
        let minimumLength = 1 / safePixelLength
        let maximumLength = max(minimumLength, 1 - origin)
        return min(max(minimumLength, normalizedValue), maximumLength)
    }
}
