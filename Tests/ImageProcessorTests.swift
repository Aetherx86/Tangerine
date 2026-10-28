import XCTest
import AppKit
@testable import TangerineKit

final class ImageProcessorTests: XCTestCase {
    var tempDir: URL!
    var samplePNG: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Create a 200x150 test image
        let image = NSImage(size: NSSize(width: 200, height: 150), flipped: false) { rect in
            NSColor.orange.setFill()
            rect.fill()
            return true
        }

        samplePNG = tempDir.appendingPathComponent("sample.png")
        if let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
           let data = rep.representation(using: .png, properties: [:]) {
            try data.write(to: samplePNG)
        }
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testConvertPNGToJPEG() async throws {
        let results = try await ImageProcessor.convert(urls: [samplePNG], toExtension: "jpg")
        XCTAssertEqual(results.count, 1)
        let out = results[0]
        XCTAssertTrue(FileManager.default.fileExists(atPath: out.path))
        XCTAssertEqual(out.pathExtension.lowercased(), "jpg")

        let img = NSImage(contentsOf: out)
        XCTAssertNotNil(img)
        XCTAssertEqual(img?.size.width, 200)
        XCTAssertEqual(img?.size.height, 150)
    }

    func testConvertPNGToTIFF() async throws {
        let results = try await ImageProcessor.convert(urls: [samplePNG], toExtension: "tiff")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].pathExtension.lowercased(), "tiff")
        XCTAssertTrue(FileManager.default.fileExists(atPath: results[0].path))
    }

    func testConvertPNGToBMP() async throws {
        let results = try await ImageProcessor.convert(urls: [samplePNG], toExtension: "bmp")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].pathExtension.lowercased(), "bmp")
        XCTAssertTrue(FileManager.default.fileExists(atPath: results[0].path))
    }

    func testConvertPNGToPDF() async throws {
        let results = try await ImageProcessor.convert(urls: [samplePNG], toExtension: "pdf")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].pathExtension.lowercased(), "pdf")
        XCTAssertTrue(FileManager.default.fileExists(atPath: results[0].path))
    }

    func testCropSquare() async throws {
        let results = try await ImageProcessor.cropSquare(urls: [samplePNG])
        XCTAssertEqual(results.count, 1)
        let cropped = results[0]
        XCTAssertTrue(FileManager.default.fileExists(atPath: cropped.path))

        guard let imgSource = CGImageSourceCreateWithURL(cropped as CFURL, nil),
              let cg = CGImageSourceCreateImageAtIndex(imgSource, 0, nil) else {
            XCTFail("Failed to load cropped image")
            return
        }
        XCTAssertEqual(cg.width, cg.height, "Cropped image must be 1:1 square")
        XCTAssertEqual(cg.width, 150)
    }

    func testAddBackground() async throws {
        let results = try await ImageProcessor.addBackground(urls: [samplePNG], bgColor: .white)
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: results[0].path))
    }

    func testStripMetadata() async throws {
        let results = try await ImageProcessor.stripMetadata(urls: [samplePNG])
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: results[0].path))
    }

    func testCompressImage() async throws {
        let results = try await ImageProcessor.compress(urls: [samplePNG], quality: 0.5)
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: results[0].path))
    }

    func testEmptyURLs() async throws {
        let results = try await ImageProcessor.convert(urls: [], toExtension: "jpg")
        XCTAssertTrue(results.isEmpty)
    }
}
