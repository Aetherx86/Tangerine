import XCTest
@testable import TangerineKit

final class RadialMathTests: XCTestCase {
    // Tests that top position (12 o'clock) maps to index 0, 3 o'clock maps to quarter index, etc.
    func testPolarCoordinateMapping8Slices() {
        let count = 8
        let span = (2.0 * .pi) / Double(count)

        func indexFor(dx: CGFloat, dy: CGFloat) -> Int? {
            let distance = sqrt(dx * dx + dy * dy)
            guard distance >= 50 && distance <= 150 else { return nil }
            let angle = atan2(dy, dx)
            var angleFromTop = Double.pi / 2.0 - Double(angle)
            if angleFromTop < 0 { angleFromTop += 2.0 * .pi }
            return Int(angleFromTop / span) % count
        }

        // 1. Center dead zone
        XCTAssertNil(indexFor(dx: 0, dy: 0), "Center (0,0) must be nil (dead zone)")
        XCTAssertNil(indexFor(dx: 20, dy: 20), "Distance < 50 must be nil")

        // 2. Outside wheel
        XCTAssertNil(indexFor(dx: 200, dy: 200), "Distance > 150 must be nil")

        // 3. Exact Top (dx = 0, dy = 100 in AppKit where dy > 0 is up)
        XCTAssertEqual(indexFor(dx: 0, dy: 100), 0, "Top 12 o'clock must be index 0")

        // 4. Exact Right (dx = 100, dy = 0)
        XCTAssertEqual(indexFor(dx: 100, dy: 0), 2, "Right 3 o'clock in 8-slice wheel must be index 2")

        // 5. Exact Bottom (dx = 0, dy = -100)
        XCTAssertEqual(indexFor(dx: 0, dy: -100), 4, "Bottom 6 o'clock in 8-slice wheel must be index 4")

        // 6. Exact Left (dx = -100, dy = 0)
        XCTAssertEqual(indexFor(dx: -100, dy: 0), 6, "Left 9 o'clock in 8-slice wheel must be index 6")
    }

    func testPolarCoordinateMapping4Slices() {
        let count = 4
        let span = (2.0 * .pi) / Double(count)

        func indexFor(dx: CGFloat, dy: CGFloat) -> Int? {
            let distance = sqrt(dx * dx + dy * dy)
            guard distance >= 50 && distance <= 150 else { return nil }
            let angle = atan2(dy, dx)
            var angleFromTop = Double.pi / 2.0 - Double(angle)
            if angleFromTop < 0 { angleFromTop += 2.0 * .pi }
            return Int(angleFromTop / span) % count
        }

        XCTAssertEqual(indexFor(dx: 0, dy: 100), 0)
        XCTAssertEqual(indexFor(dx: 100, dy: 0), 1)
        XCTAssertEqual(indexFor(dx: 0, dy: -100), 2)
        XCTAssertEqual(indexFor(dx: -100, dy: 0), 3)
    }
}
