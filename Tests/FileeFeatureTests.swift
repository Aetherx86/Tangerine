import XCTest
import PDFKit
@testable import TangerineKit

final class FileeFeatureTests: XCTestCase {
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    @MainActor
    func testConversionHistoryAndUndo() {
        let history = ConversionHistoryManager.shared
        history.clearAll()

        let dummyOutput = tempDir.appendingPathComponent("output.png")
        try? "test data".data(using: .utf8)?.write(to: dummyOutput)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dummyOutput.path))

        history.record(
            sources: [tempDir.appendingPathComponent("input.jpg")],
            outputs: [dummyOutput],
            format: "PNG",
            success: true
        )

        XCTAssertEqual(history.items.count, 1)
        let item = history.items[0]
        XCTAssertEqual(item.targetFormat, "PNG")
        XCTAssertFalse(item.isUndone)

        // Test Undo (Move to Trash)
        history.undo(item: item)
        XCTAssertTrue(history.items[0].isUndone)
        XCTAssertFalse(FileManager.default.fileExists(atPath: dummyOutput.path))
    }

    @MainActor
    func testWatchFolderRules() {
        let watcher = FolderWatcherService.shared
        let folder = tempDir.appendingPathComponent("WatchedFolder")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        watcher.addRule(folderURL: folder, targetFormat: "JPG", moveOriginals: true)
        let rules = SettingsStore.shared.watchRules
        XCTAssertTrue(rules.contains { $0.folderPath == folder.path && $0.targetFormat == "JPG" })

        if let rule = rules.first(where: { $0.folderPath == folder.path }) {
            watcher.toggleRule(id: rule.id)
            XCTAssertFalse(SettingsStore.shared.watchRules.first(where: { $0.id == rule.id })?.isEnabled ?? true)

            watcher.removeRule(id: rule.id)
            XCTAssertFalse(SettingsStore.shared.watchRules.contains { $0.id == rule.id })
        }
    }

    func testPDFMerge() async throws {
        // Create 2 single page PDFs
        let pdf1URL = tempDir.appendingPathComponent("doc1.pdf")
        let pdf2URL = tempDir.appendingPathComponent("doc2.pdf")

        let doc1 = PDFDocument()
        let doc2 = PDFDocument()

        let img = NSImage(size: NSSize(width: 100, height: 100), flipped: false) { rect in
            NSColor.blue.setFill()
            rect.fill()
            return true
        }

        if let p1 = PDFPage(image: img), let p2 = PDFPage(image: img) {
            doc1.insert(p1, at: 0)
            doc2.insert(p2, at: 0)
            doc1.write(to: pdf1URL)
            doc2.write(to: pdf2URL)
        }

        let merged = try await PDFProcessor.merge(urls: [pdf1URL, pdf2URL])
        XCTAssertEqual(merged.count, 1)

        let mergedDoc = PDFDocument(url: merged[0])
        XCTAssertNotNil(mergedDoc)
        XCTAssertEqual(mergedDoc?.pageCount, 2)
    }

    @MainActor
    func testDonutFlipSide() {
        let controller = RadialWheelController.shared
        controller.show(at: .zero, mode: .convert, urls: [URL(fileURLWithPath: "/test.jpg")])
        XCTAssertEqual(controller.currentSide, 1)

        controller.flipSide()
        XCTAssertEqual(controller.currentSide, 2)
        XCTAssertTrue(controller.subtitleText.contains("Side 2"))

        controller.flipSide()
        XCTAssertEqual(controller.currentSide, 1)
        XCTAssertTrue(controller.subtitleText.contains("Side 1"))
    }
}
