//
//  GlobalHotkeyManager.swift
//  LumiAgent
//
//  Registers a system-wide hotkey using Carbon's RegisterEventHotKey.
//  This properly *intercepts* the key — it never reaches the frontmost app —
//  unlike NSEvent.addGlobalMonitorForEvents which only observes.
//
//  Default: ⌥⌘L  (Option + Command + L)
//  Change by calling register(keyCode:modifiers:) with different values.
//

import Carbon.HIToolbox
import Foundation

// MARK: - Carbon key constants (bridged for Swift clarity)

extension GlobalHotkeyManager {
    /// Carbon virtual key codes for common keys.
    enum KeyCode {
        static let L: UInt32     = UInt32(kVK_ANSI_L)
        static let Space: UInt32 = UInt32(kVK_Space)
    }
    /// Carbon modifier flags.
    enum Modifiers {
        static let command: UInt32 = UInt32(cmdKey)      // 256
        static let option: UInt32  = UInt32(optionKey)   // 2048
        static let shift: UInt32   = UInt32(shiftKey)    // 512
        static let control: UInt32 = UInt32(controlKey)  // 4096
    }
}

// MARK: - Manager

final class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    /// Called on the main thread when the hotkey is pressed.
    var onActivate: (() -> Void)?

    private init() {}

    // MARK: Register / Unregister

    /// Register the global hotkey. Safe to call multiple times — re-registers.
    func register(keyCode: UInt32 = KeyCode.L,
                  modifiers: UInt32 = Modifiers.option | Modifiers.command) {
        unregister()

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        // Pass a raw pointer to self so the C callback can call back into Swift.
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, userInfo) -> OSStatus in
                guard let ptr = userInfo else { return OSStatus(eventNotHandledErr) }
                let mgr = Unmanaged<GlobalHotkeyManager>
                    .fromOpaque(ptr)
                    .takeUnretainedValue()
                DispatchQueue.main.async { mgr.onActivate?() }
                return noErr
            },
            1,
            &spec,
            selfPtr,
            &eventHandlerRef
        )

        // 'LUMI' as FourCharCode = 0x4C554D49
        var hkID = EventHotKeyID(signature: 0x4C554D49, id: 1)
        RegisterEventHotKey(
            keyCode, modifiers, hkID,
            GetApplicationEventTarget(), 0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let ref = hotKeyRef   { UnregisterEventHotKey(ref); hotKeyRef = nil }
        if let ref = eventHandlerRef { RemoveEventHandler(ref); eventHandlerRef = nil }
    }
}
