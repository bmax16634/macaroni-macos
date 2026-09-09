import AppKit
import Darwin
import FinderSync
import os

final class FinderSync: FIFinderSync {
    private let logger = Logger(
        subsystem: "com.benjaminmaxwell.Macaroni.FinderExtension",
        category: "FinderSync"
    )
    private var pendingDestination: URL?

    override init() {
        super.init()

        // Finder does not reliably treat the filesystem root as a monitored folder.
        // Register the real (non-sandbox-container) home and mounted-volume roots.
        let directories = Self.monitoredDirectories()
        FIFinderSyncController.default().directoryURLs = directories
        logger.info("Monitoring \(directories.count, privacy: .public) Finder roots")
    }

    override func beginObservingDirectory(at url: URL) {
        logger.debug("Finder began observing \(url.path, privacy: .public)")
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForContainer || menuKind == .contextualMenuForItems else {
            return nil
        }

        pendingDestination = destinationDirectory(for: menuKind)

        let menu = NSMenu(title: "Macaroni")
        let item = NSMenuItem(
            title: "New File…",
            action: #selector(createNewFile(_:)),
            keyEquivalent: ""
        )
        menu.addItem(item)
        logger.debug("Providing the New File contextual menu")
        return menu
    }

    private static func monitoredDirectories() -> Set<URL> {
        var directories = Set<URL>()

        // A sandboxed extension's Foundation home directory can point inside its
        // container, so obtain the account home directory from the user database.
        if let account = getpwuid(getuid()), let home = account.pointee.pw_dir {
            directories.insert(
                URL(fileURLWithPath: String(cString: home), isDirectory: true).standardizedFileURL
            )
        }

        directories.insert(
            URL(fileURLWithPath: "/Volumes", isDirectory: true).standardizedFileURL
        )
        return directories
    }

    @objc private func createNewFile(_ sender: Any?) {
        logger.notice("New File action selected")

        guard let destination = pendingDestination else {
            logger.error("No Finder destination was available for New File")
            return
        }

        var request = URLComponents()
        request.scheme = "macaroni"
        request.host = "new-file"
        request.queryItems = [URLQueryItem(name: "directory", value: destination.path)]

        guard let requestURL = request.url, NSWorkspace.shared.open(requestURL) else {
            logger.error("Could not hand the New File request to the Macaroni app")
            return
        }

        logger.notice("Handed New File request to the Macaroni app")
    }

    private func destinationDirectory(for menuKind: FIMenuKind) -> URL? {
        let controller = FIFinderSyncController.default()

        if menuKind == .contextualMenuForItems,
           let selectedURLs = controller.selectedItemURLs(),
           selectedURLs.count == 1,
           let selectedURL = selectedURLs.first,
           isDirectory(selectedURL) {
            return selectedURL
        }

        guard let targetURL = controller.targetedURL() else { return nil }
        return isDirectory(targetURL) ? targetURL : targetURL.deletingLastPathComponent()
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }
}
