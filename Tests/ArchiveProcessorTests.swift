import XCTest
@testable import TangerineKit

final class ArchiveProcessorTests: XCTestCase {
    var tempDir: URL!
    var sampleFolder: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        sampleFolder = tempDir.appendingPathComponent("sample_folder")
        try FileManager.default.createDirectory(at: sampleFolder, withIntermediateDirectories: true)

        let file1 = sampleFolder.appendingPathComponent("file1.txt")
        try "Content 1".write(to: file1, atomically: true, encoding: .utf8)

        let file2 = sampleFolder.appendingPathComponent("file2.txt")
        try "Content 2".write(to: file2, atomically: true, encoding: .utf8)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testCreateZipAndExtract() async throws {
        // 1. Create ZIP
        let zipResults = try await ArchiveProcessor.convert(urls: [sampleFolder], toExtension: "zip")
        XCTAssertEqual(zipResults.count, 1)
        let zipURL = zipResults[0]
        XCTAssertTrue(FileManager.default.fileExists(atPath: zipURL.path))
        XCTAssertEqual(zipURL.pathExtension.lowercased(), "zip")

        // 2. Extract Archive
        let extractedResults = try await ArchiveProcessor.extract(urls: [zipURL])
        XCTAssertEqual(extractedResults.count, 1)
        let extractedDir = extractedResults[0]
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedDir.path))

        // Verify contents
        let contents = try FileManager.default.contentsOfDirectory(atPath: extractedDir.path)
        XCTAssertTrue(contents.contains("file1.txt") || contents.contains("sample_folder"))
    }

    func testCreateTar() async throws {
        let results = try await ArchiveProcessor.convert(urls: [sampleFolder], toExtension: "tar")
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: results[0].path))
        XCTAssertEqual(results[0].pathExtension.lowercased(), "tar")
    }

    func testCreateGzip() async throws {
        let results = try await ArchiveProcessor.convert(urls: [sampleFolder], toExtension: "gzip")
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: results[0].path))
        XCTAssertTrue(results[0].path.hasSuffix(".tar.gz"))
    }
}
