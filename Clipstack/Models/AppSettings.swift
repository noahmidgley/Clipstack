//
//  AppSettings.swift
//  Clipstack
//

import Foundation
import Observation

/// An app the clipboard monitor ignores.
struct IgnoredApp: Codable, Hashable, Identifiable {
    var bundleID: String
    var name: String
    var id: String { bundleID }
}

/// Every preference in one place. Each change is saved to UserDefaults straight away.
@Observable
final class AppSettings {
    static let shared = AppSettings()

    static let maxItemsChoices = [50, 200, 500, 1000]
    /// Days to keep items. 0 means forever.
    static let maxAgeChoices = [1, 7, 30, 0]

    @ObservationIgnored private let defaults: UserDefaults

    var quickPasteShortcut: HotKeyShortcut {
        didSet { save(quickPasteShortcut, forKey: "quickPasteShortcut") }
    }
    var showInMenuBar: Bool {
        didSet { defaults.set(showInMenuBar, forKey: "showInMenuBar") }
    }
    /// Unpinned items to keep.
    var maxItems: Int {
        didSet { defaults.set(maxItems, forKey: "maxItems") }
    }
    /// Days to keep unpinned items. 0 means forever.
    var maxAgeDays: Int {
        didSet { defaults.set(maxAgeDays, forKey: "maxAgeDays") }
    }
    var clearOnLaunch: Bool {
        didSet { defaults.set(clearOnLaunch, forKey: "clearOnLaunch") }
    }
    /// Skip copies marked concealed or transient, which password managers use.
    var skipPrivateItems: Bool {
        didSet { defaults.set(skipPrivateItems, forKey: "skipPrivateItems") }
    }
    var ignoredApps: [IgnoredApp] {
        didSet { save(ignoredApps, forKey: "ignoredApps") }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        quickPasteShortcut = Self.load(HotKeyShortcut.self, forKey: "quickPasteShortcut", from: defaults) ?? .quickPasteDefault
        showInMenuBar = defaults.object(forKey: "showInMenuBar") as? Bool ?? true
        maxItems = defaults.object(forKey: "maxItems") as? Int ?? 200
        maxAgeDays = defaults.object(forKey: "maxAgeDays") as? Int ?? 0
        clearOnLaunch = defaults.bool(forKey: "clearOnLaunch")
        skipPrivateItems = defaults.object(forKey: "skipPrivateItems") as? Bool ?? true
        ignoredApps = Self.load([IgnoredApp].self, forKey: "ignoredApps", from: defaults) ?? []
    }

    func isIgnored(bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return ignoredApps.contains { $0.bundleID == bundleID }
    }

    private func save(_ value: some Encodable, forKey key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }

    private static func load<T: Decodable>(_ type: T.Type, forKey key: String, from defaults: UserDefaults) -> T? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }
}
