import Foundation

public struct ConversionMatrix: Sendable {
    public static func validTargets(for category: FileCategory, currentExtension ext: String = "") -> [String] {
        let normExt = ext.lowercased()
        switch category {
        case .image:
            var list = ["JPG", "PNG", "WEBP", "HEIC", "TIFF", "AVIF", "BMP", "PDF"]
            let norm = (normExt == "jpeg" ? "jpg" : normExt).uppercased()
            list.removeAll { $0 == norm }
            return list

        case .video:
            var list = ["MP4", "MOV", "MKV", "WEBM", "AVI", "WMV", "GIF", "MP3"]
            list.removeAll { $0 == normExt.uppercased() }
            return list

        case .audio:
            var list = ["M4A", "WAV", "FLAC", "OGG", "OPUS", "AIFF", "WMA", "MP3"]
            list.removeAll { $0 == normExt.uppercased() }
            return list

        case .pdf:
            return ["DOCX", "PAGES", "PPTX", "XLSX", "JPG", "PNG", "EPUB", "TXT", "MD"]

        case .document:
            // Strictly NO JPG/PNG for documents!
            var list = ["PAGES", "PDF", "TXT", "MD", "HTML", "EPUB", "DOCX"]
            let norm = (normExt == "markdown" ? "md" : normExt).uppercased()
            list.removeAll { $0 == norm }
            return list

        case .epub:
            return ["PDF", "DOCX", "PAGES", "TXT", "MD", "HTML"]

        case .spreadsheet:
            var list = ["ODS", "PDF", "TSV", "CSV", "XLSX"]
            list.removeAll { $0 == normExt.uppercased() }
            return list

        case .presentation:
            return ["PDF", "JPG", "PNG"]

        case .subtitle:
            var list = ["VTT", "TXT", "SRT"]
            list.removeAll { $0 == normExt.uppercased() }
            return list

        case .archive:
            var list = ["TAR", "GZIP", "ZIP"]
            let norm = (normExt == "gz" || normExt == "tgz" ? "gzip" : normExt).uppercased()
            list.removeAll { $0 == norm }
            return list

        case .generic:
            return ["PDF", "ZIP", "TXT"]
        }
    }

    public static func validTargets(for sourceExtension: String) -> [String] {
        let cat = FileCategory.detect(from: [URL(fileURLWithPath: "test.\(sourceExtension.lowercased())")])
        return validTargets(for: cat, currentExtension: sourceExtension)
    }

    public static func isValid(from sourceExtension: String, to targetExtension: String) -> Bool {
        let targets = validTargets(for: sourceExtension).map { $0.lowercased() }
        let normTarget = (targetExtension == "jpeg" ? "jpg" : (targetExtension == "gz" ? "gzip" : targetExtension)).lowercased()
        return targets.contains(normTarget)
    }

    public static func supportedDescription(for sourceExtension: String) -> String {
        let targets = validTargets(for: sourceExtension)
        if targets.isEmpty {
            return "No conversions available for .\(sourceExtension)"
        }
        return "Allowed targets for .\(sourceExtension): " + targets.joined(separator: ", ")
    }
}
