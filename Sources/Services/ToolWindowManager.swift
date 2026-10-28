import Foundation
import AppKit
import SwiftUI

@MainActor
public final class ToolWindowManager {
    public static let shared = ToolWindowManager()

    private var activeEditorWindow: NSWindow?
    private var activeMetadataWindow: NSWindow?

    private init() {}

    public func openImageEditor(for url: URL, mode: EditorMode = .crop) {
        let vm = ImageEditorViewModel(url: url, initialMode: mode)
        let editorView = ImageEditorView(
            vm: vm,
            onSave: { [weak self] outputURL in
                self?.activeEditorWindow?.close()
                self?.activeEditorWindow = nil
                ProgressHUDManager.shared.finishJob(outputURLs: [outputURL])
            },
            onCancel: { [weak self] in
                self?.activeEditorWindow?.close()
                self?.activeEditorWindow = nil
            }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Tangerine Editor — \(url.lastPathComponent)"
        window.center()
        window.contentView = NSHostingView(rootView: editorView)
        self.activeEditorWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    public func openMetadataEditor(for url: URL) {
        let vm = MetadataEditorViewModel(url: url)
        let metaView = MetadataEditorView(
            vm: vm,
            onSave: { [weak self] outputURL in
                self?.activeMetadataWindow?.close()
                self?.activeMetadataWindow = nil
                ProgressHUDManager.shared.finishJob(outputURLs: [outputURL])
            },
            onClose: { [weak self] in
                self?.activeMetadataWindow?.close()
                self?.activeMetadataWindow = nil
            }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 620),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Metadata Inspector & Editor — \(url.lastPathComponent)"
        window.center()
        window.contentView = NSHostingView(rootView: metaView)
        self.activeMetadataWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
