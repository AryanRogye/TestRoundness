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

    @State private var canvasTool: CanvasTool = .adjustOverlay
    @State private var showsHandles = true
    @State private var zoomScale: CGFloat = 1
    @State private var magnifyStartScale: CGFloat?
    @State private var panOffset: CGSize = .zero
    @State private var panStartOffset: CGSize?
    @State private var dragStartRect: CGRect?
    @State private var resizeStartRect: CGRect?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                CheckerboardBackground()

                if let importedImage {
                    imageEditor(for: importedImage, in: proxy.size)
                        .scaleEffect(zoomScale)
                        .offset(panOffset)
                        .simultaneousGesture(panGesture())
                        .simultaneousGesture(magnificationGesture())

                    canvasControls
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.quaternary.opacity(0.2))
            .onChange(of: importedImage?.id) {
                resetCanvasView()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(.secondary)

            Text("Import or paste an image to start matching its corner radius.")
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button {
                    onImportImage()
                } label: {
                    Label("Import Image", systemImage: "photo.badge.plus")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    onPasteImage()
                } label: {
                    Label("Paste Image", systemImage: "doc.on.clipboard")
                }
                .keyboardShortcut("v", modifiers: .command)
            }
        }
    }

    private func imageEditor(for importedImage: ImportedImage, in availableSize: CGSize) -> some View {
        let pixelSize = importedImage.pixelSize
        let imageFrame = fittedImageFrame(imageSize: pixelSize, availableSize: availableSize)

        return ZStack(alignment: .topLeading) {
            Image(nsImage: importedImage.image)
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
        let strokeWidth = settings.strokeWidth * swiftUIToCanvasScale

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(
                cornerRadius: cornerRadius,
                style: settings.cornerStyle.swiftUIStyle
            )
            .fill(tint.opacity(settings.fillOpacity))
            .overlay {
                if settings.showsStroke {
                    RoundedRectangle(
                        cornerRadius: cornerRadius,
                        style: settings.cornerStyle.swiftUIStyle
                    )
                    .stroke(
                        isSelected ? Color.white : tint,
                        lineWidth: strokeWidth
                    )
                    .shadow(color: .black.opacity(0.35), radius: 1 / zoomScale)
                }
            }
            .overlay {
                if isSelected {
                    Rectangle()
                        .stroke(Color.accentColor, lineWidth: 1 / zoomScale)
                }
            }
            .frame(width: rect.width, height: rect.height)
            .contentShape(Rectangle())
            .offset(x: rect.minX, y: rect.minY)
            .onTapGesture {
                selectedOverlayID = overlay.wrappedValue.id
            }
            .gesture(dragGesture(overlay: overlay, in: imageSize))

            if isSelected && showsHandles {
                ForEach(ResizeHandle.allCases) { handle in
                    ResizeHandleView(handle: handle, zoomScale: zoomScale)
                        .position(handle.position(in: rect))
                        .opacity(canvasTool == .adjustOverlay ? 1 : 0.35)
                        .gesture(resizeGesture(overlay: overlay, handle: handle, in: imageSize))
                }
            }
        }
        .frame(width: imageSize.width, height: imageSize.height)
    }

    private var canvasControls: some View {
        VStack {
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

                Divider()
                    .frame(height: 20)

                Picker("Tool", selection: $canvasTool) {
                    Label("Overlay", systemImage: "rectangle.dashed")
                        .tag(CanvasTool.adjustOverlay)
                    Label("Pan", systemImage: "hand.draw")
                        .tag(CanvasTool.pan)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 128)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
    }

    private func panGesture() -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard canvasTool == .pan else { return }

                if panStartOffset == nil {
                    panStartOffset = panOffset
                }

                guard let panStartOffset else { return }
                panOffset = CGSize(
                    width: panStartOffset.width + value.translation.width,
                    height: panStartOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                panStartOffset = nil
            }
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
        magnifyStartScale = nil
    }

    private func dragGesture(overlay: Binding<OverlayRectangle>, in imageSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard canvasTool == .adjustOverlay else { return }

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
                guard canvasTool == .adjustOverlay else { return }

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
                onEndOverlayEdit()
            }
    }

    private func normalizedDelta(_ translation: CGSize, in imageSize: CGSize) -> CGSize {
        CGSize(
            width: translation.width / (imageSize.width * zoomScale),
            height: translation.height / (imageSize.height * zoomScale)
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
        let minWidth = max(28 / imageSize.width, 0.02)
        let minHeight = max(28 / imageSize.height, 0.02)

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

private struct ResizeHandleView: View {
    let handle: ResizeHandle
    let zoomScale: CGFloat

    var body: some View {
        Circle()
            .fill(.background)
            .strokeBorder(Color.accentColor, lineWidth: 2 / zoomScale)
            .frame(
                width: (handle.isCorner ? 12 : 10) / zoomScale,
                height: (handle.isCorner ? 12 : 10) / zoomScale
            )
            .shadow(color: .black.opacity(0.2), radius: 2 / zoomScale, y: 1 / zoomScale)
    }
}

private enum ResizeHandle: CaseIterable, Identifiable {
    case topLeft
    case top
    case topRight
    case right
    case bottomRight
    case bottom
    case bottomLeft
    case left

    var id: Self { self }

    var isCorner: Bool {
        switch self {
        case .topLeft, .topRight, .bottomRight, .bottomLeft:
            return true
        case .top, .right, .bottom, .left:
            return false
        }
    }

    var movesLeft: Bool {
        self == .topLeft || self == .bottomLeft || self == .left
    }

    var movesRight: Bool {
        self == .topRight || self == .bottomRight || self == .right
    }

    var movesTop: Bool {
        self == .topLeft || self == .topRight || self == .top
    }

    var movesBottom: Bool {
        self == .bottomLeft || self == .bottomRight || self == .bottom
    }

    func position(in rect: CGRect) -> CGPoint {
        switch self {
        case .topLeft:
            return CGPoint(x: rect.minX, y: rect.minY)
        case .top:
            return CGPoint(x: rect.midX, y: rect.minY)
        case .topRight:
            return CGPoint(x: rect.maxX, y: rect.minY)
        case .right:
            return CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomRight:
            return CGPoint(x: rect.maxX, y: rect.maxY)
        case .bottom:
            return CGPoint(x: rect.midX, y: rect.maxY)
        case .bottomLeft:
            return CGPoint(x: rect.minX, y: rect.maxY)
        case .left:
            return CGPoint(x: rect.minX, y: rect.midY)
        }
    }
}

private enum CanvasTool: Hashable {
    case adjustOverlay
    case pan
}

private struct CheckerboardBackground: View {
    var body: some View {
        Canvas { context, size in
            let tileSize: CGFloat = 16
            let columns = Int(ceil(size.width / tileSize))
            let rows = Int(ceil(size.height / tileSize))

            for row in 0...rows {
                for column in 0...columns where (row + column).isMultiple(of: 2) {
                    let rect = CGRect(
                        x: CGFloat(column) * tileSize,
                        y: CGFloat(row) * tileSize,
                        width: tileSize,
                        height: tileSize
                    )
                    context.fill(Path(rect), with: .color(.primary.opacity(0.035)))
                }
            }
        }
    }
}
