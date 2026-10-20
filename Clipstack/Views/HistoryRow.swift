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
    /// The context menu title for choosing, "Copy" or "Paste".
    var chooseTitle = "Copy"
    /// Read by VoiceOver, such as "Copies to the clipboard".
    var chooseHint = "Copies to the clipboard"
    var onChoose: () -> Void
    /// When set, a click selects the row and a double-click chooses it.
    var onSelect: (() -> Void)?
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
                subtitle
                    .font(.subheadline)
                    .foregroundStyle(secondaryStyle)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let shortcutNumber {
                Text("⌘\(shortcutNumber)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(secondaryStyle)
            }

            pinButton
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .foregroundStyle(isSelected ? Color(nsColor: .alternateSelectedControlTextColor) : .primary)
        .environment(\.backgroundProminence, isSelected ? .increased : .standard)
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
        .onTapGesture { (onSelect ?? onChoose)() }
        .simultaneousGesture(TapGesture(count: 2).onEnded(onChoose), including: onSelect == nil ? .none : .all)
        .onHover { isHovering = $0 }
        .contextMenu {
            Button(chooseTitle, action: onChoose)
            Button(item.isPinned ? "Unpin" : "Pin", action: onTogglePin)
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
        // VoiceOver reads the row as one element, with pin and delete as actions.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.accessibilityDescription(now: now, shortcutNumber: shortcutNumber))
        .accessibilityHint(chooseHint)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction(.default, onChoose)
        .accessibilityAction(named: item.isPinned ? "Unpin" : "Pin", onTogglePin)
        .accessibilityAction(named: "Delete", onDelete)
    }

    /// On the blue selection, grey text drops to about 2.7:1, so selected rows use full white (5.4:1).
    private var secondaryStyle: AnyShapeStyle {
        isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary)
    }

    /// Shown while pinned, hovered or selected, so rows stay calm otherwise. When hidden it isn't
    /// drawn at all, so keyboard focus can't land on an invisible button.
    @ViewBuilder
    private var pinButton: some View {
        if item.isPinned || isHovering || isSelected {
            Button(action: onTogglePin) {
                Image(systemName: item.isPinned ? "pin.fill" : "pin")
                    .frame(width: 24, height: 24)
                    .contentShape(.rect)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(item.isPinned && !isSelected ? AnyShapeStyle(.tint) : secondaryStyle)
            .help(item.isPinned ? "Unpin" : "Pin")
        } else {
            Color.clear.frame(width: 24, height: 24)
        }
    }

    /// "Safari · 2 min ago", or the device symbol and "Other Device" for Universal Clipboard.
    private var subtitle: Text {
        let time = ClipItem.timeFormatter.localizedString(for: item.date, relativeTo: now)
        guard let source = item.sourceName else { return Text(time) }
        if item.isFromOtherDevice {
            return Text("\(Image(systemName: ClipItem.otherDeviceSymbol)) \(source) · \(time)")
        }
        return Text("\(source) · \(time)")
    }
}
