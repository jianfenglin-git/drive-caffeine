import XCTest
@testable import DriveCaffeineKit

// Regression tests for "eject a drive, plug it back in → it stays 'Not
// connected', the Read toggle does nothing, and no timed read happens until the
// app is relaunched" (2026-11-15).
//
// Root cause: onMount started security-scoped access on the URL from the
// NSWorkspace mount notification. Under App Sandbox that URL carries no scope,
// so startAccessingSecurityScopedResource() returns false (verified in a
// sandboxed probe), activeAccessURLs stayed empty, and arm()/setMode() both bail
// without an access URL. Relaunch "fixed" it because launch resolves the stored
// bookmark, which does carry the grant. The fix makes remount do the same.
//
// `swift test` isn't sandboxed (plain URLs DO start access here), so the
// sandbox rule is modelled by the injected `startScopedAccess`: the
// notification URL is a different directory on the SAME volume (so it resolves
// to the same identity) and is refused, like an unscoped URL in the sandbox.
@MainActor
final class RemountTests: XCTestCase {

    private var root: URL!
    private var driveDir: URL!         // stands in for the drive (bookmarked)
    private var notificationURL: URL!  // what NSWorkspace hands us: same volume, no scope

    override func setUpWithError() throws {
        let fm = FileManager.default
        root = fm.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("dc-remount-\(UUID().uuidString)", isDirectory: true)
        driveDir = root.appendingPathComponent("drive", isDirectory: true)
        notificationURL = root.appendingPathComponent("notified", isDirectory: true)
        try fm.createDirectory(at: driveDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: notificationURL, withIntermediateDirectories: true)
        try Data("keepalive".utf8).write(to: driveDir.appendingPathComponent("sample.txt"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    /// A controller that already knows the "drive" (settings + bookmark), as on
    /// a launch after the user added it once.
    private func makeController(modes: KeepAliveMode = .read) throws -> (KeepAliveController, String) {
        let identity = try XCTUnwrap(VolumeIdentity.resolve(from: driveDir))
        XCTAssertEqual(VolumeIdentity.resolve(from: notificationURL)?.storageKey, identity.storageKey,
                       "precondition: notification URL must identify as the same volume")
        let store = BookmarkStore(store: MemoryStore())
        store.saveSettings(VolumeSettings(identity: identity, modes: modes))
        guard store.saveBookmark(for: identity.storageKey, url: driveDir) else {
            throw XCTSkip("can't create a security-scoped bookmark in this environment")
        }
        let unscopedPath = notificationURL.standardizedFileURL.path
        let c = KeepAliveController(store: store, startScopedAccess: {
            $0.standardizedFileURL.path != unscopedPath
        })
        addTeardownBlock { @MainActor in c.removeVolume(key: identity.storageKey) }   // stop runners
        return (c, identity.storageKey)
    }

    private func status(_ c: KeepAliveController) -> VolumeStatus? { c.volumes.first?.status }

    // The reported bug, end to end: eject → reconnect must re-arm on its own.
    func testReconnectReArmsWithoutRelaunch() throws {
        let (c, key) = try makeController()
        XCTAssertEqual(status(c), .active(.read), "launch resolves the bookmark and arms")
        let mounted = try XCTUnwrap(c.volumes.first?.mountURL)

        c.handleUnmount(url: mounted)
        XCTAssertEqual(status(c), .unmounted)
        XCTAssertNil(c.volumes.first?.mountURL, "an ejected drive has no mount URL")

        c.handleMount(url: notificationURL)
        XCTAssertEqual(status(c), .active(.read),
                       "reconnect must re-arm from the bookmark, not stay 'Not connected'")
        XCTAssertEqual(c.volumes.first?.mountURL?.standardizedFileURL.path,
                       driveDir.standardizedFileURL.path,
                       "access must come from the bookmark-resolved URL")

        // "Can't be selected again": after reconnect, toggles must work too.
        // .checking proves setMode found an access URL and armed a runner.
        _ = c.setMode(.read, enabled: false, forKey: key)
        XCTAssertEqual(status(c), .disabled)
        _ = c.setMode(.read, enabled: true, forKey: key)
        XCTAssertEqual(status(c), .checking, "re-enabling Read after reconnect must arm again")
    }

    // Reconnecting when the unmount was never seen (missed notification, or a
    // poke noticed first) must still take the fresh grant, not keep a dead one.
    func testReconnectWithoutPriorUnmountStillReArms() throws {
        let (c, _) = try makeController()
        c.handleMount(url: notificationURL)
        XCTAssertEqual(status(c), .active(.read))
        XCTAssertNotNil(c.volumes.first?.mountURL)
    }

    // URL == compares strings, so a trailing-slash difference between the
    // stored mount URL and the unmount notification's used to miss the match.
    func testUnmountMatchesWithOrWithoutTrailingSlash() throws {
        for withSlash in [true, false] {
            let (c, _) = try makeController()
            let path = try XCTUnwrap(c.volumes.first?.mountURL).standardizedFileURL.path
            let note = URL(string: "file://" + path + (withSlash ? "/" : ""))!
            c.handleUnmount(url: note)
            XCTAssertEqual(status(c), .unmounted, "unmount via \(note.absoluteString) must match")
        }
    }

    // A drive the user set to sleep (both modes off) must come back Disabled —
    // not "Active — keeping awake via " with a green check and nothing running.
    func testDisabledDriveStaysDisabledAcrossLaunchAndReconnect() throws {
        let (c, key) = try makeController(modes: [])
        XCTAssertEqual(status(c), .disabled, "launch must not report a disabled drive as active")

        c.handleUnmount(url: try XCTUnwrap(c.volumes.first?.mountURL))
        c.handleMount(url: notificationURL)
        XCTAssertEqual(status(c), .disabled)

        // ...but it IS connected, so turning Read on must arm it.
        _ = c.setMode(.read, enabled: true, forKey: key)
        XCTAssertEqual(status(c), .checking)
    }

    // A drive the app has never seen mounting must not be added or touched.
    func testMountOfUnknownVolumeIsIgnored() {
        let c = KeepAliveController(store: BookmarkStore(store: MemoryStore()),
                                    startScopedAccess: { _ in true })
        c.handleMount(url: driveDir)
        XCTAssertTrue(c.volumes.isEmpty)
    }
}
