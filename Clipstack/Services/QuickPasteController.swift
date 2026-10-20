//
//  QuickPasteController.swift
//  Clipstack
//

import AppKit
import Carbon.HIToolbox
import Observation
import OSLog
import SwiftUI

/// Owns the global shortcut and the quick paste panel, and pastes into the app you were using.
@Observable
final class QuickPasteController: NSObject, NSWindowDelegate {
    @ObservationIgnored private let store: HistoryStore
    @ObservationIgnored private let monitor: ClipboardMonitor
    @ObservationIgnored let permission: AccessibilityPermission
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private var panel: QuickPastePanel?
    @ObservationIgnored private lazy var hotKey = GlobalHotKey { [weak self] in self?.toggle() }

    /// The app that was in front when the panel opened. Pasting sends ⌘V to it.
    private(set) var targetApp: NSRunningApplication?

    init(store: HistoryStore, monitor: ClipboardMonitor, permission: AccessibilityPermission, settings: AppSettings) {
        self.store = store
        self.monitor = monitor
        self.permission = permission
        self.settings = settings
        super.init()
        resumeShortcut()
    }

    private static let log = Logger(subsystem: "com.noahmidgley.Clipstack", category: "QuickPaste")

    // MARK: - Shortcut

    var shortcut: HotKeyShortcut { settings.quickPasteShortcut }

    /// Switches to a new shortcut. Returns false, keeping the old one, if another app already uses it.
    func changeShortcut(to newShortcut: HotKeyShortcut) -> Bool {
        guard hotKey.register(newShortcut) else {
            Self.log.error("Couldn’t register \(newShortcut.displayString, privacy: .public). Another app may be using it.")
            resumeShortcut()
            return false
        }
        settings.quickPasteShortcut = newShortcut
        return true
    }

    /// Stops listening while Settings records a new shortcut, so pressing the current one is captured.
    func suspendShortcut() {
        hotKey.unregister()
    }

    func resumeShortcut() {
        if !hotKey.register(shortcut) {
            Self.log.error("Couldn’t register \(self.shortcut.displayString, privacy: .public). Another app may be using it.")
        }
    }

    // MARK: - Showing and hiding

    func toggle() {
        if panel?.isVisible == true { hide() } else { show() }
    }

    func show() {
        let frontmost = NSWorkspace.shared.frontmostApplication
        if frontmost?.processIdentifier != NSRunningApplication.current.processIdentifier {
            targetApp = frontmost
        }
        permission.refresh()

        let panel = panel ?? makePanel()
        self.panel = panel
        position(panel)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    /// Clicking anywhere else dismisses the panel, like Spotlight.
    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    private func makePanel() -> QuickPastePanel {
        let view = QuickPasteView(controller: self)
            .environment(store)
            .environment(permission)
        let panel = QuickPastePanel(contentView: NSHostingView(rootView: view))
        panel.delegate = self
        return panel
    }

    /// Centres the panel a little above the middle of the screen the pointer is on.
    private func position(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2,
                                     y: visible.midY - size.height / 2 + visible.height / 10))
    }

    // MARK: - Pasting

    /// Puts the item on the clipboard, closes the panel and, with permission, presses ⌘V in the target app.
    func paste(_ item: ClipItem, asPlainText: Bool = false) {
        monitor.copy(item, asPlainText: asPlainText)
        hide()
        guard permission.isTrusted else { return }
        targetApp?.activate()
        Task {
            // Give the target app a moment to take keyboard focus back.
            try? await Task.sleep(for: .milliseconds(80))
            Self.pressCommandV()
        }
    }

    private static func pressCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey = CGKeyCode(kVK_ANSI_V)
        for isDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: isDown)
            event?.flags = .maskCommand
            event?.post(tap: .cgAnnotatedSessionEventTap)
        }
    }
}

/// A floating panel that takes keyboard focus without making Clipstack the active app.
final class QuickPastePanel: NSPanel {
    init(contentView: NSView) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 760, height: 460),
                   styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        self.contentView = contentView
        title = "Quick Paste"
        isFloatingPanel = true
        level = .floating
        // Appear on the current Space, including over full-screen apps.
        collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        contentMinSize = NSSize(width: 620, height: 360)
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
    }

    override var canBecomeKey: Bool { true }

    /// Esc closes the panel when focus isn't in the search field.
    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }
}
