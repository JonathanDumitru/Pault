//
//  GlobalHotkeyManager.swift
//  Pault
//

import Foundation
import Carbon
import AppKit
import os

private let hotkeyLogger = Logger(subsystem: "com.pault.app", category: "hotkey")

class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()

    private var eventHandler: EventHandlerRef?
    private var hotkeyID = EventHotKeyID()
    private var hotkeyRef: EventHotKeyRef?
    private var callback: (() -> Void)?

    private init() {}

    func register(keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) {
        self.callback = callback

        unregister()

        hotkeyID.signature = fourCharCodeFrom("PALT")
        hotkeyID.id = 1

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.callback?()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        if status != noErr {
            hotkeyLogger.error("Failed to install event handler: \(status)")
            return
        }

        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        if registerStatus != noErr {
            hotkeyLogger.error("Failed to register hotkey: \(registerStatus)")
        }
    }

    func unregister() {
        if let hotkeyRef = hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
            self.hotkeyRef = nil
        }
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    private func fourCharCodeFrom(_ string: String) -> FourCharCode {
        var result: FourCharCode = 0
        for char in string.utf8.prefix(4) {
            result = (result << 8) + FourCharCode(char)
        }
        return result
    }

    deinit {
        unregister()
    }
}

extension GlobalHotkeyManager {
    static let keyCodeP: UInt32 = 0x23
}
