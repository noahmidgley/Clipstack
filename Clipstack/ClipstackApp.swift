//
//  ClipstackApp.swift
//  Clipstack
//
//  Created by Noah Midgley on 20/10/2026.
//

import AppKit
import SwiftUI

@main
struct ClipstackApp: App {
    @State private var store: HistoryStore
    private let monitor: ClipboardMonitor
    private let quickPaste: QuickPasteController

    init() {
        Self.quitOtherInstances()
        let store = HistoryStore()
        let monitor = ClipboardMonitor(store: store)
        monitor.start()
        _store = State(initialValue: store)
        self.monitor = monitor
        quickPaste = QuickPasteController(store: store, monitor: monitor, permission: AccessibilityPermission())
    }

    var body: some Scene {
        MenuBarExtra("Clipstack", systemImage: "list.clipboard") {
            HistoryPopover(monitor: monitor, quickPaste: quickPaste)
                .environment(store)
        }
        // .window gives a popover-style panel instead of a plain menu.
        .menuBarExtraStyle(.window)
    }

    /// Two copies would show two menu bar icons and write the same history file,
    /// so the newest launch replaces any copy that's already running.
    private static func quitOtherInstances() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0 != .current }
            .forEach { $0.terminate() }
    }
}
