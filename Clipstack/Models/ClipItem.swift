//
//  ClipItem.swift
//  Clipstack
//

import Foundation

/// One entry in the clipboard history.
struct ClipItem: Identifiable, Codable, Hashable {
    enum Kind: String, Codable {
        case text, link, image, color
    }

    var id = UUID()
    var kind: Kind
    /// The text, URL string or hex code. For images, a short description like "Image 1024 × 768".
    var text: String
    /// File name of the full-size PNG and its thumbnail, for images only.
    var imageFileName: String?
    /// File name of saved RTF or HTML formatting, for text copied with styles.
    var richTextFileName: String?
    /// Used to spot duplicates: the text itself, or a hash of the image data.
    var contentKey: String
    var sourceAppName: String?
    var sourceBundleID: String?
    var date = Date.now
    var isPinned = false

    var thumbnailFileName: String? {
        imageFileName.map { "thumb-" + $0 }
    }

    /// Every file this item owns on disk.
    var fileNames: Set<String> {
        Set([imageFileName, thumbnailFileName, richTextFileName].compactMap(\.self))
    }

    /// A readable name for the kind, used by VoiceOver and the preview.
    var kindName: String {
        switch kind {
        case .text: "Text"
        case .link: "Link"
        case .image: "Image"
        case .color: "Colour"
        }
    }

    /// The text to show people. File links show their path rather than "file:///…".
    var displayText: String {
        if kind == .link, let url = URL(string: text), url.isFileURL {
            return url.path(percentEncoded: false)
        }
        return text
    }

    /// A short, single-paragraph version for list rows.
    var rowText: String {
        String(displayText.prefix(300))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacing(/\s+/, with: " ")
    }

    var symbolName: String {
        switch kind {
        case .text: "text.alignleft"
        case .link: "link"
        case .image: "photo"
        case .color: "paintpalette"
        }
    }
}

extension ClipItem {
    /// Matches #RGB, #RRGGBB and #RRGGBBAA.
    private static let hexPattern = /^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/

    static func isHexColor(_ string: String) -> Bool {
        string.wholeMatch(of: hexPattern) != nil
    }

    /// A web or file link with no surrounding text.
    static func isLink(_ string: String) -> Bool {
        guard !string.contains(where: \.isWhitespace),
              let url = URL(string: string),
              let scheme = url.scheme?.lowercased() else { return false }
        return ["http", "https", "mailto", "file"].contains(scheme)
            && (url.host() != nil || scheme == "mailto" || scheme == "file")
    }
}
