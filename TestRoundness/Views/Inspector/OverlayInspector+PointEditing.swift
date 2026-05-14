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
        OverlayPointEditing.pointMetricBinding(
            metric,
            overlay: overlay,
            importedImage: importedImage,
            swiftUIScale: swiftUIScale
        )
    }
}
