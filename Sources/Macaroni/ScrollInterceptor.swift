// Physical-wheel interception is adapted from UnnaturalScrollWheels.
// Copyright © 2020 Theron Tjapkes. Licensed under GPLv3.

import AppKit
import CoreGraphics
import Foundation

final class ScrollRuntimeSettings {
    static let shared = ScrollRuntimeSettings()

    private let lock = NSLock()
    private var invertPhysicalWheel = false

    func update(invertPhysicalWheel: Bool) {
        lock.lock()
        self.invertPhysicalWheel = invertPhysicalWheel
        lock.unlock()
    }

    func shouldInvertPhysicalWheel() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return invertPhysicalWheel
    }
}

final class ScrollInterceptor {
    static let shared = ScrollInterceptor()

    private let stateLock = NSLock()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var runLoop: CFRunLoop?
    private var isIntercepting = false
    private var wakeObserver: NSObjectProtocol?

    private let callback: CGEventTapCallBack = { _, type, event, _ in
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            ScrollInterceptor.shared.reEnableTap()
            return Unmanaged.passUnretained(event)
        }

        guard type == .scrollWheel,
              event.getIntegerValueField(.scrollWheelEventIsContinuous) == 0,
              ScrollRuntimeSettings.shared.shouldInvertPhysicalWheel() else {
            return Unmanaged.passUnretained(event)
        }

        let vertical = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: -vertical)
        return Unmanaged.passUnretained(event)
    }

    func start() {
        stateLock.lock()
        guard !isIntercepting else {
            stateLock.unlock()
            return
        }
        isIntercepting = true
        stateLock.unlock()

        registerForWakeNotifications()

        DispatchQueue.global(qos: .userInteractive).async {
            guard let eventTap = CGEvent.tapCreate(
                tap: .cghidEventTap,
                place: .tailAppendEventTap,
                options: .defaultTap,
                eventsOfInterest: CGEventMask(1 << CGEventType.scrollWheel.rawValue),
                callback: self.callback,
                userInfo: nil
            ) else {
                self.clearState()
                return
            }

            guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) else {
                CFMachPortInvalidate(eventTap)
                self.clearState()
                return
            }

            let loop = CFRunLoopGetCurrent()
            self.stateLock.lock()
            self.eventTap = eventTap
            self.runLoopSource = source
            self.runLoop = loop
            self.stateLock.unlock()

            CFRunLoopAddSource(loop, source, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
            CFRunLoopRun()
            CFRunLoopRemoveSource(loop, source, .commonModes)
            CFMachPortInvalidate(eventTap)
            self.clearState()
        }
    }

    func reEnableTap() {
        stateLock.lock()
        let tap = eventTap
        let loop = runLoop
        stateLock.unlock()

        guard let tap else {
            start()
            return
        }

        if !CGEvent.tapIsEnabled(tap: tap) {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        if !CGEvent.tapIsEnabled(tap: tap), let loop {
            CFRunLoopStop(loop)
            DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.5) {
                self.start()
            }
        }
    }

    private func registerForWakeNotifications() {
        stateLock.lock()
        let registered = wakeObserver != nil
        stateLock.unlock()
        guard !registered else { return }

        let observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: nil
        ) { _ in
            ScrollInterceptor.shared.reEnableTap()
            DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 1) {
                ScrollInterceptor.shared.reEnableTap()
            }
        }

        stateLock.lock()
        wakeObserver = observer
        stateLock.unlock()
    }

    private func clearState() {
        stateLock.lock()
        eventTap = nil
        runLoopSource = nil
        runLoop = nil
        isIntercepting = false
        stateLock.unlock()
    }
}
