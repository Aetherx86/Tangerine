import XCTest
import PDFKit
@testable import TangerineKit

final class DocumentProcessorTests: XCTestCase {
    var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testSRTToVTTConversion() async throws {
        let srtContent = """
        1
        00:00:01,000 --> 00:00:04,000
        Welcome to Tangerine.

        2
        00:00:04,500 --> 00:00:08,000
        Convert files instantly.
        """
        let srtURL = tempDir.appendingPathComponent("subtitles.srt")
        try srtContent.write(to: srtURL, atomically: true, encoding: .utf8)

        let results = try await DocumentProcessor.convert(urls: [srtURL], toExtension: "vtt")
        XCTAssertEqual(results.count, 1)
        let vttURL = results[0]
        XCTAssertTrue(FileManager.default.fileExists(atPath: vttURL.path))

        let vttContent = try String(contentsOf: vttURL, encoding: .utf8)
        XCTAssertTrue(vttContent.hasPrefix("WEBVTT"))
        XCTAssertTrue(vttContent.contains("00:00:01.000 --> 00:00:04.000"), "Commas should be replaced with periods in VTT")
        XCTAssertTrue(vttContent.contains("Welcome to Tangerine."))
    }

    func testVTTToPlainTXT() async throws {
        let vttContent = """
        WEBVTT

        1
        00:00:01.000 --> 00:00:04.000
        First line of dialogue.

        2
        00:00:04.500 --> 00:00:08.000
        Second line of dialogue.
        """
        let vttURL = tempDir.appendingPathComponent("subtitles.vtt")
        try vttContent.write(to: vttURL, atomically: true, encoding: .utf8)

        let results = try await DocumentProcessor.convert(urls: [vttURL], toExtension: "txt")
        XCTAssertEqual(results.count, 1)
        let txtURL = results[0]
        XCTAssertTrue(FileManager.default.fileExists(atPath: txtURL.path))

        let plain = try String(contentsOf: txtURL, encoding: .utf8)
        XCTAssertFalse(plain.contains("WEBVTT"))
        XCTAssertFalse(plain.contains("-->"))
        XCTAssertTrue(plain.contains("First line of dialogue."))
        XCTAssertTrue(plain.contains("Second line of dialogue."))
    }

    func testMarkdownToHTML() async throws {
        let mdContent = "# Hello Tangerine\nThis is a test."
        let mdURL = tempDir.appendingPathComponent("test.md")
        try mdContent.write(to: mdURL, atomically: true, encoding: .utf8)

        let results = try await DocumentProcessor.convert(urls: [mdURL], toExtension: "html")
        XCTAssertEqual(results.count, 1)
        let htmlURL = results[0]
        let htmlContent = try String(contentsOf: htmlURL, encoding: .utf8)
        XCTAssertTrue(htmlContent.contains("<html>"))
        XCTAssertTrue(htmlContent.contains("Hello Tangerine"))
    }

    func testMarkdownToPDFProducesValidOpenablePDF() async throws {
        let mdContent = """
        # Tangerine Project Overview
        
        This document verifies that Markdown to PDF generates an authentic, openable PDF.
        
        ## Highlights
        - Native macOS CoreText rendering
        - Multi-page support with standard margins
        - Fully searchable text
        """
        let mdURL = tempDir.appendingPathComponent("document.md")
        try mdContent.write(to: mdURL, atomically: true, encoding: .utf8)

        let results = try await DocumentProcessor.convert(urls: [mdURL], toExtension: "pdf")
        XCTAssertEqual(results.count, 1)
        let pdfURL = results[0]
        XCTAssertTrue(FileManager.default.fileExists(atPath: pdfURL.path))

        // Verify with Apple PDFKit that the file is an authentic, readable PDF
        let pdfDoc = PDFDocument(url: pdfURL)
        XCTAssertNotNil(pdfDoc, "Generated PDF must be successfully opened by PDFKit")
        XCTAssertGreaterThanOrEqual(pdfDoc?.pageCount ?? 0, 1, "PDF must contain at least 1 page")
        let text = pdfDoc?.string ?? ""
        XCTAssertTrue(text.contains("Tangerine Project Overview"), "PDF must contain the rendered title")
        XCTAssertTrue(text.contains("CoreText rendering"), "PDF must contain the body content")
    }

    func testMarkdownToDOCXProducesValidOfficeDocument() async throws {
        let mdContent = "# OpenXML Document\nGenerated natively by Tangerine."
        let mdURL = tempDir.appendingPathComponent("doc.md")
        try mdContent.write(to: mdURL, atomically: true, encoding: .utf8)

        let results = try await DocumentProcessor.convert(urls: [mdURL], toExtension: "docx")
        XCTAssertEqual(results.count, 1)
        let docxURL = results[0]
        XCTAssertTrue(FileManager.default.fileExists(atPath: docxURL.path))

        // Verify it can be read back as an NSAttributedString
        let attr = try NSAttributedString(url: docxURL, options: [:], documentAttributes: nil)
        XCTAssertTrue(attr.string.contains("OpenXML Document"))
    }

    func testMarkdownToEPUBProducesValidArchive() async throws {
        let mdContent = "# Chapter 1\nOnce upon a time in California."
        let mdURL = tempDir.appendingPathComponent("book.md")
        try mdContent.write(to: mdURL, atomically: true, encoding: .utf8)

        let results = try await DocumentProcessor.convert(urls: [mdURL], toExtension: "epub")
        XCTAssertEqual(results.count, 1)
        let epubURL = results[0]
        XCTAssertTrue(FileManager.default.fileExists(atPath: epubURL.path))
        XCTAssertGreaterThan(try Data(contentsOf: epubURL).count, 500)
    }
}
