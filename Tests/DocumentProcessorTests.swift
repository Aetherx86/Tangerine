import XCTest
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
}
