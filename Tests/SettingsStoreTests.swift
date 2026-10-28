import XCTest
@testable import TangerineKit

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testDefaultSettings() {
        let store = SettingsStore.shared
        XCTAssertEqual(store.convertModifierKey, "shift")
        XCTAssertEqual(store.toolsModifierKey, "command")
        XCTAssertEqual(store.actionsModifierKey, "control")
        XCTAssertEqual(store.playSounds, true)
        XCTAssertEqual(store.hapticFeedback, true)
        XCTAssertEqual(store.revealInFinder, true)
        XCTAssertEqual(store.saveBesideOriginal, true)
        XCTAssertEqual(store.jpegQuality, 0.88)
        XCTAssertEqual(store.pdfDPI, 300.0)
    }

    func testIconStyles() {
        let store = SettingsStore.shared
        store.menuBarIconStyle = .coloredTangerine
        XCTAssertEqual(store.menuBarIconStyle, .coloredTangerine)

        store.menuBarIconStyle = .monochromeTemplate
        XCTAssertEqual(store.menuBarIconStyle, .monochromeTemplate)

        // Reset
        store.menuBarIconStyle = .coloredTangerine
    }
}
