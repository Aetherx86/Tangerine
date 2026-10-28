import Foundation
import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
public final class RadialWheelController: ObservableObject {
    public static let shared = RadialWheelController()

    @Published public var isVisible: Bool = false
    @Published public var slices: [RadialSlice] = []
    @Published public var hoveredIndex: Int? = nil
    @Published public var centerText: String = ""
    @Published public var subtitleText: String = ""
    @Published public var currentCategory: FileCategory = .image
    @Published public var currentURLs: [URL] = []
    @Published public var currentMode: WheelMode = .convert
    @Published public var currentSide: Int = 1

    private var panel: RadialWheelPanel?

    private init() {}

    public func flipSide() {
        SoundManager.shared.playHoverTick()
        if currentSide == 1 {
            currentSide = 2
            let ext = currentURLs.first?.pathExtension ?? ""
            if currentMode == .convert {
                self.slices = RadialSlice.slices(for: currentCategory, mode: .tools, currentExtension: ext)
                self.subtitleText = "Side 2: File Tools (Tab / Scroll to flip)"
            } else if currentMode == .tools {
                self.slices = RadialSlice.slices(for: currentCategory, mode: .actions, currentExtension: ext)
                self.subtitleText = "Side 2: File Actions (Tab / Scroll to flip)"
            } else {
                self.slices = RadialSlice.slices(for: currentCategory, mode: .convert, currentExtension: ext)
                self.subtitleText = "Side 2: Formats (Tab / Scroll to flip)"
            }
        } else {
            currentSide = 1
            let ext = currentURLs.first?.pathExtension ?? ""
            self.slices = RadialSlice.slices(for: currentCategory, mode: currentMode, currentExtension: ext)
            self.subtitleText = "Side 1: Primary (Tab / Scroll to flip)"
        }
        self.hoveredIndex = nil
    }

    public func show(at screenPoint: NSPoint, mode: WheelMode, urls: [URL] = []) {
        self.currentMode = mode
        self.currentSide = 1
        self.currentURLs = urls
        self.currentCategory = FileCategory.detect(from: urls)

        let ext = urls.first?.pathExtension ?? ""
        self.slices = RadialSlice.slices(for: currentCategory, mode: mode, currentExtension: ext)
        // IMPORTANT: hoveredIndex is ALWAYS nil initially! Only highlights when cursor enters a wedge!
        self.hoveredIndex = nil

        switch mode {
        case .convert: self.subtitleText = "Convert formats"
        case .tools: self.subtitleText = "File tools"
        case .actions: self.subtitleText = "File actions"
        }

        // Compute file size text if available
        if let first = urls.first, let attrs = try? FileManager.default.attributesOfItem(atPath: first.path),
           let size = attrs[.size] as? Int64 {
            let bcf = ByteCountFormatter()
            bcf.allowedUnits = [.useMB, .useKB, .useBytes]
            bcf.countStyle = .file
            self.centerText = bcf.string(fromByteCount: size)
        } else if !urls.isEmpty {
            self.centerText = "\(urls.count) item\(urls.count == 1 ? "" : "s")"
        } else {
            self.centerText = ""
        }

        if panel == nil {
            panel = RadialWheelPanel(controller: self)
        }

        let panelSize: CGFloat = 360
        let origin = NSPoint(x: screenPoint.x - panelSize / 2, y: screenPoint.y - panelSize / 2)
        panel?.setFrameOrigin(origin)
        panel?.orderFrontRegardless()
        isVisible = true
    }

    public func hide() {
        panel?.orderOut(nil)
        isVisible = false
        hoveredIndex = nil
        currentURLs = []
    }

    public func executeSelectedSlice(urls: [URL]) {
        guard let idx = hoveredIndex, idx >= 0, idx < slices.count else {
            hide()
            return
        }
        let slice = slices[idx]
        hide()

        Task {
            await ConversionEngine.execute(slice: slice, urls: urls, category: currentCategory)
        }
    }
}

public final class RadialWheelPanel: NSPanel {
    private unowned let controller: RadialWheelController

    public init(controller: RadialWheelController) {
        self.controller = controller
        let rect = NSRect(x: 0, y: 0, width: 360, height: 360)

        super.init(
            contentRect: rect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        self.level = .popUpMenu
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.isMovableByWindowBackground = false

        let dropView = RadialDropDestinationView(controller: controller)
        self.contentView = dropView
    }

    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }
}

public final class RadialDropDestinationView: NSView {
    private unowned let controller: RadialWheelController
    private var hostingView: NSHostingView<AnyView>?
    private var lastHoveredIdx: Int? = nil

    public init(controller: RadialWheelController) {
        self.controller = controller
        super.init(frame: NSRect(x: 0, y: 0, width: 360, height: 360))

        registerForDraggedTypes([
            .fileURL,
            NSPasteboard.PasteboardType("public.file-url"),
            NSPasteboard.PasteboardType("NSFilenamesPboardType")
        ])

        let rootView = AnyView(
            RadialWheelContainerView(controller: controller)
        )
        let host = NSHostingView(rootView: rootView)
        host.frame = self.bounds
        host.autoresizingMask = [.width, .height]
        addSubview(host)
        self.hostingView = host
    }

    required init?(coder: NSCoder) { fatalError() }

    // Intercept hit test so this view directly receives all drag tracking callbacks
    public override func hitTest(_ point: NSPoint) -> NSView? {
        return self
    }

    public override func scrollWheel(with event: NSEvent) {
        if abs(event.deltaY) > 1.5 || abs(event.deltaX) > 1.5 {
            controller.flipSide()
        }
    }

    public override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        updateFiles(from: sender)
        updateHover(location: sender.draggingLocation)
        return .copy
    }

    public override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        updateHover(location: sender.draggingLocation)
        return .copy
    }

    public override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        controller.hoveredIndex = nil
        lastHoveredIdx = nil
    }

    public override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let urls = getURLs(from: sender) ?? controller.currentURLs
        guard !urls.isEmpty else {
            controller.hide()
            return false
        }

        if controller.hoveredIndex != nil {
            controller.executeSelectedSlice(urls: urls)
            return true
        } else {
            controller.hide()
            return false
        }
    }

    public override func draggingEnded(_ sender: any NSDraggingInfo) {
        if controller.isVisible {
            controller.hide()
        }
    }

    private func updateFiles(from sender: NSDraggingInfo) {
        if let urls = getURLs(from: sender), !urls.isEmpty {
            controller.currentURLs = urls
            let detected = FileCategory.detect(from: urls)
            controller.currentCategory = detected
            let ext = urls.first?.pathExtension ?? ""
            controller.slices = RadialSlice.slices(for: detected, mode: controller.currentMode, currentExtension: ext)

            if let first = urls.first, let attrs = try? FileManager.default.attributesOfItem(atPath: first.path),
               let size = attrs[.size] as? Int64 {
                let bcf = ByteCountFormatter()
                bcf.allowedUnits = [.useMB, .useKB, .useBytes]
                bcf.countStyle = .file
                controller.centerText = bcf.string(fromByteCount: size)
            }
        }
    }

    private func updateHover(location: NSPoint) {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = sqrt(dx * dx + dy * dy)

        let innerR: CGFloat = 50
        let outerR: CGFloat = 145

        // If outside the donut ring (in center or outside the wheel)
        guard distance >= innerR && distance <= (outerR + 25) else {
            if controller.hoveredIndex != nil {
                controller.hoveredIndex = nil
                lastHoveredIdx = nil
            }
            return
        }

        let count = controller.slices.count
        guard count > 0 else { return }

        // Angle in AppKit (dy > 0 is up)
        let angle = atan2(dy, dx)
        // Convert to clockwise angle from top (+y)
        var angleFromTop = Double.pi / 2.0 - Double(angle)
        if angleFromTop < 0 { angleFromTop += 2.0 * .pi }

        let span = (2.0 * .pi) / Double(count)
        let idx = Int(angleFromTop / span) % count

        if idx != lastHoveredIdx {
            lastHoveredIdx = idx
            controller.hoveredIndex = idx
            SoundManager.shared.playHoverTick()
            SoundManager.shared.triggerHaptic()
        }
    }

    private func getURLs(from sender: NSDraggingInfo) -> [URL]? {
        let pboard = sender.draggingPasteboard
        if let urls = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            return urls
        }
        if let paths = pboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String], !paths.isEmpty {
            return paths.map { URL(fileURLWithPath: $0) }
        }
        return nil
    }
}

public struct RadialWheelContainerView: View {
    @ObservedObject var controller: RadialWheelController

    public var body: some View {
        RadialWheelView(
            slices: controller.slices,
            hoveredIndex: controller.hoveredIndex,
            centerText: controller.centerText,
            subtitleText: controller.subtitleText,
            onSelectSlice: { slice in
                if !controller.currentURLs.isEmpty {
                    controller.executeSelectedSlice(urls: controller.currentURLs)
                }
            }
        )
    }
}
