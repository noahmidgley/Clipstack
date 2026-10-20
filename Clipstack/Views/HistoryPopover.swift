//
//  HistoryPopover.swift
//  Clipstack
//

import AppKit
import SwiftUI

/// The window that opens from the menu bar icon.
struct HistoryPopover: View {
    @Environment(HistoryStore.self) private var store
    @Environment(\.openSettings) private var openSettings
    let monitor: ClipboardMonitor
    let quickPaste: QuickPasteController

    @State private var list = HistoryListState()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HistoryList(state: $list, chooseTitle: "Copy", chooseHint: "Copies to the clipboard", clickSelects: false, onChoose: choose)
                .frame(maxHeight: .infinity)
            Divider()
            footer
        }
        .frame(width: 400, height: 500)
        .background {
            HistoryShortcuts(state: list, onChoose: choose)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            SearchField(
                text: $list.searchText,
                prompt: "Search Clipboard History",
                onMoveUp: { list.moveSelection(by: -1, in: store.items) },
                onMoveDown: { list.moveSelection(by: 1, in: store.items) },
                onSubmit: { list.selectedItem(in: store.items).map(choose) },
                onEscape: close,
                onWindowBecameKey: { list.reset() }
            )

            Picker("Filter", selection: $list.filter) {
                ForEach(HistoryFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(12)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            if let removal = store.lastRemoval {
                UndoRemovalButton(removal: removal)
            } else {
                Button("Clear History") {
                    store.clearHistory()
                    list.selectedID = nil
                }
                .disabled(!store.items.contains { !$0.isPinned })
                .help("Removes everything except pinned items. You can undo this.")
            }

            Spacer()

            Text("↩ Copy   ⌘P Pin")
                .foregroundStyle(.secondary)
                .accessibilityLabel("Return copies the selected item. Command P pins it.")

            Menu {
                Button("About Clipstack") {
                    close()
                    NSApp.activate()
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
                Divider()
                Button("Quick Paste") {
                    close()
                    quickPaste.show()
                }
                // Display only: the global shortcut catches the keys first.
                .keyboardShortcut(quickPaste.shortcut.keyboardShortcut)
                Button("Settings…", action: showSettings)
                    .keyboardShortcut(",")
                Divider()
                Button("Quit Clipstack") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            } label: {
                Image(systemName: "ellipsis.circle")
                    .frame(width: 24, height: 24)
                    .contentShape(.rect)
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("More")
            .help("More")
        }
        .font(.callout)
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            // ⌘, and ⌘Q also work while the menu is closed.
            Group {
                Button("Settings", action: showSettings)
                    .keyboardShortcut(",")
                Button("Quit") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
                .opacity(0)
                .allowsHitTesting(false)
                .focusable(false)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Actions

    private func choose(_ item: ClipItem) {
        monitor.copy(item)
        close()
    }

    /// Clipstack has no Dock icon, so it activates first to bring the Settings window to the front.
    private func showSettings() {
        close()
        NSApp.activate()
        openSettings()
    }

    private func close() {
        NSApp.keyWindow?.close()
    }
}

extension HotKeyShortcut {
    /// The same shortcut in SwiftUI terms, for showing it next to a menu item.
    var keyboardShortcut: KeyboardShortcut? {
        let named: [String: KeyEquivalent] = [
            "Space": .space, "↩": .return, "⇥": .tab, "⌫": .delete, "⌦": .deleteForward,
            "←": .leftArrow, "→": .rightArrow, "↑": .upArrow, "↓": .downArrow,
            "↖": .home, "↘": .end, "⇞": .pageUp, "⇟": .pageDown,
        ]
        let key: KeyEquivalent
        if let namedKey = named[keyName] {
            key = namedKey
        } else if keyName.count == 1, let character = keyName.lowercased().first {
            key = KeyEquivalent(character)
        } else {
            return nil // Function keys have no KeyEquivalent.
        }
        var eventModifiers: EventModifiers = []
        if modifiers.contains(.command) { eventModifiers.insert(.command) }
        if modifiers.contains(.shift) { eventModifiers.insert(.shift) }
        if modifiers.contains(.option) { eventModifiers.insert(.option) }
        if modifiers.contains(.control) { eventModifiers.insert(.control) }
        return KeyboardShortcut(key, modifiers: eventModifiers)
    }
}
