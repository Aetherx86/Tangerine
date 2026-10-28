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
    case vector = "Vector"
    case cad = "CAD"
    case font = "Font"
    case model3D = "3D Model"
    case geo = "Geospatial"
    case generic = "File"

    public static func detect(from urls: [URL]) -> FileCategory {
        guard let first = urls.first else { return .generic }
        let ext = first.pathExtension.lowercased()
        
        // Exact extension checks matching Filee 268-format registry
        switch ext {
        case "jpg", "jpeg", "png", "webp", "heic", "heif", "tiff", "tif", "bmp", "avif", "gif", "ico", "icns", "psd", "psb", "tga", "ppm", "cur", "xpm", "qoi", "dds", "pcx", "dng", "cr2", "cr3", "nef", "arw", "orf", "rw2", "raf", "jp2", "jxl", "livp", "exr", "hdr", "fits", "fts":
            return .image

        case "svg", "svgz", "eps", "ps", "ai", "emf", "wmf", "cdr", "vsd", "odg", "fodg":
            return .vector

        case "dwg", "dxf":
            return .cad

        case "ttf", "otf", "woff", "woff2", "eot", "fon":
            return .font

        case "glb", "gltf", "stl", "obj", "3mf", "ply", "fbx":
            return .model3D

        case "geojson", "kml", "kmz", "gpx", "shp", "fit":
            return .geo

        case "mp4", "mov", "mkv", "avi", "wmv", "webm", "m4v", "flv", "ts", "m2ts", "3gp", "3g2", "ogv", "vob", "mpg", "mpeg", "dav", "h264", "h265":
            return .video

        case "mp3", "m4a", "wav", "flac", "ogg", "opus", "aiff", "aif", "wma", "aac", "alac", "ac3", "eac3", "amr", "caf", "wv", "tta", "ape", "dsf", "dff", "dts":
            return .audio

        case "pdf":
            return .pdf

        case "epub", "kepub", "mobi", "azw3", "azw", "azw4", "fb2", "cbz", "cbr", "cb7", "chm", "lit", "lrf", "pdb":
            return .epub

        case "docx", "docm", "dotx", "dotm", "doc", "dot", "odt", "fodt", "ott", "rtf", "rtfd", "pages", "ofd", "wpd", "hwp", "hwpx", "txt", "log", "md", "markdown", "html", "htm", "rst", "tex", "org", "adoc", "typ", "ipynb", "eml", "msg":
            return .document

        case "xlsx", "xlsm", "xltx", "xls", "xlt", "ods", "ots", "fods", "csv", "tsv", "json", "jsonl", "yaml", "yml", "toml", "xml", "vcf", "ics", "har", "numbers":
            return .spreadsheet

        case "pptx", "pptm", "potx", "potm", "ppsx", "ppt", "odp", "otp", "fodp", "key", "keynote":
            return .presentation

        case "srt", "vtt", "ass", "ssa", "smi", "lrc", "ttml", "sub", "scc":
            return .subtitle

        case "zip", "7z", "rar", "tar", "gz", "tgz", "bz2", "tbz2", "xz", "txz", "dmg", "iso", "cab", "alz", "egg":
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
