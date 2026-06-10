import Foundation

// A volume's stable identity. We key everything (settings, bookmarks) on the
// volume UUID, NOT the name or mount path — both of which are unstable:
//   - the user can rename a volume
//   - /Volumes/Foo can become /Volumes/Foo 1 on a name collision at remount
// The UUID survives both, so a drive's settings persist across unplug/replug.
public struct VolumeIdentity: Hashable, Codable, Sendable {
    /// Volume UUID string (from URLResourceKey.volumeUUIDStringKey). Primary key.
    public let uuid: String?
    /// Human-readable name, for display only. Never used as a key.
    public let name: String

    public init(uuid: String?, name: String) {
        self.uuid = uuid
        self.name = name
    }

    /// The key we persist under. Prefer UUID; fall back to name only when the
    /// filesystem can't give us a UUID (rare — some network/FUSE mounts).
    public var storageKey: String {
        if let uuid, !uuid.isEmpty { return "uuid:\(uuid)" }
        return "name:\(name)"
    }

    public var hasStableUUID: Bool {
        if let uuid { return !uuid.isEmpty }
        return false
    }

    /// Resolve identity from a mounted volume URL. Returns nil only if the URL
    /// isn't a reachable volume.
    public static func resolve(from url: URL) -> VolumeIdentity? {
        let keys: Set<URLResourceKey> = [.volumeUUIDStringKey, .volumeNameKey, .nameKey]
        guard let vals = try? url.resourceValues(forKeys: keys) else {
            // Even without resource values, fall back to last path component so
            // the app degrades gracefully rather than dropping the volume.
            return VolumeIdentity(uuid: nil, name: url.lastPathComponent)
        }
        let name = vals.volumeName ?? vals.name ?? url.lastPathComponent
        return VolumeIdentity(uuid: vals.volumeUUIDString, name: name)
    }
}
