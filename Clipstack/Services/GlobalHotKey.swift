//
//  GlobalHotKey.swift
//  Clipstack
//

import AppKit
import Carbon.HIToolbox

/// A key plus modifiers, saved in UserDefaults so it can be changed in Settings.
struct HotKeyShortcut: Codable, Equatable {
    /// The physical key, such as kVK_ANSI_V.
    var keyCode: UInt32
    var modifiers: NSEvent.ModifierFlags
    /// What the key shows, such as "V", captured when the shortcut was recorded.
    var keyName: String

    static let quickPasteDefault = HotKeyShortcut(keyCode: UInt32(kVK_ANSI_V), modifiers: [.shift, .command], keyName: "V")

    /// Modifier symbols in Apple's order (Control, Option, Shift, Command), then the key: "⇧⌘V".
    var displayString: String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        return result + keyName
    }

    var carbonModifiers: UInt32 {
        var result = 0
        if modifiers.contains(.command) { result |= cmdKey }
        if modifiers.contains(.shift) { result |= shiftKey }
        if modifiers.contains(.option) { result |= optionKey }
        if modifiers.contains(.control) { result |= controlKey }
        return UInt32(result)
    }

    enum CodingKeys: CodingKey { case keyCode, modifiers, keyName }

    init(keyCode: UInt32, modifiers: NSEvent.ModifierFlags, keyName: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection([.command, .shift, .option, .control])
        self.keyName = keyName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(keyCode: try container.decode(UInt32.self, forKey: .keyCode),
                  modifiers: NSEvent.ModifierFlags(rawValue: try container.decode(UInt.self, forKey: .modifiers)),
                  keyName: try container.decode(String.self, forKey: .keyName))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keyCode, forKey: .keyCode)
        try container.encode(modifiers.rawValue, forKey: .modifiers)
        try container.encode(keyName, forKey: .keyName)
    }
}

/// A system-wide keyboard shortcut that works whichever app is in front.
final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void
    private(set) var shortcut: HotKeyShortcut?

    init(action: @escaping () -> Void) {
        self.action = action
    }

    /// Registers the shortcut, replacing any previous one. Returns false if another app already owns it.
    @discardableResult
    func register(_ shortcut: HotKeyShortcut) -> Bool {
        unregister()
        installHandlerIfNeeded()
        let id = EventHotKeyID(signature: OSType(0x434C_5053), id: 1) // "CLPS"
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.carbonModifiers, id,
                                         GetApplicationEventTarget(), 0, &hotKeyRef)
        guard status == noErr else { return false }
        self.shortcut = shortcut
        return true
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
        shortcut = nil
    }

    fileprivate func fire() {
        action()
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), hotKeyHandler, 1, &eventType,
                            Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
    }
}

/// Carbon calls this C function on the main thread when the shortcut is pressed.
private nonisolated func hotKeyHandler(_: EventHandlerCallRef?, _: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let userData else { return noErr }
    MainActor.assumeIsolated {
        Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue().fire()
    }
    return noErr
}
