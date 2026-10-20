//
//  SearchField.swift
//  Clipstack
//

import AppKit
import SwiftUI

/// A native NSSearchField that keeps focus while the arrow keys, Return and Esc drive the list.
struct SearchField: NSViewRepresentable {
    @Binding var text: String
    var prompt: String
    var onMoveUp: () -> Void = {}
    var onMoveDown: () -> Void = {}
    var onSubmit: () -> Void = {}
    /// Esc with an empty field.
    var onEscape: () -> Void = {}
    /// Called each time the field's window becomes key, such as when the popover opens.
    var onWindowBecameKey: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> AutoFocusSearchField {
        let field = AutoFocusSearchField()
        field.placeholderString = prompt
        field.setAccessibilityLabel(prompt)
        field.delegate = context.coordinator
        field.focusRingType = .default
        return field
    }

    func updateNSView(_ field: AutoFocusSearchField, context: Context) {
        context.coordinator.parent = self
        field.onWindowBecameKey = onWindowBecameKey
        if field.stringValue != text {
            field.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: SearchField

        init(parent: SearchField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.moveUp(_:)):
                parent.onMoveUp()
            case #selector(NSResponder.moveDown(_:)):
                parent.onMoveDown()
            case #selector(NSResponder.insertNewline(_:)):
                parent.onSubmit()
            case #selector(NSResponder.cancelOperation(_:)):
                // First Esc clears the search, the next one closes.
                if parent.text.isEmpty {
                    parent.onEscape()
                } else {
                    parent.text = ""
                    control.stringValue = ""
                }
            default:
                return false
            }
            return true
        }
    }
}

/// Takes keyboard focus whenever its window becomes key, so you can type straight away.
final class AutoFocusSearchField: NSSearchField {
    var onWindowBecameKey: () -> Void = {}
    private var keyTask: Task<Void, Never>?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        keyTask?.cancel()
        guard let window else { return }
        keyTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: NSWindow.didBecomeKeyNotification, object: window) {
                guard let self else { return }
                self.window?.makeFirstResponder(self)
                self.onWindowBecameKey()
            }
        }
    }
}
