//
//  HistoryList.swift
//  Clipstack
//

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

/// Search, filter and selection, shared by the popover and the quick paste panel.
struct HistoryListState {
    var searchText = ""
    var filter = HistoryFilter.all
    var selectedID: ClipItem.ID?

    /// Matching items split into pinned and recent, in the order shown on screen.
    func sections(of items: [ClipItem]) -> (pinned: [ClipItem], recent: [ClipItem]) {
        let matching = items.filter { item in
            guard filter.includes(item) else { return false }
            guard !searchText.isEmpty else { return true }
            return item.displayText.localizedStandardContains(searchText)
                || (item.sourceAppName?.localizedStandardContains(searchText) ?? false)
        }
        return (matching.filter(\.isPinned), matching.filter { !$0.isPinned })
    }

    func visibleItems(of items: [ClipItem]) -> [ClipItem] {
        let sections = sections(of: items)
        return sections.pinned + sections.recent
    }

    /// The selected item, falling back to the first row.
    func selectedItem(in items: [ClipItem]) -> ClipItem? {
        let visible = visibleItems(of: items)
        return visible.first { $0.id == selectedID } ?? visible.first
    }

    func item(at index: Int, in items: [ClipItem]) -> ClipItem? {
        let visible = visibleItems(of: items)
        return visible.indices.contains(index) ? visible[index] : nil
    }

    mutating func moveSelection(by offset: Int, in items: [ClipItem]) {
        let visible = visibleItems(of: items)
        guard !visible.isEmpty else { return }
        let current = visible.firstIndex { $0.id == selectedItem(in: items)?.id } ?? 0
        selectedID = visible[min(max(current + offset, 0), visible.count - 1)].id
    }

    /// Called each time the popover or panel opens.
    mutating func reset() {
        searchText = ""
        selectedID = nil
    }
}

/// The scrolling list of pinned and recent items, or an empty state.
struct HistoryList: View {
    @Environment(HistoryStore.self) private var store
    @Binding var state: HistoryListState
    /// "Copy" or "Paste", for the context menu.
    let chooseTitle: String
    /// What Return, a double-click or VoiceOver's default action does, such as "Pastes into Safari".
    let chooseHint: String
    /// When true, a single click selects and a double-click chooses. When false, a click chooses.
    let clickSelects: Bool
    var onChoose: (ClipItem) -> Void

    var body: some View {
        let sections = state.sections(of: store.items)
        let selectedID = state.selectedItem(in: store.items)?.id

        if sections.pinned.isEmpty && sections.recent.isEmpty {
            emptyState
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    // Redraws every 30 seconds so "2 min ago" stays accurate.
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        LazyVStack(alignment: .leading, spacing: 2) {
                            if !sections.pinned.isEmpty {
                                sectionHeader("Pinned")
                                rows(sections.pinned, startingAt: 0, selectedID: selectedID, now: context.date)
                                if !sections.recent.isEmpty {
                                    sectionHeader("Recent")
                                }
                            }
                            rows(sections.recent, startingAt: sections.pinned.count, selectedID: selectedID, now: context.date)
                        }
                        .padding(6)
                    }
                }
                .onChange(of: state.selectedID) { _, id in
                    if let id { proxy.scrollTo(id) }
                }
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

    private func rows(_ items: [ClipItem], startingAt offset: Int, selectedID: ClipItem.ID?, now: Date) -> some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            let position = offset + index
            HistoryRow(
                item: item,
                shortcutNumber: position < 9 ? position + 1 : nil,
                isSelected: item.id == selectedID,
                now: now,
                chooseTitle: chooseTitle,
                chooseHint: chooseHint,
                onChoose: { onChoose(item) },
                onSelect: clickSelects ? { state.selectedID = item.id } : nil,
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
        } else if !state.searchText.isEmpty {
            ContentUnavailableView.search(text: state.searchText)
        } else if state.filter == .pinned {
            ContentUnavailableView {
                Label("No Pinned Items", systemImage: "pin")
            } description: {
                Text("Pin items you use often to keep them at the top.")
            }
        } else {
            ContentUnavailableView("No \(state.filter.rawValue)", systemImage: "line.3.horizontal.decrease.circle")
        }
    }
}

/// Invisible buttons for ⌘1–⌘9, ⌘P (pin) and ⌘⌫ (delete) on the selected item.
struct HistoryShortcuts: View {
    @Environment(HistoryStore.self) private var store
    let state: HistoryListState
    var onChoose: (ClipItem) -> Void

    var body: some View {
        Group {
            ForEach(1...9, id: \.self) { number in
                Button("Choose Item \(number)") {
                    state.item(at: number - 1, in: store.items).map(onChoose)
                }
                .keyboardShortcut(KeyEquivalent(Character("\(number)")), modifiers: .command)
            }
            Button("Pin") { state.selectedItem(in: store.items).map(store.togglePin) }
                .keyboardShortcut("p")
            Button("Delete") { state.selectedItem(in: store.items).map(store.delete) }
                .keyboardShortcut(.delete)
        }
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
