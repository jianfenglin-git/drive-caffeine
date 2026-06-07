import Foundation
#if canImport(AppKit)
import AppKit
#endif

// The app's brain. Owns the list of volumes, one PerVolumeRunner each, the
// bookmark store, and the system lifecycle wiring (mount/unmount/sleep/wake +
// App Nap defense). The UI observes `volumes`.
@MainActor
public final class KeepAliveController: ObservableObject {

    @Published public private(set) var volumes: [VolumeState] = []

    private let store: BookmarkStore
    private var runners: [String: PerVolumeRunner] = [:]   // keyed by storageKey
    private var activeAccessURLs: [String: URL] = [:]      // security-scoped, started
    private var activityToken: (any NSObjectProtocol)?      // App Nap defense

    public init(store: BookmarkStore = BookmarkStore()) {
        self.store = store
        loadPersisted()
        installLifecycleObservers()
    }

    // MARK: Bootstrap

    /// Rebuild volume list from persisted settings; resolve bookmarks to find
    /// which are currently mounted, and re-arm those.
    private func loadPersisted() {
        let settings = store.allSettings()
        volumes = settings.map { VolumeState(settings: $0, status: .unmounted) }
        for s in settings { resumeIfMounted(key: s.identity.storageKey) }
    }

    private func resumeIfMounted(key: String) {
        switch store.resolveBookmark(for: key) {
        case .resolved(let url):
            beginAccess(key: key, url: url)
            updateStatus(key: key, mountURL: url)
            arm(key: key)
        case .stale:
            setStatus(key: key, .needsRegrant)
        case .missing, .failed:
            setStatus(key: key, .unmounted)
        }
    }

    // MARK: Public API (UI calls these)

    /// Add a freshly user-picked volume (from an NSOpenPanel URL), persist its
    /// bookmark + default settings, and start keeping it alive.
    /// Returns nil on success, or a human-readable reason the volume was rejected
    /// (e.g. the user picked the internal system disk or `/Volumes` itself).
    @discardableResult
    public func addVolume(url: URL) -> String? {
        // Validate BEFORE accepting. Picking the internal disk, `/Volumes`, or
        // `/` would later fail at poke time with a cryptic errno (ENOENT/EPERM)
        // and a yellow bang. Reject up front with a clear message instead.
        if let reason = Self.rejectionReason(for: url) { return reason }

        guard let identity = VolumeIdentity.resolve(from: url) else {
            return "Couldn't read that drive's info. Try a different one."
        }
        let key = identity.storageKey
        store.saveBookmark(for: key, url: url)
        let settings = store.loadSettings(for: key) ?? VolumeSettings(identity: identity)
        store.saveSettings(settings)

        if let idx = volumes.firstIndex(where: { $0.id == key }) {
            volumes[idx].settings = settings
        } else {
            volumes.append(VolumeState(settings: settings))
        }
        beginAccess(key: key, url: url)
        updateStatus(key: key, mountURL: url)
        arm(key: key)
        return nil
    }

    /// Re-grant access to a drive whose security-scoped bookmark went stale
    /// (after an OS update, reformat, or volume rename). The user re-picks the
    /// drive in a panel; we re-save the bookmark and resume with the SAME
    /// settings (read/write/interval), keyed by UUID — no re-setup.
    ///
    /// `pickedURL` is what the user chose. Returns nil on success, or a reason:
    /// either a normal rejection, or a mismatch if they picked a different drive.
    @discardableResult
    public func regrant(key: String, pickedURL url: URL) -> String? {
        if let reason = Self.rejectionReason(for: url) { return reason }
        guard let picked = VolumeIdentity.resolve(from: url) else {
            return "Couldn't read that drive's info. Try again."
        }
        // Guard against re-granting to the wrong drive: if the original had a
        // stable UUID, the picked drive must match it.
        if let existing = volumes.first(where: { $0.id == key }),
           existing.settings.identity.hasStableUUID,
           picked.storageKey != key {
            return "That's a different drive. Pick \(existing.settings.identity.name) to restore it."
        }
        // addVolume already restores existing settings (loadSettings by key) and
        // re-arms, so re-granting the same drive resumes exactly where it was.
        return addVolume(url: url)
    }

    /// Why a picked URL is not a valid keep-alive target, or nil if it's fine.
    /// External/removable volumes are the target; the internal boot disk,
    /// the `/Volumes` mount-point directory, and `/` are rejected.
    /// `nonisolated` — pure function over the URL, no actor state.
    nonisolated static func rejectionReason(for url: URL) -> String? {
        let path = url.standardizedFileURL.path
        if path == "/Volumes" {
            return "That's the Volumes folder, not a drive. Pick the external drive itself."
        }
        if path == "/" {
            return "That's the system disk. Pick an external drive."
        }
        let keys: Set<URLResourceKey> = [.volumeIsInternalKey, .volumeIsRemovableKey,
                                          .volumeIsEjectableKey, .volumeURLKey]
        guard let v = try? url.resourceValues(forKeys: keys) else {
            return nil   // can't classify (e.g. network mount) — allow, fail later if truly bad
        }
        // If macOS says this is the internal, non-removable boot volume, reject.
        let isInternal = v.volumeIsInternal ?? false
        let isRemovable = (v.volumeIsRemovable ?? false) || (v.volumeIsEjectable ?? false)
        if isInternal && !isRemovable {
            let name = v.volume?.lastPathComponent ?? "the system disk"
            return "\(name) is your internal disk — it doesn't spin down. Pick an external drive."
        }
        return nil
    }

    /// Toggle a mode on/off. NON-BLOCKING: the checkbox flips instantly and the
    /// model is committed immediately; the actual keep-alive I/O happens on the
    /// runner's background queue. We do NOT run a synchronous probe here — on a
    /// sleeping drive that I/O blocks for up to the watchdog (~8s) and freezes
    /// the popover. Instead we mark `.checking` and let the first background poke
    /// report success/failure via `apply()`, which replaces `.checking` with
    /// `.active`/`.failed`/etc.
    ///
    /// Returns a reason ONLY for failures we can determine instantly without I/O
    /// (enabling Write on a read-only mount). Everything else resolves async.
    @discardableResult
    public func setMode(_ mode: KeepAliveMode, enabled: Bool, forKey key: String) -> String? {
        guard let idx = volumes.firstIndex(where: { $0.id == key }) else { return "Unknown volume" }
        let modes = volumes[idx].settings.modes
        let proposed: KeepAliveMode = enabled ? modes.union(mode) : modes.subtracting(mode)

        // Instant, no-I/O guard: Write needs a writable volume. isWritable is a
        // cheap stat, not a blocking poke, so it's safe on the main actor.
        if enabled, mode == .write, let url = activeAccessURLs[key], !isWritable(url) {
            objectWillChange.send()   // snap the rejected checkbox back
            return "This drive is read-only — Write isn't available. Use Read."
        }

        volumes[idx].settings.modes = proposed
        store.saveSettings(volumes[idx].settings)

        if proposed.isActive {
            if activeAccessURLs[key] != nil {
                setStatus(key: key, .checking)   // first poke verifies in the background
                arm(key: key)
            }
        } else {
            // Both modes off is allowed: keep-alive is DISABLED for this volume
            // (the user is letting it sleep). Stop poking, mark disabled.
            runners[key]?.stop()
            setStatus(key: key, .disabled)
        }
        return nil
    }

    public func setInterval(_ seconds: Double, forKey key: String) {
        guard let idx = volumes.firstIndex(where: { $0.id == key }) else { return }
        volumes[idx].settings.intervalSeconds = KeepAliveDefaults.clampInterval(seconds)
        store.saveSettings(volumes[idx].settings)
        if activeAccessURLs[key] != nil { arm(key: key) }
    }

    public func removeVolume(key: String) {
        runners[key]?.stop()
        runners[key] = nil
        endAccess(key: key)
        store.forget(key: key)
        volumes.removeAll { $0.id == key }
    }

    // MARK: Arming runners

    private func arm(key: String) {
        guard let idx = volumes.firstIndex(where: { $0.id == key }),
              let url = activeAccessURLs[key] else { return }
        let settings = volumes[idx].settings
        let writable = isWritable(url)

        let runner = runners[key] ?? PerVolumeRunner(label: key)
        runners[key] = runner

        runner.start(
            interval: settings.intervalSeconds,
            poke: { KeepAliveEngine.poke(volumeRoot: url, modes: settings.modes, writable: writable) },
            report: { [weak self] outcome in
                Task { @MainActor in self?.apply(outcome, key: key, url: url) }
            }
        )
        ensureActivity()
        // Do NOT set .active here — the status stays .checking until the first
        // background poke reports via apply(). Setting .active now would lie
        // about a drive whose first poke hasn't succeeded yet. If we're re-arming
        // an already-active volume (e.g. interval change), reflect that instead.
        if case .checking = currentStatus(key) {
            // leave .checking; apply() will resolve it
        } else {
            setStatus(key: key, .active(settings.modes))
        }
    }

    private func currentStatus(_ key: String) -> VolumeStatus? {
        volumes.first(where: { $0.id == key })?.status
    }

    private func apply(_ outcome: KeepAliveEngine.Outcome, key: String, url: URL) {
        switch outcome.action {
        case .ok:
            if let idx = volumes.firstIndex(where: { $0.id == key }) {
                setStatus(key: key, .active(volumes[idx].settings.modes))
            }
        case .fallbackToRead:
            // Write hit read-only → flip this volume to read and re-arm.
            if let idx = volumes.firstIndex(where: { $0.id == key }) {
                volumes[idx].settings.modes = .read
                store.saveSettings(volumes[idx].settings)
                setStatus(key: key, .active(.read))
                arm(key: key)
            }
        case .waitRemount:
            runners[key]?.stop()
            setStatus(key: key, .unmounted)
        case .regrant:
            runners[key]?.stop()
            setStatus(key: key, .needsRegrant)
        case .markFailed(let e):
            setStatus(key: key, .failed(Self.friendlyError(errno: e)))
        }
    }

    /// Human-readable failure text instead of a raw "errno 2".
    nonisolated static func friendlyError(errno e: Int32) -> String {
        switch e {
        case ENOENT: return "no readable file found — try Write"
        case EROFS, EACCES, EPERM: return "drive is read-only"
        case ENOSPC: return "drive is full"
        case ETIMEDOUT: return "drive not responding"
        default: return "couldn't access the drive (errno \(e))"
        }
    }

    // MARK: Security-scoped access

    private func beginAccess(key: String, url: URL) {
        #if canImport(AppKit)
        if activeAccessURLs[key] == nil, url.startAccessingSecurityScopedResource() {
            activeAccessURLs[key] = url
        }
        #else
        activeAccessURLs[key] = url
        #endif
    }

    private func endAccess(key: String) {
        #if canImport(AppKit)
        activeAccessURLs[key]?.stopAccessingSecurityScopedResource()
        #endif
        activeAccessURLs[key] = nil
    }

    // MARK: System lifecycle

    private func installLifecycleObservers() {
        #if canImport(AppKit)
        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(self, selector: #selector(onMount(_:)),
                       name: NSWorkspace.didMountNotification, object: nil)
        ws.addObserver(self, selector: #selector(onUnmount(_:)),
                       name: NSWorkspace.didUnmountNotification, object: nil)
        ws.addObserver(self, selector: #selector(onSleep(_:)),
                       name: NSWorkspace.willSleepNotification, object: nil)
        ws.addObserver(self, selector: #selector(onWake(_:)),
                       name: NSWorkspace.didWakeNotification, object: nil)
        #endif
    }

    #if canImport(AppKit)
    @objc private func onMount(_ note: Notification) {
        guard let url = note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL,
              let identity = VolumeIdentity.resolve(from: url) else { return }
        let key = identity.storageKey
        // Only re-arm volumes we already know about.
        if volumes.contains(where: { $0.id == key }) {
            beginAccess(key: key, url: url)
            updateStatus(key: key, mountURL: url)
            arm(key: key)
        }
    }

    @objc private func onUnmount(_ note: Notification) {
        guard let url = note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else { return }
        // Match by mount URL among known volumes.
        for v in volumes where v.mountURL == url {
            runners[v.id]?.stop()
            endAccess(key: v.id)
            setStatus(key: v.id, .unmounted)
        }
    }

    @objc private func onSleep(_ note: Notification) {
        // Suspend all timers — no point poking while the Mac sleeps, and we
        // avoid racing a write as the system goes down.
        for (_, runner) in runners { runner.stop() }
    }

    @objc private func onWake(_ note: Notification) {
        // Re-validate each known volume still mounted, then re-arm.
        for v in volumes where activeAccessURLs[v.id] != nil {
            arm(key: v.id)
        }
    }
    #endif

    // MARK: App Nap defense

    private func ensureActivity() {
        #if canImport(AppKit)
        guard activityToken == nil else { return }
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Keeping selected external drives awake"
        )
        #endif
    }

    // MARK: status helpers

    private func setStatus(key: String, _ status: VolumeStatus) {
        guard let idx = volumes.firstIndex(where: { $0.id == key }) else { return }
        volumes[idx].status = status
    }

    private func updateStatus(key: String, mountURL: URL?) {
        guard let idx = volumes.firstIndex(where: { $0.id == key }) else { return }
        volumes[idx].mountURL = mountURL
    }

    private func isWritable(_ url: URL) -> Bool {
        FileManager.default.isWritableFile(atPath: url.path)
    }
}
