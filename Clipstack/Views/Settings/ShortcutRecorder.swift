//
//  ShortcutRecorder.swift
//  Clipstack
//

import AppKit
import Carbon.HIToolbox
import SwiftUI

/// A button that shows the quick paste shortcut and records a new one when clicked.
struct ShortcutRecorder: View {
    let controller: QuickPasteController

    @State private var isRecording = false
    @State private var keyMonitor: Any?
    @State private var message: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 8) {
                if controller.shortcut != .quickPasteDefault && !isRecording {
                    Button("Restore Default") {
                        apply(.quickPasteDefault)
                    }
                }
                Button {
                    isRecording ? stopRecording() : startRecording()
                } label: {
                    Text(isRecording ? "Type Shortcut…" : controller.shortcut.displayString)
                        .frame(minWidth: 96)
                }
                .accessibilityLabel("Quick Paste shortcut")
                .accessibilityValue(isRecording ? "Recording" : controller.shortcut.spokenString)
                .accessibilityHint(isRecording ? "Press the new shortcut, or Escape to cancel." : "Click to record a new shortcut.")
            }
            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onDisappear(perform: stopRecording)
    }

    private func startRecording() {
        message = nil
        isRecording = true
        controller.suspendShortcut()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event)
            return nil // Don't let the key do anything else while recording.
        }
    }

    private func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        controller.resumeShortcut()
    }

    private func handle(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        if event.keyCode == UInt16(kVK_Escape) && modifiers.isEmpty {
            stopRecording()
            return
        }
        guard !modifiers.intersection([.command, .option, .control]).isEmpty else {
            message = "Include ⌘, ⌥ or ⌃ so the shortcut doesn’t get in the way of typing."
            return
        }
        guard let keyName = Self.keyName(for: event) else {
            message = "That key can’t be used. Try a letter, number or function key."
            return
        }
        stopRecording()
        apply(HotKeyShortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers, keyName: keyName))
    }

    private func apply(_ shortcut: HotKeyShortcut) {
        if controller.changeShortcut(to: shortcut) {
            message = nil
        } else {
            message = "Another app is already using \(shortcut.displayString). Try a different shortcut."
        }
    }

    /// What to show for a key: "V", "1", "Space", "F5", "←".
    private static func keyName(for event: NSEvent) -> String? {
        let named: [Int: String] = [
            kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
            kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
            kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
            kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        ]
        if let name = named[Int(event.keyCode)] { return name }
        // Without modifiers, so Shift-1 shows "1" rather than "!".
        guard let characters = event.characters(byApplyingModifiers: []),
              let character = characters.first, !character.isWhitespace, !character.isNewline else { return nil }
        return String(character).uppercased()
    }
}
