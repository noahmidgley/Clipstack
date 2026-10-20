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

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private var expiryTask: Task<Void, Never>?

    @ObservationIgnored let directory: URL
    @ObservationIgnored let filesDirectory: URL
    @ObservationIgnored private var historyFile: URL { directory.appending(path: "history.json") }

    init(settings: AppSettings) {
        self.settings = settings
        let support = URL.applicationSupportDirectory.appending(path: "Clipstack", directoryHint: .isDirectory)
        directory = support
        filesDirectory = support.appending(path: "Files", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: filesDirectory, withIntermediateDirectories: true)
        load()
        enforceLimits()
        // Check once an hour so old items expire even when nothing new is copied.
        expiryTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3600), tolerance: .seconds(300))
                self?.enforceLimits()
            }
        }
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
        applyLimits()
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
        applyLimits()
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

    /// Removes items outside the current limits and saves.
    func enforceLimits() {
        if applyLimits() { save() }
    }

    /// Unpinned items that the given limits would remove: the oldest beyond `maxItems`,
    /// and any older than `maxAgeDays` (0 means no age limit). Pinned items are never removed.
    func itemsOutsideLimits(maxItems: Int, maxAgeDays: Int, now: Date = .now) -> [ClipItem] {
        let cutoff = maxAgeDays > 0 ? Calendar.current.date(byAdding: .day, value: -maxAgeDays, to: now) : nil
        var unpinnedSeen = 0
        return items.filter { item in
            guard !item.isPinned else { return false }
            unpinnedSeen += 1
            if unpinnedSeen > maxItems { return true }
            if let cutoff, item.date < cutoff { return true }
            return false
        }
    }

    /// Returns true if anything was removed.
    @discardableResult
    private func applyLimits() -> Bool {
        let removed = itemsOutsideLimits(maxItems: settings.maxItems, maxAgeDays: settings.maxAgeDays)
        guard !removed.isEmpty else { return false }
        let ids = Set(removed.map(\.id))
        items.removeAll { ids.contains($0.id) }
        removed.forEach(deleteFiles)
        return true
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
