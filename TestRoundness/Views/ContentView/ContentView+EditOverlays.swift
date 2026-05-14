import CoreGraphics
import Foundation

extension ContentView {
    func addOverlay() {
        commitDocumentMutation {
            var overlay = OverlayRectangle.makeDefault(number: nextOverlayNumber)

            if let selectedOverlay = overlays.first(where: { $0.id == selectedOverlayID }) {
                overlay.settings = selectedOverlay.settings
                overlay.settings.normalizedRect = shiftedRect(selectedOverlay.settings.normalizedRect)
            }

            overlays.append(overlay)
            selectedOverlayID = overlay.id
        }
    }

    func deleteSelectedOverlay() {
        guard let selectedOverlayID,
              let selectedIndex = overlays.firstIndex(where: { $0.id == selectedOverlayID })
        else {
            return
        }

        commitDocumentMutation {
            overlays.remove(at: selectedIndex)

            if overlays.isEmpty {
                self.selectedOverlayID = nil
            } else {
                self.selectedOverlayID = overlays[min(selectedIndex, overlays.count - 1)].id
            }
        }
    }

    func resetSelectedOverlay() {
        guard let selectedOverlayID,
              let selectedIndex = overlays.firstIndex(where: { $0.id == selectedOverlayID })
        else {
            return
        }

        commitDocumentMutation {
            overlays[selectedIndex].settings.normalizedRect = CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
        }
    }

    func toggleOverlayVisibility(_ overlayID: UUID) {
        guard let overlayIndex = overlays.firstIndex(where: { $0.id == overlayID }) else { return }

        commitDocumentMutation {
            overlays[overlayIndex].isVisible.toggle()
            selectedOverlayID = overlayID
        }
    }

    func showAllOverlays() {
        guard overlays.contains(where: { !$0.isVisible }) else { return }

        commitDocumentMutation {
            for index in overlays.indices {
                overlays[index].isVisible = true
            }
        }
    }

    func updateSelectedOverlay(_ updatedOverlay: OverlayRectangle) {
        guard let index = overlays.firstIndex(where: { $0.id == updatedOverlay.id }),
              overlays[index] != updatedOverlay
        else {
            return
        }

        commitDocumentMutation {
            overlays[index] = updatedOverlay
            selectedOverlayID = updatedOverlay.id
        }
    }

    var nextOverlayNumber: Int {
        let usedNumbers = overlays.compactMap { overlay in
            overlay.name
                .split(separator: " ")
                .last
                .flatMap { Int($0) }
        }

        return (usedNumbers.max() ?? overlays.count) + 1
    }

    func shiftedRect(_ rect: CGRect) -> CGRect {
        let offset = CGFloat((overlays.count % 5) + 1) * 0.035
        let candidates = [
            rect.offsetBy(dx: offset, dy: offset),
            rect.offsetBy(dx: -offset, dy: offset),
            rect.offsetBy(dx: offset, dy: -offset),
            rect.offsetBy(dx: -offset, dy: -offset)
        ]

        return candidates
            .map(clampedRect)
            .first { candidate in
                candidate.origin != rect.origin
            } ?? clampedRect(rect.offsetBy(dx: offset, dy: offset))
    }

    func clampedRect(_ rect: CGRect) -> CGRect {
        var clamped = rect
        clamped.origin.x = min(max(0, clamped.minX), max(0, 1 - clamped.width))
        clamped.origin.y = min(max(0, clamped.minY), max(0, 1 - clamped.height))
        return clamped
    }
}
