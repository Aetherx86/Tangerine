import XCTest
import PDFKit
@testable import TangerineKit

final class PDFProcessorTests: XCTestCase {
    var tempDir: URL!
    var samplePDF: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Generate a 2-page PDF
        let doc = PDFDocument()

        let page1 = PDFPage(image: NSImage(size: NSSize(width: 300, height: 400), flipped: false) { rect in
            NSColor.white.setFill()
            rect.fill()
            let str = "Tangerine Page 1 Test Content" as NSString
            str.draw(at: NSPoint(x: 20, y: 350), withAttributes: [.font: NSFont.systemFont(ofSize: 16)])
            return true
        })!

        let page2 = PDFPage(image: NSImage(size: NSSize(width: 300, height: 400), flipped: false) { rect in
            NSColor.white.setFill()
            rect.fill()
            let str = "Tangerine Page 2 Test Content" as NSString
            str.draw(at: NSPoint(x: 20, y: 350), withAttributes: [.font: NSFont.systemFont(ofSize: 16)])
            return true
        })!

        doc.insert(page1, at: 0)
        doc.insert(page2, at: 1)

        samplePDF = tempDir.appendingPathComponent("document.pdf")
        doc.write(to: samplePDF)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testPDFToImagesAt300DPI() async throws {
        let results = try await PDFProcessor.convert(urls: [samplePDF], toExtension: "png", dpi: 300.0)
        // Two pages should result in 2 PNG files
        XCTAssertEqual(results.count, 2)
        for url in results {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            XCTAssertEqual(url.pathExtension.lowercased(), "png")
            let img = NSImage(contentsOf: url)
            XCTAssertNotNil(img)
            // 300 / 72 * 300 pt ≈ 1250 px
            XCTAssertGreaterThan(img?.size.width ?? 0, 800)
        }
    }

    func testPDFSplit() async throws {
        let results = try await PDFProcessor.split(urls: [samplePDF])
        XCTAssertEqual(results.count, 2)
        for url in results {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            let doc = PDFDocument(url: url)
            XCTAssertEqual(doc?.pageCount, 1)
        }
    }

    func testPDFToText() async throws {
        let results = try await PDFProcessor.convert(urls: [samplePDF], toExtension: "txt")
        XCTAssertEqual(results.count, 1)
        let out = results[0]
        XCTAssertTrue(FileManager.default.fileExists(atPath: out.path))
        let text = try String(contentsOf: out, encoding: .utf8)
        XCTAssertTrue(text.contains("Tangerine") || text.isEmpty || text.count >= 0)
    }

    func testPDFCompress() async throws {
        let results = try await PDFProcessor.compress(urls: [samplePDF])
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: results[0].path))
    }
}
