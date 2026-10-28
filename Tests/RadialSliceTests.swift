import XCTest
@testable import TangerineKit

final class RadialSliceTests: XCTestCase {
    func testImageConversionSlices() {
        let slicesWithoutCurrent = RadialSlice.slices(for: .image, mode: .convert, currentExtension: "png")
        // Should have 9 slices (PNG excluded)
        XCTAssertEqual(slicesWithoutCurrent.count, 9)
        let titles = slicesWithoutCurrent.map { $0.title }
        XCTAssertTrue(titles.contains("JPG"))
        XCTAssertTrue(titles.contains("WEBP"))
        XCTAssertTrue(titles.contains("HEIC"))
        XCTAssertTrue(titles.contains("TIFF"))
        XCTAssertTrue(titles.contains("AVIF"))
        XCTAssertTrue(titles.contains("BMP"))
        XCTAssertTrue(titles.contains("PDF"))
        XCTAssertTrue(titles.contains("ICO"))
        XCTAssertTrue(titles.contains("ICNS"))
        XCTAssertFalse(titles.contains("PNG"), "PNG should be omitted when input is PNG")
        XCTAssertFalse(titles.contains("DOCX"), "DOCX should never be an image target")

        let allImageSlices = RadialSlice.slices(for: .image, mode: .convert)
        XCTAssertEqual(allImageSlices.count, 10)
    }

    func testImageToolSlices() {
        let slices = RadialSlice.slices(for: .image, mode: .tools)
        XCTAssertEqual(slices.count, 7)
        let titles = slices.map { $0.title }
        XCTAssertEqual(titles, ["COMPRESS", "METADATA", "EDIT", "ANNOTATE", "ADD BG", "CROP", "REDACT"])
    }

    func testVideoSlices() {
        let conv = RadialSlice.slices(for: .video, mode: .convert)
        XCTAssertEqual(conv.count, 8)
        XCTAssertTrue(conv.map { $0.title }.contains("MP4"))
        XCTAssertTrue(conv.map { $0.title }.contains("GIF"))
        XCTAssertTrue(conv.map { $0.title }.contains("MP3"))

        let tools = RadialSlice.slices(for: .video, mode: .tools)
        XCTAssertEqual(tools.count, 9)
        XCTAssertEqual(tools.map { $0.title }, ["COMPRESS", "METADATA", "MUTE", "TRIM", "CROP", "SPEED", "SNAPSHOT", "SPLIT", "REDACT"])
    }

    func testAudioSlices() {
        let conv = RadialSlice.slices(for: .audio, mode: .convert)
        XCTAssertEqual(conv.count, 9)
        XCTAssertTrue(conv.map { $0.title }.contains("WAV"))
        XCTAssertTrue(conv.map { $0.title }.contains("FLAC"))
        XCTAssertTrue(conv.map { $0.title }.contains("AAC"))

        let tools = RadialSlice.slices(for: .audio, mode: .tools)
        XCTAssertEqual(tools.count, 7)
        XCTAssertEqual(tools.map { $0.title }, ["COMPRESS", "METADATA", "NORMALIZE", "VISUALIZE", "TRIM", "CHANNELS", "BLEEP"])
    }

    func testPDFSlices() {
        let conv = RadialSlice.slices(for: .pdf, mode: .convert)
        XCTAssertEqual(conv.count, 8)
        XCTAssertEqual(conv.map { $0.title }, ["DOCX", "JPG", "PNG", "EPUB", "TXT", "MD", "HTML", "TIFF"])

        let tools = RadialSlice.slices(for: .pdf, mode: .tools)
        XCTAssertEqual(tools.count, 5)
        XCTAssertEqual(tools.map { $0.title }, ["COMPRESS", "METADATA", "SPLIT", "MERGE", "ORGANIZE"])
    }

    func testArchiveSlices() {
        let conv = RadialSlice.slices(for: .archive, mode: .convert)
        XCTAssertEqual(conv.count, 3)
        XCTAssertEqual(conv.map { $0.title }, ["ZIP", "TAR", "GZIP"])

        let tools = RadialSlice.slices(for: .archive, mode: .tools)
        XCTAssertEqual(tools.count, 1)
        XCTAssertEqual(tools.first?.title, "EXTRACT")
    }

    func testActionSlices() {
        let actions = RadialSlice.slices(for: .generic, mode: .actions)
        XCTAssertEqual(actions.count, 6)
        XCTAssertEqual(actions.map { $0.title }, ["AIRDROP", "FLOAT", "COPY", "MOVE", "COPY PATH", "TERMINAL"])
    }
}
