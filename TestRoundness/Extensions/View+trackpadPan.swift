//
//  View+trackpadPan.swift
//  TestRoundness
//
//  Created by Aryan Rogye on 5/14/26.
//

import SwiftUI

#if os(macOS)
import AppKit

extension View {
    func trackpadPan(_ onPan: @escaping (CGSize) -> Void) -> some View {
        background(TrackpadPanMonitor(onPan: onPan))
    }
}

struct TrackpadPanMonitor: NSViewRepresentable {
    let onPan: (CGSize) -> Void
    
    func makeNSView(context: Context) -> MonitoringView {
        let view = MonitoringView()
        view.onPan = onPan
        return view
    }
    
    func updateNSView(_ nsView: MonitoringView, context: Context) {
        nsView.onPan = onPan
    }
    
    final class MonitoringView: NSView {
        var onPan: ((CGSize) -> Void)?
        private var monitor: Any?
        
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            
            if window == nil {
                removeMonitor()
            } else if monitor == nil {
                installMonitor()
            }
        }
        
        deinit {
            removeMonitor()
        }
        
        private func installMonitor() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, window != nil else { return event }
                
                let point = convert(event.locationInWindow, from: nil)
                guard bounds.contains(point), !isPointInControlsArea(point) else { return event }
                
                let multiplier: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 8
                onPan?(
                    CGSize(
                        width: event.scrollingDeltaX * multiplier,
                        height: event.scrollingDeltaY * multiplier
                    )
                )
                
                return event
            }
        }
        
        private func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }
        
        private func isPointInControlsArea(_ point: CGPoint) -> Bool {
            point.y > bounds.height - 72
        }
    }
}
#else
extension View {
    func trackpadPan(_ onPan: @escaping (CGSize) -> Void) -> some View {
        self
    }
}
#endif
