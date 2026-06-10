import Foundation

// Performs ONE keep-alive poke for a volume, honoring its active modes. This is
// the bridge between the pure pieces (DiskIO, ReadTarget, ErrnoAction) and the
// timer machinery in KeepAliveController. It does real I/O, so it runs on the
// controller's per-volume serial queue — never the main thread.
//
// A poke runs the active modes in order (write, then read) and returns the
// first action that isn't `.ok`, so a failure is surfaced immediately. If all
// active modes succeed, the result is `.ok` with the modes that ran.
public enum KeepAliveEngine {

    public struct Outcome: Equatable, Sendable {
        public let action: KeepAliveAction
        public let ranModes: KeepAliveMode
        public init(action: KeepAliveAction, ranModes: KeepAliveMode) {
            self.action = action
            self.ranModes = ranModes
        }
    }

    /// One poke. `writable` tells the read path whether to use the app marker or
    /// hunt for an existing file. The caller resolves it (mount flags or a prior
    /// write result) and is responsible for security-scoped access being active.
    public static func poke(volumeRoot: URL,
                            modes: KeepAliveMode,
                            writable: Bool,
                            fileManager: FileManager = .default) -> Outcome {
        guard modes.isActive else {
            return Outcome(action: .ok, ranModes: [])
        }

        var ran: KeepAliveMode = []

        // Write first (if enabled and the volume is writable). If a write fails
        // read-only, ErrnoAction returns .fallbackToRead — the controller flips
        // the volume's mode and the read below still runs this cycle.
        if modes.contains(.write) {
            let res = DiskIO.writeMarker(path: DiskIO.markerPath(forVolume: volumeRoot))
            let action = ErrnoAction.action(forResult: res.result, errno: res.errno)
            ran.insert(.write)
            if action != .ok && action != .fallbackToRead {
                return Outcome(action: action, ranModes: ran)
            }
            // On .fallbackToRead we fall through to the read path below.
        }

        if modes.contains(.read) || (modes.contains(.write) && !writable) {
            // Always read a REAL existing file (never our own marker) so the read
            // is a genuine device hit, not a RAM-served cache hit. See ReadTarget.
            guard let selection = ReadTarget.select(volumeRoot: volumeRoot,
                                                    fileManager: fileManager) else {
                // No readable file on the drive → can't keep alive via read.
                return Outcome(action: ErrnoAction.noReadableFile, ranModes: ran)
            }
            let path: String
            switch selection {
            case .marker(let p): path = p          // (select no longer returns this)
            case .existingFile(let p): path = p
            }

            let res = DiskIO.readUncached(path: path)
            DCLog.keepalive.info("read \(res.result) bytes from \((path as NSString).lastPathComponent, privacy: .public) (errno \(res.errno))")
            let action = ErrnoAction.action(forResult: res.result, errno: res.errno)
            ran.insert(.read)
            if action != .ok {
                return Outcome(action: action, ranModes: ran)
            }
        }

        return Outcome(action: .ok, ranModes: ran)
    }
}
