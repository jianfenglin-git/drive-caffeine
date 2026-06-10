import XCTest
@testable import DriveCaffeineKit

// DiskIO mechanics tested against a temp directory on the local disk. This
// proves the I/O is CORRECT (opens, sets flags, round-trips bytes, handles
// missing files). It does NOT prove "defeats a firmware timer" — that's the
// real-drive integration suite + the Step-0.5 spike (both passed on hardware).
final class DiskIOTests: XCTestCase {
    var tmp: URL!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("drivecaffeine-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    func testWriteMarkerThenReadItBack() {
        let path = DiskIO.markerPath(forVolume: tmp)
        let w = DiskIO.writeMarker(path: path)
        XCTAssertTrue(w.succeeded, "write errno \(w.errno)")
        XCTAssertEqual(w.result, 8, "fixed 8-byte payload")

        let r = DiskIO.readUncached(path: path)
        XCTAssertTrue(r.succeeded, "read errno \(r.errno)")
        XCTAssertGreaterThan(r.result, 0)
    }

    func testMarkerIsFixedSizeAcrossWrites() throws {
        let path = DiskIO.markerPath(forVolume: tmp)
        _ = DiskIO.writeMarker(path: path)
        _ = DiskIO.writeMarker(path: path)
        _ = DiskIO.writeMarker(path: path)
        let size = try FileManager.default
            .attributesOfItem(atPath: path)[.size] as? Int
        XCTAssertEqual(size, 8, "marker must not grow (truncate/overwrite, never append)")
    }

    func testReadMissingFileFails() {
        let r = DiskIO.readUncached(path: tmp.appendingPathComponent("nope").path)
        XCTAssertFalse(r.succeeded)
        XCTAssertEqual(ErrnoAction.action(forResult: r.result, errno: r.errno), .waitRemount)
    }

    func testMarkerIsHidden() {
        XCTAssertTrue(DiskIO.markerName.hasPrefix("."), "marker must be a hidden dotfile")
    }
}

final class ReadTargetTests: XCTestCase {
    var tmp: URL!
    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("dc-rt-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: tmp) }

    // Regression for the cache-hit no-op bug (2026-06-06): Read must pick a REAL
    // existing file even on a WRITABLE volume — never the app's own marker, which
    // gets served from RAM in ~0ms and lets the drive sleep. Proven by os_log.
    func testWritableVolumeReadsRealFileNotMarker() throws {
        let real = tmp.appendingPathComponent("real-data.txt")
        try Data(repeating: 0x42, count: 500).write(to: real)
        let sel = ReadTarget.select(volumeRoot: tmp, writable: true)
        guard case .existingFile(let p)? = sel else {
            return XCTFail("writable volume must read a real existing file, not the marker")
        }
        XCTAssertFalse(p.hasSuffix(DiskIO.markerName),
                       "must NOT read our own marker — that's the cache-hit bug")
        XCTAssertEqual(URL(fileURLWithPath: p).resolvingSymlinksInPath().path,
                       real.resolvingSymlinksInPath().path)
    }

    func testReadOnlyPicksSmallExistingFile() throws {
        let small = tmp.appendingPathComponent("small.txt")
        try Data(repeating: 0x41, count: 100).write(to: small)
        let sel = ReadTarget.select(volumeRoot: tmp, writable: false)
        guard case .existingFile(let p)? = sel else { return XCTFail("expected existing file") }
        // Compare resolved paths: /var is a symlink to /private/var on macOS.
        XCTAssertEqual(URL(fileURLWithPath: p).resolvingSymlinksInPath().path,
                       small.resolvingSymlinksInPath().path)
    }

    func testReadOnlyWithOnlyLargeFilesStillPicksOne() throws {
        // Plex case: only a big file exists. We still pick it (read first chunk only).
        let big = tmp.appendingPathComponent("movie.bin")
        try Data(repeating: 0, count: 3_000_000).write(to: big)
        let sel = ReadTarget.select(volumeRoot: tmp, writable: false)
        guard case .existingFile(let p)? = sel else { return XCTFail("expected existing file") }
        XCTAssertEqual(URL(fileURLWithPath: p).resolvingSymlinksInPath().path,
                       big.resolvingSymlinksInPath().path)

        // And reading it returns at most one chunk, not the whole 3MB.
        let r = DiskIO.readUncached(path: p)
        XCTAssertTrue(r.succeeded)
        XCTAssertLessThanOrEqual(r.result, DiskIO.chunkSize)
    }

    func testReadOnlyEmptyVolumeReturnsNil() {
        XCTAssertNil(ReadTarget.select(volumeRoot: tmp, writable: false))
    }
}

final class KeepAliveEngineTests: XCTestCase {
    var tmp: URL!
    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("dc-eng-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: tmp) }

    func testReadModeReadsRealFileOnWritableVolume() throws {
        // Read now requires a REAL existing file (not the app's marker), even on
        // writable volumes. With a real file present, read succeeds.
        try Data(repeating: 0x43, count: 4096).write(to: tmp.appendingPathComponent("data.bin"))
        let out = KeepAliveEngine.poke(volumeRoot: tmp, modes: .read, writable: true)
        XCTAssertEqual(out.action, .ok)
        XCTAssertTrue(out.ranModes.contains(.read))
    }

    func testReadModeOnEmptyWritableVolumeReportsNoFile() {
        // No real file on the volume → read can't run; surfaces noReadableFile
        // (the UI tells the user to try Write). Previously this wrongly "succeeded"
        // by reading the app's own marker — the cache-hit bug.
        let out = KeepAliveEngine.poke(volumeRoot: tmp, modes: .read, writable: true)
        XCTAssertEqual(out.action, ErrnoAction.noReadableFile)
    }

    func testWriteModeOnWritableTempSucceeds() {
        let out = KeepAliveEngine.poke(volumeRoot: tmp, modes: .write, writable: true)
        XCTAssertEqual(out.action, .ok)
        XCTAssertTrue(out.ranModes.contains(.write))
    }

    func testReadOnlyEmptyVolumeReportsNoReadableFile() {
        let out = KeepAliveEngine.poke(volumeRoot: tmp, modes: .read, writable: false)
        XCTAssertEqual(out.action, ErrnoAction.noReadableFile)
    }

    func testInactiveModesIsOkNoop() {
        let out = KeepAliveEngine.poke(volumeRoot: tmp, modes: [], writable: true)
        XCTAssertEqual(out.action, .ok)
        XCTAssertEqual(out.ranModes, [])
    }
}
