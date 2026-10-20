//
//  ClipstackApp.swift
//  Clipstack
//
//  Created by Noah Midgley on 20/10/2026.
//

import SwiftUI

@main
struct ClipstackApp: App {
    @State private var store: HistoryStore
    private let monitor: ClipboardMonitor

    init() {
        let store = HistoryStore()
        let monitor = ClipboardMonitor(store: store)
        monitor.start()
        _store = State(initialValue: store)
        self.monitor = monitor
    }

    var body: some Scene {
        MenuBarExtra("Clipstack", systemImage: "list.clipboard") {
            HistoryPopover(monitor: monitor)
                .environment(store)
        }
        // .window gives a popover-style panel instead of a plain menu.
        .menuBarExtraStyle(.window)
    }
}
