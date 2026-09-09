import SwiftUI

@main
struct MacaroniApp: App {
    @NSApplicationDelegateAdaptor(MacaroniAppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            QuickMenuPanel(model: model)
        } label: {
            MacaroniMenuBarIcon()
        }
        .menuBarExtraStyle(.window)
    }
}
