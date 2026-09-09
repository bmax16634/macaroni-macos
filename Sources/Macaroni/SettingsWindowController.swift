import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var windowController: NSWindowController?

    private init() {}

    func show(model: AppModel) {
        let controller: NSWindowController
        if let windowController {
            controller = windowController
        } else {
            let hostingController = NSHostingController(rootView: SettingsPanel(model: model))
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Macaroni Settings"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 780, height: 560))
            window.minSize = NSSize(width: 700, height: 500)
            window.isReleasedWhenClosed = false
            window.collectionBehavior.insert(.moveToActiveSpace)
            window.center()

            controller = NSWindowController(window: window)
            windowController = controller
        }

        NSApp.activate(ignoringOtherApps: true)
        if controller.window?.isMiniaturized == true {
            controller.window?.deminiaturize(nil)
        }
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }
}
