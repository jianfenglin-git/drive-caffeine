import Foundation

// Low-level keep-alive I/O. One shared core (`perform`) does the open / set-flag
// / operate / close, and the three public entry points are thin wrappers so the
// flag and errno handling can't drift between read and write.
//
// WHY THIS WORKS (read this before "optimizing"):
// The idle timer that spins these drives down lives in the ENCLOSURE BRIDGE CHIP
// (JMicron/ASMedia), not the platters. It resets on I/O traffic CROSSING THE
// BRIDGE, not on platter motion. F_NOCACHE is load-bearing: it forces the read
// command past the macOS unified buffer cache so a real command reaches the
// device every interval — even if the drive's own DRAM serves the bytes, the
// bridge saw the command and resets its timer. DROPPING F_NOCACHE would let the
// OS satisfy the read from RAM, the command never crosses the bridge, and the
// drive spins down while the app still reports success. Verified end-to-end in
// the Step-0.5 sandbox spike.
//
// A poke's outcome is reported as a PokeResult so the controller can hand it to
// the pure ErrnoAction mapper. All functions here are blocking and MUST run off
// the main thread (the controller uses a per-volume serial queue + watchdog).
public struct PokeResult: Equatable, Sendable {
    /// Syscall return: bytes read/written (>= 0) or -1 on error.
    public let result: Int
    /// errno captured immediately after the failing syscall; 0 on success.
    public let errno: Int32
    public init(result: Int, errno: Int32) {
        self.result = result
        self.errno = errno
    }
    public var succeeded: Bool { result >= 0 }
    public static let success = PokeResult(result: 0, errno: 0)
}

public enum DiskIO {

    /// Marker filename written/read on writable volumes. Small AND hidden.
    public static let markerName = ".drivecaffeine_keepalive"

    /// One block. We only ever touch the first chunk of any file, never the whole thing.
    public static let chunkSize = 64 * 1024

    // MARK: Public operations

    /// Read the first chunk of `path` with caching bypassed. Used for both the
    /// app's own marker (writable volumes) and an arbitrary existing file
    /// (read-only volumes — see ReadTarget).
    public static func readUncached(path: String) -> PokeResult {
        perform(path: path, flags: O_RDONLY, create: false) { fd in
            _ = fcntl(fd, F_NOCACHE, 1)
            var buf = [UInt8](repeating: 0, count: chunkSize)
            let n = buf.withUnsafeMutableBytes { read(fd, $0.baseAddress, $0.count) }
            return n
        }
    }

    /// Write a tiny fixed payload to the marker at offset 0 and force it to
    /// physical media with F_FULLFSYNC (plain fsync can return while the data
    /// still sits in the drive's cache). Truncate/overwrite — the file never
    /// grows. `path` should be `<volume>/markerName`.
    public static func writeMarker(path: String) -> PokeResult {
        perform(path: path, flags: O_WRONLY | O_CREAT | O_TRUNC, create: true) { fd in
            // 8-byte payload (content is irrelevant; the I/O crossing the bridge is the point).
            let payload: [UInt8] = [0xDC, 0xAF, 0xFE, 0x00, 0x00, 0x00, 0x00, 0x01]
            let n = payload.withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
            if n < 0 { return n }
            // The flush is the point — without F_FULLFSYNC the bridge may never
            // see the write hit media.
            if fcntl(fd, F_FULLFSYNC) < 0 { return -1 }
            return n
        }
    }

    /// Full path to a volume's marker file given the volume root URL.
    public static func markerPath(forVolume root: URL) -> String {
        root.appendingPathComponent(markerName).path
    }

    // MARK: Shared core

    /// open → run `body(fd)` → close, capturing errno on any failure. `body`
    /// returns the syscall result (>= 0 ok, < 0 error). Keeping this single
    /// chokepoint means the read and write paths share identical open/close and
    /// errno-capture semantics.
    static func perform(path: String,
                        flags: Int32,
                        create: Bool,
                        _ body: (Int32) -> Int) -> PokeResult {
        let fd = create ? open(path, flags, 0o644) : open(path, flags)
        if fd < 0 { return PokeResult(result: -1, errno: errno) }
        defer { close(fd) }

        let n = body(fd)
        if n < 0 { return PokeResult(result: -1, errno: errno) }
        return PokeResult(result: n, errno: 0)
    }
}
