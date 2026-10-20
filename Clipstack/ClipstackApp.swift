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
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var settings: AppSettings
    @State private var store: HistoryStore
    private let monitor: ClipboardMonitor
    private let quickPaste: QuickPasteController

    init() {
        Self.quitOtherInstances()
        let settings = AppSettings.shared
        let store = HistoryStore(settings: settings)
        if settings.clearOnLaunch {
            store.clearHistory()
            store.discardRemoval()
        }
        let monitor = ClipboardMonitor(store: store, settings: settings)
        monitor.start()
        _settings = State(initialValue: settings)
        _store = State(initialValue: store)
        self.monitor = monitor
        quickPaste = QuickPasteController(store: store, monitor: monitor,
                                          permission: AccessibilityPermission(), settings: settings)
    }

    var body: some Scene {
        MenuBarExtra("Clipstack", systemImage: "list.clipboard", isInserted: $settings.showInMenuBar) {
            HistoryPopover(monitor: monitor, quickPaste: quickPaste)
                .environment(store)
        }
        // .window gives a popover-style panel instead of a plain menu.
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(quickPaste: quickPaste)
                .environment(settings)
                .environment(store)
        }
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

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Opening Clipstack while it's already running brings back a hidden menu bar icon.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        AppSettings.shared.showInMenuBar = true
        return true
    }
}
