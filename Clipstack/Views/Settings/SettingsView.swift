//
//  SettingsView.swift
//  Clipstack
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The Settings window. Each tab is a pane; the window title follows the selected pane.
struct SettingsView: View {
    let quickPaste: QuickPasteController

    /// Reopens on the pane people used last.
    @AppStorage("settingsPane") private var pane = Pane.general

    enum Pane: String {
        case general, history, privacy
    }

    var body: some View {
        TabView(selection: $pane) {
            GeneralSettingsPane(quickPaste: quickPaste)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(Pane.general)
            HistorySettingsPane()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(Pane.history)
            PrivacySettingsPane()
                .tabItem { Label("Privacy", systemImage: "hand.raised") }
                .tag(Pane.privacy)
        }
        .frame(width: 500)
    }
}

// MARK: - General

struct GeneralSettingsPane: View {
    @Environment(AppSettings.self) private var settings
    let quickPaste: QuickPasteController
    @State private var loginItem = LoginItem()

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                LabeledContent("Quick Paste shortcut") {
                    ShortcutRecorder(controller: quickPaste)
                }
            } footer: {
                Text("Opens Quick Paste from any app.")
                    .settingsFooter()
            }

            Section {
                Toggle("Open at login", isOn: Binding(
                    get: { loginItem.isEnabled },
                    set: { loginItem.setEnabled($0) }
                ))
                if loginItem.needsApproval {
                    LabeledContent {
                        Button("Open Login Items") { loginItem.openSystemSettings() }
                    } label: {
                        Text("Allow Clipstack in Login Items so it can open at login.")
                            .foregroundStyle(.secondary)
                    }
                }
                if let error = loginItem.errorMessage {
                    Text(error).foregroundStyle(.secondary)
                }

                Toggle("Show in menu bar", isOn: $settings.showInMenuBar)
            } footer: {
                if !settings.showInMenuBar {
                    Text("To bring the icon back, open Clipstack again from your Applications folder. Quick Paste still works with \(quickPaste.shortcut.displayString).")
                        .settingsFooter()
                }
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { loginItem.refresh() }
    }
}

// MARK: - History

struct HistorySettingsPane: View {
    @Environment(AppSettings.self) private var settings
    @Environment(HistoryStore.self) private var store

    /// A limit change that would remove items, waiting for confirmation.
    @State private var pendingLimits: (maxItems: Int, maxAgeDays: Int, removing: Int)?

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Picker("Keep up to", selection: limitBinding(\.maxItems)) {
                    ForEach(AppSettings.maxItemsChoices, id: \.self) { count in
                        Text("\(count.formatted()) items").tag(count)
                    }
                }
                Picker("Keep items for", selection: limitBinding(\.maxAgeDays)) {
                    ForEach(AppSettings.maxAgeChoices, id: \.self) { days in
                        Text(Self.ageName(days)).tag(days)
                    }
                }
            } footer: {
                Text("Older items are removed first. Pinned items are always kept and don’t count toward the limit.")
                    .settingsFooter()
            }

            Section {
                Toggle("Clear history when Clipstack starts", isOn: $settings.clearOnLaunch)
            } footer: {
                Text("Also happens after you restart your Mac. Pinned items are kept.")
                    .settingsFooter()
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
        .confirmationDialog(
            "Remove \(pendingLimits?.removing ?? 0) items?",
            isPresented: Binding(get: { pendingLimits != nil }, set: { if !$0 { pendingLimits = nil } })
        ) {
            Button("Remove Items", role: .destructive) {
                if let pendingLimits { apply(maxItems: pendingLimits.maxItems, maxAgeDays: pendingLimits.maxAgeDays) }
                pendingLimits = nil
            }
            Button("Cancel", role: .cancel) { pendingLimits = nil }
        } message: {
            Text("The new limit removes your oldest unpinned items. This can’t be undone.")
        }
    }

    /// Applies a limit straight away, unless it would remove items; then it asks first.
    private func limitBinding(_ keyPath: ReferenceWritableKeyPath<AppSettings, Int>) -> Binding<Int> {
        Binding {
            settings[keyPath: keyPath]
        } set: { newValue in
            var maxItems = settings.maxItems
            var maxAgeDays = settings.maxAgeDays
            if keyPath == \AppSettings.maxItems { maxItems = newValue } else { maxAgeDays = newValue }
            let removing = store.itemsOutsideLimits(maxItems: maxItems, maxAgeDays: maxAgeDays).count
            if removing > 0 {
                pendingLimits = (maxItems, maxAgeDays, removing)
            } else {
                apply(maxItems: maxItems, maxAgeDays: maxAgeDays)
            }
        }
    }

    private func apply(maxItems: Int, maxAgeDays: Int) {
        settings.maxItems = maxItems
        settings.maxAgeDays = maxAgeDays
        store.enforceLimits()
    }

    private static func ageName(_ days: Int) -> String {
        switch days {
        case 0: "Forever"
        case 1: "1 day"
        default: "\(days) days"
        }
    }
}

// MARK: - Privacy

struct PrivacySettingsPane: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Toggle("Skip passwords and other private items", isOn: $settings.skipPrivateItems)
            } footer: {
                Text("Password managers mark what they copy as private or temporary. Clipstack won’t save those items.")
                    .settingsFooter()
            }

            Section {
                if settings.ignoredApps.isEmpty {
                    Text("No ignored apps")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(settings.ignoredApps) { app in
                        IgnoredAppRow(app: app) {
                            settings.ignoredApps.removeAll { $0.id == app.id }
                        }
                    }
                }
                Button("Add App…", action: addApps)
            } header: {
                Text("Ignored apps")
            } footer: {
                Text("Clipstack doesn’t save anything copied in these apps.")
                    .settingsFooter()
            }

            Section {
                Label("Your clipboard history is stored only on this Mac and never leaves it.", systemImage: "lock")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func addApps() {
        let panel = NSOpenPanel()
        panel.title = "Choose Apps to Ignore"
        panel.prompt = "Ignore"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(filePath: "/Applications")
        guard panel.runModal() == .OK else { return }

        for url in panel.urls {
            guard let bundleID = Bundle(url: url)?.bundleIdentifier,
                  !settings.isIgnored(bundleID: bundleID) else { continue }
            let name = FileManager.default.displayName(atPath: url.path(percentEncoded: false))
                .replacing(/\.app$/, with: "")
            settings.ignoredApps.append(IgnoredApp(bundleID: bundleID, name: name))
        }
        settings.ignoredApps.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

private struct IgnoredAppRow: View {
    let app: IgnoredApp
    var onRemove: () -> Void

    var body: some View {
        LabeledContent {
            Button(action: onRemove) {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .help("Stop ignoring \(app.name)")
            .accessibilityLabel("Stop ignoring \(app.name)")
        } label: {
            Label {
                Text(app.name)
            } icon: {
                if let icon {
                    Image(nsImage: icon).resizable().frame(width: 20, height: 20)
                }
            }
        }
    }

    private var icon: NSImage? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID)
            .map { NSWorkspace.shared.icon(forFile: $0.path(percentEncoded: false)) }
    }
}

private extension Text {
    func settingsFooter() -> some View {
        font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
