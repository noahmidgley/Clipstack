//
//  HistoryRow.swift
//  Clipstack
//

import SwiftUI

/// One item in the history list.
struct HistoryRow: View {
    let item: ClipItem
    /// 1–9 for the first nine rows, shown as a ⌘ shortcut.
    let shortcutNumber: Int?
    let isSelected: Bool
    let now: Date
    var onChoose: () -> Void
    var onTogglePin: () -> Void
    var onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            ItemIcon(item: item)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.rowText)
                    .lineLimit(2)
                    .truncationMode(.tail)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let shortcutNumber {
                Text("⌘\(shortcutNumber)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            pinButton
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .foregroundStyle(isSelected ? Color(nsColor: .alternateSelectedControlTextColor) : .primary)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(nsColor: .selectedContentBackgroundColor))
            } else if isHovering {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.quinary)
            }
        }
        .contentShape(.rect)
        .onTapGesture(perform: onChoose)
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Copy", action: onChoose)
            Button(item.isPinned ? "Unpin" : "Pin", action: onTogglePin)
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
        // VoiceOver reads the row as one element, with pin and delete as actions.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Copies to the clipboard")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction(.default, onChoose)
        .accessibilityAction(named: item.isPinned ? "Unpin" : "Pin", onTogglePin)
        .accessibilityAction(named: "Delete", onDelete)
    }

    /// Visible while pinned, hovered or selected, so rows stay calm otherwise.
    private var pinButton: some View {
        Button(action: onTogglePin) {
            Image(systemName: item.isPinned ? "pin.fill" : "pin")
                .frame(width: 24, height: 24)
                .contentShape(.rect)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(item.isPinned && !isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
        .opacity(item.isPinned || isHovering || isSelected ? 1 : 0)
        .help(item.isPinned ? "Unpin" : "Pin")
    }

    private var subtitle: String {
        let time = Self.timeFormatter.localizedString(for: item.date, relativeTo: now)
        guard let app = item.sourceAppName else { return time }
        return "\(app) · \(time)"
    }

    private var accessibilityText: String {
        var parts = [item.kindName, item.kind == .image ? item.text : item.rowText]
        if let app = item.sourceAppName { parts.append("from \(app)") }
        parts.append(Self.timeFormatter.localizedString(for: item.date, relativeTo: now))
        if item.isPinned { parts.append("Pinned") }
        if let shortcutNumber { parts.append("Command \(shortcutNumber)") }
        return parts.joined(separator: ", ")
    }

    private static let timeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.dateTimeStyle = .named // "now" rather than "in 0 sec."
        return formatter
    }()
}
