import Foundation
import SwiftUI
import AppKit

public struct JobProgress: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let detail: String
    public let outputURLs: [URL]
    public let isComplete: Bool
    public let error: String?

    public init(id: UUID = UUID(), title: String, detail: String, outputURLs: [URL] = [], isComplete: Bool = false, error: String? = nil) {
        self.id = id
        self.title = title
        self.detail = detail
        self.outputURLs = outputURLs
        self.isComplete = isComplete
        self.error = error
    }
}

@MainActor
public final class ProgressHUDManager: ObservableObject {
    public static let shared = ProgressHUDManager()

    @Published public var currentJob: JobProgress?
    private var hudWindow: NSPanel?

    private init() {}

    public func startJob(title: String, detail: String) {
        currentJob = JobProgress(title: title, detail: detail, isComplete: false)
        showHUD()
    }

    public func finishJob(outputURLs: [URL]) {
        guard let current = currentJob else { return }
        currentJob = JobProgress(id: current.id, title: "Done!", detail: "\(outputURLs.count) item(s) ready", outputURLs: outputURLs, isComplete: true)
        SoundManager.shared.playSuccess()

        if SettingsStore.shared.revealInFinder, !outputURLs.isEmpty {
            NSWorkspace.shared.activateFileViewerSelecting(outputURLs)
        }

        // Auto dismiss after 4 seconds
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if self.currentJob?.id == current.id {
                self.hideHUD()
            }
        }
    }

    public func failJob(error: String) {
        guard let current = currentJob else { return }
        currentJob = JobProgress(id: current.id, title: "Failed", detail: error, isComplete: true, error: error)
    }

    public func showHUD() {
        if hudWindow == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 260, height: 80),
                styleMask: [.nonactivatingPanel, .borderless],
                backing: .buffered,
                defer: false
            )
            panel.level = .floating
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.contentView = NSHostingView(rootView: ProgressHUDView(manager: self))
            self.hudWindow = panel
        }

        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.maxX - 280
            let y = screenRect.maxY - 100
            hudWindow?.setFrameOrigin(NSPoint(x: x, y: y))
        }

        hudWindow?.orderFront(nil)
    }

    public func hideHUD() {
        hudWindow?.orderOut(nil)
        currentJob = nil
    }
}
