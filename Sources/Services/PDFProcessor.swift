import Foundation
import PDFKit
import AppKit

public struct PDFProcessor: Sendable {
    public static func convert(urls: [URL], toExtension ext: String, dpi: Double = 300.0) async throws -> [URL] {
        var results: [URL] = []
        let targetExt = ext.lowercased()

        for url in urls {
            guard let document = PDFDocument(url: url) else { continue }
            let baseName = url.deletingPathExtension().lastPathComponent
            let folder = url.deletingLastPathComponent()

            if targetExt == "jpg" || targetExt == "png" {
                // Export each page as image at 300 DPI
                let pageCount = document.pageCount
                for i in 0..<pageCount {
                    guard let page = document.page(at: i) else { continue }
                    let pageRect = page.bounds(for: .mediaBox)
                    let scale = dpi / 72.0
                    let pixelSize = NSSize(width: pageRect.width * scale, height: pageRect.height * scale)

                    let image = NSImage(size: pixelSize, flipped: false) { rect in
                        guard let context = NSGraphicsContext.current?.cgContext else { return false }
                        context.setFillColor(NSColor.white.cgColor)
                        context.fill(rect)
                        context.saveGState()
                        context.scaleBy(x: scale, y: scale)
                        page.draw(with: .mediaBox, to: context)
                        context.restoreGState()
                        return true
                    }

                    let pageFileName = pageCount > 1 ? "\(baseName)_page_\(i + 1).\(targetExt)" : "\(baseName).\(targetExt)"
                    let pageURL = folder.appendingPathComponent(pageFileName)

                    if let tiff = image.tiffRepresentation,
                       let rep = NSBitmapImageRep(data: tiff) {
                        let fileType: NSBitmapImageRep.FileType = targetExt == "png" ? .png : .jpeg
                        let data = rep.representation(using: fileType, properties: [.compressionFactor: 0.9])
                        try data?.write(to: pageURL)
                        results.append(pageURL)
                    }
                }
            } else if targetExt == "txt" || targetExt == "md" {
                // Extract full text from PDF
                var fullText = ""
                for i in 0..<document.pageCount {
                    if let page = document.page(at: i), let pageString = page.string {
                        if targetExt == "md" {
                            fullText += "## Page \(i + 1)\n\n\(pageString)\n\n"
                        } else {
                            fullText += pageString + "\n\n"
                        }
                    }
                }
                let outputURL = folder.appendingPathComponent("\(baseName).\(targetExt)")
                try fullText.write(to: outputURL, atomically: true, encoding: .utf8)
                results.append(outputURL)
            } else {
                // Other document formats: save text extraction or formatted export
                let outputURL = folder.appendingPathComponent("\(baseName).\(targetExt)")
                let str = document.string ?? ""
                try str.write(to: outputURL, atomically: true, encoding: .utf8)
                results.append(outputURL)
            }
        }

        return results
    }

    public static func split(urls: [URL]) async throws -> [URL] {
        var results: [URL] = []
        for url in urls {
            guard let document = PDFDocument(url: url) else { continue }
            let baseName = url.deletingPathExtension().lastPathComponent
            let folder = url.deletingLastPathComponent()

            for i in 0..<document.pageCount {
                guard let page = document.page(at: i) else { continue }
                let newDoc = PDFDocument()
                newDoc.insert(page, at: 0)

                let pageURL = folder.appendingPathComponent("\(baseName)_page_\(i + 1).pdf")
                newDoc.write(to: pageURL)
                results.append(pageURL)
            }
        }
        return results
    }

    public static func compress(urls: [URL]) async throws -> [URL] {
        var results: [URL] = []
        for url in urls {
            guard let document = PDFDocument(url: url) else { continue }
            let baseName = url.deletingPathExtension().lastPathComponent
            let outputURL = url.deletingLastPathComponent().appendingPathComponent("\(baseName)_compressed.pdf")

            // Resample pages into a clean compressed document
            let compressedDoc = PDFDocument()
            for i in 0..<document.pageCount {
                guard let page = document.page(at: i) else { continue }
                let pageRect = page.bounds(for: .mediaBox)
                let image = NSImage(size: pageRect.size, flipped: false) { rect in
                    guard let context = NSGraphicsContext.current?.cgContext else { return false }
                    context.setFillColor(NSColor.white.cgColor)
                    context.fill(rect)
                    page.draw(with: .mediaBox, to: context)
                    return true
                }
                if let newPage = PDFPage(image: image) {
                    compressedDoc.insert(newPage, at: i)
                }
            }

            compressedDoc.write(to: outputURL)
            results.append(outputURL)
        }
        return results
    }
}
