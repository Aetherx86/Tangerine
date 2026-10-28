import XCTest
@testable import TangerineKit

final class FileCategoryTests: XCTestCase {
    func testImageDetection() {
        let exts = ["png", "jpg", "jpeg", "webp", "heic", "tiff", "bmp", "avif", "gif", "PNG", "JPG"]
        for ext in exts {
            let url = URL(fileURLWithPath: "/tmp/sample.\(ext)")
            XCTAssertEqual(FileCategory.detect(from: [url]), .image, "Failed for extension .\(ext)")
        }
    }

    func testVideoDetection() {
        let exts = ["mp4", "mov", "mkv", "avi", "wmv", "webm", "m4v", "MP4", "MOV"]
        for ext in exts {
            let url = URL(fileURLWithPath: "/tmp/sample.\(ext)")
            XCTAssertEqual(FileCategory.detect(from: [url]), .video, "Failed for extension .\(ext)")
        }
    }

    func testAudioDetection() {
        let exts = ["mp3", "m4a", "wav", "flac", "ogg", "opus", "aiff", "wma", "MP3", "WAV"]
        for ext in exts {
            let url = URL(fileURLWithPath: "/tmp/sample.\(ext)")
            XCTAssertEqual(FileCategory.detect(from: [url]), .audio, "Failed for extension .\(ext)")
        }
    }

    func testPDFDetection() {
        let url = URL(fileURLWithPath: "/tmp/document.pdf")
        XCTAssertEqual(FileCategory.detect(from: [url]), .pdf)
    }

    func testDocumentDetection() {
        let exts = ["docx", "pages", "txt", "md", "markdown", "rtf"]
        for ext in exts {
            let url = URL(fileURLWithPath: "/tmp/doc.\(ext)")
            XCTAssertEqual(FileCategory.detect(from: [url]), .document, "Failed for extension .\(ext)")
        }
    }

    func testSpreadsheetDetection() {
        let exts = ["xlsx", "xls", "ods", "csv", "tsv"]
        for ext in exts {
            let url = URL(fileURLWithPath: "/tmp/sheet.\(ext)")
            XCTAssertEqual(FileCategory.detect(from: [url]), .spreadsheet, "Failed for extension .\(ext)")
        }
    }

    func testPresentationDetection() {
        let exts = ["pptx", "ppt", "key"]
        for ext in exts {
            let url = URL(fileURLWithPath: "/tmp/slides.\(ext)")
            XCTAssertEqual(FileCategory.detect(from: [url]), .presentation, "Failed for extension .\(ext)")
        }
    }

    func testArchiveDetection() {
        let exts = ["zip", "tar", "gz", "tgz", "bz2", "rar", "7z"]
        for ext in exts {
            let url = URL(fileURLWithPath: "/tmp/archive.\(ext)")
            XCTAssertEqual(FileCategory.detect(from: [url]), .archive, "Failed for extension .\(ext)")
        }
    }

    func testSubtitleDetection() {
        XCTAssertEqual(FileCategory.detect(from: [URL(fileURLWithPath: "/tmp/movie.srt")]), .subtitle)
        XCTAssertEqual(FileCategory.detect(from: [URL(fileURLWithPath: "/tmp/movie.vtt")]), .subtitle)
    }

    func testEdgeCases() {
        // Empty URLs
        XCTAssertEqual(FileCategory.detect(from: []), .generic)
        // No extension
        XCTAssertEqual(FileCategory.detect(from: [URL(fileURLWithPath: "/tmp/unknown_file")]), .generic)
        // Hidden file
        XCTAssertEqual(FileCategory.detect(from: [URL(fileURLWithPath: "/tmp/.hidden")]), .generic)
    }
}
