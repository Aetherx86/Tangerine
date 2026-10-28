import Foundation
import SwiftUI
import AppKit

@MainActor
public final class FloatingShelfManager: ObservableObject {
    public static let shared = FloatingShelfManager()

    @Published public var floatingFiles: [URL] = []
    @Published public var isVisible: Bool = false

    private var shelfWindow: NSPanel?

    private init() {}

    public func addFiles(_ urls: [URL]) {
        for url in urls where !floatingFiles.contains(url) {
            floatingFiles.append(url)
        }
        showShelf()
    }

    public func removeFile(_ url: URL) {
        floatingFiles.removeAll { $0 == url }
        if floatingFiles.isEmpty {
            hideShelf()
        }
    }

    public func clear() {
        floatingFiles.removeAll()
        hideShelf()
    }

    public func showShelf() {
        if shelfWindow == nil {
            setupWindow()
        }
        shelfWindow?.makeKeyAndOrderFront(nil)
        isVisible = true
    }

    public func hideShelf() {
        shelfWindow?.orderOut(nil)
        isVisible = false
    }

    private func setupWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 20, y: 100, width: 280, height: 360),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true

        let shelfView = FloatingShelfView(manager: self)
        panel.contentView = NSHostingView(rootView: shelfView)
        self.shelfWindow = panel
    }
}
