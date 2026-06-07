import Foundation

// Per-volume runtime + persisted state. The persisted slice (identity, modes,
// interval) is Codable and keyed by VolumeIdentity.storageKey; the runtime
// slice (mounted, status, current read selection) is rebuilt each session.
public struct VolumeSettings: Codable, Equatable, Sendable {
    public var identity: VolumeIdentity
    public var modes: KeepAliveMode
    public var intervalSeconds: Double

    public init(identity: VolumeIdentity,
                modes: KeepAliveMode = .defaultMode,
                intervalSeconds: Double = KeepAliveDefaults.interval) {
        self.identity = identity
        self.modes = modes
        self.intervalSeconds = intervalSeconds
    }
}

public enum KeepAliveDefaults {
    public static let interval: Double = 30      // Step-0 confirmed 30s holds a 45s timer
    public static let minInterval: Double = 5
    public static let maxInterval: Double = 120

    /// Clamp a user-entered interval into the supported range.
    public static func clampInterval(_ v: Double) -> Double {
        min(max(v, minInterval), maxInterval)
    }
}

// Live status shown per volume in the menu.
public enum VolumeStatus: Equatable, Sendable {
    case idle                       // known but not actively kept alive
    case checking                   // first poke in flight (verifying a just-enabled mode)
    case active(KeepAliveMode)      // being kept alive via these modes
    case disabled                   // both modes off — user is letting it sleep
    case failed(String)             // last poke failed; reason for the UI
    case needsRegrant               // stale/revoked bookmark
    case unmounted                  // known volume not currently present
}

public struct VolumeState: Identifiable, Equatable, Sendable {
    public var id: String { settings.identity.storageKey }
    public var settings: VolumeSettings
    public var status: VolumeStatus
    public var mountURL: URL?       // present only while mounted

    public init(settings: VolumeSettings,
                status: VolumeStatus = .idle,
                mountURL: URL? = nil) {
        self.settings = settings
        self.status = status
        self.mountURL = mountURL
    }
}
