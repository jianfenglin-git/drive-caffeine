import XCTest
@testable import DriveCaffeineKit

// In-memory KeyValueStore so settings persistence is testable without touching
// real UserDefaults or the filesystem.
final class MemoryStore: KeyValueStore {
    private var dict: [String: Data] = [:]
    func data(forKey key: String) -> Data? { dict[key] }
    func set(_ data: Data?, forKey key: String) { dict[key] = data }
    func removeObject(forKey key: String) { dict[key] = nil }
    func allKeys(withPrefix prefix: String) -> [String] {
        dict.keys.filter { $0.hasPrefix(prefix) }
    }
}

final class BookmarkStoreTests: XCTestCase {
    func testSettingsRoundTrip() {
        let store = BookmarkStore(store: MemoryStore())
        let id = VolumeIdentity(uuid: "U1", name: "Passport")
        let s = VolumeSettings(identity: id, modes: [.read, .write], intervalSeconds: 45)
        store.saveSettings(s)

        let back = store.loadSettings(for: id.storageKey)
        XCTAssertEqual(back, s)
    }

    func testAllSettingsListsEveryVolume() {
        let store = BookmarkStore(store: MemoryStore())
        store.saveSettings(VolumeSettings(identity: .init(uuid: "A", name: "A")))
        store.saveSettings(VolumeSettings(identity: .init(uuid: "B", name: "B")))
        XCTAssertEqual(store.allSettings().count, 2)
    }

    func testForgetRemovesSettings() {
        let store = BookmarkStore(store: MemoryStore())
        let id = VolumeIdentity(uuid: "U1", name: "X")
        store.saveSettings(VolumeSettings(identity: id))
        store.forget(key: id.storageKey)
        XCTAssertNil(store.loadSettings(for: id.storageKey))
    }

    func testMissingBookmarkResolvesToMissing() {
        let store = BookmarkStore(store: MemoryStore())
        XCTAssertEqual(store.resolveBookmark(for: "uuid:none"), .missing)
    }
}
