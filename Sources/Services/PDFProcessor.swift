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
            } else if targetExt == "docx" || targetExt == "rtf" {
                let fullText = (0..<document.pageCount).compactMap { document.page(at: $0)?.string }.joined(separator: "\n\n")
                let attr = NSAttributedString(string: fullText, attributes: [
                    .font: NSFont.systemFont(ofSize: 12),
                    .foregroundColor: NSColor.black
                ])
                let docType: NSAttributedString.DocumentType = targetExt == "docx" ? .officeOpenXML : .rtf
                let outputURL = folder.appendingPathComponent("\(baseName).\(targetExt)")
                if let docData = try? attr.data(from: NSRange(location: 0, length: attr.length), documentAttributes: [.documentType: docType]) {
                    try docData.write(to: outputURL)
                    results.append(outputURL)
                }
            } else if targetExt == "html" {
                var html = "<!DOCTYPE html>\n<html><head><meta charset=\"utf-8\"><title>\(baseName)</title><style>body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;max-width:800px;margin:40px auto;padding:0 20px;line-height:1.6;color:#333;}.page{background:#fff;padding:30px;border-radius:8px;box-shadow:0 2px 8px rgba(0,0,0,0.08);margin-bottom:30px;}h2{color:#FF6B00;border-bottom:1px solid #eee;padding-bottom:8px;}</style></head><body>\n"
                for i in 0..<document.pageCount {
                    if let page = document.page(at: i), let pageString = page.string {
                        html += "<div class=\"page\"><h2>Page \(i + 1)</h2><p>\(pageString.replacingOccurrences(of: "\n", with: "<br/>"))</p></div>\n"
                    }
                }
                html += "</body></html>"
                let outputURL = folder.appendingPathComponent("\(baseName).html")
                try html.write(to: outputURL, atomically: true, encoding: .utf8)
                results.append(outputURL)
            } else if targetExt == "epub" {
                let fullText = (0..<document.pageCount).compactMap { document.page(at: $0)?.string }.joined(separator: "\n\n")
                let outputURL = folder.appendingPathComponent("\(baseName).epub")
                try DocumentProcessor.createEPUB(title: baseName, text: fullText, destinationURL: outputURL)
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

    /// Merges multiple PDFs or image files into a single unified PDF (matches Filee's merge feature)
    public static func merge(urls: [URL]) async throws -> [URL] {
        guard !urls.isEmpty else { return [] }
        let mergedDoc = PDFDocument()
        var pageIndex = 0

        for url in urls {
            if url.pathExtension.lowercased() == "pdf", let doc = PDFDocument(url: url) {
                for i in 0..<doc.pageCount {
                    if let page = doc.page(at: i) {
                        mergedDoc.insert(page, at: pageIndex)
                        pageIndex += 1
                    }
                }
            } else if let image = NSImage(contentsOf: url), let page = PDFPage(image: image) {
                mergedDoc.insert(page, at: pageIndex)
                pageIndex += 1
            }
        }

        let firstURL = urls[0]
        let base = firstURL.deletingPathExtension().lastPathComponent
        let outputURL = firstURL.deletingLastPathComponent().appendingPathComponent("\(base)_merged.pdf")
        mergedDoc.write(to: outputURL)
        return [outputURL]
    }
}
