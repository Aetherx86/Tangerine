import Foundation
import AppKit

public struct FileActionsProcessor: Sendable {
    @MainActor
    public static func handle(action: FileActionType, urls: [URL]) {
        guard !urls.isEmpty else { return }

        switch action {
        case .airdrop:
            if let service = NSSharingService(named: .sendViaAirDrop) {
                service.perform(withItems: urls)
            }

        case .float:
            FloatingShelfManager.shared.addFiles(urls)

        case .copy:
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            // In macOS, Finder specifically requires NSFilenamesPboardType with path strings
            // in order for Command+V (Paste) to be enabled and work!
            pasteboard.declareTypes([
                .fileURL,
                NSPasteboard.PasteboardType("NSFilenamesPboardType"),
                NSPasteboard.PasteboardType("public.file-url"),
                .string
            ], owner: nil)

            let paths = urls.map { $0.path }
            pasteboard.setPropertyList(paths, forType: NSPasteboard.PasteboardType("NSFilenamesPboardType"))
            pasteboard.writeObjects(urls as [NSURL])
            pasteboard.setString(paths.joined(separator: "\n"), forType: .string)

            ProgressHUDManager.shared.startJob(title: "Copied!", detail: "\(urls.count) file(s) ready to paste in Finder")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                ProgressHUDManager.shared.hideHUD()
            }

        case .move:
            let openPanel = NSOpenPanel()
            openPanel.canChooseFiles = false
            openPanel.canChooseDirectories = true
            openPanel.allowsMultipleSelection = false
            openPanel.prompt = "Move Here"
            openPanel.message = "Choose destination directory for \(urls.count) item(s):"

            if openPanel.runModal() == .OK, let destDir = openPanel.url {
                var moved: [URL] = []
                for url in urls {
                    let destURL = destDir.appendingPathComponent(url.lastPathComponent)
                    do {
                        try FileManager.default.moveItem(at: url, to: destURL)
                        moved.append(destURL)
                    } catch {
                        print("Failed to move \(url): \(error)")
                    }
                }
                ProgressHUDManager.shared.finishJob(outputURLs: moved)
            }

        case .copyPath:
            let paths = urls.map { $0.path }.joined(separator: "\n")
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(paths, forType: .string)
            ProgressHUDManager.shared.startJob(title: "Path Copied!", detail: "\(urls.count) path(s) to clipboard")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                ProgressHUDManager.shared.hideHUD()
            }

        case .terminal:
            guard let first = urls.first else { return }
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: first.path, isDirectory: &isDir)
            let folder = isDir.boolValue ? first.path : first.deletingLastPathComponent().path

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", "Terminal", folder]
            do {
                try process.run()
                ProgressHUDManager.shared.startJob(title: "Terminal Opened", detail: "At \(URL(fileURLWithPath: folder).lastPathComponent)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    ProgressHUDManager.shared.hideHUD()
                }
            } catch {
                ProgressHUDManager.shared.failJob(error: "Could not open Terminal: \(error.localizedDescription)")
            }
        }
    }
}
