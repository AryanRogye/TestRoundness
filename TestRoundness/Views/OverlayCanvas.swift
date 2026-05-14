import SwiftUI

struct OverlayCanvas: View {
    let importedImage: ImportedImage?
    @Binding var overlays: [OverlayRectangle]
    @Binding var selectedOverlayID: UUID?
    let swiftUIScale: Double
    let onImportImage: () -> Void
    let onPasteImage: () -> Void
    let onBeginOverlayEdit: () -> Void
    let onEndOverlayEdit: () -> Void

    @State private var showsHandles = true
    @State private var zoomScale: CGFloat = 1
    @State private var magnifyStartScale: CGFloat?
    @State private var panOffset: CGSize = .zero
    @State private var panStartOffset: CGSize?
    @State private var isTouchPanBlocked = false
    @State private var dragStartRect: CGRect?
    @State private var resizeStartRect: CGRect?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                canvasSurface(in: proxy.size)

                if importedImage != nil {
                    canvasControls
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.quaternary.opacity(0.2))
            .onChange(of: importedImage?.id) {
                resetCanvasView()
            }
        }
    }

    private func canvasSurface(in availableSize: CGSize) -> some View {
        let surface = ZStack {
            CheckerboardBackground()

            if let importedImage {
                imageEditor(for: importedImage, in: availableSize)
                    .scaleEffect(zoomScale)
                    .offset(panOffset)
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .trackpadPan { delta in
            guard !isTouchPanBlocked else { return }
            
            panOffset.width += delta.width
            panOffset.height += delta.height
        }
        
        #if os(iOS)
        return surface
            .simultaneousGesture(touchPanGesture(in: availableSize))
            .simultaneousGesture(magnificationGesture())
        #else
        return surface
            .simultaneousGesture(magnificationGesture())
        #endif
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(.secondary)

            Text("Import or paste an image to start matching its corner radius.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            ViewThatFits {
                HStack(spacing: 10) {
                    importButton
                    pasteButton
                }

                VStack(spacing: 10) {
                    importButton
                    pasteButton
                }
            }
        }
        .padding(24)
    }

    private var importButton: some View {
        Button {
            onImportImage()
        } label: {
            Label("Import Image", systemImage: "photo.badge.plus")
        }
        .buttonStyle(.borderedProminent)
    }

    private var pasteButton: some View {
        Button {
            onPasteImage()
        } label: {
            Label("Paste Image", systemImage: "doc.on.clipboard")
        }
        .keyboardShortcut("v", modifiers: .command)
    }

    private func imageEditor(for importedImage: ImportedImage, in availableSize: CGSize) -> some View {
        let pixelSize = importedImage.pixelSize
        let imageFrame = fittedImageFrame(imageSize: pixelSize, availableSize: availableSize)

        return ZStack(alignment: .topLeading) {
            importedImage.swiftUIImage
                .resizable()
                .interpolation(zoomScale >= 2 ? .none : .high)
                .aspectRatio(contentMode: .fit)
                .frame(width: imageFrame.width, height: imageFrame.height)

            overlayLayer(in: imageFrame.size, pixelSize: pixelSize, zoomScale: zoomScale)
        }
        .frame(width: imageFrame.width, height: imageFrame.height)
        .position(x: imageFrame.midX, y: imageFrame.midY)
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
    }

    private func overlayLayer(
        in imageSize: CGSize,
        pixelSize: CGSize,
        zoomScale: CGFloat
    ) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach($overlays) { $overlay in
                if overlay.isVisible {
                    overlayView(
                        overlay: $overlay,
                        imageSize: imageSize,
                        pixelSize: pixelSize,
                        zoomScale: zoomScale
                    )
                    .zIndex(overlay.id == selectedOverlayID ? 1 : 0)
                }
            }
        }
        .frame(width: imageSize.width, height: imageSize.height)
    }

    private func overlayView(
        overlay: Binding<OverlayRectangle>,
        imageSize: CGSize,
        pixelSize: CGSize,
        zoomScale: CGFloat
    ) -> some View {
        let settings = overlay.wrappedValue.settings
        let rect = denormalizedRect(settings.normalizedRect, in: imageSize)
        let isSelected = overlay.wrappedValue.id == selectedOverlayID
        let tint = overlay.wrappedValue.tint.color
        let swiftUIToCanvasScale = swiftUIToCanvasScale(displaySize: imageSize, pixelSize: pixelSize)
        let cornerRadius = settings.cornerRadius * swiftUIToCanvasScale

        let localRect = CGRect(origin: .zero, size: rect.size)

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(
                cornerRadius: cornerRadius,
                style: settings.cornerStyle.swiftUIStyle
            )
            .fill(tint.opacity(settings.fillOpacity))
            .frame(width: rect.width, height: rect.height)
            .contentShape(Rectangle())
            .onTapGesture {
                selectedOverlayID = overlay.wrappedValue.id
            }
            .gesture(dragGesture(overlay: overlay, in: imageSize))

            if isSelected && showsHandles {
                ForEach(ResizeHandle.allCases) { handle in
                    ResizeHandleView(handle: handle, zoomScale: zoomScale)
                        .position(handle.position(in: localRect))
                        .gesture(resizeGesture(overlay: overlay, handle: handle, in: imageSize))
                }
            }
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
    }

    private var canvasControls: some View {
        VStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        setZoom(zoomScale / 1.25)
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .help("Zoom out")

                    Text("\(Int((zoomScale * 100).rounded()))%")
                        .font(.callout)
                        .monospacedDigit()
                        .frame(width: 54, alignment: .trailing)

                    Slider(
                        value: Binding(
                            get: { zoomScale },
                            set: { setZoom($0) }
                        ),
                        in: 0.25...8
                    )
                    .frame(width: 150)

                    Button {
                        setZoom(zoomScale * 1.25)
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .help("Zoom in")

                    Button {
                        resetCanvasView()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .help("Reset view")

                    Button {
                        showsHandles.toggle()
                    } label: {
                        Image(systemName: showsHandles ? "eye" : "eye.slash")
                    }
                    .help(showsHandles ? "Hide resize handles" : "Show resize handles")

                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(8)
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
    }

    private func magnificationGesture() -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if magnifyStartScale == nil {
                    magnifyStartScale = zoomScale
                }

                guard let magnifyStartScale else { return }
                setZoom(magnifyStartScale * value)
            }
            .onEnded { _ in
                magnifyStartScale = nil
            }
    }

    private func setZoom(_ scale: CGFloat) {
        zoomScale = min(max(scale, 0.25), 8)

        if zoomScale == 1 {
            panOffset = .zero
        }
    }

    private func resetCanvasView() {
        zoomScale = 1
        panOffset = .zero
        panStartOffset = nil
        isTouchPanBlocked = false
        magnifyStartScale = nil
    }

    #if os(iOS)
    private func touchPanGesture(in availableSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if panStartOffset == nil && !isTouchPanBlocked {
                    isTouchPanBlocked = isPointOnVisibleOverlay(
                        value.startLocation,
                        availableSize: availableSize
                    )

                    if !isTouchPanBlocked {
                        panStartOffset = panOffset
                    }
                }

                guard !isTouchPanBlocked, let panStartOffset else { return }
                panOffset = CGSize(
                    width: panStartOffset.width + value.translation.width,
                    height: panStartOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                panStartOffset = nil
                isTouchPanBlocked = false
            }
    }

    private func isPointOnVisibleOverlay(_ point: CGPoint, availableSize: CGSize) -> Bool {
        guard let importedImage else { return false }

        let imageFrame = transformedImageFrame(
            for: importedImage,
            availableSize: availableSize
        )

        return overlays.contains { overlay in
            guard overlay.isVisible else { return false }

            let rect = overlay.settings.normalizedRect
            let overlayFrame = CGRect(
                x: imageFrame.minX + rect.minX * imageFrame.width,
                y: imageFrame.minY + rect.minY * imageFrame.height,
                width: rect.width * imageFrame.width,
                height: rect.height * imageFrame.height
            )
            .insetBy(dx: -28, dy: -28)

            return overlayFrame.contains(point)
        }
    }

    private func transformedImageFrame(
        for importedImage: ImportedImage,
        availableSize: CGSize
    ) -> CGRect {
        let imageFrame = fittedImageFrame(
            imageSize: importedImage.pixelSize,
            availableSize: availableSize
        )
        let scaledSize = CGSize(
            width: imageFrame.width * zoomScale,
            height: imageFrame.height * zoomScale
        )
        let center = CGPoint(
            x: imageFrame.midX + panOffset.width,
            y: imageFrame.midY + panOffset.height
        )

        return CGRect(
            x: center.x - scaledSize.width / 2,
            y: center.y - scaledSize.height / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )
    }
    #endif

    private func dragGesture(overlay: Binding<OverlayRectangle>, in imageSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                isTouchPanBlocked = true
                selectedOverlayID = overlay.wrappedValue.id

                if dragStartRect == nil {
                    dragStartRect = overlay.wrappedValue.settings.normalizedRect
                    onBeginOverlayEdit()
                }

                guard let dragStartRect else { return }
                let delta = normalizedDelta(value.translation, in: imageSize)
                overlay.wrappedValue.settings.normalizedRect = movedRect(dragStartRect, by: delta)
            }
            .onEnded { _ in
                dragStartRect = nil
                isTouchPanBlocked = false
                onEndOverlayEdit()
            }
    }

    private func resizeGesture(
        overlay: Binding<OverlayRectangle>,
        handle: ResizeHandle,
        in imageSize: CGSize
    ) -> some Gesture {
        DragGesture()
            .onChanged { value in
                isTouchPanBlocked = true
                selectedOverlayID = overlay.wrappedValue.id

                if resizeStartRect == nil {
                    resizeStartRect = overlay.wrappedValue.settings.normalizedRect
                    onBeginOverlayEdit()
                }

                guard let resizeStartRect else { return }
                let delta = normalizedDelta(value.translation, in: imageSize)

                overlay.wrappedValue.settings.normalizedRect = resizedRect(
                    resizeStartRect,
                    handle: handle,
                    by: delta,
                    in: imageSize
                )
            }
            .onEnded { _ in
                resizeStartRect = nil
                isTouchPanBlocked = false
                onEndOverlayEdit()
            }
    }

    private func normalizedDelta(_ translation: CGSize, in imageSize: CGSize) -> CGSize {
        let speed: CGFloat = 1.75
        
        return CGSize(
            width: (translation.width * speed) / (imageSize.width * zoomScale),
            height: (translation.height * speed) / (imageSize.height * zoomScale)
        )
    }
    
    private func movedRect(_ rect: CGRect, by delta: CGSize) -> CGRect {
        var candidate = rect.offsetBy(dx: delta.width, dy: delta.height)
        candidate.origin.x = min(max(0, candidate.minX), 1 - candidate.width)
        candidate.origin.y = min(max(0, candidate.minY), 1 - candidate.height)
        return candidate
    }

    private func resizedRect(
        _ rect: CGRect,
        handle: ResizeHandle,
        by delta: CGSize,
        in imageSize: CGSize
    ) -> CGRect {
        let minWidth = max(2 / imageSize.width, 0.0001)
        let minHeight = max(2 / imageSize.height, 0.0001)

        var minX = rect.minX
        var maxX = rect.maxX
        var minY = rect.minY
        var maxY = rect.maxY

        if handle.movesLeft {
            minX = min(max(0, rect.minX + delta.width), maxX - minWidth)
        }

        if handle.movesRight {
            maxX = max(min(1, rect.maxX + delta.width), minX + minWidth)
        }

        if handle.movesTop {
            minY = min(max(0, rect.minY + delta.height), maxY - minHeight)
        }

        if handle.movesBottom {
            maxY = max(min(1, rect.maxY + delta.height), minY + minHeight)
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func denormalizedRect(_ rect: CGRect, in size: CGSize) -> CGRect {
        CGRect(
            x: rect.minX * size.width,
            y: rect.minY * size.height,
            width: rect.width * size.width,
            height: rect.height * size.height
        )
    }

    private func swiftUIToCanvasScale(displaySize: CGSize, pixelSize: CGSize) -> CGFloat {
        let pixelsWide = max(pixelSize.width, 1)
        let pixelsHigh = max(pixelSize.height, 1)
        let xScale = displaySize.width / pixelsWide
        let yScale = displaySize.height / pixelsHigh
        return CGFloat(max(swiftUIScale, 1)) * min(xScale, yScale)
    }

    private func fittedImageFrame(imageSize: CGSize, availableSize: CGSize) -> CGRect {
        let padding: CGFloat = 48
        let maxWidth = max(1, availableSize.width - padding)
        let maxHeight = max(1, availableSize.height - padding)
        let scale = min(maxWidth / imageSize.width, maxHeight / imageSize.height)
        let fittedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)

        return CGRect(
            x: (availableSize.width - fittedSize.width) / 2,
            y: (availableSize.height - fittedSize.height) / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }
}
