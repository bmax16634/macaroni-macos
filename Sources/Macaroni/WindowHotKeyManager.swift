import Carbon
import Foundation

enum WindowHotKeyError: LocalizedError {
    case couldNotInstallHandler(OSStatus)
    case shortcutUnavailable(WindowSnapAction, OSStatus)

    var errorDescription: String? {
        switch self {
        case .couldNotInstallHandler(let status):
            "Macaroni could not start its window-shortcut handler (error \(status))."
        case .shortcutUnavailable(let action, _):
            "The \(action.shortcutDescription) shortcut for \(action.title) is already in use."
        }
    }
}

final class WindowHotKeyManager {
    var actionHandler: ((WindowSnapAction) -> Void)?

    private static let signature: OSType = 0x4D_43_52_4E // "MCRN"
    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRefs: [EventHotKeyRef] = []

    deinit {
        unregisterAll()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        unregisterAll()
        guard enabled else { return }

        try installEventHandlerIfNeeded()
        do {
            try register(.leftHalf, keyCode: UInt32(kVK_LeftArrow))
            try register(.rightHalf, keyCode: UInt32(kVK_RightArrow))
            try register(.maximize, keyCode: UInt32(kVK_Return))
        } catch {
            unregisterAll()
            throw error
        }
    }

    private func installEventHandlerIfNeeded() throws {
        guard eventHandlerRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }

                var hotKeyID = EventHotKeyID()
                let result = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard result == noErr,
                      hotKeyID.signature == WindowHotKeyManager.signature,
                      let action = WindowSnapAction(rawValue: hotKeyID.id) else {
                    return OSStatus(eventNotHandledErr)
                }

                let manager = Unmanaged<WindowHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    manager.actionHandler?(action)
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
        guard status == noErr else {
            throw WindowHotKeyError.couldNotInstallHandler(status)
        }
    }

    private func register(_ action: WindowSnapAction, keyCode: UInt32) throws {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: action.rawValue)
        let modifiers = UInt32(controlKey | optionKey)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard status == noErr, let hotKeyRef else {
            throw WindowHotKeyError.shortcutUnavailable(action, status)
        }
        hotKeyRefs.append(hotKeyRef)
    }

    private func unregisterAll() {
        hotKeyRefs.forEach { UnregisterEventHotKey($0) }
        hotKeyRefs.removeAll()
    }
}
