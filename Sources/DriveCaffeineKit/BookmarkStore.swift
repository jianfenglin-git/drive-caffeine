import Foundation

// Persists per-volume settings and security-scoped bookmarks, keyed by
// VolumeIdentity.storageKey (UUID-first). Two responsibilities:
//   1. Codable settings (modes + interval) round-tripped through UserDefaults.
//   2. Security-scoped bookmark data, so a sandboxed app regains access to a
//      user-picked volume across launches WITHOUT re-prompting.
//
// The bookmark resolve path detects staleness (bookmarkDataIsStale): on stale,
// we drop the entry and signal the UI to prompt re-grant rather than silently
// failing. The store is protocol-injected so tests can use an in-memory backing.

public protocol KeyValueStore: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ data: Data?, forKey key: String)
    func removeObject(forKey key: String)
    func allKeys(withPrefix prefix: String) -> [String]
}

// UserDefaults-backed store for production.
public final class UserDefaultsStore: KeyValueStore {
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    public func data(forKey key: String) -> Data? { defaults.data(forKey: key) }
    public func set(_ data: Data?, forKey key: String) { defaults.set(data, forKey: key) }
    public func removeObject(forKey key: String) { defaults.removeObject(forKey: key) }
    public func allKeys(withPrefix prefix: String) -> [String] {
        defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(prefix) }
    }
}

public enum BookmarkResolution: Equatable {
    case resolved(URL)
    case stale            // entry dropped; caller should prompt re-grant
    case missing
    case failed(String)
}

public final class BookmarkStore {
    private let store: KeyValueStore
    private static let settingsPrefix = "settings."
    private static let bookmarkPrefix = "bookmark."

    public init(store: KeyValueStore = UserDefaultsStore()) {
        self.store = store
    }

    // MARK: Settings

    public func saveSettings(_ s: VolumeSettings) {
        guard let data = try? JSONEncoder().encode(s) else { return }
        store.set(data, forKey: Self.settingsPrefix + s.identity.storageKey)
    }

    public func loadSettings(for key: String) -> VolumeSettings? {
        guard let data = store.data(forKey: Self.settingsPrefix + key) else { return nil }
        return try? JSONDecoder().decode(VolumeSettings.self, from: data)
    }

    public func allSettings() -> [VolumeSettings] {
        store.allKeys(withPrefix: Self.settingsPrefix).compactMap { key in
            guard let data = store.data(forKey: key) else { return nil }
            return try? JSONDecoder().decode(VolumeSettings.self, from: data)
        }
    }

    public func forget(key: String) {
        store.removeObject(forKey: Self.settingsPrefix + key)
        store.removeObject(forKey: Self.bookmarkPrefix + key)
    }

    // MARK: Security-scoped bookmarks

    /// Create + persist a security-scoped bookmark for a user-picked volume URL.
    @discardableResult
    public func saveBookmark(for key: String, url: URL) -> Bool {
        #if canImport(AppKit)
        guard let data = try? url.bookmarkData(options: .withSecurityScope,
                                               includingResourceValuesForKeys: nil,
                                               relativeTo: nil) else { return false }
        #else
        guard let data = try? url.bookmarkData() else { return false }
        #endif
        store.set(data, forKey: Self.bookmarkPrefix + key)
        return true
    }

    /// Resolve a stored bookmark. On staleness, drop it and return `.stale` so
    /// the UI prompts re-grant — never a silent failure.
    public func resolveBookmark(for key: String) -> BookmarkResolution {
        guard let data = store.data(forKey: Self.bookmarkPrefix + key) else { return .missing }
        var stale = false
        do {
            #if canImport(AppKit)
            let url = try URL(resolvingBookmarkData: data,
                              options: .withSecurityScope,
                              relativeTo: nil,
                              bookmarkDataIsStale: &stale)
            #else
            let url = try URL(resolvingBookmarkData: data,
                              options: [],
                              relativeTo: nil,
                              bookmarkDataIsStale: &stale)
            #endif
            if stale {
                store.removeObject(forKey: Self.bookmarkPrefix + key)
                return .stale
            }
            return .resolved(url)
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
