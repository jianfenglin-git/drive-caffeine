import XCTest
@testable import DriveCaffeineKit

final class KeepAliveModeTests: XCTestCase {
    func testDefaultIsReadOnly() {
        XCTAssertTrue(KeepAliveMode.defaultMode.contains(.read))
        XCTAssertFalse(KeepAliveMode.defaultMode.contains(.write))
    }

    func testActiveRequiresAtLeastOne() {
        XCTAssertFalse(KeepAliveMode([]).isActive)
        XCTAssertTrue(KeepAliveMode.read.isActive)
        let both: KeepAliveMode = [.read, .write]
        XCTAssertTrue(both.isActive)
    }

    func testCodableRoundTrip() throws {
        let m: KeepAliveMode = [.read, .write]
        let data = try JSONEncoder().encode(m)
        let back = try JSONDecoder().decode(KeepAliveMode.self, from: data)
        XCTAssertEqual(m, back)
    }
}

final class VolumeIdentityTests: XCTestCase {
    func testUUIDKeyPreferredOverName() {
        let id = VolumeIdentity(uuid: "ABC-123", name: "My Passport")
        XCTAssertEqual(id.storageKey, "uuid:ABC-123")
        XCTAssertTrue(id.hasStableUUID)
    }

    func testFallsBackToNameWhenNoUUID() {
        let id = VolumeIdentity(uuid: nil, name: "My Passport")
        XCTAssertEqual(id.storageKey, "name:My Passport")
        XCTAssertFalse(id.hasStableUUID)
    }

    func testRenameDoesNotChangeKeyWhenUUIDStable() {
        // Same UUID, different name (user renamed the volume) → same storage key,
        // so settings persist across the rename. This is the whole point of
        // keying on UUID (eng review Issue 4).
        let a = VolumeIdentity(uuid: "U1", name: "Old Name")
        let b = VolumeIdentity(uuid: "U1", name: "New Name")
        XCTAssertEqual(a.storageKey, b.storageKey)
    }
}

final class IntervalClampTests: XCTestCase {
    func testClampWithinRange() {
        XCTAssertEqual(KeepAliveDefaults.clampInterval(30), 30)
    }
    func testClampBelowFloor() {
        XCTAssertEqual(KeepAliveDefaults.clampInterval(1), KeepAliveDefaults.minInterval)
    }
    func testClampAboveCeiling() {
        XCTAssertEqual(KeepAliveDefaults.clampInterval(9999), KeepAliveDefaults.maxInterval)
    }
    func testDefaultUnderTypicalTimer() {
        // 30s default must sit safely under the shortest timers we expect (~45s
        // measured, 60s WD My Book). Guard against a regression to 60.
        XCTAssertLessThan(KeepAliveDefaults.interval, 45)
    }
}
