//
//  AccessibilityPermission.swift
//  Clipstack
//

import AppKit
import ApplicationServices
import Observation
import OSLog

/// Tracks whether Clipstack may send ⌘V to other apps, which macOS treats as an Accessibility feature.
@Observable
final class AccessibilityPermission {
    private(set) var isTrusted = AXIsProcessTrusted()

    /// macOS only shows its prompt once. After that, people turn access on in System Settings.
    private(set) var hasAsked = UserDefaults.standard.bool(forKey: "hasAskedForAccessibility")

    @ObservationIgnored private var watchTask: Task<Void, Never>?

    init() {
        Logger(subsystem: "com.noahmidgley.Clipstack", category: "Permissions")
            .info("Accessibility access at launch: \(self.isTrusted ? "granted" : "not granted", privacy: .public)")
        // macOS posts this whenever the Accessibility list in System Settings changes.
        watchTask = Task { [weak self] in
            let changes = DistributedNotificationCenter.default().notifications(named: .init("com.apple.accessibility.api"))
            for await _ in changes {
                // The new value can take a moment to apply.
                try? await Task.sleep(for: .milliseconds(300))
                self?.refresh()
            }
        }
    }

    func refresh() {
        isTrusted = AXIsProcessTrusted()
    }

    /// Shows the system prompt the first time, then opens System Settings.
    func requestAccess() {
        // Asking every time also re-adds this build to the list in System Settings,
        // which matters when an entry from an older build no longer matches.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        isTrusted = AXIsProcessTrustedWithOptions(options)
        if hasAsked && !isTrusted {
            openSettings()
        }
        hasAsked = true
        UserDefaults.standard.set(true, forKey: "hasAskedForAccessibility")
    }

    func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
