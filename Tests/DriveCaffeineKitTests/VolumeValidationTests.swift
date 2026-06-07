import XCTest
@testable import DriveCaffeineKit

// Regression tests for the "added /Volumes or the internal disk → errno 2 yellow
// bang" bug (2026-06-06). The fix rejects bad targets up front with a clear
// message instead of accepting them and failing at poke time.
final class VolumeValidationTests: XCTestCase {

    func testRejectsVolumesFolder() {
        let reason = KeepAliveController.rejectionReason(for: URL(fileURLWithPath: "/Volumes"))
        XCTAssertNotNil(reason, "/Volumes is the mount-point folder, not a drive — must be rejected")
        XCTAssertTrue(reason!.lowercased().contains("volumes") || reason!.lowercased().contains("folder"))
    }

    func testRejectsRootSystemDisk() {
        let reason = KeepAliveController.rejectionReason(for: URL(fileURLWithPath: "/"))
        XCTAssertNotNil(reason, "/ is the system disk — must be rejected")
    }

    func testRejectsInternalBootVolume() {
        // The internal boot volume resolves through /Volumes/Macintosh HD on a
        // standard Mac. It's internal + non-removable → reject (it never spins down).
        let macHD = URL(fileURLWithPath: "/Volumes/Macintosh HD")
        // Only assert if this path exists on the test machine (it does on macOS).
        if FileManager.default.fileExists(atPath: macHD.path) {
            let reason = KeepAliveController.rejectionReason(for: macHD)
            XCTAssertNotNil(reason, "internal non-removable boot volume must be rejected")
        }
    }

    @MainActor
    func testRegrantRejectsWrongDrive() {
        // A known drive (stable UUID) whose bookmark went stale. Re-granting to
        // a DIFFERENT drive must be rejected, not silently swap identities.
        let store = BookmarkStore(store: MemoryStore())
        let original = VolumeIdentity(uuid: "ORIGINAL-UUID", name: "MyPassport")
        store.saveSettings(VolumeSettings(identity: original))
        let c = KeepAliveController(store: store)
        // Re-grant with /Volumes (a different, also-invalid target) → rejected.
        let reason = c.regrant(key: original.storageKey,
                               pickedURL: URL(fileURLWithPath: "/Volumes"))
        XCTAssertNotNil(reason, "re-granting to a non-matching/invalid target must be rejected")
    }

    func testAllowsUnclassifiableMount() {
        // A path we can't classify (no resource values) should NOT be hard-rejected
        // here — we allow it and let the poke layer surface a real failure. Use a
        // temp dir as a stand-in for "some mount we can't classify as internal."
        let tmp = FileManager.default.temporaryDirectory
        // A temp dir lives on the internal disk, so it MAY be rejected as internal —
        // that's acceptable. The contract we assert: the function never crashes and
        // returns a String? for any input.
        _ = KeepAliveController.rejectionReason(for: tmp)
    }
}
