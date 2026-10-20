//
//  HistoryStore.swift
//  Clipstack
//

import AppKit
import ImageIO
import Observation
import UniformTypeIdentifiers

/// Holds the clipboard history and saves it to disk. Nothing here touches the network.
@Observable
final class HistoryStore {
    /// Newest first. Pinned items are mixed in; views group them.
    private(set) var items: [ClipItem] = []
    /// Items removed by the last "Clear History", kept so it can be undone.
    private(set) var clearedItems: [ClipItem]?

    var canUndoClear: Bool { clearedItems != nil }

    /// Unpinned items to keep. Becomes a setting later.
    var maxItems: Int {
        UserDefaults.standard.object(forKey: "maxItems") as? Int ?? 200
    }

    @ObservationIgnored let directory: URL
    @ObservationIgnored let filesDirectory: URL
    @ObservationIgnored private var historyFile: URL { directory.appending(path: "history.json") }

    init() {
        let support = URL.applicationSupportDirectory.appending(path: "Clipstack", directoryHint: .isDirectory)
        directory = support
        filesDirectory = support.appending(path: "Files", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: filesDirectory, withIntermediateDirectories: true)
        load()
    }

    // MARK: - Changing the history

    /// Adds a new item, or moves an existing identical one to the top.
    func add(_ item: ClipItem) {
        if let index = items.firstIndex(where: { $0.contentKey == item.contentKey }) {
            var existing = items.remove(at: index)
            existing.date = item.date
            existing.sourceAppName = item.sourceAppName
            existing.sourceBundleID = item.sourceBundleID
            existing.origin = item.origin
            items.insert(existing, at: 0)
            // Delete any files the new copy saved that the existing item doesn't use.
            deleteFiles(item.fileNames.subtracting(existing.fileNames))
        } else {
            items.insert(item, at: 0)
        }
        trimToLimit()
        save()
    }

    /// Moves an item to the top after someone picks it from the history.
    func markUsed(_ item: ClipItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        var used = items.remove(at: index)
        used.date = .now
        items.insert(used, at: 0)
        save()
    }

    func togglePin(_ item: ClipItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        trimToLimit()
        save()
    }

    func delete(_ item: ClipItem) {
        items.removeAll { $0.id == item.id }
        deleteFiles(for: item)
        save()
    }

    /// Removes every unpinned item. Pinned items stay.
    func clearHistory() {
        discardClearedItems()
        let removed = items.filter { !$0.isPinned }
        guard !removed.isEmpty else { return }
        items.removeAll { !$0.isPinned }
        clearedItems = removed
        save()
    }

    func undoClear() {
        guard let restored = clearedItems else { return }
        clearedItems = nil
        items = (items + restored).sorted { $0.date > $1.date }
        save()
    }

    /// Makes the last clear permanent by deleting its image files.
    func discardClearedItems() {
        clearedItems?.forEach(deleteFiles)
        clearedItems = nil
    }

    private func trimToLimit() {
        var unpinnedSeen = 0
        var removed: [ClipItem] = []
        items.removeAll { item in
            guard !item.isPinned else { return false }
            unpinnedSeen += 1
            if unpinnedSeen > maxItems {
                removed.append(item)
                return true
            }
            return false
        }
        removed.forEach(deleteFiles)
    }

    // MARK: - Images

    func imageURL(for item: ClipItem) -> URL? {
        item.imageFileName.map { filesDirectory.appending(path: $0) }
    }

    func thumbnailURL(for item: ClipItem) -> URL? {
        item.thumbnailFileName.map { filesDirectory.appending(path: $0) }
    }

    /// Saves image data as a PNG plus a small thumbnail. Returns the file name and pixel size.
    func saveImage(_ data: Data) -> (fileName: String, width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }

        let fileName = UUID().uuidString + ".png"
        let url = filesDirectory.appending(path: fileName)
        guard writePNG(image, to: url) else { return nil }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 128,
        ]
        if let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) {
            _ = writePNG(thumbnail, to: filesDirectory.appending(path: "thumb-" + fileName))
        }
        return (fileName, image.width, image.height)
    }

    private func writePNG(_ image: CGImage, to url: URL) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            return false
        }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination)
    }

    // MARK: - Formatted text

    /// Saves RTF or HTML data and returns its file name, such as "….rtf".
    func saveRichText(_ data: Data, type: NSPasteboard.PasteboardType) -> String? {
        let fileName = UUID().uuidString + (type == .rtf ? ".rtf" : ".html")
        do {
            try data.write(to: filesDirectory.appending(path: fileName), options: .atomic)
            return fileName
        } catch {
            return nil
        }
    }

    /// The saved formatting for an item and the pasteboard type to write it as.
    func richText(for item: ClipItem) -> (data: Data, type: NSPasteboard.PasteboardType)? {
        guard let fileName = item.richTextFileName,
              let data = try? Data(contentsOf: filesDirectory.appending(path: fileName)) else { return nil }
        return (data, fileName.hasSuffix(".rtf") ? .rtf : .html)
    }

    private func deleteFiles(for item: ClipItem) {
        deleteFiles(item.fileNames)
    }

    private func deleteFiles(_ fileNames: Set<String>) {
        for fileName in fileNames {
            try? FileManager.default.removeItem(at: filesDirectory.appending(path: fileName))
        }
    }

    func item(withContentKey key: String) -> ClipItem? {
        items.first { $0.contentKey == key }
    }

    // MARK: - Saving and loading

    private func save() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: historyFile, options: [.atomic, .completeFileProtection])
        } catch {
            print("Couldn’t save history: \(error)")
        }
    }

    private func load() {
        if let data = try? Data(contentsOf: historyFile),
           let saved = try? JSONDecoder().decode([ClipItem].self, from: data) {
            items = saved
        }
        removeOrphanedImages()
    }

    /// Deletes files that no item refers to, such as ones left behind by a clear that was never undone.
    private func removeOrphanedImages() {
        let inUse = items.reduce(into: Set<String>()) { $0.formUnion($1.fileNames) }
        let files = (try? FileManager.default.contentsOfDirectory(atPath: filesDirectory.path())) ?? []
        for file in files where !inUse.contains(file) {
            try? FileManager.default.removeItem(at: filesDirectory.appending(path: file))
        }
    }
}
