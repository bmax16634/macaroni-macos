import AppKit
import ApplicationServices

enum WindowSnapAction: UInt32, CaseIterable {
    case leftHalf = 1
    case rightHalf = 2
    case maximize = 3

    var title: String {
        switch self {
        case .leftHalf: "Left Half"
        case .rightHalf: "Right Half"
        case .maximize: "Maximize"
        }
    }

    var shortcutDescription: String {
        switch self {
        case .leftHalf: "⌃⌥←"
        case .rightHalf: "⌃⌥→"
        case .maximize: "⌃⌥↩"
        }
    }
}

struct WindowSnapGeometry {
    static func frame(for action: WindowSnapAction, in visibleFrame: CGRect) -> CGRect {
        switch action {
        case .leftHalf:
            return CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY,
                width: visibleFrame.width / 2,
                height: visibleFrame.height
            )
        case .rightHalf:
            return CGRect(
                x: visibleFrame.midX,
                y: visibleFrame.minY,
                width: visibleFrame.width / 2,
                height: visibleFrame.height
            )
        case .maximize:
            return visibleFrame
        }
    }
}

struct WindowDragSnapGeometry {
    static let defaultEdgeThreshold: CGFloat = 10

    static func action(
        for pointerLocation: CGPoint,
        in screenFrame: CGRect,
        edgeThreshold: CGFloat = defaultEdgeThreshold
    ) -> WindowSnapAction? {
        guard screenFrame.insetBy(dx: -edgeThreshold, dy: -edgeThreshold).contains(pointerLocation) else {
            return nil
        }

        // The top edge wins at the corners so dragging upward always maximizes.
        if pointerLocation.y >= screenFrame.maxY - edgeThreshold {
            return .maximize
        }
        if pointerLocation.x <= screenFrame.minX + edgeThreshold {
            return .leftHalf
        }
        if pointerLocation.x >= screenFrame.maxX - edgeThreshold {
            return .rightHalf
        }
        return nil
    }
}

enum WindowSnapError: LocalizedError {
    case accessibilityRequired
    case noFrontmostApplication
    case noFocusedWindow
    case unreadableWindowFrame
    case noScreen
    case couldNotMoveWindow(AXError)

    var errorDescription: String? {
        switch self {
        case .accessibilityRequired:
            "Enable Accessibility for Macaroni before using window shortcuts."
        case .noFrontmostApplication:
            "Macaroni could not find the active application."
        case .noFocusedWindow:
            "The active application does not have a movable window."
        case .unreadableWindowFrame:
            "Macaroni could not read the active window's position and size."
        case .noScreen:
            "Macaroni could not determine which display contains the active window."
        case .couldNotMoveWindow(let error):
            "macOS did not allow Macaroni to move that window (Accessibility error \(error.rawValue))."
        }
    }
}

@MainActor
final class WindowSnapController {
    func snap(_ action: WindowSnapAction) throws {
        guard AXIsProcessTrusted() else {
            throw WindowSnapError.accessibilityRequired
        }
        guard let application = NSWorkspace.shared.frontmostApplication,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            throw WindowSnapError.noFrontmostApplication
        }

        let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
        var focusedWindowValue: CFTypeRef?
        let focusedWindowResult = AXUIElementCopyAttributeValue(
            applicationElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindowValue
        )
        guard focusedWindowResult == .success, let focusedWindowValue else {
            throw WindowSnapError.noFocusedWindow
        }
        let windowElement = focusedWindowValue as! AXUIElement

        guard let currentFrame = frame(of: windowElement) else {
            throw WindowSnapError.unreadableWindowFrame
        }
        guard let screen = screen(containing: currentFrame) else {
            throw WindowSnapError.noScreen
        }

        let targetFrame = WindowSnapGeometry.frame(for: action, in: screen.visibleFrame)
        try set(frame: targetFrame, for: windowElement)
    }

    func focusedWindowFrame() throws -> CGRect {
        guard AXIsProcessTrusted() else {
            throw WindowSnapError.accessibilityRequired
        }
        guard let application = NSWorkspace.shared.frontmostApplication,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            throw WindowSnapError.noFrontmostApplication
        }

        let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
        var focusedWindowValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            applicationElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindowValue
        )
        guard result == .success, let focusedWindowValue else {
            throw WindowSnapError.noFocusedWindow
        }
        guard let frame = frame(of: focusedWindowValue as! AXUIElement) else {
            throw WindowSnapError.unreadableWindowFrame
        }
        return frame
    }

    private func frame(of element: AXUIElement) -> CGRect? {
        guard let position = pointAttribute(kAXPositionAttribute, of: element),
              let size = sizeAttribute(kAXSizeAttribute, of: element),
              let referenceTop = cocoaReferenceTop else {
            return nil
        }

        return CGRect(
            x: position.x,
            y: referenceTop - position.y - size.height,
            width: size.width,
            height: size.height
        )
    }

    private func set(frame cocoaFrame: CGRect, for element: AXUIElement) throws {
        guard let referenceTop = cocoaReferenceTop else {
            throw WindowSnapError.noScreen
        }

        var position = CGPoint(x: cocoaFrame.minX, y: referenceTop - cocoaFrame.maxY)
        var size = cocoaFrame.size
        guard let positionValue = AXValueCreate(.cgPoint, &position),
              let sizeValue = AXValueCreate(.cgSize, &size) else {
            throw WindowSnapError.unreadableWindowFrame
        }

        // Some applications adjust their origin while resizing. Moving once before and
        // once after the resize keeps the requested edge anchored more reliably.
        var result = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, positionValue)
        guard result == .success else {
            throw WindowSnapError.couldNotMoveWindow(result)
        }
        result = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)
        guard result == .success else {
            throw WindowSnapError.couldNotMoveWindow(result)
        }
        result = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, positionValue)
        guard result == .success else {
            throw WindowSnapError.couldNotMoveWindow(result)
        }
    }

    private func pointAttribute(_ attribute: String, of element: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        let axValue = value as! AXValue
        guard AXValueGetType(axValue) == .cgPoint else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(axValue, .cgPoint, &point) ? point : nil
    }

    private func sizeAttribute(_ attribute: String, of element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        let axValue = value as! AXValue
        guard AXValueGetType(axValue) == .cgSize else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(axValue, .cgSize, &size) ? size : nil
    }

    private func screen(containing windowFrame: CGRect) -> NSScreen? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }

        return screens.max { first, second in
            intersectionArea(first.visibleFrame, windowFrame) < intersectionArea(second.visibleFrame, windowFrame)
        }
    }

    private func intersectionArea(_ first: CGRect, _ second: CGRect) -> CGFloat {
        let intersection = first.intersection(second)
        guard !intersection.isNull else { return 0 }
        return intersection.width * intersection.height
    }

    private var cocoaReferenceTop: CGFloat? {
        let screens = NSScreen.screens
        return screens.first(where: { $0.frame.origin == .zero })?.frame.maxY
            ?? screens.first?.frame.maxY
    }
}
