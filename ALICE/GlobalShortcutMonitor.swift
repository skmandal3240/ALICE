//
//  GlobalShortcutMonitor.swift
//  ALICE
//
//  System-wide push-to-talk via listen-only CGEvent tap.
//  Default shortcut: ctrl + option (configurable).
//

import AppKit
import Combine
import CoreGraphics
import Foundation

enum ShortcutTransition {
    case pressed
    case released
}

final class GlobalShortcutMonitor: ObservableObject {
    let shortcutTransitionPublisher = PassthroughSubject<ShortcutTransition, Never>()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    @Published private(set) var isPressed = false

    // Default shortcut: ctrl + option
    // ponytail: single shortcut for now; configurable shortcuts are a UI concern, not an engine concern
    private let requiredFlags: CGEventFlags = [.maskControl, .maskAlternate]

    deinit { stop() }

    func start() {
        guard eventTap == nil else { return }

        let mask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)
                            | (1 << CGEventType.keyDown.rawValue)
                            | (1 << CGEventType.keyUp.rawValue)

        let callback: CGEventTapCallBack = { _, eventType, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<GlobalShortcutMonitor>.fromOpaque(userInfo).takeUnretainedValue()
            return monitor.handle(eventType: eventType, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            return
        }

        self.eventTap = tap
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        isPressed = false
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        if let tap = eventTap {
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
    }

    private func handle(eventType: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if eventType == .tapDisabledByTimeout || eventType == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let flags = event.flags
        let match = flags.contains(.maskControl) && flags.contains(.maskAlternate)
        // Ensure no extra modifiers (no shift, no command)
        let noExtras = !flags.contains(.maskShift) && !flags.contains(.maskCommand)

        if match && noExtras && !isPressed {
            isPressed = true
            shortcutTransitionPublisher.send(.pressed)
        } else if (!match || !noExtras) && isPressed {
            isPressed = false
            shortcutTransitionPublisher.send(.released)
        }

        return Unmanaged.passUnretained(event)
    }
}
