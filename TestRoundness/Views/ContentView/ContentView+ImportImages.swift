import Foundation
import SwiftUI

#if os(macOS)
import AppKit
#elseif os(iOS)
import PhotosUI
import UIKit
#endif

extension ContentView {
    func presentImageImporter() {
        #if os(iOS)
        isPhotoPickerPresented = true
        #else
        isImporterPresented = true
        #endif
    }

    func importImage(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let isSecurityScoped = url.startAccessingSecurityScopedResource()
            defer {
                if isSecurityScoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            guard let image = PlatformImage(data: data) else {
                importError = "The selected file could not be decoded as an image."
                return
            }

            createProject(image, sourceName: url.lastPathComponent)
        } catch {
            importError = error.localizedDescription
        }
    }

    func pasteImageFromClipboard() {
        #if os(macOS)
        let pasteboard = NSPasteboard.general

        if let image = pasteboard
            .readObjects(forClasses: [NSImage.self], options: nil)?
            .compactMap({ $0 as? NSImage })
            .first {
            createProject(image, sourceName: "Pasted Image")
            return
        }

        for type in [NSPasteboard.PasteboardType.tiff, .png] {
            if let data = pasteboard.data(forType: type), let image = NSImage(data: data) {
                createProject(image, sourceName: "Pasted Image")
                return
            }
        }

        importError = "The clipboard does not currently contain an image. Copy a photo or screenshot, then paste again."
        #else
        guard let image = UIPasteboard.general.image else {
            importError = "The clipboard does not currently contain an image. Copy a photo or screenshot, then paste again."
            return
        }

        createProject(image, sourceName: "Pasted Image")
        #endif
    }

    #if os(iOS)
    func importSelectedPhoto() {
        guard let selectedPhotoItem else { return }
        self.selectedPhotoItem = nil

        Task {
            do {
                guard
                    let data = try await selectedPhotoItem.loadTransferable(type: Data.self),
                    let image = PlatformImage(data: data)
                else {
                    importError = "The selected photo could not be decoded as an image."
                    return
                }

                createProject(image, sourceName: "Photo Library Image")
            } catch {
                importError = error.localizedDescription
            }
        }
    }
    #endif
}
