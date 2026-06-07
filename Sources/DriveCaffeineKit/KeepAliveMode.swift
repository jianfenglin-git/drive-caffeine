import Foundation

// The two independent keep-alive mechanisms a volume can use. Read and Write
// are NOT mutually exclusive — a volume can run both (mirrors what the old
// disk-keep-alive did: write + read every cycle). At least one must be on for
// keep-alive to be active.
public struct KeepAliveMode: OptionSet, Codable, Equatable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    /// Uncached read of a file (F_NOCACHE). Default ON. Gentle (no disk wear),
    /// works on read-only volumes, and the read command crosses the enclosure
    /// bridge chip — which is what resets its idle timer.
    public static let read  = KeepAliveMode(rawValue: 1 << 0)

    /// Write a tiny hidden marker + F_FULLFSYNC. Default OFF. For the minority
    /// of drives whose idle timer resets only on writes (timer in the drive's
    /// own firmware rather than the bridge).
    public static let write = KeepAliveMode(rawValue: 1 << 1)

    /// The out-of-box default: read only.
    public static let defaultMode: KeepAliveMode = .read

    public var isActive: Bool { !isEmpty }
}
