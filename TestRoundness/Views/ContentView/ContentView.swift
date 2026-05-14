import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#elseif os(iOS)
import PhotosUI
import UIKit
#endif

struct ContentView: View {
    static let initialDocumentState = RoundnessDocumentState.fresh

    @State var importedImage: ImportedImage?
    @State var overlays = initialDocumentState.overlays
    @State var selectedOverlayID = initialDocumentState.selectedOverlayID
    @State var undoStack: [RoundnessDocumentState] = []
    @State var redoStack: [RoundnessDocumentState] = []
    @State var pendingEditSnapshot: RoundnessDocumentState?
    @State var isImporterPresented = false
    @State var importError: String?
    @State var projects: [ProjectSummary] = []
    @State var selectedProjectID: UUID?
    @State var showsProjectHome = true
    @State var isShowingAllSizingInfo = false
    @State var allowHoverSizingInfo = false
    @State var projectPendingDeletion: ProjectSummary?
    @AppStorage("swiftUIScale") var swiftUIScale = 3.0
    #if os(iOS)
    @State var isPhotoPickerPresented = false
    @State var selectedPhotoItem: PhotosPickerItem?
    #endif

    let imageStore = LastImageStore()

    var body: some View {
        #if os(iOS)
        content
            .photosPicker(
                isPresented: $isPhotoPickerPresented,
                selection: $selectedPhotoItem,
                matching: .images
            )
            .onChange(of: selectedPhotoItem) {
                importSelectedPhoto()
            }
        #else
        content
        #endif
    }
}
