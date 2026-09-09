import AppKit
import ApplicationServices

@MainActor
final class MacaroniAppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard let directory = Self.newFileDirectory(from: url) else { continue }
            NewFileRequestController.shared.createAndBeginRename(in: directory)
        }
    }

    private static func newFileDirectory(from url: URL) -> URL? {
        guard url.scheme?.lowercased() == "macaroni",
              url.host?.lowercased() == "new-file",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let path = components.queryItems?.first(where: { $0.name == "directory" })?.value else {
            return nil
        }

        let directory = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
        let directoryPath = directory.path
        let homePath = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        let isInsideHome = directoryPath == homePath || directoryPath.hasPrefix(homePath + "/")
        let isMountedVolume = directoryPath == "/Volumes" || directoryPath.hasPrefix("/Volumes/")

        var isDirectory: ObjCBool = false
        guard (isInsideHome || isMountedVolume),
              FileManager.default.fileExists(atPath: directoryPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }

        return directory
    }
}

@MainActor
private final class NewFileRequestController {
    static let shared = NewFileRequestController()

    func createAndBeginRename(in directory: URL) {
        do {
            let fileURL = try UntitledFileCreator.create(in: directory)
            selectInCurrentFinderViewer(
                fileURL,
                isDesktop: Self.isDesktop(directory),
                attemptsRemaining: 20
            )
        } catch {
            presentError("Macaroni could not create the file: \(error.localizedDescription)")
        }
    }

    private static func isDesktop(_ directory: URL) -> Bool {
        guard let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first else {
            return false
        }
        return directory.standardizedFileURL == desktop.standardizedFileURL
    }

    private func selectInCurrentFinderViewer(
        _ fileURL: URL,
        isDesktop: Bool,
        attemptsRemaining: Int
    ) {
        if isDesktop {
            guard selectDesktopItem(fileURL) else {
                presentError(
                    "Macaroni could not select the new Desktop file. Allow Macaroni to control Finder in System Settings → Privacy & Security → Automation."
                )
                return
            }
            beginDesktopInlineRename(for: fileURL, attemptsRemaining: 30)
            return
        }

        if NSWorkspace.shared.selectFile(fileURL.path, inFileViewerRootedAtPath: "") {
            activateFinder()
            beginInlineRenameWhenFinderIsReady(attemptsRemaining: 20)
            return
        }

        guard attemptsRemaining > 0 else {
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
            beginInlineRenameWhenFinderIsReady(attemptsRemaining: 20)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.selectInCurrentFinderViewer(
                fileURL,
                isDesktop: isDesktop,
                attemptsRemaining: attemptsRemaining - 1
            )
        }
    }

    private func selectDesktopItem(_ fileURL: URL) -> Bool {
        let filename = fileURL.lastPathComponent
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        tell application "Finder"
            select window of desktop
            set selection to {item "\(filename)" of desktop}
        end tell
        """

        guard let script = NSAppleScript(source: source) else { return false }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        return error == nil
    }

    private func beginDesktopInlineRename(for fileURL: URL, attemptsRemaining: Int) {
        guard attemptsRemaining > 0 else { return }

        if selectedFinderItemPath() == fileURL.path {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                guard self.selectedFinderItemPath() == fileURL.path else { return }
                self.pressReturnKeyInFinder()
            }
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.beginDesktopInlineRename(
                for: fileURL,
                attemptsRemaining: attemptsRemaining - 1
            )
        }
    }

    private func selectedFinderItemPath() -> String? {
        let source = """
        tell application "Finder"
            set selectedItems to selection
            if (count of selectedItems) is 0 then return ""
            return POSIX path of (item 1 of selectedItems as alias)
        end tell
        """

        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        guard error == nil else { return nil }
        return result.stringValue
    }

    private func pressReturnKeyInFinder() {
        guard AXIsProcessTrusted(),
              let finder = NSRunningApplication.runningApplications(
                  withBundleIdentifier: "com.apple.finder"
              ).first else {
            return
        }

        finder.activate(options: [])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let keyDown = CGEvent(
                keyboardEventSource: nil,
                virtualKey: 36,
                keyDown: true
            ), let keyUp = CGEvent(
                keyboardEventSource: nil,
                virtualKey: 36,
                keyDown: false
            ) else {
                return
            }

            keyDown.postToPid(finder.processIdentifier)
            keyUp.postToPid(finder.processIdentifier)
        }
    }

    private func activateFinder() {
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder")
            .first?
            .activate(options: [.activateAllWindows])
    }

    private func beginInlineRenameWhenFinderIsReady(attemptsRemaining: Int) {
        guard attemptsRemaining > 0 else { return }

        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder" else {
                    return
                }
                self.pressReturnKey()
            }
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.beginInlineRenameWhenFinderIsReady(attemptsRemaining: attemptsRemaining - 1)
        }
    }

    private func pressReturnKey() {
        guard AXIsProcessTrusted(),
              let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 36, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 36, keyDown: false) else {
            return
        }

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private func presentError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "New File"
        alert.informativeText = message
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

enum UntitledFileCreator {
    static func create(in directory: URL) throws -> URL {
        for number in 1...10_000 {
            let filename = number == 1 ? "untitled" : "untitled \(number)"
            let candidate = directory.appendingPathComponent(filename, isDirectory: false)

            do {
                try Data().write(to: candidate, options: .withoutOverwriting)
                return candidate
            } catch CocoaError.fileWriteFileExists {
                continue
            }
        }

        throw CocoaError(.fileWriteUnknown)
    }
}
