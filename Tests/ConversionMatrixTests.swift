import XCTest
@testable import TangerineKit

final class ConversionMatrixTests: XCTestCase {
    func testIllegalDocumentConversions() {
        // Markdown (.md) should NEVER allow conversion to image or audio formats
        XCTAssertFalse(ConversionMatrix.isValid(from: "md", to: "jpg"), "md to jpg must be illegal")
        XCTAssertFalse(ConversionMatrix.isValid(from: "md", to: "jpeg"), "md to jpeg must be illegal")
        XCTAssertFalse(ConversionMatrix.isValid(from: "md", to: "png"), "md to png must be illegal")
        XCTAssertFalse(ConversionMatrix.isValid(from: "md", to: "webp"), "md to webp must be illegal")
        XCTAssertFalse(ConversionMatrix.isValid(from: "md", to: "mp3"), "md to mp3 must be illegal")
        XCTAssertFalse(ConversionMatrix.isValid(from: "md", to: "mp4"), "md to mp4 must be illegal")

        // Plain text (.txt)
        XCTAssertFalse(ConversionMatrix.isValid(from: "txt", to: "jpg"), "txt to jpg must be illegal")
        XCTAssertFalse(ConversionMatrix.isValid(from: "txt", to: "png"), "txt to png must be illegal")

        // Word DOCX
        XCTAssertFalse(ConversionMatrix.isValid(from: "docx", to: "jpg"), "docx to jpg must be illegal")
        XCTAssertFalse(ConversionMatrix.isValid(from: "docx", to: "png"), "docx to png must be illegal")
    }

    func testIllegalCrossCategoryConversions() {
        // Audio to document
        XCTAssertFalse(ConversionMatrix.isValid(from: "mp3", to: "docx"))
        XCTAssertFalse(ConversionMatrix.isValid(from: "wav", to: "pdf"))

        // Archive to video
        XCTAssertFalse(ConversionMatrix.isValid(from: "zip", to: "mp4"))

        // Image to video
        XCTAssertFalse(ConversionMatrix.isValid(from: "png", to: "mp4"))
    }

    func testValidDocumentConversions() {
        XCTAssertTrue(ConversionMatrix.isValid(from: "md", to: "pdf"))
        XCTAssertTrue(ConversionMatrix.isValid(from: "md", to: "html"))
        XCTAssertTrue(ConversionMatrix.isValid(from: "md", to: "txt"))
        XCTAssertTrue(ConversionMatrix.isValid(from: "md", to: "docx"))
        XCTAssertTrue(ConversionMatrix.isValid(from: "md", to: "epub"))
        XCTAssertTrue(ConversionMatrix.isValid(from: "docx", to: "pdf"))
    }

    func testValidImageConversions() {
        XCTAssertTrue(ConversionMatrix.isValid(from: "png", to: "jpg"))
        XCTAssertTrue(ConversionMatrix.isValid(from: "png", to: "webp"))
        XCTAssertTrue(ConversionMatrix.isValid(from: "png", to: "heic"))
        XCTAssertTrue(ConversionMatrix.isValid(from: "png", to: "tiff"))
        XCTAssertTrue(ConversionMatrix.isValid(from: "png", to: "avif"))
        XCTAssertTrue(ConversionMatrix.isValid(from: "png", to: "bmp"))
        XCTAssertTrue(ConversionMatrix.isValid(from: "png", to: "pdf"))
    }

    func testValidVideoConversions() {
        XCTAssertTrue(ConversionMatrix.isValid(from: "mp4", to: "mov"))
        XCTAssertTrue(ConversionMatrix.isValid(from: "mp4", to: "gif"))
        XCTAssertTrue(ConversionMatrix.isValid(from: "mp4", to: "mp3"), "Video to MP3 audio extraction is valid")
    }

    func testValidPDFConversions() {
        XCTAssertTrue(ConversionMatrix.isValid(from: "pdf", to: "docx"))
        XCTAssertTrue(ConversionMatrix.isValid(from: "pdf", to: "pages"))
        XCTAssertTrue(ConversionMatrix.isValid(from: "pdf", to: "pptx"))
        XCTAssertTrue(ConversionMatrix.isValid(from: "pdf", to: "xlsx"))
        XCTAssertTrue(ConversionMatrix.isValid(from: "pdf", to: "jpg"))
        XCTAssertTrue(ConversionMatrix.isValid(from: "pdf", to: "png"))
        XCTAssertTrue(ConversionMatrix.isValid(from: "pdf", to: "txt"))
        XCTAssertTrue(ConversionMatrix.isValid(from: "pdf", to: "md"))
    }

    func testRadialSlicesForMarkdownExcludesImages() {
        let slices = RadialSlice.slices(for: .document, mode: .convert, currentExtension: "md")
        let titles = slices.map { $0.title }
        XCTAssertFalse(titles.contains("JPG"), "Markdown wheel must never contain JPG")
        XCTAssertFalse(titles.contains("PNG"), "Markdown wheel must never contain PNG")
        XCTAssertFalse(titles.contains("BMP"), "Markdown wheel must never contain BMP")
        XCTAssertTrue(titles.contains("HTML"))
        XCTAssertTrue(titles.contains("PDF"))
        XCTAssertTrue(titles.contains("TXT"))
    }
}
