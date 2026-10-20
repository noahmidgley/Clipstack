//
//  ItemPreview.swift
//  Clipstack
//

import AppKit
import SwiftUI

/// The full content of an item, with its details underneath.
struct ItemPreview: View {
    @Environment(HistoryStore.self) private var store
    let item: ClipItem

    @State private var image: NSImage?

    /// Very long text is cut short so the preview stays fast.
    private static let previewLimit = 50_000

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            details
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task(id: item.id) {
            image = store.imageURL(for: item).flatMap(NSImage.init(contentsOf:))
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .text, .link:
            ScrollView {
                Text(String(item.displayText.prefix(Self.previewLimit)))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
        case .color:
            VStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hex: item.text) ?? .clear)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.separator))
                    .frame(width: 120, height: 120)
                    .accessibilityHidden(true)
                Text(item.text)
                    .font(.title2.monospaced())
                    .textSelection(.enabled)
            }
        case .image:
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(16)
                    .accessibilityLabel(item.text)
            } else {
                ContentUnavailableView("Image Unavailable", systemImage: "photo")
            }
        }
    }

    // MARK: - Details

    private var details: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 4) {
            detailRow("Type") { Text(item.kindName) }
            if let app = item.sourceAppName {
                detailRow("Source") {
                    Label {
                        Text(app)
                    } icon: {
                        if let icon = sourceAppIcon {
                            Image(nsImage: icon).resizable().frame(width: 16, height: 16)
                        }
                    }
                }
            }
            detailRow("Copied") {
                Text(item.date.formatted(date: .abbreviated, time: .shortened))
            }
            switch item.kind {
            case .text, .link:
                let stats = TextStats(item.displayText)
                detailRow("Characters") { Text(stats.characters, format: .number) }
                detailRow("Words") { Text(stats.words, format: .number) }
            case .image:
                if let size = pixelSize {
                    detailRow("Size") { Text("\(size.width) × \(size.height) pixels") }
                }
            case .color:
                if let rgb = rgbDescription {
                    detailRow("RGB") { Text(rgb) }
                }
            }
        }
        .font(.callout)
    }

    private func detailRow(_ label: String, @ViewBuilder value: () -> some View) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
            value()
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
    }

    private var sourceAppIcon: NSImage? {
        guard let bundleID = item.sourceBundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))
    }

    private var pixelSize: (width: Int, height: Int)? {
        guard let rep = image?.representations.first else { return nil }
        return (rep.pixelsWide, rep.pixelsHigh)
    }

    private var rgbDescription: String? {
        guard let color = Color(hex: item.text).map(NSColor.init)?.usingColorSpace(.sRGB) else { return nil }
        let values = [color.redComponent, color.greenComponent, color.blueComponent].map { Int(($0 * 255).rounded()) }
        return values.map(String.init).joined(separator: ", ")
    }
}

/// Character and word counts for a piece of text.
struct TextStats {
    let characters: Int
    let words: Int

    init(_ text: String) {
        characters = text.count
        var words = 0
        text.enumerateSubstrings(in: text.startIndex..., options: [.byWords, .substringNotRequired]) { _, _, _, _ in
            words += 1
        }
        self.words = words
    }
}
