import AppKit
import SwiftUI

/// A deliberately simple, monochrome noodle mark for the macOS menu bar.
///
/// The single rounded stroke keeps the pasta-shaped M legible at status-item
/// sizes. A native template image lets macOS supply the correct menu-bar color
/// in light, dark, highlighted, and accessibility appearances.
struct MacaroniMenuBarIcon: View {
    var body: some View {
        Image(nsImage: MacaroniStatusImage.image)
            .renderingMode(.template)
            .accessibilityLabel("Macaroni")
    }
}

enum MacaroniStatusImage {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            let point: (CGFloat, CGFloat) -> NSPoint = { x, y in
                NSPoint(
                    x: rect.minX + rect.width * x,
                    y: rect.minY + rect.height * (1 - y)
                )
            }

            let path = NSBezierPath()
            path.move(to: point(0.08, 0.78))
            path.curve(
                to: point(0.28, 0.20),
                controlPoint1: point(0.10, 0.43),
                controlPoint2: point(0.18, 0.20)
            )
            path.curve(
                to: point(0.50, 0.68),
                controlPoint1: point(0.38, 0.20),
                controlPoint2: point(0.40, 0.68)
            )
            path.curve(
                to: point(0.72, 0.20),
                controlPoint1: point(0.60, 0.68),
                controlPoint2: point(0.62, 0.20)
            )
            path.curve(
                to: point(0.92, 0.78),
                controlPoint1: point(0.82, 0.20),
                controlPoint2: point(0.90, 0.43)
            )
            path.lineWidth = 2.7
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            NSColor.black.setStroke()
            path.stroke()
            return true
        }

        image.isTemplate = true
        image.accessibilityDescription = "Macaroni"
        return image
    }()
}
