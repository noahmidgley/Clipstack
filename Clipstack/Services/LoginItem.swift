//
//  LoginItem.swift
//  Clipstack
//

import Observation
import ServiceManagement

/// Opens Clipstack at login. macOS keeps the real state, since people can also change it
/// in System Settings, so this always asks SMAppService rather than saving its own copy.
@Observable
final class LoginItem {
    private(set) var status = SMAppService.mainApp.status
    private(set) var errorMessage: String?

    var isEnabled: Bool { status == .enabled || status == .requiresApproval }
    var needsApproval: Bool { status == .requiresApproval }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            errorMessage = "Couldn’t change this setting. Try again in System Settings → General → Login Items."
        }
        refresh()
    }

    func refresh() {
        status = SMAppService.mainApp.status
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
