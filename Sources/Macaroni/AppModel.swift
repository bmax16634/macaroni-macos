import AppKit
import ApplicationServices
import Foundation
import ServiceManagement

enum ScrollDirection: String, CaseIterable, Identifiable {
    case natural
    case traditional

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var isNatural: Bool { self == .natural }
}

struct ScrollPolicy {
    static func shouldInvertWheel(mouse: ScrollDirection, trackpad: ScrollDirection) -> Bool {
        mouse != trackpad
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var trackpadDirection: ScrollDirection
    @Published private(set) var mouseDirection: ScrollDirection
    @Published private(set) var disableTrackpadAcceleration: Bool
    @Published private(set) var windowSnappingEnabled: Bool
    @Published private(set) var windowDragSnappingEnabled: Bool
    @Published private(set) var dockAutoHide: Bool
    @Published private(set) var instantDockReveal: Bool
    @Published private(set) var disableDockAnimation: Bool
    @Published private(set) var showHiddenFiles: Bool
    @Published private(set) var disableFinderSounds: Bool
    @Published private(set) var showQuitFinder: Bool
    @Published private(set) var finderExtensionEnabled: Bool
    @Published private(set) var launchAtLogin: Bool
    @Published private(set) var accessibilityGranted: Bool
    @Published var lastError: String?

    private let defaults = UserDefaults.standard
    private let preferences = SystemPreferenceManager()
    private let trackpadAcceleration = TrackpadAccelerationController()
    private let windowSnapController = WindowSnapController()
    private let windowHotKeys = WindowHotKeyManager()
    private lazy var windowDragSnap = WindowDragSnapManager(windowSnapController: windowSnapController)
    private var accessibilityRefreshTask: Task<Void, Never>?

    private enum Key {
        static let mouseDirection = "mouseDirection"
        static let disableTrackpadAcceleration = "disableTrackpadAcceleration"
        static let windowSnappingEnabled = "windowSnappingEnabled"
        static let windowDragSnappingEnabled = "windowDragSnappingEnabled"
    }

    init() {
        let systemNatural = preferences.bool(for: .naturalScrolling) ?? true
        trackpadDirection = systemNatural ? .natural : .traditional
        mouseDirection = defaults.string(forKey: Key.mouseDirection).flatMap(ScrollDirection.init(rawValue:)) ?? .traditional
        disableTrackpadAcceleration = defaults.bool(forKey: Key.disableTrackpadAcceleration)
        windowSnappingEnabled = defaults.object(forKey: Key.windowSnappingEnabled) as? Bool ?? true
        windowDragSnappingEnabled = defaults.object(forKey: Key.windowDragSnappingEnabled) as? Bool ?? true
        dockAutoHide = preferences.bool(for: .dockAutoHide) ?? false
        instantDockReveal = preferences.double(for: .dockRevealDelay) == 0
        disableDockAnimation = preferences.double(for: .dockAnimationDuration) == 0
        showHiddenFiles = preferences.bool(for: .finderShowHiddenFiles) ?? false
        disableFinderSounds = !(preferences.bool(for: .finderSoundEffects) ?? true)
        showQuitFinder = preferences.bool(for: .finderQuitMenuItem) ?? false
        finderExtensionEnabled = FinderExtensionController.isEnabled
        launchAtLogin = Self.loginItemEnabled
        accessibilityGranted = AXIsProcessTrusted()

        updateScrollRuntime()
        if accessibilityGranted {
            ScrollInterceptor.shared.start()
        }

        windowHotKeys.actionHandler = { [weak self] action in
            self?.snapWindow(action)
        }
        windowDragSnap.actionHandler = { [weak self] action in
            self?.snapWindow(action)
        }
        do {
            try windowHotKeys.setEnabled(windowSnappingEnabled)
        } catch {
            windowSnappingEnabled = false
            lastError = error.localizedDescription
        }
        windowDragSnap.setEnabled(windowDragSnappingEnabled && accessibilityGranted)

        if disableTrackpadAcceleration {
            do {
                try trackpadAcceleration.setDisabled(true)
            } catch {
                lastError = error.localizedDescription
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak trackpadAcceleration] _ in
            try? trackpadAcceleration?.restoreOriginalValue()
        }
    }

    func setTrackpadDirection(_ value: ScrollDirection) {
        guard value != trackpadDirection else { return }
        do {
            try preferences.setBool(value.isNatural, for: .naturalScrolling)
            trackpadDirection = value
            updateScrollRuntime()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func setMouseDirection(_ value: ScrollDirection) {
        mouseDirection = value
        defaults.set(value.rawValue, forKey: Key.mouseDirection)
        updateScrollRuntime()
    }

    func setDisableTrackpadAcceleration(_ value: Bool) {
        do {
            try trackpadAcceleration.setDisabled(value)
            disableTrackpadAcceleration = value
            defaults.set(value, forKey: Key.disableTrackpadAcceleration)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func setWindowSnappingEnabled(_ value: Bool) {
        do {
            try windowHotKeys.setEnabled(value)
            windowSnappingEnabled = value
            defaults.set(value, forKey: Key.windowSnappingEnabled)
        } catch {
            windowSnappingEnabled = false
            defaults.set(false, forKey: Key.windowSnappingEnabled)
            lastError = error.localizedDescription
        }
    }

    func setWindowDragSnappingEnabled(_ value: Bool) {
        windowDragSnappingEnabled = value
        defaults.set(value, forKey: Key.windowDragSnappingEnabled)
        windowDragSnap.setEnabled(value && accessibilityGranted)
    }

    func snapWindow(_ action: WindowSnapAction) {
        do {
            try windowSnapController.snap(action)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func setDockAutoHide(_ value: Bool) {
        apply(value, to: .dockAutoHide) { dockAutoHide = value }
    }

    func setInstantDockReveal(_ value: Bool) {
        apply(value ? 0 : nil, to: .dockRevealDelay) { instantDockReveal = value }
    }

    func setDisableDockAnimation(_ value: Bool) {
        apply(value ? 0 : nil, to: .dockAnimationDuration) { disableDockAnimation = value }
    }

    func setShowHiddenFiles(_ value: Bool) {
        apply(value, to: .finderShowHiddenFiles) { showHiddenFiles = value }
    }

    func setDisableFinderSounds(_ value: Bool) {
        apply(!value, to: .finderSoundEffects) { disableFinderSounds = value }
    }

    func setShowQuitFinder(_ value: Bool) {
        apply(value, to: .finderQuitMenuItem) { showQuitFinder = value }
    }

    func refreshFinderExtension() {
        finderExtensionEnabled = FinderExtensionController.isEnabled
    }

    func openFinderExtensionSettings() {
        FinderExtensionController.showManagementInterface()
    }

    func setLaunchAtLogin(_ value: Bool) {
        do {
            if value {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = Self.loginItemEnabled
        } catch {
            lastError = "Could not update Launch at Login: \(error.localizedDescription)"
            launchAtLogin = Self.loginItemEnabled
        }
    }

    func requestAccessibility() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        accessibilityGranted = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
        if accessibilityGranted {
            ScrollInterceptor.shared.start()
        }
        watchForAccessibilityApproval()
    }

    func refreshAccessibility() {
        accessibilityGranted = AXIsProcessTrusted()
        if accessibilityGranted {
            ScrollInterceptor.shared.start()
        }
        windowDragSnap.setEnabled(windowDragSnappingEnabled && accessibilityGranted)
    }

    func restoreOriginalSettings() {
        do {
            try preferences.restoreAll()
            try trackpadAcceleration.restoreOriginalValue()
            disableTrackpadAcceleration = false
            defaults.set(false, forKey: Key.disableTrackpadAcceleration)
            refreshFromSystem()
            updateScrollRuntime()
        } catch {
            lastError = "Could not restore all settings: \(error.localizedDescription)"
        }
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func refreshFromSystem() {
        let natural = preferences.bool(for: .naturalScrolling) ?? true
        trackpadDirection = natural ? .natural : .traditional
        mouseDirection = trackpadDirection
        defaults.set(mouseDirection.rawValue, forKey: Key.mouseDirection)
        dockAutoHide = preferences.bool(for: .dockAutoHide) ?? false
        instantDockReveal = preferences.double(for: .dockRevealDelay) == 0
        disableDockAnimation = preferences.double(for: .dockAnimationDuration) == 0
        showHiddenFiles = preferences.bool(for: .finderShowHiddenFiles) ?? false
        disableFinderSounds = !(preferences.bool(for: .finderSoundEffects) ?? true)
        showQuitFinder = preferences.bool(for: .finderQuitMenuItem) ?? false
    }

    private func updateScrollRuntime() {
        ScrollRuntimeSettings.shared.update(
            invertPhysicalWheel: ScrollPolicy.shouldInvertWheel(
                mouse: mouseDirection,
                trackpad: trackpadDirection
            )
        )
    }

    private func watchForAccessibilityApproval() {
        accessibilityRefreshTask?.cancel()
        accessibilityRefreshTask = Task { @MainActor [weak self] in
            for _ in 0..<60 {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard let self else { return }
                self.refreshAccessibility()
                if self.accessibilityGranted { return }
            }
        }
    }

    private func apply(_ value: Bool, to preference: ManagedPreference, success: () -> Void) {
        do {
            try preferences.setBool(value, for: preference)
            success()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func apply(_ value: Double?, to preference: ManagedPreference, success: () -> Void) {
        do {
            if let value {
                try preferences.setDouble(value, for: preference)
            } else {
                try preferences.unset(preference)
            }
            success()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private static var loginItemEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}
