import Foundation
import AppKit

public struct WebDragHandler: Sendable {
    /// Extracts files from web browser drag pasteboards (Safari, Chrome, Edge, Firefox)
    public static func extractWebDrop(from pasteboard: NSPasteboard) -> [URL] {
        let fm = FileManager.default
        let downloadsDir = fm.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())

        var resultURLs: [URL] = []

        // 1. Direct Image Payload from Browser
        let imageTypes = [
            ("public.png", "png"),
            ("public.jpeg", "jpg"),
            ("public.tiff", "tiff"),
            ("org.webmproject.webp", "webp"),
            ("com.compuserve.gif", "gif")
        ]

        for (pbType, ext) in imageTypes {
            if let data = pasteboard.data(forType: NSPasteboard.PasteboardType(pbType)), !data.isEmpty {
                let filename = "Browser_Image_\(Int(Date().timeIntervalSince1970)).\(ext)"
                let targetURL = downloadsDir.appendingPathComponent(filename)
                if (try? data.write(to: targetURL)) != nil {
                    resultURLs.append(targetURL)
                    return resultURLs
                }
            }
        }

        // 2. Direct Web Image / File URL
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in urls where !url.isFileURL {
                // If it's a web URL (http / https)
                if url.scheme == "http" || url.scheme == "https" {
                    let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
                    let filename = "Web_Download_\(Int(Date().timeIntervalSince1970)).\(ext)"
                    let targetURL = downloadsDir.appendingPathComponent(filename)
                    if let data = try? Data(contentsOf: url) {
                        if (try? data.write(to: targetURL)) != nil {
                            resultURLs.append(targetURL)
                        }
                    }
                }
            }
        }

        return resultURLs
    }
}
