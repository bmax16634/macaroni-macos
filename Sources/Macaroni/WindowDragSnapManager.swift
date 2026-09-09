import AppKit
import Foundation

@MainActor
final class WindowDragSnapManager {
    var actionHandler: ((WindowSnapAction) -> Void)?

    private let windowSnapController: WindowSnapController
    private var eventMonitor: Any?
    private var initialWindowFrame: CGRect?
    private var windowMoved = false

    init(windowSnapController: WindowSnapController) {
        self.windowSnapController = windowSnapController
    }

    deinit {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }

    func setEnabled(_ enabled: Bool) {
        if enabled {
            start()
        } else {
            stop()
        }
    }

    private func start() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            Task { @MainActor in
                self?.handle(event)
            }
        }
    }

    private func stop() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
        resetDrag()
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDragged:
            recordDragProgress()
        case .leftMouseUp:
            finishDrag(at: NSEvent.mouseLocation)
        default:
            break
        }
    }

    private func recordDragProgress() {
        guard let currentFrame = try? windowSnapController.focusedWindowFrame() else {
            resetDrag()
            return
        }

        guard let initialWindowFrame else {
            self.initialWindowFrame = currentFrame
            return
        }

        if abs(currentFrame.minX - initialWindowFrame.minX) > 2
            || abs(currentFrame.minY - initialWindowFrame.minY) > 2 {
            windowMoved = true
        }
    }

    private func finishDrag(at pointerLocation: CGPoint) {
        defer { resetDrag() }
        guard let initialWindowFrame,
              let currentFrame = try? windowSnapController.focusedWindowFrame() else {
            return
        }

        let moved = windowMoved
            || abs(currentFrame.minX - initialWindowFrame.minX) > 2
            || abs(currentFrame.minY - initialWindowFrame.minY) > 2
        guard moved,
              let screen = screen(containing: pointerLocation),
              let action = WindowDragSnapGeometry.action(
                  for: pointerLocation,
                  in: screen.frame
              ) else {
            return
        }

        actionHandler?(action)
    }

    private func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first {
            $0.frame.insetBy(dx: -1, dy: -1).contains(point)
        }
    }

    private func resetDrag() {
        initialWindowFrame = nil
        windowMoved = false
    }
}
