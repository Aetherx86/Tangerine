import Foundation
import ImageIO
import AppKit
import AVFoundation
import PDFKit

public struct FileMetadataItem: Identifiable, Sendable {
    public let id: String
    public let category: String
    public let key: String
    public var value: String

    public init(category: String, key: String, value: String) {
        self.id = "\(category)_\(key)"
        self.category = category
        self.key = key
        self.value = value
    }
}

public struct FileMetadataRecord: Sendable {
    public let url: URL
    public var title: String
    public var author: String
    public var copyright: String
    public var description: String
    public var items: [FileMetadataItem]

    public init(url: URL, title: String = "", author: String = "", copyright: String = "", description: String = "", items: [FileMetadataItem] = []) {
        self.url = url
        self.title = title
        self.author = author
        self.copyright = copyright
        self.description = description
        self.items = items
    }
}

private struct ExifToolResponse: Codable {
    let fields: [ExifToolField]?
}

private struct ExifToolField: Codable {
    let key: String?
    let value: String?
    let scope: String?
    let editable: Bool?
    let original: String?
}

public struct MetadataReader: Sendable {
    public static func readMetadata(for url: URL) -> FileMetadataRecord {
        var items: [FileMetadataItem] = []
        var title = ""
        var author = ""
        var copyright = ""
        var desc = ""

        // 1. Try ExifTool Perl script if available
        if let perlURL = findExifToolScript() {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
            process.arguments = [perlURL.path, "read", url.path]
            process.standardOutput = pipe
            process.standardError = Pipe()

            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let response = try? JSONDecoder().decode(ExifToolResponse.self, from: data),
                   let fields = response.fields, !fields.isEmpty {
                    for f in fields {
                        guard let k = f.key else { continue }
                        let v = f.value ?? f.original ?? ""
                        if v.isEmpty || v == "[Binary data]" { continue }
                        let scope = f.scope ?? "Metadata"

                        items.append(FileMetadataItem(category: scope, key: k, value: v))

                        // Match common editable keys
                        let lowerK = k.lowercased()
                        if lowerK == "title" || lowerK == "objectname" { title = v }
                        else if lowerK == "author" || lowerK == "byline" || lowerK == "artist" { author = v }
                        else if lowerK == "copyright" || lowerK == "copyrightnotice" { copyright = v }
                        else if lowerK == "description" || lowerK == "caption-abstract" { desc = v }
                    }
                }
            } catch {
                print("ExifTool execution error: \(error)")
            }
        }

        // 2. Add native macOS fallback / file system attributes if items is empty
        if items.isEmpty {
            let fallback = readNativeMetadata(for: url)
            items = fallback.items
            if title.isEmpty { title = fallback.title }
            if author.isEmpty { author = fallback.author }
            if copyright.isEmpty { copyright = fallback.copyright }
            if desc.isEmpty { desc = fallback.description }
        }

        // Always ensure basic file attributes exist
        if !items.contains(where: { $0.category == "File" && $0.key == "File Size" }) {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) {
                if let size = attrs[.size] as? Int64 {
                    let bcf = ByteCountFormatter()
                    bcf.countStyle = .file
                    items.insert(FileMetadataItem(category: "File", key: "File Size", value: bcf.string(fromByteCount: size)), at: 0)
                }
                if let date = attrs[.creationDate] as? Date {
                    items.append(FileMetadataItem(category: "File", key: "Created", value: date.formatted(date: .abbreviated, time: .shortened)))
                }
            }
        }

        return FileMetadataRecord(
            url: url,
            title: title,
            author: author,
            copyright: copyright,
            description: desc,
            items: items
        )
    }

    private static func findExifToolScript() -> URL? {
        if let script = Bundle.main.url(forResource: "tangerine_metadata", withExtension: "pl", subdirectory: "ExifTool") {
            return script
        }
        let local = URL(fileURLWithPath: "Resources/ExifTool/tangerine_metadata.pl")
        if FileManager.default.fileExists(atPath: local.path) {
            return local
        }
        return nil
    }

    private static func readNativeMetadata(for url: URL) -> FileMetadataRecord {
        let ext = url.pathExtension.lowercased()
        let cat = FileCategory.detect(from: [url])

        var items: [FileMetadataItem] = []
        var title = ""
        var author = ""
        var copyright = ""
        var desc = ""

        if cat == .image {
            if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
               let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {

                if let w = props[kCGImagePropertyPixelWidth] as? Int, let h = props[kCGImagePropertyPixelHeight] as? Int {
                    items.append(FileMetadataItem(category: "Image", key: "Dimensions", value: "\(w) × \(h) px"))
                }
                if let cs = props[kCGImagePropertyColorModel] as? String {
                    items.append(FileMetadataItem(category: "Image", key: "Color Model", value: cs))
                }

                if let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
                    if let make = tiff[kCGImagePropertyTIFFMake] as? String {
                        items.append(FileMetadataItem(category: "Camera", key: "Camera Make", value: make))
                    }
                    if let model = tiff[kCGImagePropertyTIFFModel] as? String {
                        items.append(FileMetadataItem(category: "Camera", key: "Camera Model", value: model))
                    }
                    if let cr = tiff[kCGImagePropertyTIFFCopyright] as? String {
                        copyright = cr
                        items.append(FileMetadataItem(category: "Attribution", key: "Copyright", value: cr))
                    }
                }

                if let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any] {
                    if let lens = exif[kCGImagePropertyExifLensModel] as? String {
                        items.append(FileMetadataItem(category: "Camera", key: "Lens", value: lens))
                    }
                    if let iso = (exif[kCGImagePropertyExifISOSpeedRatings] as? [Int])?.first {
                        items.append(FileMetadataItem(category: "Exposure", key: "ISO", value: "\(iso)"))
                    }
                    if let f = exif[kCGImagePropertyExifFNumber] as? Double {
                        items.append(FileMetadataItem(category: "Exposure", key: "Aperture", value: String(format: "ƒ/%.1f", f)))
                    }
                    if let dt = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
                        items.append(FileMetadataItem(category: "Camera", key: "Date Taken", value: dt))
                    }
                }

                if let iptc = props[kCGImagePropertyIPTCDictionary] as? [CFString: Any] {
                    if let t = iptc[kCGImagePropertyIPTCObjectName] as? String { title = t }
                    if let by = iptc[kCGImagePropertyIPTCByline] as? String { author = by }
                    if let d = iptc[kCGImagePropertyIPTCCaptionAbstract] as? String { desc = d }
                }

                if let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any] {
                    if let lat = gps[kCGImagePropertyGPSLatitude] as? Double,
                       let lon = gps[kCGImagePropertyGPSLongitude] as? Double {
                        items.append(FileMetadataItem(category: "Location", key: "GPS Coordinates", value: String(format: "%.4f, %.4f", lat, lon)))
                    }
                }
            }
        } else if cat == .pdf {
            if let doc = PDFDocument(url: url) {
                items.append(FileMetadataItem(category: "PDF", key: "Page Count", value: "\(doc.pageCount)"))
                if let attrs = doc.documentAttributes {
                    if let t = attrs[PDFDocumentAttribute.titleAttribute] as? String { title = t }
                    if let a = attrs[PDFDocumentAttribute.authorAttribute] as? String { author = a }
                    if let s = attrs[PDFDocumentAttribute.subjectAttribute] as? String { desc = s }
                }
            }
        }

        return FileMetadataRecord(
            url: url,
            title: title,
            author: author,
            copyright: copyright,
            description: desc,
            items: items
        )
    }

    public static func saveMetadata(record: FileMetadataRecord, outputURL: URL) throws {
        let url = record.url
        let cat = FileCategory.detect(from: [url])

        if cat == .image {
            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let utType = CGImageSourceGetType(imageSource) else {
                throw NSError(domain: "Tangerine", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to open image source"])
            }

            guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, utType, 1, nil) else {
                throw NSError(domain: "Tangerine", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create image destination"])
            }

            var props = (CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any]) ?? [:]

            var iptc = (props[kCGImagePropertyIPTCDictionary] as? [CFString: Any]) ?? [:]
            if !record.title.isEmpty { iptc[kCGImagePropertyIPTCObjectName] = record.title }
            if !record.author.isEmpty { iptc[kCGImagePropertyIPTCByline] = record.author }
            if !record.description.isEmpty { iptc[kCGImagePropertyIPTCCaptionAbstract] = record.description }
            props[kCGImagePropertyIPTCDictionary] = iptc

            var tiff = (props[kCGImagePropertyTIFFDictionary] as? [CFString: Any]) ?? [:]
            if !record.copyright.isEmpty { tiff[kCGImagePropertyTIFFCopyright] = record.copyright }
            props[kCGImagePropertyTIFFDictionary] = tiff

            CGImageDestinationAddImageFromSource(destination, imageSource, 0, props as CFDictionary)
            if !CGImageDestinationFinalize(destination) {
                throw NSError(domain: "Tangerine", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to save image with updated metadata"])
            }
        } else if cat == .pdf {
            guard let doc = PDFDocument(url: url) else {
                throw NSError(domain: "Tangerine", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to open PDF"])
            }
            var attrs = doc.documentAttributes ?? [:]
            if !record.title.isEmpty { attrs[PDFDocumentAttribute.titleAttribute] = record.title }
            if !record.author.isEmpty { attrs[PDFDocumentAttribute.authorAttribute] = record.author }
            if !record.description.isEmpty { attrs[PDFDocumentAttribute.subjectAttribute] = record.description }
            doc.documentAttributes = attrs
            doc.write(to: outputURL)
        }
    }
}
