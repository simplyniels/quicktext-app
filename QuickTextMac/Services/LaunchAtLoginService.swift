import Foundation
import Observation
import ServiceManagement

@Observable
@MainActor
final class LaunchAtLoginService {
    var isEnabled = false
    var helperText = "Quick Text startet nicht automatisch."
    var errorText: String?

    init() {
        refresh()
    }

    func refresh() {
        let status = SMAppService.mainApp.status

        switch status {
        case .enabled:
            isEnabled = true
            helperText = "Quick Text startet beim Anmelden automatisch."
        case .notFound:
            isEnabled = false
            helperText = "Quick Text muss in /Applications liegen, damit der Anmeldestart verf\u{00FC}gbar ist."
        case .requiresApproval:
            isEnabled = true
            helperText = "Noch in den Systemeinstellungen freigeben."
        case .notRegistered:
            isEnabled = false
            helperText = "Quick Text startet nicht automatisch."
        @unknown default:
            isEnabled = false
            helperText = "Auf diesem Mac nicht verfügbar."
        }
    }

    func setEnabled(_ enabled: Bool) {
        errorText = nil

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refresh()
        } catch {
            refresh()
            errorText = enabled
                ? "Anmeldestart konnte nicht aktiviert werden. Lege Quick Text in /Applications und versuche es erneut."
                : "Anmeldestart konnte nicht deaktiviert werden. Bitte versuche es erneut."
        }
    }
}
