import Foundation

enum ManagedPreference: String, CaseIterable, Codable {
    case naturalScrolling
    case dockAutoHide
    case dockRevealDelay
    case dockAnimationDuration
    case finderShowHiddenFiles
    case finderSoundEffects
    case finderQuitMenuItem

    enum ValueKind: String, Codable {
        case bool
        case double
    }

    enum RestartTarget {
        case none
        case dock
        case finder
    }

    var domain: String {
        switch self {
        case .naturalScrolling: "NSGlobalDomain"
        case .dockAutoHide, .dockRevealDelay, .dockAnimationDuration: "com.apple.dock"
        case .finderShowHiddenFiles, .finderSoundEffects, .finderQuitMenuItem: "com.apple.finder"
        }
    }

    var key: String {
        switch self {
        case .naturalScrolling: "com.apple.swipescrolldirection"
        case .dockAutoHide: "autohide"
        case .dockRevealDelay: "autohide-delay"
        case .dockAnimationDuration: "autohide-time-modifier"
        case .finderShowHiddenFiles: "AppleShowAllFiles"
        case .finderSoundEffects: "FXEnableSoundEffects"
        case .finderQuitMenuItem: "QuitMenuItem"
        }
    }

    var kind: ValueKind {
        switch self {
        case .dockRevealDelay, .dockAnimationDuration: .double
        default: .bool
        }
    }

    var restartTarget: RestartTarget {
        switch self {
        case .naturalScrolling: .none
        case .dockAutoHide, .dockRevealDelay, .dockAnimationDuration: .dock
        case .finderShowHiddenFiles, .finderSoundEffects, .finderQuitMenuItem: .finder
        }
    }
}

private struct PreferenceSnapshot: Codable {
    let existed: Bool
    let rawValue: String?
}

enum PreferenceError: LocalizedError {
    case commandFailed(String)
    case invalidValue(String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message): message
        case .invalidValue(let value): "macOS returned an unsupported preference value: \(value)"
        }
    }
}

final class SystemPreferenceManager {
    private let backupKey = "managedPreferenceBackupsV1"
    private let appDefaults = UserDefaults.standard

    func bool(for preference: ManagedPreference) -> Bool? {
        guard let raw = readRaw(preference) else { return nil }
        switch raw.lowercased() {
        case "1", "true", "yes": return true
        case "0", "false", "no": return false
        default: return nil
        }
    }

    func double(for preference: ManagedPreference) -> Double? {
        guard let raw = readRaw(preference) else { return nil }
        return Double(raw)
    }

    func setBool(_ value: Bool, for preference: ManagedPreference) throws {
        try captureOriginalIfNeeded(preference)
        try runDefaults(["write", preference.domain, preference.key, "-bool", value ? "true" : "false"])
        restart(preference.restartTarget)
    }

    func setDouble(_ value: Double, for preference: ManagedPreference) throws {
        try captureOriginalIfNeeded(preference)
        try runDefaults(["write", preference.domain, preference.key, "-float", String(value)])
        restart(preference.restartTarget)
    }

    func unset(_ preference: ManagedPreference) throws {
        try captureOriginalIfNeeded(preference)
        try delete(preference)
        restart(preference.restartTarget)
    }

    func restore(_ preference: ManagedPreference) throws {
        guard let snapshot = snapshots()[preference.rawValue] else {
            try delete(preference)
            restart(preference.restartTarget)
            return
        }
        try restore(snapshot, preference: preference)
        var saved = snapshots()
        saved.removeValue(forKey: preference.rawValue)
        saveSnapshots(saved)
        restart(preference.restartTarget)
    }

    func restoreAll() throws {
        let saved = snapshots()
        var restartDock = false
        var restartFinder = false

        for preference in ManagedPreference.allCases {
            guard let snapshot = saved[preference.rawValue] else { continue }
            try restore(snapshot, preference: preference)
            switch preference.restartTarget {
            case .dock: restartDock = true
            case .finder: restartFinder = true
            case .none: break
            }
        }

        saveSnapshots([:])
        if restartDock { restart(.dock) }
        if restartFinder { restart(.finder) }
    }

    private func captureOriginalIfNeeded(_ preference: ManagedPreference) throws {
        var saved = snapshots()
        guard saved[preference.rawValue] == nil else { return }
        let raw = readRaw(preference)
        saved[preference.rawValue] = PreferenceSnapshot(existed: raw != nil, rawValue: raw)
        saveSnapshots(saved)
    }

    private func restore(_ snapshot: PreferenceSnapshot, preference: ManagedPreference) throws {
        guard snapshot.existed, let raw = snapshot.rawValue else {
            try delete(preference)
            return
        }

        switch preference.kind {
        case .bool:
            let normalized = raw.lowercased()
            guard ["1", "true", "yes", "0", "false", "no"].contains(normalized) else {
                throw PreferenceError.invalidValue(raw)
            }
            try runDefaults(["write", preference.domain, preference.key, "-bool", ["1", "true", "yes"].contains(normalized) ? "true" : "false"])
        case .double:
            guard Double(raw) != nil else { throw PreferenceError.invalidValue(raw) }
            try runDefaults(["write", preference.domain, preference.key, "-float", raw])
        }
    }

    private func delete(_ preference: ManagedPreference) throws {
        let result = run(executable: "/usr/bin/defaults", arguments: ["delete", preference.domain, preference.key])
        if result.status != 0, readRaw(preference) != nil {
            throw PreferenceError.commandFailed(result.error)
        }
    }

    private func readRaw(_ preference: ManagedPreference) -> String? {
        let result = run(executable: "/usr/bin/defaults", arguments: ["read", preference.domain, preference.key])
        guard result.status == 0 else { return nil }
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func runDefaults(_ arguments: [String]) throws {
        let result = run(executable: "/usr/bin/defaults", arguments: arguments)
        guard result.status == 0 else {
            throw PreferenceError.commandFailed(result.error.isEmpty ? "The macOS defaults command failed." : result.error)
        }
    }

    private func restart(_ target: ManagedPreference.RestartTarget) {
        let processName: String
        switch target {
        case .none: return
        case .dock: processName = "Dock"
        case .finder: processName = "Finder"
        }
        _ = run(executable: "/usr/bin/killall", arguments: [processName])
    }

    private func snapshots() -> [String: PreferenceSnapshot] {
        guard let data = appDefaults.data(forKey: backupKey) else { return [:] }
        return (try? JSONDecoder().decode([String: PreferenceSnapshot].self, from: data)) ?? [:]
    }

    private func saveSnapshots(_ values: [String: PreferenceSnapshot]) {
        if values.isEmpty {
            appDefaults.removeObject(forKey: backupKey)
        } else if let data = try? JSONEncoder().encode(values) {
            appDefaults.set(data, forKey: backupKey)
        }
    }

    private func run(executable: String, arguments: [String]) -> (status: Int32, output: String, error: String) {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (-1, "", error.localizedDescription)
        }

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (process.terminationStatus, output, error.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
