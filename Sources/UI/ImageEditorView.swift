import SwiftUI
import AppKit
import UniformTypeIdentifiers

public enum EditorMode: String, CaseIterable, Identifiable {
    case crop = "Crop"
    case annotate = "Annotate & Redact"
    case adjust = "Adjust"
    case background = "Add Background"

    public var id: String { rawValue }
}

public enum AspectRatioPreset: String, CaseIterable, Identifiable {
    case freeform = "Freeform"
    case square1x1 = "1:1 Square"
    case ratio4x3 = "4:3 Standard"
    case ratio16x9 = "16:9 Wide"
    case ratio3x2 = "3:2 Classic"
    case ratio9x16 = "9:16 Vertical"

    public var id: String { rawValue }

    public var ratio: CGFloat? {
        switch self {
        case .freeform: return nil
        case .square1x1: return 1.0
        case .ratio4x3: return 4.0 / 3.0
        case .ratio16x9: return 16.0 / 9.0
        case .ratio3x2: return 3.0 / 2.0
        case .ratio9x16: return 9.0 / 16.0
        }
    }
}

public struct RedactionBox: Identifiable, Equatable {
    public let id = UUID()
    public var rect: CGRect
    public var isRedaction: Bool // true: black box, false: yellow highlight
}

@MainActor
public final class ImageEditorViewModel: ObservableObject {
    public let url: URL
    @Published public var originalImage: NSImage
    @Published public var currentMode: EditorMode = .crop

    // Crop settings
    @Published public var selectedPreset: AspectRatioPreset = .freeform
    @Published public var cropWidthPx: Int = 0
    @Published public var cropHeightPx: Int = 0
    @Published public var cropOriginXPx: Int = 0
    @Published public var cropOffsetYPx: Int = 0

    // Annotations & Redactions
    @Published public var redactions: [RedactionBox] = []
    @Published public var currentToolIsRedact: Bool = true

    // Adjustments
    @Published public var brightness: Double = 0.0
    @Published public var contrast: Double = 1.0
    @Published public var saturation: Double = 1.0

    // Background
    @Published public var bgPadding: CGFloat = 30
    @Published public var bgColor: Color = .white

    public init(url: URL, initialMode: EditorMode = .crop) {
        self.url = url
        self.currentMode = initialMode
        let img = NSImage(contentsOf: url) ?? NSImage()
        self.originalImage = img

        if let rep = img.representations.first {
            self.cropWidthPx = rep.pixelsWide > 0 ? rep.pixelsWide : Int(img.size.width)
            self.cropHeightPx = rep.pixelsHigh > 0 ? rep.pixelsHigh : Int(img.size.height)
        } else {
            self.cropWidthPx = Int(img.size.width)
            self.cropHeightPx = Int(img.size.height)
        }
    }

    public func applyPreset(_ preset: AspectRatioPreset) {
        selectedPreset = preset
        guard let ratio = preset.ratio else { return }

        let origW = originalImagePixelWidth
        let origH = originalImagePixelHeight

        if ratio >= 1.0 {
            let newW = min(origW, Int(CGFloat(origH) * ratio))
            let newH = Int(CGFloat(newW) / ratio)
            cropWidthPx = newW
            cropHeightPx = newH
        } else {
            let newH = min(origH, Int(CGFloat(origW) / ratio))
            let newW = Int(CGFloat(newH) * ratio)
            cropWidthPx = newW
            cropHeightPx = newH
        }
        cropOriginXPx = (origW - cropWidthPx) / 2
        cropOffsetYPx = (origH - cropHeightPx) / 2
    }

    public var originalImagePixelWidth: Int {
        if let rep = originalImage.representations.first, rep.pixelsWide > 0 {
            return rep.pixelsWide
        }
        return Int(originalImage.size.width)
    }

    public var originalImagePixelHeight: Int {
        if let rep = originalImage.representations.first, rep.pixelsHigh > 0 {
            return rep.pixelsHigh
        }
        return Int(originalImage.size.height)
    }

    public func executeSave() -> URL? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              var cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return nil
        }

        let origW = cgImage.width
        let origH = cgImage.height

        // 1. Apply Adjustments if modified
        if brightness != 0.0 || contrast != 1.0 || saturation != 1.0 {
            let ciImage = CIImage(cgImage: cgImage)
            let filter = CIFilter(name: "CIColorControls")
            filter?.setValue(ciImage, forKey: kCIInputImageKey)
            filter?.setValue(brightness, forKey: kCIInputBrightnessKey)
            filter?.setValue(contrast, forKey: kCIInputContrastKey)
            filter?.setValue(saturation, forKey: kCIInputSaturationKey)

            if let outputCI = filter?.outputImage {
                let context = CIContext()
                if let adjustedCG = context.createCGImage(outputCI, from: outputCI.extent) {
                    cgImage = adjustedCG
                }
            }
        }

        // 2. Apply Crop
        let cropW = max(1, min(cropWidthPx, origW))
        let cropH = max(1, min(cropHeightPx, origH))
        let cropX = max(0, min(cropOriginXPx, origW - cropW))
        // In CGImage, y = 0 is top
        let cropY = max(0, min(cropOffsetYPx, origH - cropH))

        let cropRect = CGRect(x: cropX, y: cropY, width: cropW, height: cropH)
        guard let croppedCG = cgImage.cropping(to: cropRect) else { return nil }

        // 3. Render Annotations / Redactions / Background
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let finalW = currentMode == .background ? croppedCG.width + Int(bgPadding * 2) : croppedCG.width
        let finalH = currentMode == .background ? croppedCG.height + Int(bgPadding * 2) : croppedCG.height

        guard let context = CGContext(
            data: nil,
            width: finalW,
            height: finalH,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Background fill
        if currentMode == .background {
            let nsColor = NSColor(bgColor)
            context.setFillColor(nsColor.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: finalW, height: finalH))
            let drawRect = CGRect(x: CGFloat(bgPadding), y: CGFloat(bgPadding), width: CGFloat(croppedCG.width), height: CGFloat(croppedCG.height))
            context.draw(croppedCG, in: drawRect)
        } else {
            context.draw(croppedCG, in: CGRect(x: 0, y: 0, width: finalW, height: finalH))
        }

        // Draw redactions
        for red in redactions {
            let rx = red.rect.origin.x * CGFloat(finalW)
            let ry = red.rect.origin.y * CGFloat(finalH)
            let rw = red.rect.size.width * CGFloat(finalW)
            let rh = red.rect.size.height * CGFloat(finalH)
            let rRect = CGRect(x: rx, y: ry, width: rw, height: rh)

            if red.isRedaction {
                context.setFillColor(NSColor.black.cgColor)
                context.fill(rRect)
            } else {
                context.setFillColor(NSColor.yellow.withAlphaComponent(0.45).cgColor)
                context.fill(rRect)
            }
        }

        guard let finalCG = context.makeImage() else { return nil }

        // Output URL
        let ext = url.pathExtension.lowercased()
        let suffix = currentMode == .crop ? "cropped" : (currentMode == .annotate ? "annotated" : (currentMode == .adjust ? "edited" : "with_bg"))
        let outURL = ImageProcessor.destinationURL(for: url, newExtension: "\(suffix).\(ext)")

        guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, (ext == "png" ? UTType.png.identifier : UTType.jpeg.identifier) as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(dest, finalCG, nil)
        if CGImageDestinationFinalize(dest) {
            return outURL
        }
        return nil
    }
}

public struct ImageEditorView: View {
    @ObservedObject var vm: ImageEditorViewModel
    public let onSave: (URL) -> Void
    public let onCancel: () -> Void

    public init(vm: ImageEditorViewModel, onSave: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
        self.vm = vm
        self.onSave = onSave
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Mode Picker Toolbar
            HStack {
                Picker("Mode", selection: $vm.currentMode) {
                    Text("✂️ Crop").tag(EditorMode.crop)
                    Text("✏️ Annotate & Redact").tag(EditorMode.annotate)
                    Text("🎛️ Adjust").tag(EditorMode.adjust)
                    Text("🎨 Add Background").tag(EditorMode.background)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 480)

                Spacer()

                Button("Reset") {
                    vm.applyPreset(.freeform)
                    vm.redactions.removeAll()
                    vm.brightness = 0.0
                    vm.contrast = 1.0
                    vm.saturation = 1.0
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(Color.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.regularMaterial)

            Divider()

            // Main Editor Canvas
            ZStack {
                Color.black.opacity(0.12)
                    .ignoresSafeArea()

                Image(nsImage: vm.originalImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(24)
                    .overlay(
                        editorOverlays
                    )
            }
            .frame(minHeight: 380)

            Divider()

            // Contextual Control Panel
            HStack(spacing: 20) {
                switch vm.currentMode {
                case .crop:
                    cropControlBar
                case .annotate:
                    annotateControlBar
                case .adjust:
                    adjustControlBar
                case .background:
                    backgroundControlBar
                }

                Spacer()

                // Actions
                HStack(spacing: 12) {
                    Button("Cancel", action: onCancel)
                        .keyboardShortcut(.cancelAction)

                    Button("Apply & Save") {
                        if let output = vm.executeSave() {
                            onSave(output)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.orange)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.regularMaterial)
        }
        .frame(minWidth: 700, minHeight: 540)
    }

    @ViewBuilder
    private var editorOverlays: some View {
        if vm.currentMode == .crop {
            // Semi-transparent crop guide
            Rectangle()
                .strokeBorder(Color.orange, lineWidth: 2)
                .background(Color.orange.opacity(0.08))
                .padding(24)
        } else if vm.currentMode == .annotate {
            // Render active redactions
            GeometryReader { geo in
                ForEach(vm.redactions) { box in
                    Rectangle()
                        .fill(box.isRedaction ? Color.black : Color.yellow.opacity(0.5))
                        .frame(
                            width: box.rect.size.width * geo.size.width,
                            height: box.rect.size.height * geo.size.height
                        )
                        .position(
                            x: (box.rect.origin.x + box.rect.size.width / 2) * geo.size.width,
                            y: (box.rect.origin.y + box.rect.size.height / 2) * geo.size.height
                        )
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onEnded { value in
                        // Add redaction/highlight box
                        let box = RedactionBox(
                            rect: CGRect(
                                x: min(value.startLocation.x, value.location.x) / 400.0,
                                y: min(value.startLocation.y, value.location.y) / 300.0,
                                width: abs(value.translation.width) / 400.0,
                                height: abs(value.translation.height) / 300.0
                            ),
                            isRedaction: vm.currentToolIsRedact
                        )
                        vm.redactions.append(box)
                    }
            )
        }
    }

    private var cropControlBar: some View {
        HStack(spacing: 16) {
            Picker("Aspect Ratio", selection: $vm.selectedPreset) {
                ForEach(AspectRatioPreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }
            .frame(width: 170)
            .onChange(of: vm.selectedPreset) { _, newPreset in
                vm.applyPreset(newPreset)
            }

            HStack(spacing: 6) {
                Text("W:")
                    .font(.system(size: 11, weight: .bold))
                TextField("Width", value: $vm.cropWidthPx, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                Text("px")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)

                Text("×")
                    .foregroundStyle(Color.secondary)

                Text("H:")
                    .font(.system(size: 11, weight: .bold))
                TextField("Height", value: $vm.cropHeightPx, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                Text("px")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
            }

            Text("Original: \(vm.originalImagePixelWidth) × \(vm.originalImagePixelHeight) px")
                .font(.system(size: 11))
                .foregroundStyle(Color.secondary)
        }
    }

    private var annotateControlBar: some View {
        HStack(spacing: 14) {
            Picker("Tool", selection: $vm.currentToolIsRedact) {
                Text("⬛ Redact (Blackout)").tag(true)
                Text("🟨 Highlight").tag(false)
            }
            .pickerStyle(.segmented)
            .frame(width: 220)

            if !vm.redactions.isEmpty {
                Button("Undo Last") {
                    _ = vm.redactions.popLast()
                }
                Button("Clear All") {
                    vm.redactions.removeAll()
                }
            }

            Text("Drag over any area to redact or highlight")
                .font(.system(size: 11))
                .foregroundStyle(Color.secondary)
        }
    }

    private var adjustControlBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Brightness: \(Int(vm.brightness * 100))%")
                    .font(.system(size: 10))
                Slider(value: $vm.brightness, in: -0.5...0.5)
                    .frame(width: 110)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Contrast: \(Int(vm.contrast * 100))%")
                    .font(.system(size: 10))
                Slider(value: $vm.contrast, in: 0.5...1.8)
                    .frame(width: 110)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Saturation: \(Int(vm.saturation * 100))%")
                    .font(.system(size: 10))
                Slider(value: $vm.saturation, in: 0.0...2.0)
                    .frame(width: 110)
            }
        }
    }

    private var backgroundControlBar: some View {
        HStack(spacing: 16) {
            ColorPicker("Background Color", selection: $vm.bgColor)

            HStack {
                Text("Padding: \(Int(vm.bgPadding)) px")
                    .font(.system(size: 11))
                Slider(value: $vm.bgPadding, in: 0...100, step: 5)
                    .frame(width: 100)
            }
        }
    }
}
