//
//  HistoryPopover.swift
//  Clipstack
//

import AppKit
import SwiftUI

/// The window that opens from the menu bar icon.
struct HistoryPopover: View {
    @Environment(HistoryStore.self) private var store
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
            if store.canUndoClear {
                Text("History cleared")
                    .foregroundStyle(.secondary)
                Button("Undo Clear") {
                    store.undoClear()
                }
                .keyboardShortcut("z")
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
                Button("Quick Paste") {
                    close()
                    quickPaste.show()
                }
                .keyboardShortcut("v", modifiers: [.shift, .command])
                Divider()
                Button("Quit Clipstack") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            } label: {
                Image(systemName: "ellipsis.circle")
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
            // ⌘Q also works while the menu is closed.
            Button("Quit") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
                .opacity(0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Actions

    private func choose(_ item: ClipItem) {
        monitor.copy(item)
        close()
    }

    private func close() {
        NSApp.keyWindow?.close()
    }
}
