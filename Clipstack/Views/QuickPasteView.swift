//
//  QuickPasteView.swift
//  Clipstack
//

import SwiftUI

/// The content of the quick paste panel: history on the left, a preview on the right.
struct QuickPasteView: View {
    @Environment(HistoryStore.self) private var store
    @Environment(AccessibilityPermission.self) private var permission
    let controller: QuickPasteController

    @State private var list = HistoryListState()

    var body: some View {
        let selected = list.selectedItem(in: store.items)

        VStack(spacing: 0) {
            if !permission.isTrusted {
                AccessibilityBanner()
                Divider()
            }

            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    SearchField(
                        text: $list.searchText,
                        prompt: "Search Clipboard History",
                        onMoveUp: { list.moveSelection(by: -1, in: store.items) },
                        onMoveDown: { list.moveSelection(by: 1, in: store.items) },
                        onSubmit: { selected.map { paste($0) } },
                        onAlternateSubmit: { selected.map { paste($0, asPlainText: true) } },
                        onEscape: controller.hide,
                        onWindowBecameKey: { list.reset() }
                    )
                    .padding(10)
                    Divider()
                    HistoryList(state: $list, chooseTitle: pasteTitle, chooseHint: pasteHint, clickSelects: true) { paste($0) }
                    Divider()
                    Group {
                        if let removal = store.lastRemoval {
                            UndoRemovalButton(removal: removal)
                                .font(.callout)
                                .controlSize(.small)
                                .padding(.vertical, 6)
                        } else {
                            keyboardHints
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(width: 300)

                Divider()

                if let selected {
                    VStack(spacing: 0) {
                        ItemPreview(item: selected)
                        Divider()
                        actions(for: selected)
                    }
                } else {
                    ContentUnavailableView("No Item Selected", systemImage: "doc.on.clipboard")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(minWidth: 620, minHeight: 360)
        .background {
            HistoryShortcuts(state: list) { paste($0) }
        }
    }

    // MARK: - Actions

    private func actions(for item: ClipItem) -> some View {
        HStack(spacing: 8) {
            Button {
                store.togglePin(item)
            } label: {
                Label(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin")
            }

            Spacer()

            Button(permission.isTrusted ? "Paste as Plain Text" : "Copy as Plain Text") {
                paste(item, asPlainText: true)
            }
            .keyboardShortcut(.return, modifiers: .option)
            .disabled(item.kind == .image)

            Button(pasteTitle) {
                paste(item)
            }
            .keyboardShortcut(.defaultAction)
            .help(pasteHint)
        }
        .padding(12)
    }

    private var keyboardHints: some View {
        Text("↩ \(pasteTitle)   ⌥↩ Plain Text   ⌘P Pin")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .accessibilityLabel("Return: \(pasteTitle). Option-Return: plain text. Command-P: pin.")
    }

    /// Without Accessibility access, Clipstack can only copy, so the buttons say so.
    private var pasteTitle: String {
        permission.isTrusted ? "Paste" : "Copy"
    }

    private var pasteHint: String {
        guard permission.isTrusted else { return "Copies to the clipboard" }
        guard let name = controller.targetApp?.localizedName else { return "Pastes into the app you were using" }
        return "Pastes into \(name)"
    }

    private func paste(_ item: ClipItem, asPlainText: Bool = false) {
        controller.paste(item, asPlainText: asPlainText)
    }
}

/// Explains why Accessibility access is needed. Its one button leads to the system prompt.
struct AccessibilityBanner: View {
    @Environment(AccessibilityPermission.self) private var permission

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "accessibility")
                .font(.title2)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Let Clipstack Paste for You")
                    .font(.headline)
                Text("To paste, Clipstack presses ⌘V in the app you were using, which needs Accessibility access. It’s used for nothing else. Until then, items are copied and you press ⌘V yourself.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if permission.hasAsked {
                    Text("Already switched on? Remove Clipstack from the list with the – button, then click Open System Settings again.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            Button(permission.hasAsked ? "Open System Settings" : "Continue") {
                permission.requestAccess()
            }
        }
        .padding(12)
        .background(.quinary)
        .accessibilityElement(children: .contain)
    }
}
