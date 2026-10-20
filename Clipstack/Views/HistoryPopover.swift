//
//  HistoryPopover.swift
//  Clipstack
//

import AppKit
import SwiftUI

enum HistoryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case text = "Text"
    case links = "Links"
    case images = "Images"
    case pinned = "Pinned"

    var id: Self { self }

    func includes(_ item: ClipItem) -> Bool {
        switch self {
        case .all: true
        case .text: item.kind == .text || item.kind == .color
        case .links: item.kind == .link
        case .images: item.kind == .image
        case .pinned: item.isPinned
        }
    }
}

/// The window that opens from the menu bar icon.
struct HistoryPopover: View {
    @Environment(HistoryStore.self) private var store
    let monitor: ClipboardMonitor

    @State private var searchText = ""
    @State private var filter = HistoryFilter.all
    @State private var selectedID: ClipItem.ID?

    var body: some View {
        let pinned = matchingItems.filter(\.isPinned)
        let recent = matchingItems.filter { !$0.isPinned }

        VStack(spacing: 0) {
            header
            Divider()
            Group {
                if pinned.isEmpty && recent.isEmpty {
                    emptyState
                } else {
                    list(pinned: pinned, recent: recent)
                }
            }
            .frame(maxHeight: .infinity)
            Divider()
            footer
        }
        .frame(width: 400, height: 500)
        .background { shortcutButtons }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            SearchField(
                text: $searchText,
                prompt: "Search Clipboard History",
                onMoveUp: { moveSelection(by: -1) },
                onMoveDown: { moveSelection(by: 1) },
                onSubmit: { selectedItem.map(choose) },
                onEscape: close,
                onWindowBecameKey: {
                    searchText = ""
                    selectedID = nil
                }
            )

            Picker("Filter", selection: $filter) {
                ForEach(HistoryFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(12)
    }

    // MARK: - List

    private func list(pinned: [ClipItem], recent: [ClipItem]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                // Redraws every 30 seconds so "2 min ago" stays accurate.
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    LazyVStack(alignment: .leading, spacing: 2) {
                        if !pinned.isEmpty {
                            sectionHeader("Pinned")
                            rows(pinned, startingAt: 0, now: context.date)
                            if !recent.isEmpty {
                                sectionHeader("Recent")
                            }
                        }
                        rows(recent, startingAt: pinned.count, now: context.date)
                    }
                    .padding(6)
                }
            }
            .onChange(of: selectedID) { _, id in
                if let id { proxy.scrollTo(id) }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .accessibilityAddTraits(.isHeader)
    }

    private func rows(_ items: [ClipItem], startingAt offset: Int, now: Date) -> some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            let position = offset + index
            HistoryRow(
                item: item,
                shortcutNumber: position < 9 ? position + 1 : nil,
                isSelected: item.id == selectedItem?.id,
                now: now,
                onChoose: { choose(item) },
                onTogglePin: { store.togglePin(item) },
                onDelete: { store.delete(item) }
            )
            .id(item.id)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if store.items.isEmpty {
            ContentUnavailableView {
                Label("No Clipboard History", systemImage: "list.clipboard")
            } description: {
                Text("Copy text, links, images or colours and they’ll appear here.")
            }
        } else if !searchText.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else if filter == .pinned {
            ContentUnavailableView {
                Label("No Pinned Items", systemImage: "pin")
            } description: {
                Text("Pin items you use often to keep them at the top.")
            }
        } else {
            ContentUnavailableView("No \(filter.rawValue)", systemImage: "line.3.horizontal.decrease.circle")
        }
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
                    selectedID = nil
                }
                .disabled(!store.items.contains { !$0.isPinned })
                .help("Removes everything except pinned items. You can undo this.")
            }

            Spacer()

            Text("↩ Copy   ⌘P Pin")
                .foregroundStyle(.secondary)
                .accessibilityLabel("Return copies the selected item. Command P pins it.")

            Menu {
                Button("Quit Clipstack") { NSApp.terminate(nil) }
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
    }

    /// Invisible buttons that give the popover its keyboard shortcuts.
    private var shortcutButtons: some View {
        Group {
            ForEach(1...9, id: \.self) { number in
                Button("Copy Item \(number)") { chooseItem(at: number - 1) }
                    .keyboardShortcut(KeyEquivalent(Character("\(number)")), modifiers: .command)
            }
            Button("Pin") { selectedItem.map(store.togglePin) }
                .keyboardShortcut("p")
            Button("Delete") { selectedItem.map(store.delete) }
                .keyboardShortcut(.delete)
            Button("Quit") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Data and actions

    private var matchingItems: [ClipItem] {
        store.items.filter { item in
            guard filter.includes(item) else { return false }
            guard !searchText.isEmpty else { return true }
            return item.displayText.localizedStandardContains(searchText)
                || (item.sourceAppName?.localizedStandardContains(searchText) ?? false)
        }
    }

    /// Pinned first, then recent: the order shown on screen.
    private var visibleItems: [ClipItem] {
        let items = matchingItems
        return items.filter(\.isPinned) + items.filter { !$0.isPinned }
    }

    /// The selected item, falling back to the first row.
    private var selectedItem: ClipItem? {
        let items = visibleItems
        return items.first { $0.id == selectedID } ?? items.first
    }

    private func moveSelection(by offset: Int) {
        let items = visibleItems
        guard !items.isEmpty else { return }
        let current = items.firstIndex { $0.id == selectedItem?.id } ?? 0
        let next = min(max(current + offset, 0), items.count - 1)
        selectedID = items[next].id
    }

    private func chooseItem(at index: Int) {
        let items = visibleItems
        guard items.indices.contains(index) else { return }
        choose(items[index])
    }

    private func choose(_ item: ClipItem) {
        monitor.copy(item)
        close()
    }

    private func close() {
        NSApp.keyWindow?.close()
    }
}
