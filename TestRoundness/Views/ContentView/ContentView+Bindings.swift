import SwiftUI

extension ContentView {
    var importErrorBinding: Binding<Bool> {
        Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )
    }

    var projectDeletionBinding: Binding<Bool> {
        Binding(
            get: { projectPendingDeletion != nil },
            set: { if !$0 { projectPendingDeletion = nil } }
        )
    }

    var selectedOverlayBinding: Binding<OverlayRectangle>? {
        guard let selectedOverlayID else { return nil }

        return Binding(
            get: {
                overlays.first { $0.id == selectedOverlayID } ?? OverlayRectangle.makeDefault(number: 1)
            },
            set: { updatedOverlay in
                updateSelectedOverlay(updatedOverlay)
            }
        )
    }
}
