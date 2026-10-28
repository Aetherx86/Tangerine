import Foundation
import UniformTypeIdentifiers

public enum FileCategory: String, CaseIterable, Sendable {
    case image = "Image"
    case video = "Video"
    case audio = "Audio"
    case pdf = "PDF"
    case document = "Document"
    case spreadsheet = "Spreadsheet"
    case presentation = "Presentation"
    case epub = "EPUB"
    case subtitle = "Subtitle"
    case archive = "Archive"
    case generic = "File"

    public static func detect(from urls: [URL]) -> FileCategory {
        guard let first = urls.first else { return .generic }
        let ext = first.pathExtension.lowercased()
        
        // Exact extension checks
        switch ext {
        case "jpg", "jpeg", "png", "webp", "heic", "heif", "tiff", "tif", "bmp", "avif", "gif", "svg":
            return .image
        case "mp4", "mov", "mkv", "avi", "wmv", "webm", "m4v":
            return .video
        case "mp3", "m4a", "wav", "flac", "ogg", "opus", "aiff", "aif", "wma":
            return .audio
        case "pdf":
            return .pdf
        case "epub":
            return .epub
        case "docx", "doc", "pages", "txt", "md", "markdown", "rtf", "rtfd":
            return .document
        case "xlsx", "xls", "ods", "csv", "tsv":
            return .spreadsheet
        case "pptx", "ppt", "key", "keynote":
            return .presentation
        case "srt", "vtt":
            return .subtitle
        case "zip", "tar", "gz", "tgz", "bz2", "rar", "7z":
            return .archive
        default:
            break
        }

        // UTType fallback
        if let utType = UTType(filenameExtension: ext) {
            if utType.conforms(to: .image) { return .image }
            if utType.conforms(to: .movie) || utType.conforms(to: .video) { return .video }
            if utType.conforms(to: .audio) { return .audio }
            if utType.conforms(to: .pdf) { return .pdf }
            if utType.conforms(to: .spreadsheet) { return .spreadsheet }
            if utType.conforms(to: .presentation) { return .presentation }
            if utType.conforms(to: .archive) { return .archive }
            if utType.conforms(to: .plainText) || utType.conforms(to: .compositeContent) { return .document }
        }

        return .generic
    }
}
