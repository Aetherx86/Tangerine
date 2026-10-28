import Foundation
import AppKit
import SwiftUI
import TangerineKit

@MainActor
func renderViewToPNG<V: View>(_ view: V, size: CGSize, outputPath: String) {
    let window = NSWindow(
        contentRect: NSRect(origin: .zero, size: size),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.isOpaque = false
    window.backgroundColor = .clear

    let host = NSHostingView(rootView: view)
    host.frame = CGRect(origin: .zero, size: size)
    window.contentView = host
    window.layoutIfNeeded()

    guard let bitmapRep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
        print("Failed to create bitmap rep for \(outputPath)")
        return
    }
    host.cacheDisplay(in: host.bounds, to: bitmapRep)

    if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
        try? pngData.write(to: URL(fileURLWithPath: outputPath))
        print("Rendered: \(outputPath) (\(Int(size.width))x\(Int(size.height)))")
    }
}

@MainActor
func generateAllScreenshots() {
    let fm = FileManager.default
    let outputDir = "/tmp/tangerine_screenshots"
    try? fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

    // 1. Convert Wheel (Shift)
    let convertSlices = RadialSlice.slices(for: .image, mode: .convert, currentExtension: "jpg")
    let convertWheel = RadialWheelView(
        slices: convertSlices,
        hoveredIndex: 0,
        centerText: "PNG",
        subtitleText: "Convert to PNG"
    )
    .padding(20)
    .background(Color.clear)
    renderViewToPNG(convertWheel, size: CGSize(width: 360, height: 380), outputPath: "\(outputDir)/wheel_convert.png")

    // 2. Tools Wheel (Command)
    let toolSlices = RadialSlice.slices(for: .image, mode: .tools)
    let toolsWheel = RadialWheelView(
        slices: toolSlices,
        hoveredIndex: 5,
        centerText: "CROP",
        subtitleText: "Crop & Resize Tool"
    )
    .padding(20)
    .background(Color.clear)
    renderViewToPNG(toolsWheel, size: CGSize(width: 360, height: 380), outputPath: "\(outputDir)/wheel_tools.png")

    // 3. Actions Wheel (Control)
    let actionSlices = RadialSlice.slices(for: .generic, mode: .actions)
    let actionsWheel = RadialWheelView(
        slices: actionSlices,
        hoveredIndex: 5,
        centerText: "TERMINAL",
        subtitleText: "Open Folder in Terminal"
    )
    .padding(20)
    .background(Color.clear)
    renderViewToPNG(actionsWheel, size: CGSize(width: 360, height: 380), outputPath: "\(outputDir)/wheel_actions.png")

    // 4. Crop & Size Selector (ImageEditorView)
    let sampleSource = URL(fileURLWithPath: "Resources/TangerineSlice.png")
    let sampleURL = URL(fileURLWithPath: "\(outputDir)/Tangerine_Capture_4K.jpg")
    if fm.fileExists(atPath: sampleSource.path) {
        try? fm.copyItem(at: sampleSource, to: sampleURL)
    } else {
        let sampleImg = NSImage(size: NSSize(width: 600, height: 400), flipped: false) { rect in
            let gradient = NSGradient(starting: NSColor(red: 1.0, green: 0.5, blue: 0.1, alpha: 1.0), ending: NSColor(red: 0.9, green: 0.25, blue: 0.05, alpha: 1.0))
            gradient?.draw(in: rect, angle: 45)
            return true
        }
        if let tiff = sampleImg.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
           let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: sampleURL)
        }
    }

    let editorVM = ImageEditorViewModel(url: sampleURL, initialMode: .crop)
    editorVM.applyPreset(.square1x1)
    editorVM.cropWidthPx = 800
    editorVM.cropHeightPx = 800

    let editorView = ImageEditorView(
        vm: editorVM,
        onSave: { _ in },
        onCancel: { }
    )
    .frame(width: 720, height: 550)
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
    )
    .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 10)
    .padding(25)

    renderViewToPNG(editorView, size: CGSize(width: 770, height: 600), outputPath: "\(outputDir)/editor_crop.png")

    // 5. Metadata Inspector & Editor
    let metaVM = MetadataEditorViewModel(url: sampleURL)
    metaVM.record = FileMetadataRecord(
        url: sampleURL,
        title: "Tangerine Tree Orchard",
        author: "Jeffrey Kim",
        copyright: "© 2026 Tangerine Pro",
        description: "High resolution citrus capture in 4K ProRes",
        items: [
            FileMetadataItem(category: "Camera", key: "Camera Model", value: "Sony α7R V"),
            FileMetadataItem(category: "Camera", key: "Lens", value: "FE 24-70mm F2.8 GM II"),
            FileMetadataItem(category: "Exposure", key: "Aperture", value: "ƒ/2.8"),
            FileMetadataItem(category: "Exposure", key: "Shutter Speed", value: "1/500 s"),
            FileMetadataItem(category: "Exposure", key: "ISO", value: "100"),
            FileMetadataItem(category: "Location", key: "GPS Coordinates", value: "37.5665° N, 126.9780° E"),
            FileMetadataItem(category: "File", key: "File Size", value: "4.8 MB"),
            FileMetadataItem(category: "Image", key: "Dimensions", value: "3840 × 2160 px")
        ]
    )
    metaVM.titleInput = "Tangerine Tree Orchard"
    metaVM.authorInput = "Jeffrey Kim"
    metaVM.copyrightInput = "© 2026 Tangerine Pro"
    metaVM.descriptionInput = "High resolution citrus capture in 4K ProRes"

    let metaView = MetadataEditorView(
        vm: metaVM,
        onSave: { _ in },
        onClose: { }
    )
    .frame(width: 580, height: 600)
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
    )
    .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 10)
    .padding(25)

    renderViewToPNG(metaView, size: CGSize(width: 630, height: 650), outputPath: "\(outputDir)/metadata_editor.png")

    // 6. Progress HUD
    let hudManager = ProgressHUDManager.shared
    hudManager.currentJob = JobProgress(
        title: "Done!",
        detail: "2 items converted beside original",
        outputURLs: [sampleURL],
        isComplete: true
    )
    let hudView = ProgressHUDView(manager: hudManager)
        .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 6)
        .padding(20)
    renderViewToPNG(hudView, size: CGSize(width: 380, height: 95), outputPath: "\(outputDir)/progress_hud.png")

    print("All screenshots generated successfully in \(outputDir)!")
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
Task { @MainActor in
    generateAllScreenshots()
    exit(0)
}
app.run()
