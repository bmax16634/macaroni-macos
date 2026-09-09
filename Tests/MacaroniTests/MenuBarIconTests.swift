import AppKit
import XCTest
@testable import Macaroni

final class MenuBarIconTests: XCTestCase {
    func testStatusImageIsVisibleTemplateArtwork() throws {
        let image = MacaroniStatusImage.image
        XCTAssertTrue(image.isTemplate)
        XCTAssertEqual(image.size, NSSize(width: 18, height: 18))

        let data = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: data))
        var visiblePixelCount = 0

        for x in 0..<bitmap.pixelsWide {
            for y in 0..<bitmap.pixelsHigh {
                if (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.1 {
                    visiblePixelCount += 1
                }
            }
        }

        XCTAssertGreaterThan(visiblePixelCount, 20)
    }
}
