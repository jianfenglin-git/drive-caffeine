import XCTest
@testable import DriveCaffeineKit

// Regression tests for the "toggle needs two clicks / checkbox lies about real
// state" bug (2026-06-06). Root cause: the UI mirrored mode state in local
// @State that drifted from the controller's model. The UI now binds directly to
// the model, so these tests assert the MODEL is the single source of truth —
// which is exactly what the checkbox now reads from.
@MainActor
final class ToggleStateTests: XCTestCase {

    private func makeController() -> (KeepAliveController, String) {
        let store = BookmarkStore(store: MemoryStore())
        let id = VolumeIdentity(uuid: "TOGGLE-TEST", name: "TestDrive")
        store.saveSettings(VolumeSettings(identity: id))   // read default, no bookmark
        let controller = KeepAliveController(store: store)
        return (controller, id.storageKey)
    }

    // A single setMode call flips the model on the FIRST call — not the second.
    func testSingleCallTogglesModelOnce() {
        let (c, key) = makeController()
        // Default is read-on, write-off.
        XCTAssertTrue(c.volumes.first?.settings.modes.contains(.read) ?? false)
        XCTAssertFalse(c.volumes.first?.settings.modes.contains(.write) ?? true)

        // Enable write with ONE call (not mounted, so test-on-toggle is skipped).
        let reason = c.setMode(.write, enabled: true, forKey: key)
        XCTAssertNil(reason, "enabling write on an unmounted volume should succeed")
        XCTAssertTrue(c.volumes.first!.settings.modes.contains(.write),
                      "model must reflect write=on after a SINGLE call")
    }

    // Disabling BOTH modes is allowed (the user is letting the drive sleep).
    // No rejection, no error — the volume goes to .disabled. This replaces the
    // old "can't disable last mode" popup, which caused a focus-cycle in the
    // menu-bar popover (2026-06-06).
    func testDisablingBothModesIsAllowedAndMarksDisabled() {
        let (c, key) = makeController()
        // Only read is on; turning it off should succeed (no error returned).
        let reason = c.setMode(.read, enabled: false, forKey: key)
        XCTAssertNil(reason, "disabling the last mode must NOT be rejected")
        XCTAssertFalse(c.volumes.first!.settings.modes.isActive,
                       "both modes off → modes is empty")
        XCTAssertEqual(c.volumes.first!.status, .disabled,
                       "empty modes → status is .disabled, not active")
    }

    // setMode must NOT do blocking I/O — enabling a mode returns immediately and
    // the volume goes to .checking (the first background poke verifies). This is
    // the regression for "checking read/write froze the UI for 10s on a sleeping
    // drive" (2026-06-06). We can't mount a real volume here, but we assert the
    // synchronous path returns nil fast and never enters .failed inline.
    func testEnablingModeDoesNotBlockOrFailInline() {
        let (c, key) = makeController()
        // No bookmark/URL is active in this unit context, so arm() is skipped and
        // status won't change to .checking — but the key invariant holds: the
        // call returns nil synchronously with no I/O and no inline failure.
        let reason = c.setMode(.write, enabled: true, forKey: key)
        XCTAssertNil(reason, "enabling a mode must not return a blocking-probe failure")
        XCTAssertTrue(c.volumes.first!.settings.modes.contains(.write))
    }

    func testFriendlyErrorMapsEnoent() {
        XCTAssertEqual(KeepAliveController.friendlyError(errno: ENOENT),
                       "no readable file found — try Write")
        XCTAssertFalse(KeepAliveController.friendlyError(errno: ETIMEDOUT).contains("errno"),
                       "known errnos get human text, not 'errno N'")
    }

    // Re-enabling a mode after disabling brings the volume back out of .disabled.
    func testReEnablingAfterDisableReactivates() {
        let (c, key) = makeController()
        _ = c.setMode(.read, enabled: false, forKey: key)   // → disabled
        XCTAssertEqual(c.volumes.first!.status, .disabled)
        let reason = c.setMode(.read, enabled: true, forKey: key)
        XCTAssertNil(reason)
        XCTAssertTrue(c.volumes.first!.settings.modes.contains(.read),
                      "read is back on after re-enabling")
    }

    // Toggling write on then off returns the model to exactly read-only.
    func testToggleWriteOnThenOffIsClean() {
        let (c, key) = makeController()
        _ = c.setMode(.write, enabled: true, forKey: key)
        XCTAssertEqual(c.volumes.first!.settings.modes, [.read, .write])
        let reason = c.setMode(.write, enabled: false, forKey: key)
        XCTAssertNil(reason)
        XCTAssertEqual(c.volumes.first!.settings.modes, .read,
                       "model must be exactly read-only after toggling write off")
    }
}
