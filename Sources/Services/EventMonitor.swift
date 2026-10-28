import Foundation
import ApplicationServices
import AppKit

@MainActor
public final class EventMonitor: ObservableObject {
    public static let shared = EventMonitor()

    private var machPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var retryTimer: Timer?
    private var isMouseDown: Bool = false
    private var isDragging: Bool = false
    private var lastKeyTime: Date = Date.distantPast
    private var globalEventMonitor: Any?

    private init() {}

    public func start() {
        stop()
        setupEventTap()

        // Backup global monitor for key/mouse events
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            Task { @MainActor in
                self?.handleNSEvent(event)
            }
        }

        // If tap couldn't be created (e.g. waiting for accessibility), poll every 2 seconds
        if machPort == nil {
            retryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    if AXIsProcessTrusted() {
                        self?.setupEventTap()
                        if self?.machPort != nil {
                            self?.retryTimer?.invalidate()
                            self?.retryTimer = nil
                        }
                    }
                }
            }
        }
    }

    public func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        if let port = machPort {
            CFMachPortInvalidate(port)
            machPort = nil
        }
        if let gm = globalEventMonitor {
            NSEvent.removeMonitor(gm)
            globalEventMonitor = nil
        }
        retryTimer?.invalidate()
        retryTimer = nil
    }

    private func setupEventTap() {
        guard AXIsProcessTrusted() else { return }

        let mask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue) |
                                (1 << CGEventType.leftMouseDragged.rawValue) |
                                (1 << CGEventType.leftMouseUp.rawValue) |
                                (1 << CGEventType.flagsChanged.rawValue) |
                                (1 << CGEventType.keyDown.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        machPort = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<EventMonitor>.fromOpaque(refcon).takeUnretainedValue()
                monitor.processCGEvent(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: refcon
        )

        if let machPort = machPort {
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, machPort, 0)
            self.runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            print("🍊 Tangerine: CGEventTap successfully initialized!")
        }
    }

    nonisolated private func processCGEvent(type: CGEventType, event: CGEvent) {
        let flags = event.flags
        Task { @MainActor in
            self.handleEvent(type: type, flags: flags)
        }
    }

    private func handleEvent(type: CGEventType, flags: CGEventFlags) {
        switch type {
        case .leftMouseDown:
            isMouseDown = true
            isDragging = false

        case .leftMouseDragged:
            isMouseDown = true
            isDragging = true

        case .leftMouseUp:
            isMouseDown = false
            isDragging = false
            // Dismiss if open and drop didn't occur
            if RadialWheelController.shared.isVisible {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    if self.isMouseDown == false && RadialWheelController.shared.isVisible {
                        RadialWheelController.shared.hide()
                    }
                }
            }

        case .keyDown:
            if RadialWheelController.shared.isVisible {
                // Tab key (48) or any key tap while wheel is active flips to Side 2
                RadialWheelController.shared.flipSide()
                return
            }
            checkModifierTrigger(flags: flags)

        case .flagsChanged:
            checkModifierTrigger(flags: flags)

        default:
            break
        }
    }

    private func handleNSEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDragged:
            isMouseDown = true
            isDragging = true
        case .leftMouseUp:
            isMouseDown = false
            isDragging = false
            if RadialWheelController.shared.isVisible {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    if self.isMouseDown == false && RadialWheelController.shared.isVisible {
                        RadialWheelController.shared.hide()
                    }
                }
            }
        case .flagsChanged:
            checkModifierTrigger(flags: CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue)))
        default:
            break
        }
    }

    private func checkModifierTrigger(flags: CGEventFlags) {
        // Is mouse held down anywhere in the OS?
        let isLeftDown = isMouseDown || CGEventSource.buttonState(.combinedSessionState, button: .left)
        guard isLeftDown else { return }

        // Debounce
        let now = Date()
        guard now.timeIntervalSince(lastKeyTime) > 0.15 else { return }

        let store = SettingsStore.shared
        var detectedMode: WheelMode? = nil

        if matchesCGModifier(flags: flags, keyName: store.convertModifierKey) || flags.contains(.maskAlternate) {
            detectedMode = .convert
        } else if matchesCGModifier(flags: flags, keyName: store.toolsModifierKey) {
            detectedMode = .tools
        } else if matchesCGModifier(flags: flags, keyName: store.actionsModifierKey) || flags.contains(.maskControl) {
            detectedMode = .actions
        }

        guard let mode = detectedMode else { return }

        // ONLY trigger if actual files are being dragged!
        // Prevent showing the wheel when the user is dragging across text or selecting text.
        let urls = getActiveDraggedURLs()
        guard !urls.isEmpty else {
            return
        }

        lastKeyTime = now
        let mousePoint = NSEvent.mouseLocation
        RadialWheelController.shared.show(at: mousePoint, mode: mode, urls: urls)
    }

    private func matchesCGModifier(flags: CGEventFlags, keyName: String) -> Bool {
        switch keyName.lowercased() {
        case "shift":
            return flags.contains(.maskShift)
        case "command", "cmd":
            return flags.contains(.maskCommand)
        case "option", "alt":
            return flags.contains(.maskAlternate)
        case "control", "ctrl":
            return flags.contains(.maskControl)
        default:
            return false
        }
    }

    /// Reads URLs ONLY from active file drag sessions.
    /// Strictly ignores text drags, text selections, and non-file clipboard data.
    public func getActiveDraggedURLs() -> [URL] {
        let dragPb = NSPasteboard(name: .drag)
        guard let types = dragPb.types, !types.isEmpty else {
            return []
        }

        // Strict verification: The drag pasteboard MUST contain file types or web browser drops.
        // If it only contains plain text, RTF, HTML without files, it is a text drag/selection!
        let fileTypeIdentifiers: Set<String> = [
            "public.file-url",
            "NSFilenamesPboardType",
            "com.apple.finder.node",
            NSPasteboard.PasteboardType.fileURL.rawValue,
            "public.png",
            "public.jpeg",
            "public.tiff",
            "org.webmproject.webp",
            "com.apple.pasteboard.promised-file-url"
        ]

        let containsFileType = types.contains { t in
            fileTypeIdentifiers.contains(t.rawValue)
        }

        guard containsFileType else {
            // Text selection or non-file drag — do NOT show wheel!
            return []
        }

        var urls: [URL] = []
        if let items = dragPb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            urls.append(contentsOf: items.filter { $0.isFileURL && FileManager.default.fileExists(atPath: $0.path) })
        }

        if urls.isEmpty, let paths = dragPb.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            urls.append(contentsOf: paths.map { URL(fileURLWithPath: $0) }.filter { FileManager.default.fileExists(atPath: $0.path) })
        }

        // Check browser direct drops (Safari, Chrome, Firefox)
        if urls.isEmpty {
            urls = WebDragHandler.extractWebDrop(from: dragPb)
        }

        return urls
    }

    public func getActiveDraggedOrSelectedURLs() -> [URL] {
        let dragged = getActiveDraggedURLs()
        if !dragged.isEmpty {
            return dragged
        }
        return getFinderSelection()
    }

    public func getFinderSelection() -> [URL] {
        let script = """
        tell application "Finder"
            set theSelection to selection as alias list
            set posixList to {}
            repeat with anItem in theSelection
                set end of posixList to POSIX path of anItem
            end repeat
            return posixList
        end tell
        """
        guard let appleScript = NSAppleScript(source: script) else { return [] }
        var error: NSDictionary?
        let descriptor = appleScript.executeAndReturnError(&error)
        guard error == nil, descriptor.numberOfItems > 0 else { return [] }

        var urls: [URL] = []
        for i in 1...descriptor.numberOfItems {
            if let path = descriptor.atIndex(i)?.stringValue {
                urls.append(URL(fileURLWithPath: path))
            }
        }
        return urls
    }
}
