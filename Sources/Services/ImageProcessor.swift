import Foundation
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import PDFKit

public struct ImageProcessor: Sendable {
    public static func convert(urls: [URL], toExtension ext: String, quality: Double = 0.88) async throws -> [URL] {
        var results: [URL] = []
        let targetExt = ext.lowercased()

        for url in urls {
            let outputURL = destinationURL(for: url, newExtension: targetExt)

            if targetExt == "pdf" {
                // Image to PDF
                if let image = NSImage(contentsOf: url), let pdfData = imageToPDF(image) {
                    try pdfData.write(to: outputURL)
                    results.append(outputURL)
                }
                continue
            }

            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                // Fallback via NSImage
                if let nsImage = NSImage(contentsOf: url),
                   let cg = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    try writeCGImage(cg, to: outputURL, format: targetExt, quality: quality)
                    results.append(outputURL)
                }
                continue
            }

            try writeCGImage(cgImage, to: outputURL, format: targetExt, quality: quality)
            results.append(outputURL)
        }

        return results
    }

    public static func compress(urls: [URL], quality: Double = 0.65) async throws -> [URL] {
        var results: [URL] = []
        for url in urls {
            let ext = url.pathExtension.lowercased()
            let base = url.deletingPathExtension().lastPathComponent
            let outputURL = url.deletingLastPathComponent().appendingPathComponent("\(base)_compressed.\(ext)")

            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                continue
            }

            try writeCGImage(cgImage, to: outputURL, format: ext, quality: quality)
            results.append(outputURL)
        }
        return results
    }

    public static func stripMetadata(urls: [URL]) async throws -> [URL] {
        var results: [URL] = []
        for url in urls {
            let ext = url.pathExtension.lowercased()
            let base = url.deletingPathExtension().lastPathComponent
            let outputURL = url.deletingLastPathComponent().appendingPathComponent("\(base)_nometa.\(ext)")

            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                continue
            }

            // Write image with empty metadata dictionary
            try writeCGImage(cgImage, to: outputURL, format: ext, quality: 0.95, stripMetadata: true)
            results.append(outputURL)
        }
        return results
    }

    public static func cropSquare(urls: [URL]) async throws -> [URL] {
        var results: [URL] = []
        for url in urls {
            let ext = url.pathExtension.lowercased()
            let base = url.deletingPathExtension().lastPathComponent
            let outputURL = url.deletingLastPathComponent().appendingPathComponent("\(base)_cropped.\(ext)")

            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                continue
            }

            let w = cgImage.width
            let h = cgImage.height
            let minDim = min(w, h)
            let cropRect = CGRect(x: (w - minDim) / 2, y: (h - minDim) / 2, width: minDim, height: minDim)

            if let cropped = cgImage.cropping(to: cropRect) {
                try writeCGImage(cropped, to: outputURL, format: ext, quality: 0.9)
                results.append(outputURL)
            }
        }
        return results
    }

    public static func addBackground(urls: [URL], bgColor: NSColor = .white) async throws -> [URL] {
        var results: [URL] = []
        for url in urls {
            let ext = url.pathExtension.lowercased()
            let base = url.deletingPathExtension().lastPathComponent
            let outputURL = url.deletingLastPathComponent().appendingPathComponent("\(base)_with_bg.\(ext)")

            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                continue
            }

            let width = cgImage.width
            let height = cgImage.height
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { continue }

            context.setFillColor(bgColor.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

            if let newImage = context.makeImage() {
                try writeCGImage(newImage, to: outputURL, format: ext, quality: 0.9)
                results.append(outputURL)
            }
        }
        return results
    }

    private static func writeCGImage(
        _ image: CGImage,
        to outputURL: URL,
        format: String,
        quality: Double,
        stripMetadata: Bool = false
    ) throws {
        let utType: UTType
        switch format.lowercased() {
        case "png": utType = .png
        case "jpg", "jpeg": utType = .jpeg
        case "webp": utType = UTType("org.webmproject.webp") ?? .png
        case "heic": utType = .heic
        case "tiff", "tif": utType = .tiff
        case "bmp": utType = .bmp
        case "avif": utType = UTType("public.avif") ?? .png
        default: utType = .png
        }

        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, utType.identifier as CFString, 1, nil) else {
            throw NSError(domain: "Tangerine", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create image destination for \(utType.identifier)"])
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]

        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        if !CGImageDestinationFinalize(destination) {
            throw NSError(domain: "Tangerine", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to finalize image destination"])
        }
    }

    private static func imageToPDF(_ image: NSImage) -> Data? {
        let pdfData = NSMutableData()
        let rect = CGRect(origin: .zero, size: image.size)
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            return nil
        }

        context.beginPage(mediaBox: nil)
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context.draw(cgImage, in: rect)
        }
        context.endPage()
        context.closePDF()
        return pdfData as Data
    }

    public static func destinationURL(for sourceURL: URL, newExtension: String) -> URL {
        let folder = sourceURL.deletingLastPathComponent()
        let name = sourceURL.deletingPathExtension().lastPathComponent
        var target = folder.appendingPathComponent("\(name).\(newExtension)")
        var counter = 1
        while FileManager.default.fileExists(atPath: target.path) {
            target = folder.appendingPathComponent("\(name)_\(counter).\(newExtension)")
            counter += 1
        }
        return target
    }
}
