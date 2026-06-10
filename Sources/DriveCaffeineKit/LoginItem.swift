import Foundation
#if canImport(ServiceManagement)
import ServiceManagement
#endif

// Launch-at-login control via SMAppService (macOS 13+). This registers the app
// itself as a login item — no separate helper bundle, no deprecated
// SMLoginItemSetEnabled. The user toggles it; macOS persists the choice.
//
// Wrapped so the UI doesn't touch SMAppService directly and so the kit still
// compiles on platforms without ServiceManagement (tests).
public enum LoginItem {

    /// Whether the app is currently registered to launch at login.
    public static var isEnabled: Bool {
        #if canImport(ServiceManagement)
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        #endif
        return false
    }

    /// True if launch-at-login can be controlled in this build/runtime. It can't
    /// from a raw `swift run` binary (no app bundle) or pre-macOS-13.
    public static var isSupported: Bool {
        #if canImport(ServiceManagement)
        if #available(macOS 13.0, *) { return true }
        #endif
        return false
    }

    /// Turn launch-at-login on or off. Returns nil on success, or a
    /// human-readable reason on failure (e.g. the user must approve it in
    /// System Settings → General → Login Items the first time).
    @discardableResult
    public static func setEnabled(_ enabled: Bool) -> String? {
        #if canImport(ServiceManagement)
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    // If already enabled, register() is a harmless no-op.
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    try SMAppService.mainApp.unregister()
                }
                return nil
            } catch {
                return "Couldn't change Launch at Login. You may need to approve it in System Settings → General → Login Items. (\(error.localizedDescription))"
            }
        }
        #endif
        return "Launch at Login requires macOS 13 or later."
    }
}
