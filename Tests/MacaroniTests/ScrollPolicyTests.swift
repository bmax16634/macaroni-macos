import XCTest
@testable import Macaroni

final class ScrollPolicyTests: XCTestCase {
    func testMatchingDirectionsDoNotInvertPhysicalWheel() {
        XCTAssertFalse(ScrollPolicy.shouldInvertWheel(mouse: .natural, trackpad: .natural))
        XCTAssertFalse(ScrollPolicy.shouldInvertWheel(mouse: .traditional, trackpad: .traditional))
    }

    func testDifferentDirectionsInvertPhysicalWheel() {
        XCTAssertTrue(ScrollPolicy.shouldInvertWheel(mouse: .traditional, trackpad: .natural))
        XCTAssertTrue(ScrollPolicy.shouldInvertWheel(mouse: .natural, trackpad: .traditional))
    }
}
