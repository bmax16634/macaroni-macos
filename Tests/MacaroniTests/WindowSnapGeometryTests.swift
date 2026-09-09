import CoreGraphics
import XCTest
@testable import Macaroni

final class WindowSnapGeometryTests: XCTestCase {
    private let visibleFrame = CGRect(x: -1440, y: 25, width: 1440, height: 875)

    func testLeftHalfUsesLeftSideOfVisibleFrame() {
        XCTAssertEqual(
            WindowSnapGeometry.frame(for: .leftHalf, in: visibleFrame),
            CGRect(x: -1440, y: 25, width: 720, height: 875)
        )
    }

    func testRightHalfUsesRightSideOfVisibleFrame() {
        XCTAssertEqual(
            WindowSnapGeometry.frame(for: .rightHalf, in: visibleFrame),
            CGRect(x: -720, y: 25, width: 720, height: 875)
        )
    }

    func testMaximizeUsesEntireVisibleFrame() {
        XCTAssertEqual(
            WindowSnapGeometry.frame(for: .maximize, in: visibleFrame),
            visibleFrame
        )
    }

    func testDragToLeftEdgeChoosesLeftHalf() {
        XCTAssertEqual(
            WindowDragSnapGeometry.action(
                for: CGPoint(x: -1439, y: 400),
                in: CGRect(x: -1440, y: 0, width: 1440, height: 900)
            ),
            .leftHalf
        )
    }

    func testDragToRightEdgeChoosesRightHalf() {
        XCTAssertEqual(
            WindowDragSnapGeometry.action(
                for: CGPoint(x: -1, y: 400),
                in: CGRect(x: -1440, y: 0, width: 1440, height: 900)
            ),
            .rightHalf
        )
    }

    func testDragToTopEdgeChoosesMaximizeIncludingCorner() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        XCTAssertEqual(
            WindowDragSnapGeometry.action(for: CGPoint(x: 720, y: 899), in: screen),
            .maximize
        )
        XCTAssertEqual(
            WindowDragSnapGeometry.action(for: CGPoint(x: 1, y: 899), in: screen),
            .maximize
        )
    }

    func testDragAwayFromEdgesDoesNotSnap() {
        XCTAssertNil(
            WindowDragSnapGeometry.action(
                for: CGPoint(x: 720, y: 450),
                in: CGRect(x: 0, y: 0, width: 1440, height: 900)
            )
        )
    }
}
