import FinderSync

@MainActor
enum FinderExtensionController {
    static var isEnabled: Bool {
        FIFinderSyncController.isExtensionEnabled
    }

    static func showManagementInterface() {
        FIFinderSyncController.showExtensionManagementInterface()
    }
}
