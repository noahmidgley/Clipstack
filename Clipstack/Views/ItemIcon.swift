//
//  ItemIcon.swift
//  Clipstack
//

import AppKit
import SwiftUI

/// The leading icon for an item: a symbol, a colour swatch or an image thumbnail.
struct ItemIcon: View {
    @Environment(HistoryStore.self) private var store
    /// Increased on a selected row, where the symbol needs full strength to stay visible on blue.
    @Environment(\.backgroundProminence) private var prominence
    let item: ClipItem
    var size: CGFloat = 28

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
    }

    var body: some View {
        Group {
            switch item.kind {
            case .color:
                shape
                    .fill(Color(hex: item.text) ?? .clear)
                    .overlay(shape.strokeBorder(.separator))
            case .image:
                if let image = thumbnail {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(shape)
                        .overlay(shape.strokeBorder(.separator))
                } else {
                    symbol
                }
            case .text, .link:
                symbol
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var symbol: some View {
        shape
            .fill(.quaternary)
            .overlay {
                Image(systemName: item.symbolName)
                    .font(.system(size: size * 0.45, weight: .medium))
                    .foregroundStyle(prominence == .increased ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
            }
    }

    private var thumbnail: NSImage? {
        guard let url = store.thumbnailURL(for: item) else { return nil }
        return ThumbnailCache.image(at: url)
    }
}

/// Keeps decoded thumbnails in memory so scrolling doesn't reread them from disk.
enum ThumbnailCache {
    private static let cache = NSCache<NSURL, NSImage>()

    static func image(at url: URL) -> NSImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        guard let image = NSImage(contentsOf: url) else { return nil }
        cache.setObject(image, forKey: url as NSURL)
        return image
    }
}

extension Color {
    /// Creates a colour from "#RGB", "#RRGGBB" or "#RRGGBBAA".
    init?(hex: String) {
        var digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        if digits.count == 3 {
            digits = digits.map { "\($0)\($0)" }.joined()
        }
        guard digits.count == 6 || digits.count == 8,
              let value = UInt64(digits, radix: 16) else { return nil }
        let hasAlpha = digits.count == 8
        let r = Double((value >> (hasAlpha ? 24 : 16)) & 0xFF) / 255
        let g = Double((value >> (hasAlpha ? 16 : 8)) & 0xFF) / 255
        let b = Double((value >> (hasAlpha ? 8 : 0)) & 0xFF) / 255
        let a = hasAlpha ? Double(value & 0xFF) / 255 : 1
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
